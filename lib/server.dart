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

  var pipeline = const Pipeline().addMiddleware(_localhostCorsMiddleware());
  if (enableRequestLogging) {
    pipeline = pipeline.addMiddleware(logRequests());
  }
  return pipeline.addHandler(router.call);
}

bool _isLocalhostOrigin(String origin) {
  final uri = Uri.tryParse(origin);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  return uri.host == 'localhost' ||
      uri.host == '127.0.0.1' ||
      uri.host == '::1';
}

Middleware _localhostCorsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final origin = request.headers['origin'];
      final allowed = origin != null && _isLocalhostOrigin(origin);
      final corsHeaders = allowed
          ? <String, String>{
              'access-control-allow-origin': origin,
              'access-control-allow-methods': 'POST, OPTIONS',
              'access-control-allow-headers': 'Content-Type',
              'vary': 'Origin',
            }
          : const <String, String>{};

      if (request.method == 'OPTIONS') {
        return Response(204, headers: corsHeaders);
      }

      final response = await innerHandler(request);
      if (corsHeaders.isEmpty) return response;
      return response.change(headers: corsHeaders);
    };
  };
}
