import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

enum AmsState { open, closed, error }

typedef AmsStateCallback = void Function(AmsState state);
typedef AmsStreamCallback = void Function(MediaStream stream);
typedef AmsCommandCallback = void Function(String command, Map<dynamic, dynamic> data);

/// Lightweight AMS WebRTC signalling client.
///
/// Replaces ant_media_flutter for Publish and Play modes.
/// Internally uses dart:io WebSocket + flutter_webrtc RTCPeerConnection.
class AmsRtcClient {
  AmsRtcClient({
    required this.websocketUrl,
    required this.streamId,
    required this.publish,
    required this.onStateChange,
    required this.onCommand,
    this.onRemoteStream,
    this.iceServers = const [],
  });

  final String websocketUrl;
  final String streamId;

  /// true = streamer (Publish), false = viewer (Play).
  final bool publish;

  final List<Map<String, String>> iceServers;
  final AmsStateCallback onStateChange;
  final AmsCommandCallback onCommand;
  final AmsStreamCallback? onRemoteStream;

  WebSocket? _ws;
  RTCPeerConnection? _pc;
  Timer? _pingTimer;
  bool _closed = false;
  MediaStream? _localStream;

  static const _encoder = JsonEncoder();
  static const _decoder = JsonDecoder();

  // SDP offer constraints — same for both modes; track presence drives directionality.
  static const _offerConstraints = <String, dynamic>{
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
  };
  static const _answerConstraints = <String, dynamic>{
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
  };

  /// Inject the local camera/mic stream before [connect] is called so the SDK
  /// uses it directly and does not open a second camera track.
  void setStream(MediaStream stream) => _localStream = stream;

  Future<void> connect() async {
    try {
      _ws = await WebSocket.connect(websocketUrl);
    } catch (_) {
      onStateChange(AmsState.error);
      return;
    }

    onStateChange(AmsState.open);

    _send(publish
        ? {'command': 'publish', 'streamId': streamId, 'video': true, 'audio': true}
        : {'command': 'play', 'streamId': streamId});

    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _send({'command': 'ping'});
    });

    _ws!.listen(
      (data) {
        if (data is String) _onMessage(data);
      },
      onDone: () {
        _pingTimer?.cancel();
        if (!_closed) onStateChange(AmsState.closed);
      },
      onError: (_) {
        _pingTimer?.cancel();
        if (!_closed) onStateChange(AmsState.error);
      },
    );
  }

  void _send(Map<String, dynamic> msg) {
    final ws = _ws;
    if (ws != null && ws.readyState == WebSocket.open) {
      ws.add(_encoder.convert(msg));
    }
  }

  void _onMessage(String raw) {
    final Map<String, dynamic> data;
    try {
      data = _decoder.convert(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final command = data['command'] as String? ?? '';
    _dispatch(command, data);
    onCommand(command, data);
  }

  Future<void> _dispatch(String command, Map<String, dynamic> data) async {
    switch (command) {
      case 'start':
        await _createPeerConnection();
        await _sendOffer();

      case 'takeConfiguration':
        final sdp = data['sdp'] as String?;
        final type = data['type'] as String?;
        if (sdp == null || type == null) return;
        // Strip 3GPP video-orientation extmap that some AMS versions include,
        // which confuses the browser WebRTC stack.
        final cleanSdp =
            sdp.replaceAll('a=extmap:13 urn:3gpp:video-orientation\r\n', '');
        await _pc?.setRemoteDescription(RTCSessionDescription(cleanSdp, type));
        if (type == 'offer') await _sendAnswer();

      case 'takeCandidate':
        final candidate = RTCIceCandidate(
          data['candidate'] as String?,
          data['id'] as String?,
          data['label'] as int?,
        );
        await _pc?.addCandidate(candidate);

      case 'error':
        final def = data['definition'] as String?;
        if (def != 'no_stream_exist') onStateChange(AmsState.error);
    }
  }

  Future<void> _createPeerConnection() async {
    final config = <String, dynamic>{
      'sdpSemantics': 'unified-plan',
      'iceServers': iceServers,
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };
    _pc = await createPeerConnection(config);

    if (publish) {
      final stream = _localStream;
      if (stream != null) {
        for (final track in stream.getTracks()) {
          await _pc!.addTrack(track, stream);
        }
      }
    }

    _pc!.onIceConnectionState = (RTCIceConnectionState state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _pc?.restartIce();
      }
    };

    _pc!.onIceCandidate = (c) {
      _send({
        'command': 'takeCandidate',
        'streamId': streamId,
        'label': c.sdpMLineIndex,
        'id': c.sdpMid,
        'candidate': c.candidate,
      });
    };

    _pc!.onTrack = (event) {
      if (!publish && event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams[0]);
      }
    };
  }

  Future<void> _sendOffer() async {
    final pc = _pc;
    if (pc == null) return;
    final offer = await pc.createOffer(_offerConstraints);
    final sdpVp8 = _preferVp8(offer.sdp ?? '');
    await pc.setLocalDescription(RTCSessionDescription(sdpVp8, offer.type));
    _send({
      'command': 'takeConfiguration',
      'streamId': streamId,
      'type': offer.type,
      'sdp': sdpVp8,
    });
  }

  Future<void> _sendAnswer() async {
    final pc = _pc;
    if (pc == null) return;
    final answer = await pc.createAnswer(_answerConstraints);
    // Enable stereo for Opus audio.
    final sdpStereo =
        (answer.sdp ?? '').replaceAll('useinbandfec=1', 'useinbandfec=1; stereo=1');
    await pc.setLocalDescription(RTCSessionDescription(sdpStereo, answer.type));
    _send({
      'command': 'takeConfiguration',
      'streamId': streamId,
      'type': answer.type,
      'sdp': sdpStereo,
    });
  }

  /// Reorders the m=video payload list so VP8 comes first.
  /// Unchanged if VP8 is not present in the SDP.
  String _preferVp8(String sdp) {
    final lines = sdp.split('\r\n');
    final vp8Payloads = <String>[];
    for (final line in lines) {
      final m = RegExp(r'^a=rtpmap:(\d+) VP8/90000').firstMatch(line);
      if (m != null) vp8Payloads.add(m.group(1)!);
    }
    if (vp8Payloads.isEmpty) return sdp;
    return lines.map((line) {
      if (!line.startsWith('m=video ')) return line;
      final parts = line.split(' ');
      if (parts.length <= 3) return line;
      final header = parts.sublist(0, 3);
      final payloads = parts.sublist(3);
      final reordered = [
        ...vp8Payloads,
        ...payloads.where((p) => !vp8Payloads.contains(p)),
      ];
      return [...header, ...reordered].join(' ');
    }).join('\r\n');
  }

  void close() {
    _closed = true;
    _pingTimer?.cancel();
    _pc?.close();
    _pc = null;
    _ws?.close();
    _ws = null;
  }
}
