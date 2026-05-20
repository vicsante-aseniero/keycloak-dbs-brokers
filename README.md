# Keycloak IAM, Databases & Message Brokers

> **Local Development Stack** - Docker Compose configuration for Keycloak IAM, databases (PostgreSQL, MariaDB, SQL Server, MongoDB), and message brokers (Redis, RabbitMQ), with LocalStack for AWS emulation.

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone <repo-url>
cd keycloak-dbs-brokers

# 2. Generate SSL certificates for PostgreSQL (first time only)
./generate-certs.sh
# Or manually:
openssl req -new -x509 -days 365 -nodes -text \
  -out certs/server.crt -keyout certs/server.key \
  -subj "/CN=postgres-dev"
chmod 600 certs/server.key

# 3. Start all services
docker compose up -d

# 4. Check status
docker compose ps
```

---

## 📦 Services

| Service | Port | Description | Web UI |
|---------|------|-------------|--------|
| **Keycloak** | 9000 | Identity & Access Management | http://localhost:9000 |
| **PostgreSQL** | 5432 | Primary database (SSL enabled) | - |
| **MariaDB** | 3306 | MySQL-compatible database | - |
| **SQL Server** | 1433 | Microsoft SQL Server 2022 | - |
| **MongoDB** | 27017 | NoSQL document database | - |
| **Redis** | 6379 | In-memory cache/broker | - |
| **RabbitMQ** | 5672, 15672 | Message broker | http://localhost:15672 |
| **LocalStack** | 4566 | AWS cloud emulator | - |
| **phpMyAdmin** | 9080 | MariaDB web admin | http://localhost:9080 |

---

## 🎪 Default Credentials

> [!WARNING]
> These credentials are for **local development only**. Never use in production.

| Service | Username | Password |
|---------|----------|----------|
| Keycloak Admin | `admin` | `jajnav5@` |
| PostgreSQL | `postgres` | `jajnav5@` |
| PostgreSQL (Keycloak) | `keycloak_user` | `jajnav5@` |
| MariaDB Root | `root` | `jajnav5@` |
| MariaDB User | `devuser` | `JajNav5@2119` |
| SQL Server SA | `sa` | `jajnav5@` |
| MongoDB | `devuser` | `jajnav5@` |
| RabbitMQ | `admin` | `jajnav5@` |
| Redis | - | `jajnav5@` |

---

## 🔐 PostgreSQL SSL Certificate Setup

PostgreSQL is configured with SSL/TLS encryption. Certificates must be generated before first run.

### Option 1: Quick Generation (Self-Signed)

```bash
# Generate self-signed certificate valid for 365 days
openssl req -new -x509 -days 365 -nodes -text \
  -out certs/server.crt \
  -keyout certs/server.key \
  -subj "/CN=postgres-dev"

# Set required permissions (CRITICAL!)
chmod 600 certs/server.key
chmod 644 certs/server.crt
```

### Option 2: With Custom Details

```bash
# Generate private key
openssl genrsa -out certs/server.key 4096

# Generate certificate signing request
openssl req -new -key certs/server.key -out certs/server.csr \
  -subj "/C=PH/ST=NCR/L=Manila/O=Development/CN=postgres-dev"

# Self-sign the certificate
openssl x509 -req -days 365 -in certs/server.csr \
  -signkey certs/server.key -out certs/server.crt

# Remove CSR and set permissions
rm certs/server.csr
chmod 600 certs/server.key
chmod 644 certs/server.crt
```

### Why Permissions Matter

PostgreSQL **requires** the private key file to have restricted permissions:
- `600` (owner read/write only) for `server.key`
- If permissions are too open, PostgreSQL will refuse to start

The `docker-compose.yml` handles copying and setting permissions inside the container automatically.

### Connecting with SSL

```bash
# From command line
psql "host=localhost port=5432 dbname=postgres user=postgres sslmode=require"

