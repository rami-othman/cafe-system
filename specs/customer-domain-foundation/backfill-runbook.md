# Customer Foundation Backfill Runbook

This runbook is the conditional production procedure for a customer table whose
row count cannot be completed safely inside the deployment window. It does not
assert a production row count or measured timing.

1. Run the expansion migration and deploy the dual-read application version.
2. Record the tenant/customer row counts and confirm the dedicated PostgreSQL
   database, `pg_trgm`, and required indexes before writing data.
3. Process tenants in ascending ID order and customers in ascending ID order in
   bounded batches. Each batch is transactional and may be retried safely.
4. Assign missing customer numbers, normalized names, and legacy primary phones
   through the same production normalizers. Do not rewrite non-null legacy phone
   values or delete rows to satisfy an invariant.
5. Reconcile after every batch: no duplicate tenant/customer numbers, no missing
   normalized names, no more than one primary phone, and counter high-water marks
   at least the maximum assigned sequence plus one.
6. Enable the new admin and quick-create routes only after the reconciliation is
   complete. Run the constraint migration as a forward-only roll-forward step.
7. If a batch fails, roll back that batch, retain the expansion schema and legacy
   reader, correct the reported invariant, and resume from the last reconciled
   cursor. Never use `migrate:fresh`, `db:wipe`, or destructive reseeding.
