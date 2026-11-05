#!/usr/bin/env bash
set -Eeuo pipefail

# Claude Code 通过 settings.json 的 env 节点读取网关地址和凭证。
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/backup-apiqik"

log() {
  printf '[APIQIK] %s\n' "$1" >&2
}

fail() {
  printf '[APIQIK] 错误：%s\n' "$1" >&2
  exit 1
}

require_python() {
  command -v python3 >/dev/null 2>&1 || fail '需要 Python 3 来安全合并和校验 settings.json。'
}

normalize_base_url() {
  local value="$1"
  value="${value%/}"
  if [[ "$value" == */v1 ]]; then
    value="${value%/v1}"
    log '已移除 Base URL 末尾的 /v1，避免 Claude Code 请求路径重复。'
  fi
  [[ "$value" =~ ^https?://[^[:space:]]+$ ]] || fail 'Base URL 必须是 http:// 或 https:// 地址。'
  printf '%s' "$value"
}

backup_settings() {
  [[ -f "$SETTINGS_FILE" ]] || return 0

  local timestamp backup_file
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_file="$BACKUP_DIR/settings.json.$timestamp"
  mkdir -p "$BACKUP_DIR"
  cp "$SETTINGS_FILE" "$backup_file"
  log "已备份现有配置：$backup_file"
}

write_settings() {
  local base_url="$1"
  local model="$2"
  local api_key
  read -r -s -p '请输入 APIQIK API Key：' api_key
  printf '\n'
  [[ -n "$api_key" ]] || fail 'API Key 不能为空。'

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
    raise SystemExit("API Key 不能为空")

settings = {}
if os.path.exists(settings_path):
    with open(settings_path, encoding="utf-8") as source:
        settings = json.load(source)
if not isinstance(settings, dict):
    raise SystemExit("settings.json 顶层必须是 JSON 对象")

env = settings.get("env")
if env is None:
    env = {}
elif not isinstance(env, dict):
    raise SystemExit("settings.json 的 env 必须是 JSON 对象")

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
  log "Claude Code 配置完成：$SETTINGS_FILE"
}

test_connection() {
  local base_url model api_key
  read -r -p 'APIQIK Base URL：' base_url
  [[ -n "$base_url" ]] || fail 'Base URL 不能为空。'
  base_url="$(normalize_base_url "$base_url")"
  read -r -p '测试模型名：' model
  [[ -n "$model" ]] || fail '测试模型名不能为空。'
  read -r -s -p '请输入 APIQIK API Key：' api_key
  printf '\n'
  [[ -n "$api_key" ]] || fail 'API Key 不能为空。'

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
            raise SystemExit(f"网关返回 HTTP {response.status}")
except urllib.error.HTTPError as error:
    raise SystemExit(f"网关返回 HTTP {error.code}，请检查 API Key、模型名和额度")
except urllib.error.URLError as error:
    raise SystemExit(f"无法连接网关：{error.reason}")
PY
  unset api_key
  log '连接测试通过。'
}

restore_settings() {
  [[ -d "$BACKUP_DIR" ]] || fail '没有找到 APIQIK 配置备份。'

  local latest
  latest="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'settings.json.*' -print | sort | tail -n 1)"
  [[ -n "$latest" ]] || fail '没有找到 APIQIK 配置备份。'

  cp "$latest" "$SETTINGS_FILE"
  chmod 600 "$SETTINGS_FILE"
  log "已恢复配置：$latest"
}

configure() {
  local base_url model
  read -r -p 'APIQIK Base URL：' base_url
  [[ -n "$base_url" ]] || fail 'Base URL 不能为空。'
  base_url="$(normalize_base_url "$base_url")"

  read -r -p '模型名（可留空，保留 Claude Code 默认模型）：' model
  write_settings "$base_url" "$model"

  log '请重启 Claude Code，然后运行 /status 检查 Anthropic base URL 和 Auth token。'
}

main() {
  require_python
  mkdir -p "$CLAUDE_DIR"

  while true; do
    printf '\nAPIQIK Claude Code 配置器\n'
    printf '  1. 配置或更新 APIQIK\n'
    printf '  2. 测试 APIQIK 连接\n'
    printf '  9. 恢复最近一次配置备份\n'
    printf '  0. 退出\n\n'
    read -r -p '请选择操作 [1]：' action
    action="${action:-1}"

    case "$action" in
      1) configure; return 0 ;;
      2) test_connection; return 0 ;;
      9) restore_settings; return 0 ;;
      0) return 0 ;;
      *) log '无效选项，请重新选择。' ;;
    esac
  done
}

main "$@"