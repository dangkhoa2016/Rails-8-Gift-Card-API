# Design Decisions and Trade-offs

This document distinguishes clarified business rules from implementation choices.

## Business rules clarified by WOGI

- The application generates activation numbers and optional PINs; no external provider integration is necessary.
- Safe retries accept either a unique reference number or an `Idempotency-Key` header.
- Payout is the gift card face value multiplied by the client payout rate.
- The payout rate at issuance must be preserved on the card for historical correctness.
- Cancelled cards do not receive effective payout, and cancellations appear in reports.
- Products with issued cards cannot be physically removed.
- Existing cards remain cancellable after the related product or brand is deactivated.

## Implementation choices

| Topic | Decision | Reason |
|---|---|---|
| Idempotency interface | Mandatory `Idempotency-Key` on issue | Explicit replay contract independent of client body |
| Key scope and retention | Unique per client indefinitely while card history is retained | Avoid accidental second issuance on late retries |
| Replay | Matching fingerprint gives HTTP 200 with the original card | Preserve original issuance |
| Key collision | Same key with different product/PIN choice yields HTTP 409 | Prevent ambiguous requests |
| Concurrency | PostgreSQL advisory transaction lock and unique indexes | Prevent duplicate issuance under real parallel requests |
| Financial representation | PostgreSQL numeric, `BigDecimal`, two fractional digits, `ROUND_HALF_UP` | Avoid floating-point drift |
| Rate scale | Percentage 0–100 with four decimal places | Documented precision choice |
| Currency | Three uppercase characters; group reports per currency | Avoid adding unlike currencies without FX information |
| Financial snapshots | Copy face value and currency in addition to confirmed rate | Product modifications do not rewrite history |
| Product deletion | Always soft-delete, force inactive | Uniform handling without breaking foreign keys |
| Optional PIN | Six cryptographically random digits when `with_pin=true` | Internal issuance; encrypted at rest |
| PIN visibility | Returned to owner on new issue and exact replay; never on list/show/report/audit | Safe response minimization |
| Report period | Half-open UTC `[from,to)` by issuance/cancellation event | Period activity is reproducible when cancellations happen later |
| Cancellation in reports | Subtract face value/payout on cancellation date | No effective payout for cancelled cards |
| API format | Consistent JSON envelopes, not strict official JSON:API | Requirements did not demand full JSON:API |
| Logout | Audited but no server-side JWT denylist | Revocation was optional; behavior explicitly disclosed |
| Reviewer execution | Local setup, seeds, curl examples, RSpec | Reproducible without a notebook or tunnel |

## Important interpretation of payout

`issued_payout` is the amount accrued when cards are issued. `cancelled_payout` is the amount reversed by cancellations in the selected period. `net_payout_activity = issued_payout - cancelled_payout` can be negative for a cancellation-only period. It is **not** a current outstanding/as-of balance; the latter would require a separate point-in-time query.

## Deliberate exclusions

There is no external card provider, frontend admin application, JWT denylist, FX conversion service, or hosted demo requirement. These choices keep the take-home focused on correctness, authorization, auditability and reproducibility. For production, add rate limiting, operational monitoring, secret rotation and environment-specific infrastructure.
