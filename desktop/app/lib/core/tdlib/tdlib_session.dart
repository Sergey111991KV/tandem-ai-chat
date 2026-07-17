import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// ignore: implementation_imports
import 'package:tdlib/src/tdclient/event_subject.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:tdlib/td_client.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../pipeline/incoming_message.dart';

/// Low-level TDLib client: auth state machine + chat list sync.
class TdLibSession {
  TdLibSession({required this._config});

  final AppConfig _config;
  final _uuid = const Uuid();
  int? _clientId;
  StreamSubscription<td.TdObject>? _updates;

  TelegramAuthPhase _phase = TelegramAuthPhase.disconnected;
  final List<ChatSummary> _chats = [];
  String? _codeHint;

  TelegramAuthPhase get phase => _phase;
  List<ChatSummary> get chats => List.unmodifiable(_chats);
  String? get codeHint => _codeHint;

  final _phaseController = StreamController<TelegramAuthPhase>.broadcast();
  final _chatsController = StreamController<List<ChatSummary>>.broadcast();
  final _messagesController = StreamController<IncomingMessage>.broadcast();

  Stream<TelegramAuthPhase> get phaseStream => _phaseController.stream;
  Stream<List<ChatSummary>> get chatsStream => _chatsController.stream;
  Stream<IncomingMessage> get newMessages => _messagesController.stream;

  Future<void> start() async {
    if (_clientId != null) return;
    await EventSubject.initialize();
    _clientId = tdCreate();
    _updates = EventSubject.instance.listen(_clientId!).listen(_onUpdate);
    _setPhase(TelegramAuthPhase.disconnected);
  }

  Future<void> dispose() async {
    await _updates?.cancel();
    if (_clientId != null) {
      tdSend(_clientId!, const td.Close());
      _clientId = null;
    }
    await _phaseController.close();
    await _chatsController.close();
    await _messagesController.close();
  }

