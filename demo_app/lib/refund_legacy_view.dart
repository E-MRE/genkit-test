import 'package:flutter/material.dart';

import 'refund_api.dart';

const List<String> _legacyExampleMessages = <String>[
  "1042 numaralı siparişteki 3 kahveden 2'sini iade etmek istiyorum, soğuk gelmişti.",
  "1043'teki sandviçi iade edin, bayattı.",
  "1042'deki 5 latteyi iade etmek istiyorum.",
  'Merhaba, kargom nerede?',
];

/// Original single-card view calling `POST /refundFlow`.
class RefundLegacyView extends StatefulWidget {
  const RefundLegacyView({super.key, required this.apiClient});

  final RefundApiClient apiClient;

  @override
  State<RefundLegacyView> createState() => _RefundLegacyViewState();
}

class _RefundLegacyViewState extends State<RefundLegacyView> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  RefundResultModel? _result;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
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
      final response = await widget.apiClient.callRefundFlow(text);
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
    return SingleChildScrollView(
      child: _LegacyBody(
        controller: _controller,
        isLoading: _isLoading,
        result: _result,
        errorMessage: _errorMessage,
        onSelectExample: _fillExample,
        onSubmit: _submit,
      ),
    );
  }
}

class _LegacyBody extends StatelessWidget {
  const _LegacyBody({
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
          child: _LegacyColumn(
            controller: controller,
            isLoading: isLoading,
            result: result,
            errorMessage: errorMessage,
            onSelectExample: onSelectExample,
            onSubmit: onSubmit,
          ),
        ),
      ),
    );
  }
}

class _LegacyColumn extends StatelessWidget {
  const _LegacyColumn({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _LegacyInputSection(
          controller: controller,
          isLoading: isLoading,
          onSelectExample: onSelectExample,
          onSubmit: onSubmit,
        ),
        if (errorMessage != null) _LegacyErrorBanner(message: errorMessage!),
        if (result != null) _LegacyResultCard(result: result!),
      ],
    );
  }
}

class _LegacyInputSection extends StatelessWidget {
  const _LegacyInputSection({
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
        _LegacyMessageField(controller: controller, enabled: !isLoading),
        const SizedBox(height: 12),
        _LegacyExampleChips(enabled: !isLoading, onSelected: onSelectExample),
        const SizedBox(height: 16),
        _LegacySendButton(isLoading: isLoading, onPressed: onSubmit),
      ],
    );
  }
}

class _LegacyMessageField extends StatelessWidget {
  const _LegacyMessageField({required this.controller, required this.enabled});

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

class _LegacyExampleChips extends StatelessWidget {
  const _LegacyExampleChips({required this.enabled, required this.onSelected});

  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final example in _legacyExampleMessages)
          ActionChip(
            label: Text(example, overflow: TextOverflow.ellipsis),
            onPressed: enabled ? () => onSelected(example) : null,
          ),
      ],
    );
  }
}

class _LegacySendButton extends StatelessWidget {
  const _LegacySendButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: _LegacySendButtonContent(isLoading: isLoading),
      ),
    );
  }
}

class _LegacySendButtonContent extends StatelessWidget {
  const _LegacySendButtonContent({required this.isLoading});

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

class _LegacyErrorBanner extends StatelessWidget {
  const _LegacyErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            message,
            style: TextStyle(color: scheme.onErrorContainer),
          ),
        ),
      ),
    );
  }
}

class _LegacyResultCard extends StatelessWidget {
  const _LegacyResultCard({required this.result});

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
              _LegacyStatusHeader(result: result),
              const Divider(height: 24),
              _LegacyDetailsList(result: result),
              const SizedBox(height: 8),
              _LegacyRawJsonTile(rawJson: result.rawJson),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegacyStatusHeader extends StatelessWidget {
  const _LegacyStatusHeader({required this.result});

  final RefundResultModel result;

  @override
  Widget build(BuildContext context) {
    final elapsedText = '${result.elapsedSeconds.toStringAsFixed(2)} sn';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _LegacyStatusBadge(status: result.status, label: result.rawStatus),
        Text(elapsedText, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LegacyStatusBadge extends StatelessWidget {
  const _LegacyStatusBadge({required this.status, required this.label});

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

class _LegacyDetailsList extends StatelessWidget {
  const _LegacyDetailsList({required this.result});

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
        _LegacyDetailRow(label: 'Sipariş No', value: orderText),
        _LegacyDetailRow(label: 'Ürünler', value: _formatItems()),
        _LegacyDetailRow(label: 'Neden', value: reasonText),
        _LegacyDetailRow(label: 'Eksik Bilgi', value: missingText),
      ],
    );
  }
}

class _LegacyDetailRow extends StatelessWidget {
  const _LegacyDetailRow({required this.label, required this.value});

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

class _LegacyRawJsonTile extends StatelessWidget {
  const _LegacyRawJsonTile({required this.rawJson});

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
