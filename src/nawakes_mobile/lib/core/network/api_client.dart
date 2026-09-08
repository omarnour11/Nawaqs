import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retrofit/retrofit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/features/auth/data/auth_models.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/reports/data/report_models.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';
import 'package:nawakes_mobile/features/profile/data/profile_models.dart';
import 'package:nawakes_mobile/core/network/secure_storage_provider.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

part 'api_client.g.dart';

@RestApi(baseUrl: "http://localhost:5001/api/v1")
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  @POST("/auth/login")
  Future<AuthResponse> login(@Body() LoginRequest body);

  @GET("/search")
  Future<SearchMedicationResponse> searchMedications(
    @Query("medication") String medication,
    @Query("lat") double lat,
    @Query("lng") double lng,
    @Query("radius") double radius,
    @Query("sortBy") String sortBy,
  );

  @POST("/reservations")
  Future<ReservationResponse> createReservation(
    @Body() CreateReservationRequest body,
  );

  @GET("/reservations")
  Future<List<ReservationResponse>> getMyReservations();

  @DELETE("/reservations/{id}")
  Future<void> cancelReservation(@Path("id") String id);

  @POST("/pharmacies/{id}/reports")
  Future<dynamic> createReport(
    @Path("id") String pharmacyId,
    @Body() CreateReportRequest body,
  );

  @GET("/pharmacy/reservations")
  Future<List<PharmacyReservationResponse>> getPharmacyReservations();

  @PATCH("/pharmacy/reservations/{id}/complete")
  Future<PharmacyReservationResponse> completePharmacyReservation(
    @Path("id") String id,
  );

  @GET("/pharmacy/inventory")
  Future<List<PharmacyInventoryItemDto>> getPharmacyInventory();

  @POST("/pharmacy/inventory")
  Future<PharmacyInventoryItemDto> addInventoryItem(
    @Body() AddInventoryItemRequest body,
  );

  @PATCH("/pharmacy/inventory/{id}/status")
  Future<dynamic> toggleInventoryStatus(
    @Path("id") String id,
    @Body() ToggleStatusRequest body,
  );

  @GET("/profile")
  Future<ProfileResponse> getProfile();

  @PATCH("/profile")
  Future<void> updateProfile(@Body() UpdateProfileRequest body);
}

@riverpod
Dio dio(Ref ref) {
  final dio = Dio();
  // Read storage once synchronously — avoids ref-after-dispose in async interceptor
  final storage = ref.read(secureStorageProvider);

  dio.interceptors.add(LogInterceptor(responseBody: true));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: 'jwt_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          options.headers.remove('Authorization');
        }
        return handler.next(options);
      },
    ),
  );

  return dio;
}

@riverpod
ApiClient apiClient(Ref ref) {
  final dio = ref.watch(dioProvider);
  String baseUrl = 'http://localhost:5001/api/v1';
  if (!kIsWeb && Platform.isAndroid) {
    baseUrl = 'http://10.0.2.2:5001/api/v1';
  }
  return ApiClient(dio, baseUrl: baseUrl);
}
