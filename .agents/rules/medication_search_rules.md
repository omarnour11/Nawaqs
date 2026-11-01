---
trigger: always_on
description: "Rules for medication search, voice recognition, and multi-medication fulfillment in Nawaqs"
---

# Medication Search & Voice Recognition Invariants

1. **Arabic-First Catalog Lookup**:
   When handling spoken voice or patient inputs in Arabic/Egyptian dialect, always query the local database/catalog using the normalized Arabic string first. Only fallback to phonetic transliteration or English mapping if no direct catalog match exists.

2. **Multi-Medication Single-Pharmacy Priority**:
   When fulfilling a batch/prescription containing multiple medications:
   - Always prioritize a single nearest pharmacy that has ALL requested medications in stock.
   - Only split across multiple pharmacies via greedy assignment when no single pharmacy has complete stock.

3. **Reactive Voice UI State**:
   Always link real-time speech transcription to reactive state (`useState`, `StateNotifier`) in Flutter widgets rather than passive controllers, ensuring animated overlays reflect live speech.

