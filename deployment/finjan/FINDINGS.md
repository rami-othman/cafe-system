# Codebase audit — findings behind the deployment package's decisions

Generated against commit `6d4f26145162dd78156f9ceb25cd9edcf260836e` (branch `main`).
Every claim below is backed by a grep/read against the actual repository, not assumed.

## APP_KEY rotation safety

Searched `backend/app/` and `backend/config/` for `Crypt::`, `->encrypt(`, `->decrypt(`,
and Eloquent `'encrypted'` / `"encrypted"` cast declarations: **zero matches**.

- No model casts a column as `encrypted`, `encrypted:array`, `encrypted:object`, etc.
- No controller/service calls the `Crypt` facade directly.
- `SESSION_ENCRYPT=false` in `.env.example` — sessions are not encrypted at rest either.

**Conclusion: nothing in this codebase persists data that only APP_KEY can decrypt.**
APP_KEY is still used to sign/verify sessions, CSRF tokens, and any `Str::password`/
`URL::signedRoute` output. Rotating it would silently log out every active session and
invalidate any outstanding signed URLs — an availability annoyance, not a data-loss risk.

**Recommendation implemented:** `install.sh` still prompts you to paste the *existing*
production APP_KEY if one exists, and only generates a new one if you explicitly say
there isn't one yet. This is the conservative choice given in the original instructions,
even though the code-level risk turned out to be low.

## Queue: why `QUEUE_CONNECTION=sync` is kept

- `grep -rl "ShouldQueue" backend/app/` → no matches. There are no queued job classes
  anywhere in the application.
- `backend/database/migrations/` contains no `jobs`, `failed_jobs`, or `job_batches`
  table migration, so `QUEUE_CONNECTION=database` would fail at runtime with a missing
  table until that migration is added by hand.
- `.env.example` (local *and* the commented-out Render/staging block) both use
  `QUEUE_CONNECTION=sync`.

**Conclusion:** `sync` is not a staging leftover here — it is the only driver the
current codebase actually supports without additional migration work. The deployment
package ships `supervisor/cafe-worker.conf` pre-written but disabled
(`autostart=false`), so turning on real background jobs later is a two-step edit, not a
new design.

## Scheduler: why the cron entry is a documented no-op today

- `backend/routes/console.php` only registers the built-in `inspire` Artisan command.
- `backend/bootstrap/app.php` never calls `->withSchedule(...)`.
- No `app/Console/Kernel.php` exists (Laravel 11+ style bootstrap), and no other file
  registers `Schedule::command(...)` / `Schedule::call(...)`.

**Conclusion:** there are currently no scheduled tasks in this application.
`install.sh` still installs the standard `* * * * * php artisan schedule:run` cron
entry, because it's the correct forward-compatible baseline and is harmless (it exits
immediately with nothing to run) — but `health-check.sh` reports this explicitly so you
are never left wondering why "the scheduler" doesn't appear to do anything.

`app/Console/Commands/` does contain five manual/on-demand commands
(`CheckFinancialIntegrity`, `InitializeStaging`, `ReconcileInventoryBalances`,
`RepairWarehouseConfiguration`, `VerifyFinanceDemo`). None of them are scheduled; they
are operator-invoked tools.

**`InitializeStaging` must never be run in production** — it hard-codes a guard
(`backend/app/Console/Commands/InitializeStaging.php:25`) that only permits execution
against the specific Supabase staging pooler hostname
(`aws-0-eu-central-1.pooler.supabase.com`). It will refuse to run against the local
production database, by design, and no deployment script in this package calls it.

## Storage: local product images require no code changes

`backend/config/product-images.php` already reads the active disk from
`PRODUCT_IMAGE_DISK`, defaulting to `product-images-local`:

```php
'disk' => env('PRODUCT_IMAGE_DISK', 'product-images-local'),
```

`backend/config/filesystems.php` already defines `product-images-local` as a plain
local disk rooted at `storage_path('app/public')` — exactly the directory
`php artisan storage:link` exposes at `public/storage`. The `supabase-product-images`
disk (S3-compatible, via `league/flysystem-aws-s3-v3`) is only ever selected when
`PRODUCT_IMAGE_DISK=supabase-product-images` is explicitly set in the environment.

**Conclusion:** switching production storage to "local on this VPS" is a **configuration
change, not a code change** — simply never set `PRODUCT_IMAGE_DISK` to the Supabase
value in `backend/.env`. `migrate-storage.sh` handles copying the *existing* files down
from Supabase and rewriting any stored URLs; see that script and
`MIGRATE_STORAGE_NOTES.md` for how product image references are actually persisted.

## Database: `DB_SSLMODE` / `DB_URL`

