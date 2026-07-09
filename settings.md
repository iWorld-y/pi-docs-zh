# Settings

Pi 使用 JSON 设置文件，项目设置会覆盖全局设置。

| 位置 | 作用域 |
|----------|-------|
| `~/.pi/agent/settings.json` | 全局（所有项目） |
| `.pi/settings.json` | 项目（当前目录） |

可直接编辑，或使用 `/settings` 设置常用选项。

## 项目信任

在交互式启动时，如果项目文件夹包含项目本地设置、资源或项目 `.agents/skills`，且 `~/.pi/agent/trust.json` 中对该文件夹或父文件夹没有已保存的决定，pi 会在信任前询问。信任项目后，pi 可加载 `.pi/settings.json` 和 `.pi` 资源、安装缺失的项目包并执行项目扩展。

非交互式模式（`-p`、`--mode json` 和 `--mode rpc`）不显示信任提示。如果没有适用的已保存信任决定，它们使用全局设置中的 `defaultProjectTrust`：`ask`（默认）和 `never` 会忽略这些项目资源，而 `always` 会信任它们。传递 `--approve`/`-a` 或 `--no-approve`/`-na` 可为单次运行覆盖项目信任。

如果没有扩展或已保存的决定适用，`defaultProjectTrust` 控制回退行为。在 `~/.pi/agent/settings.json` 中将其设置为 `"ask"`、`"always"` 或 `"never"`，或通过 `/settings` 更改。

`pi config` 和包命令使用相同的项目信任流程，但 `pi update` 从不提示。传递 `--approve` 可为单次命令信任项目本地设置，或传递 `--no-approve` 忽略它们。

在交互式模式中使用 `/trust` 可为后续会话保存项目信任决定，包括对直接父文件夹的信任。它仅写入 `~/.pi/agent/trust.json`；当前会话不会重新加载，因此需重启 pi 才能使更改生效。

## 全部设置

### 模型与思考

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `defaultProvider` | string | - | 默认提供商（如 `"anthropic"`、`"openai"`） |
| `defaultModel` | string | - | 默认模型 ID |
| `defaultThinkingLevel` | string | - | `"off"`、`"minimal"`、`"low"`、`"medium"`、`"high"`、`"xhigh"` |
| `hideThinkingBlock` | boolean | `false` | 在输出中隐藏思考块 |
| `thinkingBudgets` | object | - | 每个思考级别的自定义 Token 预算 |

#### thinkingBudgets

```json
{
  "thinkingBudgets": {
    "minimal": 1024,
    "low": 4096,
    "medium": 10240,
    "high": 32768
  }
}
```

### UI 与显示

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `theme` | string | `"dark"` | 主题名称（`"dark"`、`"light"` 或自定义） |
| `externalEditor` | string | `$VISUAL`，然后 `$EDITOR`，Windows 上为 Notepad，其他为 `nano` | Ctrl+G 外部编辑器的命令；优先级高于环境变量 |
| `quietStartup` | boolean | `false` | 隐藏启动头部 |
| `defaultProjectTrust` | string | `"ask"` | 回退项目信任行为：`"ask"`、`"always"` 或 `"never"`。仅限全局设置 |
| `collapseChangelog` | boolean | `false` | 更新后显示精简的变更日志 |
| `enableInstallTelemetry` | boolean | `true` | 在首次安装或变更日志检测到的更新后发送匿名安装/更新版本 ping。这不控制更新检查 |
| `enableAnalytics` | boolean | `false` | 选择加入分析数据共享。目前仅在实验性首次设置期间（`PI_EXPERIMENTAL=1`）询问 |
| `trackingId` | string | - | 分析跟踪标识符，在启用 `enableAnalytics` 时生成 |
| `doubleEscapeAction` | string | `"tree"` | 双击 Escape 操作：`"tree"`、`"fork"` 或 `"none"` |
| `treeFilterMode` | string | `"default"` | `/tree` 的默认过滤器：`"default"`、`"no-tools"`、`"user-only"`、`"labeled-only"`、`"all"` |
| `editorPaddingX` | number | `0` | 输入编辑器的水平内边距（0-3） |
| `outputPad` | number | `1` | 用户消息、助手消息和思考的水平内边距（0 或 1） |
| `autocompleteMaxVisible` | number | `5` | 自动完成下拉列表的最大可见项数（3-20） |
| `showHardwareCursor` | boolean | `false` | 在 TUI 为 IME 支持定位时显示终端光标 |

