import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/endpoints.dart';
import '../../core/webrtc/ams_rtc_client.dart';
import '../auth/application/auth_providers.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import 'data/live_chat_ws_client.dart';
import 'domain/live_chat_message.dart';
import 'domain/live_session.dart';
import 'widgets/gift_burst.dart';

enum _Phase { idle, preparing, ready, live, ending, ended }

class GoLivePage extends ConsumerStatefulWidget {
  const GoLivePage({super.key, this.skipAntMediaCheck = false});

  // When true, /start/ is called with ?skip_ant_media=true and the Ant Media
  // SDK is bypassed entirely — useful for local testing without a WebRTC setup.
  final bool skipAntMediaCheck;

  @override
  ConsumerState<GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends ConsumerState<GoLivePage> {
  _Phase _phase = _Phase.idle;
  LiveSession? _session;
  final List<LiveChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  bool _sendingMessage = false;
  String? _error;
  Timer? _statusTimer;
  Timer? _durationTimer;
  Timer? _chatFallbackTimer;
  int _durationSeconds = 0;
  int _lastChatId = 0;
  int _startRetries = 0;
  static const int _maxMessages = 200;
  bool _chatError = false;

  // WebSocket chat
  LiveChatWsClient? _chatWs;
  bool _chatWsConnected = false;

  // WebRTC
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  AmsRtcClient? _amsClient;
  bool _cameraReady = false;
  bool _isFrontCamera = true;
  bool _isMuted = false;
  bool _publishStarted = false;
  bool _freshRestartInProgress = false;
  // Incremented each time _initAndPublish() is called. Callbacks capture
  // the generation at registration time and bail out if it no longer matches,
  // preventing stale client instances from interfering with a newer session.
  int _antGeneration = 0;

  // Title
  final TextEditingController _titleController = TextEditingController();

  // Orientation
  bool _isLandscape = false;

  // Gift animation
  final List<PendingGift> _activeGifts = [];
  int _nextGiftId = 0;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _chatController.dispose();
    _titleController.dispose();
    _chatWs?.close();
    _stopPolling();
    _localRenderer.dispose();
    if (!widget.skipAntMediaCheck) {
      _amsClient?.close();
    }
    super.dispose();
  }

  void _toggleOrientation() {
    final bool next = !_isLandscape;
    setState(() => _isLandscape = next);
    if (next) {
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  // ── API calls ──────────────────────────────────────────────────────────────

  Future<void> _quickStart() async {
    setState(() {
      _phase = _Phase.preparing;
      _error = null;
    });
    try {
      final String title = _titleController.text.trim();
      final response = await ref.read(apiClientProvider).post<dynamic>(
        Endpoints.liveQuickStart,
        data: <String, dynamic>{
          if (title.isNotEmpty) 'title': title,
        },
        authenticated: true,
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic> && mounted) {
        // Guard: publish_config.ok must be true
        final dynamic pub = data['publish_config'];
        if (pub is Map<String, dynamic> && pub['ok'] != true) {
          final String msg = pub['message']?.toString() ??
              'Publish config unavailable. Please try again.';
          throw Exception(msg);
        }

        final LiveSession session = LiveSession.fromJson(data);

        if (session.id.isEmpty) {
          throw Exception('Missing live.id from quick-start response');
        }
        if (session.websocketUrl.isEmpty || session.streamId.isEmpty) {
          throw Exception('Missing Ant Media publish config');
        }

        setState(() {
          _session = session;
          _phase = _Phase.ready;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _phase = _Phase.idle;
        });
      }
    }
  }

  // Called by Go Live button. Branches on widget.skipAntMediaCheck.
  Future<void> _goLive() async {
    if (widget.skipAntMediaCheck) {
      await _startLive();
    } else {
      unawaited(_initAndPublish());
    }
  }

  // Acquire media with explicit constraints, show local preview immediately,
  // then connect to AMS and inject the stream so the client skips its own
  // getUserMedia call (tracks are added to PeerConnection only when _localStream != null).
  Future<void> _initAndPublish() async {
    final LiveSession? session = _session;
    if (session == null) return;
    setState(() {
      _phase = _Phase.preparing;
      _error = null;
    });

    _publishStarted = false;
    _freshRestartInProgress = false;
    final int gen = ++_antGeneration;

    // Close any previous client before creating a new one.
    _amsClient?.close();
    _amsClient = null;

    // Acquire stream with explicit 720p/30fps constraints before connecting.
    // This lets us verify colour correctness in the preview independently of
    // the AMS client, and prevents it from opening a second camera track.
    MediaStream stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': true,
        'video': <String, dynamic>{
          'width': <String, dynamic>{'ideal': 854, 'max': 1280},
          'height': <String, dynamic>{'ideal': 480, 'max': 720},
          'frameRate': <String, dynamic>{'ideal': 24, 'max': 30},
          'facingMode': 'user',
        },
      });
    } catch (e) {
      if (!mounted || gen != _antGeneration) return;
      setState(() {
        _error = 'Camera access failed. Check permissions and try again.';
        _phase = _Phase.ready;
      });
      return;
    }

