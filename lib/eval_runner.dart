import 'dart:convert';
import 'dart:io';

import 'refund_assistant.dart';

/// Expected product/quantity pair for an evaluation case.
class ExpectedItem {
  const ExpectedItem(this.product, this.quantity);

  final String product;
  final int quantity;

  Map<String, Object?> toJson() => {
    'product': product,
    'quantity': quantity,
  };
}

/// Definition of one refund evaluation test case.
class EvalCase {
  const EvalCase({
    required this.id,
    required this.input,
    required this.expectedStatus,
    required this.expectedOrderNumber,
    required this.expectedItems,
    this.note,
  });

  final int id;
  final String input;
  final String expectedStatus;
  final int? expectedOrderNumber;
  final List<ExpectedItem> expectedItems;
  final String? note;

  Map<String, Object?> toJson() => {
    'id': id,
    'input': input,
    'expectedStatus': expectedStatus,
    'expectedOrderNumber': expectedOrderNumber,
    'expectedItems': [for (final item in expectedItems) item.toJson()],
    if (note != null) 'note': note,
  };
}

/// The 10 Turkish refund evaluation cases.
const List<EvalCase> refundEvalCases = <EvalCase>[
  EvalCase(
    id: 1,
    input:
        "1042 numaralı siparişteki 3 kahveden 2'sini iade etmek istiyorum, soğuk gelmişti.",
    expectedStatus: 'ok',
    expectedOrderNumber: 1042,
    expectedItems: [ExpectedItem('Latte', 2)],
    note: 'reason about being cold',
  ),
  EvalCase(
    id: 2,
    input: "1043'teki sandviçi iade edin, bayattı.",
    expectedStatus: 'ok',
    expectedOrderNumber: 1043,
    expectedItems: [ExpectedItem('Sandviç', 1)],
  ),
  EvalCase(
    id: 3,
    input: '1044 siparişimi tamamen iade etmek istiyorum.',
    expectedStatus: 'ok',
    expectedOrderNumber: 1044,
    expectedItems: [ExpectedItem('Filtre kahve', 1)],
  ),
  EvalCase(
    id: 4,
    input: "Siparişimdeki cheesecake'i iade etmek istiyorum.",
    expectedStatus: 'missing_info',
    expectedOrderNumber: null,
    expectedItems: [],
    note: 'orderNumber null, tool not called',
  ),
  EvalCase(
    id: 5,
    input: '9999 numaralı siparişi iade et.',
    expectedStatus: 'order_not_found',
    expectedOrderNumber: 9999,
    expectedItems: [],
  ),
  EvalCase(
    id: 6,
    input: "1042'deki 5 latteyi iade etmek istiyorum.",
    expectedStatus: 'invalid_quantity',
    expectedOrderNumber: 1042,
    expectedItems: [],
  ),
  EvalCase(
    id: 7,
    input: "1043'teki pizzayı iade et.",
    expectedStatus: 'item_not_in_order',
    expectedOrderNumber: 1043,
    expectedItems: [],
  ),
  EvalCase(
    id: 8,
    input: "1042'deki cheesecake ile 1 latteyi iade edin.",
    expectedStatus: 'ok',
    expectedOrderNumber: 1042,
    expectedItems: [
      ExpectedItem('Cheesecake', 1),
      ExpectedItem('Latte', 1),
    ],
    note: 'reason null',
  ),
  EvalCase(
    id: 9,
    input: 'Merhaba, kargom nerede?',
    expectedStatus: 'not_refund_request',
    expectedOrderNumber: null,
    expectedItems: [],
  ),
  EvalCase(
    id: 10,
    input: '1043 numaralı siparişteki suların hepsini iade edeyim.',
    expectedStatus: 'ok',
    expectedOrderNumber: 1043,
    expectedItems: [ExpectedItem('Su', 2)],
  ),
];

/// Result of running one [EvalCase] through `refundFlow`.
class EvalCaseResult {
  const EvalCaseResult({
    required this.evalCase,
    required this.actual,
    required this.toolCalled,
    required this.toolCallCount,
    required this.calledOrderNumbers,
    required this.passed,
    this.error,
  });

  final EvalCase evalCase;
  final RefundResponse? actual;
  final bool toolCalled;
  final int toolCallCount;
  final List<int> calledOrderNumbers;
  final bool passed;
  final String? error;

  String get actualStatusLabel => actual?.status ?? 'ERROR';

  Map<String, Object?> toJson() => {
    'case': evalCase.id,
    'input': evalCase.input,
    'expected': {
      'status': evalCase.expectedStatus,
      'orderNumber': evalCase.expectedOrderNumber,
      'items': [for (final item in evalCase.expectedItems) item.toJson()],
      if (evalCase.note != null) 'note': evalCase.note,
    },
    'actual': actual == null
        ? null
        : {
            'status': actual!.status,
            'orderNumber': actual!.orderNumber,
            'items': [
              for (final item in actual!.items)
                {'product': item.product, 'quantity': item.quantity},
            ],
            'reason': actual!.reason,
            'missingInfo': actual!.missingInfo,
          },
    'toolCalled': toolCalled,
    'toolCallCount': toolCallCount,
    'calledOrderNumbers': calledOrderNumbers,
    'passed': passed,
    if (error != null) 'error': error,
  };
}

