import 'prompt_builder.dart';

enum ParseFallback { useFullText, returnEmpty }

class ParseOutcome {
  const ParseOutcome.success(this.text) : isSuccess = true;
  const ParseOutcome.failure()
      : text = null,
        isSuccess = false;

  final bool isSuccess;
  final String? text;
}

class ProtocolResponse {
  const ProtocolResponse({
    required this.raw,
    this.requestId,
    this.sourceChatId,
  });

  final String raw;
  final String? requestId;
  final String? sourceChatId;

  String? finalAnswer({String prefix = 'Answer:'}) =>
      ResponseParser.textAfterLabel(raw: raw, label: prefix);
}

/// Simplified AI protocol + answer extraction (behavior-aligned with Mac ParseEngine).
class ResponseParser {
  const ResponseParser();

  ProtocolResponse parseProtocol(String raw) {
    return ProtocolResponse(
      raw: raw,
      requestId: lineValue(raw: raw, label: 'REQUEST_ID:'),
      sourceChatId: lineValue(raw: raw, label: 'SOURCE_CHAT_ID:'),
    );
  }

  ParseOutcome parseAnswer({
    required String raw,
    String answerPrefix = 'Answer:',
    ParseFallback fallback = ParseFallback.useFullText,
  }) {
    final trimmed = raw.trim();
    if (answerPrefix.trim().isNotEmpty) {
      final extracted = textAfterLabel(raw: trimmed, label: answerPrefix);
      if (extracted != null && extracted.isNotEmpty) {
        return ParseOutcome.success(
          cleanFinalAnswer(
            extracted,
            seenMarker: PromptBuilder.contextSeenMarker,
          ),
        );
      }
    }

    switch (fallback) {
      case ParseFallback.useFullText:
        if (trimmed.isEmpty) return const ParseOutcome.failure();
        return ParseOutcome.success(
          cleanFinalAnswer(
            trimmed,
            seenMarker: PromptBuilder.contextSeenMarker,
          ),
        );
      case ParseFallback.returnEmpty:
        return const ParseOutcome.failure();
    }
  }

  static String? lineValue({required String raw, required String label}) {
    String? lastMatch;
    for (final line in raw.split('\n')) {
      final value = _valueAfterLabel(line, label);
      if (value != null && value.isNotEmpty) {
        lastMatch = value;
      }
    }
    return lastMatch;
  }

  static String? textAfterLabel({required String raw, required String label}) {
    final lines = raw.split('\n');
    String? lastMatch;
    for (var i = 0; i < lines.length; i++) {
      final first = _valueAfterLabel(lines[i], label);
      if (first == null) continue;
      final tail = [first, ...lines.skip(i + 1)].join('\n').trim();
      if (tail.isNotEmpty) lastMatch = tail;
    }
    return lastMatch;
  }

  static String cleanFinalAnswer(
    String text, {
    String seenMarker = PromptBuilder.contextSeenMarker,
  }) {
    const protocolLabels = [
      'REQUEST_ID:',
      'SOURCE_CHAT_ID:',
      'REQUEST_TYPE:',
      'CURRENT_MESSAGE_ID:',
      'AI_KNOWN_UNTIL_MESSAGE_ID:',
      'CONTEXT_MODE:',
      'ORIGINAL_MESSAGE_ID:',
    ];
    final labels = [...protocolLabels, seenMarker];
    final lines = text.split('\n').where((line) {
      return !labels.any((label) => _valueAfterLabel(line, label) != null);
    });
    return lines.join('\n').trim();
  }

  static String? _valueAfterLabel(String rawLine, String label) {
    final line = rawLine.trim();
    final lowerLine = line.toLowerCase();
    final lowerLabel = label.toLowerCase().trim();
    if (!lowerLine.startsWith(lowerLabel)) return null;
    return line.substring(label.trim().length).trim();
  }
}
