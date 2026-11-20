import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

import 'refund_assistant.dart';

part 'assistant_flow.g.dart';

/// Fake in-memory shipment step record.
class FakeShipmentStep {
  const FakeShipmentStep({
    required this.label,
    required this.done,
    required this.time,
  });

  final String label;
  final bool done;
  final String time;
}

/// Fake in-memory shipment record.
class FakeShipmentRecord {
  const FakeShipmentRecord({required this.state, required this.steps});

  final String state;
  final List<FakeShipmentStep> steps;
}

/// Fake in-memory shipment catalog used by `getShipment`.
const Map<int, FakeShipmentRecord> fakeShipments = <int, FakeShipmentRecord>{
  1042: FakeShipmentRecord(
    state: 'delivered',
    steps: <FakeShipmentStep>[
      FakeShipmentStep(label: 'Hazırlandı', done: true, time: '09:10'),
      FakeShipmentStep(label: 'Kargoya verildi', done: true, time: '11:30'),
      FakeShipmentStep(label: 'Dağıtımda', done: true, time: '14:05'),
      FakeShipmentStep(label: 'Teslim edildi', done: true, time: '16:20'),
    ],
  ),
  1043: FakeShipmentRecord(
    state: 'in_transit',
    steps: <FakeShipmentStep>[
      FakeShipmentStep(label: 'Hazırlandı', done: true, time: '10:00'),
      FakeShipmentStep(label: 'Kargoya verildi', done: true, time: '13:15'),
      FakeShipmentStep(label: 'Dağıtımda', done: false, time: 'Bekleniyor'),
      FakeShipmentStep(label: 'Teslim edildi', done: false, time: 'Bekleniyor'),
    ],
  ),
  1044: FakeShipmentRecord(
    state: 'preparing',
    steps: <FakeShipmentStep>[
      FakeShipmentStep(label: 'Hazırlandı', done: false, time: 'Hazırlanıyor'),
      FakeShipmentStep(
        label: 'Kargoya verildi',
        done: false,
        time: 'Bekleniyor',
      ),
      FakeShipmentStep(label: 'Dağıtımda', done: false, time: 'Bekleniyor'),
      FakeShipmentStep(label: 'Teslim edildi', done: false, time: 'Bekleniyor'),
    ],
  ),
};

/// Input schema for the `getShipment` tool.
@Schema(description: 'Lookup parameters for retrieving shipment tracking.')
abstract class $GetShipmentInput {
  @Field(description: 'The integer order number to look up, e.g. 1043.')
  int get orderNumber;
}

/// One step in a shipment tracking timeline.
@Schema(description: 'A single shipment status step.')
abstract class $ShipmentStep {
  @Field(description: 'Short Turkish step label.')
  String get label;

  @Field(description: 'Whether this step is completed.')
  bool get done;

  @Field(description: 'Short time or status text for this step.')
  String get time;
}

/// Output schema returned by the `getShipment` tool.
@Schema(description: 'Result of looking up shipment tracking by orderNumber.')
abstract class $GetShipmentOutput {
  @StringField(
    enumValues: ['found', 'not found'],
    description: 'Whether shipment tracking exists ("found") or ("not found").',
  )
  String get status;

  @Field(description: 'The order number that was queried.')
  int get orderNumber;

  @Field(
    description:
        'Summary shipment state ("delivered", "in_transit", "preparing") or empty string if not found.',
  )
  String get shipmentStatus;

  @Field(description: 'Ordered tracking steps; empty when not found.')
  List<$ShipmentStep> get steps;
}

/// Product line item in [AssistantResponse].
@Schema(description: 'A product, quantity, and unit price in TL.')
abstract class $AssistantItem {
  @Field(description: 'Exact product name returned by getOrder.')
  String get product;

  @IntegerField(minimum: 1, description: 'Positive integer quantity.')
  int get quantity;

