import 'package:flutter/material.dart';

import 'assistant_cards.dart';
import 'refund_api.dart';

/// Three tappable example prompts shown above the chat input.
const List<String> assistantExamplePrompts = <String>[
  "1042'deki 2 latteyi iade etmek istiyorum.",
  'Kargom nerede? Sipariş 1043',
  '1044 numaralı siparişte ne vardı?',
];

enum _ChatEntryKind { user, assistant, loading, error }

class _ChatEntry {
  const _ChatEntry({
    required this.kind,
    this.text = '',
    this.result,
  });

  final _ChatEntryKind kind;
  final String text;
  final AssistantResultModel? result;
}

/// Chat-style screen wired to `POST /assistantFlow`.
class AssistantChatView extends StatefulWidget {
  const AssistantChatView({super.key, required this.apiClient});

  final RefundApiClient apiClient;

  @override
  State<AssistantChatView> createState() => _AssistantChatViewState();
}

class _AssistantChatViewState extends State<AssistantChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatEntry> _entries = <_ChatEntry>[];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _isLoading = true;
      _entries.add(_ChatEntry(kind: _ChatEntryKind.user, text: text));
      _entries.add(const _ChatEntry(kind: _ChatEntryKind.loading));
    });
    _scrollToBottom();

    try {
      final response = await widget.apiClient.callAssistantFlow(text);
      if (!mounted) return;
      setState(() {
        _replaceLoadingEntry(
          _ChatEntry(kind: _ChatEntryKind.assistant, result: response),
        );
        _isLoading = false;
      });
    } on RefundApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _replaceLoadingEntry(
          _ChatEntry(kind: _ChatEntryKind.error, text: error.message),
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _replaceLoadingEntry(
          _ChatEntry(kind: _ChatEntryKind.error, text: 'Beklenmeyen hata: $error'),
        );
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _replaceLoadingEntry(_ChatEntry replacement) {
    if (_entries.isNotEmpty && _entries.last.kind == _ChatEntryKind.loading) {
      _entries.removeLast();
    }
    _entries.add(replacement);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: _ChatColumn(
          entries: _entries,
          scrollController: _scrollController,
          controller: _controller,
          isLoading: _isLoading,
          onSend: _sendMessage,
        ),
      ),
    );
  }
}

class _ChatColumn extends StatelessWidget {
  const _ChatColumn({
    required this.entries,
    required this.scrollController,
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  final List<_ChatEntry> entries;
  final ScrollController scrollController;
  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: _ChatMessageList(
            entries: entries,
            scrollController: scrollController,
            onSelectSuggestion: onSend,
          ),
        ),
        const Divider(height: 1),
        _ChatComposer(controller: controller, isLoading: isLoading, onSend: onSend),
      ],
    );
  }
}

class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({
    required this.entries,
    required this.scrollController,
    required this.onSelectSuggestion,
  });

  final List<_ChatEntry> entries;
  final ScrollController scrollController;
  final ValueChanged<String> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyChatPlaceholder();
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        return _ChatEntryTile(
          entry: entries[index],
          onSelectSuggestion: onSelectSuggestion,
        );
      },
    );
  }
}

class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Başlamak için aşağıdan bir örnek seçin veya sipariş sorunuzu yazın.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _ChatEntryTile extends StatelessWidget {
  const _ChatEntryTile({
    required this.entry,
    required this.onSelectSuggestion,
  });

  final _ChatEntry entry;
  final ValueChanged<String> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    switch (entry.kind) {
      case _ChatEntryKind.user:
        return _UserBubble(text: entry.text);
      case _ChatEntryKind.loading:
        return const _LoadingBubble();
      case _ChatEntryKind.error:
        return _ErrorBubble(message: entry.text);
      case _ChatEntryKind.assistant:
        return _AssistantTurn(
          result: entry.result!,
          onSelectSuggestion: onSelectSuggestion,
        );
    }
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text, style: TextStyle(color: scheme.onPrimaryContainer)),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: _LoadingRow(),
          ),
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text('Yanıt hazırlanıyor...'),
      ],
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: SelectableText(
          message,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _AssistantTurn extends StatelessWidget {
  const _AssistantTurn({
    required this.result,
    required this.onSelectSuggestion,
  });

  final AssistantResultModel result;
  final ValueChanged<String> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _AssistantMessageRow(result: result),
          const SizedBox(height: 6),
          AssistantResponseCard(
            result: result,
            onSelectSuggestion: onSelectSuggestion,
          ),
        ],
      ),
    );
  }
}

class _AssistantMessageRow extends StatelessWidget {
  const _AssistantMessageRow({required this.result});

  final AssistantResultModel result;

  @override
  Widget build(BuildContext context) {
    final elapsed = '${result.elapsedSeconds.toStringAsFixed(2)} sn';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Text(
            result.message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        Text(elapsed, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _AssistantExampleChips(enabled: !isLoading, onTapChip: onSend),
          const SizedBox(height: 10),
          _ChatInputRow(
            controller: controller,
            isLoading: isLoading,
            onSend: () => onSend(controller.text),
          ),
        ],
      ),
    );
  }
}

class _AssistantExampleChips extends StatelessWidget {
  const _AssistantExampleChips({
    required this.enabled,
    required this.onTapChip,
  });

  final bool enabled;
  final ValueChanged<String> onTapChip;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        for (var i = 0; i < assistantExamplePrompts.length; i++)
          _ExampleChipItem(
            index: i,
            text: assistantExamplePrompts[i],
            enabled: enabled,
            onPressed: () => onTapChip(assistantExamplePrompts[i]),
          ),
      ],
    );
  }
}

class _ExampleChipItem extends StatelessWidget {
  const _ExampleChipItem({
    required this.index,
    required this.text,
    required this.enabled,
    required this.onPressed,
  });

  final int index;
  final String text;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final semanticId = 'example_chip_${index + 1}';
    return Semantics(
      identifier: semanticId,
      label: semanticId,
      button: true,
      child: ActionChip(
        label: Text(text),
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}

class _ChatInputRow extends StatelessWidget {
  const _ChatInputRow({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ChatTextField(
            controller: controller,
            enabled: !isLoading,
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        _ChatSendButton(isLoading: isLoading, onPressed: onSend),
      ],
    );
  }
}

class _ChatTextField extends StatelessWidget {
  const _ChatTextField({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'chat_input',
      label: 'chat_input',
      textField: true,
      child: TextField(
        controller: controller,
        enabled: enabled,
        onSubmitted: onSubmitted,
        decoration: const InputDecoration(
          hintText: 'Mesajınızı yazın...',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _ChatSendButton extends StatelessWidget {
  const _ChatSendButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'send_button',
      label: 'send_button',
      button: true,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: const Text('Gönder'),
      ),
    );
  }
}
