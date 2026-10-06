import json,urllib.request,subprocess,sys
sys.stdout.reconfigure(encoding="utf-8")
from pathlib import Path
compose=Path(__file__).with_name('discount_acceptance.compose.yml').resolve()
identity=subprocess.run(['docker','compose','-f',str(compose),'exec','-T','accept-backend','php','artisan','tinker','--execute',"dump(app()->environment(), config('database.connections.pgsql.host'), DB::selectOne('select current_database() as name')->name);"],capture_output=True,text=True,check=True).stdout
assert all(value in identity for value in ['"testing"','"accept-postgres"','"cafe_discount_acceptance_testing"']),identity
print(identity,flush=True)
BASE='http://localhost:18100/api/v1/'
# Monetary expectation is recorded before any acceptance interaction.
expected={'subtotal':40,'fixedPerUnit':4,'selectedQuantity':2,'discount':8,'tax':2.56,'total':34.56}
Path('docs/verification/discount_acceptance_expected_2026-10-03.json').write_text(json.dumps(expected,indent=2))
def req(method,path,body=None,token=None):
 h={'Content-Type':'application/json','Accept':'application/json','X-App-Locale':'en'}
 if token:h['Authorization']='Bearer '+token
 r=urllib.request.Request(BASE+path,data=json.dumps(body).encode() if body is not None else None,headers=h,method=method)
 try:
  with urllib.request.urlopen(r) as v:return json.load(v)
 except urllib.error.HTTPError as e:raise RuntimeError(f'{method} {path}: {e.code} {e.read().decode()}')
token=req('POST','auth/login',{'email':'owner@cafe618.local','password':'owner-local-dev'})['data']['accessToken']
def api(method,path,body=None):return req(method,path,body,token)
# This script is only for the isolated project confirmed before migration.
existing={x['name']:x['id'] for x in api('GET','discounts/references/products?search=Acc&perPage=100')['data']}
ids={}
for name,variants in [('Acc Tea',[('Small',10),('Large',20),('XL',30)]),('Acc Cake',[('Slice',15),('Whole',25)]),('Acc Latte',[(f'Size {i}',10+i) for i in range(1,46)])]:
 data=api('GET',f"admin/catalog/products/{existing[name]}")['data'] if name in existing else api('POST','admin/catalog/products',{'name':name,'nameAr':name,'categoryId':2,'isActive':True,'isStockTracked':False,'variants':[{'name':n,'basePrice':price,'isDefault':i==0,'isActive':True,'sortOrder':i} for i,(n,price) in enumerate(variants)]})['data']
 api('PATCH',f"admin/catalog/products/{data['id']}",{'categoryId':2})
 ids[name]={'productId':data['id'],'variantIds':[v['id'] for v in data['variants']]}
for i in range(45):
 if f'Acc filler {i:02}' in existing:continue
 api('POST','admin/catalog/products',{'name':f'Acc filler {i:02}','isActive':True,'isStockTracked':False,'variants':[{'name':'Regular','basePrice':1,'isDefault':True,'isActive':True}]})
menus=api('GET','admin/menus?perPage=100&status=all')['data']
print('menus',menus,flush=True)
m=next((x['id'] for x in menus if x['name']=='Acceptance Menu'),None)
if m is None:m=api('POST','admin/menus',{'name':'Acceptance Menu','status':'draft'})['data']['id']
sections=api('GET',f'admin/menus/{m}/sections')['data']
s=next((x['id'] for x in sections if x['name']=='Acceptance'),None)
if s is None:s=api('POST',f'admin/menus/{m}/sections',{'name':'Acceptance','isActive':True})['data']['id']
placements=api('GET',f'admin/menu-sections/{s}/placements')['data']
for n in ['Acc Tea','Acc Cake']:
 if not any(x['productId']==ids[n]['productId'] for x in placements):api('POST',f'admin/menu-sections/{s}/placements',{'productId':ids[n]['productId'],'isVisible':True})
print('assignments',api('PUT','admin/menu-management/assignments',{'branchId':1,'channel':'pos','assignments':[{'menuId':m,'isActive':True}]}),flush=True)
api('PATCH',f'admin/menus/{m}',{'status':'active'})
validation=api('POST',f'admin/menus/{m}/validate',{'branchId':1,'channel':'pos'})
print('validation errors',validation['data']['errors'],flush=True)
print('published',api('POST','admin/menu-management/publish',{'branchId':1,'channel':'pos','menuIds':[m]}))
print('readiness',api('GET','shifts/readiness?branchId=1'))
if api('GET','shifts/current?branchId=1')['data'] is None:print('shift',api('POST','shifts/current',{'branchId':1,'openingCash':0}))
Path('docs/verification/discount_acceptance_fixture_2026-10-03.json').write_text(json.dumps({'ids':ids,'expected':{'subtotal':40,'fixedPerUnit':4,'selectedQuantity':2,'discount':8,'tax':2.56,'total':34.56}},indent=2))
print(ids)

