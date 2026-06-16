import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/study/study_mode.dart';
import '../../shared/widgets/ui.dart';

/// 공부 시작 진입 허브 — 학습을 목적별로 묶어 보여준다.
///   · 자기주도 학습: 자유집중 · 백지복습 · 포모도로
///   · 과목별 학습: 영어 단어 학습(+ 확장 예정 과목)
///   · 친구들과 학습: 경쟁전(향후)
///
/// 하단 탭(홈·기록·나)은 그대로이며, 경쟁전은 별도 탭이 아니라 여기 한 모드로 들어간다.
/// 자기주도 카드는 기존 공부 준비 화면(/study/setup)으로 모드를 미리 선택해 진입하므로,
/// 암기·문제풀이·시험 대비 모드는 그 화면에 그대로 남아 보존된다(삭제 없음).
class StudyLaunchPage extends StatelessWidget {
  const StudyLaunchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('공부 시작', style: AppType.headline2.copyWith(color: c.labelNormal)),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s8),
          children: [
            // ---- 자기주도 학습 ----
            const SectionLabel('자기주도 학습'),
            _LaunchCard(
              icon: Icons.timer_outlined,
              title: '자유집중',
              subtitle: '원하는 만큼 집중해요',
              onTap: () => context.push('/study/setup', extra: StudyMode.free),
            ),
            _LaunchCard(
              icon: Icons.edit_note_outlined,
              title: '백지복습',
              subtitle: '배운 내용을 써보고 토리가 분석해요',
              onTap: () => context.push('/study/setup', extra: StudyMode.blank),
            ),
            _LaunchCard(
              icon: Icons.av_timer_outlined,
              title: '포모도로',
              subtitle: '25분 집중 + 5분 휴식',
              onTap: () => context.push('/study/setup', extra: StudyMode.pomodoro),
            ),
            const SizedBox(height: AppSpace.s16),

            // ---- 과목별 학습 ----
            const SectionLabel('과목별 학습'),
            _LaunchCard(
              icon: Icons.style_outlined,
              title: '영어 단어 학습',
              subtitle: '사진·입력으로 단어를 모아 외워요',
              onTap: () => context.push('/vocab'),
            ),
            _LaunchCard(icon: Icons.calculate_outlined, title: '수학', subtitle: '준비 중이에요', comingSoon: true),
            _LaunchCard(icon: Icons.menu_book_outlined, title: '국어', subtitle: '준비 중이에요', comingSoon: true),
            _LaunchCard(icon: Icons.science_outlined, title: '과학', subtitle: '준비 중이에요', comingSoon: true),
            _LaunchCard(icon: Icons.public_outlined, title: '사회/역사', subtitle: '준비 중이에요', comingSoon: true),
            const SizedBox(height: AppSpace.s16),

            // ---- 친구들과 학습 ----
            const SectionLabel('친구들과 학습'),
            _LaunchCard(
              icon: Icons.emoji_events_outlined,
              title: '단어 경쟁전',
              subtitle: '참가 코드로 단어 복습 챌린지에 참여해요',
              onTap: () => context.push('/battle/join'),
            ),
            const SizedBox(height: AppSpace.s24),
          ],
        ),
      ),
    );
  }
}

class _LaunchCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool comingSoon;
  const _LaunchCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Material(
        color: c.bgElevated,
        borderRadius: AppRadius.b14,
        child: InkWell(
          borderRadius: AppRadius.b14,
          onTap: comingSoon
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('곧 만나요 — 준비 중인 기능이에요.')),
                  )
              : onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.b14,
              border: Border.all(color: c.lineAlt),
            ),
            child: Row(
              children: [
                Icon(icon, size: 24, color: comingSoon ? c.labelAssistive : c.accent),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title,
                                style: AppType.headline2
                                    .copyWith(color: comingSoon ? c.labelAlt : c.labelNormal)),
                          ),
                          if (comingSoon) ...[
                            const SizedBox(width: AppSpace.s8),
                            _pill(context, '준비 중'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppType.body2.copyWith(color: c.labelAssistive)),
                    ],
                  ),
                ),
                if (!comingSoon) Icon(Icons.chevron_right, color: c.labelAssistive),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String t) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: c.fill, borderRadius: AppRadius.bFull),
      child: Text(t, style: AppType.caption2.copyWith(color: c.labelAlt, fontWeight: FontWeight.w700)),
    );
  }
}
