import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({
    super.key,
    required this.messages,
    required this.inputController,
    required this.scrollController,
    required this.sending,
    required this.enabled,
    required this.onSend,
    this.onPreviewNotes,
  });

  final List<ChatMessage> messages;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback? onPreviewNotes;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];

              return Align(
                alignment: message.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectableText(message.text),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: inputController,
                  onSubmitted: (_) {
                    if (enabled && !sending) onSend();
                  },
                  decoration: const InputDecoration(
                    hintText: 'メッセージを入力',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: enabled && !sending ? onPreviewNotes : null,
                icon: const Icon(Icons.description_outlined),
                label: const Text('送信メモを確認'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: enabled && !sending ? onSend : null,
                child: Text(sending ? '回答中…' : '送信'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
