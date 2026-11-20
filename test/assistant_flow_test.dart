import 'package:genkit_refund_experiment/assistant_flow.dart';
import 'package:genkit_refund_experiment/refund_assistant.dart';
import 'package:genkit_refund_experiment/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('getOrder unit prices', () {
    late RefundAssistant assistant;

    setUp(() {
      assistant = createRefundAssistant(apiKey: 'dummy-key', isDevEnv: false);
    });

    tearDown(() async {
      await assistant.ai.shutdown();
    });

    test('returns TL unit prices for all fake orders', () async {
      final r1042 = (await assistant.getOrderTool(
        GetOrderInput(orderNumber: 1042),
      )).output;
      expect(r1042.items.length, 2);
      expect(r1042.items[0].product, 'Latte');
      expect(r1042.items[0].quantity, 3);
      expect(r1042.items[0].unitPrice, 95);
      expect(r1042.items[1].product, 'Cheesecake');
      expect(r1042.items[1].quantity, 1);
      expect(r1042.items[1].unitPrice, 140);

      final r1043 = (await assistant.getOrderTool(
        GetOrderInput(orderNumber: 1043),
      )).output;
      expect(r1043.items[0].product, 'Su');
      expect(r1043.items[0].unitPrice, 20);
      expect(r1043.items[1].product, 'Sandviç');
      expect(r1043.items[1].unitPrice, 120);

      final r1044 = (await assistant.getOrderTool(
        GetOrderInput(orderNumber: 1044),
      )).output;
      expect(r1044.items[0].product, 'Filtre kahve');
      expect(r1044.items[0].unitPrice, 80);
    });
  });

  group('getShipment tool', () {
    late RefundAssistant assistant;
    late OrderAssistantFlowBundle bundle;

    setUp(() {
      assistant = createRefundAssistant(apiKey: 'dummy-key', isDevEnv: false);
      bundle = createAssistantFlow(assistant);
    });

    tearDown(() async {
      await assistant.ai.shutdown();
    });

    test('returns delivered steps for 1042', () async {
      final result = (await bundle.getShipmentTool(
        GetShipmentInput(orderNumber: 1042),
      )).output;
      expect(result.status, 'found');
      expect(result.shipmentStatus, 'delivered');
      expect(result.steps.length, 4);
      expect(result.steps.every((s) => s.done), isTrue);
      expect(result.steps[0].label, 'Hazırlandı');
      expect(result.steps[3].label, 'Teslim edildi');
    });

    test('returns in-transit steps for 1043', () async {
      final result = (await bundle.getShipmentTool(
        GetShipmentInput(orderNumber: 1043),
      )).output;
      expect(result.status, 'found');
      expect(result.shipmentStatus, 'in_transit');
      expect(result.steps.map((s) => s.done).toList(), [
        true,
        true,
        false,
        false,
      ]);
      expect(result.steps[1].label, 'Kargoya verildi');
      expect(result.steps[2].label, 'Dağıtımda');
    });

    test('returns preparing steps for 1044', () async {
      final result = (await bundle.getShipmentTool(
        GetShipmentInput(orderNumber: 1044),
      )).output;
      expect(result.status, 'found');
      expect(result.shipmentStatus, 'preparing');
      expect(result.steps.every((s) => !s.done), isTrue);
      expect(result.steps[0].label, 'Hazırlandı');
    });

    test('returns not found for unknown order', () async {
      final result = (await bundle.getShipmentTool(
        GetShipmentInput(orderNumber: 9999),
      )).output;
      expect(result.status, 'not found');
      expect(result.shipmentStatus, '');
      expect(result.steps, isEmpty);
    });
  });

  group('AssistantResponse schema and prompt', () {
    test('marks every field required (no nullable fields)', () {
      final def = AssistantResponse.$schema.schemaMetadata?.definition;
      expect(def, isNotNull);
      final requiredFields = def!['required'] as List<Object?>;
      expect(
        requiredFields,
        containsAll(<String>[
          'view',
          'message',
          'orderNumber',
          'items',
          'refundStatus',
          'shipmentSteps',
          'suggestions',
        ]),
      );
    });

    test('parses order_details with integer unitPrice and empty lists', () {
      final parsed = AssistantResponse.$schema.parse(<String, Object?>{
        'view': 'order_details',
        'message': '1044 numaralı siparişinizin detayları aşağıdadır.',
        'orderNumber': '1044',
        'items': <Object?>[
          <String, Object?>{
            'product': 'Filtre kahve',
            'quantity': 1,
            'unitPrice': 80,
          },
        ],
        'refundStatus': 'none',
        'shipmentSteps': <Object?>[],
        'suggestions': <Object?>[],
      });

      expect(parsed.view, 'order_details');
      expect(parsed.orderNumber, '1044');
      expect(parsed.items.length, 1);
      expect(parsed.items.first.product, 'Filtre kahve');
      expect(parsed.items.first.quantity, 1);
      expect(parsed.items.first.unitPrice, 80.0);
      expect(parsed.refundStatus, 'none');
      expect(parsed.shipmentSteps, isEmpty);
      expect(parsed.suggestions, isEmpty);
    });

    test('parses shipment_tracking and clarification views', () {
      final tracking = AssistantResponse.$schema.parse(<String, Object?>{
        'view': 'shipment_tracking',
        'message': '1043 numaralı siparişiniz kargoda.',
        'orderNumber': '1043',
        'items': <Object?>[],
        'refundStatus': 'none',
        'shipmentSteps': <Object?>[
          <String, Object?>{
            'label': 'Hazırlandı',
            'done': true,
            'time': '10:00',
          },
        ],
        'suggestions': <Object?>[],
      });
      expect(tracking.shipmentSteps.length, 1);
      expect(tracking.shipmentSteps.first.done, isTrue);

      final clarify = AssistantResponse.$schema.parse(<String, Object?>{
        'view': 'clarification',
        'message': 'Hangi sipariş numarası için işlem yapmak istiyorsunuz?',
        'orderNumber': '',
        'items': <Object?>[],
        'refundStatus': 'none',
        'shipmentSteps': <Object?>[],
        'suggestions': <Object?>["1042'deki 2 latteyi iade etmek istiyorum."],
      });
      expect(clarify.orderNumber, '');
      expect(clarify.suggestions.length, 1);
    });

    test('injects today date into system prompt', () {
      final prompt = buildAssistantSystemPrompt(DateTime(2026, 11, 20));
      expect(prompt, contains('2026-11-20'));
    });
  });

  group('assistantFlow HTTP routing', () {
    late RefundAssistant assistant;
    late OrderAssistantFlowBundle bundle;

    setUp(() {
      assistant = createRefundAssistant(apiKey: 'dummy-key', isDevEnv: false);
      bundle = createAssistantFlow(assistant);
    });

    tearDown(() async {
      await assistant.ai.shutdown();
    });

    test('mounts POST /assistantFlow with localhost CORS', () async {
      final handler = createRefundServerHandler(
        assistant,
        assistantFlow: bundle.assistantFlow,
        enableRequestLogging: false,
      );

      final preflightRes = await handler(
        Request(
          'OPTIONS',
          Uri.parse('http://localhost:8080/assistantFlow'),
          headers: <String, String>{'origin': 'http://localhost:50000'},
        ),
      );
      expect(preflightRes.statusCode, 204);
      expect(
        preflightRes.headers['access-control-allow-origin'],
        'http://localhost:50000',
      );

      final badBodyRes = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost:8080/assistantFlow'),
          headers: <String, String>{
            'origin': 'http://localhost:50000',
            'content-type': 'application/json',
          },
          body: 'not-json',
        ),
      );
      expect(badBodyRes.statusCode, 400);
      expect(
        badBodyRes.headers['access-control-allow-origin'],
        'http://localhost:50000',
      );

      final refundRes = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost:8080/refundFlow'),
          headers: <String, String>{'content-type': 'application/json'},
          body: 'not-json',
        ),
      );
      expect(refundRes.statusCode, 400);
    });
  });
}
