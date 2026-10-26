# API Examples

Run the Rails server locally. First seed a development Admin and Client as described in the README, then log in as each role and copy the returned bearer tokens into `ADMIN_TOKEN` and `CLIENT_TOKEN`.

## Login

```bash
curl -sS -X POST http://localhost:3000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@example.test","password":"YOUR_DEMO_ADMIN_PASSWORD"}'
```

## Admin: create a brand, product, client and grant

```bash
curl -sS -X POST http://localhost:3000/api/v1/admin/brands \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Example Brand","state":"active","custom_fields":{"region":"EU"}}'

curl -sS -X POST http://localhost:3000/api/v1/admin/brands/BRAND_ID/products \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"USD 100 Gift","face_value":"100.00","currency":"USD"}'

curl -sS -X POST http://localhost:3000/api/v1/admin/clients \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"email":"new-client@example.test","password":"A_STRONG_DEMO_PASSWORD","payout_rate":"90.0000"}'

curl -sS -X POST http://localhost:3000/api/v1/admin/clients/CLIENT_ID/product_accesses \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"product_id":PRODUCT_ID}'
```

Replace IDs with the values returned by preceding calls.

## Client: catalog, issue, exact retry and cancel

```bash
curl -sS http://localhost:3000/api/v1/client/catalog \
  -H "Authorization: Bearer $CLIENT_TOKEN"

# Optional filters can be combined: q matches product or brand name
# case-insensitively; brand_id selects one brand; currency is a 3-letter code.
curl -sS -G http://localhost:3000/api/v1/client/catalog \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  --data-urlencode 'q=gift' \
  --data-urlencode 'brand_id=BRAND_ID' \
  --data-urlencode 'currency=USD'

curl -sS -X POST http://localhost:3000/api/v1/client/cards \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -H 'Idempotency-Key: order-example-001' \
  -H 'Content-Type: application/json' \
  -d '{"product_id":PRODUCT_ID,"with_pin":true}'

# Filter My cards by PIN presence (without returning the PIN itself).
# has_pin=true: PIN exists; has_pin=false: no PIN; omit for all cards.
# Filters combine with status and are applied before pagination.
curl -sS -G http://localhost:3000/api/v1/client/cards \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  --data-urlencode 'has_pin=true' \
  --data-urlencode 'status=issued' \
  --data-urlencode 'per_page=25'

# Repeat the same issue request with the same Idempotency-Key and JSON.
# Expect HTTP 200 and the SAME card ID, not a new card.

curl -sS -X POST http://localhost:3000/api/v1/client/cards/CARD_ID/cancel \
  -H "Authorization: Bearer $CLIENT_TOKEN"
```

A repeated cancellation returns HTTP 409, and a card ID belonging to another client returns HTTP 404.

## Reports and audit

```bash
curl -sS "http://localhost:3000/api/v1/admin/reports/by_brand?from=2026-10-01&to=2026-11-01" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

curl -sS "http://localhost:3000/api/v1/admin/reports/by_client?from=2026-10-01&to=2026-11-01" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

curl -sS "http://localhost:3000/api/v1/client/reports/spending?from=2026-10-01&to=2026-11-01" \
  -H "Authorization: Bearer $CLIENT_TOKEN"

curl -sS "http://localhost:3000/api/v1/admin/audit_logs?action=card.issued&record_type=Card&page=1&per_page=25" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# Combined Audit filters: success/refused and a UTC day range (to is EXCLUSIVE).
# This example covers all of October 20 and October 21, 2026.
curl -sS -G http://localhost:3000/api/v1/admin/audit_logs \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data-urlencode 'outcome=refused' \
  --data-urlencode 'from=2026-10-20' \
  --data-urlencode 'to=2026-10-22' \
  --data-urlencode 'per_page=50'

# To include the UTC second 10:15:30 and all its fractional timestamps,
# pass an exclusive upper bound of 10:15:31. UI accepts HH:MM:SS,
# interprets the value as UTC, and performs this one-second conversion.
curl -sS -G http://localhost:3000/api/v1/admin/audit_logs \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --data-urlencode 'from=2026-10-20T10:15:30Z' \
  --data-urlencode 'to=2026-10-20T10:15:31Z'
```

These date ranges use UTC and include `from` but exclude `to`. JSON money values are decimal strings. Each report is grouped by currency.

### Client: Reveal an owned Card PIN with password confirmation

```bash
# Password must be the currently signed-in Client's password, not an Admin password.
# Supply this through a protected interactive environment, not a shell history entry.
curl -sS -X POST http://localhost:3000/api/v1/client/cards/CARD_ID/reveal_pin \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary @- <<'JSON'
{"password":"<CLIENT_PASSWORD>"}
JSON
```

The example password is only a placeholder. The endpoint returns a PIN only after ownership and fresh password verification; it sets a `no-store` response, audits the attempt without sensitive values, and throttles repeated incorrect passwords. Do not save the real password or returned PIN in shell history, logs, screenshots, or public documentation.

### Safe API error response (mistyped endpoint)

```bash
curl -i http://localhost:3000/api/v1/client/catalog7 -H 'Accept: application/json'
```

Returns HTTP **404**, `error.code = "route_not_found"`, a human-readable error message and `request_id`. No Rails framework traces are returned by default. For trusted local debugging only, set `WOGI_SHOW_EXCEPTION_DETAILS=true` **before starting Rails** to add `error.details` containing exception class, a filtered message and up to 15 backtrace entries; production always ignores this flag. The Demo's **View error details** modal shows the returned JSON, not server log files.
