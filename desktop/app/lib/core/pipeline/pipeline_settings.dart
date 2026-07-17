/// Persisted AI pipeline preferences (SharedPreferences-backed).
class PipelineSettings {
  const PipelineSettings({
    this.pipelineEnabled = false,
    this.aiDestinationChatId,
    this.aiDestinationTitle,
    this.rolePrompt = defaultRolePrompt,
    this.hasThirdPartyConsent = false,
    this.consentForChatId,
    this.answerPrefix = 'Answer:',
  });

  static const defaultRolePrompt =
      'You are a helpful assistant drafting concise Telegram replies.';

  final bool pipelineEnabled;
  final int? aiDestinationChatId;
  final String? aiDestinationTitle;
  final String rolePrompt;
  final bool hasThirdPartyConsent;
  /// Destination chat id that consent was granted for; must match [aiDestinationChatId].
  final String? consentForChatId;
  final String answerPrefix;

  bool get hasValidDestination =>
      aiDestinationChatId != null && aiDestinationChatId != 0;

  bool get consentSatisfied =>
      hasThirdPartyConsent &&
      hasValidDestination &&
      consentForChatId == '${aiDestinationChatId!}';

  PipelineSettings copyWith({
    bool? pipelineEnabled,
    int? aiDestinationChatId,
    String? aiDestinationTitle,
    String? rolePrompt,
    bool? hasThirdPartyConsent,
    String? consentForChatId,
    String? answerPrefix,
    bool clearDestination = false,
    bool clearConsent = false,
  }) {
    return PipelineSettings(
      pipelineEnabled: pipelineEnabled ?? this.pipelineEnabled,
      aiDestinationChatId: clearDestination
          ? null
          : (aiDestinationChatId ?? this.aiDestinationChatId),
      aiDestinationTitle: clearDestination
          ? null
          : (aiDestinationTitle ?? this.aiDestinationTitle),
      rolePrompt: rolePrompt ?? this.rolePrompt,
      hasThirdPartyConsent: clearConsent
          ? false
          : (hasThirdPartyConsent ?? this.hasThirdPartyConsent),
      consentForChatId:
          clearConsent ? null : (consentForChatId ?? this.consentForChatId),
      answerPrefix: answerPrefix ?? this.answerPrefix,
    );
  }

  Map<String, dynamic> toJson() => {
        'pipelineEnabled': pipelineEnabled,
        'aiDestinationChatId': aiDestinationChatId,
        'aiDestinationTitle': aiDestinationTitle,
        'rolePrompt': rolePrompt,
        'hasThirdPartyConsent': hasThirdPartyConsent,
        'consentForChatId': consentForChatId,
        'answerPrefix': answerPrefix,
      };

  factory PipelineSettings.fromJson(Map<String, dynamic> json) {
    return PipelineSettings(
      pipelineEnabled: json['pipelineEnabled'] as bool? ?? false,
      aiDestinationChatId: json['aiDestinationChatId'] as int?,
      aiDestinationTitle: json['aiDestinationTitle'] as String?,
      rolePrompt: json['rolePrompt'] as String? ?? defaultRolePrompt,
      hasThirdPartyConsent: json['hasThirdPartyConsent'] as bool? ?? false,
      consentForChatId: json['consentForChatId'] as String?,
      answerPrefix: json['answerPrefix'] as String? ?? 'Answer:',
    );
  }
}
