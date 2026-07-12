# Store listing

## Names

- App name (max 30): Hulaki
- Short description (Play, max 80): An offline-first, privacy-focused field
  mapping app.

## Full description (Play, max 4000)

Hulaki is a field mapping app. Offline and privacy focused, a group can record what they see in the field and see it in one place.

It is offline first. You can drop points and send messages with no signal, and
they sync when you are back online. You can save a map area for offline use.

It is privacy first. Messages and photos are end to end encrypted on your
device. The server stores only encrypted data and cannot read your content. The
group key is shared through the group invite link, never sent to the server.

What you can do:
- Create a group and invite people with a link.
- Drop points on the map and tag them with quick tags.
- Attach a photo to a point.
- See every group member's points on one map.
- Record a track while you move.
- Set a mapping area for the group.
- Find public groups near you and ask to join.
- Export points as GeoJSON or GPX.

Hulaki is a personal, non-commercial project, open source under AGPL-3.0. It is
provided as is, without warranty.

## Category and rating

- Category: Maps & Navigation
- Content rating: Everyone
- Contains ads: No
- In-app purchases: No

## Data safety

- Data collected: location (approximate and precise), photos, messages, and a
  chosen username plus a random device id.
- Purpose: app functionality only.
- Shared with third parties: not for advertising or analytics. Encrypted content
  is relayed and stored through Supabase, a processor that cannot read it.
- Public groups: when a group is made publicly discoverable, its name and
  approximate location are stored readably in the directory so others can find
  it.
- Encrypted in transit: yes.
- Stored encrypted on the server: yes, end to end. The server holds only
  ciphertext.
- Deletion requests: yes, by contacting krschap@proton.me.

## URLs

- Privacy policy: https://kshitijrajsharma.github.io/Hulaki/privacy-policy.html
- Terms of use: https://kshitijrajsharma.github.io/Hulaki/terms.html
- Child safety standards:
  https://kshitijrajsharma.github.io/Hulaki/child-safety.html
- Support email: krschap@proton.me
- Support site: https://github.com/kshitijrajsharma/Hulaki

## Assets

- App icon 512x512: `pages/icon-512.png`
- Feature graphic 1024x500: `pages/feature-graphic.png`
- Phone screenshots: `pages/shots/`

Regenerate the icon and the feature graphic with `python3 tool/render_brand.py`.

## App Store

- Subtitle (max 30): Map the field 
- Keywords (max 100): field mapping, gis, survey, gps, offline, geojson, gpx,
  osm, data collection, encrypted chat
- Privacy: no tracking. Location, photos, and messages are end to end encrypted
  and are not used to track you.
