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

## Post-delivery fix: `random_secret()` SIGPIPE crash (found on a real VPS run)

Static analysis and the checks above did not catch this one — it only showed
up running `install.sh` for real, which is exactly the gap a runtime test now
closes.

**Symptom:** `install.sh` exited silently at `== Step 10-11/27: PostgreSQL app
user + database ==`, with no error message.

**Root cause:** `lib/common.sh`'s `random_secret()` was:

```bash
tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-32}"
```

`/dev/urandom` is an infinite stream. `head -c N` exits the instant it has
read its N bytes, closing its end of the pipe. `tr` is still trying to write
more filtered bytes into that now-closed pipe, so it's killed by `SIGPIPE`
(exit status 141). Every script in this package runs `set -euo pipefail`, so
`pipefail` promotes that 141 to the whole pipeline's exit status, and `set -e`
then aborts the script — at `DB_APP_PASSWORD="$(random_secret 32)"` in
`install.sh`, with nothing printed to stderr because SIGPIPE termination is
silent. Reproduced directly in this environment:

```
$ bash -c 'set -euo pipefail; tr -dc "A-Za-z0-9" </dev/urandom | head -c 32'
$ echo $?
141
```

**Fix:** replaced the pipeline with a single `openssl rand -hex` call (no
pipe, so no early-exiting downstream consumer to SIGPIPE anything):

```bash
random_secret() {
  local len="${1:-32}"
  command -v openssl >/dev/null 2>&1 || fatal "openssl is required to generate secrets but was not found on PATH."
  local hex
  hex="$(openssl rand -hex "$(( (len + 1) / 2 ))")"
  printf '%s' "${hex:0:len}"
}
```

Character set changed from mixed-case alphanumeric (62 symbols) to lowercase
hex (16 symbols); at the lengths this package actually requests (20, 24, 32),
that's still 80–128 bits of entropy — cryptographically strong, well above
what's needed for a generated database or admin password. `install.sh`'s
other secret-generation call, `openssl rand -base64 32` for `APP_KEY`
(line ~255), was already pipe-free and was not affected.

**Audit of every other script for the same class of bug** (an early-exiting
consumer — chiefly `head`, or `-m`-less `grep` piped into one — SIGPIPE-ing an
upstream producer under active `set -e`/`pipefail`):

| Location | Pattern | Verdict |
|---|---|---|
| `lib/common.sh` `random_secret()` | `tr </dev/urandom \| head -c N` | **Confirmed bug — fixed above.** |
| `install.sh` (`listen_addresses` check) | `grep "^..." "$PG_CONF" \| head -1` | Latent risk: safe today because that file normally has one matching line, but would SIGPIPE `grep` (and abort `install.sh`, which runs with active `set -e`/`pipefail`) if it ever had two. Fixed: replaced with `grep -m1 "^..." "$PG_CONF"` — no pipe, grep stops itself after the first match. |
| `verify-cutover.sh` (latest migration report) | `find ... \| sort -rn \| head -1 \| cut ...` | Not actually exploitable — this script does `set +e` right after sourcing `common.sh`, so even a non-zero pipeline status can't abort it — but the same early-exit shape, so tidied for consistency: reordered to `sort -n \| tail -1`, which must consume the whole stream before it can emit anything, so `sort` always finishes writing normally. |
| `backup.sh` (retention pruning) | `find ... \| sort -rn \| tail -n "+K" \| cut ...` | Safe as originally written — `tail -n +K` reads to end-of-input before producing output, so it never lets `sort` see a closed pipe early. No change. |
| `health-check.sh` / `migrate-database.sh` / `restore-backup.sh` / `verify-cutover.sh` — assorted `echo "$x" \| tr -d '[:space:]'`, `df \| tail -1 \| awk ... \| tr -d '%'`, `dig ... \| tail -1` | `tr`/`awk`/`cut` here are pure line-by-line filters (no truncation), and every `tail` (unlike `head`) must read its entire input before it can emit the last line — none of these let a downstream command exit before an upstream one finishes writing. No change. |
| `install.sh` (`APP_KEY` generation) | `openssl rand -base64 32` | Already a single command, no pipe. No change. |

