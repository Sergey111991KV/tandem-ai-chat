enum ReplyMode { draft, autoSend }

extension ReplyModeLabel on ReplyMode {
  String get label => switch (this) {
        ReplyMode.draft => 'Draft for approval',
        ReplyMode.autoSend => 'Auto-send',
      };
}

enum TelegramAuthPhase {
  disconnected,
  waitingPhone,
  waitingCode,
  waitingPassword,
  ready,
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.title,
    required this.isMonitored,
    required this.replyMode,
    this.isPaused = false,
    this.lastMessagePreview,
  });

  final int id;
  final String title;
  final bool isMonitored;
  final ReplyMode replyMode;

  /// When true, the chat stays monitored but the AI pipeline skips new messages.
  final bool isPaused;
  final String? lastMessagePreview;

  ChatSummary copyWith({
    bool? isMonitored,
    ReplyMode? replyMode,
    bool? isPaused,
    String? lastMessagePreview,
  }) {
    return ChatSummary(
      id: id,
      title: title,
      isMonitored: isMonitored ?? this.isMonitored,
      replyMode: replyMode ?? this.replyMode,
      isPaused: isPaused ?? this.isPaused,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    );
  }
}

class LicenseEntitlement {
  const LicenseEntitlement({
    required this.isActive,
    this.expirationDate,
  });

  const LicenseEntitlement.inactive()
      : isActive = false,
        expirationDate = null;

  final bool isActive;
  final DateTime? expirationDate;
}
