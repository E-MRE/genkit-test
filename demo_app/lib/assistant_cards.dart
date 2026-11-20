import 'package:flutter/material.dart';

import 'refund_api.dart';

/// Maps known product names to Material icons in Flutter.
IconData iconForProduct(String product) {
  final lower = product.toLowerCase();
  if (lower.contains('latte') || lower.contains('filtre kahve')) {
    return Icons.coffee;
  }
  if (lower.contains('cheesecake')) {
    return Icons.cake;
  }
  if (lower == 'su' || lower.contains('su')) {
    return Icons.water_drop;
  }
  if (lower.contains('sandvi')) {
    return Icons.lunch_dining;
  }
  return Icons.shopping_bag;
}

/// Formats a TL price cleanly (omitting `.00` for whole numbers).
String formatTl(double amount) {
  if (amount == amount.roundToDouble()) {
    return '${amount.toInt()} TL';
  }
  return '${amount.toStringAsFixed(2)} TL';
}

/// Chooses and animates the assistant card matching [result.view].
class AssistantResponseCard extends StatelessWidget {
  const AssistantResponseCard({
    super.key,
    required this.result,
    required this.onSelectSuggestion,
  });

  final AssistantResultModel result;
  final ValueChanged<String> onSelectSuggestion;

  Widget _buildInnerCard() {
    switch (result.view) {
      case AssistantView.refundSummary:
        return _RefundSummaryCard(result: result);
      case AssistantView.shipmentTracking:
        return _ShipmentTrackingCard(result: result);
      case AssistantView.orderDetails:
        return _OrderDetailsCard(result: result);
      case AssistantView.clarification:
        return _ClarificationCard(
          result: result,
          onSelectSuggestion: onSelectSuggestion,
        );
      case AssistantView.unsupported:
        return _UnsupportedCard(
          result: result,
          onSelectSuggestion: onSelectSuggestion,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CardEntrance(child: _buildInnerCard());
  }
}

class _CardEntrance extends StatefulWidget {
  const _CardEntrance({required this.child});

  final Widget child;

  @override
  State<_CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<_CardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _fade = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _RefundSummaryCard extends StatelessWidget {
  const _RefundSummaryCard({required this.result});

  final AssistantResultModel result;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'card_refund_summary',
      label: 'card_refund_summary',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _RefundSummaryContent(result: result),
        ),
      ),
    );
  }
}

class _RefundSummaryContent extends StatelessWidget {
  const _RefundSummaryContent({required this.result});

  final AssistantResultModel result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _RefundSummaryHeader(result: result),
        if (result.items.isNotEmpty) const Divider(height: 20),
        for (final item in result.items) _RefundItemRow(item: item),
      ],
    );
  }
}

class _RefundSummaryHeader extends StatelessWidget {
  const _RefundSummaryHeader({required this.result});

  final AssistantResultModel result;

  @override
  Widget build(BuildContext context) {
    final title = result.orderNumber.isNotEmpty
        ? 'İade Özeti · Sipariş #${result.orderNumber}'
        : 'İade Özeti';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        _AssistantRefundBadge(
          status: result.refundStatus,
          label: result.rawRefundStatus,
        ),
      ],
    );
  }
}

class _AssistantRefundBadge extends StatelessWidget {
  const _AssistantRefundBadge({required this.status, required this.label});

  final AssistantRefundStatus status;
  final String label;

  Color _color() {
    switch (status) {
      case AssistantRefundStatus.ok:
        return Colors.green;
      case AssistantRefundStatus.invalidQuantity:
      case AssistantRefundStatus.itemNotInOrder:
        return Colors.orange;
      case AssistantRefundStatus.orderNotFound:
        return Colors.red;
      case AssistantRefundStatus.none:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color(),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RefundItemRow extends StatelessWidget {
  const _RefundItemRow({required this.item});

  final AssistantItemModel item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(iconForProduct(item.product), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(item.product)),
          Text(
            '× ${item.quantity}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ShipmentTrackingCard extends StatelessWidget {
  const _ShipmentTrackingCard({required this.result});

  final AssistantResultModel result;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'card_shipment_tracking',
      label: 'card_shipment_tracking',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _ShipmentTrackingContent(result: result),
        ),
      ),
    );
  }
}

class _ShipmentTrackingContent extends StatelessWidget {
  const _ShipmentTrackingContent({required this.result});

  final AssistantResultModel result;

