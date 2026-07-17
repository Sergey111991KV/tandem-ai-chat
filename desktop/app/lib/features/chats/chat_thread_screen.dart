import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/pipeline/pipeline_status.dart';
import '../../core/providers/app_providers.dart';

class ChatThreadScreen extends ConsumerWidget {
  const ChatThreadScreen({super.key, required this.chatId});

  final int chatId;

  String _phaseLabel(PipelinePhase phase) {
    return switch (phase) {
      PipelinePhase.idle => 'Idle',
      PipelinePhase.waitingConsent => 'Waiting for AI consent',
      PipelinePhase.generating => 'Sending prompt…',
      PipelinePhase.awaitingAiReply => 'Waiting for AI reply…',
      PipelinePhase.draftReady => 'Draft ready',
      PipelinePhase.sent => 'Reply sent',
      PipelinePhase.failed => 'Failed',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telegram = ref.watch(telegramControllerProvider);
    final pipelineUi = ref.watch(pipelineControllerProvider);
    final settingsAsync = ref.watch(pipelineSettingsProvider);
    final matches = telegram.chats.where((c) => c.id == chatId);
    final chat = matches.isEmpty ? null : matches.first;

    if (chat == null) {
      return const Center(child: Text('Chat not found'));
    }

    final notifier = ref.read(telegramControllerProvider.notifier);
    final pipeline = ref.read(pipelineControllerProvider.notifier);
    final status = pipelineUi.forChat(chat.id);
    final settings = settingsAsync.valueOrNull;
    final isDestination = settings?.aiDestinationChatId == chat.id;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chat.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(chat.lastMessagePreview ?? ''),
          const SizedBox(height: 16),
          if (chat.isMonitored || status.phase != PipelinePhase.idle)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: Icon(
                  switch (status.phase) {
                    PipelinePhase.draftReady => Icons.drafts_outlined,
                    PipelinePhase.failed => Icons.error_outline,
                    PipelinePhase.awaitingAiReply ||
                    PipelinePhase.generating =>
                      Icons.hourglass_top,
                    _ => Icons.smart_toy_outlined,
                  },
                ),
                title: Text('Pipeline: ${_phaseLabel(status.phase)}'),
                subtitle: Text(
                  status.lastError ??
                      status.detail ??
                      (settings?.pipelineEnabled == true
                          ? 'Monitoring enabled'
                          : 'Enable the pipeline in Settings'),
                ),
              ),
            ),
          if (isDestination)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'This chat is your AI destination. Incoming bot replies are parsed here.',
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Monitor this chat'),
                    subtitle: const Text(
                      'When enabled, new messages can be forwarded to your AI assistant.',
                    ),
                    value: chat.isMonitored,
                    onChanged: (v) => notifier.setMonitored(chat.id, v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pause pipeline'),
                    subtitle: const Text(
                      'Keep monitoring selected, but skip AI turns for this chat.',
                    ),
                    value: chat.isPaused,
                    onChanged: chat.isMonitored
                        ? (v) => notifier.setPaused(chat.id, v)
                        : null,
                  ),
                  const Divider(height: 28),
                  Text(
                    'Reply mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ReplyMode>(
                    segments: ReplyMode.values
                        .map(
                          (mode) => ButtonSegment(
                            value: mode,
                            label: Text(mode.label),
                          ),
                        )
                        .toList(),
                    selected: {chat.replyMode},
                    onSelectionChanged: (selection) {
                      notifier.setReplyMode(chat.id, selection.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (status.pendingDraft != null &&
              status.pendingDraft!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI draft',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(status.pendingDraft!),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () => pipeline.approveDraft(chat.id),
                          child: const Text('Send draft'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => pipeline.clearDraft(chat.id),
                          child: const Text('Discard'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (telegram.isStub && chat.isMonitored) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await pipeline.simulateIncoming(
                  chatId: chat.id,
                  text: 'Hello from the demo inbox — please draft a short reply.',
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Simulate inbound message (stub)'),
            ),
          ],
          const Spacer(),
          Text(
            chat.isMonitored
                ? 'Monitored: new inbound texts are sent to your AI destination when the pipeline is enabled.'
                : 'Enable monitoring to include this chat in the AI pipeline.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
