import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_providers.dart';
import '../../app/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/tori_spirit.dart';
import '../../shared/widgets/ui.dart';

/// 온보딩 — 소개 → 정령 이름 → 첫 공부. 첫 성취까지 최단 경로.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;
  final _nameCtrl = TextEditingController(text: '토리');

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = ref.watch(settingsProvider).accent;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              ToriSpirit(stageIndex: _step == 0 ? 1 : 0, size: 150, accent: accent),
              const SizedBox(height: AppSpace.s24),
              if (_step == 0) ...[
                Text('지식 정령과 함께\n성장하는 학습', textAlign: TextAlign.center, style: AppType.title2),
                const SizedBox(height: AppSpace.s12),
                Text('OCL은 타이머가 아니에요. 공부할수록\n토리가 당신을 더 깊이 이해해요.',
                    textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
              ] else if (_step == 1) ...[
                Text('정령의 이름을\n지어줄까요?', textAlign: TextAlign.center, style: AppType.title2),
                const SizedBox(height: AppSpace.s16),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _nameCtrl,
                    textAlign: TextAlign.center,
                    maxLength: 8,
                    style: AppType.headline1,
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: c.bgElevated,
                      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
                      focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
                    ),
                  ),
                ),
              ] else ...[
                Text('${_nameCtrl.text}을(를) 만났어요', textAlign: TextAlign.center, style: AppType.title2),
                const SizedBox(height: AppSpace.s12),
                Text('아직 깨어나지 않은 지식의 알이에요.\n첫 공부로 깨워볼까요?',
                    textAlign: TextAlign.center, style: AppType.body1.copyWith(color: c.labelAlt)),
              ],
              const Spacer(),
              OclButton(
                // 소개(0) → 토리 이름(1, 마지막). 가입 직후 학생만 진입하며, 끝나면 홈으로.
                _step < 1 ? '다음' : '시작하기',
                onPressed: () async {
                  if (_step < 1) {
                    setState(() => _step++);
                    return;
                  }
                  final name = _nameCtrl.text.trim().isEmpty ? '토리' : _nameCtrl.text.trim();
                  ref.read(appProvider.notifier).rename(name);
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('hasOnboarded', true);
                  } catch (_) {}
                  if (context.mounted) context.go('/home');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
