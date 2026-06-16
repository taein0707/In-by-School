import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/app_providers.dart';
import '../../app/classroom_providers.dart';
import '../../app/teacher_workspace.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/notifications/fcm_service.dart';
import '../../features/classroom/student_classrooms_page.dart' show openJoinByCodeSheet;

/// 웹 셸의 네비게이션 항목 — 셸 브랜치([branchIndex]) 또는 최상위 라우트([route]) 둘 중 하나.
class WebNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// StatefulShellRoute 브랜치 인덱스(있으면 goBranch). null 이면 [route] 사용.
  final int? branchIndex;

  /// 셸 밖 최상위 라우트(있으면 push — 브라우저 뒤로가기 동작). [branchIndex] 가 우선.
  final String? route;

  const WebNavItem({
    required this.label,
    required this.icon,
    IconData? activeIcon,
    this.branchIndex,
    this.route,
  }) : activeIcon = activeIcon ?? icon;
}

/// P5/P8 — 태블릿/데스크톱 전용 웹 레이아웃.
///
/// 역할 분리(P8 #3):
///   - **GNB**(상단 헤더) = 기능 이동(홈/스터디/숙제 …) + 더보기 오버플로(보조 기능).
///   - **Sidebar/Rail**(좌측) = 교실 목록 **전용**(기능 메뉴 없음). 교실 클릭 → 해당 교실.
///   - **Footer** = 브랜드 정보. **My(나) 화면에서만** 표시(P8 #1).
class WebShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  /// 데스크톱이면 사이드바+푸터, 아니면(태블릿) 레일.
  final bool desktop;

  /// 좌측 로고 옆 서비스명.
  final String brand;

  /// 헤더 주 네비(기능).
  final List<WebNavItem> gnbNav;

  /// 헤더 더보기(보조 기능) — 비면 미표시.
  final List<WebNavItem> moreNav;

  /// 우상단 프로필 아바타 탭 시 이동할 경로(학생 '/my', 교사 '/t/my').
  final String profileRoute;

  /// 푸터를 노출할 My(나) 브랜치 인덱스.
  final int myBranchIndex;

  /// 사이드바 교실 목록 소스(교사=내가 만든 교실 / 학생=내가 속한 교실).
  final bool teacher;

  const WebShell({
    super.key,
    required this.navigationShell,
    required this.desktop,
    required this.brand,
    required this.gnbNav,
    required this.moreNav,
    required this.profileRoute,
    required this.myBranchIndex,
    required this.teacher,
  });

  bool _isSelected(WebNavItem item) =>
      item.branchIndex != null && item.branchIndex == navigationShell.currentIndex;

  void _onTap(BuildContext context, WebNavItem item) {
    if (item.branchIndex != null) {
      navigationShell.goBranch(
        item.branchIndex!,
        initialLocation: item.branchIndex == navigationShell.currentIndex,
      );
    } else if (item.route != null) {
      // 최상위 라우트는 push — 브라우저/시스템 뒤로가기가 동작하도록(P8 #2).
      context.push(item.route!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final onMy = navigationShell.currentIndex == myBranchIndex;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _Header(shell: this),
          Divider(height: 1, thickness: 1, color: c.lineAlt),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                desktop ? _Sidebar(shell: this) : _Rail(shell: this),
                VerticalDivider(width: 1, thickness: 1, color: c.lineAlt),
                // 콘텐츠 칼럼: [Expanded(콘텐츠)] + [Footer(My 전용)].
                // 푸터를 이 칼럼 안에 두어 사이드바 높이를 건드리지 않는다(P9 #2).
                Expanded(
                  child: desktop
                      ? Column(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: kWebContentMaxWidth),
                                  child: navigationShell,
                                ),
                              ),
                            ),
                            if (onMy) const _Footer(),
                          ],
                        )
                      : navigationShell,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 콘텐츠 최대 폭(가독성) — 셸 안팎 공용(P8 #6).
const double kWebContentMaxWidth = 1160;

/// 사이드바/레일이 보여줄 교실 목록(교사/학생 공통 형태로 정규화).
List<({String id, String name})> _classroomsFor(WidgetRef ref, bool teacher) {
  if (teacher) {
    final list = ref.watch(teacherClassroomsProvider).valueOrNull ?? const [];
    return [for (final c in list) (id: c.id, name: c.name)];
  }
  final list = ref.watch(myClassroomsProvider).valueOrNull ?? const [];
  return [for (final m in list) (id: m.classroomId, name: m.classroomName)];
}

/// 교실 탭 — 교사는 워크스페이스(현재 교실)를 바꾸고 홈으로(전체 화면 컨텍스트 전환, P9-2),
/// 학생은 해당 교실 상세로 이동한다.
void _onClassroomTap(BuildContext context, WidgetRef ref, bool teacher, String id, String name) {
  if (teacher) {
    ref.read(teacherWorkspaceProvider.notifier).select(id, name);
    context.go('/t/home');
  } else {
    context.push('/classrooms/$id', extra: name);
  }
}

void _addClassroom(BuildContext context, WidgetRef ref, bool teacher) {
  if (teacher) {
    context.push('/t/classrooms'); // 교실 만들기 화면
  } else {
    openJoinByCodeSheet(context, ref); // 코드로 즉시 참여
  }
}

/// 상단 헤더 — 로고/서비스명 · GNB(기능) · 더보기 · 알림/프로필/로그아웃.
class _Header extends ConsumerWidget {
  final WebShell shell;
  const _Header({required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Container(
      height: 64,
      color: c.bg,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: c.accent, borderRadius: AppRadius.b8),
            alignment: Alignment.center,
            child: const Text('O', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          if (shell.desktop) ...[
            const SizedBox(width: AppSpace.s10),
            Text(shell.brand, style: AppType.headline1.copyWith(color: c.labelStrong)),
          ],
          const SizedBox(width: AppSpace.s20),
          // GNB(기능) — 좁은 폭에서도 넘치지 않도록 가로 스크롤.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [for (final item in shell.gnbNav) _HeaderNavButton(shell: shell, item: item)],
              ),
            ),
          ),
          if (shell.moreNav.isNotEmpty) _MoreMenu(shell: shell),
          const _NotificationBell(),
          const SizedBox(width: AppSpace.s4),
          IconButton(
            tooltip: '프로필',
            onPressed: () => context.go(shell.profileRoute),
            icon: CircleAvatar(radius: 15, backgroundColor: c.accentSoft, child: Icon(Icons.person, size: 18, color: c.accent)),
          ),
          const SizedBox(width: AppSpace.s4),
          IconButton(
            tooltip: '로그아웃',
            onPressed: () => logoutFromWeb(context, ref),
            icon: Icon(Icons.logout, size: 20, color: c.labelAlt),
          ),
        ],
      ),
    );
  }
}

