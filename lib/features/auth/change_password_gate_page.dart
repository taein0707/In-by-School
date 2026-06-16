import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/notifications/fcm_service.dart';
import '../../shared/widgets/ui.dart';

/// P8-3 — 일괄 생성된 학생의 첫 로그인 강제 비밀번호 변경 화면.
/// 라우터가 `mustChangePassword == true` 인 동안 이 화면 외 접근을 막는다.
/// 새 비밀번호 저장(플래그 해제) 시 프로필 스트림이 갱신되며 라우터가 정상 화면으로 보낸다.
class ChangePasswordGatePage extends ConsumerStatefulWidget {
  const ChangePasswordGatePage({super.key});

  @override
  ConsumerState<ChangePasswordGatePage> createState() => _ChangePasswordGatePageState();
}

class _ChangePasswordGatePageState extends ConsumerState<ChangePasswordGatePage> {
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pw = _pw.text;
    if (pw.length < 6) {
      setState(() => _error = '새 비밀번호는 6자 이상이어야 해요.');
      return;
    }
    if (pw != _confirm.text) {
      setState(() => _error = '비밀번호가 서로 달라요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).completePasswordChange(pw);
      // 성공 — users 문서의 플래그가 내려가면 currentProfileProvider 가 갱신되고
      // 라우터 redirect 가 자동으로 홈으로 보낸다. 안전하게 명시 이동도 시도.
      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.code == 'requires-recent-login'
          ? '보안을 위해 다시 로그인한 뒤 변경해주세요.'
          : '변경에 실패했어요 (${e.code}).');
    } catch (_) {
      setState(() => _error = '문제가 생겼어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final study = ref.read(studyRepositoryProvider);
    await FcmService.clearCurrentToken(ref.read(accountRepositoryProvider));
    await study.signOut();
    await ref.read(appProvider.notifier).reload();
    if (mounted) context.go('/role-select');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b20),
                    child: Icon(Icons.lock_reset, size: 34, color: c.accent),
                  ),
                  const SizedBox(height: AppSpace.s20),
                  Text('새 비밀번호를 설정해주세요', style: AppType.title3.copyWith(color: c.labelStrong)),
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    '지금 비밀번호는 선생님이 만든 임시 비밀번호예요.\n나만 아는 새 비밀번호로 바꿔야 시작할 수 있어요.',
                    style: AppType.body2.copyWith(color: c.labelAlt),
                  ),
                  const SizedBox(height: AppSpace.s24),
                  _field(c, _pw, '새 비밀번호 (6자 이상)'),
                  const SizedBox(height: AppSpace.s12),
                  _field(c, _confirm, '새 비밀번호 확인', onSubmit: _save),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpace.s12),
                    Text(_error!, style: AppType.body2.copyWith(color: c.negative)),
                  ],
                  const SizedBox(height: AppSpace.s24),
                  _loading
                      ? Center(child: CircularProgressIndicator(color: c.accent))
                      : OclButton('변경하고 시작하기', onPressed: _save),
                  const SizedBox(height: AppSpace.s8),
                  TextButton(
                    onPressed: _loading ? null : _logout,
                    child: Text('로그아웃', style: AppType.label1.copyWith(color: c.labelAlt)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(AppColors c, TextEditingController ctrl, String hint, {VoidCallback? onSubmit}) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      style: AppType.body1.copyWith(color: c.labelNormal),
      onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.bgElevated,
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
        contentPadding: const EdgeInsets.all(AppSpace.s16),
      ),
    );
  }
}
