#!/usr/bin/env bash
set -euo pipefail

BOLD=$(tput bold)
NORMAL=$(tput sgr0)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"
if [[ $# -lt 1 ]]; then
  echo "Must provide a sandbox name as the first argument."
  exit 1
fi
NEMOCLAW_SANDBOX_NAME=$1

# Read a key=value line from the .env file
read_env_var() {
  local key="$1"
  if [[ ! -f "$ENV_FILE" ]]; then return; fi
  grep "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '\r' || true
}

echo "${BOLD}==> Reading environment variables${NORMAL}"
HF_MODEL_NAME="$(read_env_var "HF_MODEL_NAME")"
HF_MODEL_NAME="${HF_MODEL_NAME:-gpt-oss-20b}"
echo "Hugging Face model name: $HF_MODEL_NAME"
HF_MODEL_REPO="$(read_env_var "HF_MODEL_REPO")"
HF_MODEL_REPO="${HF_MODEL_REPO:-openai}"
echo "Hugging Face model family: $HF_MODEL_REPO"
PUBLIC_IP="$(hostname -I | awk '{print $1}')"
VLLM_PORT="$(read_env_var "VLLM_PORT")"
VLLM_PORT="${VLLM_PORT:-8020}"
echo "vLLM external port: $VLLM_PORT"

# Build a local image with gh
echo "${BOLD}==> Building custom base image for sandboxes${NORMAL}"
docker build -f "${ROOT_DIR}/Dockerfile.sandbox" -t sandbox-base:latest "${ROOT_DIR}"
sed -i "s|BASE_IMAGE=.*:latest|BASE_IMAGE=sandbox-base:latest|g" "${HOME}/.nemoclaw/source/Dockerfile"

# Onboard a new sandbox
echo "${BOLD}==> Configuring NemoClaw${NORMAL}"
echo "You will need to:"
echo "  1. Accept the NVIDIA EULA"
echo "  2. Do not run express install"
echo "  3. When asked for 'Inference options:'"
echo "     - if you see '7) Local vLLM [experimental] (localhost:${VLLM_PORT}) — running (suggested)' then choose that"
echo "     - if not then select '5) Other Anthropic-compatible endpoint'"
echo "       - 'Anthropic-compatible base URL' should be 'http://${PUBLIC_IP}:${VLLM_PORT}/v1'"
echo "       - 'Other Anthropic-compatible endpoint API key:' should be 'dummy'"
echo "       - 'Other Anthropic-compatible endpoint model: should be '${HF_MODEL_REPO}/${HF_MODEL_NAME}'"
echo "  4. When asked for 'Sandbox name' enter whatever you want, e.g. 'saferclaw'"
echo "  5. When asked 'Apply this configuration? [Y/n]:', check the details and select 'Y'"
echo "  6. When asked 'Available messaging channels:', we suggest using Slack (you will need a bot token)"
echo "  7. Networking presets: we suggest including only 'npm', 'pypi', 'huggingface', 'claude-code', 'slack'"
nemoclaw onboard --no-gpu --name "$NEMOCLAW_SANDBOX_NAME"

# Patch the sandbox
echo "${BOLD}==> Patching the $NEMOCLAW_SANDBOX_NAME sandbox${NORMAL}"
echo "  1. Applying network policies from ./policies"
nemoclaw "$NEMOCLAW_SANDBOX_NAME" policy-add --from-dir ./policies/ --yes
echo "  2. Installing skills from ./skills"
for SKILL_PATH in ./skills/*/; do
  nemoclaw "$NEMOCLAW_SANDBOX_NAME" skill install "${SKILL_PATH}"
done
echo "  3. Installing wakeup command"
./scripts/wakeup.sh "$NEMOCLAW_SANDBOX_NAME"

# Instructions to the user
echo "${BOLD}==> User actions${NORMAL}"
echo "To configure GitHub token login:"
echo "  - open an openclaw terminal with 'nemoclaw $NEMOCLAW_SANDBOX_NAME connect'"
echo "  - then in the openclaw terminal, run: 'gh auth login'"
