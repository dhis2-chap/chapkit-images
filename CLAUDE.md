# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## NO EMOJIS EVER

**CRITICAL RULE: ABSOLUTELY NO EMOJIS ANYWHERE**

NO EMOJIS. EVER.

This means:
- NO emojis in commit messages
- NO emojis in PR titles
- NO emojis in PR descriptions
- NO emojis in code comments
- NO emojis in documentation
- NO emojis in any output whatsoever

Use plain text instead:
- `[x]` / `[ ]` for checklists
- `CRITICAL` / `Note:` / `WARNING:` for callouts

## Overall guidelines

- Be concise and to the point
- Follow existing patterns in the Dockerfiles, `Makefile`, and workflow
- Prioritize reproducibility, minimal image size, and cache-friendly layer ordering
- Write clear commit messages WITHOUT AI attribution
- NEVER use emojis
- Ask the user before creating branches or pull requests

## Project overview

`chapkit-images` publishes base Docker images for [chapkit](https://github.com/dhis2-chap/chapkit) services. The images ship ready-to-use Python, R, and R+INLA runtimes with `chapkit`, `uv`, `renv`, and `pak` pre-installed. Consumers either:

1. Run an image directly and mount an MLproject into `/work` — the default `CMD` is `chapkit run .`.
2. Use an image as a `FROM` base in their own Dockerfile and layer in a user-authored `main.py` + deps. This is the flow scaffolded by `chapkit init` / `chapkit migrate`.

Lives in its own repository so the slow R + INLA builds don't block every commit on `chapkit` itself.

## Layout

```
chapkit-images/
├── chapkit-py.Dockerfile        # Python 3.13 + uv + chapkit. Multi-arch (amd64, arm64).
├── chapkit-r.Dockerfile         # Debian trixie + R 4.5 + renv/pak + chapkit. Multi-arch.
├── chapkit-r-inla.Dockerfile    # Adds compiled INLA + spatial/time-series R stack. amd64 only.
├── Makefile                     # Local build helpers (build-py / build-r / build-r-inla).
├── .github/workflows/docker.yml # CI: builds and pushes to ghcr.io/dhis2-chap/<image>.
├── README.md
└── LICENSE                      # AGPL-3.0, matches upstream chapkit.
```

## Local builds

```bash
make build                      # All three images, chapkit @ main.
make build-py                   # Python image only.
make build-r                    # R base, multi-arch.
make build-r-inla               # R + INLA, amd64 only.

# Pin a specific chapkit ref (branch / tag / SHA):
make build-py CHAPKIT_REF=v0.19.0
```

## CI / publishing

`.github/workflows/docker.yml` publishes to `ghcr.io/dhis2-chap/<image>`.

Triggers:
- push to `main` — updates `:main` / `:latest`
- tag `v*` — publishes the matching semver tag
- `schedule` (weekly, Mon 04:17 UTC) — picks up base-image security fixes
- `workflow_dispatch` — manual with `chapkit_ref` input
- `repository_dispatch` (`event_type: chapkit-release`) — chapkit's release workflow fires this

After all three builds succeed, a `smoke` job pulls each `:main` image and runs `chapkit --help` (plus `library(INLA)` for `chapkit-r-inla`) to catch broken publishes.

## Image conventions

- All images set `WORKDIR /work` and `CMD ["chapkit","run",".","--host","0.0.0.0","--port","8000"]`. Downstream Dockerfiles built on top of these images override `CMD` as needed.
- `chapkit` is installed via `git clone --depth 1 --branch ${CHAPKIT_REF}` + `uv sync --frozen --no-dev` into `/app/.venv`.
- R images install `renv` and `pak` so downstream projects can `renv::restore()` without bootstrapping from CRAN.
- `chapkit-r-inla` uses a two-stage build: an `inla-builder` stage compiles INLA + the spatial/time-series R package set, then the runtime stage copies `/usr/local/lib/R/site-library`.
- Images run as `root`. Non-root hardening is a deferred follow-up.

## Git workflow

**Branch + PR is the default. Ask the user before creating a branch or PR.**

Branch naming aligns with the conventional-commits prefix:

- `feat/*` — New features
- `fix/*` — Bug fixes
- `chore/*` — Dependencies, tooling, CI, maintenance
- `docs/*` — Documentation changes
- `refactor/*` — Refactoring without behavior change
- `ci/*` — CI-only changes
- `build/*` — Dockerfile / build-system changes

Process:
1. Ask the user whether they want a branch + PR.
2. `git checkout -b <prefix>/<topic>` from `main`.
3. Commit with a conventional-commits prefix (see below).
4. `git push -u origin <branch>`.
5. `gh pr create --title "<prefix>: ..." --body "..."`.

### Conventional commits

All commits MUST use a conventional-commits prefix: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `build`, `perf`.

Examples:
- `feat: add arm64 build for chapkit-r-inla`
- `fix: fall back CHAPKIT_REF to github.ref_name on tag pushes`
- `chore: bump GHA actions to Node 24 majors`
- `docs: add image sizes to README`
- `build: shrink chapkit-r by dropping build-essential at runtime`

### Commit message requirements

- NEVER include `Co-Authored-By: Claude` or any AI attribution.
- NEVER use emojis.
- Subject under ~72 characters; use the body for details.
- Focus on what changed and why.

### PR requirements

- Title uses a conventional-commits prefix.
- NO emojis in title or body.
- NO AI attribution (no `Generated with Claude Code` footer or similar).
- Include a `Test plan` checklist when the change affects the build or CI.

## What NOT to do

- Don't add emojis. Ever.
- Don't include AI attribution in commits, PRs, or docs.
- Don't hardcode a chapkit version in a Dockerfile — it's `ARG CHAPKIT_REF` for a reason.
- Don't add runtime dependencies without considering image size (current sizes in `README.md`).
- Don't commit secrets, credentials, or local build artifacts.

## Additional resources

- chapkit: https://github.com/dhis2-chap/chapkit
- chapkit docs: https://dhis2-chap.github.io/chapkit
- chapkit-images README: [README.md](README.md)