  @override
  Widget build(BuildContext context) {
    final steps = result.shipmentSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ShipmentHeader(orderNumber: result.orderNumber),
        const Divider(height: 20),
        for (var i = 0; i < steps.length; i++)
          _ShipmentStepRow(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _ShipmentHeader extends StatelessWidget {
  const _ShipmentHeader({required this.orderNumber});

  final String orderNumber;

  @override
  Widget build(BuildContext context) {
    final title = orderNumber.isNotEmpty
        ? 'Kargo Takibi · Sipariş #$orderNumber'
        : 'Kargo Takibi';
    return Row(
      children: <Widget>[
        const Icon(Icons.local_shipping, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ShipmentStepRow extends StatelessWidget {
  const _ShipmentStepRow({required this.step, required this.isLast});

  final ShipmentStepModel step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TimelineIndicator(done: step.done, isLast: isLast),
          const SizedBox(width: 10),
          Expanded(child: _TimelineStepText(step: step)),
        ],
      ),
    );
  }
}

class _TimelineIndicator extends StatelessWidget {
  const _TimelineIndicator({required this.done, required this.isLast});

  final bool done;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final icon = done ? Icons.check_circle : Icons.radio_button_unchecked;
    final color = done ? Colors.green : Colors.grey;
    return Column(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        if (!isLast)
          Expanded(
            child: Container(width: 2, color: color.withValues(alpha: 0.4)),
          ),
      ],
    );
  }
}

class _TimelineStepText extends StatelessWidget {
  const _TimelineStepText({required this.step});

  final ShipmentStepModel step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            step.label,
            style: TextStyle(
              fontWeight: step.done ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(step.time, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({required this.result});

  final AssistantResultModel result;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'card_order_details',
      label: 'card_order_details',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _OrderDetailsContent(result: result),
        ),
      ),
    );
  }
}

class _OrderDetailsContent extends StatelessWidget {
  const _OrderDetailsContent({required this.result});

  final AssistantResultModel result;

  double _computeTotal() {
    var total = 0.0;
    for (final item in result.items) {
      total += item.quantity * item.unitPrice;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final header = result.orderNumber.isNotEmpty
        ? 'Sipariş Fişi · #${result.orderNumber}'
        : 'Sipariş Fişi';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ReceiptHeader(title: header),
        const Divider(height: 20),
        for (final item in result.items) _OrderDetailRow(item: item),
        const Divider(height: 20),
        _ReceiptTotalRow(total: _computeTotal()),
      ],
    );
  }
}

class _ReceiptHeader extends StatelessWidget {
  const _ReceiptHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.receipt_long, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _OrderDetailRow extends StatelessWidget {
  const _OrderDetailRow({required this.item});

  final AssistantItemModel item;

  @override
  Widget build(BuildContext context) {
    final lineTotal = item.quantity * item.unitPrice;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(iconForProduct(item.product), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${item.product} (${item.quantity} × ${formatTl(item.unitPrice)})',
            ),
          ),
          Text(
            formatTl(lineTotal),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ReceiptTotalRow extends StatelessWidget {
  const _ReceiptTotalRow({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        const Text('Toplam', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          formatTl(total),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ClarificationCard extends StatelessWidget {
  const _ClarificationCard({
    required this.result,
    required this.onSelectSuggestion,
  });

  final AssistantResultModel result;
  final ValueChanged<String> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'card_clarification',
      label: 'card_clarification',
      container: true,
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _SuggestionCardContent(
            icon: Icons.chat_bubble_outline,
            title: 'Biraz daha bilgi gerekli',
            suggestions: result.suggestions,
            onSelectSuggestion: onSelectSuggestion,
          ),
        ),
      ),
    );
  }
}

class _UnsupportedCard extends StatelessWidget {
  const _UnsupportedCard({
    required this.result,
    required this.onSelectSuggestion,
  });

  final AssistantResultModel result;
  final ValueChanged<String> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'card_unsupported',
      label: 'card_unsupported',
      container: true,
      child: Card(
        color: Colors.grey.shade200,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _SuggestionCardContent(
            icon: Icons.info_outline,
            title: 'Bu konuda yardımcı olamıyorum',
            suggestions: result.suggestions,
            onSelectSuggestion: onSelectSuggestion,
          ),
        ),
      ),
    );
  }
}

class _SuggestionCardContent extends StatelessWidget {
  const _SuggestionCardContent({
    required this.icon,
    required this.title,
    required this.suggestions,
    required this.onSelectSuggestion,
  });

  final IconData icon;
  final String title;
  final List<String> suggestions;
  final ValueChanged<String> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SuggestionCardHeader(icon: icon, title: title),
        if (suggestions.isNotEmpty) const SizedBox(height: 10),
        if (suggestions.isNotEmpty)
          _SuggestionChips(
            suggestions: suggestions,
            onSelectSuggestion: onSelectSuggestion,
          ),
      ],
    );
  }
}

class _SuggestionCardHeader extends StatelessWidget {
  const _SuggestionCardHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({
    required this.suggestions,
    required this.onSelectSuggestion,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final suggestion in suggestions)
          ActionChip(
            label: Text(suggestion),
            onPressed: () => onSelectSuggestion(suggestion),
          ),
      ],
    );
  }
}
