# Phase 1 Plan: Authentication, Onboarding & Core Setup

**Objective:** Build the foundational shell of the Pyble app, allowing users to sign up, log in, and view a basic home screen. This phase focuses on user identity, session management, and core UI setup.

**References:**
* **Master Spec:** `claude.md`
* **Design System:** `system-design.md`
* **Database Schema:** `database-schema.md`
* **API Schema:** `backend-api.md`

---

## 1. High-Level Goals

1. **Initialize App:** Set up the Flutter project with Supabase, Riverpod, and GoRouter.
2. **Implement Auth Flow:** Create all screens for onboarding, sign-up, and sign-in.
3. **Manage Auth State:** Use Riverpod to manage the user's Supabase session and fetch their Cosmos DB profile.
4. **Create User Profiles:** On sign-up, call the Azure Functions `/profiles` endpoint to create the user's profile document in Cosmos DB.
5. **Build Core UI:** Implement the Home Screen skeleton and a functional Drawer with account management.

---

## 2. Feature Breakdown

### 2.1 Core App Initialization (main.dart)

* Initialize `Supabase` with the project URL and anon key.
* Wrap the app in a `ProviderScope` for Riverpod.
* Set up `MaterialApp.router` using the `GoRouter` configuration.
* Apply the `lightTheme` (using `Snow`, `Dark Fig`, etc.) from the `system-design.md` to the `theme` property.

### 2.2 Routing (GoRouter)

* Implement the following initial routes:
    * `/onboarding` (for new users)
    * `/auth` (for sign-in / sign-up)
    * `/home` (the main app screen after login)
    * `/terms` (for accepting T&Cs)
    * `/settings` (stubbed page for account details)
* Implement an **Auth Redirect Guard** (`listen`ing to the Riverpod `userProfileProvider`):
    * **Case 1 (Logged Out):** If auth state is `null`, all routes redirect to `/auth` (except `/onboarding`).
    * **Case 2 (Logged In, T&Cs NOT Accepted):** If auth state is `valid` but `UserProfile.hasAcceptedTerms == false`, all routes **must** redirect to `/terms`.
    * **Case 3 (Logged In, T&Cs Accepted):** If auth state is `valid` and `UserProfile.hasAcceptedTerms == true`, redirect `/auth` or `/onboarding` to `/home`.

### 2.3 Auth State Management (Riverpod)

* Create a global `authStreamProvider` that listens to `supabase.auth.onAuthStateChange` and returns the `User?`.
* Create a global `userProfileProvider` (e.g., `AsyncNotifierProvider`) that:
    1. `watch`es the `authStreamProvider`.
    2. If the auth state is `null`, it returns `AsyncValue.data(null)`.
    3. If the auth state is `valid`, it calls the Azure `/profiles/me` endpoint to fetch the user's profile from Cosmos DB.
    4. This single provider will manage the app's `UserProfile?` state.
* The `GoRouter` redirect guard will `listen` to this `userProfileProvider`.

### 2.4 Onboarding & T&Cs Flow

* **Onboarding Screen (`/onboarding`):**
    * Show only if `tutorialSeen` (stored in `shared_preferences`) is `false`.
    * Implement the multi-screen swipe tutorial.
    * Must have a **"Skip tutorial"** button.
    * On completion or skip, set `tutorialSeen = true` in `shared_preferences` and navigate to `/auth`.
* **Terms & Conditions Screen (`/terms`):**
    * This screen will be **forced** by the `GoRouter` guard on first login.
    * Must have a scrollable T&Cs text.
    * Must have a checkbox "I accept the Terms & Conditions".
    * The "Continue" button (`Deep Berry` primary) is disabled until the box is checked.
    * On tap, call an Azure endpoint (`/profiles/me/accept-terms`) to set `hasAcceptedTerms = true` in Cosmos DB. This will cause the `userProfileProvider` to refetch, and the `GoRouter` guard will then automatically redirect to `/home`.

### 2.5 Authentication Screens (`/auth`)

* **UI Implementation:**
    * Follow the `system-design.md` for all components.
    * **Text Fields:** Use the specified style (`Dark Fig` text, `Snow` background, `Deep Berry` focus border).
    * **Buttons:**
        * "Continue with Google" (`SecondaryButton` style).
        * "Continue with Microsoft" (`SecondaryButton` style).
        * "Sign In / Sign Up" (`PrimaryButton` style, `Deep Berry`).
* **Auth Logic:**
    * Implement `supabase.auth.signInWithPassword` and `supabase.auth.signUp`.
    * Implement `supabase.auth.signInWithOAuth` for Google and Microsoft.
    * Display error messages (e.g., "Invalid password") from Supabase in a `Snackbar` or inline text.
* **Profile Creation (On Sign Up):**
    * After a successful `signUp`, call the Azure `/profiles` endpoint to create the user's profile document in Cosmos DB.
    * The payload should include the Supabase `auth.users.id`, email, and display name.

### 2.6 Home Screen & Drawer Skeleton

* **Home Screen (`/home`):**
    * A simple `Scaffold` with an `AppBar` (with `Dark Fig` title) and a `Drawer`.
    * The body should contain two large, centered buttons:
        * **"Create Table"** (`PrimaryButton` - `Deep Berry`). (Does nothing in this phase).
        * **"Join Table"** (`SecondaryButton` - `Dark Fig` outline). (Does nothing in this phase).
* **Drawer Implementation:**
    * Must match the `system-design.md` specification.
    * **Account Section:**
        * Display `UserProfile.displayName` and `email`.
        * Stubbed "Delete account" button (`Destructive` style). It should show a confirmation dialog.
    * **Sign Out Button:**
        * Must be pinned at the bottom.
        * Must use the `Destructive` style (Red text/icon).
        * On tap, must call `supabase.auth.signOut()` and navigate the user back to the `/auth` screen.
    * **Stubbed Menu Items:**
        * "Payment Methods" (links to an empty page).
        * "History" (links to an empty page).
        * "Settings" (links to `/settings` page).

---

## 3. Definition of Done (Acceptance Criteria)

* [ ] App initializes Supabase and Riverpod without errors.
* [ ] A **new user** can open the app, see/skip the tutorial, and sign up using Email/Password.
* [ ] A **new user** can sign up using Google.
* [ ] On successful sign-up, the Azure Functions `/profiles` endpoint is called and the profile document is stored in Cosmos DB.
* [ ] A **new user**, after signing in, is **forced** to the `/terms` screen and cannot leave until they accept the T&Cs.
* [ ] An **existing user** (with T&Cs accepted) can open the app and is automatically logged in (persistent session works).
* [ ] A logged-in user lands on the `/home` screen.
* [ ] The Home screen shows the "Create Table" and "Join Table" buttons.
* [ ] The user can open the Drawer, see their email/name in the header.
* [ ] Auth errors (e.g., wrong password) are shown to the user.
* [ ] The user can successfully **sign out** from the Drawer and is returned to the `/auth` screen.
* [ ] All UI components (buttons, inputs, drawer) **must** strictly follow the `system-design.md` palette (`Deep Berry`, `Dark Fig`, `Snow`, etc.).