    if (!mounted || gen != _antGeneration) {
      stream.dispose();
      return;
    }

    // Bind to renderer now — colour check happens here, before any WebRTC code.
    setState(() {
      _localStream = stream;
      _localRenderer.srcObject = stream;
      _cameraReady = true;
    });

    final client = AmsRtcClient(
      websocketUrl: session.websocketUrl,
      streamId: session.streamId,
      publish: true,
      onStateChange: (AmsState state) {
        if (!mounted || gen != _antGeneration) return;
        if (state == AmsState.error || state == AmsState.closed) {
          if (!_publishStarted &&
              _phase != _Phase.live &&
              _phase != _Phase.ending) {
            setState(() {
              _error = 'Stream connection failed. Please try again.';
              _phase = _Phase.ready;
              _cameraReady = false;
            });
          }
        }
      },
      onCommand: (String command, Map<dynamic, dynamic> mapData) {
        if (gen != _antGeneration) return;
        if (command == 'notification' &&
            mapData['definition'] == 'publish_started') {
          if (!_publishStarted) {
            _publishStarted = true;
            unawaited(_startLive());
          }
        } else if (command == 'error' &&
            mapData['definition'] == 'streamIdInUse') {
          if (_publishStarted) {
            _antGeneration++;
            _amsClient?.close();
            _amsClient = null;
          } else if (!_freshRestartInProgress) {
            unawaited(_freshRestart());
          }
        }
      },
    );

