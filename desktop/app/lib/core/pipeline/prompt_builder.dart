/// Builds the structured prompt sent to the AI destination chat (Mac parity MVP).
class PromptBuilder {
  static const contextRequestCommand = 'NEED_CONTEXT:';
  static const contextSeenMarker = 'CONTEXT_SEEN_UNTIL:';

  const PromptBuilder();

  String build({
    required String requestId,
    required String sourceChatId,
    required String chatTitle,
    required String senderId,
    required String messageId,
    required String userMessage,
    required String rolePrompt,
    required DateTime timestamp,
    String answerPrefix = 'Answer:',
    String aiKnownUntilMessageId = 'none',
    String recentMessages = '',
    String contextMode = 'askWhenNeeded',
  }) {
    final role = rolePrompt.trim().isEmpty
        ? 'Reply helpfully and concisely.'
        : rolePrompt.trim();
    final recentBlock = recentMessages.trim().isEmpty
        ? '(none)'
        : recentMessages.trim();
    final iso = timestamp.toUtc().toIso8601String();

    return '''
REQUEST_ID: $requestId
SOURCE_CHAT_ID: $sourceChatId
REQUEST_TYPE: ANSWER
CURRENT_MESSAGE_ID: $messageId
AI_KNOWN_UNTIL_MESSAGE_ID: $aiKnownUntilMessageId
CONTEXT_MODE: $contextMode

Chat: $chatTitle
Sender: $senderId
Time: $iso

Instructions:
$role

Recent context, if included:
$recentBlock

User message:
$userMessage

Reply format:
If you need exact recent conversation, reply only:
REQUEST_ID: $requestId
SOURCE_CHAT_ID: $sourceChatId
$contextRequestCommand <number>; <reason>

If you can answer, reply with:
REQUEST_ID: $requestId
SOURCE_CHAT_ID: $sourceChatId
$answerPrefix <final reply>
$contextSeenMarker <latest message id you used>
'''.trim();
  }
}
