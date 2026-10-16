# Nawaqs (نواقص) — Implementation Blueprint
> **Audience:** Developers, Architects, and AI Agents executing tasks on this codebase.  
> **Format:** Pure Implementation Guide — Steps, Hints, File Names, Classes, Interfaces, and Method Signatures (Zero Code Bloat).  
> **Standard:** English for architecture, APIs, and file names; Arabic for user-facing UI labels, dialect mappings, and clinical warnings.

---

## 🧭 Master Implementation Index

| Phase | Feature Name | Core Technologies | Slices | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1** | Production Readiness & System Hardening | Docker, SQL Server Spatial, Redis, Serilog, Sentry | 1.1 – 1.5 | ✅ **DONE** |
| **Phase 2** | Multimodal Search («صوّر العلبة أو الروشتة، أو اتكلم») | Google ML Kit, Flutter Camera, STT, Regex, Gemini Flash | 2.1 – 2.4 | ⏳ Planned |
| **Phase 3** | Fair Availability Queue («نبّهني لما يرجع») | Hangfire, SQL Server RowVersion, FCM Deep Links | 3.1 – 3.5 | ⏳ Planned |
| **Phase 4** | EDA Generic Substitutes («بدائل بنفس المادة الفعالة») | SQL Server Deterministic Join, EDA Registry | 4.1 – 4.2 | ⏳ Planned |
| **Phase 5** | Family Cabinet & Depletion Engine («دولاب دوا العيلة») | Hangfire Recurring Cron, Geo-Search, Multi-Profile | 5.1 – 5.4 | ⏳ Planned |
| **Phase 6** | Offline Support & Store Release | Flutter Secure Storage, Proguard/R8 | 6.1 – 6.2 | ⏳ Planned |

---

## Phase 1: Production Readiness & Hardening ✅ [DONE]

### Slice 1.1: Containerization & Cloud Environments ✅ [DONE]
* **Objective:** Standardize local, staging, and production environments.
* **Files:**
  * `[NEW]` `Dockerfile` (Root)
  * `[NEW]` `docker-compose.yml` (Root)
  * `[NEW]` `.github/workflows/ci.yml` (Root)
  * `[MODIFY]` `src/Nawakes.API/appsettings.json`
* **Implementation Steps:**
  1. Build multi-stage Dockerfile targeting `.NET 9 SDK` for build and `mcr.microsoft.com/dotnet/aspnet:9.0-alpine` for runtime.
  2. Run the container with non-root security context (`USER app`).
  3. Configure Docker Compose with three services: `api`, `sqlserver` (with spatial extensions enabled), and `redis:7-alpine` (with persistent append-only storage).
  4. Create GitHub Actions CI pipeline running `dotnet restore`, `dotnet build --no-restore`, and `dotnet test`.
* **Hints & Pitfalls:**
  * Never commit JWT secrets or connection strings. Use environment variable substitution in Docker (`ConnectionStrings__DefaultConnection`).

---

### Slice 1.2: Geospatial & SQL Performance ✅ [DONE]
* **Objective:** Ensure spatial queries scale to millions of pharmacy searches without latency spikes.
* **Files:**
  * `[NEW]` `src/Nawakes.Infrastructure/Persistence/Migrations/<Timestamp>_AddSpatialIndexes.cs`
  * `[MODIFY]` `src/Nawakes.Infrastructure/DependencyInjection.cs`
* **Implementation Steps:**
  1. Create an EF Core migration executing raw SQL to build spatial grid indexes:
     * `CREATE SPATIAL INDEX IX_Pharmacies_GeoPoint ON Pharmacies(GeoPoint) USING GEOGRAPHY_GRID...`
     * `CREATE SPATIAL INDEX IX_Subscriptions_GeoPoint ON Subscriptions(GeoPoint) USING GEOGRAPHY_GRID...`
  2. Configure connection resilience in `DependencyInjection.cs` using `sql.EnableRetryOnFailure(maxRetryCount: 5, maxRetryDelay: TimeSpan.FromSeconds(10), errorNumbersToAdd: null)`.
* **Hints & Pitfalls:**
  * SQL Server geography indexes require bounding parameters; use `GEOGRAPHY_GRID` with 4 levels of `MEDIUM` density for Egyptian coordinates.

