import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_service.g.dart';

class LocationSuggestion {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final String? governorate;

  const LocationSuggestion({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.governorate,
  });

  String get fullLabel => subtitle.isNotEmpty ? '$title، $subtitle' : title;
}

String normalizeArabic(String text) {
  return text
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '') // remove tashkeel
      .replaceAll(RegExp(r'[إأآا]'), 'ا') // normalize alef with hamza
      .replaceAll(RegExp(r'[يى]'), 'ي') // normalize alef maksura / yaa
      .replaceAll('ة', 'ه') // normalize teh marbuta
      .replaceAll('ؤ', 'و') // normalize waw with hamza
      .replaceAll('ئ', 'ي') // normalize yaa with hamza
      .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ') // remove punctuation
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

const List<LocationSuggestion> curatedEgyptianPlaces = [
  // ── 6th of October & Sheikh Zayed ─────────────────────────
  LocationSuggestion(
    title: 'الحي المتميز',
    subtitle: '6 أكتوبر، الجيزة',
    latitude: 29.9870,
    longitude: 30.9420,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'الحي الأول',
    subtitle: 'مدينة 6 أكتوبر، الجيزة',
    latitude: 29.9735,
    longitude: 30.9380,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'الشيخ زايد',
    subtitle: 'هايبر وان والحي الأول، الجيزة',
    latitude: 30.0150,
    longitude: 30.9850,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'ميدان الحصري',
    subtitle: '6 أكتوبر، الجيزة',
    latitude: 29.9722,
    longitude: 30.9455,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'الحي الثاني',
    subtitle: 'مدينة 6 أكتوبر، الجيزة',
    latitude: 29.9750,
    longitude: 30.9470,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'الحي الثالث',
    subtitle: 'مدينة 6 أكتوبر، الجيزة',
    latitude: 29.9680,
    longitude: 30.9410,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'الحي الرابع',
    subtitle: 'مدينة 6 أكتوبر، الجيزة',
    latitude: 29.9620,
    longitude: 30.9480,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'الحي الخامس',
    subtitle: 'مدينة 6 أكتوبر، الجيزة',
    latitude: 29.9650,
    longitude: 30.9570,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'الحي السابع',
    subtitle: 'مدينة 6 أكتوبر، الجيزة',
    latitude: 29.9810,
    longitude: 30.9530,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'الحي الثامن',
    subtitle: 'مدينة 6 أكتوبر، الجيزة',
    latitude: 29.9890,
    longitude: 30.9620,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'حدائق أكتوبر',
    subtitle: 'طريق الواحات والمنطقة السياحية، الجيزة',
    latitude: 29.9350,
    longitude: 31.0200,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'بيفرلي هيلز',
    subtitle: 'الشيخ زايد، الجيزة',
    latitude: 30.0650,
    longitude: 30.9400,
    governorate: 'الجيزة',
  ),

  // ── Giza Hubs ─────────────────────────────────────────────
  LocationSuggestion(
    title: 'شارع الهرم',
    subtitle: 'مشعل والمطبعة ومحطة نصر الدين، الجيزة',
    latitude: 29.9972,
    longitude: 31.1856,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'شارع فيصل',
    subtitle: 'العشرين وحسن محمد والعريش، الجيزة',
    latitude: 30.0075,
    longitude: 31.1780,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'حدائق الأهرام',
    subtitle: 'هضبة الأهرام والبوابات، الجيزة',
    latitude: 29.9720,
    longitude: 31.1150,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'الدقي والعجوزة',
    subtitle: 'ميدان المساحة ومصدق، الجيزة',
    latitude: 30.0380,
    longitude: 31.2120,
    governorate: 'الجيزة',
  ),
  LocationSuggestion(
    title: 'المهندسين',
    subtitle: 'شارع جامعة الدول وميدان سفنكس، الجيزة',
    latitude: 30.0540,
    longitude: 31.2000,
    governorate: 'الجيزة',
  ),

  // ── Cairo Hubs ────────────────────────────────────────────
  LocationSuggestion(
    title: 'التجمع الخامس',
    subtitle: 'شارع التسعين، القاهرة الجديدة',
    latitude: 30.0074,
    longitude: 31.4313,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'التجمع الأول',
    subtitle: 'محور السادات والياسمين، القاهرة الجديدة',
    latitude: 30.0610,
    longitude: 31.4550,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'مدينة الرحاب',
    subtitle: 'السوق التجاري وبوابة 6، القاهرة',
    latitude: 30.0570,
    longitude: 31.4920,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'مدينتي',
    subtitle: 'ساوث بارك والكرافت زون، القاهرة',
    latitude: 30.0980,
    longitude: 31.6260,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'مدينة الشروق',
    subtitle: 'طريق السويس والجامعة البريطانية، القاهرة',
    latitude: 30.1250,
    longitude: 31.6150,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'المعادي',
    subtitle: 'شارع 9 وثكنات المعادي، القاهرة',
    latitude: 29.9590,
    longitude: 31.2610,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'زهراء المعادي',
    subtitle: 'الشطر العاشر والشارع التجاري، القاهرة',
    latitude: 29.9700,
    longitude: 31.3050,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'المقطم',
    subtitle: 'شارع 9 وميدان النافورة، القاهرة',
    latitude: 30.0100,
    longitude: 31.3050,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'مدينة نصر',
    subtitle: 'مكرم عبيد وعباس العقاد، القاهرة',
    latitude: 30.0560,
    longitude: 31.3450,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'مصر الجديدة',
    subtitle: 'ميدان روكسي والكوربة، القاهرة',
    latitude: 30.0910,
    longitude: 31.3250,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'الزمالك',
    subtitle: 'شارع 26 يوليو وماريوت، القاهرة',
    latitude: 30.0610,
    longitude: 31.2200,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'وسط البلد',
    subtitle: 'ميدان التحرير وطلعت حرب، القاهرة',
    latitude: 30.0444,
    longitude: 31.2357,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'شبرا',
    subtitle: 'دوران شبرا وشارع شبرا، القاهرة',
    latitude: 30.0820,
    longitude: 31.2480,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'حلوان',
    subtitle: 'ميدان المحطة والحديقة اليابانية، القاهرة',
    latitude: 29.8450,
    longitude: 31.3350,
    governorate: 'القاهرة',
  ),
  LocationSuggestion(
    title: 'العبور',
    subtitle: 'الحي الأول وسوق العبور، القليوبية',
    latitude: 30.2250,
    longitude: 31.4700,
    governorate: 'القليوبية',
  ),
  LocationSuggestion(
    title: 'العاشر من رمضان',
    subtitle: 'الموقف الجديد وصيدناوي، الشرقية',
    latitude: 30.3000,
    longitude: 31.7400,
    governorate: 'الشرقية',
  ),
  LocationSuggestion(
    title: 'العاصمة الإدارية',
    subtitle: 'الحي الحكومي والبرج الأيقوني، القاهرة',
    latitude: 30.0200,
    longitude: 31.7000,
    governorate: 'القاهرة',
  ),

  // ── Alexandria & Coastal ──────────────────────────────────
  LocationSuggestion(
    title: 'سموحة',
    subtitle: 'سيدي جابر، الإسكندرية',
    latitude: 31.2150,
    longitude: 29.9530,
    governorate: 'الإسكندرية',
  ),
  LocationSuggestion(
    title: 'محطة الرمل',
    subtitle: 'وسط البلد، الإسكندرية',
    latitude: 31.2001,
    longitude: 29.9010,
    governorate: 'الإسكندرية',
  ),
  LocationSuggestion(
    title: 'ميامي وسيدي بشر',
    subtitle: 'شارع جمال عبد الناصر، الإسكندرية',
    latitude: 31.2650,
    longitude: 29.9950,
    governorate: 'الإسكندرية',
  ),

  // ── Delta & Canal ─────────────────────────────────────────
  LocationSuggestion(
    title: 'المنصورة',
    subtitle: 'المشاية السفلية والجامعة، الدقهلية',
    latitude: 31.0409,
    longitude: 31.3785,
    governorate: 'الدقهلية',
  ),
  LocationSuggestion(
    title: 'طنطا',
    subtitle: 'شارع البحر والمحطة، الغربية',
    latitude: 30.7865,
    longitude: 31.0004,
    governorate: 'الغربية',
  ),
  LocationSuggestion(
    title: 'الزقازيق',
    subtitle: 'ميدان القومية، الشرقية',
    latitude: 30.5877,
    longitude: 31.5020,
    governorate: 'الشرقية',
  ),
  LocationSuggestion(
    title: 'بنها',
    subtitle: 'الأهرام والفلل، القليوبية',
    latitude: 30.4660,
    longitude: 31.1853,
    governorate: 'القليوبية',
  ),
  LocationSuggestion(
    title: 'شبين الكوم',
    subtitle: 'البر الشرقي والجامعة، المنوفية',
    latitude: 30.5526,
    longitude: 31.0101,
    governorate: 'المنوفية',
  ),
  LocationSuggestion(
    title: 'الإسماعيلية',
    subtitle: 'نمرة 6 وشارع السلطان حسين، الإسماعيلية',
    latitude: 30.5965,
    longitude: 32.2715,
    governorate: 'الإسماعيلية',
  ),
  LocationSuggestion(
    title: 'بورسعيد',
    subtitle: 'طرح البحر والممشى السياحي، بورسعيد',
    latitude: 31.2653,
    longitude: 32.3019,
    governorate: 'بورسعيد',
  ),
  LocationSuggestion(
    title: 'السويس',
    subtitle: 'بورتوفيق وكورنيش السويس الجديد، السويس',
    latitude: 29.9668,
    longitude: 32.5498,
    governorate: 'السويس',
  ),

  // ── Upper Egypt ───────────────────────────────────────────
  LocationSuggestion(
    title: 'أسيوط',
    subtitle: 'شارع الجمهورية والمحطة، أسيوط',
    latitude: 27.1783,
    longitude: 31.1859,
    governorate: 'أسيوط',
  ),
  LocationSuggestion(
    title: 'سوهاج',
    subtitle: 'الكورنيش الشرقي، سوهاج',
    latitude: 26.5590,
    longitude: 31.6957,
    governorate: 'سوهاج',
  ),
];

