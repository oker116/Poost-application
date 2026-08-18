# Build and Release

## Development
1. Install Flutter stable.
2. Install Android SDK and accept licenses.
3. Run `flutter pub get`.
4. Run `flutter analyze`.
5. Run `flutter test`.
6. Run `flutter build apk --release`.

## Release
- Sign the APK with a private Android keystore.
- Never commit the keystore/password.
- Build separate debug/release configurations.
- Test on Android devices.
- Verify deep links/OAuth redirect.
- Verify offline behavior and sync retry.
- Verify role isolation.
- Verify Meta token never appears in logs.