---

### Slice 1.3: Observability, Health Checks & Telemetry ✅ [DONE]
* **Objective:** Real-time visibility into server and mobile health.
* **Files:**
  * `[MODIFY]` `src/Nawakes.API/Program.cs`
  * `[MODIFY]` `src/nawakes_mobile/lib/main.dart`
* **Implementation Steps:**
  1. Register ASP.NET Core health checks in `Program.cs`:
     * Endpoint `/health/live`: Basic ping for load balancers.
     * Endpoint `/health/ready`: Validates active connections to SQL Server, Redis, and Hangfire.
  2. Configure Serilog with structural enrichment: `TraceId`, `UserId`, `ClientIp`.
  3. Initialize Sentry in `nawakes_mobile/lib/main.dart` wrapping `runApp` inside `runZonedGuarded`.
* **Hints & Pitfalls:**
  * Do not log patient health questionnaires or prescription search terms to avoid compliance violations.

---

### Slice 1.4: Security, Anti-Scraping & Egyptian Compliance ✅ [DONE]
* **Objective:** Prevent black-market bot scraping and comply with Egyptian Personal Data Protection Law (Law No. 151 of 2020).
* **Files:**
  * `[MODIFY]` `src/Nawakes.API/Program.cs`
  * `[MODIFY]` `src/Nawakes.Infrastructure/Persistence/Repositories/PharmacySearchRepository.cs`
* **Implementation Steps:**
  1. Add a sliding-window rate limiter in `Program.cs` on `SearchController` allowing maximum 30 requests/minute per IP and 60 requests/minute per authenticated user.
  2. Filter all public queries in `PharmacySearchRepository.cs` with `Pharmacy.VerificationStatus == VerificationStatus.Approved`.
  3. Require pharmacist syndicate card (كارنيه النقابة) and commercial registry during pharmacy onboarding.
* **Hints & Pitfalls:**
  * Return HTTP 429 with `Retry-After: 60` header when rate limit is exceeded.

---

### Slice 1.5: Egyptian Pharmacy Inventory Freshness ✅ [DONE]
* **Objective:** Overcome the barrier of busy pharmacists failing to update stock manually.
* **Files:**
  * `[NEW]` `src/Nawakes.Infrastructure/BackgroundJobs/StaleInventoryDecayJob.cs`
  * `[NEW]` `src/nawakes_mobile/lib/features/pharmacy/presentation/quick_barcode_scanner_sheet.dart`
* **Implementation Steps:**
  1. Build a 1-tap mobile barcode scanner for pharmacists: Scanning an item barcode immediately flips status between `InStock` and `OutOfStock` without opening forms.
  2. Schedule a Hangfire daily job `StaleInventoryDecayJob`: Automatically flags items unverified for $> 14$ days as `Unconfirmed` and lowers their ranking.

---

## Phase 2: Multimodal Search — «صوّر العلبة أو الروشتة، أو اتكلم»

### Objective
Allow users and elderly patients to search by snapping a picture of a medicine box or prescription, or speaking in colloquial Egyptian Arabic, with 100% on-device privacy and zero server API costs.

### Architectural Decision Record (ADR): ML Kit vs. Building OCR from Scratch
* **Decision:** Use Google ML Kit (On-Device Text Recognition) + Device Native STT. **Do NOT build an OCR engine from scratch.**
* **Cost & Feasibility Analysis:**
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

---

### Slice 2.1: Flutter On-Device Camera & OCR
* **Libraries:** `google_mlkit_text_recognition: ^0.14.0`, `camera: ^0.11.1`, `permission_handler: ^11.3.1`.
* **Files:**
  * `[NEW]` `nawakes_mobile/lib/core/services/on_device_ocr_service.dart`
  * `[NEW]` `nawakes_mobile/lib/features/search/presentation/camera_scan_sheet.dart`
