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
    final userId = await storage.read(key: _userIdKey);

    if (token == null || token.isEmpty) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    return AuthState(status: _statusFromRole(role), userId: userId);
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
    state = await AsyncValue.guard(() async {
      final client = ref.read(apiClientProvider);
      final response = await client.login(LoginRequest(email: email, password: password));
      await _persist(response);
      return AuthState(status: _statusFromRole(response.role), userId: response.userId);
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? role,
    List<String>? knownAllergies,
    List<String>? chronicIllnesses,
    PharmacyRegistrationDto? pharmacy,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(apiClientProvider);
      final response = await client.register(RegisterRequest(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        knownAllergies: knownAllergies,
        chronicIllnesses: chronicIllnesses,
        pharmacy: pharmacy,
      ));
      await _persist(response);
      return AuthState(status: _statusFromRole(response.role), userId: response.userId);
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
    ref.invalidate(apiClientProvider);
    await registerDeviceToken();
  }

  /// Stores (optional) and uploads the FCM token so push can reach this device.
  Future<void> registerDeviceToken([String? token]) async {
    final storage = ref.read(secureStorageProvider);
    if (token != null && token.isNotEmpty) {
      await storage.write(key: 'fcm_token', value: token);
    }
    final fcm = token ?? await storage.read(key: 'fcm_token');
    if (fcm == null || fcm.isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .updateDeviceToken(DeviceTokenRequest(fcmToken: fcm));
    } catch (_) {}
  }
}

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? errorMessage;

  const AuthState({required this.status, this.userId, this.errorMessage});

  bool get isAuthenticated => status != AuthStatus.unauthenticated && status != AuthStatus.unknown;
}

/// Extracts a human-readable message from a Dio error.
String describeApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      if (data['errors'] is Map) {
        final errMap = data['errors'] as Map;
        final list = <String>[];
        for (final val in errMap.values) {
          if (val is List) {
            list.addAll(val.map((e) => e.toString()));
          } else if (val != null) {
            list.add(val.toString());
          }
        }
        if (list.isNotEmpty) return list.join('\n');
      }
      if (data['detail'] != null) return data['detail'].toString();
      if (data['message'] != null) return data['message'].toString();
      if (data['title'] != null &&
          data['title'] != 'One or more validation errors occurred.') {
        return data['title'].toString();
      }
    }
    if (error.response?.statusCode == 401) return 'البريد أو كلمة المرور غير صحيحة.';
    if (error.response?.statusCode == 403) {
      return 'غير مسموح. صيدليتك ما زالت قيد مراجعة الإدارة ولم يتم اعتمادها بعد.';
    }
    if (error.response?.statusCode == 409) {
      return data is String && data.isNotEmpty ? _cleanHtml(data) : 'البيانات مسجلة بالفعل.';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'تعذر الاتصال بالخادم. يرجى التأكد من اتصال الإنترنت.';
    }
    if (data is String && data.isNotEmpty) return _cleanHtml(data);
    return 'حدث خطأ في البيانات المدخلة، يرجى المراجعة والمحاولة مرة أخرى.';
  }
  return error.toString();
}

String _cleanHtml(String s) {
  final withoutTags = s.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
  if (withoutTags.length > 200) return '${withoutTags.substring(0, 200)}…';
  return withoutTags;
}
