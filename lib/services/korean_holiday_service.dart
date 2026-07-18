import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/korean_holiday.dart';
import '../utils/korean_holiday_utils.dart';

class KoreanHolidayService {
  KoreanHolidayService._();

  static final KoreanHolidayService instance = KoreanHolidayService._();

  static final Uri _feedUri = Uri.parse(
    'https://calendar.google.com/calendar/ical/'
    'ko.south_korea%23holiday%40group.v.calendar.google.com/public/basic.ics',
  );
  static const _cacheDuration = Duration(days: 7);
  static const _cachePrefix = 'korean_holidays_';
  static const _fetchedAtPrefix = 'korean_holidays_fetched_at_';

  final _memory = <int, List<KoreanHoliday>>{};
  final _memoryFetchedAt = <int, DateTime>{};
  Future<Map<int, List<KoreanHoliday>>>? _refreshing;

  Future<List<KoreanHoliday>> getHolidaysForYear(
    int year, {
    bool forceRefresh = false,
  }) async {
    final memoryFetchedAt = _memoryFetchedAt[year];
    if (!forceRefresh &&
        memoryFetchedAt != null &&
        DateTime.now().difference(memoryFetchedAt) < _cacheDuration) {
      return _memory[year] ?? const <KoreanHoliday>[];
    }

    final cached = await _readCache(year);
    if (!forceRefresh && cached != null && !cached.isStale) {
      _memory[year] = cached.holidays;
      _memoryFetchedAt[year] = cached.fetchedAt;
      return cached.holidays;
    }

    try {
      final refreshed = await (_refreshing ??= _refreshAll().whenComplete(() {
        _refreshing = null;
      }));
      final holidays = refreshed[year];
      if (holidays != null) {
        _memory[year] = holidays;
        return holidays;
      }
    } catch (error) {
      debugPrint('[KoreanHolidayService] refresh error: $error');
    }

    return cached?.holidays ?? const <KoreanHoliday>[];
  }

  Future<Map<int, List<KoreanHoliday>>> _refreshAll() async {
    final response = await http
        .get(_feedUri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Holiday feed returned ${response.statusCode}',
        _feedUri,
      );
    }

    final parsed = parseKoreanHolidaysIcs(utf8.decode(response.bodyBytes));
    if (parsed.isEmpty) {
      throw const FormatException('Holiday feed contained no public holidays');
    }

    final byYear = <int, List<KoreanHoliday>>{};
    for (final holiday in parsed) {
      (byYear[holiday.date.year] ??= []).add(holiday);
    }

    final prefs = await SharedPreferences.getInstance();
    final fetchedAt = DateTime.now().millisecondsSinceEpoch;
    for (final entry in byYear.entries) {
      await prefs.setString(
        '$_cachePrefix${entry.key}',
        jsonEncode(entry.value.map((holiday) => holiday.toJson()).toList()),
      );
      await prefs.setInt('$_fetchedAtPrefix${entry.key}', fetchedAt);
      _memory[entry.key] = entry.value;
      _memoryFetchedAt[entry.key] = DateTime.fromMillisecondsSinceEpoch(
        fetchedAt,
      );
    }
    return byYear;
  }

  Future<_CachedHolidays?> _readCache(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cachePrefix$year');
    final fetchedAtMillis = prefs.getInt('$_fetchedAtPrefix$year');
    if (raw == null || fetchedAtMillis == null) return null;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final holidays = decoded
          .map(
            (item) =>
                KoreanHoliday.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .where((holiday) => holiday.name.isNotEmpty)
          .toList();
      return _CachedHolidays(
        holidays: holidays,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAtMillis),
      );
    } catch (error) {
      debugPrint('[KoreanHolidayService] cache parse error: $error');
      return null;
    }
  }
}

class _CachedHolidays {
  final List<KoreanHoliday> holidays;
  final DateTime fetchedAt;

  const _CachedHolidays({required this.holidays, required this.fetchedAt});

  bool get isStale =>
      DateTime.now().difference(fetchedAt) >=
      KoreanHolidayService._cacheDuration;
}
