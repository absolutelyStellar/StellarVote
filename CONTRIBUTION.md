# Contributing to StellarVote

Thanks for your interest in contributing. StellarVote is early-stage infrastructure, and every contribution — docs, tests, features, bug reports — moves it forward.

---

## Branch Strategy

- **`main`** — release-ready code only. Every commit on `main` is a tagged, stable release. No direct commits, no PRs targeting `main`.
- **`deploy`** — active development target. **All pull requests must target `deploy`.** This branch is where features are integrated, tested, and verified before they're promoted to `main`.

### Workflow

```
feature/your-feature → deploy → main (tagged release)
```

1. Branch off `deploy` for your work.
2. Open a PR targeting `deploy`.
3. After review and passing CI, the PR merges into `deploy`.
4. When `deploy` is stable and ready for release, it's merged into `main` and tagged.

---

## Getting Started

1. Fork the repository on GitHub.
2. Clone your fork:

```bash
git clone https://github.com/your-username/StellarVote.git
cd StellarVote
```

3. Create a branch off `deploy`:

```bash
git fetch origin deploy
git checkout -b feature/your-feature origin/deploy
```

4. Make changes, then push your feature branch:

```bash
git push -u origin feature/your-feature
```

5. Open a pull request on GitHub targeting `deploy`.
6. Set up the development environment:

```bash
# Start Postgres
make docker-run

# Run the API
make run

# Run tests
make test
```

---

## Development Guidelines

### Code Style

- Go code follows standard `gofmt` formatting. Run `golangci-lint run` before committing.
- TypeScript (SDK) follows the project's ESLint and Prettier config.
- Rust (Soroban contracts) follows `rustfmt` with the project's config.
- No commented-out code. Delete it.
- No TODOs in committed code. Use issues instead.

### Commit Messages

Follow conventional commits:

```
type: short description

- bullet points for details if needed
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `ci`.

### Tests

- All new features must include tests.
- Soroban contracts: Rust unit tests using the Soroban test environment.
- Go backend: `go test ./...` must pass. Integration tests require Docker.
- Frontend: Jest + React Testing Library for components.
- SDK: Vitest for unit tests.

```bash
make test        # All tests
make itest       # Database integration tests only
```

### Pull Request Checklist

Before opening a PR, ensure:

- [ ] Branch is up to date with `deploy`
- [ ] Code compiles and lints without warnings
- [ ] All tests pass
- [ ] New features include tests
- [ ] Commit messages follow conventional commits
- [ ] PR description explains what and why (not just how)

### PR Description Template

```markdown
## Summary

What this PR does and why.

## Related Issues

Closes #123

## Testing

How the changes were tested.

## Notes

Anything reviewers should know.
```

---

## Project Structure

| Directory | Contents |
|---|---|
| `cmd/api/` | Go entrypoint |
| `internal/` | Go packages (server, database) |
| `contracts/` | Soroban smart contracts (Rust) |
| `sdk/` | TypeScript SDK |
| `frontend/` | Next.js application |
| `docs/` | Architecture docs, ERD, auth flows |

---

## Code of Conduct

Be respectful, constructive, and assume good faith. This is a small project — every interaction matters.

---

## Questions?

Open a [GitHub Discussion](https://github.com/StellarVote/StellarVote/discussions) or ask in the PR comments.
