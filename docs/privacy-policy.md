# FieldChat privacy policy

Last updated: 2026-07-05

FieldChat is a field mapping chat app. This policy explains what the app
collects, how it is used, and the choices you have. Plain language, no jargon.

## The short version

- Your messages, photos, and locations are end-to-end encrypted. The server
  stores only ciphertext and cannot read your content.
- There is no phone number, no email, and no password. You pick a username.
- No advertising, no analytics trackers, no selling of data.

## What the app collects

- **Username**: a handle you choose. It is shown to your teammates in a group.
- **Device identifier**: a random id created on your device to identify you
  within a group. It is not linked to your real identity.
- **Location**: each observation you send is tagged with GPS coordinates, and
  optionally altitude and heading. This is the core purpose of the app.
- **Photos**: only the photos you choose to attach to an observation.
- **Messages**: the text and tags you send.

## How your data is stored

- **On your device**: everything is saved locally so the app works offline.
- **On the server**: to sync between teammates, encrypted copies of messages
  and photos are relayed through Supabase. The content is encrypted on your
  device before it leaves, so the server only ever holds unreadable ciphertext.
  The key that decrypts a group is shared only through the group invite link,
  never with the server.

## Permissions the app requests

- **Location**: to tag observations and show you on the map.
- **Camera and photos**: to attach photos to observations, when you choose to.
- **Internet**: to sync with your team and load map tiles.

## Third parties

- **Supabase** hosts the encrypted relay and storage. It processes only
  ciphertext. See supabase.com/privacy.
- **CARTO** serves the map tiles. Like any web request, loading tiles sends
  your IP address to CARTO. See carto.com/privacy.

## Data retention and deletion

- Your local breadcrumb trail is kept for 24 hours, then purged.
- You can delete observations and leave groups at any time.
- Uninstalling the app removes all local data from your device.

## Children

FieldChat is not directed at children under 13.

## Changes

If this policy changes, the date above is updated.

## Contact

Developer: Kshitij Raj Sharma. Questions: open an issue at
github.com/kshitijrajsharma, or email <add-your-contact-email>.
