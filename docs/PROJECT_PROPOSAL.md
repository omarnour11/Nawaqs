# Nawaqs (نواقص)

## Real-Time Medication Availability & Clinical Safety Platform for Egypt

**Project Proposal & Technical Documentation**
Version 1.0 — November 2026

---

## 1. Executive Summary

**Nawaqs** (Arabic for "shortages") is a full-stack, Arabic-first digital health platform that solves a daily problem for millions of Egyptians: **finding which nearby pharmacy actually has your medication in stock — right now — at a fair price, and holding it for you before someone else takes it.**

Patients search a live, geospatial index of pharmacy inventory by text, voice, or a photo of a doctor's prescription; see prices verified against the official Egyptian Drug Authority (EDA) ceiling prices; place a 2-hour reservation with a QR pickup pass; and receive fair-queue availability alerts when an out-of-stock medication lands back on a shelf. Pharmacies get a complete operations dashboard — inventory management with GS1 barcode scanning and POS/ERP synchronization, live order fulfillment with delivery dispatch, a shortage-claim queue, and a community-trust score that holds them accountable for stock accuracy and price gouging.

What differentiates Nawaqs from a generic "find a pharmacy" app is the depth of its **Egypt-specific clinical and regulatory engineering**:

- A **3-tier AI prescription-reading pipeline** (Gemini Vision → Azure Read → on-device OCR) that deciphers handwritten Egyptian prescriptions, with hard PII redaction compliant with **Egyptian Data Protection Law No. 151/2020**.
- A **clinical safety shield** that cross-checks every reservation against the patient's chronic regimen, allergies, and chronic conditions before checkout — and empowers pharmacists to clinically reject a prescription with a suggested alternative.
- **Official EDA price verification** on every search result, with anti-gouging badges and a community trust score that decays when pharmacies overcharge.
- A **fair-queue allocation engine** — first-come-first-served offers with a 15-minute claim window — so scarce stock (insulin, chronic meds) goes to the people waiting longest, not the loudest.
- A **family medication cabinet** with caregiver sharing and 7-day depletion warnings, designed for Egyptian households managing elderly parents' regimens.

**Stack:** .NET 8 / C# 12 (Clean Architecture: Domain → Application → Infrastructure → API), SQL Server 2022 with geospatial (`geography`) indexing, Redis caching, Hangfire background jobs, SignalR real-time push, Google Gemini + Azure AI Vision, and a Flutter (Dart 3) patient & pharmacy app for Android. 17 REST controllers, 10 background jobs, 18 migrations, 37 test files, and a 373-drug seeded EDA catalog.

---

## 2. Problem Statement

Egypt's medication supply chain has three chronic pain points:

1. **Invisible stock.** Patients physically hop between 4–6 pharmacies hunting for a medication, with no way to know which one has it. Chronic patients (insulin, cardiac, thyroid) waste hours and risk treatment gaps.
2. **Price gouging on scarce drugs.** When a drug is scarce, informal markups appear. The EDA publishes official ceiling prices, but patients have no tool to verify a pharmacy's price against them at the point of decision.
3. **Illegible prescriptions.** Doctors' handwritten prescriptions in Egyptian Arabic/Latin shorthand (e.g. "1x2 PO") are error-prone for both patients and pharmacy clerks — and privacy-sensitive: a photo of a prescription carries the patient's identity and their medical conditions.

Nawaqs addresses all three with real-time, verified, fair data — and treats the pharmacy, not just the patient, as a first-class user.

---

## 3. Solution Overview

### 3.1 For Patients

