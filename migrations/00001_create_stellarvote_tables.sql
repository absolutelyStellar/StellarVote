-- +goose Up
CREATE TYPE voting_type AS ENUM ('wallet_based', 'token_weighted', 'whitelist');

CREATE TABLE api_keys (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id    UUID NOT NULL,
    name        TEXT NOT NULL,
    key_prefix  TEXT NOT NULL,
    key_hash    TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ
);

CREATE TABLE elections (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id           UUID NOT NULL,
    title              TEXT NOT NULL,
    description        TEXT,
    voting_type        voting_type NOT NULL,
    start_time         TIMESTAMPTZ NOT NULL,
    end_time           TIMESTAMPTZ NOT NULL,
    is_active          BOOLEAN NOT NULL DEFAULT true,
    soroban_contract_id TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE candidates (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id UUID NOT NULL REFERENCES elections(id) ON DELETE CASCADE,
    label       TEXT NOT NULL,
    description TEXT,
    metadata    JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE election_whitelist (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id     UUID NOT NULL REFERENCES elections(id) ON DELETE CASCADE,
    wallet_address  TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE token_snapshots (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id     UUID NOT NULL REFERENCES elections(id) ON DELETE CASCADE,
    wallet_address  TEXT NOT NULL,
    balance         NUMERIC NOT NULL,
    captured_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE votes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id     UUID NOT NULL REFERENCES elections(id) ON DELETE CASCADE,
    candidate_id    UUID NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    voter_address   TEXT NOT NULL,
    weight          NUMERIC NOT NULL DEFAULT 1,
    tx_hash         TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE election_vote_guard (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id     UUID NOT NULL REFERENCES elections(id) ON DELETE CASCADE,
    voter_address   TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE election_results (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id     UUID NOT NULL REFERENCES elections(id) ON DELETE CASCADE,
    candidate_id    UUID NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    vote_count      BIGINT NOT NULL DEFAULT 0,
    vote_weight     NUMERIC NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id UUID REFERENCES elections(id) ON DELETE SET NULL,
    actor       TEXT NOT NULL,
    action      TEXT NOT NULL,
    payload     JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_api_keys_prefix ON api_keys(key_prefix);
CREATE UNIQUE INDEX idx_api_keys_hash ON api_keys(key_hash);
CREATE INDEX idx_api_keys_owner ON api_keys(owner_id);

CREATE INDEX idx_elections_owner ON elections(owner_id);

CREATE INDEX idx_candidates_election ON candidates(election_id);

CREATE UNIQUE INDEX idx_whitelist_entry ON election_whitelist(election_id, wallet_address);
CREATE INDEX idx_whitelist_election ON election_whitelist(election_id);

CREATE UNIQUE INDEX idx_snapshot_entry ON token_snapshots(election_id, wallet_address);
CREATE INDEX idx_snapshots_election ON token_snapshots(election_id);

CREATE UNIQUE INDEX idx_vote_unique ON votes(election_id, voter_address);
CREATE INDEX idx_votes_election ON votes(election_id);
CREATE INDEX idx_votes_candidate ON votes(candidate_id);

CREATE UNIQUE INDEX idx_vote_guard_entry ON election_vote_guard(election_id, voter_address);
CREATE INDEX idx_vote_guard_election ON election_vote_guard(election_id);

CREATE UNIQUE INDEX idx_result_candidate ON election_results(election_id, candidate_id);
CREATE INDEX idx_results_election ON election_results(election_id);

CREATE INDEX idx_audit_logs_election ON audit_logs(election_id);

-- +goose Down
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS election_results;
DROP TABLE IF EXISTS election_vote_guard;
DROP TABLE IF EXISTS votes;
DROP TABLE IF EXISTS token_snapshots;
DROP TABLE IF EXISTS election_whitelist;
DROP TABLE IF EXISTS candidates;
DROP TABLE IF EXISTS elections;
DROP TABLE IF EXISTS api_keys;
DROP TYPE IF EXISTS voting_type;
