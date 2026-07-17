import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tandem_colors.dart';

class TelegramAuthScreen extends ConsumerStatefulWidget {
  const TelegramAuthScreen({super.key});

  @override
  ConsumerState<TelegramAuthScreen> createState() => _TelegramAuthScreenState();
}

class _TelegramAuthScreenState extends ConsumerState<TelegramAuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _bootstrapped = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telegram = ref.watch(telegramControllerProvider);

    if (!_bootstrapped) {
      _bootstrapped = true;
      Future.microtask(() async {
        try {
          await ref.read(telegramControllerProvider.notifier).bootstrap();
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      });
    }

    if (telegram.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/chats');
      });
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/icons/app_icon.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Connect Telegram',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(telegram.statusMessage ?? ''),
                  if (telegram.isStub)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Run desktop/scripts/setup-tdlib.sh and set API credentials in '
                        'desktop/config/app_config.local.json for real Telegram login.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Use your phone number linked to Telegram. Codes arrive in the Telegram app.',
                      ),
                    ),
                  const SizedBox(height: 24),
                  _buildForm(context, telegram.phase),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, TelegramAuthPhase phase) {
    switch (phase) {
      case TelegramAuthPhase.disconnected:
      case TelegramAuthPhase.waitingPhone:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+1 555 000 0000',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref
                  .read(telegramControllerProvider.notifier)
                  .submitPhone(_phoneController.text),
              child: const Text('Send code'),
            ),
          ],
        );
      case TelegramAuthPhase.waitingCode:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Login code',
                hintText: '12345',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref
                  .read(telegramControllerProvider.notifier)
                  .submitCode(_codeController.text),
              child: const Text('Verify'),
            ),
          ],
        );
      case TelegramAuthPhase.waitingPassword:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '2FA password'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref
                  .read(telegramControllerProvider.notifier)
                  .submitPassword(_passwordController.text),
              child: const Text('Continue'),
            ),
          ],
        );
      case TelegramAuthPhase.ready:
        return const Center(
          child: CircularProgressIndicator(color: TandemColors.accent),
        );
    }
  }
}
