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
import '../../domain/account/user_profile.dart';
import '../../shared/widgets/ui.dart';
import 'signup_fields.dart';

/// 회원가입 2단계(학생) — 이름 · 무소속/소속(코드) · 이메일 가입.
class StudentSignupScreen extends ConsumerStatefulWidget {
  const StudentSignupScreen({super.key});
  @override
  ConsumerState<StudentSignupScreen> createState() => _StudentSignupScreenState();
}

class _StudentSignupScreenState extends ConsumerState<StudentSignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pw = _pw.text;
    if (name.isEmpty) return setState(() => _error = '이름을 입력해주세요.');
    if (email.isEmpty || pw.length < 6) {
      return setState(() => _error = '이메일과 6자 이상 비밀번호를 입력해주세요.');
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(studyRepositoryProvider).signUpEmail(email, pw);
      final account = ref.read(accountRepositoryProvider);
      await account.createProfile(
        role: UserRole.student,
        displayName: name,
      );
      await FcmService.syncToken(account);
      await _finish();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authMessage(e.code));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finish() async {
    await ref.read(appProvider.notifier).reload();
    // 학생: 가입 완료 → 토리 이름 설정(온보딩) → 홈. (이름 설정에서 hasOnboarded 저장)
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('학생 회원가입', style: AppType.headline2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s24),
          children: [
            signupField(context, _name, '이름'),
            const SizedBox(height: AppSpace.s20),
            signupField(context, _email, '이메일', type: TextInputType.emailAddress),
            const SizedBox(height: AppSpace.s12),
            signupField(context, _pw, '비밀번호 (6자 이상)', obscure: true),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.s12),
              Text(_error!, style: AppType.body2.copyWith(color: c.negative)),
            ],
            const SizedBox(height: AppSpace.s24),
            _loading
                ? Center(child: CircularProgressIndicator(color: c.accent))
                : OclButton('가입하기', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
