import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/classroom_providers.dart';
import '../../app/classroom_tools_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/classroom_tools/seat_layout.dart';
import '../../shared/widgets/ui.dart';

/// 랜덤 자리 배치(P3-2) — 격자 배치 + 다시 섞기 + 수동 이동 + 저장.
class SeatLayoutPage extends ConsumerStatefulWidget {
  final String classroomId;
  final String? classroomName;
  const SeatLayoutPage({super.key, required this.classroomId, this.classroomName});

  @override
  ConsumerState<SeatLayoutPage> createState() => _SeatLayoutPageState();
}

class _SeatLayoutPageState extends ConsumerState<SeatLayoutPage> {
  int _rows = 0;
  int _cols = 4;
  List<String> _seats = [];
  int? _selected; // 수동 이동 선택 좌석
  bool _moveMode = false;
  bool _inited = false;

  List<String> _studentNames(List<dynamic> members) => [
        for (var i = 0; i < members.length; i++)
          (members[i].displayName as String).trim().isEmpty ? '학생${i + 1}' : members[i].displayName as String,
      ];

  List<String> get _occupants => _seats.where((s) => s.isNotEmpty).toList();

  void _refill(List<String> names) => _seats = SeatPlanner.fill(names, _rows, _cols);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final studentsAsync = ref.watch(classroomStudentsProvider(widget.classroomId));
    final seatAsync = ref.watch(seatLayoutProvider(widget.classroomId));
    final names = _studentNames(studentsAsync.valueOrNull ?? const []);

    if (!_inited && studentsAsync.hasValue && seatAsync.hasValue) {
      final saved = seatAsync.valueOrNull;
      if (saved != null && saved.capacity > 0) {
        _rows = saved.rows;
        _cols = saved.cols;
        _seats = [...saved.seats];
      } else {
        _cols = 4;
        _rows = names.isEmpty ? 1 : ((names.length + _cols - 1) ~/ _cols);
        _refill(names);
      }
      _inited = true;
    }

    final overflow = names.length - _rows * _cols;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('자리 배치', style: AppType.headline1),
        actions: [
          TextButton(
            onPressed: _inited ? _save : null,
            child: Text('저장', style: AppType.label1.copyWith(color: c.accent)),
          ),
        ],
      ),
      body: SafeArea(
        child: names.isEmpty
            ? _empty(context)
            : ListView(
                padding: const EdgeInsets.all(AppSpace.s20),
                children: [
                  _stepperRow(c),
                  const SizedBox(height: AppSpace.s12),
                  Row(children: [
                    Expanded(child: OclButton('랜덤 배치', onPressed: () => setState(() => _seats = SeatPlanner.shuffleFill(names, _rows, _cols)))),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(child: OclButton('다시 섞기', ghost: true, onPressed: () => setState(() => _seats = SeatPlanner.shuffleFill(_occupants, _rows, _cols)))),
                  ]),
                  const SizedBox(height: AppSpace.s8),
                  _moveToggle(c),
                  if (overflow > 0) ...[
                    const SizedBox(height: AppSpace.s8),
                    Text('자리가 $overflow명 부족해요. 행/열을 늘려주세요.', style: AppType.body2.copyWith(color: c.negative)),
                  ],
                  const SizedBox(height: AppSpace.s16),
                  SectionLabel('칠판 (앞쪽)'),
                  const SizedBox(height: AppSpace.s8),
                  _grid(c),
                ],
              ),
      ),
    );
  }

  Widget _stepperRow(AppColors c) => Row(children: [
        Expanded(child: _stepper(c, '행', _rows, (v) => setState(() { _rows = v; _refill(_occupants); }))),
        const SizedBox(width: AppSpace.s8),
        Expanded(child: _stepper(c, '열', _cols, (v) => setState(() { _cols = v; _refill(_occupants); }))),
      ]);

  Widget _stepper(AppColors c, String label, int value, ValueChanged<int> onChanged) => OclCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s8),
        child: Row(children: [
          Text(label, style: AppType.body2.copyWith(color: c.labelAlt)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: c.labelAlt,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Text('$value', style: AppType.headline2),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: c.accent,
            onPressed: value < 12 ? () => onChanged(value + 1) : null,
          ),
        ]),
      );

  Widget _moveToggle(AppColors c) => Material(
        color: _moveMode ? c.accent.withValues(alpha: 0.12) : c.bgElevated,
        borderRadius: AppRadius.b14,
        child: InkWell(
          borderRadius: AppRadius.b14,
          onTap: () => setState(() { _moveMode = !_moveMode; _selected = null; }),
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.b14,
              border: Border.all(color: _moveMode ? c.accent : c.lineAlt),
            ),
            child: Row(children: [
              Icon(Icons.swap_horiz, color: _moveMode ? c.accent : c.labelAlt),
              const SizedBox(width: AppSpace.s8),
              Expanded(child: Text(_moveMode ? '수동 이동: 두 자리를 차례로 누르면 바뀝니다' : '수동 이동', style: AppType.body2.copyWith(color: _moveMode ? c.accent : c.labelNeutral))),
              if (_moveMode) Icon(Icons.check_circle, color: c.accent, size: 18),
            ]),
          ),
        ),
      );

  Widget _grid(AppColors c) => GridView.count(
        crossAxisCount: _cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpace.s8,
        crossAxisSpacing: AppSpace.s8,
        childAspectRatio: 1.4,
        children: [
          for (var i = 0; i < _rows * _cols; i++) _seatCell(c, i),
        ],
      );

  Widget _seatCell(AppColors c, int i) {
    final name = i < _seats.length ? _seats[i] : '';
    final empty = name.isEmpty;
    final selected = _selected == i;
    return InkWell(
      borderRadius: AppRadius.b14,
      onTap: _moveMode ? () => _onSeatTap(i) : null,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpace.s4),
        decoration: BoxDecoration(
          color: selected ? c.accent : (empty ? c.bg : c.bgElevated),
          borderRadius: AppRadius.b14,
          border: Border.all(color: selected ? c.accent : c.lineAlt),
        ),
        child: Text(
          empty ? '·' : name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.body2.copyWith(color: selected ? Colors.white : (empty ? c.labelAssistive : c.labelNeutral)),
        ),
      ),
    );
  }

  void _onSeatTap(int i) {
    setState(() {
      if (_selected == null) {
        _selected = i;
      } else {
        final tmp = _seats[_selected!];
        _seats[_selected!] = _seats[i];
        _seats[i] = tmp;
        _selected = null;
      }
    });
  }

  Future<void> _save() async {
    await ref.read(classroomToolsRepositoryProvider).saveSeatLayout(
          classroomId: widget.classroomId,
          rows: _rows,
          cols: _cols,
          seats: _seats,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('자리 배치를 저장했어요.')));
    }
  }

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.grid_view_outlined, size: 48, color: c.labelAssistive),
          const SizedBox(height: AppSpace.s12),
          Text('교실에 학생이 없어요.', style: AppType.body1.copyWith(color: c.labelAlt)),
          const SizedBox(height: 4),
          Text('학생을 추가한 뒤 자리를 배치해보세요.', style: AppType.body2.copyWith(color: c.labelAssistive)),
        ]),
      ),
    );
  }
}
