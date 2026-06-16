import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/analytics/analytics.dart';
import '../../domain/study/study_session.dart';
import '../../shared/widgets/ui.dart';

/// 기록 — "나는 어떤 방식으로 공부하는 사람인가". 숫자 나열이 아니라 서술 중심.
class RecordPage extends ConsumerWidget {
  const RecordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final app = ref.watch(appProvider);
    final insights = Analytics.weeklyInsights(app.sessions, app.growth);
    final tips = Analytics.methodTips(app.sessions, app.growth);
    final week = _weekMinutes(app.sessions);
    final subjects = _subjectTotals(app.sessions);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s12),
          children: [
            Text('기록', style: AppType.title2),
            const SizedBox(height: AppSpace.s16),
            OclCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('이번 주 집중', style: AppType.headline2),
                  const SizedBox(height: AppSpace.s16),
                  _WeekBars(week: week),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            _textCard(context, 'AI 학습 분석', insights),
            const SizedBox(height: AppSpace.s12),
            _textCard(context, '맞춤 공부법', tips),
            const SizedBox(height: AppSpace.s12),
            OclCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('과목별 누적', style: AppType.headline2),
                  const SizedBox(height: AppSpace.s12),
                  if (subjects.isEmpty)
                    Text('아직 기록이 없어요.', style: AppType.body2.copyWith(color: c.labelAssistive))
                  else
                    ...subjects.map((e) => _subjectBar(context, e.key, e.value, subjects.first.value)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textCard(BuildContext context, String title, List<String> lines) => OclCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppType.headline2),
            const SizedBox(height: AppSpace.s8),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(l, style: AppType.body1.copyWith(color: context.c.labelNeutral)),
                )),
          ],
        ),
      );

  Widget _subjectBar(BuildContext context, String name, int v, int max) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 56, child: Text(name, style: AppType.label2.copyWith(color: c.labelNeutral))),
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.bFull,
            child: LinearProgressIndicator(
              value: max > 0 ? v / max : 0,
              minHeight: 8,
              backgroundColor: c.fillStrong,
              valueColor: AlwaysStoppedAnimation(c.accent),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 48, child: Text('$v분', textAlign: TextAlign.right, style: AppType.caption1.copyWith(color: c.labelAlt))),
      ]),
    );
  }

  List<({String label, int min, bool today})> _weekMinutes(List<StudySession> sessions) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: (now.weekday + 6) % 7));
    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final min = sessions
          .where((s) => s.date.year == day.year && s.date.month == day.month && s.date.day == day.day)
          .fold<int>(0, (a, s) => a + s.focusedMin);
      final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
      return (label: labels[i], min: min, today: isToday);
    });
  }

  List<MapEntry<String, int>> _subjectTotals(List<StudySession> sessions) {
    final m = <String, int>{};
    for (final s in sessions) {
      m[s.subject] = (m[s.subject] ?? 0) + s.focusedMin;
    }
    final list = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }
}

class _WeekBars extends StatelessWidget {
  final List<({String label, int min, bool today})> week;
  const _WeekBars({required this.week});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final max = week.fold<int>(60, (a, d) => d.min > a ? d.min : a);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: week.map((d) {
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 18,
                  height: (d.min / max * 96).clamp(4, 96).toDouble(),
                  decoration: BoxDecoration(
                    color: d.today ? c.accent : c.fillStrong,
                    borderRadius: AppRadius.b8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(d.label, style: AppType.caption1.copyWith(color: c.labelAssistive)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
