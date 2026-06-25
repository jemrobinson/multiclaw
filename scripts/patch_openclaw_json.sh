#!/usr/bin/env bash
set -euo pipefail

# Patches openclaw.json inside an OpenShell sandbox:
#   - enables the wakeup skill in the skill registry
#   - sets tools.profile to "coding" if unset
# Safe to run standalone or called from wakeup.sh.
# Pass OPENSHELL_BIN via env to skip re-detection when called from wakeup.sh.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}  ▸ $1${NC}"; }
ok()    { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()  { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail()  { echo -e "${RED}  ✗ $1${NC}"; exit 1; }

SANDBOX_NAME="${1:-}"
[ -z "$SANDBOX_NAME" ] && fail "Usage: $(basename "$0") <sandbox-name>"

# ── Detect openshell (accept pre-detected path via env) ───────────
if [ -z "${OPENSHELL_BIN:-}" ]; then
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
fi
[ -z "${OPENSHELL_BIN:-}" ] && fail "openshell CLI not found. Is NemoClaw installed?"

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

# ── Locate openclaw.json ──────────────────────────────────────────
OPENCLAW_JSON="/sandbox/.openclaw/openclaw.json"

if ! ssh_sandbox "$SANDBOX_NAME" "[ -f $OPENCLAW_JSON ]"; then
  # Distinguish legacy layout (no openclaw.json expected) from genuinely missing.
  if ssh_sandbox "$SANDBOX_NAME" "[ -d /sandbox/.openclaw-data/workspace ]" && \
     ! ssh_sandbox "$SANDBOX_NAME" "[ -d /sandbox/.openclaw/workspace ]"; then
    warn "Legacy OpenClaw layout; openclaw.json not present. Nothing to patch."
  else
    warn "$OPENCLAW_JSON not found; skipping skill-registry + tools-profile update"
  fi
  exit 0
fi

# ── Patch ─────────────────────────────────────────────────────────
info "Patching $OPENCLAW_JSON on sandbox '$SANDBOX_NAME'..."
info "  1. enable the wakeup skill in the registry"
info "  2. allow exec/read/write tools in the prompt (tools.profile=coding)"
info "  3. allow pro-active Slack interactions without an explicit mention"
ssh_sandbox "$SANDBOX_NAME" "python3 - <<'PYEOF'
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

# 3) Disable requireMention so the agent responds without needing to be @-mentioned.
def patch_require_mention(obj):
    patched = False
    if isinstance(obj, dict):
        if 'requireMention' in obj:
            if obj['requireMention'] is not False:
                obj['requireMention'] = False
                patched = True
            if obj.get('allowBots') is not True:
                obj['allowBots'] = True
                patched = True
        for v in obj.values():
            if patch_require_mention(v):
                patched = True
    elif isinstance(obj, list):
        for item in obj:
            if patch_require_mention(item):
                patched = True
    return patched
if patch_require_mention(d):
    changed = True

if changed:
    json.dump(d, open(p, 'w'), indent=2)
    print('updated')
else:
    print('already configured')
PYEOF"
