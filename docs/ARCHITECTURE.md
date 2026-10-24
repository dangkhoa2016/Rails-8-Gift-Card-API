# Architecture

## Overview

The service is a Rails 8.1 API-only application backed by PostgreSQL. It separates HTTP authentication/authorization, domain services, Active Record models, immutable snapshots, SQL reporting and append-only audit history. There are no third-party gift card provider calls.

## Layers

- `app/controllers/api/v1`: route contracts, JWT checks, role checks, strong parameters, serializations and HTTP status/error envelopes.
- `app/models`: six core entities, model-level validations, relational associations, enumerated states and optional encrypted card PIN.
- `app/services/auth`: HS256 JWT issuance and validation (3,600-second TTL).
- `app/services/cards`: transactional issuance and cancellation.
- `app/services/audit`: central allowlist sanitization for before/after snapshots.
- `app/services/reports`: UTC date parsing and parameter-bound SQL event ledger.
- `db/migrate`: database-enforced foreign keys, uniqueness indexes, CHECK constraints and precise numeric columns.
- `spec`: model, request and separate-database-connection concurrency tests.

## Data relationships

- `User` has role `admin` or `client` and bcrypt password digest; active clients require payout percentage.
- `Brand` owns `Product`. Both can be active/inactive, and Product can be soft-deleted with `deleted_at`.
- `ProductAccess` grants a client access to a product; a composite unique index prevents duplicate grants.
- `Card` belongs to client and product. Historical face value, currency and payout rate/amount are copied into card snapshots at issuance. PIN is stored encrypted, not as plaintext.
- `AuditEvent` stores actor, action, outcome, record identifiers, safe before/after, request IP/user agent and event timestamp.

## Card issuance consistency

1. Authenticate the JWT and fetch the current active client from PostgreSQL.
2. Require a client-scoped `Idempotency-Key`; canonicalize product ID and `with_pin`; hash the canonical payload.
3. Inside a PostgreSQL transaction, obtain a transaction-scoped advisory lock derived from client ID and key.
4. Lookup an existing card **before** testing current catalog eligibility; return it if the fingerprint matches, or return 409 on mismatch.
5. For a fresh key, verify active brand/product and the client's product grant; generate activation number/PIN with SecureRandom.
6. Snapshot the financial values, insert the card and successful audit event together.
7. Database indexes independently enforce uniqueness of activation number and client/key, including under concurrent requests.
8. Rejected operations persist a separately committed, sanitized refusal audit event.

An existing card can be replayed after its product becomes inactive; no second card is generated.

## Cancellation consistency

Fetch a card only from `current_user.cards`, then lock its row. The only allowed transition is `issued -> cancelled`. The card and success audit are committed atomically; failed or repeated cancellations have independent refusal audit events. No current product/brand/grant status check is made while cancelling a card already owned by the client.

## Reporting

The report service constructs an event ledger with one issuance row per card and one cancellation row per cancelled card (`UNION ALL`). Aggregates run inside PostgreSQL using constant SQL and bind parameters. The service groups by brand, client or just currency for the authenticated client.

A half-open UTC period `[from,to)` counts issuance and cancellation at their respective event timestamps. This supports stable historical period activity. For example, a cancellation in a later month reverses payout activity in that later month rather than rewriting the earlier month's issuance event.

## Security boundaries

- JWT signature/expiration are verified with an explicitly selected HS256 algorithm.
- The authenticated user and role are reloaded from PostgreSQL each request; deactivated accounts cannot continue using older valid JWTs.
- Client resources are scoped to the authenticated owner's database relations, including card lookup and reports.
- PIN, password, digest, and token fields are excluded from serialized responses and audit data; PIN may be returned only to the authenticated issuing client on a new issue or exact replay.
- JSON request validation, pagination bounds and SQL bind parameters prevent unsafe use of client-supplied values.

## Deployment

A reviewer can run the service locally using Ruby, PostgreSQL, and the README instructions. Source files and automated tests are sufficient; no hosted runtime, Jupyter notebook, or public tunnel is required.
