import 'package:flutter/material.dart';

class BackupPickerDialog extends StatelessWidget {
  const BackupPickerDialog({super.key, required this.backups});

  final List<Map<String, dynamic>> backups;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('復元するバックアップ'),
      content: SizedBox(
        width: 600,
        height: 360,
        child: ListView.builder(
          itemCount: backups.length,
          itemBuilder: (context, index) {
            final backup = backups[index];
            final time = DateTime.tryParse(
              backup['createdAt']?.toString() ?? '',
            );

            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                time == null
                    ? '日時不明'
                    : time.toLocal().toString().split('.').first,
              ),
              subtitle: Text(backup['name'] as String? ?? ''),
              onTap: () {
                Navigator.pop(context, backup);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ],
    );
  }
}
