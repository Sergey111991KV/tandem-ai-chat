import '../models/models.dart';
import '../pipeline/incoming_message.dart';

/// TDLib integration point. Phase B uses [TdLibTelegramService] when native lib is present.
abstract class TelegramService {
  TelegramAuthPhase get authPhase;
  List<ChatSummary> get chats;
  bool get isReady => authPhase == TelegramAuthPhase.ready;

  /// Fires when auth phase or chat list changes (TDLib async updates).
  Stream<void> get updates;

  /// New text messages (incoming and outgoing) for the AI pipeline.
  Stream<IncomingMessage> get newMessages;

  Future<void> initialize();
  Future<void> submitPhone(String phone);
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);
  Future<void> signOut();

  Future<void> setMonitored(int chatId, bool monitored);
  Future<void> setReplyMode(int chatId, ReplyMode mode);
  Future<void> setPaused(int chatId, bool paused);

  /// Sends plain text; returns the local/server message id when known.
  Future<int> sendPlainTextMessage(int chatId, String text);

  /// Stub / tests: inject a fake inbound message. No-op for live TDLib.
  Future<void> simulateIncomingMessage({
    required int chatId,
    required String text,
    String senderId = 'user',
  }) async {}
}
