import 'package:genkit/io.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'refund_assistant.dart';

/// Builds the Shelf HTTP [Handler] exposing `POST /refundFlow` via
/// [GenkitRouter] and `package:genkit_shelf`, plus `GET /health`.
Handler createRefundServerHandler(
  RefundAssistant assistant, {
  bool enableRequestLogging = true,
}) {
  final genkitRouter = GenkitRouter()..addAction(assistant.refundFlow);

  final router = Router()
    ..get('/health', (Request request) => Response.ok('OK'))
    ..mount('/', genkitRouter.asShelfHandler(cors: const CorsOptions()));

  var pipeline = const Pipeline();
  if (enableRequestLogging) {
    pipeline = pipeline.addMiddleware(logRequests());
  }
  return pipeline.addHandler(router.call);
}
