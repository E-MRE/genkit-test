import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'refund_assistant.g.dart';

/// Default free-tier Gemini Flash model recommended by the Genkit Dart docs.
const String defaultGeminiFlashModel = 'gemini-flash-latest';

/// Allowed values for [RefundResponse.status].
const List<String> refundStatuses = <String>[
  'ok',
  'missing_info',
  'order_not_found',
  'invalid_quantity',
  'item_not_in_order',
  'not_refund_request',
];

/// Fake in-memory order catalog used by the `getOrder` tool.
const Map<int, List<({String product, int quantity})>> fakeOrders = {
  1042: [(product: 'Latte', quantity: 3), (product: 'Cheesecake', quantity: 1)],
  1043: [(product: 'Su', quantity: 2), (product: 'Sandviç', quantity: 1)],
  1044: [(product: 'Filtre kahve', quantity: 1)],
};

/// Input schema for the `getOrder` tool.
@Schema(description: 'Lookup parameters for retrieving an order by number.')
abstract class $GetOrderInput {
  @Field(description: 'The integer order number to look up, e.g. 1042.')
  int get orderNumber;
}

/// Single item entry in an order or refund request.
@Schema(description: 'A product and integer quantity.')
abstract class $RefundItem {
  @Field(
    description:
        'Exact product name as returned by getOrder (never invent or rename).',
  )
  String get product;

  @IntegerField(
    minimum: 1,
    description: 'Positive integer quantity of the product.',
  )
  int get quantity;
}

/// Output schema returned by the `getOrder` tool.
@Schema(description: 'Result of looking up an order by orderNumber.')
abstract class $GetOrderOutput {
  @StringField(
    enumValues: ['found', 'not found'],
    description: 'Whether the order exists ("found") or not ("not found").',
  )
  String get status;

  @Field(description: 'The order number that was queried.')
  int get orderNumber;

  @Field(description: 'Items in the order; empty when status is "not found".')
  List<$RefundItem> get items;
}

/// Structured output schema for `refundFlow`.
@Schema(description: 'Structured refund decision extracted from user text.')
abstract class $RefundResponse {
  @StringField(
    enumValues: [
      'ok',
      'missing_info',
      'order_not_found',
      'invalid_quantity',
      'item_not_in_order',
      'not_refund_request',
    ],
    description: 'Outcome of validating the Turkish refund request.',
  )
  String get status;

  @Field(description: 'Order number from the user message, or null if absent.')
  int? get orderNumber;

  @Field(
    description:
        'Refund items using exact product names from getOrder. Empty unless status is "ok".',
  )
  List<$RefundItem> get items;

  @Field(
    description:
        'Short refund reason from the user message, or null if no reason was given.',
  )
  String? get reason;

  @Field(
    description:
        'List of missing required fields when status is "missing_info" (e.g. ["orderNumber"]). Empty otherwise.',
  )
  List<String> get missingInfo;
}

/// Tracks calls made to the `getOrder` tool so evaluations can verify usage.
class OrderToolTracker {
  final List<int> _calledOrderNumbers = <int>[];

  /// Total number of `getOrder` invocations recorded since creation or [reset].
  int get callCount => _calledOrderNumbers.length;

  /// Order numbers passed to `getOrder`, in call order.
  List<int> get calledOrderNumbers => List.unmodifiable(_calledOrderNumbers);

  void record(int orderNumber) {
    _calledOrderNumbers.add(orderNumber);
  }

  void reset() {
    _calledOrderNumbers.clear();
  }
}

/// Container holding the initialized Genkit instance, tool, flow, and tracker.
class RefundAssistant {
  RefundAssistant({
    required this.ai,
    required this.getOrderTool,
    required this.refundFlow,
    required this.tracker,
    required this.modelName,
  });

  final Genkit ai;
  final Tool<GetOrderInput, GetOrderOutput> getOrderTool;
  final Flow<String, RefundResponse, void, void> refundFlow;
  final OrderToolTracker tracker;
  final String modelName;
}

