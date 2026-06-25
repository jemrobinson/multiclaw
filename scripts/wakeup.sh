#!/usr/bin/env bash
set -euo pipefail

# ── SaferClaw Wakeup Installer ───────────────────────────────────
#
# Taken from: https://github.com/brevdev/nemoclaw-demos
#
# Sets up a host-side cron job that periodically wakes the OpenClaw
# agent inside an OpenShell sandbox via SSH. The agent reads its
# instructions from <workspace>/WAKEUP.md.
#
# Trigger path: host cron > SSH > openclaw agent > reads WAKEUP.md
# SSH is used instead of `openshell sandbox exec` because exec is
# unreliable (hangs/aborts). SSH via openshell ssh-proxy is fast
# (~400ms) and always completes.
#
# Path layout — auto-detected, with fallback for older OpenShell:
#   New (openshell ≥ 0.0.44 / openclaw ≥ 2026.5.x):
#     workspace: /sandbox/.openclaw/workspace
#     skills:    /sandbox/.openclaw/skills
#     config:    /sandbox/.openclaw/openclaw.json   (skill registry + tools profile)
#   Legacy (older builds):
#     workspace: /sandbox/.openclaw-data/workspace
#     skills:    /sandbox/.openclaw-data/skills

INSTALL_DIR="$HOME/.saferclaw/wakeup"
SANDBOXES_JSON="$HOME/.saferclaw/sandboxes.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}  ▸ $1${NC}"; }
ok()    { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()  { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail()  { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

usage_exit() {
  echo ""
  echo "  Usage: ./install.sh [options] [sandbox-name]"
  echo ""
  echo "  Options:"
  echo "    --interval <minutes>  Wakeup interval in minutes (default: 10)"
  echo "    --uninstall           Remove wakeup cron job and files"
  echo "    --status              Show current wakeup status"
  echo "    -h, --help            Show this help"
  echo ""
  echo "  The agent reads its instructions from WAKEUP.md inside the sandbox."
  echo "  Edit it via the TUI, Telegram, or manually."
  echo ""
  exit 0
}

ssh_sandbox() {
  local sandbox="$1"; shift
  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o GlobalKnownHostsFile=/dev/null \
      -o LogLevel=ERROR \
      -o ConnectTimeout=10 \
      -o ProxyCommand="$OPENSHELL_BIN ssh-proxy --gateway-name nemoclaw --name $sandbox" \
      "sandbox@openshell-$sandbox" "$@" 2>/dev/null
}

# ── Path detection ────────────────────────────────────────────────
# Sets LAYOUT, WORKSPACE_DIR, SKILLS_DIR, OPENCLAW_JSON, WAKEUP_MD_PATH,
# SKILL_DEST based on what actually exists in the target sandbox.
detect_paths() {
  local sandbox="$1"
  if ssh_sandbox "$sandbox" "[ -d /sandbox/.openclaw/workspace ]"; then
    LAYOUT="new"
    WORKSPACE_DIR="/sandbox/.openclaw/workspace"
    SKILLS_DIR="/sandbox/.openclaw/skills"
    OPENCLAW_JSON="/sandbox/.openclaw/openclaw.json"
  elif ssh_sandbox "$sandbox" "[ -d /sandbox/.openclaw-data/workspace ]"; then
    LAYOUT="legacy"
    WORKSPACE_DIR="/sandbox/.openclaw-data/workspace"
    SKILLS_DIR="/sandbox/.openclaw-data/skills"
    OPENCLAW_JSON=""
  else
    # Brand new sandbox: prefer new layout, create dirs lazily.
    LAYOUT="new"
    WORKSPACE_DIR="/sandbox/.openclaw/workspace"
    SKILLS_DIR="/sandbox/.openclaw/skills"
    OPENCLAW_JSON="/sandbox/.openclaw/openclaw.json"
  fi
  WAKEUP_MD_PATH="$WORKSPACE_DIR/WAKEUP.md"
  SKILL_DEST="$SKILLS_DIR/wakeup/SKILL.md"
}

# ── openclaw.json mutation helpers ────────────────────────────────
# All updates run a small Python program inside the sandbox over SSH so
# the JSON edit is atomic and we don't need jq.
#
# configure_openclaw_json: enable the wakeup skill in the
# skill registry and ensure tools.profile is "coding" so the agent can
# actually use `read`/`exec` to load SKILL.md and run commands.
# Idempotent. No-op on legacy layouts.
configure_openclaw_json() {
  local sandbox="$1"
  [ -z "$OPENCLAW_JSON" ] && return 0
  if ! ssh_sandbox "$sandbox" "[ -f $OPENCLAW_JSON ]"; then
    warn "$OPENCLAW_JSON not found; skipping skill-registry + tools-profile update"
    return 0
  fi
  ssh_sandbox "$sandbox" "python3 - <<'PYEOF'
import json
p = '$OPENCLAW_JSON'
d = json.load(open(p))
changed = False

# 1) Enable this skill in the registry so it surfaces in the system prompt.
entry = d.setdefault('skills', {}).setdefault('entries', {}).setdefault('wakeup', {})
if entry.get('enabled') is not True:
    entry['enabled'] = True
    changed = True

# 2) Ensure the agent has exec/read/write tools surfaced in the prompt.
# 'coding' is the documented OpenClaw profile for sandboxes that run
# binaries. Without it, OpenClaw v2026.5.18+ defaults to compact tool-
# search mode which hides 'read' and the agent never loads SKILL.md.
tools = d.setdefault('tools', {})
if tools.get('profile') is None:
    tools['profile'] = 'coding'
    changed = True
elif tools.get('profile') != 'coding':
    print('WARN: tools.profile is set to %r; leaving as-is. If the agent fails to load SKILL.md, set it to \"coding\".' % tools.get('profile'))

if changed:
    json.dump(d, open(p, 'w'), indent=2)
    print('updated')
else:
    print('already configured')
PYEOF"
}

# ── Parse arguments ───────────────────────────────────────────────
SANDBOX_NAME=""
INTERVAL=""
DO_UNINSTALL=false
DO_STATUS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)  INTERVAL="$2"; shift 2 ;;
    --uninstall) DO_UNINSTALL=true; shift ;;
    --status)    DO_STATUS=true; shift ;;
    -h|--help)   usage_exit ;;
    -*)          fail "Unknown option: $1" ;;
    *)
      if [ -z "$SANDBOX_NAME" ]; then
        SANDBOX_NAME="$1"; shift
      else
        fail "Unknown argument: $1"
      fi
      ;;
  esac
