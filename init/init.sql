-- init.sql
-- Bootstraps PostgreSQL for Keycloak.
-- Runs once on first container start via /docker-entrypoint-initdb.d/
-- REQUIRES: KEYCLOAK_DB_PASSWORD env var to be set.
-- NOTE: Keycloak creates its own tables via Liquibase on first boot.
--       This script only sets up the user, database, and permissions.

-- ── Step 0: Read password from environment ───────────────────────────────────
\getenv kc_pass KEYCLOAK_DB_PASSWORD

\if :{?kc_pass}
\else
    \warn 'FATAL: KEYCLOAK_DB_PASSWORD is not set. Aborting.'
    \quit
\endif

-- ── Step 1: Create the Keycloak database user ────────────────────────────────
-- RECOMMENDATION: The username here MUST match KC_DB_USERNAME in docker-compose.yml.
-- If KC_DB_USERNAME=keycloak_user in your .env, this is correct.
-- Least-privilege: no superuser, no createdb, no createrole.
CREATE USER keycloak_user WITH PASSWORD :'kc_pass'
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    LOGIN;  -- explicit LOGIN is good documentation practice

-- ── Step 2: Create the Keycloak database ─────────────────────────────────────
-- C.UTF-8 is portable (no OS locale dependency) and fully supports Unicode.
CREATE DATABASE keycloak
    OWNER keycloak_user          -- user owns the DB; no extra grants needed
    ENCODING 'UTF8'
    LC_COLLATE 'C.UTF-8'
    LC_CTYPE 'C.UTF-8'
    TEMPLATE template0;

-- ── Step 3: Grant connection privilege (belt-and-suspenders) ─────────────────
-- OWNER already has CONNECT, but being explicit prevents surprises if ownership
-- is ever changed.
GRANT CONNECT ON DATABASE keycloak TO keycloak_user;

-- ── Step 4: Schema permissions inside the keycloak database ──────────────────
\c keycloak

-- Allow keycloak_user to use and create objects in public schema.
-- Keycloak's Liquibase migrations require CREATE to build tables/indexes.
GRANT USAGE, CREATE ON SCHEMA public TO keycloak_user;

-- ── NOTE on keycloak_admin role ───────────────────────────────────────────────
-- The original script created a keycloak_admin role but granted it no
-- privileges, making it a no-op. Removed to reduce confusion.
-- If you want a read-only admin role for inspection/reporting, add it here
-- with explicit SELECT grants after Keycloak has created its tables.