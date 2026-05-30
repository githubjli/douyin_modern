import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/feed_item.dart';

/// Persists the feed item list and per-episode playback progress locally.
///
/// Cache-first strategy:
///   1. Read stale cache → show immediately while network refreshes.
///   2. On network success → overwrite cache with fresh data.
///   3. On network failure → keep showing stale cache with offline banner.
class FeedCache {
  static const String _feedKey = 'feed_cache_v1';
  static const String _progressPrefix = 'feed_progress_v1_';
  static const String _feedIndexKey = 'feed_last_index_v1';

  // ------------------------------------------------------------------
  // Feed list
  // ------------------------------------------------------------------

  Future<void> saveFeed(List<FeedItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString(_feedKey, encoded);
  }

  Future<List<FeedItem>?> loadFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_feedKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupted cache — clear it.
      await prefs.remove(_feedKey);
      return null;
    }
  }

  Future<void> clearFeed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_feedKey);
  }

  // ------------------------------------------------------------------
  // Last viewed index (which page the user was on)
  // ------------------------------------------------------------------

  Future<void> saveLastIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_feedIndexKey, index);
  }

  Future<int> loadLastIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_feedIndexKey) ?? 0;
  }

  // ------------------------------------------------------------------
  // Per-episode playback progress
  // ------------------------------------------------------------------

  Future<void> saveProgress(int episodeId, int positionSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_progressPrefix$episodeId', positionSeconds);
  }

  Future<int?> loadProgress(int episodeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_progressPrefix$episodeId');
  }

  Future<void> clearProgress(int episodeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_progressPrefix$episodeId');
  }
}
