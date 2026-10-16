# Nawaqs (نواقص) — Second Brain & Architectural Blueprint
> **Purpose:** Master implementation roadmap and technical reference for developers and AI agents.  
> **Format:** Actionable steps, exact file paths, method signatures, and architectural hints (Zero code bloat).  
> **Tech Stack:** .NET 9 (Clean Architecture + CQRS), SQL Server + NetTopologySuite, Redis, Hangfire, Flutter (Riverpod + Hooks).

---

## 🧭 Table of Contents
1. [Phase 1: Production Readiness & Hardening](#phase-1-production-readiness--hardening)
2. [Phase 2: Multimodal Search — «صوّر العلبة أو الروشتة، أو اتكلم»](#phase-2-multimodal-search--صور-العلبة-أو-الروشتة-أو-اتكلم)
3. [Phase 3: Back-in-Stock Queue & 2-Hour Hold — «نبّهني لما يرجع»](#phase-3-back-in-stock-queue--2-hour-hold--نبهني-لما-يرجع)
4. [Phase 4: EDA Generic Substitutes — «بدائل بنفس المادة الفعالة»](#phase-4-eda-generic-substitutes--بدائل-بنفس-المادة-الفعالة)
5. [Phase 5: Family Cabinet & Depletion Engine — «دولاب دوا العيلة»](#phase-5-family-cabinet--depletion-engine--دولاب-دوا-العيلة)
6. [Phase 6: Mobile Offline Support & Release Readiness](#phase-6-mobile-offline-support--release-readiness)

---

## Phase 1: Production Readiness & Hardening ✅ [DONE]

### Slice 1.1: DevOps & Environments ✅ [DONE]
* **Tools:** Docker, Docker Compose, GitHub Actions.
* **Steps:**
  1. Create multi-stage `Dockerfile` for `Nawakes.API` targeting `.NET 9 SDK` build and `chiseled/alpine` runtime.
  2. Create `docker-compose.yml` defining services: `api`, `sqlserver` (with spatial support), and `redis` (v7-alpine with persistence).
  3. Move hardcoded secrets (JWT key, connection strings, FCM keys) to environment variables and Key Vault / Secrets Manager.
* **Files to create/modify:**
  * `[NEW]` `Dockerfile` (Root)
  * `[NEW]` `docker-compose.yml` (Root)
  * `[NEW]` `.github/workflows/ci.yml` (GitHub Actions CI pipeline)
  * `[MODIFY]` `src/Nawakes.API/appsettings.json`

### Slice 1.2: Geospatial & SQL Performance ✅ [DONE]
* **Tools:** SQL Server Management / EF Core Migrations, NetTopologySuite.
* **Steps:**
  1. Add spatial grid index to `Pharmacies` and `Subscriptions` tables on `GeoPoint`.
  2. Configure EF Core connection pooling and SQL Server transient retry policy (`EnableRetryOnFailure`).
* **Files to create/modify:**
  * `[NEW]` `src/Nawakes.Infrastructure/Persistence/Migrations/<Timestamp>_AddSpatialIndexes.cs`
  * `[MODIFY]` `src/Nawakes.Infrastructure/DependencyInjection.cs`
* **Hints & SQL Commands:**
  * Execute via migration: `CREATE SPATIAL INDEX IX_Pharmacies_GeoPoint ON Pharmacies(GeoPoint) USING GEOGRAPHY_GRID...`

### Slice 1.3: Observability & Health Checks ✅ [DONE]
* **Tools:** ASP.NET Core Health Checks, Serilog, Sentry.
* **Steps:**
  1. Register SQL Server, Redis, and Hangfire health check providers.
  2. Expose `/health/live` (basic ping) and `/health/ready` (checks external services).
  3. Setup Sentry in both `Nawakes.API` and `nawakes_mobile` (`main.dart`).
* **Files to create/modify:**
  * `[MODIFY]` `src/Nawakes.API/Program.cs` (`builder.Services.AddHealthChecks().AddSqlServer().AddRedis()`)
  * `[MODIFY]` `src/nawakes_mobile/lib/main.dart` (`SentryFlutter.init(...)`)

### Slice 1.4: Security, Anti-Scraping & Compliance ✅ [DONE]
* **Tools:** `Microsoft.AspNetCore.RateLimiting`, Data Protection API.
* **Steps:**
  1. Enforce sliding window rate limiting on `SearchController` (30 req/min/IP) to prevent black-market hoarding bots.
  2. Implement pharmacist verification requirement (`VerificationStatus == Approved`) before pharmacy stock appears in public search.
  3. Comply with Egyptian Data Protection Law (Law 151/2020) by encrypting patient questionnaire data.
* **Files to modify:**
  * `[MODIFY]` `src/Nawakes.API/Program.cs`
  * `[MODIFY]` `src/Nawakes.Infrastructure/Persistence/Repositories/PharmacySearchRepository.cs`

### Slice 1.5: Pharmacy Real-World Stock Freshness ✅ [DONE]
* **Tools:** Mobile camera barcode scanning (`mobile_scanner`), Twilio / WhatsApp webhook.
* **Steps:**
  1. Add 1-tap quick toggle: Pharmacist scans medicine barcode to flip status (`InStock` $\leftrightarrow$ `OutOfStock`) in 1 second.
  2. Add Hangfire auto-decay job: Mark inventory unverified if unupdated for 14 days.
* **Files to create/modify:**
  * `[NEW]` `src/Nawakes.Infrastructure/BackgroundJobs/StaleInventoryDecayJob.cs`
  * `[NEW]` `src/nawakes_mobile/lib/features/pharmacy/presentation/quick_barcode_scanner_sheet.dart`

---

## Phase 2: Multimodal Search — «صوّر العلبة أو الروشتة، أو اتكلم»

### Objective
Allow patients and elderly users to snap an empty box, snap a prescription, or speak in colloquial Egyptian Arabic instead of typing complex pharmaceutical names.

### Privacy Mandate (Egyptian Law 151/2020)
### Architectural Decision Record (ADR): ML Kit vs. Building OCR from Scratch
* **Decision:** Use Google ML Kit (On-Device Text Recognition) + Device Native STT. **Do NOT build an OCR engine from scratch.**
* **Cost & Feasibility:**
  * **Google ML Kit:** **100% Free forever.** Runs entirely on device CPU/NPU (Android & iOS). Zero cloud API costs, zero monthly bills, zero quota limits regardless of user count ($0$ for 1 user, $0$ for 10M users).
  * **Native Speech-to-Text (`speech_to_text`):** **100% Free.** Leverages built-in OS engines (Google Speech on Android, Apple Dictation on iOS) with pre-trained Egyptian Arabic (`ar_EG`) language models.
  * **Why Building OCR from Scratch is an Anti-Pattern:** Training deep neural networks (CRNN/TrOCR) on skewed photos, glossy box reflections, and Arabic fonts requires tens of thousands of dollars and months of ML engineering, yielding worse performance than Google's battle-tested models.

### Privacy Mandate (Egyptian Law 151/2020)
* **Zero Image Storage:** Photos of prescriptions and boxes **MUST NEVER** be uploaded to any server or cloud storage.
* **On-Device OCR Only:** Google ML Kit processes images in local mobile RAM, strips personal identifying info, and discards the image immediately.

### The Secret Weapon: 37,000 Egyptian Drug Dataset as Intelligent Post-Processing Engine
* **The Problem:** Hand-written prescriptions and camera glare produce imperfect OCR tokens (e.g., reads `"Concr 5m"` instead of `"Concor 5mg"`, or `"Augmntn 1g"` instead of `"Augmentin 1gm"`).
* **The Solution:** The 37,000 official Egyptian Drug Dataset acts as an **auto-correct and fuzzy anchor**:
  1. OCR extracts raw, noisy text lines on-device ($70\%-80\%$ accuracy is sufficient).
  2. The text is passed to the backend `ParseMultimodalQueryCommand`.
  3. The backend executes a **Fuzzy Matching Pipeline** against the 37,000 registered drugs:
     * **Step 1 (Exact Match):** Normalized uppercase lookup against `TradeNameNormalized`.
     * **Step 2 (Trigram & Damerau-Levenshtein $\le 2$):** Matches noisy tokens against the 37k catalog. `"Concr"` immediately snaps to `"Concor 5mg"`; `"Augmntn 1g"` immediately snaps to `"Augmentin 1g"`.
     * **Step 3 (Disambiguation):** If multiple candidates match (confidence $< 0.8$), returns top 3 suggestions for 1-tap user confirmation.

### Tech Stack & Libraries
* **Mobile:** `google_mlkit_text_recognition: ^0.14.0`, `camera: ^0.11.1`, `speech_to_text: ^7.0.0`, `permission_handler: ^11.3.1`.
* **Backend:** Two-Pass Normalizer: Rule Table (Pass 1) + Lightweight LLM / Gemini Flash (Pass 2 fallback).

---

### Step-by-Step Tasks

#### Slice 2.1: Flutter On-Device Camera & OCR
* **Files to create:**
  * `[NEW]` `nawakes_mobile/lib/core/services/on_device_ocr_service.dart`
  * `[NEW]` `nawakes_mobile/lib/features/search/presentation/camera_scan_sheet.dart`
* **Key Classes & Methods:**
  * `OnDeviceOcrService`:
    * `Future<List<String>> extractMedicationNames(File imageFile)`: Runs ML Kit Latin & Arabic text recognition.
    * `bool _isPersonalData(String text)`: Privacy redactor filtering out lines containing keywords: *(دكتور, دكتورة, عيادة, مستشفى, كشف, مريض, Clinic, Dr)*.
    * `bool _looksLikePharmaceutical(String text)`: Matches lines containing dosage units (`mg`, `ml`, `مجم`, `وحدة`, `أقراص`, `حقن`).
  * `CameraScanSheet`:
    * Modal sheet rendering live camera preview with rectangular guide box.
    * Auto-capture or snap button.
    * Shows privacy notice in Arabic: *«🔒 الصورة لا تُرفع على أي سيرفر — المعالجة على جهازك فقط»*.

#### Slice 2.2: Flutter Egyptian Dialect Voice Search
* **Files to create/modify:**
  * `[NEW]` `nawakes_mobile/lib/core/services/voice_search_service.dart`
  * `[MODIFY]` `nawakes_mobile/lib/features/search/presentation/search_screen.dart`
* **Key Classes & Methods:**
  * `VoiceSearchService`:
    * `Future<bool> initialize()`
    * `Future<void> startListening({required Function(String) onResult, required Function() onDone})`: Configured with `localeId: 'ar_EG'`.
  * `SearchScreen`:
    * Add animated microphone button inside search bar.
    * When speech finishes, calls the backend normalizer endpoint.

#### Slice 2.3: Backend Multimodal Parsing Endpoint
* **Files to create:**
  * `[NEW]` `src/Nawakes.Application/Search/Commands/ParseMultimodal/ParseMultimodalQueryCommand.cs`
  * `[NEW]` `src/Nawakes.Application/Search/Commands/ParseMultimodal/ParseMultimodalQueryCommandHandler.cs`
  * `[NEW]` `src/Nawakes.Application/Common/Interfaces/IEgyptianDialectNormalizer.cs`
  * `[NEW]` `src/Nawakes.Infrastructure/NLP/EgyptianDialectNormalizerService.cs`
  * `[MODIFY]` `src/Nawakes.API/Controllers/SearchController.cs`
* **Method Signatures & Contracts:**
  * `POST /api/v1/search/parse-multimodal`:
    * **Request Body:** `{ "rawText": "عايز شريطين كونكور خمسة", "inputType": "voice" }`
    * **Response Body:** `{ "resolvedName": "Concor", "strength": "5mg", "dosageForm": "Tablet", "confidence": 0.95 }`
  * `IEgyptianDialectNormalizer`:
    * `Task<NormalizedMedication?> NormalizeAsync(string rawText, CancellationToken cancellationToken)`
* **Normalization Hints:**
  * **Pass 1 (Rule Table):**
    * Egyptian drug mapping: *"جلوفاج"* $\rightarrow$ `Glucophage`, *"لانتوس"* $\rightarrow$ `Lantus`, *"كلكسان ستين"* $\rightarrow$ `Clexane 60mg`, *"كونكور خمسة"* $\rightarrow$ `Concor 5mg`.
    * Egyptian dosage words: *"خمسة"* $\rightarrow$ 5mg, *"عشرة"* $\rightarrow$ 10mg, *"ستين"* $\rightarrow$ 60mg, *"الف"* $\rightarrow$ 1000mg.
    * Egyptian package words: *"شريطين"* $\rightarrow$ 2 strips, *"علبة"* $\rightarrow$ 1 box.
  * **Pass 2 (Fuzzy Match against 37k Dataset):**
    * Uses SQL Server Full-Text search and Trigrams similarity on the 37,000 drug catalog.
  * **Pass 3 (Gemini Flash Fallback):**
    * Invoked only if Passes 1 & 2 yield no confident candidate. System prompt strictly limits LLM to text cleaning and prohibits clinical suggestions.

#### Slice 2.4: 37,000 Egyptian Drug Authority (EDA) Master Catalog Ingestion
* **Files to create:**
  * `[NEW]` `src/Nawakes.Domain/Entities/EgyptianDrugRegistry.cs`
  * `[NEW]` `src/Nawakes.Infrastructure/Persistence/Configurations/EgyptianDrugRegistryConfiguration.cs`
  * `[NEW]` `src/Nawakes.Infrastructure/Persistence/Seed/EdaDrugSeeder.cs`
  * `[MODIFY]` `src/Nawakes.Application/Common/Interfaces/IApplicationDbContext.cs`
  * `[MODIFY]` `src/Nawakes.Infrastructure/Persistence/ApplicationDbContext.cs`
* **Database Ingestion & Indexing for 37k Dataset:**
  * `EdaDrugSeeder.cs`: Seeds the 37,000 records from JSON/CSV export in batches of 1,000.
  * Composite unique index on `(ActiveIngredientNormalized, Strength, DosageForm, TradeNameNormalized)`.
  * Index on `TradeNameNormalized` for instant exact lookups.
  * SQL Server Full-Text Index on `(TradeName, ActiveIngredient, Manufacturer)` using catalog `nawakes_fts`.
* **Entity Fields:**
  * `TradeName`, `TradeNameNormalized` (uppercase, Tashkeel-free)
  * `ActiveIngredient`, `ActiveIngredientNormalized`
  * `Strength` (e.g. `5mg`, `1000mg`)
  * `DosageForm` (e.g. `Tablet`, `Injection Pen`)
  * `OfficialPriceEGP` (Egyptian Ministry of Health official price)
  * `Manufacturer`, `EdaRegistrationNumber`, `IsChronic`

---

## Phase 3: Back-in-Stock Queue & 2-Hour Hold — «نبّهني لما يرجع»

### Objective
Prevent stampedes when scarce drugs arrive in small batches. Allocate stock through a **fair FIFO priority queue** with a 15-minute priority claim window, leading to a 2-hour pickup code (`NWQ-XXXXXX`).

### Tech Stack & Libraries
* **Backend:** Hangfire (Background jobs, scheduled delays), SQL Server `RowVersion` (Optimistic concurrency).
* **Mobile:** Firebase Cloud Messaging (FCM deep linking), Riverpod countdown timer.

---

### Step-by-Step Tasks

#### Slice 3.1: Domain & Enum Extensions
* **Files to modify:**
  * `[MODIFY]` `src/Nawakes.Domain/Entities/Subscription.cs`
  * `[MODIFY]` `src/Nawakes.Domain/Enums/DomainEnums.cs`
* **Additions:**
  * Add to `Subscription`:
    * `int QueuePosition`
    * `QueueStatus QueueStatus`
    * `DateTime? OfferedAt`, `DateTime? OfferExpiresAt`
    * `Guid? OfferedInventoryItemId`
    * `string? OfferExpiryHangfireJobId`
  * Add to `DomainEnums.cs`:
    * `enum QueueStatus : byte { Waiting = 0, Offered = 1, Claimed = 2, Skipped = 3, Fulfilled = 4, Cancelled = 5 }`
    * Add to `NotificationType`: `AvailabilityOfferSent = 8`, `OfferExpired = 9`.

#### Slice 3.2: Fair Allocation Job & Offer Expiry Job
* **Files to create/modify:**
  * `[MODIFY]` `src/Nawakes.Infrastructure/BackgroundJobs/InventoryAvailabilityNotificationJob.cs`
  * `[NEW]` `src/Nawakes.Infrastructure/BackgroundJobs/OfferWindowExpiryJob.cs`
* **Flow & Methods:**
  1. `InventoryAvailabilityNotificationJob.AllocateQueueSlotsAsync(Guid inventoryItemId)`:
     * Reads `InventoryItem.Quantity`.
     * Queries top $N$ subscribers ordered by `QueuePosition` and distance.
     * Transitions subscription status to `QueueStatus.Offered`.
     * Schedules `OfferWindowExpiryJob` in Hangfire with 15-minute delay.
     * Dispatches FCM push with payload: `{"action": "open_claim_sheet", "subscriptionId": "...", "expiresAt": "..."}`.
  2. `OfferWindowExpiryJob.ExpireOfferAsync(Guid subscriptionId)`:
     * Checks if still in `Offered` status.
     * If unclaimed, updates status to `Skipped` and re-triggers allocation for the next subscriber in line.

#### Slice 3.3: Claim Offer Command
* **Files to create:**
  * `[NEW]` `src/Nawakes.Application/Subscriptions/Commands/ClaimOffer/ClaimQueueOfferCommand.cs`
  * `[NEW]` `src/Nawakes.Application/Subscriptions/Commands/ClaimOffer/ClaimQueueOfferCommandHandler.cs`
  * `[MODIFY]` `src/Nawakes.API/Controllers/SubscriptionsController.cs`
* **Method Signatures:**
  * `POST /api/v1/subscriptions/{id}/claim-offer`
  * Returns `ReservationDto` containing `ReservationCode` (`NWQ-XXXXXX`), `ExpiresAt` (2 hours), and pharmacy contact info.
* **Hints:**
  * Must check EF Core `RowVersion` concurrency on `InventoryItem` during status flip to `Reserved`.
  * Deletes the scheduled `OfferWindowExpiryJob` upon successful claim.

#### Slice 3.4: Mobile Offer Sheet & Deep Linking
* **Files to create/modify:**
  * `[NEW]` `nawakes_mobile/lib/features/alerts/presentation/reservation_offer_sheet.dart`
  * `[MODIFY]` `nawakes_mobile/lib/main.dart` (FCM background & terminated tap handler)
  * `[MODIFY]` `nawakes_mobile/lib/core/network/api_client.dart`
* **UI & Components:**
  * `ReservationOfferSheet`:
    * Shows pharmacy name, distance, and medicine name.
    * 15-minute countdown clock (`MM:SS`).
    * Large button: *«تأكيد حجز الدواء لساعتين»*.
    * On tap: Calls `claimQueueOffer` and navigates to pickup QR code screen.

#### Slice 3.5: Shortage Demand Analytics (طابور النواقص)
* **Files to create:**
  * `[NEW]` `src/Nawakes.Application/Admin/Queries/GetShortageDemandReport/GetShortageDemandReportQuery.cs`
  * `[MODIFY]` `src/Nawakes.API/Controllers/AdminController.cs`
* **Method Signatures:**
  * `GET /api/v1/admin/shortage-demand`: Returns unmet subscriber count grouped by medication name and geographic zone.

---

## Phase 4: EDA Generic Substitutes — «بدائل بنفس المادة الفعالة»

### Objective
When a prescribed medication is out of stock, suggest exact bioequivalent generics from official Egyptian Drug Authority (EDA) data, showing price differences and nearby pharmacy stock.

### Non-Negotiable Medical Guardrails
* **No AI Guessing:** The AI never invents or guesses substitute molecules or alters doses.
* **Deterministic Matching Rule (100% SQL Query):**
  $$\text{ActiveIngredient(A)} = \text{ActiveIngredient(B)} \quad\land\quad \text{Strength(A)} = \text{Strength(B)} \quad\land\quad \text{DosageForm(A)} = \text{DosageForm(B)}$$

---

### Step-by-Step Tasks

#### Slice 4.1: Query & Bioequivalent Engine
* **Files to create:**
  * `[NEW]` `src/Nawakes.Application/Search/Queries/GetMedicationEquivalents/GetMedicationEquivalentsQuery.cs`
  * `[NEW]` `src/Nawakes.Application/Search/Queries/GetMedicationEquivalents/GetMedicationEquivalentsQueryHandler.cs`
  * `[MODIFY]` `src/Nawakes.API/Controllers/SearchController.cs`
* **Method Signatures:**
  * `GET /api/v1/search/equivalents?medicationName=Concor&lat=30.0&lng=31.0&radiusKm=5`
  * **Response:**
    * `Original`: Trade name, active ingredient, strength, official price, availability status.
    * `AvailableEquivalents`: List of generics in stock at nearby pharmacies with price, distance, and `% savings`.
    * `LegalDisclaimer`: Fixed clinical warning in Arabic.

#### Slice 4.2: Mobile Generic Recommendation Card
* **Files to create/modify:**
  * `[NEW]` `nawakes_mobile/lib/features/search/presentation/medication_equivalents_card.dart`
  * `[MODIFY]` `nawakes_mobile/lib/features/search/presentation/pharmacy_details_screen.dart`
  * `[MODIFY]` `nawakes_mobile/lib/features/search/presentation/search_screen.dart`
* **UI Elements:**
  * Displayed automatically when an item is out of stock.
  * Side-by-side comparison: *Concor 5mg (80 EGP - غير متوفر) vs. Bisor 5mg (42 EGP - متوفر في صيدلية الشفاء على بعد 400 متر)*.
  * Prominent yellow banner:
    *«⚠️ تنبيه طبي: هذا بديل متطابق بنفس المادة الفعالة والتركيز. استشر الصيدلي أو الطبيب دائماً قبل الاستبدال»*.
  * Action button: *«احجز البديل لساعتين»*.

---

## Phase 5: Family Cabinet & Depletion Engine — «دولاب دوا العيلة»

### Objective
Allow caregivers (sons/daughters) to manage chronic medications for elderly parents, track pill depletion, and receive automated refill alerts 7 days before medicine runs out.

### Depletion Calculation Logic
$$\text{TotalUnitsRemaining} = \text{StripsCount} \times \text{UnitsPerStrip}$$
$$\text{DaysRemaining} = \left\lfloor \frac{\text{TotalUnitsRemaining}}{\text{DailyDoseUnits}} \right\rfloor$$

---

### Step-by-Step Tasks

#### Slice 5.1: Domain Modeling
* **Files to create:**
  * `[NEW]` `src/Nawakes.Domain/Entities/FamilyProfile.cs` (Contains `OwnerUserId`, `Nickname` e.g. "والدي", `HomeLatitude`, `HomeLongitude`).
  * `[NEW]` `src/Nawakes.Domain/Entities/FamilyMedication.cs` (Contains `StripsCount`, `UnitsPerStrip`, `DailyDoseUnits`, `LastRefillDate`, `AlertThresholdDays`).
  * `[NEW]` `src/Nawakes.Domain/Entities/FamilyCaregiverLink.cs` (Contains `CaregiverUserId`, `InvitedPhoneNumber`, `IsAccepted`).
  * `[NEW]` `src/Nawakes.Infrastructure/Persistence/Configurations/FamilyCabinetConfigurations.cs`
  * `[MODIFY]` `src/Nawakes.Application/Common/Interfaces/IApplicationDbContext.cs`
  * `[MODIFY]` `src/Nawakes.Infrastructure/Persistence/ApplicationDbContext.cs`

#### Slice 5.2: Daily Depletion Background Job
* **Files to create:**
  * `[NEW]` `src/Nawakes.Infrastructure/BackgroundJobs/CheckCabinetDepletionJob.cs`
  * `[MODIFY]` `src/Nawakes.Infrastructure/DependencyInjection.cs`
* **Job Logic:**
  * Cron Schedule: Daily at 8:00 AM Cairo Time (`0 6 * * *` UTC).
  * Filter: All `FamilyMedication` where `DaysRemaining <= AlertThresholdDays` (e.g. $\le 7$ days).
  * Silent Geo-Search: Checks for stock in verified pharmacies within 5 km of the family's home location.
  * Notification Dispatch: Sends push notifications to account owner + all co-caregivers:
    *«⚠️ دواء والدك (جلوفاج 1000) هيكفي 6 أيام بس! متوفر حالياً في صيدلية [س]. اضغط هنا لحجزه مسبقاً»*.

#### Slice 5.3: CQRS Commands & Controller
* **Files to create:**
  * `[NEW]` `src/Nawakes.Application/FamilyCabinet/Commands/CreateFamilyProfile/CreateFamilyProfileCommand.cs`
  * `[NEW]` `src/Nawakes.Application/FamilyCabinet/Commands/AddFamilyMedication/AddFamilyMedicationCommand.cs`
  * `[NEW]` `src/Nawakes.Application/FamilyCabinet/Commands/RefillFamilyMedication/RefillFamilyMedicationCommand.cs`
  * `[NEW]` `src/Nawakes.Application/FamilyCabinet/Commands/InviteCaregiver/InviteCaregiverCommand.cs`
  * `[NEW]` `src/Nawakes.Application/FamilyCabinet/Queries/GetFamilyCabinet/GetFamilyCabinetQuery.cs`
  * `[NEW]` `src/Nawakes.API/Controllers/FamilyCabinetsController.cs`
* **Method Signatures:**
  * `GET /api/v1/family-cabinets`
  * `POST /api/v1/family-cabinets`
  * `POST /api/v1/family-cabinets/{profileId}/medications`
  * `POST /api/v1/family-cabinets/medications/{id}/refill`
  * `POST /api/v1/family-cabinets/{profileId}/invite`

#### Slice 5.4: Flutter Family Cabinet UI
* **Files to create:**
  * `[NEW]` `nawakes_mobile/lib/features/family_cabinet/data/family_cabinet_models.dart`
  * `[NEW]` `nawakes_mobile/lib/features/family_cabinet/presentation/family_cabinet_screen.dart`
  * `[NEW]` `nawakes_mobile/lib/features/family_cabinet/presentation/family_cabinet_controller.dart`
  * `[NEW]` `nawakes_mobile/lib/features/family_cabinet/presentation/medication_depletion_card.dart`
  * `[NEW]` `nawakes_mobile/lib/features/family_cabinet/presentation/add_family_member_sheet.dart`
* **UI Features:**
  * Color-coded depletion bar: Green ($>14$ days), Orange ($7–14$ days), Red ($<7$ days).
  * Quick-action buttons: *[+ إضافة شريط]*, *[تسجيل تناول الجرعة]*, *[ابحث عن صيدلية]*.
  * Caregiver invite dialog: Share link/QR code via WhatsApp.

---

## Phase 6: Mobile Offline Support & Release Readiness

### Slice 6.1: Offline Reservation Pass
* **Tools:** `flutter_secure_storage`.
* **Steps:**
  1. Cache active reservation details locally so patients can view pickup code `NWQ-XXXXXX` and pharmacy address inside pharmacy basements without mobile signal.
* **Files to modify:**
  * `[MODIFY]` `nawakes_mobile/lib/features/reservations/presentation/reservation_detail_screen.dart`

### Slice 6.2: Android/iOS Build Optimization
* **Steps:**
  1. Configure Proguard / R8 rules for NetTopologySuite and Dio reflection.
  2. Verify RTL layout and Arabic Cairo font rendering across all modal sheets.
* **Files to modify:**
  * `[MODIFY]` `nawakes_mobile/android/app/build.gradle`
  * `[NEW]` `nawakes_mobile/android/app/proguard-rules.pro`

---

## 🛠️ Step-by-Step Implementation Execution Order

When you or an AI agent begin writing code, follow this exact sequence:

1. **Step 1:** Run database migration for `EgyptianDrugRegistry` and populate seed data.
2. **Step 2:** Implement OCR and voice search Flutter services (`OnDeviceOcrService`, `VoiceSearchService`) and the backend `ParseMultimodalQueryCommand`.
3. **Step 3:** Implement the bioequivalent substitute query (`GetMedicationEquivalentsQuery`) and its Flutter card.
4. **Step 4:** Upgrade `Subscription` entity, rewrite `InventoryAvailabilityNotificationJob` for fair queueing, and add `ClaimQueueOfferCommand`.
5. **Step 5:** Build `FamilyProfile` and `FamilyMedication` entities, the daily Hangfire depletion job, and the Flutter Family Cabinet tab.
6. **Step 6:** Production hardening: Add rate limiting, spatial indexes, health checks, and Docker containerization.