* **Classes & Method Signatures:**
  * `class OnDeviceOcrService`:
    * `Future<List<String>> extractMedicationNames(File imageFile)`: Performs Latin & Arabic on-device text recognition.
    * `bool _isPersonalData(String text)`: Redacts doctor, patient, clinic, date, and phone number lines.
    * `bool _looksLikePharmaceutical(String text)`: Identifies pharmaceutical units (`mg`, `ml`, `مجم`, `وحدة`, `أقراص`, `حقن`).
  * `class CameraScanSheet extends StatefulWidget`:
    * Camera viewfinder with rectangular framing guide for boxes/prescriptions.
    * Capture button triggering on-device OCR.
    * Arabic Privacy Label: *«🔒 الصورة لا تُرفع على أي سيرفر — المعالجة على جهازك فقط»*.
* **Hints & Pitfalls:**
  * Call `imageFile.deleteSync()` immediately inside the `finally` block of OCR extraction.

---

### Slice 2.2: Flutter Egyptian Dialect Voice Input
* **Libraries:** `speech_to_text: ^7.0.0` (Uses native Google/Apple on-device speech engine — 100% Free).
* **Files:**
  * `[NEW]` `nawakes_mobile/lib/core/services/voice_search_service.dart`
  * `[MODIFY]` `nawakes_mobile/lib/features/search/presentation/search_screen.dart`
* **Classes & Method Signatures:**
  * `class VoiceSearchService`:
    * `Future<bool> initialize()`
    * `Future<void> startListening({required Function(String) onResult, required Function() onDone})`: Listens with `localeId: 'ar_EG'`.
    * `Future<void> stop()`
* **UI Integration:**
  * Add animated microphone icon button to the search bar.
  * Speech completion automatically forwards transcript to `ParseMultimodalQueryCommand`.

---

### Slice 2.3: Backend Multimodal Parser & Dialect Normalizer
* **Files:**
  * `[NEW]` `src/Nawakes.Application/Search/Commands/ParseMultimodal/ParseMultimodalQueryCommand.cs`
  * `[NEW]` `src/Nawakes.Application/Search/Commands/ParseMultimodal/ParseMultimodalQueryCommandHandler.cs`
  * `[NEW]` `src/Nawakes.Application/Common/Interfaces/IEgyptianDialectNormalizer.cs`
  * `[NEW]` `src/Nawakes.Infrastructure/NLP/EgyptianDialectNormalizerService.cs`
  * `[MODIFY]` `src/Nawakes.API/Controllers/SearchController.cs`
* **Contracts & Signatures:**
  * `record ParseMultimodalQueryCommand(string RawText, string InputType) : IRequest<ParsedMedicationDto>`
  * `record ParsedMedicationDto(string ResolvedName, string? Strength, string? DosageForm, decimal Confidence, bool RequiresDisambiguation)`
  * `interface IEgyptianDialectNormalizer`:
    * `Task<NormalizedMedication?> NormalizeAsync(string rawText, CancellationToken ct)`
* **API Route:**
  * `POST /api/v1/search/parse-multimodal`
    * Request: `{ "rawText": "عايز شريطين كونكور خمسة", "inputType": "voice" }`
    * Response: `{ "resolvedName": "Concor", "strength": "5mg", "dosageForm": "Tablet", "confidence": 0.95 }`
* **Hints & Dialect Normalization Logic:**
  * **Pass 1 (Rule Table):**
    * Drug names: *"جلوفاج"* $\rightarrow$ `Glucophage`, *"لانتوس"* $\rightarrow$ `Lantus`, *"كلكسان ستين"* $\rightarrow$ `Clexane 60mg`, *"كونكور خمسة"* $\rightarrow$ `Concor 5mg`.
    * Number words: *"خمسة"* $\rightarrow$ 5, *"عشرة"* $\rightarrow$ 10, *"ستين"* $\rightarrow$ 60, *"الف"* $\rightarrow$ 1000.
    * Quantities: *"شريطين"* $\rightarrow$ 2 strips, *"علبة"* $\rightarrow$ 1 box.
  * **Pass 2 (Fuzzy Match against 37k Dataset):**
    * Uses SQL Server Full-Text search and Trigrams similarity on the 37,000 drug catalog.
  * **Pass 3 (Gemini Flash Fallback):**
    * Invoked only if Passes 1 & 2 yield no confident candidate. System prompt strictly limits LLM to text cleaning and prohibits clinical suggestions.

---