| Capability | Detail |
|---|---|
| **Live geospatial search** | Search medication stock within 5/10/20 km using GPS. Results ranked by distance, price, or pharmacy trust score, deduplicated per pharmacy. |
| **Multi-modal input** | Type in Arabic or English, dictate by voice (Egyptian dialect mapping: "بانادول" → Panadol), or scan the prescription with the camera. |
| **AI prescription scanning** | Photo → parsed medication list with strength, dosage form, quantity, Arabic dosage instructions, and price estimates — with a post-scan privacy crop (Law 151/2020) before anything is shared with a pharmacist. |
| **Smart basket (روشتة كاملة)** | Paste/scan a whole prescription: the engine finds pharmacies stocking every item, proposes the best single pharmacy, or an optimal **2-pharmacy split plan** (balanced / cheapest / shortest route / highest trust), then reserves all items in one tap. |
| **2-hour reservations** | Optimistic-concurrency hold (SQL RowVersion) with a crypto-random pickup code (`NWQ-XXXXXX`) and a QR pass screen. Race conditions return a clean 409. |
| **Fair-queue availability alerts** | Subscribe to an out-of-stock drug + radius. When it restocks, the system offers it FIFO to waiting subscribers with a 15-minute claim window (one tap converts the offer to a reservation). Pause/resume per alert. |
| **Clinical safety shield** | Before checkout: duplicate active ingredients, drug–drug interactions, allergy conflicts, chronic-condition advisories — surfaced from the patient's declared regimen and EDA active-ingredient mapping. Critical findings block the reservation; warnings require explicit acknowledgment. |
| **EDA price verification** | Every result carries an official-price badge: "مطابق للتسعيرة الرسمية ✓" (within 2% tolerance) or an over-price warning with variance %. |
| **Pharmacy trust score** | 0–100 score decayed by community reports (inaccurate stock −5, price gouging −8, gouged items −4) and rewarded for accuracy — recalculated on every verified report. |
| **Family medication cabinet** | Family profiles with per-medication strip counts and daily dose → days-remaining computation; automatic alerts 7 days before depletion to the owner and accepted caregivers. |
| **Delivery flow** | Pickup or home delivery (address, GPS pin, recipient phone), with live delivery status transitions and **WhatsApp dispatch to the pharmacy runner** in one tap. |
| **Shortage SOS** | For drugs with zero stock anywhere nearby: a 6-hour shortage request that pharmacies claim from their dashboard queue. |
| **Medical profile** | Gender, age, chronic conditions, allergies (structured chips), medication history — plus a granular consent flag controlling whether pharmacists may view the active regimen for safety checks. Health questionnaire stored **AES-256 encrypted**. |

### 3.2 For Pharmacies

| Capability | Detail |
|---|---|
| **Operations dashboard** | Five tabs: Active Orders, Inventory, Shortage Queue, Sales Ledger, Profile. |
| **Live order inbox** | Real-time reservation notifications; mark Ready / Complete / Cancel; delivery-status transitions; **clinical rejection** with a recommended alternative (pushed back to the patient as a one-tap "reserve the alternative" action). |
| **GS1 barcode scanning** | Scan a medicine box (GS1 DataMatrix AI(01) GTIN-14 + AI(17) expiry, or EAN-13): the system parses it, matches against inventory → POS SKU → EDA registry, auto-creates the item with the **official EDA price**, and applies quantity deltas (+1 receipt / −1 dispense) in seconds. |
| **POS/ERP batch sync** | `POST pos-sync` webhook-style batch endpoint matches by barcode, external POS SKU, or normalized name and synchronizes quantities while protecting active reservations. |
| **Shortage claiming** | Live queue of patient SOS requests nearby; claim converts to a tracked reservation. |
| **Sales ledger** | Completed-reservation ledger with revenue history. |
| **Verification workflow** | Admin-reviewed onboarding (license + national ID uploads) — only Approved pharmacies are searchable, with Suspended pharmacies blocked from new reservations. |

### 3.3 For Administrators

- Pharmacy verification/rejection with document review.
- Community report moderation (review → trust-score impact).
- Platform stats, patient directory, and full medicine-catalog views.
- Hangfire dashboard (`/hangfire`) behind an admin auth filter for full job observability.

---

## 4. System Architecture

