import 'package:dio/dio.dart' show DioException, DioExceptionType;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/secure_storage_provider.dart';
import 'package:nawakes_mobile/features/auth/data/auth_models.dart';

part 'auth_controller.g.dart';

/// Auth statuses used by the router to guard routes.
enum AuthStatus { unknown, unauthenticated, patient, pharmacyOwner, admin }

@riverpod
class AuthController extends _$AuthController {
  static const _tokenKey = 'jwt_token';
  static const _refreshKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _roleKey = 'user_role';

  @override
  Future<AuthState> build() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: _tokenKey);
    final role = await storage.read(key: _roleKey);

    if (token == null || token.isEmpty) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    return AuthState(status: _statusFromRole(role));
  }

  static AuthStatus _statusFromRole(String? role) {
    switch (role) {
      case 'PharmacyOwner':
        return AuthStatus.pharmacyOwner;
      case 'Admin':
        return AuthStatus.admin;
      case 'Patient':
        return AuthStatus.patient;
      default:
        return AuthStatus.unauthenticated;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    await AsyncValue.guard(() async {
      final client = ref.read(apiClientProvider);
      final response = await client.login(LoginRequest(email: email, password: password));
      await _persist(response);
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    List<String>? knownAllergies,
    List<String>? chronicIllnesses,
  }) async {
    state = const AsyncValue.loading();
    await AsyncValue.guard(() async {
      final client = ref.read(apiClientProvider);
      final response = await client.register(RegisterRequest(
        email: email,
        password: password,
        fullName: fullName,
        knownAllergies: knownAllergies,
        chronicIllnesses: chronicIllnesses,
      ));
      await _persist(response);
    });
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    final refresh = await storage.read(key: _refreshKey);
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await ref.read(apiClientProvider).logout(RefreshTokenRequest(refreshToken: refresh));
      }
    } catch (_) {
      // Server-side revoke is best-effort; local session is cleared regardless.
    }
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _refreshKey);
    await storage.delete(key: _userIdKey);
    await storage.delete(key: _roleKey);
    state = const AsyncValue.data(AuthState(status: AuthStatus.unauthenticated));
    ref.invalidate(apiClientProvider);
  }

  Future<void> _persist(AuthResponse response) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: _tokenKey, value: response.accessToken);
    await storage.write(key: _refreshKey, value: response.refreshToken);
    await storage.write(key: _userIdKey, value: response.userId);
    await storage.write(key: _roleKey, value: response.role);
    state = AsyncValue.data(AuthState(status: _statusFromRole(response.role)));
    ref.invalidate(apiClientProvider);
  }
}

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({required this.status, this.errorMessage});

  bool get isAuthenticated => status != AuthStatus.unauthenticated && status != AuthStatus.unknown;
}

/// Extracts a human-readable message from a Dio error.
String describeApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    if (data is Map && data['title'] != null) return data['title'].toString();
    if (error.response?.statusCode == 401) return 'Invalid email or password.';
    if (error.response?.statusCode == 409) {
      return data is String && data.isNotEmpty ? _cleanHtml(data) : 'Already exists.';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the server. Check your connection and try again.';
    }
    if (data is String && data.isNotEmpty) return _cleanHtml(data);
    return 'Something went wrong. Please try again.';
  }
  return error.toString();
}

String _cleanHtml(String s) {
  final withoutTags = s.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
  if (withoutTags.length > 200) return '${withoutTags.substring(0, 200)}…';
  return withoutTags;
}
