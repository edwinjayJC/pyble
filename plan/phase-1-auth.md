# Phase 1: Setup & Scan (Host Flow)

**Objective:** Enable the Host to create a table, scan/add bill items, and invite participants. This phase focuses on the Host's initial setup flow after they've already paid the restaurant bill. Also includes onboarding, authentication, and terms acceptance.

**References:**
* **Master Spec:** `CLAUDE.md` (Sections 5.1 & 6)
* **Design System:** `system-design.md`
* **API Schema:** `backend-api.md` - The source of truth for our api calls.


---

## 1. High-Level Goals

1. **Onboarding:** Show tutorial on first launch, persist completion status.
2. **Authentication:** Supabase Auth via `supabase_auth_ui` package.
3. **Terms Acceptance:** Require T&Cs acceptance before app use.
4. **Create Table:** Host creates a new `TableSession` with status `claiming`.
5. **Active Table Check:** Prevent creating multiple active tables.
6. **Scan Bill (AI Path):** Send image to API for OCR parsing.
7. **Manual Entry (Escape Hatch):** Allow manual item entry if scan fails.
8. **Invite Participants:** Display QR code, 6-char code, and share link.

---

## 2. Feature Breakdown

### 2.0 Onboarding & Authentication Flow

#### 2.0.1 Tutorial Screen (`/onboarding`)

* **First Launch Check:**
  * Check `shared_preferences` for `tutorialSeen` key
  * If false or not set, show onboarding
* **UI Components:**
  * Welcome message: "Welcome to Pyble"
  * App overview/benefits (can be carousel or single page)
  * "Get Started" button
* **On Complete:**
  * Set `tutorialSeen = true` in `shared_preferences`
  * Navigate to `/auth`

#### 2.0.2 Authentication Screen (`/auth`)

* **Using `supabase_auth_ui` Package:**
  * Pre-built auth UI components
  * Support for email/password
  * Support for OAuth providers (Google, Apple, etc.)
* **Session Persistence:**
  * Supabase handles session restore automatically
  * Check `supabase.auth.currentSession` on app start
* **On Success:**
  * Load `UserProfile` from API
  * Check `hasAcceptedTerms`
  * Navigate accordingly

#### 2.0.3 Terms & Conditions Screen (`/terms`)

* **Trigger:** User authenticated but `hasAcceptedTerms == false`
* **UI Components:**
  * Scrollable terms text
  * "Accept & Continue" button
* **API Call:** Update `UserProfile.hasAcceptedTerms` to true
* **On Accept:** Navigate to `/home`

#### 2.0.4 Session Restore Flow

On app start:
1. Check `tutorialSeen` from `shared_preferences`
2. If false → `/onboarding`
3. If true, check `supabase.auth.currentSession`
4. If no session → `/auth`
5. If session exists, load `UserProfile` from API
6. If `!hasAcceptedTerms` → `/terms`
7. Otherwise → `/home`

### 2.1 Create Table Screen (`/create-table`)

* **Trigger:** Home screen "Create Table" button.
* **Pre-Check:**
  * Call `GET /tables/active` to check for existing active tables.
  * If active table exists, show dialog: "Resume existing table" or "Cancel".
* **API Call:** `POST /tables` with optional title.
* **Response:** API returns `{ table: TableSession, signalRNegotiationPayload: {...} }`.
* **Navigation:** On success, navigate to `/table/:tableId/scan`.

### 2.2 Scan Bill Screen (`/table/:tableId/scan`)

* **UI Components:**
  * Camera capture button (using `image_picker` or `mobile_scanner`)
  * Gallery picker option
  * "Add Items Manually" text button
  * Loading indicator during scan
  * Items list display after scanning

* **AI Scan Flow (Magic Path):**
  1. User captures/selects image.
  2. Call `POST /tables/:tableId/scan` with image bytes.
  3. API calls AI service (Gemini/GPT) for OCR.
  4. API parses items and adds to `SplitTable.items` array.
  5. Client reloads table data to show new items.

