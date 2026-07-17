import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'incoming_message.dart';
import 'pipeline_settings.dart';
import 'pipeline_status.dart';
import 'prompt_builder.dart';
import 'response_parser.dart';

/// Minimal transport used by [AiPipelineCoordinator] (TDLib or stub).
abstract class PipelineTransport {
  bool get isReady;
  List<ChatSummary> get chats;
  Stream<IncomingMessage> get newMessages;
  Future<int> sendPlainTextMessage(int chatId, String text);
}

class _PendingTurn {
  _PendingTurn({
    required this.requestId,
    required this.sourceChatId,
    required this.aiChatId,
    required this.afterMessageId,
    required this.originalMessageId,
    required this.replyMode,
  });

  final String requestId;
  final String sourceChatId;
  final int aiChatId;
  final int afterMessageId;
  final int originalMessageId;
  final ReplyMode replyMode;
}

/// Monitors selected chats → prompt → AI destination → parse → draft / auto-send.
class AiPipelineCoordinator {
  AiPipelineCoordinator({
    required this._transport,
    PromptBuilder? promptBuilder,
    ResponseParser? responseParser,
  })  : _promptBuilder = promptBuilder ?? const PromptBuilder(),
        _parser = responseParser ?? const ResponseParser();

  final PipelineTransport _transport;
  final PromptBuilder _promptBuilder;
  final ResponseParser _parser;
  final _uuid = const Uuid();
  final _statusByChat = <int, ChatPipelineStatus>{};
  final _statusController =
      StreamController<Map<int, ChatPipelineStatus>>.broadcast();
  final _seenKeys = <String>{};

  PipelineSettings _settings = const PipelineSettings();
  StreamSubscription<IncomingMessage>? _messagesSub;
  _PendingTurn? _pending;
  Timer? _timeout;
  bool _started = false;

  /// When true (external billing builds), inactive licenses block new pipeline turns.
  bool _requireActiveLicense = false;
  bool _licenseActive = true;

  Stream<Map<int, ChatPipelineStatus>> get statusStream =>
      _statusController.stream;

  Map<int, ChatPipelineStatus> get statuses =>
      Map.unmodifiable(_statusByChat);

  PipelineSettings get settings => _settings;

  ChatPipelineStatus statusFor(int chatId) =>
      _statusByChat[chatId] ?? const ChatPipelineStatus();

  Future<void> start({required PipelineSettings settings}) async {
    if (_started) {
      updateSettings(settings);
      return;
    }
    _started = true;
    _settings = settings;
    await _restoreDrafts();
    _messagesSub = _transport.newMessages.listen(_onMessage);
  }

  void updateSettings(PipelineSettings settings) {
    final destinationChanged =
        settings.aiDestinationChatId != _settings.aiDestinationChatId;
    _settings = settings;
    if (destinationChanged && _pending != null) {
      final src = int.tryParse(_pending!.sourceChatId);
      _clearPending();
      if (src != null) {
        _setStatus(
          src,
          const ChatPipelineStatus(
            phase: PipelinePhase.failed,
            lastError: 'AI destination changed; in-flight turn cancelled.',
          ),
        );
      }
    }
  }

  /// When [requireActive] is true, monitored turns need an active Lemon Squeezy license.
  void updateLicenseGate({required bool requireActive, required bool isActive}) {
    _requireActiveLicense = requireActive;
    _licenseActive = isActive;
  }

  Future<void> dispose() async {
    await _messagesSub?.cancel();
    _timeout?.cancel();
    await _statusController.close();
  }

  Future<void> clearDraft(int chatId) async {
    final current = statusFor(chatId);
    _setStatus(
      chatId,
      current.copyWith(
        phase: PipelinePhase.idle,
        clearDraft: true,
        clearError: true,
        detail: 'Draft cleared',
      ),
    );
    await _persistDrafts();
  }

