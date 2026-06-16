import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../data/firebase/webrtc_repository.dart';

/// 웹 전용 — answerer 로서 학생 offer 를 받아 answer 를 만들고 원격 스트림을 렌더링.
Widget studentScreenView({
  required String sessionId,
  required String teacherUid,
  required String studentUid,
}) =>
    _StudentScreenView(sessionId: sessionId, teacherUid: teacherUid, studentUid: studentUid);

class _StudentScreenView extends StatefulWidget {
  final String sessionId;
  final String teacherUid;
  final String studentUid;
  const _StudentScreenView({required this.sessionId, required this.teacherUid, required this.studentUid});

  @override
  State<_StudentScreenView> createState() => _StudentScreenViewState();
}

class _StudentScreenViewState extends State<_StudentScreenView> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  final WebrtcRepository _repo = WebrtcRepository();
  final List<StreamSubscription<dynamic>> _subs = [];
  RTCPeerConnection? _pc;
  bool _ready = false;

  static const Map<String, dynamic> _config = {
    'iceServers': [
      {
        'urls': ['stun:stun.l.google.com:19302']
      }
    ]
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _renderer.initialize();
    final pc = await createPeerConnection(_config);
    _pc = pc;

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _renderer.srcObject = event.streams.first;
        if (mounted) setState(() => _ready = true);
      }
    };
    pc.onIceCandidate = (RTCIceCandidate cand) {
      _repo.addIce(
        sessionId: widget.sessionId,
        role: 'teacher',
        teacherUid: widget.teacherUid,
        studentUid: widget.studentUid,
        candidate: cand.candidate,
        sdpMid: cand.sdpMid,
        sdpMLineIndex: cand.sdpMLineIndex,
      );
    };

    var offered = false;
    _subs.add(_repo.watchSession(widget.sessionId).listen((data) async {
      if (data == null) return;
      final offer = data['offer'];
      if (!offered && offer is Map) {
        offered = true;
        await pc.setRemoteDescription(
          RTCSessionDescription(offer['sdp'] as String?, offer['type'] as String?),
        );
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await _repo.setAnswer(widget.sessionId, answer.sdp, answer.type);
      }
    }));

    _subs.add(_repo.watchIce(sessionId: widget.sessionId, role: 'student').listen((list) async {
      for (final m in list) {
        await pc.addCandidate(RTCIceCandidate(
          m['candidate'] as String?,
          m['sdpMid'] as String?,
          (m['sdpMLineIndex'] as num?)?.toInt(),
        ));
      }
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _pc?.close();
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: _ready
              ? RTCVideoView(_renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)
              : const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  ),
                ),
        ),
      ),
    );
  }
}
