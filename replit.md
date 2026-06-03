# Grok2API Runner

A self-hosted OpenAI-compatible API server that proxies requests to Grok (grok.com), supporting chat, image generation (imagine), and image editing.

## Run & Operate

- `uvicorn main:app --host 0.0.0.0 --port 8000` — run from `grok2api/` directory
- Workflow **"Grok2API Server"** — already configured, starts automatically
- Admin panel: `http://localhost:8000/admin` (password: `grok2api`)

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9 (for any future frontend)
- **grok2api**: Python 3.13, FastAPI, uvicorn, curl-cffi
- API: Express 5 (existing api-server artifact, not in use for grok2api)
- Build: esbuild (CJS bundle)

## Where things live

- `grok2api/` — the Python FastAPI server (main source)
- `grok2api/main.py` — FastAPI entry point
- `grok2api/app/services/reverse/utils/statsig.py` — Statsig ID generator (PR #567 fix applied)
- `grok2api/data/token.json` — SSO token pool (local, not committed)
- `grok2api/data/config.toml` — runtime config (cf_clearance, proxy settings)
- `grok2api/config.defaults.toml` — default config values

## Architecture decisions

- Cloned from https://github.com/shakapakalo/Grok-API-Runner (grok2api subdir)
- Applied PR #567 fix: `statsig.py` prefix changed from `e:` to `x1:` to bypass Grok anti-bot rules
- Tokens stored in `grok2api/data/token.json` (gitignored by the project's .gitignore)
- Runs on port 8000; proxy routes `/v1/*` through Replit's shared proxy at port 80

## Product

OpenAI-compatible REST API backed by Grok:
- `GET /v1/models` — list all available Grok models
- `POST /v1/chat/completions` — chat with grok-3, grok-4, etc.
- `POST /v1/images/generations` — text-to-image via `grok-imagine-1.0`
- `POST /v1/images/edits` — image editing via `grok-imagine-1.0-edit`
- `/admin` — web-based admin panel (token management, config)

## User preferences

_Populate as you build — explicit user instructions worth remembering across sessions._

## Gotchas

- `cf_clearance` cookie expires frequently — update in `grok2api/data/config.toml` under `[proxy]`
- SSO token is in `grok2api/data/token.json` — replace if it expires (via admin panel or directly)
- After updating tokens/config, restart the **"Grok2API Server"** workflow
- The statsig fix (PR #567): always use `x1:` prefix, never `e:` — see `statsig.py`
- Python 3.13 (python-base-3.13 module) is required
- Run all uvicorn commands from `grok2api/` directory so relative imports resolve

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
- Upstream source: https://github.com/shakapakalo/Grok-API-Runner/tree/main/grok2api
- Statsig fix: https://github.com/chenyme/grok2api/pull/567
