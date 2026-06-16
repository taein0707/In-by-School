import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/classroom_providers.dart';
import '../../app/classroom_tools_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/classroom_tools/group_activity.dart';
import '../../domain/engagement/roulette.dart';
import '../../shared/widgets/ui.dart';

/// 랜덤 룰렛(P4-4) — 학생/모둠/번호 추첨 + 중복 옵션 + 기록 저장.
class RoulettePage extends ConsumerStatefulWidget {
  final String classroomId;
  final String? classroomName;
  const RoulettePage({super.key, required this.classroomId, this.classroomName});

  @override
  ConsumerState<RoulettePage> createState() => _RoulettePageState();
}

class _RoulettePageState extends ConsumerState<RoulettePage> {
  RouletteMode _mode = RouletteMode.student;
  bool _allowRepeat = false;
  int _numberCount = 30;
  int _teamSize = 4;
  String? _result;
  List<String>? _resultMembers;
  final List<String> _recent = [];
  List<List<String>> _lastGroups = const [];
  bool _inited = false;

  List<String> _studentNames(List<dynamic> members) => [
        for (var i = 0; i < members.length; i++)
          (members[i].displayName as String).trim().isEmpty ? '학생${i + 1}' : members[i].displayName as String,
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final members = ref.watch(classroomStudentsProvider(widget.classroomId)).valueOrNull ?? const [];
    final names = _studentNames(members);
    final activities = ref.watch(groupActivitiesProvider(widget.classroomId)).valueOrNull ?? const [];

    if (!_inited && activities.isNotEmpty) {
      final last = activities.where((a) => a.type == GroupActivityType.roulette).toList();
      if (last.isNotEmpty && last.first.picks.isNotEmpty) _recent.addAll(last.first.picks);
      _inited = true;
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('랜덤 룰렛', style: AppType.headline1),
        actions: [
          if (_recent.isNotEmpty)
            TextButton(onPressed: () => _save(), child: Text('저장', style: AppType.label1.copyWith(color: c.accent))),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            SectionLabel('모드'),
            Wrap(spacing: AppSpace.s8, children: [
              for (final m in RouletteMode.values)
                ChoiceChip(
                  label: Text(m.label, style: AppType.label1.copyWith(color: _mode == m ? Colors.white : c.labelNeutral)),
                  selected: _mode == m,
                  onSelected: (_) => setState(() { _mode = m; _result = null; _resultMembers = null; }),
                  selectedColor: c.accent,
                  backgroundColor: c.bgElevated,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.b14, side: BorderSide(color: _mode == m ? c.accent : c.lineAlt)),
                ),
            ]),
            const SizedBox(height: AppSpace.s16),
            if (_mode == RouletteMode.number) _stepperCard(c, '번호 범위 (1 ~ N)', _numberCount, 2, 100, (v) => setState(() => _numberCount = v)),
            if (_mode == RouletteMode.team) _stepperCard(c, '모둠당 인원', _teamSize, 2, 10, (v) => setState(() => _teamSize = v)),
            OclCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s4),
              child: Row(children: [
                Expanded(child: Text('중복 허용', style: AppType.body1.copyWith(color: c.labelNeutral))),
                Switch(value: _allowRepeat, activeColor: c.accent, onChanged: (v) => setState(() => _allowRepeat = v)),
              ]),
            ),
            const SizedBox(height: AppSpace.s16),
            _resultCard(c),
            const SizedBox(height: AppSpace.s16),
            OclButton(_result == null ? '돌리기' : '다시 돌리기', onPressed: () => _spin(names)),
            const SizedBox(height: AppSpace.s24),
            if (_recent.isNotEmpty) ...[
              Row(children: [
                Expanded(child: SectionLabel('최근 추첨 결과')),
                TextButton(onPressed: () => setState(() { _recent.clear(); _result = null; _resultMembers = null; }),
                    child: Text('기록 지우기', style: AppType.label2.copyWith(color: c.labelAlt))),
              ]),
              const SizedBox(height: AppSpace.s4),
              Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: [
                for (var i = 0; i < _recent.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: 6),
                    decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
                    child: Text('${i + 1}. ${_recent[i]}', style: AppType.body2.copyWith(color: c.labelNeutral)),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepperCard(AppColors c, String label, int value, int minV, int maxV, ValueChanged<int> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s16),
        child: OclCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
          child: Row(children: [
            Expanded(child: Text(label, style: AppType.body2.copyWith(color: c.labelAlt))),
            IconButton(icon: const Icon(Icons.remove_circle_outline), color: c.labelAlt, onPressed: value > minV ? () => onChanged(value - 1) : null),
            Text('$value', style: AppType.headline2),
            IconButton(icon: const Icon(Icons.add_circle_outline), color: c.accent, onPressed: value < maxV ? () => onChanged(value + 1) : null),
          ]),
        ),
      );

  Widget _resultCard(AppColors c) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpace.s20),
        decoration: BoxDecoration(
          color: _result == null ? c.bgElevated : c.accentSoft,
          borderRadius: AppRadius.b16,
          border: Border.all(color: _result == null ? c.lineAlt : c.accent),
        ),
        child: _result == null
            ? Text('버튼을 눌러 추첨하세요', style: AppType.body1.copyWith(color: c.labelAssistive))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🎯 ${_mode.label}', style: AppType.body2.copyWith(color: c.accent)),
                const SizedBox(height: AppSpace.s8),
                Text(_result!, style: AppType.display3.copyWith(color: c.labelStrong), textAlign: TextAlign.center),
                if (_resultMembers != null && _resultMembers!.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s12),
                  Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, alignment: WrapAlignment.center, children: [
                    for (final m in _resultMembers!)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: 6),
                        decoration: BoxDecoration(color: c.bg, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
                        child: Text(m, style: AppType.body2.copyWith(color: c.labelNeutral)),
                      ),
                  ]),
                ],
              ]),
      );

  void _spin(List<String> names) {
    if (_mode == RouletteMode.number) {
      final cands = RouletteLogic.numberPool(_numberCount);
      final pick = PresenterPicker.pick(cands, recent: _recent, allowRepeat: _allowRepeat);
      if (pick == null) return;
      setState(() { _result = pick; _resultMembers = null; _recent.insert(0, pick); });
      return;
    }
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('교실에 학생이 없어요.')));
      return;
    }
    if (_mode == RouletteMode.student) {
      final pick = PresenterPicker.pick(names, recent: _recent, allowRepeat: _allowRepeat);
      if (pick == null) return;
      setState(() { _result = pick; _resultMembers = null; _recent.insert(0, pick); });
    } else {
      // 모둠 추첨 — 모둠을 편성한 뒤 한 모둠을 뽑는다.
      final groups = GroupMaker.make(names, _teamSize);
      _lastGroups = groups;
      final labels = [for (var i = 0; i < groups.length; i++) '${i + 1}모둠'];
      final picked = PresenterPicker.pick(labels, recent: _recent, allowRepeat: _allowRepeat);
      if (picked == null) return;
      final idx = labels.indexOf(picked);
      setState(() {
        _result = picked;
        _resultMembers = idx >= 0 ? groups[idx] : null;
        _recent.insert(0, picked);
      });
    }
  }

  Future<void> _save() async {
    await ref.read(classroomToolsRepositoryProvider).saveGroupActivity(
          classroomId: widget.classroomId,
          type: GroupActivityType.roulette,
          picks: _recent,
          groups: _mode == RouletteMode.team ? _lastGroups : const [],
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('추첨 기록을 저장했어요.')));
    }
  }
}
