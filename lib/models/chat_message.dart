/// 画面に表示する１件のメッセージ。保存形式は従来と同じ。
class ChatMessage {
  const ChatMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      isUser: json['isUser'] as bool,
      text: json['text'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'isUser': isUser, 'text': text};
}
