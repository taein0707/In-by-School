import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/app_providers.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/notifications/fcm_service.dart';
import 'web_shell.dart';

/// 학생 셸(P0 개편) — 하단 탭 3개(홈·스터디·나) + 상단 헤더 + 사이드바(Drawer).
/// 기존 기능(기록·숙제·카드·문제·경쟁전)은 삭제하지 않고 사이드바로 이동.
/// P5: 폭 >=700 이면 웹 레이아웃(WebShell), 미만이면 기존 모바일 UX 유지.
class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});

  static const _titles = ['홈', '스터디', '나'];

  /// GNB(기능 이동) — 학생 핵심 섹션. (사이드바는 교실 목록 전용 — P8 #3)
  static const _gnbNav = [
    WebNavItem(label: '홈', icon: Icons.home_outlined, activeIcon: Icons.home, branchIndex: 0),
    WebNavItem(label: '스터디', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, branchIndex: 1),
    WebNavItem(label: '문제', icon: Icons.checklist_outlined, route: '/tasks'),
    WebNavItem(label: '나', icon: Icons.person_outline, activeIcon: Icons.person, branchIndex: 2),
  ];

  /// 더보기(보조 기능) — 탭에서 옮긴 기능(삭제 금지).
  static const _moreNav = [
    WebNavItem(label: '내 공부 기록', icon: Icons.insights_outlined, route: '/record'),
    WebNavItem(label: '학습기록 제출', icon: Icons.edit_note_outlined, route: '/study-report'),
    WebNavItem(label: '단어 경쟁전', icon: Icons.emoji_events_outlined, route: '/battle/join'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = context.screenSize;
    if (size != ScreenSize.mobile) {
      return WebShell(
        navigationShell: navigationShell,
        desktop: size == ScreenSize.desktop,
        brand: 'OCL',
        gnbNav: _gnbNav,
        moreNav: _moreNav,
        profileRoute: '/my',
        myBranchIndex: 2,
        teacher: false,
      );
    }
    return _mobile(context, ref);
  }

  Widget _mobile(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final idx = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(idx >= 0 && idx < _titles.length ? _titles[idx] : 'OCL', style: AppType.headline1),
      ),
      drawer: const _StudentSidebar(),
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
                _tab(context, 1, '스터디', Icons.menu_book_outlined, Icons.menu_book),
                _tab(context, 2, '나', Icons.person_outline, Icons.person),
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

/// 학생 사이드바 — 탭에서 옮긴 기능 + 하단 고정(내 정보·로그아웃).
class _StudentSidebar extends ConsumerWidget {
  const _StudentSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final name = ref.watch(currentProfileProvider).valueOrNull?.displayName ?? '';

    return Drawer(
      backgroundColor: c.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.s20),
              child: Row(children: [
                CircleAvatar(radius: 22, backgroundColor: c.accentSoft, child: Icon(Icons.person, color: c.accent)),
                const SizedBox(width: AppSpace.s12),
                Expanded(child: Text(name.isEmpty ? '학생' : name, style: AppType.title3)),
              ]),
            ),
            Divider(height: 1, color: c.lineAlt),
            const SizedBox(height: AppSpace.s8),
            _item(context, '내 공부 내용 보기', Icons.insights_outlined, '/record'),
            _item(context, '학습기록 제출', Icons.edit_note_outlined, '/study-report'),
            _item(context, '문제', Icons.checklist_outlined, '/tasks'),
            _item(context, '단어 경쟁전', Icons.emoji_events_outlined, '/battle/join'),
            _item(context, '내 교실', Icons.meeting_room_outlined, '/classrooms'),
            const Spacer(),
            Divider(height: 1, color: c.lineAlt),
            _item(context, '내 정보', Icons.settings_outlined, '/settings'),
            _logoutItem(context, ref),
            const SizedBox(height: AppSpace.s8),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, String label, IconData icon, String path) {
    final c = context.c;
    return ListTile(
      leading: Icon(icon, color: c.labelNeutral),
      title: Text(label, style: AppType.body1.copyWith(color: c.labelNeutral)),
      onTap: () {
        Navigator.pop(context); // 드로어 닫기
        context.push(path);
      },
    );
  }

  Widget _logoutItem(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return ListTile(
      leading: Icon(Icons.logout, color: c.negative),
      title: Text('로그아웃', style: AppType.body1.copyWith(color: c.negative)),
      onTap: () async {
        Navigator.pop(context);
        final study = ref.read(studyRepositoryProvider);
        await FcmService.clearCurrentToken(ref.read(accountRepositoryProvider));
        await study.signOut();
        await ref.read(appProvider.notifier).reload();
        if (context.mounted) context.go('/role-select');
      },
    );
  }
}
