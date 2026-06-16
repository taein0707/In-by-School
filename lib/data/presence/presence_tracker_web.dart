// P6/P7 웹 전용 추적기 — dart:html 은 조건부 임포트(dart.library.html)로
// 웹 빌드에서만 컴파일된다. 비-웹/테스트는 presence_tracker_io.dart 사용.
// 화면 캡처는 P7 ScreenBroadcaster 로 분리됨 — 여기선 참여 감지만 한다.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

import '../../domain/presence/presence_evaluator.dart';
import '../../domain/presence/student_presence.dart';
import 'presence_tracker.dart';

/// 웹 전용 추적기 — document.visibilityState / window blur·focus / 입력 이벤트로
/// 참여 상태(active/idle/away/offline)를 판정한다.
class _WebTracker implements PresenceTracker {
  void Function(StudentPresence)? _onChange;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _ticker;

  bool _documentHidden = false;
  bool _windowBlurred = false;
  DateTime? _hiddenSince;
  DateTime _lastInputAt = DateTime.now();
  StudentPresence _last = StudentPresence.active;

  bool get _visible => !_documentHidden && !_windowBlurred;

  @override
  void start(void Function(StudentPresence status) onChange) {
    _onChange = onChange;
    _documentHidden = html.document.visibilityState == 'hidden';
    _hiddenSince = _visible ? null : DateTime.now();
    _lastInputAt = DateTime.now();

    _subs.add(html.document.onVisibilityChange.listen((_) {
      _documentHidden = html.document.visibilityState == 'hidden';
      _onVisibilityShift();
    }));
    _subs.add(html.window.onBlur.listen((_) {
      _windowBlurred = true;
      _onVisibilityShift();
    }));
    _subs.add(html.window.onFocus.listen((_) {
      _windowBlurred = false;
      _onVisibilityShift();
    }));
    _subs.add(html.document.onMouseMove.listen((_) => _onInput()));
    _subs.add(html.document.onKeyDown.listen((_) => _onInput()));
    _subs.add(html.document.onMouseDown.listen((_) => _onInput()));
    _subs.add(html.window.onBeforeUnload.listen((_) {
      _emit(StudentPresence.offline);
    }));

    // 1초마다 무입력/비가시 경과를 재평가(타임아웃 전이를 잡는다).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
    _recompute();
  }

  void _onVisibilityShift() {
    _hiddenSince = _visible ? null : (_hiddenSince ?? DateTime.now());
    if (_visible) _lastInputAt = DateTime.now(); // 돌아오면 즉시 활성으로 보이게
    _recompute();
  }

  void _onInput() {
    _lastInputAt = DateTime.now();
    if (_visible && _last != StudentPresence.active) _recompute();
  }

  void _recompute() {
    final now = DateTime.now();
    final hiddenFor = _visible || _hiddenSince == null ? Duration.zero : now.difference(_hiddenSince!);
    final idleFor = now.difference(_lastInputAt);
    final next = evaluatePresence(
      sharing: false,
      visible: _visible,
      hiddenFor: hiddenFor,
      idleFor: idleFor,
    );
    if (next != _last) _emit(next);
  }

  void _emit(StudentPresence s) {
    _last = s;
    _onChange?.call(s);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _onChange = null;
  }
}

PresenceTracker createPresenceTracker() => _WebTracker();