class _HeaderNavButton extends StatelessWidget {
  final WebShell shell;
  final WebNavItem item;
  const _HeaderNavButton({required this.shell, required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final selected = shell._isSelected(item);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.s4),
      child: TextButton.icon(
        onPressed: () => shell._onTap(context, item),
        icon: Icon(selected ? item.activeIcon : item.icon, size: 18, color: selected ? c.accent : c.labelNeutral),
        label: Text(
          item.label,
          style: AppType.label1.copyWith(
            color: selected ? c.accent : c.labelNeutral,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s8),
          backgroundColor: selected ? c.accentSoft : Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.b8),
        ),
      ),
    );
  }
}

/// 헤더 우측 '더보기' — 보조 기능(기록/통계/경쟁전 등)을 메뉴로 모은다.
class _MoreMenu extends StatelessWidget {
  final WebShell shell;
  const _MoreMenu({required this.shell});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PopupMenuButton<WebNavItem>(
      tooltip: '더보기',
      position: PopupMenuPosition.under,
      onSelected: (item) => shell._onTap(context, item),
      itemBuilder: (_) => [
        for (final item in shell.moreNav)
          PopupMenuItem<WebNavItem>(
            value: item,
            child: Row(children: [
              Icon(item.icon, size: 20, color: c.labelNeutral),
              const SizedBox(width: AppSpace.s12),
              Text(item.label, style: AppType.body2.copyWith(color: c.labelNeutral)),
            ]),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: AppSpace.s8),
        child: Row(children: [
          Text('더보기', style: AppType.label1.copyWith(color: c.labelNeutral)),
          Icon(Icons.expand_more, size: 18, color: c.labelNeutral),
        ]),
      ),
    );
  }
}

