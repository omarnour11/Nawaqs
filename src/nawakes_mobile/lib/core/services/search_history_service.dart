import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nawakes_mobile/core/network/secure_storage_provider.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';

const int _kMaxHistoryItems = 15;

/// Isolated Recent Search History Service:
/// Strictly isolates search logs per authenticated user account, preventing cross-account leaks.
class SearchHistoryNotifier extends Notifier<List<String>> {
  String _currentStorageKey = 'nawaqs_recent_search_history_guest';

  @override
  List<String> build() {
    // Reactively watch auth status changes (e.g. login/logout)
    final authState = ref.watch(authControllerProvider).valueOrNull;
    if (authState == null || !authState.isAuthenticated) {
      _currentStorageKey = 'nawaqs_recent_search_history_guest';
      _loadFromDisk();
    } else {
      _loadUserStorage();
    }
    return const [];
  }

  Future<void> _loadUserStorage() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final userId = await storage.read(key: 'user_id');
      _currentStorageKey = (userId != null && userId.isNotEmpty)
          ? 'nawaqs_recent_search_history_user_$userId'
          : 'nawaqs_recent_search_history_guest';
    } catch (_) {
      _currentStorageKey = 'nawaqs_recent_search_history_guest';
    }
    await _loadFromDisk();
  }

  /// Explicitly scope search history to a user ID (for isolated account testing & switching)
  Future<void> scopeToUser(String? userId) async {
    _currentStorageKey = (userId != null && userId.isNotEmpty)
        ? 'nawaqs_recent_search_history_user_$userId'
        : 'nawaqs_recent_search_history_guest';
    await _loadFromDisk();
  }

  String get activeStorageKey => _currentStorageKey;

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_currentStorageKey) ?? [];
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
      await prefs.setStringList(_currentStorageKey, updated);
    } catch (_) {}
  }

  Future<void> removeQuery(String query) async {
    final updated = state.where((item) => item != query).toList();
    state = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_currentStorageKey, updated);
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    state = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentStorageKey);
    } catch (_) {}
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(
  SearchHistoryNotifier.new,
);
