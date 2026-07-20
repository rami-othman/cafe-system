# Super Admin security

Only active, tenantless users with a platform role are accepted. Session IDs are HTTP-only Laravel cookies, login is throttled and generic, sessions regenerate after login, CSRF runs through the `web` middleware, and server-side permission checks protect all sensitive endpoints.
