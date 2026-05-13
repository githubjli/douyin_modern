import 'dart:async';

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
// Shared bullet-comment (弹幕) overlay used by both FeedPage and
// DramaPlayerPage.
// ─────────────────────────────────────────────────────────────────

class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({super.key, required this.comments});
  final List<String> comments;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuEntry {
  _DanmakuEntry({
    required this.text,
    required this.controller,
    required this.lane,
  });
  final String text;
  final AnimationController controller;
  final int lane;
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with TickerProviderStateMixin {
  static const int _laneCount = 5;
  static const double _laneHeight = 34;
  static const double _topOffset = 110;
  static const Duration _interval = Duration(milliseconds: 2500);
  static const Duration _speed = Duration(seconds: 7);

  final List<_DanmakuEntry> _active = <_DanmakuEntry>[];
  Timer? _timer;
  int _commentIndex = 0;
  int _nextLane = 0;

  @override
  void initState() {
    super.initState();
    _launch();
    _timer = Timer.periodic(_interval, (_) => _launch());
  }

  void _launch() {
    if (!mounted || widget.comments.isEmpty) return;
    final String text =
        widget.comments[_commentIndex % widget.comments.length];
    _commentIndex++;
    final int lane = _nextLane % _laneCount;
    _nextLane++;

    final AnimationController ctrl = AnimationController(
      vsync: this,
      duration: _speed,
    );
    final _DanmakuEntry entry =
        _DanmakuEntry(text: text, controller: ctrl, lane: lane);
    setState(() => _active.add(entry));
    ctrl.forward().then((_) {
      if (mounted) setState(() => _active.remove(entry));
      ctrl.dispose();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final _DanmakuEntry e in _active) {
      e.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    return Stack(
      children: _active.map((_DanmakuEntry entry) {
        final double top = _topOffset + entry.lane * _laneHeight;
        return AnimatedBuilder(
          animation: entry.controller,
          builder: (_, __) => Positioned(
            top: top,
            left: w - entry.controller.value * (w + 320),
            child: Text(
              entry.text,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1,
                shadows: <Shadow>[
                  Shadow(color: Colors.black87, blurRadius: 4),
                  Shadow(color: Colors.black54, blurRadius: 8),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
