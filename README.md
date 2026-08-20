# Microservices Operations

This repository serves as the **central orchestrator** for a set of microservices that provide authentication and user management functionality. The project is designed to be **forked and tailored** to specific use cases, offering a solid foundation for teams that need robust auth and profile management with modern event-driven architecture patterns.

## 🎯 Project Purpose

This microservices platform provides:
- **Authentication Service**: User registration, login, JWT token management (access + refresh tokens), token validation, and logout
- **User Management Service**: User profile CRUD operations with event-driven integration
- **Shared Infrastructure**: Kafka message broker, Debezium CDC, API gateway, and supporting tools

The repositories are structured for easy customization — fork the services you need and adapt them to your requirements.

## 📁 Repository Structure

This is a **workspace orchestrator** repository. Application code lives in separate Git repositories cloned as subdirectories:

```
microservices-ops/                      ← This repo (central orchestrator)
├── microservice-auth-service/          ← Separate repo: Authentication service
├── microservice-users-service/         ← Separate repo: User profile management
├── microservice-core-services/         ← Separate repo: Shared infrastructure
└── environment/                        ← Environment configuration files created during onboarding.  ** NOT ** to be commited to repository.
```

## 🏗️ Managed Repositories

| Repository | Purpose | GitHub |
|------------|---------|--------|
| **microservices-ops** | Central orchestrator & issue tracking | [tonydail/microservices-ops](https://github.com/tonydail/microservices-ops) |
| **microservice-auth-service** | Authentication & JWT token management | [tonydail/microservice-auth-service](https://github.com/tonydail/microservice-auth-service) |
| **microservice-users-service** | User profile management | [tonydail/microservice-users-service](https://github.com/tonydail/microservice-users-service) |
| **microservice-core-services** | Shared infrastructure (Kafka, nginx, etc.) | [tonydail/microservice-core-services](https://github.com/tonydail/microservice-core-services) |

> **Note:** This central repository is the **only** repository with GitHub Issues and Projects enabled. All issue tracking is centralized here. Individual service repositories have issues disabled.

## 🚀 Services Overview

| Service | REST Port | gRPC Port | Postgres (Host) | Purpose |
|---------|-----------|-----------|-----------------|---------|
| **auth-service** | 3001 | 50051 | 5433 | Registration, login, JWT management, token validation |
| **users-service** | 3002 | 50052 | 5434 | User profile CRUD, consumes registration events |
| **nginx gateway** | 80 | — | — | API gateway with JWT validation |
| **Kafka** | 29092 (host) | — | — | Event streaming platform |
| **Kafka Connect** | 8083 | — | — | Debezium CDC for transactional outbox |
| **Kafka UI** | 8080 | — | — | Kafka management UI |
| **CloudBeaver** | 8978 | — | — | Database administration tool |

## 🏛️ Architecture Overview

### Communication Patterns
- **External (Client → Services)**: REST API via nginx gateway (port 80)
- **Internal (Service → Service)**: gRPC for synchronous calls
- **Async (Service → Service)**: Kafka events via Transactional Outbox pattern

### Event-Driven Flow
1. Services write events to `outbox_events` table within database transactions
2. Debezium CDC watches PostgreSQL WAL and publishes events to Kafka
3. Consuming services process events idempotently using `event_id` for deduplication

### API Gateway
nginx validates JWT tokens at the gateway and injects `X-User-Id` and `X-User-Role` headers before forwarding requests to services:
- `/auth/*` → `auth-service:3001`
- `/users/*` → `users-service:3002`

### Network Architecture
All services join the `microservices-net` Docker bridge network, enabling communication between:
- Shared infrastructure (Kafka, nginx)
- Individual service Dev Containers
- Service databases

## 🛠️ Tech Stack

- **Runtime**: Node.js + TypeScript
- **API Framework**: Express (REST), gRPC (@grpc/grpc-js)
- **Database**: PostgreSQL + Prisma ORM
- **Messaging**: Apache Kafka + Debezium CDC
- **Gateway**: nginx
- **Validation**: Zod schemas
- **Logging**: Pino
- **Testing**: Vitest (unit + integration)
- **Code Quality**: ESLint + Prettier
- **Development**: Dev Containers (Docker)

## 🔑 Key Architectural Patterns

### Transactional Outbox Pattern
Services **never** publish to Kafka directly. All events are written to an `outbox_events` table within the same database transaction as the domain operation:

```typescript
await prisma.$transaction([
  prisma.user.create({ data: userPayload }),
  prisma.outboxEvent.create({
    data: { 
      aggregateId: userId, 
      eventType: 'user.registered', 
      payload: { ... } 
    }
  })
]);
```

Debezium monitors the WAL and publishes events to Kafka, ensuring exactly-once semantics.

### Layered Architecture
Each service follows strict layer separation:
- **Routes**: Express Router wiring (no logic)
- **Controllers**: Request parsing, Zod validation, response formatting
- **Services**: Business logic and orchestration
- **Repositories**: All Prisma queries (zero business logic)
- **Events**: Kafka producers/consumers + outbox writer

### Topic Naming Convention
Kafka topics follow the pattern: `<service>.<aggregate>.<event>`
- Example: `auth.user.registered`


## 🐛 Issue Tracking

**All issues and project management are centralized in this repository** using GitHub Issues and Projects. Individual service repositories have issues disabled.

To report bugs, request features, or track work:
- Open issues here: [microservices-ops/issues](https://github.com/tonydail/microservices-ops/issues)
- View project board: [microservices-ops/projects](https://github.com/tonydail/microservices-ops/projects)

## 🤝 Contributing

1. Fork the repository you want to modify
2. Create a feature branch
3. Make your changes following the established patterns
4. Write tests for new functionality
5. Submit a pull request
6. Track the issue in the central `microservices-ops` repository

## 📚 Additional Resources

- [Auth Service README](./microservice-auth-service/README.md)
- [Users Service README](./microservice-users-service/README.md)
- [Core Services README](./microservice-core-services/README.md)

## 🚀 Getting Started

Ready to start developing? We've prepared a comprehensive step-by-step guide to get you up and running in about 5 minutes. The guide covers prerequisites, first-time setup, development workflows, environment configuration, and common commands you'll use daily.

**➡️ [Read the complete Developer Onboarding Guide](./DEVELOPER-ONBOARDING.MD)**



For questions, issues, or feature requests, please use the [centralized issue tracker](https://github.com/tonydail/microservices-ops/issues).
