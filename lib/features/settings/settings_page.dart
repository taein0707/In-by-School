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
import '../../domain/account/notif_prefs.dart';
import '../../shared/widgets/ui.dart';

/// 설정 — 알림 · 계정 · 법적 문서. 출시 필수 기능 묶음.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final study = ref.read(studyRepositoryProvider);
    final isEmail = study.isEmailAccount;
    final prefs = ref.watch(notifPrefsProvider).value ?? const NotifPrefs();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('설정', style: AppType.headline2),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            // ---- 알림 설정 ----
            const SectionLabel('알림 설정'),
            OclCard(
              child: Column(
                children: [
                  _switch(context, '전체 알림', prefs.all,
                      (v) => _setPrefs(ref, prefs.copyWith(all: v))),
                  _div(c),
                  _switch(context, '숙제 알림', prefs.assignment, prefs.all
                      ? (v) => _setPrefs(ref, prefs.copyWith(assignment: v))
                      : null),
                  _switch(context, '플래시카드 알림', prefs.flashcard, prefs.all
                      ? (v) => _setPrefs(ref, prefs.copyWith(flashcard: v))
                      : null),
                  _switch(context, 'AI 문제 알림', prefs.ai, prefs.all
                      ? (v) => _setPrefs(ref, prefs.copyWith(ai: v))
                      : null),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s20),

            // ---- 계정 ----
            const SectionLabel('계정'),
            if (isEmail)
              _tile(context, '비밀번호 재설정', Icons.lock_reset_outlined,
                  () => _resetPassword(context, ref)),
            _tile(context, '로그아웃', Icons.logout, () => _logout(context, ref)),
            _tile(context, '회원 탈퇴', Icons.person_remove_outlined,
                () => _deleteAccount(context, ref), danger: true),
            const SizedBox(height: AppSpace.s20),

            // ---- 법적 ----
            const SectionLabel('약관 및 정보'),
            _tile(context, '개인정보처리방침', Icons.privacy_tip_outlined,
                () => context.push('/legal/privacy')),
            _tile(context, '이용약관', Icons.description_outlined,
                () => context.push('/legal/terms')),
            _tile(context, '오픈소스 라이선스', Icons.code_outlined, () {
              showLicensePage(context: context, applicationName: 'OCL Study');
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _setPrefs(WidgetRef ref, NotifPrefs prefs) =>
      ref.read(accountRepositoryProvider).setNotifPrefs(prefs);

  Future<void> _resetPassword(BuildContext context, WidgetRef ref) async {
    final study = ref.read(studyRepositoryProvider);
    final email = study.email;
    if (email == null) return;
    try {
      await study.sendPasswordReset(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$email 로 재설정 메일을 보냈어요.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메일 발송에 실패했어요. 잠시 후 다시 시도해주세요.')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final study = ref.read(studyRepositoryProvider);
    await FcmService.clearCurrentToken(ref.read(accountRepositoryProvider));
    await study.signOut();
    await ref.read(appProvider.notifier).reload();
    // 로그아웃 후 역할 선택(첫 화면)으로 일원화.
    if (context.mounted) context.go('/role-select');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DeleteAccountSheet(),
    );
    if (ok == true && context.mounted) {
      await ref.read(appProvider.notifier).reload();
      // 탈퇴 후 역할 선택(첫 화면)으로.
      if (context.mounted) context.go('/role-select');
    }
  }

  Widget _switch(BuildContext context, String label, bool value, ValueChanged<bool>? onChanged) {
    final c = context.c;
    final on = value && onChanged != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppType.body1.copyWith(color: onChanged == null ? c.labelAssistive : c.labelNeutral)),
        Switch(value: on, activeColor: c.accent, onChanged: onChanged),
      ],
    );
  }

  Widget _div(AppColors c) => Divider(height: AppSpace.s12, color: c.lineAlt);

  Widget _tile(BuildContext context, String label, IconData icon, VoidCallback onTap, {bool danger = false}) {
    final c = context.c;
    final color = danger ? c.negative : c.labelNeutral;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Material(
        color: c.bgElevated,
        borderRadius: AppRadius.b14,
        child: InkWell(
          borderRadius: AppRadius.b14,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s16),
            decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: c.lineAlt)),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: AppSpace.s12),
                Text(label, style: AppType.body1.copyWith(color: color)),
                const Spacer(),
                if (!danger) Icon(Icons.chevron_right, color: c.labelAssistive),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 회원 탈퇴 확인 + (이메일 계정) 재인증 시트.
class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();
  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _pw = TextEditingController();
  bool _agree = false;
  bool _busy = false;
  bool _needReauth = false; // requires-recent-login 발생 시 비번 요구
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_agree) return setState(() => _error = '안내를 확인하고 동의에 체크해주세요.');
    final study = ref.read(studyRepositoryProvider);
    final account = ref.read(accountRepositoryProvider);
    final uid = study.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // 재인증이 필요한 단계면 먼저 처리.
      if (_needReauth) {
        if (_pw.text.isEmpty) {
          setState(() {
            _busy = false;
            _error = '비밀번호를 입력해주세요.';
          });
          return;
        }
        await study.reauthenticate(_pw.text);
      }
      // 데이터 연쇄 삭제 → 토큰 정리 → Auth 계정 삭제.
      await account.purgeUserData(uid);
      await FcmService.clearCurrentToken(account);
      await study.deleteAuthUser();
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        setState(() {
          _needReauth = true;
          _busy = false;
          _error = '보안을 위해 비밀번호를 다시 입력해주세요.';
        });
      } else {
        setState(() {
          _busy = false;
          _error = '탈퇴에 실패했어요 (${e.code}).';
        });
      }
    } catch (_) {
      setState(() {
        _busy = false;
        _error = '탈퇴 처리 중 문제가 생겼어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isEmail = ref.read(studyRepositoryProvider).isEmailAccount;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.s24,
        right: AppSpace.s24,
        top: AppSpace.s24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('회원 탈퇴', style: AppType.title3.copyWith(color: c.negative, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpace.s12),
          Text('탈퇴하면 아래 데이터가 즉시 영구 삭제되며 복구할 수 없어요.',
              style: AppType.body1.copyWith(color: c.labelNeutral)),
          const SizedBox(height: AppSpace.s8),
          Text('• 프로필·학습 기록(토리 성장 포함)\n• 연결·숙제·플래시카드·AI 문제 결과\n• 받은/보낸 알림',
              style: AppType.body2.copyWith(color: c.labelAlt)),
          const SizedBox(height: AppSpace.s16),
          if (_needReauth || (isEmail && _busy)) ...[
            TextField(
              controller: _pw,
              obscureText: true,
              autofocus: _needReauth,
              style: AppType.body1.copyWith(color: c.labelNormal),
              decoration: InputDecoration(
                hintText: '비밀번호 확인',
                filled: true,
                fillColor: c.bgElevated,
                enabledBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
                focusedBorder: OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
              ),
            ),
            const SizedBox(height: AppSpace.s12),
          ],
          InkWell(
            onTap: () => setState(() => _agree = !_agree),
            child: Row(children: [
              Icon(_agree ? Icons.check_box : Icons.check_box_outline_blank,
                  color: _agree ? c.negative : c.labelAssistive, size: 22),
              const SizedBox(width: AppSpace.s8),
              Expanded(child: Text('위 내용을 확인했고 영구 삭제에 동의합니다.',
                  style: AppType.body2.copyWith(color: c.labelNeutral))),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.s8),
            Text(_error!, style: AppType.body2.copyWith(color: c.negative)),
          ],
          const SizedBox(height: AppSpace.s16),
          _busy
              ? Center(child: CircularProgressIndicator(color: c.negative))
              : Row(children: [
                  Expanded(child: OclButton('취소', ghost: true, onPressed: () => Navigator.pop(context, false))),
                  const SizedBox(width: AppSpace.s10),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: Material(
                        color: c.negative,
                        borderRadius: AppRadius.b16,
                        child: InkWell(
                          borderRadius: AppRadius.b16,
                          onTap: _delete,
                          child: Center(child: Text('탈퇴', style: AppType.headline2.copyWith(color: Colors.white))),
                        ),
                      ),
                    ),
                  ),
                ]),
        ],
      ),
    );
  }
}
