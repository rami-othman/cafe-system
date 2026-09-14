#!/usr/bin/env bash
# Finjan production installer for Cafe System 618.
# Idempotent: safe to re-run. Only installs/changes what is missing or wrong.
#
# Usage:
#   cd /var/www/cafe-system
#   sudo bash deployment/finjan/install.sh
#
# What this does NOT do:
#   - migrate data from Supabase (see migrate-database.sh)
#   - copy product images from Supabase Storage (see migrate-storage.sh)
#   - obtain SSL certificates until DNS actually resolves to this VPS
#   - touch Railway/Supabase/Netlify — those stay exactly as they are

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

# This repo may have been committed from a Windows checkout (core.fileMode=false),
# which drops the executable bit on .sh files even though every invocation in
# this package uses `bash <script>` rather than `./<script>` (so it never blocks
# anything) — restore it anyway so a operator running a script directly, or a
# future tool that shells out to it, doesn't hit a confusing permission error.
chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true

log_info "Repo root detected as: ${REPO_ROOT}"
[[ -f "${REPO_ROOT}/backend/composer.json" ]] || fatal "backend/composer.json not found under ${REPO_ROOT} — is this script running from inside the cafe-system repo?"

DEPLOYED_COMMIT="$(cd "${REPO_ROOT}" && git rev-parse HEAD)"
log_info "Repository is currently checked out at commit: ${DEPLOYED_COMMIT}"

# =============================================================================
# 1. Detect Ubuntu version
# =============================================================================
log_info "== Step 1/27: OS detection =="
if [[ ! -f /etc/os-release ]]; then
  fatal "/etc/os-release not found — this script targets Ubuntu 24.04 LTS."
fi
# shellcheck source=/dev/null
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  fatal "This installer targets Ubuntu (detected ID=${ID:-unknown}). Aborting rather than guessing package names."
fi
if [[ "${VERSION_ID:-}" != "24.04" ]]; then
  log_warn "Detected Ubuntu ${VERSION_ID:-unknown}, package sets were verified against 24.04. Continuing, but watch for apt errors."
fi
log_ok "OS: ${PRETTY_NAME:-Ubuntu ${VERSION_ID:-unknown}}"

apt-get update -qq

# =============================================================================
# 2-3. Verify / install required base packages
# =============================================================================
log_info "== Step 2-3/27: base packages =="
ensure_packages curl git unzip zip ca-certificates gnupg lsb-release ufw supervisor cron

# =============================================================================
# 4. PHP version + required extensions (from composer.json + Dockerfile, see FINDINGS.md)
# =============================================================================
log_info "== Step 4/27: PHP 8.4 + extensions =="
if ! command -v php >/dev/null 2>&1; then
  fatal "PHP is not installed. This VPS was verified to already have PHP 8.4.25 installed; install it via your distro's PHP source (e.g. ondrej/php PPA) before re-running."
fi
PHP_VERSION="$(php -r 'echo PHP_VERSION;')"
log_info "Detected PHP ${PHP_VERSION}"
php -r 'exit(version_compare(PHP_VERSION, "8.3.0", ">=") ? 0 : 1);' \
  || fatal "PHP ${PHP_VERSION} does not satisfy composer.json's \"php\": \"^8.3\" requirement."

PHP_MINOR="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
REQUIRED_EXTENSIONS=(mbstring pgsql pdo_pgsql xml curl zip bcmath intl gd opcache fileinfo tokenize ctype)
MISSING_EXT_PKGS=()
for ext in "${REQUIRED_EXTENSIONS[@]}"; do
  case "$ext" in
    tokenize) modname="tokenizer" ;;
    *) modname="$ext" ;;
  esac
  if ! php_ext_present "$modname"; then
    MISSING_EXT_PKGS+=("php${PHP_MINOR}-${ext}")
  fi