* **Manual Entry (Escape Hatch):**
  * **"Add Items Manually"** button opens dialog:
    - Item description field
    - Price field (numeric input)
    - Calls `PUT /tables/:tableId/item` to add single item
  * **"Enter Total & Split Evenly"** button:
    - Single total amount field
    - Creates one `BillItem` with full total

* **Success State:**
  * Display list of all added items
  * Show total at bottom
  * "Continue to Invite" button

### 2.3 Host Invite Screen (`/table/:tableId/invite`)

* **UI Components:**
  * Large QR code (generated using `qr_flutter`)
  * 6-character table code (prominently displayed)
  * "Copy Code" button
  * "Share Invite Link" button (using `share_plus`)
  * List of joined participants (initially just Host)

* **QR Code Content:**
  * Deep link format: `pyble://join?code=ABC123`
  * Use `TableRepository.getJoinLink(tableCode)` to generate

* **Share Link:**
  * Generate invite link with table code
  * Use `Share.share()` to open system share sheet

* **Participant Display:**
  * Show avatars/initials of joined participants
  * Real-time update via API polling (every 3 seconds)
  * "Continue to Claiming" button when ready

---

## 3. Data Models Required

### TableSession
```dart
class TableSession {
  final String id;
  final String code;
  final String hostUserId;
  final TableStatus status; // claiming, collecting, settled, cancelled
  final String? title;
  final DateTime createdAt;
  final DateTime? closedAt;
}
```

### BillItem
```dart
class BillItem {
  final String id;
  final String tableId;
  final String description;
  final double price;
  final List<ClaimedBy> claimedBy;
}
```

---

## 4. API Endpoints Required

| Endpoint | Method | Description |
|:---------|:-------|:------------|
| `/tables/active` | GET | Check for user's active table |
| `/tables` | POST | Create new table |
| `/tables/:tableId` | GET | Get table data with items/participants |
| `/tables/:tableId/scan` | POST | AI scan bill image |
| `/tables/:tableId/item` | PUT | Add single item manually |

---

## 5. Riverpod Providers

* `tableRepositoryProvider` - Repository instance
* `currentTableProvider` - AsyncNotifier for current table state
* `isHostProvider` - Boolean if current user is host
* `tableBillItemsProvider` - Derived list of items

---

## 6. Definition of Done (Acceptance Criteria)

### Onboarding & Auth
* [ ] Tutorial screen shows on first launch (when `tutorialSeen` is false).
* [ ] "Get Started" button sets `tutorialSeen = true` and navigates to auth.
* [ ] Auth screen uses `supabase_auth_ui` for email/password and OAuth.
* [ ] Session persists across app restarts via Supabase.
* [ ] Terms screen shows when `hasAcceptedTerms` is false.
* [ ] Accepting terms updates `UserProfile` and navigates to home.
* [ ] GoRouter redirects enforce the onboarding → auth → terms → home flow.

### Table Creation & Scanning
* [ ] Host can tap "Create Table" and new `TableSession` is created with `status: 'claiming'`.
* [ ] If Host has active table, dialog prompts to resume or cancel.
* [ ] Host is navigated to scan screen after table creation.
* [ ] Host can capture photo or pick from gallery.
* [ ] Image is sent to API for AI parsing.
* [ ] Items returned from AI are displayed in list.
* [ ] If scan fails, Host can add items manually via dialog.
* [ ] Host can enter single total amount for even split.

### Host Invite
* [ ] Host can navigate to invite screen.
* [ ] QR code displays with correct deep link (`pyble://join?code=ABC123`).
* [ ] 6-character code is prominently displayed.
* [ ] "Copy Code" button copies to clipboard.
* [ ] "Share" button opens system share sheet.
* [ ] Participants list updates via API polling.

### General
* [ ] All UI follows `system-design.md` (Deep Berry, Dark Fig, Snow colors).
* [ ] Currency symbol is consistent ($) throughout.
