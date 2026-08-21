# Copilot Instructions

## Repository Layout

Workspace orchestrator root — no application source lives here.
Each service is its own Git repository cloned as a subdirectory.

```
microservices-ops/
├── microservice-auth-service/       ← separate git repo
│   ├── src/                         ← service source code
│   ├── prisma/                      ← schema + migrations
│   ├── tests/                       ← unit + integration tests
│   ├── .devcontainer/               ← VS Code dev container config
│   ├── start.sh / stop.sh           ← service lifecycle scripts
│   └── register-outbox-connector.sh ← registers Debezium connector
├── microservice-users-service/      ← separate git repo (same structure)
│   └── register-outbox-connector.sh
├── microservice-core-services/      ← shared infrastructure
│   ├── docker-compose.yml           ← Kafka, Debezium, nginx, CloudBeaver
│   ├── gateway/nginx.conf           ← API gateway routing
│   └── start.sh / stop.sh           ← infra lifecycle scripts
├── environment/                     ← .env files (created during onboarding, gitignored)
├── configure-environment.sh         ← creates environment files from onboarding-config.yml
└── clone-repositories.sh            ← clones all service repos from GitHub
```

---

## Services

| Service | REST Port | gRPC Port | Postgres (host) |
|---|---|---|---|
| microservice-auth-service | 3001 | 50051 | 5433 |
| microservice-users-service | 3002 | 50052 | 5434 |
| nginx gateway | 80 | — | — |
| Kafka (KRaft mode) | 29092 (host) | — | — |
| Kafka Connect | 8083 | — | — |
| Kafka UI | 8080 | — | — |

**microservice-auth-service**: registration, login, JWT access (15m) + refresh (7d) tokens, token refresh, logout/revocation.

**microservice-users-service**: user profile CRUD. Consumes `auth.user.registered` from Kafka to create profiles on registration.

---

## Dev Containers

Each service has its own `.devcontainer/` — open that service folder in VS Code and click **"Reopen in Container"**. Its app container + dedicated Postgres start independently.

Both devcontainers join the external `microservices-net` Docker bridge network, enabling them to reach `kafka:9092`, `nginx`, and each other over gRPC.

**Working in a devcontainer**: All `npm` commands, Prisma operations, and tests run inside the container. The container includes Node.js, Docker CLI (for host access), and GitHub CLI.

### First-time setup
```bash
# 1. Clone all service repositories (uses onboarding-config.yml):
./clone-repositories.sh

# 2. Configure environment variables (validates required tools):
./configure-environment.sh

# 3. Create shared Docker network and start core infrastructure:
cd microservice-core-services && ./start.sh

# 4. Start auth service:
cd ../microservice-auth-service && ./start.sh

# 5. Start users service:
cd ../microservice-users-service && ./start.sh
```

**Note:** Each service registers its own Debezium connector on startup. No manual registration needed!

### Access points (after startup)
- **API Gateway**: http://localhost (nginx)
- **Kafka UI**: http://localhost:8080 (Browse topics & consumers)
- **Kafka Connect**: http://localhost:8083 (Connector management)
- **CloudBeaver**: http://localhost:8978 (Database UI)

---

## Internal Layer Structure (both services, strict — no layer skipping)

```
src/
  routes/          # Express Router only — wires controllers, no logic
  controllers/     # Parse/validate req (Zod) → call service → next(err) on failure
  services/        # Business logic; orchestrates repos + outbox writes
  repositories/    # All Prisma queries; zero business logic
  events/
    producers/     # Kafka producer wrappers
    consumers/     # Kafka consumer handlers (idempotent)
    outbox/        # outbox.writer.ts — ONLY called inside prisma.$transaction
  grpc/
    server.ts      # gRPC server (microservice-auth-service exposes ValidateToken)
    client.ts      # gRPC client stubs (microservice-users-service calls microservice-auth-service)
    proto/         # .proto definitions
  middleware/      # authGuard.ts, errorHandler.ts (AppError class)
  config/
    index.ts       # Zod-validated env — only place process.env is read
    logger.ts      # Pino logger instance — import everywhere else
  types/           # Zod schemas + TypeScript interfaces
prisma/
  schema.prisma    # domain models + OutboxEvent model
  migrations/
tests/
  unit/            # vi.mock() all repos; no real DB
  integration/     # real Postgres required
```

---

## Transactional Outbox Pattern

Application code **never** publishes to Kafka directly. Always:

```ts
await prisma.$transaction([
  prisma.user.create({ data: userPayload }),
  prisma.outboxEvent.create({
    data: { aggregateId: userId, eventType: 'user.registered', payload: { ... } },
  }),
]);
```

Debezium watches `outbox_events` via Postgres WAL (pgoutput) and publishes to Kafka.
Topic convention: `<service>.<aggregate>.<event>` — e.g. `auth.user.registered`.
Consumers check `event_id` for deduplication (idempotent).

**Connector Registration:** Each service registers its own Debezium outbox connector during startup via `register-outbox-connector.sh`. No manual registration needed.

**Outbox Writer Location:** `src/events/outbox/outbox.writer.ts` — **never call standalone**, only inside `prisma.$transaction()`. Prefer repository methods that handle transactions internally.

---

## API Gateway

nginx on port 80. **JWT validation at gateway is planned but not yet implemented**. Once enabled, `X-User-Id` / `X-User-Role` headers will be injected before forwarding. Services will trust those headers — **no re-validation inside service code**.

