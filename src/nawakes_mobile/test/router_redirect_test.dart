import 'package:flutter_test/flutter_test.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';

/// Pure logic test matching app_router.dart redirect rules
String? testRedirectLogic(AuthStatus status, String loc) {
  final inAuthFlow = loc == '/splash' || loc == '/login' || loc == '/register';

  if (status == AuthStatus.unknown) {
    return inAuthFlow ? null : '/splash';
  }
  if (status == AuthStatus.unauthenticated) {
    return inAuthFlow ? null : '/login';
  }

  // Authenticated:
  if (inAuthFlow) {
    return switch (status) {
      AuthStatus.pharmacyOwner => '/pharmacy',
      AuthStatus.admin => '/admin',
      _ => '/home',
    };
  }

  // Role-based area protection
  final inPatientArea = loc == '/home' ||
      loc == '/passes' ||
      loc == '/alerts' ||
      loc == '/family-cabinet' ||
      loc == '/profile' ||
      loc.startsWith('/support') ||
      loc.startsWith('/pass-detail') ||
      loc.startsWith('/pharmacy-details') ||
      loc.startsWith('/all-results');
  if (inPatientArea && status != AuthStatus.patient) return '/login';

  // Notifications are visible to every authenticated role (admin/pharmacy bells too)
  if (loc.startsWith('/notifications')) return null;

  final inPharmacyArea = loc == '/pharmacy' || loc.startsWith('/pharmacy/');
  if (inPharmacyArea && status != AuthStatus.pharmacyOwner) return '/login';

  final inAdminArea = loc == '/admin' || loc.startsWith('/admin/');
  if (inAdminArea && status != AuthStatus.admin) return '/login';

  return null;
}

void main() {
  group('Router area protection rules', () {
    test('Patient navigating to /pharmacy-details is NOT redirected to /login or /home', () {
      final redirect = testRedirectLogic(AuthStatus.patient, '/pharmacy-details');
      expect(redirect, isNull);
    });

    test('Patient navigating to /pharmacy area IS protected and redirected to /login', () {
      expect(testRedirectLogic(AuthStatus.patient, '/pharmacy'), equals('/login'));
      expect(testRedirectLogic(AuthStatus.patient, '/pharmacy/scan'), equals('/login'));
      expect(testRedirectLogic(AuthStatus.patient, '/pharmacy/add-inventory'), equals('/login'));
    });

    test('Pharmacy owner navigating to /pharmacy is allowed', () {
      expect(testRedirectLogic(AuthStatus.pharmacyOwner, '/pharmacy'), isNull);
      expect(testRedirectLogic(AuthStatus.pharmacyOwner, '/pharmacy/scan'), isNull);
    });

    test('Pharmacy owner navigating to patient-only area is redirected to /login', () {
      expect(testRedirectLogic(AuthStatus.pharmacyOwner, '/home'), equals('/login'));
      expect(testRedirectLogic(AuthStatus.pharmacyOwner, '/pharmacy-details'), equals('/login'));
    });
  });
}
