import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/routing/patient_shell.dart';
import 'package:nawakes_mobile/features/admin/data/admin_models.dart';
import 'package:nawakes_mobile/features/auth/presentation/auth_controller.dart';
import 'package:nawakes_mobile/features/auth/presentation/login_screen.dart';
import 'package:nawakes_mobile/features/auth/presentation/register_screen.dart';
import 'package:nawakes_mobile/features/splash/presentation/splash_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/search_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/all_results_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/pharmacy_details_screen.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/reservations/presentation/passes_screen.dart';
import 'package:nawakes_mobile/features/alerts/presentation/alerts_screen.dart';
import 'package:nawakes_mobile/features/support/presentation/support_screen.dart';
import 'package:nawakes_mobile/features/profile/presentation/profile_screen.dart';
import 'package:nawakes_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_onboarding_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/add_inventory_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/qr_scanner_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/sales_ledger_screen.dart';
import 'package:nawakes_mobile/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:nawakes_mobile/features/admin/presentation/pharmacy_review_screen.dart';
import 'package:nawakes_mobile/features/admin/presentation/admin_ticket_detail_screen.dart';
import 'package:nawakes_mobile/features/admin/presentation/admin_reports_screen.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final authNotifier = ValueNotifier<AuthStatus>(AuthStatus.unknown);

  ref.listen<AsyncValue<AuthState>>(authControllerProvider, (_, next) {
    final status = next.value?.status;
    if (status != null) authNotifier.value = status;
  });

  // Kick a load of the persisted session so listeners fire even before any UI watches it.
  Future(() => ref.read(authControllerProvider.future));

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final status = authNotifier.value;
      final loc = state.matchedLocation;

      final inAuthFlow =
          loc == '/splash' || loc == '/login' || loc == '/register';

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
          loc == '/profile' ||
          loc.startsWith('/support') ||
          loc.startsWith('/pass-detail') ||
          loc.startsWith('/pharmacy-details') ||
          loc.startsWith('/all-results');
      if (inPatientArea && status != AuthStatus.patient) return '/login';

      // Notifications are visible to every authenticated role (admin/pharmacy bells too)
      if (loc.startsWith('/notifications')) return null;

      final inPharmacyArea = loc.startsWith('/pharmacy');
      if (inPharmacyArea && status != AuthStatus.pharmacyOwner) return '/login';

      final inAdminArea = loc.startsWith('/admin');
      if (inAdminArea && status != AuthStatus.admin) return '/login';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),

      // ── Patient area ───────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => PatientShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const SearchScreen()),
          GoRoute(
              path: '/passes', builder: (context, state) => const PassesScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
          GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
        ],
      ),
      GoRoute(
        path: '/pass-detail',
        builder: (context, state) {
          final r = state.extra as ReservationResponse;
          return PassDetailScreen(reservation: r);
        },
      ),
      GoRoute(
        path: '/all-results',
        builder: (context, state) {
          final r = state.extra as AllResultsArgs;
          return AllResultsScreen(results: r.results, medicationName: r.medicationName);
        },
      ),
      GoRoute(
        path: '/pharmacy-details',
        builder: (context, state) {
          final item = state.extra as PharmacyDetailsArgs;
          return PharmacyDetailsScreen(args: item);
        },
      ),
      GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen()),

      // ── Pharmacy area ─────────────────────────────────────────────────
      GoRoute(
          path: '/pharmacy',
          builder: (context, state) => const PharmacyDashboardScreen()),
      GoRoute(
          path: '/pharmacy/onboarding',
          builder: (context, state) => const PharmacyOnboardingScreen()),
      GoRoute(
          path: '/pharmacy/add-inventory',
          builder: (context, state) => const AddInventoryScreen()),
      GoRoute(
          path: '/pharmacy/scan',
          builder: (context, state) => const QrScannerScreen()),
      GoRoute(
          path: '/pharmacy/ledger',
          builder: (context, state) => const SalesLedgerScreen()),

      // ── Admin area ────────────────────────────────────────────────────
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(
        path: '/admin/review',
        builder: (context, state) {
          final pharmacy = state.extra as AdminPharmacyDto;
          return PharmacyReviewScreen(pharmacy: pharmacy);
        },
      ),
      GoRoute(
        path: '/admin/ticket-detail',
        builder: (context, state) {
          final ticket = state.extra as AdminTicketDto;
          return AdminTicketDetailScreen(ticket: ticket);
        },
      ),
      GoRoute(
          path: '/admin/reports',
          builder: (context, state) => const AdminReportsScreen()),
    ],
  );
}
