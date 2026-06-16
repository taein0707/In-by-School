import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/router/app_router.dart';
import '../features/presence/student_presence_scope.dart';
import 'account_providers.dart';
import 'settings_provider.dart';

class OclApp extends ConsumerWidget {
  const OclApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    ref.watch(emailIndexBackfillProvider); // P9 #8 — 로그인 시 이메일 인덱스 백필
    return MaterialApp.router(
      title: 'OCL Study',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent: settings.accent),
      darkTheme: AppTheme.dark(accent: settings.accent),
      themeMode: settings.themeMode,
      routerConfig: ref.watch(routerProvider),
      // P6: 학생·웹에서만 참여 상태 추적 + 화면 공유 동의 오버레이를 전역으로 감싼다.
      builder: (context, child) => StudentPresenceScope(child: child ?? const SizedBox.shrink()),
    );
  }
}
