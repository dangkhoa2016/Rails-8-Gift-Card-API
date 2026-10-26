# Optional Vue 3 Review Workspace

This is an optional, non-mock interactive UI for reviewing the real Gift Card API. It does not replace the JSON API, change business logic, or require any build system.

## Run locally

Set up Ruby 3.4, Rails 8.1, PostgreSQL and dependencies using the root README. In development, create demo accounts and a sample authorized product:

    export DEMO_ADMIN_PASSWORD='CHOOSE_A_STRONG_LOCAL_ADMIN_PASSWORD'
    export DEMO_CLIENT_PASSWORD='CHOOSE_A_DIFFERENT_STRONG_LOCAL_CLIENT_PASSWORD'
    bin/rails db:prepare
    bin/rails db:seed
    bin/rails server

Open http://localhost:3000/demo (or /demo/index.html). Sign in as admin@example.test or client@example.test using the corresponding locally configured password. No real or demo passwords are embedded in static files.

## Development seed and report validation

Development seeding creates fictional human-readable Brand names such as Aurora Market, Bluebird Market, Cedar Books, Harbor Books and Willow Tech. Rerunning the seed upgrades previous numbered synthetic Brand names **on the same Brand records**, preserving their IDs and all associated Products, Cards, access grants and audit events. Keys are stable and credentials/PINs are never printed.

For meaningful financial grouping, the seed adds 15 Cards distributed across five different USD Brands for the main reviewer Client, plus nine Cards for three distinct synthetic Clients with different payout rates. It calls the actual Cards::Issue and Cards::Cancel application services. As Admin, open **Financial reports**: **By brand** separates multiple Brands in USD; **By client** displays the main Client plus three synthetic Clients. Client reports remain restricted to their own Cards. The original 160 pagination Cards are not reassigned, and repeated seeds do not add Cards or audit events.

## Admin workflow

1. In **Brands**, create a brand, use **View** to retrieve its details, **Edit** to change its name/state/custom fields, or deactivate/reactivate it. There is intentionally no Brand hard-delete endpoint.
2. In **Products**, choose a brand; create, view, edit name/value/currency/custom fields/state, or soft-delete an individual product. Existing cards remain historically intact. A product's parent Brand is not editable.
3. In **Clients**, create an account, view details, edit email/payout rate/status, optionally replace its password, and disable/reactivate the account. There is intentionally no Client hard-delete endpoint.
4. In **Product access**, type all or part of a Client email into **Find a Client** to see live matching rows; click a row to select it (or follow **Grants →** from Clients). A selected Client can be changed with **Change Client**; searches are case-insensitive over up to 100 loaded Client records and show a clear empty result when nothing matches. The account summary shows email, active/disabled status and payout rate. Choose a Brand and optionally search the product list. Each ungranted, non-deleted Product has a **+ Grant** button; once granted, it moves out of available products and appears in **Granted products** across all Brands. Search grants by product/brand/currency and use **Revoke** with a confirmation dialog to remove a permission. Existing issued cards are unaffected. Inactive Products/Brands are identified because access alone does not permit issuance until they become active. Successful grant/revoke actions update the lists without an extra GET; use **Refresh** to synchronize changes made elsewhere. Up to 100 Products per Brand and Grants per Client are displayed.
5. In **Reports**, grouping IDs are rendered as Brand names or Client emails; click those names to open the related Admin details, or inspect raw JSON. **Audit logs** can be filtered by Action, Actor, Outcome (`success` / `refused`) and UTC date/time down to **HH:MM:SS**. **From (UTC, inclusive)** and **To (UTC, inclusive second)** use `datetime-local` controls (`step=1`); their displayed wall-clock values are interpreted as UTC, not the browser's local timezone. Both entered seconds are included; the UI sends an ISO8601 `from` timestamp and adds one second to the entered `to` before calling the API's half-open `[from, to)` endpoint. For example, 2026-10-20 10:15:30 through 10:15:30 UTC includes every event in that second, including fractional-second database timestamps. Leave either timestamp blank for an open-ended range, use **Apply filters** to fetch the latest 50 matches, or **Clear all** to reset all filters. Filtering is server-side (before pagination), and invalid ranges are rejected rather than silently returning no matches. Audit rows show outcome badges, actor emails and affected-record links where an Admin view exists; events involving cards remain read-only because there is no Admin card-detail API.
6. Click a Brand or Client name to see record details; click a Product's Brand name to open its parent. Product access cards link Products, Brands and Clients to the corresponding Admin workspaces. Choosing **Product access** directly from the menu requires an explicit Client selection; deep links from the Clients directory and Audit log retain their target Client.

