"""Focused backend evidence for the three actual Web acceptance scenarios."""
import argparse
import json
from pathlib import Path
import discount_plan2_fixture as fixture
from discount_plan2_context_fixture import connect


def effects(order):
    # Parser integer and fixed slug only; never accept a tenant from the caller.
    return json.loads(fixture.php(f"""
    $tenant = DB::table('tenants')->where('slug','discount-plan2-live-20261004')->value('id');
    if (!$tenant || !DB::table('orders')->where('tenant_id',$tenant)->where('id',{order})->exists()) throw new RuntimeException('Wrong acceptance order');
    $result = [];
    foreach (['payments','discount_usages','sale_consumptions'] as $table) {{
        $result[$table] = DB::table($table)->where('tenant_id',$tenant)->where('order_id',{order})->count();
    }}
    $result['stock'] = DB::table('stock_balances')->where('tenant_id',$tenant)->get(['warehouse_id','inventory_item_id','quantity_on_hand','average_unit_cost'])->toArray();
    $result['movements'] = DB::table('stock_movements')->where('tenant_id',$tenant)->get(['id','type','quantity','unit_cost'])->toArray();
    $result['journals'] = DB::table('journal_entries as e')->join('journal_entry_lines as l','l.journal_entry_id','=','e.id')
        ->where('e.tenant_id',$tenant)->where('e.source_type','pos_order')->where('e.source_id',{order})
        ->groupBy('e.id','e.source_type','e.status')->selectRaw('e.id,e.source_type,e.status,sum(l.debit)::text as debit,sum(l.credit)::text as credit')->get()->toArray();
    echo json_encode($result, JSON_THROW_ON_ERROR);
    """))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['snapshot', 'reject-quote', 'replay', 'branch-check'])
    parser.add_argument('--order', required=True, type=int)
    parser.add_argument('--quote')
    parser.add_argument('--held-order', type=int)
    args = parser.parse_args()
    token = connect()
    def api(method, path, body=None):
        return fixture.request(method, path, body, token)
    before = effects(args.order)
    detail = api('GET', f'orders/{args.order}')
    record = {'action': args.action, 'order': detail,
              'state': api('GET', f'orders/{args.order}/discount-state'), 'effectsBefore': before}
    if args.action == 'reject-quote':
        assert args.quote and detail['customer'] is None
        method = next(m for m in api('GET','finance/payment-methods?perPage=100') if m['type']=='cash' and m['isActive'])
        try:
            api('POST', f'orders/{args.order}/pay', {
                'quoteId': args.quote, 'paymentMethodId': method['id'], 'method': 'cash',
                'amount': '9.72', 'idempotencyKey': f'd2-context-old-customer-quote-{args.order}',
            })
        except RuntimeError as error:
            record['rejection'] = str(error)
            assert 'HTTP 422' in str(error)
            assert any(code in str(error) for code in ['DISCOUNT_CUSTOMER_REQUIRED','DISCOUNT_CUSTOMER_NOT_ELIGIBLE','ORDER_TOTAL_CHANGED'])
        else:
            raise AssertionError('Old customer quote was accepted')
        after = effects(args.order)
        assert before == after and before['payments'] == 0 and before['sale_consumptions'] == 0 and before['discount_usages'] == 0
        record['effectsAfter'] = after
    elif args.action == 'branch-check':
        fixture_ids = json.loads(Path('docs/verification/discount-plan2-context-fixture.json').read_text())
        assert args.held_order and detail['branchId'] == fixture_ids['branchIds'][1]
        held = api('GET', f'orders/{args.held_order}')
        assert held['branchId'] == fixture_ids['branchIds'][0] and held['status'] == 'held'
        record['heldOrder'] = held
        record['capabilities'] = api('GET', 'discount-capabilities')
        assert record['capabilities']['supportsPaymentQuote'] and not record['capabilities']['engineReady']
        assert not api('GET', 'cafe-configuration/discount-settings')['automaticEnabled']
        try:
            api('POST', f'orders/{args.order}/discounts/preview', {
                'action': 'apply', 'intent': {'source': 'configured_manual',
                    'discountId': fixture_ids['policies']['D2 branch restricted']},
            })
        except RuntimeError as error:
            record['rejection'] = str(error)
            assert 'HTTP 422' in str(error) and 'DISCOUNT_BRANCH_NOT_ELIGIBLE' in str(error)
        else:
            raise AssertionError('Branch A policy was accepted at B')
        quotes = json.loads(fixture.php(f"""
            echo json_encode(DB::table('discount_payment_quotes')->where('order_id',{args.order})
                ->where('tenant_id',{fixture_ids['tenantId']})->orderByDesc('id')->first(['identity','result']), JSON_THROW_ON_ERROR);
        """))
        assert quotes and quotes['identity'] != args.quote
        record['newBranchQuote'] = quotes
        after = effects(args.order)
        assert before == after and before['payments'] == 0 and before['sale_consumptions'] == 0 and before['discount_usages'] == 0
        record['effectsAfter'] = after
    elif args.action == 'replay':
        assert args.quote and detail['paymentStatus'] == 'paid'
        payment = detail['payments'][0]
        method = next(m for m in api('GET','finance/payment-methods?perPage=100')
                      if m['type'] == payment['method'] and m['isActive'])
        record['receiptBefore'] = api('GET', f'orders/{args.order}/receipt')
        record['replayResult'] = api('POST', f'orders/{args.order}/pay', {
            'quoteId': args.quote, 'paymentMethodId': method['id'], 'method': payment['method'],
            'amount': '9.72', 'idempotencyKey': payment['idempotencyKey'],
        })
        after = effects(args.order)
        assert before == after
        record['receiptAfter'] = api('GET', f'orders/{args.order}/receipt')
        assert record['receiptBefore'] == record['receiptAfter']
        record['effectsAfter'] = after
    path = Path('docs/verification') / f'discount-plan2-context-{args.action}-{args.order}.json'
    path.write_text(json.dumps(record, indent=2, ensure_ascii=False), encoding='utf-8')
    print(json.dumps({'evidence': str(path), 'effects': before, 'rejection': record.get('rejection')}))
