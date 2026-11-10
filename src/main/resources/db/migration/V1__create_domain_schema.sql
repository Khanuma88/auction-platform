-- P34 Online auction platform — initial domain schema
-- Aggregate: Auction -> Lot -> Bid -> Bidder ; Lot -> Category

-- Users: a "Bidder" in the domain is an app_user who places bids.
CREATE TABLE app_user (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(100) NOT NULL,
    display_name  VARCHAR(100) NOT NULL,
    role          VARCHAR(20)  NOT NULL CHECK (role IN ('BIDDER', 'SELLER', 'MODERATOR', 'ADMIN')),
    enabled       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE category (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(500),
    prohibited  BOOLEAN      NOT NULL DEFAULT FALSE  -- used by the AI screening feature
);

CREATE TABLE auction (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id             BIGINT       NOT NULL REFERENCES app_user (id),
    title                 VARCHAR(200) NOT NULL,
    description           TEXT,
    status                VARCHAR(20)  NOT NULL DEFAULT 'DRAFT'
                          CHECK (status IN ('DRAFT', 'SCHEDULED', 'OPEN', 'CLOSED', 'CANCELLED')),
    starts_at             TIMESTAMPTZ  NOT NULL,
    ends_at               TIMESTAMPTZ  NOT NULL,   -- moves forward on anti-sniping extension
    original_ends_at      TIMESTAMPTZ  NOT NULL,   -- the closing time the seller set
    anti_snipe_window_sec INT          NOT NULL DEFAULT 120 CHECK (anti_snipe_window_sec >= 0),
    extension_sec         INT          NOT NULL DEFAULT 120 CHECK (extension_sec >= 0),
    closed_at             TIMESTAMPTZ,             -- set exactly once, when the auction is closed
    version               BIGINT       NOT NULL DEFAULT 0, -- optimistic locking
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT chk_auction_times CHECK (ends_at > starts_at)
);
-- The closing job looks for OPEN auctions whose ends_at has passed.
CREATE INDEX idx_auction_status_ends_at ON auction (status, ends_at);

CREATE TABLE lot (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    auction_id      BIGINT        NOT NULL REFERENCES auction (id) ON DELETE CASCADE,
    category_id     BIGINT        NOT NULL REFERENCES category (id),
    title           VARCHAR(200)  NOT NULL,
    seller_notes    TEXT,                          -- input for the AI description draft
    description     TEXT,                          -- AI-drafted, edited by the seller
    starting_price  NUMERIC(12, 2) NOT NULL CHECK (starting_price > 0),
    min_increment   NUMERIC(12, 2) NOT NULL DEFAULT 1.00 CHECK (min_increment > 0),
    current_price   NUMERIC(12, 2),
    status          VARCHAR(25)   NOT NULL DEFAULT 'PENDING_MODERATION'
                    CHECK (status IN ('PENDING_MODERATION', 'APPROVED', 'REJECTED', 'SOLD', 'UNSOLD')),
    leading_bid_id  BIGINT,                        -- optional relation, FK added below
    version         BIGINT        NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_lot_auction ON lot (auction_id);
CREATE INDEX idx_lot_category ON lot (category_id);

CREATE TABLE bid (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lot_id     BIGINT         NOT NULL REFERENCES lot (id) ON DELETE CASCADE,
    bidder_id  BIGINT         NOT NULL REFERENCES app_user (id),
    amount     NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    kind       VARCHAR(10)    NOT NULL DEFAULT 'MANUAL' CHECK (kind IN ('MANUAL', 'PROXY')),
    status     VARCHAR(10)    NOT NULL DEFAULT 'ACCEPTED' CHECK (status IN ('ACCEPTED', 'REJECTED')),
    placed_at  TIMESTAMPTZ    NOT NULL DEFAULT now()
);
-- Advanced requirement 1: two accepted bids with the same amount on the same lot are impossible.
-- The database is the final referee; the service catches the violation and rejects the loser.
CREATE UNIQUE INDEX uq_bid_lot_amount_accepted ON bid (lot_id, amount) WHERE status = 'ACCEPTED';
CREATE INDEX idx_bid_lot_amount ON bid (lot_id, amount DESC);
CREATE INDEX idx_bid_bidder ON bid (bidder_id);

ALTER TABLE lot
    ADD CONSTRAINT fk_lot_leading_bid FOREIGN KEY (leading_bid_id) REFERENCES bid (id) ON DELETE SET NULL;

-- Advanced requirement 3: proxy bidding.
-- Association entity between Lot and Bidder (many-to-many) carrying attributes.
CREATE TABLE proxy_bid (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lot_id      BIGINT         NOT NULL REFERENCES lot (id) ON DELETE CASCADE,
    bidder_id   BIGINT         NOT NULL REFERENCES app_user (id),
    max_amount  NUMERIC(12, 2) NOT NULL CHECK (max_amount > 0),  -- hidden maximum
    active      BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ    NOT NULL DEFAULT now(),
    CONSTRAINT uq_proxy_bid_lot_bidder UNIQUE (lot_id, bidder_id)
);

-- AI feature: anything flagged is held for moderation before it goes live.
CREATE TABLE moderation_case (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lot_id                BIGINT       NOT NULL REFERENCES lot (id) ON DELETE CASCADE,
    flag_reason           VARCHAR(500) NOT NULL,
    ai_suggested_category VARCHAR(100),
    ai_confidence         NUMERIC(4, 3) CHECK (ai_confidence BETWEEN 0 AND 1),
    status                VARCHAR(10)  NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'APPROVED', 'REJECTED')),
    reviewer_id           BIGINT       REFERENCES app_user (id),  -- optional until a moderator decides
    decision_note         VARCHAR(500),
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    decided_at            TIMESTAMPTZ
);
CREATE INDEX idx_moderation_status ON moderation_case (status);
