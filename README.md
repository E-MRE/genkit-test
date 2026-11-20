# Genkit Dart Refund Assistant Experiment

Minimal, pure-Dart experiment using the official [Genkit for Dart](https://genkit.dev/docs/dart/) packages (`genkit`, `genkit_google_genai`, `genkit_shelf`, and `schemantic`).

A single Genkit flow (`refundFlow`) parses free-text Turkish customer messages into a structured refund decision, calling a `getOrder(orderNumber)` tool backed by fake in-memory order data before validating items and quantities.

## Prerequisites

- **Dart SDK `>=3.12.0`** (required by `genkit ^1.0.3` and `schemantic ^1.0.0`)
- A Gemini API key from Google AI Studio (`GEMINI_API_KEY`)

## 1. Install

```bash
dart pub get
```

Generated schema code (`lib/refund_assistant.g.dart`) is committed in the repo. If you edit any `@Schema()` classes in `lib/refund_assistant.dart`, regenerate it with:

```bash
dart run build_runner build
```

Configure your API key using either an environment variable or a local `.env` file (ignored by git):

```bash
cp .env.example .env
# Edit .env and set GEMINI_API_KEY=<your-key>
```

Or export it in your shell:

```bash
export GEMINI_API_KEY="your-api-key"
```

Optional environment variables:

- `GEMINI_MODEL` — defaults to `gemini-flash-latest`
- `PORT` — HTTP server port, defaults to `8080`

## 2. Run the eval

Runs all 10 Turkish test cases through `refundFlow`, prints a summary table (`case`, `expected status`, `actual status`, `tool called (yes/no)`, `pass/fail`), and writes detailed output to `results/eval.json`:

```bash
dart run bin/eval.dart
```

## 3. Start the HTTP server

Exposes `POST /refundFlow` using `GenkitRouter` and `genkit_shelf` (`shelf` + `shelf_router`), as recommended in the [Genkit Dart Shelf guide](https://genkit.dev/docs/dart/backend-frameworks/shelf/):

```bash
dart run bin/server.dart
```

Default endpoints:

- `POST http://localhost:8080/refundFlow`
- `GET http://localhost:8080/health`

## 4. `curl` example

Genkit's HTTP flow protocol wraps flow input inside `{"data": ...}`:

```bash
curl -X POST http://localhost:8080/refundFlow \
  -H "Content-Type: application/json" \
  -d '{"data": "1042 numaralı siparişteki 3 kahveden 2'\''sini iade etmek istiyorum, soğuk gelmişti."}'
```

Example response:

```json
{
  "result": {
    "status": "ok",
    "orderNumber": 1042,
    "items": [
      { "product": "Latte", "quantity": 2 }
    ],
    "reason": "soğuk gelmişti",
    "missingInfo": []
  }
}
```

## 5. Open the Genkit Developer UI

Genkit Dart supports the [Genkit Developer UI](https://genkit.dev/docs/dart/devtools/) via the Genkit CLI.

Install the Genkit CLI (choose one):

```bash
npm install -g genkit-cli
# or
curl -sL cli.genkit.dev | bash
```

Start the server under `genkit start` (this sets `GENKIT_ENV=dev`, which automatically enables Genkit Dart's reflection server and telemetry):

```bash
genkit start -- dart run bin/server.dart
```

Then open **http://localhost:4000** in your browser (or add `-o` to open it automatically: `genkit start -o -- dart run bin/server.dart`). From the Developer UI you can invoke `refundFlow`, test `getOrder`, and inspect full traces.

## Tests & static analysis

```bash
dart analyze
dart test
```