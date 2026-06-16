import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/ui.dart';

enum _Mode { countdown, stopwatch }

/// 교사용 타이머(P3-2) — 카운트다운 / 스톱워치 + 프리셋 + 전체화면.
class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  _Mode _mode = _Mode.countdown;
  int _initialSec = 5 * 60;
  int _remainingSec = 5 * 60;
  int _elapsedSec = 0;
  bool _running = false;
  bool _fullscreen = false;
  Timer? _timer;

  static const _presets = [3, 5, 10, 20]; // 분

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(int totalSec) {
    final s = totalSec.abs();
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  int get _displaySec => _mode == _Mode.countdown ? _remainingSec : _elapsedSec;

  void _tick(Timer t) {
    setState(() {
      if (_mode == _Mode.countdown) {
        if (_remainingSec > 0) _remainingSec--;
        if (_remainingSec <= 0) {
          _stop();
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.heavyImpact();
        }
      } else {
        _elapsedSec++;
      }
    });
  }

  void _start() {
    if (_running) return;
    if (_mode == _Mode.countdown && _remainingSec <= 0) _remainingSec = _initialSec;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    setState(() => _running = true);
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _stop() {
    _timer?.cancel();
    _running = false;
  }

  void _reset() {
    _stop();
    setState(() {
      if (_mode == _Mode.countdown) {
        _remainingSec = _initialSec;
      } else {
        _elapsedSec = 0;
      }
    });
  }

  void _setMode(_Mode m) {
    _stop();
    setState(() {
      _mode = m;
      _remainingSec = _initialSec;
      _elapsedSec = 0;
    });
  }

  void _setPreset(int minutes) {
    _stop();
    setState(() {
      _mode = _Mode.countdown;
      _initialSec = minutes * 60;
      _remainingSec = _initialSec;
    });
  }

  Future<void> _custom() async {
    final ctrl = TextEditingController(text: '${_initialSec ~/ 60}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return AlertDialog(
          backgroundColor: c.bgElevated,
          title: Text('시간 설정(분)', style: AppType.title3),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: AppType.body1.copyWith(color: c.labelNormal),
            decoration: const InputDecoration(hintText: '예: 15'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())), child: const Text('확인')),
          ],
        );
      },
    );
    if (v != null && v >= 1) _setPreset(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_fullscreen) return _fullscreenView(c);

    final isCustom = _mode == _Mode.countdown && !_presets.contains(_initialSec ~/ 60);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => Navigator.of(context).pop()),
        title: Text('타이머', style: AppType.headline1),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: '전체화면',
            onPressed: () => setState(() => _fullscreen = true),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s20),
          children: [
            _modeToggle(c),
            const SizedBox(height: AppSpace.s24),
            _timeDisplay(c, big: false),
            const SizedBox(height: AppSpace.s24),
            if (_mode == _Mode.countdown) ...[
              SectionLabel('프리셋'),
              const SizedBox(height: AppSpace.s4),
              Wrap(spacing: AppSpace.s8, runSpacing: AppSpace.s8, children: [
                for (final p in _presets) _presetChip(c, '$p분', _initialSec == p * 60 && !isCustom, () => _setPreset(p)),
                _presetChip(c, isCustom ? '${_initialSec ~/ 60}분' : '사용자 지정', isCustom, _custom),
              ]),
              const SizedBox(height: AppSpace.s24),
            ],
            _controls(c),
          ],
        ),
      ),
    );
  }

  Widget _modeToggle(AppColors c) => Row(children: [
        Expanded(child: _segBtn(c, '카운트다운', _mode == _Mode.countdown, () => _setMode(_Mode.countdown))),
        const SizedBox(width: AppSpace.s8),
        Expanded(child: _segBtn(c, '스톱워치', _mode == _Mode.stopwatch, () => _setMode(_Mode.stopwatch))),
      ]);

  Widget _segBtn(AppColors c, String label, bool on, VoidCallback onTap) => Material(
        color: on ? c.accent : c.bgElevated,
        borderRadius: AppRadius.b14,
        child: InkWell(
          borderRadius: AppRadius.b14,
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: AppRadius.b14, border: Border.all(color: on ? c.accent : c.lineAlt)),
            child: Text(label, style: AppType.label1.copyWith(color: on ? Colors.white : c.labelNeutral)),
          ),
        ),
      );

  Widget _presetChip(AppColors c, String label, bool on, VoidCallback onTap) => ActionChip(
        label: Text(label, style: AppType.label1.copyWith(color: on ? Colors.white : c.labelNeutral)),
        onPressed: onTap,
        backgroundColor: on ? c.accent : c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.b14, side: BorderSide(color: on ? c.accent : c.lineAlt)),
      );

  Widget _timeDisplay(AppColors c, {required bool big}) {
    final warn = _mode == _Mode.countdown && _remainingSec <= 10 && _remainingSec > 0;
    final done = _mode == _Mode.countdown && _remainingSec <= 0;
    final color = done ? c.negative : (warn ? c.cautionary : c.labelStrong);
    return Center(
      child: Text(
        _fmt(_displaySec),
        style: (big ? AppType.display3 : AppType.display3).copyWith(
          color: color,
          fontSize: big ? 120 : 72,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _controls(AppColors c) => Row(children: [
        Expanded(child: OclButton(_running ? '일시정지' : '시작', onPressed: _running ? _pause : _start)),
        const SizedBox(width: AppSpace.s8),
        Expanded(child: OclButton('초기화', ghost: true, onPressed: _reset)),
      ]);

  Widget _fullscreenView(AppColors c) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white70),
                onPressed: () => setState(() => _fullscreen = false),
              ),
            ),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  _fmt(_displaySec),
                  style: AppType.display3.copyWith(
                    color: (_mode == _Mode.countdown && _remainingSec <= 0)
                        ? c.negative
                        : (_mode == _Mode.countdown && _remainingSec <= 10 && _remainingSec > 0 ? c.cautionary : Colors.white),
                    fontSize: 140,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppSpace.s32),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _fsBtn(_running ? Icons.pause : Icons.play_arrow, _running ? _pause : _start),
                  const SizedBox(width: AppSpace.s24),
                  _fsBtn(Icons.refresh, _reset),
                ]),
              ]),
            ),
          ]),
        ),
      );

  Widget _fsBtn(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white10,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(AppSpace.s16), child: Icon(icon, color: Colors.white, size: 40)),
        ),
      );
}
