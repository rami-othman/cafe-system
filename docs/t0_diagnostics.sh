#!/usr/bin/env bash
# T0 diagnostics — read-only. No UPDATE/DELETE/INSERT anywhere in this script.
# Run this on the production server, then send back t0_results.txt.
#
# See docs/CLIENT_FIXES_PLAN_2026-09-28.md section T0 for what each block checks.

set -uo pipefail

# ---- Fill these in before running ----------------------------------------
BACKEND_DIR="/var/www/cafe18/backend"     # backend Laravel root on the server
WEB_JS_FILE="/var/www/cafe18/main.dart.js" # deployed Flutter web build
NGINX_ACCESS_LOG="/var/log/nginx/access.log" # rotated copies: access.log.1, .gz, ...
DB_NAME="cafe18"
DB_USER="cafe18"
DB_HOST="127.0.0.1"
DB_PORT="5432"
# export PGPASSWORD or rely on ~/.pgpass — do not hardcode the password here.
ITEM_NAME="اسم المادة هنا"                 # T0 bullet 6: material to inspect
# ---------------------------------------------------------------------------

OUT_FILE="$(dirname "$0")/t0_results.txt"
: > "$OUT_FILE"

log_section() {
    {
        echo ""
        echo "===================================================================="
        echo "$1"
        echo "===================================================================="
    } >> "$OUT_FILE"
}

# $1 = SQL to run (no -c, no leading psql flags). Any extra args are passed
# through to psql (e.g. -v item_name=...). Read-only guard checks the SQL
# text itself and the query is sent over stdin inside a READ ONLY transaction.
psql_ro() {
    local sql="$1"
    shift || true
    if echo "$sql" | grep -qiE '\b(update|delete|insert|drop|alter|truncate|grant|revoke)\b'; then
        echo "REFUSED: query looks like a write statement, skipping." >> "$OUT_FILE"
        return 0
    fi
    {
        PGOPTIONS='-c statement_timeout=30000' psql \
            -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            --single-transaction -v ON_ERROR_STOP=0 "$@" <<SQL
SET TRANSACTION READ ONLY;
$sql
SQL
    } >> "$OUT_FILE" 2>&1 || true
}

# --- 1. Deployed web build version ----------------------------------------
log_section "1) نسخة الويب — عدد ظهور نص 'لا تتوفر بيانات استخدام الوصفات' في main.dart.js"
if [ -f "$WEB_JS_FILE" ]; then
    grep -c "لا تتوفر بيانات استخدام الوصفات" "$WEB_JS_FILE" >> "$OUT_FILE" 2>&1 || echo "0" >> "$OUT_FILE"
else
    echo "ملف $WEB_JS_FILE غير موجود — تحقق من المسار." >> "$OUT_FILE"
fi

# --- 2. Shift-close / daily-closing close requests from the nginx access log
log_section "2) طلبات إغلاق الوردية/الإغلاق اليومي من سجل nginx (آخر 50 سطر) + توزيع status code"
if ls "$NGINX_ACCESS_LOG"* >/dev/null 2>&1; then
    MATCHES="$(zgrep -hE 'POST [^ ]*/shifts/[0-9]+/close|POST [^ ]*/daily-closings/[0-9]+/close' "$NGINX_ACCESS_LOG"* 2>/dev/null || true)"
    if [ -n "$MATCHES" ]; then
        echo "$MATCHES" | awk '{print $4, $7, $9}' | tail -50 >> "$OUT_FILE"
        {
            echo ""
            echo "توزيع status code:"
        } >> "$OUT_FILE"
        echo "$MATCHES" | awk '{print $9}' | sort | uniq -c | sort -rn >> "$OUT_FILE"
    else
        echo "(لا طلبات مطابقة بسجل nginx)" >> "$OUT_FILE"
    fi
else
    echo "لا يوجد ملف $NGINX_ACCESS_LOG (أو نسخه المدوَّرة) — تحقق من المسار." >> "$OUT_FILE"
fi

log_section "2ب) أخطاء production.ERROR من laravel*.log (ثانوي — ValidationException لا تُسجَّل هنا)"
if ls "$BACKEND_DIR"/storage/logs/laravel*.log >/dev/null 2>&1; then
    grep "production.ERROR" "$BACKEND_DIR"/storage/logs/laravel*.log 2>/dev/null | tail -50 >> "$OUT_FILE" || echo "(لا نتائج)" >> "$OUT_FILE"
else
    echo "لا يوجد ملفات laravel*.log تحت $BACKEND_DIR/storage/logs" >> "$OUT_FILE"
fi

# --- 3. Closed shifts in the last 21 days, with their close/transfer info -
log_section "3) ورديات مُغلقة آخر 21 يوم (SELECT فقط)"
psql_ro "
SELECT id, shift_number, closed_at, business_date, expected_cash, closing_cash,
       closing_float_amount, close_transfer_id, close_destination_financial_location_id, close_type
FROM shifts
WHERE status = 'closed' AND closed_at > now() - interval '21 days'
ORDER BY closed_at DESC;
"

# --- 4. Close transfers whose transfer_date differs from the shift's day --
log_section "4) تحويلات إغلاق بتاريخ مختلف عن يوم الوردية (SELECT فقط)"
psql_ro "
SELECT s.shift_number, s.business_date, s.closed_at::date AS closed_day, t.transfer_date, t.amount
FROM shifts s JOIN cash_transfers t ON t.id = s.close_transfer_id
WHERE t.transfer_date <> COALESCE(s.business_date, s.closed_at::date);
"

# --- 6. Material lookup + which recipes reference it ----------------------
log_section "6) المادة '$ITEM_NAME' ونسخها المحتملة + عدد الوصفات المرتبطة بكل نسخة (SELECT فقط)"
psql_ro "
SELECT id, name_ar, sku, owner_branch_id, unit FROM inventory_items WHERE name_ar ILIKE '%' || :'item_name' || '%';
" -v item_name="$ITEM_NAME"
psql_ro "
SELECT vrc.inventory_item_id, count(*)
FROM variant_recipe_components vrc
JOIN inventory_items i ON i.id = vrc.inventory_item_id
WHERE i.name_ar ILIKE '%' || :'item_name' || '%'
GROUP BY 1;
" -v item_name="$ITEM_NAME"

echo "" >> "$OUT_FILE"
echo "تم. راجع $OUT_FILE" >> "$OUT_FILE"
echo "Done. Results in $OUT_FILE"
