import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:refund_demo/main.dart';
import 'package:refund_demo/refund_api.dart';

void main() {
  testWidgets('fills message from chip and renders structured result card', (
    WidgetTester tester,
  ) async {
    String? capturedBody;
    final mockHttp = MockClient((http.Request request) async {
      capturedBody = request.body;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode(<String, Object?>{
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
          }),
        ),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });

    final apiClient = RefundApiClient(client: mockHttp);
    await tester.pumpWidget(RefundDemoApp(apiClient: apiClient));

    expect(find.text('İade Asistanı (Genkit demo)'), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(4));

    await tester.tap(find.byType(ActionChip).first);
    await tester.pump();

    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();

    expect(capturedBody, isNotNull);
    final sent = jsonDecode(capturedBody!) as Map<String, dynamic>;
    expect(
      sent['data'],
      "1042 numaralı siparişteki 3 kahveden 2'sini iade etmek istiyorum, soğuk gelmişti.",
    );

    expect(find.text('ok'), findsOneWidget);
    expect(find.text('1042'), findsOneWidget);
    expect(find.text('Latte × 2, Sandviç × 1'), findsOneWidget);
    expect(find.text('soğuk gelmişti'), findsOneWidget);
    expect(find.text('Ham JSON'), findsOneWidget);

    await tester.tap(find.text('Ham JSON'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"result"'), findsOneWidget);
  });

  testWidgets('shows clear error for non-200 response with body', (
    WidgetTester tester,
  ) async {
    final mockHttp = MockClient((http.Request request) async {
      return http.Response('{"message":"apiKey missing"}', 500);
    });

    final apiClient = RefundApiClient(client: mockHttp);
    await tester.pumpWidget(RefundDemoApp(apiClient: apiClient));

    await tester.tap(find.byType(ActionChip).last);
    await tester.pump();
    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();

    expect(find.textContaining('HTTP 500'), findsOneWidget);
    expect(find.textContaining('apiKey missing'), findsOneWidget);
  });

  test('RefundApiClient reports connection error and timeout clearly', () async {
    final offlineClient = RefundApiClient(
      client: MockClient((http.Request _) async {
        throw http.ClientException('Connection refused');
      }),
    );

    await expectLater(
      offlineClient.callRefundFlow('Merhaba'),
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
      slowClient.callRefundFlow('Merhaba'),
      throwsA(
        isA<RefundApiException>().having(
          (e) => e.message,
          'message',
          contains('zaman aşımına uğradı'),
        ),
      ),
    );
  });
}
