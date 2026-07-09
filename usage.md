# 使用 Pi

本页汇集了快速开始页面未涵盖的日常使用细节。

## 交互式模式

<p align="center"><img src="images/interactive-mode.png" alt="Interactive Mode" width="600"></p>

界面包含四个主要区域：

- **启动头部** — 快捷键、已加载的上下文文件、提示模板、技能和扩展
- **消息区** — 用户消息、助手回复、工具调用、工具结果、通知、错误及扩展 UI
- **编辑器** — 输入区域；边框颜色指示当前思考级别
- **底部栏** — 工作目录、会话名称、Token/缓存用量、费用、上下文用量及当前模型

编辑器可被内置 UI（如 `/settings`）或自定义扩展 UI 临时替换。

### 编辑器功能

| 功能 | 操作方式 |
|---------|-----|
| 文件引用 | 输入 `@` 可模糊搜索项目文件 |
| 路径补全 | 按 Tab 补全路径 |
| 多行输入 | Shift+Enter，或在 Windows Terminal 上使用 Ctrl+Enter |
| 图片 | 使用 Ctrl+V 粘贴，Windows 上为 Alt+V，或拖拽到终端中 |
| Shell 命令 | `!command` 运行并将输出发送给模型 |
| 隐藏 Shell 命令 | `!!command` 运行但不将输出发送给模型 |
| 外部编辑器 | Ctrl+G 打开 `externalEditor`、`$VISUAL`、`$EDITOR`、Windows 上的 Notepad，或其他的 `nano` |

所有快捷键和自定义方式请参阅 [Keybindings](keybindings.md)。

## 斜杠命令

在编辑器中输入 `/` 可打开命令补全。扩展可注册自定义命令，技能以 `/skill:name` 的形式可用，提示模板通过 `/templatename` 展开。

| 命令 | 说明 |
|---------|-------------|
| `/login`、`/logout` | 管理 OAuth 或 API 密钥凭证 |
| `/model` | 切换模型 |
| `/scoped-models` | 启用/禁用用于 Ctrl+P 循环的模型 |
| `/settings` | 思考级别、主题、消息投递、传输方式 |
| `/resume` | 从之前的会话中选择 |
| `/new` | 开始新会话 |
| `/name <name>` | 设置会话显示名称 |
| `/session` | 显示会话文件、ID、消息、Token 和费用 |
| `/tree` | 跳转到会话中的任意节点并从该处继续 |
| `/trust` | 保存项目信任决定以供后续会话使用 |
| `/fork` | 从之前的用户消息创建新会话 |
| `/clone` | 将当前活动分支复制到新会话 |
| `/compact [prompt]` | 手动压缩上下文，可附带自定义指令 |
| `/copy` | 将最后一条助手消息复制到剪贴板 |
| `/export [file]` | 将会话导出为 HTML 或 JSONL |
| `/import <file>` | 从 JSONL 文件导入并恢复会话 |
| `/share` | 上传为私有 GitHub gist 并生成可分享的 HTML 链接 |
| `/reload` | 重新加载键绑定、扩展、技能、提示和上下文文件 |
| `/hotkeys` | 显示所有键盘快捷键 |
| `/changelog` | 显示版本历史 |
| `/quit` | 退出 pi |

## 消息队列

你可以在代理仍在工作时提交消息：

- **Enter** 排队一条引导消息，在当前助手轮次完成工具调用执行后投递。
- **Alt+Enter** 排队一条跟进消息，在代理完成所有工作后投递。
- **Escape** 中止并将排队的消息恢复到编辑器。
- **Alt+Up** 将排队的消息取回编辑器。

在 Windows Terminal 上，Alt+Enter 默认为全屏。如需让 pi 接收该快捷键，请按照 [Terminal setup](terminal-setup.md) 中的说明重新映射。

可在 [Settings](settings.md) 中通过 `steeringMode` 和 `followUpMode` 配置投递方式。

## 会话

会话自动保存到 `~/.pi/agent/sessions/`，按工作目录组织。

```bash
pi -c                  # 继续最近的会话
pi -r                  # 浏览并选择会话
pi --no-session        # 临时模式；不保存
pi --name "my task"    # 启动时设置会话显示名称
pi --session <path|id> # 使用特定会话文件或部分 UUID
pi --fork <path|id>    # 将会话文件分叉为新会话
```

实用的会话命令：

- `/session` 显示当前会话文件和 ID。
- `/tree` 导航文件内的会话树，可汇总已放弃的分支。
- `/fork` 从更早的用户消息创建新会话。
- `/clone` 将当前活动分支复制到新会话文件。
- `/compact` 汇总旧消息以释放上下文。

详细说明请参阅 [Sessions](sessions.md) 和 [Compaction](compaction.md)。

## 上下文文件

Pi 在启动时从以下位置加载 `AGENTS.md` 或 `CLAUDE.md`：

- `~/.pi/agent/AGENTS.md` 用于全局指令
- 从当前工作目录向上遍历的父目录
- 当前目录

