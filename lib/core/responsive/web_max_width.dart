import 'package:flutter/widgets.dart';

/// 콘텐츠 최대 폭(웹 가독성, P8 #6). 넓은 화면에서 좌우 여백으로 가운데 정렬한다.
///
/// 가로 패딩 방식이라 자식의 세로 제약(스크롤 가능 영역 등)을 보존한다 —
/// `Center`/`Align` 으로 감쌀 때 생기는 unbounded-height 오류가 없다.
/// 셸 밖 단독 화면(GNB로 진입하는 페이지)의 `body` 를 감싸 쓴다.
class WebMaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const WebMaxWidth({super.key, required this.child, this.maxWidth = 1160});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (!w.isFinite || w <= maxWidth) return child;
        final pad = (w - maxWidth) / 2;
        return Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: child);
      },
    );
  }
}
