import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ocl_study/core/theme/app_theme.dart';
import 'package:ocl_study/features/brand/brand_motion.dart';

void main() {
  setUp(() => BrandSfx.enabled = false); // silence feedback in tests
  tearDown(() => BrandSfx.enabled = true);

  Widget host(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

  testWidgets('BrandIntro reveals HI CLASS and finishes', (tester) async {
    var done = false;
    await tester.pumpWidget(host(BrandIntro(onDone: () => done = true)));
    await tester.pump(const Duration(milliseconds: 2600)); // run the reveal to completion
    expect(find.text('HI'), findsOneWidget);
    expect(find.text('CLASS'), findsOneWidget);
    expect(find.text('오늘도 목표를 향해 한 걸음 더'), findsOneWidget);
    expect(done, isFalse); // hold (800ms) has just started
    await tester.pump(const Duration(milliseconds: 1000)); // hold elapses
    expect(done, isTrue);
  });

  testWidgets('BrandOutro reaches OUT by CLASS and finishes', (tester) async {
    var done = false;
    await tester.pumpWidget(host(BrandOutro(onDone: () => done = true)));
    await tester.pump(); // first frame
    await tester.pump(const Duration(milliseconds: 4000)); // drain all stage timers
    expect(find.text('OUT'), findsOneWidget);
    expect(find.text('See you tomorrow 👋'), findsOneWidget);
    expect(done, isTrue);
  });

  testWidgets('ClassEnterIntro shows the class name and finishes', (tester) async {
    var done = false;
    await tester.pumpWidget(host(ClassEnterIntro(className: '영어 1반', onDone: () => done = true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3600));
    expect(find.text('영어 1반'), findsOneWidget);
    expect(find.text('오늘도 즐겁게 공부해보자!'), findsOneWidget);
    expect(done, isTrue);
  });

  testWidgets('SubmitCelebration shows reward chips and finishes', (tester) async {
    var done = false;
    await tester.pumpWidget(host(SubmitCelebration(
      subtitle: '자동 채점 12 / 15',
      tori: 20,
      streakDays: 7,
      onDone: () => done = true,
    )));
    await tester.pump(const Duration(milliseconds: 1700)); // run the celebration to completion
    expect(find.text('✨ 제출 완료'), findsOneWidget);
    expect(find.text('+20 토리'), findsOneWidget);
    expect(find.text('🔥 연속 학습 7일'), findsOneWidget);
    expect(done, isFalse); // hold (1300ms) has just started
    await tester.pump(const Duration(milliseconds: 1500));
    expect(done, isTrue);
  });

  testWidgets('SubmitCelebration omits chips when no reward is given', (tester) async {
    await tester.pumpWidget(host(const SubmitCelebration(subtitle: '자동 채점 3 / 5')));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('✨ 제출 완료'), findsOneWidget);
    expect(find.textContaining('토리'), findsNothing);
    expect(find.textContaining('연속 학습'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1400)); // drain hold timer
  });
}