Routing (see `microservice-core-services/gateway/nginx.conf`):
- `/auth/*` → `microservice-auth-service-app:3001`
- `/users/*` → `microservice-users-service-app:3002`

---

## Key Conventions

### Configuration & Environment
- **Config**: Only `src/config/index.ts` reads `process.env` (Zod-parsed at startup). Never elsewhere.
- **.env**: Each service uses `.env` (gitignored). Devcontainer loads from `environment/*.env` files at workspace root.
- **Environment files**: Created by `configure-environment.sh` from `onboarding-config.yml`. Never commit `environment/` folder.

### Error Handling
- **Controllers**: Always call `next(err)` for errors. Never `res.status(...).json()` directly on errors.
- **AppError**: Custom error class in `src/middleware/errorHandler.ts`. Use for expected errors with specific status codes.
- **Error Handler**: `errorHandler.ts` middleware formats all responses. No stack traces in production.
- **Zod Errors**: Automatically formatted to `{ error: 'Validation error', details: {...} }` by error handler.

### TypeScript & Validation
- **No `any`**: Use `unknown` + Zod/type guards. `strict: true` in tsconfig.json.
- **Prisma types**: Canonical — import from `@prisma/client`, do not redeclare.
- **Zod schemas**: Define in `src/types/`. Validate in controller before calling service.
- **Type location**: `src/types/*.types.ts` — one file per domain area.

### Logging
- **Pino only**: Import from `src/config/logger.ts`. Never use `console.log()`.
- **Log levels**:
  - `logger.info()` — request lifecycle, normal operations
  - `logger.warn()` — recoverable issues, degraded state
  - `logger.error()` — unhandled errors, failures
- **Never log**: secrets, passwords, tokens, full JWTs, or sensitive user data.
- **Structured logging**: Always use object first: `logger.info({ userId, action }, 'User logged in')`

### Testing
- **Unit tests**: `tests/unit/` — `vi.mock()` for all repos, services, external deps. No real DB.
- **Integration tests**: `tests/integration/` — real Postgres required. Test full flow.
- **Test files**: `*.test.ts` naming convention.
- **Run single test**: `npm run test -- path/to/file.test.ts`
- **Vitest config**: `vitest.config.ts` in service root.

### Database & Prisma
- **Migrations**: Never edit generated migrations. Create new migration for changes.
- **Schema location**: `prisma/schema.prisma` — includes OutboxEvent model for transactional outbox.
- **Client generation**: Run `npm run db:generate` after schema changes.
- **Queries**: All Prisma queries in `repositories/` — zero business logic, just data access.
- **Transactions**: Use `prisma.$transaction()` for multi-step operations. Always include outbox writes in transaction.

### Code Style
- **ESLint + Prettier**: Configured. Run `npm run lint:fix` and `npm run format` before commit.
- **Import order**: Config → types → services → repositories → middleware → utils.
- **No default exports**: Use named exports for better refactoring.

---

## Orchestrator Scripts (run from repository root)

```bash
./clone-repositories.sh             # Clone all service repos from GitHub
./configure-environment.sh          # Create environment files + validate required tools
```

### Per-service scripts (run from service directory)
```bash
./start.sh                           # Start this service's containers
./stop.sh                            # Stop this service's containers
./teardown.sh                        # Stop & remove containers + volumes (data loss)
./register-outbox-connector.sh       # Manually register Debezium connector
```

---

## Commands (run from inside a service directory)

### Development
```bash
npm run dev                          # ts-node-dev watch (hot reload)
npm run build                        # tsc → dist/ + copy .proto files
npm start                            # node dist/index.js (production)
```

### Testing
```bash
npm run test                         # vitest run (all tests)
npm run test:unit                    # vitest run tests/unit
npm run test:integration             # vitest run tests/integration
npm run test:watch                   # vitest (interactive watch mode)
npm run test -- path/to.test.ts      # run single test file
```

### Code Quality
```bash
npm run lint                         # eslint src/
npm run lint:fix                     # eslint src/ --fix
npm run format                       # prettier --write src/
```

### Database (Prisma)
```bash
npm run db:migrate                   # prisma migrate dev (creates + applies migrations)
npm run db:migrate:prod              # prisma migrate deploy (production)
npm run db:seed                      # ts-node prisma/seed.ts
npm run db:studio                    # prisma studio (GUI)
npm run db:generate                  # prisma generate (regenerate client after schema changes)
```

---

## Debugging

### Logs
```bash
# View service logs
docker logs -f microservice-auth-service-app
docker logs -f microservice-users-service-app
docker logs kafka-connect              # Debezium connector logs

# Follow multiple logs
docker compose logs -f                  # (from service directory)
```

### Kafka
```bash
# List topics
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --list

# Consume messages (from beginning)
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic auth.user.registered \
  --from-beginning

# Check connector status
curl http://localhost:8083/connectors/auth-outbox-connector/status | jq
```

### Database
```bash
# Connect to service database
docker exec -it microservice-auth-service-db psql -U authuser -d authdb

# View outbox events
npm run db:studio    # Prisma Studio GUI
```

### Dev Container debugging
- **Attach debugger**: VS Code → Run → Attach to Node Process (port 9229)
- **Service not reachable**: Check `docker network inspect microservices-net`
- **Hot reload not working**: Restart Dev Container