  Future<void> approveDraft(int chatId) async {
    final draft = statusFor(chatId).pendingDraft;
    if (draft == null || draft.isEmpty) return;
    try {
      await _transport.sendPlainTextMessage(chatId, draft);
      _setStatus(
        chatId,
        const ChatPipelineStatus(
          phase: PipelinePhase.sent,
          detail: 'Draft sent',
        ),
      );
      await _persistDrafts();
    } catch (e) {
      _setStatus(
        chatId,
        ChatPipelineStatus(
          phase: PipelinePhase.failed,
          pendingDraft: draft,
          lastError: 'Failed to send draft: $e',
        ),
      );
    }
  }

  void _onMessage(IncomingMessage message) {
    if (!_transport.isReady) return;
    final key = '${message.chatId}-${message.messageId}';
    if (_seenKeys.contains(key)) return;
    _seenKeys.add(key);
    if (_seenKeys.length > 2000) _seenKeys.clear();

    final dest = _settings.aiDestinationChatId;
    if (dest != null && message.chatId == dest) {
      _handleAiChatMessage(message);
      return;
    }
    _handleMonitoredMessage(message);
  }

  void _handleMonitoredMessage(IncomingMessage message) {
    if (!_settings.pipelineEnabled) return;
    if (message.isOutgoing) return;
    if (message.text.trim().isEmpty) return;
    if (!_settings.hasValidDestination) return;
    if (message.chatId == _settings.aiDestinationChatId) return;

    final chat = _findChat(message.chatId);
    if (chat == null || !chat.isMonitored) return;
    if (chat.isPaused) {
      _setStatus(
        message.chatId,
        ChatPipelineStatus(
          phase: PipelinePhase.idle,
          detail: 'Monitoring paused for this chat',
          pendingDraft: statusFor(message.chatId).pendingDraft,
        ),
      );
      return;
    }

    if (_requireActiveLicense && !_licenseActive) {
      _setStatus(
        message.chatId,
        const ChatPipelineStatus(
          phase: PipelinePhase.failed,
          lastError:
              'Activate a Lemon Squeezy license in Settings → Subscription to run the AI pipeline.',
        ),
      );
      return;
    }

    if (!_settings.consentSatisfied) {
      _setStatus(
        message.chatId,
        const ChatPipelineStatus(
          phase: PipelinePhase.waitingConsent,
          lastError:
              'Grant third-party AI sharing consent in Settings before the pipeline can send.',
        ),
      );
      return;
    }

    if (_pending != null) {
      _setStatus(
        message.chatId,
        ChatPipelineStatus(
          phase: PipelinePhase.idle,
          detail: 'Queued behind in-flight turn for ${_pending!.sourceChatId}',
          pendingDraft: statusFor(message.chatId).pendingDraft,
        ),
      );
      return;
    }

    unawaited(_startTurn(message: message, chat: chat));
  }

  void _handleAiChatMessage(IncomingMessage message) {
    final pending = _pending;
    if (pending == null) return;
    if (message.isOutgoing) return;
    if (message.messageId <= pending.afterMessageId) return;
    if (message.chatId != pending.aiChatId) return;
    unawaited(_finishWithAiReply(message.text));
  }

