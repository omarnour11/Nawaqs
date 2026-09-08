import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/features/auth/presentation/login_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/search_screen.dart';
import 'package:nawakes_mobile/features/search/presentation/pharmacy_details_screen.dart';
import 'package:nawakes_mobile/features/reservations/presentation/my_reservations_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/presentation/pharmacy_dashboard_screen.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/profile/presentation/profile_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/pharmacy-dashboard',
        builder: (context, state) => const PharmacyDashboardScreen(),
      ),
      GoRoute(
        path: '/my-reservations',
        builder: (context, state) => const MyReservationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/pharmacy-details',
        builder: (context, state) {
          final item = state.extra as PharmacySearchResultDto;
          return PharmacyDetailsScreen(item: item);
        },
      ),
    ],
  );
}