## Client workflow

1. Sign in as Client and open Catalog. Only active granted products are shown, with Brand names. Search Product/Brand names and filter by currency. Click the Brand label to narrow the catalog to that Brand, or the Product name to jump to Issue card with it selected. Use **Clear** to remove all filters.
2. In **Issue card**, choose an authorized Product from searchable selection cards; the selected Brand, face value and currency appear in a review summary. Supply a unique Idempotency-Key or use **Generate key** (browser `crypto.randomUUID()`), optionally enable PIN, then click **Issue gift card**. The result area displays HTTP 201, activation number, face value, payout, and PIN only if the API supplied it; focus and scroll move to the result. Existing catalog product deep links retain their selection.
3. Submit the identical request with the same key. Observe HTTP 200 and the same card ID, clearly shown as an idempotent replay, without issuing another card. After each successful HTTP 201 or HTTP 200 response, the form clears the selected Product, Idempotency-Key and Generate PIN checkbox, while keeping the last Card response visible. **To test replay, copy the original key before submission, then reselect the same Product, re-enter the key and restore the same PIN option.** Failed requests such as HTTP 409 keep the form values unchanged for troubleshooting.
4. Change the Product or PIN option but reuse the same key. Observe HTTP 409. Use **Generate key** for a new card instead.
5. In **My cards**, inspect Product/Brand, face value and status; click **View** or the activation number to open a focused modal showing that Card without fetching again when cached. Close with X, Close, Escape or backdrop to return to the same list position; the modal shows the Card status. Cancel an issued card and verify the cancellation in personal spending.
6. Return to Admin, refresh Reports and Audit logs, and verify corresponding events.

The API console supports GET, POST, PATCH and DELETE for same-origin /api/v1/ endpoints only. It sends JSON objects, accepts an optional Idempotency-Key header, and displays HTTP status, duration and raw JSON. See API_EXAMPLES.md for example requests.

## Financial reports: traceable Card drill-down

Issued and Cancelled counts in each reporting row are accessible buttons. Select a number to open a read-only, paginated Card records dialog showing activation number, Card ID, Product, Brand, face-value/payout snapshots, current status and event timestamp. Admin also sees the owning Client. First/Previous/Next/Last navigate matching events without downloading the entire list. The dialog is keyboard accessible and closes via Escape, X, Close or backdrop while preserving the original report and scroll position.

The optional read-only endpoints are GET /api/v1/client/reports/cards and GET /api/v1/admin/reports/cards, accepting currency, event=issued|cancelled, UTC from/to, page and per_page (max 100). Client requests are always scoped to current_user.cards, optionally narrowed by brand_id; forged client_id is rejected. Admin requests require group_by=brand&brand_id=... or group_by=client&client_id=..., never an unrestricted list. The same half-open event-time rules as the SQL financial report apply before server-side pagination: Issued means issued_at in the range, even if subsequently cancelled; Cancelled means cancelled_at in range. Current status is shown separately so it cannot be confused with the historical event. PINs, encrypted PINs, passwords and idempotency data are never returned; revealing PIN is still restricted to the password-confirmed Client workflow. An event count mismatch from a concurrent update is visibly explained.

## Financial reports: human-readable dashboard

The event-time ledger calculation and financial snapshots are unchanged. **Admin** sees **Financial reports** with the existing **By brand / By client** options. **Client** sees **Personal spending** with **By currency / By brand**. The Client **By brand** choice sends GET /api/v1/client/reports/spending?group_by=brand, restricted to that authenticated Client's own Cards. A Client cannot group across other Clients or open Admin-only Brand screens. The original currency-only response remains the default when group_by is omitted. Unsupported grouping returns 422 invalid_filter. Group names are returned as read-only labels for clarity.

