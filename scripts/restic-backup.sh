#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
REPO_ROOT="$SCRIPT_DIR/.."
PLAYBOOK="$REPO_ROOT/ansible/playbook.yaml"
VARS="$REPO_ROOT/ansible/vars.yaml"
STACKS_DIR="$REPO_ROOT/stacks"

for f in "$PLAYBOOK" "$VARS"; do
  [[ -f "$f" ]] || { echo "FATAL: $f not found"; exit 1; }
done

command -v yq  >/dev/null || { echo "FATAL: yq is not installed";  exit 1; }
command -v restic >/dev/null || { echo "FATAL: restic is not installed"; exit 1; }

export RESTIC_PASSWORD
RESTIC_PASSWORD=$(yq '.restic_password' "$VARS")
export RESTIC_REPOSITORY
RESTIC_REPOSITORY=$(yq '.restic_primary_repo' "$VARS")

MIRROR_PATH=$(yq '.restic_mirror_path' "$VARS")
KEEP_DAILY=$(yq  '.restic_keep_daily  // 7'  "$VARS")
KEEP_WEEKLY=$(yq '.restic_keep_weekly // 4'  "$VARS")
KEEP_MONTHLY=$(yq '.restic_keep_monthly // 6' "$VARS")
KEEP_YEARLY=$(yq '.restic_keep_yearly // 1' "$VARS")

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

docker_compose() {
  local stack_dir="$1"; shift
  docker compose -f "$stack_dir/docker-compose.yaml" "$@"
}

log "=== Restic backup started ==="
log "Repository : $RESTIC_REPOSITORY"
log "Mirror     : $MIRROR_PATH"

STACK_COUNT=$(yq '.[] | .vars.stacks | length' "$PLAYBOOK")

for i in $(seq 0 $((STACK_COUNT - 1))); do
  STACK_NAME=$(yq ".[] | .vars.stacks[$i].name" "$PLAYBOOK")

  BACKUP_PATHS=()
  VOL_COUNT=$(yq ".[] | .vars.stacks[$i].volumes | length // 0" "$PLAYBOOK")

  for j in $(seq 0 $((VOL_COUNT - 1))); do
    IS_BACKUP=$(yq ".[] | .vars.stacks[$i].volumes[$j].backup // false" "$PLAYBOOK")
    if [[ "$IS_BACKUP" == "true" ]]; then
      VOL_PATH=$(yq ".[] | .vars.stacks[$i].volumes[$j].path" "$PLAYBOOK")
      BACKUP_PATHS+=("$VOL_PATH")
    fi
  done

  [[ ${#BACKUP_PATHS[@]} -eq 0 ]] && continue

  STOP_BEFORE=$(yq ".[] | .vars.stacks[$i].stop_before_backup // true" "$PLAYBOOK")
  STACK_DIR="$STACKS_DIR/$STACK_NAME"
  STOPPED=false

  log "--- Stack: $STACK_NAME (stop=$STOP_BEFORE, paths=${#BACKUP_PATHS[@]}) ---"

  if [[ "$STOP_BEFORE" == "true" ]]; then
    log "Stopping $STACK_NAME ..."
    docker_compose "$STACK_DIR" stop
    STOPPED=true
  fi

  log "Backing up: ${BACKUP_PATHS[*]}"
  restic backup "${BACKUP_PATHS[@]}" --tag "$STACK_NAME"

  if [[ "$STOPPED" == "true" ]]; then
    log "Starting $STACK_NAME ..."
    docker_compose "$STACK_DIR" start
  fi
done

log "=== Applying retention policy ==="
restic forget \
  --prune \
  --keep-daily   "$KEEP_DAILY" \
  --keep-weekly  "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --keep-yearly  "$KEEP_YEARLY"

if [[ -n "$MIRROR_PATH" && "$MIRROR_PATH" != "null" ]]; then
  log "=== Mirroring to $MIRROR_PATH ==="
  mkdir -p "$MIRROR_PATH"
  rsync -a --delete "$RESTIC_REPOSITORY/" "$MIRROR_PATH/"
  log "Mirror complete"
fi

log "=== Restic backup finished ==="
