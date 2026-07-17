import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tandem_colors.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telegram = ref.watch(telegramControllerProvider);
    final monitored = telegram.chats.where((c) => c.isMonitored).toList();
    final others = telegram.chats.where((c) => !c.isMonitored).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chats', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text(
            'Choose which conversations Tandem should watch. Configure the AI destination in Settings.',
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                if (monitored.isNotEmpty) ...[
                  _sectionTitle(context, 'Monitored'),
                  ...monitored.map((c) => _ChatTile(chat: c)),
                ],
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionTitle(context, 'All chats'),
                  ...others.map((c) => _ChatTile(chat: c)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: TandemColors.textMuted,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat});

  final ChatSummary chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(telegramControllerProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(chat.title),
        subtitle: Text(chat.lastMessagePreview ?? 'No preview'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilterChip(
              label: const Text('Monitor'),
              selected: chat.isMonitored,
              onSelected: (value) => notifier.setMonitored(chat.id, value),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => context.go('/chats/${chat.id}'),
            ),
          ],
        ),
        onTap: () => context.go('/chats/${chat.id}'),
      ),
    );
  }
}