上下文文件用于定义项目规范、命令、安全规则和偏好。可通过 `--no-context-files` 或 `-nc` 禁用加载。

### 系统提示文件

使用以下文件替换默认系统提示：

- `.pi/SYSTEM.md` 用于项目级
- `~/.pi/agent/SYSTEM.md` 用于全局

使用 `APPEND_SYSTEM.md` 可在任一位置追加到默认提示而不替换它。

### 项目信任

在交互式启动时，如果项目文件夹包含项目本地设置、资源或项目 `.agents/skills`，且 `~/.pi/agent/trust.json` 中对该文件夹或父文件夹没有已保存的决定，pi 会在信任前询问。信任项目后，pi 可加载 `.pi/settings.json` 和 `.pi` 资源、安装缺失的项目包并执行项目扩展。

在信任决定之前，pi 仅加载上下文文件、用户/全局扩展和 CLI `-e` 扩展，以便它们能处理 `project_trust` 事件。项目本地扩展、项目包管理扩展和项目设置仅在项目被信任后加载。当切换到一个来自不同 cwd 且信任尚未在当前进程中解决的会话时，同样适用此拆分规则。

非交互式模式（`-p`、`--mode json` 和 `--mode rpc`）不显示信任提示。如果没有适用的已保存信任决定，它们使用全局设置中的 `defaultProjectTrust`：`ask`（默认）和 `never` 会忽略这些项目资源，而 `always` 会信任它们。传递 `--approve`/`-a` 或 `--no-approve`/`-na` 可为单次运行覆盖项目信任。

如果没有扩展或已保存的决定适用，`defaultProjectTrust` 控制回退行为。在 `~/.pi/agent/settings.json` 中将其设置为 `"ask"`、`"always"` 或 `"never"`，或通过 `/settings` 更改。

`pi config` 和包命令使用相同的项目信任流程，但 `pi update` 从不提示。传递 `--approve` 可为单次命令信任项目本地设置，或传递 `--no-approve` 忽略它们。

在交互式模式中使用 `/trust` 可为后续会话保存项目信任决定，包括对直接父文件夹的信任。它仅写入 `~/.pi/agent/trust.json`；当前会话不会重新加载，因此需重启 pi 才能使更改生效。

## 导出和分享会话

使用 `/export [file]` 将会话写入 HTML。

使用 `/share` 上传为私有 GitHub gist 并生成可分享的 HTML 链接。

