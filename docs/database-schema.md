# Pyble: Database Schema (Cosmos DB)

**Objective:** This document is the source of truth for all data models stored in our **Azure Cosmos DB** database. All Azure Functions must read from and write to these structures.

## Core Architecture

* **Authentication (Supabase):** User identity is managed by Supabase. When a user signs up, a new record is created in the `supabase.auth.users` table. We do not touch this table.
* **Application Data (Cosmos DB):** All data related to users, tables, and payments is stored in Cosmos DB.
* **The Link:** The `id` for a document in our `UserProfile` collection **is** the `id` (UUID) from the `supabase.auth.users` table. This provides a 1:1 relationship.

---

## 1. `UserProfile` Collection

This collection stores all app-specific data for a single user.

**Document ID:** `id` (string, UUID) - *Mirrors the `supabase.auth.users.id`.*

| Field | Type | Description | Required | Default |
|:------|:-----|:------------|:---------|:--------|
| `id` | string (UUID) | The Supabase Auth User ID. | **Yes** | `N/A` |
| `email` | string | User's email. (Denormalized for quick access). | **Yes** | `N/A` |
| `displayName` | string | User's public-facing name. | **Yes** | `N/A` |
| `hasAcceptedTerms` | bool | Flag for the `GoRouter` guard. | **Yes** | `false` |
| `paystackCustomerId` | string | The customer token from Paystack. | No | `null` |
| `themePreference` | string | 'light', 'dark', or 'system'. | No | 'system' |
| `notificationSettings` | object | User's notification preferences. | No | `{ "newNudge": true }` |
| `friendUserIds` | array (string) | List of `UserProfile` IDs for the "Rolling Tab" feature. | No | `[]` |
| `createdAt` | string (ISO 8601) | Timestamp of profile creation. | **Yes** | `(Server timestamp)` |

**Example `UserProfile` Document:**

```json
{
  "id": "8b52b3b0-e1b1-4f1e-8e3b-b2b3f1f8b4a0",
  "email": "julie@example.com",
  "displayName": "Julie",
  "hasAcceptedTerms": true,
  "paystackCustomerId": "CUS_1a2b3c4d5e",
  "themePreference": "dark",
  "notificationSettings": {
    "newNudge": true,
    "paymentReceived": true
  },
  "friendUserIds": [
    "9c12a3b4-e1b1-4f1e-8e3b-f1f8b4a0b2b3"
  ],
  "createdAt": "2025-11-16T20:00:00Z"
}
```

---

## 2. `SplitTable` Collection

This collection stores data for a single bill-splitting session (a "table").

**Document ID:** `id` (string, UUID) - *A new, randomly generated UUID for this table.*

| Field | Type | Description | Required | Default |
|:------|:-----|:------------|:---------|:--------|
| `id` | string (UUID) | Unique ID for this split table. | **Yes** | `(Generated UUID)` |
| `hostUserId` | string (UUID) | The `UserProfile.id` of the person who created the table. | **Yes** | `N/A` |
| `status` | string | Current state: `claiming`, `collecting`, `settled`. | **Yes** | `claiming` |
| `tableCode` | string | The 6-character short code for joining (e.g., "AX39B1"). | **Yes** | `(Generated)` |
| `title` | string | Optional title (e.g., "Dinner at The Grill"). | No | `null` |
| `createdAt` | string (ISO 8601) | Timestamp of table creation. | **Yes** | `(Server timestamp)` |
| `participants` | array (object) | List of users at the table. See schema below. | **Yes** | `[]` |
| `items` | array (object) | The itemized list from the bill. See schema below. | **Yes** | `[]` |
| `subTotal` | number | The total of all items (before tax/tip). | No | `0` |
| `tax` | number | Tax amount, if added as an "orphan" item. | No | `0` |
| `tip` | number | Tip amount, if added by the host. | No | `0` |

### 2.1 Embedded Schema: `participants`

An object inside the `SplitTable.participants` array.

| Field | Type | Description |
|:------|:-----|:------------|
| `userId` | string (UUID) | The `UserProfile.id` of the participant. |
| `displayName` | string | `UserProfile.displayName` (Denormalized for speed). |
| `status` | string | `joining`, `claiming`, `paid_in_app`, `awaiting_confirmation`, `paid_outside`. |
| `totalOwed` | number | The calculated total this user owes (updates in real-time). |

### 2.2 Embedded Schema: `items`

An object inside the `SplitTable.items` array.

| Field | Type | Description |
|:------|:-----|:------------|
| `itemId` | string (UUID) | A unique ID for this item (generated in-app). |
| `name` | string | The item name from the OCR scan (e.g., "Steak Frites"). |
| `price` | number | The price of this single item (e.g., `30.00`). |
| `claimedBy` | array (object) | List of users claiming this item. See schema below. |

### 2.3 Embedded Schema: `items.claimedBy`

An object inside the `items.claimedBy` array.

| Field | Type | Description |
|:------|:-----|:------------|
| `userId` | string (UUID) | The `UserProfile.id` of the claimant. |
| `share` | number | The portion of the price this user is responsible for (e.g., `15.00` if split 50/50). |

---

## 3. `RollingTab` Collection (Future)

This collection tracks a "rolling tab" or net balance between two friends.

**Document ID:** `id` (string) - *A composite key: `[userA_id]::[userB_id]` (alphabetically sorted).*

| Field | Type | Description | Required |
|:------|:-----|:------------|:---------|
| `id` | string | Composite key of the two user IDs. | **Yes** |
| `userIds` | array (string) | The two `UserProfile.id`s in this tab. | **Yes** |
| `netBalance` | number | How much User B owes User A. (Positive if A is owed, negative if A owes). | **Yes** |
| `lastUpdated` | string (ISO 8601) | The last time this tab was modified. | **Yes** |

**Example `RollingTab` Document:**

```json
// This ID represents a tab between user "aaa..." and "bbb..."
{
  "id": "aaa-user-id::bbb-user-id",
  "userIds": [
    "aaa-user-id",
    "bbb-user-id"
  ],
  // "bbb" owes "aaa" $12.50
  "netBalance": 12.50,
  "lastUpdated": "2025-11-20T10:00:00Z"
}
```
