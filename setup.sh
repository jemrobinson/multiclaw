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

echo "==> Configuration options"
prompt_env_var "HuggingFace API token" "HF_TOKEN"
prompt_env_var "OpenShell installation path" "OPENSHELL_INSTALL_PATH"
OPENSHELL_INSTALL_PATH="$(read_env_var "OPENSHELL_INSTALL_PATH")"
OPENSHELL_INSTALL_PATH="${OPENSHELL_INSTALL_PATH:--/tmp/openshell}"
prompt_env_var "vLLM port" "VLLM_PORT"
VLLM_PORT="$(read_env_var "VLLM_PORT")"
VLLM_PORT="${VLLM_PORT:-8020}"
echo ""

echo "==> Installing OpenShell binary"
OPENSHELL_SUPERVISOR_DIR="${OPENSHELL_INSTALL_PATH}/supervisor"
mkdir -p "$OPENSHELL_SUPERVISOR_DIR"
docker create --name tmp-supervisor ghcr.io/nvidia/openshell/supervisor:latest
docker cp tmp-supervisor:/openshell-sandbox "${OPENSHELL_SUPERVISOR_DIR}/openshell-sandbox"
docker rm tmp-supervisor
chmod +x "${OPENSHELL_SUPERVISOR_DIR}/openshell-sandbox"

echo "==> Writing OpenShell gateway JWT and config"
OPENSHELL_GATEWAY_DIR="${OPENSHELL_INSTALL_PATH}/gateway"
mkdir -p "$OPENSHELL_GATEWAY_DIR"

# Generate stable JWT signing keys once; preserve across re-runs so live
# sandbox tokens don't become invalid on restart.
OPENSHELL_JWT_DIR="${OPENSHELL_GATEWAY_DIR}/jwt"
mkdir -p "$OPENSHELL_JWT_DIR"
if [[ ! -f "${OPENSHELL_JWT_DIR}/signing.pem" ]]; then
  openssl genrsa -out "${OPENSHELL_JWT_DIR}/signing.pem" 4096
  openssl rsa -in "${OPENSHELL_JWT_DIR}/signing.pem" \
    -pubout -out "${OPENSHELL_JWT_DIR}/public.pem"
  openssl rand -hex 16 > "${OPENSHELL_JWT_DIR}/kid"
fi

cat << EOF > "${OPENSHELL_GATEWAY_DIR}/config.toml"
# From https://github.com/NVIDIA/OpenShell/blob/main/deploy/docker/gateway.toml
[openshell]
version = 1

[openshell.gateway]
bind_address        = "127.0.0.1:8080"
health_bind_address = "127.0.0.1:8081"
log_level           = "info"
compute_drivers     = ["docker"]
disable_tls         = true

[openshell.gateway.gateway_jwt]
signing_key_path = "/etc/openshell/jwt/signing.pem"
public_key_path  = "/etc/openshell/jwt/public.pem"
kid_path         = "/etc/openshell/jwt/kid"
gateway_id       = "openshell"

[openshell.drivers.docker]
default_image     = "ghcr.io/nvidia/openshell-community/sandboxes/base:latest"
supervisor_image  = "ghcr.io/nvidia/openshell/supervisor:latest"
image_pull_policy = "IfNotPresent"
sandbox_namespace = "openshell"
grpc_endpoint     = "http://host.openshell.internal:8080"
EOF
echo ""

echo "==> Starting the docker compose stack"
docker compose down
docker compose up -d
echo ""

echo "==> Waiting for OpenShell gateway to be healthy"
until nc -z 127.0.0.1 "${OPENSHELL_PORT:-8080}" 2>/dev/null; do
  echo "  gateway not ready yet, retrying in 2s..."
  sleep 2
done
echo "  gateway is healthy"
echo ""

echo "==> Registering the OpenShell gateway and provider"
sleep 2
if ! openshell gateway list | grep -q 'multiclaw'; then
  openshell gateway add http://127.0.0.1:8080 --local --name multiclaw
fi
if ! openshell provider list --gateway multiclaw | grep -q 'multiclaw-vllm'; then
  PUBLIC_IP="$(hostname -I | awk '{print $1}')"
  openshell provider create \
    --config "OPENAI_BASE_URL=http://${PUBLIC_IP}:${VLLM_PORT}/v1" \
    --credential "OPENAI_API_KEY=dummy" \
    --name multiclaw-vllm \
    --type openai
fi

openshell inference set --provider multiclaw-vllm --model openai/gpt-oss-20b