  @DoubleField(
    minimum: 0,
    description: 'Exact unit price in TL returned by getOrder.',
  )
  double get unitPrice;
}

/// Non-nullable structured output schema for `assistantFlow`.
@Schema(
  description:
      'Structured assistant response choosing a UI card view and data.',
)
abstract class $AssistantResponse {
  @StringField(
    enumValues: [
      'refund_summary',
      'shipment_tracking',
      'order_details',
      'clarification',
      'unsupported',
    ],
    description: 'Which UI card to display for this response.',
  )
  String get view;

  @Field(description: 'One short Turkish sentence shown above the card.')
  String get message;

  @Field(
    description:
        'Order number as string (e.g. "1042"), or empty string "" if none.',
  )
  String get orderNumber;

  @Field(
    description:
        'Relevant items with exact product names and unitPrice from getOrder; empty list [] if not relevant.',
  )
  List<$AssistantItem> get items;

  @StringField(
    enumValues: [
      'none',
      'ok',
      'invalid_quantity',
      'item_not_in_order',
      'order_not_found',
    ],
    description:
        'Refund validation status for refund_summary; "none" for all other views.',
  )
  String get refundStatus;

  @Field(
    description:
        'Shipment steps copied from getShipment for shipment_tracking; empty list [] otherwise.',
  )
  List<$ShipmentStep> get shipmentSteps;

  @Field(
    description:
        'Short Turkish follow-up prompts for clarification or unsupported views; empty list [] otherwise.',
  )
  List<String> get suggestions;
}

/// Container holding the `getShipment` tool and `assistantFlow`.
class OrderAssistantFlowBundle {
  OrderAssistantFlowBundle({
    required this.getShipmentTool,
    required this.assistantFlow,
  });

  final Tool<GetShipmentInput, GetShipmentOutput> getShipmentTool;
  final Flow<String, AssistantResponse, void, void> assistantFlow;
}

/// Formats [date] as `YYYY-MM-DD` for injection into the system prompt.
String formatAssistantPromptDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Builds the runtime system prompt for `assistantFlow` including [today].
String buildAssistantSystemPrompt(DateTime today) {
  final dateText = formatAssistantPromptDate(today);
  return '''
You are a Turkish order support assistant ("Sipariş Asistanı").
Today's date is $dateText.

Your job is to classify the user's Turkish message, call the appropriate tool(s) when an order number is provided, and return a structured JSON response that picks the UI card (`view`) and fills every required field.

Critical rules:
- NEVER invent order numbers, products, quantities, unit prices, or shipment steps.
- Only call `getOrder` or `getShipment` when the user explicitly provides an order number.
- Every field in the JSON schema is non-nullable: use "" for an absent `orderNumber`, "none" for `refundStatus` when not a refund, and [] for unused lists.
- `message` must always be ONE short, natural Turkish sentence shown above the card.

Intent routing:
1. Refund request that includes an order number:
   - Call `getOrder(orderNumber)` first.
   - Set `view="refund_summary"`, `orderNumber="<orderNumber>"`, `shipmentSteps=[]`, `suggestions=[]`.
   - If `getOrder` returns status="not found": set `refundStatus="order_not_found"`, `items=[]`.
   - Else validate requested item(s) against the returned order. Map colloquial or partial item references to the exact product name returned by `getOrder`; "all" or "the whole order" means every item at full quantity. Always copy exact `product` and `unitPrice` from `getOrder`:
     * Requested product not in order -> `refundStatus="item_not_in_order"`, `items=[]`.
     * Requested quantity <= 0 or > ordered quantity -> `refundStatus="invalid_quantity"`, `items=[]`.
     * Valid -> `refundStatus="ok"`, `items=[{product, quantity, unitPrice}, ...]` for the refunded quantities.

2. Shipment / cargo tracking request that includes an order number:
   - Call `getShipment(orderNumber)` first.
   - If `getShipment` returns status="found":
     Set `view="shipment_tracking"`, `orderNumber="<orderNumber>"`, `shipmentSteps` copied exactly from `getShipment`, `items=[]`, `refundStatus="none"`, `suggestions=[]`.
   - If `getShipment` returns status="not found":
     Set `view="clarification"`, `orderNumber="<orderNumber>"`, `items=[]`, `refundStatus="none"`, `shipmentSteps=[]`, and provide 2-3 short Turkish follow-up `suggestions`.

3. Order details / contents inquiry that includes an order number:
   - Call `getOrder(orderNumber)` first.
   - If `getOrder` returns status="found":
     Set `view="order_details"`, `orderNumber="<orderNumber>"`, `items` copied exactly (product, quantity, unitPrice) from `getOrder`, `refundStatus="none"`, `shipmentSteps=[]`, `suggestions=[]`.
   - If `getOrder` returns status="not found":
     Set `view="clarification"`, `orderNumber="<orderNumber>"`, `items=[]`, `refundStatus="none"`, `shipmentSteps=[]`, and provide 2-3 short Turkish follow-up `suggestions`.

4. Order, refund or shipment request that has NO order number:
   - Do NOT call any tool.
   - Set `view="clarification"`, `orderNumber=""`, `items=[]`, `refundStatus="none"`, `shipmentSteps=[]`.
   - Provide 2-3 short generic Turkish `suggestions` asking for the missing information, such as "Sipariş numaramı yazayım: …" or "İade etmek istediğim ürünü yazayım: …".

5. Unrelated / out-of-scope request:
   - Do NOT call any tool.
   - Set `view="unsupported"`, `orderNumber=""`, `items=[]`, `refundStatus="none"`, `shipmentSteps=[]`.
   - Provide 2-3 short Turkish `suggestions` naming the supported actions (refund, shipment tracking, order details).
''';
}

