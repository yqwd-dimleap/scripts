#!/usr/bin/env bash
set -Eeuo pipefail

# Claude Code reads the gateway URL and credentials from the env node in settings.json.
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/backup-apiqik"

log() {
  printf '[APIQIK] %s\n' "$1" >&2
}

fail() {
  printf '[APIQIK] Error: %s\n' "$1" >&2
  exit 1
}

require_python() {
  command -v python3 >/dev/null 2>&1 || fail 'Python 3 is required to safely merge and validate settings.json.'
}

normalize_base_url() {
  local value="$1"
  value="${value%/}"
  if [[ "$value" == */v1 ]]; then
    value="${value%/v1}"
    log 'Removed the trailing /v1 from the Base URL to avoid duplicating the request path.'
  fi
  [[ "$value" =~ ^https?://[^[:space:]]+$ ]] || fail 'Base URL must use an http:// or https:// address.'
  printf '%s' "$value"
}

backup_settings() {
  [[ -f "$SETTINGS_FILE" ]] || return 0

  local timestamp backup_file
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_file="$BACKUP_DIR/settings.json.$timestamp"
  mkdir -p "$BACKUP_DIR"
  cp "$SETTINGS_FILE" "$backup_file"
  log "Backed up the existing configuration: $backup_file"
}

write_settings() {
  local base_url="$1"
  local model="$2"
  local api_key
  read -r -s -p 'Enter the APIQIK API key: ' api_key
  printf '\n'
  [[ -n "$api_key" ]] || fail 'API key cannot be empty.'

  mkdir -p "$CLAUDE_DIR"
  chmod 700 "$CLAUDE_DIR"
  backup_settings

  APIQIK_SETUP_KEY="$api_key" python3 - "$SETTINGS_FILE" "$base_url" "$model" <<'PY'
import json
import os
import sys
import tempfile

settings_path, base_url, model = sys.argv[1:]
api_key = os.environ.get("APIQIK_SETUP_KEY", "")

if not api_key:
    raise SystemExit("API key cannot be empty")

settings = {}
if os.path.exists(settings_path):
    with open(settings_path, encoding="utf-8") as source:
        settings = json.load(source)
if not isinstance(settings, dict):
    raise SystemExit("settings.json must contain a top-level JSON object")

env = settings.get("env")
if env is None:
    env = {}
elif not isinstance(env, dict):
    raise SystemExit("settings.json env must be a JSON object")

env["ANTHROPIC_BASE_URL"] = base_url
env["ANTHROPIC_AUTH_TOKEN"] = api_key
if model:
    env["ANTHROPIC_MODEL"] = model
else:
    env.pop("ANTHROPIC_MODEL", None)
settings["env"] = env

parent = os.path.dirname(settings_path) or "."
fd, temporary_path = tempfile.mkstemp(prefix="settings.json.", suffix=".tmp", dir=parent, text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as target:
        json.dump(settings, target, ensure_ascii=False, indent=2)
        target.write("\n")
    with open(temporary_path, encoding="utf-8") as check:
        json.load(check)
    os.replace(temporary_path, settings_path)
finally:
    if os.path.exists(temporary_path):
        os.unlink(temporary_path)
PY

  chmod 600 "$SETTINGS_FILE"
  unset api_key
  log "Claude Code configuration completed: $SETTINGS_FILE"
}

test_connection() {
  local base_url model api_key
  read -r -p 'APIQIK Base URL: ' base_url
  [[ -n "$base_url" ]] || fail 'Base URL cannot be empty.'
  base_url="$(normalize_base_url "$base_url")"
  read -r -p 'Test model name: ' model
  [[ -n "$model" ]] || fail 'Test model name cannot be empty.'
  read -r -s -p 'Enter the APIQIK API key: ' api_key
  printf '\n'
  [[ -n "$api_key" ]] || fail 'API key cannot be empty.'

  APIQIK_SETUP_KEY="$api_key" python3 - "$base_url" "$model" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

base_url, model = sys.argv[1:]
request = urllib.request.Request(
    f"{base_url}/v1/messages",
    data=json.dumps({
        "model": model,
        "max_tokens": 1,
        "messages": [{"role": "user", "content": "ping"}],
    }).encode(),
    headers={
        "Content-Type": "application/json",
        "anthropic-version": "2023-06-01",
        "x-api-key": os.environ["APIQIK_SETUP_KEY"],
    },
    method="POST",
)
try:
    with urllib.request.urlopen(request, timeout=30) as response:
        if not 200 <= response.status < 300:
            raise SystemExit(f"Gateway returned HTTP {response.status}")
except urllib.error.HTTPError as error:
    raise SystemExit(f"Gateway returned HTTP {error.code}; check the API key, model name, and quota")
except urllib.error.URLError as error:
    raise SystemExit(f"Unable to connect to the gateway: {error.reason}")
PY
  unset api_key
  log 'Connection test passed.'
}

restore_settings() {
  [[ -d "$BACKUP_DIR" ]] || fail 'No APIQIK configuration backup was found.'

  local latest
  latest="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'settings.json.*' -print | sort | tail -n 1)"
  [[ -n "$latest" ]] || fail 'No APIQIK configuration backup was found.'

  cp "$latest" "$SETTINGS_FILE"
  chmod 600 "$SETTINGS_FILE"
  log "Configuration restored: $latest"
}

configure() {
  local base_url model
  read -r -p 'APIQIK Base URL: ' base_url
  [[ -n "$base_url" ]] || fail 'Base URL cannot be empty.'
  base_url="$(normalize_base_url "$base_url")"

  read -r -p 'Model name (leave empty to keep the Claude Code default): ' model
  write_settings "$base_url" "$model"

  log 'Restart Claude Code, then run /status to check the Anthropic base URL and auth token.'
}

main() {
  require_python
  mkdir -p "$CLAUDE_DIR"

  while true; do
    printf '\nAPIQIK Claude Code configurator\n'
    printf '  1. Configure or update APIQIK\n'
    printf '  2. Test APIQIK connection\n'
    printf '  9. Restore the latest configuration backup\n'
    printf '  0. Exit\n\n'
    read -r -p 'Select an operation [1]: ' action
    action="${action:-1}"

    case "$action" in
      1) configure; return 0 ;;
      2) test_connection; return 0 ;;
      9) restore_settings; return 0 ;;
      0) return 0 ;;
      *) log 'Invalid option. Please try again.' ;;
    esac
  done
}

main "$@"