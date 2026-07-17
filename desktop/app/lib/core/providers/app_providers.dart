import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../models/models.dart';
import '../pipeline/ai_pipeline_coordinator.dart';
import '../pipeline/pipeline_settings.dart';
import '../pipeline/pipeline_settings_store.dart';
import '../pipeline/pipeline_status.dart';
import '../pipeline/telegram_pipeline_transport.dart';
import '../services/license_repository.dart';
import '../services/telegram_service.dart';

final licenseRepositoryProvider = Provider<LicenseRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return LicenseRepository(config: config);
});

final licenseEntitlementProvider =
    FutureProvider<LicenseEntitlement>((ref) async {
  final repo = ref.watch(licenseRepositoryProvider);
  return repo.resolveEntitlement();
});

final pipelineSettingsStoreProvider = Provider<PipelineSettingsStore>((ref) {
  return PipelineSettingsStore();
});

class PipelineSettingsController extends AsyncNotifier<PipelineSettings> {
  @override
  Future<PipelineSettings> build() async {
    final store = ref.watch(pipelineSettingsStoreProvider);
    return store.load();
  }

  Future<void> save(PipelineSettings settings) async {
    state = AsyncData(settings);
    await ref.read(pipelineSettingsStoreProvider).save(settings);
    ref.read(pipelineControllerProvider.notifier).applySettings(settings);
  }

  Future<void> setEnabled(bool enabled) async {
    final current = state.valueOrNull ?? const PipelineSettings();
    await save(current.copyWith(pipelineEnabled: enabled));
  }

  Future<void> setDestination({
    required int chatId,
    required String title,
  }) async {
    final current = state.valueOrNull ?? const PipelineSettings();
    final sameConsent = current.consentForChatId == '$chatId';
    await save(
      current.copyWith(
        aiDestinationChatId: chatId,
        aiDestinationTitle: title,
        hasThirdPartyConsent: sameConsent && current.hasThirdPartyConsent,
        consentForChatId: sameConsent ? current.consentForChatId : null,
        clearConsent: !sameConsent,
      ),
    );
  }

  Future<void> setRolePrompt(String role) async {
    final current = state.valueOrNull ?? const PipelineSettings();
    await save(current.copyWith(rolePrompt: role));
  }

  Future<void> grantConsent() async {
    final current = state.valueOrNull ?? const PipelineSettings();
    if (!current.hasValidDestination) return;
    await save(
      current.copyWith(
        hasThirdPartyConsent: true,
        consentForChatId: '${current.aiDestinationChatId}',
      ),
    );
  }

  Future<void> revokeConsent() async {
    final current = state.valueOrNull ?? const PipelineSettings();
    await save(current.copyWith(clearConsent: true));
  }
}

final pipelineSettingsProvider =
    AsyncNotifierProvider<PipelineSettingsController, PipelineSettings>(
  PipelineSettingsController.new,
);

class PipelineUiState {
  const PipelineUiState({
    this.statuses = const {},
  });

  final Map<int, ChatPipelineStatus> statuses;

  ChatPipelineStatus forChat(int chatId) =>
      statuses[chatId] ?? const ChatPipelineStatus();
}

class PipelineController extends Notifier<PipelineUiState> {
  AiPipelineCoordinator? _coordinator;
  StreamSubscription<Map<int, ChatPipelineStatus>>? _statusSub;
  bool _booted = false;

  @override
  PipelineUiState build() {
    ref.onDispose(() {
      _statusSub?.cancel();
      unawaited(_coordinator?.dispose());
    });
    return const PipelineUiState();
  }

  Future<void> ensureStarted() async {
    if (_booted) return;
    _booted = true;

    final service = ref.read(telegramServiceProvider);
    final settings = await ref.read(pipelineSettingsProvider.future);
    final transport = TelegramPipelineTransport(service);
    final coordinator = AiPipelineCoordinator(transport: transport);
    await coordinator.start(settings: settings);
    _coordinator = coordinator;
    await refreshLicenseGate();
    _statusSub = coordinator.statusStream.listen((statuses) {
      state = PipelineUiState(statuses: statuses);
    });
    state = PipelineUiState(statuses: coordinator.statuses);
  }

  AiPipelineCoordinator? get coordinator => _coordinator;

  void applySettings(PipelineSettings settings) {
    _coordinator?.updateSettings(settings);
  }

  Future<void> refreshLicenseGate() async {
    final config = ref.read(appConfigProvider);
    final entitlement = await ref.read(licenseEntitlementProvider.future);
    _coordinator?.updateLicenseGate(
      requireActive: config.requiresActiveLicense,
      isActive: entitlement.isActive,
    );
  }

  Future<void> approveDraft(int chatId) async {
    await _coordinator?.approveDraft(chatId);
  }

  Future<void> clearDraft(int chatId) async {
    await _coordinator?.clearDraft(chatId);
  }

  Future<void> simulateIncoming({
    required int chatId,
    required String text,
  }) async {
    await ref.read(telegramServiceProvider).simulateIncomingMessage(
          chatId: chatId,
          text: text,
        );
  }
}

final pipelineControllerProvider =
    NotifierProvider<PipelineController, PipelineUiState>(
  PipelineController.new,
);

class TelegramState {
  const TelegramState({
    required this.phase,
    required this.chats,
    this.isStub = true,
    this.statusMessage,
  });

  final TelegramAuthPhase phase;
  final List<ChatSummary> chats;
  final bool isStub;
  final String? statusMessage;

  bool get isReady => phase == TelegramAuthPhase.ready;
}

class TelegramController extends Notifier<TelegramState> {
  late TelegramService _service;
  bool _bootstrapped = false;
  StreamSubscription<void>? _updatesSub;

  @override
  TelegramState build() {
    _service = ref.read(telegramServiceProvider);
    ref.onDispose(() => _updatesSub?.cancel());
    final isStub = _service.runtimeType.toString().contains('Stub');
    return TelegramState(
      phase: _service.authPhase,
      chats: _service.chats,
      isStub: isStub,
      statusMessage: isStub
          ? 'TDLib library not loaded — demo chats only.'
          : 'Connected via TDLib.',
    );
  }

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await _service.initialize();
    _updatesSub ??= _service.updates.listen((_) => _sync());
    _sync();
    await ref.read(pipelineControllerProvider.notifier).ensureStarted();
  }

  Future<void> submitPhone(String phone) async {
    await _service.submitPhone(phone);
    _sync();
  }

  Future<void> submitCode(String code) async {
    await _service.submitCode(code);
    _sync();
  }

  Future<void> submitPassword(String password) async {
    await _service.submitPassword(password);
    _sync();
  }

  Future<void> signOut() async {
    await _service.signOut();
    _sync();
  }

  Future<void> setMonitored(int chatId, bool value) async {
    await _service.setMonitored(chatId, value);
    _sync();
  }

  Future<void> setReplyMode(int chatId, ReplyMode mode) async {
    await _service.setReplyMode(chatId, mode);
    _sync();
  }

  Future<void> setPaused(int chatId, bool paused) async {
    await _service.setPaused(chatId, paused);
    _sync();
  }

  void _sync() {
    final isStub = _service.runtimeType.toString().contains('Stub');
    state = TelegramState(
      phase: _service.authPhase,
      chats: _service.chats,
      isStub: isStub,
      statusMessage: isStub
          ? 'TDLib library not loaded — demo chats only.'
          : 'Connected via TDLib.',
    );
  }
}

final telegramControllerProvider =
    NotifierProvider<TelegramController, TelegramState>(
  TelegramController.new,
);

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding.complete') ?? false;
});

Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding.complete', true);
}
