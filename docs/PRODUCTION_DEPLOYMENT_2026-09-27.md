# Production deployment — 2026-09-27

- Server: `46.224.139.32`; repository: `/var/www/cafe-system`.
- Deployed remote main: `43c2678c3a361dd8c2b458f5837a99b3c91b1b81`.
- Previous production commit: `9e7716f3b8b6482d790a10068bc2b94440a99931`.
- Database backup: `/root/cafe618-safety/deploy-20260927T084736Z/database.dump`; archive catalogue validated with `pg_restore -l`. This was not a restore rehearsal.
- Backend and admin environment backups are in the same private directory.
- Previous cafe frontend: `/var/www/cafe18-backup-20260927T084736Z`.
- Installed production Composer dependencies, applied 14 forward migrations successfully, rebuilt Laravel config/view caches.
- Built Flutter Web with HTTPS API `https://46.224.139.32/api/v1` and base path `/cafe18/`; validated both JSON manifests before publication.
- Rebuilt Next.js admin using HTTPS API, restarted PHP-FPM and cafe-admin, validated/reloaded Nginx, ended maintenance mode.
- Nginx initially served an expired certificate although a renewed certificate existed. Reloading activated the valid certificate; added a Certbot deployment hook to reload Nginx after renewal.
- Checks: services active; cafe frontend HTTP 200; admin redirects to login; protected factory currency endpoint HTTP 401 without credentials (expected); published and built main.dart.js hashes match.
- Staging code remains `9e7716f3b8b6482d790a10068bc2b94440a99931`; staging application/database were not deployed. Nginx reload affects the shared service.
- No demo seeders, database reset, or test financial documents were executed on production. Authenticated business workflow acceptance was not performed.
- Deployment log: `/root/cafe618-deploy-main-20260927.log`.

The current Laravel source is checked out at the exact deployed commit. A code-only rollback must account for the new database schema; do not restore the pre-deployment database over newer business records without a separate reviewed recovery plan.
