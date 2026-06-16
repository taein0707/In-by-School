import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 회원가입 화면 공통 입력 필드(로그인 화면 스타일과 동일).
Widget signupField(
  BuildContext context,
  TextEditingController ctrl,
  String hint, {
  TextInputType type = TextInputType.text,
  bool obscure = false,
  bool capital = false,
}) {
  final c = context.c;
  return TextField(
    controller: ctrl,
    keyboardType: type,
    obscureText: obscure,
    autocorrect: false,
    enableSuggestions: false,
    textCapitalization: capital ? TextCapitalization.characters : TextCapitalization.none,
    inputFormatters: capital ? [_UpperCaseFormatter()] : null,
    style: AppType.body1.copyWith(color: c.labelNormal),
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: c.bgElevated,
      enabledBorder:
          OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
      focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s16),
    ),
  );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue next) =>
      next.copyWith(text: next.text.toUpperCase());
}

/// FirebaseAuthException.code → 한국어 안내(로그인/가입 공용).
String authMessage(String code) {
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
