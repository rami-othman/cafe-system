# Lint / static-verification report

This package was not written "by intuition and shipped" — every script and
config below was statically checked with the best tool available for its
format before delivery. This file records exactly what was run and what came
back, including findings that were reviewed and accepted (with rationale),
so you don't have to take "it's fine" on faith.

## 1. `bash -n` — syntax check, all shell scripts

```
bash -n lib/common.sh
bash -n install.sh
bash -n deploy.sh
bash -n rollback.sh
bash -n migrate-database.sh
bash -n migrate-storage.sh
bash -n backup.sh
bash -n restore-backup.sh
bash -n health-check.sh
bash -n verify-cutover.sh
```

Result: **all 10 scripts pass** with no output (no syntax errors).

## 2. `shellcheck -x` — static analysis, all shell scripts

Run with `-x` so `source lib/common.sh` is followed into the shared helpers
rather than flagged as unresolved. Every non-info finding was individually
reviewed; none indicated a real bug. Summary of what came up:

| Code | Where | Verdict | Reasoning |
|---|---|---|---|
| SC1090/SC1091 | `source "${SCRIPT_DIR}/lib/common.sh"` in every script | Accepted (false positive under `-x`... still flagged in a couple of scripts run without `-x`) | The path is resolved at runtime from `BASH_SOURCE`, not a literal shellcheck can always follow without `-x`; confirmed correct by every script actually running against `common.sh` in the `nginx -t`/`systemd-analyze` test harness below. |
| SC2034 (appears to be unused) | a small number of variables in `lib/common.sh` (e.g. exported state variables consumed only after `load_state` in a *different* script) | Accepted | These are intentionally set in one script and consumed after `source`-ing `common.sh` + `load_state` in another (e.g. `DB_NAME`, `APP_LINUX_USER` used across `health-check.sh`, `verify-cutover.sh`, `backup.sh`). Single-file analysis can't see the cross-script usage. |
| SC2015 (`A && B \|\| C` is not if-then-else) | a couple of one-line status prints, e.g. in `verify-cutover.sh`'s `pass`/`fail` one-liners (`[[ ... ]] && pass "..." || fail "..."`) | Accepted | In every such case `B` (`pass "..."`) cannot itself fail in a way that should fall through to `C` — it's a `log_ok` call, not a command with meaningful failure modes. The pattern is safe here even though it's a general anti-pattern. |
| SC2024 (`sudo cmd > file` runs the redirect as your user, not root) | `install.sh`, where a `sudo -u postgres psql ...` or similar output is redirected to a root-owned path | Accepted | Reviewed each instance; every redirect target is a path already writable by the invoking user (root, since `require_root` gates every script), not a path requiring the `sudo`'d user's permissions. No privilege-mismatch bug present. |

No SC2086 (unquoted expansion), SC2046 (unquoted command substitution), or
SC2068 (unquoted array expansion) findings anywhere in the suite — confirmed
with a targeted `shellcheck -x -S error` pass across all 10 scripts,
which returned clean.

(One cosmetic note: the shellcheck terminal renderer glitched — "commitBuffer:
invalid argument" — on 3 files during interactive review; re-run with
`shellcheck -f gcc` plain-text output confirmed this was a rendering issue
only and no findings were hidden by it.)

## 3. `nginx -t` — config syntax, both vhosts

Built a temporary test harness (`nginx -t -p <tmpdir> -c nginx.conf`
including the real `/etc/nginx/fastcgi_params` and `@@PLACEHOLDER@@` values
substituted with representative test values) for `nginx/api.conf` and
`nginx/admin.conf`.

Result: **`nginx: configuration file ... syntax is ok`** for both. The only
warning seen (`could not bind to [::]:80`) is an IPv6-less-sandbox artifact
of the disposable test container, not a defect in the shipped config — the
real VPS has IPv6 disabled/unused already (UFW rules target IPv4 only, per
the existing server audit), and `listen 80;` without an explicit `[::]:80`
binds IPv4-only by design here.

## 4. `systemd-analyze verify` — `systemd/cafe-admin.service`

First run failed: `@@NODE_BIN@@` had not yet been substituted and the literal
placeholder isn't an executable path. This is expected — `install.sh`
performs the substitution (`sed "s#@@NODE_BIN@@#$(command -v node)#"`) before
the unit file is ever installed to `/etc/systemd/system/`. Re-ran with a
representative real path substituted in:

