import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_player/video_player.dart';

import '../../core/webrtc/ams_rtc_client.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/widgets/app_cached_image.dart' show AppCachedImage;
import '../../core/network/api_error.dart';
import '../../core/network/endpoints.dart';
import '../auth/application/auth_providers.dart';
import '../creator_profile/presentation/creator_profile_page.dart';
import '../home/domain/home_models.dart';
import '../shop/domain/shop_models.dart';
import '../shop/product_detail_page.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import 'data/live_chat_ws_client.dart';
import 'domain/live_chat_message.dart';
import 'domain/live_watch_config.dart';
import 'widgets/gift_burst.dart';

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
  AmsRtcClient? _amsClient;
  bool _webrtcBound = false;

  /// Incremented each time we start a fresh WebRTC session (not retries).
  int _antGeneration = 0;

  /// Number of reconnection attempts within the current generation.
  int _webrtcRetryCount = 0;
  static const int _maxWebrtcRetries = 1;

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
  bool _sendingGift = false;
  bool _chatError = false;
  int _lastChatId = 0;
  static const int _maxMessages = 200;

  // WebSocket chat
  LiveChatWsClient? _chatWs;
  bool _chatWsConnected = false;

  // ── Gift animation ────────────────────────────────────────────────────────
  final List<PendingGift> _activeGifts = [];
  int _nextGiftId = 0;

  // ── Gift catalog + wallet ─────────────────────────────────────────────────
  List<LiveGiftCatalogEntry> _giftCatalog = const <LiveGiftCatalogEntry>[];
  double _pointsBalance = 0;
  double _creditsBalance = 0;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _statusTimer;
  Timer? _chatFallbackTimer;

  // ── Orientation ───────────────────────────────────────────────────────────
  bool _isLandscape = false;

  // ── Shop — products featured by the streamer ───────────────────────────────
  final List<ShopProduct> _featuredProducts = <ShopProduct>[];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
    _viewerCount = widget.item.viewerCount ?? 0;
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _loadWatchConfig();
    _loadFeaturedProducts();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _stopPolling();
    _webrtcTimeoutTimer?.cancel();
    _antGeneration++; // invalidate any in-flight callbacks
    _amsClient?.close();
    _amsClient = null;
    _remoteRenderer.dispose();
    _hlsController?.removeListener(_onHlsPlayerUpdate);
    _hlsController?.dispose();
    _chatWs?.close();
    _chatInput.dispose();
    _chatScroll.dispose();
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
    _webrtcRetryCount = 0;
    _attachWebRTC(config, gen: ++_antGeneration);
  }

  /// Creates and connects a new AmsRtcClient. Shared by initial connect and retries.
  /// [gen] must equal [_antGeneration] at call time; retries reuse the same gen so
  /// stale callbacks from the closed client are rejected by the gen check.
  void _attachWebRTC(LiveWatchConfig config, {required int gen}) {
    _webrtcTimeoutTimer?.cancel();
    _webrtcTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || gen != _antGeneration) return;
      if (_phase == _WatchPhase.connecting) {
        _handleWebRtcFailure(config, gen);
      }
    });

    final client = AmsRtcClient(
      websocketUrl: config.playback.websocketUrl!,
      streamId: config.playback.streamId!,
      publish: false,
      onStateChange: (AmsState state) {
        if (!mounted || gen != _antGeneration) return;
        if ((state == AmsState.error || state == AmsState.closed) &&
            _phase == _WatchPhase.connecting) {
          _handleWebRtcFailure(config, gen);
        }
      },
      onRemoteStream: (MediaStream stream) {
        if (!mounted || gen != _antGeneration) return;
        _webrtcTimeoutTimer?.cancel();
        _remoteRenderer.srcObject = stream;
        setState(() {
          _webrtcBound = true;
          _phase = _WatchPhase.playing;
        });
      },
      onCommand: (String command, Map<dynamic, dynamic> data) {
        if (!mounted || gen != _antGeneration) return;
        if (command == 'notification') {
          final String? def = data['definition']?.toString();
          if (def == 'play_finished' || def == 'publish_finished') {
            _onStreamEnded();
          }
        }
      },
    );

    _amsClient = client;
    client.connect();
  }

  /// Retries WebRTC up to [_maxWebrtcRetries] times (2 s delay), then falls back to HLS.
  void _handleWebRtcFailure(LiveWatchConfig config, int gen) {
    if (!mounted || gen != _antGeneration) return;
    _webrtcTimeoutTimer?.cancel();
    _amsClient?.close();
    _amsClient = null;
    _remoteRenderer.srcObject = null;

    if (_webrtcRetryCount < _maxWebrtcRetries) {
      _webrtcRetryCount++;
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted || gen != _antGeneration) return;
        _attachWebRTC(config, gen: gen);
      });
    } else {
      _webrtcRetryCount = 0;
      _startHLS(config);
    }
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
    // Chat fallback: poll every 5 s when WS is not connected.
    _chatFallbackTimer = Timer.periodic(
        const Duration(seconds: 5), (_) {
      if (!_chatWsConnected) _pollChat();
    });
    // Fetch chat history via REST first, then hand off to WebSocket.
    _pollChat().then((_) => _connectChatWs());
    // Load gift catalog + wallet in parallel.
    _loadGiftsAndWallet();
  }

  Future<void> _loadGiftsAndWallet() async {
    final api = ref.read(apiClientProvider);
    await Future.wait(<Future<void>>[
      api.get<dynamic>(Endpoints.liveGifts(widget.item.id), authenticated: true).then((r) {
        if (!mounted) return;
        final dynamic data = r.data;
        final List<dynamic> list = data is List ? data : <dynamic>[];
        setState(() {
          _giftCatalog = list
              .whereType<Map<String, dynamic>>()
              .map(LiveGiftCatalogEntry.fromJson)
              .where((g) => g.isActive)
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        });
      }).catchError((_) {}),
      api.get<dynamic>(Endpoints.meowPointsWallet, authenticated: true).then((r) {
        if (!mounted) return;
        final dynamic data = r.data;
        if (data is Map<String, dynamic>) {
          setState(() {
            _pointsBalance =
                double.tryParse(data['balance']?.toString() ?? '') ?? 0;
          });
        }
      }).catchError((_) {}),
      api.get<dynamic>(Endpoints.meowCreditWallet, authenticated: true).then((r) {
        if (!mounted) return;
        final dynamic data = r.data;
        if (data is Map<String, dynamic>) {
          setState(() {
            _creditsBalance =
                double.tryParse(data['balance']?.toString() ?? '') ?? 0;
          });
        }
      }).catchError((_) {}),
    ]);
  }

  void _stopPolling() {
    _statusTimer?.cancel();
    _chatFallbackTimer?.cancel();
    _chatWs?.close();
    _chatWs = null;
  }

  Future<void> _connectChatWs() async {
    if (!mounted) return;
    final String? token = await TokenStorage().readAccessToken();
    if (token == null || token.isEmpty || !mounted) return;

    _chatWs?.close();
    _chatWs = LiveChatWsClient(
      baseUrl: ApiClient.defaultBaseUrl,
      liveId: widget.item.id,
      token: token,
      onMessage: _handleChatWsEvent,
      onStateChange: (LiveChatWsState state) {
        if (!mounted) return;
        setState(() {
          _chatWsConnected = state == LiveChatWsState.connected;
          _chatError = state == LiveChatWsState.disconnected;
        });
        // After reconnect, compensate missed messages via REST.
        if (state == LiveChatWsState.connected && _lastChatId > 0) _pollChat();
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
      if (_messages.any((m) => m.id == msg.id)) return;
      setState(() {
        _chatError = false;
        _messages.add(msg);
        if (_messages.length > _maxMessages) {
          _messages.removeRange(0, _messages.length - _maxMessages);
        }
        if (msg.id > _lastChatId) _lastChatId = msg.id;
      });
      if (msg.isGift) _triggerGiftBurst(msg);
      if (msg.isProduct) _handleProductMessage(msg);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScroll.hasClients) {
          _chatScroll.animateTo(
            _chatScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });

    } else if (type == 'message_updated') {
      final int updatedId = (msgData['id'] as num?)?.toInt() ?? 0;
      final int idx = _messages.indexWhere((m) => m.id == updatedId);
      if (idx >= 0) {
        setState(() => _messages[idx] = LiveChatMessage.fromJson(msgData));
      }

    } else if (type == 'message_deleted') {
      final int deletedId = (msgData['id'] as num?)?.toInt() ?? 0;
      setState(() => _messages.removeWhere((m) => m.id == deletedId));
    }
  }

  Future<void> _pollStatus() async {
    try {
      final response = await ref.read(apiClientProvider).get<dynamic>(
        Endpoints.liveStatus(widget.item.id),
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
        final List<LiveChatMessage> fetched = results
            .whereType<Map<String, dynamic>>()
            .map(LiveChatMessage.fromJson)
            .toList();
        // Deduplicate against already-displayed messages (WS may have
        // delivered some of these already).
        final Set<int> existingIds =
            _messages.map((m) => m.id).toSet();
        final List<LiveChatMessage> newMsgs =
            fetched.where((m) => !existingIds.contains(m.id)).toList();
        if (newMsgs.isEmpty) {
          if (mounted) setState(() => _chatError = false);
          return;
        }
        setState(() {
          _chatError = false;
          _messages.addAll(newMsgs);
          if (_messages.length > _maxMessages) {
            _messages.removeRange(0, _messages.length - _maxMessages);
          }
          _lastChatId = fetched.last.id; // track highest seen ID
        });
        for (final msg in newMsgs) {
          if (msg.isGift && mounted) _triggerGiftBurst(msg);
          if (msg.isProduct && mounted) _handleProductMessage(msg);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScroll.hasClients) {
            _chatScroll.animateTo(
              _chatScroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      } else if (mounted) {
        setState(() => _chatError = false);
      }
    } catch (_) {
      if (mounted) setState(() => _chatError = true);
    }
  }

  Future<void> _sendMessage() async {
    final String text = _chatInput.text.trim();
    if (text.isEmpty || _sendingMessage) return;
    setState(() => _sendingMessage = true);
    _chatInput.clear();

    // Prefer WebSocket; fall back to REST when WS is not connected.
    final bool sentViaWs = _chatWsConnected && (_chatWs?.sendText(text) ?? false);
    if (!sentViaWs) {
      try {
        await ref.read(apiClientProvider).post<dynamic>(
          Endpoints.liveChatMessages(widget.item.id),
          data: <String, dynamic>{'message_type': 'text', 'content': text},
          authenticated: true,
        );
        await _pollChat();
      } catch (_) {
        if (mounted) _chatInput.text = text;
      }
    }

    if (mounted) setState(() => _sendingMessage = false);
  }

  Future<void> _sendFixedGift(LiveGiftCatalogEntry gift, int quantity) async {
    if (_sendingGift) return;
    setState(() => _sendingGift = true);
    try {
      await ref.read(apiClientProvider).post<dynamic>(
        Endpoints.liveGiftSend(widget.item.id),
        data: <String, dynamic>{'gift_id': gift.id, 'quantity': quantity},
        authenticated: true,
      );
      // Optimistically update local balance; WS event will confirm.
      if (mounted) {
        setState(() => _pointsBalance -= gift.coinCost * quantity);
      }
    } on ApiError catch (e) {
      if (mounted) _showGiftError(e);
    } catch (_) {
      // Silent — WS will confirm if it went through.
    } finally {
      if (mounted) setState(() => _sendingGift = false);
    }
  }

  Future<void> _sendAmountGift(int amount, String paymentMethod) async {
    if (_sendingGift) return;
    setState(() => _sendingGift = true);
    try {
      await ref.read(apiClientProvider).post<dynamic>(
        Endpoints.liveGiftSend(widget.item.id),
        data: <String, dynamic>{
          'amount': amount,
          'payment_method': paymentMethod,
        },
        authenticated: true,
      );
      if (mounted) {
        setState(() {
          if (paymentMethod == 'meow_points') {
            _pointsBalance -= amount;
          } else {
            _creditsBalance -= amount;
          }
        });
      }
    } on ApiError catch (e) {
      if (mounted) _showGiftError(e);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _sendingGift = false);
    }
  }

  void _showGiftError(ApiError e) {
    final bool isInsufficient = e.code == 'insufficient_balance';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isInsufficient
          ? 'Insufficient balance. Please top up.'
          : e.message),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showGiftPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _GiftPickerSheet(
        gifts: _giftCatalog,
        pointsBalance: _pointsBalance,
        creditsBalance: _creditsBalance,
        onSendFixed: _sendFixedGift,
        onSendAmount: _sendAmountGift,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
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
          _buildOrientationButton(),
          if (_phase == _WatchPhase.loading ||
              _phase == _WatchPhase.connecting)
            _buildLoadingOverlay(),
          // Chat + input — shown as soon as config is loaded.
          if (_phase != _WatchPhase.loading &&
              _phase != _WatchPhase.ended &&
              _phase != _WatchPhase.failed &&
              _phase != _WatchPhase.error)
            _buildChatPanel(),
          if (_phase == _WatchPhase.ended) _buildEndedOverlay(),
          if (_phase == _WatchPhase.failed ||
              _phase == _WatchPhase.error)
            _buildErrorOverlay(),
          // Shop FAB — visible when streamer has featured products
          if (_featuredProducts.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 160,
              child: GestureDetector(
                onTap: _showProductSheet,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.brandGold.withValues(alpha: 0.6)),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.brandGold,
                        size: 22,
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppColors.brandGold,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${_featuredProducts.length}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Gift burst overlay
          if (_activeGifts.isNotEmpty)
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
                    if (mounted) {
                      setState(() => _activeGifts.removeWhere((x) => x.id == g.id));
                    }
                  },
                )).toList(),
              ),
            ),
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
      return AppCachedImage(
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

  Widget _buildOrientationButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 56,
      right: AppSpacing.sm,
      child: GestureDetector(
        onTap: _toggleOrientation,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(
            _isLandscape
                ? Icons.stay_current_portrait_rounded
                : Icons.stay_current_landscape_rounded,
            color: Colors.white,
            size: 18,
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            label,
            key: ValueKey(label),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // ── Chat panel (messages + input, anchored above keyboard) ──────────────

  Widget _buildChatPanel() {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: keyboardHeight,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Messages list ──────────────────────────────────────────────
            if (_messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 72),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ShaderMask(
                    shaderCallback: (Rect rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Colors.transparent, Colors.white],
                      stops: <double>[0.0, 0.3],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      controller: _chatScroll,
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _messages.length,
                      itemBuilder: (_, int i) => _buildChatBubble(_messages[i]),
                    ),
                  ),
                ),
              ),
            // ── Connection error hint ──────────────────────────────────────
            if (_chatError)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 2),
                child: Row(
                  children: const <Widget>[
                    Icon(Icons.wifi_off, color: Colors.white38, size: 12),
                    SizedBox(width: 4),
                    Text('Chat connection lost',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            // ── Input row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, 4, AppSpacing.sm, AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.4)),
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
                  // Gift button
                  GestureDetector(
                    onTap: _sendingGift ? null : _showGiftPicker,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: _sendingGift
                          ? const Padding(
                              padding: EdgeInsets.all(9),
                              child: CircularProgressIndicator(
                                  color: AppColors.brandGold, strokeWidth: 2),
                            )
                          : const Icon(Icons.card_giftcard_rounded,
                              color: AppColors.brandGold, size: 18),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Send button
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
          ],
        ),
      ),
    );
  }

  /// Pre-load products that the streamer has already bound to this live session.
  /// Falls back silently — real-time product messages fill the list anyway.
  Future<void> _loadFeaturedProducts() async {
    try {
      final response = await ref.read(apiClientProvider).get<dynamic>(
        Endpoints.liveProducts(widget.item.id),
        authenticated: false,
      );
      if (!mounted) return;
      final dynamic data = response.data;
      final List<dynamic> items = data is Map<String, dynamic>
          ? (data['results'] as List<dynamic>? ?? <dynamic>[])
          : data is List<dynamic>
              ? data
              : <dynamic>[];
      setState(() {
        for (final item in items.whereType<Map<String, dynamic>>()) {
          // Each item has shape: { binding_id, product: {...}, is_active, ... }
          final dynamic productJson = item['product'];
          if (productJson is! Map<String, dynamic>) continue;
          try {
            final ShopProduct p = ShopProduct.fromLivePayload(productJson);
            if (!_featuredProducts.any((x) => x.id == p.id)) {
              _featuredProducts.add(p);
            }
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('[LiveWatch] Failed to preload products: $e');
    }
  }

  void _triggerGiftBurst(LiveChatMessage msg) {
    final dynamic rawId = msg.payload['gift_id'];
    final int giftId = rawId is num
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final String giftCode = msg.payload['gift_code']?.toString() ?? '';
    final LiveGiftCatalogEntry? cat =
        _giftCatalog.cast<LiveGiftCatalogEntry?>().firstWhere(
      (g) => g!.id == giftId || (giftCode.isNotEmpty && g.code == giftCode),
      orElse: () => null,
    );
    setState(() {
      _activeGifts.add(PendingGift(
        id: _nextGiftId++,
        emoji: cat?.emoji ?? giftEmojiFromPayload(msg.payload),
        senderName: msg.senderName,
        label: msg.message,
        iconUrl: cat?.iconUrl ??
            resolveGiftUrl(msg.payload['icon_url']?.toString()),
        animationUrl: cat?.animationUrl ??
            resolveGiftUrl(msg.payload['animation_url']?.toString()),
        animationType:
            cat?.animationType ?? msg.payload['animation_type']?.toString(),
      ));
    });
  }

  void _handleProductMessage(LiveChatMessage msg) {
    if (msg.payload.isEmpty) return;
    try {
      final ShopProduct product = ShopProduct.fromLivePayload(msg.payload);
      if (!_featuredProducts.any((p) => p.id == product.id)) {
        setState(() => _featuredProducts.add(product));
      }
    } catch (_) {
      // malformed product payload — ignore
    }
  }

  void _showProductSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LiveProductSheet(
        products: _featuredProducts,
        onProductTap: (ShopProduct p) {
          Navigator.of(context).pop();
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, ScrollController sc) => ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusLg)),
                child: ProductDetailPage(product: p),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatBubble(LiveChatMessage msg) {
    final String streamerName = widget.item.ownerName ?? '';

    // System message
    if (msg.isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          msg.message,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      );
    }

    // Gift message — gold bubble
    if (msg.isGift) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.brandGold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: RichText(
            text: TextSpan(children: <InlineSpan>[
              const TextSpan(
                  text: '🎁 ', style: TextStyle(fontSize: 13)),
              TextSpan(
                text: msg.senderName,
                style: const TextStyle(
                    color: AppColors.brandGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: '  ${msg.message}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 13),
              ),
            ]),
          ),
        ),
      );
    }

    // Regular chat — streamer name in gold, viewers in white
    final bool isStreamer =
        streamerName.isNotEmpty && msg.senderName == streamerName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(children: <TextSpan>[
          TextSpan(
            text: '${msg.senderName}  ',
            style: TextStyle(
              color: isStreamer ? AppColors.brandGold : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: msg.message,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ]),
      ),
    );
  }

  // ── Status overlays ───────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    final String label = _phase == _WatchPhase.connecting
        ? 'Connecting to live stream...'
        : 'Loading...';
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(
                color: AppColors.brandGold, strokeWidth: 2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13),
            ),
          ],
        ),
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

