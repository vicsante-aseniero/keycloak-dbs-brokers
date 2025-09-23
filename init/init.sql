-- Create a new user and a role.
CREATE USER keycloak_user WITH PASSWORD 'jajnav5@';
CREATE ROLE keycloak_admin;

-- Grant standard superuser privileges to the role.
ALTER ROLE keycloak_admin WITH SUPERUSER;

-- Grant the new Role public schema table permission.
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO keycloak_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO keycloak_admin;

-- Link the user to the role.
GRANT keycloak_admin TO keycloak_user;

-- Create the Keycloak database and grant privileges to the role/user.
CREATE DATABASE keycloak OWNER keycloak_user;

-- Optional: Grant all privileges on the database to the role and user.
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak_admin;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak_user;

-- Optional: Grant all privileges on the database to the role and user.
GRANT ALL PRIVILEGES ON DATABASE postgres TO keycloak_admin;
GRANT ALL PRIVILEGES ON DATABASE postgres TO keycloak_user;

-- Grant CREATE privilege on the 'public' schema
-- to ensure the application can create its tables.
GRANT CREATE ON SCHEMA public TO keycloak_admin;
GRANT CREATE ON SCHEMA public TO keycloak_user;
