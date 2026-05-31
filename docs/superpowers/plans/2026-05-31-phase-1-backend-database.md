# Cafe System 618 Phase 1 Backend Database Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Docker-only Laravel backend workspace with the Phase 1 PostgreSQL schema and demo data.

**Architecture:** A root Compose project runs a custom PHP CLI backend container and PostgreSQL 16. Laravel migrations model the multi-tenant database with restrictive historical foreign keys and nullable references that become null when their parent is removed.

**Tech Stack:** Docker Compose, PHP CLI, Composer, Laravel, PostgreSQL 16

---

### Task 1: Docker Runtime

**Files:**
- Create: `Dockerfile`
- Create: `docker-compose.yml`

- [x] Build a PHP CLI image with Composer and `pdo_pgsql`.
- [x] Define the long-running backend service and PostgreSQL 16 service.
- [x] Build the backend image and start PostgreSQL.

### Task 2: Laravel Scaffold

**Files:**
- Create: `backend/`
- Modify: `backend/.env.example`
- Create: `backend/.env`

- [x] Scaffold the current stable `laravel/laravel` release with Composer in Docker.
- [x] Configure PostgreSQL environment variables with `DB_HOST=postgres`.
- [x] Start the backend service and generate the application key.

### Task 3: Phase 1 Migrations

**Files:**
- Replace: `backend/database/migrations/*.php`

- [x] Replace Laravel's default schema with 21 ordered migrations.
- [x] Add PostgreSQL-compatible types, indexes, soft deletes, and foreign keys.
- [x] Use `nullOnDelete()` for nullable historical references and avoid cascade deletion for order and financial history.

### Task 4: Demo Seeder

**Files:**
- Modify: `backend/database/seeders/DatabaseSeeder.php`

- [x] Seed the Cafe 6:18 tenant, branch, users, categories, products, tables, warehouse, inventory items, and OPEN10 discount.

### Task 5: Verification

- [x] Run `docker compose up -d`.
- [x] Run `docker compose exec backend php artisan migrate:fresh --seed`.
- [x] Run `docker compose exec backend php artisan migrate:status`.
- [x] Query PostgreSQL for the created table names and verify seeded row counts.