`backend/config/database.php` line ~99: `'sslmode' => env('DB_SSLMODE', 'prefer')`.
Leaving `DB_SSLMODE` unset in production is correct — `prefer` negotiates SSL but does
not require it, which is fine for a loopback/same-host PostgreSQL connection. `DB_URL`
is a Render/Supabase-era convenience (`config/database.php` reads `env('DB_URL')` first
for several connections) — production `.env` uses the discrete `DB_HOST`/`DB_DATABASE`/
`DB_USERNAME`/`DB_PASSWORD` variables instead and never sets `DB_URL`.

## Dependency audit: Railway / Supabase / Netlify

Grepped `backend/app`, `backend/config`, `backend/routes`, `backend/bootstrap`,
`backend/database`, and the repository root for `supabase`, `railway.app`, `netlify`
(case-insensitive):

| Reference | File | Status after this deployment |
|---|---|---|
| Supabase staging pooler hostname guard | `backend/app/Console/Commands/InitializeStaging.php` | Inert in production — command refuses to run here. Fine to leave; can be deleted later if desired. |
| `supabase-product-images` disk definition | `backend/config/filesystems.php` | Fine to leave as dead code — it's only a config array, never loaded unless `PRODUCT_IMAGE_DISK` is set to it. Not used in production `.env`. |
| `SUPABASE_STORAGE_*` env var references | `backend/.env.example`, `render.yaml` | Not present in production `.env` (see `env.production.example`). |
| `render.yaml` (Render, not Railway) | repo root | Render is still referenced as a *staging* deploy target. It is not touched by this package and keeps working independently — decommission it yourself once you're done using staging, per your cutover plan. |
| `netlify.toml` | repo root | Builds `windows_application` as **Flutter Web** (`flutter build web`, publish `build/web`) — a different artifact from the Windows desktop release. This is the "Netlify" dependency your instructions want removed from production. It only ever served a web build of the Flutter app; it has no relationship to the Laravel API or Next.js Super Admin. Safe to disable/delete once you no longer need a hosted web build of the POS app. |
| Railway | — | **No `railway.json`, `railway.toml`, `Procfile`, or any Railway-specific file or reference exists anywhere in this repository.** The only cloud staging target actually wired up in-repo is Render (`render.yaml`, `Dockerfile`). If Railway is genuinely in use, it must be configured entirely outside this repo (dashboard-only env vars) — worth double-checking your Railway project directly, since nothing here points at it. |

**Net result:** after this deployment package is applied, the production runtime
(backend `.env` + Nginx + systemd) has **zero live dependency** on Supabase, Railway, or
Netlify. Dead references (the disk definition, the staging-only guard command,
`render.yaml`, `netlify.toml`) remain in the repository as inert configuration/code —
removing them entirely is a separate, optional cleanup, not required for cutover.

## Flutter Windows client: API base URL

`windows_application/lib/core/config/api_config.dart`:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api/v1',
);
```

This is a **compile-time** Dart define, not a runtime `.env` file. There is no way to
point an already-built `.exe` at production without rebuilding it. See
`deployment/finjan/README.md` § Flutter Windows for the exact `flutter build windows`
command with `--dart-define=API_BASE_URL=...`, to be run on a Windows machine (Flutter
Windows desktop cannot be built from Linux/WSL).

## Next.js Super Admin: build-time API URL

`super_admin_web/.env.example`: `NEXT_PUBLIC_API_URL=http://localhost:8000/api/super-admin/v1`.

`NEXT_PUBLIC_*` variables are inlined into the JavaScript bundle **at build time**, not
read at server start. `install.sh`/`deploy.sh` write `super_admin_web/.env.production`
with `NEXT_PUBLIC_API_URL=https://api.cafesystemsyria.com/api/super-admin/v1` *before*
running `npm run build`, matching the route prefix Laravel actually serves
(`routes/super_admin.php` mounted at `api/super-admin/v1` in `bootstrap/app.php`).

`next.config.ts` already sets `output: 'standalone'`, so the production artifact is the
self-contained `.next/standalone/server.js` run directly by systemd — no `next start`
+ full `node_modules` needed in production.

## PHP version and extensions

`backend/composer.json` declares only `"php": "^8.3"` — no explicit `ext-*`
requirements. The authoritative source for which PHP extensions this application
actually needs in production is `Dockerfile` (the working Render/staging image):

```dockerfile
FROM php:8.4-cli AS base
RUN apt-get install -y --no-install-recommends libonig-dev libpq-dev unzip \
 && docker-php-ext-install mbstring pdo_pgsql
```

i.e. beyond a standard PHP 8.4 CLI/FPM baseline, this app needs **`mbstring`** and
**`pdo_pgsql`** specifically. `install.sh` installs those plus the standard Laravel
baseline (`xml`, `curl`, `zip`, `bcmath`, `intl`, `gd`, `opcache`) and verifies each with
`php -m` rather than assuming, installing only what's actually missing.

The same `Dockerfile` also documents the exact production `opcache` tuning currently
proven to work on Render; `install.sh`'s PHP-FPM pool config mirrors those values.
