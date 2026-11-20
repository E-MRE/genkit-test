import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Default local Genkit Shelf server base/flow URL, overridable via
/// `--dart-define=API_URL=...`.
const String defaultApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080/refundFlow',
);

/// Structured status values returned by `/refundFlow`.
enum RefundStatus {
  ok,
  missingInfo,
  orderNotFound,
  invalidQuantity,
  itemNotInOrder,
  notRefundRequest,
  unknown,
}

/// Maps a `/refundFlow` wire status string to [RefundStatus].
RefundStatus parseRefundStatus(String value) {
  if (value == 'ok') return RefundStatus.ok;
  if (value == 'missing_info') return RefundStatus.missingInfo;
  if (value == 'order_not_found') return RefundStatus.orderNotFound;
  if (value == 'invalid_quantity') return RefundStatus.invalidQuantity;
  if (value == 'item_not_in_order') return RefundStatus.itemNotInOrder;
  if (value == 'not_refund_request') return RefundStatus.notRefundRequest;
  return RefundStatus.unknown;
}

/// Card view types returned by `/assistantFlow`.
enum AssistantView {
  refundSummary,
  shipmentTracking,
  orderDetails,
  clarification,
  unsupported,
}

/// Maps an `/assistantFlow` `view` string to [AssistantView].
AssistantView parseAssistantView(String value) {
  if (value == 'refund_summary') return AssistantView.refundSummary;
  if (value == 'shipment_tracking') return AssistantView.shipmentTracking;
  if (value == 'order_details') return AssistantView.orderDetails;
  if (value == 'clarification') return AssistantView.clarification;
  return AssistantView.unsupported;
}

/// Refund validation status returned inside `/assistantFlow`.
enum AssistantRefundStatus {
  none,
  ok,
  invalidQuantity,
  itemNotInOrder,
  orderNotFound,
}

/// Maps an `/assistantFlow` `refundStatus` string to [AssistantRefundStatus].
AssistantRefundStatus parseAssistantRefundStatus(String value) {
  if (value == 'ok') return AssistantRefundStatus.ok;
  if (value == 'invalid_quantity') return AssistantRefundStatus.invalidQuantity;
  if (value == 'item_not_in_order') return AssistantRefundStatus.itemNotInOrder;
  if (value == 'order_not_found') return AssistantRefundStatus.orderNotFound;
  return AssistantRefundStatus.none;
}

/// One item in a `/refundFlow` response.
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

