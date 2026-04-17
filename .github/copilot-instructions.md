# Copilot Instructions

## Build, test, and lint commands

- **Build the local image:** `docker build -t hermes-agent .`
- **Run the app locally:** `docker run --rm -it -p 8080:8080 -e PORT=8080 -e ADMIN_PASSWORD=changeme -v hermes-data:/data hermes-agent`
- **Tests:** no test suite is checked into this repository today, so there is no full-suite or single-test command to run.
- **Linting:** no linter configuration or lint command is checked into this repository today.

## High-level architecture

- `server.py` is the whole backend: a Starlette app that serves the admin page, exposes JSON APIs under `/api/*`, enforces Basic Auth on admin routes, and manages the Hermes gateway as an async subprocess.
- `Dockerfile` installs system dependencies plus `gh`, then copies in the server, templates, installer scripts, and the wrapper commands in `/usr/local/bin`. Hermes itself is not baked into the image; it is installed into the persistent runtime under `/data/.hermes` on first boot or first use.
- `start.sh` pre-creates the persistent data directories, exports `GH_CONFIG_DIR`, appends `/data/.hermes/bin` to `PATH`, and launches `python /app/server.py`.
- Runtime state lives under `${HERMES_HOME}` (`/data/.hermes` in the container). The dashboard writes `${HERMES_HOME}/.env`, the server rewrites `${HERMES_HOME}/config.yaml`, pairing approvals live as JSON files in `${HERMES_HOME}/pairing/`, and GitHub CLI state lives under `/data/.config/gh` plus `/data/.local/share/gh/copilot`.
- `templates/index.html` is the entire frontend: inline CSS, inline Alpine.js state, and direct `fetch()` calls to the backend. There is no separate asset pipeline or JS build step.
- Railway relies on `/health` as the unauthenticated health check (`railway.toml` points to it). Everything else is intended to stay behind Basic Auth.
- Browser automation for future Copilot sessions is configured repo-wide through `.copilot/mcp-config.json`, and `.github/workflows/copilot-setup-steps.yml` preinstalls Node/Chromium for cloud-agent sessions.

## Key conventions

- `ENV_VARS` in `server.py` is the backend source of truth for configurable fields. Its metadata drives API responses, secret masking, category-based `.env` serialization, and which keys count as providers.
- Provider/channel/tool additions are cross-file changes. Keep `server.py` (`ENV_VARS`, `PROVIDER_KEYS`, `CHANNEL_MAP`) aligned with the Alpine config in `templates/index.html`, `.env.example`, and any README lists/setup instructions that mention supported integrations.
- Secret values round-trip through the UI in masked form. `mask()` returns shortened values ending in `***`, and `unmask()` preserves the existing secret when the client submits a masked value back. Do not break that contract when changing `/api/config`.
- Gateway startup always rewrites `config.yaml` from the saved env before spawning `hermes gateway`. That write is intentional because Hermes does not reliably pick up the selected model from env vars alone.
- The `hermes` and `copilot` commands are image-level wrappers in `/usr/local/bin`. Keep them ahead of `/data/.hermes/bin` on `PATH`; otherwise a stale persisted runtime can shadow the wrapper and break bootstrapping.
- When debugging Hermes CLI problems, test the `hermes` wrapper command first. Do not assume `/data/.hermes/bin/hermes` is directly executable, because the persisted virtualenv can be stale while the wrapper is still healthy enough to repair it.
- `install_hermes.sh` and `docker-bin/hermes` both treat a runtime as healthy only if `/data/.hermes/bin/hermes --version` succeeds. Preserve that behavior so broken persisted runtimes trigger reinstall instead of being reused.
- `install_github_tools.sh` must continue to handle both modern native `gh copilot` behavior and older `gh-copilot` extension installs.
- Saved values from `${HERMES_HOME}/.env` intentionally override container/Railway env vars when the gateway process is started. Preserve that precedence unless you are deliberately changing dashboard behavior.
- The frontend clears related env keys when a channel or tool is toggled off (`clearChannel()` / `clearTool()`). If you add new fields, update those clearing paths so stale credentials do not remain in the saved `.env`.
- New protected routes need an explicit `guard(request)` call even though the app uses `AuthenticationMiddleware`; `/health` is the only route that should remain publicly accessible for platform health checks.
- Pairing state is file-based, not database-backed. Pending requests and approved users are stored per platform in `*-pending.json` and `*-approved.json`, and pending requests expire based on `PAIRING_TTL`.
- Shell scripts in this repo should stay on LF line endings. CRLF breaks Bash execution in the container and during validation.
