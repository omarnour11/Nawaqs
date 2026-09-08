import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/features/reports/data/report_models.dart';

part 'report_controller.g.dart';

@riverpod
class ReportController extends _$ReportController {
  @override
  FutureOr<void> build() {}

  Future<void> submitReport(String pharmacyId, int type, String medicationName, {double? reportedPrice, String? description}) async {
    state = const AsyncValue.loading();
    
    state = await AsyncValue.guard(() async {
      final client = ref.read(apiClientProvider);
      try {
        await client.createReport(
          pharmacyId, 
          CreateReportRequest(
            type: type, 
            medicationName: medicationName,
            reportedPrice: reportedPrice,
            description: description,
          )
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 409 || e.response?.statusCode == 429) {
          throw Exception('Thanks! You have already submitted a report for this recently.');
        } else {
          throw Exception('Failed to submit report: ${e.message}');
        }
      } catch (e) {
        throw Exception('An unexpected error occurred.');
      }
    });
  }
}