  /// Sends plain text and returns the resulting message id.
  Future<int> sendPlainTextMessage(int chatId, String text) async {
    _ensureClient();
    final message = await _send<td.Message>(
      td.SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        replyTo: null,
        options: null,
        replyMarkup: null,
        inputMessageContent: td.InputMessageText(
          text: td.FormattedText(text: text, entities: const []),
          disableWebPagePreview: true,
          clearDraft: true,
        ),
      ),
    );
    return message.id;
  }

  Future<void> submitPhone(String phone) async {
    _ensureClient();
    await _send(td.SetAuthenticationPhoneNumber(
      phoneNumber: phone.trim(),
      settings: null,
    ));
  }

  Future<void> submitCode(String code) async {
    _ensureClient();
    await _send(td.CheckAuthenticationCode(code: code.trim()));
  }

  Future<void> submitPassword(String password) async {
    _ensureClient();
    await _send(td.CheckAuthenticationPassword(password: password));
  }

  Future<void> signOut() async {
    _ensureClient();
    await _send(const td.LogOut());
    _chats.clear();
    _emitChats();
  }

  void _ensureClient() {
    if (_clientId == null) {
      throw StateError('TDLib client not started');
    }
  }

  Future<T> _send<T extends td.TdObject>(td.TdFunction request) async {
    final extra = _uuid.v4();
    final completer = Completer<td.TdObject>();
    late StreamSubscription<td.TdObject> sub;
    sub = EventSubject.instance.listen(_clientId!).listen((event) {
      if (event.extra == extra) {
        completer.complete(event);
        sub.cancel();
      }
    });
    tdSend(_clientId!, request, extra);
    final result = await completer.future.timeout(const Duration(seconds: 60));
    if (result is td.TdError) {
      throw TdLibException(result.message);
    }
    return result as T;
  }

  void _onUpdate(td.TdObject update) {
    if (update is td.UpdateAuthorizationState) {
      unawaited(_handleAuthState(update.authorizationState));
    } else if (update is td.UpdateNewChat) {
      _upsertChat(update.chat);
    } else if (update is td.UpdateNewMessage) {
      _emitIncoming(update.message);
    }
  }

  void _emitIncoming(td.Message message) {
    final content = message.content;
    if (content is! td.MessageText) return;
    final text = content.text.text.trim();
    if (text.isEmpty) return;
    if (_messagesController.isClosed) return;
    _messagesController.add(
      IncomingMessage(
        chatId: message.chatId,
        messageId: message.id,
        text: text,
        isOutgoing: message.isOutgoing,
        senderId: _senderLabel(message.senderId),
        timestamp: DateTime.fromMillisecondsSinceEpoch(message.date * 1000),
      ),
    );

    final index = _chats.indexWhere((c) => c.id == message.chatId);
    if (index >= 0) {
      _chats[index] = _chats[index].copyWith(lastMessagePreview: text);
      _emitChats();
    }
  }

  String _senderLabel(td.MessageSender sender) {
    if (sender is td.MessageSenderUser) return 'user:${sender.userId}';
    if (sender is td.MessageSenderChat) return 'chat:${sender.chatId}';
    return 'unknown';
  }

  Future<void> _handleAuthState(td.AuthorizationState state) async {
    if (state is td.AuthorizationStateWaitTdlibParameters) {
      await _applyTdlibParameters();
    } else if (state is td.AuthorizationStateWaitPhoneNumber) {
      _setPhase(TelegramAuthPhase.waitingPhone);
    } else if (state is td.AuthorizationStateWaitCode) {
      _codeHint = state.codeInfo.phoneNumber;
      _setPhase(TelegramAuthPhase.waitingCode);
    } else if (state is td.AuthorizationStateWaitPassword) {
      _setPhase(TelegramAuthPhase.waitingPassword);
    } else if (state is td.AuthorizationStateReady) {
      _setPhase(TelegramAuthPhase.ready);
      await _loadChats();
    } else if (state is td.AuthorizationStateClosed) {
      _setPhase(TelegramAuthPhase.disconnected);
    }
  }

  Future<void> _applyTdlibParameters() async {
    if (!_config.tdlib.isConfigured) {
      throw TdLibException(
        'Telegram API credentials missing. Set tdlib.apiId and tdlib.apiHash in '
        'desktop/config/app_config.local.json (from my.telegram.org).',
      );
    }

    final support = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(support.path, 'tdlib'));
    final filesDir = Directory(p.join(dbDir.path, 'files'));
    await dbDir.create(recursive: true);
    await filesDir.create(recursive: true);

    _ensureClient();
    tdSend(
      _clientId!,
      td.SetTdlibParameters(
        useTestDc: false,
        databaseDirectory: dbDir.path,
        filesDirectory: filesDir.path,
        databaseEncryptionKey: '',
        useFileDatabase: true,
        useChatInfoDatabase: true,
        useMessageDatabase: true,
        useSecretChats: false,
        apiId: _config.tdlib.apiId,
        apiHash: _config.tdlib.apiHash,
        systemLanguageCode: Platform.localeName.split('_').first,
        deviceModel: 'Desktop',
        systemVersion: Platform.operatingSystemVersion,
        applicationVersion: '1.0.0',
        enableStorageOptimizer: true,
        ignoreFileNames: false,
      ),
    );
  }

  Future<void> _loadChats() async {
    await _send(const td.LoadChats(limit: 100));
    final chats = await _send<td.Chats>(const td.GetChats(limit: 100));
    _chats.clear();
    for (final id in chats.chatIds) {
      try {
        final chat = await _send<td.Chat>(td.GetChat(chatId: id));
        _upsertChat(chat);
      } catch (_) {
        // Skip individual chat load failures.
      }
    }
    _emitChats();
  }

  void _upsertChat(td.Chat chat) {
    final summary = ChatSummary(
      id: chat.id,
      title: chat.title,
      isMonitored: false,
      replyMode: ReplyMode.draft,
      lastMessagePreview: _messagePreview(chat.lastMessage),
    );
    final index = _chats.indexWhere((c) => c.id == chat.id);
    if (index >= 0) {
      final existing = _chats[index];
      _chats[index] = summary.copyWith(
        isMonitored: existing.isMonitored,
        replyMode: existing.replyMode,
        isPaused: existing.isPaused,
      );
    } else {
      _chats.add(summary);
    }
    _emitChats();
  }

  String? _messagePreview(td.Message? message) {
    if (message == null) return null;
    final content = message.content;
    if (content is td.MessageText) {
      return content.text.text;
    }
    return null;
  }

  void _setPhase(TelegramAuthPhase phase) {
    _phase = phase;
    _phaseController.add(phase);
  }

  void _emitChats() {
    _chatsController.add(List.unmodifiable(_chats));
  }

  void applyChatPreferences(Map<int, ChatPreferences> prefs) {
    for (var i = 0; i < _chats.length; i++) {
      final pref = prefs[_chats[i].id];
      if (pref != null) {
        _chats[i] = _chats[i].copyWith(
          isMonitored: pref.isMonitored,
          replyMode: pref.replyMode,
          isPaused: pref.isPaused,
        );
      }
    }
    _emitChats();
  }

  ChatPreferences chatPreferencesFor(int chatId) {
    final chat = _chats.firstWhere((c) => c.id == chatId);
    return ChatPreferences(
      isMonitored: chat.isMonitored,
      replyMode: chat.replyMode,
      isPaused: chat.isPaused,
    );
  }

  void updateChatLocal(
    int chatId, {
    bool? monitored,
    ReplyMode? mode,
    bool? paused,
  }) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index < 0) return;
    _chats[index] = _chats[index].copyWith(
      isMonitored: monitored,
      replyMode: mode,
      isPaused: paused,
    );
    _emitChats();
  }
}

class ChatPreferences {
  const ChatPreferences({
    required this.isMonitored,
    required this.replyMode,
    this.isPaused = false,
  });

  final bool isMonitored;
  final ReplyMode replyMode;
  final bool isPaused;

  Map<String, dynamic> toJson() => {
        'monitored': isMonitored,
        'replyMode': replyMode.name,
        'paused': isPaused,
      };

  factory ChatPreferences.fromJson(Map<String, dynamic> json) {
    return ChatPreferences(
      isMonitored: json['monitored'] as bool? ?? false,
      replyMode: ReplyMode.values.byName(
        json['replyMode'] as String? ?? ReplyMode.draft.name,
      ),
      isPaused: json['paused'] as bool? ?? false,
    );
  }
}

class TdLibException implements Exception {
  TdLibException(this.message);
  final String message;
  @override
  String toString() => message;
}
