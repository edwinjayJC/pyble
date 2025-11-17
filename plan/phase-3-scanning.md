# Phase 3: Settlement & Collection

**Objective:** Implement the payment and reimbursement flows after the Host locks the bill. This phase enables Participants to reimburse the Host via two paths: Pay in App (PIA) with a 4% fee or Paid Outside App (POA) with manual host confirmation.

**References:**
* **Master Spec:** `CLAUDE.md` (Section 8)
* **Design System:** `system-design.md`
* **API Schema:** `backend-api.md` - The source of truth for our api calls.

---

## 1. High-Level Goals

1. **State Transition:** Detect when table status changes to `collecting`.
2. **Participant Payment Options:** Offer PIA (convenience) and POA (free) paths.
3. **WebView Payment Flow:** Integrate payment gateway via WebView.
4. **Payment Status Polling:** Track payment completion via API polling.
5. **Host Dashboard:** Display participant payment statuses and confirm POA payments.
6. **Settle Table:** Close the session when all participants are paid.

---

## 2. Feature Breakdown

### 2.1 Status Transition Detection

* **Trigger:** Table status changes from `claiming` to `collecting`
* **Auto-Navigation:**
  * Host → `/table/:tableId/dashboard` (Collection Dashboard)
  * Participants → `/table/:tableId/payment` (Payment Screen)
* **Tech:** Riverpod `ref.listen` watches `tableStatusProvider` for changes
* **UI Lock:** Once in `collecting` status, claiming is disabled

### 2.2 Participant Payment Screen (`/table/:tableId/payment`)

* **Header:** "You owe [Host Name] $XX.XX"
* **Amount Breakdown:**
  * Individual item totals (based on claims)
  * Per-user share calculations
  * Final total owed

* **Two Payment Options:**

**A. Pay in App (PIA) - Primary Button**
* Button text: "Pay in App"
* Shows fee preview: "Amount: $28.50 | Fee (4%): $1.14 | Total: $29.64"
* Provides instant settlement

**B. Paid Outside App (POA) - Secondary Button**
* Button text: "Mark as Paid Outside"
* For cash, EFT, bank transfer, etc.
* Requires host confirmation (not instant)

### 2.3 Pay in App (PIA) Flow

1. **Checkout Screen:**
   * Display: Amount owed, 4% app fee, final total
   * "Proceed to Payment" button

2. **Initiate Payment:**
   * **API Call:** `POST /payments/initiate`
   * Body: `{ "tableId": "uuid", "amount": 28.50 }`
   * Returns: `{ "paymentUrl": "https://...", "paymentId": "uuid" }`

3. **WebView Screen (`PaymentWebviewScreen`):**
   * Load `paymentUrl` in WebView
   * User completes payment in gateway
   * Gateway redirects to `callbackUrl`
   * `NavigationDelegate` intercepts callback URL
   * Extract success/failure from URL parameters

4. **Payment Processing Screen (`PaymentProcessingScreen`):**
   * Show spinner: "Processing your payment..."
   * **Poll:** `GET /payments/status/:paymentId` every 2 seconds
   * Wait for `transactionStatus: 'completed'`

5. **Success State:**
   * Backend updates `Participant.paymentStatus` to `paid`
   * UI shows: "You're All Settled!" with green checkmark
   * Participant is done

### 2.4 Paid Outside App (POA) Flow

1. **User Action:** Taps "Mark as Paid Outside"
2. **Confirmation Dialog:** "This will notify the host that you've paid outside the app. Continue?"
3. **API Call:** `PUT /participants/mark-pending`
   * Updates `paymentStatus` from `owing` to `pending_confirmation`
4. **Waiting State:**
   * UI shows: "Awaiting Host Confirmation..."
   * Participant waits for host to verify payment
5. **Host Confirms (see 2.6):**
   * Backend updates `paymentStatus` to `paid`
   * Polling detects change
   * UI updates to "You're All Settled!"

### 2.5 Host Collection Dashboard (`/table/:tableId/dashboard`)

* **Purpose:** Host's accountability dashboard to track reimbursements

* **Participant List:** Shows each participant with status:
  * `PAID (In-App)` - Green indicator, `paymentStatus == 'paid'` via PIA
  * `PAID (Outside)` - Green indicator, `paymentStatus == 'paid'` via POA
  * `OWES $XX.XX` - Red indicator, `paymentStatus == 'owing'`
  * `Awaiting Your Confirmation` - Orange indicator, `paymentStatus == 'pending_confirmation'`

* **Real-time Updates:**
  * Poll `GET /tables/:tableId/participants` every 3 seconds
  * Dashboard updates as participants pay

* **Total Summary:**
  * Total owed: Sum of all `owing` amounts
  * Total received: Sum of `paid` amounts
  * Pending confirmation: Sum of `pending_confirmation` amounts

### 2.6 Host Confirms POA Payment

