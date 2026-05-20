# Docker Stack Analysis

> **Purpose**: Comprehensive technical analysis of the local development infrastructure stack optimized for a 16GB RAM workstation.

## Overview

This Docker Compose configuration provides a complete local development environment including:
- **Identity & Access Management**: Keycloak
- **Relational Databases**: PostgreSQL (with SSL), MariaDB, SQL Server
- **NoSQL Database**: MongoDB
- **Message Brokers**: RabbitMQ, Redis
- **AWS Cloud Emulation**: LocalStack
- **Database Administration**: phpMyAdmin

---

## Resource Allocation Analysis

### Total Memory Allocation

| Service | Memory Limit | Memory Reserved | CPU Limit |
|---------|-------------|-----------------|-----------|
| SQL Server | 2.5 GB | 2.0 GB | 2.0 |
| LocalStack | 2.0 GB | - | 2.0 |
| MongoDB | 1.0 GB | 512 MB | 1.0 |
| Keycloak | 1.0 GB | - | 1.5 |
| PostgreSQL | 768 MB | - | 1.0 |
| MariaDB | 512 MB | - | 1.0 |
| RabbitMQ | 512 MB | - | 1.0 |
| Redis | 256 MB | - | 0.5 |
| phpMyAdmin | 256 MB | - | 0.5 |
| **TOTAL** | **~8.8 GB** | **~2.5 GB** | **10.5 cores** |

### Why Resource Limits Are Critical for 16GB Systems

#### The Problem: Memory Contention

When running Docker containers on a development workstation with only **16GB RAM**, you must account for:

1. **Host Operating System**: ~2-3 GB
2. **WSL2 Subsystem** (if on Windows): ~1-2 GB
3. **IDE(s)**: VS Code, IntelliJ, Visual Studio: ~1-4 GB each
4. **Docker Desktop**: ~1-2 GB overhead
5. **LocalStack Desktop**: ~500 MB - 1 GB
6. **SQL Tools** (Azure Data Studio, DBeaver, pgAdmin): ~500 MB - 1 GB each
7. **Browser(s)**: ~1-3 GB
8. **Other tools**: Terminal, Postman, etc: ~500 MB

**Typical development session breakdown:**
```
Host OS + WSL2:           ~3.0 GB
IDE (VS Code):            ~1.5 GB
Docker Desktop:           ~1.5 GB
Browser (Chrome):         ~2.0 GB
SQL Tool (DBeaver):       ~0.8 GB
Remaining for containers: ~7.0 GB
```

#### The Solution: Explicit Resource Limits

Without explicit limits, containers will consume as much memory as they want:
- **SQL Server** can easily consume 4-6 GB alone
- **LocalStack** with many services can grow to 3-4 GB
- **Keycloak** (JVM-based) defaults to consuming 25% of available RAM

By setting explicit limits, we ensure:
1. **Predictable behavior** - No sudden OOM kills
2. **Fair distribution** - Each service gets its allocation
3. **System stability** - Host remains responsive
4. **Swap prevention** - Reduces disk thrashing

#### Memory Reservation vs. Limits

```yaml
deploy:
  resources:
    limits:
      memory: 2.5G  # Hard ceiling - container gets killed if exceeded
    reservations:
      memory: 2G    # Guaranteed minimum allocation
```

- **Limits**: Maximum memory allowed. Container is killed (OOM) if exceeded.
- **Reservations**: Minimum guaranteed. Docker scheduler ensures this much is available.

SQL Server reserves 2GB because it will **terminate itself** if it cannot allocate at least 2GB.

---

## Service Configuration Details

### PostgreSQL with SSL

PostgreSQL is configured with SSL/TLS encryption for secure connections:

```yaml
volumes:
  - ./certs/server.crt:/tmp/server.crt:ro
  - ./certs/server.key:/tmp/server.key:ro
entrypoint: >
  sh -c "
  cp /tmp/server.crt /var/lib/postgresql/server.crt &&
  cp /tmp/server.key /var/lib/postgresql/server.key &&
  chown postgres:postgres /var/lib/postgresql/server.key &&
  chmod 600 /var/lib/postgresql/server.key &&
  exec docker-entrypoint.sh postgres 
  -c ssl=on 
  -c ssl_cert_file=/var/lib/postgresql/server.crt 
  -c ssl_key_file=/var/lib/postgresql/server.key
  "
```

**Key Points:**
- Certificates are mounted read-only (`:ro`)
- Copied to container's PostgreSQL directory
- Private key must be owned by `postgres` user
- Private key must have `600` permissions (owner read/write only)

See [README.md](./README.md) for certificate generation instructions.

### Keycloak JVM Tuning

```yaml
JAVA_OPTS: "-Xms512m -Xmx768m -XX:MetaspaceSize=96M -XX:MaxMetaspaceSize=256m"
```

