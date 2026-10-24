# Gift Card API

A JSON API for a gift card platform, implemented in **Ruby 3.4.x**, **Rails 8.1.x (API mode)**, **PostgreSQL**, and **RSpec**. It supports **Admin** and **Client** users. No external gift card provider is required.

## Quick start

Install Ruby, PostgreSQL, and Bundler. Create a local PostgreSQL role that can create development/test databases (Rails uses the current OS user by default unless configured otherwise).

```bash
bundle install
bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
bin/rails server
```

The default endpoint is `http://localhost:3000`. The health endpoint is `GET /up`. For a repeatable **development-only** dataset, export strong demo passwords and run:

```bash
export DEMO_ADMIN_PASSWORD='REPLACE_WITH_LOCAL_DEVELOPMENT_PASSWORD'
export DEMO_CLIENT_PASSWORD='REPLACE_WITH_DIFFERENT_LOCAL_DEVELOPMENT_PASSWORD'
bin/rails db:seed
```

Do not use demo passwords in production. The seed script is idempotent, and does not print credentials. See `.env.example` for optional environment variables; it is an **example**, not an automatically loaded configuration file.

## API

All business endpoints are under `/api/v1`. Except for login, requests require `Authorization: Bearer <jwt>`. JWTs are signed using HS256, include `sub`, `role`, `iat` and `exp`, and expire after **one hour**. User activity and current role are rechecked against PostgreSQL for every authenticated request.

### Auth

| Method | Route | Notes |
|---|---|---|
| POST | `/api/v1/auth/login` | Public; email/password login |
| POST | `/api/v1/auth/logout` | Audits logout; does **not** revoke JWT on the server |

### Admin

| Method | Route | Notes |
|---|---|---|
| GET, POST | `/api/v1/admin/brands` | List/search or create brands |
| GET, PATCH | `/api/v1/admin/brands/:id` | View or update brand |
| GET, POST | `/api/v1/admin/brands/:brand_id/products` | List/create products for brand |
| GET, PATCH, DELETE | `/api/v1/admin/products/:id` | View/update/soft-delete product |
| GET, POST | `/api/v1/admin/clients` | List/create clients |
| GET, PATCH | `/api/v1/admin/clients/:id` | View/update client |
| GET, POST | `/api/v1/admin/clients/:client_id/product_accesses` | List/grant access |
| DELETE | `/api/v1/admin/clients/:client_id/product_accesses/:product_id` | Revoke access |
| GET | `/api/v1/admin/audit_logs` | Filtered, paginated audit events |
| GET | `/api/v1/admin/reports/by_brand` | Brand and currency summary |
| GET | `/api/v1/admin/reports/by_client` | Client and currency summary |

### Client

| Method | Route | Notes |
|---|---|---|
| GET | `/api/v1/client/catalog` | Active assigned products only |
| POST | `/api/v1/client/cards` | Issue card; `Idempotency-Key` header required |
| GET | `/api/v1/client/cards` | Own cards; optional status filter |
| GET | `/api/v1/client/cards/:id` | Own card; PIN excluded |
| POST | `/api/v1/client/cards/:id/cancel` | Cancel own issued card once |
| GET | `/api/v1/client/reports/spending` | Own issue/cancellation activity |

Request bodies are JSON objects; for example, `POST /api/v1/client/cards` accepts `{"product_id":123,"with_pin":true}`. Creation returns HTTP **201** and a PIN only if requested. Replaying the same key and canonical payload returns the original card with HTTP **200**; different payload using that key returns **409**. The key is unique per client for the life of the retained card history.

## Testing the API

```bash
# Login as a development user; copy data.access_token from the JSON response.
curl -sS -X POST http://localhost:3000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"client@example.test","password":"YOUR_DEMO_CLIENT_PASSWORD"}'

# Set CLIENT_TOKEN to the access token from that response.
curl -sS http://localhost:3000/api/v1/client/catalog \
  -H "Authorization: Bearer $CLIENT_TOKEN"

curl -sS -X POST http://localhost:3000/api/v1/client/cards \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -H 'Idempotency-Key: demo-order-001' \
  -H 'Content-Type: application/json' \
  -d '{"product_id":1,"with_pin":true}'
```

Repeat the last request with the same key to verify the card ID is unchanged. Replace product ID 1 with an ID actually granted to the client. See [API examples](docs/API_EXAMPLES.md) for Admin creation, grants, cancellation, reporting and audit queries.

## Semantics and security

- **Authorization:** Admin and Client APIs reject the wrong role with HTTP 403. Invalid/expired tokens and disabled accounts return 401. A different client's card ID returns 404.
- **Passwords and PINs:** passwords use bcrypt. PINs are generated with a cryptographically secure RNG and encrypted at rest using Active Record Encryption. PINs are absent from list/show, audit snapshots, and reports. Passwords, JWTs and sensitive request values are filtered from Rails parameter logs.
- **Issuer eligibility:** client account, brand, product, and product access must all be active/authorized. Soft-deleted products cannot be newly issued.
- **Idempotency and concurrency:** each `(client_id, idempotency_key)` pair has a unique PostgreSQL index. A transaction-scoped advisory lock serializes same-key requests. Activation numbers have a global unique index. Real separate-connection concurrency is exercised in RSpec.
- **Cancellation:** `issued -> cancelled` exactly once under a row lock; a cancelled card has no effective payout. Historical card values remain stored and unchanged. Cancellation remains allowed after product/brand deactivation, product soft-deletion or access revocation.
- **Financial snapshots:** card issuance copies face value, currency, payout percentage and payout amount. Payout is `face_value * payout_rate / 100`, calculated with `BigDecimal` and `ROUND_HALF_UP` to two decimal places.
- **Reports:** SQL aggregates by currency without implicit FX conversion. Time filters are half-open UTC `[from, to)`, with `YYYY-MM-DD` or offset-bearing ISO8601 datetimes. Issuance is counted at `issued_at` and cancellation at `cancelled_at`. The `net_payout_activity` field means payout issued minus payout reversed **during the selected period**, not the historical as-of balance.
- **Audit:** successful and refused issue/cancel, login success/failure/logout and Admin changes have audit records. Admin can filter by `actor_id`, `action`, `record_type`, `from`, `to` and paginate. Before/after content is allowlisted.
- **Response shape:** JSON `data` or `error` plus `meta` when relevant. This implementation does not claim strict official JSON:API compliance.

## Validation and maintenance

```bash
bundle exec rspec
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit check --update
bin/rails zeitwerk:check
```

See [Architecture](docs/ARCHITECTURE.md) and [Design Decisions](docs/DESIGN_DECISIONS.md). All seed/demo credentials must be development-only. Never commit Rails master keys, real tokens or external assignment communications.

## Known limitations

- Server-side JWT revocation/denylist is **not** implemented; logout is auditable but the bearer token remains valid until its existing expiration. The client should discard the token locally.
- Rate limiting and production deployment hardening are not implemented.
- A current outstanding/as-of payout view is not provided; reports expose event-time net activity.
- Currency is validated as three uppercase letters, but no live FX conversion or provider catalog is integrated.
- This API intentionally has no notebook or Cloudflare Tunnel deliverable.
