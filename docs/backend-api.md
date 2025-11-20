# Pyble API Specification (Azure Functions)

**Version:** 1.0
**Base URL:** `[Your Azure Function Base URL]/api/`
**Architecture:** This API is a set of serverless Azure Functions that act as the backend for the Pyble app. It uses **Cosmos DB** for data storage (following the `database-schema.md`) and **Supabase** for JWT-based authentication.

---

## 1. Global Rules: Authentication

All endpoints (unless specified) are protected. The client **must** send a valid Supabase JWT in the authorization header.

* **Header:** `Authorization: Bearer <Supabase JWT>`
* **Error Response (Missing/Invalid Token):**
    * **Code:** `401 Unauthorized`
    * **Body:** `{ "error": "Authentication required." }`

---

## 2. Resource: Profiles & Auth

Endpoints for managing user profiles and auth-related tasks.

### `POST /profiles`
* **Action:** Creates a new user profile in Cosmos DB. This is called **once** immediately after a successful Supabase sign-up.
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

## 3. Resource: Tables & Real-Time

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
* **Error Response:** `409 Conflict` (if the user is already a Host of an active table).

### `GET /tables/:tableId`
* **Action:** (Phase 2) Fetches the complete, single `SplitTable` document.
* **Success Response:** `200 OK`
    * **Body:** The `SplitTable` document.
* **Error Response:** `404 Not Found`, `403 Forbidden` (if user is not a participant).

### `POST /tables/:code/join`
* **Action:** (Phase 2) Joins an existing table using the 6-character code.
* **Success Response:** `200 OK`
    * **Body:** `{ "table": SplitTable, "signalRNegotiationPayload": { ... } }`
* **Error Response:** `404 Not Found` (invalid code), `403 Forbidden` (table is locked/settled).

### `GET /tables/active`
* **Action:** (Phase 4) Gets a list of all `SplitTable` documents where the current user is a participant or host and the `status` is not `settled`.
* **Success Response:** `200 OK`
  * **Body:** `[ SplitTable, SplitTable, ... ]`

### `PUT /tables/:tableId/lock`
* **Action:** (Phase 3) (Host-only) Locks the table and changes status from `claiming` to `collecting`. Once locked, no more items can be claimed.
* **Success Response:** `200 OK`
  * **Body:** The updated `SplitTable` document with `status: 'collecting'`.
* **Error Response:** `403 Forbidden` (if not host), `409 Conflict` (if not all items are claimed).

### `PUT /tables/:tableId/unlock`
* **Action:** (Phase 3) (Host-only) Unlocks the table and changes status from `collecting` back to `claiming`. This allows participants to resume claiming items.
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
* **Error Response:** `403 Forbidden` (if not host), `409 Conflict` (if not all participants have paid).

### `PUT /tables/:tableId/cancel`
* **Action:** (Phase 4) (Host-only) Cancels the table and changes status to `cancelled`.
* **Success Response:** `200 OK`
  * **Body:** None.
* **Error Response:** `403 Forbidden` (if not host).

### `POST /tables/:tableId/leave`
* **Action:** (Phase 4) (Participant-only) Allows a participant to leave a table. Removes the user from participants and clears all their claims from items. Recalculates totals for remaining participants.
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

## 4. Resource: Bill Management

Endpoints for scanning and editing the bill.

### `POST /tables/:tableId/scan`
* **Action:** (Phase 3) (Host-only) Scans the bill. Sends image to Vertex AI, parses items, and patches the `items` array in the `SplitTable` document.
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
* **Action:** (Phase 3) (Host-only) Edits an existing item. Both `name` and `price` are optional, but at least one must be provided.
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
* **Action:** (Phase 3) (Host-only) Clears all items from the bill. This is useful for the "Scan Again" functionality where the host wants to rescan the bill. Also resets subTotal, tax, and tip to 0.
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
* **Action:** (Phase 2) (Host-only) Creates split requests for participants. Each targeted participant must approve before being added to the item.
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

## 5. Resource: Payments & Settlement

Endpoints for handling the payment and verification flow.

### `POST /tables/:tableId/pay`
* **Action:** (Phase 4) (Participant) Initiates an in-app payment via Paystack.
* **Body:**
    ```json
    {
      "tipAmount": 20.50 
    }
    ```
* **Success Response:** `200 OK` (Client will update via SignalR).
* **Error Response:** `402 Payment Required` (if Paystack charge fails).

### `POST /tables/:tableId/mark-paid-outside`
* **Action:** (Phase 4) (Participant) Marks their payment as "Paid outside app," setting their status to `awaiting_confirmation`.
* **Success Response:** `200 OK` (Client will update via SignalR).

### `POST /tables/:tableId/mark-paid-direct`
* **Action:** (Phase 4) (Participant) Marks their payment as "Paid restaurant directly" - meaning they paid the restaurant for their share, not the host. This sets their status to `pending_direct_confirmation`.
* **Use Case:** When a participant paid the restaurant directly (e.g., split the check at the register), so the host doesn't need to be reimbursed for this participant's share.
* **Success Response:** `200 OK` (Client will update via SignalR).
* **Error Response:**
  * `400 Bad Request` (if tableId not provided)
  * `403 Forbidden` (if user is not a participant)
  * `404 Not Found` (if table doesn't exist)
  * `409 Conflict` (if table is not in collecting status)

### `POST /tables/:tableId/confirm-payment`
* **Action:** (Phase 4) (Host-only) Confirms an "outside" or "direct" payment. Works for both `awaiting_confirmation` and `pending_direct_confirmation` statuses.
* **Body:**
    ```json
    {
      "participantUserId": "uuid-of-participant"
    }
    ```
* **Success Response:** `200 OK` (Client will update via SignalR).
* **Note:** For direct payments, confirming indicates the host acknowledges the participant paid the restaurant directly for their share.

### `POST /tables/:tableId/close`
* **Action:** (Phase 4) (Host-only) Closes the table, setting its status to `settled`.
* **Pre-condition:** All participants must have a `paid_` status.
* **Success Response:** `200 OK` (Client will update via SignalR).
* **Error Response:** `409 Conflict` (if not all participants are settled).

---

## 6. Resource: History

Endpoints for retrieving historical data.

### `GET /tables/history`
* **Action:** (Phase 4) Gets a list of all `SplitTable` documents where the current user was a participant and the `status` is `settled`.
* **Success Response:** `200 OK`
    * **Body:** `[ SplitTable, SplitTable, ... ]`

---

## 7. Resource: Real-Time & Debug

### `POST /signalr/negotiate`
* **Action:** (Phase 2) Gets the connection info for the Azure SignalR hub.
* **Note:** This is often returned by the `POST /tables` and `POST /tables/:code/join` endpoints automatically, but a standalone negotiator may be needed.
* **Success Response:** `200 OK`
    * **Body:** `{ "url": "...", "accessToken": "..." }`

### `POST /ocr-test`
* **Action:** (Phase 3) Debug endpoint. Sends an image directly to Vertex AI and returns the raw JSON. Does not touch Cosmos DB.
* **Body:** `(multipart/form-data)` with the image file.
* **Success Response:** `200 OK`
    * **Body:** The raw JSON response from Gemini.