    // Inject stream before connect() — the PeerConnection is created only after
    // the WebSocket 'start' message arrives, so setStream() here guarantees the
    // tracks are available when addTrack() is called inside AmsRtcClient.
    client.setStream(stream);
    _amsClient = client;
    await client.connect();
  }

  Future<void> _switchCamera() async {
    final List<MediaStreamTrack> tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
    if (mounted) setState(() => _isFrontCamera = !_isFrontCamera);
  }

  // Called when streamIdInUse is received before publish_started.
  // Ends the stale client session and acquires a brand-new live session.
  Future<void> _freshRestart() async {
    if (_freshRestartInProgress) return;
    _freshRestartInProgress = true;
    _amsClient?.close();
    _amsClient = null;
    if (!mounted) {
      _freshRestartInProgress = false;
      return;
    }
    setState(() {
      _phase = _Phase.preparing;
      _cameraReady = false;
      _error = 'Previous stream detected — starting fresh session…';
    });
    try {
      final response = await ref.read(apiClientProvider).post<dynamic>(
        Endpoints.liveQuickStart,
        queryParameters: <String, dynamic>{'fresh': 'true'},
        data: <String, dynamic>{},
        authenticated: true,
      );
      final dynamic data = response.data;
      if (!mounted) return;
      if (data is Map<String, dynamic>) {
        final dynamic pub = data['publish_config'];
        if (pub is Map<String, dynamic> && pub['ok'] != true) {
          throw Exception(
              pub['message']?.toString() ?? 'Publish config unavailable.');
        }
        final LiveSession session = LiveSession.fromJson(data);
        if (session.id.isEmpty ||
            session.streamId.isEmpty ||
            session.websocketUrl.isEmpty) {
          throw Exception('Invalid fresh session response');
        }
        setState(() {
          _session = session;
          _phase = _Phase.ready;
          _error = null;
        });
        _freshRestartInProgress = false;
        unawaited(_initAndPublish());
      }
    } catch (e) {
      _freshRestartInProgress = false;
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _phase = _Phase.ready;
        });
      }
    }
  }

  // Called either directly (bypass) or from SDK publish_started callback.
  // POST /api/live/{id}/start/ is now idempotent — any 200 response is success.
  // Only 409 is a hard conflict. Other errors are retried up to maxStartRetry.
  Future<void> _startLive() async {
    final String? id = _session?.id;
    if (id == null || id.isEmpty) return;
    // Don't push phase to "preparing" if camera is already broadcasting —
    // that would hide the live camera preview from the user.
    if (!_publishStarted) {
      setState(() {
        _phase = _Phase.preparing;
        _error = null;
      });
    }
    try {
      await ref.read(apiClientProvider).post<dynamic>(
        Endpoints.liveStart(id),
        queryParameters: widget.skipAntMediaCheck
            ? <String, dynamic>{'skip_ant_media': 'true'}
            : null,
        authenticated: true,
      );
      if (!mounted) return;
      // Any 200 response (including already_started:true) → transition to live.
      _startRetries = 0;
      setState(() {
        _phase = _Phase.live;
        _durationSeconds = 0;
        _error = null;
      });
      _startPolling();
    } on DioException catch (e) {
      if (!mounted) return;
      final int statusCode = e.response?.statusCode ?? 0;
      final dynamic body = e.response?.data;
      if (statusCode == 409) {
        // Hard conflict (session mismatch, expired, ended, failed) — stop retrying.
        _startRetries = 0;
        final String msg = body is Map<String, dynamic>
            ? body['detail']?.toString() ?? 'Stream conflict. Please try again.'
            : 'Stream conflict. Please try again.';
        setState(() {
          _error = msg;
          _phase = _Phase.ready;
        });
      } else {
        _handleStartRetry();
      }
    } catch (_) {
      if (!mounted) return;
      _handleStartRetry();
    }
  }

  // Retry _startLive() up to session.maxStartRetry times (default 20).
  // Only used when a transient error occurs and _publishStarted may be true.
  void _handleStartRetry() {
    final int maxR = _session?.maxStartRetry ?? 20;
    _startRetries++;
    if (_startRetries <= maxR) {
      setState(() => _error = 'Connecting to server... ($_startRetries/$maxR)');
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted) unawaited(_startLive());
      });
    } else {
      _startRetries = 0;
      setState(() {
        _error = 'Server not responding. Try ending and restarting.';
        _phase = _Phase.ready;
      });
    }
  }

  Future<void> _endLive() async {
    final String? id = _session?.id;
    if (id == null) return;
    _stopPolling();
    if (!widget.skipAntMediaCheck) {
      _amsClient?.close();
      _amsClient = null;
    }
    setState(() {
      _phase = _Phase.ending;
      _cameraReady = false;
      _localStream = null;
    });
    try {
      await ref.read(apiClientProvider).post<dynamic>(
        Endpoints.liveEnd(id),
        authenticated: true,
      );
    } on DioException catch (e) {
      // 4xx means the session is already ended/closed server-side — proceed.
      // 5xx or network errors: surface to user so they can retry.
      final int statusCode = e.response?.statusCode ?? 0;
      if (statusCode == 0 || statusCode >= 500) {
        if (mounted) {
          setState(() {
            _phase = _Phase.live;
            _error = 'Failed to end stream. Please try again.';
          });
          _startPolling();
        }
        return;
      }
    } catch (_) {
      // Unexpected error — treat as non-fatal and proceed to ended state.
    }
    // One-shot status refresh to pick up the latest thumbnail_url.
    if (mounted) await _pollStatus();
    if (mounted) setState(() => _phase = _Phase.ended);
  }

  // ── Polling + WebSocket ────────────────────────────────────────────────────

  void _startPolling() {
    _statusTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _pollStatus());
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
    // Chat fallback: poll every 5 s when WS is not connected.
    _chatFallbackTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_chatWsConnected) _pollChat();
    });
    _pollStatus();
    // Fetch initial chat history via REST, then hand off to WebSocket.
    _pollChat().then((_) => _connectChatWs());
  }

  void _stopPolling() {
    _statusTimer?.cancel();
    _durationTimer?.cancel();
    _chatFallbackTimer?.cancel();
    _chatWs?.close();
    _chatWs = null;
  }

  Future<void> _connectChatWs() async {
    final String? id = _session?.id;
    if (id == null || !mounted) return;
    final String? token = await TokenStorage().readAccessToken();
    if (token == null || token.isEmpty || !mounted) return;

    _chatWs?.close();
    _chatWs = LiveChatWsClient(
      baseUrl: ApiClient.defaultBaseUrl,
      liveId: id,
      token: token,
      onMessage: _handleChatWsEvent,
      onStateChange: (LiveChatWsState state) {
        if (!mounted) return;
        final bool connected = state == LiveChatWsState.connected;
        setState(() {
          _chatWsConnected = connected;
          _chatError = state == LiveChatWsState.disconnected;
        });
        // After reconnect, compensate any missed messages via REST.
        if (connected && _lastChatId > 0) _pollChat();
      },
    );
    _chatWs!.connect();
  }

  void _handleChatWsEvent(Map<String, dynamic> frame) {
    if (!mounted) return;
    final String type = frame['type']?.toString() ?? '';
    final dynamic msgData = frame['message'];
    if (msgData is! Map<String, dynamic>) return;

    if (type == 'message_created') {
      final LiveChatMessage msg = LiveChatMessage.fromJson(msgData);
      // Deduplicate — REST compensation may have already added this id.
      if (_messages.any((m) => m.id == msg.id)) return;
      setState(() {
        _messages.add(msg);
        if (_messages.length > _maxMessages) {
          _messages.removeRange(0, _messages.length - _maxMessages);
        }
        if (msg.id > _lastChatId) _lastChatId = msg.id;
        _chatError = false;
      });
      if (msg.isGift) _triggerGiftBurst(msg);

    } else if (type == 'message_updated') {
      final int updatedId = (msgData['id'] as num?)?.toInt() ?? 0;
      final int idx = _messages.indexWhere((m) => m.id == updatedId);
      if (idx >= 0) {
        setState(() {
          _messages[idx] = LiveChatMessage.fromJson(msgData);
        });
      }

    } else if (type == 'message_deleted') {
      final int deletedId = (msgData['id'] as num?)?.toInt() ?? 0;
      setState(() => _messages.removeWhere((m) => m.id == deletedId));
    }
  }

  Future<void> _pollStatus() async {
    final String? id = _session?.id;
    if (id == null) return;
    try {
      final response = await ref.read(apiClientProvider).get<dynamic>(
        Endpoints.liveStatus(id),
        authenticated: true,
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic> && mounted) {
        // Status response is flat — merge into existing session to preserve
        // stream_id / websocket_url from quick-start.
        final LiveSession current = _session!;
        final LiveSession updated = current.copyWith(
          effectiveStatus: data['effective_status']?.toString(),
          status: data['status']?.toString(),
          viewerCount: (data['viewer_count'] as num?)?.toInt(),
          canStart: data['can_start'] as bool?,
          canEnd: data['can_end'] as bool?,
          thumbnailUrl: data['thumbnail_url'] as String?,
          previewImageUrl: data['preview_image_url'] as String?,
          snapshotUrl: data['snapshot_url'] as String?,
          thumbnailCaptureStatus:
              data['thumbnail_capture_status'] as String?,
          thumbnailCapturedAt: data['thumbnail_captured_at'] as String?,
        );
        setState(() {
          _session = updated;
          if (updated.isEnded && _phase == _Phase.live) {
            // Server ended the stream (timeout / admin action).
            _phase = _Phase.ended;
            _stopPolling();
          } else if (updated.isFailed &&
              (_phase == _Phase.live || _phase == _Phase.preparing)) {
            // Server-side failure — surface error and let user retry / fresh-restart.
            _phase = _Phase.ready;
            _error = 'Stream failed. You can try again or start a fresh session.';
            _stopPolling();
            if (!widget.skipAntMediaCheck) {
              _amsClient?.close();
              _amsClient = null;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pollChat() async {
    final String? id = _session?.id;
    if (id == null) return;
    try {
      final Map<String, dynamic>? query =
          _lastChatId > 0 ? <String, dynamic>{'after_id': _lastChatId} : null;
      final response = await ref.read(apiClientProvider).get<dynamic>(
        Endpoints.liveChatMessages(id),
        queryParameters: query,
        authenticated: true,
      );
      final dynamic data = response.data;
      if (!mounted) return;
      List<dynamic> results = <dynamic>[];
      if (data is Map<String, dynamic>) {
        results = data['results'] as List<dynamic>? ?? <dynamic>[];
      } else if (data is List<dynamic>) {
        results = data;
      }
      if (results.isNotEmpty) {
        final List<LiveChatMessage> newMessages = results
            .whereType<Map<String, dynamic>>()
            .map(LiveChatMessage.fromJson)
            .toList();
        setState(() {
          _chatError = false;
          _messages.addAll(newMessages);
          if (_messages.length > _maxMessages) {
            _messages.removeRange(0, _messages.length - _maxMessages);
          }
          _lastChatId = newMessages.last.id;
        });
        for (final msg in newMessages) {
          if (msg.isGift && mounted) _triggerGiftBurst(msg);
        }
      } else if (mounted) {
        setState(() => _chatError = false);
      }
    } catch (_) {
      if (mounted) setState(() => _chatError = true);
    }
  }

  void _toggleMute() {
    final tracks = _localStream?.getAudioTracks() ?? <MediaStreamTrack>[];
    final next = !_isMuted;
    for (final t in tracks) {
      t.enabled = !next;
    }
    setState(() => _isMuted = next);
  }

  void _triggerGiftBurst(LiveChatMessage msg) {
    final emoji = giftEmojiFromPayload(msg.payload);
    setState(() {
      _activeGifts.add(PendingGift(
        id: _nextGiftId++,
        emoji: emoji,
        senderName: msg.senderName,
        label: msg.message,
        iconUrl: _resolveGiftUrl(msg.payload['icon_url']?.toString()),
        animationUrl: _resolveGiftUrl(msg.payload['animation_url']?.toString()),
        animationType: msg.payload['animation_type']?.toString(),
      ));
    });
  }

  static String? _resolveGiftUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = ApiClient.defaultBaseUrl.endsWith('/')
        ? ApiClient.defaultBaseUrl.substring(0, ApiClient.defaultBaseUrl.length - 1)
        : ApiClient.defaultBaseUrl;
    return '$base${raw.startsWith('/') ? raw : '/$raw'}';
  }

  Future<void> _sendMessage() async {
    final String text = _chatController.text.trim();
    if (text.isEmpty || _sendingMessage) return;
    final String? id = _session?.id;
    if (id == null) return;
    setState(() => _sendingMessage = true);
    _chatController.clear();

    // Prefer WebSocket; fall back to REST when WS is not connected.
    final bool sentViaWs = _chatWsConnected && (_chatWs?.sendText(text) ?? false);
    if (!sentViaWs) {
      try {
        await ref.read(apiClientProvider).post<dynamic>(
          Endpoints.liveChatMessages(id),
          data: <String, dynamic>{'message_type': 'text', 'content': text},
          authenticated: true,
        );
        await _pollChat();
      } catch (_) {
        if (mounted) _chatController.text = text;
      }
    }

    if (mounted) setState(() => _sendingMessage = false);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDuration(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String displayName = ref.watch(authControllerProvider).session?.displayName ?? '';
    final Widget page = switch (_phase) {
      _Phase.ended => _EndedView(
          session: _session,
          durationSeconds: _durationSeconds,
          onClose: () => Navigator.of(context).maybePop(),
        ),
      _Phase.live || _Phase.ending => _LiveView(
          session: _session,
          messages: _messages,
          chatController: _chatController,
          sendingMessage: _sendingMessage,
          sendingGift: false,
          chatError: _chatError,
          durationSeconds: _durationSeconds,
          ending: _phase == _Phase.ending,
          localRenderer: _cameraReady ? _localRenderer : null,
          isFrontCamera: _isFrontCamera,
          canSwitchCamera: _localStream != null,
          isMuted: _isMuted,
          isLandscape: _isLandscape,
          displayName: displayName,
          onSend: _sendMessage,
          onEnd: _endLive,
          onSwitchCamera: _switchCamera,
          onToggleMute: _toggleMute,
          onToggleOrientation: _toggleOrientation,
          formatDuration: _formatDuration,
        ),
      _ => _PrepareView(
          phase: _phase,
          error: _error,
          session: _session,
          localRenderer: _cameraReady ? _localRenderer : null,
          publishStarted: _publishStarted,
          isFrontCamera: _isFrontCamera,
          canSwitchCamera: _localStream != null,
          isMuted: _isMuted,
          isLandscape: _isLandscape,
          displayName: displayName,
          titleController: _titleController,
          onStart: _phase == _Phase.idle ? _quickStart : _goLive,
          onEnd: _endLive,
          onSwitchCamera: _switchCamera,
          onToggleMute: _toggleMute,
          onToggleOrientation: _toggleOrientation,
          onBack: () => Navigator.of(context).maybePop(),
        ),
    };

    // Gift burst overlay — rendered above everything.
    if (_activeGifts.isEmpty) return page;
    return Stack(
      children: [
        page,
        Positioned(
          right: 16,
          bottom: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _activeGifts.map((g) => GiftBurst(
              key: ValueKey(g.id),
              emoji: g.emoji,
              senderName: g.senderName,
              label: g.label,
              iconUrl: g.iconUrl,
              animationUrl: g.animationUrl,
              animationType: g.animationType,
              onDone: () {
                if (mounted) setState(() => _activeGifts.removeWhere((x) => x.id == g.id));
              },
            )).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Prepare / Idle / Ready ────────────────────────────────────────────────────

class _PrepareView extends StatelessWidget {
  const _PrepareView({
    required this.phase,
    required this.error,
    required this.session,
    required this.onStart,
    required this.onEnd,
    required this.onBack,
    required this.onSwitchCamera,
    required this.onToggleMute,
    required this.onToggleOrientation,
    required this.publishStarted,
    required this.isFrontCamera,
    required this.canSwitchCamera,
    required this.isMuted,
    required this.isLandscape,
    required this.displayName,
    required this.titleController,
    this.localRenderer,
  });

  final _Phase phase;
  final String? error;
  final LiveSession? session;
  final bool publishStarted;
  final bool isFrontCamera;
  final bool canSwitchCamera;
  final bool isMuted;
  final bool isLandscape;
  final String displayName;
  final TextEditingController titleController;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onBack;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleOrientation;
  final RTCVideoRenderer? localRenderer;

  @override
  Widget build(BuildContext context) {
    final bool loading = phase == _Phase.preparing;
    final LiveSession? s = session;
    final bool broadcasting = publishStarted && localRenderer != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Camera preview or placeholder
          localRenderer != null
              ? RTCVideoView(
                  localRenderer!,
                  mirror: isFrontCamera,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFF0D0D0D), Color(0xFF1C1C14)],
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.videocam_outlined, color: Color(0xFF333333), size: 80),
                        SizedBox(height: 12),
                        Text('Camera Preview', style: TextStyle(color: Color(0xFF444444), fontSize: 14)),
                      ],
                    ),
                  ),
                ),

          // Gradient overlay (only when broadcasting, so text is readable)
          if (broadcasting)
            Positioned(
              bottom: 0, left: 0, right: 0, height: 200,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[Color(0xE0000000), Colors.transparent],
                  ),
                ),
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  if (!broadcasting)
                    _CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
                  if (broadcasting) ...<Widget>[
                    _StreamerChip(displayName: displayName),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '● BROADCASTING',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (canSwitchCamera) ...<Widget>[
                    _CircleButton(icon: Icons.flip_camera_ios_rounded, onTap: onSwitchCamera),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  if (canSwitchCamera) ...<Widget>[
                    _CircleButton(
                      icon: isMuted ? Icons.mic_off : Icons.mic,
                      onTap: onToggleMute,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  _CircleButton(
                    icon: isLandscape
                        ? Icons.stay_current_portrait_rounded
                        : Icons.stay_current_landscape_rounded,
                    onTap: onToggleOrientation,
                  ),
                ],
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: broadcasting
                    ? _BroadcastingPanel(error: error, onEnd: onEnd)
                    : _PreparePanel(
                        phase: phase,
                        error: error,
                        session: s,
                        loading: loading,
                        onStart: onStart,
                        titleController: titleController,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Shown when camera is live on Ant Media but /start/ hasn't confirmed yet
class _BroadcastingPanel extends StatelessWidget {
  const _BroadcastingPanel({required this.error, required this.onEnd});
  final String? error;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: <Widget>[
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandGold),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  error ?? 'Connecting to server...',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton(
          onPressed: onEnd,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          child: const Text('End Stream', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// Shown in idle / ready states (before camera is live)
class _PreparePanel extends StatelessWidget {
  const _PreparePanel({
    required this.phase,
    required this.error,
    required this.session,
    required this.loading,
    required this.onStart,
    required this.titleController,
  });
  final _Phase phase;
  final String? error;
  final LiveSession? session;
  final bool loading;
  final VoidCallback onStart;
  final TextEditingController titleController;

  @override
  Widget build(BuildContext context) {
    final LiveSession? s = session;
    final bool hasSession = s != null;
    final bool isIdle = phase == _Phase.idle;
    // In the ready phase, respect server's can_start flag.
    // Default true for idle (no session yet) and when the field is absent.
    final bool canGoLive = isIdle || (s?.canStart ?? true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Title input — only shown before the session is prepared
        if (isIdle) ...<Widget>[
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: Colors.white24),
            ),
            child: TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: 'Live title (optional)',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (hasSession) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.softBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SESSION READY',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.brandGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                _InfoRow(label: 'Live ID', value: s.id),
                if (s.title.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  _InfoRow(label: 'Title', value: s.title),
                ],
                if (s.effectiveStatus.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  _InfoRow(label: 'Status', value: s.effectiveStatus),
                ],
                if (s.streamId.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  _InfoRow(
                    label: 'Stream ID',
                    value: '${s.streamId.substring(0, s.streamId.length.clamp(0, 12))}••••',
                  ),
                ],
                if (s.websocketUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  _InfoRow(
                    label: 'WebSocket',
                    value: s.websocketUrl.replaceFirst('wss://', '').split('/').first,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Publish config received — tap Go Live',
                      style: AppTextStyles.caption.copyWith(color: Colors.greenAccent, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (error != null) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.redAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ElevatedButton(
          onPressed: (loading || !canGoLive) ? null : onStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGold,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  phase == _Phase.idle ? 'Prepare Live' : 'Go Live',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}

// ── Live view ─────────────────────────────────────────────────────────────────

class _LiveView extends StatefulWidget {
  const _LiveView({
    required this.session,
    required this.messages,
    required this.chatController,
    required this.sendingMessage,
    required this.sendingGift,
    required this.chatError,
    required this.durationSeconds,
    required this.ending,
    required this.isFrontCamera,
    required this.canSwitchCamera,
    required this.isMuted,
    required this.isLandscape,
    required this.displayName,
    required this.onSend,
    required this.onEnd,
    required this.onSwitchCamera,
    required this.onToggleMute,
    required this.onToggleOrientation,
    required this.formatDuration,
    this.localRenderer,
  });

  final LiveSession? session;
  final List<LiveChatMessage> messages;
  final TextEditingController chatController;
  final bool sendingMessage;
  // Kept for future use (e.g. moderator sending gifts); not shown in streamer UI.
  final bool sendingGift;
  final bool chatError;
  final RTCVideoRenderer? localRenderer;
  final bool isFrontCamera;
  final bool canSwitchCamera;
  final bool isMuted;
  final bool isLandscape;
  final String displayName;
  final int durationSeconds;
  final bool ending;
  final VoidCallback onSend;
  final VoidCallback onEnd;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleOrientation;
  final String Function(int) formatDuration;

  @override
  State<_LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<_LiveView> {
  final ScrollController _scrollController = ScrollController();
  bool _showEndConfirm = false;

  /// Chat and gifts are disabled once the session is ended or failed.
  bool get _isLiveActive =>
      !widget.ending &&
      widget.session?.effectiveStatus != 'ended' &&
      widget.session?.effectiveStatus != 'failed';


  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_LiveView old) {
    super.didUpdateWidget(old);
    if (widget.messages.length != old.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Camera placeholder
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF0D0D0D), Color(0xFF1C1C14)],
              ),
            ),
            child: widget.localRenderer != null
                ? RTCVideoView(
                    widget.localRenderer!,
                    mirror: widget.isFrontCamera,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : null,
          ),

          // Top gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 320,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[Color(0xF0000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // UI content
          SafeArea(
            child: Column(
              children: <Widget>[
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      // Streamer identity chip
                      _StreamerChip(displayName: widget.displayName),
                      const SizedBox(width: AppSpacing.sm),
                      // Live badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '● LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Timer
                      Text(
                        widget.formatDuration(widget.durationSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      // Viewer count
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.session?.viewerCount ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Flip camera
                      if (widget.canSwitchCamera) ...<Widget>[
                        _CircleButton(
                          icon: Icons.flip_camera_ios_rounded,
                          onTap: widget.onSwitchCamera,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      // Mute
                      _CircleButton(
                        icon: widget.isMuted ? Icons.mic_off : Icons.mic,
                        onTap: widget.onToggleMute,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      // Orientation toggle
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _CircleButton(
                          icon: widget.isLandscape
                              ? Icons.stay_current_portrait_rounded
                              : Icons.stay_current_landscape_rounded,
                          onTap: widget.onToggleOrientation,
                        ),
                      ),
                      // End button — gated by server can_end
                      GestureDetector(
                        onTap: (widget.session?.canEnd ?? true)
                            ? () => setState(() => _showEndConfirm = true)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.session?.canEnd ?? true)
                                ? Colors.redAccent.withAlpha(200)
                                : Colors.grey.withAlpha(80),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: const Text(
                            'End',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat messages (grows from bottom)
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        shrinkWrap: true,
                        itemCount: widget.messages.length,
                        itemBuilder: (BuildContext context, int index) {
                          final LiveChatMessage msg = widget.messages[index];

                          // System message — centred hint text
                          if (msg.isSystem) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                msg.message,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          // Gift message — gold-tinted bubble with gift icon
                          if (msg.isGift) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandGold.withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    children: <InlineSpan>[
                                      const TextSpan(
                                        text: '🎁 ',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      TextSpan(
                                        text: msg.senderName,
                                        style: const TextStyle(
                                          color: AppColors.brandGold,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '  ${msg.message}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          // Default chat message
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: RichText(
                              text: TextSpan(
                                children: <TextSpan>[
                                  TextSpan(
                                    text: '${msg.senderName}  ',
                                    style: const TextStyle(
                                      color: AppColors.brandGold,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: msg.message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Chat error hint
                if (widget.chatError)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 2),
                    child: Row(
                      children: const <Widget>[
                        Icon(Icons.wifi_off, color: Colors.white38, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Chat connection lost',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                // Chat input
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      // Text field
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(
                                _isLiveActive ? 25 : 12),
                            borderRadius: BorderRadius.circular(21),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: TextField(
                            controller: widget.chatController,
                            enabled: _isLiveActive,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: _isLiveActive
                                  ? 'Say something...'
                                  : 'Live ended',
                              hintStyle: const TextStyle(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: _isLiveActive
                                ? (_) => widget.onSend()
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Send button
                      GestureDetector(
                        onTap: (_isLiveActive && !widget.sendingMessage)
                            ? widget.onSend
                            : null,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _isLiveActive
                                ? AppColors.brandGold
                                : Colors.grey.withAlpha(80),
                            shape: BoxShape.circle,
                          ),
                          child: widget.sendingMessage
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.black,
                                  size: 18,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // End confirmation / ending overlay
          if (_showEndConfirm || widget.ending)
            _EndOverlay(
              ending: widget.ending,
              onConfirm: widget.onEnd,
              onCancel: () => setState(() => _showEndConfirm = false),
            ),
        ],
      ),
    );
  }
}

// ── End confirmation overlay ──────────────────────────────────────────────────

class _EndOverlay extends StatelessWidget {
  const _EndOverlay({
    required this.ending,
    required this.onConfirm,
    required this.onCancel,
  });

  final bool ending;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.softBorder),
          ),
          child: ending
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircularProgressIndicator(color: AppColors.brandGold),
                    SizedBox(height: AppSpacing.md),
                    Text('Ending live...', style: AppTextStyles.body),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text('End Live?', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your live stream will end for all viewers.',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.mutedOliveText),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      child: const Text('End Live'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Ended summary ─────────────────────────────────────────────────────────────

class _EndedView extends StatelessWidget {
  const _EndedView({
    required this.session,
    required this.durationSeconds,
    required this.onClose,
  });

  final LiveSession? session;
  final int durationSeconds;
  final VoidCallback onClose;

  String _formatDuration(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    if (h > 0) return '$h hr ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final String? cover = session?.coverUrl;

    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),

              // ── Thumbnail / cover ──────────────────────────────────────
              if (cover != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _LiveEndedPlaceholder(),
                    ),
                  ),
                )
              else
                const _LiveEndedPlaceholder(),

              const SizedBox(height: AppSpacing.md),

              const Text(
                'Live Ended',
                style: AppTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SummaryRow(
                label: 'Duration',
                value: _formatDuration(durationSeconds),
              ),
              _SummaryRow(
                label: 'Viewers',
                value: '${session?.viewerCount ?? 0}',
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGold,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: const Text(
                  'Done',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveEndedPlaceholder extends StatelessWidget {
  const _LiveEndedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.softBorder),
        ),
        child: const Icon(
          Icons.live_tv_rounded,
          color: AppColors.brandGold,
          size: 56,
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

/// Avatar initial + display name chip shown in both the broadcasting and live bars.
class _StreamerChip extends StatelessWidget {
  const _StreamerChip({required this.displayName});
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final String initial = displayName.isNotEmpty
        ? displayName.trimLeft()[0].toUpperCase()
        : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.brandGold,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (displayName.isNotEmpty) ...<Widget>[
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          '$label: ',
          style: AppTextStyles.caption
              .copyWith(color: AppColors.mutedOliveText),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.caption.copyWith(color: AppColors.cocoaText),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.softBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: AppTextStyles.body),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: AppColors.brandGold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

