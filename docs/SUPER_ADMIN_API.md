# Super Admin API

Base URL: `/api/super-admin/v1`. All responses use `{data, meta?}` and all
routes except CSRF/login require an active platform-admin Laravel session.

## Authentication

- `GET /auth/csrf`
- `POST /auth/login`
- `POST /auth/logout`
- `GET /auth/me`

`/auth/me` returns the signed-in administrator, platform roles, and effective
permissions. The web application calls it before rendering protected routes.

## Dashboard and tenants

- `GET /dashboard?from=&to=&timezone=` - KPIs, alerts, trends, subscription
  mix, currency-separated sales, recent tenants, and recent activity.
- `GET /tenants?search=&status=&plan=&page=&perPage=`
- `POST /tenants`
- `GET /tenants/{tenant}`
- `PUT /tenants/{tenant}/status`

## Platform operations

- `GET /branches?tenantId=&search=` / `PUT /branches/{branch}`
- `GET /tenant-users?tenantId=&search=` / `PUT /tenant-users/{user}`
- `GET /plans` / `POST /plans` / `PUT /plans/{plan}`
- `GET /subscriptions?status=&endingBefore=` / `PUT /subscriptions/{subscription}`
- `GET /analytics/overview?from=&to=`
- `GET /audit-logs?action=&tenantId=`
- `GET /announcements` / `POST /announcements` / `PUT /announcements/{announcement}`
- `GET /system/health`
- `GET /settings` / `PUT /settings/{setting}`
- `GET /platform-admins`
- `GET /exports/tenants` - immediate CSV export with an audit event.

All mutations are permission-protected, throttled, and record a platform audit
event. Status-changing mutations require a reason so operators can understand
who changed the platform state and why.
