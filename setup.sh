#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"

# Write or update a key=value line in the .env file
upsert_env_key() {
  local key="$1" value="$2"
  if [[ -f "$ENV_FILE" ]] && grep -q "^${key}=" "$ENV_FILE"; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  else
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

read_env_key() {
  local key="$1"
  if [[ ! -f "$ENV_FILE" ]]; then return; fi
  grep "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '\r' || true
}

prompt_api_key() {
  local label="$1" key="$2"
  local existing
  existing="$(read_env_key "$key")"
  if [[ -n "$existing" ]]; then
    echo "$label already set, skipping."
    return
  fi
  read -r -p "$label (leave blank to skip): " value
  if [[ -n "$value" ]]; then
    upsert_env_key "$key" "$value"
    echo "  Saved $key."
  fi
}

echo "==> Provider API keys"
prompt_api_key "Anthropic API key" "ANTHROPIC_API_KEY"
prompt_api_key "Claude AI session key" "CLAUDE_AI_SESSION_KEY"
prompt_api_key "OpenAI API key" "OPENAI_API_KEY"
prompt_api_key "HuggingFace token" "HF_TOKEN"
echo ""

echo "==> Gateway token"
existing_token="$(read_env_key "OPENCLAW_GATEWAY_TOKEN")"
if [[ -n "$existing_token" ]]; then
  echo "Gateway token already present in .env, reusing."
else
  if command -v openssl >/dev/null 2>&1; then
    token="$(openssl rand -hex 32)"
  else
    token="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  fi
  upsert_env_key "OPENCLAW_GATEWAY_TOKEN" "$token"
  echo "Generated and saved new gateway token."
fi
echo ""

echo "==> Pre-creating bind-mount directories"
# Resolve host-side source paths and write them to .env so docker-compose uses
# them for volume mount sources. The environment: section in compose then pins
# the container-side values to /home/node/... regardless of these host paths.
# OPENCLAW_CONFIG_DIR is the base; compose appends /0/config for the mount source.
OPENCLAW_CONFIG_DIR="$(read_env_key "OPENCLAW_CONFIG_DIR")"
OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-${HOME:-/tmp}/.multiclaw}"
upsert_env_key "OPENCLAW_CONFIG_DIR" "$OPENCLAW_CONFIG_DIR"

OPENCLAW_WORKSPACE_DIR="$(read_env_key "OPENCLAW_WORKSPACE_DIR")"
OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-${HOME:-/tmp}/.multiclaw/0/workspace}"
upsert_env_key "OPENCLAW_WORKSPACE_DIR" "$OPENCLAW_WORKSPACE_DIR"

OPENCLAW_AUTH_PROFILE_SECRET_DIR="$(read_env_key "OPENCLAW_AUTH_PROFILE_SECRET_DIR")"
OPENCLAW_AUTH_PROFILE_SECRET_DIR="${OPENCLAW_AUTH_PROFILE_SECRET_DIR:-${HOME:-/tmp}/.multiclaw/0/auth-profile-secrets}"
upsert_env_key "OPENCLAW_AUTH_PROFILE_SECRET_DIR" "$OPENCLAW_AUTH_PROFILE_SECRET_DIR"

HF_HUB_CACHE="$(read_env_key "HF_HUB_CACHE")"
HF_HUB_CACHE="${HF_HUB_CACHE:-${HOME:-/tmp}/.cache/huggingface}"
upsert_env_key "HF_HUB_CACHE" "$HF_HUB_CACHE"

# Create multiclaw directories so that bind mounts work on Docker
for DIRECTORY in "$OPENCLAW_CONFIG_DIR/0/config/agents/main/agent" \
                 "$OPENCLAW_CONFIG_DIR/0/config/agents/main/sessions" \
                 "$OPENCLAW_CONFIG_DIR/0/config/identity" \
                 "$OPENCLAW_CONFIG_DIR/0/config/workspace" \
                 "$OPENCLAW_WORKSPACE_DIR" \
                 "$OPENCLAW_AUTH_PROFILE_SECRET_DIR" \
                 "$HF_HUB_CACHE"; do
  mkdir -p "$DIRECTORY"
  echo "Ensured directory $DIRECTORY exists"
done

echo "==> Starting Multiclaw with Docker"
docker compose down
docker compose build
docker compose up -d
