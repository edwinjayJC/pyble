# claude.md

You are an expert Flutter engineer and software architect.  
Build a **production-ready, modular Flutter app** that implements the following product spec.

> **Note for Claude Code**: This specification is comprehensive and sufficient for autonomous development. It outlines the full architecture, API-driven data flow, state management, and implementation phases. 
> 
> **The UI/UX design is specified in a separate document. Follow the `system-design.md` file strictly** for all colors (Deep Berry, Dark Fig, etc.), typography, components, and theme implementation.

---

## 1. HIGH-LEVEL PRODUCT SUMMARY

App name: **Pyble** – a group bill-splitting app for restaurant bills.

### Core Idea: The "Host-Confirmed Reimbursement" Model

This is a **reimbursement model**. The app's primary function is to help a **Host** (who has already paid the restaurant bill) get reimbursed by **Participants**.

1. The **Host** creates a "table," scans the bill, and invites Participants.
2. **Participants** join and see the itemized bill.
3. Everyone "claims" the items they consumed. The app supports **individual claims** and **complex multi-user splits**.
4. The Host can also **split "orphan" items** (like tax or tips) among all diners.
5. Once claiming is done, the **Host "locks" the bill** to begin collection.
6. Participants then **reimburse the Host** via two methods.

### Payment & Reimbursement Flows

This model is designed to **protect the Host** from financial loss.

1. **Pay in App (PIA): The "Convenience" Option**
   * The participant pays their total + a 4% app fee.
   * This uses the WebView polling flow specified later.
   * The result is **instant settlement**. The participant is marked as "PAID" immediately.

2. **Paid Outside App (POA): The "Free" Option**
   * The participant taps "Mark as Paid Outside" (for cash, EFT, etc.).
   * This is **not** instant. The participant's status changes to "Awaiting Host Confirmation."
   * The Host must **manually confirm** they received the money before the participant is marked as "PAID."

### Data & Auth Architecture

- **Authentication**: Handled *exclusively* by **Supabase Auth** via the `supabase_flutter` and `supabase_auth_ui` packages.
- **Application Data**: There is **no local database**. The app is online-only.
- **State Management**: All app state (current user, table data, bill items, etc.) is held in-memory using **Riverpod providers**.
- **Data Sync**: All application data is fetched from a **backend HTTP API**.
- **Data Freshness**: Data is kept up-to-date by **API polling** (e.g., `Timer.periodic` in a provider) or manual "pull-to-refresh." **There is no realtime websocket connection.**

---

## 2. UX DESIGN & VISUAL THEME

The complete visual design language, component library, color palette, typography, spacing system, and Flutter theme implementation are defined in the **`system-design.md`** file.

All UI development must **strictly adhere** to the specifications in that document, using the "Warm, Clear & Trustworthy" theme (Deep Berry, Dark Fig, Snow, etc.).

---

## 3. TECH STACK & ARCHITECTURE

Use:

- **Flutter** (latest stable, null safety).
- **Supabase** (via `supabase_flutter` & `supabase_auth_ui`) for OAuth, email/password auth, and session persistence **only**.
- **Backend HTTP APIs** (e.g., Azure Functions + Cosmos DB) for *all* application data (tables, participants, items, claims, payments).
- **API Polling** for data synchronization.
- **flutter_riverpod** for all state management.
- **go_router** for navigation and deep linking.
- **webview_flutter** for the payment flow.

Use the **latest stable** versions of these packages:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Core
  flutter_riverpod: ^3.0.3  # Or latest
  go_router: ^16.2.5       # Or latest

  # Auth
  supabase_flutter: ^2.10.3  # Or latest
  supabase_auth_ui: ^2.0.0   # Or latest

  # Payments
  webview_flutter: ^4.8.0    # Or latest
  
  # Utilities
  http: ^1.2.0
  qr_flutter: ^4.1.0
  mobile_scanner: ^6.0.0     # For scanning QR codes and bills
  shared_preferences: ^2.3.0
  share_plus: ^10.0.0
