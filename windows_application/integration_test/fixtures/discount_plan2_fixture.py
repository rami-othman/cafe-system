"""Guarded, non-destructive fixtures for the existing Discount acceptance project."""
import argparse
import json
import subprocess
import urllib.error
import urllib.request
from pathlib import Path

COMPOSE = Path(__file__).with_name('discount_acceptance.compose.yml').resolve()
BASE = 'http://localhost:18100/api/v1/'


def php(code):
    result = subprocess.run(
        ['docker', 'compose', '-f', str(COMPOSE), 'exec', '-T', 'accept-backend',
         'php', 'artisan', 'tinker', '--execute', code],
        capture_output=True, text=True, check=True,
    )
    return result.stdout


def guard(database):
    identity = php("dump(app()->environment(), config('database.connections.pgsql.host'), DB::selectOne('select current_database() as name')->name);")
    assert all(f'"{value}"' in identity for value in ['testing', 'accept-postgres', database]), identity
    print(identity, flush=True)


def request(method, path, body=None, token=None):
    headers = {'Content-Type': 'application/json', 'Accept': 'application/json', 'X-Discount-Contract': '2'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(BASE + path, data=None if body is None else json.dumps(body).encode(), headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.load(response)['data']
    except urllib.error.HTTPError as error:
        # Never print request bodies, coupon text or raw Backend errors.
        try:
            payload = json.load(error)
            code = payload.get('code')
            safe_code = code if isinstance(code, str) and code.replace('_', '').isalnum() and code.isupper() else None
            fields = sorted(payload.get('errors', {}).keys())
        except (ValueError, TypeError, AttributeError):
            safe_code, fields = None, []
        raise RuntimeError(f'{method} {path}: HTTP {error.code}; code={safe_code}; fields={fields}') from None


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['identity', 'accounts', 'revoke', 'restore'])
    parser.add_argument('--database', default='cafe_discount_acceptance_testing', choices=['cafe_discount_acceptance_testing', 'cafe_system_618_testing'])
    args = parser.parse_args()
    guard(args.database)
    if args.action == 'accounts':
        print(php("dump(DB::table('users')->whereIn('email', ['owner@cafe618.local','manager@cafe618.local','cashier@cafe618.local'])->get(['email','role','is_active'])->toArray());"))
    if args.action in ['revoke', 'restore']:
        token = request('POST', 'auth/login', {'email': 'owner@cafe618.local', 'password': 'owner-local-dev'})['accessToken']
        record = Path('output/discount-plan2-manager-grants-before.json')
        if args.action == 'revoke':
            before = request('GET', 'discounts/role-permissions/manager', token=token)
            assert 'discounts.settings.manage' in before['permissions']
            record.write_text(json.dumps(before))
            permissions = [p for p in before['permissions'] if p != 'discounts.settings.manage']
        else:
            permissions = json.loads(record.read_text())['permissions']
        saved = request('PUT', 'discounts/role-permissions/manager', {'permissions': permissions}, token)
        assert sorted(saved['permissions']) == sorted(permissions)
        print(json.dumps(saved))
