import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 스플래시(로딩 전용) — Firebase 초기화·인증 복원 동안 표시.
/// 버튼 없음. 라우터 redirect 가 준비 완료 시 자동으로 다음 화면(환영/홈)으로 보낸다.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b24),
                child: Icon(Icons.auto_stories_outlined, size: 50, color: c.accent),
              ),
              const SizedBox(height: AppSpace.s20),
              Text('OCL', style: AppType.display3.copyWith(color: c.labelNormal, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpace.s8),
              Text('Open Class Lounge', style: AppType.headline2.copyWith(color: c.labelNeutral)),
              const SizedBox(height: AppSpace.s4),
              Text('학생과 선생님을 위한 학습 플랫폼', style: AppType.body2.copyWith(color: c.labelAlt)),
              const Spacer(flex: 3),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: c.accent),
              ),
              const SizedBox(height: AppSpace.s12),
              Text('서비스를 준비하고 있어요…', style: AppType.caption1.copyWith(color: c.labelAssistive)),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
