import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../domain/account/user_profile.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../../features/home/home_page.dart';
import '../../features/auth/welcome_page.dart';
import '../../features/splash/splash_page.dart';
import '../responsive/web_max_width.dart';
import '../../features/study/study_hub_page.dart';
import '../../features/tasks/student_tasks_page.dart';
import '../../features/record/record_page.dart';
import '../../features/my/my_page.dart';
import '../../features/growth/growth_page.dart';
import '../../features/items/items_screen.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/study/session_config.dart';
import '../../features/study/study_launch_page.dart';
import '../../features/study/study_setup_page.dart';
import '../../features/review/review_page.dart';
import '../../domain/study/study_mode.dart';
import '../../features/study/study_active_page.dart';
import '../../features/study/study_result_page.dart';
import '../../features/study/evolution_page.dart';
import '../../features/life/life_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/role_select_screen.dart';
import '../../features/auth/student_signup_screen.dart';
import '../../features/auth/teacher_signup_screen.dart';
import '../../features/auth/change_password_gate_page.dart';
import '../../features/teacher/teacher_scaffold.dart';
import '../../features/teacher/teacher_pages.dart';
import '../../features/teacher/teacher_assignments.dart';
import '../../features/teacher/teacher_flashcards.dart';
import '../../features/teacher/teacher_aiquestions.dart';
import '../../features/teacher/teacher_reports.dart';
import '../../features/teacher/teacher_my_page.dart';
import '../../features/teacher/teacher_dashboard_page.dart';
import '../../features/teacher/teacher_homework_hub_page.dart';
import '../../features/teacher/teacher_students_hub_page.dart';
import '../../features/teacher/teacher_lessons_page.dart';
import '../../features/teacher/teacher_lesson_editor_page.dart';
import '../../features/teacher/ai_lesson_builder_page.dart';
import '../../features/teacher/teacher_live_console_page.dart';
import '../../features/teacher/teacher_tv_mode_page.dart';
import '../../features/student/student_live_player_page.dart';
import '../../domain/lesson/lesson.dart';
import '../../features/classroom/teacher_classrooms_page.dart';
import '../../features/classroom/student_classrooms_page.dart';
import '../../features/classroom/classroom_notice_page.dart';
import '../../features/classroom/teacher_classroom_students_page.dart';
import '../../features/classroom/classroom_detail_page.dart';
import '../../features/classroom/bulk_student_upload_page.dart';
import '../../features/classroom/join_classroom_page.dart';
import '../../features/worksheet/teacher_worksheets_page.dart';
import '../../features/worksheet/worksheet_editor_page.dart';
import '../../features/worksheet/worksheet_results_page.dart';
import '../../features/worksheet/student_worksheets_page.dart';
import '../../features/worksheet/worksheet_solve_page.dart';
import '../../domain/worksheet/worksheet.dart';
import '../../features/classroom_tools/classroom_tools_page.dart';
import '../../features/classroom_tools/seat_layout_page.dart';
import '../../features/classroom_tools/group_maker_page.dart';
import '../../features/classroom_tools/presenter_picker_page.dart';
import '../../features/classroom_tools/timer_page.dart';
import '../../features/presence/activity_monitor_page.dart';
import '../../features/engagement/participation_hub_page.dart';
import '../../features/engagement/bingo_list_page.dart';
import '../../features/engagement/bingo_play_page.dart';
import '../../features/engagement/crossword_list_page.dart';
import '../../features/engagement/crossword_solve_page.dart';
import '../../features/engagement/crossword_results_page.dart';
import '../../features/engagement/quiz_list_page.dart';
import '../../features/engagement/quiz_play_page.dart';
import '../../features/engagement/roulette_page.dart';
import '../../features/report/study_report_page.dart';
import '../../domain/report/study_report.dart';
import '../../features/battle/battle_create_page.dart';
import '../../features/battle/battle_join_page.dart';
import '../../features/battle/battle_live_page.dart';
import '../../features/battle/battle_play_page.dart';
import '../../features/battle/battle_result_page.dart';
import '../../features/student/student_assignments.dart';
import '../../features/student/student_flashcards.dart';
import '../../features/student/student_aiquestions.dart';
import '../../features/notifications/deep_link_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/legal/legal_page.dart';
import '../../features/brand/brand_showcase_page.dart';
import '../../data/notifications/fcm_service.dart';
import '../../domain/assignment/assignment.dart';
import '../../domain/flashcard/flashcard_deck.dart';
import '../../domain/aiquestion/ai_question_set.dart';
import '../../features/vocab/vocab_setup_page.dart';
import '../../features/vocab/flashcard_page.dart';
import '../../features/vocab/vocab_result_page.dart';
import '../../domain/vocab/vocab_word.dart';

