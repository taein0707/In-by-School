import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/aiquestion_providers.dart';
import '../../app/assignment_providers.dart';
import '../../app/flashcard_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/account/user_profile.dart';

/// 알림 클릭 딥링크 로더 — `/open?type=&id=`.
/// refId 만으로 문서를 불러와 역할(선생님/학생)에 맞는 상세로 이동한다.
///   type=assignment → 숙제 상세
///   type=deck       → 카드(덱) 상세(선생님) / 카드 탭(학생)
///   type=quizset    → 문제 세트 상세(선생님) / 문제 탭(학생)
class DeepLinkPage extends ConsumerStatefulWidget {
  final String type;
  final String id;
  const DeepLinkPage({super.key, required this.type, required this.id});

  @override
  ConsumerState<DeepLinkPage> createState() => _DeepLinkPageState();
}

class _DeepLinkPageState extends ConsumerState<DeepLinkPage> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final isTeacher = ref.read(currentProfileProvider).value?.role == UserRole.teacher;
    try {
      switch (widget.type) {
        case 'assignment':
          final a = await ref.read(assignmentRepositoryProvider).fetchAssignment(widget.id);
          if (a == null) return _fallback(isTeacher);
          _replace(isTeacher ? '/t/assignments/detail' : '/assignments/detail', a);
        case 'deck':
          if (isTeacher) {
            final d = await ref.read(flashcardRepositoryProvider).fetchDeck(widget.id);
            if (d == null) return _fallback(isTeacher);
            _replace('/t/flashcards/detail', d);
          } else {
            _goTab('/flashcards');
          }
        case 'quizset':
          if (isTeacher) {
            final s = await ref.read(aiQuestionRepositoryProvider).fetchSet(widget.id);
            if (s == null) return _fallback(isTeacher);
            _replace('/t/ai/detail', s);
          } else {
            _goTab('/quizzes');
          }
        default:
          _fallback(isTeacher);
      }
    } catch (_) {
      _fallback(isTeacher);
    }
  }

  void _replace(String path, Object extra) {
    if (mounted) context.pushReplacement(path, extra: extra);
  }

  void _goTab(String path) {
    if (mounted) context.go(path);
  }

  void _fallback(bool isTeacher) {
    if (!mounted) return;
    setState(() => _failed = true);
    context.go(isTeacher ? '/t/home' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: _failed
            ? const SizedBox.shrink()
            : CircularProgressIndicator(color: c.accent),
      ),
    );
  }
}
