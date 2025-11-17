# Phase 2: Live Claiming (All Users)

**Objective:** Enable all users (Host and Participants) to join a table and claim items from the bill. This phase implements the "polling-based realtime" claiming process where users see updates via API polling.

**References:**
* **Master Spec:** `CLAUDE.md` (Section 7)
* **Design System:** `system-design.md`
* **API Schema:** `backend-api.md` - The source of truth for our api calls.

---

## 1. High-Level Goals

1. **Join Table:** Participants join via QR code, 6-char code, or deep link.
2. **See Itemized Bill:** All users view the bill items in real-time (via polling).
3. **Individual Claims:** Users tap items to claim them for themselves.
4. **Shared Claims:** Users split items among multiple people.
5. **Orphan Item Handling:** Host splits unclaimed items (tax/tip) among all diners.
6. **Lock Bill:** Host locks the table to transition to collection phase.

---

## 2. Feature Breakdown

### 2.1 Join Table Flow

* **Entry Points:**
  * Home screen "Join Table" button
  * Deep link: `pyble://join?code=ABC123`
  * QR code scan (contains deep link)
* **Join Table Screen (`/join-table`):**
  * 6-character code text field (uppercase, alphanumeric)
  * "Scan QR Code" button (opens camera scanner)
  * Auto-join if deep link provides code
* **API Call:** `POST /tables/join`
  * Body: `{ "code": "ABC123" }`
  * Validates code exists and table status is `claiming`
  * Creates new `Participant` with `paymentStatus: 'owing'`
  * Returns full table data (TableSession, Participants, Items)
* **Navigation:** On success, navigate to `/table/:tableId/claim`

### 2.2 Claim Screen (`/table/:tableId/claim`)

* **Real-time Updates (Polling):**
  * Use `Timer.periodic` (every 3 seconds) to poll `GET /tables/:tableId`
  * Update Riverpod provider with fresh data
  * UI automatically rebuilds with new state
* **UI Components:**
  * List of all bill items
  * Each item shows: description, price, claimed-by indicators
  * Participant avatars/initials for each claim
  * Running total at bottom
  * "Lock Totals & Start Collection" button (Host only)

### 2.3 Individual Item Claims

* **Trigger:** User taps on an item
* **Optimistic UI:** Immediately update local state (toggle claim)
* **API Call:** `POST /claims`
  * Body: `{ "billItemId": "uuid", "action": "claim" | "unclaim" }`
  * Creates or removes `ItemClaim` record
* **Error Handling:** If API fails, rollback optimistic update
* **Visual Feedback:**
  * Claimed items show user's avatar/initials
  * Highlight indicates "you claimed this"
  * Multiple claims show split indicator (e.g., "÷2", "÷3")

### 2.4 Shared Item Claims (Complex Splits)

* **Trigger:** User taps "Split this item" button on an item
* **Bottom Sheet (`ComplexSplitSheet`):**
  * Shows all table participants
  * Checkboxes for each person
  * Pre-select current user
  * "Confirm Split" button
* **API Call:** `POST /claims/split`
  * Body: `{ "billItemId": "uuid", "userIds": ["uuid1", "uuid2", "uuid3"] }`
  * Creates multiple `ItemClaim` records atomically
* **Split Calculation:**
  * Per-user share = `item.price / claimantsCount`
  * Example: $30 item with 3 claimants = $10 each

### 2.5 Orphan Item Handling (Host Only)

* **Orphan Items:** Items not claimed by anyone (e.g., tax, service charge, tip)
* **Host UI:** Unassigned items show "Split Among All Diners" option
* **API Call:** `POST /items/:itemId/split-all`
  * Creates `ItemClaim` records for ALL participants in the table
  * Automatically calculates even split
* **Use Cases:**
  * Tax split evenly
  * Shared appetizers
  * Service charges

### 2.6 Lock Bill (Transition to Collection)

* **Pre-conditions:**
  * All items must be claimed (no orphan items)
  * Only Host can lock
* **Trigger:** Host taps "Lock Totals & Start Collection" button
* **Confirmation Dialog:** "This will lock the bill and start collection. Continue?"
* **API Call:** `PUT /tables/:tableId/lock`
  * Updates `TableSession.status` from `claiming` to `collecting`
  * This is a critical state transition
* **Post-Lock Behavior:**
  * Claiming is disabled for all users
  * Auto-navigate: Host → Dashboard, Participants → Payment Screen
  * Polling provider detects status change and triggers navigation

---

## 3. Data Flow Architecture

### API Polling Pattern

```dart
class CurrentTableNotifier extends AsyncNotifier<TableData> {
  Timer? _pollingTimer;

  void startPolling() {
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshTableData(),
    );
  }

  Future<void> _refreshTableData() async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final repository = ref.read(tableRepositoryProvider);
    final freshData = await repository.getTableById(currentData.table.id);
    state = AsyncValue.data(freshData);
  }

  void stopPolling() => _pollingTimer?.cancel();
}
```

### Optimistic Updates

```dart
Future<void> claimItem(String itemId) async {
  final currentData = state.valueOrNull;
  if (currentData == null) return;

  // 1. Optimistic update
  final optimisticItems = _addClaimLocally(currentData.items, itemId);
  state = AsyncValue.data(currentData.copyWith(items: optimisticItems));

  try {
    // 2. API call
    await repository.claimItem(tableId, itemId);
    // 3. Next poll will confirm the change
  } catch (e) {
    // 4. Rollback on error
    state = AsyncValue.data(currentData);
    rethrow;
  }
}
```

---

## 4. API Endpoints Required

| Endpoint | Method | Description |
|:---------|:-------|:------------|
| `/tables/join` | POST | Join table by code, returns full table data |
| `/tables/:tableId` | GET | Get table snapshot (items, participants, claims) |
| `/claims` | POST | Create or remove individual item claim |
| `/claims/split` | POST | Create multiple claims for shared item |
| `/items/:itemId/split-all` | POST | Split item among all table participants |
| `/tables/:tableId/lock` | PUT | Change status from `claiming` to `collecting` |

---

## 5. Riverpod Providers

* `currentTableProvider` - AsyncNotifier with polling for table state
* `tableStatusProvider` - Derived provider for current table status
* `tableBillItemsProvider` - Derived list of items with claim data
* `tableParticipantsProvider` - Derived list of participants
* `isHostProvider` - Boolean if current user is host
* `userOwedAmountProvider` - Calculated total owed by current user

---

## 6. Definition of Done (Acceptance Criteria)

* [ ] Participants can join table via 6-character code entry.
* [ ] Participants can join via QR code scanner.
* [ ] Deep links (`pyble://join?code=ABC123`) auto-join the table.
* [ ] All users see the same itemized bill (via API polling every 3 seconds).
* [ ] Users can tap items to claim/unclaim them individually.
* [ ] Users can split items among multiple people via bottom sheet.
* [ ] Host can split orphan items among all diners.
* [ ] Per-user share is calculated correctly (item.price / claimantsCount).
* [ ] UI shows optimistic updates with rollback on error.
* [ ] Host sees "Lock Totals" button; participants do not.
* [ ] Locking the bill changes status to `collecting`.
* [ ] After lock, users auto-navigate (Host→Dashboard, Participants→Payment).
* [ ] All claims persist correctly in the database.
* [ ] Currency symbol is consistent ($) throughout.
* [ ] UI follows `system-design.md` (Deep Berry, Dark Fig, Snow colors).
