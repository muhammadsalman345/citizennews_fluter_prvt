import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/news_models.dart';

/// Small device cache for public feed previews only.
///
/// Article bodies, authentication data and viewer-specific state are never
/// persisted here.
class FeedCache {
  static const _storageKey = 'citizennews-public-feed-v1';
  static const _maxAge = Duration(hours: 24);
  static const _maxFeeds = 8;
  static const _maxStories = 12;
  static Future<void> _writeQueue = Future<void>.value();

  const FeedCache();

  static String key({
    required String tab,
    String city = '',
    String country = '',
    String region = '',
    String category = '',
  }) => jsonEncode([
    tab,
    city,
    country,
    region,
    category,
  ]);

  static String scopedKey({
    required String kind,
    required String slug,
    required String countrySlug,
    required String sort,
    String category = '',
    String area = '',
    String dateFrom = '',
    String dateTo = '',
  }) => jsonEncode([
    'scoped',
    kind,
    countrySlug,
    slug,
    sort,
    category,
    area,
    dateFrom,
    dateTo,
  ]);

  Future<List<NewsSummary>?> read(String key) async {
    try {
      final entries = await _entries();
      for (final entry in entries) {
        if (entry.key == key) return entry.rows;
      }
    } catch (error) {
      debugPrint('[CitizenNews FeedCache] Read failed: $error');
    }
    return null;
  }

  Future<void> write(String key, List<NewsSummary> rows) {
    _writeQueue = _writeQueue
        .then((_) => _write(key, rows))
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('[CitizenNews FeedCache] Write failed: $error');
        });
    return _writeQueue;
  }

  Future<void> _write(String key, List<NewsSummary> rows) async {
    final entries = (await _entries())
        .where((entry) => entry.key != key)
        .toList(growable: true);
    final previews = rows.take(_maxStories).toList(growable: false);
    if (previews.isNotEmpty) {
      entries.insert(
        0,
        _FeedCacheEntry(
          key: key,
          savedAt: DateTime.now().millisecondsSinceEpoch,
          rows: previews,
        ),
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(
        entries.take(_maxFeeds).map((entry) => entry.toJson()).toList(),
      ),
    );
  }

  Future<List<_FeedCacheEntry>> _entries() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = <_FeedCacheEntry>[];
    for (final value in decoded) {
      if (value is! Map) continue;
      final json = Map<String, dynamic>.from(value);
      final key = json['key'];
      final savedAt = json['saved'];
      final savedRows = json['rows'];
      if (key is! String || savedAt is! num || savedRows is! List) continue;
      final age = now - savedAt.toInt();
      if (age < 0 || age > _maxAge.inMilliseconds) continue;
      final rows = <NewsSummary>[];
      for (final row in savedRows) {
        if (row is! Map) continue;
        final story = NewsSummary.fromJson(Map<String, dynamic>.from(row));
        if (story.id.isEmpty || story.slug.isEmpty || story.headline.isEmpty) {
          continue;
        }
        rows.add(story);
      }
      if (rows.isNotEmpty) {
        entries.add(
          _FeedCacheEntry(key: key, savedAt: savedAt.toInt(), rows: rows),
        );
      }
    }
    return entries;
  }
}

class _FeedCacheEntry {
  const _FeedCacheEntry({
    required this.key,
    required this.savedAt,
    required this.rows,
  });

  final String key;
  final int savedAt;
  final List<NewsSummary> rows;

  Map<String, dynamic> toJson() => {
    'key': key,
    'saved': savedAt,
    'rows': rows.map((row) => row.toCacheJson()).toList(growable: false),
  };
}
