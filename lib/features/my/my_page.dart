import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/notifications/notification_service.dart';
import '../../shared/widgets/tori_spirit.dart';
import '../../shared/widgets/ui.dart';

/// 나 — 프로필 · 누적 통계 · 설정.
class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final settings = ref.watch(settingsProvider);
    final g = ref.watch(appProvider).growth;
    final hours = g.totalMin ~/ 60, mins = g.totalMin % 60;
    final dark = settings.themeMode == ThemeMode.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s12),
          children: [
            Text('나', style: AppType.title2),
            const SizedBox(height: AppSpace.s16),
            Row(children: [
              ToriSpirit(stageIndex: g.stageIndex, size: 84, accent: settings.accent, animate: false),
              const SizedBox(width: AppSpace.s14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, style: AppType.title3),
                  Text('${g.stage.name} · LV ${g.level}', style: AppType.body2.copyWith(color: c.labelAlt)),
                ],
              ),
            ]),
            const SizedBox(height: AppSpace.s20),
            Row(children: [
              _stat(context, '$hours시간 $mins분', '누적 공부'),
              const SizedBox(width: AppSpace.s8),
              _stat(context, '${g.totalSessions}', '세션'),
              const SizedBox(width: AppSpace.s8),
              _stat(context, '${g.streakCurrent}', '일 연속'),
            ]),
            const SizedBox(height: AppSpace.s16),
            if (Firebase.apps.isNotEmpty) ...[
              _listTile(
                context,
                ref.read(studyRepositoryProvider).isEmailAccount
                    ? '계정 · ${ref.read(studyRepositoryProvider).email}'
                    : '로그인 / 회원가입',
                () => context.push('/login'),
              ),
              const SizedBox(height: AppSpace.s8),
              _listTile(context, '학습 기록 제출', () => context.push('/study-report')),
              const SizedBox(height: AppSpace.s8),
            ],
            _listTile(context, '아이템', () => context.push('/items')),
            const SizedBox(height: AppSpace.s8),
            _listTile(context, '정령 진화 기록', () => context.push('/growth')),
            const SizedBox(height: AppSpace.s8),
            _listTile(context, '설정', () => context.push('/settings')),
            const SizedBox(height: AppSpace.s12),
            OclCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('설정', style: AppType.headline2),
                  const SizedBox(height: AppSpace.s8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('다크 모드', style: AppType.body1.copyWith(color: c.labelNeutral)),
                      Switch(
                        value: dark,
                        activeColor: c.accent,
                        onChanged: (v) => ref.read(settingsProvider.notifier).setDark(v),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('학습 알림', style: AppType.body1.copyWith(color: c.labelNeutral)),
                      TextButton(
                        onPressed: () async {
                          final ok = await NotificationService.requestPermission();
                          if (ok) await NotificationService.scheduleDailyReminder();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? '알림이 켜졌어요 (매일 리마인더 포함)' : '설정에서 알림 권한을 허용해주세요')),
                            );
                          }
                        },
                        child: Text('켜기', style: AppType.label1.copyWith(color: c.accent)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final c = context.c;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(color: c.bgAlt, borderRadius: AppRadius.b14),
        child: Column(children: [
          Text(value, style: AppType.headline2.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label, style: AppType.caption1.copyWith(color: c.labelAlt)),
        ]),
      ),
    );
  }

  Widget _listTile(BuildContext context, String label, VoidCallback onTap) {
    final c = context.c;
    return Material(
      color: c.bgElevated,
      borderRadius: AppRadius.b14,
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpace.s16),
          decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
          child: Row(
            children: [
              Text(label, style: AppType.body1.copyWith(color: c.labelNeutral)),
              const Spacer(),
              Icon(Icons.chevron_right, color: c.labelAssistive),
            ],
          ),
        ),
      ),
    );
  }
}
