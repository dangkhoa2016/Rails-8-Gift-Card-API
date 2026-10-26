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
2. Choose Issue card. Supply a unique Idempotency-Key, select a product, optionally enable PIN, and issue it.
3. Submit the identical request with the same key. Observe HTTP 200 and the same card ID. New issuance is HTTP 201.
4. Change payload but reuse the same key. Observe HTTP 409.
5. Open My cards to view the Product and Brand names, inspect card details using **View**, then cancel an issued card. Verify the cancellation in personal spending.
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
