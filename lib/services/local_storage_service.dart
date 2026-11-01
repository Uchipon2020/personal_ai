import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation_data.dart';

/// Mac内の保存・読み込み。キー名とJSON形式を変えず、既存データを読む。
class LocalStorageService {
  final _preferences = SharedPreferencesAsync();

  Future<List<String>> loadNotes() async {
    return await _preferences.getStringList('notes') ?? [];
  }

  Future<void> saveNotes(List<String> notes) async {
    await _preferences.setStringList('notes', List<String>.from(notes));
  }

  Future<ConversationData?> loadConversation() async {
    final saved = await _preferences.getString('conversation_v1');
    if (saved == null) return null;
    return ConversationData.fromJson(jsonDecode(saved) as Map<String, dynamic>);
  }

  Future<void> saveConversation(ConversationData conversation) async {
    await _preferences.setString(
      'conversation_v1',
      jsonEncode(conversation.toJson()),
    );
  }

  /// 復元前の退避と、書き込み失敗時の巻き戻しを担当する。
  Future<void> restoreBackup({
    required List<String> oldNotes,
    required ConversationData oldConversation,
    required List<String> newNotes,
    required ConversationData newConversation,
  }) async {
    await _preferences.setString(
      'before_restore_v1',
      jsonEncode({'notes': oldNotes, 'conversation': oldConversation.toJson()}),
    );

    try {
      await saveNotes(newNotes);
      await saveConversation(newConversation);
    } catch (_) {
      try {
        await saveNotes(oldNotes);
        await saveConversation(oldConversation);
      } catch (_) {
        throw RestoreRollbackException();
      }
      throw Exception('保存に失敗したため、元のデータに戻しました。');
    }
  }
}

class RestoreRollbackException implements Exception {
  @override
  String toString() =>
      '保存と元への書き戻しに失敗しました。'
      '操作を止めて、この表示を教えてください。'
      '復元前のデータは端末内の退避領域に保存されています。';
}
