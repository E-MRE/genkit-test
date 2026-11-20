import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:genkit_refund_experiment/env.dart';
import 'package:genkit_refund_experiment/eval_runner.dart';
import 'package:genkit_refund_experiment/refund_assistant.dart';
import 'package:genkit_refund_experiment/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('env helper', () {
    test('reads GEMINI_API_KEY from a .env file with quotes and comments', () {
      final tempDir = Directory.systemTemp.createTempSync('genkit_env_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final envFile = File('${tempDir.path}/.env')
        ..writeAsStringSync(
          '# Comment line\n'
          'OTHER=value\n'
          'GEMINI_API_KEY="test-key-123"\n',
        );

      expect(
        readEnvVar('OTHER', envFile: envFile, environment: const {}),
        'value',
      );
      expect(
        readEnvVar('GEMINI_API_KEY', envFile: envFile, environment: const {}),
        'test-key-123',
      );
      expect(
        readEnvVar('MISSING_KEY', envFile: envFile, environment: const {}),
        isNull,
      );
    });
  });

  group('getOrder tool and schemas', () {
    late RefundAssistant assistant;

    setUp(() {
      assistant = createRefundAssistant(apiKey: 'dummy-key', isDevEnv: false);
    });

    tearDown(() async {
      await assistant.ai.shutdown();
    });

    test('returns exact fake order items and counts every call', () async {
      expect(assistant.tracker.callCount, 0);

      final r1042 = (await assistant.getOrderTool(
        GetOrderInput(orderNumber: 1042),
      )).output;
      expect(r1042.status, 'found');
      expect(r1042.orderNumber, 1042);
      expect(r1042.items.map((i) => (i.product, i.quantity)).toList(), [
        ('Latte', 3),
        ('Cheesecake', 1),
      ]);

      final r1043 = (await assistant.getOrderTool(
        GetOrderInput(orderNumber: 1043),
      )).output;
      expect(r1043.status, 'found');
      expect(r1043.items.map((i) => (i.product, i.quantity)).toList(), [
        ('Su', 2),
        ('Sandviç', 1),
      ]);

      final r1044 = (await assistant.getOrderTool(
        GetOrderInput(orderNumber: 1044),
      )).output;
      expect(r1044.status, 'found');
      expect(r1044.items.map((i) => (i.product, i.quantity)).toList(), [
        ('Filtre kahve', 1),
      ]);

      final r9999 = (await assistant.getOrderTool(
        GetOrderInput(orderNumber: 9999),
      )).output;
      expect(r9999.status, 'not found');
      expect(r9999.items, isEmpty);

      expect(assistant.tracker.callCount, 4);
      expect(assistant.tracker.calledOrderNumbers, [1042, 1043, 1044, 9999]);

      assistant.tracker.reset();
      expect(assistant.tracker.callCount, 0);
    });

    test('RefundResponse schema parses nullable fields and enum status', () {
      final parsed = RefundResponse.$schema.parse({
        'status': 'missing_info',
        'orderNumber': null,
        'items': <Object?>[],
        'reason': null,
        'missingInfo': ['orderNumber'],
      });

      expect(parsed.status, 'missing_info');
      expect(parsed.orderNumber, isNull);
      expect(parsed.items, isEmpty);
      expect(parsed.reason, isNull);
      expect(parsed.missingInfo, ['orderNumber']);
    });
  });

  group('eval matching and formatting', () {
    test('defines all 10 cases', () {
      expect(refundEvalCases.length, 10);
      expect(refundEvalCases.map((c) => c.id).toList(), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ]);
    });

    test('matches items regardless of ordering (case 8)', () {
      final case8 = refundEvalCases.firstWhere((c) => c.id == 8);
      final reversedItems = RefundResponse(
        status: 'ok',
        orderNumber: 1042,
        items: [
          RefundItem(product: 'Latte', quantity: 1),
          RefundItem(product: 'Cheesecake', quantity: 1),
        ],
        reason: null,
        missingInfo: const [],
      );

      expect(matchesExpected(case8, reversedItems), isTrue);

      final wrongQuantity = RefundResponse(
        status: 'ok',
        orderNumber: 1042,
        items: [
          RefundItem(product: 'Latte', quantity: 2),
          RefundItem(product: 'Cheesecake', quantity: 1),
        ],
        reason: null,
        missingInfo: const [],
      );
      expect(matchesExpected(case8, wrongQuantity), isFalse);
    });

    test('formats table with required columns and writes eval.json', () async {
      final tempDir = Directory.systemTemp.createTempSync('genkit_eval_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final sample = [
        EvalCaseResult(
          evalCase: refundEvalCases.first,
          actual: RefundResponse(
            status: 'ok',
            orderNumber: 1042,
            items: [RefundItem(product: 'Latte', quantity: 2)],
            reason: 'soğuk gelmişti',
            missingInfo: const [],
          ),
          toolCalled: true,
          toolCallCount: 1,
          calledOrderNumbers: const [1042],
          passed: true,
        ),
      ];

      final table = formatEvalTable(sample);
      expect(table, contains('case'));
      expect(table, contains('expected status'));
      expect(table, contains('actual status'));
      expect(table, contains('tool called (yes/no)'));
      expect(table, contains('pass/fail'));
      expect(table, contains('error'));
      expect(table, contains('| 1    | ok'));
      expect(table, contains('| yes'));
      expect(table, contains('| pass'));

      final outPath = '${tempDir.path}/results/eval.json';
      await writeEvalJson(
        sample,
        modelName: defaultGeminiFlashModel,
        outputPath: outPath,
      );

      final decoded =
          jsonDecode(File(outPath).readAsStringSync()) as Map<String, dynamic>;
      expect(decoded['summary']['passed'], 1);
      expect(decoded['cases'], hasLength(1));
    });
  });

  group('pass rule and runner', () {
    final ok1 = RefundResponse(
      status: 'ok',
      orderNumber: 1042,
      items: [RefundItem(product: 'Latte', quantity: 2)],
      reason: null,
      missingInfo: const [],
    );
    final missing = RefundResponse(
      status: 'missing_info',
      orderNumber: null,
      items: const [],
      reason: null,
      missingInfo: const ['orderNumber'],
    );

    test('tool must be called except for cases 4 and 9', () {
      final case1 = refundEvalCases.firstWhere((c) => c.id == 1);
      final case4 = refundEvalCases.firstWhere((c) => c.id == 4);
      final case9 = refundEvalCases.firstWhere((c) => c.id == 9);
      for (final c in refundEvalCases) {
        expect(
          c.expectToolCall,
          !(c.id == 4 || c.id == 9),
          reason: 'case ${c.id}',
        );
      }
      expect(casePasses(case1, ok1, toolCalled: true), isTrue);
      expect(casePasses(case1, ok1, toolCalled: false), isFalse);
      expect(casePasses(case4, missing, toolCalled: false), isTrue);
      expect(casePasses(case4, missing, toolCalled: true), isFalse);
      final notRefund = RefundResponse(
        status: 'not_refund_request',
        orderNumber: null,
        items: const [],
        reason: null,
        missingInfo: const [],
      );
      expect(casePasses(case9, notRefund, toolCalled: false), isTrue);
      expect(casePasses(case9, notRefund, toolCalled: true), isFalse);
    });

    test('shortError truncates to 80 chars on one line', () {
      final short = shortError('a\n' * 100);
      expect(short.length, 80);
      expect(short, isNot(contains('\n')));
      expect(shortError('boom'), 'boom');
    });

    test('quota/transient errors are retried up to 3 attempts; other errors are not; stuck case times out', () async {
      final assistant = createRefundAssistant(
        apiKey: 'dummy-key',
        isDevEnv: false,
      );
      addTearDown(assistant.ai.shutdown);
      final case4 = refundEvalCases.firstWhere((c) => c.id == 4);

      var calls = 0;
      var results = await runEvalSuite(
        assistant,
        cases: [case4],
        delayBetweenCases: Duration.zero,
        retryDelay: Duration.zero,
        runFlow: (_) async {
          calls++;
          if (calls == 1) throw Exception('429 RESOURCE_EXHAUSTED quota');
          return missing;
        },
      );
      expect(calls, 2);
      expect(results.single.passed, isTrue);
      expect(results.single.error, isNull);

      calls = 0;
      results = await runEvalSuite(
        assistant,
        cases: [case4],
        delayBetweenCases: Duration.zero,
        retryDelay: Duration.zero,
        runFlow: (_) async {
          calls++;
          throw Exception('429 RESOURCE_EXHAUSTED ${'x' * 200}');
        },
      );
      expect(calls, 3);
      expect(results.single.passed, isFalse);
      expect(results.single.error, contains('RESOURCE_EXHAUSTED'));
      final table = formatEvalTable(results);
      expect(table, contains('...'));

      results = await runEvalSuite(
        assistant,
        cases: [case4],
        delayBetweenCases: Duration.zero,
        caseTimeout: const Duration(milliseconds: 50),
        runFlow: (_) => Completer<RefundResponse>().future,
      );
      expect(results.single.passed, isFalse);
      expect(results.single.error, contains('ERROR: timeout'));

      calls = 0;
      results = await runEvalSuite(
        assistant,
        cases: [case4],
        delayBetweenCases: Duration.zero,
        retryDelay: Duration.zero,
        runFlow: (_) async {
          calls++;
          throw Exception('bad request');
        },
      );
      expect(calls, 1);
      expect(results.single.passed, isFalse);
    });
  });

  group('HTTP server handler', () {
    late RefundAssistant assistant;

    setUp(() {
      assistant = createRefundAssistant(apiKey: 'dummy-key', isDevEnv: false);
    });

    tearDown(() async {
      await assistant.ai.shutdown();
    });

    test('serves /health and mounts /refundFlow via genkit_shelf', () async {
      final handler = createRefundServerHandler(
        assistant,
        enableRequestLogging: false,
      );

      final healthRes = await handler(
        Request('GET', Uri.parse('http://localhost:8080/health')),
      );
      expect(healthRes.statusCode, 200);
      expect(await healthRes.readAsString(), 'OK');

      final missingRes = await handler(
        Request('POST', Uri.parse('http://localhost:8080/doesNotExist')),
      );
      expect(missingRes.statusCode, 404);

      final badBodyRes = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost:8080/refundFlow'),
          headers: {'content-type': 'application/json'},
          body: 'not-json',
        ),
      );
      expect(badBodyRes.statusCode, 400);
    });

    test('handles localhost CORS preflight and response headers', () async {
      final handler = createRefundServerHandler(
        assistant,
        enableRequestLogging: false,
      );

      final preflightRes = await handler(
        Request(
          'OPTIONS',
          Uri.parse('http://localhost:8080/refundFlow'),
          headers: {'origin': 'http://localhost:54321'},
        ),
      );
      expect(preflightRes.statusCode, 204);
      expect(
        preflightRes.headers['access-control-allow-origin'],
        'http://localhost:54321',
      );
      expect(
        preflightRes.headers['access-control-allow-methods'],
        'POST, OPTIONS',
      );
      expect(
        preflightRes.headers['access-control-allow-headers'],
        'Content-Type',
      );

      final postRes = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost:8080/refundFlow'),
          headers: {
            'origin': 'http://127.0.0.1:4200',
            'content-type': 'application/json',
          },
          body: 'not-json',
        ),
      );
      expect(postRes.statusCode, 400);
      expect(
        postRes.headers['access-control-allow-origin'],
        'http://127.0.0.1:4200',
      );

      final foreignRes = await handler(
        Request(
          'OPTIONS',
          Uri.parse('http://localhost:8080/refundFlow'),
          headers: {'origin': 'https://example.com'},
        ),
      );
      expect(foreignRes.headers['access-control-allow-origin'], isNull);
    });
  });
}
