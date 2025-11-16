# Phase 3 Plan: OCR & AI Bill Scanning

**Objective:** Integrate AI-powered bill scanning. This phase enables the Host to scan a physical receipt, have an AI parse it into itemized line items, and populate the `SplitTable` document, all propagated in real-time via SignalR.

**References:**

* **Master Spec:** `claude.md`
* **Design System:** `system-design.md`
* **Database Schema:** `database-schema.md` (Crucial for the `SplitTable.items` schema)

---

## 1. High-Level Goals

1. **Build Scan UI:** Create a camera interface for capturing the bill image.
2. **Create Azure Function:** Develop an Azure Function (`POST /tables/:tableId/scan`) to receive the image.
3. **Integrate AI:** Have the Azure Function securely call the **Gemini API (via Vertex AI)** to perform OCR and bill analysis.
4. **Populate Bill:** The function will **`PATCH`** the `SplitTable` document, adding the AI-parsed items to the embedded `items` array.
5. **Enable Host Editing:** Build a UI (Host-only) and corresponding Azure Function endpoints (`PUT`, `DELETE`) to manage the `items` array.
6. **Test Route:** Create a dedicated `/ocr-test` route for isolated testing of the Vertex AI integration.

---

## 2. Feature Breakdown

### 2.1 "Scan Bill" Button (Host Flow)

* **Enable "Scan Bill" Button:** On the `/table/:tableId` screen, the "Scan Bill" button (previously a stub) is now active for the Host.
* **Navigation:** Tapping this button navigates the Host to a new `/table/:tableId/scan` screen.

### 2.2 Bill Scanning Screen (`/table/:tableId/scan`)

* **UI:** Implement a full-screen camera preview using the `camera` package.
* **Overlay:** Show simple corner-bracket guides.
* **Capture Button:** A standard "Capture" button.
* **Confirmation Step:**
  * On capture, navigate to a "Confirm Image" screen (`/table/:code/confirm-scan`).
  * Show the captured image.
  * **"Use Photo" Button (`PrimaryButton` - `Deep Berry`):** Proceeds to the next step.
  * **"Retake" Button (`SecondaryButton` - `Dark Fig` Outline):** Navigates back.

### 2.3 Azure Function: AI Scan (`POST /tables/:tableId/scan`)

* **Authentication:** Must be secured; validates the Supabase JWT from the `Authorization` header.
* **Input:** `(imageBytes: Uint8List)` from a multipart/form-data request.
* **Logic:**
  1. **Receive Image:** Get the image data.
  2. **Call Gemini (Vertex AI):** Securely call the Vertex AI API for Gemini.
  3. **Prompt Engineering:** Use a prompt designed to extract line items and return structured JSON.
      > **Prompt:** "You are an expert receipt OCR system. Extract all line items from this image. For each item, provide a 'name' and a 'price' as a numeric value. Return only a valid JSON array of objects, like `[{\"name\": \"Burger\", \"price\": 120.50}, {\"name\": \"Fries\", \"price\": 45.00}]`. Do not include tax or tip."
  4. **Parse Response:** Parse the JSON response from Gemini.
  5. **Get Document:** Fetch the *one* `SplitTable` document from Cosmos DB.
  6. **Atomic `PATCH`:** Add the new items (with new `itemId` UUIDs) to the `items` array.
  7. **Save Document:** `PATCH` the `SplitTable` document back to Cosmos DB.
  8. **Return:** Return a `200 OK` to the client.

### 2.4 Client-Side OCR Handling (Riverpod)

* **`OcrRepository`:**
  * On "Use Photo" tap, show a full-screen loading indicator ("Analyzing bill...").
  * Call the `POST /tables/:tableId/scan` Azure Function with the image data.
  * **On Success:** Navigate *back* to the `/table/:tableId` screen.
  * **On Error:** Show an error dialog ("Failed to scan bill. Please try again or add items manually.") and navigate back.
* **Real-time Update (The Magic):**
  * The client **does nothing** with the function's response.
  * The backend `PATCH` operation triggers the **Cosmos Change Feed**.
  * This (from Phase 2) fires the **SignalR `table_updated` event**.
  * The client's main `AsyncNotifier` (listening to SignalR) receives the *entire new `SplitTable` object* (now full of items) and automatically rebuilds the UI. The items just appear.

### 2.5 Host Editing UI (`/table/:tableId` Screen)

* **Conditional UI:** This UI is **only visible** to the Host.
* **Edit Item:**
  * Each `ItemCard` gets an "Edit" `IconButton` (`Icon(Icons.edit)`).
  * Tapping it opens a dialog pre-filled with the item's `name` and `price`.
  * On save, calls a new Azure Function: **`PUT /tables/:tableId/item/:itemId`**
* **Delete Item:**
  * Each `ItemCard` gets a "Delete" `IconButton` (`Icon(Icons.delete)`, `Destructive` Red color).
  * Tapping it shows a confirmation dialog.
  * On confirm, calls a new Azure Function: **`DELETE /tables/:tableId/item/:itemId`**
* **Real-time Updates:** Both `PUT` and `DELETE` functions work the same way: they `PATCH` the `items` array in the Cosmos document, which fires the Change Feed and updates all clients via SignalR.

### 2.6 Debug/Test Route (`/ocr-test`)

* **Purpose:** To test the Vertex AI integration in isolation.
* **UI:** A "Pick Image from Gallery" button and a "Run OCR Test" button.
* **Logic:**
  * Calls a new, simple Azure Function: **`POST /ocr-test`**.
  * This function *only* calls Gemini with the image and returns the raw JSON response. It does not touch Cosmos DB.
  * The client displays the raw JSON response in a text box for debugging.

---

## 3. Azure Function Endpoints Needed

| Endpoint | Action | Description |
|:---------|:-------|:------------|
| `POST /tables/:tableId/scan` | Scan Bill | (Host) Sends image, calls Vertex AI, patches `items` array. |
| `PUT /tables/:tableId/item/:itemId` | Edit Item | (Host) Edits a single item in the `items` array. |
| `DELETE /tables/:tableId/item/:itemId` | Delete Item | (Host) Removes a single item from the `items` array. |
| `POST /ocr-test` | Test AI | (Debug) Sends image, returns raw Gemini JSON. |

---

## 4. Definition of Done (Acceptance Criteria)

* [ ] The "Scan Bill" button is enabled for the Host and disabled for Participants.
* [ ] The Host can capture a photo and confirm it.
* [ ] Tapping "Use Photo" sends the image to the `.../scan` Azure Function and shows a loading state.
* [ ] The Azure Function successfully calls the Gemini (Vertex AI) API.
* [ ] The Azure Function successfully `PATCH`es the `SplitTable` document with the new items.
* [ ] The Host (and all participants) see the new items appear on the Bill Screen in real-time **via the `table_updated` SignalR event**.
* [ ] The Host can tap the "Edit" icon, change an item's price, and all participants see the price update via SignalR.
* [ ] The Host can tap the "Delete" icon, confirm, and all participants see the item disappear via SignalR.
* [ ] The `/ocr-test` route exists and can be used to get a raw JSON response from the Vertex AI integration.
* [ ] All new UI elements (scan screen, host controls) strictly follow the `system-design.md`.
