# Project: Nawaqs Brand Kit v3 and Application Fixes

## Architecture
- **Mobile Frontend (`src/nawakes_mobile`)**: Flutter Clean Architecture with Feature-first organization. State management via Riverpod (`flutter_riverpod`).
  - `core/ui/`: Shared brand widgets, design tokens, logo, vector mascot (`nawaqss_brand_widgets.dart`), theme (`app_theme.dart`).
  - `core/location/`: Location service, GPS permissions, dynamic governorate classification (`location_service.dart`).
  - `core/services/`: Medication name mapping and text splitting (`arabic_medication_mapper.dart`).
  - `features/search/`: Prescription scanner HUD, prescription basket, search controller, catalog view, nearby pharmacy options.
  - `features/family_cabinet/`: Smart home medicine cabinet inventory, depletion countdown, expiry tracking, 1-tap re-order.
  - `features/pharmacy/`: Pharmacy dashboard, active orders, sales ledger.
- **Backend Application (`src/Nawakes.Application`)**: CQRS with MediatR, ASP.NET Core Clean Architecture.
  - `Pharmacy/Queries/GetSalesLedger/`: Sales ledger retrieval and earnings calculation.
  - `Pharmacy/Queries/GetActiveReservations/`: Active orders and reservation counts.
  - `Search/Queries/BatchSearch/`: Multi-medication single pharmacy prioritization and split plans.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Brand Kit v3 Stickers | "لقيناه!", "ناقص!", "الاسم والرقم اتحجبوا 🔒", "دوا واحد بس", and counter badges in `nawaqss_brand_widgets.dart` | M1 | Item 1 |
| 2 | Nuqous Mascot in 4 Moods | Vector mascot supporting `welcome`, `searching`, `celebrating`, `worried` (empty tummy) moods | M1 | Item 2 |
| 3 | Mandatory Location Prompt | Blocking dialog with "سماح" button preventing search and delivery without active GPS | M3 | Item 3 |
| 4 | 29px RenderFlex Overflow Fix | Eliminate bottom overflow in scanner HUD and basket screen dialogs | M2 | Item 4 |
| 5 | Uncover Prescription List | Compact privacy banner into single-line ticker ("🔒 الاسم والرقم اتحجبوا · خصوصية مشفرة بقانون 151") and hide empty safety alerts | M2 | Item 5 |
| 6 | Multi-Medication Text Search | Parse multi-medication queries ("بنادول و كتافلام") and automatically route to batch search | M3 | Item 6 |
| 7 | Dynamic Governorate & Delivery Sorting | Detect user governorate from GPS (Qalyubia, Giza, Cairo, Alexandria...), real distances, sort pharmacies by "توصيل متاح 🛵" | M3 | Item 7 |
| 8 | Smart Home Medicine Cabinet | Track home inventory directly, depletion countdown, expiry alerts, 1-tap re-order | M4 | Item 8 |
| 9 | Pharmacy Dashboard & Ledger Resilience | Return empty DTOs instead of 404 for new pharmacies, calculate total earnings as `Price * Quantity`, interactive ledger | M4 | Item 9 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Brand Kit v3 Stickers & Mascot | Brand stickers ("لقيناه!", "ناقص!", "الاسم والرقم اتحجبوا 🔒", "دوا واحد بس", counter) & Nuqous mascot moods | none | DONE |
| M2 | Prescription Scanner HUD & Basket Fixes | Eliminate 29px overflow, compact privacy banner into single-line ticker, hide empty safety alerts | M1 | DONE |
| M3 | Location, Dynamic Governorates & Multi-Search | Blocking "سماح" dialog, dynamic governorate detection, delivery sorting with "توصيل متاح 🛵", multi-medication search router | none | DONE |
| M4 | Smart Home Cabinet & Pharmacy Dashboard | Direct home inventory, depletion countdown, expiry alerts, 1-tap re-order, pharmacy earnings `Price * Quantity`, 404 resilience | none | DONE |
| M5 | Final E2E Test Suite Pass & Adversarial Hardening | 100% pass of Tiers 1-4 E2E tests, Tier 5 adversarial coverage hardening | M1, M2, M3, M4 | IN_PROGRESS |

## Interface Contracts

### Brand Stickers ↔ Consuming Screens
- File: `src/nawakes_mobile/lib/core/ui/nawaqss_brand_widgets.dart`
- Widgets implemented and verified:
  - `NawaqssFoundSticker`, `NawaqssShortageSticker`, `NawaqssPrivacySticker`, `NawaqssSingleMedSticker`, `NawaqssCounterSticker`
- Mascot:
  - `NuqousMascot` with moods `welcome`, `searching`, `celebrating`, `worried`

### Prescription Screen Contracts
- File: `src/nawakes_mobile/lib/features/search/presentation/prescription_basket_screen.dart`
- Privacy ticker:
  - Key: `ValueKey('prescription_privacy_assurance_banner')`
  - Text: `"🔒 الاسم والرقم اتحجبوا · خصوصية مشفرة بقانون 151"`
- Safety alerts:
  - Empty or nominal alerts suppressed (`SizedBox.shrink()`)
- Dialog:
  - Wrapped in `SingleChildScrollView` (0 RenderFlex overflow)

### Location Gate ↔ Search & Delivery
- File: `src/nawakes_mobile/lib/features/search/presentation/widgets/mandatory_location_prompt_dialog.dart`
- Interface:
  - `Future<bool> ensureLocationPermission(BuildContext context, WidgetRef ref)`
  - Blocks until user grants GPS permission via "سماح" button.

### Multi-Medication Search Router ↔ Batch Search
- Delimiter regex: `RegExp(r'\s+(?:و|\+|مع|and)\s+|[,\u060C+]')`
- Output: `List<BatchSearchItemDto>` routed to `BatchSearchResultsScreen(items: batchItems)`

### Pharmacy Dashboard ↔ Backend API
- `GetSalesLedgerQuery`:
  - `TotalRevenue = Sum(d.Price * d.Quantity)`
  - If `pharmacy == null`, return `new SalesLedgerDto(0, 0m, 0, [])`
- `GetActiveReservationsQuery`:
  - If `pharmacy == null`, return `[]`

## Code Layout
- `src/nawakes_mobile/lib/core/ui/`: Brand widgets and sticker components
- `src/nawakes_mobile/lib/core/location/`: Location service, geocoding, governorate detection
- `src/nawakes_mobile/lib/features/search/presentation/`: Search, Scanner HUD, Basket screens
- `src/nawakes_mobile/lib/features/family_cabinet/`: Cabinet screen and depletion cards
- `src/nawakes_mobile/lib/features/pharmacy/`: Pharmacy dashboard and sales ledger
- `src/Nawakes.Application/Pharmacy/Queries/`: Backend sales ledger and reservations queries
- `src/nawakes_mobile/test/`: Flutter unit and widget tests
- `tests/Nawakes.Application.Tests/`: .NET unit and integration tests
