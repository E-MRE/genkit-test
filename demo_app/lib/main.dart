import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'assistant_chat_view.dart';
import 'refund_api.dart';
import 'refund_legacy_view.dart';

/// Which backend flow the demo screen currently targets.
enum DemoFlowMode { assistant, refund }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  runApp(const RefundDemoApp());
}

class RefundDemoApp extends StatelessWidget {
  const RefundDemoApp({super.key, this.apiClient});

  final RefundApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sipariş Asistanı (Genkit demo)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: DemoHomeScreen(apiClient: apiClient),
    );
  }
}

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({super.key, this.apiClient});

  final RefundApiClient? apiClient;

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  late final RefundApiClient _apiClient;
  late final bool _ownsApiClient;
  DemoFlowMode _mode = DemoFlowMode.assistant;

  @override
  void initState() {
    super.initState();
    final provided = widget.apiClient;
    _ownsApiClient = provided == null;
    _apiClient = provided ?? RefundApiClient();
  }

  @override
  void dispose() {
    if (_ownsApiClient) {
      _apiClient.dispose();
    }
    super.dispose();
  }

  void _onChangeMode(DemoFlowMode nextMode) {
    setState(() {
      _mode = nextMode;
    });
  }

  Widget _buildBody() {
    switch (_mode) {
      case DemoFlowMode.assistant:
        return AssistantChatView(apiClient: _apiClient);
      case DemoFlowMode.refund:
        return RefundLegacyView(apiClient: _apiClient);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sipariş Asistanı (Genkit demo)'),
        actions: <Widget>[
          _FlowModeToggle(mode: _mode, onChanged: _onChangeMode),
        ],
      ),
      body: _buildBody(),
    );
  }
}

class _FlowModeToggle extends StatelessWidget {
  const _FlowModeToggle({required this.mode, required this.onChanged});

  static const List<ButtonSegment<DemoFlowMode>> _segments =
      <ButtonSegment<DemoFlowMode>>[
        ButtonSegment<DemoFlowMode>(
          value: DemoFlowMode.assistant,
          label: Text('assistantFlow'),
        ),
        ButtonSegment<DemoFlowMode>(
          value: DemoFlowMode.refund,
          label: Text('refundFlow'),
        ),
      ];

  final DemoFlowMode mode;
  final ValueChanged<DemoFlowMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SegmentedButton<DemoFlowMode>(
        showSelectedIcon: false,
        segments: _segments,
        selected: <DemoFlowMode>{mode},
        onSelectionChanged: (Set<DemoFlowMode> selection) {
          if (selection.isNotEmpty) onChanged(selection.first);
        },
      ),
    );
  }
}