/// Whether the user has finished onboarding. Overridden in main() from
/// SharedPreferences; defaults true so tests/previews land on Home.
final onboardedProvider = Provider<bool>((ref) => true);

/// 전역 라우터 참조 — FCM 알림 클릭 딥링크가 위젯 트리 밖에서 이동할 때 사용.
GoRouter? rootRouter;

/// 셸 밖 단독 화면을 데스크톱에서 1160px·가운데로 제한한다(P8 #6).
/// 좁은 화면(<=1160)에선 그대로 전체 폭. Quiz Battle 등은 감싸지 않아 풀스크린 유지.
Widget _wide(BuildContext c, Widget page) =>
    ColoredBox(color: Theme.of(c).scaffoldBackgroundColor, child: WebMaxWidth(child: page));

/// 학생 셸의 루트 경로 — 선생님이 여기에 도착하면 선생님 홈으로 돌린다.
const _studentRoots = {'/home', '/study', '/record', '/my', '/assignments', '/flashcards', '/quizzes'};

/// Router is created once (memoized by Riverpod) so navigation state survives
/// theme rebuilds. 역할(프로필)에 따라 학생 셸(/home)·선생님 셸(/t/*)로 분기.
final routerProvider = Provider<GoRouter>((ref) {
  // 프로필/인증이 바뀌면 redirect 를 다시 평가하도록 GoRouter 를 새로고침.
  final refresh = ValueNotifier<int>(0);
  ref.listen(currentProfileProvider, (_, __) => refresh.value++);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  // 인증/온보딩 게이트 화면 — 프로필이 없어도 머무를 수 있다(역할 선택·가입·로그인·이름).
  const gateRoutes = {'/welcome', '/role-select', '/signup/student', '/signup/teacher', '/login', '/onboarding'};

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // 백엔드 없음(테스트/로컬 프리뷰): 인증 게이트 생략, 스플래시는 홈으로.
      if (Firebase.apps.isEmpty) return loc == '/splash' ? '/home' : null;

      final auth = ref.read(authStateProvider);
      // 인증 복원 중 → 스플래시 유지(새로고침 깜빡임/오redirect 방지).
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      // 인증 스트림 에러 → 미인증으로 간주(환영 화면). .valueOrNull 로 rethrow 방지.
      if (auth.hasError) {
        if (loc == '/splash') return '/welcome';
        return gateRoutes.contains(loc) ? null : '/welcome';
      }

      final user = auth.valueOrNull;
      // 미로그인 → 첫 실행: 환영 화면(스플래시→환영→역할선택). 게이트 화면은 통과.
      if (user == null) {
        if (loc == '/splash') return '/welcome';
        return gateRoutes.contains(loc) ? null : '/welcome';
      }

      final profileAsync = ref.read(currentProfileProvider);
      // 프로필 로딩 중 → 스플래시 유지.
      if (profileAsync.isLoading) return loc == '/splash' ? null : '/splash';
      // 프로필 스트림 에러 → 스플래시 유지(재평가 대기). .valueOrNull 로 rethrow 방지.
      if (profileAsync.hasError) return loc == '/splash' ? null : '/splash';
      final profile = profileAsync.valueOrNull;

      // 임시 비밀번호 강제 변경 게이트(P8-3) — 일괄 생성된 학생은 새 비밀번호 설정 전까지
      // 비밀번호 변경 화면 외 모든 경로 접근을 막는다.
      if (profile != null && profile.mustChangePassword) {
        return loc == '/change-password' ? null : '/change-password';
      }
      if (loc == '/change-password') {
        // 플래그가 내려갔는데 이 화면이면 정상 착지점으로.
        return profile == null
            ? '/role-select'
            : (profile.role == UserRole.teacher ? '/t/home' : '/home');
      }

      // 인증/프로필 확정 후의 정규 착지점.
      final landing = profile == null
          ? '/role-select'
          : (profile.role == UserRole.teacher ? '/t/home' : '/home');
      if (loc == '/splash') return landing;

      // 로그인됐지만 역할(프로필) 미설정 → 역할 선택/가입으로.
      if (profile == null) {
        return gateRoutes.contains(loc) ? null : '/role-select';
      }

      // 선생님: 학생 셸/역할선택/온보딩(토리)으로 가면 교사 홈으로. (교사는 토리 화면 비노출)
      if (profile.role == UserRole.teacher) {
        if (loc == '/role-select' || loc == '/onboarding' || _studentRoots.contains(loc)) {
          return '/t/home';
        }
        return null;
      }

      // 학생: 교사 셸/역할선택으로 가면 학생 홈으로.
      if (loc.startsWith('/t/') || loc == '/role-select') return '/home';
      return null;
    },
    routes: [
      // ---- 부팅 스플래시(인증/프로필 복원 동안 표시 — 새로고침 깜빡임 방지) ----
      GoRoute(path: '/splash', builder: (c, s) => const SplashPage()),
      // ---- 학생 셸 ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => MainScaffold(navigationShell: navShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/study', builder: (c, s) => const StudyHubPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/my', builder: (c, s) => const MyPage())]),
        ],
      ),
      // ---- 선생님 셸(P9-2 개편) — GNB: 홈/숙제/수업/학생/나 ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => TeacherScaffold(navigationShell: navShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/t/home', builder: (c, s) => const TeacherDashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/t/assignments', builder: (c, s) => const TeacherHomeworkHubPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/t/lessons', builder: (c, s) => const TeacherLessonsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/t/students', builder: (c, s) => const TeacherStudentsHubPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/t/my', builder: (c, s) => const TeacherMyPage()),
          ]),
        ],
      ),
      // ---- 교사 보조 기능(셸 밖 최상위 — GNB '더보기'/숙제 허브에서 진입, 삭제 금지) ----
      GoRoute(path: '/t/flashcards', builder: (c, s) => _wide(c, const TeacherFlashcardsPage())),
      GoRoute(path: '/t/ai', builder: (c, s) => _wide(c, const TeacherAiQuestionsPage())),
      GoRoute(
        path: '/t/stats',
        builder: (c, s) => _wide(
            c,
            const TeacherStubPage(
                title: '통계',
                icon: Icons.bar_chart_outlined,
                note: '학생별 공부 시간·완료율·정답률을 주간/월간으로 봐요.')),
      ),
      GoRoute(path: '/t/reports', builder: (c, s) => _wide(c, const TeacherReportsPage())),
      GoRoute(path: '/t/lessons/edit', redirect: (c, s) => s.extra is Lesson ? null : '/t/lessons', builder: (c, s) => TeacherLessonEditorPage(lesson: s.extra as Lesson)),
      GoRoute(path: '/t/lessons/ai', builder: (c, s) => const AiLessonBuilderPage()),
      // ---- Teacher Live Mode(P10-2) ----
      GoRoute(path: '/t/lessons/live', redirect: (c, s) => s.extra is Lesson ? null : '/t/lessons', builder: (c, s) => TeacherLiveConsolePage(lesson: s.extra as Lesson)),
      GoRoute(path: '/t/lessons/tv', redirect: (c, s) => s.extra is Lesson ? null : '/t/lessons', builder: (c, s) => TeacherTvModePage(lesson: s.extra as Lesson)),
      GoRoute(path: '/live/:cid', builder: (c, s) => StudentLivePlayerPage(classroomId: s.pathParameters['cid'] ?? '')),
      // ---- 학생 부가(셸에서 사이드바로 이동 — 최상위 라우트) ----
      GoRoute(path: '/record', builder: (c, s) => _wide(c, const RecordPage())),
      GoRoute(path: '/assignments', builder: (c, s) => _wide(c, const StudentAssignmentsPage())),
      GoRoute(path: '/flashcards', builder: (c, s) => _wide(c, const StudentFlashcardsPage())),
      GoRoute(path: '/quizzes', builder: (c, s) => _wide(c, const StudentAiQuestionsPage())),
      GoRoute(path: '/tasks', builder: (c, s) => _wide(c, const StudentTasksPage())),
      // ---- 환영 화면(P0) ----
      GoRoute(path: '/welcome', builder: (c, s) => const WelcomePage()),
      // ---- 교실(P2-0) ----
      GoRoute(path: '/t/classrooms', builder: (c, s) => _wide(c, const TeacherClassroomsPage())),
      GoRoute(path: '/classrooms', builder: (c, s) => _wide(c, const StudentClassroomsPage())),
      // ---- 초대 링크 자동 가입(P8 #4) — /join?code=ABC123 ----
      GoRoute(
        path: '/join',
        builder: (c, s) => JoinClassroomPage(code: s.uri.queryParameters['code'] ?? ''),
      ),
      // ---- 교실 상세 허브(P3-1) ----
      GoRoute(
        path: '/t/classrooms/:id',
        builder: (c, s) => ClassroomDetailPage(
            classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?, teacher: true),
      ),
      GoRoute(
        path: '/classrooms/:id',
        builder: (c, s) => ClassroomDetailPage(
            classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?, teacher: false),
      ),
      // ---- 학습지(P3-1) ----
      GoRoute(
        path: '/t/classrooms/:id/worksheets',
        builder: (c, s) => TeacherWorksheetsPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?),
      ),
      GoRoute(
        path: '/classrooms/:id/worksheets',
        builder: (c, s) => StudentWorksheetsPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?),
      ),
      GoRoute(
        path: '/worksheets/edit',
        redirect: (c, s) => s.extra is Worksheet ? null : '/home',
        builder: (c, s) => WorksheetEditorPage(worksheet: s.extra as Worksheet),
      ),
      GoRoute(
        path: '/worksheets/results',
        redirect: (c, s) => s.extra is Worksheet ? null : '/home',
        builder: (c, s) => WorksheetResultsPage(worksheet: s.extra as Worksheet),
      ),
      GoRoute(
        path: '/worksheets/solve',
        redirect: (c, s) => s.extra is Worksheet ? null : '/home',
        builder: (c, s) => WorksheetSolvePage(worksheet: s.extra as Worksheet),
      ),
      // ---- 수업 도구(P3-2) — 교사용 ----
      GoRoute(
        path: '/t/classrooms/:id/tools',
        builder: (c, s) => ClassroomToolsPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?),
      ),
      GoRoute(
        path: '/t/classrooms/:id/tools/seats',
        builder: (c, s) => SeatLayoutPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?),
      ),
      GoRoute(
        path: '/t/classrooms/:id/tools/groups',
        builder: (c, s) => GroupMakerPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?),
      ),
      GoRoute(
        path: '/t/classrooms/:id/tools/presenter',
        builder: (c, s) => PresenterPickerPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?),
      ),
      GoRoute(
        path: '/t/classrooms/:id/tools/timer',
        builder: (c, s) => const TimerPage(),
      ),
      // ---- 참여 모니터(P6, 웹 전용) — 교사용 ----
      GoRoute(
        path: '/t/classrooms/:id/monitor',
        builder: (c, s) => ActivityMonitorPage(
            classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?),
      ),
      // ---- 참여 활동(P4) — 교사/학생 공용 허브 + 도구 ----
      GoRoute(
        path: '/t/classrooms/:id/engage',
        builder: (c, s) => ParticipationHubPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?, teacher: true),
      ),
      GoRoute(
        path: '/classrooms/:id/engage',
        builder: (c, s) => ParticipationHubPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?, teacher: false),
      ),
      // 빙고(P4-1)
      GoRoute(
        path: '/t/classrooms/:id/engage/bingo',
        builder: (c, s) => BingoListPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?, teacher: true),
      ),
      GoRoute(
        path: '/classrooms/:id/engage/bingo',
        builder: (c, s) => BingoListPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?, teacher: false),
      ),
      GoRoute(
        path: '/engage/bingo/:gameId',
        builder: (c, s) => BingoPlayPage(gameId: s.pathParameters['gameId'] ?? '', teacher: s.uri.queryParameters['t'] == '1'),
      ),
      // 가로세로 퍼즐(P4-2)
      GoRoute(
        path: '/t/classrooms/:id/engage/crossword',
        builder: (c, s) => CrosswordListPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?, teacher: true),
      ),
      GoRoute(
        path: '/classrooms/:id/engage/crossword',
        builder: (c, s) => CrosswordListPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?, teacher: false),
      ),
      GoRoute(
        path: '/engage/crossword/solve/:setId',
        builder: (c, s) => CrosswordSolvePage(setId: s.pathParameters['setId'] ?? ''),
      ),
      GoRoute(
        path: '/engage/crossword/results/:setId',
        builder: (c, s) => CrosswordResultsPage(setId: s.pathParameters['setId'] ?? ''),
      ),
      // 퀴즈 대회(P4-3)
      GoRoute(
        path: '/t/classrooms/:id/engage/quiz',
        builder: (c, s) => QuizListPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?, teacher: true),
      ),
      GoRoute(
        path: '/classrooms/:id/engage/quiz',
        builder: (c, s) => QuizListPage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?, teacher: false),
      ),
      GoRoute(
        path: '/engage/quiz/:quizId',
        builder: (c, s) => QuizPlayPage(competitionId: s.pathParameters['quizId'] ?? '', teacher: s.uri.queryParameters['t'] == '1'),
      ),
      // 랜덤 룰렛(P4-4)
      GoRoute(
        path: '/t/classrooms/:id/engage/roulette',
        builder: (c, s) => RoulettePage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?),
      ),
      GoRoute(
        path: '/classrooms/:id/engage/roulette',
        builder: (c, s) => RoulettePage(classroomId: s.pathParameters['id'] ?? '', classroomName: s.extra as String?),
      ),
      // ---- 교실 공지(P2-1) — 경로 파라미터(:id=classroomId), 이름은 extra(선택) ----
      GoRoute(
        path: '/t/classrooms/:id/notices',
        builder: (c, s) => ClassroomNoticePage(
          classroomId: s.pathParameters['id'] ?? '',
          classroomName: s.extra as String?,
          teacher: true,
        ),
      ),
      GoRoute(
        path: '/t/classrooms/:id/students',
        builder: (c, s) => TeacherClassroomStudentsPage(
          classroomId: s.pathParameters['id'] ?? '',
          classroomName: s.extra as String?,
        ),
      ),
      // ---- 학생 일괄 등록(P8-3) — 파일 업로드 + AI 이름 추출 ----
      GoRoute(
        path: '/t/classrooms/:id/students/bulk',
        builder: (c, s) => BulkStudentUploadPage(
          classroomId: s.pathParameters['id'] ?? '',
          classroomName: s.extra as String?,
        ),
      ),
      GoRoute(
        path: '/classrooms/:id/notices',
        builder: (c, s) => ClassroomNoticePage(
          classroomId: s.pathParameters['id'] ?? '',
          classroomName: s.extra as String?,
          teacher: false,
        ),
      ),
      // ---- 공통/학생 부가 ----
      GoRoute(path: '/growth', builder: (c, s) => const GrowthPage()),
      GoRoute(path: '/items', builder: (c, s) => const ItemsScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingPage()),
      GoRoute(path: '/study/launch', builder: (c, s) => const StudyLaunchPage()),
      GoRoute(path: '/review', builder: (c, s) => const ReviewPage()),
      // ---- 스터디 플래너(Phase S) ----
      GoRoute(path: '/study-report', builder: (c, s) => _wide(c, const StudyReportPage())),
      GoRoute(
        path: '/t/reports/detail',
        redirect: (c, s) => s.extra is StudyReport ? null : '/t/reports',
        builder: (c, s) => TeacherReportDetailPage(report: s.extra as StudyReport),
      ),
      // ---- 단어 경쟁전(Phase C) ----
      GoRoute(
        path: '/battle/new',
        redirect: (c, s) => s.extra is FlashcardDeck ? null : '/t/flashcards',
        builder: (c, s) => BattleCreatePage(deck: s.extra as FlashcardDeck),
      ),
      GoRoute(path: '/battle/join', builder: (c, s) => const BattleJoinPage()),
      GoRoute(
        path: '/battle/live',
        redirect: (c, s) => s.extra is String ? null : '/t/home',
        builder: (c, s) => BattleLivePage(battleId: s.extra as String),
      ),
      GoRoute(
        path: '/battle/play',
        redirect: (c, s) => s.extra is String ? null : '/battle/join',
        builder: (c, s) => BattlePlayPage(battleId: s.extra as String),
      ),
      GoRoute(
        path: '/battle/result',
        redirect: (c, s) => s.extra is String ? null : '/home',
        builder: (c, s) => BattleResultPage(battleId: s.extra as String),
      ),
      GoRoute(path: '/study/setup', builder: (c, s) => StudySetupPage(initialMode: s.extra as StudyMode?)),
      GoRoute(
        path: '/study/active',
        redirect: (c, s) => s.extra is SessionConfig ? null : '/home',
        builder: (c, s) => StudyActivePage(config: s.extra as SessionConfig),
      ),
      GoRoute(path: '/study/result', builder: (c, s) => const StudyResultPage()),
      GoRoute(path: '/study/evolve', builder: (c, s) => const EvolutionPage()),
      GoRoute(path: '/life', builder: (c, s) => const LifeScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      // ---- 회원가입(역할 선택 → 학생/선생님) ----
      GoRoute(path: '/role-select', builder: (c, s) => const RoleSelectScreen()),
      GoRoute(path: '/signup/student', builder: (c, s) => const StudentSignupScreen()),
      GoRoute(path: '/signup/teacher', builder: (c, s) => const TeacherSignupScreen()),
      // ---- 임시 비밀번호 강제 변경 게이트(P8-3) ----
      GoRoute(path: '/change-password', builder: (c, s) => const ChangePasswordGatePage()),
      // ---- 숙제(Phase 1): 생성·상세는 셸 위에 전체 화면으로 ----
      GoRoute(path: '/t/assignments/new', builder: (c, s) => const TeacherAssignmentCreatePage()),
      GoRoute(
        path: '/t/assignments/detail',
        redirect: (c, s) => s.extra is Assignment ? null : '/t/assignments',
        builder: (c, s) => TeacherAssignmentDetailPage(assignment: s.extra as Assignment),
      ),
      GoRoute(
        path: '/assignments/detail',
        redirect: (c, s) => s.extra is Assignment ? null : '/assignments',
        builder: (c, s) => StudentAssignmentDetailPage(assignment: s.extra as Assignment),
      ),
      // ---- 플래시카드(Phase 2): 생성·상세·학습·결과는 셸 위 전체 화면 ----
      GoRoute(path: '/t/flashcards/new', builder: (c, s) => const TeacherDeckCreatePage()),
      GoRoute(
        path: '/t/flashcards/detail',
        redirect: (c, s) => s.extra is FlashcardDeck ? null : '/t/flashcards',
        builder: (c, s) => TeacherDeckDetailPage(deck: s.extra as FlashcardDeck),
      ),
      GoRoute(
        path: '/flashcards/study',
        redirect: (c, s) => s.extra is FlashcardStudyArgs ? null : '/flashcards',
        builder: (c, s) => StudentDeckStudyPage(args: s.extra as FlashcardStudyArgs),
      ),
      GoRoute(
        path: '/flashcards/result',
        redirect: (c, s) => s.extra is FlashcardResult ? null : '/flashcards',
        builder: (c, s) => StudentFlashcardResultPage(result: s.extra as FlashcardResult),
      ),
      // ---- AI 문제(Phase 3): 생성·상세·풀이·결과는 셸 위 전체 화면 ----
      GoRoute(path: '/t/ai/new', builder: (c, s) => const TeacherQuestionCreatePage()),
      GoRoute(
        path: '/t/ai/detail',
        redirect: (c, s) => s.extra is AiQuestionSet ? null : '/t/ai',
        builder: (c, s) => TeacherQuestionDetailPage(set: s.extra as AiQuestionSet),
      ),
      GoRoute(
        path: '/quizzes/solve',
        redirect: (c, s) => s.extra is QuizSolveArgs ? null : '/quizzes',
        builder: (c, s) => StudentQuizSolvePage(args: s.extra as QuizSolveArgs),
      ),
      GoRoute(
        path: '/quizzes/result',
        redirect: (c, s) => s.extra is QuizResultArgs ? null : '/quizzes',
        builder: (c, s) => StudentQuizResultPage(args: s.extra as QuizResultArgs),
      ),
      GoRoute(path: '/vocab', builder: (c, s) => const VocabSetupPage()),
      GoRoute(
        path: '/vocab/cards',
        redirect: (c, s) => s.extra is List<VocabWord> ? null : '/vocab',
        builder: (c, s) => FlashcardPage(deck: s.extra as List<VocabWord>),
      ),
      GoRoute(
        path: '/vocab/result',
        redirect: (c, s) => s.extra is VocabResult ? null : '/vocab',
        builder: (c, s) => VocabResultPage(result: s.extra as VocabResult),
      ),
      // ---- 브랜드 모션 쇼케이스(IN by CLASS) ----
      GoRoute(path: '/brand', builder: (c, s) => const BrandShowcasePage()),
      // ---- 설정 · 법적 문서(Phase M2) ----
      GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
      GoRoute(
        path: '/legal/:doc',
        builder: (c, s) => LegalPage(docKey: s.pathParameters['doc'] ?? 'privacy'),
      ),
      // ---- 알림 클릭 딥링크 로더(Phase 4) ----
      GoRoute(
        path: '/open',
        builder: (c, s) => DeepLinkPage(
          type: s.uri.queryParameters['type'] ?? '',
          id: s.uri.queryParameters['id'] ?? '',
        ),
      ),
    ],
  );

  // 전역 참조 노출 + 종료 상태에서 들어온 알림 클릭 흘려보내기.
  rootRouter = router;
  FcmService.flushPendingRoute();
  return router;
});

