import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' show FlutterSecureStorage;
import 'package:json_annotation/json_annotation.dart';
import 'package:retrofit/retrofit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/config.dart';
import 'package:nawakes_mobile/core/network/secure_storage_provider.dart';
import 'package:nawakes_mobile/features/auth/data/auth_models.dart';
import 'package:nawakes_mobile/features/search/data/search_models.dart';
import 'package:nawakes_mobile/features/reservations/data/reservation_models.dart';
import 'package:nawakes_mobile/features/reports/data/report_models.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_dashboard_models.dart';
import 'package:nawakes_mobile/features/pharmacy/data/pharmacy_profile_models.dart';
import 'package:nawakes_mobile/features/profile/data/profile_models.dart';
import 'package:nawakes_mobile/features/notifications/data/notification_models.dart';
import 'package:nawakes_mobile/features/alerts/data/alert_models.dart';
import 'package:nawakes_mobile/features/favorites/data/favorite_models.dart';
import 'package:nawakes_mobile/features/admin/data/admin_models.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';
import 'package:nawakes_mobile/features/profile/data/medication_models.dart';
import 'package:nawakes_mobile/features/pharmacy/data/sales_ledger_models.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';

part 'api_client.g.dart';

@RestApi(baseUrl: "http://localhost:5001/api/v1")
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  // ── Auth ───────────────────────────────────────────────────────────────
  @POST("/auth/login")
  Future<AuthResponse> login(@Body() LoginRequest body);

  @POST("/auth/register")
  Future<AuthResponse> register(@Body() RegisterRequest body);

  @POST("/auth/refresh")
  Future<AuthResponse> refreshToken(@Body() RefreshTokenRequest body);

  @POST("/auth/logout")
  Future<void> logout(@Body() RefreshTokenRequest body);

  // ── Search ─────────────────────────────────────────────────────────────
  @GET("/search")
  Future<SearchMedicationResponse> searchMedications(
    @Query("medication") String medication,
    @Query("lat") double lat,
    @Query("lng") double lng,
    @Query("radius") double radius,
    @Query("sortBy") String sortBy,
  );

  @GET("/search/suggest")
  Future<List<String>> suggestMedications(@Query("prefix") String prefix);

  @POST("/search/parse-multimodal")
  Future<ParsedMedicationResponse> parseMultimodal(@Body() ParseMultimodalBody body);

  @GET("/search/equivalents")
  Future<MedicationEquivalentsResponse> getMedicationEquivalents(
    @Query("medicationName") String medicationName,
    @Query("lat") double lat,
    @Query("lng") double lng,
    @Query("radiusKm") double radiusKm,
  );

  // ── Reservations (patient) ─────────────────────────────────────────────
  @POST("/reservations")
  Future<ReservationResponse> createReservation(@Body() CreateReservationRequest body);

  @GET("/reservations")
  Future<List<ReservationResponse>> getMyReservations();

  @DELETE("/reservations/{id}")
  Future<void> cancelReservation(@Path("id") String id);

  // ── Pharmacies (patient-facing) ────────────────────────────────────────
  @GET("/pharmacies/{id}")
  Future<PharmacyDetailDto> getPharmacyDetail(@Path("id") String id);

  @POST("/pharmacies/{id}/reports")
  Future<dynamic> createReport(@Path("id") String pharmacyId, @Body() CreateReportRequest body);

  @PUT("/pharmacies/{id}/rating")
  Future<void> ratePharmacy(@Path("id") String pharmacyId, @Body() RatePharmacyRequest body);

  @POST("/pharmacies/{id}/favorite")
  Future<ToggleFavoriteResponse> toggleFavorite(@Path("id") String pharmacyId);

  @GET("/pharmacies/favorites")
  Future<List<FavoritePharmacyDto>> getMyFavorites();

  // ── Alerts (availability subscriptions) ────────────────────────────────
  @POST("/subscriptions")
  Future<IdResponse> createAlert(@Body() CreateAlertRequest body);

  @GET("/subscriptions")
  Future<List<AlertDto>> getMyAlerts();

  @DELETE("/subscriptions/{id}")
  Future<void> deleteAlert(@Path("id") String id);

  // ── Notifications ──────────────────────────────────────────────────────
  @GET("/notifications")
  Future<List<NotificationDto>> getNotifications();

  @GET("/notifications/unread-count")
  Future<UnreadCountResponse> getUnreadCount();

  @POST("/notifications/mark-read")
  Future<MarkReadResponse> markNotificationsRead(@Body() MarkReadRequest body);

  // ── Pharmacy dashboard ─────────────────────────────────────────────────
  @GET("/pharmacy/reservations")
  Future<List<PharmacyReservationResponse>> getPharmacyReservations();

  @PATCH("/pharmacy/reservations/{id}/complete")
  Future<PharmacyReservationResponse> completePharmacyReservation(@Path("id") String id);

  @PATCH("/pharmacy/reservations/{id}/ready")
  Future<PharmacyReservationResponse> markReservationReady(@Path("id") String id);

  @PATCH("/pharmacy/reservations/{id}/cancel")
  Future<void> cancelReservationByPharmacy(
    @Path("id") String id,
    @Body() CancelByPharmacyRequest body,
  );

  @GET("/pharmacy/inventory")
  Future<List<PharmacyInventoryItemDto>> getPharmacyInventory();

  @POST("/pharmacy/inventory")
  Future<PharmacyInventoryItemDto> addInventoryItem(@Body() AddInventoryItemRequest body);

  @PATCH("/pharmacy/inventory/{id}/status")
  Future<dynamic> toggleInventoryStatus(
    @Path("id") String id,
    @Body() ToggleStatusRequest body,
  );

  @PATCH("/pharmacy/inventory/{id}/availability")
  Future<dynamic> setAvailability(
    @Path("id") String id,
    @Body() SetAvailabilityRequest body,
  );

  // ── Pharmacy profile (onboarding) ──────────────────────────────────────
  @GET("/pharmacy/profile")
  Future<MyPharmacyDto?> getMyPharmacy();

  @POST("/pharmacy/profile")
  Future<IdResponse> registerPharmacy(@Body() RegisterPharmacyRequest body);

  // ── Profile ────────────────────────────────────────────────────────────
  @GET("/profile")
  Future<ProfileResponse> getProfile();

  @PATCH("/profile")
  Future<void> updateProfile(@Body() UpdateProfileRequest body);

  // ── Admin ──────────────────────────────────────────────────────────────
  @GET("/admin/stats")
  Future<DashboardStatsDto> getAdminStats();

  @GET("/admin/pharmacies")
  Future<List<AdminPharmacyDto>> getAdminPharmacies(@Query("all") bool all);

  @POST("/admin/pharmacies/{id}/review")
  Future<void> reviewPharmacy(@Path("id") String id, @Body() ReviewPharmacyRequest body);

  @GET("/admin/reports")
  Future<List<AdminReportDto>> getAdminReports(@Query("pendingOnly") bool pendingOnly);

  @POST("/admin/reports/{id}/review")
  Future<void> reviewReport(@Path("id") String id, @Body() ReviewReportRequest body);

  // ── Support tickets ────────────────────────────────────────────────────
  @POST("/support")
  Future<IdResponse> createTicket(@Body() CreateTicketRequest body);

  @GET("/support")
  Future<List<TicketDto>> getMyTickets();

  // ── Medications (patient regimen) ─────────────────────────────────────
  @GET("/profile/medications")
  Future<List<PatientMedicationDto>> getMyMedications();

  @POST("/profile/medications")
  Future<IdResponse> addMyMedication(@Body() MedicationRequest body);

  @PUT("/profile/medications/{id}")
  Future<void> updateMyMedication(@Path("id") String id, @Body() MedicationRequest body);

  @DELETE("/profile/medications/{id}")
  Future<void> deleteMyMedication(@Path("id") String id);

  // ── Shortage broadcast ────────────────────────────────────────────────
  @POST("/shortage")
  Future<IdResponse> createShortageRequest(@Body() CreateShortageRequest body);

  @GET("/shortage/open")
  Future<List<ShortageRequestDto>> getOpenShortageRequests(
    @Query("lat") double lat,
    @Query("lng") double lng,
    @Query("radiusKm") double radiusKm,
  );

  @POST("/shortage/{id}/claim")
  Future<ClaimShortageResponse> claimShortageRequest(@Path("id") String id);

  // ── Forgot / reset password ───────────────────────────────────────────
  @POST("/auth/forgot-password")
  Future<ForgotPasswordResponse> forgotPassword(@Body() ForgotPasswordRequest body);

  @POST("/auth/reset-password")
  Future<void> resetPassword(@Body() ResetPasswordRequest body);

  @GET("/support/queue")
  Future<List<AdminTicketDto>> getAdminTicketQueue();

  @POST("/support/{id}/resolve")
  Future<void> resolveTicket(@Path("id") String id, @Body() ResolveTicketRequest body);

  @GET("/support/{id}/messages")
  Future<List<TicketMessageDto>> getTicketMessages(@Path("id") String id);

  @POST("/support/{id}/messages")
  Future<IdResponse> postTicketMessage(
    @Path("id") String id,
    @Body() PostMessageRequest body,
  );

  // ── Sales ledger (pharmacy) ───────────────────────────────────────────
  @GET("/pharmacy/reservations/ledger")
  Future<SalesLedgerDto> getSalesLedger({@Query("take") int take = 100});

  // ── Family cabinet ─────────────────────────────────────────────────────
  @GET("/family-cabinets")
  Future<FamilyCabinetResponseModel> getFamilyCabinet();

  @POST("/family-cabinets")
  Future<IdResponse> createFamilyProfile(@Body() CreateFamilyProfileRequest body);

  @POST("/family-cabinets/{profileId}/medications")
  Future<IdResponse> addFamilyMedication(
    @Path("profileId") String profileId,
    @Body() FamilyMedicationRequest body,
  );

  @POST("/family-cabinets/medications/{id}/refill")
  Future<IdResponse> refillFamilyMedication(
    @Path("id") String id,
    @Body() RefillFamilyMedicationRequest body,
  );

  @POST("/family-cabinets/{profileId}/invite")
  Future<IdResponse> inviteCaregiver(
    @Path("profileId") String profileId,
    @Body() InviteCaregiverRequest body,
  );
}