对于 VS Code，请包含 `--wait` 以便 pi 在编辑器退出后恢复：

```json
{
  "externalEditor": "code --wait"
}
```

### 遥测和更新检查

`enableInstallTelemetry` 仅控制向 `https://pi.dev/api/report-install` 发送的匿名安装/更新 ping。选择退出遥测不会禁用更新检查；Pi 仍可获取 `https://pi.dev/api/latest-version` 以查找最新版本。

设置 `PI_SKIP_VERSION_CHECK=1` 可禁用 Pi 版本更新检查。使用 `--offline` 或 `PI_OFFLINE=1` 可禁用此处描述的所有启动网络操作，包括更新检查、包更新检查和安装/更新遥测。

### 网络

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `httpProxy` | string | - | 作为 `HTTP_PROXY` 和 `HTTPS_PROXY` 应用的 HTTP 代理 URL。仅限全局设置 |

```json
{
  "httpProxy": "http://127.0.0.1:7890"
}
```

### 警告

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `warnings.anthropicExtraUsage` | boolean | `true` | 当 Anthropic 订阅认证可能使用付费额外用量时显示警告 |

```json
{
  "warnings": {
    "anthropicExtraUsage": false
  }
}
```

### 压缩

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `compaction.enabled` | boolean | `true` | 启用自动压缩 |
| `compaction.reserveTokens` | number | `16384` | 为 LLM 响应保留的 Token 数 |
| `compaction.keepRecentTokens` | number | `20000` | 保留的近期 Token 数（不进行摘要） |

```json
{
  "compaction": {
    "enabled": true,
    "reserveTokens": 16384,
    "keepRecentTokens": 20000
  }
}
```

### 分支摘要

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `branchSummary.reserveTokens` | number | `16384` | 为分支摘要保留的 Token 数 |
| `branchSummary.skipPrompt` | boolean | `false` | 在 `/tree` 导航时跳过 "Summarize branch?" 提示（默认为不摘要） |

### 重试

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `retry.enabled` | boolean | `true` | 启用瞬时错误时的自动代理级重试 |
| `retry.maxRetries` | number | `3` | 最大代理级重试次数 |
| `retry.baseDelayMs` | number | `2000` | 代理级指数退避的基础延迟（2s、4s、8s） |
| `retry.provider.timeoutMs` | number | SDK 默认值 | 提供商/SDK 请求超时时间（毫秒） |
| `retry.provider.maxRetries` | number | `0` | 提供商/SDK 重试次数 |
| `retry.provider.maxRetryDelayMs` | number | `60000` | 在失败前服务器请求的最大延迟（60s） |

当提供商请求的重试延迟超过 `retry.provider.maxRetryDelayMs`（例如 Google 的 "quota will reset after 5h"），请求会立即失败并返回信息丰富的错误，而不是静默等待。设置为 `0` 可禁用该上限。

除非明确需要提供商级重试，否则请将 `retry.provider.maxRetries` 保持为 `0`。将其设置为高于 `0` 的值可能使 SDK/提供商重试在 Pi 看到用量限制错误之前处理它们，这在某些情况下可能阻塞代理直到提供商配额重置。

```json
{
  "retry": {
    "enabled": true,
    "maxRetries": 3,
    "baseDelayMs": 2000,
    "provider": {
      "timeoutMs": 3600000,
      "maxRetries": 0,
      "maxRetryDelayMs": 60000
    }
  }
}
```

### 消息投递

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `steeringMode` | string | `"one-at-a-time"` | 引导消息的发送方式：`"all"` 或 `"one-at-a-time"` |
| `followUpMode` | string | `"one-at-a-time"` | 跟进消息的发送方式：`"all"` 或 `"one-at-a-time"` |
| `transport` | string | `"auto"` | 支持多种传输方式的提供商的首选传输方式：`"sse"`、`"websocket"`、`"websocket-cached"` 或 `"auto"` |
| `httpIdleTimeoutMs` | number | `300000` | HTTP 头部/主体空闲超时时间（毫秒），也用于具有明确流空闲超时的提供商。设置为 `0` 可禁用 |
| `websocketConnectTimeoutMs` | number | `15000` | 支持 WebSocket 传输的提供商的 WebSocket 连接/打开握手超时时间（毫秒）。设置为 `0` 可禁用 |

