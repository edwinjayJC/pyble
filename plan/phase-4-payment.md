# Phase 4 Plan: Payments, Tips & Table Closure

**Objective:** Implement the complete end-to-end payment and settlement flow. This involves integrating Paystack via Azure Functions, managing payment methods on the `UserProfile` document, calculating final totals, and handling both In-App and Manual payment flows, all reflected in the `SplitTable` document.

**References:**

* **Master Spec:** `claude.md`
* **Design System:** `system-design.md`
* **Database Schema:** `database-schema.md`

---

## 1. High-Level Goals

1. **Payment Method Management:** Allow users to save/manage their Paystack payment methods. This data will be stored on their `UserProfile` document in Cosmos DB.
2. **Client-Side Totals:** Implement the final total calculation in Riverpod, which watches the `SplitTable` state and a new local "tip" provider.
3. **In-App Payment Flow (PIA):** Build the `POST /tables/:tableId/pay` Azure Function to charge a user via Paystack and update the `SplitTable` document.
4. **Manual Payment Flow (POA):** Build the `POST /tables/:tableId/mark-paid-outside` Azure Function to update the participant's status.
5. **Host Verification Flow:** Build the `POST /tables/:tableId/confirm-payment` Azure Function for the Host to approve POA settlements.
6. **Table Closure & History:** Build the `POST /tables/:tableId/close` function to finalize a table and a `GET /tables/history` function to retrieve settled tables.

---

## 2. Feature Breakdown

### 2.1 Payment Method Management (Drawer)

* **Implement "Payment Methods" Screen:**
  * Accessed from the Drawer.
  * **Crucial Logic:** This screen interacts with a new set of Azure Functions (e.g., `POST /profile/payment-method`) that talk to Paystack.
  * **Add Card Flow:**
    1. User taps "Add Card".
    2. Client SDK talks to Paystack, gets a *client-side token*.
    3. Client sends this *token* to `POST /profile/payment-method`.
    4. Azure Function takes the token, calls Paystack to create a "Customer", gets back a `paystackCustomerId`.
    5. The function `PATCH`es the user's `UserProfile` document in Cosmos DB, saving this `paystackCustomerId`.
  * **Add Payout Account Flow:**
    1. User taps "Add Bank Account" (for receiving money).
    2. Client collects bank details, sends them to `POST /profile/payout-account`.
    3. Azure Function calls Paystack to create a "Transfer Recipient" and saves the `recipient_code` to the user's `UserProfile` doc.
* **UI:** The screen lists saved cards (from Paystack) and the saved payout account.

### 2.2 Final Totals Calculation (Riverpod)

* **Update `userTotalProvider`:**
  * This provider is 100% client-side. It `watch`es:
    1. The main `SplitTable` state (for the `userSubtotal`).
    2. A new `StateProvider<int>` for `selectedTipPercentage` (default 0).
* **"Your Total" Panel UI:**
  * **Tip Selector:** Add a UI (`SegmentedButton`) for selecting tip: 0%, 5%, 10%, 15%, 20%. This updates the `selectedTipPercentage` provider.
  * **Fee Display:** The `PriceBreakdownCard` must clearly show two different states:
    * **If "Pay in App" is selected:**
      * `Subtotal:` (from `SplitTable`)
      * `Your Tip:` (`Subtotal` * `tipPercentage`)
      * `App Fee (1%):` (`Subtotal` * 0.01)
      * `Transaction Fee (~4%):` (A fee calculated from Paystack)
      * **`Total Payable:`** (Sum of all above)
    * **If "Paid outside app" is selected:**
      * `Total Owed:` (Subtotal + Your Tip)
      * All fees are hidden and set to 0.

### 2.3 Flow 1: "Pay in App" (Azure Function)

* **Endpoint:** `POST /tables/:tableId/pay`
* **Logic (Azure Function):**
  1. Validate JWT.
  2. Get `UserProfile` (to find `paystackCustomerId`).
  3. Get `SplitTable` (to verify the `totalOwed` amount).
  4. Call Paystack's "Charge" API to charge the user's saved card for the `Total Payable` (including all fees/tip).
  5. On success, **`PATCH`** the `SplitTable` document:
    * Find the user in the `participants` array.
    * Set their `status: "paid_in_app"`.
* **Client Flow:**
  * On tap, show a confirmation.
  * On confirm, show a loading indicator ("Processing payment...").
  * Call the `POST /tables/:tableId/pay` function.
* **Real-time Update:** The `PATCH` operation triggers the **Cosmos Change Feed**, which fires the **SignalR `table_updated` event**. The client's UI (and everyone else's) automatically updates to show the user's status as `Paid`.