### Slice 2.4: 37,000 Egyptian Drug Authority (EDA) Master Catalog Ingestion
* **Files:**
  * `[NEW]` `src/Nawakes.Domain/Entities/EgyptianDrugRegistry.cs`
  * `[NEW]` `src/Nawakes.Infrastructure/Persistence/Configurations/EgyptianDrugRegistryConfiguration.cs`
  * `[NEW]` `src/Nawakes.Infrastructure/Persistence/Seed/EdaDrugSeeder.cs`
  * `[MODIFY]` `src/Nawakes.Application/Common/Interfaces/IApplicationDbContext.cs`
  * `[MODIFY]` `src/Nawakes.Infrastructure/Persistence/ApplicationDbContext.cs`
* **Entity Fields:**
  * `TradeName`, `TradeNameNormalized` (uppercase, diacritic-free).
  * `ActiveIngredient`, `ActiveIngredientNormalized`.
  * `Strength` (e.g. `5mg`, `1000mg`).
  * `DosageForm` (e.g. `Film-Coated Tablet`, `Pre-filled Pen`).
  * `OfficialPriceEGP` (Egyptian Ministry of Health compulsory ceiling price).
  * `Manufacturer`, `EdaRegistrationNumber`, `IsChronic`.
* **Database Ingestion & Indexing for 37k Dataset:**
  * `EdaDrugSeeder.cs`: Seeds the 37,000 records from JSON/CSV export in batches of 1,000.
  * Composite unique index on `(ActiveIngredientNormalized, Strength, DosageForm, TradeNameNormalized)`.
  * Index on `TradeNameNormalized` for instant exact lookups.
  * SQL Server Full-Text Index on `(TradeName, ActiveIngredient, Manufacturer)` using catalog `nawakes_fts`.


---

## Phase 3: Fair Availability Queue — «نبّهني لما يرجع»

### Objective
Eliminate customer stampedes when scarce medicines arrive in low stock by implementing a fair FIFO priority queue with a 15-minute claim window, converting into a 2-hour reservation (`NWQ-XXXXXX`).

---

### Slice 3.1: Domain Queue Status & Entity Extensions
* **Files:**
  * `[MODIFY]` `src/Nawakes.Domain/Entities/Subscription.cs`
  * `[MODIFY]` `src/Nawakes.Domain/Enums/DomainEnums.cs`
* **New Properties on `Subscription`:**
  * `int QueuePosition` (FIFO rank based on subscription timestamp + distance).
  * `QueueStatus QueueStatus` (`Waiting`, `Offered`, `Claimed`, `Skipped`, `Fulfilled`, `Cancelled`).
  * `DateTime? OfferedAt`, `DateTime? OfferExpiresAt`.
  * `Guid? OfferedInventoryItemId`.
  * `string? OfferExpiryHangfireJobId`.
* **New Notification Types:**
  * `AvailabilityOfferSent = 8`, `OfferExpired = 9`.

---

### Slice 3.2: Fair Allocation Job & Offer Expiry Job
* **Files:**
  * `[MODIFY]` `src/Nawakes.Infrastructure/BackgroundJobs/InventoryAvailabilityNotificationJob.cs`
  * `[NEW]` `src/Nawakes.Infrastructure/BackgroundJobs/OfferWindowExpiryJob.cs`
* **Methods & Workflow:**
  * `InventoryAvailabilityNotificationJob.AllocateQueueSlotsAsync(Guid inventoryItemId)`:
    * Reads `InventoryItem.Quantity`.
    * Queries top $N$ subscribers ordered by `QueuePosition`.
    * Sets `QueueStatus = Offered` with 15-minute expiry.
    * Schedules `OfferWindowExpiryJob` in Hangfire with 15-minute delay.
    * Sends FCM push with data payload: `{"action": "open_claim_sheet", "subscriptionId": "...", "expiresAt": "..."}`.
  * `OfferWindowExpiryJob.ExpireOfferAsync(Guid subscriptionId)`:
    * If subscription is still `Offered` after 15 minutes, changes status to `Skipped`.
    * Re-triggers `AllocateQueueSlotsAsync` for the next person in line.

---

### Slice 3.3: Claim Offer Command
* **Files:**
  * `[NEW]` `src/Nawakes.Application/Subscriptions/Commands/ClaimOffer/ClaimQueueOfferCommand.cs`
  * `[NEW]` `src/Nawakes.Application/Subscriptions/Commands/ClaimOffer/ClaimQueueOfferCommandHandler.cs`
  * `[MODIFY]` `src/Nawakes.API/Controllers/SubscriptionsController.cs`
