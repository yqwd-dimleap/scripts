#!/usr/bin/env bash
set -Eeuo pipefail

SETUP_SCRIPT_URL="${APIQIK_SETUP_SCRIPT_URL:-https://raw.githubusercontent.com/your-org/your-repo/main/claude-code-apiqik-setup.sh}"

run_setup() {
  local script_dir=""
  if [[ "${BASH_SOURCE[0]}" != /dev/fd/* && "${BASH_SOURCE[0]}" != /proc/self/fd/* ]]; then
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  fi

  if [[ -n "$script_dir" && -f "$script_dir/claude-code-apiqik-setup.sh" ]]; then
    bash "$script_dir/claude-code-apiqik-setup.sh"
    return
  fi

  bash <(curl -fsSL "$SETUP_SCRIPT_URL")
}

run_setup "$@"
