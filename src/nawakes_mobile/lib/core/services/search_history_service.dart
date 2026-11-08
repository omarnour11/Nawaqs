import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kSearchHistoryKey = 'nawaqs_recent_search_history_v1';
const int _kMaxHistoryItems = 15;

class SearchHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadFromDisk();
    return const [];
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kSearchHistoryKey) ?? [];
      state = list;
    } catch (_) {
      // SharedPreferences unavailable or testing fallback
    }
  }

  Future<void> addQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.length < 2) return;

    final updated = [
      trimmed,
      ...state.where((item) => item.toLowerCase() != trimmed.toLowerCase()),
    ];

    if (updated.length > _kMaxHistoryItems) {
      updated.removeRange(_kMaxHistoryItems, updated.length);
    }

    state = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kSearchHistoryKey, updated);
    } catch (_) {}
  }

  Future<void> removeQuery(String query) async {
    final updated = state.where((item) => item != query).toList();
    state = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kSearchHistoryKey, updated);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    state = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSearchHistoryKey);
    } catch (_) {}
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(SearchHistoryNotifier.new);
