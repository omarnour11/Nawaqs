# Nawaqs Test Infrastructure Specification (`TEST_INFRA.md`)

## 1. Overview & Architecture

Nawaqs employs an opaque-box, requirement-driven automated testing infrastructure validating end-to-end user journeys across the mobile client (`src/nawakes_mobile`) and backend services (`src/Nawakes.*`). The testing framework rigorously exercises all 9 core functional features under Egyptian healthcare operating conditions, Arabic dialect normalization rules, and strict clinical/data privacy invariants (Egyptian Law 151/2020).

### Key Architectural Invariants
1. **Arabic-First Catalog Lookup**: Patient medication searches and voice queries in Egyptian dialect resolve against the normalized Arabic catalog first, falling back to phonetic transliteration or English trade names only if no direct match exists.
2. **Multi-Medication Single-Pharmacy Priority**: Prescriptions and multi-medication batch searches prioritize the single nearest pharmacy stocking all items before falling back to multi-pharmacy split plans.
3. **Reactive Voice & GPS State**: Location permissions, GPS state, and real-time transcription are strictly bound to reactive state providers (`Riverpod`), ensuring modal blocking and dynamic UI responsiveness.

---

## 2. Test Suites Layout

The test harness is divided into complementary mobile widget/integration suites and backend unit/integration suites:

```
Nawaqs/
├── src/nawakes_mobile/test/
│   ├── e2e_brand_and_features_test.dart            # Primary 4-Tier E2E Test Suite (Tiers 1–4, 105 tests)
│   ├── brand_kit_theme_and_screens_test.dart       # Design system, tokens, and vector mascot tests
│   ├── radar_hud_and_privacy_verification_test.dart# Scanner HUD, basket layout, and privacy ticker tests
│   ├── voice_and_basket_search_test.dart          # Voice recognition and batch search tests
│   ├── home_catalog_and_scanner_hud_test.dart      # Catalog navigation and HUD layout tests
│   ├── pharmacy_screens_test.dart                  # Pharmacy dashboard and sales ledger tests
│   ├── challenger_m1_adversarial_test.dart         # Adversarial edge cases and security tests
│   └── family_cabinet_models_test.dart             # Medicine cabinet models and depletion tests
│
└── tests/Nawakes.Application.Tests/
    ├── Pharmacy/
    │   ├── SalesLedgerRevenueAndResilienceTests.cs # Backend Price * Quantity and 404 resilience tests
    │   ├── GetActiveReservationsQueryHandlerTests.cs
    │   └── GetPharmacyDetailQueryHandlerTests.cs
    └── Search/
        ├── BatchSearchSplitOptimizerTests.cs
        └── PrescriptionOcrPipelineTests.cs
```

---

## 3. Four-Tier Testing Methodology

The comprehensive E2E test suite (`e2e_brand_and_features_test.dart`) implements 4 rigorous tiers of opaque-box, requirement-driven tests:

### Tier 1: Feature Coverage (>=5 Isolated Tests per Feature)
- **Feature 1: Brand Kit v3 Stickers**: Validates `NawaqssFoundSticker`, `NawaqssShortageSticker`, `NawaqssPrivacySticker`, `NawaqssSingleMedSticker`, and `NawaqssCounterSticker`.
- **Feature 2: Nuqous Mascot in 4 Moods**: Validates vector rendering and geometry for `welcome`, `searching`, `celebrating`, and `worried` (empty circular tummy hole) moods.
- **Feature 3: Mandatory Location Prompt ("سماح")**: Validates modal blocking barrier, "سماح" permission grant action, and rejection of search/delivery without GPS.
- **Feature 4: 29px RenderFlex Overflow Elimination**: Validates responsive viewport constraints on scanner HUD, basket screens, and add medication dialogs.
- **Feature 5: Uncover Prescription Medications List**: Validates single-line ticker `"🔒 الاسم والرقم اتحجبوا · خصوصية مشفرة بقانون 151"`, empty safety alerts suppression, and medication list visibility above fold.
- **Feature 6: Multi-Medication Text Search Router**: Validates multi-token query parsing (" و ", ",", "+", "مع") and automated routing to batch search.
- **Feature 7: Dynamic Governorate & Delivery Sorting**: Validates GPS governorate detection (Qalyubia, Giza, Cairo, Alexandria...), real distances, and "توصيل متاح 🛵" pharmacy prioritization.
- **Feature 8: Smart Home Medicine Cabinet Revamp**: Validates direct home inventory tracking, depletion countdown badges ("باقي X أيام على النفاذ ⏳"), expiry alert warnings, and 1-tap re-order.
- **Feature 9: Pharmacy Dashboard & Sales Ledger Resilience**: Validates 404 resilience for newly registered pharmacies, orders count metrics, and aggregate revenue calculation as `Price * Quantity`.