* **Contracts & Signatures:**
  * `record ClaimQueueOfferCommand(Guid SubscriptionId) : IRequest<ReservationDto>`
  * `POST /api/v1/subscriptions/{id}/claim-offer`
* **Implementation Steps:**
  1. Validate subscription belongs to the current user and status is `Offered`.
  2. Validate `OfferExpiresAt > DateTime.UtcNow`.
  3. Atomically transition `InventoryItem.Status = Reserved` using EF Core `RowVersion` optimistic locking.
  4. Delete the scheduled `OfferWindowExpiryJob` from Hangfire.
  5. Create `Reservation` with 2-hour expiry and crypto pickup code (`NWQ-XXXXXX`).
  6. Return `ReservationDto`.

---

### Slice 3.4: Flutter Offer Sheet UI & Deep Linking
* **Files:**
  * `[NEW]` `nawakes_mobile/lib/features/alerts/presentation/reservation_offer_sheet.dart`
  * `[MODIFY]` `nawakes_mobile/lib/main.dart`
  * `[MODIFY]` `nawakes_mobile/lib/core/network/api_client.dart`
* **UI Components:**
  * Catch FCM background tap: If `type == 'availability_offer'`, navigate directly to `/offer/:id`.
  * `ReservationOfferSheet`:
    * Shows pharmacy name, distance, and medication name.
    * Live countdown timer (`MM:SS`) bound to `OfferExpiresAt`.
    * Prominent button: *«تأكيد حجز الدواء لساعتين»*.
    * On confirmation: Navigates to existing reservation pass screen with QR code.

---

### Slice 3.5: Shortage Demand Heatmap (طابور النواقص)
* **Files:**
  * `[NEW]` `src/Nawakes.Application/Admin/Queries/GetShortageDemandReport/GetShortageDemandReportQuery.cs`
  * `[MODIFY]` `src/Nawakes.API/Controllers/AdminController.cs`
* **API Route:**
  * `GET /api/v1/admin/shortage-demand`
  * Returns aggregated counts of active waiting subscribers grouped by `MedicationName` and `City/District` to help suppliers target deliveries.

---

## Phase 4: EDA Generic Substitutes — «بدائل بنفس المادة الفعالة»

### Objective
When a medication is out of stock, automatically display exact bioequivalent generics registered by the Egyptian Drug Authority (EDA), complete with price savings and nearby pharmacy stock.

### Non-Negotiable Medical Guardrails
* **Zero AI Hallucination:** No generative AI is used for clinical matching.
* **Deterministic Matching Rule (Strict SQL):**
  $$\text{Same Active Ingredient} + \text{Same Strength} + \text{Same Dosage Form}$$

---

### Slice 4.1: Bioequivalent Query & Price Savings Calculation
* **Files:**
  * `[NEW]` `src/Nawakes.Application/Search/Queries/GetMedicationEquivalents/GetMedicationEquivalentsQuery.cs`
  * `[NEW]` `src/Nawakes.Application/Search/Queries/GetMedicationEquivalents/GetMedicationEquivalentsQueryHandler.cs`
  * `[MODIFY]` `src/Nawakes.API/Controllers/SearchController.cs`
* **Contracts & Signatures:**
  * `record GetMedicationEquivalentsQuery(string MedicationName, double Lat, double Lng, decimal RadiusKm) : IRequest<MedicationEquivalentsResponse>`
  * `record MedicationEquivalentsResponse(OriginalMedicationInfo Original, IReadOnlyList<EquivalentPharmacyResult> AvailableEquivalents, string LegalDisclaimer)`
  * `record EquivalentPharmacyResult(string EquivalentTradeName, string Manufacturer, decimal OfficialPriceEGP, decimal PriceSavingPercent, Guid PharmacyId, string PharmacyName, double DistanceKm, Guid InventoryItemId)`
* **API Route:**
  * `GET /api/v1/search/equivalents?medicationName=Concor&lat=30.0&lng=31.0&radiusKm=5`
