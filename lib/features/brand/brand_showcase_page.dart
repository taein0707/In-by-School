import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'brand_motion.dart';

/// Preview gallery for the Brand Motion Pack — one tap plays each moment.
/// Reachable at `/brand`.
class BrandShowcasePage extends StatelessWidget {
  const BrandShowcasePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('브랜드 모션', style: AppType.headline2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            Text('IN by CLASS', style: AppType.title2.copyWith(color: c.labelStrong)),
            const SizedBox(height: AppSpace.s4),
            Text('서비스의 첫 인상을 만드는 브랜드 애니메이션', style: AppType.body2.copyWith(color: c.labelAlt)),
            const SizedBox(height: AppSpace.s24),
            _row(context, '첫 로그인', 'IN by CLASS → HI CLASS 👋', Icons.login_outlined,
                () => BrandIntro.show(context)),
            _row(context, '로그아웃', 'HI CLASS → OUT by CLASS', Icons.logout_outlined,
                () => BrandOutro.show(context)),
            _row(context, '학습지 제출', '체크 → ✨ 제출 완료 + 보상', Icons.task_alt_outlined,
                () => SubmitCelebration.show(context,
                    subtitle: '자동 채점 12 / 15', tori: 20, streakDays: 7)),
            _row(context, '수업 입장', 'IN → HI → 영어 1반', Icons.meeting_room_outlined,
                () => ClassEnterIntro.show(context, '영어 1반')),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String title, String desc, IconData icon, VoidCallback onTap) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Material(
        color: c.bgElevated,
        borderRadius: AppRadius.b16,
        child: InkWell(
          borderRadius: AppRadius.b16,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s16),
            decoration: BoxDecoration(borderRadius: AppRadius.b16, border: Border.all(color: c.lineAlt)),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b12),
                  child: Icon(icon, color: c.accent),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppType.headline2.copyWith(color: c.labelNormal)),
                      const SizedBox(height: 2),
                      Text(desc, style: AppType.label2.copyWith(color: c.labelAlt)),
                    ],
                  ),
                ),
                Icon(Icons.play_circle_outline, color: c.labelAssistive),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
