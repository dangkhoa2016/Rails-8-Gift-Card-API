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
5. In **My cards**, inspect Product/Brand, face value and status; click **View** or the activation number to auto-scroll to and focus the selected card details below the list without fetching again when cached. The selected card detail is highlighted and its status displayed. Cancel an issued card and verify the cancellation in personal spending.
6. Return to Admin, refresh Reports and Audit logs, and verify corresponding events.

The API console supports GET, POST, PATCH and DELETE for same-origin /api/v1/ endpoints only. It sends JSON objects, accepts an optional Idempotency-Key header, and displays HTTP status, duration and raw JSON. See API_EXAMPLES.md for example requests.

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
- **Client UI navigation:** Product selection in Issue card is an accessible searchable list rather than a long select. Each issuance response scrolls to its result panel without changing idempotency semantics; all other API payloads and endpoints remain unchanged. My cards **View** scrolls and keyboard-focuses the detail heading after cached or uncached retrieval, respecting reduced-motion preferences and avoiding redundant GET requests for loaded cards.
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

In **My cards**, selecting **View** opens the Card detail. For an owned Card with `has_pin=true`, the Client can enter their current account password and click **Reveal PIN**. The separate `POST /api/v1/client/cards/:id/reveal_pin` endpoint checks ownership, reconfirms the current password, and returns the PIN with `Cache-Control: no-store, private`. The decrypted PIN is never included in normal GET list/detail responses. The password is read from an unbound input, cleared after submission, and not persisted in Vue state, local storage, or browser history. PIN reveal and failed attempts are audited without storing credentials or PIN values. After five wrong passwords in 15 minutes, reveal is rate-limited (HTTP 429) for that Client. The PIN disappears on **Hide PIN**, navigation, sign-out, or after 30 seconds; it is not copied into the list/detail record.

Use a Client's own account password, **not an Admin password**. A Card without a PIN shows `None`, not a Reveal action. Cancelled Cards owned by that Client can still be revealed. PINs should not be shared in screenshots or logs.

### Inline errors for My cards PIN confirmation

The password-confirmation form for **My cards → View → Reveal PIN** displays incorrect-password, rate-limit and other non-session PIN reveal errors directly **below the password input**, using `role=alert`, `aria-invalid` and `aria-describedby`. The global page-header error banner is reserved for unrelated requests and expired sessions. Errors disappear when the Client types again, selects a different Card, signs out, or successfully reveals the PIN. The password field is always cleared after an attempt. Backend authentication, ownership, throttling and audit behavior are unchanged.
