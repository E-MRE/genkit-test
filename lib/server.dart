import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'refund_assistant.dart';

/// Builds the Shelf HTTP [Handler] exposing `POST /refundFlow` (and optionally
/// `POST /assistantFlow`) via `shelfHandler` from `package:genkit_shelf`,
/// plus `GET /health` and minimal localhost CORS headers.
///
/// When [staticWebDir] is provided and exists, static files (such as a built
/// Flutter web bundle) are served on `GET` requests for previewing.
Handler createRefundServerHandler(
  RefundAssistant assistant, {
  Flow? assistantFlow,
  String? staticWebDir,
  bool enableRequestLogging = true,
}) {
  final router = Router()
    ..get('/health', (Request request) => Response.ok('OK'))
    ..post('/refundFlow', shelfHandler(assistant.refundFlow));

  if (assistantFlow != null) {
    router.post('/assistantFlow', shelfHandler(assistantFlow));
  }

  Handler rootHandler = router.call;
  if (staticWebDir != null && Directory(staticWebDir).existsSync()) {
    final staticHandler = _staticDirectoryHandler(Directory(staticWebDir));
    rootHandler = Cascade().add(router.call).add(staticHandler).handler;
  }

  var pipeline = const Pipeline().addMiddleware(_localhostCorsMiddleware());
  if (enableRequestLogging) {
    pipeline = pipeline.addMiddleware(logRequests());
  }
  return pipeline.addHandler(rootHandler);
}

Handler _staticDirectoryHandler(Directory rootDir) {
  final rootPath = rootDir.resolveSymbolicLinksSync();
  return (Request request) async {
    if (request.method != 'GET' && request.method != 'HEAD') {
      return Response.notFound('Not found');
    }

    final rawPath = request.url.path;
    final relativePath = rawPath.isEmpty ? 'index.html' : rawPath;
    final candidate = File('$rootPath/$relativePath');
    if (!candidate.existsSync()) {
      return Response.notFound('Not found');
    }

    final resolved = candidate.resolveSymbolicLinksSync();
    if (!resolved.startsWith('$rootPath${Platform.pathSeparator}')) {
      return Response.forbidden('Forbidden');
    }

    final bytes = await candidate.readAsBytes();
    return Response.ok(
      request.method == 'HEAD' ? null : bytes,
      headers: <String, String>{
        'content-type': _contentTypeForPath(resolved),
      },
    );
  };
}

String _contentTypeForPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.html')) return 'text/html; charset=utf-8';
  if (lower.endsWith('.js') || lower.endsWith('.mjs')) {
    return 'application/javascript; charset=utf-8';
  }
  if (lower.endsWith('.css')) return 'text/css; charset=utf-8';
  if (lower.endsWith('.json')) return 'application/json; charset=utf-8';
  if (lower.endsWith('.wasm')) return 'application/wasm';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.ico')) return 'image/x-icon';
  if (lower.endsWith('.otf')) return 'font/otf';
  if (lower.endsWith('.ttf')) return 'font/ttf';
  if (lower.endsWith('.woff2')) return 'font/woff2';
  return 'application/octet-stream';
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
