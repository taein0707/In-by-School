import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/life/life.dart';

/// 아이템 — 정령을 돕는 소비/효과 아이템.
class ItemsScreen extends ConsumerWidget {
  const ItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final life = ref.watch(appProvider).life;
    final boostActive = life.xpBoostActive(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('아이템', style: AppType.headline2),
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s8),
          children: [
            _card(context, name: '해독제', icon: Icons.healing, count: life.antidotes,
                desc: '죽은 정령을 부활시킵니다. 골든타임 내에만 사용 가능합니다.',
                btnLabel: '사용',
                enabled: life.state == LifeState.dead && life.antidotes > 0,
                disabledHint: life.state == LifeState.dead ? null : '골든타임에만 사용할 수 있어요',
                onUse: () {
                  ref.read(appProvider.notifier).reviveWithAntidote();
                  _toast(context, '해독제를 사용해 토리를 깨웠어요');
                  context.go('/home');
                }),
            _card(context, name: '기억의 결정', icon: Icons.diamond_outlined, count: life.memoryCrystal,
                desc: '환생 시 일부 경험치를 계승합니다.',
                btnLabel: '자동 적용', enabled: false, disabledHint: '환생(관)에서 자동으로 쓰여요'),
            _card(context, name: '성장 촉진제', icon: Icons.bolt, count: life.growthBooster,
                desc: '24시간 동안 XP 획득량이 +20% 증가합니다.',
                btnLabel: boostActive ? '적용 중' : '사용',
                enabled: !boostActive && life.growthBooster > 0,
                disabledHint: boostActive ? '효과가 적용되고 있어요' : null,
                onUse: () {
                  ref.read(appProvider.notifier).useGrowthBooster();
                  _toast(context, '성장 촉진제 사용 — 24시간 XP +20%');
                }),
            _card(context, name: '각성 보호막', icon: Icons.shield_outlined, count: life.awakeningShield,
                desc: '각성 계약 실패(사망)를 1회 무효화합니다.',
                btnLabel: '자동 적용', enabled: false, disabledHint: '계약 중 위기 때 자동으로 쓰여요'),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _card(BuildContext context,
      {required String name,
      required IconData icon,
      required int count,
      required String desc,
      required String btnLabel,
      required bool enabled,
      String? disabledHint,
      VoidCallback? onUse}) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(color: c.bgElevated, borderRadius: AppRadius.b16, border: Border.all(color: c.lineAlt)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: AppRadius.b12),
              child: Icon(icon, color: c.accent, size: 22),
            ),
            const SizedBox(width: AppSpace.s12),
            Text(name, style: AppType.headline2),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: c.fill, borderRadius: AppRadius.bFull),
              child: Text('보유 $count', style: AppType.label2.copyWith(color: c.labelNeutral, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: AppSpace.s10),
          Text(desc, style: AppType.body2.copyWith(color: c.labelNeutral, height: 1.5)),
          const SizedBox(height: AppSpace.s12),
          Row(children: [
            if (disabledHint != null && !enabled)
              Expanded(child: Text(disabledHint, style: AppType.caption1.copyWith(color: c.labelAlt))),
            if (!(disabledHint != null && !enabled)) const Spacer(),
            SizedBox(
              height: 38,
              child: Material(
                color: enabled ? c.accent : c.fill,
                borderRadius: AppRadius.b12,
                child: InkWell(
                  borderRadius: AppRadius.b12,
                  onTap: enabled ? onUse : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: Text(btnLabel,
                          style: AppType.label1.copyWith(
                              color: enabled ? Colors.white : c.labelAssistive, fontWeight: FontWeight.w700)),
                    ),
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
