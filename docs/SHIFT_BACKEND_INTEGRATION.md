# Shift backend integration

The Shift module's production registration now uses `ShiftRepository` and
Laravel, rather than the UI-only mock source.

- `GET /api/v1/shifts/current/snapshot` supplies the shared overview and
  closing-wizard snapshot.
- `GET /api/v1/shifts/history` and `GET /api/v1/shifts/{shiftNumber}/report`
  serve server-derived history and sealed reports.
- Opening allocates a tenant-unique `SH-YYYYMMDD-NNN` number. Closing seals a
  `RPT-...` report and requires a reason for material cash differences.
- Expected cash now includes `shift_cash_movements`: deposits add while
  withdrawals and expenses subtract.
- Required bar checks are posted as part of the close transaction; no client
  side result is authoritative.

The legacy mock repository remains as a test fixture only until widget tests
are migrated to API fakes. Native print/export is not included in this scope.
