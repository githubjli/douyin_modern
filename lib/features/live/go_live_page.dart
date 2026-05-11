import 'dart:async';

import 'package:ant_media_flutter/ant_media_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import 'domain/live_chat_message.dart';
import 'domain/live_session.dart';

enum _Phase { idle, preparing, ready, live, ending, ended }

// true  → use ?skip_ant_media=true on /start/ (no real WebRTC needed)
// false → use Ant Media SDK; onPublishStarted triggers /start/
const bool _kSkipAntMediaCheck = false;

class GoLivePage extends StatefulWidget {
  const GoLivePage({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends State<GoLivePage> {
  _Phase _phase = _Phase.idle;
  LiveSession? _session;
  final List<LiveChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  bool _sendingMessage = false;
  String? _error;
  Timer? _statusTimer;
  Timer? _chatTimer;
  Timer? _durationTimer;
  int _durationSeconds = 0;
  int _lastChatId = 0;
  int _startRetries = 0;
  static const int _maxStartRetries = 5;

  // Ant Media / WebRTC
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _cameraReady = false;
  bool _publishStarted = false;
  bool _freshRestartInProgress = false;
  // Incremented each time _initAndPublish() is called. Callbacks capture
  // the generation at registration time and bail out if it no longer matches,
  // preventing stale AntHelper instances (the SDK keeps a reconnect loop even
  // after close()) from interfering with a newer session.
  int _antGeneration = 0;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _stopPolling();
    _localRenderer.dispose();
    if (!_kSkipAntMediaCheck) {
      AntMediaFlutter.anthelper?.close();
    }
    super.dispose();
  }

  // ── API calls ──────────────────────────────────────────────────────────────

  Future<void> _quickStart() async {
    setState(() {
      _phase = _Phase.preparing;
      _error = null;
    });
    try {
      final response = await widget.apiClient.post<dynamic>(
        Endpoints.liveQuickStart,
        data: <String, dynamic>{},
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

  // Called by Go Live button. Branches on _kSkipAntMediaCheck.
  Future<void> _goLive() async {
    if (_kSkipAntMediaCheck) {
      await _startLive();
    } else {
      _initAndPublish();
    }
  }

  // Initialise Ant Media SDK and start publishing.
  // /start/ is called once the SDK fires the publish_started notification.
  void _initAndPublish() {
    final LiveSession? session = _session;
    if (session == null) return;
    setState(() {
      _phase = _Phase.preparing;
      _error = null;
    });

    _publishStarted = false;
    _freshRestartInProgress = false;
    final int gen = ++_antGeneration; // this session's generation token

    AntMediaFlutter.requestPermissions();

    // connect(ip, streamId, roomId, token, type, userScreen,
    //         onStateChange, onLocalStream, onAddRemoteStream,
    //         onDataChannel, onDataChannelMessage,
    //         onupdateConferencePerson, onRemoveRemoteStream,
    //         iceServers, callbacks)
    AntMediaFlutter.connect(
      session.websocketUrl,  // ip / websocket URL
      session.streamId,      // streamId (= stream_key)
      '',                    // roomId
      '',                    // token
      AntMediaType.Publish,
      false,                 // userScreen — false = camera
      (HelperState state) {
        if (!mounted || gen != _antGeneration) return;
        switch (state) {
          case HelperState.ConnectionError:
          case HelperState.ConnectionClosed:
            // Only treat as failure if publishing never started
            if (!_publishStarted &&
                _phase != _Phase.live &&
                _phase != _Phase.ending) {
              setState(() {
                _error = 'Stream connection failed. Please try again.';
                _phase = _Phase.ready;
                _cameraReady = false;
              });
            }
          default:
            break;
        }
      },
      (MediaStream stream) {
        if (!mounted || gen != _antGeneration) return;
        setState(() {
          _localRenderer.srcObject = stream;
          _cameraReady = true;
        });
      },
      (MediaStream stream) {},
      (RTCDataChannel channel) {},
      (RTCDataChannel dc, RTCDataChannelMessage data, bool isReceived) {},
      (dynamic streams) {},
      (MediaStream stream) {},
      <Map<String, String>>[],
      (String command, Map<dynamic, dynamic> mapData) {
        if (gen != _antGeneration) return; // stale helper — ignore
        if (command == 'notification' &&
            mapData['definition'] == 'publish_started') {
          // Stream is live on Ant Media — notify backend once
          if (!_publishStarted) {
            _publishStarted = true;
            unawaited(_startLive());
          }
        } else if (command == 'error' &&
            mapData['definition'] == 'streamIdInUse') {
          if (_publishStarted) {
            // SDK reconnected after a successful publish — stream already live.
            // Increment generation so any further callbacks from this helper
            // are ignored, then close it to stop the reconnect loop.
            _antGeneration++;
            AntMediaFlutter.anthelper?.close();
          } else if (!_freshRestartInProgress) {
            // Previous session still occupying this streamId on Ant Media.
            // End the old session server-side and get a fresh one.
            unawaited(_freshRestart());
          }
        }
      },
    );
  }

  // Called when streamIdInUse is received before publish_started.
  // Ends the stale Ant Media session and acquires a brand-new live session.
  Future<void> _freshRestart() async {
    _freshRestartInProgress = true;
    AntMediaFlutter.anthelper?.close();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.preparing;
      _cameraReady = false;
      _error = 'Previous stream detected — starting fresh session…';
    });
    try {
      final response = await widget.apiClient.post<dynamic>(
        '${Endpoints.liveQuickStart}?fresh=true',
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
        _initAndPublish();
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
  Future<void> _startLive() async {
    final String? id = _session?.id;
    if (id == null || id.isEmpty) return;
    setState(() {
      _phase = _Phase.preparing;
      _error = null;
    });
    try {
      final String startUrl = _kSkipAntMediaCheck
          ? '${Endpoints.liveStart(id)}?skip_ant_media=true'
          : Endpoints.liveStart(id);
      final response = await widget.apiClient.post<dynamic>(
        startUrl,
        authenticated: true,
      );
      if (!mounted) return;
      final dynamic data = response.data;

      // Backend may respond with "waiting_for_signal" if Ant Media hasn't
      // received the stream yet. Retry up to _maxStartRetries times.
      if (data is Map<String, dynamic> &&
          data['next_action'] == 'retry_status') {
        if (_startRetries < _maxStartRetries) {
          _startRetries++;
          setState(() {
            _error =
                'Waiting for stream signal... (retry $_startRetries/$_maxStartRetries)';
            _phase = _Phase.ready;
          });
          await Future<void>.delayed(const Duration(seconds: 3));
          if (mounted) unawaited(_startLive());
        } else {
          _startRetries = 0;
          setState(() {
            _error =
                'Stream signal not received. Make sure your stream is publishing.';
            _phase = _Phase.ready;
          });
        }
        return;
      }

      _startRetries = 0;
      setState(() {
        _phase = _Phase.live;
        _durationSeconds = 0;
      });
      _startPolling();
    } on DioException catch (e) {
      if (!mounted) return;
      // 409 means Ant Media hasn't received the stream yet.
      // Extract next_action from response body if available.
      final dynamic body = e.response?.data;
      final String? nextAction = body is Map<String, dynamic>
          ? body['next_action']?.toString()
          : null;

      if (e.response?.statusCode == 409 &&
          nextAction == 'retry_status' &&
          _startRetries < _maxStartRetries) {
        _startRetries++;
        setState(() {
          _error =
              'Waiting for stream signal... (retry $_startRetries/$_maxStartRetries)';
          _phase = _Phase.ready;
        });
        await Future<void>.delayed(const Duration(seconds: 3));
        if (mounted) unawaited(_startLive());
      } else {
        _startRetries = 0;
        final String msg = body is Map<String, dynamic>
            ? body['detail']?.toString() ?? 'Failed to start live.'
            : 'Failed to start live. Please try again.';
        setState(() {
          _error = msg;
          _phase = _Phase.ready;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to start live. Please try again.';
          _phase = _Phase.ready;
        });
      }
    }
  }

  Future<void> _endLive() async {
    final String? id = _session?.id;
    if (id == null) return;
    _stopPolling();
    if (!_kSkipAntMediaCheck) {
      AntMediaFlutter.anthelper?.close();
    }
    setState(() {
      _phase = _Phase.ending;
      _cameraReady = false;
    });
    try {
      await widget.apiClient.post<dynamic>(
        Endpoints.liveEnd(id),
        authenticated: true,
      );
    } catch (_) {
      // best-effort — session may already be closed server-side
    }
    if (mounted) setState(() => _phase = _Phase.ended);
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  void _startPolling() {
    _statusTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _pollStatus());
    _chatTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _pollChat());
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
    _pollStatus();
    _pollChat();
  }

  void _stopPolling() {
    _statusTimer?.cancel();
    _chatTimer?.cancel();
    _durationTimer?.cancel();
  }

  Future<void> _pollStatus() async {
    final String? id = _session?.id;
    if (id == null) return;
    try {
      final response = await widget.apiClient.get<dynamic>(
        Endpoints.liveStatus(id),
        authenticated: true,
      );
      final dynamic data = response.data;
      if (data is Map<String, dynamic> && mounted) {
        // Status response is flat — merge into existing session to preserve
        // stream_id / websocket_url from quick-start
        final LiveSession current = _session!;
        final LiveSession updated = current.copyWith(
          effectiveStatus: data['effective_status']?.toString(),
          status: data['status']?.toString(),
          viewerCount: (data['viewer_count'] as num?)?.toInt(),
          canStart: data['can_start'] == true,
          canEnd: data['can_end'] == true,
        );
        setState(() {
          _session = updated;
          if (updated.isEnded && _phase == _Phase.live) {
            _phase = _Phase.ended;
            _stopPolling();
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
      final response = await widget.apiClient.get<dynamic>(
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
          _messages.addAll(newMessages);
          _lastChatId = newMessages.last.id;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final String text = _chatController.text.trim();
    if (text.isEmpty || _sendingMessage) return;
    final String? id = _session?.id;
    if (id == null) return;
    setState(() => _sendingMessage = true);
    _chatController.clear();
    try {
      await widget.apiClient.post<dynamic>(
        Endpoints.liveChatMessages(id),
        data: <String, String>{'message': text},
        authenticated: true,
      );
      await _pollChat();
    } catch (_) {
      if (mounted) _chatController.text = text;
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
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
    return switch (_phase) {
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
          durationSeconds: _durationSeconds,
          ending: _phase == _Phase.ending,
          localRenderer: _cameraReady ? _localRenderer : null,
          onSend: _sendMessage,
          onEnd: _endLive,
          formatDuration: _formatDuration,
        ),
      _ => _PrepareView(
          phase: _phase,
          error: _error,
          session: _session,
          localRenderer: _cameraReady ? _localRenderer : null,
          onStart: _phase == _Phase.idle ? _quickStart : _goLive,
          onBack: () => Navigator.of(context).maybePop(),
        ),
    };
  }
}

// ── Prepare / Idle / Ready ────────────────────────────────────────────────────

class _PrepareView extends StatelessWidget {
  const _PrepareView({
    required this.phase,
    required this.error,
    required this.session,
    required this.onStart,
    required this.onBack,
    this.localRenderer,
  });

  final _Phase phase;
  final String? error;
  final LiveSession? session;
  final VoidCallback onStart;
  final VoidCallback onBack;
  final RTCVideoRenderer? localRenderer;

  @override
  Widget build(BuildContext context) {
    final bool loading = phase == _Phase.preparing;
    final LiveSession? s = session;
    final bool hasSession = s != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Camera preview or placeholder
          localRenderer != null
              ? RTCVideoView(localRenderer!, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
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

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
                alignment: Alignment.topLeft,
                child: _CircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (hasSession) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground.withValues(alpha: 0.9),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
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
                                value:
                                    '${s.streamId.substring(0, s.streamId.length.clamp(0, 12))}••••',
                              ),
                            ],
                            if (s.websocketUrl.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              _InfoRow(
                                label: 'WebSocket',
                                value: s.websocketUrl
                                    .replaceFirst('wss://', '')
                                    .split('/')
                                    .first,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.greenAccent,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Publish config received — tap Go Live',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.greenAccent,
                                    fontSize: 11,
                                  ),
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
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    ElevatedButton(
                      onPressed: loading ? null : onStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              phase == _Phase.idle
                                  ? 'Prepare Live'
                                  : 'Go Live',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
    required this.durationSeconds,
    required this.ending,
    required this.onSend,
    required this.onEnd,
    required this.formatDuration,
    this.localRenderer,
  });

  final LiveSession? session;
  final List<LiveChatMessage> messages;
  final TextEditingController chatController;
  final bool sendingMessage;
  final RTCVideoRenderer? localRenderer;
  final int durationSeconds;
  final bool ending;
  final VoidCallback onSend;
  final VoidCallback onEnd;
  final String Function(int) formatDuration;

  @override
  State<_LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<_LiveView> {
  final ScrollController _scrollController = ScrollController();
  bool _showEndConfirm = false;

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
                ? RTCVideoView(widget.localRenderer!, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
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
                      // End button
                      GestureDetector(
                        onTap: () => setState(() => _showEndConfirm = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withAlpha(200),
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
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(21),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: TextField(
                            controller: widget.chatController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Say something...',
                              hintStyle: TextStyle(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => widget.onSend(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      GestureDetector(
                        onTap: widget.sendingMessage ? null : widget.onSend,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: AppColors.brandGold,
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
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              const Icon(
                Icons.live_tv_rounded,
                color: AppColors.brandGold,
                size: 72,
              ),
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
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

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
