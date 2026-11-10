# ADR-0001: Persistence model — PostgreSQL, Flyway, and the database as referee for bids and closing

- **Status:** Accepted
- **Date:** 2026-11-10
- **Milestone:** M1

## Context

The platform must accept bids correctly when they arrive at the same moment. Two bids of the
same amount on the same lot must produce exactly one winner and one rejection. On top of that,
three things compete for the same auction near its end: incoming bids, the anti-sniping rule
that moves `ends_at` forward, and the scheduled job that closes auctions. The auction must be
closed **exactly once**, even if the application runs as two instances.

The course requires PostgreSQL or MySQL for the graded version, schema managed by Flyway or
Liquibase (no auto-generated schema), and JPA over Hibernate 7.

## Decision

1. **PostgreSQL 17** is the database in every environment: in Docker locally, through
   Testcontainers in integration tests, and on a managed free tier (Neon) in production.
2. **Flyway** owns the schema. Migrations are plain SQL in `src/main/resources/db/migration`.
   Hibernate runs with `ddl-auto: none` (later `validate`), so it never creates or changes tables.
3. **Correctness rules live in the database as well as in the service layer:**
   - A **partial unique index** `uq_bid_lot_amount_accepted ON bid (lot_id, amount) WHERE status = 'ACCEPTED'`.
     If two equal bids race, both may pass the Java check, but only one insert can succeed.
     The service catches the constraint violation and records the other bid as `REJECTED`.
   - Placing a bid takes a **pessimistic row lock on the lot** (`SELECT ... FOR UPDATE`) so that
     the "is this higher than the current price?" check and the update of `current_price` /
     `leading_bid_id` happen atomically.
   - **Closing is a conditional update:**
     `UPDATE auction SET status = 'CLOSED', closed_at = now() WHERE id = ? AND status = 'OPEN' AND ends_at <= now()`.
     Whoever gets "1 row updated" performs the closing work; everybody else gets 0 and does
     nothing. A bid that extended `ends_at` in the same moment makes the condition false, so the
     auction is not closed early.
   - `auction` and `lot` have a `version` column for **optimistic locking** of ordinary edits
     (seller changes a title while someone else edits the same record).
4. Money is stored as `NUMERIC(12,2)` and mapped to `BigDecimal`; times are `TIMESTAMPTZ` in UTC
   and mapped to `Instant`.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| **MySQL** | Allowed by the course, but MySQL has no partial (filtered) unique index, which is the simplest way to say "only accepted bids must be unique". Neon/Supabase also offer free managed PostgreSQL. |
| **Hibernate `ddl-auto=update`** | Not allowed in the final version, and it hides schema changes from the Git history. Flyway migrations are reviewable and repeatable. |
| **Liquibase** | Works equally well, but XML/YAML changelogs add a layer over SQL. Plain SQL in Flyway is easier to read in a defense. |
| **Only `synchronized` / Java locks** | Works only inside one JVM. With two instances (required for the scheduled jobs in LO7) two bids could still both be accepted. |
| **Only optimistic locking for bids** | Under heavy bidding at the end of an auction most transactions would fail with `OptimisticLockException` and need retries. A short row lock on one lot is simpler and fair. |
| **H2 everywhere** | Behaves differently from PostgreSQL in locking and in partial indexes, so the concurrency test would prove nothing. |

## Consequences

- (+) Equal concurrent bids are impossible even if the service has a bug; the test for advanced
  requirement 1 can fire two threads and assert one `ACCEPTED`, one `REJECTED`.
- (+) Closing "exactly once" does not depend on the scheduler running on one machine only.
- (+) The schema history is visible in Git as numbered migrations.
- (−) Tests that touch the database need Docker (Testcontainers); they are slower than H2 tests.
- (−) Business rules exist in two places (service + database). The database constraints are the
  safety net; the service gives users a friendly message.
- (−) Row locks on a lot serialize bids on that lot. This is acceptable: bids on one lot are rare
  compared with reads, and lots do not block each other.
