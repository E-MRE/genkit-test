import 'dart:io';

import 'package:genkit_refund_experiment/env.dart';
import 'package:genkit_refund_experiment/eval_runner.dart';
import 'package:genkit_refund_experiment/refund_assistant.dart';

Future<void> main() async {
  final apiKey = readGeminiApiKey();
  if (apiKey == null) {
    stderr.writeln(
      'Missing GEMINI_API_KEY. Export GEMINI_API_KEY or add it to a local .env file.',
    );
    exitCode = 1;
    return;
  }

  final modelName = readEnvVar('GEMINI_MODEL') ?? defaultGeminiFlashModel;
  final assistant = createRefundAssistant(
    apiKey: apiKey,
    modelName: modelName,
    isDevEnv: false,
  );

  try {
    stdout.writeln(
      'Running ${refundEvalCases.length} refundFlow eval cases ($modelName)...\n',
    );
    final results = await runEvalSuite(
      assistant,
      onResult: (r) => stdout.writeln(
        'case ${r.evalCase.id}: ${r.actualStatusLabel} ${r.passed ? 'pass' : 'fail'} ${r.error == null ? '' : shortError(r.error!)}',
      ),
    );

    stdout.write(formatEvalTable(results));
    await writeEvalJson(results, modelName: modelName);
    stdout.writeln('Wrote results/eval.json');

    if (results.any((r) => !r.passed)) {
      exitCode = 1;
    }
  } finally {
    await assistant.ai.shutdown();
  }
  await stdout.flush();
  exit(exitCode);
}