class LocationService {
  final Dio _dio;

  LocationService({Dio? dio}) : _dio = dio ?? Dio();

  Future<Position?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return await Geolocator.getLastKnownPosition();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return await Geolocator.getLastKnownPosition();
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1&accept-language=ar';
      final resp = await _dio.get(
        url,
        options: Options(
          headers: {'User-Agent': 'NawaqsEgypt/1.0 (contact@nawaqs.eg)'},
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (resp.data is Map<String, dynamic>) {
        final data = resp.data as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};
        final displayName = (data['display_name'] as String? ?? '').trim();

        final local = address['neighbourhood'] ??
            address['suburb'] ??
            address['quarter'] ??
            address['road'] ??
            address['residential'] ??
            address['village'];
        final city = address['city'] ??
            address['town'] ??
            address['county'] ??
            address['state'] ??
            address['governorate'];

        if (local != null && city != null && local.toString().trim() != city.toString().trim()) {
          return '${local.toString().trim()}، ${city.toString().trim()}';
        } else if (local != null) {
          return local.toString().trim();
        } else if (city != null) {
          return city.toString().trim();
        } else if (displayName.isNotEmpty) {
          final parts = displayName
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty && s != 'مصر' && !RegExp(r'^\d+$').hasMatch(s))
              .take(2)
              .toList();
          if (parts.isNotEmpty) {
            return parts.join('، ');
          }
        }
      }
    } catch (_) {}

    // Fallback: match nearest curated place if within 15km
    try {
      LocationSuggestion? bestMatch;
      double minDistance = 15000; // 15 km in meters
      for (final place in curatedEgyptianPlaces) {
        final d = Geolocator.distanceBetween(lat, lng, place.latitude, place.longitude);
        if (d < minDistance) {
          minDistance = d;
          bestMatch = place;
        }
      }
      if (bestMatch != null) {
        return '${bestMatch.title}، ${bestMatch.subtitle}';
      }
    } catch (_) {}

    return null;
  }

  Future<List<LocationSuggestion>> searchPlaces(
    String query, {
    double? centerLat,
    double? centerLng,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    // 1. Normalized multi-token matching over curated Egyptian catalog
    final normQuery = normalizeArabic(cleanQuery);
    final queryTokens = normQuery.split(' ').where((s) => s.isNotEmpty).toList();

    final localMatches = curatedEgyptianPlaces.where((p) {
      if (queryTokens.isEmpty) return false;
      final combined = normalizeArabic('${p.title} ${p.subtitle} ${p.governorate ?? ''}');
      return queryTokens.every((token) => combined.contains(token));
    }).toList();

    // 2. Query Nominatim for live suggestions
    try {
      String url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&addressdetails=1&countrycodes=eg&limit=8&accept-language=ar';
      if (centerLat != null && centerLng != null) {
        final minLon = centerLng - 0.45;
        final maxLon = centerLng + 0.45;
        final minLat = centerLat - 0.45;
        final maxLat = centerLat + 0.45;
        url += '&viewbox=$minLon,$maxLat,$maxLon,$minLat';
      }

      var resp = await _dio.get(
        url,
        options: Options(
          headers: {'User-Agent': 'NawaqsEgypt/1.0 (contact@nawaqs.eg)'},
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

      List listData = [];
      if (resp.data is List && (resp.data as List).isNotEmpty) {
        listData = resp.data as List;
      } else if (centerLat != null && centerLng != null) {
        // Fallback search across Egypt without viewbox restriction
        final fallbackUrl =
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&addressdetails=1&countrycodes=eg&limit=8&accept-language=ar';
        final fallbackResp = await _dio.get(
          fallbackUrl,
          options: Options(
            headers: {'User-Agent': 'NawaqsEgypt/1.0 (contact@nawaqs.eg)'},
            sendTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        );
        if (fallbackResp.data is List) {
          listData = fallbackResp.data as List;
        }
      }

      final networkResults = <LocationSuggestion>[];
      for (final item in listData) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final displayName = (item['display_name'] as String? ?? '').trim();
        final address = item['address'] as Map<String, dynamic>? ?? {};

        final mainName = address['amenity'] ??
            address['building'] ??
            address['road'] ??
            address['suburb'] ??
            address['neighbourhood'] ??
            address['quarter'] ??
            address['village'] ??
            address['town'] ??
            address['city'];

        final parts = displayName
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        String title;
        String subtitle;

        if (mainName != null && mainName.toString().trim().isNotEmpty) {
          title = mainName.toString().trim();
          final remaining = parts
              .where((p) =>
                  p != title &&
                  p != 'مصر' &&
                  !RegExp(r'^\d+$').hasMatch(p))
              .take(2)
              .join('، ');
          subtitle = remaining.isNotEmpty
              ? remaining
              : (parts.length > 1 ? parts[1] : '');
        } else if (parts.isNotEmpty) {
          title = parts.first;
          final remaining = parts
              .skip(1)
              .where((p) =>
                  p != 'مصر' && !RegExp(r'^\d+$').hasMatch(p))
              .take(2)
              .join('، ');
          subtitle = remaining;
        } else {
          title = displayName;
          subtitle = '';
        }

        final gov = (address['state'] ??
                address['governorate'] ??
                address['city'])
            ?.toString();

        networkResults.add(LocationSuggestion(
          title: title,
          subtitle: subtitle,
          latitude: lat,
          longitude: lon,
          governorate: gov,
        ));
      }

      if (networkResults.isNotEmpty) {
        // Merge with local matches to prevent duplicates
        final merged = <LocationSuggestion>[...networkResults];
        for (final local in localMatches) {
          final isDupe = merged.any((n) =>
              normalizeArabic(n.title) == normalizeArabic(local.title) ||
              (Geolocator.distanceBetween(n.latitude, n.longitude, local.latitude, local.longitude) < 500));
          if (!isDupe) {
            merged.add(local);
          }
        }
        return merged;
      }
    } catch (_) {}

    return localMatches;
  }
}

@riverpod
LocationService locationService(Ref ref) {
  return LocationService();
}
