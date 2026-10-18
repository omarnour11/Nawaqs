import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart' show apiClientProvider, describeApiError;
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/ui/widgets.dart';
import 'package:nawakes_mobile/features/family_cabinet/data/family_cabinet_models.dart';

import 'medication_depletion_card.dart';
import 'add_family_member_sheet.dart';

class FamilyCabinetScreen extends HookConsumerWidget {
  const FamilyCabinetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cabinet = useState<FamilyCabinetResponseModel?>(null);
    final loading = useState(true);
    final error = useState<String?>(null);

    Future<void> load() async {
      loading.value = true;
      error.value = null;
      try {
        final res = await ref.read(apiClientProvider).getFamilyCabinet();
        cabinet.value = res;
      } catch (e) {
        error.value = describeApiError(e);
      } finally {
        loading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('دولاب دوا العيلة'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showAddFamilyMemberSheet(context);
          if (created == true) load();
        },
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        label: const Text('إضافة شخص'),
        icon: const Icon(Icons.person_add_alt_1),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: loading.value
            ? const Center(child: CircularProgressIndicator())
            : error.value != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(child: Text(error.value!, textAlign: TextAlign.center)),
                      const SizedBox(height: 12),
                      Center(
                        child: OutlinedButton(onPressed: load, child: const Text('إعادة المحاولة')),
                      ),
                    ],
                  )
                : cabinet.value == null || cabinet.value!.profiles.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('مفيش حد متتبع لسه', style: TextStyle(color: AppColors.textSecondary))),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: cabinet.value!.profiles.length,
                        itemBuilder: (context, i) {
                          final profile = cabinet.value!.profiles[i];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  profile.nickname,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ),
                              if (profile.medications.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text('مفيش أدوية متتبعة', style: TextStyle(color: AppColors.textSecondary)),
                                )
                              else
                                ...profile.medications.map(
                                  (m) => MedicationDepletionCard(
                                    medication: m,
                                    onChanged: load,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
      ),
    );
  }
}
