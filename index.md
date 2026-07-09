# Pi Documentation

Pi 是一款精简的终端编程外壳（harness）。其核心设计小巧精简，同时可通过 TypeScript 扩展、技能（Skills）、提示模板（Prompt templates）、主题（Themes）以及 pi 包进行功能扩展。

## 快速开始

使用 npm 安装 Pi：

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

`--ignore-scripts` 会在安装过程中禁用依赖包的生命周期脚本。对于常规的 npm 安装，Pi 并不依赖安装脚本即可完成安装。

在 Linux 或 macOS 上，也可以使用安装器：

```bash
curl -fsSL https://pi.dev/install.sh | sh
```

对于通过 curl 和 npm 安装的方式，可使用 npm 卸载 Pi：

```bash
npm uninstall -g @earendil-works/pi-coding-agent
```

对于 pnpm、Yarn 或 Bun 安装，请使用对应的全局移除命令：`pnpm remove -g @earendil-works/pi-coding-agent`、`yarn global remove @earendil-works/pi-coding-agent` 或 `bun uninstall -g @earendil-works/pi-coding-agent`。

然后在项目目录中运行：

```bash
pi
```

通过 `/login` 进行订阅提供商的认证，或在启动 pi 之前设置 API 密钥（如 `ANTHROPIC_API_KEY`）。

完整的首次运行流程，请参阅 [Quickstart](quickstart.md)。

## 从这里开始

- [Quickstart](quickstart.md) — 安装、认证并运行第一次会话。
- [使用 Pi](usage.md) — 交互式模式、斜杠命令、上下文文件及 CLI 参考。
- [Providers](providers.md) — 内置提供商的订阅与 API 密钥配置。
- [Security](security.md) — 项目信任、沙箱边界及漏洞报告。
- [Containerization](containerization.md) — 使用 Gondolin、Docker 或 OpenShell 对 pi 进行沙箱化。
- [Settings](settings.md) — 全局与项目设置。
- [Keybindings](keybindings.md) — 默认快捷键与自定义键绑定。
- [Sessions](sessions.md) — 会话管理、分支与树形导航。
- [Compaction](compaction.md) — 上下文压缩与分支摘要。

## 自定义

- [Extensions](extensions.md) — 用于工具、命令、事件和自定义 UI 的 TypeScript 模块。
- [Skills](skills.md) — 可按需复用的 Agent Skills。
- [Prompt templates](prompt-templates.md) — 可通过斜杠命令展开的可复用提示。
- [Themes](themes.md) — 内置与自定义终端主题。
- [Pi packages](packages.md) — 打包并分享扩展、技能、提示和主题。
- [Custom models](models.md) — 为受支持的提供商 API 添加模型条目。
- [Custom providers](custom-provider.md) — 实现自定义 API 与 OAuth 流程。

## 程序化使用

- [SDK](sdk.md) — 将 pi 嵌入 Node.js 应用程序。
- [RPC mode](rpc.md) — 通过 stdin/stdout JSONL 进行集成。
- [JSON event stream mode](json.md) — 带结构化事件的打印模式。
- [TUI components](tui.md) — 为扩展构建自定义终端 UI。

## 参考

- [Session format](session-format.md) — JSONL 会话文件格式、条目类型与 SessionManager API。

## 平台配置

- [Windows](windows.md)
- [Termux on Android](termux.md)
- [tmux](tmux.md)
- [Terminal setup](terminal-setup.md)
- [Shell aliases](shell-aliases.md)

## 开发

- [Development](development.md) — 本地配置、项目结构与调试。
