# StellarVote

**Governance-as-a-Service for the Stellar ecosystem.**

StellarVote is an open-source platform that lets any Stellar application, DAO, or community embed secure, auditable voting without building governance infrastructure from scratch. A Go REST API orchestration layer, Soroban smart contracts for vote integrity, a TypeScript SDK for easy integration, and a Next.js frontend - all working together to make on-chain governance a plug-and-play utility.

---

## Why StellarVote?

Today, every Stellar project that needs voting builds it themselves - inconsistently, often insecurely, and never interoperably. StellarVote standardizes that layer:

- **On-chain integrity** - votes recorded on Soroban, not just in a database. Double-vote prevention and tamper-proof audit trails are built in, not bolted on.
- **Off-chain performance** - PostgreSQL indexes votes for real-time dashboards and analytics. The chain is the source of truth; the database is the speed layer.
- **Pluggable eligibility** - wallet-based, token-weighted, or whitelist voting per election. The identity model doesn't dictate the governance model.
- **SDK-first** - embed voting in any frontend with a TypeScript SDK and optional React components.

---

## What We're Building

Four major feature areas, each being built from scratch:

### 1. Soroban Smart Contracts

The immutable foundation. An ElectionContract on Soroban stores election metadata, records votes with transaction hashes, enforces eligibility rules, and prevents double voting through on-chain checks. No one, not even the election creator, can alter votes after they're cast.

**Key deliverables:**
- On-chain data structures for elections, candidates, and vote records
- Election initialization and metadata management
- Vote casting with wallet-based, whitelist, and token-weighted eligibility
- Double-vote prevention and time-window enforcement
- Read-only queries for election state, vote tallies, and audit verification
- Comprehensive Soroban Rust test suite

### 2. Go REST API

The orchestration layer that bridges the blockchain to the rest of the platform. Manages election lifecycles, ingests on-chain votes into a queryable PostgreSQL database, authenticates admins and SDK clients, and serves real-time analytics.

**Key deliverables:**
- HTTP server with middleware (logging, CORS, recovery, rate-limiting)
- PostgreSQL schema with Goose migrations and sqlc code generation
- Election CRUD endpoints (create, read, list, update status, delete)
- Vote ingestion service that indexes Soroban events into PostgreSQL
- JWT-based admin authentication and API key auth for SDK clients
- Analytics and results aggregation endpoints
- OpenAPI 3.0 specification

### 3. TypeScript SDK

The developer-facing integration layer. Wraps the Go REST API and Soroban interactions into a clean, promise-based interface. With an app ID and API key, developers can create elections, cast votes, retrieve results, and verify votes on-chain - without managing blockchain internals.

**Key deliverables:**
- Dual-target npm package (browser and Node.js)
- HTTP client with typed error handling
- Election management methods (create, get, list)
- Vote casting with Stellar wallet signing and Soroban submission
- Results retrieval and on-chain vote verification
- Full API reference and usage documentation

### 4. Next.js Frontend

The end-user facing layer. An admin dashboard for creating and managing elections, a public voting page where users connect their Stellar wallets and cast votes, transparent results pages with audit trails, an analytics dashboard with charts and insights, and an embed generator for dropping voting widgets into external sites.

**Key deliverables:**
- Project scaffold with routing, auth state, and reusable UI components
- Admin dashboard with election creation form and list views
- Public voting page with wallet connection and transaction signing
- Results page with vote tallies, distribution charts, and on-chain audit trail
- Analytics dashboard with time-series and participation metrics
- Embed generator with live preview and copy-paste code snippets

---

## MVP Scope

| In scope | Out of scope (later) |
|---|---|
| Wallet-based, whitelist, and token-weighted voting | NFT voting |
| Soroban vote recording and double-vote prevention | Privacy-preserving voting |
| Go REST API with PostgreSQL indexing | DID / identity systems |
| Admin dashboard for election management | Delegated voting |
| Public voting page | Cross-chain voting |
| Results and analytics views | Governance marketplaces |
| TypeScript SDK (browser + Node.js) | Quadratic voting |
| Embeddable voting widget | Reputation systems |

---

## Auth Model

Two auth paths, one system:

- **Dashboard users** authenticate via Authula (email/password + OTP, Google OAuth, GitHub OAuth) mounted at `/auth` on the Go backend. Sessions use JWTs.
- **SDK / API clients** authenticate via API keys (argon2-hashed, prefix-lookup). Each key is owned by a user and scoped to their elections.

Elections are owned directly by users or wallet addresses. No org hierarchy, no multi-tenancy overhead - create, share, vote.

---

## Architecture (Planned)

```
End User (Wallet)
       |
       v
Next.js Frontend (Voting UI / Admin Dashboard)
       |
       v
TypeScript SDK (StellarVote SDK)
       |
       v
Go REST API (Orchestration, Auth, Validation)
       |
       +--------> PostgreSQL (Indexing, Analytics)
       |
       +--------> Soroban Contract (Vote Recording, Integrity)
```

Soroban is the truth layer; PostgreSQL is the speed layer. Each vote carries its transaction hash, so anyone can independently verify the chain.

The full system is documented in the [`docs/`](docs/) directory - PRD, system architecture, ERD, auth flows, and plugin configurations.

---

## Quick Start (Current)

```bash
# Prerequisites: Go 1.26+, Docker (for Postgres)

# Start Postgres
make docker-run

# Run the API
make run

# Run tests
make test
```

The API currently serves `GET /` (hello world) and `GET /health` (health check with DB ping).

---

## Project Structure

```
cmd/api/main.go          # Entrypoint - builds to main.exe
internal/
  server/                # HTTP server, routes, handlers
  database/              # pgx/v5 DB singleton
docs/
  PRD.md                 # Full product requirements
  system-architecture.md # Layered architecture deep-dive
  authentication-flow.md # Authula integration design
  authula-plugins.md     # Plugin configuration reference
  ERD.mmd                # Entity-relationship diagram
```

---

## Commands

| Command | What it does |
|---|---|
| `make build` | Build to `main.exe` |
| `make run` | Run the API server |
| `make test` | Full test suite (includes Docker-backed integration tests) |
| `make itest` | Database integration tests only |
| `make watch` | Live reload via `air` |
| `make docker-run` | Start Postgres container |
| `make docker-down` | Stop Postgres container |

---

## Philosophy

**Governance is infrastructure, not a feature.** StellarVote treats voting the way Stripe treats payments - as a standardized, pluggable layer that application developers shouldn't have to think about. The project values:

- **Verifiability over trust** - voters don't need to trust the operator; they can check the chain.
- **Developer experience** - clean SDK, clear docs, embeddable widgets.
- **Pragmatic layering** - use the chain for what it's good at (integrity, uniqueness) and the database for what it's good at (speed, queries).
- **Honest scope** - this doesn't solve real-world identity (Sybil attacks). It provides pluggable eligibility rules and lets each election define its trust model.

---

## License

Apache 2.0
