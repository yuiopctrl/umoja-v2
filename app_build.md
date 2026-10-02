# kutengeneza release ya app ( installabel)
flutter clean
flutter pub get

flutter build apk --release \
  --dart-define-from-file=env.local.json

# apk inapatikana
build/app/outputs/flutter-apk/app-release.apk

<!-- Kwa USB: -->
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Development
<!-- Kwa development Android: -->
flutter run \
  --dart-define-from-file=env.local.json

  <!-- Kwa Linux: -->
  flutter run -d linux \
  --dart-define-from-file=env.local.json

  <!-- Na Web: -->
  flutter run -d chrome \
  --dart-define-from-file=env.local.json