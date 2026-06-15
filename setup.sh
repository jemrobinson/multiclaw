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
  read -r -p "$label (leave blank to use default): " value
  if [[ -n "$value" ]]; then
    upsert_env_var "$key" "$value"
    echo "  Saved $key."
  fi
}

echo "==> Setting environment variables"
prompt_env_var "Hugging Face local cache path" "HF_HUB_CACHE"
HF_HUB_CACHE="$(read_env_var "HF_HUB_CACHE")"
HF_HUB_CACHE="${HF_HUB_CACHE:-${HOME}/.cache/huggingface}"
echo "... using '$HF_HUB_CACHE'"
prompt_env_var "Hugging Face model name" "HF_MODEL_NAME"
HF_MODEL_NAME="$(read_env_var "HF_MODEL_NAME")"
HF_MODEL_NAME="${HF_MODEL_NAME:-gpt-oss-20b}"
echo "... using '$HF_MODEL_NAME'"
prompt_env_var "Hugging Face model family" "HF_MODEL_REPO"
HF_MODEL_REPO="$(read_env_var "HF_MODEL_REPO")"
HF_MODEL_REPO="${HF_MODEL_REPO:-openai}"
echo "... using '$HF_MODEL_REPO'"
prompt_env_var "Hugging Face access token" "HF_TOKEN"
HF_TOKEN="$(read_env_var "HF_TOKEN")"
if [[ -n "$HF_TOKEN" ]]; then
  echo "... using provided token"
else
  echo "... no token provided, skipping"
fi
prompt_env_var "NemoClaw installation tag" "NEMOCLAW_INSTALL_TAG"
NEMOCLAW_INSTALL_TAG="$(read_env_var "NEMOCLAW_INSTALL_TAG")"
NEMOCLAW_INSTALL_TAG="${NEMOCLAW_INSTALL_TAG:-v0.0.64}"
echo "... using $NEMOCLAW_INSTALL_TAG"
prompt_env_var "vLLM external port" "VLLM_PORT"
VLLM_PORT="$(read_env_var "VLLM_PORT")"
VLLM_PORT="${VLLM_PORT:-8020}"
echo "... using $VLLM_PORT"
prompt_env_var "vLLM version" "VLLM_VERSION"
VLLM_VERSION="$(read_env_var "VLLM_VERSION")"
VLLM_VERSION="${VLLM_VERSION:-26.05.post1-py3}"
echo "... using $VLLM_VERSION"

echo "==> Preparing to install NemoClaw..."
read -r -p "Do you want to start a vLLM server to run ${HF_MODEL_REPO}/${HF_MODEL_NAME}? " START_VLLM
PUBLIC_IP="$(hostname -I | awk '{print $1}')"
if [[ "$START_VLLM" =~ ^[Yy]$ ]]; then
    docker compose down
    docker compose up -d
    echo "vLLM server will be available at http://${PUBLIC_IP}:${VLLM_PORT}"
    echo "You can check configuration progress by running docker compose logs"
fi
echo "==> Currently available vLLM models..."
curl http://${PUBLIC_IP}:${VLLM_PORT}/v1/models

echo "==> Installing NemoClaw ${NEMOCLAW_INSTALL_TAG}"
echo "You will need to:"
echo "  1. Accept the NVIDIA EULA"
echo "  2. Do not run express install"
echo "  3. When asked for 'Inference options:'"
echo "     - select '5) Other Anthropic-compatible endpoint'"
echo "     - 'Anthropic-compatible base URL' should be 'http://${PUBLIC_IP}:${VLLM_PORT}/v1'"
echo "     - 'Other Anthropic-compatible endpoint API key:' should be 'dummy'"
echo "     - 'Other Anthropic-compatible endpoint model: should be '${HF_MODEL_REPO}/${HF_MODEL_NAME}'"
echo "  4. When asked for 'Sandbox name' enter whatever you want, e.g. 'saferclaw'"
echo "  5. When asked 'Apply this configuration? [Y/n]:', check the details and select 'Y'"
echo "  6. When asked 'Available messaging channels:', we suggest using Slack (you will need a bot token)"
echo "  7. Networking presets: we suggest including only 'npm', 'pypi', 'huggingface', 'brew', 'github', 'slack'"
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash

echo "==> Using NemoClaw agents"
echo "The easiest way will be to use the terminal UI:"
echo "> nemoclaw \$SANDBOX_NAME connect"
echo "> nemoclaw dactyl connect"
