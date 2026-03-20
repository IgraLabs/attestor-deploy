#!/bin/bash
# setup.sh - Interactive setup for the Igra Attestor
#
# Usage: ./setup.sh <testnet|mainnet>
#
# Prerequisites: igra-orchestra must be running with the backend and frontend-w1 profiles.

set -euo pipefail
trap 'PRIVATE_KEY=; unset PRIVATE_KEY 2>/dev/null' EXIT INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; exit 1; }

# --- Validate network argument ---
SELECTED_NETWORK="${1:-}"
if [[ "$SELECTED_NETWORK" != "testnet" && "$SELECTED_NETWORK" != "mainnet" ]]; then
    echo "Usage: ./setup.sh <testnet|mainnet>"
    exit 1
fi

echo "========================================"
echo "  Igra Attestor Setup ($SELECTED_NETWORK)"
echo "========================================"
echo

# --- Prerequisites ---
log "Checking prerequisites..."

command -v docker &>/dev/null || die "Docker is not installed."
docker compose version &>/dev/null || die "Docker Compose is not installed."
docker info &>/dev/null || die "Docker daemon is not running."
log "Docker: OK"

# --- Environment ---
ENV_TEMPLATE=".env.example.${SELECTED_NETWORK}"
if [[ ! -f .env ]]; then
    if [[ ! -f "$ENV_TEMPLATE" ]]; then
        die "$ENV_TEMPLATE not found. Are you in the deploy directory?"
    fi
    cp "$ENV_TEMPLATE" .env
    chmod 600 .env
    log "Created .env from $ENV_TEMPLATE"
else
    log "Using existing .env"
fi

# Source .env to read NETWORK
set -a
# shellcheck source=/dev/null
source .env
set +a

# Validate that .env NETWORK matches the requested network
if [[ "$NETWORK" != "$SELECTED_NETWORK" ]]; then
    die "Existing .env has NETWORK=$NETWORK but you requested $SELECTED_NETWORK. Remove .env and re-run, or edit .env manually."
fi

# Verify orchestra network exists
NETWORK_NAME="igra-orchestra-${NETWORK}_igra-network"
if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
    die "Docker network '$NETWORK_NAME' not found.\n  Is igra-orchestra running? Start it first with: docker compose --profile backend --profile frontend-w1 up -d"
fi
log "Orchestra network ($NETWORK_NAME): OK"
echo

# --- Private Key ---
mkdir -p secrets
chmod 700 secrets

if [[ -f secrets/private_key.txt ]]; then
    log "Private key file already exists: secrets/private_key.txt"
    read -r -p "Overwrite with a new key? [y/N]: " overwrite
    if [[ ! "$overwrite" =~ ^[Yy] ]]; then
        log "Keeping existing key"
    else
        if [[ -t 0 ]]; then
            read -r -s -p "Enter your attester private key: " PRIVATE_KEY
            echo
        else
            read -r PRIVATE_KEY
        fi
        [[ -z "$PRIVATE_KEY" ]] && die "Private key cannot be empty."
        printf '%s' "$PRIVATE_KEY" > secrets/private_key.txt
        chmod 600 secrets/private_key.txt
        log "Private key saved"
        PRIVATE_KEY=""
        unset PRIVATE_KEY
    fi
else
    echo "Enter the private key for your attester account."
    echo "This will be stored in secrets/private_key.txt (permissions 600)."
    echo
    if [[ -t 0 ]]; then
        read -r -s -p "Private key: " PRIVATE_KEY
        echo
    else
        read -r PRIVATE_KEY
    fi
    [[ -z "$PRIVATE_KEY" ]] && die "Private key cannot be empty."
    printf '%s' "$PRIVATE_KEY" > secrets/private_key.txt
    chmod 600 secrets/private_key.txt
    log "Private key saved"
    PRIVATE_KEY=""
    unset PRIVATE_KEY
fi
echo

# --- Start ---
log "Starting attestor..."
if ! docker compose up -d; then
    die "Failed to start attestor."
fi
echo

echo "========================================"
echo "  Attestor is running!"
echo "========================================"
echo
echo "Useful commands:"
echo "  docker compose logs -f              # Follow logs"
echo "  curl -s localhost:${HEALTH_PORT:-8180} | jq          # Health status"
echo "  curl -s localhost:${METRICS_PORT:-9190} | jq          # Metrics"
echo "  curl -s localhost:${METRICS_PORT:-9190}/prometheus    # Prometheus metrics"
echo "  docker compose down                 # Stop attestor"
echo