@JsonSerializable()
class CancelByPharmacyRequest {
  final String? reason;

  CancelByPharmacyRequest({this.reason});

  factory CancelByPharmacyRequest.fromJson(Map<String, dynamic> json) =>
      _$CancelByPharmacyRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CancelByPharmacyRequestToJson(this);
}

@JsonSerializable()
class PharmacyDetailDto {
  final String id;
  final String name;
  final String addressLine;
  final String city;
  final String phone;
  final double trustScore;
  final String verificationStatus;
  final double latitude;
  final double longitude;
  final String directionsUrl;
  final DateTime createdAt;

  PharmacyDetailDto({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.city,
    required this.phone,
    required this.trustScore,
    required this.verificationStatus,
    required this.latitude,
    required this.longitude,
    required this.directionsUrl,
    required this.createdAt,
  });

  factory PharmacyDetailDto.fromJson(Map<String, dynamic> json) =>
      _$PharmacyDetailDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PharmacyDetailDtoToJson(this);
}

@JsonSerializable()
class RatePharmacyRequest {
  final int score;
  final String? comment;

  RatePharmacyRequest({required this.score, this.comment});

  factory RatePharmacyRequest.fromJson(Map<String, dynamic> json) =>
      _$RatePharmacyRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RatePharmacyRequestToJson(this);
}

