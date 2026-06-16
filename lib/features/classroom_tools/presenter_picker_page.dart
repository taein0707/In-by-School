import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/classroom_providers.dart';
import '../../app/classroom_tools_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/classroom_tools/group_activity.dart';
import '../../shared/widgets/ui.dart';

/// 발표 학생 추첨(P3-2) — 랜덤 추첨 + 중복 옵션 + 최근 기록 + 저장.
class PresenterPickerPage extends ConsumerStatefulWidget {
  final String classroomId;
  final String? classroomName;
  const PresenterPickerPage({super.key, required this.classroomId, this.classroomName});

  @override
  ConsumerState<PresenterPickerPage> createState() => _PresenterPickerPageState();
}

class _PresenterPickerPageState extends ConsumerState<PresenterPickerPage> {
  bool _allowRepeat = false;
  final List<String> _recent = []; // 최근순(앞이 가장 최근)
  String? _last;
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
      final lastPresenter = activities.where((a) => a.type == GroupActivityType.presenter).toList();
      if (lastPresenter.isNotEmpty && lastPresenter.first.picks.isNotEmpty) {
        _recent.addAll(lastPresenter.first.picks);
        _last = _recent.first;
      }
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
        title: Text('발표 학생 추첨', style: AppType.headline1),
        actions: [
          if (_recent.isNotEmpty)
            TextButton(onPressed: _save, child: Text('저장', style: AppType.label1.copyWith(color: c.accent))),
        ],
      ),
      body: SafeArea(
        child: names.isEmpty
            ? _empty(context)
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [
                  _repeatToggle(c),
                  const SizedBox(height: AppSpace.s16),
                  _resultCard(c),
                  const SizedBox(height: AppSpace.s16),
                  OclButton(_last == null ? '추첨하기' : '다시 추첨', onPressed: () => _draw(names)),
                  const SizedBox(height: AppSpace.s24),
                  if (_recent.isNotEmpty) ...[
                    Row(children: [
                      Expanded(child: SectionLabel('최근 발표자')),
                      TextButton(onPressed: () => setState(() { _recent.clear(); _last = null; }), child: Text('기록 지우기', style: AppType.label2.copyWith(color: c.labelAlt))),
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

  Widget _repeatToggle(AppColors c) => OclCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s4),
        child: Row(children: [
          Expanded(child: Text('중복 허용', style: AppType.body1.copyWith(color: c.labelNeutral))),
          Switch(value: _allowRepeat, activeColor: c.accent, onChanged: (v) => setState(() => _allowRepeat = v)),
        ]),
      );

  Widget _resultCard(AppColors c) => Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _last == null ? c.bgElevated : c.accentSoft,
          borderRadius: AppRadius.b16,
          border: Border.all(color: _last == null ? c.lineAlt : c.accent),
        ),
        child: _last == null
            ? Text('아직 추첨 전이에요', style: AppType.body1.copyWith(color: c.labelAssistive))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🎉 발표자', style: AppType.body2.copyWith(color: c.accent)),
                const SizedBox(height: AppSpace.s8),
                Text(_last!, style: AppType.display3.copyWith(color: c.labelStrong)),
              ]),
      );

  void _draw(List<String> names) {
    final picked = PresenterPicker.pick(names, recent: _recent, allowRepeat: _allowRepeat);
    if (picked == null) return;
    setState(() {
      _last = picked;
      _recent.insert(0, picked);
    });
  }

  Future<void> _save() async {
    await ref.read(classroomToolsRepositoryProvider).saveGroupActivity(
          classroomId: widget.classroomId,
          type: GroupActivityType.presenter,
          picks: _recent,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('발표자 기록을 저장했어요.')));
    }
  }

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.campaign_outlined, size: 48, color: c.labelAssistive),
          const SizedBox(height: AppSpace.s12),
          Text('교실에 학생이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
        ]),
      ),
    );
  }
}
