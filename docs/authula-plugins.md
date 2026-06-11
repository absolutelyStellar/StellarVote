# Authula Plugin Configuration Reference

All user-auth is delegated to [Authula](https://authula.vercel.app/docs) in **library mode** (`github.com/Authula/authula`), mounted at `/auth` on the existing Go server.

---

## 1. JWT Plugin — Stateless Auth Tokens

Replaces Authula's default session-cookie plugin with JWKS-based access + refresh tokens.

```go
jwtplugin.New(jwtplugintypes.JWTPluginConfig{
    Enabled:                true,
    Algorithm:              jwtplugintypes.JWTAlgEdDSA,
    ExpiresIn:              15 * time.Minute,
    RefreshExpiresIn:       168 * time.Hour,             // 7 days
    KeyRotationInterval:    720 * time.Hour,             // 30 days
    KeyRotationGracePeriod: time.Hour,
    JWKSCacheTTL:           24 * time.Hour,
    RefreshGracePeriod:     10 * time.Second,
})
```

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/.well-known/jwks.json` | Public JWKS for token verification |
| `POST` | `/auth/token/refresh` | Exchange refresh token for new pair |

### Response on sign-in

```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ..."
}
```

### Tables created

- `jwt_keys` — signing key pairs, rotated on interval
- `jwt_refresh_tokens` — user-bound refresh tokens with revocation support

### Hook usage

- `jwt.respond_json` — attach to sign-in/sign-up routes so Authula returns JWT pairs instead of session cookies

---

## 2. Bearer Plugin — JWT Validation Middleware

Validates the `Authorization: Bearer <token>` header against the JWT plugin's JWKS.

```go
bearerplugin.New(bearerplugintypes.BearerPluginConfig{
    Enabled: true,
})
```

### Hook usage

Routes in the dashboard require `bearer.auth` (required auth) or `bearer.auth.optional` before access-control enforcement.

### Notes

- Replaces the `session.auth` hook for dashboard API routes.
- Reads JWT from the `Accept` header per config, not from cookies.
- Required before access-control enforcement in the route-mapping chain.

---

## 3. Email & Password Plugin — Sign-Up / Sign-In

```go
emailpasswordplugin.New(emailpasswordplugintypes.EmailPasswordPluginConfig{
    Enabled:                       true,
    MinPasswordLength:             8,
    MaxPasswordLength:             128,
    DisableSignUp:                 false,
    RequireEmailVerification:      true,
    AutoSignIn:                    true,
    SendEmailOnSignUp:             true,
    SendEmailOnSignIn:             false,
    EmailVerificationExpiresIn:    24 * time.Hour,
    PasswordResetExpiresIn:        time.Hour,
    RequestEmailChangeExpiresIn:   time.Hour,
})
```

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/auth/email-password/sign-up` | Register with email + password |
| `POST` | `/auth/email-password/sign-in` | Sign in |
| `GET` | `/auth/email-password/verify-email` | Verify email via link |
| `POST` | `/auth/email-password/send-email-verification` | Resend verification |
| `POST` | `/auth/email-password/request-password-reset` | Request reset email |
| `POST` | `/auth/email-password/change-password` | Change password |
| `POST` | `/auth/email-password/request-email-change` | Request email change |

### Tables

None — uses Authula's core `users` table.

### Notes

- Passwords are hashed with **argon2** automatically.
- OTP/verification emails require the **Email plugin**.
- Route-mapping should chain `jwt.respond_json` on sign-in/sign-up to return JWT tokens.

---

## 4. OAuth2 Plugin — Google / GitHub Login

