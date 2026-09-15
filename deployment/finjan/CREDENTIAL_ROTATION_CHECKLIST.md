# Credential rotation checklist

You told me some Supabase/Railway-related credentials were exposed during
earlier setup. Treat all of the following as compromised and rotate them —
this package never places any of them in Git, but that doesn't undo prior
exposure elsewhere (terminal scrollback, chat history, screenshots, etc.).

Rotate **after** migration is verified and you no longer need the old
credentials for `migrate-database.sh` / `migrate-storage.sh` (rotating first
would just mean re-fetching the new ones to run those scripts).

- [ ] **Supabase PostgreSQL password** (the role used in the source connection
      string you pasted into `migrate-database.sh`). Rotate in the Supabase
      dashboard → Database → Roles.
- [ ] **Supabase Storage access key ID / secret access key** (pasted into
      `migrate-storage.sh`). Rotate in Supabase dashboard → Storage →
      S3 credentials, or revoke the specific key pair used.
- [ ] **Any Render environment variables** marked `sync: false` in
      `render.yaml` (`APP_KEY`, `DB_URL`, `CORS_ALLOWED_ORIGINS`,
      `SUPABASE_STORAGE_ENDPOINT`, `SUPABASE_STORAGE_ACCESS_KEY_ID`,
      `SUPABASE_STORAGE_SECRET_ACCESS_KEY`, `SUPABASE_STORAGE_PUBLIC_URL`) —
      these were entered directly into the Render dashboard and are not in
      Git, but rotate them once Render/staging is no longer needed.
- [ ] **Railway credentials**, if Railway is genuinely in use somewhere outside
      this repository (see `FINDINGS.md` — no Railway configuration was found
      in-repo, so double-check this directly in your Railway account).
- [ ] **The Super Admin password `install.sh` generated** for the first-run
      platform admin account — log in once, then change it immediately from
      within the Super Admin UI.
- [ ] **The local PostgreSQL application password** `install.sh` generated for
      `cafe618_app` is stored only in `backend/.env` (mode 640, root/cafe618
      only) — no action needed unless you suspect that file itself was
      exposed, in which case: `sudo -u postgres psql -c "ALTER ROLE cafe618_app PASSWORD '<new>';"`
      and update `DB_PASSWORD` in `backend/.env`, then
      `php artisan config:cache`.
- [ ] **APP_KEY**, if you generated a *new* one during `install.sh` rather than
      preserving an existing production key — this isn't a "rotation" so much
      as a one-time note: it invalidated old sessions/signed URLs, which is
      expected, not a leak.
- [ ] **Netlify deploy credentials/tokens**, once you decommission the
      `netlify.toml`-based Flutter Web build per your own cutover schedule.

None of the above values are printed by any script in this package. Where a
script needed one of them, it was read via `read -s` (hidden input) and
either never persisted (Supabase creds) or written only into
`backend/.env` with `640` permissions (the generated local DB/Super Admin
passwords).