/// 데스크톱 좌측 사이드바 — **교실 목록 전용**.
class _Sidebar extends ConsumerWidget {
  final WebShell shell;
  const _Sidebar({required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final name = ref.watch(currentProfileProvider).valueOrNull?.displayName ?? '';
    final classrooms = _classroomsFor(ref, shell.teacher);
    return Container(
      width: 240,
      color: c.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: c.accentSoft, child: Icon(Icons.person, color: c.accent)),
              const SizedBox(width: AppSpace.s12),
              Expanded(child: Text(name.isEmpty ? '사용자' : name, style: AppType.headline2, overflow: TextOverflow.ellipsis)),
            ]),
          ),
          Divider(height: 1, color: c.lineAlt),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s16, AppSpace.s16, AppSpace.s8, AppSpace.s4),
            child: Row(children: [
              Text('내 교실', style: AppType.label2.copyWith(color: c.labelAlt)),
              const Spacer(),
              IconButton(
                tooltip: shell.teacher ? '교실 만들기' : '교실 참여',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add, size: 20, color: c.accent),
                onPressed: () => _addClassroom(context, ref, shell.teacher),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
              children: [
                // 교사: 전체 교실(워크스페이스 해제).
                if (shell.teacher)
                  _ClassroomTile(
                    name: '전체 교실',
                    icon: Icons.apps_outlined,
                    selected: ref.watch(teacherWorkspaceProvider).isAll,
                    onTap: () {
                      ref.read(teacherWorkspaceProvider.notifier).selectAll();
                      context.go('/t/home');
                    },
                  ),
                if (classrooms.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: AppSpace.s8),
                    child: Text(
                      shell.teacher ? '아직 만든 교실이 없어요.' : '참여 코드로 교실에 들어가요.',
                      style: AppType.caption1.copyWith(color: c.labelAssistive),
                    ),
                  ),
                for (final room in classrooms)
                  _ClassroomTile(
                    name: room.name.isEmpty ? '교실' : room.name,
                    selected: shell.teacher && ref.watch(teacherWorkspaceProvider).classroomId == room.id,
                    onTap: () => _onClassroomTap(context, ref, shell.teacher, room.id, room.name),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: c.lineAlt),
          _PlainTile(icon: Icons.settings_outlined, label: '내 정보', color: c.labelNeutral, onTap: () => context.push('/settings')),
          _PlainTile(icon: Icons.logout, label: '로그아웃', color: c.negative, onTap: () => logoutFromWeb(context, ref)),
          const SizedBox(height: AppSpace.s8),
        ],
      ),
    );
  }
}

