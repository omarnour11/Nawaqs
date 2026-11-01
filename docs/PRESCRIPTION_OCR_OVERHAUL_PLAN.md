# Prescription OCR System Overhaul: Architecture & Implementation Plan

**System**: Nawakes Healthcare Platform (`Nawakes.API` & `nawakes_mobile`)  
**Document Version**: 1.0.0  
**Date**: October 2026  
**Status**: Approved Architecture & Implementation Blueprint  

---

## 1. Executive Summary & Problem Context

In Egypt, doctor prescriptions (روشتات الأطباء) represent the primary clinical document for patient medication fulfillment. However, they present extreme OCR challenges:
1. **Medical Cursive Handwriting**: Highly stylized, rapid, non-standard cursive handwriting with custom shorthand and ligatures.
2. **Multilingual Blending**: Latin trade names (e.g., *Concor*, *Augmentin*, *Glucophage*) mixed with Arabic clinical instructions (e.g., *قرص يومياً بعد الإفطار*) and Latin medical abbreviations (*Rx*, *tab*, *cap*, *bid*, *tid*, *prn*).
3. **Capture Variations**: Mobile photos captured under suboptimal indoor lighting, camera shake, wrinkled paper pads, doctor stamps, and clinic letterhead noise.

### Deficiencies in Current Pipeline
- **Mobile Client-Side Blocker**: The mobile application utilizes Google ML Kit text recognition configured exclusively for `TextRecognitionScript.latin`. When ML Kit encounters messy Arabic/Latin cursive handwriting, it frequently returns 0 lines. The client code (`camera_scan_sheet.dart` line 181 and `prescription_source_sheet.dart` line 60) immediately halts and shows an error, never sending the photo to the backend.
- **Narrow Center Crop**: `PrescriptionFrameCrop` cuts a fixed center box from the camera stream, truncating top/bottom medications.
- **Payload Inefficiencies**: Converting images to base64 strings in JSON inflates payload size by 33%, causing failures on slow mobile connections and triggering a hardcoded 6MB limit.
- **Quota Fragility**: Backend Gemini Vision uses in-process memory caching for quota tracking (lost on server restart), and a single HTTP 429 trips a 1-hour circuit breaker.

This document defines an end-to-end, production-grade architectural overhaul to replace the low-accuracy pipeline with a resilient, multi-tiered AI and clinical verification system.

---

## 2. End-to-End System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Mobile Client (Flutter)                         │
├───────────────────────────┬────────────────────────────────────────────┤
│ Full Prescription Camera  │ • Auto document boundary detection         │
│ & Gallery Picker          │ • Contrast enhancement & EXIF orientation  │
│                           │ • Optional on-device ML Kit text preview   │
└─────────────┬─────────────┴────────────────────────────────────────────┘
              │ Multipart POST /api/v1/search/parse-prescription-image
              ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     Backend Web API (Nawakes.API)                      │
├────────────────────────────────────────────────────────────────────────┤
│ Rate Limiter & Ephemeral Store (Redis-backed quota + 15-min image TTL)  │
└─────────────┬──────────────────────────────────────────────────────────┘
              │
      ┌───────┴───────────────────────────────┐
      ▼                                       ▼
┌───────────────────────────┐   ┌────────────────────────────────────────┐
│  Tier 1: Cloud Vision AI  │   │     Tier 2: Specialized OCR Cloud      │
│  (Gemini 1.5/2.0 Flash)   │   │  (Azure AI Vision 4.0 Read / G-Vision) │
│ • Handwriting extraction  │   │ • Dense multilingual handwriting text  │
│ • Structured JSON output  │   │ • Word-level bounding boxes           │
└─────────────┬─────────────┘   └───────────────────┬────────────────────┘
              │                                     │
              └───────────────────┬─────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────────┐
