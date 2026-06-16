import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// LNB(세부 카테고리) 탭 — GNB 화면 안에서 세부 기능을 가르는 가로 탭(P9-2).
/// 디자인은 IN by CLASS 고유(밑줄 인디케이터 + 가로 스크롤).
class LnbTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  const LnbTabs({super.key, required this.labels, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.lineAlt))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
        child: Row(
          children: [for (var i = 0; i < labels.length; i++) _tab(c, i)],
        ),
      ),
    );
  }

  Widget _tab(AppColors c, int i) {
    final on = i == selected;
    return InkWell(
      onTap: () => onSelected(i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: on ? c.accent : Colors.transparent, width: 2)),
        ),
        child: Text(
          labels[i],
          style: AppType.label1.copyWith(
            color: on ? c.accent : c.labelAlt,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
