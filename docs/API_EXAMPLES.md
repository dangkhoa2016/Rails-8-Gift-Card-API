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

curl -sS -X POST http://localhost:3000/api/v1/client/cards \
  -H "Authorization: Bearer $CLIENT_TOKEN" \
  -H 'Idempotency-Key: order-example-001' \
  -H 'Content-Type: application/json' \
  -d '{"product_id":PRODUCT_ID,"with_pin":true}'

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
```

These date ranges use UTC and include `from` but exclude `to`. JSON money values are decimal strings. Each report is grouped by currency.