│             Tier 3: Clinical Validation & Feasibility Gate             │
│                     (ClinicalPrescriptionMatcher)                      │
├────────────────────────────────────────────────────────────────────────┤
│ • Consonant skeleton compression & Egyptian phonetic normalization    │
│ • 37k Official EDA Drug Catalog matching                               │
│ • Look-Alike Sound-Alike (LASA) safety check                           │
│ • Dosage Feasibility Gate (verify brand actually exists in dosage)     │
└─────────────┬──────────────────────────────────────────────────────────┘
              ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      Client Interactive Review                         │
├────────────────────────────────────────────────────────────────────────┤
│ • PrescriptionBasketScreen: review, edit quantities, add/remove items  │
│ • 1-Tap Batch Search across nearest pharmacies                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Pipeline Stages & Detailed Engineering

### Stage 1: Client Capture & Preprocessing (Flutter)
1. **Full-Frame Document Capture**:
   - Replace fixed center-box cropping with full camera view framing.
   - Display a non-destructive guideline overlay for document alignment.
2. **On-Device Preprocessing**:
   - Correct orientation via EXIF metadata.
   - Perform local contrast normalization (histogram equalization or adaptive thresholding) to sharpen faint ballpoint pen strokes.
3. **Non-Blocking On-Device OCR**:
   - Run ML Kit Text Recognition as a fast preliminary heuristic or offline indicator.
   - **Crucial Rule**: Even if local ML Kit returns 0 recognized lines, the mobile client **must never abort**. The image is immediately forwarded to the cloud vision tier.
4. **Transport Optimization**:
   - Transition from base64 JSON payload to standard `multipart/form-data` uploads (`POST /api/v1/search/parse-prescription-image`).
   - Compress JPEG with quality factor 85, balancing file size (~400KB - 800KB) and OCR resolution ($\ge 1500 \times 2000$ px).

### Stage 2: Ingestion & Ephemeral Storage (Backend)
1. **Endpoint**: `POST /api/v1/search/parse-prescription-image`
2. **Security & Privacy Isolation**:
   - Prescriptions contain sensitive patient medical data.
   - Images are processed in-memory or stored in ephemeral storage with an enforced 15-minute Time-To-Live (TTL).
   - Once clinical parsing and catalog matching are completed, raw image data is purged.
3. **Distributed Rate Limiting & Quota Management**:
   - Replace `IMemoryCache` with Redis-backed distributed atomic counters (`IDistributedCache`).
   - Implement exponential backoff with jitter for transient provider failures instead of a blanket 1-hour circuit breaker.

### Stage 3: Multi-Engine AI & OCR Ensemble
The architecture employs a 3-tier ensemble:

#### Tier 1: Multimodal Vision LLM (Primary Engine)
- **Model**: Google Gemini 1.5 Flash / Gemini 2.0 Flash (`models/gemini-1.5-flash`).
- **Capabilities**: Unmatched semantic understanding of medical context, deciphering cursive doctor abbreviations (*Aug 1g* $\rightarrow$ *Augmentin 1g*, *Concr 5* $\rightarrow$ *Concor 5mg*).
- **Configuration**:
  - `temperature`: 0.0 (deterministic clinical extraction).
  - `responseMimeType`: `application/json`.
  - Prompt enforces exclusion of physician names, clinic letterheads, patient names, and addresses.
  - Returns array of medications: `tradeName`, `activeIngredient`, `strength`, `dosageForm`, `frequency`, `quantity`, `confidence`.

#### Tier 2: Specialized Document Cloud OCR (Secondary Failover)
- **Service**: Azure AI Vision 4.0 Read API or Google Cloud Vision Document Text Detection.
- **Trigger**: Automatic fallback when Tier 1 encounters HTTP 429 (quota exhaustion) or timeout (> 15 seconds).
- **Function**: Extracts high-precision word tokens and line clusters from handwritten Arabic and Latin text, feeding raw lines to Tier 3.

