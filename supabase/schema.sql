-- Hulaki backend schema. Run once in the Supabase SQL editor.
-- The relay only ever stores ciphertext; content is unreadable without the
-- group key, which is shared out of band through the invite link.

-- sender_pubkey is the author's Ed25519 signing key, stored in the clear so the
-- group-guard Edge Function can authorise an author deleting their own message
-- without a group key. It is public and adds no exposure beyond sender_id.
create table if not exists public.envelopes (
  seq           bigint generated always as identity primary key,
  group_id      text        not null,
  message_id    text        not null,
  sender_id     text        not null,
  sender_pubkey text        not null,
  ciphertext    text        not null,
  created_at    timestamptz not null default now(),
  unique (group_id, message_id)
);

create index if not exists envelopes_group_seq_idx
  on public.envelopes (group_id, seq);

alter table public.envelopes enable row level security;

-- MVP posture: any signed-in device (anonymous auth) may read and append.
-- Access is not scoped per group at the database layer; confidentiality comes
-- from end-to-end encryption. Harden later with a membership check.
create policy envelopes_select on public.envelopes
  for select to authenticated using (true);

create policy envelopes_insert on public.envelopes
  for insert to authenticated with check (true);

-- No client delete policy: deletes go through the group-guard Edge Function,
-- which verifies the caller is the message author or a group admin and deletes
-- with the service role. A direct client delete matches no rows.

-- Realtime fan-out for subscribe().
alter publication supabase_realtime add table public.envelopes;

-- Encrypted media blobs, keyed by id.
insert into storage.buckets (id, name, public)
  values ('media', 'media', false)
  on conflict (id) do nothing;

create policy media_read on storage.objects
  for select to authenticated using (bucket_id = 'media');

create policy media_write on storage.objects
  for insert to authenticated with check (bucket_id = 'media');

-- Delete lets a client drop a blob when its message is deleted or its group is
-- purged, so removed media does not linger. Same open MVP posture as the other
-- policies: any signed-in device may delete, and confidentiality still rests on
-- end-to-end encryption, not on the store.
create policy media_delete on storage.objects
  for delete to authenticated using (bucket_id = 'media');

-- Encrypted web snapshots: one small JSON plus one object per photo under
-- <id>/…. Public read is safe because every object is ciphertext and the
-- per-link key rides the URL fragment. Insert publishes a link, update
-- refreshes it in place (same link and key), delete revokes it. Drops precede
-- the creates so this block can be re-applied over the existing bucket.
insert into storage.buckets (id, name, public)
  values ('snapshots', 'snapshots', true)
  on conflict (id) do nothing;

drop policy if exists "snapshots read" on storage.objects;
create policy "snapshots read" on storage.objects
  for select to public using (bucket_id = 'snapshots');

drop policy if exists "snapshots insert" on storage.objects;
create policy "snapshots insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'snapshots');

drop policy if exists "snapshots update" on storage.objects;
create policy "snapshots update" on storage.objects
  for update to authenticated using (bucket_id = 'snapshots')
  with check (bucket_id = 'snapshots');

drop policy if exists "snapshots delete" on storage.objects;
create policy "snapshots delete" on storage.objects
  for delete to authenticated using (bucket_id = 'snapshots');

-- The public directory: groups their admins chose to make discoverable. This
-- holds plaintext metadata plus the group key, so anyone nearby can find and
-- join. Private groups never appear here. The geo index keeps proximity search
-- instant.
-- scope is 'local' (listed by proximity, has a center) or 'global' (listed in
-- the worldwide feed, no center). center_lat/lng are null for global groups, so
-- a global listing carries no location at all.
create table if not exists public.public_groups (
  group_id     text primary key,
  name         text not null,
  description  text,
  scope        text not null default 'local',
  center_lat   double precision,
  center_lng   double precision,
  enc_key      text not null,
  photo        text,
  tags         jsonb not null default '[]'::jsonb,
  aoi          text,
  updated_at   timestamptz not null default now()
);

