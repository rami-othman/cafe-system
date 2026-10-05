<?php
require '/var/www/cafe-system-staging/backend/vendor/autoload.php';
$app = require '/var/www/cafe-system-staging/backend/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\DB;
if (!app()->environment('staging') || DB::connection()->getDatabaseName() !== 'cafe618_staging') throw new RuntimeException('Wrong target');
$r=[];
foreach (['payments','payment_refunds','cash_transfers','shift_cash_movements'] as $t) $r[$t] = DB::table($t)->where('tenant_id',1)->orderByDesc('id')->limit(12)->get();
$r['journals']=DB::table('journal_entries')->where('tenant_id',1)->orderByDesc('id')->limit(8)->get();
$r['audit']=DB::table('activity_logs')->where('tenant_id',1)->where(fn($q)=>$q->where('entity_type','branch')->where('entity_id',5)->orWhere('action','like','%cash%')->orWhere('action','like','%shift%'))->orderByDesc('id')->limit(15)->get(['id','action','entity_type','entity_id','before_state','after_state','created_at']);
echo json_encode($r,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR);
