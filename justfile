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

build-android:
    flutter build apk --release

# Release App Bundle. 
bundle:
    flutter build appbundle --release

# Release build, iOS (macOS only).
build-ios:
    flutter build ipa --release

# Report toolchain status.
doctor:
    flutter doctor -v
