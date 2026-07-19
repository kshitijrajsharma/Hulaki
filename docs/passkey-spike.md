# Passkey recovery spike (Phase A)

A throwaway spike to de-risk the passkey path before building Phase C. It leans
on two things that are not on every device: WebAuthn PRF (to derive a local key
encryption key) and Supabase's passkey beta (to give a device a durable account).
Run it on real hardware, record the findings at the bottom, then decide.

Run everything on a scratch branch. Nothing here ships.

## Why this exists

The recovery key path (Phase B) already works end to end and closes the
production blocker on its own. The passkey path is the nicer everyday experience:
the user unlocks recovery with Face ID or a password manager instead of pasting a
52-character key. It is worth building only if PRF and the Supabase beta both
hold up on the platforms we target. If either fails on iOS or Android, we stay
recovery-key primary and drop the passkey layer.

## Targets

Run each probe on all four combinations, because PRF and account durability vary
by both OS and authenticator:

- iOS with Apple Passwords (iCloud Keychain)
- iOS with Bitwarden
- Android with Google Password Manager
- Android with Bitwarden

## Prerequisites

- A physical iPhone and Android phone. PRF and platform passkeys do not work in
  the iOS Simulator or a bare Android emulator without Play Services.
- Bitwarden installed and set as a passkey provider on each phone.
- In the Supabase dashboard: Authentication > Configuration > Passkeys enabled
  for the Fieldchat project (beta toggle).
- `supabase_flutter` >= 2.15.0 (the app is on 2.15.4, which satisfies this).
- `flutter pub add flutter_passkey_service` on the scratch branch.

## Probe 1: PRF derives a stable key (the load-bearing one)

Goal: confirm the same passkey returns the same PRF-derived KEK after an app
reinstall and on a second device, so it can wrap the recovery data key.

1. Register a passkey with PRF enabled (`enablePrf: true` in the registration
   options).
2. Authenticate with a fixed application salt and read the derived key from
   `response.clientExtensionResults?.prf?.results?`. It comes back base64url;
   decode to bytes before any AES-GCM use.
3. Record the KEK bytes (hash them, do not paste raw key material into the notes).
4. Delete and reinstall the app. Authenticate again with the same salt. Confirm
   the KEK is identical.
5. On a second phone signed into the same passkey provider, authenticate with the
   same salt. Confirm the KEK is identical there too.

Pass: the KEK is byte-identical across reinstall and across devices on every
target. Fail on any target: note which OS plus authenticator, and whether PRF was
absent (no `prf` in the results) or present but unstable.

Known risk: not every OS or authenticator supports PRF. Always check the result
is present before using it, and keep the recovery-key path as the fallback.

## Probe 2: Supabase passkey gives a durable account

Goal: confirm a passkey yields a stable `auth.uid()` that a second device reaches,
so the backup row can later be scoped to it.

The app signs in anonymously today. The beta documents that registering a passkey
"requires an existing, confirmed, non-anonymous user." So the first question is
the upgrade path, and it is probe 2a because everything else depends on it.

### Probe 2a: can the anonymous session hold a passkey

1. From the current anonymous session, call `registerPasskey` (the extension on
   `GoTrueClient`).
2. Record what happens. Either it works in place (the anonymous user is promoted),
   or it rejects and the user must first be converted to a non-anonymous user
   (for example by adding an email or another factor).
3. If it rejects, find the smallest conversion that satisfies "confirmed,
   non-anonymous" without adding SMS or a mandatory email step, and record it.

This answer decides the Phase C onboarding UX. Do not skip it.

### Probe 2b: durability across devices

1. Register a passkey, note `supabase.auth.currentUser?.id`.
2. Reinstall, sign in with the passkey, confirm the same id.
3. On a second device, sign in with the passkey, confirm the same id.

Pass: the same `auth.uid()` on reinstall and on the second device.

## Probe 3: one prompt or two

Goal: decide whether one passkey credential can serve both the Supabase sign-in
and the PRF derivation in a single user prompt, or whether two separate WebAuthn
ceremonies are needed.

1. Attempt a flow that authenticates to Supabase and derives the PRF KEK.
2. Count the biometric or provider prompts the user sees.

Record: one ceremony or two. Two prompts is acceptable but shapes the UX copy
("unlock", then "confirm"), so it must be known before building.

## Decision gate

- PRF stable on all targets and Supabase durable: build Phase C as planned, passkey
  primary with the recovery key as fallback.
- PRF stable only on some targets: passkey where it works, recovery key elsewhere,
  chosen per device at runtime from the PRF availability check.
- PRF or the beta unworkable: stay recovery-key primary, shelve the passkey layer,
  revisit when platform support improves.

## Findings (fill in)

| Probe | iOS + Apple | iOS + Bitwarden | Android + Google | Android + Bitwarden |
| --- | --- | --- | --- | --- |
| 1 PRF stable | | | | |
| 2a anon upgrade | | | | |
| 2b uid durable | | | | |
| 3 prompts | | | | |

Decision:

## Sources

- flutter_passkey_service PRF (KEK) guide:
  https://pub.dev/packages/flutter_passkey_service
- Supabase passkeys (beta): https://supabase.com/docs/guides/auth/passkeys
- Passkeys for Supabase Auth (beta) changelog:
  https://supabase.com/changelog/46458-passkeys-for-supabase-auth-beta
