# Notes on Genkit Dart

Honest notes on what worked, what was unclear or inconsistent in the Genkit Dart docs/SDK (`genkit 1.0.3`, `genkit_google_genai 1.2.0`, `genkit_shelf 1.0.3`, `schemantic 1.0.0`), and what could not be verified here.

## What could not be run in this environment

- **Live eval (`dart run bin/eval.dart`)**: No `GEMINI_API_KEY` is configured in this build environment, so the 10-case eval could not be run against the live Gemini API and `results/eval.json` is not pre-generated in the repository.
- **Live Genkit Developer UI (`genkit start -- dart run bin/server.dart`)**: `genkit-cli` is not installed in this container and no browser/API key is attached.
- **What was verified locally (Dart SDK 3.14.1)**:
  - `dart pub get` against pub.dev (`genkit 1.0.3`, `genkit_google_genai 1.2.0`, `genkit_shelf 1.0.3`, `schemantic 1.0.0`)
  - `dart run build_runner build` (`schemantic_builder 1.0.0` generating `lib/refund_assistant.g.dart`)
  - `dart analyze` (zero errors/warnings)
  - `dart test` (unit tests for `.env` reading, `getOrder` tool + call counting, `RefundResponse` schema parsing, 10-case eval matcher/table/JSON writer, and Shelf HTTP handler routing)
  - Starting `bin/server.dart` and hitting `GET /health` and `POST /refundFlow` over HTTP.

## Unclear / broken items in Genkit Dart docs vs. SDK

1. **Dart SDK version requirement mismatch (`3.10.0` vs `^3.12.0`)**
   - The [Shelf tutorial](https://genkit.dev/docs/dart/backend-frameworks/shelf/) lists "Dart SDK 3.10.0 or later" as a prerequisite.
   - `genkit 1.0.3` and `schemantic 1.0.0` on pub.dev actually declare `environment: sdk: ^3.12.0` (and use Dart dot-shorthand syntax such as `.string()` and `.response(...)`).

2. **Missing `dev:schemantic_builder` in the Shelf tutorial install command**
   - The Shelf tutorial recommends:
     `dart pub add genkit genkit_google_genai genkit_shelf schemantic shelf shelf_router dev:build_runner`
   - `schemantic 1.0.0` only lists `schemantic_builder` in its own `dev_dependencies`, not `dependencies`. Without adding `dev:schemantic_builder` to your project's `dev_dependencies`, `dart run build_runner build` will not generate `*.g.dart` schema files.

3. **`defineTool` return type inconsistency across doc pages**
   - `https://genkit.dev/docs/dart/backend-frameworks/shelf/` returns a plain value (`return [SaleIngredient(...)]`) from `ai.defineTool`'s `fn`.
   - In `genkit 1.0.3`, `ToolFn<Input, Output>` requires returning `Future<ToolResult<Output>>`, i.e. `return .response(...)` or `return ToolResult.response(...)` (which is what `https://genkit.dev/docs/dart/tool-calling/` shows).
   - Similarly, calling a `Tool` directly in Dart (`await getOrderTool(input)`) returns a `ToolResult<Output>`, so callers must unwrap `.output` (after checking `.hasResponse` if interrupts are possible).

4. **`tools:` vs `toolNames:` mismatch in Tool Calling docs**
   - `https://genkit.dev/docs/dart/tool-calling/` shows `ai.generate(..., tools: ['getWeather'])`.
   - In `genkit 1.0.3`, `tools:` expects `List<Tool>?` (actual `Tool` instances), while string tool names must be passed to `toolNames: ['getWeather']`.

5. **Nullable schema fields in `schemantic` (`int?`, `String?`)**
   - When a `@Schema()` abstract class declares nullable getters (`int? get orderNumber;`, `String? get reason;`), `schemantic_builder` emits them as optional properties (excluded from `required`) with `'type': 'integer'` / `'type': 'string'` rather than JSON Schema nullable unions (`['integer', 'null']`), and `toJson()` omits null keys instead of emitting `"orderNumber": null`.
   - The generated getters safely parse both omitted keys and explicit JSON `null` to Dart `null`. To avoid confusing Gemini's constrained decoder, the system prompt tells the model to omit `orderNumber` / `reason` when null, and `eval_runner.dart` explicitly writes `null` values into `results/eval.json`.

6. **Model routing (`gemini-flash-latest` and the Interactions API)**
   - `genkit_google_genai 1.2.0` routes `gemini-flash-latest` (and newer Gemini 3.x models) through the Gemini Interactions API (`knownGeminiInteractions`), while `gemini-2.5-flash` is marked `legacy` and routed through `generateContent`.
   - All official Genkit Dart docs use `googleAI.gemini('gemini-flash-latest')`, so this project uses that as the default, with a `GEMINI_MODEL` env var override in case a free-tier key behaves differently with a specific Flash model.

7. **Dev reflection server lifecycle in CLI scripts**
   - When `GENKIT_ENV=dev` is set in the shell, `Genkit()` automatically starts a reflection HTTP server that keeps the Dart VM alive. `bin/eval.dart` explicitly sets `isDevEnv: false` and calls `await assistant.ai.shutdown()` in a `finally` block so the eval script always exits cleanly, while `bin/server.dart` leaves `isDevEnv` unset so `genkit start -- dart run bin/server.dart` attaches to the Developer UI automatically.

8. **`ai.generate()` returns `FinishReason.failed` instead of throwing**
   - In `genkit 1.0.3`, provider errors (such as a missing `GEMINI_API_KEY` or API error) resolve as a `GenerateResult` with `finishReason == FinishReason.failed`, `output == null`, and details in `response.error` / `response.cause`, rather than throwing directly. If a flow only checks `if (response.output == null)`, the underlying API error is hidden. `refundFlow` explicitly checks `FinishReason.failed` and `FinishReason.aborted` first so real errors propagate cleanly to HTTP clients and `results/eval.json`.
