#!/usr/bin/env bash
set -euo pipefail
live=/var/www/cafe-system-staging
safety=/root/cafe618-safety/shift-fix-20261005
ui=/var/www/cafe18-staging-shift-fix-20261005
test -s /root/cafe618-shift-ui-rehearsal/windows_application/build/web/main.dart.js
test ! -e "$ui"
test ! -e "$safety/pre-apply.dump"
mkdir "$ui"
cp -a /root/cafe618-shift-ui-rehearsal/windows_application/build/web/. "$ui/"
chown -R cafe618:www-data "$ui"
find "$ui" -type d -exec chmod 755 {} \;
find "$ui" -type f -exec chmod 644 {} \;
cd "$live/backend"
php artisan down
trap 'cd /var/www/cafe-system-staging/backend; php artisan up' EXIT
sudo -u postgres pg_dump -Fc cafe618_staging > "$safety/pre-apply.dump"
pg_restore -l "$safety/pre-apply.dump" > "$safety/pre-apply-catalog.txt"
cd "$live"
tar -tf /tmp/shift-fix-code.tar > "$safety/backend-files.txt"
tar -cf "$safety/backend-original.tar" -T "$safety/backend-files.txt"
tar -tf /tmp/shift-fix-ui.tar > "$safety/frontend-files.txt"
tar -cf "$safety/frontend-source-original.tar" -T "$safety/frontend-files.txt"
readlink /var/www/cafe18-staging-root/cafe18 > "$safety/frontend-original-link.txt"
tar -xf /tmp/shift-fix-code.tar -C "$live"
tar -xf /tmp/shift-fix-ui.tar -C "$live"
install -m 644 /root/cafe618-shift-fix-test/app/Services/CashDrawerConsolidationService.php "$live/backend/app/Services/CashDrawerConsolidationService.php"
while IFS= read -r file; do
    if [[ "$file" == *.php ]]; then php -l "$live/$file"; fi
done < "$safety/backend-files.txt"
php -l "$live/backend/app/Services/CashDrawerConsolidationService.php"
php /tmp/run-staging-drawer-repair.php "$live/backend" --apply "$safety/pre-apply.dump" | tee "$safety/repair-result.json"
ln -s "$ui" /var/www/cafe18-staging-root/cafe18-shift-next
mv -Tf /var/www/cafe18-staging-root/cafe18-shift-next /var/www/cafe18-staging-root/cafe18
cd "$live/backend"
php artisan up
trap - EXIT
curl -k --fail --silent --show-error https://46.224.139.32:8443/cafe18/main.dart.js -o "$safety/published-main.dart.js"
cmp "$ui/main.dart.js" "$safety/published-main.dart.js"
sha256sum "$ui/main.dart.js"
echo 'Staging PHP, drawer consolidation, and frontend deployed. Production untouched.'