/// One priced item in an `/assistantFlow` response.
class AssistantItemModel {
  const AssistantItemModel({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  final String product;
  final int quantity;
  final double unitPrice;
}

/// One shipment step in an `/assistantFlow` response.
class ShipmentStepModel {
  const ShipmentStepModel({
    required this.label,
    required this.done,
    required this.time,
  });

  final String label;
  final bool done;
  final String time;
}

/// Parsed response from `POST /assistantFlow`.
class AssistantResultModel {
  const AssistantResultModel({
    required this.view,
    required this.rawView,
    required this.message,
    required this.orderNumber,
    required this.items,
    required this.refundStatus,
    required this.rawRefundStatus,
    required this.shipmentSteps,
    required this.suggestions,
    required this.rawJson,
    required this.elapsedSeconds,
  });

  final AssistantView view;
  final String rawView;
  final String message;
  final String orderNumber;
  final List<AssistantItemModel> items;
  final AssistantRefundStatus refundStatus;
  final String rawRefundStatus;
  final List<ShipmentStepModel> shipmentSteps;
  final List<String> suggestions;
  final String rawJson;
  final double elapsedSeconds;
}

/// User-facing error raised when calling a Genkit flow fails.
class RefundApiException implements Exception {
  const RefundApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolves the URL for [flowName] (`refundFlow` or `assistantFlow`) from a
/// configured [apiUrl] (which may be a base URL or end in a flow path).
String resolveFlowUrl(String apiUrl, String flowName) {
  final trimmed = apiUrl.trim();
  if (trimmed.endsWith('/refundFlow')) {
    return '${trimmed.substring(0, trimmed.length - '/refundFlow'.length)}/$flowName';
  }
  if (trimmed.endsWith('/assistantFlow')) {
    return '${trimmed.substring(0, trimmed.length - '/assistantFlow'.length)}/$flowName';
  }
  if (trimmed.endsWith('/')) {
    return '$trimmed$flowName';
  }
  return '$trimmed/$flowName';
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

  /// Sends [message] to `POST /refundFlow`.
  Future<RefundResultModel> callRefundFlow(String message) async {
    final targetUrl = resolveFlowUrl(apiUrl, 'refundFlow');
    final envelope = await _postFlow(targetUrl, message);
    return _parseRefundResult(envelope.decoded, envelope.elapsedSeconds);
  }

  /// Sends [message] to `POST /assistantFlow`.
  Future<AssistantResultModel> callAssistantFlow(String message) async {
    final targetUrl = resolveFlowUrl(apiUrl, 'assistantFlow');
    final envelope = await _postFlow(targetUrl, message);
    return _parseAssistantResult(envelope.decoded, envelope.elapsedSeconds);
  }

  Future<_FlowEnvelope> _postFlow(String url, String message) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw RefundApiException('Geçersiz sunucu adresi: $url');
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
        'Sunucuya bağlanılamadı ($url). '
        'Arka uç sunucusunun çalıştığından emin olun (dart run bin/server.dart).',
      );
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('socketexception') ||
          text.contains('connection refused') ||
          text.contains('failed to fetch')) {
        throw RefundApiException(
          'Sunucuya bağlanılamadı ($url). '
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

    return _FlowEnvelope(
      decoded: decoded,
      elapsedSeconds: stopwatch.elapsedMilliseconds / 1000.0,
    );
  }

  RefundResultModel _parseRefundResult(
    Map<String, dynamic> decoded,
    double elapsedSeconds,
  ) {
    final resultValue = decoded['result'];
    if (resultValue is! Map<String, dynamic>) {
      throw const RefundApiException('Yanıtta "result" nesnesi bulunamadı.');
    }

    final rawStatusValue = resultValue['status'];
    final rawStatus = rawStatusValue is String ? rawStatusValue : 'unknown';

    final orderValue = resultValue['orderNumber'];
    final int? orderNumber = orderValue is num ? orderValue.toInt() : null;

    final reasonValue = resultValue['reason'];
    final String? reason = reasonValue is String && reasonValue.trim().isNotEmpty
        ? reasonValue
        : null;

    final prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);
    return RefundResultModel(
      status: parseRefundStatus(rawStatus),
      rawStatus: rawStatus,
      orderNumber: orderNumber,
      items: _parseRefundItems(resultValue['items']),
      reason: reason,
      missingInfo: _parseStringList(resultValue['missingInfo']),
      rawJson: prettyJson,
      elapsedSeconds: elapsedSeconds,
    );
  }

  AssistantResultModel _parseAssistantResult(
    Map<String, dynamic> decoded,
    double elapsedSeconds,
  ) {
    final resultValue = decoded['result'];
    if (resultValue is! Map<String, dynamic>) {
      throw const RefundApiException('Yanıtta "result" nesnesi bulunamadı.');
    }

    final rawViewValue = resultValue['view'];
    final rawView = rawViewValue is String ? rawViewValue : 'unsupported';

    final messageValue = resultValue['message'];
    final message = messageValue is String ? messageValue : '';

    final orderValue = resultValue['orderNumber'];
    final orderNumber = orderValue is String ? orderValue : '';

    final refundStatusValue = resultValue['refundStatus'];
    final rawRefundStatus = refundStatusValue is String
        ? refundStatusValue
        : 'none';

    final prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);
    return AssistantResultModel(
      view: parseAssistantView(rawView),
      rawView: rawView,
      message: message,
      orderNumber: orderNumber,
      items: _parseAssistantItems(resultValue['items']),
      refundStatus: parseAssistantRefundStatus(rawRefundStatus),
      rawRefundStatus: rawRefundStatus,
      shipmentSteps: _parseShipmentSteps(resultValue['shipmentSteps']),
      suggestions: _parseStringList(resultValue['suggestions']),
      rawJson: prettyJson,
      elapsedSeconds: elapsedSeconds,
    );
  }

  List<RefundItemModel> _parseRefundItems(Object? rawItems) {
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

  List<AssistantItemModel> _parseAssistantItems(Object? rawItems) {
    if (rawItems is! List) return const <AssistantItemModel>[];
    final parsed = <AssistantItemModel>[];
    for (final entry in rawItems) {
      if (entry is Map<String, dynamic>) {
        final product = entry['product'];
        final quantity = entry['quantity'];
        final unitPrice = entry['unitPrice'];
        if (product is String && quantity is num) {
          parsed.add(
            AssistantItemModel(
              product: product,
              quantity: quantity.toInt(),
              unitPrice: unitPrice is num ? unitPrice.toDouble() : 0.0,
            ),
          );
        }
      }
    }
    return parsed;
  }

  List<ShipmentStepModel> _parseShipmentSteps(Object? rawSteps) {
    if (rawSteps is! List) return const <ShipmentStepModel>[];
    final parsed = <ShipmentStepModel>[];
    for (final entry in rawSteps) {
      if (entry is Map<String, dynamic>) {
        final label = entry['label'];
        final done = entry['done'];
        final time = entry['time'];
        if (label is String && done is bool) {
          parsed.add(
            ShipmentStepModel(
              label: label,
              done: done,
              time: time is String ? time : '',
            ),
          );
        }
      }
    }
    return parsed;
  }

  List<String> _parseStringList(Object? rawList) {
    if (rawList is! List) return const <String>[];
    final parsed = <String>[];
    for (final entry in rawList) {
      if (entry is String && entry.trim().isNotEmpty) {
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

class _FlowEnvelope {
  const _FlowEnvelope({required this.decoded, required this.elapsedSeconds});

  final Map<String, dynamic> decoded;
  final double elapsedSeconds;
}
