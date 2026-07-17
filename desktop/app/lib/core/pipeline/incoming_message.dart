/// Normalized Telegram message for the AI pipeline (TDLib or stub).
class IncomingMessage {
  const IncomingMessage({
    required this.chatId,
    required this.messageId,
    required this.text,
    required this.isOutgoing,
    required this.senderId,
    required this.timestamp,
  });

  final int chatId;
  final int messageId;
  final String text;
  final bool isOutgoing;
  final String senderId;
  final DateTime timestamp;
}
