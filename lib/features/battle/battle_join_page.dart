import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account_providers.dart';
import '../../app/battle_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/battle/battle.dart';
import '../../shared/widgets/ui.dart';

/// 학생 참가 — 참가 코드 입력(+ 비회원 닉네임). QR 스캔은 후속 확장(현재 코드 입력).
class BattleJoinPage extends ConsumerStatefulWidget {
  const BattleJoinPage({super.key});
  @override
  ConsumerState<BattleJoinPage> createState() => _BattleJoinPageState();
}

class _BattleJoinPageState extends ConsumerState<BattleJoinPage> {
  final _code = TextEditingController();
  final _nick = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final name = ref.read(currentProfileProvider).value?.displayName ?? '';
    if (name.isNotEmpty) _nick.text = name;
  }

  @override
  void dispose() {
    _code.dispose();
    _nick.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = '참가 코드를 입력해주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(battleRepositoryProvider);
      final session = await repo.findByCode(code);
      if (session == null) {
        setState(() => _error = '코드를 찾을 수 없어요. 다시 확인해주세요.');
        return;
      }
      if (session.status == BattleStatus.ended) {
        setState(() => _error = '이미 종료된 경쟁전이에요.');
        return;
      }
      await repo.joinBattle(battleId: session.id, nickname: _nick.text);
      if (mounted) context.pushReplacement('/battle/play', extra: session.id);
    } finally {
      if (mounted) setState(() => _busy = false);
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
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Text('단어 경쟁전', style: AppType.headline1),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s24),
          children: [
            Text('참가 코드', style: AppType.title3),
            const SizedBox(height: AppSpace.s8),
            Text('선생님이 보여주는 코드를 입력하면 바로 참여할 수 있어요.',
                style: AppType.body2.copyWith(color: c.labelAlt)),
            const SizedBox(height: AppSpace.s16),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: AppType.display3.copyWith(color: c.labelNormal, letterSpacing: 4),
              decoration: _dec(c, '예) AB3K9Z'),
            ),
            const SizedBox(height: AppSpace.s16),
            Text('닉네임', style: AppType.label1.copyWith(color: c.labelAlt)),
            const SizedBox(height: AppSpace.s8),
            TextField(
              controller: _nick,
              style: AppType.body1.copyWith(color: c.labelNormal),
              decoration: _dec(c, '비워두면 게스트로 참가해요'),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.s12),
              Text(_error!, style: AppType.body2.copyWith(color: c.negative)),
            ],
            const SizedBox(height: AppSpace.s24),
            OclButton(_busy ? '참가 중…' : '참가하기', onPressed: _busy ? null : _join),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(AppColors c, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.bgElevated,
        enabledBorder:
            OutlineInputBorder(borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.lineAlt)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.b14, borderSide: BorderSide(color: c.accent, width: 2)),
        contentPadding: const EdgeInsets.all(AppSpace.s16),
      );
}
