# Quickstart

本页将带你从安装过渡到第一次可用的 pi 会话。

## 安装

Pi 以 npm 包的形式发布：

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

`--ignore-scripts` 会在安装过程中禁用依赖包的生命周期脚本。对于常规的 npm 安装，Pi 并不依赖安装脚本即可完成安装。

### 卸载

使用安装 pi 时所用的包管理器进行卸载。curl 安装器使用 npm 全局安装，因此通过 curl 和 npm 安装的方式均使用 npm 卸载：

```bash
# curl installer 或 npm install -g
npm uninstall -g @earendil-works/pi-coding-agent

# pnpm
pnpm remove -g @earendil-works/pi-coding-agent

# Yarn
yarn global remove @earendil-works/pi-coding-agent

# Bun
bun uninstall -g @earendil-works/pi-coding-agent
```

卸载 pi 后，设置、凭证、已安装的 pi 包和会话仍保留在 `~/.pi/agent/` 目录中。

然后在你要操作的项目目录中启动 pi：

```bash
cd /path/to/project
pi
```

## 认证

Pi 可通过 `/login` 使用订阅提供商，也可通过环境变量或认证文件使用 API 密钥提供商。

### 选项 1：订阅登录

启动 pi 并运行：

```text
/login
```

然后选择一个提供商。内置的订阅登录包括 Claude Pro/Max、ChatGPT Plus/Pro (Codex) 和 GitHub Copilot。

### 选项 2：API 密钥

在启动 pi 之前设置 API 密钥：

```bash
export ANTHROPIC_API_KEY=sk-ant-...
pi
```

你也可以运行 `/login` 并选择一个 API 密钥提供商，将密钥存储在 `~/.pi/agent/auth.json` 中。

所有受支持的环境变量、提供商及云平台配置请参阅 [Providers](providers.md)。

## 第一次会话

pi 启动后，输入请求并按回车：

```text
Summarize this repository and tell me how to run its checks.
```

默认情况下，pi 为模型提供四个工具：

- `read` — 读取文件
- `write` — 创建或覆盖文件
- `edit` — 修补文件
- `bash` — 运行 Shell 命令

额外的内置只读工具（`grep`、`find`、`ls`）通过工具选项可用。Pi 在当前工作目录中运行，可修改该目录中的文件。如果希望便于回滚，可使用 git 或其他检查点工作流。

## 给 pi 指定项目指令

Pi 在启动时加载上下文文件。添加一个 `AGENTS.md` 文件来告知 pi 如何在该项目中工作：

```markdown
# Project Instructions

- Run `npm run check` after code changes.
- Do not run production migrations locally.
- Keep responses concise.
```

Pi 会加载：

- `~/.pi/agent/AGENTS.md` 用于全局指令
- 父目录和当前目录中的 `AGENTS.md` 或 `CLAUDE.md`

修改上下文文件后，请重新启动 pi 或运行 `/reload`。

## 常用操作尝试

### 引用文件

在编辑器中输入 `@` 可进行文件模糊搜索，或在命令行传入文件：

```bash
pi @README.md "Summarize this"
pi @src/app.ts @src/app.test.ts "Review these together"
```

图片可通过 Ctrl+V（Windows 上为 Alt+V）粘贴，或拖拽到支持的终端中。

### 运行 Shell 命令

在交互式模式下：

```text
!npm run lint
```

命令输出会被发送给模型。使用 `!!command` 可运行命令但不将输出添加到模型上下文中。

### 切换模型

使用 `/model` 或 Ctrl+L 选择模型。使用 Shift+Tab 循环切换思考级别。使用 Ctrl+P / Shift+Ctrl+P 循环切换限定范围的模型。

### 稍后继续

会话会自动保存：

```bash
pi -c                  # 继续最近的会话
pi -r                  # 浏览之前的会话
pi --name "my task"    # 启动时设置会话显示名称
pi --session <path|id> # 打开特定会话
```

在 pi 内部，可使用 `/resume`、`/new`、`/tree`、`/fork` 和 `/clone` 来管理会话。

### 非交互式模式

针对一次性提示：

```bash
pi -p "Summarize this codebase"
cat README.md | pi -p "Summarize this text"
pi -p @screenshot.png "What's in this image?"
```

使用 `--mode json` 可输出 JSON 事件流，使用 `--mode rpc` 可进行进程集成。

## 下一步

- [使用 Pi](usage.md) — 交互式模式、斜杠命令、会话、上下文文件及 CLI 参考。
- [Providers](providers.md) — 认证与模型配置。
- [Settings](settings.md) — 全局与项目配置。
- [Keybindings](keybindings.md) — 快捷键与自定义。
- [Pi Packages](packages.md) — 安装共享的扩展、技能、提示和主题。

平台说明请参阅：[Windows](windows.md)、[Termux](termux.md)、[tmux](tmux.md)、[Terminal setup](terminal-setup.md)、[Shell aliases](shell-aliases.md)。
