#!/usr/bin/env bash
set -Eeuo pipefail

SETUP_SCRIPT_URL="${APIQIK_SETUP_SCRIPT_URL:-https://raw.githubusercontent.com/yqwd-dimleap/scripts/main/claude-code-apiqik-setup.sh}"

run_setup() {
  local script_dir=""
  if [[ "${BASH_SOURCE[0]}" != /dev/fd/* && "${BASH_SOURCE[0]}" != /proc/self/fd/* ]]; then
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  fi

  if [[ -n "$script_dir" && -f "$script_dir/claude-code-apiqik-setup.sh" ]]; then
    bash "$script_dir/claude-code-apiqik-setup.sh" --locale en
    return
  fi

  local temporary_script status
  temporary_script="$(mktemp "${TMPDIR:-/tmp}/apiqik-setup.XXXXXX")"
  if ! curl -fsSL --output "$temporary_script" "$SETUP_SCRIPT_URL"; then
    rm -f "$temporary_script"
    printf '[APIQIK] Error: failed to download the setup script: %s\n' "$SETUP_SCRIPT_URL" >&2
    return 1
  fi

  if bash "$temporary_script" --locale en; then
    status=0
  else
    status=$?
  fi
  rm -f "$temporary_script"
  return "$status"
}

run_setup "$@"
