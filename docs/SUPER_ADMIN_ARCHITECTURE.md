# Super Admin architecture

The Next.js application at `super_admin_web/` calls only Laravel at `/api/super-admin/v1`. Laravel sessions, platform permissions, SaaS data, and audit logs are the system of record. No Super Admin endpoint uses `TenantContext`.
