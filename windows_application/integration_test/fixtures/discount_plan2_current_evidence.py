"""Read-only, token-free records of the dedicated isolated acceptance tenant."""
import argparse
import json
from pathlib import Path
import discount_plan2_fixture as fixture

parser = argparse.ArgumentParser()
parser.add_argument('--order', type=int)
parser.add_argument('--label', required=True)
args = parser.parse_args()
fixture.guard('cafe_system_618_testing')
token = fixture.request('POST', 'auth/login', {
    'email': 'plan2-owner@acceptance.invalid', 'password': 'Plan2-acceptance-only',
})['accessToken']

def api(path):
    return fixture.request('GET', path, token=token)

policies = []
for row in api('discounts?perPage=100'):
    detail = api(f"discounts/{row['id']}")
    detail['codePresent'] = detail.get('code') is not None
    detail.pop('code', None)
    policies.append(detail)
record = {'label': args.label, 'database': 'cafe_system_618_testing',
          'capabilities': api('discount-capabilities'),
          'settings': api('cafe-configuration/discount-settings'), 'policies': policies}
if args.order:
    record.update(order=api(f'orders/{args.order}'),
                  state=api(f'orders/{args.order}/discount-state'))
    if record['order'].get('paymentStatus') == 'paid':
        record['receipt'] = api(f'orders/{args.order}/receipt')
    # IDs are parser integers. Only selected business effects are read;
    # no users, password hashes, sessions or tokens are included.
    code = f"""
    $tenant = DB::table('tenants')->where('slug','discount-plan2-live-20261004')->value('id');
    if (! $tenant || ! DB::table('orders')->where('tenant_id',$tenant)->where('id',{args.order})->exists()) throw new RuntimeException('Wrong acceptance order');
    $result = [];
    foreach (['discount_usages','sale_consumptions'] as $table) {{
        $result[$table] = DB::table($table)->where('tenant_id',$tenant)->where('order_id',{args.order})->get()->toArray();
    }}
    $result['journals'] = DB::table('journal_entries as e')->join('journal_entry_lines as l','l.journal_entry_id','=','e.id')
        ->where('e.tenant_id',$tenant)->where('e.source_type','pos_order')->where('e.source_id',{args.order})
        ->groupBy('e.id','e.source_type','e.status')->selectRaw('e.id,e.source_type,e.status,sum(l.debit)::text as debit,sum(l.credit)::text as credit')->get()->toArray();
    $result['tenantStockMovementCount'] = DB::table('stock_movements')->where('tenant_id',$tenant)->count();
    echo json_encode($result, JSON_THROW_ON_ERROR);
    """
    record['effects'] = json.loads(fixture.php(code))
path = Path('docs/verification') / f'discount-plan2-20261005-{args.label}.json'
path.write_text(json.dumps(record, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({'evidence': str(path), 'policies': [p['id'] for p in policies], 'order': args.order}))