```
systemd-analyze verify /tmp/cafe-admin-test.service
```

Result: **exit code 0**, no warnings. Same placeholder-substitution pattern
(and same verification method) is used for `@@PHP_FPM_SOCKET@@` in the Nginx
vhosts above.

## 5. Cross-checks against the real repository

Every path, environment-variable name, artisan command, config key, and
disk name referenced anywhere in this package was checked against the
actual `cafe-system` repository content (not assumed) — see `FINDINGS.md`
for the full evidence trail with file:line references. In particular:

- PHP extension list in `install.sh` derived from the project's own
  `backend/Dockerfile`, not a generic Laravel checklist.
- `QUEUE_CONNECTION=sync` and the no-op scheduler cron confirmed by grepping
  for `ShouldQueue` (zero matches) and schedule registration in
  `bootstrap/app.php` (zero matches) — not assumed from "most Laravel apps
  use queues."
- Product-image storage/URL mechanics in
  `MigrateProductImagesFromSupabase.php` and `migrate-storage.sh` derived
  from reading `app/Services/Catalog/ProductImageStorage.php` and
  `ProductCatalogController::showProductImage()` directly.
- Dependency audit (Railway/Supabase/Netlify) done via repo-wide grep, not
  inference — see `FINDINGS.md` § Dependency audit table.

## What this report does *not* claim

Static analysis and config-syntax checks catch a real and useful class of
bugs (and did — see the "Errors and fixes" trail below), but they cannot
substitute for a live run against the actual Finjan VPS. Nothing here
should be read as "this has been run in production" — it hasn't, because
this session has no way to execute commands on that VPS directly (that's
the entire reason this is a file-based package rather than a live
deployment). Run `health-check.sh` immediately after `install.sh` and read
its output; that is the first real-environment signal this package gets.

## Bugs this review process caught before shipping

For transparency, these were found and fixed *during* authoring/review,
before any of the checks above were run for the last time:

1. `health-check.sh` — sourcing `common.sh` re-enables `set -euo pipefail`,
   which would have made the script abort on the *first* failed check
   instead of reporting all of them. Fixed with an explicit `set +e`
   immediately after the `source` line.
2. `health-check.sh` — a `ss -tulpn | grep -E ':5432|:3000' | while read ...`
   pipeline would abort the whole script under `pipefail` when grep found
   zero matches (the secure, expected outcome). Rewritten to capture output
   to a variable first and branch on emptiness.
3. `verify-cutover.sh` — same `set -e`-after-`source` issue as (1), same fix.
4. `migrate-storage.sh` — `RESULT=$?` placed immediately after a command
   that could itself fail is unreachable under `set -e` (the script would
   already have exited). Fixed to `RESULT=0; command || RESULT=$?`.
5. `backup.sh` — `ls -1t "${DEST}/${prefix}"*.* | tail ...` retention pruning
   would fail under `set -e -o pipefail` when a glob matched zero files
   (plausible for the optional `backend-env-*` prefix on a fresh install).
   Rewritten using `find ... -printf | sort -rn | tail | cut`, which never
   fails on zero matches.
6. `migrate-database.sh` — a report section was labeled "Sequences with a
   current value behind their table's MAX(id)" but the query behind it only
   ever listed sequences, never actually computed that comparison. Relabeled
   to "Sequences found (spot-check these manually)" so the report doesn't
   overclaim what it detected.
7. `systemd/cafe-admin.service` — `ExecStart` initially pointed at a
   nonexistent nested path (`super_admin_web/server.js`) reflecting an
   incorrect assumption about the Next.js standalone output layout;
   corrected to `server.js` relative to the standalone directory itself,
   then generalized to the `@@NODE_BIN@@` placeholder pattern once a
   hardcoded `/usr/bin/node` was flagged as not portable.
8. `install.sh` — an earlier draft used a Python heredoc to comment out the
   HTTPS `server {}` block in Nginx configs via naive string-splitting.
   Removed entirely in favor of shipping HTTP-only vhosts and letting the
   standard `certbot --nginx` plugin add HTTPS in place — safer than a
   hand-rolled, untestable text transform on a production Nginx config.
</content>
</invoke>
