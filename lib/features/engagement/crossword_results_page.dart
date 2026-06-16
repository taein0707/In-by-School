import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/engagement_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/ui.dart';

/// 가로세로 퍼즐 결과(P4-2, 교사) — 제출 학생별 진행률.
class CrosswordResultsPage extends ConsumerWidget {
  final String setId;
  const CrosswordResultsPage({super.key, required this.setId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final subs = ref.watch(crosswordSubmissionsProvider(setId)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('퍼즐 결과', style: AppType.headline1),
      ),
      body: SafeArea(
        child: subs.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s32),
                  child: Text('아직 제출한 학생이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [
                  for (final s in subs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s8),
                      child: OclCard(
                        child: Row(children: [
                          Icon(s.solved ? Icons.check_circle : Icons.timelapse, color: s.solved ? c.positive : c.labelAlt),
                          const SizedBox(width: AppSpace.s12),
                          Expanded(child: Text(s.studentName.isEmpty ? '학생' : s.studentName, style: AppType.headline2)),
                          Text('${s.correct}/${s.total} (${(s.progress * 100).round()}%)', style: AppType.body2.copyWith(color: c.labelAlt)),
                        ]),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
