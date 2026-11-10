# Online Auction Platform (P34)

Sellers list items, buyers bid, and the highest bid at closing time wins.

Course project — *Rapid Development of Java Applications Using Programming Frameworks*, 2026/27.

## Current state: Milestone M1

| M1 item | Status | Where |
|---|---|---|
| Topic accepted | P34 Online auction platform | — |
| Domain model (entity diagram) | Done | [docs/domain-model.md](docs/domain-model.md) |
| First ADR | Done | [docs/adr/0001-persistence-model.md](docs/adr/0001-persistence-model.md) |
| Empty project running with the database in Docker | Done | `compose.yaml`, start page on `http://localhost:8080` |
| Low-fidelity wireframes in Figma | Link: _TODO_ | Figma |
| Hosting platform chosen | **Render** (application, Docker) + **Neon** (managed PostgreSQL) | — |
| AI provider chosen | **Google Gemini (Flash model, free tier) via Spring AI 2.0** | — |

## Technology

- Java 25, Spring Boot 4.1 (Spring MVC, Thymeleaf, Bean Validation)
- PostgreSQL 17, Flyway, Spring Data JPA / Hibernate 7, HikariCP
- Spring Boot Actuator (health check)
- JUnit + Mockito
- Docker / Docker Compose

Planned: Spring Security 7, springdoc-openapi, Spring AI, Testcontainers, Quartz, JaCoCo, GitHub Actions.

## How to run

Requirements: JDK 25, Docker Desktop.

```bash
# 1. Start PostgreSQL
docker compose up -d

# 2. Start the application (or run AuctionApplication in IntelliJ IDEA)
mvn spring-boot:run
```

Open <http://localhost:8080> — the page shows the PostgreSQL version, the number of applied
Flyway migrations and the seeded categories. Health check: <http://localhost:8080/actuator/health>.

Run everything in Docker (database + application):

```bash
docker compose --profile app up --build
```

## Project structure

```
src/main/java/com/auction
├── web/          controllers (Thymeleaf + later REST)
├── service/      business logic
└── repository/   database access
src/main/resources
├── db/migration/ Flyway SQL migrations
└── templates/    Thymeleaf pages
docs/
├── adr/          architecture decision records
└── domain-model.md
```

## Advanced requirements (planned)

1. **Concurrent equal bids** — one accepted, one rejected; enforced by a partial unique index and proven by a test.
2. **Anti-sniping** — a bid in the final window extends `ends_at`.
3. **Proxy bidding** — the system bids for the user up to a hidden maximum.
4. **AI feature** — draft the lot description from the seller's notes and screen for prohibited categories; flagged lots wait for a moderator.

## Limitations / next steps

M1 contains only the skeleton and the schema. Next: JPA entities, Spring Security with roles,
CRUD screens for Auction → Lot, REST API.
