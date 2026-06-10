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

## 5. Organizations Plugin — Multi-Tenancy

Each StellarVote app/tenant = one Authula organization. Users sign up, create or join orgs, and perform operations within their org scope.

```go
organizationsplugin.New(organizationsplugintypes.OrganizationsPluginConfig{
    Enabled:                          true,
    OrganizationsLimit:               new(10),       // 0 = unlimited
    MembersLimit:                     new(100),
    InvitationsLimit:                 new(100),
    InvitationExpiresIn:              7 * 24 * time.Hour,
    RequireEmailVerifiedOnInvitation: true,
    DatabaseHooks: &organizationsplugintypes.OrganizationsDatabaseHooksConfig{
        // Optional: hook into org create/update/delete lifecycle
    },
})
```

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/auth/organizations` | Create org |
| `GET` | `/auth/organizations` | List user's orgs |
| `PATCH` | `/auth/organizations/{id}` | Update org metadata |
| `DELETE` | `/auth/organizations/{id}` | Delete org |
| `POST` | `/auth/organizations/{id}/invitations` | Invite user by email |
| `POST` | `/auth/organizations/{id}/invitations/{inv_id}/accept` | Accept invitation |
| `POST` | `/auth/organizations/{id}/invitations/{inv_id}/reject` | Reject invitation |
| `GET` | `/auth/organizations/{id}/members` | List members |
| `PATCH` | `/auth/organizations/{id}/members/{member_id}` | Update member role |
| `DELETE` | `/auth/organizations/{id}/members/{member_id}` | Remove member |
| `POST` | `/auth/organizations/{id}/teams` | Create team |
| `GET` | `/auth/organizations/{id}/teams/{team_id}/members` | List team members |

### Tables created

- `organizations` — org records, `owner_id` → users
- `organization_invitations` — pending invitations
- `organization_members` — user → org membership with role
- `organization_teams` — team grouping within orgs
- `organization_team_members` — member → team assignments

### Notes

- **Depends on the Access Control plugin** — org member roles are enforced via RBAC.
- StellarVote's domain tables (`elections`, `api_keys`, etc.) FK to `organizations.id`.
- The `slug` field is the URL-friendly org identifier (e.g., `my-awesome-app`).

---

## 6. Access Control Plugin — RBAC

Manages roles, permissions, and user-role assignments within orgs.

```go
accesscontrolplugin.New(accesscontrolplugintypes.AccessControlPluginConfig{
    Enabled: true,
})
```

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/auth/access-control/roles` | Create role (`name`, `weight`, `is_system`) |
| `GET` | `/auth/access-control/roles` | List roles |
| `POST` | `/auth/access-control/permissions` | Create permission (`key`, `description`) |
| `POST` | `/auth/access-control/roles/{id}/permissions` | Assign permission to role |
| `POST` | `/auth/access-control/users/{id}/roles` | Assign role to user |
| `GET` | `/auth/access-control/users/{id}/permissions` | Get effective permissions for user |
| `POST` | `/auth/access-control/users/{id}/permissions/check` | Check if user has specific permission |

### Tables created

- `access_control_roles` — role definitions (`name`, `weight` for hierarchy)
- `access_control_permissions` — permission keys
- `access_control_role_permissions` — many-to-many role ↔ permission
- `access_control_user_roles` — many-to-many user ↔ role (with `expires_at`)

### Hook usage

- `access_control.enforce` — attach to protected routes with required `permissions`

```
Example route mapping:
  path = "/admin/elections"
  plugins = ["bearer.auth", "access_control.enforce"]
  permissions = ["elections.create"]
```

### Notes

- Role **weight** establishes hierarchy — a user can only assign roles with equal or lower weight than their highest role (prevents privilege escalation).
- `is_system` roles/permissions are protected from modification.
- In route mappings, `bearer.auth` must appear **before** `access_control.enforce` in the plugin chain.

---

## 7. Admin Plugin — User & Session Management

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

### Notes

- All admin endpoints should be protected by `bearer.auth` + `access_control.enforce` with a high-weight role.
- StellarVote's admin dashboard will call these endpoints for user management features.

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

Enables Redis-backed key-value storage for JWT token blacklisting (so sign-out immediately invalidates tokens). Only needed if immediate token revocation is required.

```go
// Config via redis URL env var, enabled in secondary-storage plugin config
```

---

## Route Mapping Config

All plugins are wired together via route mappings in the Authula config:

```go
authulaconfig.WithRouteMappings([]authulamodels.RouteMapping{
    // Dashboard: email/password sign-in returns JWT
    {
        Method: "POST",
        Path:   "/auth/email-password/sign-in",
        Plugins: []string{
            bearerplugin.HookIDBearerAuthOptional.String(),
            jwtplugin.HookIDJWTRespondJSON.String(),
        },
    },
    // Dashboard: OAuth callback returns JWT
    {
        Method: "GET",
        Path:   "/auth/oauth2/callback/google",
        Plugins: []string{
            jwtplugin.HookIDJWTRespondJSON.String(),
        },
    },
    // Dashboard: protected route with RBAC
    {
        Method: "GET",
        Path:   "/admin/elections",
        Plugins: []string{
            bearerplugin.HookIDBearerAuth.String(),
            accesscontrolplugin.HookIDAccessControlEnforce.String(),
        },
        Permissions: []string{"elections.read"},
    },
    // Add StellarVote's own public routes (no auth)
    {
        Method: "GET",
        Path:   "/health",
        Disabled: true,                        // excluded from Authula's router
    },
})
```

---

## Bootstrap Checklist

Order of initialization when integrating into StellarVote's `cmd/api/main.go`:

1. Load `config.toml` + `.env`
2. Init database connection (Authula handles its own migrations)
3. Init plugins in dependency order:
   - Email → (no deps)
   - JWT → (no deps)
   - Bearer → depends on JWT
   - Email & Password → depends on Email
   - OAuth2 → (no deps)
   - Access Control → (no deps)
   - Organizations → depends on Access Control
   - Admin → (no deps)
   - Rate Limit → (no deps)
4. Create Authula instance with all plugins
5. Mount `auth.Handler()` at `/auth` on the `httprouter` server
6. StellarVote's own routes live alongside, untouched

```
/auth          → Authula handler (Chi router internally)
/              → StellarVote HelloWorld
/health        → StellarVote health check
/elections     → StellarVote domain routes (protected by API key middleware or JWT)
```
