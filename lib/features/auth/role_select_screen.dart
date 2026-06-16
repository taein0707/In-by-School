import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/ui.dart';

/// 회원가입 1단계 — 학생 / 선생님 유형 선택.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpace.s8),
              Text('어떻게 사용하실 건가요?', style: AppType.title2),
              const SizedBox(height: AppSpace.s8),
              Text('역할을 먼저 선택해주세요. 나중에 바꿀 수 없어요.',
                  style: AppType.body1.copyWith(color: c.labelAlt)),
              const SizedBox(height: AppSpace.s32),
              _choice(
                context,
                emoji: '📚',
                title: '학생',
                desc: '숙제와 복습을 관리해요',
                onTap: () => context.push('/signup/student'),
              ),
              const SizedBox(height: AppSpace.s16),
              _choice(
                context,
                emoji: '🧑‍🏫',
                title: '선생님',
                desc: '학생 학습을 관리해요',
                onTap: () => context.push('/signup/teacher'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(BuildContext context,
      {required String emoji, required String title, required String desc, required VoidCallback onTap}) {
    final c = context.c;
    return InkWell(
      borderRadius: AppRadius.b16,
      onTap: onTap,
      child: OclCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s32),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: AppSpace.s12),
            Text(title, style: AppType.title2),
            const SizedBox(height: 6),
            Text(desc, textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
          ],
        ),
      ),
    );
  }
}
