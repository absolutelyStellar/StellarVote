# StellarVote — Agent Guide

## Entrypoint & Structure

- **Module**: `StellarVote`, Go 1.26.1
- **Entrypoint**: `cmd/api/main.go` — builds to `main.exe`
- **Router**: `julienschmidt/httprouter` (NOT standard `net/http` ServeMux); method is first arg: `r.HandlerFunc(http.MethodGet, "/path", handler)`
- **DB driver**: `pgx/v5` via `database/sql` stdlib adapter (`github.com/jackc/pgx/v5/stdlib`)
- **Env loading**: `github.com/joho/godotenv/autoload` — imported silently in `internal/server/server.go` and `internal/database/database.go`; `.env` is loaded automatically at package init

## Commands

| Command | What it does |
|---|---|
| `make build` | `go build -o main.exe cmd/api/main.go` |
| `make run` | `go run cmd/api/main.go` |
| `make test` | `go test ./... -v` (includes integration tests) |
| `make itest` | `go test ./internal/database -v` (integration tests only) |
| `make watch` | Installs `air-verse/air` if missing, then runs `air` for live reload |
| `make docker-run` / `make docker-down` | `docker compose up --build` / `docker compose down` |

**Command order**: `make docker-run` (start Postgres) → `make run` (start API).
**Full cycle**: `make all` runs `build` then `test`.

## Testing Quirks

- **Database tests** (`internal/database/`) use `testcontainers-go` to spin up a real Postgres container. Requires Docker to be running.
- `make test` will invoke these too — if Docker isn't running, tests fail.
- To skip integration tests: `go test $(go list ./... | grep -v /database/) -v`
- Server tests (`internal/server/routes_test.go`) are pure unit tests (no DB, no Docker).

## Database

- Postgres config via env vars with `BLUEPRINT_DB_*` prefix (legacy blueprint template naming):
  `BLUEPRINT_DB_HOST`, `BLUEPRINT_DB_PORT`, `BLUEPRINT_DB_DATABASE`, `BLUEPRINT_DB_USERNAME`, `BLUEPRINT_DB_PASSWORD`, `BLUEPRINT_DB_SCHEMA`
- Dev `.env` committed to repo; production values never committed (`.env` gitignored)
- DB connection is a **singleton** (package-level `dbInstance` in `internal/database/database.go`) — tests reset package vars (`database`, `password`, `username`, `host`, `port`) to point at testcontainers
- No migration files exist yet; schema is in planning docs only

## Platform

- Windows dev environment: binary is `main.exe`, `make watch` uses PowerShell
- Build for other platforms: override `GOOS`/`GOARCH`

## Architecture Context

The repo is an **early scaffold** (hello world + health endpoint + DB health check). The planned full architecture (from `docs/`) is:
- **Go REST API** (orchestration layer) — existing scaffold
- **Authula** (auth provider) — not yet integrated; mounts at `/auth` in library mode
- **PostgreSQL** (indexed reads / analytics)
- **Soroban smart contracts** (vote integrity — not yet implemented)
- **TypeScript SDK + Next.js frontend** (not yet implemented)

### Auth Architecture (planned, not yet coded)

- **User auth**: Authula library mode (`github.com/Authula/authula`) — email/password + OTP, Google OAuth, GitHub OAuth. JWT + Bearer plugins replace default session cookies.
- **App-level auth**: StellarVote-owned `api_keys` table + middleware (prefix lookup + constant-time hash compare). CRUD APIs not yet built.
- **Stellar wallet auth**: Post-MVP, via custom Authula plugin.
- **RBAC**: Authula access-control plugin (roles → permissions → user assignment within orgs).
- **Multi-tenancy**: Authula organizations plugin (each org = one tenant/app).

### Current code vs planned

| Layer | Status |
|---|---|
| Go backend scaffold | Built |
| Authula integration | Not started |
| API key CRUD + middleware | Not built |
| Soroban contracts | Not implemented |
| Frontend / SDK | Not implemented |

The `docs/` directory contains forward-looking PRD, architecture, ERD (updated for Authula boundary), and auth flow docs.

## Noteworthy

- `.gitignore` lists `*templ.go` — if you add templ codegen, generated files don't get committed
- No CI workflows exist yet
- `make clean` removes `main` (not `main.exe`) — may leave Windows binary behind
- Server has graceful shutdown (SIGINT/SIGTERM → 5s timeout)
- CORS is wide open (`Access-Control-Allow-Origin: *`)
