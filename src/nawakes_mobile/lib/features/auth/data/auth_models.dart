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
  final String? gender;
  final int? age;
  final String? chronicConditions;
  final dynamic knownAllergies;
  final List<String>? chronicIllnesses;
  final PharmacyRegistrationDto? pharmacy;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    this.role,
    this.gender,
    this.age,
    this.chronicConditions,
    this.knownAllergies,
    this.chronicIllnesses,
    this.pharmacy,
  });

  Map<String, dynamic> toJson() {
    List<String>? allergiesList;
    String? allergiesStr;

    if (knownAllergies is List<String>) {
      allergiesList = knownAllergies as List<String>;
      allergiesStr = allergiesList.join('، ');
    } else if (knownAllergies is List) {
      allergiesList = (knownAllergies as List).map((e) => e.toString()).toList();
      allergiesStr = allergiesList.join('، ');
    } else if (knownAllergies is String) {
      allergiesStr = knownAllergies as String;
      allergiesList = (knownAllergies as String)
          .split(RegExp(r'[,،]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return {
      'email': email,
      'password': password,
      'fullName': fullName,
      if (role != null) 'role': role,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (chronicConditions != null) 'chronicConditions': chronicConditions,
      if (allergiesStr != null) 'knownAllergies': allergiesStr,
      if (allergiesList != null || chronicIllnesses != null)
        'healthQuestionnaire': {
          if (allergiesList != null) 'knownAllergies': allergiesList,
          if (chronicIllnesses != null) 'chronicIllnesses': chronicIllnesses,
        },
      if (pharmacy != null) 'pharmacy': pharmacy!.toJson(),
    };
  }
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

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) => _$RefreshTokenRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RefreshTokenRequestToJson(this);
}

class DeviceTokenRequest {
  final String fcmToken;

  DeviceTokenRequest({required this.fcmToken});

  Map<String, dynamic> toJson() => {'fcmToken': fcmToken};
}
