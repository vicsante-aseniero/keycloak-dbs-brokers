#!/bin/bash
# =============================================================================
# docker-cleanup.sh
# =============================================================================
# Full Docker environment wipe.
# Stops all containers and removes:
#   - All containers (running or stopped)
#   - ALL local images (tagged, untagged, and dangling)
#   - ALL local named and anonymous volumes (your database data lives here)
#   - All custom networks
#   - All build cache
#
# ⚠️  DESTRUCTIVE — This script is permanent and irreversible.
#     Back up any important volume data BEFORE running this.
#
# Usage:
#   chmod +x docker-cleanup.sh
#   ./docker-cleanup.sh
#
# Optional: skip confirmation prompt for use in CI/automated environments
#   ./docker-cleanup.sh --force
# =============================================================================

set -euo pipefail
# set -e  → exit immediately if any command fails
# set -u  → treat unset variables as errors (catches typos like $VOUMES)
# set -o pipefail → if any command in a pipeline fails, the whole pipeline fails

# =============================================================================
# CONFIGURATION
# =============================================================================

# Detect if --force flag was passed. In force mode, we skip the confirmation
# prompt — useful for automated scripts or CI pipelines where no human is
# watching. In normal mode, we always ask before proceeding.
FORCE=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE=true
fi

# ANSI colour codes to make the output easier to read at a glance.
# These are standard terminal escape sequences supported by Linux Mint's terminal.
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'   # resets all formatting back to terminal default

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# A simple logging function so every status line looks consistent.
# Usage: log "emoji" "message"
log() {
  echo -e "${CYAN}${1}  ${RESET}${2}"
}

# Prints a section header to visually separate each cleanup stage.
section() {
  echo ""
  echo -e "${BOLD}══════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}  ${1}${RESET}"
  echo -e "${BOLD}══════════════════════════════════════════════════${RESET}"
}

# =============================================================================
# SAFETY CONFIRMATION
# =============================================================================
# This is the most important part of the script. Before doing anything
# destructive, we clearly describe what is about to happen and ask the user
# to type a full word (not just press Enter) to confirm. This design choice —
# requiring "yes" rather than just "y" — forces the user to be deliberate.
# It's much harder to accidentally type "yes" than to accidentally press Enter.

echo ""
echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${RED}${BOLD}║           ⚠️   DOCKER FULL CLEANUP  ⚠️            ║${RESET}"
echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${YELLOW}This script will PERMANENTLY remove:${RESET}"
echo "  • All running and stopped containers"
echo "  • ALL local Docker images (tagged and untagged)"
echo "  • ALL local volumes — including named volumes with your database data"
echo "  • All custom networks"
echo "  • All build cache"
echo ""
echo -e "${RED}Volume data CANNOT be recovered after this script runs.${RESET}"
echo -e "${RED}Make sure you have backups if you need to preserve any data.${RESET}"
echo ""

if [ "$FORCE" = false ]; then
  # Read the user's input into the variable $CONFIRM.
  # We use /dev/tty explicitly to ensure we read from the terminal even if
  # the script is being piped (e.g. curl ... | bash), which would otherwise
  # make 'read' receive EOF immediately and skip the prompt.
  read -p "Type 'yes' to continue, or anything else to cancel: " CONFIRM < /dev/tty
  echo ""

  if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${GREEN}Cancelled. Nothing was removed.${RESET}"
    exit 0
  fi
fi

# =============================================================================
# BEFORE SNAPSHOT
# =============================================================================
# Always capture the state BEFORE cleanup so you can compare at the end.
# 'docker system df' is the canonical command for this — it shows total usage
# broken down by images, containers, volumes, and build cache.

section "📊 Disk Usage BEFORE Cleanup"
docker system df
echo ""

# =============================================================================
# STEP 1 — STOP ALL RUNNING CONTAINERS
# =============================================================================
# Containers must be stopped before they can be removed. Trying to remove a
# running container without -f will fail. We stop gracefully first so that
# processes inside the container (like PostgreSQL) have time to flush writes
# to disk and close connections cleanly. Abrupt kills can leave data files
# in an inconsistent state.