* **Implementation Steps:**
  1. Find source drug in `EgyptianDrugRegistry`.
  2. Query `EgyptianDrugRegistry` where `ActiveIngredientNormalized`, `Strength`, and `DosageForm` match, but `Id != sourceDrug.Id`.
  3. Join with nearby `InventoryItems` where `Status == InStock` and distance $\le$ radius.
  4. Compute `PriceSavingPercent = ((Original - Equivalent) / Original) * 100`.
  5. Include mandatory disclaimer: *«⚠️ تنبيه طبي: هذا بديل متطابق بنفس المادة الفعالة والتركيز. استشر الصيدلي أو الطبيب دائماً قبل الاستبدال»*.

---

### Slice 4.2: Mobile Equivalence Card UI
* **Files:**
  * `[NEW]` `nawakes_mobile/lib/features/search/presentation/medication_equivalents_card.dart`
  * `[MODIFY]` `nawakes_mobile/lib/features/search/presentation/pharmacy_details_screen.dart`
  * `[MODIFY]` `nawakes_mobile/lib/features/search/presentation/search_screen.dart`
* **UI Components:**
  * Renders automatically below empty search results or on an out-of-stock pharmacy screen.
  * Side-by-side card comparing original drug and available generic with price tag and savings badge (e.g. *«يوفر 45%»*).
  * Prominent yellow alert box with the Arabic legal disclaimer.
  * 1-Tap CTA button: *«احجز البديل لساعتين»*.

---

## Phase 5: Family Cabinet & Depletion Engine — «دولاب دوا العيلة»

### Objective
Enable caregivers to track chronic medication supplies for their elderly parents, predict depletion dates, and trigger automated stock searches 7 days before running out.

### Depletion Math Formula:
$$\text{DaysRemaining} = \left\lfloor \frac{\text{StripsCount} \times \text{UnitsPerStrip}}{\text{DailyDoseUnits}} \right\rfloor$$

---

### Slice 5.1: Domain Modeling
* **Files:**
  * `[NEW]` `src/Nawakes.Domain/Entities/FamilyProfile.cs`
  * `[NEW]` `src/Nawakes.Domain/Entities/FamilyMedication.cs`
  * `[NEW]` `src/Nawakes.Domain/Entities/FamilyCaregiverLink.cs`
  * `[NEW]` `src/Nawakes.Infrastructure/Persistence/Configurations/FamilyCabinetConfigurations.cs`
  * `[MODIFY]` `src/Nawakes.Application/Common/Interfaces/IApplicationDbContext.cs`
  * `[MODIFY]` `src/Nawakes.Infrastructure/Persistence/ApplicationDbContext.cs`
* **Entity Structures:**
  * `FamilyProfile`: `OwnerUserId`, `Nickname` (*«والدي»*, *«والدتي»*), `HomeLatitude`, `HomeLongitude`.
  * `FamilyMedication`: `FamilyProfileId`, `MedicationName`, `StripsCount`, `UnitsPerStrip`, `DailyDoseUnits`, `LastRefillDate`, `AlertThresholdDays` (default: 7).
  * `FamilyCaregiverLink`: `FamilyProfileId`, `CaregiverUserId`, `InvitedPhoneNumber`, `IsAccepted`.

---

### Slice 5.2: Proactive 7-Day Refill Hangfire Job
* **Files:**
  * `[NEW]` `src/Nawakes.Infrastructure/BackgroundJobs/CheckCabinetDepletionJob.cs`
  * `[MODIFY]` `src/Nawakes.Infrastructure/DependencyInjection.cs`
* **Job Specifications:**
  * Cron Expression: Daily at 8:00 AM Cairo Time (`0 6 * * *` UTC).
  * Filter: `DaysRemaining <= AlertThresholdDays` (e.g. $\le 7$ days).
  * Actions:
    1. Runs a background spatial search (`IPharmacySearchRepository.SearchAsync`) around family `HomeLatitude`/`HomeLongitude` within 5 km.
    2. Sends high-priority push notifications to the account owner and all accepted caregivers:  
       *«⚠️ دواء والدك (جلوفاج 1000) هيكفي 6 أيام بس! متوفر حالياً في صيدلية [س]. اضغط هنا لحجزه مسبقاً»*.

---

