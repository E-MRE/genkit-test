import 'dart:io';

import 'package:genkit_refund_experiment/assistant_flow.dart';
import 'package:genkit_refund_experiment/env.dart';
import 'package:genkit_refund_experiment/refund_assistant.dart';
import 'package:genkit_refund_experiment/server.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final apiKey = readGeminiApiKey();
  if (apiKey == null) {
    stderr.writeln(
      'Warning: GEMINI_API_KEY is not set. Requests to /refundFlow and '
      '/assistantFlow will fail until GEMINI_API_KEY is exported or placed in .env.',
    );
  }

  final modelName = readEnvVar('GEMINI_MODEL') ?? defaultGeminiFlashModel;
  final port = int.tryParse(readEnvVar('PORT') ?? '') ?? 8080;
  final host = readEnvVar('HOST');
  final bindAddress = (host == null || host.isEmpty)
      ? InternetAddress.loopbackIPv4
      : (InternetAddress.tryParse(host) ?? InternetAddress.loopbackIPv4);
  final staticWebDir = readEnvVar('STATIC_WEB_DIR');

  final assistant = createRefundAssistant(apiKey: apiKey, modelName: modelName);
  final orderAssistant = createAssistantFlow(assistant);

  final handler = createRefundServerHandler(
    assistant,
    assistantFlow: orderAssistant.assistantFlow,
    staticWebDir: staticWebDir,
  );
  final server = await io.serve(handler, bindAddress, port);
  stdout.writeln(
    'Genkit HTTP server listening on http://localhost:${server.port} '
    '(/refundFlow, /assistantFlow, /health; model: $modelName)',
  );
}
