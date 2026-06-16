import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/classroom_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/account/user_profile.dart';
import '../../shared/widgets/ui.dart';

/// P8 #4 — 초대 링크(`/join?code=ABC123`) 자동 가입 화면.
/// 로그인한 학생이면 코드로 즉시 참여하고 해당 교실로 이동한다.
class JoinClassroomPage extends ConsumerStatefulWidget {
  final String code;
  const JoinClassroomPage({super.key, required this.code});

  @override
  ConsumerState<JoinClassroomPage> createState() => _JoinClassroomPageState();
}

class _JoinClassroomPageState extends ConsumerState<JoinClassroomPage> {
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile != null && profile.role == UserRole.teacher) {
      setState(() {
        _busy = false;
        _error = '참여는 학생 계정에서만 할 수 있어요.';
      });
      return;
    }
    try {
      final cls = await ref.read(classroomRepositoryProvider).joinClassroomByCode(
            code: widget.code,
            studentName: profile?.displayName ?? '',
          );
      if (!mounted) return;
      context.go('/classrooms/${cls.id}', extra: cls.name);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '코드에 맞는 교실을 찾지 못했어요. 코드를 다시 확인해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s32),
            child: _busy
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: c.accent),
                    const SizedBox(height: AppSpace.s16),
                    Text('교실에 참여하는 중…', style: AppType.headline2.copyWith(color: c.labelNeutral)),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.meeting_room_outlined, size: 48, color: c.labelAssistive),
                    const SizedBox(height: AppSpace.s12),
                    Text(_error ?? '참여하지 못했어요.',
                        textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
                    const SizedBox(height: AppSpace.s20),
                    OclButton('내 교실로 가기', onPressed: () => context.go('/classrooms')),
                    const SizedBox(height: AppSpace.s8),
                    TextButton(onPressed: _busy ? null : _join, child: const Text('다시 시도')),
                  ]),
          ),
        ),
      ),
    );
  }
}
