import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ocl_study/app/app_providers.dart';
import 'package:ocl_study/core/theme/app_theme.dart';
import 'package:ocl_study/domain/growth/growth.dart';
import 'package:ocl_study/domain/spirit/spirit_stage.dart';
import 'package:ocl_study/domain/study/study_mode.dart';
import 'package:ocl_study/domain/study/study_session.dart';
import 'package:ocl_study/features/study/evolution_page.dart';

class _EvoNotifier extends AppNotifier {
  final int before;
  final int after;
  _EvoNotifier(this.before, this.after);

  @override
  AppState build() {
    final gain = SessionGain(
      xp: 100, focusedMin: 25, leveledUp: 1, stageUp: true,
      beforeLevel: SpiritStage.all[before].levelMin,
      afterLevel: SpiritStage.all[after].levelMin,
      beforeStage: before, afterStage: after,
    );
    final session = StudySession(
      mode: StudyMode.free, subject: '수학', focusedMin: 25, goalMin: 0,
      hour: 20, date: DateTime(2026, 6, 10),
    );
    return AppState(
      growth: GrowthState(level: SpiritStage.all[after].levelMin),
      sessions: const [],
      lastResult: SessionResult(gain: gain, session: session),
    );
  }
}

Widget _host(int before, int after) => ProviderScope(
      overrides: [appProvider.overrideWith(() => _EvoNotifier(before, after))],
      child: MaterialApp(theme: AppTheme.light(), home: const EvolutionPage()),
    );

void main() {
  testWidgets('Egg-crack ceremony builds (egg → light point)', (t) async {
    await t.pumpWidget(_host(0, 1));
    await t.pump();
    expect(find.text('알이 깨어나려 해요'), findsOneWidget);
  });

  testWidgets('Evolution sequence builds (spirit → advanced)', (t) async {
    await t.pumpWidget(_host(2, 3));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    // no exception during the animated sequence
  });
}
