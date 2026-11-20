// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant_flow.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// Input schema for the `getShipment` tool.
base class GetShipmentInput {
  /// Creates a [GetShipmentInput] from a JSON map.
  factory GetShipmentInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetShipmentInput._(this._json);

  GetShipmentInput({required int orderNumber}) {
    _json = {'orderNumber': orderNumber};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetShipmentInput].
  static const SchemanticType<GetShipmentInput> $schema =
      _GetShipmentInputTypeFactory();

  int get orderNumber {
    return _json['orderNumber'] as int;
  }

  set orderNumber(int value) {
    _json['orderNumber'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetShipmentInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetShipmentInputTypeFactory
    extends SchemanticType<GetShipmentInput> {
  const _GetShipmentInputTypeFactory();

  @override
  GetShipmentInput parse(Object? json) {
    return GetShipmentInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetShipmentInput',
    definition: $Schema
        .object(
          properties: {
            'orderNumber': $Schema.integer(
              description: 'The integer order number to look up, e.g. 1043.',
            ),
          },
          required: ['orderNumber'],
          description: 'Lookup parameters for retrieving shipment tracking.',
        )
        .value,
    dependencies: [],
  );
}

/// One step in a shipment tracking timeline.
base class ShipmentStep {
  /// Creates a [ShipmentStep] from a JSON map.
  factory ShipmentStep.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ShipmentStep._(this._json);

  ShipmentStep({
    required String label,
    required bool done,
    required String time,
  }) {
    _json = {'label': label, 'done': done, 'time': time};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ShipmentStep].
  static const SchemanticType<ShipmentStep> $schema =
      _ShipmentStepTypeFactory();

  String get label {
    return _json['label'] as String;
  }

  set label(String value) {
    _json['label'] = value;
  }

  bool get done {
    return _json['done'] as bool;
  }

  set done(bool value) {
    _json['done'] = value;
  }

  String get time {
    return _json['time'] as String;
  }

  set time(String value) {
    _json['time'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ShipmentStep] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ShipmentStepTypeFactory extends SchemanticType<ShipmentStep> {
  const _ShipmentStepTypeFactory();

  @override
  ShipmentStep parse(Object? json) {
    return ShipmentStep._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ShipmentStep',
    definition: $Schema
        .object(
          properties: {
            'label': $Schema.string(description: 'Short Turkish step label.'),
            'done': $Schema.boolean(
              description: 'Whether this step is completed.',
            ),
            'time': $Schema.string(
              description: 'Short time or status text for this step.',
            ),
          },
          required: ['label', 'done', 'time'],
          description: 'A single shipment status step.',
        )
        .value,
    dependencies: [],
  );
}

/// Output schema returned by the `getShipment` tool.
base class GetShipmentOutput {
  /// Creates a [GetShipmentOutput] from a JSON map.
  factory GetShipmentOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetShipmentOutput._(this._json);

  GetShipmentOutput({
    required String status,
    required int orderNumber,
    required String shipmentStatus,
    required List<ShipmentStep> steps,
  }) {
    _json = {
      'status': status,
      'orderNumber': orderNumber,
      'shipmentStatus': shipmentStatus,
      'steps': steps.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetShipmentOutput].
  static const SchemanticType<GetShipmentOutput> $schema =
      _GetShipmentOutputTypeFactory();

  String get status {
    return _json['status'] as String;
  }

  set status(String value) {
    _json['status'] = value;
  }

  int get orderNumber {
    return _json['orderNumber'] as int;
  }

  set orderNumber(int value) {
    _json['orderNumber'] = value;
  }

  String get shipmentStatus {
    return _json['shipmentStatus'] as String;
  }

  set shipmentStatus(String value) {
    _json['shipmentStatus'] = value;
  }

  List<ShipmentStep> get steps {
    return (_json['steps'] as List)
        .map((e) => ShipmentStep.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set steps(List<ShipmentStep> value) {
    _json['steps'] = value.map((e) => e.toJson()).toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetShipmentOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetShipmentOutputTypeFactory
    extends SchemanticType<GetShipmentOutput> {
  const _GetShipmentOutputTypeFactory();

  @override
  GetShipmentOutput parse(Object? json) {
    return GetShipmentOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetShipmentOutput',
    definition: $Schema
        .object(
          properties: {
            'status': $Schema.string(
              description:
                  'Whether shipment tracking exists ("found") or ("not found").',
              enumValues: ['found', 'not found'],
            ),
            'orderNumber': $Schema.integer(
              description: 'The order number that was queried.',
            ),
            'shipmentStatus': $Schema.string(
              description:
                  'Summary shipment state ("delivered", "in_transit", "preparing") or empty string if not found.',
            ),
            'steps': $Schema.list(
              description: 'Ordered tracking steps; empty when not found.',
              items: $Schema.fromMap({'\$ref': r'#/$defs/ShipmentStep'}),
            ),
          },
          required: ['status', 'orderNumber', 'shipmentStatus', 'steps'],
          description: 'Result of looking up shipment tracking by orderNumber.',
        )
        .value,
    dependencies: [ShipmentStep.$schema],
  );
}

/// Product line item in [AssistantResponse].
base class AssistantItem {
  /// Creates a [AssistantItem] from a JSON map.
  factory AssistantItem.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AssistantItem._(this._json);

  AssistantItem({
    required String product,
    required int quantity,
    required double unitPrice,
  }) {
    _json = {'product': product, 'quantity': quantity, 'unitPrice': unitPrice};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AssistantItem].
  static const SchemanticType<AssistantItem> $schema =
      _AssistantItemTypeFactory();

  String get product {
    return _json['product'] as String;
  }

  set product(String value) {
    _json['product'] = value;
  }

  int get quantity {
    return _json['quantity'] as int;
  }

  set quantity(int value) {
    _json['quantity'] = value;
  }

  double get unitPrice {
    return (_json['unitPrice'] as num).toDouble();
  }

  set unitPrice(double value) {
    _json['unitPrice'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AssistantItem] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AssistantItemTypeFactory extends SchemanticType<AssistantItem> {
  const _AssistantItemTypeFactory();

  @override
  AssistantItem parse(Object? json) {
    return AssistantItem._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AssistantItem',
    definition: $Schema
        .object(
          properties: {
            'product': $Schema.string(
              description: 'Exact product name returned by getOrder.',
            ),
            'quantity': $Schema.integer(
              description: 'Positive integer quantity.',
              minimum: 1,
            ),
            'unitPrice': $Schema.number(
              description: 'Exact unit price in TL returned by getOrder.',
              minimum: 0,
            ),
          },
          required: ['product', 'quantity', 'unitPrice'],
          description: 'A product, quantity, and unit price in TL.',
        )
        .value,
    dependencies: [],
  );
}

/// Non-nullable structured output schema for `assistantFlow`.
base class AssistantResponse {
  /// Creates a [AssistantResponse] from a JSON map.
  factory AssistantResponse.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AssistantResponse._(this._json);

  AssistantResponse({
    required String view,
    required String message,
    required String orderNumber,
    required List<AssistantItem> items,
    required String refundStatus,
    required List<ShipmentStep> shipmentSteps,
    required List<String> suggestions,
  }) {
    _json = {
      'view': view,
      'message': message,
      'orderNumber': orderNumber,
      'items': items.map((e) => e.toJson()).toList(),
      'refundStatus': refundStatus,
      'shipmentSteps': shipmentSteps.map((e) => e.toJson()).toList(),
      'suggestions': suggestions,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AssistantResponse].
  static const SchemanticType<AssistantResponse> $schema =
      _AssistantResponseTypeFactory();

  String get view {
    return _json['view'] as String;
  }

  set view(String value) {
    _json['view'] = value;
  }

  String get message {
    return _json['message'] as String;
  }

  set message(String value) {
    _json['message'] = value;
  }

  String get orderNumber {
    return _json['orderNumber'] as String;
  }

  set orderNumber(String value) {
    _json['orderNumber'] = value;
  }

  List<AssistantItem> get items {
    return (_json['items'] as List)
        .map((e) => AssistantItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set items(List<AssistantItem> value) {
    _json['items'] = value.map((e) => e.toJson()).toList();
  }

  String get refundStatus {
    return _json['refundStatus'] as String;
  }

  set refundStatus(String value) {
    _json['refundStatus'] = value;
  }

  List<ShipmentStep> get shipmentSteps {
    return (_json['shipmentSteps'] as List)
        .map((e) => ShipmentStep.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set shipmentSteps(List<ShipmentStep> value) {
    _json['shipmentSteps'] = value.map((e) => e.toJson()).toList();
  }

  List<String> get suggestions {
    return (_json['suggestions'] as List).cast<String>();
  }

  set suggestions(List<String> value) {
    _json['suggestions'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AssistantResponse] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AssistantResponseTypeFactory
    extends SchemanticType<AssistantResponse> {
  const _AssistantResponseTypeFactory();

  @override
  AssistantResponse parse(Object? json) {
    return AssistantResponse._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AssistantResponse',
    definition: $Schema
        .object(
          properties: {
            'view': $Schema.string(
              description: 'Which UI card to display for this response.',
              enumValues: [
                'refund_summary',
                'shipment_tracking',
                'order_details',
                'clarification',
                'unsupported',
              ],
            ),
            'message': $Schema.string(
              description: 'One short Turkish sentence shown above the card.',
            ),
            'orderNumber': $Schema.string(
              description:
                  'Order number as string (e.g. "1042"), or empty string "" if none.',
            ),
            'items': $Schema.list(
              description:
                  'Relevant items with exact product names and unitPrice from getOrder; empty list [] if not relevant.',
              items: $Schema.fromMap({'\$ref': r'#/$defs/AssistantItem'}),
            ),
            'refundStatus': $Schema.string(
              description:
                  'Refund validation status for refund_summary; "none" for all other views.',
              enumValues: [
                'none',
                'ok',
                'invalid_quantity',
                'item_not_in_order',
                'order_not_found',
              ],
            ),
            'shipmentSteps': $Schema.list(
              description:
                  'Shipment steps copied from getShipment for shipment_tracking; empty list [] otherwise.',
              items: $Schema.fromMap({'\$ref': r'#/$defs/ShipmentStep'}),
            ),
            'suggestions': $Schema.list(
              description:
                  'Short Turkish follow-up prompts for clarification or unsupported views; empty list [] otherwise.',
              items: $Schema.string(),
            ),
          },
          required: [
            'view',
            'message',
            'orderNumber',
            'items',
            'refundStatus',
            'shipmentSteps',
            'suggestions',
          ],
          description:
              'Structured assistant response choosing a UI card view and data.',
        )
        .value,
    dependencies: [AssistantItem.$schema, ShipmentStep.$schema],
  );
}