```
┌─────────────────────────┐        ┌──────────────────────────────┐
│   Flutter Mobile App    │  HTTPS │        ASP.NET Core 8 API    │
│  (Patient + Pharmacy)   ├───────►│  (JWT + Refresh Rotation)    │
│ Riverpod • Retrofit     │ SignalR│   17 controllers / MediatR   │
│ mobile_scanner • ML Kit │◄───────┤   FluentValidation pipeline  │
└─────────────────────────┘  /hubs └───────┬───────────┬──────────┘
                                           │           │
                      ┌────────────────────┘           └─────────────┐
                      ▼                                              ▼
        ┌───────────────────────────────┐            ┌─────────────────────────────┐
        │     Infrastructure Layer      │            │        External AI          │
        │ EF Core 8 (SQL Server + NTS)  │            │ Gemini Flash (Tier 1)       │
        │ geography + spatial indexes   │            │ Azure AI Vision (Tier 2)    │
        │ Redis (cache + quota counters)│            │ On-device ML Kit (Tier 3)   │
        │ Hangfire (10 recurring/one-shot jobs) │     └─────────────────────────────┘
        │ ASP.NET Identity + AES vault  │
        └───────────────────────────────┘
```

### 4.1 Solution Layout (Clean Architecture)

| Project | Responsibility | Key packages |
|---|---|---|
| `Nawakes.Domain` | 14 entities + enums + `DrugNameNormalizer` (dependency-free). Zero framework dependencies besides NetTopologySuite. | NetTopologySuite |
| `Nawakes.Application` | 121 C# files of CQRS handlers (MediatR), DTOs, validators, interfaces, AI pipeline orchestration. | MediatR, FluentValidation, EF Core |
| `Nawakes.Infrastructure` | EF Core SQL Server (+NTS geography), Identity, Redis cache service (SCAN+UNLINK invalidation), Hangfire jobs & schedulers, NLP services, Gemini/Azure clients, FCM stub. | EFCore.SqlServer+Nts, StackExchange.Redis, Hangfire, Identity |
| `Nawakes.API` | 17 controllers, SignalR hub, JWT auth, Serilog, Swagger, static-file uploads. | JWT Bearer, Swashbuckle, Serilog |
| `Nawakes.Application.Tests` | 37 xUnit files: queue concurrency, barcode/POS, trust score, safety shield, split optimizer, OCR adversarial/convergence, EDA price verification. | xUnit, Moq, FluentAssertions |
| `nawakes_mobile` | Flutter app (Dart 3, 88 handwritten files): patient + pharmacy + admin surfaces. | riverpod, retrofit, signalr_netcore, mobile_scanner, flutter_map, qr_flutter, ML Kit |

### 4.2 Data Model Highlights (SQL Server 2022)

- **`Pharmacies.GeoPoint` / `Subscriptions.GeoPoint`** — `geography` (SRID 4326) columns with **raw SQL spatial indexes**; all proximity search runs server-side via `STDistance`.
- **`InventoryItems.RowVersion`** — optimistic concurrency is the reservation race guard: the hold is a conditional `UPDATE ... WHERE RowVersion = @original`; losers get a 409.
- **`Subscriptions` fair queue** — `QueuePosition`, `QueueStatus` (Waiting/Offered/Claimed/Skipped/Fulfilled/Cancelled), `OfferExpiresAt`, `OfferedInventoryItemId`, plus its own RowVersion for claim races.
- **`EgyptianDrugRegistry`** — 373 curated EDA records (trade + Arabic names, active ingredient, strength, dosage form, **official EGP price**, GTIN barcode, chronic flag), CSV-overridable, cached in-memory 4h for zero-IO catalog access.
- **`Reservations`** — pickup code, fulfillment + delivery tracking, clinical-rejection fields, and the privacy-preserving **prescription crop** (bytes + URL).
- **Identity** — `ApplicationUser` with clinical profile (gender, age, chronic conditions, allergies), consent flag, FCM token, and an AES-256-encrypted health questionnaire blob. Rotating refresh tokens (hashed, device-tagged, replace-chain).

### 4.3 The 3-Tier Prescription Reading Pipeline

```
Photo → privacy-safe downscale → Tier 1: Gemini Flash Vision (1,400/day atomic quota)
      → on quota/429/timeout → Tier 2: Azure AI Vision Read API
      → on failure → Tier 3: on-device ML Kit OCR → ClinicalPrescriptionMatcher
Result → SigDecoder (bilingual) → SafetyAuditor → PII Sanitizer (Law 151/2020)
      → post-extraction privacy crop → basket screen
```

