Below is the **system architecture diagram for StellarVote**, designed for a Drips-level submission (clean, layered, and implementation-ready).

---

# 🧭 StellarVote — System Architecture Diagram

```
                           ┌──────────────────────────────┐
                           │        End Users             │
                           │  (DAO members / voters)     │
                           └────────────┬─────────────────┘
                                        │
                                        │ Wallet Connect (Stellar)
                                        ▼
                    ┌────────────────────────────────────────┐
                    │        Next.js Frontend               │
                    │  - Voting Pages                       │
                    │  - Admin Dashboard                    │
                    │  - Embedded Voting Widget            │
                    └────────────┬───────────────────────────┘
                                 │
                                 │ TypeScript SDK (StellarVote SDK)
                                 ▼
            ┌────────────────────────────────────────────────────┐
            │            API Gateway (Go Backend)               │
            │----------------------------------------------------│
            │  - Auth (API keys / apps)                         │
            │  - Election management                             │
            │  - Vote submission handler                         │
            │  - Rate limiting / validation                     │
            └────────────┬───────────────────────────┬──────────┘
                         │                           │
                         │                           │
                         ▼                           ▼
        ┌──────────────────────────┐   ┌──────────────────────────┐
        │     PostgreSQL DB        │   │   Soroban Smart Contracts │
        │--------------------------│   │----------------------------│
        │ - elections              │   │ - ElectionContract         │
        │ - candidates             │   │ - Vote recording           │
        │ - votes (indexed copy)   │   │ - Double-vote prevention   │
        │ - elections              │   │ - Eligibility enforcement   │
        │ - analytics cache        │   └────────────┬──────────────┘
        └────────────┬─────────────┘                │
                     │                              │
                     │ Indexing / Sync             │ On-chain write
                     ▼                              ▼
        ┌────────────────────────────────────────────────────┐
        │         Vote Indexer / Sync Service (Go)          │
        │----------------------------------------------------│
        │ - Listens to Soroban events                      │
        │ - Syncs votes into PostgreSQL                    │
        │ - Computes real-time results                     │
        │ - Maintains audit logs                           │
        └────────────────────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────────────────────┐
        │              Analytics / Results Layer            │
        │----------------------------------------------------│
        │ - Live vote counts                               │
        │ - Election results                               │
        │ - Verification API                               │
        │ - Export (CSV / JSON)                            │
        └────────────────────────────────────────────────────┘

```

---

# 🔁 Key Data Flow (Simplified)

### 1. Election Creation

```
Admin → Next.js Dashboard → Go API → PostgreSQL → (optional) Soroban init
```

### 2. Voting Flow

```
User Wallet → Frontend → SDK → Go API → Soroban Contract → Event emitted
```

### 3. Indexing Flow

```
Soroban Events → Go Indexer → PostgreSQL → Analytics Layer → UI updates
```

### 4. Result Display

```
Frontend → Go API → PostgreSQL (fast reads)
          ↘ verification check → Soroban (source of truth)
```

---

# 🧱 Architectural Layers Explained

## 1. Presentation Layer

* Next.js app
* Embedded voting widget
* Admin dashboard

Responsibility:

* UX, rendering, wallet interaction

---

## 2. Developer Layer (SDK)

* TypeScript SDK
* Wraps API + wallet signing
* Provides simple integration primitives

Example:

```ts
StellarVote.castVote()
```

---

## 3. Backend Layer (Go)

Acts as the control plane:

* Election lifecycle management
* Authentication (API keys)
* Validation
* Vote ingestion coordination
* Analytics computation

---

## 4. Blockchain Layer (Soroban)

Source of truth:

* Vote immutability
* Double-vote prevention
* Eligibility enforcement
* Auditability

---

## 5. Data Layer (PostgreSQL)

Optimized read layer:

* Fast dashboards
* Analytics
* Filtering
* Aggregation

Not trusted for integrity (Soroban is).

---

## 6. Indexer Layer

Bridges blockchain ↔ database:

* Listens to Soroban events
* Syncs state
* Computes derived metrics

---

# 🔐 Trust Model

| Layer      | Trust Role               |
| ---------- | ------------------------ |
| Soroban    | Truth (votes, integrity) |
| Backend    | Coordination             |
| PostgreSQL | Performance / analytics  |
| Frontend   | User interaction         |

---

# ⚙️ Why this architecture is strong (Drips perspective)

* Clear separation of concerns (on-chain vs off-chain)
* Real blockchain integration (Soroban is meaningful, not cosmetic)
* SDK-first design (developer tooling angle is strong)
* Scalable indexing system (real infra engineering)
* Flat ownership model (no org overhead, wallet-first)

---

If you want next step, I can generate any of these:

1. Soroban contract skeleton (production-grade structure)
2. Go backend folder architecture (clean hexagonal design)
3. PostgreSQL schema + Goose migrations
4. TypeScript SDK design (full API surface)
5. MVP build plan (week-by-week execution strategy)
