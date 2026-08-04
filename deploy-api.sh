#!/usr/bin/env bash
#
# deploy-api.sh — deploy the Rails API to production from your computer.
#
# What it does:
#   1. Backs up the production database (gzip) on the VPS — always, before anything.
#   2. rsyncs api/ source to the VPS (excludes secrets/runtime dirs).
#   3. Rebuilds ONLY the api container and recreates it (db + its data untouched).
#      Migrations run automatically on boot via `rails db:prepare`.
#      NOTE: `db:prepare` never re-imports or re-seeds an existing database.
#   4. Waits for the health check to go green.
#
# Your data lives in the `pgdata` Docker volume on the VPS and is never touched
# by this script. A fresh backup is taken every run just in case.
#
# Usage:  ./deploy-api.sh
#
set -euo pipefail

# ---- config -----------------------------------------------------------------
SSH_HOST="hugo@vps.prout.io"
REMOTE_DIR="/home/hugo/apps/fundodaescola"
DB_USER="fundodaescola"
DB_NAME="fundodaescola_production"
HEALTH_URL="https://api.fundodaescola.com.br/up"
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_API_DIR="$SCRIPT_DIR/api"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }

if [[ ! -d "$LOCAL_API_DIR" ]]; then
  echo "ERROR: $LOCAL_API_DIR not found. Run this from the repo root." >&2
  exit 1
fi

bold "==> [1/4] Backing up production database on the VPS"
ssh "$SSH_HOST" "cd '$REMOTE_DIR' && mkdir -p ~/backups && \
  OUT=~/backups/fundo-backup-\$(date +%F-%H%M%S).sql.gz && \
  sudo docker compose exec -T db pg_dump -U '$DB_USER' --no-owner --no-privileges '$DB_NAME' | gzip > \"\$OUT\" && \
  echo \"    backup: \$OUT (\$(du -h \"\$OUT\" | cut -f1))\" && \
  ls -1t ~/backups/fundo-backup-*.sql.gz | tail -n +15 | xargs -r rm -f"   # keep last 14

bold "==> [2/4] Syncing api/ source to the VPS"
rsync -az --delete \
  --exclude '.git' \
  --exclude 'tmp/' \
  --exclude 'log/' \
  --exclude 'storage/' \
  --exclude '.env' \
  --exclude 'db/import_data/*.csv' \
  "$LOCAL_API_DIR/" "$SSH_HOST:$REMOTE_DIR/api/"

bold "==> [3/4] Rebuilding and recreating the api container (db is left running)"
ssh "$SSH_HOST" "cd '$REMOTE_DIR' && sudo docker compose up -d --build api"

bold "==> [4/4] Waiting for health check: $HEALTH_URL"
for i in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$HEALTH_URL" || true)"
  if [[ "$code" == "200" ]]; then
    bold "    healthy (HTTP 200). Deploy complete."
    exit 0
  fi
  printf '    attempt %2d/30 -> HTTP %s\n' "$i" "${code:-000}"
  sleep 3
done

echo "WARNING: health check did not return 200 in time. Check logs:" >&2
echo "  ssh $SSH_HOST \"cd $REMOTE_DIR && sudo docker compose logs --tail=80 api\"" >&2
exit 1
