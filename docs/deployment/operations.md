# Deployment — Operations

Day-2 tasks for a running Genesis stack. All commands run from the
`genesis-deploy` checkout on the host; `dc` below is shorthand for:

```bash
alias dc='docker compose -f docker/docker-compose.yml --env-file .env'
```

## Status & logs

```bash
dc ps                      # container status + health
dc logs -f backend         # follow backend logs (also on disk in ./logs/)
dc logs -f frontend
dc logs --tail 100 postgres
```

The backend additionally writes a rolling file log to `./logs/genesis.log`
(rotated daily, 30 days kept) — useful after a container has been removed.

## Update to a new release

```bash
# 1. In the app repo(s): fast-forward uni-prod from main, push.
# 2. On the host:
git pull
./scripts/deploy.sh
```

Only changed layers rebuild. The database is untouched; Flyway applies any
new migrations on backend startup.

## Rollback

```bash
# In the affected app repo (example: one release back):
git checkout uni-prod
git reset --hard <last-good-commit-or-tag>
git push --force-with-lease origin uni-prod

# On the host:
./scripts/deploy.sh
```

!!! warning
    Rolling back code does not roll back database migrations. If the bad
    release introduced a migration, restore the database from backup
    (below) before starting the rolled-back backend.

## Database backup & restore

```bash
# backup (run nightly via cron)
dc exec postgres pg_dump -U postgres genesis | gzip > "backup-$(date +%F).sql.gz"

# restore into a fresh volume
dc down
docker volume rm genesis_pgdata
dc up -d postgres
gunzip -c backup-YYYY-MM-DD.sql.gz | dc exec -T postgres psql -U postgres genesis
dc up -d
```

Example crontab entry (02:30 nightly, keep 14 days):

```cron
30 2 * * * cd /path/to/genesis-deploy && docker compose -f docker/docker-compose.yml --env-file .env exec -T postgres pg_dump -U postgres genesis | gzip > backups/backup-$(date +\%F).sql.gz && find backups -name 'backup-*.sql.gz' -mtime +14 -delete
```

## Restart / stop

```bash
dc restart backend         # one service
dc down                    # stop everything (data persists in the volume)
dc up -d                   # start again
```

All services use `restart: unless-stopped`, so the stack survives host
reboots once Docker starts.

## Hardening checklist (recommended)

- Put **nginx or Caddy** in front of both apps for TLS and a single public
  port; then close 3000/8080 on the firewall and only expose 443.
- Keep PostgreSQL unexposed (the compose file already does this).
- Store `.env` readable only by the deploy user (`chmod 600 .env`).
- Set up the backup cron above and periodically test a restore.
- Keep the host patched; `docker system prune` occasionally to reclaim
  space from old image layers.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `deploy.sh` fails at fetch | Host can't reach the git host or lacks access to the repos — check deploy keys / token in the repo URLs |
| Backend unhealthy, logs show JWT error | `JWT_SECRET` missing or shorter than 32 chars |
| Backend unhealthy, logs show CORS error at boot | `CORS_ALLOWED_ORIGINS` unset (required in prod) |
| Browser shows network errors calling the API | `NEXT_PUBLIC_API_URL` wrong or backend port blocked by firewall — remember it's evaluated in the browser |
| Login works but uploads fail | Cloudinary credentials wrong, or file exceeds the 25 MB action limit |
| Frontend rebuilt but old API URL persists | `NEXT_PUBLIC_API_URL` is baked at build time — rerun `deploy.sh` after changing it (it rebuilds the image) |
