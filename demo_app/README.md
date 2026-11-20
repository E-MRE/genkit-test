# İade Asistanı (Flutter Demo)

Minimal single-screen Flutter demo app (Web & macOS) that calls the local Genkit Dart `refundFlow` HTTP server.

- No API key lives in this app; it only sends requests to the local server (`POST /refundFlow`).
- Default server URL: `http://localhost:8080/refundFlow` (override with `--dart-define=API_URL=...`).
- Request timeout: `120 s` to accommodate occasional slow Gemini free-tier responses.

## Prerequisites

- Flutter `3.41.9` (Dart `3.11.5`, compatible with `sdk: ^3.10.0`)
- `GEMINI_API_KEY` configured in the repository root (`.env` or environment variable)

## 1. Start the backend server (from the repository root)

```bash
dart run bin/server.dart
```

## 2. Run the Flutter demo

Install dependencies once inside `demo_app/`:

```bash
cd demo_app
flutter pub get
```

Run on Web (Chrome):

```bash
flutter run -d chrome
```

Run on macOS:

```bash
flutter run -d macos
```

To point at a different server URL or port:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:9090/refundFlow
```

## Analyze & test

```bash
cd demo_app
flutter analyze
flutter test
```
