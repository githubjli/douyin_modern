import 'dart:async';

import 'package:ant_media_flutter/ant_media_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_error.dart';
import '../../core/network/endpoints.dart';
import '../auth/application/auth_providers.dart';
import '../creator_profile/presentation/creator_profile_page.dart';
import '../home/domain/home_models.dart';
import 'domain/live_chat_message.dart';
import 'domain/live_watch_config.dart';

// ── Phase ──────────────────────────────────────────────────────────────────

enum _WatchPhase {
  loading,    // fetching watch-config
  connecting, // WebRTC: waiting for remote stream
  playing,    // WebRTC stream active
  hlsPlaying, // HLS fallback active
  ended,      // stream finished
  failed,     // 409 – server-side stream failure
  error,      // any other load/playback error
}

// ── Page ───────────────────────────────────────────────────────────────────

class LiveWatchPage extends ConsumerStatefulWidget {
  const LiveWatchPage({super.key, required this.item});

  /// The live card that was tapped. Provides initial display info (avatar,
  /// name, thumbnail) while the watch-config is being fetched.
  final HomeLiveItem item;

  @override
  ConsumerState<LiveWatchPage> createState() => _LiveWatchPageState();
}

class _LiveWatchPageState extends ConsumerState<LiveWatchPage> {
  _WatchPhase _phase = _WatchPhase.loading;
  LiveWatchConfig? _config;
  String? _errorMessage;

  // ── WebRTC ──────────────────────────────────────────────────────────────
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _webrtcBound = false;

  /// Incremented each time we (re)connect to invalidate stale SDK callbacks.
  int _antGeneration = 0;

  /// Falls back to HLS if no remote stream arrives within this window.
  Timer? _webrtcTimeoutTimer;

  // ── HLS fallback ─────────────────────────────────────────────────────────
  VideoPlayerController? _hlsController;

  // ── Live info ─────────────────────────────────────────────────────────────
  int _viewerCount = 0;

