"""Guarded external changes for actual UI acceptance; never a client override."""
import argparse
import json
import discount_plan2_fixture as fixture

parser = argparse.ArgumentParser()
parser.add_argument('action', choices=['bump-settings', 'zero-policy', 'paid-snapshot-replay'])
args = parser.parse_args()
fixture.guard('cafe_system_618_testing')
assert 'true' in fixture.php("dump(config('discount_engine.isolated_automatic'));"), 'Isolated Automatic required'
token = fixture.request('POST', 'auth/login', {
    'email': 'plan2-owner@acceptance.invalid', 'password': 'Plan2-acceptance-only',
})['accessToken']
def api(method, path, body=None):
    return fixture.request(method, path, body, token)
if args.action == 'bump-settings':
    settings = api('GET', 'cafe-configuration/discount-settings')
    version = settings.pop('version')
    settings.pop('engineReady')
    settings['expectedVersion'] = version
    saved = api('PUT', 'cafe-configuration/discount-settings', settings)
    print(json.dumps({'previousVersion': version, 'savedVersion': saved['version']}))
elif args.action == 'zero-policy':
    # A configured Manual policy replaces all historic ad_hoc zero-balance fixtures.
    settings = api('GET', 'cafe-configuration/discount-settings')
    version = settings.pop('version')
    settings.pop('engineReady')
    settings.update(expectedVersion=version, maximumTotalDiscountPercent='100')
    api('PUT', 'cafe-configuration/discount-settings', settings)
    name = 'D2 configured zero balance 20261005'
    policies = api('GET', 'discounts?perPage=100')
    existing = next((p for p in policies if p['name'] == name), None)
    policy = existing or api('POST', 'discounts', {
        'name': name, 'applicationMode': 'manual', 'priority': 900,
        'scope': 'order', 'type': 'percentage', 'value': 100,
        'isActive': True, 'appliesToAllBranches': True,
    })
    print(json.dumps({'configuredManualPolicyId': policy['id']}))
else:
    from pathlib import Path
    before = api('GET', 'orders/6/receipt')
    detail = api('GET', 'discounts/17')
    update = {key: detail[key] for key in ['name', 'applicationMode', 'priority', 'type', 'scope',
                                          'fixedAmountBasis', 'isActive', 'appliesToAllBranches', 'branchIds',
                                          'targetProductIds']}
    update['productVariantSelections'] = [
        {key: row[key] for key in ['productId', 'variantMode', 'variantIds']}
        for row in detail['productVariantSelections']]
    update['value'] = 8
    api('PATCH', 'discounts/17', update)
    after = api('GET', 'orders/6/receipt')
    assert before == after, 'Paid receipt changed after policy edit'
    transport = Path('output/discount-plan2-20261005-web-transport.txt').read_text(encoding='utf-16')
    proof = json.loads(next(line for line in transport.splitlines() if line.startswith('{')))
    payment = [r['payment'] for r in proof['requests'] if r['path'] == '/api/v1/orders/6/pay'][-1]
    result = api('POST', 'orders/6/pay', payment)
    Path('docs/verification/discount-plan2-20261005-paid-snapshot-replay.json').write_text(
        json.dumps({'receiptUnchanged': True, 'policyId': 17, 'newPolicyValue': 8,
                    'replayedIdentity': payment['idempotencyKey'], 'result': result}, indent=2), encoding='utf-8')
    print(json.dumps({'receiptUnchanged': True, 'replayCompleted': True}))
