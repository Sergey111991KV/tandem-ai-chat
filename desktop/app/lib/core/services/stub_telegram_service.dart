import 'dart:async';

import '../models/models.dart';
import '../pipeline/ai_pipeline_coordinator.dart';
import '../pipeline/incoming_message.dart';
import '../pipeline/prompt_builder.dart';
import '../pipeline/response_parser.dart';
import 'telegram_service.dart';

/// Demo data when the TDLib native library is unavailable.
///
/// Simulates an AI destination reply so the desktop pipeline can be exercised
/// without a real Telegram session.
class StubTelegramService extends TelegramService implements PipelineTransport {
  StubTelegramService();

  TelegramAuthPhase _phase = TelegramAuthPhase.disconnected;
  int _nextMessageId = 1000;
  final _changes = StreamController<void>.broadcast();
  final _messages = StreamController<IncomingMessage>.broadcast();

  final List<ChatSummary> _chats = [
    const ChatSummary(
      id: 1,
      title: 'Support group (demo)',
      isMonitored: true,
      replyMode: ReplyMode.draft,
      lastMessagePreview: 'Can you review the latest draft?',
    ),
    const ChatSummary(
      id: 2,
      title: 'AI assistant bot (demo)',
      isMonitored: false,
      replyMode: ReplyMode.draft,
      lastMessagePreview: 'Ready when you are.',
    ),
  ];

  @override
  Stream<void> get updates => _changes.stream;

  @override
  Stream<IncomingMessage> get newMessages => _messages.stream;

  @override
  TelegramAuthPhase get authPhase => _phase;

  @override
  bool get isReady => _phase == TelegramAuthPhase.ready;

  @override
  List<ChatSummary> get chats => List.unmodifiable(_chats);

  @override
  Future<void> initialize() async {
    _phase = TelegramAuthPhase.waitingPhone;
    _changes.add(null);
  }

  @override
  Future<void> submitPhone(String phone) async {
    if (phone.trim().isEmpty) return;
    _phase = TelegramAuthPhase.waitingCode;
    _changes.add(null);
  }

  @override
  Future<void> submitCode(String code) async {
    if (code.trim().length < 4) return;
    _phase = TelegramAuthPhase.ready;
    _changes.add(null);
  }

  @override
  Future<void> submitPassword(String password) async {
    if (password.isNotEmpty) {
      _phase = TelegramAuthPhase.ready;
      _changes.add(null);
    }
  }

  @override
  Future<void> signOut() async {
    _phase = TelegramAuthPhase.waitingPhone;
    _changes.add(null);
  }

  @override
  Future<void> setMonitored(int chatId, bool monitored) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index == -1) return;
    _chats[index] = _chats[index].copyWith(isMonitored: monitored);
    _changes.add(null);
  }

  @override
  Future<void> setReplyMode(int chatId, ReplyMode mode) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index == -1) return;
    _chats[index] = _chats[index].copyWith(replyMode: mode);
    _changes.add(null);
  }

  @override
  Future<void> setPaused(int chatId, bool paused) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index == -1) return;
    _chats[index] = _chats[index].copyWith(isPaused: paused);
    _changes.add(null);
  }

  @override
  Future<int> sendPlainTextMessage(int chatId, String text) async {
    final id = ++_nextMessageId;
    _messages.add(
      IncomingMessage(
        chatId: chatId,
        messageId: id,
        text: text,
        isOutgoing: true,
        senderId: 'me',
        timestamp: DateTime.now(),
      ),
    );

    final preview = text.length > 80 ? '${text.substring(0, 80)}…' : text;
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index >= 0) {
      _chats[index] = _chats[index].copyWith(lastMessagePreview: preview);
      _changes.add(null);
    }

    // Echo a protocol-shaped AI reply when a pipeline prompt is sent.
    if (_looksLikePipelinePrompt(text)) {
      unawaited(_emitStubAiReply(chatId: chatId, prompt: text));
    }
    return id;
  }

  @override
  Future<void> simulateIncomingMessage({
    required int chatId,
    required String text,
    String senderId = 'user',
  }) async {
    final id = ++_nextMessageId;
    _messages.add(
      IncomingMessage(
        chatId: chatId,
        messageId: id,
        text: text,
        isOutgoing: false,
        senderId: senderId,
        timestamp: DateTime.now(),
      ),
    );
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index >= 0) {
      _chats[index] = _chats[index].copyWith(lastMessagePreview: text);
      _changes.add(null);
    }
  }

  bool _looksLikePipelinePrompt(String text) {
    return text.contains('REQUEST_ID:') &&
        text.contains('SOURCE_CHAT_ID:') &&
        text.contains('User message:');
  }

  Future<void> _emitStubAiReply({
    required int chatId,
    required String prompt,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final requestId =
        ResponseParser.lineValue(raw: prompt, label: 'REQUEST_ID:') ??
            'stub-request';
    final sourceChatId =
        ResponseParser.lineValue(raw: prompt, label: 'SOURCE_CHAT_ID:') ?? '1';
    final userMessage =
        ResponseParser.textAfterLabel(raw: prompt, label: 'User message:') ??
            prompt;
    // Strip reply-format instructions that follow the user message block.
    final messageOnly = userMessage
        .split('Reply format:')
        .first
        .trim();
    final reply = '''
REQUEST_ID: $requestId
SOURCE_CHAT_ID: $sourceChatId
Answer: Stub AI reply: $messageOnly
${PromptBuilder.contextSeenMarker} 0
'''.trim();

    final id = ++_nextMessageId;
    _messages.add(
      IncomingMessage(
        chatId: chatId,
        messageId: id,
        text: reply,
        isOutgoing: false,
        senderId: 'ai-bot',
        timestamp: DateTime.now(),
      ),
    );
  }
}
