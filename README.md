# FieldChat

Collect field data while chatting. FieldChat is a group chat where every
message is a geotagged field observation: send a photo, voice note, or a
one-tap label, and it drops a pin on a shared map,
offline first.

a Flutter codebase that ships to iOS and Android.

## Status

Milestone M0: project scaffold and design system. The app boots into a
three-tab shell (Chats, Map, Me) rendered with the FieldChat design system.
Backend (Supabase), end-to-end encryption, the live map, and offline tiles
arrive in later milestones.

## Architecture

- **Flutter / Dart**: single codebase, native iOS and Android builds.
- **Local source of truth**: SQLite on the device. Chat and map both render
  from local data; the network is a background courier.
- **Backend**: Supabase (Postgres, Realtime, Storage, phone-OTP Auth). The
  server only ever stores ciphertext.
- **End-to-end encryption**: Signal protocol (SenderKey group messaging).
- **Map**: MapLibre vector tiles with PMTiles cached per group for full
  offline use.
- **Location track**: a local 24-hour breadcrumb drawn as a faint line, then
  purged.

## Design system

Defined in `lib/design`.

- **Palette**: Ink `#15181B`, Paper `#F6F4EE`, Mist `#ECE7DF`, White, and
  Amber `#E0922A` reserved for GPS and signal. Tag colours add purple, red,
  and blue.
- **Type**: Hanken Grotesk for the wordmark and interface, Caveat as a
  handwritten accent. Both bundled for offline use.
- **Mark**: a navigation arrow over three typing dots, drawn as a vector and
  used for the app icon.

## Requirements

- Flutter SDK 3.44.4 (stable) on `PATH`:
  `export PATH="$HOME/flutter/bin:$PATH"`
- Android builds: Android SDK and a JDK.
- iOS builds and App Store signing: macOS with Xcode (a cloud Mac CI runner
  works for release builds).

## Common tasks

The `justfile` is the single entrypoint:

```
just setup          # install dependencies
just lint           # format check + static analysis (zero issues required)
just test           # run the test suite
just icons          # regenerate launcher icons
just run            # run on a connected device or emulator
just build-android  # release APK
just build-ios      # release IPA (macOS only)
just doctor         # toolchain status
```

## Project layout

```
lib/
  app/         app root and the three-tab shell
  design/      colours, spacing, typography, theme, brand mark, widgets
  features/    chats, map, me, onboarding
assets/
  fonts/       Hanken Grotesk, Caveat
  icon/        source app icons
design/         brand sheets and wireframes (reference, not shipped)
```