/// Checks whether [actual] satisfies [evalCase] by comparing `status`,
/// `orderNumber`, and `items` (order-independent).
bool matchesExpected(EvalCase evalCase, RefundResponse actual) {
  if (actual.status != evalCase.expectedStatus) return false;
  if (actual.orderNumber != evalCase.expectedOrderNumber) return false;
  return _itemsMatch(evalCase.expectedItems, actual.items);
}

bool _itemsMatch(List<ExpectedItem> expected, List<RefundItem> actual) {
  if (expected.length != actual.length) return false;

  final sortedExpected = [
    for (final item in expected) (product: item.product, quantity: item.quantity),
  ]..sort(_compareItemRecords);

  final sortedActual = [
    for (final item in actual) (product: item.product, quantity: item.quantity),
  ]..sort(_compareItemRecords);

  for (var i = 0; i < sortedExpected.length; i++) {
    if (sortedExpected[i].product != sortedActual[i].product ||
        sortedExpected[i].quantity != sortedActual[i].quantity) {
      return false;
    }
  }
  return true;
}

int _compareItemRecords(
  ({String product, int quantity}) a,
  ({String product, int quantity}) b,
) {
  final byName = a.product.compareTo(b.product);
  if (byName != 0) return byName;
  return a.quantity.compareTo(b.quantity);
}

/// Runs all [cases] sequentially through [assistant.refundFlow] and records
/// per-case tool usage.
Future<List<EvalCaseResult>> runEvalSuite(
  RefundAssistant assistant, {
  List<EvalCase> cases = refundEvalCases,
}) async {
  final results = <EvalCaseResult>[];

  for (final testCase in cases) {
    assistant.tracker.reset();
    try {
      final response = await assistant.refundFlow(testCase.input);
      final callCount = assistant.tracker.callCount;
      results.add(
        EvalCaseResult(
          evalCase: testCase,
          actual: response,
          toolCalled: callCount > 0,
          toolCallCount: callCount,
          calledOrderNumbers: assistant.tracker.calledOrderNumbers,
          passed: matchesExpected(testCase, response),
        ),
      );
    } catch (error) {
      final callCount = assistant.tracker.callCount;
      results.add(
        EvalCaseResult(
          evalCase: testCase,
          actual: null,
          toolCalled: callCount > 0,
          toolCallCount: callCount,
          calledOrderNumbers: assistant.tracker.calledOrderNumbers,
          passed: false,
          error: error.toString(),
        ),
      );
    }
  }

  return results;
}

/// Formats evaluation results into a fixed-width ASCII table with columns:
/// case, expected status, actual status, tool called (yes/no), pass/fail.
String formatEvalTable(List<EvalCaseResult> results) {
  const headers = [
    'case',
    'expected status',
    'actual status',
    'tool called (yes/no)',
    'pass/fail',
  ];

  final rows = <List<String>>[
    for (final r in results)
      [
        '${r.evalCase.id}',
        r.evalCase.expectedStatus,
        r.actualStatusLabel,
        r.toolCalled ? 'yes' : 'no',
        r.passed ? 'pass' : 'fail',
      ],
  ];

  final widths = List<int>.generate(headers.length, (col) {
    var maxWidth = headers[col].length;
    for (final row in rows) {
      if (row[col].length > maxWidth) {
        maxWidth = row[col].length;
      }
    }
    return maxWidth;
  });

  String formatRow(List<String> cells) {
    final padded = [
      for (var i = 0; i < cells.length; i++) cells[i].padRight(widths[i]),
    ];
    return '| ${padded.join(' | ')} |';
  }

  final divider =
      '|-${widths.map((w) => '-' * w).join('-|-')}-|';

  final buffer = StringBuffer()
    ..writeln(formatRow(headers))
    ..writeln(divider);

  for (final row in rows) {
    buffer.writeln(formatRow(row));
  }

  final passedCount = results.where((r) => r.passed).length;
  buffer.writeln();
  buffer.writeln('Summary: $passedCount/${results.length} passed');

  return buffer.toString();
}

/// Writes the evaluation run report to [outputPath] as formatted JSON.
Future<void> writeEvalJson(
  List<EvalCaseResult> results, {
  required String modelName,
  String outputPath = 'results/eval.json',
}) async {
  final file = File(outputPath);
  await file.parent.create(recursive: true);

  final passedCount = results.where((r) => r.passed).length;
  final payload = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'model': modelName,
    'summary': {
      'total': results.length,
      'passed': passedCount,
      'failed': results.length - passedCount,
    },
    'cases': [for (final r in results) r.toJson()],
  };

  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString('${encoder.convert(payload)}\n');
}