- **Tier 1 — Gemini Flash Vision**: reads cursive handwriting; returns structured candidates with confidence; every request counted against a distributed atomic daily quota (Redis/memory).
- **Tier 2 — Azure AI Vision Read**: pure text extraction fallback; feeds the matcher.
- **Tier 3 — On-device matcher**: ML Kit OCR lines → Egyptian phonetic mapping (بنادول→PANADOL, ليبيتور→LIPITOR), consonant-skeleton fuzzy matching, dosage-feasibility gate against the EDA catalog, Damerau-Levenshtein ranking. Works fully offline-from-AI.
- **Sig decoder (bilingual)**: converts "1 tab PO QD #30", "1x2", "قرصين بعد الأكل" into structured dose/route/frequency DTOs with patient-friendly Arabic stickers — **dosage-form-aware** (eye drops say "نقطة", syrups say "ملعقة صغيرة (5 سم)", never "قرص واحد").
- **PII sanitizer**: strips doctor/clinic/patient/syndicate/location lines before any image leaves the reservation boundary (Law 151/2020).

### 4.4 Fair-Queue Availability Engine

1. Patient subscribes (drug + radius + GPS) → `QueueStatus=Waiting`.
2. Item turns InStock → Hangfire job offers it **FIFO by join time**, capped by quantity.
3. Offer = 15-minute window + in-app notification + SignalR push (+ FCM when configured).
4. Claim → `RowVersion`-guarded → 2-hour reservation with QR code.
5. Expiry job → `Skipped`, immediately re-offers to the next subscriber.
6. Patients can pause/resume subscriptions; claimed offers are consumed exactly once (server 409 + UI hide).

### 4.5 Background Jobs (Hangfire — 10 workers, critical/default queues)

| Job | Trigger | Purpose |
|---|---|---|
| `ReservationExpiryJob` | one-shot at ExpiresAt | Auto-expire 2h holds, restock item, Arabic notification. Idempotent, retry ladder, disable-concurrent. |
| `OfferWindowExpiryJob` | one-shot at offer expiry | Reallocate skipped offers to next in queue. |
| `InventoryAvailabilityNotificationJob` | stock change | FIFO fair-queue offers (quantity-capped). |
| `TrustScoreRecalculationJob` | debounced 5 min after reports | Recompute 0–100 trust score (gouging −8, inaccurate −5, found +2, EDA-violating items −4). |
| `StaleInventoryDecayJob` | daily 02:00 UTC | Untouched >14 days → `Unconfirmed` (hidden from patients) to keep data honest. |
| `CheckCabinetDepletionJob` | daily 06:00 UTC (8 AM Cairo) | Family cabinet 7-day depletion warnings to owners + caregivers. |

### 4.6 Real-Time Layer

SignalR hub `/hubs/reservations` (JWT via `?access_token=` for WebSockets), auto-joining `user:{id}` groups with `reservation:{id}` and `pharmacy:{id}` channels:

- `ReservationStatusUpdated` — Active → Ready → OutForDelivery → Completed/Cancelled, live in the patient's reservations screen (auto-refresh + "مباشر" indicator).
- `QueueOfferDispatched` — instant 15-minute offer sheet with countdown.

### 4.7 Security & Privacy

- JWT access tokens (15 min) + rotating, hashed, device-aware refresh tokens with revocation chains.
- Role-separated areas (Patient / PharmacyOwner / Admin) enforced at route level.
- **Law 151/2020 compliance**: PII-stripped prescription crops, explicit "may the pharmacist see my meds?" consent gate, AES-256 encrypted health questionnaire.
- Secret management via user-secrets/environment — no credentials in the repository (enforced by GitHub Push Protection).

---

## 5. Mobile Application

Arabic-first (RTL, Cairo font), single Flutter codebase serving three roles.

**Patient surfaces**: home search (text/voice/camera), all-results + pharmacy details, prescription scanner HUD (radar animation, staged analysis), prescription basket with split plans, safety-shield dialog, passes (QR), my reservations (live), alerts (autocomplete from the EDA catalog + "from my medications" chips + pause toggle + queue state + live availability), family cabinet, notifications (consumed-once offer actions), support tickets, favorites, reports.

**Pharmacy surfaces**: onboarding wizard, 5-tab dashboard (orders with WhatsApp runner dispatch, inventory with quick barcode scanner sheet, shortage queue, sales ledger, profile).

