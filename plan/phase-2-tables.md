# Phase 2 Plan: Tables & Real-Time Claiming (Azure/Cosmos Data Plane)

**Objective:** Implement the core 'Host' and 'Participant' flows by leveraging a single, denormalized **`SplitTable` document model** in Cosmos DB. This simplifies the entire data plane, enables atomic writes, and makes real-time state management (via SignalR) trivial.

**References:**

* `claude.md` - UX + flow authority.
* `system-design.md`
* `database-schema.md` - **The source of truth for our `SplitTable` document.**
* `backend-api.md` - **The source of truth for our api calls.**

---

## 1. What Changes in This Phase

| Concern | Before (Old Plan) | Now (Our Plan) |
|:--------|:------------------|:---------------|
| Auth | Supabase | **Unchanged** |
| Data | `supabase.from('table')` | Azure Functions writing to Cosmos DB |
| Realtime | Supabase Realtime | Azure SignalR |
| Security | Supabase RLS | Azure Function Supabase JWT Validation |

## 2. The Key Architectural Simplification

This phase's success depends on **one critical decision:**
We will **NOT** use separate Cosmos containers for `participants`, `items`, and `claims`. This is a SQL-on-NoSQL anti-pattern.

Instead, we will use the **single-document model** defined in `database-schema.md`.

* An entire bill-splitting session (Host, participants, all items, all claims) is **one `SplitTable` document**.
* **Reads are fast:** Joining or viewing a table is **one** Cosmos DB read (`GET /tables/:tableId`) that fetches the *entire state*.
* **Writes are atomic:** A user joining or claiming an item is a **one** `PATCH` operation to that single document.
* **Realtime is simple:** The Cosmos Change Feed watches *one* collection. Any change to a `SplitTable` document (new participant, new claim) fires *one* event. The Azure Function then pushes the *entire updated document* via SignalR. The client doesn't need to manage granular events; it just replaces its old state with the new one.

---

## 3. Feature Breakdown (Single-Document Model)

### 3.1 Table Creation (Host Flow)

* **Trigger:** Home "Create Table" button invokes a Riverpod `AsyncNotifier`.
* **API Call:** `POST /tables` (Azure Function).
  * Function validates the Supabase JWT.
  * **Crucially:** It checks if the `UserProfile` has an `activeTableId` (from a previous session).
  * **If `activeTableId` exists:** Returns `409 Conflict` with the *existing* table data. This gracefully handles app-restarts.
  * **If no active table:**
    1. Creates a new `SplitTable` document in Cosmos DB.
    2. Sets `status: "claiming"`.
    3. Adds the Host to the `participants` array.
    4. Saves the new `tableId` to the Host's `UserProfile` document.
    5. Returns the new `SplitTable` document + SignalR negotiation payload.
* **Client:** Caches the `SplitTable` state in Riverpod, connects to SignalR, and navigates to `/table/:tableId`.

### 3.2 Host & Participant Table Screen

* **Data Loading:** On screen load, the `AsyncNotifier` calls `GET /tables/:tableId`.
  * This Azure Function validates the JWT, finds the *one* `SplitTable` document, and returns it.
  * The Riverpod provider is now hydrated with the full table state (participants, items, etc.).
* **UI:** The UI `watch`es the provider. The QR/code, `participants` list, and `items` list are all built from this single state object.

### 3.3 Joining Flow (Participants + Deep Links)

* **Trigger:** Home "Join Table" button or `upeven://join?code=ABC123` deep link.
* **API Call:** `POST /tables/:code/join`.
  * Function validates JWT.
  * Finds the `SplitTable` document by the `tableCode` (requires an index!).
  * Checks `status == "claiming"` and that the user isn't already in the `participants` array.
  * **Atomically:** Patches the `participants` array to add the new user.
  * Returns the *entire, updated* `SplitTable` document + SignalR negotiation payload.
* **Client:** Caches the state, connects to SignalR, navigates to `/table/:tableId`.

### 3.4 Real-Time Subscriptions (The Simple Way)

* **Client:**
  1. Connects to the SignalR hub using the negotiation payload.
  2. Joins the group `table:<tableId>`.
  3. Listens for **one** event: `table_updated`.
* **Backend (Cosmos Change Feed):**
  1. Any `PATCH` to a `SplitTable` document (new user, new item, new claim) fires a change event.
  2. An Azure Function is triggered by the change feed.
  3. This function grabs the *full updated document* and broadcasts it to the `table:<tableId>` SignalR group.
* **Client (On Event):**
  1. When the `table_updated` event is received, the client gets the *new, full JSON* of the table.
  2. It **does not** try to patch its local state. It simply feeds this new JSON object into the Riverpod `AsyncNotifier`, which rebuilds the UI with the fresh, authoritative state.

### 3.5 Claim Logic

* **Trigger:** User taps an item to claim/unclaim.
* **UI:** The UI *optimistically* updates itself (toggles the highlight) and sets a "loading" state.
* **API Call:** `PUT /tables/:tableId/claim`.
  * Body: `{ "itemId": "uuid-of-item", "action": "claim" | "unclaim" }`
  * The Azure Function gets the `SplitTable` document, validates the user/item, modifies the `items` array in memory (adding/removing a `claimedBy` entry), and patches the *one document* back to Cosmos.
* **Reconciliation:** The `PATCH` operation triggers the Change Feed, which fires the `table_updated` event. The client receives the *new* state (which matches its optimistic state) and simply replaces its data, clearing the "loading" state.

---

## 4. Azure Function Endpoints Needed

| Endpoint | Action | Body | Description |
|:---------|:-------|:-----|:------------|
| `POST /tables` | Create Table | `{ "title": "..." }` | Creates a new `SplitTable` document. |
| `GET /tables/:tableId` | Get Snapshot | (none) | Returns the complete `SplitTable` document. |
| `POST /tables/:code/join` | Join Table | (none) | Adds participant to the `participants` array. |
| `PUT /tables/:tableId/item` | Add Item | `{ "name": "...", "price": ... }` | (Host) Adds a new item to the `items` array. |
| `PUT /tables/:tableId/claim` | Claim Item | `{ "itemId": "...", "action": "..." }` | (Participant) Adds/removes a `claimedBy` entry. |
| `POST /signalr/negotiate` | Get Hub Token | (none) | Returns URL/token for the SignalR hub. |

*All endpoints require `Authorization: Bearer <SupabaseJWT>`.*

---

## 5. Definition of Done

* [ ] Host `POST /tables` call creates a **single** `SplitTable` document in Cosmos DB.
* [ ] Host is gracefully re-joined to their active table if one already exists.
* [ ] All clients (Host + Participant) hydrate their UI from a **single** `GET /tables/:tableId` snapshot.
* [ ] Participants can successfully join via `POST /tables/:code/join`, which **patches** the `participants` array.
* [ ] Host can manually add an item, which **patches** the `items` array.
* [ ] Users can claim/unclaim items, which **patches** the `claimedBy` sub-array for that item.
* [ ] **Crucially:** Any patch to a `SplitTable` document triggers the Cosmos Change Feed, which results in a `table_updated` SignalR event being broadcast to all clients in <1s.
* [ ] The client's Riverpod provider correctly replaces its state with the new JSON from the SignalR event, forcing a UI rebuild.
* [ ] The disabled OCR button is present as a stub.
* [ ] Supabase is *only* used for JWT validation on the backend; no data is read from it.
