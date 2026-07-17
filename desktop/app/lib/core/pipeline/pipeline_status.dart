enum PipelinePhase {
  idle,
  waitingConsent,
  generating,
  awaitingAiReply,
  draftReady,
  sent,
  failed,
}

class ChatPipelineStatus {
  const ChatPipelineStatus({
    this.phase = PipelinePhase.idle,
    this.detail,
    this.pendingDraft,
    this.lastError,
  });

  final PipelinePhase phase;
  final String? detail;
  final String? pendingDraft;
  final String? lastError;

  ChatPipelineStatus copyWith({
    PipelinePhase? phase,
    String? detail,
    String? pendingDraft,
    String? lastError,
    bool clearDraft = false,
    bool clearError = false,
  }) {
    return ChatPipelineStatus(
      phase: phase ?? this.phase,
      detail: detail ?? this.detail,
      pendingDraft: clearDraft ? null : (pendingDraft ?? this.pendingDraft),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}
