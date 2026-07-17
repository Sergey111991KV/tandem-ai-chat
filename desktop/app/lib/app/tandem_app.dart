import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/tandem_theme.dart';
import '../main.dart';
import 'router.dart';

class TandemApp extends ConsumerWidget {
  const TandemApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: config.appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: TandemTheme.dark(),
      routerConfig: router,
    );
  }
}