#### Tier 3: In-Process Clinical Validation Gate (`ClinicalPrescriptionMatcher`)
Regardless of whether Tier 1 or Tier 2 extracts candidate strings, **every candidate must pass through the Clinical Validation Gate**:
1. **Colloquial Egyptian Normalization**: Applies Egyptian dialect rule tables (e.g., *كونكور* $\rightarrow$ *Concor*, *أوجمنتين* $\rightarrow$ *Augmentin*).
2. **Consonant Skeleton & Phonetics**: Handles dropped vowels in doctor handwriting (*Concr* $\rightarrow$ *CNCR* $\rightarrow$ *Concor*) and Egyptian phonetic consonant swaps (*P* $\leftrightarrow$ *B*, *PH* $\leftrightarrow$ *F*, *C* $\leftrightarrow$ *K*).
3. **Official EDA Catalog Matching**: Matches against the 37,000 official Egyptian Drug Authority catalog entries cached in memory with zero database I/O.
4. **Dosage Feasibility Gate (LASA Safety Protection)**:
   - Validates whether the extracted dosage legally exists for that brand in Egypt (e.g., *Concor 5mg* is feasible; *Concor 500mg* is flagged as infeasible).
   - Prevents Look-Alike Sound-Alike medication errors.

---

## 4. Error Handling, Resilience & Disambiguation

| Scenario | System Behavior | User Experience |
|---|---|---|
| **Tier 1 Quota / 429** | Transparently fails over to Tier 2 (Cloud OCR) + Tier 3 (Local Matcher). | Seamless; processing completes without user-visible error. |
| **Complete Network Offline** | Falls back to local on-device ML Kit + cached top-500 chronic medication catalog. | Displays offline indicator; prompts user to confirm extracted items. |
| **Low Confidence (< 0.90) or Multiple Matches** | Backend flags `requiresDisambiguation: true` with top 3 candidates. | Opens `DisambiguationSheet` allowing 1-tap candidate selection. |
| **Unreadable Image (severe blur / obstruction)** | Returns `isSuccess: false` with specific Arabic feedback code (`BLURRY_IMAGE`, `NO_MEDICATIONS_FOUND`). | Friendly snackbar/modal: "الصورة غير واضحة، يرجى إعادة التصوير في إضاءة أفضل". |

---

## 5. Multi-Medication Basket Integration

Once parsed, candidate medications are packaged into the reactive prescription basket:
1. Opens `PrescriptionBasketScreen`.
2. Each item displays:
   - Extracted trade name.
   - Identified strength and dosage form.
   - Recommended quantity counter (default 1, editable via stepper).
   - Confidence indicator.
3. The patient can edit, add manual medications, or delete incorrect items.
4. Tapping "بحث جماعي" (Batch Search) executes multi-item inventory lookup, prioritizing pharmacies that have all medications in stock.

---

## 6. Implementation Rollout Plan

### Phase 1: Client Capture Unblocking & Multipart Endpoint (Sprint 1)
- [ ] Remove hard failure on `lines.isEmpty` in `camera_scan_sheet.dart` and `prescription_source_sheet.dart`.
- [ ] Implement `POST /api/v1/search/parse-prescription-image` accepting `IFormFile` (multipart) in `SearchController.cs`.
- [ ] Wire mobile `ImagePickerService` and `ApiClient` to use multipart upload.

### Phase 2: Distributed Quota & Vision Prompt Engineering (Sprint 2)
- [ ] Migrate Gemini quota tracking from `IMemoryCache` to Redis (`IDistributedCache`).
- [ ] Refine Gemini Vision prompt with few-shot examples of Egyptian handwritten prescriptions and abbreviations (*tab*, *amp*, *bid*, *tid*, *pc*).
- [ ] Implement exponential backoff for rate limiting.

### Phase 3: Secondary Cloud OCR Integration (Sprint 3)
- [ ] Add Azure AI Vision / Cloud Document OCR client in `Nawakes.Infrastructure/NLP/`.
- [ ] Implement automatic failover orchestration in `ParseMultimodalQueryCommandHandler.cs`.

### Phase 4: Mobile Perspective Correction & Edge Polish (Sprint 4)
- [ ] Add lightweight edge detection / perspective rectification in Flutter camera view.
- [ ] Enhance `PrescriptionBasketScreen` with real-time stock pre-check indicators.
- [ ] End-to-end device testing on Samsung Galaxy A35 and Android/iOS test devices.
