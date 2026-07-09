# Store listing

Copy for Google Play, plus the privacy answers the store asks for. Focused on
the Play submission. Apple fields are kept at the end for later.

## Names

- App name (max 30): FieldChat
- Short description (Play, max 80): Offline-first, encrypted group chat where
  every message is a mapped point.

## Full description (Play, max 4000)

FieldChat is a field mapping app. Every chat message is a point on the map, so
a group can record what they see in the field and see it in one place.

It is offline first. You can drop points and send messages with no signal, and
they sync when you are back online. You can save a map area for offline use.

It is privacy first. Messages and photos are end to end encrypted on your
device. The server stores only encrypted data and cannot read your content. The
group key is shared through the group invite link, never sent to the server.

No account is needed. There is no sign up with email or phone, no ads, no
analytics, and no tracking.

What you can do:
- Create a group and invite people with a link.
- Drop points on the map and tag them with quick tags.
- Attach a photo to a point.
- See every group member's points on one map.
- Record a track while you move.
- Set a mapping area for the group.
- Find public groups near you and ask to join.
- Export points as GeoJSON or GPX.

FieldChat is a personal, non-commercial project, open source under AGPL-3.0. It
is provided as is, without warranty. Do not rely on it for navigation,
emergency, or safety of life.

## Category and rating

- Category: Maps & Navigation (or Productivity)
- Content rating: Everyone
- Contains ads: No
- In-app purchases: No

## Play Data safety answers

- Data collected: Location (approximate and precise), Photos, Messages, and a
  chosen username plus a random device id.
- Purpose: App functionality only.
- Shared with third parties: Not for advertising or analytics. Encrypted content
  is relayed and stored through Supabase (a processor) and cannot be read by it.
- Location can be readable for public groups: if a user makes a group publicly
  discoverable, the group's name and approximate location are stored readably in
  the public directory so others can find it.
- Encrypted in transit: Yes.
- Stored encrypted on the server: Yes, end to end. The server holds only
  ciphertext.
- Users can request deletion: Yes, by contacting krschap@proton.me.

## URLs

- Privacy policy: https://kshitijrajsharma.github.io/FieldChat/privacy-policy.html
- Terms of use: https://kshitijrajsharma.github.io/FieldChat/terms.html
- Support email: krschap@proton.me
- Support site: https://github.com/kshitijrajsharma/FieldChat

## Assets to provide

- App icon (in assets/icon), and a 512x512 PNG for the listing.
- Feature graphic, 1024x500.
- At least two phone screenshots (capture from a device or the emulator).

## Apple fields (for later)

- Subtitle (max 30): Map the field while you chat
- Keywords (max 100): field mapping, gis, survey, gps, offline, geojson, gpx,
  osm, data collection, encrypted chat
- App privacy: no tracking; location, photos, and messages are end to end
  encrypted and not used to track you.
