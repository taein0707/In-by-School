import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/account/user_profile.dart';
import '../../shared/widgets/ui.dart';

/// 환영 화면(서비스 소개 전용) — Splash 이후 진입, **자동 이동 금지**.
/// 단계별 Fade 로 OCL 소개를 보여주고, 사용자가 직접 '시작하기'를 눌러야 진입.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});
  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  // 0:로고/OCL → 1:공부를 기록하고 → 2:성장을 확인하고 → 3:목표 달성 → 4:버튼
  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  Future<void> _reveal() async {
    for (var i = 1; i <= 4; i++) {
      await Future.delayed(const Duration(milliseconds: 380));
      if (!mounted) return;
      setState(() => _stage = i);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    // 로그인 상태면 홈으로, 아니면 역할 선택으로.
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      final role = ref.read(currentProfileProvider).valueOrNull?.role;
      context.go(role == UserRole.teacher ? '/t/home' : '/home');
    } else {
      context.go('/role-select');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // 로고 + OCL (1단계)
              _fade(
                _stage >= 0,
                Column(children: [
                  Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b24),
                    child: Icon(Icons.auto_stories_outlined, size: 48, color: c.accent),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  Text('Open Class Lounge',
                      textAlign: TextAlign.center, style: AppType.title2.copyWith(color: c.labelNormal)),
                ]),
              ),
              const SizedBox(height: AppSpace.s32),
              // 소개 3줄 (단계별 Fade)
              _line(c, _stage >= 1, '공부를 기록하고,'),
              const SizedBox(height: AppSpace.s8),
              _line(c, _stage >= 2, '성장을 확인하고,'),
              const SizedBox(height: AppSpace.s8),
              _line(c, _stage >= 3, '함께 목표를 달성하세요.'),
              const SizedBox(height: AppSpace.s20),
              _fade(
                _stage >= 4,
                Text('학생과 선생님을 위한\n올인원 학습 관리 플랫폼',
                    textAlign: TextAlign.center, style: AppType.body2.copyWith(color: c.labelAlt, height: 1.5)),
              ),
              const Spacer(flex: 3),
              // 시작하기 (마지막 단계에 등장)
              _fade(
                _stage >= 4,
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  OclButton('시작하기', onPressed: _start),
                  const SizedBox(height: AppSpace.s12),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: Text('이미 계정이 있으신가요? 로그인', style: AppType.label1.copyWith(color: c.labelAlt)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fade(bool visible, Widget child) =>
      AnimatedOpacity(opacity: visible ? 1 : 0, duration: const Duration(milliseconds: 420), child: child);

  Widget _line(AppColors c, bool visible, String text) => _fade(
        visible,
        Text(text, textAlign: TextAlign.center, style: AppType.title3.copyWith(color: c.labelNeutral)),
      );
}
