// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refund_assistant.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Input schema for the `getOrder` tool.
base class GetOrderInput {
  /// Creates a [GetOrderInput] from a JSON map.
  factory GetOrderInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetOrderInput._(this._json);

  GetOrderInput({required int orderNumber}) {
    _json = {'orderNumber': orderNumber};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetOrderInput].
  static const SchemanticType<GetOrderInput> $schema =
      _GetOrderInputTypeFactory();

  int get orderNumber {
    return (_json['orderNumber'] as num).toInt();
  }

  set orderNumber(int value) {
    _json['orderNumber'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetOrderInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetOrderInputTypeFactory extends SchemanticType<GetOrderInput> {
  const _GetOrderInputTypeFactory();

  @override
  GetOrderInput parse(Object? json) {
    return GetOrderInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetOrderInput',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Lookup parameters for retrieving an order by number.',
      'properties': <String, Object?>{
        'orderNumber': <String, Object?>{
          'type': 'integer',
          'description': 'The integer order number to look up, e.g. 1042.',
        },
      },
      'required': ['orderNumber'],
    },
    dependencies: [],
  );
}

/// Single item entry in an order or refund request.
base class RefundItem {
  /// Creates a [RefundItem] from a JSON map.
  factory RefundItem.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  RefundItem._(this._json);

  RefundItem({required String product, required int quantity}) {
    _json = {'product': product, 'quantity': quantity};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [RefundItem].
  static const SchemanticType<RefundItem> $schema = _RefundItemTypeFactory();

  String get product {
    return _json['product'] as String;
  }

  set product(String value) {
    _json['product'] = value;
  }

  int get quantity {
    return (_json['quantity'] as num).toInt();
  }

  set quantity(int value) {
    _json['quantity'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [RefundItem] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _RefundItemTypeFactory extends SchemanticType<RefundItem> {
  const _RefundItemTypeFactory();

  @override
  RefundItem parse(Object? json) {
    return RefundItem._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RefundItem',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'A product and integer quantity.',
      'properties': <String, Object?>{
        'product': <String, Object?>{
          'type': 'string',
          'description':
              'Exact product name as returned by getOrder (never invent or rename).',
        },
        'quantity': <String, Object?>{
          'type': 'integer',
          'description': 'Positive integer quantity of the product.',
          'minimum': 1,
        },
      },
      'required': ['product', 'quantity'],
    },
    dependencies: [],
  );
}

/// Output schema returned by the `getOrder` tool.
base class GetOrderOutput {
  /// Creates a [GetOrderOutput] from a JSON map.
  factory GetOrderOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetOrderOutput._(this._json);

  GetOrderOutput({
    required String status,
    required int orderNumber,
    required List<RefundItem> items,
  }) {
    _json = {
      'status': status,
      'orderNumber': orderNumber,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetOrderOutput].
  static const SchemanticType<GetOrderOutput> $schema =
      _GetOrderOutputTypeFactory();

  String get status {
    return _json['status'] as String;
  }

  set status(String value) {
    _json['status'] = value;
  }

  int get orderNumber {
    return (_json['orderNumber'] as num).toInt();
  }

  set orderNumber(int value) {
    _json['orderNumber'] = value;
  }

  List<RefundItem> get items {
    return (_json['items'] as List)
        .map((e) => RefundItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set items(List<RefundItem> value) {
    _json['items'] = value.map((e) => e.toJson()).toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetOrderOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetOrderOutputTypeFactory extends SchemanticType<GetOrderOutput> {
  const _GetOrderOutputTypeFactory();

  @override
  GetOrderOutput parse(Object? json) {
    return GetOrderOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetOrderOutput',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Result of looking up an order by orderNumber.',
      'properties': <String, Object?>{
        'status': <String, Object?>{
          'type': 'string',
          'description':
              'Whether the order exists ("found") or not ("not found").',
          'enum': ['found', 'not found'],
        },
        'orderNumber': <String, Object?>{
          'type': 'integer',
          'description': 'The order number that was queried.',
        },
        'items': <String, Object?>{
          'type': 'array',
          'description':
              'Items in the order; empty when status is "not found".',
          'items': <String, Object?>{r'$ref': r'#/$defs/RefundItem'},
        },
      },
      'required': ['status', 'orderNumber', 'items'],
    },
    dependencies: [RefundItem.$schema],
  );
}

/// Structured output schema for `refundFlow`.
base class RefundResponse {
  /// Creates a [RefundResponse] from a JSON map.
  factory RefundResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  RefundResponse._(this._json);

  RefundResponse({
    required String status,
    int? orderNumber,
    required List<RefundItem> items,
    String? reason,
    required List<String> missingInfo,
  }) {
    _json = {
      'status': status,
      'orderNumber': ?orderNumber,
      'items': items.map((e) => e.toJson()).toList(),
      'reason': ?reason,
      'missingInfo': missingInfo,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [RefundResponse].
  static const SchemanticType<RefundResponse> $schema =
      _RefundResponseTypeFactory();

  String get status {
    return _json['status'] as String;
  }

  set status(String value) {
    _json['status'] = value;
  }

  int? get orderNumber {
    return (_json['orderNumber'] as num?)?.toInt();
  }

  set orderNumber(int? value) {
    if (value == null) {
      _json.remove('orderNumber');
    } else {
      _json['orderNumber'] = value;
    }
  }

  List<RefundItem> get items {
    return (_json['items'] as List)
        .map((e) => RefundItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set items(List<RefundItem> value) {
    _json['items'] = value.map((e) => e.toJson()).toList();
  }

  String? get reason {
    return _json['reason'] as String?;
  }

  set reason(String? value) {
    if (value == null) {
      _json.remove('reason');
    } else {
      _json['reason'] = value;
    }
  }

  List<String> get missingInfo {
    return (_json['missingInfo'] as List).cast<String>();
  }

  set missingInfo(List<String> value) {
    _json['missingInfo'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [RefundResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _RefundResponseTypeFactory extends SchemanticType<RefundResponse> {
  const _RefundResponseTypeFactory();

  @override
  RefundResponse parse(Object? json) {
    return RefundResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RefundResponse',
    definition: <String, Object?>{
      'type': 'object',
      'description': 'Structured refund decision extracted from user text.',
      'properties': <String, Object?>{
        'status': <String, Object?>{
          'type': 'string',
          'description': 'Outcome of validating the Turkish refund request.',
          'enum': [
            'ok',
            'missing_info',
            'order_not_found',
            'invalid_quantity',
            'item_not_in_order',
            'not_refund_request',
          ],
        },
        'orderNumber': <String, Object?>{
          'type': 'integer',
          'description':
              'Order number from the user message, or null if absent.',
        },
        'items': <String, Object?>{
          'type': 'array',
          'description':
              'Refund items using exact product names from getOrder. Empty unless status is "ok".',
          'items': <String, Object?>{r'$ref': r'#/$defs/RefundItem'},
        },
        'reason': <String, Object?>{
          'type': 'string',
          'description':
              'Short refund reason from the user message, or null if no reason was given.',
        },
        'missingInfo': <String, Object?>{
          'type': 'array',
          'description':
              'List of missing required fields when status is "missing_info" (e.g. ["orderNumber"]). Empty otherwise.',
          'items': <String, Object?>{'type': 'string'},
        },
      },
      'required': ['status', 'items', 'missingInfo'],
    },
    dependencies: [RefundItem.$schema],
  );
}
