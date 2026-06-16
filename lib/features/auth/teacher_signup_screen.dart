import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/account_providers.dart';
import '../../app/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/notifications/fcm_service.dart';
import '../../domain/account/user_profile.dart';
import '../../domain/institution/institution.dart';
import '../../shared/widgets/ui.dart';
import 'institution_search_field.dart';
import 'signup_fields.dart';

/// 회원가입 2단계(선생님) — 이름 · 과목 · 소속 유형 · 이메일 가입.
class TeacherSignupScreen extends ConsumerStatefulWidget {
  const TeacherSignupScreen({super.key});
  @override
  ConsumerState<TeacherSignupScreen> createState() => _TeacherSignupScreenState();
}

class _TeacherSignupScreenState extends ConsumerState<TeacherSignupScreen> {
  final _name = TextEditingController();
  final _subject = TextEditingController();
  final _orgName = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  OrgType _org = OrgType.academy;
  bool _loading = false;
  String? _error;

  // 학교/학원 검색 선택 결과(P9 #1).
  String? _schoolId, _schoolName, _academyId, _academyName;

  void _onInstitution(Institution inst) {
    setState(() {
      if (inst.kind == InstitutionKind.school) {
        _schoolId = inst.id;
        _schoolName = inst.name;
      } else {
        _academyId = inst.id;
        _academyName = inst.name;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    _orgName.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pw = _pw.text;
    if (name.isEmpty) return setState(() => _error = '이름을 입력해주세요.');
    if (_subject.text.trim().isEmpty) return setState(() => _error = '담당 과목을 입력해주세요.');
    if (email.isEmpty || pw.length < 6) {
      return setState(() => _error = '이메일과 6자 이상 비밀번호를 입력해주세요.');
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(studyRepositoryProvider).signUpEmail(email, pw);
      await ref.read(accountRepositoryProvider).createProfile(
            role: UserRole.teacher,
            displayName: name,
            subject: _subject.text.trim(),
            orgType: _org,
            orgName: _orgName.text.trim().isEmpty ? null : _orgName.text.trim(),
            schoolId: _schoolId,
            schoolName: _schoolName,
            academyId: _academyId,
            academyName: _academyName,
          );
      await FcmService.syncToken(ref.read(accountRepositoryProvider));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasOnboarded', true);
      } catch (_) {}
      await ref.read(appProvider.notifier).reload();
      if (mounted) context.go('/t/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authMessage(e.code));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        title: Text('선생님 회원가입', style: AppType.headline2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s24),
          children: [
            signupField(context, _name, '이름'),
            const SizedBox(height: AppSpace.s12),
            signupField(context, _subject, '담당 과목 (예: 영어)'),
            const SizedBox(height: AppSpace.s20),
            const SectionLabel('소속 유형'),
            Row(
              children: [
                for (final o in OrgType.values) ...[
                  _seg(context, o),
                  if (o != OrgType.values.last) const SizedBox(width: AppSpace.s8),
                ],
              ],
            ),
            const SizedBox(height: AppSpace.s12),
            // 학교/학원은 검색해서 선택, 과외는 자유 입력(P9 #1).
            if (_org == OrgType.tutoring)
              signupField(context, _orgName, '소속 이름 (선택 · 예: ○○과외)')
            else
              InstitutionSearchField(
                controller: _orgName,
                kind: _org == OrgType.school ? InstitutionKind.school : InstitutionKind.academy,
                onSelected: _onInstitution,
                hintText: _org == OrgType.school ? '학교 이름 검색 (예: 안양고)' : '학원 이름 검색 (예: 메가스터디)',
              ),
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

  Widget _seg(BuildContext context, OrgType o) {
    final c = context.c;
    final selected = _org == o;
    return Expanded(
      child: InkWell(
        borderRadius: AppRadius.b14,
        onTap: () => setState(() => _org = o),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accent : c.bgElevated,
            borderRadius: AppRadius.b14,
            border: Border.all(color: selected ? c.accent : c.lineAlt),
          ),
          child: Text(o.label,
              style: AppType.label1.copyWith(color: selected ? Colors.white : c.labelAlt)),
        ),
      ),
    );
  }
}
