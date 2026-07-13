// group-guard: server-side authorisation for the operations RLS cannot scope.
//
// The relay stores only ciphertext and the app's identity is a device key that
// never reaches auth.uid(), so row-level security cannot tell an admin from an
// attacker. This function verifies an Ed25519 signature from the caller's
// device key and enforces:
//   - add-admin: grow the group_admins set (self-signed root, then additions
//     signed by an existing admin).
//   - delete-envelope: the message author or a group admin may delete.
//   - delete-listing / edit-listing: only a group admin may change the public
//     directory row.
//
// Writes use the service role, so clients hold no direct delete or update
// rights once the RLS policies are tightened. It never reads message content;
// it only checks public keys. Deployed via the Supabase Management API as part
// of the coordinated release, not before the app that signs these requests.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.16.0";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const encoder = new TextEncoder();
const MAX_SKEW_SECONDS = 300;

function fromBase64(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

// Verifies an Ed25519 signature over [message]. Malformed key or signature
// bytes raise from Web Crypto; a deny (false) is the correct, fail-closed
// recovery, so a hostile request cannot pass by sending garbage.
async function verify(
  publicKeyB64: string,
  signatureB64: string,
  message: string,
): Promise<boolean> {
  try {
    const key = await crypto.subtle.importKey(
      "raw",
      fromBase64(publicKeyB64),
      { name: "Ed25519" },
      false,
      ["verify"],
    );
    return await crypto.subtle.verify(
      "Ed25519",
      key,
      fromBase64(signatureB64),
      encoder.encode(message),
    );
  } catch (_error) {
    return false;
  }
}

function fresh(ts: unknown): boolean {
  if (typeof ts !== "number") return false;
  const now = Math.floor(Date.now() / 1000);
  return Math.abs(now - ts) <= MAX_SKEW_SECONDS;
}

async function adminsFor(groupId: string): Promise<Set<string>> {
  const { data, error } = await admin
    .from("group_admins")
    .select("admin_pubkey")
    .eq("group_id", groupId);
  if (error) throw error;
  return new Set((data ?? []).map((r) => r.admin_pubkey as string));
}

// group_id|admin_pubkey, matching AdminStatement.signedBytes on the client.
async function addAdmin(body: Record<string, unknown>): Promise<Response> {
  const s = body.statement as Record<string, string> | undefined;
  if (!s) return json(400, { error: "missing statement" });
  const { group_id, admin_pubkey, added_by, sig } = s;
  if (!group_id || !admin_pubkey || !added_by || !sig) {
    return json(400, { error: "incomplete statement" });
  }
  if (!(await verify(added_by, sig, `${group_id}|${admin_pubkey}`))) {
    return json(403, { error: "signature does not verify" });
  }

  const admins = await adminsFor(group_id);
  if (admins.size === 0) {
    if (added_by !== admin_pubkey) {
      return json(403, { error: "first admin must be a self-signed root" });
    }
  } else if (!admins.has(added_by)) {
    return json(403, { error: "author is not an admin" });
  }

  const { error } = await admin.from("group_admins").upsert({
    group_id,
    admin_pubkey,
    added_by,
    sig,
  });
  if (error) return json(500, { error: error.message });
  return json(200, { ok: true });
}

// delete-envelope|group_id|message_id|ts
async function deleteEnvelope(
  body: Record<string, unknown>,
): Promise<Response> {
  const groupId = body.group_id as string;
  const messageId = body.message_id as string;
  const requester = body.requester_pubkey as string;
  const ts = body.ts;
  const sig = body.sig as string;
  if (!groupId || !messageId || !requester || !sig) {
    return json(400, { error: "incomplete request" });
  }
  if (!fresh(ts)) return json(403, { error: "stale request" });
  const message = `delete-envelope|${groupId}|${messageId}|${ts}`;
  if (!(await verify(requester, sig, message))) {
    return json(403, { error: "signature does not verify" });
  }

  const { data: row, error: readError } = await admin
    .from("envelopes")
    .select("sender_pubkey")
    .eq("group_id", groupId)
    .eq("message_id", messageId)
    .maybeSingle();
  if (readError) return json(500, { error: readError.message });
  if (!row) return json(200, { ok: true }); // already gone

  const admins = await adminsFor(groupId);
  const authorised = admins.has(requester) || row.sender_pubkey === requester;
  if (!authorised) return json(403, { error: "not author or admin" });

  const { error } = await admin
    .from("envelopes")
    .delete()
    .eq("group_id", groupId)
    .eq("message_id", messageId);
  if (error) return json(500, { error: error.message });
  return json(200, { ok: true });
}

// purge-group|group_id|ts, an admin deleting every envelope of a group.
async function purgeGroup(body: Record<string, unknown>): Promise<Response> {
  const groupId = body.group_id as string;
  const requester = body.requester_pubkey as string;
  const ts = body.ts;
  const sig = body.sig as string;
  if (!groupId || !requester || !sig) {
    return json(400, { error: "incomplete request" });
  }
  if (!fresh(ts)) return json(403, { error: "stale request" });
  if (!(await verify(requester, sig, `purge-group|${groupId}|${ts}`))) {
    return json(403, { error: "signature does not verify" });
  }
  if (!(await adminsFor(groupId)).has(requester)) {
    return json(403, { error: "not an admin" });
  }
  const { error } = await admin
    .from("envelopes")
    .delete()
    .eq("group_id", groupId);
  if (error) return json(500, { error: error.message });
  // Clear the admin set too, so a deleted group leaves nothing behind.
  await admin.from("group_admins").delete().eq("group_id", groupId);
  return json(200, { ok: true });
}

// delete-listing|group_id|ts
async function deleteListing(
  body: Record<string, unknown>,
): Promise<Response> {
  const groupId = body.group_id as string;
  const requester = body.requester_pubkey as string;
  const ts = body.ts;
  const sig = body.sig as string;
  if (!groupId || !requester || !sig) {
    return json(400, { error: "incomplete request" });
  }
  if (!fresh(ts)) return json(403, { error: "stale request" });
  if (!(await verify(requester, sig, `delete-listing|${groupId}|${ts}`))) {
    return json(403, { error: "signature does not verify" });
  }
  if (!(await adminsFor(groupId)).has(requester)) {
    return json(403, { error: "not an admin" });
  }

  await admin.from("public_groups").delete().eq("group_id", groupId);
  await admin.from("join_requests").delete().eq("group_id", groupId);
  return json(200, { ok: true });
}

// edit-listing|group_id|ts|<listing json>, binding the exact row content.
async function editListing(body: Record<string, unknown>): Promise<Response> {
  const groupId = body.group_id as string;
  const requester = body.requester_pubkey as string;
  const listing = body.listing as string;
  const ts = body.ts;
  const sig = body.sig as string;
  if (!groupId || !requester || !listing || !sig) {
    return json(400, { error: "incomplete request" });
  }
  if (!fresh(ts)) return json(403, { error: "stale request" });
  const message = `edit-listing|${groupId}|${ts}|${listing}`;
  if (!(await verify(requester, sig, message))) {
    return json(403, { error: "signature does not verify" });
  }
  if (!(await adminsFor(groupId)).has(requester)) {
    return json(403, { error: "not an admin" });
  }

  const row = JSON.parse(listing) as Record<string, unknown>;
  if (row.group_id !== groupId) {
    return json(400, { error: "listing group_id mismatch" });
  }
  // A global listing must carry no location. Enforce it here so the guarantee
  // holds even against a client that sends one; a local listing needs a centre.
  if (row.scope === "global") {
    row.center_lat = null;
    row.center_lng = null;
  } else if (row.center_lat == null || row.center_lng == null) {
    return json(400, { error: "local listing needs a centre" });
  }
  const { error } = await admin.from("public_groups").upsert(row);
  if (error) return json(500, { error: error.message });
  return json(200, { ok: true });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method not allowed" });
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_error) {
    return json(400, { error: "invalid json" });
  }
  switch (body.action) {
    case "add-admin":
      return await addAdmin(body);
    case "delete-envelope":
      return await deleteEnvelope(body);
    case "purge-group":
      return await purgeGroup(body);
    case "delete-listing":
      return await deleteListing(body);
    case "edit-listing":
      return await editListing(body);
    default:
      return json(400, { error: "unknown action" });
  }
});