class _ClassroomTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  final IconData icon;
  final bool selected;
  const _ClassroomTile({
    required this.name,
    required this.onTap,
    this.icon = Icons.meeting_room_outlined,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Material(
        color: selected ? c.accentSoft : Colors.transparent,
        borderRadius: AppRadius.b12,
        child: InkWell(
          borderRadius: AppRadius.b12,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s12),
            child: Row(children: [
              Icon(icon, size: 20, color: selected ? c.accent : c.labelNeutral),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body1.copyWith(
                    color: selected ? c.accent : c.labelNeutral,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PlainTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PlainTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: color),
      title: Text(label, style: AppType.body2.copyWith(color: color)),
      onTap: onTap,
    );
  }
}

/// 태블릿 좌측 레일 — **교실 목록 전용**(아이콘+짧은 이름).
class _Rail extends ConsumerWidget {
  final WebShell shell;
  const _Rail({required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final classrooms = _classroomsFor(ref, shell.teacher);
    return Container(
      width: 88,
      color: c.bg,
      child: Column(
        children: [
          const SizedBox(height: AppSpace.s8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
              children: [
                for (final room in classrooms)
                  _RailClassroom(
                    name: room.name.isEmpty ? '교실' : room.name,
                    onTap: () => _onClassroomTap(context, ref, shell.teacher, room.id, room.name),
                  ),
                _RailAction(
                  icon: Icons.add,
                  label: shell.teacher ? '만들기' : '참여',
                  onTap: () => _addClassroom(context, ref, shell.teacher),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.lineAlt),
          IconButton(tooltip: '내 정보', onPressed: () => context.push('/settings'), icon: Icon(Icons.settings_outlined, color: c.labelNeutral)),
          IconButton(tooltip: '로그아웃', onPressed: () => logoutFromWeb(context, ref), icon: Icon(Icons.logout, color: c.negative)),
          const SizedBox(height: AppSpace.s8),
        ],
      ),
    );
  }
}

class _RailClassroom extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _RailClassroom({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: AppSpace.s2),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.b12,
        child: InkWell(
          borderRadius: AppRadius.b12,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
            child: Column(children: [
              Icon(Icons.meeting_room_outlined, size: 24, color: c.labelNeutral),
              const SizedBox(height: AppSpace.s4),
              Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppType.caption2.copyWith(color: c.labelNeutral)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RailAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: AppSpace.s2),
      child: Material(
        color: c.accentSoft,
        borderRadius: AppRadius.b12,
        child: InkWell(
          borderRadius: AppRadius.b12,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
            child: Column(children: [
              Icon(icon, size: 22, color: c.accent),
              const SizedBox(height: AppSpace.s4),
              Text(label, textAlign: TextAlign.center, style: AppType.caption2.copyWith(color: c.accent)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 데스크톱 하단 푸터 — **My 화면 전용** IN by CLASS 브랜드 정보(P8 #1).
class _Footer extends StatelessWidget {
  static const String appVersion = '1.0.0';
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: c.bgAlt, border: Border(top: BorderSide(color: c.lineAlt))),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kWebContentMaxWidth, minHeight: 220),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('IN by CLASS', style: AppType.title2.copyWith(color: c.labelStrong, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpace.s8),
                Text('학습 관리부터 교실 운영까지', style: AppType.body2.copyWith(color: c.labelAlt)),
                const SizedBox(height: AppSpace.s24),
                Wrap(
                  spacing: AppSpace.s20,
                  runSpacing: AppSpace.s8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _FooterLink('서비스', () => context.push('/settings')),
                    _FooterLink('이용약관', () => context.push('/legal/terms')),
                    _FooterLink('개인정보처리방침', () => context.push('/legal/privacy')),
                    _FooterLink('문의', () => context.push('/settings')),
                    Text('v$appVersion', style: AppType.caption1.copyWith(color: c.labelAssistive)),
                  ],
                ),
                const SizedBox(height: AppSpace.s24),
                Divider(height: 1, color: c.lineAlt),
                const SizedBox(height: AppSpace.s12),
                Text('© IN by CLASS  All rights reserved.',
                    style: AppType.caption1.copyWith(color: c.labelAssistive)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.b8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s4),
        child: Text(label, style: AppType.body2.copyWith(color: c.labelNeutral)),
      ),
    );
  }
}

/// 알림 종(bell) — 미읽음 배지 + 탭 시 알림 목록 다이얼로그.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final notifs = ref.watch(notificationsProvider).valueOrNull ?? const [];
    final unread = notifs.where((n) => !n.read).length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: '알림',
          onPressed: () => _showNotifications(context, ref),
          icon: Icon(Icons.notifications_none, size: 22, color: c.labelAlt),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: c.negative, borderRadius: AppRadius.bFull),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: AppType.caption2.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final notifs = ref.read(notificationsProvider).valueOrNull ?? const [];
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: c.bgElevated,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.b16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpace.s20),
                child: Text('알림', style: AppType.heading2),
              ),
              Divider(height: 1, color: c.lineAlt),
              Flexible(
                child: notifs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpace.s32),
                        child: Center(child: Text('새 알림이 없어요', style: AppType.body2.copyWith(color: c.labelAlt))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                        itemCount: notifs.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: c.lineAlt),
                        itemBuilder: (_, i) {
                          final n = notifs[i];
                          return ListTile(
                            leading: Icon(
                              n.read ? Icons.mark_email_read_outlined : Icons.mark_email_unread,
                              color: n.read ? c.labelAssistive : c.accent,
                            ),
                            title: Text(n.title.isEmpty ? '알림' : n.title, style: AppType.body2),
                            subtitle: n.body.isEmpty ? null : Text(n.body, style: AppType.caption1.copyWith(color: c.labelAlt)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 웹 헤더/사이드바 공용 로그아웃 — 모바일 셸과 동일한 절차.
Future<void> logoutFromWeb(BuildContext context, WidgetRef ref) async {
  final study = ref.read(studyRepositoryProvider);
  await FcmService.clearCurrentToken(ref.read(accountRepositoryProvider));
  await study.signOut();
  await ref.read(appProvider.notifier).reload();
  if (context.mounted) context.go('/role-select');
}
