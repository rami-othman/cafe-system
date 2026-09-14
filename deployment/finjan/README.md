# Finjan production deployment — Cafe System 618

Everything needed to install, migrate, run, verify, update, back up, and roll
back Cafe System 618 on the Finjan VPS, with GitHub as the source of truth and
**no runtime dependency on Railway, Supabase, or Netlify** once cutover is
complete.

Target server: `46.224.139.32` / `server.cafesystemsyria.com`
Domains: `api.cafesystemsyria.com` (Laravel), `admin.cafesystemsyria.com` (Next.js)
Deploy path: `/var/www/cafe-system`

## Operator sequence (first install)

```bash
ssh root@46.224.139.32
cd /var/www/cafe-system
git fetch origin
git checkout <approved-deployment-commit>      # see "Which commit" below
sudo bash deployment/finjan/install.sh          # answers a few secure prompts
sudo bash deployment/finjan/migrate-database.sh # prompts for Supabase source creds
sudo bash deployment/finjan/migrate-storage.sh  # prompts for Supabase Storage creds
sudo bash deployment/finjan/health-check.sh
sudo bash deployment/finjan/verify-cutover.sh
```

(This repo was committed from a Windows checkout, so the `.sh` files may not
carry the executable bit in Git — every command above invokes them via
`bash <script>` regardless, so this doesn't require any action on your part.
`install.sh` deliberately does **not** `chmod +x` these files itself: doing
so on a Linux checkout flips their tracked mode and dirties the worktree,
which then blocks `git checkout` for a future deploy/rollback. If you want
them directly executable, run `chmod +x deployment/finjan/*.sh` yourself,
once, outside of any script.)

