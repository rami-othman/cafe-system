"""Customer/branch/stock acceptance fixtures, scoped to the isolated test tenant."""
import json
import urllib.error
import urllib.request
import argparse
from pathlib import Path
import discount_plan2_fixture as fixture


def connect():
    fixture.guard('cafe_system_618_testing')
    identity = fixture.php("dump(config('discount_engine.isolated_automatic')); dump(DB::table('tenants')->where('slug','discount-plan2-live-20261004')->value('id'));")
    assert 'true' in identity
    token = fixture.request('POST', 'auth/login', {
        'email': 'plan2-owner@acceptance.invalid', 'password': 'Plan2-acceptance-only',
    })['accessToken']
    return token


def prepare(token):
    def api(method, path, body=None):
        headers = {'Content-Type': 'application/json', 'Accept': 'application/json',
                   'Authorization': 'Bearer ' + token, 'X-Discount-Contract': '2'}
        request = urllib.request.Request(fixture.BASE + path, headers=headers, method=method,
                                        data=None if body is None else json.dumps(body).encode())
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)['data']
        except urllib.error.HTTPError as error:
            payload = json.load(error)
            # Validation metadata only, no request bodies or session material.
            print(json.dumps({'path': path, 'status': error.code, 'errors': payload.get('errors', {})}))
            raise RuntimeError(f'Fixture API rejected {method} {path}: {error.code}') from None

    # Confirm session ownership against the fixed acceptance-only slug before
    # even an idempotent write. No operational tenant is selected by an ID flag.
    tenant = fixture.php("echo DB::table('tenants')->where('slug','discount-plan2-live-20261004')->value('id');")
    owner = fixture.php("echo DB::table('users')->where('email','plan2-owner@acceptance.invalid')->value('tenant_id');")
    assert tenant.strip() == owner.strip() and tenant.strip().isdigit()
    branches = api('GET', 'branches')
    first = next(b for b in branches if b['name'] == 'Plan 2 branch')
    second = next((b for b in branches if b['name'] == 'D2 context branch B'), None)
    if second is None:
        second = api('POST', 'cafe-configuration/branches', {
            'name': 'D2 context branch B', 'timezone': 'Asia/Damascus',
        })
    customers = api('GET', 'customers?search=D2%20context&perPage=100')
    customer = next((c for c in customers if c['name'] == 'D2 context customer'), None)
    if customer is None:
        customer = api('POST', 'customers/quick-create', {
            'name': 'D2 context customer', 'phone': '0999000618',
        })
    categories = api('GET', 'admin/catalog/categories?perPage=100')
    category = next((c for c in categories if c['name'] == 'D2 context'), None)
    if category is None:
        category = api('POST', 'admin/catalog/categories', {'name': 'D2 context', 'isActive': True})
    refs = api('GET', 'discounts/references/products?search=D2%20Tracked&perPage=100')
    product = next((p for p in refs if p['name'] == 'D2 Tracked Tea'), None)
    if product is None:
        product = api('POST', 'admin/catalog/products', {
            'name': 'D2 Tracked Tea', 'nameAr': 'D2 Tracked Tea', 'categoryId': category['id'],
            'isActive': True, 'isStockTracked': True,
            'variants': [{'name': 'Regular', 'basePrice': 10, 'isDefault': True, 'isActive': True}],
        })
    product = api('GET', f"admin/catalog/products/{product['id']}")
    items = api('GET', 'inventory/items?perPage=100&search=D2%20raw%20tea')['items']
    item = next((i for i in items if i['nameAr'] == 'D2 raw tea'), None)
    if item is None:
        item = api('POST', 'inventory/items', {'nameAr': 'D2 raw tea', 'itemType': 'raw_material',
                                            'unit': 'piece', 'isActive': True})
    recipe = api('GET', f"admin/catalog/products/{product['id']}/recipe")
    if not recipe or not recipe.get('components'):
        api('PUT', f"admin/catalog/products/{product['id']}/recipe", {
            'components': [{'materialId': item['id'], 'quantity': 1, 'unitCode': 'piece'}],
        })
    warehouse = next(w for w in api('GET', 'warehouses') if w['branchId'] == first['id'] and w['isActive'])
    item_detail = api('GET', f"inventory/items/{item['id']}")
    if warehouse['id'] not in item_detail['warehouseIds']:
        api('PATCH', f"inventory/items/{item['id']}", {
            **{key: item_detail[key] for key in ['nameAr', 'itemType', 'unit', 'isActive']},
            'warehouseIds': [*item_detail['warehouseIds'], warehouse['id']],
        })
    api('POST', 'inventory/movements', {
        'warehouseId': warehouse['id'], 'itemId': item['id'], 'type': 'stock_in',
        'branchId': first['id'],
        'quantity': '20', 'unitCost': '2', 'reason': 'D2 context fixture opening stock',
        'idempotencyKey': 'd2-context-opening-stock-20261006',
    })
    policies = api('GET', 'discounts?perPage=100')
    policy_ids = {}
    for name, restriction in [
        ('D2 customer restricted', {'customerEligibilityMode': 'selected_customers', 'customerIds': [customer['id']]}),
        ('D2 branch restricted', {'appliesToAllBranches': False, 'branchIds': [first['id']]}),
    ]:
        policy = next((p for p in policies if p['name'] == name), None)
        if policy is None:
            policy = api('POST', 'discounts', {
                'name': name, 'applicationMode': 'manual', 'type': 'percentage', 'scope': 'order',
                'value': 10, 'isActive': True, 'appliesToAllBranches': True, **restriction,
            })
        policy_ids[name] = policy['id']
    menus = api('GET', 'admin/menus?perPage=100&status=all')
    menu = next((m for m in menus if m['name'] == 'D2 context menu'), None)
    if menu is None:
        menu = api('POST', 'admin/menus', {'name': 'D2 context menu', 'status': 'draft'})
    sections = api('GET', f"admin/menus/{menu['id']}/sections")
    section = next((s for s in sections if s['name'] == 'D2 context'), None)
    if section is None:
        section = api('POST', f"admin/menus/{menu['id']}/sections", {'name': 'D2 context', 'isActive': True})
    placements = api('GET', f"admin/menu-sections/{section['id']}/placements")
    if not any(p['productId'] == product['id'] for p in placements):
        api('POST', f"admin/menu-sections/{section['id']}/placements", {'productId': product['id'], 'isVisible': True})
    if menu['status'] != 'active':
        api('PATCH', f"admin/menus/{menu['id']}", {'status': 'active'})
    for branch in [first, second]:
        api('PUT', 'admin/menu-management/assignments', {
            'branchId': branch['id'], 'channel': 'pos',
            'assignments': [{'menuId': menu['id'], 'isActive': True}],
        })
        validation = api('POST', f"admin/menus/{menu['id']}/validate", {'branchId': branch['id'], 'channel': 'pos'})
        assert validation.get('errorCount', 0) == 0
        api('POST', 'admin/menu-management/publish', {'branchId': branch['id'], 'channel': 'pos', 'menuIds': [menu['id']]})
        if api('GET', f"shifts/current?branchId={branch['id']}") is None:
            api('POST', 'shifts/current', {'branchId': branch['id'], 'openingCash': 0})
    record = {'tenantId': int(tenant.strip()), 'branchIds': [first['id'], second['id']],
              'customerId': customer['id'], 'productId': product['id'],
              'variantId': product['variants'][0]['id'], 'inventoryItemId': item['id'], 'warehouseId': warehouse['id'], 'policies': policy_ids}
    Path('docs/verification/discount-plan2-context-fixture.json').write_text(json.dumps(record, indent=2))
    print(json.dumps(record))
    return record


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['check', 'prepare'])
    args = parser.parse_args()
    token = connect()
    if args.action == 'prepare':
        prepare(token)
        raise SystemExit(0)
    record = json.loads(Path('docs/verification/discount-plan2-context-fixture.json').read_text())
    def read(path):
        return fixture.request('GET', path, token=token)
    branches = read('branches')
    assert all(any(b['id'] == branch and b['isActive'] for b in branches) for branch in record['branchIds'])
    assert read(f"admin/catalog/products/{record['productId']}")['isStockTracked']
    assert read(f"admin/catalog/products/{record['productId']}/recipe")['components']
    item = read(f"inventory/items/{record['inventoryItemId']}")
    assert record['warehouseId'] in item['warehouseIds'] and float(item['totalQuantity']) > 0
    for branch in record['branchIds']:
        readiness = read(f'shifts/readiness?branchId={branch}')
        current = read(f'shifts/current?branchId={branch}')
        assert current is not None and current['status'] == 'open'
        assert readiness['drawer'] and readiness['closeDestination']
    customer_policy = read(f"discounts/{record['policies']['D2 customer restricted']}")
    assert customer_policy['customerEligibilityMode'] == 'selected_customers'
    assert record['customerId'] in customer_policy['customerIds']
    branch_policy = read(f"discounts/{record['policies']['D2 branch restricted']}")
    assert branch_policy['branchIds'] == [record['branchIds'][0]] and not branch_policy['appliesToAllBranches']
    print(json.dumps({'fixtureChecks': 'passed', 'ids': record, 'stockQuantity': item['totalQuantity']}))
