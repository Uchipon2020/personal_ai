import 'package:flutter/material.dart';

class RestoreConfirmationDialog extends StatelessWidget {
  const RestoreConfirmationDialog({
    super.key,
    required this.noteCount,
    required this.messageCount,
  });

  final int noteCount;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('このバックアップから復元しますか？'),
      content: Text(
        'メモ：${noteCount}件\n'
        '会話の表示：${messageCount}件\n\n'
        '現在の会話とメモを、この内容に置き換えます。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('復元する'),
        ),
      ],
    );
  }
}