@JsonSerializable()
class MarkReadRequest {
  final String? id;

  MarkReadRequest({this.id});

  factory MarkReadRequest.fromJson(Map<String, dynamic> json) => _$MarkReadRequestFromJson(json);
  Map<String, dynamic> toJson() => _$MarkReadRequestToJson(this);
}

@riverpod
Dio dio(Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  final storage = ref.read(secureStorageProvider);

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.read(key: 'jwt_token');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      } else {
        options.headers.remove('Authorization');
      }
      handler.next(options);
    },
    onError: (e, handler) async {
      // 401 → single-flight token refresh, then retry the original request
      if (e.response?.statusCode == 401 &&
          e.requestOptions.extra['retried'] != true &&
          !(e.requestOptions.path.contains('/auth/'))) {
        final refreshed = await _tryRefreshToken(storage, dio);
        if (refreshed) {
          final opts = e.requestOptions;
          opts.extra['retried'] = true;
          final token = await storage.read(key: 'jwt_token');
          opts.headers['Authorization'] = 'Bearer $token';
          try {
            final response = await dio.fetch(opts);
            return handler.resolve(response);
          } catch (retryError) {
            return handler.next(retryError is DioException
                ? retryError
                : DioException(requestOptions: opts, error: retryError));
          }
        }
      }
      handler.next(e);
    },
  ));

  return dio;
}

Future<bool> _tryRefreshToken(FlutterSecureStorage storage, Dio dio) async {
  try {
    final refresh = await storage.read(key: 'refresh_token');
    if (refresh == null || refresh.isEmpty) return false;

    final resp = await dio.post('/auth/refresh', data: {'refreshToken': refresh});
    final auth = AuthResponse.fromJson(resp.data as Map<String, dynamic>);
    await storage.write(key: 'jwt_token', value: auth.accessToken);
    await storage.write(key: 'refresh_token', value: auth.refreshToken);
    return true;
  } catch (_) {
    return false;
  }
}

@riverpod
ApiClient apiClient(Ref ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio, baseUrl: AppConfig.apiBaseUrl);
}
