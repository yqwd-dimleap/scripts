# APIQIK Claude Code 安装脚本

这组脚本用于为 Claude Code 配置 APIQIK Anthropic 兼容网关。

## 一键运行

国内站：

```bash
(
  script_file="$(mktemp)" || exit 1
  trap 'rm -f "$script_file"' EXIT
  curl -fsSL --output "$script_file" \
    "https://raw.githubusercontent.com/yqwd-dimleap/scripts/main/install-claude-code-apiqik-cn.sh" &&
    bash "$script_file"
)
```

海外站：

```bash
(
  script_file="$(mktemp)" || exit 1
  trap 'rm -f "$script_file"' EXIT
  curl -fsSL --output "$script_file" \
    "https://raw.githubusercontent.com/yqwd-dimleap/scripts/main/install-claude-code-apiqik-global.sh" &&
    bash "$script_file"
)
```

命令会先下载脚本，确认下载成功后才执行；下载失败时会返回非零状态。

脚本会要求用户填写 APIQIK Base URL，不再预设服务地址。

脚本会自动将请求发送到对应地址的 `/v1/messages`。

## 配置流程

1. 选择 `1. 配置或更新 APIQIK`。
2. 输入 APIQIK Base URL。
3. 输入模型名；留空则保留 Claude Code 默认模型。
4. 交互式输入 API Key。
5. 重启 Claude Code 后执行 `/status` 检查配置。

配置文件为 `~/.claude/settings.json`。已有文件会先备份到
`~/.claude/backup-apiqik/`，脚本只修改 `env` 节点，不覆盖其他配置。

## 测试环境

测试连接时同样需要在交互提示中填写对应的 Base URL。

## 本地运行

克隆仓库后，可以直接运行任一入口脚本。入口脚本会优先调用同目录下的共享实现，不依赖网络下载：

```bash
./install-claude-code-apiqik-cn.sh
./install-claude-code-apiqik-global.sh
```

## 安全说明

- 仓库不包含 API Key、个人身份信息、日志、配置备份或测试凭证。
- API Key 只通过隐藏输入读取，不放入 URL、命令行参数或日志。
- API Key 仅写入本机 `settings.json`，文件权限设置为 `600`。
- 测试地址由用户交互输入，发布脚本不绑定内部环境。