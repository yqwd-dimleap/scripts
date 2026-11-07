#!/usr/bin/env bash
set -Eeuo pipefail

# Claude Code reads the gateway URL and credentials from the env node in settings.json.
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/backup-apiqik"
LOCALE="en"

message() {
  local key="$1"
  shift || true

  case "$LOCALE:$key" in
    en:menu_title) printf 'Claude Code configurator' ;;
    zh-CN:menu_title) printf 'Claude Code 配置工具' ;;
    en:menu_config) printf '  1. Configure or update APIQIK' ;;
    zh-CN:menu_config) printf '  1. 配置或更新 Dimleap' ;;
    en:menu_test) printf '  2. Test APIQIK connection' ;;
    zh-CN:menu_test) printf '  2. 测试 Dimleap 连接' ;;
    en:menu_restore) printf '  9. Restore the latest configuration backup' ;;
    zh-CN:menu_restore) printf '  9. 恢复最近的配置备份' ;;
    en:menu_exit) printf '  0. Exit' ;;
    zh-CN:menu_exit) printf '  0. 退出' ;;
    en:operation_prompt) printf 'Select an operation [1]: ' ;;
    zh-CN:operation_prompt) printf '请选择操作 [1]：' ;;
    en:base_url_prompt) printf 'Base URL: ' ;;
    zh-CN:base_url_prompt) printf 'Base URL：' ;;
    en:model_prompt) printf 'Model name (leave empty to keep the Claude Code default): ' ;;
    zh-CN:model_prompt) printf '模型名称（留空以使用 Claude Code 默认模型）：' ;;
    en:test_model_prompt) printf 'Test model name: ' ;;
    zh-CN:test_model_prompt) printf '测试模型名称：' ;;
    en:api_key_prompt) printf 'Enter the API key: ' ;;
    zh-CN:api_key_prompt) printf '请输入 API key：' ;;
    en:python_required) printf 'Python 3 is required to safely merge and validate settings.json.' ;;
    zh-CN:python_required) printf '需要 Python 3 才能安全合并并校验 settings.json。' ;;
    en:base_url_empty) printf 'Base URL cannot be empty.' ;;
    zh-CN:base_url_empty) printf 'Base URL 不能为空。' ;;
    en:model_empty) printf 'Test model name cannot be empty.' ;;
    zh-CN:model_empty) printf '测试模型名称不能为空。' ;;
    en:api_key_empty) printf 'API key cannot be empty.' ;;
    zh-CN:api_key_empty) printf 'API key 不能为空。' ;;
    en:invalid_base_url) printf 'Base URL must use an http:// or https:// address.' ;;
    zh-CN:invalid_base_url) printf 'Base URL 必须使用 http:// 或 https:// 地址。' ;;
    en:removed_v1) printf 'Removed the trailing /v1 from the Base URL to avoid duplicating the request path.' ;;
    zh-CN:removed_v1) printf '已移除 Base URL 末尾的 /v1，以避免重复请求路径。' ;;
    en:backup) printf 'Backed up the existing configuration: %s' "$1" ;;
    zh-CN:backup) printf '已备份现有配置：%s' "$1" ;;
    en:config_completed) printf 'Claude Code configuration completed: %s' "$1" ;;
    zh-CN:config_completed) printf 'Claude Code 配置完成：%s' "$1" ;;
    en:restart) printf 'Restart Claude Code, then run /status to check the Anthropic base URL and auth token.' ;;
    zh-CN:restart) printf '请重启 Claude Code，然后运行 /status 检查 Anthropic Base URL 和认证令牌。' ;;
    en:connection_passed) printf 'Connection test passed.' ;;
    zh-CN:connection_passed) printf '连接测试通过。' ;;
    en:no_backup) printf 'No APIQIK configuration backup was found.' ;;
    zh-CN:no_backup) printf '未找到 Dimleap 配置备份。' ;;
    en:restore) printf 'Configuration restored: %s' "$1" ;;
    zh-CN:restore) printf '配置已恢复：%s' "$1" ;;
    en:invalid_option) printf 'Invalid option. Please try again.' ;;
    zh-CN:invalid_option) printf '选项无效，请重试。' ;;
    en:unknown_option) printf 'Unknown option: %s' "$1" ;;
    zh-CN:unknown_option) printf '未知选项：%s' "$1" ;;
    en:error_prefix) printf 'Error: ' ;;
    zh-CN:error_prefix) printf '错误：' ;;
    en:missing_locale) printf 'The --locale option requires a value.' ;;
    zh-CN:missing_locale) printf '--locale 选项需要一个语言值。' ;;
    en:unsupported_locale) printf 'Unsupported locale: %s' "$1" ;;
    zh-CN:unsupported_locale) printf '不支持的语言：%s' "$1" ;;
    *) printf '%s' "$key" ;;
  esac
}

product_name() {
  if [[ "$LOCALE" == zh-CN ]]; then
    printf 'Dimleap'
  else
    printf 'APIQIK'
  fi
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --locale)
        (($# >= 2)) || { printf '[%s] %s%s\n' "$(product_name)" "$(message error_prefix)" "$(message missing_locale)" >&2; exit 2; }
        LOCALE="$2"
        shift 2
        ;;
      --locale=*)
        LOCALE="${1#*=}"
        shift
        ;;
      *)
        printf '[%s] %s%s\n' "$(product_name)" "$(message error_prefix)" "$(message unknown_option "$1")" >&2
        exit 2
        ;;
    esac
  done

  case "$LOCALE" in
    en|zh-CN) ;;
    *) printf '[%s] %s%s\n' "$(product_name)" "$(message error_prefix)" "$(message unsupported_locale "$LOCALE")" >&2; exit 2 ;;
  esac
}
log() {
  local key="$1"
  shift || true
  printf '[%s] %s\n' "$(product_name)" "$(message "$key" "$@")" >&2
}

