# Phase 1: Financial and Inventory Foundation

## Existing relevant architecture

- The Laravel 13 API keeps tenant-scoped records in PostgreSQL and resolves the active tenant through `TenantContext`. Existing POS controllers use query-builder queries and return `{ "data": ... }` responses.
- Branch access is represented by `user_branches`; token middleware can attach an authenticated tenant and user to a request. Existing POS routes are intentionally left unchanged in this phase.
- `warehouses`, `inventory_items`, `stock_movements`, and `activity_logs` already exist. `inventory_items.current_stock` remains a compatibility snapshot only; new work will not use it as a balance source.
- Flutter Windows uses a feature-first structure, Cubit state, GetIt registrations, go_router routes, `DioApiClient`, and the shared desktop shell/design tokens. New screens must consume live Laravel API responses only.

## New and upgraded persistence

1. Upgrade `warehouses` safely with tenant-unique codes, normalized location types, notes, and optional creator/updater references. Existing `main` rows are mapped to `branch_main`; existing rows receive deterministic legacy codes.
2. Extend `activity_logs` with optional JSON before/after state so setup changes have a tenant- and branch-aware operational audit trail.
3. Add `financial_accounts` for a per-tenant chart of accounts with Arabic/English names, code, group, normal balance, active/system-protected flags, optional parent account, and audit references.
4. Add `journal_entries` and `journal_entry_lines`. Entries and lines are tenant-scoped; lines reference a tenant-owned account and use fixed decimal debit/credit amounts. Posting is a transactional state transition after a server-side equality check of debit and credit totals.

## Tenant isolation and access approach

- Every query and mutation begins with the tenant ID from `TenantContext`, and all route-parameter lookups include that tenant ID.
- Related branch, warehouse, account, and parent-account references are validated against the same tenant before writing.
- New setup routes use the existing token-authenticated actor when it is present. Actor IDs are stored on setup records/audit events where available; the pre-existing unauthenticated POS compatibility path remains unchanged.
- Branch-specific warehouse types require a branch in the same tenant. Central warehouses cannot be assigned to a branch.

## Warehouse and inventory model

- `central` is tenant-wide and has no branch.
- `branch_main`, `bar`, `kitchen`, and `other` belong to one tenant branch.
- Future balances will be derived from stock movements grouped by `inventory_item_id` and `warehouse_id`; this phase does not modify existing stock quantity behavior or create recipes/transfers.

## Financial and audit model

- Default accounts are resolved by tenant plus account code, never by database ID.
- A setup service creates idempotent chart-of-account rows for demo and newly onboarded tenants.
- Journal entries begin as `draft`; only a balanced draft can become `posted`. The API intentionally exposes no edit or delete route for posted entries. Future reversals will create new entries.
- Warehouse/account/journal setup actions write redacted before/after snapshots to `activity_logs` without passwords, tokens, or other sensitive values.

## API endpoints

- `GET|POST /api/v1/warehouses`
- `PATCH /api/v1/warehouses/{warehouse}`
- `PATCH /api/v1/warehouses/{warehouse}/status`
- `GET|POST /api/v1/finance/accounts`
- `PATCH /api/v1/finance/accounts/{account}`
- `PATCH /api/v1/finance/accounts/{account}/status`
- `GET|POST /api/v1/finance/journal-entries`
- `GET /api/v1/finance/journal-entries/{entry}`
- `POST /api/v1/finance/journal-entries/{entry}/post`
- `GET /api/v1/finance/setup-status`

Lists support stable sorting, bounded pagination, search, and feature-appropriate filters. Controllers delegate mutations to services and Form Requests validate input.

## Flutter Windows module

- Add one RTL sidebar destination: **تهيئة المالية والمخازن**.
- Add routes/screens for readiness dashboard, warehouses, chart of accounts, and journal entries.
- A feature-owned repository and Cubit load live setup status, branches, warehouses, accounts, and entries through `DioApiClient`.
- Screens use the existing shell, cards, dialogs, loading/empty/error states, and desktop layout. Create/edit forms call live endpoints; no mock setup data is introduced.

## Seed data

- Add deterministic, idempotent setup seeders for the Cafe 6:18 demo tenant.
- Seed a central warehouse plus main/bar/kitchen locations for each demo branch, the default chart of accounts, and balanced opening/setup journal entries.
- The onboarding action invokes the same setup service to give every newly created tenant the default chart and initial central/branch-main warehouse structure.

## Test plan

- Feature tests cover cross-tenant access denial, code uniqueness, warehouse branch/type rules, seeded account idempotency, journal posting validation, posted-entry immutability, and setup-status accuracy.
- Run Laravel feature tests for the new module plus the existing suite. Run Flutter analysis and feature tests when the Flutter SDK/toolchain is available.

## Intentionally deferred

- Purchase orders, suppliers, receiving, transfers, stock counts, recipes, production/consumption, and calculated inventory balances.
- Cash sessions, expenses, assets, depreciation, account reconciliation, financial statements, and final reports.
- Automatic POS/payment/refund journalization and reversal workflows.
- Role-management redesign and a full POS authentication/session flow; this phase only integrates with the existing actor context when available.
