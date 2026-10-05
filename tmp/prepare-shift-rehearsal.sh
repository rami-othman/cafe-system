#!/usr/bin/env bash
set -euo pipefail
live=/var/www/cafe-system-staging/backend
safety=/root/cafe618-safety/shift-fix-20261005
testroot=/root/cafe618-shift-fix-test
mkdir -p "$safety"
chmod 700 "$safety"
test ! -e "$safety/database.dump"
sudo -u postgres pg_dump -Fc cafe618_staging > "$safety/database.dump"
pg_restore -l "$safety/database.dump" > "$safety/database-catalog.txt"
cp -a "$live/.env" "$safety/backend.env"
test ! -e "$testroot"
mkdir "$testroot"
cp -a "$live/." "$testroot/"
sudo -u postgres createdb cafe618_shift_fix_test -O cafe618_app
sudo -u postgres pg_restore --no-owner -d cafe618_shift_fix_test < "$safety/database.dump"
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=cafe618_shift_fix_test/;s/^APP_ENV=.*/APP_ENV=testing/' "$testroot/.env"
rm -f "$testroot/bootstrap/cache/config.php"
cd "$testroot"
composer install --no-interaction --no-scripts --prefer-dist > "$safety/composer-test.log" 2>&1
echo "Backup validated: $safety/database.dump"
echo "Isolated test backend: $testroot"