done
if [[ ${#MISSING_EXT_PKGS[@]} -gt 0 ]]; then
  log_info "Installing missing PHP extensions: ${MISSING_EXT_PKGS[*]}"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${MISSING_EXT_PKGS[@]}" \
    || log_warn "Some extension packages failed to install by that exact name — verify manually with 'php -m'."
else
  log_ok "All required PHP extensions already present (mbstring, pgsql/pdo_pgsql, xml, curl, zip, bcmath, intl, gd, opcache)."
fi
ensure_packages "php${PHP_MINOR}-fpm" "php${PHP_MINOR}-cli"

# Mirror the opcache tuning proven on the Render staging image (Dockerfile).
PHP_INI_DIR="/etc/php/${PHP_MINOR}/fpm/conf.d"
if [[ -d "$PHP_INI_DIR" ]]; then
  cat > "${PHP_INI_DIR}/99-cafe618-opcache.ini" <<'EOF'
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=192
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=1
opcache.revalidate_freq=2
realpath_cache_size=16M
realpath_cache_ttl=600
EOF
  log_ok "Wrote ${PHP_INI_DIR}/99-cafe618-opcache.ini (validate_timestamps=1, unlike the immutable Docker image, since this is a live filesystem you deploy onto repeatedly)."
fi

# =============================================================================
# 5. Composer
# =============================================================================
log_info "== Step 5/27: Composer =="
if ! command -v composer >/dev/null 2>&1; then
  log_info "Installing Composer..."
  EXPECTED_SIG="$(curl -fsSL https://composer.github.io/installer.sig)"
  curl -fsSL -o /tmp/composer-setup.php https://getcomposer.org/installer
  ACTUAL_SIG="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
  [[ "$EXPECTED_SIG" == "$ACTUAL_SIG" ]] || fatal "Composer installer signature mismatch — aborting for safety."
  php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
  rm -f /tmp/composer-setup.php
fi
log_ok "Composer: $(composer --version)"

# =============================================================================
# 6. Node.js (verify version the project actually needs)
# =============================================================================
log_info "== Step 6/27: Node.js =="
command -v node >/dev/null 2>&1 || fatal "Node.js is not installed. This VPS was verified to already have Node 22.23.2 — install Node 20+ (nodesource) before re-running."
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [[ "$NODE_MAJOR" -lt 18 ]]; then
  fatal "Node ${NODE_MAJOR}.x found; Next.js $(grep -o '"next": *"[^"]*"' "${ADMIN_DIR}/package.json" 2>/dev/null || echo '15.x') requires Node >=18.18. Upgrade Node before continuing."
fi
log_ok "Node: $(node -v), npm: $(npm -v)"

# =============================================================================
# 7. Nginx
# =============================================================================
log_info "== Step 7/27: Nginx =="
ensure_packages nginx
systemctl enable --now nginx >/dev/null 2>&1 || true
log_ok "Nginx: $(nginx -v 2>&1)"

# =============================================================================
# 8-9. PostgreSQL server, local only
# =============================================================================
log_info "== Step 8-9/27: PostgreSQL server (local) =="
if ! command -v psql >/dev/null 2>&1 || ! dpkg -s postgresql >/dev/null 2>&1; then
  ensure_packages postgresql postgresql-contrib
fi
systemctl enable --now postgresql >/dev/null 2>&1 || true

# Confirm it is bound to localhost only, never touch it if an admin already
# customized listen_addresses to something else on purpose.
PG_CONF="$(sudo -u postgres psql -tAc "SHOW config_file;" 2>/dev/null | xargs)"
if [[ -n "$PG_CONF" ]] && grep -q "^listen_addresses" "$PG_CONF" 2>/dev/null; then
  CURRENT_LISTEN="$(grep "^listen_addresses" "$PG_CONF" | head -1)"
  log_info "PostgreSQL listen_addresses: ${CURRENT_LISTEN}"
else
  log_info "PostgreSQL listen_addresses left at compiled-in default (localhost) — not modified."
fi
log_ok "PostgreSQL: $(psql --version)"

# =============================================================================
# 10-11. Dedicated Postgres app user + production database
# =============================================================================
log_info "== Step 10-11/27: PostgreSQL app user + database =="
load_state
DB_NAME="${DB_NAME:-cafe618_production}"
DB_APP_USER="${DB_APP_USER:-cafe618_app}"

DB_USER_EXISTS="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_APP_USER}'" || true)"
if [[ "$DB_USER_EXISTS" == "1" ]]; then
  log_ok "PostgreSQL role '${DB_APP_USER}' already exists — leaving its password untouched."
  if [[ -z "${DB_APP_PASSWORD:-}" ]]; then
    prompt_secret DB_APP_PASSWORD "Enter the EXISTING password for PostgreSQL role '${DB_APP_USER}' (needed to write backend/.env, not to change it)"
  fi
else
  if [[ -z "${DB_APP_PASSWORD:-}" ]]; then
    DB_APP_PASSWORD="$(random_secret 32)"
    log_info "Generated a new random password for PostgreSQL role '${DB_APP_USER}' (not printed)."
  fi
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE ROLE ${DB_APP_USER} LOGIN PASSWORD '${DB_APP_PASSWORD}';" >/dev/null
  log_ok "Created PostgreSQL role '${DB_APP_USER}'."
fi

DB_EXISTS="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" || true)"
if [[ "$DB_EXISTS" == "1" ]]; then
  log_ok "Database '${DB_NAME}' already exists — leaving its contents untouched."
else
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_APP_USER};" >/dev/null
  log_ok "Created database '${DB_NAME}' owned by '${DB_APP_USER}'."
fi
save_state DB_NAME "$DB_NAME"
save_state DB_APP_USER "$DB_APP_USER"

# =============================================================================
# 12. Dedicated application Linux user
# =============================================================================
log_info "== Step 12/27: application Linux user =="
if ! id -u "$APP_LINUX_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "/home/${APP_LINUX_USER}" --shell /usr/sbin/nologin "$APP_LINUX_USER"
  log_ok "Created system user '${APP_LINUX_USER}' (no login shell)."
else
  log_ok "System user '${APP_LINUX_USER}' already exists."
fi
mkdir -p /var/log/cafe618
chown "${APP_LINUX_USER}:${APP_LINUX_GROUP}" /var/log/cafe618

# =============================================================================
# 13. Filesystem ownership/permissions
# =============================================================================
log_info "== Step 13/27: filesystem ownership =="
cd "${BACKEND_DIR}"
mkdir -p storage/app/private storage/app/public storage/framework/cache/data \
         storage/framework/sessions storage/framework/testing storage/framework/views \
         storage/logs bootstrap/cache
chown -R "${APP_LINUX_USER}:${APP_LINUX_GROUP}" "${REPO_ROOT}"
find storage bootstrap/cache -type d -exec chmod 775 {} \;
find storage bootstrap/cache -type f -exec chmod 664 {} \;
log_ok "Ownership set to ${APP_LINUX_USER}:${APP_LINUX_GROUP} across ${REPO_ROOT}; storage/bootstrap-cache set to 775/664 (never 777)."

# =============================================================================
# 14. Composer install
# =============================================================================
log_info "== Step 14/27: composer install (no-dev) =="
sudo -u "$APP_LINUX_USER" composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction --working-dir="${BACKEND_DIR}"
log_ok "Backend Composer dependencies installed."

# =============================================================================
# 15. Next.js dependencies + build (deferred until .env.production is written — see below)
# =============================================================================
log_info "== Step 15/27: Next.js dependencies =="
if [[ -f "${ADMIN_DIR}/package-lock.json" ]]; then
  sudo -u "$APP_LINUX_USER" npm --prefix "${ADMIN_DIR}" ci
else
  log_warn "No package-lock.json found in super_admin_web — falling back to npm install (less reproducible)."
  sudo -u "$APP_LINUX_USER" npm --prefix "${ADMIN_DIR}" install
fi

# =============================================================================
# 16-18. Production backend/.env (secrets prompted, never printed)
# =============================================================================
log_info "== Step 16-18/27: backend/.env =="
ENV_FILE="${BACKEND_DIR}/.env"
if [[ -f "$ENV_FILE" ]]; then
  log_warn "backend/.env already exists. Leaving it untouched. Delete it first if you want install.sh to regenerate it from scratch."
else
  echo
  log_info "APP_KEY: does a PRODUCTION APP_KEY already exist for this application (e.g. from a prior Render/staging deployment that shares this database)?"
  if confirm "Paste an existing APP_KEY now to preserve session/signed-URL compatibility?"; then
    prompt_secret EXISTING_APP_KEY "Paste the existing APP_KEY (input hidden)"
    APP_KEY_VALUE="$EXISTING_APP_KEY"
  else
    APP_KEY_VALUE="base64:$(openssl rand -base64 32)"
    log_info "Generated a new APP_KEY. See FINDINGS.md — no persisted Crypt-encrypted data was found in this codebase, so this is safe, but it will invalidate any currently-active sessions/signed URLs from other environments sharing this DB."
  fi

  prompt_value SUPER_ADMIN_EMAIL_VAL "Platform Super Admin email (for the first-run super admin account)"
  SUPER_ADMIN_PASSWORD_VAL="$(random_secret 20)"
  log_info "Generated a random Super Admin password (not printed). Retrieve it with: sudo grep SUPER_ADMIN_PASSWORD ${ENV_FILE} — then rotate it after first login."

  APP_URL_VAL="https://api.cafesystemsyria.com"
  CORS_ORIGIN_VAL="https://admin.cafesystemsyria.com"

  install -m 640 -o "$APP_LINUX_USER" -g "$APP_LINUX_GROUP" /dev/null "$ENV_FILE"
  cat > "$ENV_FILE" <<EOF
APP_NAME="Cafe System 618"
APP_ENV=production
APP_DEBUG=false
APP_URL=${APP_URL_VAL}
APP_KEY=${APP_KEY_VALUE}
APP_LOCALE=en
APP_FALLBACK_LOCALE=en
BCRYPT_ROUNDS=12

LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=warning

TRUSTED_PROXIES=127.0.0.1
CORS_ALLOWED_ORIGINS=${CORS_ORIGIN_VAL}

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_APP_USER}
DB_PASSWORD=${DB_APP_PASSWORD}

