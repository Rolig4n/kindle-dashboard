# AGENTS.md

Guidance for AI agents working in this repository. For user-facing setup and operations, see `GUIA.md`.

## Project overview

- Local dashboard for a Kindle e-ink device (8th gen, 800×600 px) that refreshes a PNG via KOReader.
- Single Express backend (`backend/server.js`) + static frontend (`frontend/public/index.html`, all CSS/JS inline in one file). No build step, no framework beyond Express, no TypeScript.
- Deployed via Docker Compose (`docker-compose.yml`, image in `Dockerfile`). Runs on a local Ubuntu server; the Kindle pulls the PNG from `dashboard.sh`.
- There is no real monorepo: despite the folder names, `backend/` and `frontend/` are just two folders inside one small app.

## Commands

```bash
# Backend locally (Node 20)
cd backend && npm install && npm start

# Backend via Docker
docker compose up -d --build
docker compose logs -f kindle-dashboard
docker compose restart kindle-dashboard   # after changing .env
docker compose up -d --build             # after changing backend code

# Verify
curl http://localhost:3000/api/health
curl -o /tmp/test.png http://localhost:3000/screenshot
curl -o /tmp/test.png "http://localhost:3000/screenshot?force=1"   # bypass 4-min cache
```

There is **no test suite, linter, typecheck, formatter, CI, or task runner** configured. Do not invent verification commands; verify with the curl health/screenshot checks above.

## Key architecture facts

- Entrypoints: `backend/server.js` (Express, listens on `PORT` or `3000`) and `frontend/public/index.html`.
- Endpoints: `GET /api/health`, `GET /api/weather`, `GET /api/home-climate`, `GET /api/containers`, `GET /api/news`, `GET /api/gallery`; `GET /screenshot` returns an 800×600 PNG (server-side cache TTL 4 min; `?force=1` to bypass).
- Static file resolution: backend prefers `backend/frontend/public` if present, falls back to repo-root `frontend/public`; override with `FRONTEND_PATH`.
- Dockerode talks to the Docker socket at `/var/run/docker.sock`; `/api/containers` lists host containers.
- Env vars: `PORT`, `TZ`, `OWM_API_KEY` (required for weather), `OWM_CITY`, `OWM_UNITS`, `HOME_CLIMATE_URL`, `RSS_FEEDS` (comma-separated), `RSS_MAX_ITEMS`, `GALLERY_URLS` (comma-separated), `FRONTEND_PATH`. `.env` lives at repo root (gitignored; copy from `.env.example`); Docker Compose injects it automatically.

## Gotchas

- The backend does **not** load `.env` itself (no `dotenv` dependency is used). In Docker, env comes from `docker-compose.yml` → `.env`. For local runs, set vars via shell or prefer Docker.
- Puppeteer/Chromium: the container uses the system Chromium (`PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true`, `CHROMIUM_PATH=/usr/bin/chromium-browser`). Local screenshot runs need `CHROMIUM_PATH` or a system Chromium installed.
- Home climate: `/api/home-climate` returns `{ "available": false }` when `HOME_CLIMATE_URL` is empty.
- Weather/API failures return HTTP 502 with an error message (e.g. `Falha ao obter clima externo`).
- Business hours are duplicated in two places that must be kept in sync: the frontend constants (`BUSINESS_START/BUSINESS_END = 8/17` in `frontend/public/index.html`) and `dashboard.sh` (`BUSINESS_START=8`, `BUSINESS_END=22`).
- On the Kindle, `dashboard.sh` only refreshes during its business-hours window and keeps the previous PNG if `wget` fails; it validates the PNG magic bytes (`89504e47`).

## Docs

- `GUIA.md` is the main (Portuguese) setup guide; `GUIA.html` + `GUIA_files/` are the HTML version; `docs/prompt executado.txt` is the original project prompt. Prefer `GUIA.md` for operational procedures.

## Agent notes

- The working tree is not necessarily clean (local modifications and an untracked `dashboard.sh` exist) — check `git status` before assuming a clean state.
- No agent-instruction sources live in the repo (no `opencode.json`, `CLAUDE.md`, `.cursor/`, `.github/copilot-instructions.md`) — this file is the agent source of truth.
