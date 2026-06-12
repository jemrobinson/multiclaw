#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"
AUTH_PROFILE_SECRET_DIR="${HOME:-/tmp}/.multiclaw/0/auth-profile-secrets"

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

echo "==> Gateway public URL"
existing_url="$(read_env_key "OPENCLAW_PUBLIC_URL")"
if [[ -n "$existing_url" ]]; then
  echo "OPENCLAW_PUBLIC_URL already set to: $existing_url"
else
  read -r -p "Public URL for this gateway (e.g. http://a.b.c.d:8500, leave blank for local-only): " public_url
  if [[ -n "$public_url" ]]; then
    upsert_env_key "OPENCLAW_PUBLIC_URL" "$public_url"
    echo "  Saved OPENCLAW_PUBLIC_URL."
  fi
fi
echo ""

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

echo "==> Creating auth-profile secrets directory"
mkdir -p "$AUTH_PROFILE_SECRET_DIR"
echo "$AUTH_PROFILE_SECRET_DIR"
echo ""

echo "==> Starting Multiclaw with Docker"
docker compose down
docker compose build
docker compose up -d
