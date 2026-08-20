# Developer Onboarding Guide

> **Complete setup and workflow guide for microservices-ops development**

This guide walks you through everything you need to get the microservices platform up and running on your local machine, from prerequisites to daily development workflows.

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- **Docker & Docker Compose** — Required for running services and infrastructure
- **Git** — For cloning repositories
- **yq** — YAML processor for running configuration scripts
- **VS Code** (recommended) — Best experience with Dev Container support
  - **Dev Containers extension** — Required for VS Code Dev Container workflow

> 💡 **Tip:** The `configure-environment.sh` script will automatically validate that all required tools are installed and provide installation instructions if anything is missing.

### Basic Familiarity Required

- Docker containers and networking
- Node.js/TypeScript development
- PostgreSQL databases
- REST APIs

## 🚀 First-Time Setup

### Step 1: Clone the Orchestrator Repository

```bash
git clone git@github.com:tonydail/microservices-ops.git
cd microservices-ops
```

---

### Step 2: Clone the Microservices Repositories

Execute the `clone-repositories.sh` script:

```bash
chmod +x clone-repositories.sh
./clone-repositories.sh
```

**What this does:**
- Clones all microservices repositories:
  - `microservice-core-services`
  - `microservice-auth-service`
  - `microservice-users-service`

---

### Step 3: Configure Environment Variables

Execute the `configure-environment.sh` script:

```bash
chmod +x configure-environment.sh
./configure-environment.sh
```

**What this does:**
- ✅ **Validates all required tools** are installed (yq, docker, docker compose, git)
- ✅ Checks if Docker daemon is running
- ✅ Provides installation instructions if tools are missing
- ✅ Reads `onboarding-config.yml`
- ✅ Creates environment files (`*.env`) needed for each microservice
- ✅ Prompts for any missing information

> 💡 **Note:** If any required tools are missing, the script will stop and show platform-specific installation instructions before proceeding.

---

## 🚀 Starting the Environment

### Core Services (Required First)

> ⚠️ **Important:** Core services must be running and healthy BEFORE starting auth and users services.

**Services included:**
- Kafka (event streaming)
- Kafka Connect (Debezium CDC)
- Kafka UI (monitoring)
- nginx (reverse proxy/gateway)
- CloudBeaver (database WebUI)

**Location:** `microservice-core-services/`

**Management scripts:**

| Script | Action |
|--------|--------|
| `start.sh` | Creates shared Docker network + starts all core services |
| `stop.sh` | Stops services, removes containers, **keeps volumes** |
| `teardown.sh` | Stops services, removes containers, **deletes volumes & network** |

**Start core services:**

```bash
cd microservice-core-services
./start.sh
cd ..
```

**Verify services are running:**

Visit these URLs to confirm everything is up:

| Service | URL | Purpose |
|---------|-----|---------|
| **nginx Gateway** | http://localhost | API gateway |
| **Kafka UI** | http://localhost:8080 | Browse topics, consumers, messages |
| **CloudBeaver** | http://localhost:8978 | Database administration |
| **Kafka Connect** | http://localhost:8083 | Connector status |

---

### Auth Service

The auth service provides authentication and authorization. It should be running and healthy before other services that depend on it.

**Services included:**
- Auth app service (REST + gRPC)
- Auth PostgreSQL database

**Location:** `microservice-auth-service/`

#### Run Standalone (Docker Compose)

**Management scripts:**

| Script | Action |
|--------|--------|
| `start.sh` | Starts containers + runs migrations + starts service |
| `stop.sh` | Stops services, removes containers, **keeps volumes** |
| `teardown.sh` | Stops services, removes containers, **deletes volumes** |

```bash
cd microservice-auth-service
./start.sh
cd ..
```

> ✅ **Note:** Debezium connectors are registered automatically — no manual configuration needed!

#### Run in Dev Container (Development)

For active development with hot reload, code completion, and debugging:

**See the [Development Workflow](#-development-workflow) section below for detailed instructions.**

---

### Users Service

The users service provides user profile management and consumes events from the auth service.

**Services included:**
- Users app service (REST + gRPC)
- Users PostgreSQL database

**Location:** `microservice-users-service/`

#### Run Standalone (Docker Compose)

**Management scripts:**

| Script | Action |
|--------|--------|
| `start.sh` | Starts containers + runs migrations + starts service |
| `stop.sh` | Stops services, removes containers, **keeps volumes** |
| `teardown.sh` | Stops services, removes containers, **deletes volumes** |

```bash
cd microservice-users-service
./start.sh
cd ..
```

> ✅ **Note:** Debezium connectors are registered automatically — no manual configuration needed!

#### Run in Dev Container (Development)

For active development with hot reload, code completion, and debugging:

**See the [Development Workflow](#-development-workflow) section below for detailed instructions.**

---




## 💻 Development Workflow

### Working with Dev Containers

Each service has its own `.devcontainer/` configuration for isolated development.

**Benefits:**
- ✅ Service-specific Node.js environment
- ✅ Dedicated PostgreSQL database
- ✅ Pre-configured tooling (ESLint, Prettier, Prisma)
- ✅ Automatic network connectivity to Kafka and other services
- ✅ Hot reload for instant feedback
- ✅ Full IDE support (IntelliSense, debugging, etc.)

---

### Starting a Dev Container

#### Step 1: Open Service Folder in VS Code

```bash
code microservice-auth-service
# OR
code microservice-users-service
```

#### Step 2: Reopen in Container

- VS Code will prompt: **"Reopen in Container"**
- Click the prompt, or press `F1` → type "Dev Containers: Reopen in Container"

#### Step 3: Wait for Initialization

The following happens automatically:
- ✅ Service container starts
- ✅ Dedicated Postgres database starts
- ✅ Dependencies installed (`npm install`)
- ✅ Both join the `microservices-net` network

#### Step 4: Start Developing!

Once inside the container:

1. **Open integrated terminal** (already inside container)
2. **Run development server:**
   ```bash
   npm run dev
   ```
3. **Edit code** — changes sync automatically and hot reload applies
4. **Access services:**
   - Kafka: `kafka:9092`
   - Other microservices: `microservice-auth-service-app:50051` (gRPC)
   - Postgres: Already configured via `DATABASE_URL`

---

### Understanding Service Registration

#### Debezium Connectors (Automatic)

Each service has a `register-outbox-connector.sh` script that runs during container startup.

**What it does:**
- ✅ Registers the service's Debezium outbox connector with Kafka Connect
- ✅ Configures CDC to watch the `outbox_events` table
- ✅ Ensures events are published to Kafka topics

**When connectors are registered:**
- ✅ **Automatically** on service startup (preferred)
- ⚙️ **Manually** by running `./register-outbox-connector.sh` from service directory

**Troubleshooting connector issues:**

```bash
# Check connector status
curl http://localhost:8083/connectors/<connector-name>/status

# Delete and re-register a connector
curl -X DELETE http://localhost:8083/connectors/<connector-name>
cd <service-directory>
./register-outbox-connector.sh
```

---

### Daily Development Commands

Once your Dev Container is running, use these commands for daily work:

#### 🚀 Development & Building

| Command | Description |
|---------|-------------|
| `npm run dev` | Start with hot reload (ts-node-dev) |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Run compiled code (production mode) |

#### 🧪 Testing

| Command | Description |
|---------|-------------|
| `npm run test` | Run all tests (unit + integration) |
| `npm run test:unit` | Unit tests only (mocked dependencies) |
| `npm run test:integration` | Integration tests (requires real Postgres) |
| `npm run test -- path/to.test.ts` | Run specific test file |

#### ✨ Code Quality

| Command | Description |
|---------|-------------|
| `npm run lint` | Check code with ESLint |
| `npm run lint:fix` | Auto-fix ESLint issues |
| `npm run format` | Format code with Prettier |

#### 🗄️ Database Operations

| Command | Description |
|---------|-------------|
| `npm run db:migrate` | Run migrations (development) |
| `npm run db:migrate:prod` | Deploy migrations (production) |
| `npm run db:seed` | Seed database with test data |
| `npm run db:studio` | Open Prisma Studio (GUI) |

#### 🐛 Debugging

```bash
# View logs for a specific service
docker logs -f microservice-auth-service-app
docker logs -f microservice-users-service-app

# Access service shell
docker exec -it microservice-auth-service-app sh

# Check service health
curl http://localhost:3001/health  # auth service
curl http://localhost:3002/health  # users service
```

---

## 🛑 Stopping Services

### Quick Reference

| Action | Command | What Happens |
|--------|---------|--------------|
| **Stop auth service** | `cd microservice-auth-service && ./stop.sh` | Stops auth service, keeps volumes |
| **Stop users service** | `cd microservice-users-service && ./stop.sh` | Stops users service, keeps volumes |
| **Stop core infrastructure** | `cd microservice-core-services && ./stop.sh` | Stops Kafka/nginx/etc., keeps volumes |
| **Full teardown (⚠️ data loss)** | See below | Removes all containers + volumes |

---

### Stop Individual Microservices

**Auth Service:**
```bash
cd microservice-auth-service
./stop.sh
```

**Users Service:**
```bash
cd microservice-users-service
./stop.sh
```

- ✅ Stops the specific service
- ✅ Removes containers
- ✅ Keeps volumes (data preserved)
- ✅ Leaves other services running

---

### Stop Shared Infrastructure

```bash
cd microservice-core-services
./stop.sh
```

- ✅ Stops Kafka, nginx, CloudBeaver, etc.
- ✅ Keeps volumes (data preserved)

---

### Complete Teardown (⚠️ Data Loss)

If you want to remove containers **AND** volumes:

```bash
# Stop and remove individual service
cd microservice-auth-service  # or microservice-users-service
./teardown.sh

# Stop and remove core infrastructure
cd microservice-core-services
./teardown.sh
```

> ⚠️ **Warning:** Teardown **permanently deletes all data** from databases. Use only when you want a clean slate.

---

## ⚙️ Environment Configuration

The `environment/` folder at the repository root contains configuration files shared across services.

### Configuration Files

| File | Purpose |
|------|---------|
| `common-service-db.env` | Shared database settings (common across all services) |
| `microservice-auth-service-db.env` | Auth service database configuration |
| `microservice-users-service-db.env` | Users service database configuration |
| `container-hosts.env` | Container hostnames for service discovery |

---

### How Services Use Configuration

Dev Containers automatically load environment variables from these files:

1. **Service-specific variables** → Loaded from the service's dedicated `.env` file
2. **Shared variables** → Loaded from `environment/*.env` files in workspace root
3. **Merge at startup** → Dev Container configuration merges these automatically

---

### Modifying Configuration

**Steps to change configuration:**

1. Edit the appropriate file in `environment/`
2. Restart the affected service(s)
3. For database connection changes, run migrations if needed

**Example:** Changing auth service database port

```bash
# 1. Edit the environment file
nano environment/microservice-auth-service-db.env
# Change: DATABASE_PORT=5433

# 2. Restart the service
cd microservice-auth-service
./stop.sh
./start.sh
```

---

## 📝 Common Commands Reference

### Repository-Level Commands
(Run from `microservices-ops/` root)

```bash
# Infrastructure lifecycle
cd microservice-core-services
./start.sh                       # Start shared infrastructure
./stop.sh                        # Stop shared infrastructure
./teardown.sh                    # Stop + remove containers & volumes

# Monitoring
docker ps --filter "network=microservices-net"  # List all running services
docker network inspect microservices-net        # Inspect network configuration
```

### Service-Level Commands
(Run from inside a service directory or Dev Container)

```bash
# Service lifecycle (from service directory on host)
./start.sh                       # Start this service's containers
./stop.sh                        # Stop this service's containers
./teardown.sh                    # Stop + remove containers & volumes
./register-outbox-connector.sh   # Manually register Debezium connector

# Development (from Dev Container terminal)
npm run dev                      # Development with hot reload
npm run build                    # Compile TypeScript
npm run test                     # Run all tests
npm run test:unit               # Unit tests only
npm run test:integration        # Integration tests only
npm run lint                     # Lint code
npm run lint:fix                # Fix linting issues
npm run format                   # Format with Prettier

# Database (from Dev Container terminal)
npm run db:migrate              # Run migrations (development)
npm run db:migrate:prod         # Deploy migrations (production)
npm run db:seed                 # Seed database
npm run db:studio               # Open Prisma Studio
```

### Kafka Management Commands

```bash
# List topics
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --list

# Describe topic
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --describe --topic auth.user.registered

# Consume messages from topic (from beginning)
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic auth.user.registered --from-beginning

# Check connector status
curl http://localhost:8083/connectors/auth-outbox-connector/status | jq
curl http://localhost:8083/connectors/users-outbox-connector/status | jq

# List all connectors
curl http://localhost:8083/connectors | jq

# Restart a connector
curl -X POST http://localhost:8083/connectors/auth-outbox-connector/restart
```

## 🔍 Troubleshooting

### ❌ Missing Required Tools

If `configure-environment.sh` reports missing tools:

| Tool | Installation |
|------|--------------|
| **yq** | macOS: `brew install yq`<br>Linux: [Download from GitHub](https://github.com/mikefarah/yq)<br>Windows: `choco install yq` |
| **docker** | [Docker Desktop](https://www.docker.com/get-started)<br>macOS: `brew install --cask docker`<br>Linux: [Install docs](https://docs.docker.com/engine/install/) |
| **docker compose** | Usually included with Docker Desktop<br>Linux standalone: [Install docs](https://docs.docker.com/compose/install/) |
| **git** | macOS: `brew install git`<br>Linux: `sudo apt-get install git`<br>Windows: [Download](https://git-scm.com/download/win) |
| **VS Code** | [Download](https://code.visualstudio.com/)<br>macOS: `brew install --cask visual-studio-code` |

**Dev Containers extension for VS Code:**
```bash
code --install-extension ms-vscode-remote.remote-containers
```

---

### ❌ Services Won't Start

| Check | Command | Solution |
|-------|---------|----------|
| **Network exists** | `docker network ls \| grep microservices-net` | Create with `docker network create microservices-net` |
| **Port conflicts** | Check ports: 80, 3001, 3002, 5433, 5434, 8080, 8083, 8978, 29092 | Stop conflicting services |
| **Docker resources** | Check Docker Desktop settings | Allocate at least 4GB memory |

---

### ❌ Kafka Connector Not Registering

| Check | Command | Solution |
|-------|---------|----------|
| **Kafka Connect running** | `curl http://localhost:8083` | Start core services first |
| **Connector logs** | `docker logs kafka-connect` | Review error messages |
| **Manual registration** | `cd <service> && ./register-outbox-connector.sh` | Force re-registration |
| **Database connectivity** | Verify Postgres accessible | Check network and credentials |

---

### ❌ Database Migrations Failing

| Check | Command | Solution |
|-------|---------|----------|
| **Database running** | `docker ps \| grep postgres` | Start service first |
| **Connection string** | Check `DATABASE_URL` in `.env` | Verify credentials and host |
| **Clean slate** | `./teardown.sh && ./start.sh` | Reset database completely |

---

### ❌ Dev Container Not Connecting to Kafka

| Check | Command | Solution |
|-------|---------|----------|
| **Network membership** | `docker inspect <container-name>` | Check Networks section |
| **Connectivity test** | `docker exec -it <container-name> ping kafka` | Verify network routing |
| **DNS resolution** | `docker exec -it <container-name> nslookup kafka` | Check DNS configuration |

---

### ❌ Hot Reload Not Working in Dev Container

| Issue | Solution |
|-------|----------|
| **File sync problems** | Ensure VS Code Dev Container extension is active |
| **Stale file watchers** | Restart container to refresh watchers |
| **Ignored files** | Check `.dockerignore` and `nodemonConfig` in `package.json` |

---

## 🎓 Next Steps

Once your environment is set up:

1. **Explore the codebase**:
   - Review service README files in each repository
   - Study the layered architecture (routes → controllers → services → repositories)
   - Understand the transactional outbox pattern implementation

2. **Run the test suites**:
   ```bash
   npm run test
   ```

3. **Try making a change**:
   - Add a new endpoint
   - Modify validation rules
   - Add a new event type

4. **Review the architecture docs**:
   - Check out the main [README.md](./README.md) for high-level architecture
   - Read individual service READMEs for service-specific details

5. **Join the team**:
   - Check the [issue tracker](https://github.com/tonydail/microservices-ops/issues)
   - Review open pull requests
   - Familiarize yourself with the contribution guidelines

## 💡 Tips for Productive Development

| Tool | URL / Command | Use Case |
|------|---------------|----------|
| **Kafka UI** | http://localhost:8080 | Inspect messages, debug event flows |
| **CloudBeaver** | http://localhost:8978 | Database exploration, ad-hoc SQL queries |
| **Prisma Studio** | `npm run db:studio` | Quick visual data inspection |
| **Docker Desktop** | Keep open | Monitor resource usage, container health |
| **Separate terminals** | Multiple windows | Run `npm run dev` for each service |
| **Logs first** | `docker logs -f <container>` | Most issues surface in logs first |

## 🤝 Getting Help

If you get stuck:
- Check this guide's troubleshooting section
- Review logs: `docker logs <container-name>`
- Check the [main README](./README.md) for architectural context
- Open an issue in the [central issue tracker](https://github.com/tonydail/microservices-ops/issues)
- Ask your team for help!

Happy coding! 🚀