section "⏹️  Step 1 — Stopping All Running Containers"

# 'docker ps -q' outputs only the IDs of RUNNING containers (quiet mode).
# We capture this into a variable so we can check if anything is actually
# running before trying to stop it — avoids an unhelpful error if it's empty.
RUNNING_CONTAINERS=$(docker ps -q)

if [ -n "$RUNNING_CONTAINERS" ]; then
  # Count the number of IDs (one per line) for the status message
  COUNT=$(echo "$RUNNING_CONTAINERS" | wc -l | tr -d ' ')
  log "🔄" "Found ${COUNT} running container(s). Stopping..."
  docker stop $RUNNING_CONTAINERS
  log "✅" "All containers stopped."
else
  log "ℹ️" "No running containers found."
fi

# =============================================================================
# STEP 2 — REMOVE ALL CONTAINERS
# =============================================================================
# Stopped containers still exist as filesystem layers and metadata entries.
# They occupy disk space and clutter 'docker ps -a'. We remove all of them
# here — both stopped/exited containers and any in "created" state
# (containers that were created but never started).

section "🗑️  Step 2 — Removing All Containers"

ALL_CONTAINERS=$(docker ps -aq)

if [ -n "$ALL_CONTAINERS" ]; then
  COUNT=$(echo "$ALL_CONTAINERS" | wc -l | tr -d ' ')
  log "🔄" "Removing ${COUNT} container(s)..."
  docker rm $ALL_CONTAINERS
  log "✅" "All containers removed."
else
  log "ℹ️" "No containers to remove."
fi

# =============================================================================
# STEP 3 — REMOVE ALL LOCAL IMAGES
# =============================================================================
# This step now uses a TWO-PASS approach to ensure thorough removal:
#
# Pass 1 — 'docker rmi -f $(docker images -q)' removes all images by their ID.
#           The -f (force) flag is needed because a single image ID can have
#           multiple tags pointing to it (like postgres:latest AND postgres:16).
#           Without -f, Docker refuses to remove an image with multiple tags
#           since it doesn't know which tag to remove. Force bypasses this.
#
# Pass 2 — 'docker image prune -a -f' catches anything Pass 1 missed:
#           dangling images (untagged layers from failed builds or old pulls),
#           images in an inconsistent state, and intermediate build layers.
#           The -a flag means ALL unused images, not just dangling ones.
#           This double-pass guarantees a truly clean image store.

section "🖼️  Step 3 — Removing ALL Local Images"

ALL_IMAGES=$(docker images -aq)

if [ -n "$ALL_IMAGES" ]; then
  COUNT=$(echo "$ALL_IMAGES" | wc -l | tr -d ' ')
  log "🔄" "Pass 1: Force-removing ${COUNT} image(s) by ID..."

  # The || true at the end prevents the script from exiting if some images
  # are already gone by the time this runs (race condition with prune).
  # 'set -e' would otherwise abort the entire script on a non-zero exit code.
  docker rmi -f $ALL_IMAGES || true

  log "🔄" "Pass 2: Running image prune to catch any remaining layers..."
  docker image prune -a -f

  log "✅" "All local images removed."
else
  log "ℹ️" "No images found. Running prune to catch any orphaned layers..."
  docker image prune -a -f
fi

# =============================================================================
# STEP 4 — REMOVE ALL LOCAL VOLUMES
# =============================================================================
# Volumes are the most sensitive part of this cleanup. This is where your
# actual data lives — PostgreSQL databases, Keycloak configuration,
# Redis persistence files, RabbitMQ queues, and MongoDB collections.
#
# We use a TWO-PASS approach here as well, for the same thoroughness reason:
#
# Pass 1 — Explicitly remove volumes by name using 'docker volume ls -q'.
#           This guarantees named volumes like 'dev-stack_postgres_data' are
#           caught, even if Docker's prune considers them "in use" due to
#           stale container references.
#
# Pass 2 — 'docker volume prune -f' catches any anonymous volumes that
#           Pass 1 didn't list (anonymous volumes have auto-generated names
#           like '3f8a2b1c...' and are used by containers that didn't declare
#           a named volume in their compose config).
#
# ⚠️  After this step, all database data is gone. This is intentional
#     in a full-wipe scenario, but we log each volume name so the user
#     has a record of what was removed.