# Connection string
postgresql://postgres:jajnav5@@localhost:5432/postgres?sslmode=require
```

---

## 💾 Resource Management

> [!IMPORTANT]
> This stack is optimized for **16GB RAM** development workstations.

### Memory Budget

| Component | Allocation |
|-----------|-----------|
| **Docker Containers** | ~8.8 GB (limited) |
| Host OS + WSL2 | ~3 GB |
| IDE (VS Code/IntelliJ) | ~1.5 GB |
| Browser | ~2 GB |
| SQL Tools | ~1 GB |
| **Total** | ~16 GB |

### Why Limits Are Important

Without explicit limits:
- SQL Server alone can consume 4-6 GB
- LocalStack with all services grows to 3-4 GB
- Keycloak (JVM) defaults to 25% of RAM (~4 GB)

With limits, all services run concurrently without OOM kills or system freezes.

See [ANALYSIS.md](./ANALYSIS.md) for detailed resource breakdown.

---

## 📁 Project Structure

```
keycloak-dbs-brokers/
├── docker-compose.yml      # Main orchestration file
├── certs/                  # SSL certificates for PostgreSQL
│   ├── server.crt          # Public certificate
│   └── server.key          # Private key (chmod 600)
├── init/                   # Database initialization scripts
│   └── init.sql            # PostgreSQL setup for Keycloak
├── localstack-data/        # LocalStack persistent storage
├── README.md               # This file
├── ANALYSIS.md             # Detailed technical analysis
└── LICENSE                 # Project license
```

---

## 🛠️ Common Commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# View running containers
docker compose ps

# View resource usage
docker stats

# View logs (follow mode)
docker logs -f keycloak-dev
docker logs -f postgres-dev

# Restart specific service
docker compose restart keycloak

# Rebuild after changes
docker compose up -d --build

# Full reset (WARNING: deletes all data)
docker compose down -v
```

---

## 🔌 Connection Examples

### PostgreSQL
```bash
# psql CLI
psql -h localhost -p 5432 -U postgres -d keycloak

# Connection string (with SSL)
postgresql://postgres:jajnav5@@localhost:5432/keycloak?sslmode=require
```

### MariaDB
```bash
# mysql CLI
mysql -h localhost -P 3306 -u devuser -pJajNav5@2119 devDb

# Connection string
mysql://devuser:JajNav5@2119@localhost:3306/devDb
```

### SQL Server
```bash
# sqlcmd
sqlcmd -S localhost,1433 -U sa -P 'jajnav5@'

# Connection string
Server=localhost,1433;Database=master;User Id=sa;Password=jajnav5@;TrustServerCertificate=True;
```

### MongoDB
```bash
# mongosh
mongosh "mongodb://devuser:jajnav5@@localhost:27017"

# Connection string
mongodb://devuser:jajnav5@@localhost:27017/?authSource=admin
```

### Redis
```bash
# redis-cli
redis-cli -h localhost -p 6379
AUTH jajnav5@

# Connection string
redis://:jajnav5@@localhost:6379
```

### RabbitMQ
```bash
# Management UI
http://localhost:15672
# Login: admin / jajnav5@

# AMQP connection
amqp://admin:jajnav5@@localhost:5672
```

### LocalStack (AWS)
```bash
# Configure AWS CLI
aws configure set aws_access_key_id test
aws configure set aws_secret_access_key test
aws configure set region us-east-1

# Use with endpoint
aws --endpoint-url=http://localhost:4566 s3 ls
```

---

## 🚨 Troubleshooting

### SQL Server Won't Start
- **Cause**: Insufficient memory (requires minimum 2GB)
- **Solution**: Ensure no other memory-intensive apps running, or increase Docker memory limit

### PostgreSQL SSL Errors
- **Cause**: Missing or wrong permissions on certificates
- **Solution**: Regenerate certs and run `chmod 600 certs/server.key`

### Keycloak "Unhealthy" Status
- **Cause**: Health check timing; Keycloak takes ~30s to fully start
- **Solution**: Wait and check logs; if logs show "Listening on http://0.0.0.0:8080", it's running

### Out of Memory
- **Cause**: Too many apps + containers running
- **Solution**: Close IDE plugins, browsers; reduce LocalStack services

### LocalStack Connection Refused
- **Cause**: Service not enabled in SERVICES list
- **Solution**: Add required service to `SERVICES` env var in docker-compose.yml

---

## 📚 Documentation

- [ANALYSIS.md](./ANALYSIS.md) - Detailed technical analysis and architecture
- [LICENSE](./LICENSE) - Project license

---

## 🤝 Recommendations

### For Better Security
1. Create a `.env` file for credentials (add to `.gitignore`)
2. Use Docker secrets for production deployments
3. Replace self-signed certificates with CA-signed for staging/production

### For Better Performance
1. Disable unused LocalStack services to save memory
2. Use `docker compose --profile` for optional services
3. Consider running heavy services (SQL Server) only when needed

### Future Additions
- [ ] Add Nginx reverse proxy for unified access
- [ ] Add monitoring stack (Prometheus + Grafana)
- [ ] Create profiles for different workloads (minimal, full, testing)
- [ ] Add backup/restore scripts for databases
- [ ] Add healthcheck dashboard script