// ── Gift picker sheet ──────────────────────────────────────────────────────────

const List<int> _kAmounts = <int>[1, 10, 30, 100, 200, 500];

class _GiftPickerSheet extends StatefulWidget {
  const _GiftPickerSheet({
    required this.gifts,
    required this.pointsBalance,
    required this.creditsBalance,
    required this.onSendFixed,
    required this.onSendAmount,
  });

  final List<LiveGiftCatalogEntry> gifts;
  final double pointsBalance;
  final double creditsBalance;
  final Future<void> Function(LiveGiftCatalogEntry gift, int quantity) onSendFixed;
  final Future<void> Function(int amount, String paymentMethod) onSendAmount;

  @override
  State<_GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends State<_GiftPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this);
  int _selectedAmount = 10;
  String _paymentMethod = 'meow_points';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _giftIconFallback(LiveGiftCatalogEntry gift) {
    return Center(
      child: Text(gift.emoji, style: const TextStyle(fontSize: 26)),
    );
  }

  Future<void> _confirmAndSendFixed(LiveGiftCatalogEntry gift, int quantity) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Send ${gift.name}?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will cost ${gift.coinCost * quantity} pts.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandGold),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
      await widget.onSendFixed(gift, quantity);
    }
  }

  Future<void> _confirmAndSendAmount(int amount, String paymentMethod) async {
    final String methodLabel = paymentMethod == 'meow_points' ? 'pts' : 'credits';
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Send Gift?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will spend $amount $methodLabel.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandGold),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
      await widget.onSendAmount(amount, paymentMethod);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.sm, 0),
            child: Row(
              children: <Widget>[
                const Text('Send a Gift',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Balance row
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 4),
            child: Row(
              children: <Widget>[
                const Icon(Icons.stars_rounded,
                    color: AppColors.brandGold, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Points: ${widget.pointsBalance.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppColors.brandGold, fontSize: 12),
                ),
                const SizedBox(width: AppSpacing.md),
                const Icon(Icons.credit_card_rounded,
                    color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Credit: ${widget.creditsBalance.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabs,
            indicatorColor: AppColors.brandGold,
            labelColor: AppColors.brandGold,
            unselectedLabelColor: Colors.white54,
            tabs: const <Tab>[
              Tab(text: 'Gifts'),
              Tab(text: 'Amount'),
            ],
          ),
          SizedBox(
            height: 200,
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _buildGiftTab(),
                _buildAmountTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftTab() {
    if (widget.gifts.isEmpty) {
      return const Center(
          child: Text('No gifts available',
              style: TextStyle(color: Colors.white54)));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.85,
      ),
      itemCount: widget.gifts.length,
      itemBuilder: (_, int i) {
        final LiveGiftCatalogEntry gift = widget.gifts[i];
        return GestureDetector(
          onTap: () => _confirmAndSendFixed(gift, 1),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Icon: Lottie → network image → emoji fallback
                SizedBox(
                  width: 40,
                  height: 40,
                  child: gift.hasLottie
                      ? Lottie.network(
                          gift.animationUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _giftIconFallback(gift),
                        )
                      : gift.iconUrl != null
                          ? AppCachedImage(
                              imageUrl: gift.iconUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) =>
                                  _giftIconFallback(gift),
                            )
                          : _giftIconFallback(gift),
                ),
                const SizedBox(height: 3),
                Text(gift.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${gift.coinCost} pts',
                    style: const TextStyle(
                        color: AppColors.brandGold,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountTab() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Amount chips
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _kAmounts.map((int amt) {
              final bool selected = amt == _selectedAmount;
              return GestureDetector(
                onTap: () => setState(() => _selectedAmount = amt),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.brandGold
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected
                            ? AppColors.brandGold
                            : Colors.white24),
                  ),
                  child: Text(
                    '$amt',
                    style: TextStyle(
                        color:
                            selected ? Colors.black : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Payment method toggle
          Row(
            children: <Widget>[
              _PayMethodChip(
                label: 'Points',
                icon: Icons.stars_rounded,
                selected: _paymentMethod == 'meow_points',
                onTap: () =>
                    setState(() => _paymentMethod = 'meow_points'),
              ),
              const SizedBox(width: AppSpacing.xs),
              _PayMethodChip(
                label: 'Credit',
                icon: Icons.credit_card_rounded,
                selected: _paymentMethod == 'meow_credit',
                onTap: () =>
                    setState(() => _paymentMethod = 'meow_credit'),
              ),
            ],
          ),
          const Spacer(),
          // Send button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandGold),
              onPressed: () => _confirmAndSendAmount(_selectedAmount, _paymentMethod),
              child: Text('Send $_selectedAmount',
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayMethodChip extends StatelessWidget {
  const _PayMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandGold.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.brandGold : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon,
                size: 14,
                color: selected ? AppColors.brandGold : Colors.white54),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color:
                        selected ? AppColors.brandGold : Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Live product sheet (viewer side) ─────────────────────────────────────────

class _LiveProductSheet extends StatelessWidget {
  const _LiveProductSheet({
    required this.products,
    required this.onProductTap,
  });

  final List<ShopProduct> products;
  final void Function(ShopProduct) onProductTap;

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              const Icon(Icons.shopping_bag_outlined,
                  color: AppColors.brandGold, size: 18),
              const SizedBox(width: AppSpacing.xs),
              const Text(
                'Products in this Live',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: products.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white12),
              itemBuilder: (_, int i) {
                final ShopProduct p = products[i];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                  onTap: () => onProductTap(p),
                  leading: p.thumbnailUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AppCachedImage(
                            imageUrl: p.thumbnailUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined,
                              color: Colors.white38, size: 26),
                        ),
                  title: Text(
                    p.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    p.meowPointsPrice != null
                        ? '${p.meowPointsPrice} MP'
                        : p.price,
                    style: const TextStyle(
                      color: AppColors.brandGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.brandGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Buy',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

