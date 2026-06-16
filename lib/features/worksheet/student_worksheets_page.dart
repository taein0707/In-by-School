import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/worksheet_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/ui.dart';

/// 학생: 교실 학습지 목록 → 풀이 진입(P3-1).
class StudentWorksheetsPage extends ConsumerWidget {
  final String classroomId;
  final String? classroomName;
  const StudentWorksheetsPage({super.key, required this.classroomId, this.classroomName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final sheets = ref.watch(classroomWorksheetsProvider(classroomId)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('학습지', style: AppType.headline1),
      ),
      body: SafeArea(
        child: sheets.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.description_outlined, size: 48, color: c.labelAssistive),
                    const SizedBox(height: AppSpace.s12),
                    Text('아직 학습지가 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
                  ]),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: sheets
                    .map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s8),
                          child: InkWell(
                            borderRadius: AppRadius.b16,
                            onTap: () => context.push('/worksheets/solve', extra: w),
                            child: OclCard(
                              child: Row(children: [
                                Icon(Icons.description_outlined, color: c.accent),
                                const SizedBox(width: AppSpace.s12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(w.title, style: AppType.headline2),
                                    if (w.description.isNotEmpty)
                                      Text(w.description, style: AppType.body2.copyWith(color: c.labelAlt)),
                                  ]),
                                ),
                                Icon(Icons.chevron_right, color: c.labelAssistive),
                              ]),
                            ),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}
