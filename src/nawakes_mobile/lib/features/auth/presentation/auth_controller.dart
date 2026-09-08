import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/secure_storage_provider.dart';
import 'package:nawakes_mobile/features/auth/data/auth_models.dart';

part 'auth_controller.g.dart';

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {
    // Initial state is unauthenticated (void)
  }

  Future<String?> login(String email, String password) async {
    String? role;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(apiClientProvider);
      final request = LoginRequest(email: email, password: password);
      
      final response = await client.login(request);
      role = response.role;
      
      // Securely store the JWT token
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: 'jwt_token', value: response.accessToken);
      await storage.write(key: 'refresh_token', value: response.refreshToken);
      await storage.write(key: 'user_id', value: response.userId);
      await storage.write(key: 'user_role', value: response.role);
    });
    return role;
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: 'jwt_token');
    await storage.delete(key: 'refresh_token');
    await storage.delete(key: 'user_id');
    await storage.delete(key: 'user_role');
  }

  Future<bool> isAuthenticated() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'jwt_token');
    return token != null;
  }
}
