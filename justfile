# Hulaki task entrypoint. Requires the Flutter SDK on PATH
# (export PATH="$HOME/flutter/bin:$PATH").

# List available recipes.
default:
    @just --list

# Install dependencies.
setup:
    flutter pub get

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

# Run the app on the connected device or emulator.
run:
    flutter run

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