/// Registers `getShipment` and `assistantFlow` on [refundAssistant.ai].
OrderAssistantFlowBundle createAssistantFlow(
  RefundAssistant refundAssistant, {
  DateTime Function()? now,
}) {
  final ai = refundAssistant.ai;
  final clock = now ?? DateTime.now;

  final getShipmentTool = ai.defineTool(
    name: 'getShipment',
    description:
        'Looks up shipment tracking steps for an integer orderNumber, or '
        'returns status "not found" if no shipment exists.',
    inputSchema: GetShipmentInput.$schema,
    outputSchema: GetShipmentOutput.$schema,
    fn: (GetShipmentInput input, _) async {
      final record = fakeShipments[input.orderNumber];
      if (record == null) {
        return .response(
          GetShipmentOutput(
            status: 'not found',
            orderNumber: input.orderNumber,
            shipmentStatus: '',
            steps: const [],
          ),
        );
      }
      return .response(
        GetShipmentOutput(
          status: 'found',
          orderNumber: input.orderNumber,
          shipmentStatus: record.state,
          steps: [
            for (final step in record.steps)
              ShipmentStep(
                label: step.label,
                done: step.done,
                time: step.time,
              ),
          ],
        ),
      );
    },
  );

  final assistantFlow = ai.defineFlow(
    name: 'assistantFlow',
    inputSchema: .string(),
    outputSchema: AssistantResponse.$schema,
    fn: (String userMessage, _) async {
      final response = await ai.generate(
        model: googleAI.gemini(refundAssistant.modelName),
        system: buildAssistantSystemPrompt(clock()),
        prompt: userMessage,
        tools: [refundAssistant.getOrderTool, getShipmentTool],
        outputSchema: AssistantResponse.$schema,
        config: GeminiOptions(temperature: 0.0),
      );

      final output = response.output;
      if (output == null) {
        throw GenkitException(
          'Model did not return a structured AssistantResponse.',
          status: StatusCodes.INTERNAL,
        );
      }
      return output;
    },
  );

  return OrderAssistantFlowBundle(
    getShipmentTool: getShipmentTool,
    assistantFlow: assistantFlow,
  );
}