SESSION_DRIVER=file
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

BROADCAST_CONNECTION=log
QUEUE_CONNECTION=sync
CACHE_STORE=file

MAIL_MAILER=log
MAIL_FROM_ADDRESS="hello@cafesystemsyria.com"
MAIL_FROM_NAME="Cafe System 618"

FILESYSTEM_DISK=local
PRODUCT_IMAGE_DISK=product-images-local

SUPER_ADMIN_NAME="Cafe 618 Platform Admin"
SUPER_ADMIN_EMAIL=${SUPER_ADMIN_EMAIL_VAL}
SUPER_ADMIN_PASSWORD=${SUPER_ADMIN_PASSWORD_VAL}
EOF
  chmod 640 "$ENV_FILE"
  chown "${APP_LINUX_USER}:${APP_LINUX_GROUP}" "$ENV_FILE"
  log_ok "Wrote ${ENV_FILE} (mode 640, owner ${APP_LINUX_USER}). No secret values were printed above."
  unset APP_KEY_VALUE EXISTING_APP_KEY DB_APP_PASSWORD SUPER_ADMIN_PASSWORD_VAL
fi

# storage:link (idempotent) + first boot caches
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" storage:link || true
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" config:clear
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" config:cache
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" view:cache
log_ok "storage:link created; config/view caches built. Route caching is deliberately skipped (see docker/cloud-entrypoint.sh comment — the route table hasn't been audited for cache compatibility)."