-- Preview columns, applied idempotently so an existing directory gains them
-- without a rebuild. photo is a base64 JPEG icon; tags is the quick-tag list;
-- aoi is the drawn area as GeoJSON, shown as a minimap before joining.
alter table public.public_groups add column if not exists photo text;
alter table public.public_groups
  add column if not exists tags jsonb not null default '[]'::jsonb;
alter table public.public_groups add column if not exists aoi text;
alter table public.public_groups
  add column if not exists join_approval boolean not null default false;
alter table public.public_groups
  add column if not exists scope text not null default 'local';
alter table public.public_groups alter column center_lat drop not null;
alter table public.public_groups alter column center_lng drop not null;

create index if not exists public_groups_geo_idx
  on public.public_groups (center_lat, center_lng);

-- The global feed ranks by recency; activity and member count refine it in the
-- query. Partial index keeps it to just the global rows.
create index if not exists public_groups_global_idx
  on public.public_groups (updated_at desc) where scope = 'global';

alter table public.public_groups enable row level security;

create policy public_groups_select on public.public_groups
  for select to authenticated using (true);

-- No client write policy: publishing or removing a listing goes through the
-- group-guard Edge Function, which verifies the caller is a group admin and
-- writes with the service role. A direct client write is rejected.

-- Requests to join an approval-gated public group. The requester posts their
-- public keys; an admin approves by writing back the group key sealed to the
-- requester's X25519 key, so the key is never exposed to the server in the
-- clear. MVP posture matches the rest: any signed-in device may read and write.
create table if not exists public.join_requests (
  id             text primary key,
  group_id       text not null,
  requester_id   text not null,
  requester_name text,
  signing_key    text not null,
  agreement_key  text not null,
  sealed_key     text,
  created_at     timestamptz not null default now(),
  unique (group_id, requester_id)
);

create index if not exists join_requests_group_idx
  on public.join_requests (group_id);

alter table public.join_requests enable row level security;

create policy join_requests_select on public.join_requests
  for select to authenticated using (true);

create policy join_requests_write on public.join_requests
  for all to authenticated using (true) with check (true);

-- The server-readable admin set per group, holding only public Ed25519 keys.
-- It mirrors the verified admin set the client already derives, so an Edge
-- Function can authorize a delete or a listing edit without a group key and
-- without reading any content. added_by and sig record who authorized each row
-- (the creator self-signs the root; an existing admin signs every addition) so
-- the guard can verify the chain. Rows hold no secrets: a public key is public.
create table if not exists public.group_admins (
  group_id     text not null,
  admin_pubkey text not null,
  added_by     text not null,
  sig          text not null,
  created_at   timestamptz not null default now(),
  primary key (group_id, admin_pubkey)
);

alter table public.group_admins enable row level security;

-- Readable by any signed-in device (public keys only). Writes are closed to
-- clients: the group-guard Edge Function verifies the signature chain and
-- writes with the service role, so a member cannot enrol itself as admin.
create policy group_admins_select on public.group_admins
  for select to authenticated using (true);

-- Encrypted account backups, one row per recovery key. The row holds only
-- ciphertext plus the data key wrapped to the recovery key, so the server never
-- sees the identity seeds, the group keys, or the recovery key. lookup_id is
-- derived from the recovery key (unguessable) so a fresh install fetches its own
-- row without an account.
create table if not exists public.identity_backups (
  lookup_id       text primary key,
  ciphertext      text not null,
  key_wrapped_key text not null,
  updated_at      timestamptz not null default now()
);

-- RLS on with no client policy: clients can neither read nor write this table.
-- All access goes through the group-guard function (service role), which acts
-- only on the exact lookup id presented, so the table cannot be enumerated or
-- bulk-deleted. Confidentiality still rests on the end-to-end encryption; this
-- adds integrity and availability by removing direct client access.
alter table public.identity_backups enable row level security;

drop policy if exists identity_backups_select on public.identity_backups;
drop policy if exists identity_backups_write on public.identity_backups;