The UI provides **All time**, **This month** and **Last 30 days** quick periods, plus explicit From/To UTC inputs and a **Run report** button. From is inclusive; To is exclusive. Both empty means all historical events. The results show issued/cancelled event counts, **separate currency summary cards** for face value and payout, and a compact detail table with expandable **View figures** for gross issuance and cancellation totals. The currency selector filters the already loaded presentation only; it never requests another endpoint or converts between currencies. Net payout **activity** refers to issuance payout minus cancellation reversal in the selected event-time window, not the current outstanding balance. An empty report explains how to broaden the dates; the original raw API JSON is still inspectable.

To create new report data, use the existing Client **Issue gift card** and **Cancel** workflows; no report-specific manual input is supported or required. Re-running the demo seed solely to display reports is unnecessary.

## Global Back to top shortcut

The optional demo shows a floating **Top** shortcut at the lower-right of the viewport once the page has been scrolled more than 360 px. It scrolls the document back to the top with smooth motion, or instant motion when the browser prefers reduced motion. The shortcut stays hidden near the top and while any detail/error modal is open, so it does not compete with modal navigation. It works for both Admin and Client, on desktop and mobile. It does not modify application state or call API endpoints.

## Architecture and security

- Three static files under public/demo/: index.html, app.js and style.css.
- Vue 3 loaded from a version-pinned production global CDN build: https://cdn.jsdelivr.net/npm/vue@3.5.22/dist/vue.global.prod.js
- No npm package, separate frontend server, Vue CLI, Vite, Webpack, SFC, Tailwind Play CDN, build, or transpilation is required.
- Static UI and Rails API share one origin. No extra Cloudflare tunnel or backend port required.
- Browser internet connectivity to the Vue CDN is necessary; the backend and automated tests do not depend on this CDN.
- JWT stays only in Vue application memory, not localStorage, sessionStorage, cookies or URL parameters. Refresh and sign-out discard it.
- No password or secret is included in the static HTML/JS. Vue escapes interpolated data; no dynamic v-html is used.
- API Console validates same-origin /api/v1/ paths; it is not an open proxy to external origins.
- PIN is visible only when issuance or replay returns it. Sign-out clears this UI state. Do not share screenshots containing PINs.
- Admin authorization remains enforced by the Rails backend, not by frontend menus.
- Directory tables show at most 100 records per view, audit up to 50; the backend supports pagination. Names/emails are used for human-readable associations while numeric IDs remain visible for debugging. Very large directories may require API Console pagination.
- Additional labels in JSON responses are read-only convenience fields; CRUD, authorization and PIN security remain controlled by the original Rails API.
- **Validation errors:** when the API returns `error.details`, the UI lists each field-level error in an accessible error banner. For Clients, Email/Password/Payout rate errors also appear beside the relevant input, with invalid styling; a duplicate email displays a clear "Email address is already in use" explanation. Field feedback clears on input change, and the generic API message remains a fallback when no structured details are supplied. This is frontend presentation only; backend validation and JSON contracts are unchanged.
- Association names are clickable, keyboard-focusable in-session links. Their destinations are role-scoped; a Client is never offered links to protected Admin resources. The JWT remains in memory, so reloading/opening a new tab requires signing in again.
- **Client UI navigation:** Product selection in Issue card is an accessible searchable list rather than a long select. Each issuance response scrolls to its result panel without changing idempotency semantics; all other API payloads and endpoints remain unchanged. My cards **View** opens an accessible modal with keyboard focus on the detail heading after cached or uncached retrieval, preserving the underlying list position and avoiding redundant GET requests for loaded cards.
- **Request optimization:** the Admin Brand/Product/Client list serializers contain the same display fields as their detail endpoints. Opening a record already in the current in-memory list performs **zero additional API requests**, including cross-page links when cached. Uncached deep links perform **one detail GET**, not list reloads and multiple detail GETs. The same reuse applies to Client card details; this is a browser-memory cache only. Use **Refresh** to retrieve current server state after external changes; Refresh also replaces or clears a previously selected cached detail.
- The UI displays an SVG loading indicator and progress stripe for list/detail requests, plus an animated CSS spinner for form submissions. While a request is in flight, its controls are disabled, and the indicator is removed on success or error. Reduced-motion preferences disable animation.
- Brand and Client removal means **deactivation**, not hard delete; Product removal is a soft-delete, and Gift Cards can only be issued or cancelled.
- This review UI is not a production identity client. CSP hardening, rate limits, production token revocation and extensive accessibility testing are separate concerns.

