import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/account_providers.dart';
import '../../data/notifications/fcm_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/brand/brand_intro.dart';
import '../../features/brand/brand_outro.dart';
import '../../shared/widgets/ui.dart';

/// 이메일 로그인/회원가입. 익명 세션이 있으면 데이터를 보존하며 계정으로 연결.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _signup = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pw = _pw.text;
    if (email.isEmpty || pw.length < 6) {
      setState(() => _error = '이메일과 6자 이상 비밀번호를 입력해주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(studyRepositoryProvider);
    try {
      if (_signup) {
        await repo.signUpEmail(email, pw);
      } else {
        await repo.signInEmail(email, pw);
      }
      // 첫 인상: 로그인 성공 → "IN by CLASS" 브랜드 인트로.
      if (mounted) await BrandIntro.show(context);
      await ref.read(appProvider.notifier).reload();
      if (mounted) context.pop();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _msg(e.code));
    } catch (_) {
      setState(() => _error = '문제가 생겼어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _msg(String code) {
    switch (code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않아요.';
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return '이미 가입된 이메일이에요. 로그인해주세요.';
      case 'weak-password':
        return '비밀번호가 너무 약해요.';
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 맞지 않아요.';
      case 'user-not-found':
        return '가입되지 않은 이메일이에요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요.';
      default:
        return '인증에 실패했어요 ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final repo = ref.read(studyRepositoryProvider);
    final signedIn = repo.isEmailAccount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text(signedIn ? '계정' : (_signup ? '회원가입' : '로그인'), style: AppType.headline2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: signedIn ? _account(c, repo) : _form(c),
        ),
      ),
    );
  }

  Widget _form(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s8),
        Text(_signup ? '계정을 만들면 기기를 바꿔도\n토리와 기록이 이어져요.' : '다시 만나서 반가워요.',
            style: AppType.body1.copyWith(color: c.labelAlt)),
        const SizedBox(height: AppSpace.s20),
        _field(c, _email, '이메일', TextInputType.emailAddress, false),
        const SizedBox(height: AppSpace.s12),
        _field(c, _pw, '비밀번호 (6자 이상)', TextInputType.visiblePassword, true),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.s12),
          Text(_error!, style: AppType.body2.copyWith(color: c.negative)),
        ],
        const SizedBox(height: AppSpace.s24),
        _loading
            ? Center(child: CircularProgressIndicator(color: c.accent))
            : OclButton(_signup ? '가입하기' : '로그인', onPressed: _submit),
        const SizedBox(height: AppSpace.s12),
        TextButton(
          onPressed: () => setState(() {
            _signup = !_signup;
            _error = null;
          }),
          child: Text(_signup ? '이미 계정이 있어요 · 로그인' : '계정이 없어요 · 회원가입',
              style: AppType.label1.copyWith(color: c.accent)),
        ),
        const SizedBox(height: AppSpace.s4),
        TextButton(
          onPressed: () => context.push('/role-select'),
          child: Text('학생·선생님으로 시작하기',
              style: AppType.label2.copyWith(color: c.labelAlt)),
        ),
      ],
    );
  }

  Widget _account(AppColors c, repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s8),
        Text('로그인됨', style: AppType.label2.copyWith(color: c.labelAlt)),
        const SizedBox(height: 4),
        Text(repo.email ?? '', style: AppType.headline2),
        const Spacer(),
        OclButton('로그아웃', ghost: true, onPressed: () async {
          // 토큰 정리(uid 유효할 때) → 로그아웃 → 역할 선택으로 일원화.
          await FcmService.clearCurrentToken(ref.read(accountRepositoryProvider));
          await repo.signOut();
          // 작별 인사: "HI CLASS → OUT by CLASS" 브랜드 아웃트로.
          if (mounted) await BrandOutro.show(context);
          await ref.read(appProvider.notifier).reload();
          if (mounted) context.go('/role-select');
        }),
      ],
    );
  }

  Widget _field(AppColors c, TextEditingController ctrl, String hint, TextInputType type, bool obscure) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      style: AppType.body1.copyWith(color: c.labelNormal),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.bgElevated,
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
      ),
    );
  }
}
