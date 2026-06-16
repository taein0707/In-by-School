import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ocl_study/app/app_providers.dart';
import 'package:ocl_study/core/theme/app_theme.dart';
import 'package:ocl_study/domain/growth/growth.dart';
import 'package:ocl_study/features/home/home_page.dart';
import 'package:ocl_study/features/record/record_page.dart';
import 'package:ocl_study/features/my/my_page.dart';
import 'package:ocl_study/features/growth/growth_page.dart';

/// Reproduces the real-device first run: a FRESH, empty level-1 user
/// (the smoke test used seed data, so this path was never exercised).
class _FreshNotifier extends AppNotifier {
  @override
  AppState build() => const AppState(growth: GrowthState(), sessions: []);
}

Widget _host(Widget child) => ProviderScope(
      overrides: [appProvider.overrideWith(_FreshNotifier.new)],
      child: MaterialApp(theme: AppTheme.light(), home: child),
    );

void main() {
  testWidgets('Home builds for a fresh empty user', (t) async {
    await t.pumpWidget(_host(const HomePage()));
    await t.pump();
    // 대시보드 개편(P1): 안정적 요소로 검증.
    expect(find.text('오늘 공부 시간'), findsOneWidget);
    expect(find.text('오늘 해야 할 일'), findsOneWidget);
  });
  testWidgets('Record builds for a fresh empty user', (t) async {
    await t.pumpWidget(_host(const RecordPage()));
    await t.pump();
  });
  testWidgets('My builds for a fresh empty user', (t) async {
    await t.pumpWidget(_host(const MyPage()));
    await t.pump();
  });
  testWidgets('Growth builds for a fresh empty user', (t) async {
    await t.pumpWidget(_host(const GrowthPage()));
    await t.pump();
  });
}
