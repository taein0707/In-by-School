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

/// 모둠 만들기(P3-2) — 인원수 기준 랜덤 편성 + 저장.
class GroupMakerPage extends ConsumerStatefulWidget {
  final String classroomId;
  final String? classroomName;
  const GroupMakerPage({super.key, required this.classroomId, this.classroomName});

  @override
  ConsumerState<GroupMakerPage> createState() => _GroupMakerPageState();
}

class _GroupMakerPageState extends ConsumerState<GroupMakerPage> {
  int _size = 4;
  List<List<String>> _groups = const [];

  List<String> _studentNames(List<dynamic> members) => [
        for (var i = 0; i < members.length; i++)
          (members[i].displayName as String).trim().isEmpty ? '학생${i + 1}' : members[i].displayName as String,
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final members = ref.watch(classroomStudentsProvider(widget.classroomId)).valueOrNull ?? const [];
    final names = _studentNames(members);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('모둠 만들기', style: AppType.headline1),
        actions: [
          if (_groups.isNotEmpty)
            TextButton(onPressed: _save, child: Text('저장', style: AppType.label1.copyWith(color: c.accent))),
        ],
      ),
      body: SafeArea(
        child: names.isEmpty
            ? _empty(context)
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [
                  SectionLabel('모둠당 인원'),
                  const SizedBox(height: AppSpace.s4),
                  Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: [
                    for (final n in [2, 3, 4, 5]) _sizeChip(c, '$n명', n),
                    _customChip(c),
                  ]),
                  const SizedBox(height: AppSpace.s16),
                  OclButton('모둠 만들기 (${names.length}명)', onPressed: () => setState(() => _groups = GroupMaker.make(names, _size))),
                  const SizedBox(height: AppSpace.s20),
                  if (_groups.isNotEmpty) ...[
                    SectionLabel('${_groups.length}개 모둠'),
                    const SizedBox(height: AppSpace.s4),
                    for (var g = 0; g < _groups.length; g++) ...[
                      _groupCard(c, g),
                      const SizedBox(height: AppSpace.s8),
                    ],
                  ],
                ],
              ),
      ),
    );
  }

  Widget _sizeChip(AppColors c, String label, int value) {
    final on = _size == value;
    return ChoiceChip(
      label: Text(label, style: AppType.label1.copyWith(color: on ? Colors.white : c.labelNeutral)),
      selected: on,
      onSelected: (_) => setState(() => _size = value),
      selectedColor: c.accent,
      backgroundColor: c.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.b14, side: BorderSide(color: on ? c.accent : c.lineAlt)),
    );
  }

  Widget _customChip(AppColors c) {
    final preset = {2, 3, 4, 5}.contains(_size);
    final on = !preset;
    return ActionChip(
      label: Text(on ? '$_size명' : '사용자 지정', style: AppType.label1.copyWith(color: on ? Colors.white : c.labelNeutral)),
      onPressed: _pickCustom,
      backgroundColor: on ? c.accent : c.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.b14, side: BorderSide(color: on ? c.accent : c.lineAlt)),
    );
  }

  Future<void> _pickCustom() async {
    final ctrl = TextEditingController(text: '$_size');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return AlertDialog(
          backgroundColor: c.bgElevated,
          title: Text('모둠당 인원', style: AppType.title3),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: AppType.body1.copyWith(color: c.labelNormal),
            decoration: const InputDecoration(hintText: '예: 6'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())), child: const Text('확인')),
          ],
        );
      },
    );
    if (v != null && v >= 1) setState(() => _size = v);
  }

  Widget _groupCard(AppColors c, int index) => OclCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 12, backgroundColor: c.accentSoft, child: Text('${index + 1}', style: AppType.label2.copyWith(color: c.accent))),
            const SizedBox(width: AppSpace.s8),
            Text('${index + 1}모둠', style: AppType.headline2),
            const Spacer(),
            Text('${_groups[index].length}명', style: AppType.body2.copyWith(color: c.labelAlt)),
          ]),
          const SizedBox(height: AppSpace.s8),
          Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: [
            for (final name in _groups[index])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: 6),
                decoration: BoxDecoration(color: c.bg, borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
                child: Text(name, style: AppType.body2.copyWith(color: c.labelNeutral)),
              ),
          ]),
        ]),
      );

  Future<void> _save() async {
    await ref.read(classroomToolsRepositoryProvider).saveGroupActivity(
          classroomId: widget.classroomId,
          type: GroupActivityType.groups,
          groupSize: _size,
          groups: _groups,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모둠 편성을 저장했어요.')));
    }
  }

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.groups_2_outlined, size: 48, color: c.labelAssistive),
          const SizedBox(height: AppSpace.s12),
          Text('교실에 학생이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
        ]),
      ),
    );
  }
}