**New regression test:** `lib/test-random-secret.sh` calls `random_secret()`
1,800 times (9 lengths × 200 runs) under the exact `set -euo pipefail` mode
every script in this package uses, and asserts each result is alphanumeric
and exactly the requested length. Run it any time this file changes:

```bash
bash deployment/finjan/lib/test-random-secret.sh
```

Result as of this fix: **1,800/1,800 calls passed, 0 SIGPIPE/pipefail
aborts.** Re-ran `bash -n` and `shellcheck -x` (both plain `-f gcc` output and
an error-severity-only pass, `-S error`) across all 11 scripts (10 original +
the new test) after this fix — same accepted findings as the original lint
pass (SC2015/SC2024/SC2034/SC1090/SC1091, all previously reviewed above),
**zero new findings, zero error-severity findings.**

## Post-delivery fix round 2: Step 22 scheduler-cron crash, git worktree dirtying, unnecessary DB-password re-prompt

Also found on a real (fresh) VPS run, all three in the same session.

### 2a. `install.sh` Step 22 (scheduler cron) — another `set -e`/pipefail abort

**Symptom:** `install.sh` reached `== Step 22/27: scheduler cron ==` and
exited silently back to the shell prompt.

**Root cause:** the original one-liner was

```bash
( crontab -u "$APP_LINUX_USER" -l 2>/dev/null | grep -vF "artisan schedule:run" ; echo "$CRON_LINE" ) | crontab -u "$APP_LINUX_USER" -
```

`crontab -l` exits 1 on a brand-new system user with no crontab yet (true on
every fresh install), and `grep -v` exits 1 whenever it selects zero lines
(true whenever the existing crontab contains *only* a previous
`schedule:run` entry, i.e. on a re-run). Both are entirely normal, not
errors — but they sit inside a raw pipeline/subshell under this script's
`set -euo pipefail`, so either one aborted the subshell before
`echo "$CRON_LINE"` ever ran, exactly as diagnosed.

**Fix:** extracted a new `install_cron_line()` helper into `lib/common.sh`
(shared, testable in isolation — see below) that captures each step's result
explicitly with `|| true` before deciding what to write, and writes the
final crontab from a temp file (`crontab -u "$user" "$tmp"`) rather than
piping into `crontab -`, so a genuine crontab-install failure still aborts
normally. `install.sh`'s Step 22 is now a single call:
`install_cron_line "$APP_LINUX_USER" "artisan schedule:run" "$CRON_LINE"`.

**New regression test:** `lib/test-scheduler-cron.sh` runs
`install_cron_line()` against a **real** `crontab` binary (not a mock),
covering exactly the scenarios above plus idempotency:

| Scenario | Result |
|---|---|
| No existing crontab at all | 1 line written (the scheduler entry) |
| Only the scheduler entry exists (re-run) | still exactly 1 line |
| Unrelated entries + a scheduler entry | unrelated entries kept, exactly 1 scheduler line |
| 5 repeated calls in a row | unrelated entries still intact, still exactly 1 scheduler line |
| Unrelated-only crontab (no scheduler line yet) | scheduler line added, unrelated kept |

All 5/5 passed. Run it any time `install_cron_line()` or Step 22 changes:

```bash
bash deployment/finjan/lib/test-scheduler-cron.sh
```

(It manages `crontab` for the invoking user — or `$TEST_CRON_USER` — and
restores whatever crontab existed before the test ran, via a `trap ... EXIT`,
even on failure.)

### 2b. `install.sh` was dirtying the git worktree

