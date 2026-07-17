import 'dart:async';

import 'package:tdlib/td_client.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../pipeline/ai_pipeline_coordinator.dart';
import '../pipeline/incoming_message.dart';
import '../tdlib/tdlib_session.dart';
import 'chat_preferences_store.dart';
import 'telegram_service.dart';

class TdLibTelegramService extends TelegramService implements PipelineTransport {
  TdLibTelegramService({
    required AppConfig config,
    required this._libraryPath,
  }) : _session = TdLibSession(config: config);

  final TdLibSession _session;
  final String _libraryPath;
  final ChatPreferencesStore _prefs = ChatPreferencesStore();

  TelegramAuthPhase _phase = TelegramAuthPhase.disconnected;
  List<ChatSummary> _chats = const [];

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get updates => _changes.stream;

  @override
  Stream<IncomingMessage> get newMessages => _session.newMessages;

  @override
  TelegramAuthPhase get authPhase => _phase;

  @override
  bool get isReady => _phase == TelegramAuthPhase.ready;

  @override
  List<ChatSummary> get chats => List.unmodifiable(_chats);

  @override
  Future<void> initialize() async {
    await TdPlugin.initialize(_libraryPath);
    await _session.start();
    _session.phaseStream.listen((phase) {
      _phase = phase;
      _changes.add(null);
    });
    _session.chatsStream.listen((chats) {
      _chats = chats;
      _changes.add(null);
    });
    final saved = await _prefs.loadAll();
    _session.applyChatPreferences(saved);
    _phase = _session.phase;
    _chats = _session.chats;
  }

  @override
  Future<void> submitPhone(String phone) => _session.submitPhone(phone);

  @override
  Future<void> submitCode(String code) => _session.submitCode(code);

  @override
  Future<void> submitPassword(String password) =>
      _session.submitPassword(password);

  @override
  Future<void> signOut() => _session.signOut();

  @override
  Future<void> setMonitored(int chatId, bool monitored) async {
    _session.updateChatLocal(chatId, monitored: monitored);
    _chats = _session.chats;
    await _prefs.save(
      chatId,
      _session.chatPreferencesFor(chatId),
    );
    _changes.add(null);
  }

  @override
  Future<void> setReplyMode(int chatId, ReplyMode mode) async {
    _session.updateChatLocal(chatId, mode: mode);
    _chats = _session.chats;
    await _prefs.save(
      chatId,
      _session.chatPreferencesFor(chatId),
    );
    _changes.add(null);
  }

  @override
  Future<void> setPaused(int chatId, bool paused) async {
    _session.updateChatLocal(chatId, paused: paused);
    _chats = _session.chats;
    await _prefs.save(
      chatId,
      _session.chatPreferencesFor(chatId),
    );
    _changes.add(null);
  }

  @override
  Future<int> sendPlainTextMessage(int chatId, String text) =>
      _session.sendPlainTextMessage(chatId, text);
}
