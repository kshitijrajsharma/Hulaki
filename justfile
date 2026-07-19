# Hulaki task entrypoint. Requires the Flutter SDK on PATH
# (export PATH="$HOME/flutter/bin:$PATH").

# List available recipes.
default:
    @just --list

# Install dependencies and activate the git hooks.
setup:
    flutter pub get
    git config core.hooksPath tool/hooks

# Format check + static analysis. Must pass with zero issues.
lint:
    dart format --set-exit-if-changed .
    flutter analyze

# Apply formatting and safe automated fixes.
fix:
    dart fix --apply
    dart format .

# Run the test suite (excludes screenshot goldens and the slow load tests).
test:
    flutter test --exclude-tags golden,load

# Regenerate the screenshot previews in test/goldens.
screenshots:
    flutter test --tags golden --update-goldens test/screenshots_test.dart

# Run the load tests (slow, allocates hundreds of MB).
load:
    flutter test --tags load

# Check every language file against the English template.
translations:
    dart run tool/verify_translations.dart

# Regenerate launcher icons from assets/icon.
icons:
    dart run flutter_launcher_icons

# Boot an Android emulator (default fieldchat) and wait until it is ready.
emulator avd="fieldchat":
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="$HOME/Android/Sdk/emulator:$HOME/Android/Sdk/platform-tools:$PATH"
    if adb devices | grep -q 'emulator-'; then
        echo "Emulator already running:"; adb devices; exit 0
    fi
    log="/tmp/hulaki-emulator-{{avd}}"
    echo "Booting {{avd}} (logs: $log.out / $log.err)"
    nohup emulator -avd {{avd}} -no-boot-anim > "$log.out" 2> "$log.err" &
    adb wait-for-device
    printf 'Waiting for full boot'
    until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do
        printf '.'; sleep 2
    done
    echo; echo "{{avd}} is ready:"; adb devices

# Run the app on the connected device or emulator, with Supabase config from .env.
run:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f .env ] && source .env
    flutter run \
        ${SUPABASE_URL:+--dart-define=SUPABASE_URL="$SUPABASE_URL"} \
        ${SUPABASE_ANON_KEY:+--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"}

# Boot the emulator (if needed) then run the app.
dev avd="fieldchat": (emulator avd)
    @just run

# Bump the version from conventional commits: updates pubspec and CHANGELOG,
# then commits and tags. Runs the whole release chore in one step.
bump:
    cz bump

# The Play versionCode, derived from the commit count so every upload is higher
# than the last without editing pubspec by hand.
build-number := `git rev-list --count HEAD`

build-android:
    flutter build apk --release --build-number={{build-number}}

# Release App Bundle for Play.
bundle:
    flutter build appbundle --release --build-number={{build-number}}

# Release build, iOS (macOS only).
build-ios:
    flutter build ipa --release --build-number={{build-number}}

# Report toolchain status.
doctor:
    flutter doctor -v
