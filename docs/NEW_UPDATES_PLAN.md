# Nawaqs Comprehensive System Updates & Enhancements Plan

## Overview
This document outlines the architectural and user-experience enhancements for Nawaqs, based on end-to-end device testing of the mobile app (`nawakes_mobile`) and backend (`Nawakes.API`).

---

## 1. Real-time Notification State & Unread Badge Counter
- **Issue**: Tapping "Mark all as read" (`تحديد الكل كمقروء`) or clicking an individual notification marks records read on the backend, but the red badge counter does not decrement or reset in the app bar.
- **Root Cause**: `notifications_screen.dart` invalidated only `myNotificationsProvider` and omitted `unreadNotificationsCountProvider`.
- **Solution**:
  - Invalidate `unreadNotificationsCountProvider` upon bulk mark-as-read and individual item read events.
  - Implement an eager state reset method on `UnreadNotificationsCount` notifier to immediately set count to `0`.

---

## 2. Advanced Support Tickets & Complaints System
- **Issue**: Ticket submission is too generic and lacks contextual linking to recent pharmacy transactions and image evidence.
- **Patient Experience (`support_screen.dart`)**:
  - **Recent Pharmacy Selector**: Displays the last 3 pharmacies the patient conducted reservations with.
  - **Auto-populated Order Dropdown**: When a pharmacy is selected, dynamically loads the last 2–3 reservations (displaying medication names like Panadol, Cataflam, reservation code, and date) for 1-tap dispute selection.
  - **Photo Proof Upload**: Optional evidence image attachment using `image_picker` uploaded to `/api/v1/uploads`.
  - **Ticket Thread & Access Control**:
    - **Closed/Resolved**: Read-only mode with a clear resolution banner.
    - **Open (Pending Review)**: Informs the patient that an admin has not yet opened the ticket (`canReply: false`).
    - **In Progress**: Full interactive chat thread enabled with the assigned admin.
- **Admin Experience (`admin_ticket_detail_screen.dart`)**:
  - Full pharmacy summary card (name, address, phone, trust score, owner email).
  - Quick-action button: "View Pharmacy Details" (`عرض بيانات الصيدلية`).
  - Order details card displaying the dispute's reservation code and medication.
  - Full-resolution modal viewer for attached evidence photos.

---

## 3. Expired Reservation Enforcement & Background Job Resilience
- **Issue**: Expired reservations could still be completed/handed over when the pharmacist entered the code, because status was not updated to `Expired` in the database.
- **Root Cause**:
  1. `ReservationExpiryJob` crashed on `SaveChangesAsync` because EF Core's `SqlServerRetryingExecutionStrategy` rejects ambient user transactions without `CreateExecutionStrategy()`.
  2. `CompleteReservationCommandHandler` only verified `Status == Active` and neglected to check `ExpiresAt <= DateTime.UtcNow`.
- **Solution**:
  - Wrap database execution in `context.Database.CreateExecutionStrategy()` in `ReservationExpiryJob.cs`.
  - Add explicit expiry guards in `CompleteReservationCommandHandler.cs`: if `ExpiresAt <= DateTime.UtcNow`, automatically transition status to `Expired`, revert inventory, and reject completion with `ConflictException`.

---

## 4. Typography & Button Text Rendering
- **Issue**: Button labels like "حجز" and "إلغاء" showed detached/disconnected Arabic cursive letters ("ح ج ز", "إ ل غ ا ء").
- **Root Cause**: `letterSpacing: 0.4` was set in typography styles (`app_theme.dart`). In Flutter, non-zero letter spacing breaks Arabic glyph shaping.
- **Solution**:
  - Set `letterSpacing: 0.0` for all styles in `TextTheme` across the app.
  - Ensure flexible button sizing and padding in `active_orders_tab.dart` so labels do not truncate or wrap awkwardly.

---

## 5. Pharmacy Inventory: Fix Add Medication String/Null Deserialization Error
- **Issue**: Adding a medication succeeded in the database, but triggered a client-side error: `type 'Null' is not a subtype of type 'String'`.
- **Root Cause**:
  - `AddInventoryItemCommandHandler` returned `InventoryItemDto` without `CreatedAt`.
  - `PharmacyInventoryItemDto` in Flutter declared `final DateTime createdAt;` as non-nullable.
