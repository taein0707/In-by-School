import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/web_shell.dart';

/// 선생님 모드 하단 탭: 학생 · 숙제 · 플래시카드 · AI문제 · 통계.
/// 학생 모드(MainScaffold)와 별개의 셸 — 역할에 따라 라우터가 갈라준다.
/// P5: 폭 >=700 이면 웹 레이아웃(WebShell), 미만이면 기존 모바일 하단 탭 유지.
class TeacherScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const TeacherScaffold({super.key, required this.navigationShell});

  /// GNB(큰 카테고리, P9-2) — 홈/숙제/수업/학생/나. (사이드바=교실 선택 전용)
  static const _gnbNav = [
    WebNavItem(label: '홈', icon: Icons.home_outlined, activeIcon: Icons.home, branchIndex: 0),
    WebNavItem(label: '숙제', icon: Icons.assignment_outlined, activeIcon: Icons.assignment, branchIndex: 1),
    WebNavItem(label: '수업', icon: Icons.cast_for_education_outlined, activeIcon: Icons.cast_for_education, branchIndex: 2),
    WebNavItem(label: '학생', icon: Icons.groups_outlined, activeIcon: Icons.groups, branchIndex: 3),
    WebNavItem(label: '나', icon: Icons.person_outline, activeIcon: Icons.person, branchIndex: 4),
  ];

  /// 더보기(보조 기능) — 기존 기능 보존(셸 밖 최상위 라우트로 이동).
  static const _moreNav = [
    WebNavItem(label: '교실 설정', icon: Icons.meeting_room_outlined, route: '/t/classrooms'),
    WebNavItem(label: '플래시카드', icon: Icons.style_outlined, route: '/t/flashcards'),
    WebNavItem(label: 'AI문제', icon: Icons.smart_toy_outlined, route: '/t/ai'),
    WebNavItem(label: '통계', icon: Icons.bar_chart_outlined, route: '/t/stats'),
    WebNavItem(label: '학습기록', icon: Icons.history_edu_outlined, route: '/t/reports'),
  ];

  @override
  Widget build(BuildContext context) {
    final size = context.screenSize;
    if (size != ScreenSize.mobile) {
      return WebShell(
        navigationShell: navigationShell,
        desktop: size == ScreenSize.desktop,
        brand: 'OCL 선생님',
        gnbNav: _gnbNav,
        moreNav: _moreNav,
        profileRoute: '/t/my',
        myBranchIndex: 4,
        teacher: true,
      );
    }
    return _mobile(context);
  }

  Widget _mobile(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.lineAlt)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _tab(context, 0, '홈', Icons.home_outlined, Icons.home),
                _tab(context, 1, '숙제', Icons.assignment_outlined, Icons.assignment),
                _tab(context, 2, '수업', Icons.cast_for_education_outlined, Icons.cast_for_education),
                _tab(context, 3, '학생', Icons.groups_outlined, Icons.groups),
                _tab(context, 4, '나', Icons.person_outline, Icons.person),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int index, String label, IconData icon, IconData active) {
    final c = context.c;
    final selected = navigationShell.currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? active : icon, size: 24, color: selected ? c.accent : c.labelAssistive),
            const SizedBox(height: 4),
            Text(label, style: AppType.caption1.copyWith(color: selected ? c.accent : c.labelAssistive)),
          ],
        ),
      ),
    );
  }
}
