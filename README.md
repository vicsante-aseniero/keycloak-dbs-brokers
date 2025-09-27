# Keycloak IAM DBS Message Brokers
Docker Container configuration for Keycloak IAM, Databases, e.g., MS-SQL, Postgres, MongoDB, and Message Brokers, e.g., Redis and RabbitMQ.


## Structure
- `docker-compose.yml`: Main orchestration file for all containers.
- `init/`: Contains SQL scripts for initializing the database.
- `localstack-data/`: Persistent data storage for services.
  - `cache/`: SSL certificates and cache files.
  - `lib/`, `logs/`, `tmp/`: Additional data and log directories.

## Usage
1. **Clone the repository:**
	```bash
	git clone <repo-url>
	cd keycloak-dbs-brokers
	```
2. **Start the containers:**
	```bash
	docker-compose up -d
	```
3. **Database Initialization:**
	- The `init/init.sql` script is automatically executed to set up the database schema and seed initial data.

## Environment Variables
- Environment variables are set in `docker-compose.yml` or a `.env` file.
- Configure database credentials, Keycloak admin settings, and broker endpoints as needed.

## Security
- Do not commit sensitive credentials to version control.
- Use Docker secrets or environment management tools for production.

## Maintenance
- Backup persistent data in `localstack-data/` regularly.
- Update `init/init.sql` for schema changes or new seed data.

## Documentation
- See `ANALYZED.md` for a detailed analysis of the configuration and initialization files.

## License
- See `LICENSE` for details.
