import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Connection state of the WebSocket chat channel.
enum LiveChatWsState { connecting, connected, disconnected }

typedef LiveChatWsMessageCallback = void Function(Map<String, dynamic> message);
typedef LiveChatWsStateCallback = void Function(LiveChatWsState state);

/// WebSocket client for live chat.
///
/// Flow:
///   connect() → WebSocket open → onStateChange(connected)
///   Server pushes { type: "message_created"|"message_updated"|"message_deleted", message: {...} }
///   Client sends  { action: "post_message", data: { message_type, content } }
///
/// On disconnect, auto-reconnects up to [maxRetries] times (exponential backoff,
/// cap 30 s). After maxRetries failures the caller's [onStateChange] fires with
/// disconnected and it is the caller's responsibility to fall back to REST polling.
class LiveChatWsClient {
  LiveChatWsClient({
    required this.baseUrl,
    required this.liveId,
    required this.token,
    required this.onMessage,
    required this.onStateChange,
    this.maxRetries = 5,
  });

  final String baseUrl;
  final String liveId;
  final String token;

  /// Called for every event frame: message_created, message_updated,
  /// message_deleted, error — the full raw JSON map is forwarded.
  final LiveChatWsMessageCallback onMessage;
  final LiveChatWsStateCallback onStateChange;
  final int maxRetries;

  WebSocket? _ws;
  bool _closed = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  /// Derives the wss:// URL from the HTTP base URL.
  String get _wsUrl {
    final String sanitized =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final String wsBase = sanitized
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$wsBase/ws/live/$liveId/chat/?token=${Uri.encodeComponent(token)}';
  }

  Future<void> connect() async {
    _closed = false;
    await _tryConnect();
  }

  Future<void> _tryConnect() async {
    if (_closed) return;
    onStateChange(LiveChatWsState.connecting);
    try {
      _ws = await WebSocket.connect(_wsUrl);
      _retryCount = 0;
      onStateChange(LiveChatWsState.connected);

      _ws!.listen(
        (dynamic raw) {
          if (raw is String) _handleFrame(raw);
        },
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _onDisconnect();
    }
  }

  void _handleFrame(String raw) {
    try {
      final Map<String, dynamic> frame =
          jsonDecode(raw) as Map<String, dynamic>;
      onMessage(frame);
    } catch (_) {}
  }

  void _onDisconnect() {
    _ws = null;
    if (_closed) return;
    if (_retryCount >= maxRetries) {
      onStateChange(LiveChatWsState.disconnected);
      return;
    }
    // Exponential backoff: 1, 2, 4, 8, … capped at 30 s.
    final int delaySeconds = (1 << _retryCount).clamp(1, 30);
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySeconds), _tryConnect);
  }

  /// Sends a text chat message. Returns false if the socket is not open.
  bool sendText(String content) {
    return _send(<String, dynamic>{
      'action': 'post_message',
      'data': <String, dynamic>{
        'message_type': 'text',
        'content': content,
      },
    });
  }

  bool _send(Map<String, dynamic> payload) {
    final ws = _ws;
    if (ws == null || ws.readyState != WebSocket.open) return false;
    ws.add(jsonEncode(payload));
    return true;
  }

  void close() {
    _closed = true;
    _retryTimer?.cancel();
    _ws?.close();
    _ws = null;
  }
}