如果你将 pi 用于开源工作，并希望发布会话用于模型、提示、工具和评估研究，请参阅 [`badlogic/pi-share-hf`](https://github.com/badlogic/pi-share-hf)。它将会话发布到 Hugging Face 数据集。

## CLI 参考

```bash
pi [options] [@files...] [messages...]
```

### 包命令

```bash
pi install <source> [-l]     # 安装包，-l 表示项目本地
pi remove <source> [-l]      # 移除包
pi uninstall <source> [-l]   # remove 的别名
pi update [source|self|pi]   # 仅更新 pi，或更新一个包源
pi update --all              # 更新 pi 和包；协调固定的 git ref
pi update --extensions       # 仅更新包；协调固定的 git ref
pi update --self             # 仅更新 pi
pi update --extension <src>  # 更新一个包
pi list                      # 列出已安装的包
pi config                    # 启用/禁用包资源
```

这些命令管理 pi 包，`pi update` 可更新 pi CLI 安装。要卸载 pi 本身，请参阅 [Quickstart](quickstart.md#uninstall)。`pi config` 和项目包命令接受 `--approve`/`--no-approve` 来为单次命令信任或忽略项目本地设置。`pi update` 从不提示项目信任。

包源和安全说明请参阅 [Pi Packages](packages.md)。

### 模式

| 标志 | 说明 |
|------|-------------|
| 默认 | 交互式模式 |
| `-p`、`--print` | 打印响应并退出 |
| `--mode json` | 将所有事件输出为 JSON 行；参见 [JSON mode](json.md) |
| `--mode rpc` | 通过 stdin/stdout 的 RPC 模式；参见 [RPC mode](rpc.md) |
| `--export <in> [out]` | 将会话导出为 HTML |

在打印模式下，pi 还会读取管道传入的 stdin 并将其合并到初始提示中：

```bash
cat README.md | pi -p "Summarize this text"
```

### 模型选项

| 选项 | 说明 |
|--------|-------------|
| `--provider <name>` | 提供商，如 `anthropic`、`openai` 或 `google` |
| `--model <pattern>` | 模型模式或 ID；支持 `provider/id` 和可选的 `:<thinking>` |
| `--api-key <key>` | API 密钥，覆盖环境变量 |
| `--thinking <level>` | `off`、`minimal`、`low`、`medium`、`high`、`xhigh` |
| `--models <patterns>` | 逗号分隔的模式，用于 Ctrl+P 循环 |
| `--list-models [search]` | 列出可用模型 |

### 会话选项

| 选项 | 说明 |
|--------|-------------|
| `-c`、`--continue` | 继续最近的会话 |
| `-r`、`--resume` | 浏览并选择会话 |
| `--session <path\|id>` | 使用特定会话文件或部分 UUID |
| `--fork <path\|id>` | 将会话文件或部分 UUID 分叉为新会话 |
| `--session-dir <dir>` | 自定义会话存储目录 |
| `--no-session` | 临时模式；不保存 |
| `--name <name>`、`-n <name>` | 启动时设置会话显示名称 |

### 工具选项

| 选项 | 说明 |
|--------|-------------|
| `--tools <list>`、`-t <list>` | 允许列表中的特定内置、扩展和自定义工具 |
| `--exclude-tools <list>`、`-xt <list>` | 禁用特定内置、扩展和自定义工具 |
| `--no-builtin-tools`、`-nbt` | 禁用内置工具但保持扩展/自定义工具启用 |
| `--no-tools`、`-nt` | 禁用所有工具 |

内置工具：`read`、`bash`、`edit`、`write`、`grep`、`find`、`ls`。

### 资源选项

| 选项 | 说明 |
|--------|-------------|
| `-e`、`--extension <source>` | 从路径、npm 或 git 加载扩展；可重复 |
| `--no-extensions` | 禁用扩展发现 |
| `--skill <path>` | 加载技能；可重复 |
| `--no-skills` | 禁用技能发现 |
| `--prompt-template <path>` | 加载提示模板；可重复 |
| `--no-prompt-templates` | 禁用提示模板发现 |
| `--theme <path>` | 加载主题；可重复 |
| `--no-themes` | 禁用主题发现 |
| `--no-context-files`、`-nc` | 禁用 `AGENTS.md` 和 `CLAUDE.md` 发现 |

将 `--no-*` 与显式标志结合使用，可精确加载所需内容，忽略设置。示例：

```bash
pi --no-extensions -e ./my-extension.ts
```

### 其他选项

| 选项 | 说明 |
|--------|-------------|
| `--system-prompt <text>` | 替换默认提示；上下文文件和技能仍会追加 |
| `--append-system-prompt <text>` | 追加到系统提示 |
| `--verbose` | 强制详细启动 |
| `-a`、`--approve` | 信任本次运行的项目本地文件 |
| `-na`、`--no-approve` | 忽略本次运行的项目本地文件 |
| `-h`、`--help` | 显示帮助 |
| `-v`、`--version` | 显示版本 |

### 文件参数

在文件前加 `@` 前缀以将其包含在消息中：

```bash
pi @prompt.md "Answer this"
pi -p @screenshot.png "What's in this image?"
pi @code.ts @test.ts "Review these files"
```

### 示例

```bash
# 带初始提示的交互式
pi "List all .ts files in src/"

# 非交互式
pi -p "Summarize this codebase"

# 带管道 stdin 的非交互式
cat README.md | pi -p "Summarize this text"

# 命名的一次性会话
pi --name "release audit" -p "Audit this repository"

# 不同模型
pi --provider openai --model gpt-4o "Help me refactor"

# 带提供商前缀的模型
pi --model openai/gpt-4o "Help me refactor"

# 带思考级别简写的模型
pi --model sonnet:high "Solve this complex problem"

# 限制模型循环
pi --models "claude-*,gpt-4o"

# 只读模式
pi --tools read,grep,find,ls -p "Review the code"

# 禁用一个扩展或内置工具，同时保持其余可用
pi --exclude-tools ask_question
```

### 环境变量

| 变量 | 说明 |
|----------|-------------|
| `PI_CODING_AGENT_DIR` | 覆盖配置目录；默认为 `~/.pi/agent` |
| `PI_CODING_AGENT_SESSION_DIR` | 覆盖会话存储目录；被 `--session-dir` 覆盖 |
| `PI_PACKAGE_DIR` | 覆盖包目录，对 Nix/Guix 存储路径有用 |
| `PI_OFFLINE` | 禁用启动时的网络操作，包括更新检查、包更新检查和安装/更新遥测 |
| `PI_SKIP_VERSION_CHECK` | 跳过启动时的 Pi 版本更新检查。这会阻止对 `pi.dev` 最新版本的请求 |
| `PI_TELEMETRY` | 覆盖安装/更新遥测和提供商归属头：`1`/`true`/`yes` 或 `0`/`false`/`no`。这不会禁用更新检查 |
| `PI_CACHE_RETENTION` | 设置为 `long` 以在支持的情况下延长提示缓存 |
| `VISUAL`、`EDITOR` | 当 `externalEditor` 未设置时，Ctrl+G 的备用外部编辑器；Windows 上默认为 Notepad，其他平台为 `nano` |

## 设计原则

Pi 保持核心精简，将工作流特定的行为推入扩展、技能、提示模板和包中。

它有意不内置 MCP、子代理、权限弹窗、计划模式、待办事项或后台 bash。你可以将这些工作流作为扩展或包构建或安装，也可以使用容器和 tmux 等外部工具。

完整的设计理念请参阅[博客文章](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/)。
