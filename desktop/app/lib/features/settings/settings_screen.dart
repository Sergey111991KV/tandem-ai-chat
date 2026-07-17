import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/pipeline/pipeline_settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/desktop_prefs.dart';
import '../../core/services/license_repository.dart';
import '../../main.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final entitlementAsync = ref.watch(licenseEntitlementProvider);
    final telegram = ref.watch(telegramControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        _AiPipelineSection(telegram: telegram),
        const SizedBox(height: 16),
        _LicenseSection(
          checkoutUrl: config.lemonSqueezy.checkoutUrl,
          donationsUrl: config.donationsUrl,
          showsPaidPurchaseUI: config.showsPaidPurchaseUI,
          entitlementAsync: entitlementAsync,
          onChanged: () async {
            ref.invalidate(licenseEntitlementProvider);
            await ref
                .read(pipelineControllerProvider.notifier)
                .refreshLicenseGate();
          },
        ),
        const SizedBox(height: 16),
        const _DesktopBehaviorSection(),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Support'),
                subtitle: Text(config.supportEmail),
                onTap: () => launchUrl(Uri.parse('mailto:${config.supportEmail}')),
              ),
              const Divider(height: 1),
              if (config.donationsUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Donate'),
                  subtitle: const Text('Optional — does not unlock features'),
                  onTap: () => launchUrl(Uri.parse(config.donationsUrl)),
                ),
              if (config.donationsUrl.isNotEmpty) const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Use'),
                onTap: () => launchUrl(Uri.parse(config.termsUrl)),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                onTap: () => launchUrl(Uri.parse(config.privacyUrl)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out of Telegram'),
            onTap: () => ref.read(telegramControllerProvider.notifier).signOut(),
          ),
        ),
      ],
    );
  }
}

class _AiPipelineSection extends ConsumerStatefulWidget {
  const _AiPipelineSection({required this.telegram});

  final TelegramState telegram;

  @override
  ConsumerState<_AiPipelineSection> createState() => _AiPipelineSectionState();
}

class _AiPipelineSectionState extends ConsumerState<_AiPipelineSection> {
  late final TextEditingController _roleController;
  bool _controllersReady = false;

  @override
  void dispose() {
    if (_controllersReady) _roleController.dispose();
    super.dispose();
  }

  void _ensureRoleController(PipelineSettings settings) {
    if (_controllersReady) return;
    _roleController = TextEditingController(text: settings.rolePrompt);
    _controllersReady = true;
  }