done

# ── Detect openshell path ─────────────────────────────────────────
OPENSHELL_BIN=""
for candidate in \
  "$(command -v openshell 2>/dev/null || true)" \
  "$HOME/.local/bin/openshell" \
  "/usr/local/bin/openshell" \
  "/usr/bin/openshell"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    OPENSHELL_BIN="$candidate"
    break
  fi
done
[ -z "$OPENSHELL_BIN" ] && fail "openshell CLI not found. Is NemoClaw installed?"

# ── Status mode ───────────────────────────────────────────────────
if [ "$DO_STATUS" = true ]; then
  echo ""
  echo -e "${CYAN}  SaferClaw Wakeup Status${NC}"
  echo ""

  _found_any=false
  for _env in "$INSTALL_DIR"/*.env; do
    [ -f "$_env" ] || continue
    _found_any=true

    # shellcheck disable=SC1090
    source "$_env"
    _log="${_env%.env}.log"
    _script="${_env%.env}.sh"

    echo -e "${CYAN}  ── ${WAKEUP_SANDBOX:-unknown} ──${NC}"
    echo "    Interval:  every ${WAKEUP_INTERVAL:-?} minutes"
    echo "    Layout:    ${WAKEUP_LAYOUT:-unknown}"
    echo "    WAKEUP.md: ${WAKEUP_MD_PATH:-unknown}"
    echo "    SKILL.md:  ${WAKEUP_SKILL_DEST:-unknown}"
    echo "    Trigger:   SSH (via openshell ssh-proxy)"
    echo "    Log:       $_log"

    _cron=$(crontab -l 2>/dev/null | grep "saferclaw-wakeup" | grep -F "$_script" || true)
    if [ -n "$_cron" ]; then
      ok "Cron job active"
    else
      warn "No cron job found"
    fi

    if [ -f "$_log" ]; then
      echo "  Last 5 log entries:"
      tail -10 "$_log" | grep "^[0-9]" | tail -5 | while read -r line; do
        echo "    $line"
      done
    fi

    echo ""
  done

  if [ "$_found_any" = false ]; then
    warn "Not installed"
    echo ""
  fi

  exit 0
fi

# ── Uninstall mode ────────────────────────────────────────────────
if [ "$DO_UNINSTALL" = true ]; then
  echo ""
  echo -e "${CYAN}  Removing SaferClaw Wakeup...${NC}"
  echo ""

  if [ -n "$SANDBOX_NAME" ]; then
    # Remove only this sandbox's cron entry and files.
    SANDBOX_NAME_LOWER=$(echo "$SANDBOX_NAME" | tr '[:upper:]' '[:lower:]')
    _script="$INSTALL_DIR/${SANDBOX_NAME_LOWER}.sh"
    EXISTING=$(crontab -l 2>/dev/null | grep -v "$_script" || true)
    if [ -n "$EXISTING" ]; then
      echo "$EXISTING" | crontab -
    else
      crontab -r 2>/dev/null || true
    fi
    rm -f "$INSTALL_DIR/${SANDBOX_NAME_LOWER}.sh" \
          "$INSTALL_DIR/${SANDBOX_NAME_LOWER}.env" \
          "$INSTALL_DIR/${SANDBOX_NAME_LOWER}.log" \
          "$INSTALL_DIR/${SANDBOX_NAME_LOWER}.sh.lock"
    ok "Cron job and files removed for sandbox: $SANDBOX_NAME"
  else
    # No sandbox specified — remove all saferclaw-wakeup entries.
    EXISTING=$(crontab -l 2>/dev/null | grep -v "saferclaw-wakeup" || true)
    if [ -n "$EXISTING" ]; then
      echo "$EXISTING" | crontab -
    else
      crontab -r 2>/dev/null || true
    fi
    ok "All wakeup cron jobs removed"
  fi

  echo ""
  echo -e "${GREEN}  SaferClaw Wakeup uninstalled.${NC}"
  echo ""
  exit 0
fi

# ── Main install ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║  SaferClaw Wakeup Installer                              ║${NC}"
echo -e "${CYAN}  ║  Host-Side Cron > SSH > Wakes OpenClaw Agent             ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Detect sandbox ────────────────────────────────────────
if [ -z "$SANDBOX_NAME" ]; then
  SANDBOX_NAME=$(python3 -c "
import json
try:
    d = json.load(open('$SANDBOXES_JSON'))
    print(d.get('defaultSandbox',''))
except: pass
" 2>/dev/null || true)

  if [ -z "$SANDBOX_NAME" ]; then
    SANDBOX_LIST=$("$OPENSHELL_BIN" sandbox list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -5)
    if [ -n "$SANDBOX_LIST" ]; then
      echo "  Available sandboxes:"
      echo "$SANDBOX_LIST" | while read -r s; do echo "    - $s"; done
      echo ""
    fi
    echo -n "  Sandbox name: "
    read -r SANDBOX_NAME
  fi
fi

[ -z "$SANDBOX_NAME" ] && fail "No sandbox name provided."
info "Sandbox: $SANDBOX_NAME"

# ── Step 1b: Verify SSH connectivity ──────────────────────────────
info "Testing SSH connection to sandbox..."
SSH_TEST=$(ssh_sandbox "$SANDBOX_NAME" "echo OK" || echo "FAIL")
if [ "$SSH_TEST" != "OK" ]; then
  fail "Cannot SSH into sandbox '$SANDBOX_NAME'. Is it running?"
fi
ok "SSH connection verified"

# ── Step 1c: Detect OpenClaw layout (path-aware install) ──────────
detect_paths "$SANDBOX_NAME"
info "OpenClaw layout: $LAYOUT"
info "  workspace: $WORKSPACE_DIR"
info "  skills:    $SKILLS_DIR"
[ -n "$OPENCLAW_JSON" ] && info "  config:    $OPENCLAW_JSON"

# ── Step 2: Set interval ─────────────────────────────────────────
if [ -z "$INTERVAL" ]; then
  echo ""
  echo "  How often should the wakeup trigger?"
  echo ""
  echo "    1) Every 5 minutes"
  echo "    2) Every 10 minutes (recommended)"
  echo "    3) Every 15 minutes"
  echo "    4) Every 30 minutes"
  echo "    5) Every hour"
  echo "    6) Custom"
  echo ""
  echo -n "  Choice (1-6) [2]: "
  read -r CHOICE

  case "${CHOICE:-2}" in
    1) INTERVAL=5 ;;
    2) INTERVAL=10 ;;
    3) INTERVAL=15 ;;
    4) INTERVAL=30 ;;
    5) INTERVAL=60 ;;
    6)
      echo -n "  Minutes between wakeups: "
      read -r INTERVAL
      ;;
    *) INTERVAL=10 ;;
  esac
fi

[ -z "$INTERVAL" ] && INTERVAL=10
info "Interval: every $INTERVAL minutes"

# ── Step 3: Deploy skill ──────────────────────────────────────────
echo ""
info "Checking wakeup skill is installed..."

if ssh_sandbox "$SANDBOX_NAME" "[ -f $SKILL_DEST ]"; then
  ok "Skill deployed at $SKILL_DEST"
else
  warn "Skill not found at $SKILL_DEST."
  warn "Manual fix: copy skills/wakeup/SKILL.md from this repo into the sandbox at $SKILL_DEST"
fi

# ── Step 3b: Enable skill in OpenClaw registry + set tools.profile ─
if [ "$LAYOUT" = "new" ]; then
  info "Configuring openclaw.json (skill registry + tools.profile)..."
  if configure_openclaw_json "$SANDBOX_NAME"; then
    ok "openclaw.json updated"
  else
    warn "Could not update openclaw.json; agent may not surface SKILL.md"
    warn "Manual fix: edit $OPENCLAW_JSON and add:"
    warn '  "skills": { "entries": { "wakeup": { "enabled": true } } }'
    warn '  "tools":  { "profile": "coding" }'
  fi
fi

# ── Step 4: Seed WAKEUP.md if missing ────────────────────────────
info "Checking for WAKEUP.md in sandbox..."

ssh_sandbox "$SANDBOX_NAME" "mkdir -p $WORKSPACE_DIR" || true
HB_EXISTS=$(ssh_sandbox "$SANDBOX_NAME" "[ -f $WAKEUP_MD_PATH ] && echo yes || echo no")

if [ "$HB_EXISTS" = "no" ]; then
  info "Seeding default WAKEUP.md at $WAKEUP_MD_PATH..."

  ssh_sandbox "$SANDBOX_NAME" "cat > $WAKEUP_MD_PATH" << 'WKMD'
# Wakeup Instructions

This file is read by the OpenClaw agent every time the host-side wakeup
triggers. Edit these instructions to control what the agent does on each pulse.
WKMD

  ok "Default WAKEUP.md deployed"
else
  ok "WAKEUP.md already exists in sandbox"
fi

# ── Step 5: Create wakeup.sh ─────────────────────────────────────
info "Installing wakeup script..."

mkdir -p "$INSTALL_DIR"
SANDBOX_NAME_LOWER=$(echo "$SANDBOX_NAME" | tr '[:upper:]' '[:lower:]')
CRON_ENV_FILE="$INSTALL_DIR/${SANDBOX_NAME_LOWER}.env"
CRON_LOG_FILE="$INSTALL_DIR/${SANDBOX_NAME_LOWER}.log"
CRON_SCRIPT_FILE="$INSTALL_DIR/${SANDBOX_NAME_LOWER}.sh"

cat > "$CRON_SCRIPT_FILE" << WKEOF
#!/bin/bash
# SaferClaw Wakeup — fires the OpenClaw agent via SSH.
# Uses flock to prevent overlapping runs. Uses unique session IDs
# to prevent context bleed between pulses.

CONFIG="$CRON_ENV_FILE"
LOG="$CRON_LOG_FILE"
LOCK="${CRON_SCRIPT_FILE}.lock"

source "\$CONFIG" 2>/dev/null || {
  echo "\$(date +%Y-%m-%dT%H:%M:%S) ERROR ${SANDBOX_NAME_LOWER}.env missing" >> "\$LOG"
  exit 1
}

MAX_LOG=1000

# ── Concurrency guard (flock) ────────────────────────────────────
exec 9>"\$LOCK"
if ! flock -n 9; then
  echo "\$(date +%Y-%m-%dT%H:%M:%S) SKIP previous wakeup still running" >> "\$LOG"
  exit 0
fi

# ── Unique session ID ────────────────────────────────────────────
SESSION_ID="wakeup-\$(date +%s)-\$\$"

# ── Agent message ────────────────────────────────────────────────
# Baked-in path is the one detected at install time. Agent is told to
# try the new path first and fall back to the legacy path so wakeup
# pulses survive a sandbox-image upgrade between install runs.
AGENT_MSG="SaferClaw Wakeup triggered. You MUST read the file \${WAKEUP_MD_PATH} right now and follow ONLY the instructions in that file. If that file does not exist, try /sandbox/.openclaw/workspace/WAKEUP.md then /sandbox/.openclaw-data/workspace/WAKEUP.md. Do not use cached or remembered instructions from previous sessions. Do not send messages to Telegram, Discord, or Slack unless WAKEUP.md explicitly tells you to."

echo "\$(date +%Y-%m-%dT%H:%M:%S) START session=\$SESSION_ID sandbox=\$WAKEUP_SANDBOX" >> "\$LOG"

# ── Fire agent via SSH (fire-and-forget with timeout) ────────────
ssh -o StrictHostKeyChecking=no \\
    -o UserKnownHostsFile=/dev/null \\
    -o GlobalKnownHostsFile=/dev/null \\
    -o LogLevel=ERROR \\
    -o ConnectTimeout=10 \\
    -o ServerAliveInterval=30 \\
    -o ServerAliveCountMax=4 \\
    -o ProxyCommand="\$WAKEUP_OPENSHELL ssh-proxy --gateway-name nemoclaw --name \$WAKEUP_SANDBOX" \\
    "sandbox@openshell-\$WAKEUP_SANDBOX" \\
    "openclaw agent --agent main --message \\"\$AGENT_MSG\\" --session-id \\"\$SESSION_ID\\"" >> "\$LOG" 2>&1
EXIT_CODE=\$?

if [ \$EXIT_CODE -eq 0 ]; then
  echo "\$(date +%Y-%m-%dT%H:%M:%S) DONE session=\$SESSION_ID exit=0" >> "\$LOG"
else
  echo "\$(date +%Y-%m-%dT%H:%M:%S) FAIL session=\$SESSION_ID exit=\$EXIT_CODE" >> "\$LOG"
fi

# ── Log rotation ─────────────────────────────────────────────────
LINES=\$(wc -l < "\$LOG" 2>/dev/null || echo 0)
if [ "\$LINES" -gt "\$MAX_LOG" ]; then
  tail -n 500 "\$LOG" > "\$LOG.tmp" && mv "\$LOG.tmp" "\$LOG"
fi
WKEOF

chmod +x "$CRON_SCRIPT_FILE"
ok "Wakeup script: $CRON_SCRIPT_FILE"

# ── Step 6: Save config ──────────────────────────────────────────
cat > "$CRON_ENV_FILE" << CFGEOF
WAKEUP_SANDBOX="$SANDBOX_NAME"
WAKEUP_INTERVAL="$INTERVAL"
WAKEUP_OPENSHELL="$OPENSHELL_BIN"
WAKEUP_LAYOUT="$LAYOUT"
WAKEUP_MD_PATH="$WAKEUP_MD_PATH"
WAKEUP_SKILL_DEST="$SKILL_DEST"
CFGEOF
ok "Config: $CRON_ENV_FILE"

# ── Step 7: Install cron job ─────────────────────────────────────
info "Setting up cron job..."

CRON_ENTRY="*/$INTERVAL * * * * $CRON_SCRIPT_FILE  # saferclaw-wakeup"

