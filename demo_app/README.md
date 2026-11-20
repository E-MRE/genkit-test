# Sipariş Asistanı (Flutter Demo)

Minimal Flutter demo app (Web & macOS) that calls the local Genkit Dart HTTP server (`POST /assistantFlow` by default, with an app-bar toggle to switch to the legacy `POST /refundFlow` card).

- No API key lives in this app; it only talks to the local server.
- Default server URL: `http://localhost:8080/refundFlow` (override with `--dart-define=API_URL=...`; the app resolves both `/assistantFlow` and `/refundFlow` from it).
- Client timeout: `120 s` to accommodate occasional slow Gemini free-tier responses.

## Prerequisites

- Flutter `3.41.9` (Dart `3.11.5`, compatible with `sdk: ^3.10.0`)
- `GEMINI_API_KEY` configured in the repository root (`.env` or environment variable)

## 1. Start the backend server (from the repository root)

```bash
dart run bin/server.dart
```

This serves `POST /assistantFlow`, `POST /refundFlow`, and `GET /health` on port `8080` with localhost CORS headers.

## 2. Run the Flutter demo

Install dependencies once inside `demo_app/`:

```bash
cd demo_app
flutter pub get
```

Run on Chrome (web):

```bash
flutter run -d chrome
```

Run on macOS:

```bash
flutter run -d macos
```

To point at a different server URL or port:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:9090
```

## 3. Run the Maestro flow on web

Start the backend server from the repo root:

```bash
dart run bin/server.dart
```

Serve the Flutter web app on port `5050` (matching `url: http://localhost:5050` in `maestro/demo_flow.yaml`):

```bash
cd demo_app
flutter run -d chrome --web-port=5050
```

In a third terminal, run the Maestro flow (it taps the 3 example chips in order, waits up to 120 s for each card via Semantics labels, and saves 3 screenshots):

```bash
maestro test demo_app/maestro/demo_flow.yaml
```

## Analyze & test

```bash
cd demo_app
flutter analyze
flutter test
```