  Future<void> _showConsentDialog(PipelineSettings settings) async {
    final destination = settings.aiDestinationTitle ??
        'chat ${settings.aiDestinationChatId}';
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share data with AI service'),
        content: SingleChildScrollView(
          child: Text(
            'Tandem will send message text from monitored chats to your selected '
            'AI destination ($destination) over Telegram.\n\n'
            'Data sent may include chat titles, sender labels, and message content '
            'needed to draft a reply. Tandem does not run its own cloud AI backend; '
            'your chosen Telegram bot or chat is the third party.\n\n'
            'You can revoke this permission anytime in Settings.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow & continue'),
          ),
        ],
      ),
    );
    if (allowed == true && mounted) {
      await ref.read(pipelineSettingsProvider.notifier).grantConsent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(pipelineSettingsProvider);

    return settingsAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Failed to load AI settings: $e'),
        ),
      ),
      data: (settings) {
        _ensureRoleController(settings);
        final chats = widget.telegram.chats;
        final destId = settings.aiDestinationChatId;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI pipeline',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor chats → structured prompt → AI destination → draft or auto-send.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable pipeline'),
                  subtitle: Text(
                    settings.pipelineEnabled
                        ? 'New messages in monitored chats are processed.'
                        : 'Pipeline is paused.',
                  ),
                  value: settings.pipelineEnabled,
                  onChanged: (v) => ref
                      .read(pipelineSettingsProvider.notifier)
                      .setEnabled(v),
                ),
                const Divider(height: 24),
                Text(
                  'AI destination',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                DropdownMenu<int>(
                  key: ValueKey('ai-dest-$destId'),
                  initialSelection: destId != null &&
                          chats.any((c) => c.id == destId)
                      ? destId
                      : null,
                  label: const Text('Telegram chat for AI prompts'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: chats
                      .map(
                        (c) => DropdownMenuEntry(
                          value: c.id,
                          label: c.title,
                        ),
                      )
                      .toList(),
                  onSelected: (id) {
                    if (id == null) return;
                    final chat = chats.firstWhere((c) => c.id == id);
                    ref.read(pipelineSettingsProvider.notifier).setDestination(
                          chatId: chat.id,
                          title: chat.title,
                        );
                  },
                ),
                if (settings.aiDestinationTitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Selected: ${settings.aiDestinationTitle} '
                    '(id ${settings.aiDestinationChatId})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _roleController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Role / persona',
                    hintText: 'Instructions included in every AI prompt',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onEditingComplete: () {
                    ref
                        .read(pipelineSettingsProvider.notifier)
                        .setRolePrompt(_roleController.text);
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ref
                          .read(pipelineSettingsProvider.notifier)
                          .setRolePrompt(_roleController.text);
                    },
                    child: const Text('Save role'),
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    settings.consentSatisfied
                        ? Icons.verified_user_outlined
                        : Icons.privacy_tip_outlined,
                  ),
                  title: Text(
                    settings.consentSatisfied
                        ? 'Third-party AI sharing allowed'
                        : 'Third-party AI consent required',
                  ),
                  subtitle: Text(
                    settings.consentSatisfied
                        ? 'Applies to ${settings.aiDestinationTitle ?? settings.consentForChatId}'
                        : 'Required before the first prompt is sent to your AI chat.',
                  ),
                  trailing: settings.consentSatisfied
                      ? TextButton(
                          onPressed: () => ref
                              .read(pipelineSettingsProvider.notifier)
                              .revokeConsent(),
                          child: const Text('Revoke'),
                        )
                      : FilledButton(
                          onPressed: !settings.hasValidDestination
                              ? null
                              : () => _showConsentDialog(settings),
                          child: const Text('Review & allow'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LicenseSection extends ConsumerStatefulWidget {
  const _LicenseSection({
    required this.checkoutUrl,
    required this.donationsUrl,
    required this.showsPaidPurchaseUI,
    required this.entitlementAsync,
    required this.onChanged,
  });

  final String checkoutUrl;
  final String donationsUrl;
  final bool showsPaidPurchaseUI;
  final AsyncValue<LicenseEntitlement> entitlementAsync;
  final VoidCallback onChanged;

  @override
  ConsumerState<_LicenseSection> createState() => _LicenseSectionState();
}

class _LicenseSectionState extends ConsumerState<_LicenseSection> {
  final _keyController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(licenseRepositoryProvider).activate(_keyController.text);
      _keyController.clear();
      widget.onChanged();
    } on LicenseActivationException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate() async {
    setState(() => _busy = true);
    await ref.read(licenseRepositoryProvider).deactivate();
    widget.onChanged();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.entitlementAsync.maybeWhen(
      data: (e) => e.isActive,
      orElse: () => false,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subscription', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              !widget.showsPaidPurchaseUI
                  ? 'Paid plans are temporarily off. The AI pipeline stays available — optional donations help keep development going.'
                  : isActive
                      ? 'License active on this device. The AI pipeline requires an active subscription.'
                      : 'Paste your Lemon Squeezy license key to unlock the AI pipeline on this PC.',
            ),
            if (widget.entitlementAsync.hasValue &&
                isActive &&
                widget.entitlementAsync.value!.expirationDate != null) ...[
              const SizedBox(height: 6),
              Text(
                'Renews / expires: ${widget.entitlementAsync.value!.expirationDate}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            if (!widget.showsPaidPurchaseUI) ...[
              if (widget.donationsUrl.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => launchUrl(Uri.parse(widget.donationsUrl)),
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Donate'),
                ),
            ] else if (!isActive) ...[
              TextField(
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: 'License key',
                  hintText: 'XXXX-XXXX-XXXX-XXXX',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _activate,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Activate'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: widget.checkoutUrl.isEmpty
                        ? null
                        : () => launchUrl(Uri.parse(widget.checkoutUrl)),
                    child: const Text('Subscribe'),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : _refresh,
                    child: const Text('Re-check license'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _deactivate,
                    child: const Text('Deactivate'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(licenseRepositoryProvider).resolveEntitlement(force: true);
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _DesktopBehaviorSection extends ConsumerStatefulWidget {
  const _DesktopBehaviorSection();

  @override
  ConsumerState<_DesktopBehaviorSection> createState() =>
      _DesktopBehaviorSectionState();
}

class _DesktopBehaviorSectionState
    extends ConsumerState<_DesktopBehaviorSection> {
  bool? _closeToTray;

  @override
  void initState() {
    super.initState();
    DesktopPrefs().getCloseToTray().then((value) {
      if (mounted) setState(() => _closeToTray = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tray = ref.watch(desktopTrayProvider);
    final value = _closeToTray ?? true;

    return Card(
      child: SwitchListTile(
        title: const Text('Close to background'),
        subtitle: const Text(
          'Hide the window instead of quitting so the AI pipeline keeps running.',
        ),
        value: value,
        onChanged: tray == null
            ? null
            : (enabled) async {
                setState(() => _closeToTray = enabled);
                await DesktopPrefs().setCloseToTray(enabled);
                await tray.setCloseToTray(enabled);
              },
      ),
    );
  }
}
