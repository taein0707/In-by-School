import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/notifications/notification_service.dart';
import '../../domain/study/study_mode.dart';
import '../../domain/study/study_session.dart';
import '../../domain/vocab/vocab_word.dart';

/// 학습 종료 — 결과 + AI(취약 단어·복습 추천) + 성장 반영.
class VocabResultPage extends ConsumerStatefulWidget {
  final VocabResult result;
  const VocabResultPage({super.key, required this.result});
  @override
  ConsumerState<VocabResultPage> createState() => _VocabResultPageState();
}

class _VocabResultPageState extends ConsumerState<VocabResultPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  void _apply() {
    final r = widget.result;
    final now = DateTime.now();
    ref.read(appProvider.notifier).complete(StudySession(
          mode: StudyMode.vocab, subject: '영단어', focusedMin: r.focusedMin,
          goalMin: 0, hour: now.hour, date: now,
        ));
    if (r.weak.isNotEmpty) {
      final name = ref.read(appProvider).growth.name;
      NotificationService.scheduleReviews(
        subject: '영단어',
        dates: [now.add(const Duration(days: 1)), now.add(const Duration(days: 3)), now.add(const Duration(days: 7))],
        spiritName: name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = widget.result;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpace.s24, AppSpace.s24, AppSpace.s24, AppSpace.s16),
                children: [
                  Text('학습 완료', style: AppType.title2),
                  const SizedBox(height: AppSpace.s16),
                  Row(children: [
                    _stat(context, '${r.total}', '총 단어'),
                    const SizedBox(width: AppSpace.s8),
                    _stat(context, '${r.correct}', '아는 단어'),
                    const SizedBox(width: AppSpace.s8),
                    _stat(context, '${r.wrong}', '취약 단어'),
                  ]),
                  const SizedBox(height: AppSpace.s16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpace.s16),
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('토리의 제안', style: AppType.label2.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(r.weak.isEmpty
                            ? '전부 잘 외웠어요. 며칠 뒤 가볍게 다시 확인해 봐요.'
                            : '취약 단어 ${r.wrong}개는 1·3·7일 뒤 복습 알림을 잡아뒀어요.',
                            style: AppType.body1.copyWith(color: c.labelNeutral)),
                      ],
                    ),
                  ),
                  if (r.weak.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s16),
                    Text('취약 단어', style: AppType.headline2),
                    const SizedBox(height: AppSpace.s8),
                    ...r.weak.map((w) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(AppSpace.s14),
                          decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b12, border: Border.all(color: c.lineAlt)),
                          child: Row(children: [
                            Expanded(child: Text(w.term, style: AppType.body1.copyWith(fontWeight: FontWeight.w600))),
                            Expanded(child: Text(w.meaning, style: AppType.body2.copyWith(color: c.labelAlt))),
                          ]),
                        )),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s24, 0, AppSpace.s24, AppSpace.s12),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: Material(
                  color: c.accent, borderRadius: AppRadius.b16,
                  child: InkWell(
                    borderRadius: AppRadius.b16,
                    onTap: () => context.go('/home'),
                    child: Center(child: Text('확인', style: AppType.headline2.copyWith(color: Colors.white))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String v, String l) {
    final c = context.c;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: c.bgAlt, borderRadius: AppRadius.b14),
        child: Column(children: [
          Text(v, style: AppType.title3.copyWith(fontWeight: FontWeight.w700)),
          Text(l, style: AppType.caption1.copyWith(color: c.labelAlt)),
        ]),
      ),
    );
  }
}
