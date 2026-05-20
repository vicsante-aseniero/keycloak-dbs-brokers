-- init.sql
-- Bootstraps PostgreSQL for Keycloak.
-- This file runs automatically on first container start via
-- /docker-entrypoint-initdb.d/ — it does NOT re-run if the data volume exists.

-- ── Step 1: Create the Keycloak user ─────────────────────────────────────────
-- Using a role for the password so we can reference it from .env in the future.
-- For now, the password is set directly; in production use SCRAM-SHA-256 auth.
CREATE USER keycloak_user WITH PASSWORD 'jajnav5@' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- ── Step 2: Create a dedicated role with minimal privileges ──────────────────
-- We do NOT grant SUPERUSER — Keycloak only needs its own database.
CREATE ROLE keycloak_admin;

-- Grant the user the role (role membership, not superuser elevation)
GRANT keycloak_admin TO keycloak_user;

-- ── Step 3: Create the Keycloak database ─────────────────────────────────────
CREATE DATABASE keycloak OWNER keycloak_user
    ENCODING 'UTF8'
    LC_COLLATE 'en_US.UTF-8'
    LC_CTYPE 'en_US.UTF-8'
    TEMPLATE template0;

-- Grant connection rights on the database
GRANT CONNECT ON DATABASE keycloak TO keycloak_user;

-- ── Step 4: Switch to the keycloak database and set up schema permissions ────
-- \c switches the connection context — grants below now apply to THIS database.
\c keycloak

-- Allow keycloak_user to use and create objects in the public schema
GRANT USAGE, CREATE ON SCHEMA public TO keycloak_user;

-- Ensure any tables Keycloak creates in the future are also accessible
-- (This covers the case where the GRANT above runs before tables exist)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES TO keycloak_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO keycloak_user;