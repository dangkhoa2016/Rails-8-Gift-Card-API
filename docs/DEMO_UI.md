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

1. Open Brands, create or activate a brand.
2. Open Products, choose the brand and create a product with face value and currency.
3. Open Clients, create a client, specify a payout percentage, or disable/reactivate an existing client.
4. Open Product access, choose the client and product, grant or revoke access.
5. Open Reports and Audit logs to examine transaction history.

## Client workflow

1. Sign in as Client and open Catalog. Only active granted products are shown.
2. Choose Issue card. Supply a unique Idempotency-Key, select a product, optionally enable PIN, and issue it.
3. Submit the identical request with the same key. Observe HTTP 200 and the same card ID. New issuance is HTTP 201.
4. Change payload but reuse the same key. Observe HTTP 409.
5. Open My cards and cancel an issued card. Verify the cancellation in personal spending.
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
- Directory tables show at most 100 records per view, audit up to 50; the backend supports pagination.
- This review UI is not a production identity client. CSP hardening, rate limits, production token revocation and extensive accessibility testing are separate concerns.

## Validation

    bundle exec rspec
    bin/rubocop
    bin/brakeman --no-pager
    node --check public/demo/app.js

The Rails HTTP smoke tests for the interface live in spec/requests/demo_ui_spec.rb. Manual/browser verification is useful in addition to, not instead of, the complete RSpec suite.
