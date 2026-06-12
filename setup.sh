#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"

# Write or update a key=value line in the .env file
upsert_env_var() {
  local key="$1" value="$2"
  if [[ -f "$ENV_FILE" ]] && grep -q "^${key}=" "$ENV_FILE"; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  else
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

read_env_var() {
  local key="$1"
  if [[ ! -f "$ENV_FILE" ]]; then return; fi
  grep "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '\r' || true
}

prompt_env_var() {
  local label="$1" key="$2"
  local existing
  existing="$(read_env_var "$key")"
  if [[ -n "$existing" ]]; then
    echo "$label already set, skipping."
    return
  fi
  read -r -p "$label (leave blank to skip): " value
  if [[ -n "$value" ]]; then
    upsert_env_var "$key" "$value"
    echo "  Saved $key."
  fi
}

echo "==> Provider API keys"
prompt_env_var "HuggingFace token" "HF_TOKEN"
echo ""

echo "==> Working paths"
prompt_env_var "OpenShell installation path" "OPENSHELL_INSTALL_PATH"
echo ""

echo "==> Installing OpenShell binary"
OPENSHELL_SUPERVISOR_PATH="$(read_env_var "OPENSHELL_INSTALL_PATH")"
OPENSHELL_SUPERVISOR_PATH="${OPENSHELL_SUPERVISOR_PATH:--/tmp/openshell}/supervisor"
mkdir -p "$OPENSHELL_SUPERVISOR_PATH"
docker create --name tmp-supervisor ghcr.io/nvidia/openshell/supervisor:latest
docker cp tmp-supervisor:/openshell-sandbox "${OPENSHELL_SUPERVISOR_PATH}/openshell-sandbox"
docker rm tmp-supervisor
chmod +x "${OPENSHELL_SUPERVISOR_PATH}/openshell-sandbox"
