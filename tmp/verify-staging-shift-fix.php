<?php
$root = $argv[1] ?? '/root/cafe618-shift-fix-test';
if (!in_array($root, ['/root/cafe618-shift-fix-test','/var/www/cafe-system-staging/backend'],true)) throw new RuntimeException('Unexpected root');
require $root.'/vendor/autoload.php';
$app = require $root.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;
$database = DB::connection()->getDatabaseName();
if (!in_array($database,['cafe618_shift_fix_test','cafe618_staging'],true)) throw new RuntimeException('Wrong database');
$originalBalance = app(App\Services\FinancialAccountBalanceQuery::class)->summary(1,4869,locationId:12)['balance'];
$originalOrders = DB::table('orders')->count();
DB::beginTransaction();
try {
    $token = 'shift-fix-rollback-'.bin2hex(random_bytes(24));
    DB::table('api_tokens')->insert(['tenant_id'=>1,'user_id'=>5,'name'=>'shift-fix-rollback','token_hash'=>hash('sha256',$token),'expires_at'=>now()->addMinutes(5),'created_at'=>now(),'updated_at'=>now()]);
    $kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
    $call = function($method,$url,$body=[],$status=200) use($kernel,$token) {
        $req=Request::create($url,$method,[],[],[],['HTTP_ACCEPT'=>'application/json','CONTENT_TYPE'=>'application/json','HTTP_AUTHORIZATION'=>'Bearer '.$token],json_encode($body));
        $response=$kernel->handle($req);
        $payload=json_decode($response->getContent(),true);
        if ($response->getStatusCode()!==$status) throw new RuntimeException($url.' failed: '.$response->getStatusCode().' '.json_encode($payload,JSON_UNESCAPED_UNICODE));
        return $payload['data'];
    };
    $state=$call('GET','/api/v1/pos/state?branchId=5');
    if($state['terminal']['status']!=='open' || (int)$state['currentShift']['id']!==21) throw new RuntimeException('POS shift mismatch');
    $readiness=$call('GET','/api/v1/shifts/readiness?branchId=5');
    if((int)$readiness['drawer']['id']!==12 || $readiness['openShift']['id']!==21) throw new RuntimeException('Readiness drawer mismatch');
    $preview=$call('GET','/api/v1/shifts/21/close-preview');
    if(!$preview['period']['canClose'] || (float)$preview['period']['transferAmount']!==0.0) throw new RuntimeException('Zero close preview blocked');
    $version=DB::table('published_menu_versions')->where('tenant_id',1)->where('branch_id',5)->where('channel','pos')->where('status','current')->orderByDesc('id')->first();
    $menu=json_decode($version->payload_json,true);
    $product=$menu['menus'][0]['sections'][0]['products'][0];
    $options=[];
    foreach($product['modifierGroups'] ?? [] as $group) {
        if(($group['isRequired'] ?? false) || ($group['minSelections'] ?? 0)>0) {
            $available=array_values(array_filter($group['options'],fn($o)=>($o['isAvailable'] ?? true)));
            foreach(array_slice($available,0,max(1,$group['minSelections'] ?? 1)) as $option) $options[]=$option['id'];
        }
    }
    $order=$call('POST','/api/v1/orders',['branchId'=>5,'shiftId'=>21,'orderType'=>'takeaway','publishedMenuVersionId'=>$version->id,'items'=>[['productId'=>$product['productId'],'placementId'=>$product['placementId'],'variantId'=>$product['variants'][0]['id'],'modifierOptionIds'=>$options,'quantity'=>1]]],201);
    $id=$order['id'];
    $call('POST',"/api/v1/orders/$id/pay",['method'=>'cash','amount'=>$order['totals']['total'],'idempotencyKey'=>'shift-fix-test-cash-'.uniqid()]);
    $sale=DB::table('journal_entries as e')->join('journal_entry_lines as l','l.journal_entry_id','=','e.id')->where('e.source_type','pos_order')->where('e.source_id',$id)->where('l.financial_account_id',4869)->where('l.financial_location_id',12)->where('l.debit','>',0)->count();
    if($sale!==1) throw new RuntimeException('Sale did not post to 139');
    $call('POST',"/api/v1/orders/$id/refunds",['type'=>'full','reason'=>'Rollback-only verification','idempotencyKey'=>'shift-fix-test-refund-'.uniqid()],201);
    $afterRefund=app(App\Services\FinancialAccountBalanceQuery::class)->summary(1,4869,locationId:12)['balance'];
    if($afterRefund!==$originalBalance) throw new RuntimeException('Refund balance mismatch');
    if ($root === '/root/cafe618-shift-fix-test') {
        $counts=array_map(fn($line)=>['inventoryItemId'=>(int)$line['id'],'counted'=>max(0,(float)$line['theoretical']),'reason'=>'Rollback-only verification'],$preview['snapshot']['barCount']['lines']);
        $closed=$call('POST','/api/v1/shifts/21/close',['closingCash'=>'0.00','cashDifferenceReason'=>'other','cashDifferenceReasonDetail'=>'Rollback-only test of inherited historical discrepancy','barCountLines'=>$counts]);
        if($closed['closeTransferId']!==null) throw new RuntimeException('Zero close fabricated a transfer');
        $opened=$call('POST','/api/v1/shifts/current',['branchId'=>5,'openingCash'=>'500.00','fundOpeningCash'=>true],201);
        if((int)$opened['financialLocationId']!==12 || (float)$opened['openingCash']!==500.0) throw new RuntimeException('Funded opening mismatch');
        echo "Restored-copy only: zero close with explicit variance reason and funded 500 opening both passed.\n";
    }
    echo json_encode(['database'=>$database,'posShift'=>21,'drawer'=>12,'cashAccount'=>'139','originalBalance'=>$originalBalance,'zeroClosePreview'=>true,'cashSale'=>true,'cashRefund'=>true,'rollbackOnly'=>true],JSON_PRETTY_PRINT).PHP_EOL;
} finally {
    DB::rollBack();
}
if (DB::table('orders')->count()!==$originalOrders || app(App\Services\FinancialAccountBalanceQuery::class)->summary(1,4869,locationId:12)['balance']!==$originalBalance) throw new RuntimeException('Rollback verification failed');
echo "Verified: no test order or payment retained.\n";
