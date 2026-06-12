# genesis-deploy

Central deployment repository for the **Genesis** annotation platform.

Genesis is a collaborative linguistic-annotation platform (coreference, NER,
POS, WSD) built as two applications:

| App | Stack | Source branch used here |
|---|---|---|
| Backend | Spring Boot 3 (Java 21), modular monolith, PostgreSQL | `uni-prod` |
| Frontend | Next.js 15 (TypeScript, pnpm) | `uni-prod` |

This repo contains **no application source code**. It owns three things:

1. **Documentation** (`docs/`) — how both apps work (technical + functional)
   and how to deploy them. Published as a website via GitHub Pages.
2. **Configuration** (`config/`) — a documented `.env.example` with every
   variable the stack needs.
3. **The pipeline** (`docker/`, `scripts/`, `.github/workflows/`) — fetches
   both app repos at their `uni-prod` branches, builds Docker images, and
   starts the full stack with one command.

## Quick start

Prerequisites: git, Docker Engine, Docker Compose plugin.

```bash
git clone <this-repo-url> genesis-deploy
cd genesis-deploy
cp config/.env.example .env
# edit .env — set repo URLs, DB password, JWT secret, Cloudinary keys, public URLs
./scripts/deploy.sh
```

When it finishes:

- Frontend: `http://<host>:3000`
- Backend API: `http://<host>:8080`
- Backend health: `http://<host>:8080/actuator/health`

## Layout

```
genesis-deploy/
├── docs/                  # documentation set (also the GitHub Pages site)
│   ├── backend/           # architecture.md + functionality.md
│   ├── frontend/          # architecture.md + functionality.md
│   └── deployment/        # setup.md + operations.md
├── config/.env.example    # every variable, documented
├── docker/
│   └── docker-compose.yml # postgres + backend + frontend
├── scripts/
│   ├── fetch-sources.sh   # clone/update both app repos @ uni-prod
│   ├── deploy.sh          # fetch → build → up → healthcheck
│   └── healthcheck.sh
└── .github/workflows/
    ├── ci.yml             # full-stack build smoke test
    └── pages.yml          # publish docs/ to GitHub Pages
```

The app repos are checked out into a git-ignored `sources/` directory by
`fetch-sources.sh`; each app's own `Dockerfile` (maintained in its repo) is
used to build its image.

## Updating production

```bash
# 1. In the app repos: fast-forward uni-prod from main, push.
# 2. On the host:
cd genesis-deploy && git pull && ./scripts/deploy.sh
```

Rollback: reset `uni-prod` in the app repo(s) to the previous commit/tag,
push, and run `./scripts/deploy.sh` again.

## Documentation site

The full handbook (architecture, functionality, deployment, operations) is
served from GitHub Pages and rebuilt automatically on every change to
`docs/`. See `.github/workflows/pages.yml`.
