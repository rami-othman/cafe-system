# Cafe System 618 Backend

Cafe System 618 is a multi-tenant cafe management system. This repository
currently contains the Phase 1 Laravel backend workspace and PostgreSQL
database schema.

The backend runs entirely through Docker. Teammates do not need PHP, Composer,
or PostgreSQL installed on the host machine.

## Current Scope

Phase 1 includes:

- Dockerized Laravel backend workspace
- PostgreSQL 16 database
- Multi-tenant database migrations
- Demo seed data
- Basic Laravel health check and tests

Phase 1 does not include:

- Flutter desktop application
- Super Admin web dashboard
- API controllers or API endpoints
- Business logic
- Full accounting
- Offline SQLite cache or synchronization

## Architecture

| Service | Purpose |
| --- | --- |
| `backend` | Custom PHP 8.4 container running Laravel on port 8000, with Composer and the PostgreSQL PHP extension |
| `postgres` | PostgreSQL 16 database with a persistent Docker volume |

The Laravel project is stored in `/backend` on the host and mounted at
`/var/www/html` inside the backend container.

The backend service runs Laravel's development server on port `8000` for the
Flutter POS API integration.

## Requirements

Install:

- Docker Desktop
- Docker Compose, included with current Docker Desktop releases
- Git

You do not need to install PHP, Composer, or PostgreSQL locally.

## First-Time Setup

Run all commands from the repository root, where `docker-compose.yml` is
located.

### PowerShell

```powershell
Copy-Item backend/.env.example backend/.env
docker compose up -d --build
docker compose exec backend composer install
docker compose exec backend php artisan key:generate
docker compose exec backend php artisan migrate:fresh --seed
```

### Bash

```bash
cp backend/.env.example backend/.env
docker compose up -d --build
docker compose exec backend composer install
docker compose exec backend php artisan key:generate
docker compose exec backend php artisan migrate:fresh --seed
```

Confirm that both containers are running:

```bash
docker compose ps
```

Confirm that all migrations ran:

```bash
docker compose exec backend php artisan migrate:status
```

## Daily Commands

Start or stop the containers:

```bash
docker compose up -d
docker compose down
```

Check container status or view logs:

```bash
docker compose ps
docker compose logs -f
```

Confirm the API is reachable from Windows:

```bash
curl http://127.0.0.1:8000/api/v1/branches
```

Open a shell inside the backend container:

```bash
docker compose exec backend sh
```

Run Composer:

```bash
docker compose exec backend composer install
docker compose exec backend composer validate --strict
```

Run Artisan:

```bash
docker compose exec backend php artisan migrate:status
docker compose exec backend php artisan migrate
docker compose exec backend php artisan db:seed
```

Reset the local database and reload demo data:

```bash
docker compose exec backend php artisan migrate:fresh --seed
```

Warning: `migrate:fresh --seed` deletes all existing local database tables and
data before recreating them.

Run tests and formatting checks:

```bash
docker compose exec backend php artisan test
docker compose exec backend ./vendor/bin/pint --test
```

## Database Configuration

Laravel uses these values from `backend/.env`:

```dotenv
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=cafe_system_618
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

Inside Docker, Laravel connects to `DB_HOST=postgres` because `postgres` is the
Docker Compose service name.

To connect from a database client running on your host machine, use:

```text
Host: 127.0.0.1
Port: 5432
Database: cafe_system_618
Username: postgres
Password: postgres
```

## Demo Accounts

The demo seeder creates these local-development users:

| Role | Email | Password |
| --- | --- | --- |
| Owner | `owner@cafe618.local` | `password` |
| Cashier | `cashier@cafe618.local` | `password` |

## Demo Data

Running `php artisan migrate:fresh --seed` creates:

- Tenant: `Cafe 6:18`
- Branch: `Main Branch`
- Categories: Hot Drinks, Cold Drinks, Desserts, Food
- Products: Espresso, Cappuccino, Latte, Iced Coffee, Cheesecake
- Cafe tables: Table 1 through Table 4
- Warehouse: `Main Warehouse`
- Inventory items: Coffee Beans, Milk, Sugar, Cups
- Discount: `OPEN10`, a 10% opening discount

## Database Tables

The application schema contains 21 domain tables:

| Group | Tables |
| --- | --- |
| Tenancy and access | `tenants`, `branches`, `users`, `user_branches` |
| Menu | `categories`, `products` |
| Cafe operations | `cafe_tables`, `customers`, `shifts` |
| Orders and payments | `orders`, `order_items`, `payments` |
| Discounts | `discounts`, `discount_targets`, `order_discounts` |
| Loyalty | `loyalty_accounts`, `loyalty_transactions` |
| Inventory | `warehouses`, `inventory_items`, `stock_movements` |
| Auditing | `activity_logs` |

The database also contains Laravel's `migrations` tracking table.

### Database Rules

- Business records are tenant-scoped with `tenant_id`.
- Operational records include `branch_id` where branch context is required.
- Money values use fixed decimal columns, not floats.
- Stock quantities use fixed decimal columns with three decimal places.
- Status values use string columns rather than database enums.
- Important business tables use soft deletes.
- Historical order and financial records are not cascade-deleted.
- Nullable historical references use `SET NULL` where appropriate.

## Project Structure

```text
.
|-- backend/                  Laravel application
|   |-- app/                  Application code
|   |-- bootstrap/            Laravel bootstrap configuration
|   |-- config/               Laravel configuration
|   |-- database/
|   |   |-- migrations/       Ordered Phase 1 database migrations
|   |   `-- seeders/          Demo data seeder
|   |-- routes/               Console routes only in Phase 1
|   `-- tests/                Laravel tests
|-- docs/superpowers/         Design and implementation notes
|-- Dockerfile                Custom PHP CLI image
`-- docker-compose.yml        Backend and PostgreSQL services
```

## Troubleshooting

### Port 5432 is already in use

Stop the local service or container that already uses port `5432`, then run:

```bash
docker compose up -d
```

### Rebuild the backend image

Rebuild after changing the Dockerfile:

```bash
docker compose up -d --build
```

### Completely reset PostgreSQL data

```bash
docker compose down -v
docker compose up -d
docker compose exec backend php artisan migrate:fresh --seed
```

Warning: `docker compose down -v` permanently removes the local database volume.

### Laravel reports a missing application key

```bash
docker compose exec backend php artisan key:generate
```

### Laravel reports missing PHP dependencies

```bash
docker compose exec backend composer install
```

### Docker cannot mount the backend folder

Ensure Docker Desktop has permission to access the repository folder and restart
Docker Desktop.

## Development Notes

- Keep application commands Dockerized. Do not rely on host PHP or Composer.
- Do not commit `backend/.env`; commit changes to `backend/.env.example`.
- Add APIs, business logic, and the Flutter client in later phases.
- Preserve tenant scoping when adding business tables or queries.
- Preserve historical records when adding relationships to orders, payments, or
  stock movements.