  Future<void> _startTurn({
    required IncomingMessage message,
    required ChatSummary chat,
  }) async {
    final destId = _settings.aiDestinationChatId!;
    final requestId = _uuid.v4();
    final sourceChatId = '${chat.id}';

    _setStatus(
      chat.id,
      const ChatPipelineStatus(
        phase: PipelinePhase.generating,
        detail: 'Sending prompt to AI destination…',
      ),
    );

    final prompt = _promptBuilder.build(
      requestId: requestId,
      sourceChatId: sourceChatId,
      chatTitle: chat.title,
      senderId: message.senderId,
      messageId: '${message.messageId}',
      userMessage: message.text,
      rolePrompt: _settings.rolePrompt,
      timestamp: message.timestamp,
      answerPrefix: _settings.answerPrefix,
    );

    try {
      final sentId = await _transport.sendPlainTextMessage(destId, prompt);
      _pending = _PendingTurn(
        requestId: requestId,
        sourceChatId: sourceChatId,
        aiChatId: destId,
        afterMessageId: sentId,
        originalMessageId: message.messageId,
        replyMode: chat.replyMode,
      );
      _setStatus(
        chat.id,
        const ChatPipelineStatus(
          phase: PipelinePhase.awaitingAiReply,
          detail: 'Waiting for AI reply…',
        ),
      );
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: 120), () {
        if (_pending?.requestId != requestId) return;
        final src = int.tryParse(_pending!.sourceChatId);
        _clearPending();
        if (src != null) {
          _setStatus(
            src,
            const ChatPipelineStatus(
              phase: PipelinePhase.failed,
              lastError: 'Timed out waiting for AI reply.',
            ),
          );
        }
      });
    } catch (e) {
      _setStatus(
        chat.id,
        ChatPipelineStatus(
          phase: PipelinePhase.failed,
          lastError: 'Failed to send prompt: $e',
        ),
      );
    }
  }

  Future<void> _finishWithAiReply(String raw) async {
    final pending = _pending;
    if (pending == null) return;

    final protocol = _parser.parseProtocol(raw);
    if (protocol.requestId != null &&
        protocol.requestId != pending.requestId) {
      return;
    }
    if (protocol.sourceChatId != null &&
        protocol.sourceChatId != pending.sourceChatId) {
      return;
    }

    final outcome = _parser.parseAnswer(
      raw: raw,
      answerPrefix: _settings.answerPrefix,
    );
    final sourceId = int.parse(pending.sourceChatId);
    _clearPending();

    if (!outcome.isSuccess ||
        outcome.text == null ||
        outcome.text!.trim().isEmpty) {
      _setStatus(
        sourceId,
        const ChatPipelineStatus(
          phase: PipelinePhase.failed,
          lastError: 'Could not parse AI answer.',
        ),
      );
      return;
    }

    final answer = outcome.text!.trim();
    if (pending.replyMode == ReplyMode.autoSend) {
      try {
        await _transport.sendPlainTextMessage(sourceId, answer);
        _setStatus(
          sourceId,
          ChatPipelineStatus(
            phase: PipelinePhase.sent,
            detail: 'Auto-sent reply',
            pendingDraft: null,
          ),
        );
        await _persistDrafts();
      } catch (e) {
        _setStatus(
          sourceId,
          ChatPipelineStatus(
            phase: PipelinePhase.draftReady,
            pendingDraft: answer,
            lastError: 'Auto-send failed; saved as draft. $e',
          ),
        );
        await _persistDrafts();
      }
      return;
    }

    _setStatus(
      sourceId,
      ChatPipelineStatus(
        phase: PipelinePhase.draftReady,
        pendingDraft: answer,
        detail: 'Draft ready for approval',
      ),
    );
    await _persistDrafts();
  }

  ChatSummary? _findChat(int chatId) {
    for (final chat in _transport.chats) {
      if (chat.id == chatId) return chat;
    }
    return null;
  }

  void _clearPending() {
    _timeout?.cancel();
    _timeout = null;
    _pending = null;
  }

  void _setStatus(int chatId, ChatPipelineStatus status) {
    _statusByChat[chatId] = status;
    if (!_statusController.isClosed) {
      _statusController.add(Map.unmodifiable(_statusByChat));
    }
  }

  static const _draftsKey = 'tandem.desktop.pipelineDrafts';

  Future<void> _persistDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final entry in _statusByChat.entries) {
      final draft = entry.value.pendingDraft;
      if (draft != null && draft.isNotEmpty) {
        map['${entry.key}'] = draft;
      }
    }
    await prefs.setString(_draftsKey, jsonEncode(map));
  }

  Future<void> _restoreDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final chatId = int.tryParse(entry.key);
        final draft = entry.value as String?;
        if (chatId == null || draft == null || draft.isEmpty) continue;
        _statusByChat[chatId] = ChatPipelineStatus(
          phase: PipelinePhase.draftReady,
          pendingDraft: draft,
          detail: 'Restored draft',
        );
      }
      if (_statusByChat.isNotEmpty && !_statusController.isClosed) {
        _statusController.add(Map.unmodifiable(_statusByChat));
      }
    } catch (_) {
      // ignore corrupt drafts
    }
  }
}