# Replace this sandbox's existing cron entry only, preserving other sandboxes.
EXISTING_CRON=$(crontab -l 2>/dev/null | grep -v "$CRON_SCRIPT_FILE" || true)
if [ -n "$EXISTING_CRON" ]; then
  (echo "$EXISTING_CRON"; echo "$CRON_ENTRY") | crontab -
else
  echo "$CRON_ENTRY" | crontab -
fi

ok "Cron job installed (every $INTERVAL minutes)"

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║  SaferClaw Wakeup installed!                             ║${NC}"
echo -e "${GREEN}  ╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Sandbox:    $SANDBOX_NAME"
echo "  Layout:     $LAYOUT (workspace: $WORKSPACE_DIR)"
echo "  Interval:   every $INTERVAL minutes"
echo "  Trigger:    SSH (via openshell ssh-proxy, ~400ms)"
echo "  Log file:   $CRON_LOG_FILE"
echo ""
echo "  The agent reads $WAKEUP_MD_PATH for its instructions."
echo "  To change what the agent does:"
echo ""
echo "    Via TUI or Telegram:"
echo "      \"Update my $WAKEUP_MD_PATH to also check my calendar\""
echo ""
echo "    Via SSH:"
echo "      openshell sandbox connect $SANDBOX_NAME"
echo "      nano $WAKEUP_MD_PATH"
echo ""
echo "  Commands:"
echo "    Test now:         $CRON_SCRIPT_FILE"
echo "    View log:         tail -f $CRON_LOG_FILE"
echo "    Check status:     ./install.sh --status"
echo "    Change interval:  ./install.sh --interval 30"
echo "    Uninstall:        ./install.sh --uninstall"
echo ""