### Slice 5.3: CQRS Commands & Endpoints
* **Files:**
  * `[NEW]` `src/Nawakes.Application/FamilyCabinet/Commands/CreateFamilyProfile/CreateFamilyProfileCommand.cs`
  * `[NEW]` `src/Nawakes.Application/FamilyCabinet/Commands/AddFamilyMedication/AddFamilyMedicationCommand.cs`
  * `[NEW]` `src/Nawakes.Application/FamilyCabinet/Commands/RefillFamilyMedication/RefillFamilyMedicationCommand.cs`
  * `[NEW]` `src/Nawakes.Application/FamilyCabinet/Commands/InviteCaregiver/InviteCaregiverCommand.cs`
  * `[NEW]` `src/Nawakes.Application/FamilyCabinet/Queries/GetFamilyCabinet/GetFamilyCabinetQuery.cs`
  * `[NEW]` `src/Nawakes.API/Controllers/FamilyCabinetsController.cs`
* **Endpoints:**
  * `GET /api/v1/family-cabinets`
  * `POST /api/v1/family-cabinets`
  * `POST /api/v1/family-cabinets/{profileId}/medications`
  * `POST /api/v1/family-cabinets/medications/{id}/refill`
  * `POST /api/v1/family-cabinets/{profileId}/invite`
* **Hints on Refill Command:**
  * When a caregiver logs a refill (`RefillFamilyMedicationCommand`), increment `StripsCount`, update `LastRefillDate`, and dispatch an in-app alert to all co-caregivers (*«قام أحمد بشراء أشرطة جديدة لدواء الوالد»*) to prevent duplicate purchases.

---

### Slice 5.4: Flutter Family Cabinet UI
* **Files:**
  * `[NEW]` `nawakes_mobile/lib/features/family_cabinet/data/family_cabinet_models.dart`
  * `[NEW]` `nawakes_mobile/lib/features/family_cabinet/presentation/family_cabinet_screen.dart`
  * `[NEW]` `nawakes_mobile/lib/features/family_cabinet/presentation/medication_depletion_card.dart`
  * `[NEW]` `nawakes_mobile/lib/features/family_cabinet/presentation/add_family_member_sheet.dart`
* **UI Features:**
  * Color-coded depletion bar: Green ($>14$ days), Orange ($7–14$ days), Red ($<7$ days).
  * Quick-action buttons: *[+ إضافة شريط]*, *[تسجيل تناول الجرعة]*, *[ابحث عن صيدلية]*.
  * WhatsApp caregiver invite link generator.

---

## Phase 6: Mobile Offline Support & Release Readiness

### Slice 6.1: Offline Reservation Pass
* **Files:**
  * `[MODIFY]` `nawakes_mobile/lib/features/reservations/presentation/reservation_detail_screen.dart`
* **Implementation Steps:**
  * Store active reservation details (`ReservationCode`, pharmacy address, phone, QR pass) in `flutter_secure_storage`.
  * Render stored pass when network requests fail so patients can retrieve their medicine in basement pharmacies with no cell reception.

---

### Slice 6.2: Android/iOS Production Build Hardening
* **Files:**
  * `[NEW]` `nawakes_mobile/android/app/proguard-rules.pro`
  * `[MODIFY]` `nawakes_mobile/android/app/build.gradle`
* **Implementation Steps:**
  1. Enable R8 code shrinking and resource shrinking in release build.
  2. Add Proguard keep rules for NetTopologySuite spatial geometries and Dio JSON models.
  3. Verify RTL layout rendering with the Cairo Arabic font across all dialogs and sheets.

---

## 🚀 Execution Order Checklist for Developers / AI

```
1. Run EF Core Migration for EgyptianDrugRegistry and seed top 500 Egyptian medications.
2. Build on-device OCR service and voice search service in Flutter.
3. Add ParseMultimodalQueryCommand with the Egyptian dialect normalizer in backend.
4. Add GetMedicationEquivalentsQuery and the equivalents comparison UI card.
5. Extend Subscription entity with queue fields, rewrite InventoryAvailabilityNotificationJob, and build ClaimQueueOfferCommand.
6. Build FamilyProfile & FamilyMedication entities, the daily Hangfire depletion job, and the Family Cabinet UI.
7. Apply production hardening: Rate limiting, spatial indexes, health checks, and Docker containerization.
```