Point DNS (`api` and `admin` A records → `46.224.139.32`) as early as you like —
`install.sh` checks for it and configures HTTPS automatically once it resolves.
If DNS isn't ready yet, `install.sh` still does everything else and tells you
exactly what to re-run afterward (`sudo bash deployment/finjan/install.sh`
again — it's idempotent).

### Which commit

This package was authored against production commit
`6d4f26145162dd78156f9ceb25cd9edcf260836e`, but **that commit does not contain
this deployment package** — these files were necessarily added in a new
commit on top of it (deployment tooling is still an application change and
gets its own commit, per policy: production application commits are never
silently modified). Run `git log -1 --oneline` in this checkout, or check the
commit message containing "Finjan deployment package", to find the exact SHA
to deploy — it was also reported to you directly when this package was
delivered.

## What you'll be asked for, and where

| Prompted by | For | Never written to |
|---|---|---|
| `install.sh` | Existing production `APP_KEY` (or confirmation to generate a new one) | Git, logs, terminal history beyond the one hidden prompt |
| `install.sh` | Platform Super Admin email | — (email isn't secret, but the generated password is never printed — retrieve it with `sudo grep SUPER_ADMIN_PASSWORD backend/.env` once, then rotate it after first login) |
| `migrate-database.sh` | Full Supabase source `postgresql://...` connection string | Git, logs — the variable is `unset` immediately after use; only the resulting `.dump` file (root-only, mode 600) persists |
| `migrate-storage.sh` | Temporary Supabase Storage S3 access key ID + secret | Git, `backend/.env`, logs — exported only for the duration of the two `artisan` calls, then `unset` |
| You, manually | DNS A records for `api.cafesystemsyria.com` and `admin.cafesystemsyria.com` → `46.224.139.32` | — |

Have those five things ready before you start. Nothing else requires manual
credential entry.

## Package contents

```
deployment/finjan/
├── install.sh                One-shot idempotent installer (27 steps — see below)
├── deploy.sh                 Repeatable future deployments: deploy.sh <commit>
├── rollback.sh                CODE rollback only — see "Rollback vs restore"
├── migrate-database.sh       Supabase Postgres -> local Postgres (pg_dump/pg_restore)
├── migrate-storage.sh        Supabase Storage -> local disk (wraps a new artisan command)
├── backup.sh                 Local backup: DB + product images + config (7/4/6 retention)
├── restore-backup.sh         DATABASE restore only — see "Rollback vs restore"
├── health-check.sh           Point-in-time health check, non-zero exit if unhealthy
├── verify-cutover.sh         Read-only cutover smoke tests
├── env.production.example    Documented backend/.env shape (no real secrets)
├── FINDINGS.md                Codebase audit backing every design decision below
├── CREDENTIAL_ROTATION_CHECKLIST.md
├── lib/common.sh              Shared bash helpers (logging, prompts, package checks)
├── nginx/{api,admin}.conf     HTTP vhosts; Certbot adds HTTPS in place
├── systemd/cafe-admin.service Next.js (standalone build) as a systemd unit
└── supervisor/cafe-worker.conf Queue worker, installed but NOT started (see FINDINGS.md)
```

Also added in this commit, application-side (not under `deployment/`):

- `backend/app/Console/Commands/MigrateProductImagesFromSupabase.php` — the
  actual copy-and-rewrite logic `migrate-storage.sh` drives. Dry-run by
  default; see its docblock and `FINDINGS.md`.

## What `install.sh` does (27 steps, idempotent)

Detects Ubuntu; installs only missing base packages; verifies PHP 8.4 +
the specific extensions this app needs (`mbstring`, `pdo_pgsql`, plus the
standard Laravel baseline — see `FINDINGS.md` for how that list was derived
from the project's own `Dockerfile`, not guessed); verifies Composer and
Node; verifies/installs Nginx and PostgreSQL **server** locally; creates a
dedicated PostgreSQL role + database; creates a dedicated, non-root Linux
system user (`cafe618`) that owns the code and runs PHP-FPM, the Next.js
service, the queue worker (dormant), and the scheduler cron job; sets
`storage/`/`bootstrap/cache` to 775/664 (never `777`); runs
`composer install --no-dev` and `npm ci`; writes `backend/.env` from secure
prompts; configures local product-image storage (already the application
default — no code change needed, see `FINDINGS.md`); installs the two Nginx
vhosts; configures a dedicated PHP-FPM pool; installs the (dormant) queue
worker and the scheduler cron entry; builds and starts the Next.js Super
Admin as a systemd service bound to `127.0.0.1:3000`; enables everything at
boot; configures UFW (allow SSH/80/443, explicitly deny 5432/3000); runs
Certbot **only if** DNS already resolves to this VPS; finishes with
`health-check.sh`.

## Queue and scheduler — read this before wondering why nothing runs

`FINDINGS.md` documents the evidence in full, but in short: **this codebase
currently has zero background jobs and zero scheduled tasks.** `QUEUE_CONNECTION=sync`
and a no-op `schedule:run` cron entry are the *correct* production
configuration today, not oversights. `supervisor/cafe-worker.conf` is
installed but set to `autostart=false` so it's one two-line edit away from
going live the day you actually add a queued job.

## Rollback vs restore — these are different operations

- **`rollback.sh <commit>`** — CODE rollback. Checks out an older commit and
  redeploys via `deploy.sh`. Does **not** touch the database. If a migration
  ran between the two commits, verify compatibility first (the script prints
  the migration diff and asks for confirmation).
- **`restore-backup.sh <dump-file>`** — DATABASE restore. Replaces the live
  database with an older `backup.sh` dump. Always takes a fresh safety dump of
  the *current* state first. Does not touch application code.

Use the one that matches the actual problem. A bad deploy usually needs
`rollback.sh`; a bad migration or data corruption usually needs
`restore-backup.sh` (possibly both, in that order: restore the DB, then roll
back the code that expects the old schema).

## Backups — read the risk note

`backup.sh daily|weekly|monthly` backs up PostgreSQL, product images, and
non-secret config to `/var/backups/cafe618/`, with 7/4/6 retention. **A backup
that only lives on this VPS does not protect you against losing this VPS.**
No off-site destination was configured, because the brief for this deployment
was "runtime and data live on Finjan" and no external storage credentials
were provided. When you're ready, the lowest-effort addition is a nightly
`rclone sync /var/backups/cafe618 remote:some-bucket` cron job pointed at
S3-compatible storage (Cloudflare R2, Backblaze B2, AWS S3) — `backup.sh`
already keeps `.env` in its own separately-excludable archive so you can wire
that up without also shipping secrets off-site by accident.

Suggested cron (add via `crontab -e` as root, or ask for a systemd timer if
you'd rather not use cron for this):

```
0 3 * * *   /usr/bin/bash /var/www/cafe-system/deployment/finjan/backup.sh daily
0 4 * * 0   /usr/bin/bash /var/www/cafe-system/deployment/finjan/backup.sh weekly
0 5 1 * *   /usr/bin/bash /var/www/cafe-system/deployment/finjan/backup.sh monthly
```

## Future deployments

```bash
cd /var/www/cafe-system
git fetch origin
sudo bash deployment/finjan/deploy.sh <exact-commit-sha-or-tag>
```

`deploy.sh` never deploys "latest main" — you always name the revision.
It refuses to run on a dirty working tree, installs dependencies, shows you
pending migrations and asks before running them, rebuilds caches (config +
view only — route caching is intentionally skipped; see the comment in
`backend/docker/cloud-entrypoint.sh`), restarts services, and runs
`health-check.sh` at the end.

## Cutover (leaving Railway/Supabase/Netlify)

See `verify-cutover.sh` for the automated read-only checks and the 15-step
procedure it prints. Nothing in this package ever deletes or disables
Railway, Supabase, or Netlify — that decommissioning step is explicitly
yours to trigger manually after you've verified the new stack.

## Flutter Windows client

`windows_application/lib/core/config/api_config.dart` reads its API base URL
from a **compile-time** Dart define, not a runtime config file. To point a
Windows build at production, build it on a Windows machine (Flutter desktop
cannot be cross-compiled from Linux) with:

```powershell
flutter build windows --release --dart-define=API_BASE_URL=https://api.cafesystemsyria.com/api/v1
```

The release build lands at
`windows_application\build\windows\x64\runner\Release\`. That whole folder is
the distributable app; it is never uploaded to this VPS or the Linux web root.

## Security checklist covered by this package

- No `chmod -R 777` anywhere (storage/bootstrap-cache are 775/664, owned by a
  dedicated non-root user).
- PostgreSQL and Next.js bind to loopback only; UFW explicitly denies 5432 and
  3000 from outside; `health-check.sh` verifies this on every run.
- `APP_DEBUG=false`, no development passwords, no secrets in this repo or in
  any file this package writes to Git.
- `backend/.env` is mode `640`, owned by the dedicated `cafe618` user.
- SSH and UFW configuration are inspected, not blindly reconfigured, by
  `install.sh` (see comments in that script for exactly what is and isn't
  touched).
- See `CREDENTIAL_ROTATION_CHECKLIST.md` for what to rotate given that some
  Supabase/Railway credentials were previously exposed.

## Linting

Every script in this directory passes `bash -n` (syntax check) and was
reviewed against `shellcheck` where available in the authoring environment.
See `LINT_REPORT.md` for the exact commands run and their output, including
two rounds of real-VPS bugs found after initial delivery (a `tr | head`
SIGPIPE crash, a scheduler-cron `set -e` abort, a worktree-dirtying `chmod`,
and an unnecessary DB-password re-prompt on re-run) and the regression tests
added to catch each class of bug going forward — run any of them any time
`lib/common.sh` or `install.sh` changes:

```bash
bash deployment/finjan/lib/test-random-secret.sh
bash deployment/finjan/lib/test-scheduler-cron.sh
bash deployment/finjan/lib/test-clean-worktree.sh
```
