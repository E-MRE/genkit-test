import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:refund_demo/assistant_cards.dart';
import 'package:refund_demo/main.dart';
import 'package:refund_demo/refund_api.dart';

http.Response _jsonUtf8Response(Map<String, Object?> payload) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(payload)),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

void main() {
  test('iconForProduct maps Turkish coffee/food products and default', () {
    expect(iconForProduct('Latte'), Icons.coffee);
    expect(iconForProduct('Filtre kahve'), Icons.coffee);
    expect(iconForProduct('Cheesecake'), Icons.cake);
    expect(iconForProduct('Su'), Icons.water_drop);
    expect(iconForProduct('Sandviç'), Icons.lunch_dining);
    expect(iconForProduct('Bilinmeyen'), Icons.shopping_bag);
  });

  test('resolveFlowUrl swaps between refundFlow and assistantFlow', () {
    expect(
      resolveFlowUrl('http://localhost:8080/refundFlow', 'assistantFlow'),
      'http://localhost:8080/assistantFlow',
    );
    expect(
      resolveFlowUrl('http://localhost:8080/assistantFlow', 'refundFlow'),
      'http://localhost:8080/refundFlow',
    );
    expect(
      resolveFlowUrl('http://localhost:8080', 'assistantFlow'),
      'http://localhost:8080/assistantFlow',
    );
  });

  testWidgets('assistantFlow chat renders all 5 card views and computes total', (
    WidgetTester tester,
  ) async {
    final mockHttp = MockClient((http.Request request) async {
      final decoded = jsonDecode(request.body) as Map<String, dynamic>;
      final message = decoded['data'] as String;

      if (message.contains('1042')) {
        return _jsonUtf8Response(<String, Object?>{
          'result': <String, Object?>{
            'view': 'refund_summary',
            'message': '1042 numaralı sipariş için iade özeti hazır.',
            'orderNumber': '1042',
            'items': <Object?>[
              <String, Object?>{
                'product': 'Latte',
                'quantity': 2,
                'unitPrice': 95,
              },
            ],
            'refundStatus': 'ok',
            'shipmentSteps': <Object?>[],
            'suggestions': <Object?>[],
          },
        });
      }
      if (message.contains('1043')) {
        return _jsonUtf8Response(<String, Object?>{
          'result': <String, Object?>{
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
              <String, Object?>{
                'label': 'Kargoya verildi',
                'done': true,
                'time': '13:15',
              },
              <String, Object?>{
                'label': 'Dağıtımda',
                'done': false,
                'time': 'Bekleniyor',
              },
            ],
            'suggestions': <Object?>[],
          },
        });
      }
      if (message.contains('1044')) {
        return _jsonUtf8Response(<String, Object?>{
          'result': <String, Object?>{
            'view': 'order_details',
            'message': '1044 numaralı siparişinizin fişi aşağıdadır.',
            'orderNumber': '1044',
            'items': <Object?>[
              <String, Object?>{
                'product': 'Filtre kahve',
                'quantity': 2,
                'unitPrice': 80,
              },
            ],
            'refundStatus': 'none',
            'shipmentSteps': <Object?>[],
            'suggestions': <Object?>[],
          },
        });
      }
      if (message.contains('iade')) {
        return _jsonUtf8Response(<String, Object?>{
          'result': <String, Object?>{
            'view': 'clarification',
            'message': 'Hangi sipariş numarası için iade istiyorsunuz?',
            'orderNumber': '',
            'items': <Object?>[],
            'refundStatus': 'none',
            'shipmentSteps': <Object?>[],
            'suggestions': <Object?>['1044 numaralı siparişte ne vardı?'],
          },
        });
      }
      return _jsonUtf8Response(<String, Object?>{
        'result': <String, Object?>{
          'view': 'unsupported',
          'message': 'Yalnızca sipariş ve iade konularında yardımcı olabilirim.',
          'orderNumber': '',
          'items': <Object?>[],
          'refundStatus': 'none',
          'shipmentSteps': <Object?>[],
          'suggestions': <Object?>['Kargom nerede? Sipariş 1043'],
        },
      });
    });

    final apiClient = RefundApiClient(client: mockHttp);
    await tester.pumpWidget(RefundDemoApp(apiClient: apiClient));

    expect(find.text('Sipariş Asistanı (Genkit demo)'), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(5));

    // 1. refund_summary
    await tester.tap(find.text("1042'deki 2 latteyi iade etmek istiyorum."));
    await tester.pumpAndSettle();
    expect(find.text('ok'), findsOneWidget);
    expect(find.text('Latte'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('card_refund_summary')), findsOneWidget);

    // 2. shipment_tracking
    await tester.tap(find.text('Kargom nerede? Sipariş 1043'));
    await tester.pumpAndSettle();
    expect(find.text('Kargoya verildi'), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('card_shipment_tracking')),
      findsOneWidget,
    );

    // 3. order_details with Flutter-computed total (2 * 80 = 160 TL)
    await tester.tap(find.text('1044 numaralı siparişte ne vardı?'));
    await tester.pumpAndSettle();
    expect(find.text('160 TL'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('card_order_details')), findsOneWidget);

    // 4. clarification
    await tester.tap(find.text('Siparişimi iade etmek istiyorum.'));
    await tester.pumpAndSettle();
    expect(find.text('Biraz daha bilgi gerekli'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('card_clarification')), findsOneWidget);

    // 5. unsupported
    await tester.tap(find.text('Bugün hava nasıl?'));
    await tester.pumpAndSettle();
    expect(find.text('Bu konuda yardımcı olamıyorum'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('card_unsupported')), findsOneWidget);
  });

  testWidgets('app bar toggle switches to legacy refundFlow view', (
    WidgetTester tester,
  ) async {
    final mockHttp = MockClient((http.Request request) async {
      expect(request.url.path, '/refundFlow');
      return _jsonUtf8Response(<String, Object?>{
        'result': <String, Object?>{
          'status': 'ok',
          'orderNumber': 1042,
          'items': <Object?>[
            <String, Object?>{'product': 'Latte', 'quantity': 2},
            <String, Object?>{'product': 'Sandviç', 'quantity': 1},
          ],
          'reason': 'soğuk gelmişti',
          'missingInfo': <Object?>[],
        },
      });
    });

    final apiClient = RefundApiClient(client: mockHttp);
    await tester.pumpWidget(RefundDemoApp(apiClient: apiClient));

    await tester.tap(find.text('refundFlow'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ActionChip).first);
    await tester.pump();
    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();

    expect(find.text('ok'), findsOneWidget);
    expect(find.text('Latte × 2, Sandviç × 1'), findsOneWidget);
    expect(find.text('soğuk gelmişti'), findsOneWidget);

    await tester.ensureVisible(find.text('Ham JSON'));
    await tester.tap(find.text('Ham JSON'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"result"'), findsOneWidget);
  });

  test('RefundApiClient reports offline, timeout, and non-200 errors', () async {
    final offlineClient = RefundApiClient(
      client: MockClient((http.Request _) async {
        throw http.ClientException('Connection refused');
      }),
    );
    await expectLater(
      offlineClient.callAssistantFlow('Merhaba'),
      throwsA(
        isA<RefundApiException>().having(
          (e) => e.message,
          'message',
          contains('Sunucuya bağlanılamadı'),
        ),
      ),
    );

    final slowClient = RefundApiClient(
      timeout: const Duration(milliseconds: 20),
      client: MockClient((http.Request _) => Completer<http.Response>().future),
    );
    await expectLater(
      slowClient.callAssistantFlow('Merhaba'),
      throwsA(
        isA<RefundApiException>().having(
          (e) => e.message,
          'message',
          contains('zaman aşımına uğradı'),
        ),
      ),
    );

    final errorClient = RefundApiClient(
      client: MockClient(
        (http.Request _) async => http.Response('{"message":"boom"}', 500),
      ),
    );
    await expectLater(
      errorClient.callAssistantFlow('Merhaba'),
      throwsA(
        isA<RefundApiException>().having(
          (e) => e.message,
          'message',
          allOf(contains('HTTP 500'), contains('boom')),
        ),
      ),
    );
  });
}