- **-Xms512m**: Initial heap size (minimum)
- **-Xmx768m**: Maximum heap size (prevents runaway memory)
- **MetaspaceSize**: JVM class metadata allocation
- Without these settings, Keycloak would try to use 25% of system RAM (~4GB)

### SQL Server Requirements

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'        # MSSQL needs more processing power
      memory: 2.5G       # Warning: terminates if given less than 2GB
    reservations:
      memory: 2G
```

SQL Server 2022 has a **minimum requirement of 2GB RAM**. It will:
1. Refuse to start, OR
2. Start and immediately crash

The 2.5GB limit allows for buffer cache and query operations.

### LocalStack Services

```yaml
SERVICES=apigateway,s3,sqs,sns,stepfunctions,events,ec2,lambda,kms,iam,acm,transcribe,dynamodb,cloudformation,logs,cloudwatch,ssm,ses,kinesis,route53,opensearch
```

**Note:** Each enabled service consumes additional memory. Consider disabling unused services to reduce memory footprint.

---

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     backend_network                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ postgres │ │ mariadb  │ │ mongodb  │ │ mssql    │       │
│  │  :5432   │ │  :3306   │ │ :27017   │ │  :1433   │       │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘       │
│       │            │            │            │              │
│  ┌────▼─────┐ ┌────▼─────┐ ┌────▼─────┐                    │
│  │ keycloak │ │phpmyadmin│ │ redis    │                    │
│  │  :9000   │ │  :9080   │ │  :6379   │                    │
│  └──────────┘ └──────────┘ └──────────┘                    │
│                                                             │
│  ┌──────────┐ ┌──────────┐                                 │
│  │ rabbitmq │ │localstack│                                 │
│  │:5672/    │ │  :4566   │                                 │
│  │:15672    │ │          │                                 │
│  └──────────┘ └──────────┘                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Port Mapping Reference

| Service | Container Port | Host Port | Protocol |
|---------|---------------|-----------|----------|
| MongoDB | 27017 | 27017 | TCP |
| SQL Server | 1433 | 1433 | TCP |
| MariaDB | 3306 | 3306 | TCP |
| PostgreSQL | 5432 | 5432 | TCP |
| Keycloak | 8080 | 9000 | HTTP |
| phpMyAdmin | 80 | 9080 | HTTP |
| Redis | 6379 | 6379 | TCP |
| RabbitMQ | 5672, 15672 | 5672, 15672 | AMQP/HTTP |
| LocalStack | 4566 | 4566 | HTTP |

---

## Volume Persistence

| Volume Name | Purpose |
|-------------|---------|
| `keycloak_data` | Keycloak configuration and realms |
| `mongo_data` | MongoDB databases |
| `mssql_data` | SQL Server databases |
| `mariadb_data` | MariaDB/MySQL databases |
| `postgres_data` | PostgreSQL databases |
| `redis_data` | Redis persistence |
| `rabbitmq_data` | RabbitMQ messages and configuration |

Bind mounts:
- `./init` → PostgreSQL init scripts
- `./certs` → SSL certificates
- `./localstack-data` → LocalStack persistence

---

## Health Checks

| Service | Health Check | Interval |
|---------|-------------|----------|
| MariaDB | `mysqladmin ping` | 10s |
| PostgreSQL | `pg_isready -U postgres` | 5s |
| Keycloak | HTTP GET `/health/ready` | 10s |
| LocalStack | HTTP GET `/_localstack/health` | 10s |

---

## Security Considerations

> [!CAUTION]
> **This configuration is for LOCAL DEVELOPMENT ONLY.**
> Passwords are hardcoded and should NEVER be used in production.

### Current Security Settings (Dev Only)

1. All containers run as `root` for simplicity
2. Passwords are embedded in `docker-compose.yml`
3. SSL is self-signed for PostgreSQL
4. Keycloak runs in `start-dev` mode

### Production Recommendations

1. Use Docker secrets or external vault
2. Generate strong, unique passwords
3. Use proper CA-signed certificates
4. Run containers as non-root users
5. Enable network policies/firewalls
6. Use Keycloak's production mode

---

## Troubleshooting

### Container Keeps Restarting

1. Check memory limits: `docker stats`
2. View logs: `docker logs <container-name>`
3. SQL Server typically needs at least 2GB to start

### PostgreSQL SSL Errors

1. Ensure certificates exist: `ls -la certs/`
2. Check permissions: Key must be `600`
3. Regenerate if expired (see README.md)

### Out of Memory (OOM)

1. Check host memory: `free -h`
2. Reduce LocalStack services
3. Stop unused containers
4. Close IDE extensions/plugins

---

## Maintenance Commands

```bash
# View all container status
docker compose ps

# View resource usage
docker stats

# Stop all containers
docker compose down

# Stop and remove volumes (CAUTION: data loss)
docker compose down -v

# View logs for specific service
docker logs -f keycloak-dev

# Restart a specific service
docker compose restart postgres
```