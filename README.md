# Poultry Pro

Poultry Pro is a Flutter app for poultry farmers to manage flock records,
daily production, health events, stock, and farm finances.

## Features

- Flock setup and flock-level tracking
- Daily production, mortality, and feed records
- Stock and inventory records
- Health event tracking
- Farm finance summaries
- Local-first data storage with optional Supabase integration hooks

## Development

Install Flutter, then run:

```sh
flutter pub get
flutter analyze
flutter test
```

## Release Build

Android release signing uses `android/key.properties`, which is intentionally
ignored by git. For Google Play, build an app bundle:

```sh
flutter build appbundle --release
```

For sideload testing, build an APK:

```sh
flutter build apk --release
```
