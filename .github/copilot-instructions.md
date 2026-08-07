# Copilot Instructions

## Repository Layout

Workspace orchestrator root — no application source lives here.
Each service is its own Git repository cloned as a subdirectory.

```
microservices/
├── microservice-auth-service/  ← separate git repo
├── microservice-users-service/ ← separate git repo
└── microservice-core-services/
    ├── docker-compose.yml          ← shared infra (Kafka, Debezium, nginx)
    ├── gateway/nginx.conf
    ├── debezium/connectors/        ← Debezium connector configs
    ├── k8s/                        ← Kubernetes namespace manifests + Helm charts
    ├── config-environment.sh       ← platform management scripts
    ├── start-platform.sh
    ├── stop-platform.sh
    └── teardown-platform.sh
```

---

## Services

| Service | REST Port | gRPC Port | Postgres (host) |
|---|---|---|---|
| microservice-auth-service | 3001 | 50051 | 5433 |
| microservice-users-service | 3002 | 50052 | 5434 |
| nginx gateway | 80 | — | — |
| Kafka (host) | — | — | 29092 |
| Kafka Connect | 8083 | — | — |
| Kafka UI | 8080 | — | — |

**microservice-auth-service**: registration, login, JWT access (15m) + refresh (7d) tokens, token refresh, logout/revocation.

**microservice-users-service**: user profile CRUD. Consumes `auth.user.registered` from Kafka to create profiles on registration.

---

## Dev Containers

Each service has its own `.devcontainer/` — open that service folder in VS Code and click **"Reopen in Container"**. Its app container + dedicated Postgres start independently.

Both devcontainers join the external `microservices-net` Docker bridge network, enabling them to reach `kafka:9092`, `nginx`, and each other over gRPC.

### First-time setup
```bash
docker network create microservices-net
cd microservice-core-services && ./start-platform.sh

# Register Debezium connectors once:
curl -X POST http://localhost:8083/connectors \
  -H 'Content-Type: application/json' \
  -d @debezium/connectors/auth-outbox-connector.json

curl -X POST http://localhost:8083/connectors \
  -H 'Content-Type: application/json' \
  -d @debezium/connectors/users-outbox-connector.json
```

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

---

## API Gateway

nginx on port 80. JWT validated at gateway; `X-User-Id` / `X-User-Role` headers injected before forwarding.
Services trust those headers — **no re-validation inside service code**.

- `/auth/*` → `auth-service:3001`
- `/users/*` → `users-service:3002`

---

## Key Conventions

- **Config**: Only `src/config/index.ts` reads `process.env` (Zod-parsed at startup). Never elsewhere.
- **Errors**: Controllers call `next(err)`. `errorHandler.ts` formats all responses via `AppError`. No stack traces in production.
- **No `any`**: Use `unknown` + Zod/type guards. Prisma types are canonical — do not redeclare them.
- **Validation**: Zod schemas in `src/types/`. Validate in controller before calling any service.
- **Logging**: Pino only (`src/config/logger.ts`). `info` = request lifecycle, `warn` = recoverable, `error` = unhandled. Never log secrets, passwords, or tokens.
- **Tests**: Unit tests use `vi.mock()` for all repos — no real DB. Integration tests require Postgres. Test files: `*.test.ts` in `tests/unit/` or `tests/integration/`.
- **TypeScript**: `strict: true`. No `any`.
- **.env**: `.env` is gitignored. Use `.env.example` as template.

---

## Commands (run from inside a service directory)

```bash
npm run dev                          # ts-node-dev watch
npm run build                        # tsc → dist/
npm run test                         # vitest run (all)
npm run test:unit                    # vitest run tests/unit
npm run test:integration             # vitest run tests/integration
npm run test -- path/to.test.ts      # single file
npm run lint                         # eslint src/
npm run lint:fix                     # eslint src/ --fix
npm run format                       # prettier --write src/
npm run db:migrate                   # prisma migrate dev
npm run db:migrate:prod              # prisma migrate deploy
npm run db:seed                      # ts-node prisma/seed.ts
npm run db:studio                    # prisma studio
```