### 终端与图片

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `terminal.showImages` | boolean | `true` | 在终端中显示图片（如果支持） |
| `terminal.imageWidthCells` | number | `60` | 首选内联图片宽度（以终端单元格为单位） |
| `terminal.clearOnShrink` | boolean | `false` | 内容收缩时清除空行（可能导致闪烁） |
| `images.autoResize` | boolean | `true` | 将图片调整为最大 2000x2000 |
| `images.blockImages` | boolean | `false` | 阻止所有图片被发送到 LLM |

### Shell

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `shellPath` | string | - | 自定义 Shell 路径（例如 Windows 上用于 Cygwin） |
| `shellCommandPrefix` | string | - | 每个 bash 命令的前缀（例如 `"shopt -s expand_aliases"`） |
| `npmCommand` | string[] | - | 用于 npm 包查找/安装操作的命令 argv（例如 `["mise", "exec", "node@20", "--", "npm"]`） |

```json
{
  "npmCommand": ["mise", "exec", "node@20", "--", "npm"]
}
```

`npmCommand` 用于所有 npm 包管理器操作，包括安装、卸载以及 git 包内的依赖安装。用户范围的 npm 包安装在 `~/.pi/agent/npm/` 下；项目范围的 npm 包安装在 `.pi/npm/` 下。按照进程应启动的方式精确使用 argv 风格的条目。当配置了 `npmCommand` 时，git 包依赖安装使用普通的 `install`，以避免在包装器或替代包管理器中使用 npm 特定标志。

### 会话

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `sessionDir` | string | - | 会话文件存储目录。接受绝对路径或相对路径，以及 `~`。 |

```json
{ "sessionDir": ".pi/sessions" }
```

当多个来源指定会话目录时，优先级为 `--session-dir`、`PI_CODING_AGENT_SESSION_DIR`，然后是 settings.json 中的 `sessionDir`。

### 模型循环

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `enabledModels` | string[] | - | 用于 Ctrl+P 循环的模型模式（与 `--models` CLI 标志格式相同） |

```json
{
  "enabledModels": ["claude-*", "gpt-4o", "gemini-2*"]
}
```

### Markdown

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `markdown.codeBlockIndent` | string | `"  "` | 代码块的缩进 |

### 资源

这些设置定义从何处加载扩展、技能、提示和主题。

`~/.pi/agent/settings.json` 中的路径相对于 `~/.pi/agent` 解析。`.pi/settings.json` 中的路径相对于 `.pi` 解析。支持绝对路径和 `~`。

| 设置 | 类型 | 默认值 | 说明 |
|---------|------|---------|-------------|
| `packages` | array | `[]` | 要从中加载资源的 npm/git 包 |
| `extensions` | string[] | `[]` | 本地扩展文件路径或目录 |
| `skills` | string[] | `[]` | 本地技能文件路径或目录 |
| `prompts` | string[] | `[]` | 本地提示模板路径或目录 |
| `themes` | string[] | `[]` | 本地主题文件路径或目录 |
| `enableSkillCommands` | boolean | `true` | 将技能注册为 `/skill:name` 命令 |

数组支持 glob 模式和排除。使用 `!pattern` 排除。使用 `+path` 强制包含精确路径，`-path` 强制排除精确路径。

#### packages

字符串形式从包中加载所有资源：

```json
{
  "packages": ["pi-skills", "@org/my-extension"]
}
```

对象形式过滤要加载的资源：

```json
{
  "packages": [
    {
      "source": "pi-skills",
      "skills": ["brave-search", "transcribe"],
      "extensions": []
    }
  ]
}
```

包管理详情请参见 [packages.md](packages.md)。

## 示例

```json
{
  "defaultProvider": "anthropic",
  "defaultModel": "claude-sonnet-4-20250514",
  "defaultThinkingLevel": "medium",
  "theme": "dark",
  "compaction": {
    "enabled": true,
    "reserveTokens": 16384,
    "keepRecentTokens": 20000
  },
  "retry": {
    "enabled": true,
    "maxRetries": 3
  },
  "enabledModels": ["claude-*", "gpt-4o"],
  "warnings": {
    "anthropicExtraUsage": true
  },
  "packages": ["pi-skills"]
}
```

## 项目覆盖

项目设置（`.pi/settings.json`）覆盖全局设置。嵌套对象会合并：

```json
// ~/.pi/agent/settings.json (全局)
{
  "theme": "dark",
  "compaction": { "enabled": true, "reserveTokens": 16384 }
}

// .pi/settings.json (项目)
{
  "compaction": { "reserveTokens": 8192 }
}

// 结果
{
  "theme": "dark",
  "compaction": { "enabled": true, "reserveTokens": 8192 }
}
```