# =============================================================================
# 19. Nginx vhosts
# =============================================================================
log_info "== Step 19/27: Nginx vhosts =="
PHP_FPM_SOCKET="/run/php/php${PHP_MINOR}-fpm.sock"
sed "s#@@PHP_FPM_SOCKET@@#${PHP_FPM_SOCKET}#" "${SCRIPT_DIR}/nginx/api.conf" > /etc/nginx/sites-available/api.cafesystemsyria.com
cp "${SCRIPT_DIR}/nginx/admin.conf" /etc/nginx/sites-available/admin.cafesystemsyria.com

for site in api.cafesystemsyria.com admin.cafesystemsyria.com; do
  ln -sf "/etc/nginx/sites-available/${site}" "/etc/nginx/sites-enabled/${site}"
done
[[ -f /etc/nginx/sites-enabled/default ]] && rm -f /etc/nginx/sites-enabled/default

# Both shipped configs are HTTP-only (port 80) on purpose. Step 26 runs
# `certbot --nginx`, which edits these files in place to add the HTTPS server
# block and redirect — that is the standard, tested Certbot workflow, so this
# script never hand-maintains a parallel 443 block.
nginx -t
systemctl reload nginx
log_ok "Nginx vhosts installed for api.cafesystemsyria.com and admin.cafesystemsyria.com (HTTP only until step 26's Certbot run adds HTTPS)."

