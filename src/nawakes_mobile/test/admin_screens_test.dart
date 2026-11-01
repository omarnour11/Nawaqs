import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nawakes_mobile/core/network/api_client.dart';
import 'package:nawakes_mobile/core/network/api_response_models.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/features/admin/data/admin_models.dart';
import 'package:nawakes_mobile/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:nawakes_mobile/features/admin/presentation/admin_reports_screen.dart';
import 'package:nawakes_mobile/features/admin/presentation/admin_ticket_detail_screen.dart';
import 'package:nawakes_mobile/features/admin/presentation/pharmacy_review_screen.dart';
import 'package:nawakes_mobile/features/pharmacy/data/sales_ledger_models.dart';
import 'package:nawakes_mobile/features/support/data/ticket_models.dart';

/// Fake ApiClient for comprehensive Admin screen testing
class FakeAdminApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  DashboardStatsDto stats = DashboardStatsDto(
    totalPatients: 1420,
    totalPharmacies: 86,
    pendingApprovals: 3,
    approvedPharmacies: 78,
    rejectedPharmacies: 5,
    totalInventoryItems: 4200,
    inStockItems: 3800,
    outOfStockItems: 400,
    activeReservations: 42,
    completedReservations: 1250,
    pendingReports: 4,
    totalPatientsSubscriptions: 120,
    averageTrustScore: 0.92,
  );

  List<AdminPharmacyDto> pendingPharmacies = [];
  List<AdminPharmacyDto> allPharmaciesList = [];
  List<AdminReportDto> reportsList = [];
  List<AdminTicketDto> ticketQueue = [];
  List<PatientSummaryDto> patientsList = [];
  List<MedicineCatalogItemDto> catalogList = [];
  List<ShortageDemandRow> shortageDemandRows = [];
  Map<String, List<TicketMessageDto>> messagesMap = {};

  String? lastReviewedPharmacyId;
  ReviewPharmacyRequest? lastReviewPharmacyReq;
  String? lastReviewedReportId;
  ReviewReportRequest? lastReviewReportReq;
  String? lastResolvedTicketId;
  ResolveTicketRequest? lastResolveTicketReq;
  String? lastPostedMessageBody;

  FakeAdminApiClient() {
    _initDefaults();
  }

  void _initDefaults() {
    pendingPharmacies = [
      AdminPharmacyDto(
        id: 'pharm_pend_1',
        ownerId: 'owner_1',
        ownerEmail: 'dr.ahmed@example.com',
        name: 'صيدلية النور الحديثة',
        addressLine: 'شارع الهرم الرئيسي',
        city: 'الجيزة',
        phone: '01012345678',
        latitude: 29.987,
        longitude: 31.123,
        verificationStatus: 'Pending',
        trustScore: 0.95,
        inventoryCount: 140,
        licenseDocUrl: 'https://docs.nawaqs.com/license1.pdf',
        nationalIdDocUrl: 'https://docs.nawaqs.com/nid1.pdf',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      AdminPharmacyDto(
        id: 'pharm_pend_2',
        ownerId: 'owner_2',
        ownerEmail: 'dr.sara@example.com',
        name: 'صيدلية الشفاء',
        addressLine: 'ميدان التحرير',
        city: 'القاهرة',
        phone: '01198765432',
        latitude: 30.044,
        longitude: 31.235,
        verificationStatus: 'Pending',
        trustScore: 0.88,
        inventoryCount: 85,
        licenseDocUrl: 'https://docs.nawaqs.com/license2.pdf',
        nationalIdDocUrl: 'https://docs.nawaqs.com/nid2.pdf',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    allPharmaciesList = [
      ...pendingPharmacies,
      AdminPharmacyDto(
        id: 'pharm_app_1',
        ownerId: 'owner_3',
        ownerEmail: 'dr.tamer@example.com',
        name: 'صيدلية الأمل المركزية',
        addressLine: 'شارع جمال عبد الناصر',
        city: 'الإسكندرية',
        phone: '01234567890',
        latitude: 31.200,
        longitude: 29.918,
        verificationStatus: 'Approved',
        trustScore: 0.98,
        inventoryCount: 310,
        licenseDocUrl: 'https://docs.nawaqs.com/license3.pdf',
        nationalIdDocUrl: 'https://docs.nawaqs.com/nid3.pdf',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ];

    reportsList = [
      AdminReportDto(
        id: 'rep_1',
        pharmacyId: 'pharm_app_1',
        pharmacyName: 'صيدلية الأمل المركزية',
        reporterEmail: 'patient.omar@example.com',
        type: 'NotFound',
        status: 'Pending',
        medicationName: 'كونكور 5 مجم',
        description: 'ذهبت للصيدلية وأفاد الصيدلي بعدم توفر الدواء رغم ظهوره متاحاً في التطبيق.',
        reportedPrice: 45.0,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      AdminReportDto(
        id: 'rep_2',
        pharmacyId: 'pharm_app_1',
        pharmacyName: 'صيدلية الأمل المركزية',
        reporterEmail: 'patient.mona@example.com',
        type: 'Found',
        status: 'Confirmed',
        medicationName: 'أوجمنتين 1 جم',
        description: 'الدواء كان متوفراً واستلمته بنجاح بسعر الجريدة الرسمية.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    ticketQueue = [
      AdminTicketDto(
        id: 'tkt_12345678-abcd',
        userId: 'usr_pat_1',
        reporterEmail: 'patient1@example.com',
        subject: 'مشكلة في كود الاستلام بالحجز',
        description: 'الكود لم يقبله نظام الصيدلية وطلبوا مني إلغاء الحجز يدوياً.',
        category: 'ReservationIssue',
        status: 'Open',
        reservationId: 'res_87654321',
        pharmacyId: 'pharm_app_1',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    patientsList = [
      PatientSummaryDto(
        id: 'pat_1',
        email: 'ahmed.patient@example.com',
        fullName: 'أحمد محمود إبراهيم',
        phone: '01011122233',
        registeredAt: DateTime.now().subtract(const Duration(days: 90)),
        reservationCount: 8,
        complaintCount: 1,
      ),
      PatientSummaryDto(
        id: 'pat_2',
        email: 'fatma.patient@example.com',
        fullName: 'فاطمة علي حسن',
        phone: '01222233344',
        registeredAt: DateTime.now().subtract(const Duration(days: 45)),
        reservationCount: 3,
        complaintCount: 0,
      ),
    ];

    catalogList = [
      MedicineCatalogItemDto(
        id: 'med_1',
        tradeName: 'كونكور 5 مجم (Concor 5mg)',
        activeIngredient: 'بيسوبرولول فومارات (Bisoprolol)',
        strength: '5 mg',
        dosageForm: 'أقراص مغلفة',
        officialPriceEGP: 45.5,
        manufacturer: 'ميرك (Merck)',
        isChronic: true,
      ),
      MedicineCatalogItemDto(
        id: 'med_2',
        tradeName: 'أوجمنتين 1 جم (Augmentin 1g)',
        activeIngredient: 'أموكسيسيللين + كلافولانات',
        strength: '1 g',
        dosageForm: 'أقراص',
        officialPriceEGP: 99.0,
        manufacturer: 'جلاكسو سميث كلاين (GSK)',
        isChronic: false,
      ),
    ];

    shortageDemandRows = [
      ShortageDemandRow(
        medicationName: 'كونكور 5 مجم',
        city: 'القاهرة',
        waitingCount: 28,
        oldestWaitingSince: DateTime.now().subtract(const Duration(days: 3)),
      ),
      ShortageDemandRow(
        medicationName: 'أوزمبيك 1 مجم',
        city: 'الجيزة',
        waitingCount: 45,
        oldestWaitingSince: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];

    messagesMap['tkt_12345678-abcd'] = [
      TicketMessageDto(
        id: 'msg_1',
        senderId: 'usr_pat_1',
        senderRole: 'Patient',
        body: 'السلام عليكم، الصيدلية قالتلي الكود غير صالح على السيستم عندهم.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  @override
  Future<DashboardStatsDto> getAdminStats() async => stats;

  @override
  Future<List<AdminPharmacyDto>> getAdminPharmacies(bool all) async {
    return all ? allPharmaciesList : pendingPharmacies;
  }

  @override
  Future<void> reviewPharmacy(String id, ReviewPharmacyRequest body) async {
    lastReviewedPharmacyId = id;
    lastReviewPharmacyReq = body;
    pendingPharmacies.removeWhere((p) => p.id == id);
    final idx = allPharmaciesList.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final old = allPharmaciesList[idx];
      allPharmaciesList[idx] = AdminPharmacyDto(
        id: old.id,
        ownerId: old.ownerId,
        ownerEmail: old.ownerEmail,
        name: old.name,
        addressLine: old.addressLine,
        city: old.city,
        phone: old.phone,
        latitude: old.latitude,
        longitude: old.longitude,
        verificationStatus: body.approve ? 'Approved' : 'Rejected',
        rejectionReason: body.rejectionReason,
        trustScore: old.trustScore,
        inventoryCount: old.inventoryCount,
        licenseDocUrl: old.licenseDocUrl,
        nationalIdDocUrl: old.nationalIdDocUrl,
        createdAt: old.createdAt,
      );
    }
  }

  @override
  Future<List<AdminReportDto>> getAdminReports(bool pendingOnly) async {
    if (pendingOnly) {
      return reportsList.where((r) => r.status == 'Pending').toList();
    }
    return reportsList;
  }

  @override
  Future<void> reviewReport(String id, ReviewReportRequest body) async {
    lastReviewedReportId = id;
    lastReviewReportReq = body;
    final idx = reportsList.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final old = reportsList[idx];
      reportsList[idx] = AdminReportDto(
        id: old.id,
        pharmacyId: old.pharmacyId,
        pharmacyName: old.pharmacyName,
        reporterEmail: old.reporterEmail,
        type: old.type,
        status: body.confirm ? 'Confirmed' : 'Rejected',
        medicationName: old.medicationName,
        description: old.description,
        reportedPrice: old.reportedPrice,
        createdAt: old.createdAt,
        reviewedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Future<ShortageDemandResponse> getShortageDemand() async {
    return ShortageDemandResponse(
      rows: shortageDemandRows,
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<PagedPatientsResult> getAdminPatients({
    String? search,
    int page = 1,
    int pageSize = 30,
  }) async {
    var filtered = patientsList;
    if (search != null && search.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              (p.fullName?.contains(search) ?? false) ||
              p.email.contains(search) ||
              (p.phone?.contains(search) ?? false))
          .toList();
    }
    return PagedPatientsResult(
      items: filtered,
      totalCount: filtered.length,
      pageNumber: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  @override
  Future<PagedMedicineCatalogResult> getAdminMedicineCatalog({
    String? search,
    int page = 1,
    int pageSize = 50,
    bool? chronicOnly,
  }) async {
    var filtered = catalogList;
    if (chronicOnly == true) {
      filtered = filtered.where((m) => m.isChronic).toList();
    }
    if (search != null && search.isNotEmpty) {
      filtered = filtered
          .where((m) =>
              m.tradeName.toLowerCase().contains(search.toLowerCase()) ||
              (m.activeIngredient
                      ?.toLowerCase()
                      .contains(search.toLowerCase()) ??
                  false))
          .toList();
    }
    return PagedMedicineCatalogResult(
      items: filtered,
      totalCount: filtered.length,
      pageNumber: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  @override
  Future<List<AdminTicketDto>> getAdminTicketQueue() async => ticketQueue;

  @override
  Future<void> resolveTicket(String id, ResolveTicketRequest body) async {
    lastResolvedTicketId = id;
    lastResolveTicketReq = body;
    final idx = ticketQueue.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final old = ticketQueue[idx];
      ticketQueue[idx] = AdminTicketDto(
        id: old.id,
        userId: old.userId,
        reporterEmail: old.reporterEmail,
        subject: old.subject,
        description: old.description,
        category: old.category,
        status: body.startProgress ? 'InProgress' : 'Resolved',
        resolution: body.resolution,
        reservationId: old.reservationId,
        pharmacyId: old.pharmacyId,
        createdAt: old.createdAt,
      );
    }
  }

  @override
  Future<List<TicketMessageDto>> getTicketMessages(String id) async {
    return messagesMap[id] ?? [];
  }

  @override
  Future<IdResponse> postTicketMessage(String id, PostMessageRequest body) async {
    lastPostedMessageBody = body.body;
    final msg = TicketMessageDto(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'admin_1',
      senderRole: 'Admin',
      body: body.body,
      createdAt: DateTime.now(),
    );
    messagesMap.putIfAbsent(id, () => []).add(msg);
    return IdResponse(id: msg.id);
  }
}

void setupViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget buildTestAdminApp({
  required Widget child,
  required FakeAdminApiClient apiClient,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(apiClient),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. AdminDashboardScreen - Overview Tab & KPIs', () {
    testWidgets('Renders KPI metrics, system health chip and attention banner',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      await tester.pumpWidget(
        buildTestAdminApp(
          child: const AdminDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Top bar & Header
      expect(find.text('نواقص · الإدارة العليا'), findsOneWidget);
      expect(find.text('لوحة العمليات'), findsOneWidget);

      // KPI boxes
      expect(find.text('مؤشرات سلامة الشبكة'), findsOneWidget);
      expect(find.text('92% ثقة'), findsOneWidget);
      expect(find.text('1420'), findsOneWidget); // total patients
      expect(find.text('إجمالي المرضى'), findsOneWidget);
      expect(find.text('86'), findsOneWidget); // total pharmacies
      expect(find.text('الصيدليات'), findsWidgets);
      expect(find.text('3'), findsOneWidget); // pending approvals
      expect(find.text('طلبات التوثيق'), findsOneWidget);
      expect(find.text('42'), findsOneWidget); // active reservations
      expect(find.text('1250'), findsOneWidget); // completed reservations

      // Attention warning banner
      expect(find.textContaining('يوجد 3 صيدلية بانتظار مراجعة التوثيق والمستندات.'),
          findsOneWidget);
    });

    testWidgets('Renders support tickets queue and shortage demand rows with Arabic badges',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      await tester.pumpWidget(
        buildTestAdminApp(
          child: const AdminDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Support ticket
      expect(find.text('طابور الدعم'), findsOneWidget);
      expect(find.text('مشكلة في كود الاستلام بالحجز'), findsOneWidget);
      expect(find.textContaining('مفتوحة'), findsOneWidget);

      // Shortage demand table
      expect(find.text('أدوية مطلوبة (نواقص)'), findsOneWidget);
      expect(find.text('كونكور 5 مجم'), findsWidgets);
      expect(find.text('28 منتظر'), findsOneWidget);
      expect(find.text('أوزمبيك 1 مجم'), findsOneWidget);
      expect(find.text('45 منتظر'), findsOneWidget);
    });

    testWidgets('Renders pending verification pharmacy cards in overview tab',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      await tester.pumpWidget(
        buildTestAdminApp(
          child: const AdminDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('طلبات التوثيق الأخيرة'), findsOneWidget);
      expect(find.text('صيدلية النور الحديثة'), findsOneWidget);
      expect(find.textContaining('شارع الهرم الرئيسي'), findsOneWidget);
      expect(find.text('مراجعة واعتماد'), findsWidgets);
    });
  });

  group('2. AdminDashboardScreen - Tab Navigation', () {
    testWidgets('Switches smoothly between all 5 bottom navigation tabs',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      await tester.pumpWidget(
        buildTestAdminApp(
          child: const AdminDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Initially on Overview tab (index 0)
      expect(find.text('لوحة العمليات'), findsOneWidget);

      // Tap on Patients Tab (index 1)
      await tester.tap(find.byIcon(Icons.people_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('سجل المرضى'), findsOneWidget);
      expect(find.text('البحث بالاسم، البريد أو الهاتف...'), findsOneWidget);

      // Tap on Pharmacies Tab (index 2)
      await tester.tap(find.byIcon(Icons.local_pharmacy_outlined));
      await tester.pumpAndSettle();
      expect(find.text('الصيدليات والتوثيق'), findsOneWidget);
      expect(find.text('قيد التوثيق فقط'), findsOneWidget);

      // Tap on Medicines Tab (index 3)
      await tester.tap(find.byIcon(Icons.medication_outlined));
      await tester.pumpAndSettle();
      expect(find.text('دليل الأدوية (EDA)'), findsOneWidget);
      expect(find.textContaining('البحث في دليل الأدوية المصري'), findsOneWidget);

      // Tap on Tickets & Reports Tab (index 4)
      await tester.tap(find.byIcon(Icons.assignment_outlined));
      await tester.pumpAndSettle();
      expect(find.text('التذاكر والبلاغات'), findsWidgets);
      await tester.tap(find.text('بلاغات الصيدليات'));
      await tester.pumpAndSettle();
      expect(find.text('المعلقة فقط'), findsOneWidget);
    });
  });

  group('3. Patients Management Tab', () {
    testWidgets('Renders patient cards with summary details and search filtering',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      await tester.pumpWidget(
        buildTestAdminApp(
          child: const AdminDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Go to Patients tab
      await tester.tap(find.byIcon(Icons.people_outline_rounded));
      await tester.pumpAndSettle();

      // Patient 1
      expect(find.text('أحمد محمود إبراهيم'), findsOneWidget);
      expect(find.text('ahmed.patient@example.com'), findsOneWidget);
      expect(find.text('8 طلبات'), findsOneWidget);
      expect(find.text('1 شكاوى'), findsOneWidget);

      // Patient 2
      expect(find.text('فاطمة علي حسن'), findsOneWidget);
      expect(find.text('3 طلبات'), findsOneWidget);

      // Search for specific patient
      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'فاطمة');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('فاطمة علي حسن'), findsOneWidget);
      expect(find.text('أحمد محمود إبراهيم'), findsNothing);
    });
  });

  group('4. Pharmacies & Verification Tab', () {
    testWidgets('Toggles between pending verification and all pharmacies',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      await tester.pumpWidget(
        buildTestAdminApp(
          child: const AdminDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Go to Pharmacies tab
      await tester.tap(find.byIcon(Icons.local_pharmacy_outlined));
      await tester.pumpAndSettle();

      // Initially on "قيد التوثيق فقط"
      expect(find.text('العدد: 2 صيدلية'), findsOneWidget);
      expect(find.text('صيدلية النور الحديثة'), findsOneWidget);
      expect(find.text('صيدلية الشفاء'), findsOneWidget);
      expect(find.text('صيدلية الأمل المركزية'), findsNothing);

      // Switch to "جميع الصيدليات"
      await tester.tap(find.text('جميع الصيدليات'));
      await tester.pumpAndSettle();

      expect(find.text('العدد: 3 صيدلية'), findsOneWidget);
      expect(find.text('صيدلية الأمل المركزية'), findsOneWidget);
      expect(find.text('معتمدة'), findsOneWidget);
    });
  });

  group('5. Medicine Catalog Tab (EDA Registry)', () {
    testWidgets('Renders official catalog items and filters by chronic medications',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      await tester.pumpWidget(
        buildTestAdminApp(
          child: const AdminDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Go to Medicines tab
      await tester.tap(find.byIcon(Icons.medication_outlined));
      await tester.pumpAndSettle();

      expect(find.text('إجمالي المسجل: 2 دواء'), findsOneWidget);
      expect(find.text('كونكور 5 مجم (Concor 5mg)'), findsOneWidget);
      expect(find.text('45.50 ج.م'), findsOneWidget);
      expect(find.text('مزمن'), findsOneWidget);
      expect(find.text('أوجمنتين 1 جم (Augmentin 1g)'), findsOneWidget);
      expect(find.text('99.00 ج.م'), findsOneWidget);

      // Filter chronic only
      await tester.tap(find.text('أدوية الأمراض المزمنة فقط'));
      await tester.pumpAndSettle();

      expect(find.text('إجمالي المسجل: 1 دواء'), findsOneWidget);
      expect(find.text('كونكور 5 مجم (Concor 5mg)'), findsOneWidget);
      expect(find.text('أوجمنتين 1 جم (Augmentin 1g)'), findsNothing);
    });
  });

  group('6. Reports & Complaints Moderation Tab', () {
    testWidgets('Renders reports and handles confirm / dismiss actions',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      await tester.pumpWidget(
        buildTestAdminApp(
          child: const AdminDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Go to Reports tab
      await tester.tap(find.byIcon(Icons.assignment_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بلاغات الصيدليات'));
      await tester.pumpAndSettle();

      expect(find.text('صيدلية الأمل المركزية'), findsOneWidget);
      expect(find.text('مقدم البلاغ: patient.omar@example.com'), findsOneWidget);
      expect(find.text('الدواء المبلغ عنه: كونكور 5 مجم'), findsOneWidget);

      // Confirm report
      expect(find.text('تأكيد البلاغ'), findsOneWidget);
      await tester.tap(find.text('تأكيد البلاغ'));
      await tester.pumpAndSettle();

      expect(fakeApi.lastReviewedReportId, equals('rep_1'));
      expect(fakeApi.lastReviewReportReq?.confirm, isTrue);
      expect(find.text('تم تأكيد البلاغ وتعديل تقييم الصيدلية.'), findsOneWidget);
    });
  });

  group('7. PharmacyReviewScreen - Direct Review Flow', () {
    testWidgets('Renders pharmacy credentials and approves pharmacy cleanly',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      final pharmacy = fakeApi.pendingPharmacies.first;

      await tester.pumpWidget(
        buildTestAdminApp(
          child: PharmacyReviewScreen(pharmacy: pharmacy),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مراجعة واعتماد الصيدلية'), findsOneWidget);
      expect(find.text('صيدلية النور الحديثة'), findsOneWidget);
      expect(find.text('العنوان'), findsOneWidget);
      expect(find.text('رقم الهاتف'), findsOneWidget);
      expect(find.text('مستندات التوثيق والتراخيص'), findsOneWidget);
      expect(find.text('ترخيص وزارة الصحة'), findsOneWidget);
      expect(find.text('بطاقة الرقم القومي / السجل'), findsOneWidget);

      // Approve action
      final approveBtn = find.text('اعتماد الصيدلية');
      expect(approveBtn, findsOneWidget);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      expect(fakeApi.lastReviewedPharmacyId, equals('pharm_pend_1'));
      expect(fakeApi.lastReviewPharmacyReq?.approve, isTrue);
      expect(find.text('تم اعتماد صيدلية النور الحديثة بنجاح.'), findsOneWidget);
    });

    testWidgets('Rejection requires reason and validates empty input with warning',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      final pharmacy = fakeApi.pendingPharmacies.first;

      await tester.pumpWidget(
        buildTestAdminApp(
          child: PharmacyReviewScreen(pharmacy: pharmacy),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Tap reject without entering reason
      final rejectBtn = find.text('رفض الطلب');
      await tester.tap(rejectBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('يرجى كتابة سبب الرفض أولاً.'), findsOneWidget);
      expect(fakeApi.lastReviewedPharmacyId, isNull);

      // Dismiss first snackbar so the second snackbar is not queued
      ScaffoldMessenger.of(tester.element(find.byType(PharmacyReviewScreen))).hideCurrentSnackBar();
      await tester.pump();

      // Enter rejection reason and reject
      final reasonField = find.byType(TextField);
      await tester.enterText(reasonField, 'صورة ترخيص وزارة الصحة منتهية الصلاحية.');
      await tester.tap(rejectBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeApi.lastReviewedPharmacyId, equals('pharm_pend_1'));
      expect(fakeApi.lastReviewPharmacyReq?.approve, isFalse);
      expect(fakeApi.lastReviewPharmacyReq?.rejectionReason,
          equals('صورة ترخيص وزارة الصحة منتهية الصلاحية.'));
      expect(find.textContaining('تم رفض صيدلية النور الحديثة'), findsOneWidget);
    });
  });

  group('8. AdminTicketDetailScreen & Thread Interaction', () {
    testWidgets('Renders ticket info, progress stepper, and handles ticket resolution',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      final ticket = fakeApi.ticketQueue.first;

      await tester.pumpWidget(
        buildTestAdminApp(
          child: AdminTicketDetailScreen(ticket: ticket),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Header and entities
      expect(find.text('التذكرة'), findsOneWidget);
      expect(find.text('مشكلة في كود الاستلام بالحجز'), findsOneWidget);
      expect(find.text('وصف المشكلة'), findsOneWidget);
      expect(find.text('خطوات الحل'), findsOneWidget);
      expect(find.text('تم تسجيلها في النظام'), findsOneWidget);
      expect(find.text('المحادثة'), findsOneWidget);

      // Start progress action
      final startProgressBtn = find.text('ابدأ المعالجة');
      expect(startProgressBtn, findsOneWidget);
      await tester.ensureVisible(startProgressBtn);
      await tester.tap(startProgressBtn);
      await tester.pumpAndSettle();

      expect(fakeApi.lastResolvedTicketId, equals(ticket.id));
      expect(fakeApi.lastResolveTicketReq?.startProgress, isTrue);
      expect(find.text('تم تحويل التذكرة إلى قيد المعالجة.'), findsOneWidget);

      final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
      expect(container.read(adminTicketFilterProvider), equals('InProgress'));
      expect(container.read(adminDashboardTabProvider), equals(4));
      expect(container.read(adminTicketSubTabProvider), equals(0));
    });

    testWidgets('Posts admin reply to conversation thread', (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();
      final ticket = fakeApi.ticketQueue.first;

      await tester.pumpWidget(
        buildTestAdminApp(
          child: AdminTicketDetailScreen(ticket: ticket),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      // Existing message from patient
      expect(find.textContaining('الصيدلية قالتلي الكود غير صالح'), findsOneWidget);

      // Enter admin reply
      final replyField = find.widgetWithText(TextField, 'اكتب رد…');
      expect(replyField, findsOneWidget);
      await tester.ensureVisible(replyField);
      await tester.enterText(replyField, 'تم التواصل مع الصيدلية وتحديث الكود.');

      final sendBtn = find.byIcon(Icons.send_rounded);
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(fakeApi.lastPostedMessageBody,
          equals('تم التواصل مع الصيدلية وتحديث الكود.'));
    });
  });

  group('9. AdminReportsScreen Standalone', () {
    testWidgets('Renders reports screen with top bar and filter pills',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();

      await tester.pumpWidget(
        buildTestAdminApp(
          child: const AdminReportsScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مراجعة البلاغات'), findsOneWidget);
      expect(find.textContaining('بلاغات المجتمع حول توفر الأدوية'), findsOneWidget);
      expect(find.text('معلقة (1)'), findsOneWidget);
      expect(find.text('الكل (2)'), findsOneWidget);
      expect(find.textContaining('صيدلية الأمل المركزية'), findsOneWidget);
      expect(find.textContaining('أوجمنتين 1 جم'), findsNothing); // It's in confirmed ones

      // Switch to all
      await tester.tap(find.text('الكل (2)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('أوجمنتين 1 جم'), findsOneWidget);
    });
  });

  group('10. Admin Dashboard - Logout Flow', () {
    testWidgets('Shows confirmation dialog on logout and cancels cleanly',
        (tester) async {
      setupViewport(tester);

      final fakeApi = FakeAdminApiClient();

      await tester.pumpWidget(
        buildTestAdminApp(
          child: const AdminDashboardScreen(),
          apiClient: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      final logoutBtn = find.byIcon(Icons.logout_rounded);
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(find.text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('خروج'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'), findsNothing);
      expect(find.text('نواقص · الإدارة العليا'), findsOneWidget);
    });
  });
}
