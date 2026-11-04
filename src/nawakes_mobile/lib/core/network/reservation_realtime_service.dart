import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'package:nawakes_mobile/core/config.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/secure_storage_provider.dart';

/// Live reservation tracking over SignalR (/hubs/reservations).
///
/// The hub auto-joins each connection to the `user:{userId}` group, so no
/// explicit subscription is needed for personal reservation updates. Events:
/// - `ReservationStatusUpdated` — status/delivery transitions.
/// - `QueueOfferDispatched` — 15-minute shortage queue offers.
class ReservationRealtimeService {
  ReservationRealtimeService(this._ref) {
    _connect();
  }

  final Ref _ref;
  HubConnection? _connection;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _disposed = false;

  final StreamController<ReservationStatusUpdatedEvent> _statusEvents =
      StreamController<ReservationStatusUpdatedEvent>.broadcast();
  final StreamController<QueueOfferEvent> _queueOfferEvents =
      StreamController<QueueOfferEvent>.broadcast();
  final StreamController<bool> _connectionState =
      StreamController<bool>.broadcast();

  Stream<ReservationStatusUpdatedEvent> get statusEvents => _statusEvents.stream;
  Stream<QueueOfferEvent> get queueOfferEvents => _queueOfferEvents.stream;
  Stream<bool> get connectionState => _connectionState.stream;

  Future<void> _connect() async {
    if (_disposed) return;

    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: 'jwt_token');
    if (token == null || token.isEmpty) {
      _scheduleRetry();
      return;
    }

    // Derive ws base from the active API base (http://host:port/api/v1).
    final apiBase = _ref.read(apiBaseUrlProvider);
    final hubUrl = '${_hubOrigin(apiBase)}/hubs/reservations?access_token=$token';

    final connection = HubConnectionBuilder().withUrl(hubUrl).build();
    connection.onclose(({error}) {
      _connectionState.add(false);
      _scheduleRetry();
    });

    connection.on('ReservationStatusUpdated', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final map = args.first as Map<String, dynamic>;
        _statusEvents.add(ReservationStatusUpdatedEvent.fromMap(map));
      } catch (_) {}
    });

    connection.on('QueueOfferDispatched', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final map = args.first as Map<String, dynamic>;
        _queueOfferEvents.add(QueueOfferEvent.fromMap(map));
      } catch (_) {}
    });

    try {
      await connection.start();
      _connection = connection;
      _retryAttempt = 0;
      _connectionState.add(true);
    } catch (_) {
      _connectionState.add(false);
      _scheduleRetry();
    }
  }

  /// Strips /api/v1 to get the server origin hosting the hub.
  String _hubOrigin(String apiBase) {
    var origin = apiBase;
    if (origin.contains('/api/v1')) {
      origin = origin.substring(0, origin.indexOf('/api/v1'));
    }
    return origin;
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retryTimer?.cancel();
    final delay = Duration(seconds: (2 << _retryAttempt.clamp(0, 4)).clamp(2, 32));
    _retryAttempt++;
    _retryTimer = Timer(delay, _connect);
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    try {
      await _connection?.stop();
    } catch (_) {}
    await _statusEvents.close();
    await _queueOfferEvents.close();
    await _connectionState.close();
  }
}

/// Minimal typed payloads (server serializes camelCase JSON objects).
class ReservationStatusUpdatedEvent {
  final String reservationId;
  final String pharmacyId;
  final String pharmacyName;
  final String medicationName;
  final String status;
  final String? deliveryStatus;
  final String reservationCode;
  final DateTime? expiresAt;

  ReservationStatusUpdatedEvent({
    required this.reservationId,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.medicationName,
    required this.status,
    this.deliveryStatus,
    required this.reservationCode,
    this.expiresAt,
  });

  factory ReservationStatusUpdatedEvent.fromMap(Map<String, dynamic> map) {
    return ReservationStatusUpdatedEvent(
      reservationId: map['reservationId']?.toString() ?? '',
      pharmacyId: map['pharmacyId']?.toString() ?? '',
      pharmacyName: map['pharmacyName']?.toString() ?? '',
      medicationName: map['medicationName']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      deliveryStatus: map['deliveryStatus']?.toString(),
      reservationCode: map['reservationCode']?.toString() ?? '',
      expiresAt: map['expiresAt'] == null
          ? null
          : DateTime.tryParse(map['expiresAt'].toString()),
    );
  }
}

class QueueOfferEvent {
  final String pharmacyName;
  final String medicationName;
  final double price;
  final DateTime? offerExpiresAt;

  QueueOfferEvent({
    required this.pharmacyName,
    required this.medicationName,
    required this.price,
    this.offerExpiresAt,
  });

  factory QueueOfferEvent.fromMap(Map<String, dynamic> map) {
    return QueueOfferEvent(
      pharmacyName: map['pharmacyName']?.toString() ?? '',
      medicationName: map['medicationName']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      offerExpiresAt: map['offerExpiresAt'] == null
          ? null
          : DateTime.tryParse(map['offerExpiresAt'].toString()),
    );
  }
}

/// Base URL provider mirroring the active endpoint the Dio client settled on,
/// so the hub always hits the same host the REST calls succeed against.
/// Watches the Dio provider so endpoint failover (loopback ↔ LAN) re-triggers it.
final apiBaseUrlProvider = Provider<String>((ref) {
  ref.watch(dioProvider);
  final active = AppConfig.apiBaseUrl;
  return active;
});

/// Keep-alive realtime service (never auto-disposed).
final reservationRealtimeProvider = Provider<ReservationRealtimeService>((ref) {
  final service = ReservationRealtimeService(ref);
  ref.onDispose(service.dispose);
  return service;
});
