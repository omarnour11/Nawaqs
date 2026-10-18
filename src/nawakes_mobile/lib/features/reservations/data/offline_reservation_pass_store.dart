import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';

const _key = 'offline_reservation_passes';
const _storage = FlutterSecureStorage();

/// Caches active reservation passes so patients can still show their pickup
/// code and QR in basement pharmacies with no cell reception.
class OfflineReservationPassStore {
  Future<void> saveActive(List<ReservationResponse> reservations) async {
    final active = reservations
        .where((r) => r.status == 'Active' || r.status == 'Ready')
        .map((r) => jsonEncode(r.toJson()))
        .toList();
    await _storage.write(key: _key, value: jsonEncode(active));
  }

  Future<List<ReservationResponse>> loadActive() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ReservationResponse.fromJson(jsonDecode(e as String) as Map<String, dynamic>))
          .toList();
      // Drop passes whose 2-hour hold has already elapsed.
      final now = DateTime.now().toUtc();
      return list.where((r) => r.expiresAt.isAfter(now)).toList();
    } catch (_) {
      return [];
    }
  }
}
