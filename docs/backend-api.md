# Pyble API Specification (Azure Functions)

**Version:** 1.1
**Base URL:** `[Your Azure Function Base URL]/api/`
**Architecture:** This API is a set of serverless Azure Functions that act as the backend for the
Pyble app. It uses **Cosmos DB** for data storage (following the `database-schema.md`) and *
*Supabase** for JWT-based authentication.

---

## 1. Global Rules: Authentication

All endpoints (unless specified) are protected. The client **must** send a valid Supabase JWT in the
authorization header.

* **Header:** `Authorization: Bearer <Supabase JWT>`
* **Error Response (Missing/Invalid Token):**
    * **Code:** `401 Unauthorized`
    * **Body:** `{ "error": "Authentication required." }`

## Paystack Configuration

Environment variables for all Paystack calls (no values hard-coded in code):

* `PAYSTACK_PUBLIC_KEY` – `pk_test_xxx` / `pk_live_xxx`
* `PAYSTACK_SECRET_KEY` – `sk_test_xxx` / `sk_live_xxx`
* `PAYSTACK_ENV` – `test` or `live`
* `PAYSTACK_CALLBACK_URL` – e.g. `https://api.my-domain.com/payments/paystack/callback`
* `PAYSTACK_WEBHOOK_SECRET` – HMAC secret for webhook verification (kept distinct from the secret
  key)

---

## 2. Resource: Profiles & Auth

Endpoints for managing user profiles and auth-related tasks.

### `POST /profiles`

* **Action:** Creates a new user profile in Cosmos DB. This is called **once** immediately after a
  successful Supabase sign-up.
* **Body:**
    ```json
    {
      "id": "supabase-uuid",
      "email": "user@example.com",
      "displayName": "User Name"
    }
    ```
* **Success Response:** `201 Created`
    * **Body:** The new `UserProfile` document.
* **Error Response:** `409 Conflict` (if profile `id` already exists).

### `GET /profiles/me`

* **Action:** Fetches the `UserProfile` document for the currently authenticated user.
* **Success Response:** `200 OK`
    * **Body:** The `UserProfile` document from Cosmos DB.