* **Trigger:** Host taps on participant with `pending_confirmation` status
* **Dialog:** "Confirm you received $XX.XX from [Name]?"
* **API Call:** `PUT /participants/confirm-payment`
  * Body: `{ "participantId": "uuid" }`
  * Updates `paymentStatus` from `pending_confirmation` to `paid`
* **Result:**
  * Dashboard updates to show "PAID (Outside)"
  * Participant's app (polling) sees status change to `paid`
  * Participant's UI updates to "You're All Settled!"

### 2.7 Settle Table (Close Session)

* **Pre-condition:** All participants have `paymentStatus == 'paid'`
* **Trigger:** Host taps "Settle Table" button
* **Confirmation:** "All payments received. Close this session?"
* **API Call:** `PUT /tables/:tableId/settle`
  * Updates `TableSession.status` to `settled`
  * Sets `closedAt` timestamp
* **Result:**
  * Session is archived
  * Users can view in history
  * Table is no longer active

---

## 3. Data Models

### PaymentRecord

```dart
class PaymentRecord {
  final String id;
  final String tableId;
  final String payerUserId;
  final String receiverUserId; // Host
  final double amount;
  final double fee; // 4% app fee
  final PaymentType type; // app_payment, manual_payment
  final TransactionStatus transactionStatus; // pending, completed, failed
  final String? paymentGatewayReference;
}
```

### InitiatePaymentResponse

```dart
class InitiatePaymentResponse {
  final String paymentId;
  final String paymentUrl;
  final double amount;
  final double fee;
  final double total;
}
```

### PaymentStatus Updates

```dart
enum PaymentStatus {
  owing,              // Default - owes money
  pending_confirmation,  // POA - waiting for host
  paid,               // Settled (PIA or POA confirmed)
}
```

---

## 4. API Endpoints Required

| Endpoint | Method | Description |
|:---------|:-------|:------------|
| `/payments/initiate` | POST | Start PIA flow, returns payment URL and ID |
| `/payments/status/:paymentId` | GET | Poll payment completion status |
| `/participants/mark-pending` | PUT | Mark as paid outside (POA), awaiting host |
| `/participants/confirm-payment` | PUT | Host confirms POA payment received |
| `/tables/:tableId/participants` | GET | Get all participants with payment statuses |
| `/tables/:tableId/settle` | PUT | Close table session, mark as settled |

---

## 5. Riverpod Providers

* `paymentStatusProvider` - Polls payment completion for PIA flow
* `participantPaymentStatusProvider` - Current user's payment status
* `hostDashboardProvider` - Polls participant list for host
* `tableStatusProvider` - Detects `collecting` → `settled` transitions
* `userOwedAmountProvider` - Calculates total owed by current user
* `allParticipantsPaidProvider` - Boolean for settle button visibility

---

## 6. Payment Flow Architecture

### WebView Payment Polling

```dart
class PaymentStatusNotifier extends StateNotifier<AsyncValue<TransactionStatus>> {
  Timer? _pollingTimer;

  void startPolling(String paymentId) {
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkPaymentStatus(paymentId),
    );
  }

  Future<void> _checkPaymentStatus(String paymentId) async {
    final status = await repository.getPaymentStatus(paymentId);
    state = AsyncValue.data(status);

    if (status == TransactionStatus.completed ||
        status == TransactionStatus.failed) {
      stopPolling();
    }
  }
}
```

### Host Confirmation Flow

```dart
Future<void> confirmPayment(String participantId) async {
  await repository.confirmPayment(participantId);
  // Next poll will show updated status
  // Participant's app will also see the change via their polling
}
```

---

## 7. Definition of Done (Acceptance Criteria)

* [ ] When status changes to `collecting`, participants auto-navigate to payment screen.
* [ ] When status changes to `collecting`, host auto-navigates to dashboard.
* [ ] Participant sees "You owe [Host] $XX.XX" with correct calculated amount.
* [ ] PIA: User can tap "Pay in App" and see fee breakdown (amount + 4% fee).
* [ ] PIA: WebView loads payment gateway URL successfully.
* [ ] PIA: Payment completion is detected via polling (every 2 seconds).
* [ ] PIA: On success, participant sees "You're All Settled!" screen.
* [ ] POA: User can tap "Mark as Paid Outside" and status changes to `pending_confirmation`.
* [ ] POA: Participant sees "Awaiting Host Confirmation..." message.
* [ ] Host dashboard shows all participants with correct payment statuses.
* [ ] Host can tap on `pending_confirmation` participant to confirm payment.
* [ ] After host confirms POA, participant's status updates to `paid` via polling.
* [ ] Host sees "Settle Table" button when all participants are paid.
* [ ] Settling the table changes status to `settled` and closes session.
* [ ] All amounts use consistent currency symbol ($).
* [ ] UI follows `system-design.md` (Deep Berry, Dark Fig, Snow colors).
* [ ] Error states are handled gracefully (payment failures, network issues).