## Validation

    bundle exec rspec
    bin/rubocop
    bin/brakeman --no-pager
    node --check public/demo/app.js

The Rails HTTP smoke tests for the interface live in spec/requests/demo_ui_spec.rb. Manual/browser verification is useful in addition to, not instead of, the complete RSpec suite.

### Client My cards: PIN availability filters

The two checkboxes **With PIN** and **Without PIN** are mutually exclusive. Selecting one filters the current Client's cards, clicking it again returns to all PIN states, and **Clear filters** also resets Status. These filters are combined on the server before pagination, including cancelled cards. The list and detail responses contain only the `has_pin` boolean (`Enabled` or `None` in the UI). The encrypted PIN itself is never returned by GET endpoints.

### Client PIN reveal: step-up verification and temporary display

In **Issue card**, a PIN returned by a successful issue/replay response is **masked by default** in the Latest Issuance Response panel. Click **Reveal PIN** to show it, or **Hide PIN** to mask it immediately; the screen automatically masks the PIN after 30 seconds. No-PIN cards do not show this control. Leaving Issue card discards the previously issued PIN from the Client UI state; to reveal that PIN again, use the password-confirmed My cards workflow.

In **My cards**, selecting **View** opens the Card detail. For an owned Card with `has_pin=true`, the Client can enter their current account password and click **Reveal PIN**. The separate `POST /api/v1/client/cards/:id/reveal_pin` endpoint checks ownership, reconfirms the current password, and returns the PIN with `Cache-Control: no-store, private`. The decrypted PIN is never included in normal GET list/detail responses. The password is read from an unbound input, cleared after submission, and not persisted in Vue state, local storage, or browser history. PIN reveal and failed attempts are audited without storing credentials or PIN values. After five wrong passwords in 15 minutes, reveal is rate-limited (HTTP 429) for that Client. The PIN disappears on **Hide PIN**, closing the detail modal, navigation, sign-out, or after 30 seconds; it is not copied into the list/detail record.

Use a Client's own account password, **not an Admin password**. A Card without a PIN shows `None`, not a Reveal action. Cancelled Cards owned by that Client can still be revealed. PINs should not be shared in screenshots or logs.

### Inline errors for My cards PIN confirmation

The password-confirmation form for **My cards → View → Reveal PIN** displays incorrect-password, rate-limit and other non-session PIN reveal errors directly **below the password input**, using `role=alert`, `aria-invalid` and `aria-describedby`. The global page-header error banner is reserved for unrelated requests and expired sessions. Errors disappear when the Client types again, selects a different Card, signs out, or successfully reveals the PIN. The password field is always cleared after an attempt. Backend authentication, ownership, throttling and audit behavior are unchanged.

### Friendly API errors and optional diagnostics

When an API request fails, the UI shows a short, understandable message rather than an exception object or Rails framework trace. The **API console** displays a friendly failure summary, HTTP status and request ID. Choose **View error details** to open a keyboard-accessible modal displaying the actual **raw JSON HTTP error response** (not the server-side Rails log file). Other workspace request errors also provide a details button with the same modal. Sensitive response keys (including PIN, passwords and tokens) are redacted before display. Close using the X, Close button, backdrop or Escape.

For a deliberately mistyped endpoint such as `GET /api/v1/client/catalog7`, the API returns HTTP 404 and `error.code=route_not_found`, not a framework trace. The environment variable `WOGI_SHOW_EXCEPTION_DETAILS` defaults to `false`. When set to `true` **in a non-production environment**, the `error.details` object may additionally include `exception_class`, filtered `exception_message`, and up to 15 filtered backtrace entries. This is only for trusted debugging; **never enable debug details on a publicly accessible Cloudflare Quick Tunnel**. Production always disables detail exposure. Other business/API errors continue to retain their existing `error.code`/`error.message` contract.

Example (for a trusted local instance only):

```bash
WOGI_SHOW_EXCEPTION_DETAILS=true bundle exec rails server --binding 127.0.0.1 --port 3000
```

Changing the setting for an already running server requires restarting Rails with the desired environment. The modal can still display the safe API response when details are disabled.

### Pagination fixtures for API reviewers

