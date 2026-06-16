import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ocl_study/app/app.dart';

void main() {
  testWidgets('App boots to Home with 토리', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OclApp()));
    await tester.pump();

    // 대시보드 개편(P1): 부팅 후 홈 대시보드의 안정적 요소 확인.
    expect(find.text('오늘 공부 시간'), findsOneWidget);
    expect(find.text('오늘 해야 할 일'), findsOneWidget);
  });
}
