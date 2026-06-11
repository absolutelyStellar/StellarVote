Below are the **authentication + authorization flows** for StellarVote, covering:

* User-level auth (handled by **Authula**)
* API Key auth (app-level identity - StellarVote domain)

---

# 1. Authula-Managed Authentication (User Level)

All user identity flows are delegated to [Authula](https://authula.vercel.app/docs), mounted at `/auth` on the Go backend in library mode.

### Supported Methods

| Method | Authula Endpoint | Notes |
|---|---|---|
| Email + password + OTP | `POST /auth/email-password/sign-up` / `sign-in` | Verification email sent via Email plugin |
| Google OAuth | `GET /auth/oauth2/authorize/google` | Redirects to Google, callback at `/auth/oauth2/callback/google` |
| GitHub OAuth | `GET /auth/oauth2/authorize/github` | Same pattern as Google |
| Stellar wallet | **Post-MVP** | Custom Authula plugin TBD |

### Session Flow

```
User → Authula sign-in → Authula sets session cookie (authula.session_token)
                              │
                              ├── Browser sends cookie automatically with each request
                              ├── Session extended automatically (update_age = "5m")
                              └── Logout: POST /auth/sign-out clears cookie
```

Authula's default **Session plugin** is used. The cookie is `http_only` (not readable by JS), `secure` (in production), and `same_site = "lax"`. No access/refresh tokens - the session cookie is the sole auth mechanism for the dashboard.

Alternatively, the **JWT plugin** can replace session cookies with JWKS-based access + refresh tokens if stateless auth is preferred.

---

# 2. API Key Flow (Machine / SDK Access)

Machine-to-machine authentication for the StellarVote SDK and server integrations.

### Purpose

Used for:
* Creating elections
* Fetching results
* SDK operations
* Backend integrations

### Flow

```mermaid id="api_flow_1"
sequenceDiagram
    participant SDK as StellarVote SDK
    participant API as Backend API (Go)
    participant DB as PostgreSQL

    SDK->>API: Request (API Key in X-API-Key header)
    API->>API: Extract key_prefix (first 8 chars)
    API->>DB: SELECT FROM api_keys WHERE key_prefix = ?
    DB-->>API: key_hash + owner_id + metadata
    API->>API: Constant-time compare key_hash vs incoming key
    API->>API: Attach owner context (user_id)
    API-->>SDK: Authorized response
```

### Key Points

* API key maps to `api_keys.owner_id` (FK to `authula_users.id`)
* Keys are stored as **argon2-hashed**; only the prefix is stored in plaintext for lookup
* No human identity involved - this is machine-level auth
* API key management endpoints are owned by StellarVote (create, list, revoke)

---

# 3. Auth Decision by Client

| Client | Auth Method | Validation |
|---|---|---|
| Dashboard (web UI) | Session cookie (`authula.session_token`) | StellarVote middleware reads cookie, validates via Authula's session service, attaches `user_id` |
| SDK / automation | API Key (`X-API-Key`) | StellarVote middleware: prefix lookup → constant-time hash compare, attaches `owner_id` |

---

# 4. Identity Model

```text id="identity_map_1"
USER LEVEL (Authula)
    └── identifies a human (email, OAuth, or wallet)
    └── Authula tables: users, accounts

API KEY LEVEL (StellarVote)
    └── identifies a machine / SDK client
    └── StellarVote table: api_keys (FK owner_id → authula_users)

VOTER LEVEL (Blockchain)
    └── participates in elections (on-chain identity)
    └── wallet address, not stored in auth system
```

---

# 5. Storage Ownership

| Layer | Identity Type | Storage | Managed By |
|---|---|---|---|
| User | Email / OAuth / Wallet | Authula tables | Authula |
| API Key | Machine / SDK client | `api_keys` table | StellarVote |
| Voter | Wallet | Blockchain | Stellar (Soroban) |

---

# 6. Stellar Wallet Auth (Post-MVP)

When implemented, this will be a custom Authula plugin that:
1. Requests a nonce from `POST /auth/stellar/nonce`
2. User signs nonce with their Stellar wallet
3. Plugin verifies the ed25519 signature using Stellar's key format
4. On success, links wallet to the Authula user account and returns a JWT

Until then, admin users authenticate via email/password or OAuth.
