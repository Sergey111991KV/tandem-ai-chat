import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tandem_desktop/core/models/models.dart';
import 'package:tandem_desktop/core/pipeline/ai_pipeline_coordinator.dart';
import 'package:tandem_desktop/core/pipeline/incoming_message.dart';
import 'package:tandem_desktop/core/pipeline/pipeline_settings.dart';
import 'package:tandem_desktop/core/pipeline/pipeline_status.dart';
import 'package:tandem_desktop/core/pipeline/prompt_builder.dart';
import 'package:tandem_desktop/core/pipeline/response_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PromptBuilder', () {
    test('includes protocol fields and role', () {
      final prompt = const PromptBuilder().build(
        requestId: 'req-1',
        sourceChatId: '42',
        chatTitle: 'Support',
        senderId: 'user:1',
        messageId: '99',
        userMessage: 'Need help',
        rolePrompt: 'Be brief',
        timestamp: DateTime.utc(2026, 1, 1),
      );

      expect(prompt, contains('REQUEST_ID: req-1'));
      expect(prompt, contains('SOURCE_CHAT_ID: 42'));
      expect(prompt, contains('Be brief'));
      expect(prompt, contains('Need help'));
      expect(prompt, contains('Answer:'));
    });
  });

  group('ResponseParser', () {
    test('extracts answer after protocol lines', () {
      const raw = '''
REQUEST_ID: req-1
SOURCE_CHAT_ID: 42
Answer: Hello there
CONTEXT_SEEN_UNTIL: 99
''';
      final outcome = const ResponseParser().parseAnswer(raw: raw);
      expect(outcome.isSuccess, isTrue);
      expect(outcome.text, 'Hello there');
    });

    test('falls back to full text when prefix missing', () {
      final outcome = const ResponseParser().parseAnswer(
        raw: 'plain reply',
        fallback: ParseFallback.useFullText,
      );
      expect(outcome.text, 'plain reply');
    });

    test('reads REQUEST_ID from protocol', () {
      final parsed = const ResponseParser().parseProtocol(
        'REQUEST_ID: abc\nSOURCE_CHAT_ID: 7\nAnswer: ok',
      );
      expect(parsed.requestId, 'abc');
      expect(parsed.sourceChatId, '7');
    });
  });

  group('AiPipelineCoordinator', () {
    late _FakeTransport transport;
    late AiPipelineCoordinator coordinator;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      transport = _FakeTransport();
      coordinator = AiPipelineCoordinator(transport: transport);
      await coordinator.start(
        settings: const PipelineSettings(
          pipelineEnabled: true,
          aiDestinationChatId: 2,
          aiDestinationTitle: 'AI bot',
          hasThirdPartyConsent: true,
          consentForChatId: '2',
          rolePrompt: 'Be helpful',
        ),
      );
    });

    tearDown(() async {
      await coordinator.dispose();
    });

    test('draft mode stores pending draft from AI reply', () async {
      transport.emit(
        IncomingMessage(
          chatId: 1,
          messageId: 10,
          text: 'Can you help?',
          isOutgoing: false,
          senderId: 'user:1',
          timestamp: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(transport.sent.length, 1);
      expect(transport.sent.first.chatId, 2);
      expect(transport.sent.first.text, contains('REQUEST_ID:'));

      final prompt = transport.sent.first.text;
      final requestId =
          ResponseParser.lineValue(raw: prompt, label: 'REQUEST_ID:')!;

      transport.emit(
        IncomingMessage(
          chatId: 2,
          messageId: transport.sent.first.messageId + 1,
          text: '''
REQUEST_ID: $requestId
SOURCE_CHAT_ID: 1
Answer: Sure, happy to help.
CONTEXT_SEEN_UNTIL: 10
''',
          isOutgoing: false,
          senderId: 'bot',
          timestamp: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final status = coordinator.statusFor(1);
      expect(status.phase, PipelinePhase.draftReady);
      expect(status.pendingDraft, 'Sure, happy to help.');
    });

    test('blocks without consent', () async {
      coordinator.updateSettings(
        const PipelineSettings(
          pipelineEnabled: true,
          aiDestinationChatId: 2,
          aiDestinationTitle: 'AI bot',
          hasThirdPartyConsent: false,
        ),
      );

      transport.emit(
        IncomingMessage(
          chatId: 1,
          messageId: 11,
          text: 'Hello',
          isOutgoing: false,
          senderId: 'user:1',
          timestamp: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(transport.sent, isEmpty);
      expect(coordinator.statusFor(1).phase, PipelinePhase.waitingConsent);
    });

    test('auto-send delivers to source chat', () async {
      transport.chatList = [
        const ChatSummary(
          id: 1,
          title: 'Support',
          isMonitored: true,
          replyMode: ReplyMode.autoSend,
        ),
        const ChatSummary(
          id: 2,
          title: 'AI bot',
          isMonitored: false,
          replyMode: ReplyMode.draft,
        ),
      ];

      transport.emit(
        IncomingMessage(
          chatId: 1,
          messageId: 20,
          text: 'Ping',
          isOutgoing: false,
          senderId: 'user:1',
          timestamp: DateTime.now(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(transport.sent, isNotEmpty);
      final promptSend = transport.sent.first;
      final requestId =
          ResponseParser.lineValue(raw: promptSend.text, label: 'REQUEST_ID:')!;

      transport.emit(
        IncomingMessage(
          chatId: 2,
          messageId: promptSend.messageId + 1,
          text: '''
REQUEST_ID: $requestId
SOURCE_CHAT_ID: 1
Answer: Pong
''',
          isOutgoing: false,
          senderId: 'bot',
          timestamp: DateTime.now(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(transport.sent.length, 2);
      expect(transport.sent.last.chatId, 1);
      expect(transport.sent.last.text, 'Pong');
      expect(coordinator.statusFor(1).phase, PipelinePhase.sent);
    });

    test('blocks when license gate requires active license', () async {
      coordinator.updateLicenseGate(requireActive: true, isActive: false);
      transport.emit(
        IncomingMessage(
          chatId: 1,
          messageId: 30,
          text: 'Need license',
          isOutgoing: false,
          senderId: 'user:1',
          timestamp: DateTime.now(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(transport.sent, isEmpty);
      expect(coordinator.statusFor(1).phase, PipelinePhase.failed);
      expect(coordinator.statusFor(1).lastError, contains('license'));
    });

    test('skips paused monitored chats', () async {
      transport.chatList = [
        const ChatSummary(
          id: 1,
          title: 'Support',
          isMonitored: true,
          replyMode: ReplyMode.draft,
          isPaused: true,
        ),
        const ChatSummary(
          id: 2,
          title: 'AI bot',
          isMonitored: false,
          replyMode: ReplyMode.draft,
        ),
      ];
      transport.emit(
        IncomingMessage(
          chatId: 1,
          messageId: 31,
          text: 'Paused',
          isOutgoing: false,
          senderId: 'user:1',
          timestamp: DateTime.now(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(transport.sent, isEmpty);
      expect(coordinator.statusFor(1).detail, contains('paused'));
    });
  });
}

class _FakeTransport implements PipelineTransport {
  final _controller = StreamController<IncomingMessage>.broadcast();
  final sent = <({int chatId, String text, int messageId})>[];
  var _id = 100;

  List<ChatSummary> chatList = [
    const ChatSummary(
      id: 1,
      title: 'Support',
      isMonitored: true,
      replyMode: ReplyMode.draft,
    ),
    const ChatSummary(
      id: 2,
      title: 'AI bot',
      isMonitored: false,
      replyMode: ReplyMode.draft,
    ),
  ];

  @override
  bool get isReady => true;

  @override
  List<ChatSummary> get chats => chatList;

  @override
  Stream<IncomingMessage> get newMessages => _controller.stream;

  @override
  Future<int> sendPlainTextMessage(int chatId, String text) async {
    final id = ++_id;
    sent.add((chatId: chatId, text: text, messageId: id));
    return id;
  }

  void emit(IncomingMessage message) => _controller.add(message);
}
