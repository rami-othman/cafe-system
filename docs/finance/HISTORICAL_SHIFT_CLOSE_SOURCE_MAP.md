# Historical shift close: source contract

Implementation date: 2026-09-27.

The closing period starts at the original shift opening and ends **exclusively** at the following local midnight, converted from the branch timezone to UTC. This is a period close, not a filter that discards earlier days in a multi-day shift. Calendar dates come from the server, including date-picker bounds.

## Attribution and accounting

| Source | Event used for the boundary | Cash calculation | Reassignment |
| --- | --- | --- | --- |
| Orders | `closed_at`; legacy fallback completed receipt time, then opening time | Sales summaries only; receipts determine cash | Later completed orders and all currently draft/held orders move to the continuation |
| Payments | `paid_at`, fallback `created_at` | Completed, nondeleted, resolved cash method only | Later payments move without reposting |
| Payment refunds | `refunded_at`, fallback `created_at` | Completed refunds of resolved cash payments | Later refunds move; links to original payment/order remain |
| Customer payments/refunds | `created_at` at the settlement transaction | Posted settlements on the physical drawer | Later settlements move; allocations and journals are preserved |
| Expenses | Referenced journal `posted_at`, fallback journal/expense creation | Paid, nondeleted expenses on the physical drawer | Later paid expenses move; date-only `paid_at` and metadata edits do not govern attribution |
| Shift cash movements | `created_at` | Deposits add; withdrawals and expenses subtract | Later movements move without financial reposting |
| Supplier payments | `created_at` at posting | Their linked shift cash movement is the single cash effect | Later payment, voucher and movement associations move; journal remains unchanged |
| Finance vouchers | `posted_at`, fallback `created_at` for drafts | Their linked shift movement is the single cash effect | Later vouchers move; reversal movement remains an independently timed event |
| Cash transfers | `created_at` at execution | Existing unrelated transfers must reconcile via the ledger; new historical close transfer is explicitly allocated | Execution transfer belongs to the continuation and is referenced by the old close |
| Stock counts | Posting/creation time for existing counts | Inventory only | Existing later counts move; a newly prepared historical count is retained by its explicit period boundary |
| Stock movements | `occurred_at`, fallback `created_at` | Inventory quantities use base units and integer precision | No stock movement is replayed or reassigned; references remain intact |
| Journal entries | `posted_at`, fallback `created_at` | Posted location-specific lines reconstruct cash before the instant | Existing entries/lines are never rewritten |

`updated_at` is not an economic event time. It is only useful in stale-input detection and identifying unsupported reversed settlement histories.

## Physical transfer and continuation opening

The historical report closes at the selected day. Its execution time is stored separately. An actual cash transfer executed today uses today's **branch-local** date. The continuation opens temporally at the boundary with the boundary cash balance; its movements include later receipts/refunds and the actual close transfer once. `close_transfer_id` of the old shift links to that transfer even though the transfer's operational `shift_id` is the continuation.

Example: boundary cash 500, later net receipts 80, float 100. Transfer 400 now leaves 180. Continuation: opening 500 + later 80 − transfer 400 = 180. No duplicate posting of the transferred operational records occurs.

If no later records and no transfer require a continuation, the old shift closes without creating one. A transfer executed after a historical boundary requires a continuation to record its physical effect. The existing one-open-shift-per-drawer constraint remains enforced throughout the committed result.

## Counts and historical evidence

Both cash and bar counts explicitly choose `period_recorded` or `current`. Current counts subtract the net later movements to derive the historical count. This is labelled as reconstruction, not a physical count actually performed in the past.

The inventory ledger must reconcile exactly to current stock before reconstruction. Historical theoretical stock is current stock minus later net movements. Count-unit conversion is resolved through the existing unit service; amounts and stock variances use the existing posting services. Any approved historical discrepancy changes current stock once, at actual execution time. Displayed variance valuation uses current cost and is explicitly approximate; old stock costs are not rewritten.

The immutable close snapshot records the historical quantities/counts, count provenance, period, execution time and continuation ID. Both the report and shift history read that saved outcome. Current source order changes cannot change the saved report.

## Explicit unsupported/ambiguous cases

The preview blocks the following instead of fabricating historical data:

- Stock balances that do not reconcile to the stock movement ledger.
- A later stock-count adjustment affecting an item being counted; its timing could conceal an earlier discrepancy.
- Earlier customer settlements or expenses reversed/cancelled after the boundary.
- A legacy order with an earlier receipt but completion after the boundary; the current POS uses a single completed settlement, so this needs a separate partial-receipt allocation contract.
- Multiple mandatory bar templates, because the current closing wizard exposes one bar template; a future per-bar input contract is needed.
- Cash summary/ledger disagreement, unavailable close configuration, or insufficient current cash to execute the transfer.

These restrictions do not disable ordinary shift close. Existing post-close cash refund authorization remains unchanged; historical splitting does not introduce a new payout policy.

## Atomicity, concurrency and retry

Historical splitting changes operational rows, so PostgreSQL transaction-scoped `SHARE ROW EXCLUSIVE` table locks drain operational writers before the shift row is locked. This prevents the old writer domain-row → shift-row order from conflicting with a shift-first reassignment. This barrier is broader than drawer-only locking and briefly blocks writes to the listed tables across tenants; ordinary closing is unchanged. It is a deliberate correctness-first tradeoff for the rare recovery operation, with a five-second lock timeout and friendly 409 retry response. Transaction retries handle deadlocks.

The preview SHA-256 version includes source rows, shift/drawer/destination data, computed preview, relevant journal lines and headers, and warehouse stock movement rows. A close recomputes it under the barrier. Changed inputs require review. Identical committed close requests return the existing result; changed dates/counts/reasons/notes are rejected. Reassignment audit rows record source table/id and old/new shift IDs.

The PostgreSQL concurrency tests run independent PHP workers in the isolated migrations test database, never the operational database.
