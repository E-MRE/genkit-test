import 'package:flutter/material.dart';

import 'refund_api.dart';

const List<String> _exampleMessages = <String>[
  "1042 numaralı siparişteki 3 kahveden 2'sini iade etmek istiyorum, soğuk gelmişti.",
  "1043'teki sandviçi iade edin, bayattı.",
  "1042'deki 5 latteyi iade etmek istiyorum.",
  'Merhaba, kargom nerede?',
];

void main() {
  runApp(const RefundDemoApp());
}

class RefundDemoApp extends StatelessWidget {
  const RefundDemoApp({super.key, this.apiClient});

  final RefundApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İade Asistanı (Genkit demo)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: RefundScreen(apiClient: apiClient),
    );
  }
}

class RefundScreen extends StatefulWidget {
  const RefundScreen({super.key, this.apiClient});

  final RefundApiClient? apiClient;

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  final TextEditingController _controller = TextEditingController();
  late final RefundApiClient _apiClient;
  late final bool _ownsApiClient;

  bool _isLoading = false;
  RefundResultModel? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final provided = widget.apiClient;
    _ownsApiClient = provided == null;
    _apiClient = provided ?? RefundApiClient();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsApiClient) {
      _apiClient.dispose();
    }
    super.dispose();
  }

  void _fillExample(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen bir mesaj yazın veya örneklerden birini seçin.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final response = await _apiClient.callRefundFlow(text);
      if (!mounted) return;
      setState(() {
        _result = response;
        _isLoading = false;
      });
    } on RefundApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Beklenmeyen hata: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İade Asistanı (Genkit demo)')),
      body: SingleChildScrollView(
        child: _ScreenBody(
          controller: _controller,
          isLoading: _isLoading,
          result: _result,
          errorMessage: _errorMessage,
          onSelectExample: _fillExample,
          onSubmit: _submit,
        ),
      ),
    );
  }
}

class _ScreenBody extends StatelessWidget {
  const _ScreenBody({
    required this.controller,
    required this.isLoading,
    required this.result,
    required this.errorMessage,
    required this.onSelectExample,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isLoading;
  final RefundResultModel? result;
  final String? errorMessage;
  final ValueChanged<String> onSelectExample;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _InputSection(
                controller: controller,
                isLoading: isLoading,
                onSelectExample: onSelectExample,
                onSubmit: onSubmit,
              ),
              if (errorMessage != null) _ErrorBanner(message: errorMessage!),
              if (result != null) _ResultCard(result: result!),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputSection extends StatelessWidget {
  const _InputSection({
    required this.controller,
    required this.isLoading,
    required this.onSelectExample,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSelectExample;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _MessageField(controller: controller, enabled: !isLoading),
        const SizedBox(height: 12),
        _ExampleChips(enabled: !isLoading, onSelected: onSelectExample),
        const SizedBox(height: 16),
        _SendButton(isLoading: isLoading, onPressed: onSubmit),
      ],
    );
  }
}

class _MessageField extends StatelessWidget {
  const _MessageField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: 3,
      maxLines: 5,
      decoration: const InputDecoration(
        labelText: 'Müşteri mesajı',
        hintText: 'Örn: 1042 numaralı siparişteki 2 latteyi iade etmek istiyorum.',
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _ExampleChips extends StatelessWidget {
  const _ExampleChips({required this.enabled, required this.onSelected});

  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final example in _exampleMessages)
          ActionChip(
            label: Text(example, overflow: TextOverflow.ellipsis),
            onPressed: enabled ? () => onSelected(example) : null,
          ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: _SendButtonContent(isLoading: isLoading),
      ),
    );
  }
}

class _SendButtonContent extends StatelessWidget {
  const _SendButtonContent({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return const Text('Gönder');
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('Gönderiliyor...'),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        color: colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            message,
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final RefundResultModel result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _StatusHeader(result: result),
              const Divider(height: 24),
              _DetailsList(result: result),
              const SizedBox(height: 8),
              _RawJsonTile(rawJson: result.rawJson),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.result});

  final RefundResultModel result;

  @override
  Widget build(BuildContext context) {
    final elapsedText = '${result.elapsedSeconds.toStringAsFixed(2)} sn';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _StatusBadge(status: result.status, label: result.rawStatus),
        Text(elapsedText, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final RefundStatus status;
  final String label;

  Color _badgeColor() {
    switch (status) {
      case RefundStatus.ok:
        return Colors.green;
      case RefundStatus.missingInfo:
      case RefundStatus.invalidQuantity:
      case RefundStatus.itemNotInOrder:
        return Colors.orange;
      case RefundStatus.orderNotFound:
        return Colors.red;
      case RefundStatus.notRefundRequest:
      case RefundStatus.unknown:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _badgeColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailsList extends StatelessWidget {
  const _DetailsList({required this.result});

  final RefundResultModel result;

  String _formatItems() {
    if (result.items.isEmpty) return '—';
    return result.items
        .map((item) => '${item.product} × ${item.quantity}')
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final orderText = result.orderNumber != null
        ? result.orderNumber.toString()
        : '—';
    final reasonText = result.reason != null ? result.reason! : '—';
    final missingText = result.missingInfo.isNotEmpty
        ? result.missingInfo.join(', ')
        : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DetailRow(label: 'Sipariş No', value: orderText),
        _DetailRow(label: 'Ürünler', value: _formatItems()),
        _DetailRow(label: 'Neden', value: reasonText),
        _DetailRow(label: 'Eksik Bilgi', value: missingText),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _RawJsonTile extends StatelessWidget {
  const _RawJsonTile({required this.rawJson});

  final String rawJson;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Ham JSON'),
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SelectableText(
            rawJson,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }
}