fail() {
  printf '[%s] %s%s\n' "$(product_name)" "$(message error_prefix)" "$(message "$1")" >&2
  exit 1
}

require_python() {
  command -v python3 >/dev/null 2>&1 || fail python_required
}

normalize_base_url() {
  local value="$1"
  value="${value%/}"
  if [[ "$value" == */v1 ]]; then
    value="${value%/v1}"
    log removed_v1
  fi
  [[ "$value" =~ ^https?://[^[:space:]]+$ ]] || fail invalid_base_url
  printf '%s' "$value"
}

backup_settings() {
  [[ -f "$SETTINGS_FILE" ]] || return 0

  local timestamp backup_file
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_file="$BACKUP_DIR/settings.json.$timestamp"
  mkdir -p "$BACKUP_DIR"
  cp "$SETTINGS_FILE" "$backup_file"
  log backup "$backup_file"
}

write_settings() {
  local base_url="$1"
  local model="$2"
  local api_key
  read -r -s -p "$(message api_key_prompt)" api_key
  printf '\n'
  [[ -n "$api_key" ]] || fail api_key_empty

  mkdir -p "$CLAUDE_DIR"
  chmod 700 "$CLAUDE_DIR"
  backup_settings

  APIQIK_SETUP_KEY="$api_key" python3 - "$SETTINGS_FILE" "$base_url" "$model" "$LOCALE" <<'PY'
import json
import os
import sys
import tempfile

settings_path, base_url, model, locale = sys.argv[1:]
api_key = os.environ.get("APIQIK_SETUP_KEY", "")
messages = {
    "en": {
        "api_key_empty": "API key cannot be empty",
        "settings_object": "settings.json must contain a top-level JSON object",
        "settings_env": "settings.json env must be a JSON object",
    },
    "zh-CN": {
        "api_key_empty": "API key 不能为空",
        "settings_object": "settings.json 顶层必须是 JSON 对象",
        "settings_env": "settings.json 的 env 必须是 JSON 对象",
    },
}

def fail(key):
    raise SystemExit(messages[locale][key])

if not api_key:
    fail("api_key_empty")

settings = {}
if os.path.exists(settings_path):
    with open(settings_path, encoding="utf-8") as source:
        settings = json.load(source)
if not isinstance(settings, dict):
    fail("settings_object")

env = settings.get("env")
if env is None:
    env = {}
elif not isinstance(env, dict):
    fail("settings_env")

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
  log config_completed "$SETTINGS_FILE"
}

test_connection() {
  local base_url model api_key
  read -r -p "$(message base_url_prompt)" base_url
  [[ -n "$base_url" ]] || fail base_url_empty
  base_url="$(normalize_base_url "$base_url")"
  read -r -p "$(message test_model_prompt)" model
  [[ -n "$model" ]] || fail model_empty
  read -r -s -p "$(message api_key_prompt)" api_key
  printf '\n'
  [[ -n "$api_key" ]] || fail api_key_empty

  APIQIK_SETUP_KEY="$api_key" python3 - "$base_url" "$model" "$LOCALE" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

base_url, model, locale = sys.argv[1:]
messages = {
    "en": {
        "status": "Gateway returned HTTP {status}",
        "http_error": "Gateway returned HTTP {status}; check the API key, model name, and quota",
        "url_error": "Unable to connect to the gateway: {reason}",
    },
    "zh-CN": {
        "status": "网关返回 HTTP {status}",
        "http_error": "网关返回 HTTP {status}；请检查 API key、模型名称和配额",
        "url_error": "无法连接到网关：{reason}",
    },
}

base_url = base_url.rstrip("/")
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
            raise SystemExit(messages[locale]["status"].format(status=response.status))
except urllib.error.HTTPError as error:
    raise SystemExit(messages[locale]["http_error"].format(status=error.code))
except urllib.error.URLError as error:
    raise SystemExit(messages[locale]["url_error"].format(reason=error.reason))
PY
  unset api_key
  log connection_passed
}

restore_settings() {
  [[ -d "$BACKUP_DIR" ]] || fail no_backup

  local latest
  latest="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'settings.json.*' -print | sort | tail -n 1)"
  [[ -n "$latest" ]] || fail no_backup

  cp "$latest" "$SETTINGS_FILE"
  chmod 600 "$SETTINGS_FILE"
  log restore "$latest"
}

configure() {
  local base_url model
  read -r -p "$(message base_url_prompt)" base_url
  [[ -n "$base_url" ]] || fail base_url_empty
  base_url="$(normalize_base_url "$base_url")"

  read -r -p "$(message model_prompt)" model
  write_settings "$base_url" "$model"

  log restart
}

main() {
  parse_args "$@"
  require_python
  mkdir -p "$CLAUDE_DIR"

  while true; do
    printf '\n%s\n' "$(message menu_title)"
    printf '%s\n' "$(message menu_config)"
    printf '%s\n' "$(message menu_test)"
    printf '%s\n' "$(message menu_restore)"
    printf '%s\n\n' "$(message menu_exit)"
    read -r -p "$(message operation_prompt)" action
    action="${action:-1}"

    case "$action" in
      1) configure; return 0 ;;
      2) test_connection; return 0 ;;
      9) restore_settings; return 0 ;;
      0) return 0 ;;
      *) log invalid_option ;;
    esac
  done
}

main "$@"