# =============================================================================
# 20. PHP-FPM pool
# =============================================================================
log_info "== Step 20/27: PHP-FPM pool =="
FPM_POOL_DIR="/etc/php/${PHP_MINOR}/fpm/pool.d"
cat > "${FPM_POOL_DIR}/cafe618.conf" <<EOF
[cafe618]
user = ${APP_LINUX_USER}
group = ${APP_LINUX_GROUP}
listen = ${PHP_FPM_SOCKET}
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 8
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 4
pm.max_requests = 500
catch_workers_output = yes
php_admin_value[error_log] = /var/log/cafe618/php-fpm-error.log
php_admin_flag[log_errors] = on
EOF
# Ubuntu's default www pool also binds a socket/port — disable it to avoid
# two pools competing, but don't delete it (idempotent re-runs, easy revert).
if [[ -f "${FPM_POOL_DIR}/www.conf" ]]; then
  mv "${FPM_POOL_DIR}/www.conf" "${FPM_POOL_DIR}/www.conf.disabled-by-cafe618" 2>/dev/null || true
fi
systemctl restart "php${PHP_MINOR}-fpm"
log_ok "PHP-FPM pool 'cafe618' listening on ${PHP_FPM_SOCKET} as ${APP_LINUX_USER}."

# =============================================================================
# 21. Queue (see FINDINGS.md — sync is correct; worker installed but dormant)
# =============================================================================
log_info "== Step 21/27: queue =="
cp "${SCRIPT_DIR}/supervisor/cafe-worker.conf" /etc/supervisor/conf.d/cafe-worker.conf
supervisorctl reread >/dev/null && supervisorctl update >/dev/null
log_ok "Supervisor queue-worker config installed but NOT started (autostart=false) — no queued jobs exist in this codebase today. See FINDINGS.md."

# =============================================================================
# 22. Scheduler
# =============================================================================
log_info "== Step 22/27: scheduler cron =="
CRON_LINE="* * * * * cd ${BACKEND_DIR} && php artisan schedule:run >> /var/log/cafe618/scheduler.log 2>&1"
( crontab -u "$APP_LINUX_USER" -l 2>/dev/null | grep -vF "artisan schedule:run" ; echo "$CRON_LINE" ) | crontab -u "$APP_LINUX_USER" -
touch /var/log/cafe618/scheduler.log && chown "$APP_LINUX_USER:$APP_LINUX_GROUP" /var/log/cafe618/scheduler.log
log_ok "Installed 'php artisan schedule:run' cron entry for ${APP_LINUX_USER} (currently a documented no-op — see FINDINGS.md)."

# =============================================================================
# 23. Next.js build + systemd service
# =============================================================================
log_info "== Step 23/27: Next.js build + systemd =="
cat > "${ADMIN_DIR}/.env.production" <<EOF
NEXT_PUBLIC_API_URL=https://api.cafesystemsyria.com/api/super-admin/v1
EOF
chown "$APP_LINUX_USER:$APP_LINUX_GROUP" "${ADMIN_DIR}/.env.production"
sudo -u "$APP_LINUX_USER" npm --prefix "${ADMIN_DIR}" run build

if [[ ! -d "${ADMIN_DIR}/.next/standalone" ]]; then
  fatal "next build did not produce .next/standalone — confirm next.config.ts still sets output: 'standalone'."
fi
# Standalone output needs the static assets + public/ copied alongside it.
cp -r "${ADMIN_DIR}/.next/static" "${ADMIN_DIR}/.next/standalone/.next/static"
[[ -d "${ADMIN_DIR}/public" ]] && cp -r "${ADMIN_DIR}/public" "${ADMIN_DIR}/.next/standalone/public"
chown -R "$APP_LINUX_USER:$APP_LINUX_GROUP" "${ADMIN_DIR}/.next"

