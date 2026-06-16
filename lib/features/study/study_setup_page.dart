import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/analytics/analytics.dart';
import '../../domain/study/study_mode.dart';
import '../../shared/widgets/ui.dart';
import 'session_config.dart';

const _subjects = ['수학', '영어', '국어', '과학', '한국사', '독서', '코딩', '기타'];

class StudySetupPage extends ConsumerStatefulWidget {
  /// 런처(StudyLaunchPage)에서 모드를 미리 정해 들어올 때 사용. null 이면 AI 추천 모드.
  final StudyMode? initialMode;
  const StudySetupPage({super.key, this.initialMode});
  @override
  ConsumerState<StudySetupPage> createState() => _StudySetupPageState();
}

class _StudySetupPageState extends ConsumerState<StudySetupPage> {
  StudyMode? _mode;
  String _subject = '수학';
  int _goal = 25;
  int _examDdays = 14;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = ref.read(appProvider);
    final rec = Analytics.recommendMode(app.sessions, app.growth);
    _mode ??= widget.initialMode ?? rec.mode;

    // recommended mode first
    final modes = [
      StudyModeInfo.of(rec.mode),
      ...StudyModeInfo.launchModes.where((m) => m.mode != rec.mode),
    ];

    return Scaffold(
      appBar: _bar(context, '공부 준비'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
                children: [
                  const SectionLabel('공부 모드'),
                  ...modes.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s8),
                        child: _ModeCard(
                          info: m,
                          selected: _mode == m.mode,
                          recommended: m.mode == rec.mode,
                          onTap: () => setState(() => _mode = m.mode),
                        ),
                      )),
                  const SizedBox(height: AppSpace.s8),
                  const SectionLabel('과목'),
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s8,
                    children: _subjects.map((s) => _Chip(
                          label: s,
                          selected: _subject == s,
                          onTap: () => setState(() => _subject = s),
                        )).toList(),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  if (_mode == StudyMode.pomodoro)
                    Text('포모도로는 25분 단위로 진행돼요.',
                        style: AppType.body2.copyWith(color: c.labelAlt))
                  else if (_mode == StudyMode.vocab)
                    Text('다음 화면에서 사진/직접 입력으로 단어를 모아요.',
                        style: AppType.body2.copyWith(color: c.labelAlt))
                  else if (_mode == StudyMode.exam)
                    _GoalRow(
                      label: '시험까지',
                      suffix: '일',
                      value: _examDdays,
                      onMinus: () => setState(() => _examDdays = (_examDdays - 1).clamp(1, 200)),
                      onPlus: () => setState(() => _examDdays = (_examDdays + 1).clamp(1, 200)),
                    )
                  else
                    _GoalRow(value: _goal, onMinus: () => setState(() => _goal = (_goal - 5).clamp(5, 180)), onPlus: () => setState(() => _goal = (_goal + 5).clamp(5, 180))),
                  const SizedBox(height: AppSpace.s24),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s24, 0, AppSpace.s24, AppSpace.s12),
              child: OclButton('집중 시작', onPressed: () {
                final mode = _mode!;
                if (mode == StudyMode.vocab) {
                  context.pushReplacement('/vocab');
                  return;
                }
                context.pushReplacement('/study/active',
                    extra: SessionConfig(
                      mode: mode,
                      subject: _subject,
                      goalMin: mode == StudyMode.pomodoro ? 25 : (mode == StudyMode.exam ? 0 : _goal),
                      examDdays: _examDdays,
                    ));
              }),
            ),
          ],
        ),
      ),
    );
  }
}

PreferredSizeWidget _bar(BuildContext context, String title) => AppBar(
      backgroundColor: context.c.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(title, style: AppType.headline2.copyWith(color: context.c.labelNormal)),
      leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => Navigator.maybePop(context)),
    );

class _ModeCard extends StatelessWidget {
  final StudyModeInfo info;
  final bool selected, recommended;
  final VoidCallback onTap;
  const _ModeCard({required this.info, required this.selected, required this.recommended, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.accentSoft : c.bgElevated,
      borderRadius: AppRadius.b14,
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpace.s14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.b14,
            border: Border.all(color: selected ? c.accent : c.lineAlt, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(info.name, style: AppType.headline2.copyWith(color: c.labelNormal)),
                const SizedBox(width: AppSpace.s8),
                _pill(context, info.tag, c.fill, c.labelAlt),
                const Spacer(),
                if (recommended) _pill(context, 'AI 추천', c.accent, Colors.white),
              ]),
              const SizedBox(height: AppSpace.s6),
              Text(info.desc, style: AppType.body2.copyWith(color: c.labelNeutral)),
              const SizedBox(height: 2),
              Text('추천: ${info.forWhom}', style: AppType.caption1.copyWith(color: c.labelAssistive)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String t, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.bFull),
        child: Text(t, style: AppType.caption2.copyWith(color: fg, fontWeight: FontWeight.w700)),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.accent : c.fill,
      borderRadius: AppRadius.bFull,
      child: InkWell(
        borderRadius: AppRadius.bFull,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Text(label, style: AppType.label1.copyWith(color: selected ? Colors.white : c.labelNeutral)),
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final int value;
  final String label;
  final String suffix;
  final VoidCallback onMinus, onPlus;
  const _GoalRow({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.label = '목표 시간',
    this.suffix = '분',
  });
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppType.body1.copyWith(color: c.labelNeutral)),
        Row(children: [
          _round(context, Icons.remove, onMinus),
          SizedBox(width: 64, child: Text('$value$suffix', textAlign: TextAlign.center, style: AppType.headline2)),
          _round(context, Icons.add, onPlus),
        ]),
      ],
    );
  }

  Widget _round(BuildContext context, IconData i, VoidCallback onTap) => Material(
        color: context.c.fill,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(i, size: 20, color: context.c.labelNeutral)),
        ),
      );
}
