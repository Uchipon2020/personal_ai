import 'chat_message.dart';

/// 表示する会話と、AIに送る履歴をまとめる。
class ConversationData {
  ConversationData({required this.messages, required this.apiHistory});

  final List<ChatMessage> messages;
  final List<Map<String, String>> apiHistory;

  factory ConversationData.fromJson(Map<String, dynamic> json) {
    return ConversationData(
      messages: (json['display'] as List)
          .map(
            (item) =>
                ChatMessage.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      apiHistory: (json['history'] as List)
          .map(
            (item) => {
              'role': (item as Map)['role'] as String,
              'content': item['content'] as String,
            },
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'display': messages.map((item) => item.toJson()).toList(),
    'history': apiHistory,
  };

  /// 質問と回答をセットで除き、最大６往復・12000文字にする。
  static void trimHistory(List<Map<String, String>> history) {
    if (history.length.isOdd) {
      throw const FormatException('会話履歴の組み合わせが違います。');
    }
    while (history.isNotEmpty &&
        (history.length > 12 ||
            history.fold<int>(
                  0,
                  (total, item) => total + item['content']!.length,
                ) >
                12000)) {
      history.removeRange(0, 2);
    }
  }
}