section "💾  Step 4 — Removing ALL Local Volumes"
echo -e "${YELLOW}  ⚠️  This permanently deletes all database data stored in volumes.${RESET}"
echo ""

ALL_VOLUMES=$(docker volume ls -q)

if [ -n "$ALL_VOLUMES" ]; then
  COUNT=$(echo "$ALL_VOLUMES" | wc -l | tr -d ' ')
  log "📋" "Found ${COUNT} volume(s):"

  # Print each volume name on its own line so the user has a clear record
  # of exactly what was removed — useful for post-mortem debugging if
  # something important was accidentally wiped.
  echo "$ALL_VOLUMES" | while read -r vol; do
    echo "     → $vol"
  done
  echo ""

  log "🔄" "Pass 1: Removing named volumes by ID..."
  docker volume rm $ALL_VOLUMES || true

  log "🔄" "Pass 2: Running volume prune to catch anonymous volumes..."
  docker volume prune -f

  log "✅" "All local volumes removed."
else
  log "ℹ️" "No named volumes found. Running prune for anonymous volumes..."
  docker volume prune -f
fi

# =============================================================================
# STEP 5 — REMOVE ALL CUSTOM NETWORKS
# =============================================================================
# Docker networks consume minimal disk space but orphaned networks can cause
# naming conflicts when you recreate your stack (Compose will try to create
# 'dev_backend' again and fail if it already exists in a broken state).
#
# 'docker network prune' only removes CUSTOM networks — it never removes
# Docker's three built-in default networks: bridge, host, and none.
# Docker protects these automatically, so there's no risk of breaking
# Docker's core networking by running this command.

section "🌐  Step 5 — Removing Custom Networks"

docker network prune -f
log "✅" "Unused networks removed. Default networks (bridge, host, none) preserved."

# =============================================================================
# STEP 6 — CLEAR BUILD CACHE
# =============================================================================
# The build cache stores intermediate layers from 'docker build' commands.
# Each RUN, COPY, and ADD instruction in a Dockerfile creates a cached layer.
# This cache grows silently over time — it's not uncommon to accumulate
# 5-10GB after months of building custom images.
#
# Build cache is ALWAYS 100% safe to delete. It exists purely as a
# performance optimisation. The only consequence of clearing it is that
# your next 'docker build' will take longer (it rebuilds from scratch).
# Subsequent builds will be fast again as the cache repopulates.
#
# The --all flag removes internal caches that the default prune skips,
# making this more thorough than 'docker builder prune -f' alone.

section "🔧  Step 6 — Clearing Build Cache"

docker builder prune --all -f
log "✅" "Build cache cleared."

# =============================================================================
# AFTER SNAPSHOT
# =============================================================================
# Compare this output against the BEFORE snapshot at the top of the run.
# Every category should show 0B used and 0B reclaimable.
# If any numbers remain, it may indicate Docker daemon-level cached data
# that requires a daemon restart to fully flush.

section "📊 Disk Usage AFTER Cleanup"
docker system df

# =============================================================================
# FINAL SUMMARY
# =============================================================================

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║           ✅  Cleanup Complete!                   ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
echo "  Docker is now in a clean state."
echo "  To bring your dev stack back up:"
echo ""
echo "    cd ~/dev-stack"
echo "    ./generate-certs.sh        # only needed if you wiped your certs too"
echo "    docker compose up -d       # Docker will re-pull all images"
echo ""
echo -e "${YELLOW}  Note: First 'docker compose up' after a full wipe will be${RESET}"
echo -e "${YELLOW}  slow as Docker re-downloads all images from their registries.${RESET}"
echo ""