### Tier 2: Boundary & Corner Cases (>=5 Tests per Feature)
- Extreme numeric inputs (0, negative counts, large quantities > 999).
- Screen dimensions (narrow 320x480 dp, virtual keyboard occupying 50% height, zero-height mascot clamps).
- Arabic dialect edge cases (embedded non-conjunction 'و', trailing/leading delimiters, whitespace variations).
- Geographic boundary coordinates (Egypt border edges, non-Egypt coordinates fallback).
- Zero-quantity and decimal currency multiplications.

### Tier 3: Cross-Feature Combinations (Pairwise Interactions)
- Multi-medication query (F6) gating behind mandatory location prompt (F3).
- Dynamic governorate detection (F7) with multi-medication single-pharmacy batch fulfillment (F6).
- Smart home cabinet 1-tap re-order (F8) feeding directly into delivery-sorted pharmacy options with "توصيل متاح 🛵" (F7).
- Brand Kit stickers (F1) and Nuqous mascot worried mood (F2) integrated into scanner HUD (F4) and basket screen (F5).
- Pharmacy owner sales ledger audit (F9) displaying active reservations badged by counter sticker (F1).

### Tier 4: Real-World Scenarios (End-to-End User Journeys)
- **Scenario 1**: Chronic patient monthly refill journey from cabinet depletion alert to GPS-verified delivery order.
- **Scenario 2**: Emergency night search for multiple urgent medications with automated batch routing and single-pharmacy fulfillment.
- **Scenario 3**: Prescription camera scan with single-line privacy ticker, hidden empty alerts, and immediate medication basket checkout.
- **Scenario 4**: New pharmacy onboarding with zero-crash empty state and first reservation completion aggregating `Price * Quantity`.
- **Scenario 5**: Cabinet expired medicine alert, disposal guidance, and 1-tap re-order with delivery sorting.

---

## 4. Test Execution Commands

### Mobile Frontend Tests (Flutter)
```bash
# Run the complete 4-Tier E2E Test Suite
cd src/nawakes_mobile
flutter test test/e2e_brand_and_features_test.dart

# Run specific feature tests
flutter test test/brand_kit_theme_and_screens_test.dart
flutter test test/radar_hud_and_privacy_verification_test.dart
flutter test test/voice_and_basket_search_test.dart
flutter test test/pharmacy_screens_test.dart
```

### Backend Application Tests (.NET)
```bash
# Run all backend application tests
dotnet test tests/Nawakes.Application.Tests/

# Run pharmacy ledger resilience and revenue tests
dotnet test tests/Nawakes.Application.Tests/ --filter "FullyQualifiedName~SalesLedgerRevenueAndResilienceTests"
```

---

## 5. Mocking, Isolation & Determinism Strategy

1. **Riverpod Provider Scoping**: All Flutter tests wrap root widgets in a `ProviderScope` with mock overrides (`apiClientProvider`, `locationServiceProvider`, `deliveryLocationProvider`), preventing real HTTP network requests or device GPS sensor dependencies.
2. **Deterministic Time & In-Memory Storage**: Tests utilize fixed UTC timestamps or relative durations to ensure reproducible assertions regardless of test execution time.
3. **RTL & Egyptian Dialect Text**: Tests explicitly set `Directionality(textDirection: TextDirection.rtl)` and wrap UI in `MaterialApp` to guarantee Arabic font rendering, right-to-left layout alignment, and authentic Egyptian dialect string matching.
