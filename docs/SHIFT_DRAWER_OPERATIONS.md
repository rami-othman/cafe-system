# Shift / Cash Drawer Operations Runbook (A2)

Operational procedures for the shift / cash-drawer lifecycle. All commands run
from `backend/` (locally: `docker exec cafe-system-backend-1 php artisan ...`).
Every mutating command is **dry-run by default** and needs an explicit
`--apply`. Always run the dry run first, read its output, then apply.

> Never run these against staging/production without an approved change
> window, a fresh database backup, and the target identity verified
> (`php artisan migrate:status --env=<env>` shows the expected database).

## Invariants to remember

- One physical drawer = one open shift: at most one live `shifts` row with
  `status = 'open'` per `tenant_id + financial_location_id`. The PostgreSQL
  partial unique index `shifts_one_open_per_location` enforces it.
- Opening cash must equal the drawer's posted, location-specific ledger
  balance. Fund the drawer with a safe-to-drawer cash transfer before opening.
- A shift snapshots `financial_location_id`, `close_destination_financial_location_id`
  and `closing_float_amount` when it opens. Later branch edits never change an
  open shift.
- Closing moves `counted - closing float` from the drawer to the close
  destination as one cash transfer (idempotency key `shift-close-transfer:{shiftId}`).

## 1. Detect overlapping open shifts

```bash
php artisan shifts:detect-overlaps            # all tenants
php artisan shifts:detect-overlaps --tenant=7 # one tenant
```

Read-only. Exit code 0 = none found, 1 = overlaps listed (tenant, drawer
location id, count, shift ids). Equivalent SQL:

```sql
SELECT tenant_id, financial_location_id, COUNT(*), array_agg(id ORDER BY id)
FROM shifts
WHERE status = 'open' AND deleted_at IS NULL AND financial_location_id IS NOT NULL
GROUP BY tenant_id, financial_location_id
HAVING COUNT(*) > 1;
```

If migration `2026_09_29_000001_one_open_shift_per_cash_drawer` fails with
"Overlapping open shifts exist", this is the list to reconcile first.

## 2. Dry-run the reconciliation

```bash
php artisan shifts:reconcile-overlap {tenantId} {financialLocationId}
php artisan shifts:reconcile-overlap 7 42 --confirmed-cash=1250.00
```

The dry run locks nothing permanently and writes nothing. It prints the drawer,
the **posted drawer ledger balance**, every overlapping shift (opening cash,
orders by status, completed payments), active orders, and any blockers.

Physically count the drawer. `--confirmed-cash` must equal the printed ledger
balance **exactly**. If it does not, stop: investigate unposted/missing cash
movements through normal finance workflows. The command never fabricates a
difference.

## 3. Active-order blocking behaviour

Reconciliation refuses (`ACTIVE_ORDERS`) while any non-deleted order linked to
the overlapping shifts is not terminal (terminal = `paid`, `cancelled`,
`refunded`). Draft/held/other active orders are listed with their ids and
numbers. Resolve them through the normal POS workflow (pay, or cancel if never
paid) by the responsible cashier. The command never cancels, pays, or
reassigns orders, and never moves payments between shifts.

## 4. Apply the reconciliation

```bash
php artisan shifts:reconcile-overlap 7 42 \
  --confirmed-cash=1250.00 \
  --reason="Historical overlap on Downtown drawer, counted by manager" \
  --actor=15 \
  --apply
```

`--reason` and `--actor` (a user id of the same tenant) are required. In one
transaction it:

1. locks the drawer location row and all overlapping open shifts;
2. re-verifies >= 2 overlapping shifts, ledger == confirmed cash, no active orders;
3. closes every overlapping shift at the same timestamp with
   `close_type = 'legacy_reconcile'`, `closing_cash = NULL`,
   `close_transfer_id = NULL`, `cash_difference` unchanged (0), and appends a
   `[legacy_reconcile <timestamp>] ...` note;
4. creates **no** cash transfer and touches **no** order, payment, journal,
   stock movement or voucher — all cash stays in the drawer;
5. writes `activity_logs` rows: one `shift.legacy_overlap_reconciled`
   (entity `financial_location`, with tenant, branch, drawer, affected shift
   ids, original shift rows, ledger balance, confirmed cash, reason, actor,
   timestamp) and one `shift.legacy_reconciled` per shift.

Verify afterwards: `php artisan shifts:detect-overlaps --tenant=7` reports none.

## 5. Configure the branch close destination

Cafe Configuration → Branch → shift close settings (API:
`PUT /api/v1/cafe-configuration/branches/{id}` with
`shiftCloseDestinationFinancialLocationId`, `shiftClosingFloatAmount`,
optional `shiftCloseTime`). Rules (single source: `ShiftDrawerReadinessService`):

- POS drawer: active, `kind=cash`, `type=cash_drawer`, same tenant and branch;
- close destination: active cash location of the same tenant, global or of
  the same branch, and not the POS drawer;
- closing float >= 0.

New branches/tenants are provisioned with the tenant's global `MAIN-SAFE` as
the default destination when none is set. Check readiness any time:
`GET /api/v1/shifts/readiness?branchId={id}` (also `shiftDrawerReadiness` in
the branch payload). A branch without a valid destination cannot open shifts.

## 6. Adopt configuration for a legacy single open shift

An open shift opened before the branch had a destination has
`close_destination_financial_location_id = NULL` and cannot close. After
configuring the branch (step 5):

```bash
php artisan shifts:adopt-close-config {tenantId} {shiftId}             # dry run
php artisan shifts:adopt-close-config 7 311 --reason="Branch configured after open" --actor=15 --apply
```

It locks the shift, requires it to be open with no destination snapshot and no
other open shift on its drawer, validates the branch's current destination and
float against the shift's own drawer, then copies only those two values onto
the shift. No financial entry is created; an `activity_logs`
`shift.close_configuration_adopted` row records before/after. An existing
snapshot is never overwritten (`ALREADY_CONFIGURED`).

## 7. Open the clean shift

After reconciliation the drawer's full posted ledger balance is the new
custody. The cashier opens a shift through the normal app/API with
`openingCash` equal to that balance (the readiness endpoint returns it as
`drawer.ledgerBalance`). Do not try to split historical shared cash between
the old shifts.

## 8. Verify the unique index

```sql
SELECT indexname, indexdef FROM pg_indexes WHERE indexname = 'shifts_one_open_per_location';
```

Expected: `CREATE UNIQUE INDEX shifts_one_open_per_location ON public.shifts
USING btree (tenant_id, financial_location_id) WHERE (((status)::text = 'open'::text)
AND (deleted_at IS NULL) AND (financial_location_id IS NOT NULL))`. If missing
because the migration was blocked by overlaps, reconcile (steps 1–4) and then
run `php artisan migrate --force` (the migration refuses to run while overlaps exist).

## 9. Rollback / safety notes

- Dry runs are read-only. Applies are single transactions; any refusal or error
  rolls back completely.
- A reconciliation is an administrative status change only. To undo it on a
  non-production copy, restore from backup; do **not** hand-edit shifts back to
  `open` in production (it would re-create an overlap and violate the index).
- Adoption only fills two NULL snapshot columns; it is reversible by setting
  them back to NULL while the shift is still open (audit row keeps the
  before-state).
- Closed-shift transfers cannot be reversed directly (existing guard); use an
  approved correction procedure.
- Code rollback: reverting the A2 code does not require a schema rollback — no
  migration was added by A2 final; `legacy_reconcile` rows remain valid closed
  shifts (the column is `varchar(20)`).