const String _systemPrompt = '''
You are a Turkish customer support refund assistant.
Your job is to convert a single free-text Turkish message into a structured refund decision.

Follow these rules strictly in order:
1. If the message is NOT a refund/return request (for example a greeting, general question, or shipping status inquiry):
   - Do NOT call getOrder.
   - Return status="not_refund_request", omit orderNumber (null), items=[], omit reason (null), missingInfo=[].
2. If the message IS a refund request, check whether an order number is mentioned:
   - If NO order number is mentioned, do NOT call getOrder.
   - Return status="missing_info", omit orderNumber (null), items=[], reason=<short reason if stated, otherwise omit>, missingInfo=["orderNumber"].
3. If an order number IS mentioned, you MUST call the getOrder tool with that orderNumber before deciding. Never guess or invent order contents.
   - If getOrder returns status="not found":
     Return status="order_not_found", orderNumber=<the requested orderNumber>, items=[], reason=<short reason if stated, otherwise omit>, missingInfo=[].
   - If getOrder returns status="found", validate every requested item against the returned items:
     * Map colloquial or partial item references to the exact product name returned by getOrder. "All" or "the whole order" means every item in the order at its full ordered quantity.
     * Always copy the product name EXACTLY as returned by getOrder. Never invent products.
     * If any requested product is not in the order, return status="item_not_in_order", orderNumber=<orderNumber>, items=[], reason=<short reason if stated, otherwise omit>, missingInfo=[].
     * If any requested quantity is <= 0 or exceeds the ordered quantity for that product, return status="invalid_quantity", orderNumber=<orderNumber>, items=[], reason=<short reason if stated, otherwise omit>, missingInfo=[].
     * Otherwise, return status="ok", orderNumber=<orderNumber>, items=[{product, quantity}, ...], reason=<concise reason stated by the user, or omit if no reason was stated>, missingInfo=[].
''';

/// Builds and registers the `getOrder` tool and `refundFlow` on a [Genkit] instance.
RefundAssistant createRefundAssistant({
  String? apiKey,
  String modelName = defaultGeminiFlashModel,
  OrderToolTracker? tracker,
  bool? isDevEnv,
}) {
  final toolTracker = tracker ?? OrderToolTracker();

  final ai = Genkit(
    plugins: [googleAI(apiKey: apiKey)],
    isDevEnv: isDevEnv,
    promptDir: null,
  );

  final getOrderTool = ai.defineTool(
    name: 'getOrder',
    description:
        'Looks up an order by its integer orderNumber and returns its exact '
        'items and quantities, or status "not found" if the order does not exist.',
    inputSchema: GetOrderInput.$schema,
    outputSchema: GetOrderOutput.$schema,
    fn: (GetOrderInput input, _) async {
      toolTracker.record(input.orderNumber);
      final entries = fakeOrders[input.orderNumber];
      if (entries == null) {
        return .response(
          GetOrderOutput(
            status: 'not found',
            orderNumber: input.orderNumber,
            items: const [],
          ),
        );
      }
      return .response(
        GetOrderOutput(
          status: 'found',
          orderNumber: input.orderNumber,
          items: [
            for (final entry in entries)
              RefundItem(product: entry.product, quantity: entry.quantity),
          ],
        ),
      );
    },
  );

  final refundFlow = ai.defineFlow(
    name: 'refundFlow',
    inputSchema: .string(),
    outputSchema: RefundResponse.$schema,
    fn: (String userMessage, _) async {
      final response = await ai.generate(
        model: googleAI.gemini(modelName),
        system: _systemPrompt,
        prompt: userMessage,
        tools: [getOrderTool],
        outputSchema: RefundResponse.$schema,
        config: GeminiOptions(temperature: 0.0),
      );

      final output = response.output;
      if (output == null) {
        throw GenkitException(
          'Model did not return a structured RefundResponse.',
          status: StatusCodes.INTERNAL,
        );
      }
      return output;
    },
  );

  return RefundAssistant(
    ai: ai,
    getOrderTool: getOrderTool,
    refundFlow: refundFlow,
    tracker: toolTracker,
    modelName: modelName,
  );
}
