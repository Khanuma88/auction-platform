# Domain model — P34 Online auction platform

Sellers list items, buyers bid, and the highest bid at closing time wins.

**Aggregate:** `Auction → Lot → Bid → Bidder`; `Lot → Category`

![Entity diagram](domain-model.png)

```mermaid
erDiagram
    APP_USER ||--o{ AUCTION : "sells"
    AUCTION ||--|{ LOT : "contains"
    CATEGORY ||--o{ LOT : "classifies"
    LOT ||--o{ BID : "receives"
    APP_USER ||--o{ BID : "places (as bidder)"
    LOT |o--o| BID : "leading bid (optional)"
    LOT ||--o{ PROXY_BID : "has"
    APP_USER ||--o{ PROXY_BID : "sets hidden max"
    LOT ||--o{ MODERATION_CASE : "flagged in"
    APP_USER |o--o{ MODERATION_CASE : "reviews (optional)"

    APP_USER {
        bigint id PK
        varchar username UK
        varchar email UK
        varchar password_hash "BCrypt"
        varchar display_name
        varchar role "BIDDER, SELLER, MODERATOR, ADMIN"
        boolean enabled
    }
    CATEGORY {
        bigint id PK
        varchar name UK
        varchar description
        boolean prohibited "checked by AI screening"
    }
    AUCTION {
        bigint id PK
        bigint seller_id FK
        varchar title
        varchar status "DRAFT, SCHEDULED, OPEN, CLOSED, CANCELLED"
        timestamptz starts_at
        timestamptz ends_at "moved by anti-sniping"
        timestamptz original_ends_at
        int anti_snipe_window_sec
        int extension_sec
        timestamptz closed_at "set exactly once"
        bigint version "optimistic lock"
    }
    LOT {
        bigint id PK
        bigint auction_id FK
        bigint category_id FK
        varchar title
        text seller_notes "AI input"
        text description "AI draft"
        numeric starting_price
        numeric min_increment
        numeric current_price
        varchar status "PENDING_MODERATION, APPROVED, REJECTED, SOLD, UNSOLD"
        bigint leading_bid_id FK "nullable"
        bigint version
    }
    BID {
        bigint id PK
        bigint lot_id FK
        bigint bidder_id FK
        numeric amount
        varchar kind "MANUAL, PROXY"
        varchar status "ACCEPTED, REJECTED"
        timestamptz placed_at
    }
    PROXY_BID {
        bigint id PK
        bigint lot_id FK
        bigint bidder_id FK
        numeric max_amount "hidden maximum"
        boolean active
        timestamptz created_at
    }
    MODERATION_CASE {
        bigint id PK
        bigint lot_id FK
        varchar flag_reason
        varchar ai_suggested_category
        numeric ai_confidence
        varchar status "OPEN, APPROVED, REJECTED"
        bigint reviewer_id FK "nullable"
        timestamptz decided_at
    }
```

## How the model supports the requirements

| Requirement | Where it lives in the model |
|---|---|
| CRUD on the aggregate | `auction` (parent) → `lot` (child) → `bid` |
| One-to-many (LO4) | `auction` → `lot`, `lot` → `bid` |
| Many-to-many with an association entity carrying attributes (LO4) | `proxy_bid` between `lot` and bidder (`app_user`), carrying `max_amount`, `active`, timestamps |
| Optional relation (LO4) | `lot.leading_bid_id`, `moderation_case.reviewer_id` |
| Advanced 1 — concurrent equal bids | Partial unique index `uq_bid_lot_amount_accepted (lot_id, amount) WHERE status = 'ACCEPTED'`; the second insert fails and that bid is rejected |
| Advanced 2 — anti-sniping | `auction.ends_at` moves forward by `extension_sec` when a bid arrives within `anti_snipe_window_sec`; `original_ends_at` keeps the seller's time |
| Advanced 3 — proxy bidding | `proxy_bid.max_amount` is never shown to other users; generated bids are stored with `kind = 'PROXY'` |
| AI feature | `lot.seller_notes` → AI → `lot.description`; flagged lots get a `moderation_case` and stay `PENDING_MODERATION` |
| Hard part — close exactly once | `auction.status` + `closed_at` + `version`; closing is a conditional update `... WHERE status = 'OPEN' AND ends_at <= now()` (see ADR-0001) |

## Roles

| Role | Can do |
|---|---|
| BIDDER | Browse open auctions, place bids, set a proxy maximum |
| SELLER | Create auctions and lots, use the AI description draft |
| MODERATOR | Review flagged lots, approve or reject them |
| ADMIN | Manage users and categories |