  // ── Chat ──────────────────────────────────────────────────────────────────
  final List<LiveChatMessage> _messages = <LiveChatMessage>[];
  final TextEditingController _chatInput = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _sendingMessage = false;
  int _lastChatId = 0;
  static const int _maxMessages = 200;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _statusTimer;
  Timer? _chatTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
    _viewerCount = widget.item.viewerCount ?? 0;
    _loadWatchConfig();
  }

  @override
  void dispose() {
    _stopPolling();
    _webrtcTimeoutTimer?.cancel();
    _antGeneration++; // invalidate any in-flight SDK callbacks
    AntMediaFlutter.anthelper?.close();
    _remoteRenderer.dispose();
    _hlsController?.removeListener(_onHlsPlayerUpdate);
    _hlsController?.dispose();
    _chatInput.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  // ── Watch-config ──────────────────────────────────────────────────────────

  Future<void> _loadWatchConfig() async {
    setState(() {
      _phase = _WatchPhase.loading;
      _errorMessage = null;
    });
    try {
      final response = await ref.read(apiClientProvider).get<dynamic>(
        Endpoints.liveWatchConfig(widget.item.id),
        authenticated: true,
      );
      if (!mounted) return;
      final dynamic data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiError(message: 'Invalid watch-config response.');
      }
      final LiveWatchConfig config = LiveWatchConfig.fromJson(data);
      setState(() {
        _config = config;
        _viewerCount = config.viewerCount;
      });

      final bool canWebRtc = config.playback.isWebRtc &&
          config.playback.websocketUrl != null &&
          config.playback.streamId != null;

      if (canWebRtc) {
        _connectWebRTC(config);
      } else {
        await _startHLS(config);
      }
      _startPolling();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = e.statusCode == 409 ? _WatchPhase.failed : _WatchPhase.error;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _WatchPhase.error;
        _errorMessage = 'Unable to load stream. Please try again.';
      });
    }
  }

  // ── WebRTC ────────────────────────────────────────────────────────────────

  void _connectWebRTC(LiveWatchConfig config) {
    setState(() => _phase = _WatchPhase.connecting);
    final int gen = ++_antGeneration;

    // Bail out to HLS if no remote track arrives in 15 seconds.
    _webrtcTimeoutTimer?.cancel();
    _webrtcTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || gen != _antGeneration) return;
      if (_phase == _WatchPhase.connecting) {
        _antGeneration++;
        AntMediaFlutter.anthelper?.close();
        _startHLS(config);
      }
    });

    AntMediaFlutter.connect(
      config.playback.websocketUrl!,
      config.playback.streamId!,
      '', // roomId – not used for Play mode
      '', // token  – public stream, no TOTP
      AntMediaType.Play,
      false, // userScreen
      // onStateChange
      (HelperState state) {
        if (!mounted || gen != _antGeneration) return;
        if (state == HelperState.ConnectionError ||
            state == HelperState.ConnectionClosed) {
          if (_phase == _WatchPhase.connecting) {
            _antGeneration++;
            final LiveWatchConfig? cfg = _config;
            if (cfg != null) _startHLS(cfg);
          }
        }
      },
      // onLocalStream – not needed for viewer
      (MediaStream _) {},
      // onAddRemoteStream – fires when the remote track is available
      (MediaStream stream) {
        if (!mounted || gen != _antGeneration) return;
        _webrtcTimeoutTimer?.cancel();
        _remoteRenderer.srcObject = stream;
        setState(() {
          _webrtcBound = true;
          _phase = _WatchPhase.playing;
        });
      },
      (RTCDataChannel _) {},
      (RTCDataChannel dc, RTCDataChannelMessage msg, bool received) {},
      (dynamic _) {},
      (MediaStream _) {},
      const <Map<String, String>>[],
      // Ant Media signalling callbacks
      (String command, Map<dynamic, dynamic> data) {
        if (!mounted || gen != _antGeneration) return;
        if (command == 'notification') {
          final String? def = data['definition']?.toString();
          if (def == 'play_finished' || def == 'publish_finished') {
            _onStreamEnded();
          }
        }
      },
    );
  }

  // ── HLS fallback ──────────────────────────────────────────────────────────

  Future<void> _startHLS(LiveWatchConfig config) async {
    final String? hlsUrl =
        config.playback.hlsUrl ?? config.fallback.hlsUrl;
    if (hlsUrl == null || hlsUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _phase = _WatchPhase.error;
          _errorMessage = 'No playback URL available.';
        });
      }
      return;
    }
    try {
      final VideoPlayerController ctrl =
          VideoPlayerController.networkUrl(Uri.parse(hlsUrl));
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      ctrl.addListener(_onHlsPlayerUpdate);
      await ctrl.play();
      ctrl.setLooping(false);
      setState(() {
        _hlsController = ctrl;
        _phase = _WatchPhase.hlsPlaying;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = _WatchPhase.error;
          _errorMessage = 'Unable to play stream. Please try again.';
        });
      }
    }
  }

  void _onHlsPlayerUpdate() {
    final VideoPlayerController? ctrl = _hlsController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (!ctrl.value.isPlaying &&
        ctrl.value.duration > Duration.zero &&
        ctrl.value.position >= ctrl.value.duration) {
      _onStreamEnded();
    }
  }

  // ── Stream ended ──────────────────────────────────────────────────────────

  void _onStreamEnded() {
    if (!mounted) return;
    _stopPolling();
    if (_phase != _WatchPhase.ended) {
      setState(() => _phase = _WatchPhase.ended);
    }
  }

  // ── Polling ───────────────────────────────────────────────────────────────

  void _startPolling() {
    _statusTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _pollStatus());
    _chatTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => _pollChat());
    _pollChat(); // initial fetch
  }

  void _stopPolling() {
    _statusTimer?.cancel();
    _chatTimer?.cancel();
  }

  Future<void> _pollStatus() async {
    try {
      final response = await ref.read(apiClientProvider).get<dynamic>(
        Endpoints.liveWatchConfig(widget.item.id),
        authenticated: true,
      );
      if (!mounted) return;
      final dynamic data = response.data;
      if (data is Map<String, dynamic>) {
        final int count =
            (data['viewer_count'] as num?)?.toInt() ?? _viewerCount;
        final String? es = data['effective_status']?.toString() ??
            data['status']?.toString();
        setState(() => _viewerCount = count);
        if (es == 'ended' || es == 'failed') _onStreamEnded();
      }
    } catch (_) {}
  }

  Future<void> _pollChat() async {
    try {
      final Map<String, dynamic>? query = _lastChatId > 0
          ? <String, dynamic>{'after_id': _lastChatId}
          : null;
      final response = await ref.read(apiClientProvider).get<dynamic>(
        Endpoints.liveChatMessages(widget.item.id),
        queryParameters: query,
        authenticated: true,
      );
      if (!mounted) return;
      final dynamic data = response.data;
      List<dynamic> results = <dynamic>[];
      if (data is Map<String, dynamic>) {
        results = data['results'] as List<dynamic>? ?? <dynamic>[];
      } else if (data is List<dynamic>) {
        results = data;
      }
      if (results.isNotEmpty) {
        final List<LiveChatMessage> newMsgs = results
            .whereType<Map<String, dynamic>>()
            .map(LiveChatMessage.fromJson)
            .toList();
        setState(() {
          _messages.addAll(newMsgs);
          if (_messages.length > _maxMessages) {
            _messages.removeRange(0, _messages.length - _maxMessages);
          }
          _lastChatId = newMsgs.last.id;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScroll.hasClients) {
            _chatScroll.animateTo(
              _chatScroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final String text = _chatInput.text.trim();
    if (text.isEmpty || _sendingMessage) return;
    setState(() => _sendingMessage = true);
    _chatInput.clear();
    try {
      await ref.read(apiClientProvider).post<dynamic>(
        Endpoints.liveChatMessages(widget.item.id),
        data: <String, String>{'message': text},
        authenticated: true,
      );
      await _pollChat();
    } catch (_) {
      if (mounted) _chatInput.text = text;
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _buildVideoLayer(),
          // Gradient scrim for top bar readability
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),
          _buildTopBar(),
          if (_phase == _WatchPhase.loading ||
              _phase == _WatchPhase.connecting)
            _buildLoadingOverlay(),
          if (_phase == _WatchPhase.playing ||
              _phase == _WatchPhase.hlsPlaying) ...<Widget>[
            _buildChatMessages(),
            _buildChatInput(),
          ],
          if (_phase == _WatchPhase.ended) _buildEndedOverlay(),
          if (_phase == _WatchPhase.failed ||
              _phase == _WatchPhase.error)
            _buildErrorOverlay(),
        ],
      ),
    );
  }

  // ── Video layer ───────────────────────────────────────────────────────────

  Widget _buildVideoLayer() {
    // WebRTC – remote track bound
    if (_phase == _WatchPhase.playing && _webrtcBound) {
      return RTCVideoView(
        _remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    // HLS – controller ready
    if (_phase == _WatchPhase.hlsPlaying &&
        _hlsController != null &&
        _hlsController!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _hlsController!.value.size.width,
          height: _hlsController!.value.size.height,
          child: VideoPlayer(_hlsController!),
        ),
      );
    }
    // Thumbnail while loading / connecting / ended
    final String? cover = _config?.coverUrl ?? widget.item.thumbnailUrl;
    if (cover != null && cover.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cover,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
      );
    }
    return const ColoredBox(color: Colors.black);
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              _buildStreamerChip(),
              const Spacer(),
              _buildViewerBadge(),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamerChip() {
    final String? avatarUrl = widget.item.ownerAvatarUrl;
    final String name = widget.item.ownerName ?? widget.item.title;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.softBorder,
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(width: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130),
          child: Text(
            name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'LIVE',
            style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildViewerBadge() {
    final String label = _viewerCount >= 1000
        ? '${(_viewerCount / 1000).toStringAsFixed(1)}K'
        : '$_viewerCount';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.visibility_outlined,
            color: Colors.white70, size: 14),
        const SizedBox(width: 3),
        Text(label,
            style:
                const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  Widget _buildChatMessages() {
    if (_messages.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: AppSpacing.sm,
      right: 72, // leave right edge clear for future action buttons
      bottom: 64 + MediaQuery.of(context).viewInsets.bottom,
      height: 220,
      child: ShaderMask(
        shaderCallback: (Rect rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.transparent, Colors.white],
          stops: <double>[0.0, 0.35],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _chatScroll,
          itemCount: _messages.length,
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (_, int i) {
            final LiveChatMessage msg = _messages[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: RichText(
                text: TextSpan(
                  children: <TextSpan>[
                    TextSpan(
                      text: '${msg.senderName}  ',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: msg.message,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            AppSpacing.sm,
            AppSpacing.xs + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: _chatInput,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Say something...',
                      hintStyle: TextStyle(
                          color: Colors.white54, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: _sendingMessage ? null : _sendMessage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.brandGold,
                    shape: BoxShape.circle,
                  ),
                  child: _sendingMessage
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send,
                          color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status overlays ───────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(
              color: AppColors.brandGold, strokeWidth: 2),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _phase == _WatchPhase.connecting
                ? 'Connecting...'
                : 'Loading...',
            style: const TextStyle(
                color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedOverlay() {
    final int? ownerId = widget.item.ownerId;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.live_tv, color: Colors.white54, size: 48),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'This stream has ended.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            if (ownerId != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Visit the creator\'s profile to see their latest content.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandGold),
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CreatorProfilePage(creatorId: ownerId),
                  ),
                ),
                child: const Text('View Creator Profile'),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    final bool isFailed = _phase == _WatchPhase.failed;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isFailed ? Icons.error_outline : Icons.wifi_off,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isFailed
                  ? 'Stream Unavailable'
                  : (_errorMessage ?? 'Unable to load stream.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back',
                      style: TextStyle(color: Colors.white70)),
                ),
                if (!isFailed) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandGold),
                    onPressed: _loadWatchConfig,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
