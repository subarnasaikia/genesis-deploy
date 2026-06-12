# Backend — Architecture

The Genesis backend is a **Spring Boot 3 modular monolith** on **Java 21**,
built with Maven. It exposes a REST API consumed by the Next.js frontend and
persists everything in PostgreSQL.

## Module structure

The build is a Maven multi-module project. `genesis-api` is the entry point —
it holds the `@SpringBootApplication` class, wires every other module
together, and contains no business logic of its own.

| Module | Role |
|---|---|
| `genesis-api` | Application entry point; configuration and wiring only |
| `genesis-common` | Shared DTOs, the `TextProcessor` interface, value objects |
| `genesis-user` | Authentication (JWT + refresh tokens) and user management |
| `genesis-workspace` | Workspace and document lifecycle, member roles |
| `genesis-coref` | Coreference mentions and clusters |
| `genesis-ner` | Named-entity annotation |
| `genesis-pos` | Part-of-speech tagging, custom tag sets |
| `genesis-wsd` | Word-sense disambiguation, sense inventories |
| `genesis-editor` | Per-user editor session persistence |
| `genesis-notification` | Event-driven in-app notifications |
| `genesis-recommend` | Annotation recommendations |
| `genesis-import-export` | TXT / CoNLL-2012 import and export |
| `genesis-logging` | Structured logging support |
| `genesis-infra` | Database config, file storage (Cloudinary), cross-cutting infrastructure |

## Layering inside each module

Every module follows the same internal layout:

```
controller/   thin REST layer — delegates immediately to the service
service/      transactional business logic
repository/   Spring Data JPA interfaces (infra layer only)
entity/       JPA entities
dto/          request/response objects — entities never cross module boundaries
event/        Spring ApplicationEvent subclasses for cross-module signals
health/       per-module HealthIndicator implementations
```

## Cross-module communication

Modules never call each other's services directly. Instead they publish
Spring application events and interested modules listen. Example — the
document upload flow:

```
DocumentController
  → DocumentService            (saves document, publishes DocumentUploadedEvent)
    → ImportService            (listens; runs prepareForAnnotation)
      → TextProcessor          (tokenises into sentences/tokens)
        → publishes DocumentTokenizedEvent
          → notification module creates in-app notifications
```

This keeps module boundaries enforceable (verified with ArchUnit tests) and
makes new annotation types addable without touching existing modules.

## Authentication

- **JWT access tokens** (default expiry 15 minutes) signed with HS256; the
  secret must be at least 256 bits and the app refuses to boot without it.
- **Refresh tokens** (default 7 days) with rotation on use.
- Tokens are issued by the user module; a Spring Security filter validates
  them on every request.

## API conventions

- Every endpoint returns a uniform envelope:
  `{ "success": boolean, "data": T, "message": string }`.
- Database identifiers and column/table names are `snake_case`.
- Pagination on large collections (documents, tokens) uses cursor/keyset
  pagination rather than offsets.
- `/actuator/health` is the liveness/readiness endpoint; in the `prod`
  profile only `health`, `info`, `metrics`, and `prometheus` are exposed.

## Persistence

- PostgreSQL with **Flyway migrations** (versioned `V*` scripts) in the
  `prod` profile; the `dev` profile may use `ddl-auto=update` for speed.
- Connection pooling via HikariCP with conservative pool sizes suitable for
  a single-VM deployment.
- Uploaded source files are stored in Cloudinary; the database stores
  metadata, tokens, sentences, and annotations.

## Configuration

All configuration is environment-driven (12-factor). The important variables:

| Variable | Purpose |
|---|---|
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | PostgreSQL connection |
| `JWT_SECRET` | Token signing key (≥ 32 chars, required) |
| `JWT_ACCESS_TOKEN_EXPIRY`, `JWT_REFRESH_TOKEN_EXPIRY` | Optional, Spring Duration strings |
| `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` | File storage |
| `CORS_ALLOWED_ORIGINS` | Allowed frontend origins — required in prod |
| `SPRING_PROFILES_ACTIVE` | `dev` or `prod` |
| `PORT` | HTTP port (default 8080) |

## Build & runtime

- `mvn clean package` produces a single executable jar in
  `genesis-api/target/`.
- The repo ships a multi-stage `Dockerfile`: a Maven/JDK 21 build stage with
  per-module dependency caching, then a slim JRE 21 Alpine runtime stage.
- In the `prod` profile the app writes a rolling log file to `/app/logs/`
  (rotated daily, 30 days retained) in addition to stdout.
