import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nawakes_mobile/core/routing/app_router.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: NawakesApp(),
    ),
  );
}

class NawakesApp extends ConsumerWidget {
  const NawakesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Nawakes',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