**Admin surfaces**: dashboard, pharmacy review, report moderation, ticket handling.

**Core services**: Retrofit API client (Dio, single-flight token refresh, endpoint failover), SignalR client with exponential reconnect, ML Kit OCR service, prescription frame cropper, Arabic medication mapper, voice search, local notifications, OpenStreetMap (flutter_map).

---

## 6. Data & Scale Characteristics

| Metric | Value |
|---|---|
| EF Core migrations | 18 (incl. raw SQL spatial indexes) |
| REST controllers / endpoints | 17 / ~90 |
| Background jobs | 6 job classes + 4 schedulers, 32 Hangfire workers |
| EDA catalog (seeded) | 373 medications (CSV-overridable to full registry) |
| Test dataset | 50 real Giza/6th-October pharmacies, 1,000 inventory items with deliberate EDA price variance |
| Gemini quota | 1,400 scans/day with failover tiers |
| Reservation hold / offer window / cancel lock | 2 h / 15 min / 15 min |
| Trust score | 0–100, 2% EDA price tolerance |
| Automated tests | 37 files / 228 backend + 145 Flutter tests, all passing |
| Docker | docker-compose: SQL Server 2022 + Redis 7 (AOF) + API |

---

## 7. Quality Engineering

- **Concurrency correctness**: optimistic concurrency on reservations and offer claims; dedicated queue-concurrency integration tests.
- **Adversarial OCR tests**: handwriting degradation, dialect noise, partial crops.
- **Split-optimizer tests**: coverage, savings, and route metrics across candidate sets.
- **Clinical safety tests**: duplicate ingredients, allergy conflicts, chronic-condition advisories, pre-checkout safety endpoint.
- **Price-integrity tests**: EDA compliance boundaries (exactly 2% tolerance) and badge text.
- **Flutter widget tests**: fulfillment flows, fulfillment modality prompts, sanitized-crop attachment, adversarial 409/network resilience.

---

## 8. Roadmap (Next Phases)

1. **Full EDA registry ingestion** — replace the 373-drug curated seed with the complete official catalog via the supported CSV path (zero code change).
2. **Push notifications end-to-end** — FCM service is stubbed; wire `firebase_messaging` into the Flutter app to complement in-app + SignalR delivery.
3. **Pharmacy POS integrations** — prebuilt connectors on top of the existing `pos-sync` batch contract (Orgasoft/PharmaSoft SKU mapping).
4. **B2B dashboards** — shortage heat-maps and demand analytics for distributors and the EDA itself.
5. **iOS release** — the Flutter codebase is platform-neutral; signing + store pipeline.
6. **Multi-city rollout** — spatial infrastructure is already index-backed; scale-out is a data-operation, not a code change.

---

## 9. Why Nawaqs Wins

1. **Egypt-native by design** — Arabic/English drug-name normalization with dialect + phonetics, EDA official pricing baked into search results, Law 151/2020 privacy engineering, WhatsApp dispatch, and a fair-queue that matches how scarce medications actually get allocated on the ground.
2. **Clinically serious** — regimen-aware safety checks on every reservation, pharmacist clinical rejection with alternatives, chronic-patient features (regimen, family cabinet, depletion alerts) — not just "find a store".
3. **Operationally complete for pharmacies** — barcode-to-inventory in seconds, POS sync, live order management, and a trust economy that rewards accurate stock and honest pricing.
4. **Engineered for trust** — every stock row decays to "unconfirmed" without refresh; every price is checked against the official ceiling; every queue is provably FIFO; every reservation race is handled atomically.
5. **Production-grade foundations** — clean architecture, 373 test cases across two stacks, Hangfire observability, Docker environment, and a documented seed/cleanup path for realistic demos and load testing.

---

*Appendices available in-repo: `docs/IMPLEMENTATION_BLUEPRINT.md`, `docs/SECOND_BRAIN.md`, `docs/PRESCRIPTION_OCR_OVERHAUL_PLAN.md`, `docs/ANDROID_RELEASE.md`, `docs/BRANDING_PROPOSALS.md`, and the executable test-data pipeline in `scripts/`.*
