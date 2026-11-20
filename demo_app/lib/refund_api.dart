import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Default local Genkit Shelf flow URL, overridable via
/// `--dart-define=API_URL=...`.
const String defaultApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080/refundFlow',
);

/// Structured status values returned by `refundFlow`.
enum RefundStatus {
  ok,
  missingInfo,
  orderNotFound,
  invalidQuantity,
  itemNotInOrder,
  notRefundRequest,
  unknown,
}

/// Maps a wire status string to [RefundStatus].
RefundStatus parseRefundStatus(String value) {
  if (value == 'ok') return RefundStatus.ok;
  if (value == 'missing_info') return RefundStatus.missingInfo;
  if (value == 'order_not_found') return RefundStatus.orderNotFound;
  if (value == 'invalid_quantity') return RefundStatus.invalidQuantity;
  if (value == 'item_not_in_order') return RefundStatus.itemNotInOrder;
  if (value == 'not_refund_request') return RefundStatus.notRefundRequest;
  return RefundStatus.unknown;
}

/// One item in a structured refund response.
class RefundItemModel {
  const RefundItemModel({required this.product, required this.quantity});

  final String product;
  final int quantity;
}

/// Parsed response from `POST /refundFlow`, plus raw JSON and elapsed time.
class RefundResultModel {
  const RefundResultModel({
    required this.status,
    required this.rawStatus,
    required this.orderNumber,
    required this.items,
    required this.reason,
    required this.missingInfo,
    required this.rawJson,
    required this.elapsedSeconds,
  });

  final RefundStatus status;
  final String rawStatus;
  final int? orderNumber;
  final List<RefundItemModel> items;
  final String? reason;
  final List<String> missingInfo;
  final String rawJson;
  final double elapsedSeconds;
}

/// User-facing error raised when calling `refundFlow` fails.
class RefundApiException implements Exception {
  const RefundApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// HTTP client speaking the `genkit_shelf` 0.1.13 wire protocol:
/// `POST` `{"data": "<message>"}` -> `200 OK` `{"result": {...}}`.
class RefundApiClient {
  RefundApiClient({
    this.apiUrl = defaultApiUrl,
    this.timeout = const Duration(seconds: 120),
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final String apiUrl;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;

  /// Sends [message] to `refundFlow` and returns the parsed [RefundResultModel].
  Future<RefundResultModel> callRefundFlow(String message) async {
    final uri = Uri.tryParse(apiUrl);
    if (uri == null) {
      throw RefundApiException('Geçersiz sunucu adresi: $apiUrl');
    }

    final stopwatch = Stopwatch()..start();
    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{'data': message}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw RefundApiException(
        'İstek ${timeout.inSeconds} saniye içinde zaman aşımına uğradı. '
        'Sunucu veya Gemini API yanıt vermedi.',
      );
    } on http.ClientException {
      throw RefundApiException(
        'Sunucuya bağlanılamadı ($apiUrl). '
        'Arka uç sunucusunun çalıştığından emin olun (dart run bin/server.dart).',
      );
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('socketexception') ||
          text.contains('connection refused') ||
          text.contains('failed to fetch')) {
        throw RefundApiException(
          'Sunucuya bağlanılamadı ($apiUrl). '
          'Arka uç sunucusunun çalıştığından emin olun (dart run bin/server.dart).',
        );
      }
      throw RefundApiException('Beklenmeyen ağ hatası: $error');
    } finally {
      stopwatch.stop();
    }

    final rawBody = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode != 200) {
      final bodyText = rawBody.trim().isEmpty ? '(boş yanıt)' : rawBody;
      throw RefundApiException(
        'Sunucu hata döndürdü (HTTP ${response.statusCode}):\n$bodyText',
      );
    }

    return _parseSuccessResponse(
      rawBody,
      stopwatch.elapsedMilliseconds / 1000.0,
    );
  }

  RefundResultModel _parseSuccessResponse(
    String rawBody,
    double elapsedSeconds,
  ) {
    Object? decoded;
    try {
      decoded = jsonDecode(rawBody);
    } catch (_) {
      throw RefundApiException(
        'Sunucudan geçersiz JSON yanıtı alındı:\n$rawBody',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw RefundApiException(
        'Sunucudan beklenmeyen yanıt biçimi alındı:\n$rawBody',
      );
    }

    final resultValue = decoded['result'];
    if (resultValue is! Map<String, dynamic>) {
      throw RefundApiException(
        'Yanıtta "result" nesnesi bulunamadı:\n$rawBody',
      );
    }

    final rawStatusValue = resultValue['status'];
    final rawStatus = rawStatusValue is String ? rawStatusValue : 'unknown';

    final orderValue = resultValue['orderNumber'];
    final int? orderNumber = orderValue is num ? orderValue.toInt() : null;

    final reasonValue = resultValue['reason'];
    final String? reason = reasonValue is String && reasonValue.trim().isNotEmpty
        ? reasonValue
        : null;

    final items = _parseItems(resultValue['items']);
    final missingInfo = _parseMissingInfo(resultValue['missingInfo']);
    final prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);

    return RefundResultModel(
      status: parseRefundStatus(rawStatus),
      rawStatus: rawStatus,
      orderNumber: orderNumber,
      items: items,
      reason: reason,
      missingInfo: missingInfo,
      rawJson: prettyJson,
      elapsedSeconds: elapsedSeconds,
    );
  }

  List<RefundItemModel> _parseItems(Object? rawItems) {
    if (rawItems is! List) return const <RefundItemModel>[];

    final parsed = <RefundItemModel>[];
    for (final entry in rawItems) {
      if (entry is Map<String, dynamic>) {
        final product = entry['product'];
        final quantity = entry['quantity'];
        if (product is String && quantity is num) {
          parsed.add(
            RefundItemModel(product: product, quantity: quantity.toInt()),
          );
        }
      }
    }
    return parsed;
  }

  List<String> _parseMissingInfo(Object? rawMissing) {
    if (rawMissing is! List) return const <String>[];

    final parsed = <String>[];
    for (final entry in rawMissing) {
      if (entry is String && entry.isNotEmpty) {
        parsed.add(entry);
      }
    }
    return parsed;
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