**Symptom (reported directly, not yet hit as a live failure):** the
`chmod +x "${SCRIPT_DIR}"/*.sh` line added in the previous fix round (to
work around this repo's `.sh` files lacking the executable bit on a Windows
checkout) flips each tracked file's mode from `100644` to `100755` on a
Linux checkout, where `core.fileMode` normally defaults to `true` — unlike
the Windows checkout this repo was originally committed from, where it's
`false`. `git status` then reports every script as modified, which blocks a
later `git checkout <other-commit>` (needed for `deploy.sh`/`rollback.sh`)
until an operator manually discards or commits that mode-only change.

**Fix:** removed the `chmod +x` call entirely. It was never actually
required — every invocation anywhere in this package uses `bash <script>`,
never `./<script>` (re-confirmed by grep across the whole package) — so
there was nothing to "fix" at runtime in the first place; it only existed as
an over-eager defensive measure that turned out to cause the exact class of
problem it was trying to prevent. `install.sh` and `README.md` now document
this explicitly so it doesn't get silently re-added later.

**New regression test:** `lib/test-clean-worktree.sh` — a static grep guard
(scoped to real code lines, not comments, in the actual deployment scripts)
asserting no `chmod +x ... *.sh` call exists anywhere in this package, plus
a live check that builds a disposable throwaway git repo, records every
tracked file's mode and `git status`, exercises the same repo-root-detection
logic `install.sh` runs on startup, and asserts both are byte-for-byte
unchanged afterward. Verified the guard actually catches a regression (not
just a no-op pattern) by temporarily reintroducing the old `chmod +x` line
into a scratch copy and confirming the test fails against it, then confirmed
it passes clean against the real, fixed `install.sh`. Run it any time
`install.sh`'s startup section changes:

```bash
bash deployment/finjan/lib/test-clean-worktree.sh
```

### 2c. Unnecessary DB-password re-prompt when `.env` already exists