* **Error Response:** `404 Not Found` (if profile does not exist for auth'd user).

### `DELETE /profiles/me`

* **Action:** Deletes the current user's profile from both Supabase Auth and Cosmos DB.
* **Success Response:** `204 No Content`
* **Error Response:** `404 Not Found` (if profile does not exist).

### `POST /profiles/accept-terms`

* **Action:** Sets the `hasAcceptedTerms` flag to `true` for the current user.
* **Success Response:** `200 OK`
    * **Body:** The *updated* `UserProfile` document.

### `POST /profiles/payment-method`

* **Action:** (Phase 4) Saves a Paystack payment token/customer to the user's profile.
* **Body:**
    ```json
    {
      "paystackClientToken": "tok_123abc"
    }
    ```
* **Success Response:** `200 OK`
    * **Body:** `{ "paystackCustomerId": "CUS_123abc" }`

### `POST /profiles/payout-account`

* **Action:** (Phase 4) Saves Paystack payout (transfer recipient) details to the user's profile.
* **Body:**
    ```json
    {
      "accountNumber": "1234567890",
      "bankCode": "058",
      "accountName": "User Name"
    }
    ```
* **Success Response:** `200 OK`
    * **Body:** `{ "paystackRecipientCode": "RCP_123abc" }`

---

## 3. Resource: Friends

Endpoints for managing friend relationships.

### `POST /profiles/friends/request`

* **Action:** Sends a friend request to another user.
* **Body:**
    ```json
    {
      "targetUserId": "user-uuid"
    }
    ```
* **Success Response:** `201 Created`
    * **Body:** `{ "message": "Friend request sent", "requestId": "request-uuid" }`
* **Error Response:**
    * `400 Bad Request` (if targetUserId is self or missing)
    * `404 Not Found` (if target user doesn't exist)
    * `409 Conflict` (if already friends or request pending)

### `GET /profiles/friends/requests`

* **Action:** Gets all pending friend requests for the current user.
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      [
        {
          "id": "request-uuid",
          "fromUserId": "sender-uuid",
          "fromDisplayName": "Sender Name",
          "status": "pending",
          "createdAt": "2024-01-01T12:00:00Z"
        }
      ]
      ```

### `PUT /profiles/friends/request/{requestId}`

* **Action:** Accepts or rejects a friend request.
* **Body:**
    ```json
    {
      "action": "accept"
    }
    ```
  *(or "reject")*
* **Success Response:** `200 OK`
    * **Body:** `{ "message": "Friend request accepted" }`
* **Error Response:**
    * `404 Not Found` (if request doesn't exist)
    * `409 Conflict` (if request already responded to)

### `DELETE /profiles/friends/{friendUserId}`

* **Action:** Removes a friend from both users' friend lists.
* **Success Response:** `200 OK`
    * **Body:** `{ "message": "Friend removed" }`
* **Error Response:** `404 Not Found` (if friend not found)

---

## 4. Resource: Tables & Real-Time

Endpoints for creating, joining, and managing `SplitTable` sessions.

### `POST /tables`

* **Action:** (Phase 2) Creates a new `SplitTable` session. The caller becomes the Host.
* **Body:** (Optional)
    ```json
    {
      "title": "Dinner at The Grill"
    }
    ```
* **Success Response:** `201 Created`
    * **Body:** `{ "table": SplitTable, "signalRNegotiationPayload": { ... } }`

### `GET /tables/:tableId`

* **Action:** (Phase 2) Fetches the complete, single `SplitTable` document.
* **Success Response:** `200 OK`
    * **Body:** The `SplitTable` document.
* **Error Response:** `404 Not Found`, `403 Forbidden` (if user is not a participant).

### `POST /tables/:code/join`

* **Action:** (Phase 2) Joins an existing table using the 6-character code.
* **Friend-based Access Control:**
    * If user is a friend of the host → Auto-joins immediately
    * If user is not a friend → Creates a join request for host approval
    * If user is blocked → Returns 403 Forbidden
* **Success Response (Auto-join):** `200 OK`
    * **Body:** `{ "table": SplitTable, "signalRNegotiationPayload": { ... } }`
* **Success Response (Join Request Created):** `202 Accepted`
    * **Body:**
      `{ "message": "Join request sent to host", "requestId": "uuid", "requestPending": true }`
* **Error Response:**
    * `404 Not Found` (invalid code)
    * `403 Forbidden` (table is locked/settled, or user is blocked)
    * `409 Conflict` (join request already pending)

### `GET /tables/active`

* **Action:** (Phase 4) Gets a list of all `SplitTable` documents where the current user is a
  participant or host and the `status` is not `settled`.
* **Success Response:** `200 OK`
    * **Body:** `[ SplitTable, SplitTable, ... ]`

### `PUT /tables/:tableId/lock`

* **Action:** (Phase 3) (Host-only) Locks the table and changes status from `claiming` to
  `collecting`. Once locked, no more items can be claimed.
* **Body:** (Optional)
    ```json
    {
      "tipAmount": 50.00
    }
    ```
* **Success Response:** `200 OK`
    * **Body:** The updated `SplitTable` document with `status: 'collecting'`.
* **Error Response:** `403 Forbidden` (if not host), `409 Conflict` (if not all items are claimed).

### `PUT /tables/:tableId/unlock`

* **Action:** (Phase 3) (Host-only) Unlocks the table and changes status from `collecting` back to
  `claiming`. This allows participants to resume claiming items.
* **Success Response:** `200 OK`
    * **Body:** The updated `SplitTable` document with `status: 'claiming'`.
* **Error Response:**
    * `400 Bad Request` (if tableId not provided)
    * `403 Forbidden` (if not host)
    * `404 Not Found` (if table doesn't exist)
    * `409 Conflict` (if table is not in collecting status)

### `PUT /tables/:tableId/settle`

* **Action:** (Phase 4) (Host-only) Settles/closes the table and changes status to `settled`.
* **Pre-condition:** All participants must have paid.
* **Success Response:** `200 OK`
    * **Body:** The updated `SplitTable` document with `status: 'settled'`.
* **Error Response:** `403 Forbidden` (if not host), `409 Conflict` (if not all participants have
  paid).

### `PUT /tables/:tableId/cancel`

* **Action:** (Phase 4) (Host-only) Cancels the table and changes status to `cancelled`.
* **Success Response:** `200 OK`
    * **Body:** `{ "message": "Table cancelled successfully" }`
* **Error Response:** `403 Forbidden` (if not host).

### `POST /tables/:tableId/leave`

* **Action:** (Phase 4) (Participant-only) Allows a participant to leave a table. Removes the user
  from participants and clears all their claims from items. Recalculates totals for remaining
  participants.
* **Pre-conditions:**
    * User must be a participant (not the host)
    * Table must not be `settled` or `cancelled`
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      {
        "message": "Successfully left the table"
      }
      ```
* **Error Response:**
    * `400 Bad Request` (if tableId not provided)
    * `403 Forbidden` (if user is host - must cancel instead, or if user is not a participant)
    * `404 Not Found` (if table doesn't exist)
    * `409 Conflict` (if table is already settled or cancelled)

---

## 5. Resource: Join Requests

Endpoints for hosts to manage table join requests from non-friends.

### `GET /tables/:tableId/join-requests`

* **Action:** (Host-only) Gets all pending join requests for a table.
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      [
        {
          "id": "request-uuid",
          "userId": "requester-uuid",
          "displayName": "Requester Name",
          "status": "pending",
          "createdAt": "2024-01-01T12:00:00Z"
        }
      ]
      ```
* **Error Response:** `403 Forbidden` (if not host), `404 Not Found` (if table doesn't exist)

### `PUT /tables/:tableId/join-requests/:requestId`

* **Action:** (Host-only) Accepts or rejects a join request. When accepted, the user is added to
  participants and associate history is updated.
* **Body:**
    ```json
    {
      "action": "accept"
    }
    ```
  *(or "reject")*
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      {
        "message": "Join request accepted",
        "request": {
          "id": "request-uuid",
          "userId": "requester-uuid",
          "displayName": "Requester Name",
          "status": "accepted"
        }
      }
      ```
* **Error Response:**
    * `403 Forbidden` (if not host)
    * `404 Not Found` (if request doesn't exist)
    * `409 Conflict` (if request already responded to, or table is settled/cancelled)

---

## 6. Resource: User Blocking

Endpoints for hosts to block/unblock users from tables.

### `PUT /tables/:tableId/block/:userId`

* **Action:** (Host-only) Blocks a user from the table. If the user is a participant, they are
  removed and their claims are cleared. Any pending join requests from this user are rejected.
* **Success Response:** `200 OK`
    * **Body:** `{ "message": "User blocked successfully" }`
* **Error Response:**
    * `400 Bad Request` (if trying to block self)
    * `403 Forbidden` (if not host)
    * `404 Not Found` (if table doesn't exist)
    * `409 Conflict` (if user already blocked)

### `DELETE /tables/:tableId/block/:userId`

* **Action:** (Host-only) Unblocks a user from the table.
* **Success Response:** `200 OK`
    * **Body:** `{ "message": "User unblocked successfully" }`
* **Error Response:**
    * `403 Forbidden` (if not host)
    * `404 Not Found` (if table doesn't exist, or user not in blocked list)

---

## 7. Resource: Bill Management

Endpoints for scanning and editing the bill.

### `POST /tables/:tableId/scan`

* **Action:** (Phase 3) (Host-only) Scans the bill. Sends image to Vertex AI, parses items, and
  patches the `items` array in the `SplitTable` document.
* **Body:** `(multipart/form-data)` with the image file.
* **Success Response:** `200 OK` (No body needed. Client will update via SignalR).
* **Error Response:** `500 Internal Server Error` (if AI parsing fails).

### `PUT /tables/:tableId/item`

* **Action:** (Phase 3) (Host-only) Manually adds a new item to the bill.
* **Body:**
    ```json
    {
      "name": "Fries",
      "price": 50.00
    }
    ```
* **Success Response:** `200 OK` (Client will update via SignalR).

### `PUT /tables/:tableId/items/:itemId`

* **Action:** (Phase 3) (Host-only) Edits an existing item. Both `name` and `price` are optional,
  but at least one must be provided.
* **Body:**
    ```json
    {
      "name": "Large Fries",
      "price": 55.00
    }
    ```
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      {
        "message": "Item updated successfully",
        "table": <SplitTable>
      }
      ```
* **Error Response:**
    * `403 Forbidden` (if not host)
    * `404 Not Found` (if table or item doesn't exist)
    * `400 Bad Request` (if neither name nor price provided, or if price is invalid)

### `DELETE /tables/:tableId/items/:itemId`

* **Action:** (Phase 3) (Host-only) Deletes a single item from the bill.
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      {
        "message": "Item deleted successfully",
        "table": <SplitTable>
      }
      ```
* **Error Response:**
    * `403 Forbidden` (if not host)
    * `404 Not Found` (if table or item doesn't exist)

### `DELETE /tables/:tableId/items`

* **Action:** (Phase 3) (Host-only) Clears all items from the bill. This is useful for the "Scan
  Again" functionality where the host wants to rescan the bill. Also resets subTotal, tax, and tip
  to 0.
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      {
        "message": "All items cleared successfully",
        "table": <SplitTable>
      }
      ```
* **Error Response:** `403 Forbidden` (if not host)

### `PUT /tables/:tableId/claim`

* **Action:** (Phase 2) (Participant) Claims or unclaims an item.
* **Body:**
    ```json
    {
      "itemId": "uuid-of-item",
      "action": "claim"
    }
    ```
  *(or "unclaim")*
* **Success Response:** `200 OK` (Client will update via SignalR).

### `POST /tables/:tableId/items/:itemId/request-split`

* **Action:** (Phase 2) (Host-only) Creates split requests for participants. Each targeted
  participant must approve before being added to the item.
* **Body:**
    ```json
    {
      "userIds": ["user-uuid-1", "user-uuid-2"]
    }
    ```
* **Success Response:** `201 Created`
    * **Body:**
      ```json
      {
        "message": "Split requests created",
        "requests": [
          {
            "id": "request-uuid",
            "itemId": "item-uuid",
            "targetUserId": "user-uuid",
            "status": "pending"
          }
        ]
      }
      ```
* **Error Response:**
    * `403 Forbidden` (if not host)
    * `404 Not Found` (if table or item doesn't exist)
    * `409 Conflict` (if table is not in claiming status)

### `GET /tables/:tableId/split-requests`

* **Action:** (Phase 2) Gets all pending split requests for the current user on this table.
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      [
        {
          "id": "request-uuid",
          "itemId": "item-uuid",
          "itemName": "Large Pizza",
          "itemPrice": 120.00,
          "requestedByUserId": "host-uuid",
          "requestedByName": "John",
          "targetUserId": "current-user-uuid",
          "status": "pending",
          "createdAt": "2024-01-01T12:00:00Z"
        }
      ]
      ```

### `PUT /tables/:tableId/split-requests/:requestId/respond`

* **Action:** (Phase 2) (Participant) Approves or rejects a split request.
* **Body:**
    ```json
    {
      "action": "approve"
    }
    ```
  *(or "reject")*
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      {
        "message": "Split request approved",
        "request": {
          "id": "request-uuid",
          "status": "approved"
        }
      }
      ```
* **Error Response:**
    * `403 Forbidden` (if user is not the target of the request)
    * `404 Not Found` (if request doesn't exist)
    * `409 Conflict` (if request is not pending, or table is not in claiming status)

---

## 8. Resource: Payment Methods

Endpoints for managing saved payment methods.

### `GET /payment-methods`

* **Action:** Gets all active payment methods for the current user.
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      [
        {
          "id": "method-uuid",
          "provider": "paystack",
          "type": "card",
          "isDefault": true,
          "label": "My Visa",
          "last4": "4242",
          "brand": "visa",
          "expMonth": 12,
          "expYear": 2025,
          "createdAt": "2024-01-01T12:00:00Z"
        }
      ]
      ```

### `POST /payment-methods`

* **Action:** Initiates adding a new payment method (redirects to Paystack for card capture).
* **Body:**
    ```json
    {
      "provider": "paystack",
      "type": "card",
      "makeDefault": true,
      "label": "My Card"
    }
    ```
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      {
        "initMethod": "redirect",
        "redirectUrl": "https://checkout.paystack.com/...",
        "pendingPaymentMethodId": "method-uuid"
      }
      ```
* **Error Response:** `400 Bad Request` (invalid provider/type)

### `PATCH /payment-methods/:id/default`

* **Action:** Sets a payment method as the default.
* **Success Response:** `200 OK`
    * **Body:** The updated payment method object with `isDefault: true`
* **Error Response:**
    * `403 Forbidden` (if not owner)
    * `404 Not Found` (if method doesn't exist or is inactive)

### `PATCH /payment-methods/:id`

* **Action:** Updates the label of a payment method.
* **Body:**
    ```json
    {
      "label": "New Label"
    }
    ```
* **Success Response:** `200 OK`
    * **Body:** The updated payment method object
* **Error Response:**
    * `403 Forbidden` (if not owner)
    * `404 Not Found` (if method doesn't exist or is inactive)

### `DELETE /payment-methods/:id`

* **Action:** Soft-deletes a payment method. If it was the default, promotes another active method.
* **Success Response:** `200 OK`
    * **Body:**
      ```json
      {
        "id": "method-uuid",
        "isActive": false
      }
      ```
* **Error Response:**
    * `403 Forbidden` (if not owner)
    * `404 Not Found` (if method doesn't exist or already inactive)

---

## 9. Resource: Payments & Settlement

Endpoints for handling the payment and verification flow.

### Paystack diner payments (single merchant, no splits)

*Table status mapping:* `open` → `claiming`, `pending_payments` → `collecting`,
`ready_for_host_settlement` → payout-ready, `settled` → archived.

#### `POST /payments/paystack/initialize`

* **Action:** Creates a Paystack transaction per diner (reference: `pyble_<paymentId>`).
* **Body:**
    ```json
    {
      "tableId": "table-uuid",
      "dinerId": "diner-uuid",
      "dinerEmail": "guest@example.com",
      "chargeAmountZar": 120.55,
      "paymentMethodId": "method-uuid"
    }
    ```
* **Success Response:**
    ```json
    {
      "authorization_url": "https://checkout.paystack.com/...",
      "access_code": "ACCESS_xxx",
      "reference": "pyble_payment_id",
      "paymentId": "internal-payment-id",
      "callback_url": "https://api.example.com/payments/paystack/callback"
    }
    ```
* **Notes:** Amounts are sent to Paystack in minor units (ZAR cents). No `split_code` or subaccounts
  are used.

#### `GET /payments/paystack/verify/:reference`

* **Action:** Idempotent verification of a Paystack transaction.
* **Success Response:**
    ```json
    {
      "paymentId": "internal-payment-id",
      "status": "success",
      "reference": "pyble_payment_id",
      "chargeAmountZar": 120.55,
      "gatewayStatus": "success"
    }
    ```
* **Side effects:** Marks the diner `paymentStatus` as `paid` and moves the table to
  `ready_for_host_settlement` when all diners are paid; failure marks the diner as `failed`.

#### `POST /payments/paystack/webhook`

* **Action:** Handles Paystack webhooks (notably `charge.success`).
* **Security:** Validate `x-paystack-signature` via
  `HMAC-SHA512(raw_body, PAYSTACK_WEBHOOK_SECRET)`. Reject on mismatch.
* **Behaviour:** On `charge.success`, mark the Payment as `success`, `diner.paymentStatus = paid`,
  and advance table status as above. Always return `200 OK` once processed to avoid retry storms.

### Host payouts (outbound transfer to host)

#### `POST /tables/:tableId/host-payout`

* **Action:** After all diners are paid (`table.status = ready_for_host_settlement`), trigger a
  Paystack Transfer from the app's balance to the host so they can pay the restaurant offline.
* **Body:**
    ```json
    { "hostDinerId": "diner-uuid" }
    ```
* **Behaviour:** Looks up/creates a Paystack Transfer Recipient for the host, initiates the
  transfer, stores a `HostPayout` record, and (for v1) treats a successful enqueue/response as
  `status = success`, setting the table to `settled`.
* **Response:**
    ```json
    {
      "tableId": "table-uuid",
      "tableStatus": "settled",
      "hostPayout": {
        "id": "payout-id",
        "status": "success",
        "payoutAmountZar": 500.00
      }
    }
    ```
* **Note:** No restaurant payments or Paystack transaction splits are used in v1; the restaurant is
  paid outside the app by the host.

### `POST /tables/:tableId/pay`

* **Action:** (Phase 4) (Participant) Initiates an in-app payment via Paystack.
* **Body:**
    ```json
    {
      "tipAmount": 20.50
    }
    ```
* **Success Response:** `200 OK`
    * **Body:** `{ "message": "Payment successful", "amountPaid": 120.50 }`
* **Error Response:** `402 Payment Required` (if Paystack charge fails).

### `POST /tables/:tableId/mark-paid-outside`

* **Action:** (Phase 4) (Participant) Marks their payment as "Paid outside app," setting their
  status to `awaiting_confirmation`.
* **Success Response:** `200 OK`
    * **Body:** `{ "message": "Marked as paid outside app" }`

### `POST /tables/:tableId/mark-paid-direct`

* **Action:** (Phase 4) (Participant) Marks their payment as "Paid restaurant directly" - meaning
  they paid the restaurant for their share, not the host. This sets their status to
  `pending_direct_confirmation`.
* **Use Case:** When a participant paid the restaurant directly (e.g., split the check at the
  register), so the host doesn't need to be reimbursed for this participant's share.
* **Success Response:** `200 OK`
    * **Body:** `{ "message": "Marked as paid restaurant directly" }`
* **Error Response:**
    * `400 Bad Request` (if tableId not provided)
    * `403 Forbidden` (if user is not a participant)
    * `404 Not Found` (if table doesn't exist)
    * `409 Conflict` (if table is not in collecting status)

### `POST /tables/:tableId/confirm-payment`

* **Action:** (Phase 4) (Host-only) Confirms an "outside" or "direct" payment. Works for both
  `awaiting_confirmation` and `pending_direct_confirmation` statuses.
* **Body:**
    ```json
    {
      "participantUserId": "uuid-of-participant"
    }
    ```
* **Success Response:** `200 OK`
    * **Body:** `{ "message": "Payment confirmed" }`
* **Note:** For direct payments, confirming indicates the host acknowledges the participant paid the
  restaurant directly for their share.

### `POST /tables/:tableId/close`

* **Action:** (Phase 4) (Host-only) Closes the table, setting its status to `settled`.
* **Pre-condition:** All participants must have a `paid_` status.
* **Success Response:** `200 OK`
    * **Body:** `{ "message": "Table closed successfully" }`
* **Error Response:** `409 Conflict` (if not all participants are settled).

---

## 10. Resource: History

Endpoints for retrieving historical data.

### `GET /tables/history`

* **Action:** (Phase 4) Gets a list of all `SplitTable` documents where the current user was a
  participant and the `status` is `settled`.
* **Success Response:** `200 OK`
    * **Body:** `[ SplitTable, SplitTable, ... ]`

---

## 11. Resource: Real-Time & Debug

### `POST /signalr/negotiate`

* **Action:** (Phase 2) Gets the connection info for the Azure SignalR hub.
* **Note:** This is often returned by the `POST /tables` and `POST /tables/:code/join` endpoints
  automatically, but a standalone negotiator may be needed.
* **Success Response:** `200 OK`
    * **Body:** `{ "url": "...", "accessToken": "..." }`

### `POST /ocr-test`

* **Action:** (Phase 3) Debug endpoint. Sends an image directly to Vertex AI and returns the raw
  JSON. Does not touch Cosmos DB.
* **Body:** `(multipart/form-data)` with the image file.
* **Success Response:** `200 OK`
    * **Body:** The raw JSON response from Gemini.

---

## Appendix: Auto-Friend Promotion

The system automatically promotes users to friends when they have joined a host's tables more than 3
times:

1. When a user joins a table (via join request acceptance or auto-join), their `associateHistory`
   entry is updated
2. If `joinCount > 3`, the user is automatically added to the host's friends list with
   `isAuto: true`
3. The relationship is bidirectional - both users are added to each other's friends lists
4. Auto-friends can join future tables without requiring approval
