# Cafe System 618 Phase 1 Backend Database Design

## Scope

Create a Docker-only Laravel backend workspace and the Phase 1 PostgreSQL
database. This phase excludes frontend code, API controllers, business logic,
full accounting, and offline synchronization.

## Runtime

The root `docker-compose.yml` defines:

- A custom `backend` PHP CLI service with Composer and `pdo_pgsql`.
- A PostgreSQL 16 `postgres` service with a persistent Docker volume.
- A bind mount from `./backend` to `/var/www/html`.

Laravel uses `DB_HOST=postgres` because containers communicate using the
Compose service name. Host PHP and Composer installations are not required.

## Database

Laravel migrations create these tables in dependency order:

1. tenants
2. branches
3. users
4. user_branches
5. categories
6. products
7. cafe_tables
8. customers
9. shifts
10. orders
11. order_items
12. payments
13. discounts
14. discount_targets
15. order_discounts
16. loyalty_accounts
17. loyalty_transactions
18. warehouses
19. inventory_items
20. stock_movements
21. activity_logs

Business tables include `tenant_id`. Operational tables include `branch_id`
where branch context is needed. Money uses `decimal(12,2)` and stock quantities
use `decimal(12,3)`. Statuses remain strings. Important mutable business records
use soft deletes.

Historical records do not cascade-delete. Nullable historical references use
`nullOnDelete()` where appropriate. Required parent references use restrictive
foreign keys.

## Seed Data

`DatabaseSeeder` creates the Cafe 6:18 tenant, Main Branch, owner and cashier
users, four categories, five products, four cafe tables, one warehouse, four
inventory items, and the OPEN10 opening discount.

## Verification

The database setup is accepted when this command completes successfully:

```bash
docker compose exec backend php artisan migrate:fresh --seed
```
