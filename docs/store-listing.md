# Store listing

Copy for Google Play and the Apple App Store, plus the privacy disclosures each
store asks for. Fill the bracketed placeholders before submitting.

## Names

- App name: FieldChat
- Subtitle (Apple, 30 chars): Map the field while you chat
- Short description (Play, 80 chars): Offline-first, encrypted group chat where
  every message is a mapped point.

## Full description

FieldChat turns group chat into field data. Every message you send is a
geotagged observation that lands on a shared map, so your team collects clean,
located data while simply talking.

Built for field mapping:
- Offline-first. Capture points and chat with no signal; it syncs when you are
  back online.
- One-tap hot-keys tag each observation and colour its pin on the map.
- Every point carries GPS accuracy, and optionally altitude and heading.
- Draw a task area, cache its map for offline use, and export to GeoJSON or GPX.
- End-to-end encrypted. Your content is unreadable to the server.
- No phone number and no email. Pick a username and start.

Free and open source under AGPL-3.0.

## Category and rating

- Category: Productivity (or Maps & Navigation)
- Content rating: Everyone / 4+
- Contains ads: No
- In-app purchases: No

## Keywords (Apple, 100 chars)

field mapping, gis, survey, gps, offline, geojson, gpx, osm, data collection,
encrypted chat

## Assets to provide

- App icon (already in assets/icon).
- Screenshots: onboarding, chats, chat thread, map with pins, point detail,
  group members. Capture on a device or emulator.
- Feature graphic (Play, 1024x500).

## Play Data Safety answers

- Data collected: Location (approximate and precise), Photos, Messages, User ids
  (the chosen username and device id).
- Data shared with third parties: None for advertising or analytics. Encrypted
  content is relayed through Supabase (processor) and cannot be read by it.
- Data encrypted in transit: Yes.
- Data encrypted at rest on the server: Yes, end-to-end; the server holds only
  ciphertext.
- Users can request deletion: Yes, by deleting content and uninstalling.

## Apple privacy nutrition labels

- Data used to track you: None.
- Data linked to you: None (identity is a random device id and a chosen handle).
- Data not linked to you: Coarse and precise location, photos, and user content,
  all end-to-end encrypted.

## Support and policy URLs

- Privacy policy: host docs/privacy-policy.md on GitHub Pages, for example
  https://kshitijrajsharma.github.io/fieldchat/privacy-policy
- Support URL: github.com/kshitijrajsharma
