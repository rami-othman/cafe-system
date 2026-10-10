"""Prepare a dedicated tenant via real APIs on the existing isolated environment."""
import json
from pathlib import Path
import discount_plan2_fixture as fixture

fixture.guard('cafe_system_618_testing')
token = fixture.request('POST', 'auth/login', {
    'email': 'plan2-owner@acceptance.invalid', 'password': 'Plan2-acceptance-only',
})['accessToken']


def api(method, path, body=None):
    return fixture.request(method, path, body, token)


caps = api('GET', 'discount-capabilities')
assert caps['automaticPolicyCreationAvailable'] and not caps['engineReady']
# Operational discovery reflects the testing-only authority. Persisted cafe
# activation and public engine readiness must remain disabled independently.
assert caps['automaticEnabled']
assert not api('GET', 'cafe-configuration/discount-settings')['automaticEnabled']
branch = next(b['id'] for b in api('GET', 'branches') if b['name'] == 'Plan 2 branch')
categories = api('GET', 'admin/catalog/categories?perPage=100')
category = next((c['id'] for c in categories if c['name'] == 'Plan2 acceptance'), None)
if category is None:
    category = api('POST', 'admin/catalog/categories', {'name': 'Plan2 acceptance', 'isActive': True})['id']
products = {}
for name, price in [('Plan2 Tea', 10), ('Plan2 Cake', 15)]:
    references = api('GET', 'discounts/references/products?search=' + name.replace(' ', '%20') + '&perPage=100')
    existing = next((p for p in references if p['name'] == name), None)
    product = api('GET', f"admin/catalog/products/{existing['id']}") if existing else api('POST', 'admin/catalog/products', {
        'name': name, 'nameAr': name, 'categoryId': category, 'isActive': True, 'isStockTracked': False,
        'variants': [{'name': 'Regular', 'basePrice': price, 'isDefault': True, 'isActive': True}],
    })
    api('PATCH', f"admin/catalog/products/{product['id']}", {'categoryId': category})
    if name == 'Plan2 Tea' and len(product['variants']) == 1:
        api('POST', f"admin/catalog/products/{product['id']}/variants", {
            'name': 'Large', 'basePrice': 20, 'isDefault': False, 'isActive': True,
        })
    products[name] = {'productId': product['id'], 'variantId': product['variants'][0]['id']}
menus = api('GET', 'admin/menus?perPage=100&status=all')
menu = next((m['id'] for m in menus if m['name'] == 'Plan2 acceptance menu'), None)
if menu is None:
    menu = api('POST', 'admin/menus', {'name': 'Plan2 acceptance menu', 'status': 'draft'})['id']
sections = api('GET', f'admin/menus/{menu}/sections')
section = next((s['id'] for s in sections if s['name'] == 'Plan2 acceptance'), None)
if section is None:
    section = api('POST', f'admin/menus/{menu}/sections', {'name': 'Plan2 acceptance', 'isActive': True})['id']
placements = api('GET', f'admin/menu-sections/{section}/placements')
for product in products.values():
    if not any(p['productId'] == product['productId'] for p in placements):
        api('POST', f'admin/menu-sections/{section}/placements', {'productId': product['productId'], 'isVisible': True})
api('PATCH', f'admin/menus/{menu}', {'status': 'active'})
# Publication requires a branch/channel assignment, even when menuIds is sent.
# This branch belongs exclusively to the guarded Plan 2 acceptance tenant.
api('PUT', 'admin/menu-management/assignments', {
    'branchId': branch, 'channel': 'pos',
    'assignments': [{'menuId': menu, 'isActive': True}],
})
validation = api('POST', f'admin/menus/{menu}/validate', {'branchId': branch, 'channel': 'pos'})
assert validation.get('errorCount', 0) == 0, [entry.get('code') for entry in validation.get('errors', [])]
api('POST', 'admin/menu-management/publish', {'branchId': branch, 'channel': 'pos', 'menuIds': [menu]})
shift = api('GET', f'shifts/current?branchId={branch}')
if shift is None:
    shift = api('POST', 'shifts/current', {'branchId': branch, 'openingCash': 0})
methods = api('GET', 'finance/payment-methods?perPage=100')
if not any(m['type'] == 'card' and m['isActive'] for m in methods):
    bank = next(a for a in api('GET', 'finance/accounts?perPage=100') if a['code'] == '1030')
    api('POST', 'finance/payment-methods', {
        'code': 'PLAN2_CARD', 'name': 'Plan2 Card', 'type': 'card',
        'financialAccountId': bank['id'], 'isActive': True, 'sortOrder': 2,
    })
policies = {}
existing_policies = api('GET', 'discounts?perPage=100')
for name, value in [('Plan2 Tea', 4), ('Plan2 Cake', 3)]:
    label = name + ' automatic'
    existing = next((p for p in existing_policies if p['name'] == label), None)
    policy = api('GET', f"discounts/{existing['id']}") if existing else api('POST', 'discounts', {
        'name': label, 'applicationMode': 'automatic', 'code': None, 'priority': 10,
        'type': 'fixed', 'fixedAmountBasis': 'per_unit', 'scope': 'product', 'value': value,
        'isActive': True, 'appliesToAllBranches': True,
        'targetProductIds': [products[name]['productId']],
        'productVariantSelections': [{'productId': products[name]['productId'], 'variantMode': 'selected', 'variantIds': [products[name]['variantId']]}],
    })
    policies[name] = policy['id']
settings = api('GET', 'cafe-configuration/discount-settings')
version = settings.pop('version')
settings.pop('engineReady')
settings.update(expectedVersion=version, automaticEnabled=False, combinationMode='disjoint_items', maximumTotalDiscountPercent='20')
saved = api('PUT', 'cafe-configuration/discount-settings', settings)
assert not saved['automaticEnabled'] and not saved['engineReady']
record = {'database': 'cafe_system_618_testing', 'branchId': branch, 'products': products, 'policies': policies, 'settings': saved, 'capabilities': api('GET', 'discount-capabilities')}
Path('docs/verification/discount-plan2-automatic-fixture.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps({'branchId': branch, 'products': products, 'policies': policies, 'engineReady': False, 'automaticEnabled': False}))