```

### Project Structure

(This structure supports the feature-based flow)

* `lib/core/`
  * `widgets/` - Reusable UI components from `system-design.md`
  * `constants/` - App-wide constants, route names
  * `router/` - GoRouter config, route names, deep-link parsing
  * `providers/` - Global Riverpod providers (Supabase client, auth state)
  * `api/` - API client/helper (handles `http` requests, auth headers)
* `lib/features/auth/`
  * `screens/` - Auth screen (using `supabase_auth_ui`)
* `lib/features/table/`
  * `models/` - TableSession, Participant, BillItem, ItemClaim
  * `providers/` - Table state, participants, bill items (will include polling logic)
  * `repository/` - TableRepository (makes API calls)
  * `screens/`
    * `create_table_screen.dart` (Phase 1)
    * `host_invite_screen.dart` (Phase 1)
    * `join_table_screen.dart` (Phase 2)
    * `claim_screen.dart` (Phase 2)
    * `host_dashboard_screen.dart` (Phase 3)
    * `participant_payment_screen.dart` (Phase 3)
  * `widgets/` - Bill item row, complex_split_sheet.dart, participant_status_row.dart
* `lib/features/ocr/`
  * `repository/` - OcrRepository (calls API with image)
  * `screens/` - Camera/scan screen
* `lib/features/payments/`
  * `providers/` - Payment status polling provider
  * `repository/` - PaymentRepository (gets URL, checks status)
  * `screens/` - PaymentWebviewScreen, PaymentProcessingScreen
* `lib/features/history/`
  * `screens/` - History list, history detail
* `lib/features/settings/`
  * `screens/` - Account settings, T&Cs, sign-out/delete

---

## 4. DOMAIN MODELS (API Data Structures)

Create Dart models with `fromJson` / `toJson` methods for the data returned by the API.

### 4.1 UserProfile

* `id` (UUID, matches `auth.users.id`)
* `displayName`
* `email`
* `avatarUrl` (nullable)
* `hasAcceptedTerms` (bool)

### 4.2 TableSession

* `id` (UUID)
* `code` (6-character alphanumeric, unique)
* `hostUserId`
* `status` (enum: `claiming`, `collecting`, `closed`, `cancelled`)
* `createdAt`
* `closedAt` (nullable)

### 4.3 Participant

* `id` (UUID)
* `tableId`
* `userId`
* `displayName`
* `initials`
* `paymentStatus` (enum: `owing`, `pending_confirmation`, `paid`)

### 4.4 BillItem

* `id` (UUID)
* `tableId`
* `description`
* `price` (numeric)

### 4.5 ItemClaim

* `id` (UUID)
* `billItemId`
* `userId`

**Even split logic** is derived in the client:

* `claimantsCount` for item = number of `item_claims` where `billItemId = this.id`.
* Per-user share for this item = `price / claimantsCount`.

### 4.6 PaymentRecord

* `id` (UUID)
* `tableId`
* `payerUserId`
* `receiverUserId` (Host)
* `amount`
* `fee` (e.g., the 4% app fee)
* `type` (enum: `app_payment`, `manual_payment`)
* `transactionStatus` (enum: `pending`, `completed`, `failed`)
* `paymentGatewayReference` (nullable)

---

## 5. APP FLOW & UX

### 5.1 Onboarding, Tutorial, T&Cs, and Persistent Login

(This flow is standard and precedes the main "Host-Confirmed Reimbursement" flow)

On app start:

1. **Session restore:**
   * Use `supabase.auth.currentSession`. If valid, load `UserProfile` from API.
   * If `hasAcceptedTerms` is true and `tutorialSeen` (from `shared_preferences`) is true, go to **Home Screen**.
   * If no session, show onboarding.
2. **Tutorial (first launch)**:
   * Show only when `tutorialSeen` is false.
   * Set `tutorialSeen = true` in `shared_preferences` when done.
3. **Terms & Conditions Screen**:
   * If `hasAcceptedTerms` is false.
   * On accept, call API to update `UserProfile.hasAcceptedTerms`.
4. **Auth (Supabase)**:
   * Show an auth screen that uses the **`supabase_auth_ui`** package.
   * On successful sign-in, GoRouter navigates to Home.

### 5.2 Routing

Use **GoRouter** with named routes:

* `/onboarding`
* `/auth`
* `/home`
* `/table/:code` (This will be the main screen, showing different content based on user/table state)
* `/payment-processing/:tableId`
* `/history`
* `/settings`

Include:

* Route guards for authenticated routes.
* Deep-link handling for `upeven://join?code=ABC123` → join table flow.

---

## 6. Phase 1: Setup & Scan (Host Flow)

This details the Host's actions to start a table, *after* they have already paid the restaurant.

1. **Create Table:**
   * Host taps "Create Table" on the `HomeScreen`.
   * **Tech**: Calls API to check for active tables. If none, calls API to create a new `TableSession` with `status: 'claiming'`. API returns the new `TableSession` object.
2. **AI Scan:**
   * Host is prompted to scan the physical bill.
   * **Tech (Magic Path)**: App sends image to `/api/v1/ocr_bill` API with `tableId`. API parses items and saves `BillItem` records. Client polls and displays the new items.
   * **Tech (Escape Hatch)**: If scan fails, Host is shown buttons:
     * "Add Items Manually": A form to call the API for each `BillItem`.
     * "Enter Total & Split Evenly": A form to create a single `BillItem` for the total.
3. **Invite Participants:**
   * The Host's screen now shows a big QR code, 6-character code, and "Share Invite Link" button.
   * **Tech**: The screen displays the `code` from the `TableSession` object. The QR code contains the deep link `upeven://join?code=ABC123`.

---

