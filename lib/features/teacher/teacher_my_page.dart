import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/notifications/fcm_service.dart';
import '../../shared/widgets/ui.dart';

/// 교사 마이페이지 — 하단 탭바 '나' 탭(셸 브랜치 /t/my).
/// 프로필 · 설정 · 개인정보 · 약관 · 버전 · 로그아웃. (토리 관련 화면 없음)
class TeacherMyPage extends ConsumerWidget {
  const TeacherMyPage({super.key});

  /// 앱 버전(표시용). pubspec version 과 동기화.
  static const String appVersion = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final profile = ref.watch(currentProfileProvider).value;
    final email = ref.read(studyRepositoryProvider).email;
    final meta = [
      if (profile?.subject?.isNotEmpty ?? false) profile!.subject!,
      if (profile?.orgType != null) profile!.orgType!.label,
      if (profile?.orgName?.isNotEmpty ?? false) profile!.orgName!,
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppSpace.s20,
        title: Text('마이페이지', style: AppType.headline1),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s12),
          children: [
            // 프로필
            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: c.accentSoft,
                child: Icon(Icons.cast_for_education_outlined, color: c.accent),
              ),
              const SizedBox(width: AppSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?.displayName.isNotEmpty == true ? profile!.displayName : '선생님',
                        style: AppType.title3),
                    if (meta.isNotEmpty)
                      Text(meta, style: AppType.body2.copyWith(color: c.labelAlt)),
                    if (email != null && email.isNotEmpty)
                      Text(email, style: AppType.caption1.copyWith(color: c.labelAssistive)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.s20),

            _tile(context, '내 교실 관리', Icons.meeting_room_outlined, () => context.push('/t/classrooms')),
            const SizedBox(height: AppSpace.s8),
            _tile(context, '설정', Icons.settings_outlined, () => context.push('/settings')),
            const SizedBox(height: AppSpace.s8),
            _tile(context, '개인정보처리방침', Icons.privacy_tip_outlined, () => context.push('/legal/privacy')),
            const SizedBox(height: AppSpace.s8),
            _tile(context, '이용약관', Icons.description_outlined, () => context.push('/legal/terms')),
            const SizedBox(height: AppSpace.s8),
            _tile(context, '버전 정보', Icons.info_outline, null, trailing: 'v$appVersion'),
            const SizedBox(height: AppSpace.s20),

            OclButton('로그아웃', ghost: true, onPressed: () => _logout(context, ref)),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final study = ref.read(studyRepositoryProvider);
    await FcmService.clearCurrentToken(ref.read(accountRepositoryProvider));
    await study.signOut();
    await ref.read(appProvider.notifier).reload();
    if (context.mounted) context.go('/role-select');
  }

  Widget _tile(BuildContext context, String label, IconData icon, VoidCallback? onTap, {String? trailing}) {
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
              Icon(icon, size: 20, color: c.labelNeutral),
              const SizedBox(width: AppSpace.s12),
              Text(label, style: AppType.body1.copyWith(color: c.labelNeutral)),
              const Spacer(),
              if (trailing != null)
                Text(trailing, style: AppType.body2.copyWith(color: c.labelAssistive))
              else
                Icon(Icons.chevron_right, color: c.labelAssistive),
            ],
          ),
        ),
      ),
    );
  }
}
