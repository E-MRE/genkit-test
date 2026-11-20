import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'refund_assistant.dart';

/// Builds the Shelf HTTP [Handler] exposing `POST /refundFlow` via
/// `shelfHandler` from `package:genkit_shelf`, plus `GET /health`.
Handler createRefundServerHandler(
  RefundAssistant assistant, {
  bool enableRequestLogging = true,
}) {
  final router = Router()
    ..get('/health', (Request request) => Response.ok('OK'))
    ..post('/refundFlow', shelfHandler(assistant.refundFlow));

  var pipeline = const Pipeline();
  if (enableRequestLogging) {
    pipeline = pipeline.addMiddleware(logRequests());
  }
  return pipeline.addHandler(router.call);
}