The development-only `db/seeds.rb` creates sufficient synthetic Brands, Products, Clients, Product Access grants, Gift Cards and audited card events for multi-page API testing (including `per_page=100`). It is safe to rerun without resetting the database. Account credentials are not printed, and extra test Client passwords are randomly generated and not exposed. On a persistent Kaggle runtime with existing accounts, run `bash /kaggle/working/setup_wogi_kaggle.sh seed` explicitly to add the fixtures; `resume` intentionally does not reseed a populated database.

Use **API Console** to explore pagination: Admin `GET /api/v1/admin/brands?page=2&per_page=25`, Admin `GET /api/v1/admin/clients?page=2&per_page=25`, Admin `GET /api/v1/admin/audit_logs?page=2&per_page=25` and Client `GET /api/v1/client/cards?page=2&per_page=25&has_pin=true`. Inspect `meta.page`, `meta.per_page` and `meta.total` and compare page 1 with page 2. `per_page` is capped at 100. The Client **My cards** workspace supports numbered pages, Previous/Next, total matching count and 10/25/50/100 records per page using the same API metadata; other standard workspaces still show only the first page. API Console can exercise all pagination endpoints directly. The Client Catalog endpoint returns its eligible result set without server-side pagination.

### Independent Catalog and Issue card navigation

Client **Catalog** search, currency and Brand filters are temporary view state. Opening **Catalog** through the sidebar (including revisiting it) clears all three filters and reloads the complete entitled catalog. Clicking a Brand label on a Catalog tile is the intentional exception: it opens the Catalog filtered to that Brand only, with the other filters cleared.

**Issue card** is independent: each visit via the sidebar clears the Issue product-search input and starts without a selected Product. Its available Product list is fetched without Catalog filter parameters. Clicking **Issue card →** or the Product name from a filtered Catalog instead forwards **only the Product ID** as a one-time navigation option, loads the full entitled list in Issue card, and preselects the matching Product. Nothing from the Catalog query, currency, or Brand filter is carried across; a revoked/unavailable Product is not retained as a valid selection. Returning to the Catalog later starts unfiltered again. This behavior changes only Vue page state, not API contracts, authorization or idempotency semantics.

### My cards: server-side text search and independent deep-linked Card details

The Client **My cards** page includes a text search for an **activation number, Product name or Brand name**. Type part of any value and press **Search** or Enter; combine with the existing Status and With/Without PIN controls. Searching is performed by the authenticated Rails API with `GET /api/v1/client/cards?q=...` **before pagination**, not by filtering only the currently loaded rows in JavaScript. Search is case-insensitive; `%` and `_` are treated as literal text. `q` is capped at 100 characters; invalid types produce `422 invalid_filter`. Normal list and detail GETs never disclose decrypted PINs, and the query is restricted to the current Client's own Cards.

Press **Clear filters** to clear text, Status and PIN choices. **My cards** starts with 25 records per page (select 10/25/50/100) and shows the total matching count, current range, numbered pages and First/Previous/Next/Last. First and Previous are disabled on page 1; Next and Last are disabled on the last page. Search, Status and PIN changes return to page 1, and switching pages retains the filters. After a successful First, Previous, Next, Last, or numbered-page click, the viewport scrolls to the top of the refreshed Card list (with reduced-motion preferences respected). Click the **Gift card**, **Product / Brand**, **Face value**, **Payout**, **Status**, or **PIN** table header to sort all matching Card records on the backend (not just the currently loaded page). Clicking the same header again reverses the direction; switching to a new column starts ascending and returns to page 1 while retaining Search/Status/PIN filters. The active direction is indicated by an arrow and accessible aria-sort. Product is sorted case-insensitively by Product name and then Brand, financial amounts numerically (currency as a secondary key), and PIN by has_pin existence; equal values use Card ID descending to prevent unstable page boundaries. Default navigation returns to Card ID descending. **Actions** is not sortable. The optional API parameters sort_by and sort_dir are strictly validated; unsupported fields/directions return HTTP 422 invalid_filter, without exposing PIN values. Selecting an activation number or **View** in the currently loaded list reuses its cached row; it does **not** navigate away, clear filters or refetch the first page. Each visit to **My cards** using the sidebar loads the unfiltered first page. The **View in My cards →** link in the Issue gift card result similarly opens the normal unfiltered first page **and** loads the specific Card detail by ID when it is not in that page. The details open in a focusable modal without scrolling the underlying list; the list is never replaced with only that record. The separate password-confirmed PIN reveal retains all its existing safeguards.
