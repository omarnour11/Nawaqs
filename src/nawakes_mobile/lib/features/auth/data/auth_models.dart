import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_models.g.dart';

@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

class RegisterRequest {
  final String email;
  final String password;
  final String fullName;
  final String? role;
  final List<String>? knownAllergies;
  final List<String>? chronicIllnesses;
  final PharmacyRegistrationDto? pharmacy;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    this.role,
    this.knownAllergies,
    this.chronicIllnesses,
    this.pharmacy,
  });

  // factory RegisterRequest.fromJson not needed

  /// API expects nested `healthQuestionnaire` and optional `pharmacy` details.
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'fullName': fullName,
        if (role != null) 'role': role,
        if (knownAllergies != null || chronicIllnesses != null)
          'healthQuestionnaire': {
            'knownAllergies': knownAllergies,
            'chronicIllnesses': chronicIllnesses,
          },
        if (pharmacy != null) 'pharmacy': pharmacy!.toJson(),
      };
}

class PharmacyRegistrationDto {
  final String name;
  final String addressLine;
  final String city;
  final String phone;
  final double? latitude;
  final double? longitude;
  final String? licenseDocUrl;
  final String? nationalIdDocUrl;

  const PharmacyRegistrationDto({
    required this.name,
    required this.addressLine,
    required this.city,
    required this.phone,
    this.latitude,
    this.longitude,
    this.licenseDocUrl,
    this.nationalIdDocUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'addressLine': addressLine,
        'city': city,
        'phone': phone,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (licenseDocUrl != null) 'licenseDocUrl': licenseDocUrl,
        if (nationalIdDocUrl != null) 'nationalIdDocUrl': nationalIdDocUrl,
      };
}

@JsonSerializable()
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String role;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

@JsonSerializable()
class RefreshTokenRequest {
  final String refreshToken;

  RefreshTokenRequest({required this.refreshToken});

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RefreshTokenRequestToJson(this);
}

class DeviceTokenRequest {
  final String fcmToken;

  DeviceTokenRequest({required this.fcmToken});

  Map<String, dynamic> toJson() => {'fcmToken': fcmToken};
}
