-- init.sql
-- Bootstraps PostgreSQL for Keycloak.
-- This file runs automatically on first container start via
-- /docker-entrypoint-initdb.d/ — it does NOT re-run if the data volume exists.
--
-- Requires PostgreSQL 14+ for \getenv support.
-- Requires the KEYCLOAK_DB_PASSWORD environment variable to be set.

-- ── Step 0: Read password from environment ───────────────────────────────────
-- \getenv reads directly from the process environment — more reliable than
-- \set with backtick shell expansion, which does not work consistently inside
-- docker-entrypoint-initdb.d scripts.
\getenv kc_pass KEYCLOAK_DB_PASSWORD

-- Guard against a missing or empty password variable.
-- This causes the script to fail loudly rather than create a user
-- with a blank password, which would be a silent security failure.
\if :{?kc_pass}
\else
    \warn 'FATAL: KEYCLOAK_DB_PASSWORD is not set in the environment. Aborting init.sql.'
    \quit
\endif

-- ── Step 1: Create the Keycloak user ─────────────────────────────────────────
-- NOSUPERUSER NOCREATEDB NOCREATEROLE follows the principle of least privilege.
-- The password is sourced from the environment variable above, not hardcoded.
CREATE USER keycloak_user WITH PASSWORD :'kc_pass'
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE;

-- ── Step 2: Create a dedicated role with minimal privileges ──────────────────
CREATE ROLE keycloak_admin;

-- Grant the user membership in the role (not superuser elevation).
GRANT keycloak_admin TO keycloak_user;

-- ── Step 3: Create the Keycloak database ─────────────────────────────────────
-- C.UTF-8 is used instead of en_US.UTF-8 for portability across images.
-- en_US.UTF-8 requires the locale to be installed on the OS; C.UTF-8 is
-- always available and still fully supports Unicode data storage.
CREATE DATABASE keycloak OWNER keycloak_user
    ENCODING 'UTF8'
    LC_COLLATE 'C.UTF-8'
    LC_CTYPE 'C.UTF-8'
    TEMPLATE template0;

-- Grant connection rights explicitly.
GRANT CONNECT ON DATABASE keycloak TO keycloak_user;

-- ── Step 4: Switch to the keycloak database and set up schema permissions ────
-- \c switches the psql connection context — all grants below now apply
-- to objects inside the keycloak database, not the default postgres database.
\c keycloak

-- Allow keycloak_user to use the public schema and create objects within it.
GRANT USAGE, CREATE ON SCHEMA public TO keycloak_user;

-- Ensure future tables and sequences created by Keycloak are also accessible.
-- ALTER DEFAULT PRIVILEGES applies to objects created AFTER this statement runs.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES TO keycloak_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO keycloak_user;