import 'package:flutter/material.dart';

class NotesPanel extends StatelessWidget {
  const NotesPanel({
    super.key,
    required this.notes,
    required this.enabled,
    required this.onAddNote,
  });

  final List<String> notes;
  final bool enabled;
  final VoidCallback onAddNote;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Text(
                'メモ ${notes.length}件',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: enabled ? onAddNote : null,
                icon: const Icon(Icons.add),
                label: const Text('メモを追加'),
              ),
            ],
          ),
        ),
        Expanded(
          child: notes.isEmpty
              ? const Center(child: Text('まだメモはありません'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: notes.length,
                  itemBuilder: (context, index) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(notes[index]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