NODE_BIN="$(command -v node)"
sed "s#@@NODE_BIN@@#${NODE_BIN}#" "${SCRIPT_DIR}/systemd/cafe-admin.service" > /etc/systemd/system/cafe-admin.service
systemctl daemon-reload
systemctl enable --now cafe-admin
log_ok "Super Admin built and running as systemd unit 'cafe-admin' on 127.0.0.1:3000."

# =============================================================================
# 24. Enable everything at boot
# =============================================================================
log_info "== Step 24/27: enable services at boot =="
systemctl enable nginx "php${PHP_MINOR}-fpm" postgresql supervisor cafe-admin cron >/dev/null 2>&1 || true
log_ok "nginx, php${PHP_MINOR}-fpm, postgresql, supervisor, cafe-admin, cron all enabled at boot."

# =============================================================================
# 25. Firewall
# =============================================================================
log_info "== Step 25/27: firewall =="
ufw allow OpenSSH >/dev/null 2>&1 || ufw allow 22/tcp >/dev/null 2>&1 || true
ufw allow 80/tcp >/dev/null 2>&1 || true
ufw allow 443/tcp >/dev/null 2>&1 || true
ufw deny 5432/tcp >/dev/null 2>&1 || true
ufw deny 3000/tcp >/dev/null 2>&1 || true
if ! ufw status | grep -q "Status: active"; then
  log_warn "UFW is not active. Enabling it now (SSH/80/443 are already allowed above)."
  ufw --force enable
fi
log_ok "Firewall: SSH/80/443 allowed; 5432 and 3000 explicitly denied from outside."
ufw status verbose || true

# =============================================================================
# 26. SSL (only if DNS already resolves)
# =============================================================================
log_info "== Step 26/27: SSL (Certbot) =="
THIS_VPS_IP="46.224.139.32"
SSL_READY=true
for domain in api.cafesystemsyria.com admin.cafesystemsyria.com; do
  if dns_resolves_to_this_host "$domain"; then
    RESOLVED_IP="$(dig +short A "$domain" | tail -1)"
    if [[ "$RESOLVED_IP" == "$THIS_VPS_IP" ]]; then
      log_ok "${domain} resolves to ${THIS_VPS_IP} — ready for Certbot."
    else
      log_warn "${domain} resolves to ${RESOLVED_IP:-<none>}, not ${THIS_VPS_IP}. Skipping SSL for this domain."
      SSL_READY=false
    fi
  else
    log_warn "${domain} does not resolve yet. Skipping SSL for this domain — create the A record, then re-run install.sh."
    SSL_READY=false
  fi
done

if [[ "$SSL_READY" == true ]]; then
  ensure_packages certbot python3-certbot-nginx
  certbot --nginx -d api.cafesystemsyria.com -d admin.cafesystemsyria.com \
    --non-interactive --agree-tos -m "admin@cafesystemsyria.com" --redirect \
    || log_warn "Certbot did not complete successfully — check 'certbot certificates' and re-run manually."
  systemctl list-timers | grep -qi certbot && log_ok "Certbot auto-renewal timer is active." || log_warn "Could not confirm certbot renewal timer — check 'systemctl list-timers | grep certbot'."
else
  log_warn "DNS is not fully pointed at ${THIS_VPS_IP} yet. Create these A records, then re-run: sudo bash deployment/finjan/install.sh"
  log_warn "  api.cafesystemsyria.com   -> ${THIS_VPS_IP}"
  log_warn "  admin.cafesystemsyria.com -> ${THIS_VPS_IP}"
fi

# =============================================================================
# 27. Health checks
# =============================================================================
log_info "== Step 27/27: health checks =="
save_state DEPLOYED_COMMIT "$DEPLOYED_COMMIT"
bash "${SCRIPT_DIR}/health-check.sh" || log_warn "Some health checks failed/are pending (expected if DNS/SSL isn't ready yet) — see output above."

echo
log_ok "install.sh finished. Deployed commit: ${DEPLOYED_COMMIT}"
log_info "Next steps: deployment/finjan/migrate-database.sh, then migrate-storage.sh, then re-run health-check.sh."