- **Solution**:
  - Include `CreatedAt = item.CreatedAt` in `InventoryItemDto`.
  - Make `createdAt` nullable or provide default fallback in `PharmacyInventoryItemDto.fromJson`.

---

## 6. Pharmacy Inventory: Item Management (Settings Cog, Quantity Editing, & Safe Deletion)
- **Issue**: Pharmacists lacked the ability to delete items or modify quantities with custom precision.
- **Solution**:
  - **Backend**:
    - Add `DELETE /api/v1/pharmacy/inventory/{id}` endpoint.
    - Check for active reservations before deletion; prevent deletion if active orders exist (`ConflictException`).
    - Soft-delete or mark item so historical sales records and patient reservation histories remain intact.
    - Invalidate search and inventory caches.
  - **Mobile**:
    - Add a settings gear / menu icon (`Icons.settings_outlined`) to `_MedCard` in `inventory_tab.dart`.
    - Provide a management bottom sheet:
      - Custom quantity editor (numeric field + stepper).
      - Price editor.
      - Delete button with confirmation dialog.

---

## 7. Pharmacy Sales Ledger: Order Details & Patient Contact
- **Issue**: Pharmacist could not view order details or reach out to the patient when tapping on a completed sales order.
- **Solution**:
  - Make `_LedgerRow` in `sales_ledger_screen.dart` interactive (`InkWell`).
  - Open an "Order Details" modal bottom sheet:
    - Medication name, quantity, unit price, and total revenue.
    - Reservation code with quick copy.
    - Completion timestamp.
    - Patient contact number and display name, with direct 1-tap Call and WhatsApp actions.

---

## 8. Pharmacy Registration & Profile: Guided Location UX
- **Issue**: Map pin placement during registration and onboarding was unintuitive and prone to inaccuracy.
- **Solution**:
  - Automatically fetch device GPS and prompt: "Is this location accurate?" (`هل هذا موقع صيدليتك بدقة؟`).
  - Provide an in-sheet search bar using OpenStreetMap Nominatim with localized bounding/proximity bias (e.g. 6th of October City) so searching "العزبي" prioritizes local branches rather than global hits.
  - Tapping a search result smoothly animates the map camera to the target pharmacy coordinate.

---

## 9. Pharmacy Critical Data Re-review Workflow
- **Issue**: Modifications to approved pharmacy profiles did not trigger admin re-verification.
- **Solution**:
  - In `RegisterPharmacyCommandHandler.cs`, if an approved pharmacy modifies critical identity attributes (`Name`, `GeoPoint`, `LicenseDocUrl`, `NationalIdDocUrl`), set `VerificationStatus = VerificationStatus.Pending`.
  - Display an "Under Review" banner in the pharmacy dashboard until the admin approves changes.

---

## 10. Direct File & National ID Document Uploads
- **Issue**: Pharmacists were forced to enter external URLs for licenses and national IDs instead of uploading files directly.
- **Solution**:
  - **Backend**: Introduce `POST /api/v1/uploads` accepting `multipart/form-data` (images/PDF, max 10MB), storing securely and returning `{ url }`.
  - **Mobile**: Replace URL text fields with upload cards featuring camera/gallery picker, thumbnail previews, and upload progress indicators.

---

## 11. Bottom Navigation Bar Label Stability
- **Issue**: Navigation bar labels in pharmacy and admin dashboards only appeared when active (`onlyShowSelected`), causing visual jumping.
- **Solution**:
  - Update `labelBehavior` to `NavigationDestinationLabelBehavior.alwaysShow` in both `pharmacy_dashboard_screen.dart` and `admin_dashboard_screen.dart`.

---

## 12. Admin Community Reports & Dispute Resolution
- **Issue**: Admin report moderation lacked investigation tools and communication channels with pharmacies.
- **Solution**:
  - Expand `AdminReportsScreen` with a detailed dispute inspection view:
    - Pharmacy credentials and rating.
    - Linked order/reservation data and patient description.
    - "Inquire / Send Notification to Pharmacy" action to solicit clarification.
    - Pharmacy justification view before confirming penalties or dismissing the report.