**Symptom:** on a re-run where `backend/.env` already exists (and is
correctly left untouched per Step 16-18's existing idempotency), Step 10-11
still unconditionally prompted the operator to re-enter the PostgreSQL app
role's existing password — even though that value is never read back out of
`backend/.env` and was about to be completely unused for the rest of the
run.

**Root cause:** `DB_APP_PASSWORD` is used in exactly one place in the whole
package — populating a **brand-new** `backend/.env`'s `DB_PASSWORD=` line at
Step 16-18. The Step 10-11 "role already exists" branch prompted for it
unconditionally whenever the Postgres role pre-existed, without checking
whether `.env` (the only consumer) was even going to be written this run.

**Fix:** moved the `ENV_FILE="${BACKEND_DIR}/.env"` definition up to the top
of the script (previously only defined at Step 16-18, too late for Step
10-11 to see it) and restructured Step 10-11's "role already exists" branch:

```bash
if [[ -f "$ENV_FILE" ]]; then
  log_info "backend/.env already exists too, so the existing DB password isn't needed here — it stays wherever it already is."
elif [[ -z "${DB_APP_PASSWORD:-}" ]]; then
  prompt_secret DB_APP_PASSWORD "Enter the EXISTING password for PostgreSQL role '${DB_APP_USER}' (needed once, to write a new backend/.env)"
fi
```

Now the prompt fires only in the one case where it's genuinely needed: the
role pre-exists (so this script doesn't know its password) **and**
`backend/.env` does not yet exist (so something still has to go on its
`DB_PASSWORD=` line). Every other combination — including the common re-run
case where both already exist — asks for nothing. The password is still
never printed or logged anywhere (`prompt_secret` uses `read -s`, same as
before), and no code path reads it back out of an existing `.env` file
(never needed to, since that branch now never touches `.env` at all).

### Audit of Steps 23-27 for legitimate non-zero exit codes (not just SIGPIPE)

Went through every command in Steps 23-27 that could plausibly return
non-zero under normal/expected conditions, given `install.sh` runs with
`set -euo pipefail` active throughout (no `set +e` override anywhere in this
script, unlike `health-check.sh`/`verify-cutover.sh`):

| Location | Risk considered | Verdict |
|---|---|---|
| Step 23: `[[ -d "${ADMIN_DIR}/public" ]] && cp -r ...` | `cp` only conditionally needed (not every Next.js app ships a `public/` dir) | Safe as written — confirmed empirically that `[[ cond ]] && cmd` as a standalone statement does **not** trigger `set -e` when `cond` is false (only the *last* command in an AND-OR list is subject to `-e`; earlier ones, including a false test that short-circuits the rest, are exempt). No change. |
| Step 23: `NODE_BIN="$(command -v node)"` | `command -v` fails if Node is missing | Intentional hard-fail — Node being genuinely absent at this point is a real problem worth aborting on, not a false positive. No change. |
| Step 24: `systemctl enable ... \|\| true` | — | Already guarded. No change. |
| Step 25: firewall rules, `if ! ufw status \| grep -q "Status: active"; then` | `grep -q` finding nothing (UFW not yet enabled) is the expected first-run case | Already safe — inside an `if`/`!` context, both fully exempt from `set -e` regardless of match/no-match. No change. |
| Step 26: `if dns_resolves_to_this_host "$domain"; then` | DNS not resolving yet is the expected pre-DNS-cutover case | Already safe — `if`-context exemption. No change. |
| Step 26: `RESOLVED_IP="$(dig +short A "$domain" \| tail -1)"` | a transient resolver hiccup on this *second* `dig` call (right after `dns_resolves_to_this_host` already proved an A record exists) | **Hardened defensively**: wrapped as `\|\| true`. Not a guaranteed-every-run condition like the others in this table, but a rare transient failure here shouldn't be able to abort the *entire* installer this late (Steps 1-25 already made real system changes) when an empty `RESOLVED_IP` already correctly falls into the existing "not ready yet, skip SSL, re-run later" branch. |
| Step 26: `certbot --nginx ... \|\| log_warn ...` | Certbot failing (rate limits, network) | Already guarded. No change. |
| Step 26: `systemctl list-timers \| grep -qi certbot && log_ok ... \|\| log_warn ...` | classic `A && B \|\| C` (SC2015) | Already reviewed and accepted in the original lint pass — `log_ok`/`log_warn` can't themselves fail in a way that falls through. No change. |
| Step 27: `bash health-check.sh \|\| log_warn ...` | health checks legitimately failing pre-DNS/SSL | Already guarded. No change. |
| (Step 10-11, re-checked while touching this area) `PG_CONF="$(sudo -u postgres psql ... \| xargs)"` | `psql` failing | Intentional hard-fail — Postgres not responding at this point (after `systemctl enable --now postgresql` already ran) is a real problem worth surfacing. No change. |

Net result: **one** additional defensive hardening applied (the second `dig`
call in Step 26); everything else in Steps 23-27 was already either
correctly exempt from `set -e` by construction (`if`/`&&`-short-circuit
contexts) or intentionally fatal on a genuine failure, not a misdiagnosed
normal condition.

### Full verification after this round

- `bash -n` on all 13 scripts (10 original + 3 test scripts): all pass.
- `lib/test-random-secret.sh`: 1,800/1,800 pass (unaffected by this round's
  changes, re-run to confirm no regression).
- `lib/test-scheduler-cron.sh`: 5/5 scenarios pass against a real `crontab`.
- `lib/test-clean-worktree.sh`: static guard + live git-repo check both pass;
  guard verified to actually fail against a reintroduced copy of the old bug.
- `shellcheck -x -f gcc` across all 13 scripts: same previously-accepted
  findings (SC2015/SC2024/SC2034/SC1090/SC1091) plus two new, equally benign
  ones from the two new test scripts' `trap`-registered cleanup functions —
  `SC2317` ("command appears unreachable"), a well-known shellcheck
  limitation when a function is only ever called indirectly via `trap`, not
  a real defect (confirmed both functions run correctly — the crontab
  restoration in `test-scheduler-cron.sh` and the temp-dir cleanup in
  `test-clean-worktree.sh` were observed firing on every test run above).
- `shellcheck -x -S error` (error-severity only): **zero findings**, same as
  every prior round.
</content>
</invoke>