## 7. Phase 2: Live Claiming (All Users)

This is the "realtime" (polling-based) claiming process.

1. **Join Table:**
   * Participants scan the Host's QR code or use the link/code to join.
   * **Tech**: App calls API to join table with `code`. API validates `code`, finds `tableId`, and creates a new `Participant` record with `paymentStatus: 'owing'`.
2. **See List:**
   * All users see the itemized bill.
   * **Tech**: A Riverpod provider polls an API endpoint (e.g., `/api/v1/table/{tableId}/state`) to get all `BillItem`s and `ItemClaim`s.
3. **Claim Items (Individual):**
   * A user taps an item.
   * **Tech**: UI updates optimistically. App calls API (e.g., `POST /api/v1/claims`) to create an `ItemClaim`. The change is confirmed on the next poll.
4. **Claim Items (Shared):**
   * A user taps "Split this item." A bottom sheet shows all table members.
   * **Tech**: User selects people. On confirm, app calls a batch API (e.g., `POST /api/v1/claims/split`) with the `billItemId` and a list of `userIds`.
5. **Handle "Orphan" Items (Host Control):**
   * Host taps an unassigned item (e.g., "Tax") and selects "Split Among All Diners."
   * **Tech**: Host calls a special API endpoint (e.g., `POST /api/v1/items/{itemId}/split-all`) that creates `ItemClaim` records for *all* participants in the table.
6. **Lock Bill:**
   * Once all items are claimed, the Host taps **"Lock Totals & Start Collection."**
   * **Tech**: Host calls API (e.g., `PUT /api/v1/table/{tableId}/lock`) to update the `TableSession.status` from `'claiming'` to `'collecting'`. This is a critical state change.

---

## 8. Phase 3: Settlement & Collection

The app state now changes. All UI logic (driven by the `TableSession.status` provider) switches from claiming to collection.

### A. Participant Flow: The "Choice"

The Participant's screen (polling the API) sees the table status is now `'collecting'` and displays the payment screen: **"You owe [Host Name] $XX.XX"**.

**1. Pay in App (PIA) Path (The "Convenience" Option):**

* User taps the primary **"Pay in App"** button.
* A checkout screen shows the fee breakdown (e.g., `Amount: $28.50`, `Fee (4%): $1.14`, `Total: $29.64`).
* **Tech (Payment):**
  1. App calls `POST /api/v1/payments/initiate` with the amount and `tableId`.
  2. API returns a `paymentUrl` and `paymentId`.
  3. App navigates to `PaymentWebviewScreen` and loads the `paymentUrl`.
  4. User pays in the WebView.
  5. WebView redirects to a `callbackUrl`. The app's `NavigationDelegate` detects this, prevents navigation, and instead navigates to a `PaymentProcessingScreen`.
  6. The `PaymentProcessingScreen` shows a spinner and triggers a Riverpod provider to **poll** `GET /api/v1/payments/status/{paymentId}`.
  7. Once the API returns `status: 'completed'`, the backend *also* updates the `Participant.paymentStatus` to `'paid'`.
* **Result (Instant):** The polling provider updates, and the UI changes to the green "You're All Settled!" screen.

**2. Paid Outside App (POA) Path (The "Free" Option):**

* User taps the secondary **"Mark as Paid Outside"** button.
* **Tech**: App calls an API (e.g., `PUT /api/v1/participants/mark-pending`) to change their `Participant.paymentStatus` from `'owing'` to `'pending_confirmation'`.
* **Result (Pending):** The UI (which is polling this status) updates to show: **"Awaiting Host Confirmation..."** The user is *not* settled.

### B. Host Flow: The "Accountability Dashboard"

The Host's screen (polling the API) also sees the `'collecting'` status and displays the new "Collection Dashboard."

* **Tech**: The dashboard is a Riverpod provider polling `GET /api/v1/table/{tableId}/participants`. It displays a list based on the `paymentStatus` of each participant:
  * `Julie: PAID (In-App)` (where `paymentStatus == 'paid'`)
  * `Jared: OWES $22.00` (where `paymentStatus == 'owing'`)
  * `Mike: Awaiting Your Confirmation` (where `paymentStatus == 'pending_confirmation'`)
* **Host's Job:**
  * Mike (POA) gives the Host cash.
  * The Host taps on Mike's name in the app.
  * A prompt appears: "Confirm you received $XX.XX from Mike?"
  * **Tech**: Host taps "Confirm," which calls an API (e.g., `PUT /api/v1/participants/confirm-payment`) to set Mike's `Participant.paymentStatus` to `'paid'`.
* **Flow Completion:**
  * The Host's dashboard updates on its next poll to show `Mike: PAID (Outside)`.
  * Simultaneously, Mike's app (which is also polling its own status) sees the `paymentStatus` change to `'paid'` and automatically updates from "Pending..." to the green **"You're All Settled!"** screen.