```go
oauth2plugin.New(oauth2plugintypes.OAuth2PluginConfig{
    Enabled: true,
    Providers: map[string]oauth2plugintypes.ProviderConfig{
        "google": {
            Enabled:      true,
            ClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
            ClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
            RedirectURL:  "http://localhost:8080/auth/oauth2/callback/google",
        },
        "github": {
            Enabled:      true,
            ClientID:     os.Getenv("GITHUB_CLIENT_ID"),
            ClientSecret: os.Getenv("GITHUB_CLIENT_SECRET"),
            RedirectURL:  "http://localhost:8080/auth/oauth2/callback/github",
        },
    },
})
```

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/auth/oauth2/authorize/{provider}` | Redirect user to provider |
| `GET` | `/auth/oauth2/callback/{provider}` | Handle callback, create/link account |

### Tables

None — links to Authula's core `accounts` table.

### Notes

- Provider client IDs/secrets set via env vars (`GOOGLE_CLIENT_ID`, `GITHUB_CLIENT_ID`, etc.).
- Redirect URL must match exactly what's registered with the OAuth provider.
- Route-mapping should chain `jwt.respond_json` on the callback to return JWT.

---

## 5. Organizations Plugin (Optional — Not Used in MVP)

The Organizations plugin is **not required** for StellarVote's flat ownership model. Elections and API keys are owned directly by a user (via `authula_users.id`), not scoped to an organization.

This plugin may be added in a future phase if multi-user election management (teams, shared workspaces) is needed. For MVP, the simpler model applies: one user creates and controls their elections.

---

## 6. Access Control Plugin (Optional — Not Used in MVP)

The Access Control plugin is **not required** for StellarVote's flat ownership model. Authorization is simple: the resource owner has full control. No roles, permissions, or RBAC are needed at this stage.

This plugin may be added later if the Organizations plugin is introduced and multi-user election management requires permission scoping.

---

## 7. Admin Plugin (Optional)

Provides user management, session management, and impersonation endpoints. Not needed for MVP but useful if the platform grows to support multiple users.

```go
adminplugin.New(adminplugintypes.AdminPluginConfig{
    Enabled:                   true,
    ImpersonationMaxExpiresIn: 15 * time.Minute,
})
```

### Useful endpoint groups

| Group | Key endpoints |
|---|---|
| Users | `GET/POST/PATCH/DELETE /auth/admin/users[/{id}]` |
| Banning | `POST /auth/admin/users/{id}/ban`, `/unban` |
| Sessions | `GET /auth/admin/users/{id}/sessions`, `POST /auth/admin/sessions/{id}/revoke` |
| Impersonation | `POST /auth/admin/impersonations` (start), `POST .../{id}/stop` |

### Tables created

- `admin_impersonations` — audit trail for impersonation events
- `admin_user_states` — ban state per user
- `admin_session_states` — revocation/impersonation state per session

---

## 8. Email Plugin — Transactional Emails

Required by the Email & Password plugin for verification, OTP, and password-reset emails.

```go
emailplugin.New(emailplugintypes.EmailPluginConfig{
    Enabled:          true,
    Provider:         emailplugintypes.ProviderSMTP,   // or "resend"
    FromAddress:      "noreply@stellarvote.io",
    TLSMode:          emailplugintypes.SMTPTLSModeStartTLS,
    FallbackProvider: emailplugintypes.ProviderResend,  // optional backup
})
```

### SMTP config

| Env var | Example |
|---|---|
| `SMTP_HOST` | `smtp.sendgrid.net` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | `apikey` |
| `SMTP_PASS` | `SG.xxxxx` |

### Resend config

| Env var | Example |
|---|---|
| `RESEND_API_KEY` | `re_xxxxx` |

### Notes

- No tables, no HTTP endpoints — internal service only.
- `from_address` must be verified with the provider for deliverability.
- OTP emails are triggered by the Email & Password plugin, not called directly.

---

## 9. Rate Limit Plugin — Abuse Protection

Protects auth endpoints from brute-force attacks. Uses Redis when running multiple instances.

```go
ratelimitplugin.New(ratelimitplugin.RateLimitPluginConfig{
    Enabled:  true,
    Provider: ratelimitplugin.RateLimitProviderRedis,
    Window:   time.Minute,
    Max:      100,                    // global default
    Prefix:   "ratelimit:",
    CustomRules: map[string]ratelimitplugin.RateLimitRule{
        "/auth/email-password/sign-in": {
            Window: 15 * time.Minute,
            Max:    10,
        },
        "/auth/email-password/sign-up": {
            Window: 15 * time.Minute,
            Max:    5,
        },
    },
})
```

### Table (database provider only)

- `rate_limits` — key-value with expiry. Uses unlogged table in Postgres for performance.

### Notes

- **Memory** provider is fine for single-instance dev. Use **Redis** for production multi-instance.
- Auth endpoints should have stricter limits (e.g., 10 attempts per 15 min for sign-in).
- `OPTIONS` requests and WebSocket upgrades are automatically excluded.
- Standard rate-limit headers (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-Retry-After`) are set on all responses.

---

## 10. Secondary Storage Plugin (Optional)

Enables Redis-backed key-value storage for session blacklisting (sign-out immediately invalidates sessions). Only needed if immediate session revocation is required outside the session plugin's built-in cleanup.

```go
// Config via redis URL env var, enabled in secondary-storage plugin config
```

---

## Route Mapping Config

Authula's route mappings only cover routes that live under its own handler (`/auth`). StellarVote's own routes (elections, API keys, etc.) stay on the `httprouter` and validate sessions via direct cookie reading in custom middleware.

```go
authulaconfig.WithRouteMappings([]authulamodels.RouteMapping{
    // Authula handlers — session set automatically by the Session plugin on sign-in
    // (No custom hooks needed for sign-in/out — Authula's router handles them)
})
```

StellarVote's middleware for dashboard routes:

```go
// Pseudocode — reads session cookie, validates via Authula's session service
func (s *Server) sessionMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        cookie, err := r.Cookie("authula.session_token")
        if err != nil {
            http.Error(w, "unauthorized", http.StatusUnauthorized)
            return
        }
        session, err := s.auth.SessionService.ValidateSession(r.Context(), cookie.Value)
        if err != nil {
            http.Error(w, "unauthorized", http.StatusUnauthorized)
            return
        }
        // Attach user context to request
        ctx := context.WithValue(r.Context(), "user_id", session.UserID)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

---

## Bootstrap Checklist

Order of initialization when integrating into StellarVote's `cmd/api/main.go`:

1. Load `config.toml` + `.env`
2. Init database connection (Authula handles its own migrations)
3. Init plugins in dependency order:
   - Rate Limit → (no deps)
   - Email → (no deps)
   - Session → (no deps)
   - Email & Password → depends on Email
   - OAuth2 → (no deps)
   - JWT (optional, replaces Session) → depends on Session or standalone
   - Admin (optional) → (no deps)
   - Organizations (optional, future) → depends on Access Control
   - Access Control (optional, future) → (no deps)
4. Create Authula instance with all plugins
5. Mount `auth.Handler()` at `/auth` on the `httprouter` server
6. StellarVote's own routes live alongside, untouched

```
/auth          → Authula handler (Chi router internally)
/              → StellarVote HelloWorld
/health        → StellarVote health check
/elections     → StellarVote domain routes (protected by session middleware or API key middleware)
```
