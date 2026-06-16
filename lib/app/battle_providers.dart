import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase/battle_repository.dart';
import '../domain/battle/battle.dart';
import 'account_providers.dart';

final battleRepositoryProvider = Provider<BattleRepository>((ref) => BattleRepository());

/// 미인증(로그아웃/전환)이면 빈 스트림 — stale 리스너 permission-denied 방지(P2-1).
bool _signedOut(Ref ref) =>
    Firebase.apps.isEmpty || ref.watch(authStateProvider).value == null;

/// 세션 단건(문제 포함) 구독.
final battleProvider = StreamProvider.family<BattleSession?, String>((ref, battleId) {
  if (_signedOut(ref)) return Stream.value(null);
  return ref.watch(battleRepositoryProvider).watchBattle(battleId);
});

/// 참가자 목록(점수순) 구독 — 교사 라이브/결과.
final battlePlayersProvider = StreamProvider.family<List<BattlePlayer>, String>((ref, battleId) {
  if (_signedOut(ref)) return Stream.value(const []);
  return ref.watch(battleRepositoryProvider).watchPlayers(battleId);
});