### 2.4 Flow 2: "Paid outside app" (Azure Function)

* **Endpoint:** `POST /tables/:tableId/mark-paid-outside`
* **Logic (Azure Function):**
  1. Validate JWT.
  2. **`PATCH`** the `SplitTable` document:
    * Find the user in the `participants` array.
    * Set their `status: "awaiting_confirmation"`.
* **Client Flow:**
  * On tap, show a confirmation dialog.
  * On confirm, call the Azure Function.
* **Real-time Update:** The `PATCH` fires SignalR. The user's status chip updates to "Pending" (Amber color) for everyone.

### 2.5 Host Verification Flow (Azure Function)

* **Endpoint:** `POST /tables/:tableId/confirm-payment`
* **Body:** `{ "participantUserId": "uuid-of-user-to-confirm" }`
* **Logic (Azure Function):**
  1. Validate JWT.
  2. Get `SplitTable` doc and verify the caller is the `hostUserId`.
  3. **`PATCH`** the `SplitTable` document:
    * Find the `participantUserId` in the `participants` array.
    * Set their `status: "paid_outside"`.
* **Client Flow (Host-Only UI):**
  * The Host sees "Confirm" / "Reject" buttons next to any participant with `awaiting_confirmation` status.
  * Tapping "Confirm" calls this endpoint.
* **Real-time Update:** The `PATCH` fires SignalR. The participant's status updates to "Paid" (Green color) for everyone.

### 2.6 Table Closure & History (Azure Functions)

* **"Close Table" Button (Host-Only UI):**
  * The "Close Table" button (`Deep Berry`) is only enabled when a Riverpod provider confirms that **all** `participants` in the `SplitTable` have a status of `paid_in_app` or `paid_outside`.
* **Endpoint 1: `POST /tables/:tableId/close`**
  * **Logic:** Host calls this when the button is enabled.
  * The Azure Function verifies all are paid, then `PATCH`es the `SplitTable` to set `status: "settled"`.
  * This `PATCH` fires SignalR. The clients (listening for this) can then boot all users from the table (e.g., `GoRouter.pop()`).
  * **(Future):** This function will also trigger the Paystack `Transfer` to pay out the Host.
* **Endpoint 2: `GET /tables/history`**
  * **Logic:** Fetches all `SplitTable` documents from Cosmos DB where `status == "settled"` and the `participants.userId` array contains the current user's ID.
* **History Screens (Client):**
  * `/history`: A `FutureProvider` calls `GET /tables/history` and displays a list.
  * `/history/:tableId`: Tapping a list item calls `GET /tables/:tableId` and displays a read-only summary.

---

## 3. Azure Function Endpoints Needed

| Endpoint | Action | Description |
|:---------|:-------|:------------|
| `POST /profile/payment-method` | Add Card | (User) Saves a Paystack payment token to their `UserProfile`. |
| `POST /profile/payout-account` | Add Bank | (User) Saves Paystack payout details to their `UserProfile`. |
| `POST /tables/:tableId/pay` | Pay In-App | (Participant) Charges card via Paystack, updates `status: "paid_in_app"`. |
| `POST /tables/:tableId/mark-paid-outside` | Pay Outside | (Participant) Updates `status: "awaiting_confirmation"`. |
| `POST /tables/:tableId/confirm-payment` | Host Confirm | (Host) Updates participant `status: "paid_outside"`. |
| `POST /tables/:tableId/close` | Close Table | (Host) Sets `status: "settled"` after all are paid. |
| `GET /tables/history` | Get History | (User) Fetches all `settled` tables for the user. |

---

## 4. Definition of Done (Acceptance Criteria)

* [ ] A user can go to "Payment Methods" and successfully save their card and payout info (data is stored in their `UserProfile` in Cosmos).
* [ ] The "Your Total" panel correctly calculates and displays `Subtotal`, `Tip`, `App Fee`, and `Transaction Fee`.
* [ ] The fees are **only** visible in the "Pay in App" flow.
* [ ] A participant can tap "Pay in App", and (on success) their status updates to "Paid" via the **SignalR `table_updated` event**.
* [ ] A participant can tap "Paid outside app", and their status updates to "Pending" via SignalR.
* [ ] The **Host** sees the "Pending" status and has "Confirm" / "Reject" buttons.
* [ ] The Host can tap "Confirm", and the participant's status updates to "Paid" via SignalR.
* [ ] The Host's "Close Table" button is disabled until all participants are in a "paid" state.
* [ ] The Host can "Close Table", which sets the `status: "settled"` in Cosmos DB.
* [ ] All users can now see the closed table in their `/history` screen.
* [ ] All new UI elements strictly follow the `system-design.md`.
