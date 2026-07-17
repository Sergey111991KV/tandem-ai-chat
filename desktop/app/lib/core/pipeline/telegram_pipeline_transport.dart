import '../models/models.dart';
import '../services/telegram_service.dart';
import 'ai_pipeline_coordinator.dart';
import 'incoming_message.dart';

/// Adapts any [TelegramService] to [PipelineTransport].
class TelegramPipelineTransport implements PipelineTransport {
  TelegramPipelineTransport(this._service);

  final TelegramService _service;

  @override
  bool get isReady => _service.isReady;

  @override
  List<ChatSummary> get chats => _service.chats;

  @override
  Stream<IncomingMessage> get newMessages => _service.newMessages;

  @override
  Future<int> sendPlainTextMessage(int chatId, String text) =>
      _service.sendPlainTextMessage(chatId, text);
}
