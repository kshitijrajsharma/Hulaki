# FieldChat task entrypoint. Requires the Flutter SDK on PATH
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

# Run the test suite (excludes platform-sensitive screenshot goldens).
test:
    flutter test --exclude-tags golden

# Regenerate the screenshot previews in test/goldens.
screenshots:
    flutter test --tags golden --update-goldens test/screenshots_test.dart

# Regenerate launcher icons from assets/icon.
icons:
    dart run flutter_launcher_icons

# Run the app on the connected device or emulator.
run:
    flutter run

# Release build, Android.
build-android:
    flutter build apk --release

# Release build, iOS (macOS only).
build-ios:
    flutter build ipa --release

# Report toolchain status.
doctor:
    flutter doctor -v
