# APIQIK Claude Code Setup Scripts

These scripts configure the APIQIK Anthropic-compatible gateway for Claude Code.

## One-click installation

China endpoint:

```bash
(
  script_file="$(mktemp)" || exit 1
  trap 'rm -f "$script_file"' EXIT
  curl -fsSL --output "$script_file" \
    "https://raw.githubusercontent.com/yqwd-dimleap/scripts/main/install-claude-code-apiqik-cn.sh" &&
    bash "$script_file"
)
```

Global endpoint:

```bash
(
  script_file="$(mktemp)" || exit 1
  trap 'rm -f "$script_file"' EXIT
  curl -fsSL --output "$script_file" \
    "https://raw.githubusercontent.com/yqwd-dimleap/scripts/main/install-claude-code-apiqik-global.sh" &&
    bash "$script_file"
)
```

The command downloads the script before execution and returns a non-zero status if the download fails.

The China entry script uses Chinese prompts and the global entry script uses English prompts. Both entry scripts share the same configuration implementation.

The script prompts for an APIQIK Base URL and does not use a predefined service address.

Requests are sent to the `/v1/messages` path of the configured endpoint.

## Configuration flow

1. Select `1. Configure or update APIQIK`.
2. Enter the APIQIK Base URL.
3. Enter the model name; leave it empty to keep the Claude Code default model.
4. Enter the API key when prompted.
5. Restart Claude Code and run `/status` to verify the configuration.

The configuration file is `~/.claude/settings.json`. Existing files are backed up to
`~/.claude/backup-apiqik/`; the script only updates the `env` node and preserves other settings.

## Test environment

Enter the appropriate Base URL when testing a connection.

## Local usage

After cloning the repository, run either entry script directly. The entry scripts prefer the shared implementation in the same directory and do not require a network download:

```bash
./install-claude-code-apiqik-cn.sh
./install-claude-code-apiqik-global.sh
```

## Security notes

- The repository does not contain API keys, personal information, logs, configuration backups, or test credentials.
- API keys are read without echoing them and are never placed in URLs, command-line arguments, or logs.
- API keys are written only to the local `settings.json`, which is assigned `600` permissions.
- Test endpoints are entered interactively; the published scripts do not bind to an internal environment.