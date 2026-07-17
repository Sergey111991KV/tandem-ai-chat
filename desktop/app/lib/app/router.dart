import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
import '../features/auth/telegram_auth_screen.dart';
import '../features/chats/chat_thread_screen.dart';
import '../features/chats/chats_list_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(onboardingCompleteProvider, (_, _) => notifyListeners());
    ref.listen(telegramControllerProvider, (_, _) => notifyListeners());
  }

  final Ref ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: refresh,
    redirect: (context, state) {
      final onboardingDone = ref.read(onboardingCompleteProvider).maybeWhen(
            data: (value) => value,
            orElse: () => null,
          );
      if (onboardingDone == null) return null;

      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!onboardingDone && !atOnboarding) return '/onboarding';
      if (onboardingDone && atOnboarding) return '/auth';

      final telegram = ref.read(telegramControllerProvider);
      final atAuth = state.matchedLocation == '/auth';
      if (onboardingDone && !telegram.isReady && !atAuth && !atOnboarding) {
        return '/auth';
      }
      if (telegram.isReady && atAuth) return '/chats';

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const TelegramAuthScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/chats',
            builder: (context, state) => const ChatsListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ChatThreadScreen(chatId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
