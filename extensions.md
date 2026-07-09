> pi 可以创建扩展。让它为你的使用场景构建一个。

# 扩展

扩展（Extensions）是用 TypeScript 模块来增强 pi 行为的方式。它们可以订阅生命周期事件、注册 LLM 可调用的自定义工具、添加命令等。

> **/reload 的放置位置：** 将扩展放在 `~/.pi/agent/extensions/`（全局）或 `.pi/extensions/`（项目本地）以实现自动发现。仅在快速测试时使用 `pi -e ./path.ts`。自动发现位置的扩展可以通过 `/reload` 热重载。

**核心能力：**
- **自定义工具** - 通过 `pi.registerTool()` 注册 LLM 可调用的工具
- **事件拦截** - 阻止或修改工具调用、注入上下文、自定义压缩（compaction）
- **用户交互** - 通过 `ctx.ui` 提示用户（选择、确认、输入、通知）
- **自定义 UI 组件** - 通过 `ctx.ui.custom()` 使用键盘输入实现完整的 TUI 组件，用于复杂交互
- **自定义命令** - 通过 `pi.registerCommand()` 注册 `/mycommand` 等命令
- **会话持久化** - 通过 `pi.appendEntry()` 存储重启后仍保留的状态
- **自定义渲染** - 控制工具调用/结果和消息在 TUI 中的显示方式

**示例使用场景：**
- 权限门控（在执行 `rm -rf`、`sudo` 等前确认）
- Git 检查点（每轮 stash，切分支时恢复）
- 路径保护（阻止写入 `.env`、`node_modules/`）
- 自定义压缩（按你的方式总结对话）
- 对话摘要（参见 `summarize.ts` 示例）
- 交互式工具（提问、向导、自定义对话框）
- 有状态工具（待办列表、连接池）
- 外部集成（文件监听、webhook、CI 触发）
- 等待时玩游戏（参见 `snake.ts` 示例）

参见 [examples/extensions/](../examples/extensions/) 获取可运行的实现。

## 目录

- [快速开始](#quick-start)
- [扩展位置](#extension-locations)
- [可用导入](#available-imports)
- [编写扩展](#writing-an-extension)
  - [扩展风格](#extension-styles)
- [事件](#events)
  - [生命周期概览](#lifecycle-overview)
  - [资源事件](#resource-events)
  - [会话事件](#session-events)
  - [Agent 事件](#agent-events)
  - [模型事件](#model-events)
  - [工具事件](#tool-events)
- [ExtensionContext](#extensioncontext)
- [ExtensionCommandContext](#extensioncommandcontext)
- [ExtensionAPI 方法](#extensionapi-methods)
- [状态管理](#state-management)
- [自定义工具](#custom-tools)
- [自定义 UI](#custom-ui)
- [错误处理](#error-handling)
- [模式行为](#mode-behavior)
- [示例参考](#examples-reference)

## 快速开始

创建 `~/.pi/agent/extensions/my-extension.ts`：

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI) {
  // 响应事件
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.notify("扩展已加载!", "info");
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName === "bash" && event.input.command?.includes("rm -rf")) {
      const ok = await ctx.ui.confirm("危险!", "允许 rm -rf?");
      if (!ok) return { block: true, reason: "被用户阻止" };
    }
  });

  // 注册自定义工具
  pi.registerTool({
    name: "greet",
    label: "Greet",
    description: "按名称打招呼",
    parameters: Type.Object({
      name: Type.String({ description: "要打招呼的名称" }),
    }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      return {
        content: [{ type: "text", text: `你好, ${params.name}!` }],
        details: {},
      };
    },
  });

  // 注册命令
  pi.registerCommand("hello", {
    description: "打招呼",
    handler: async (args, ctx) => {
      ctx.ui.notify(`Hello ${args || "world"}!`, "info");
    },
  });
}
```

使用 `--extension` (或 `-e`) 标志进行测试：

```bash
pi -e ./my-extension.ts
```

## 扩展位置

> **安全性：** 扩展以你的完整系统权限运行，可以执行任意代码。只安装你信任的来源。

扩展从受信任的位置自动发现。项目本地的 `.pi/extensions` 条目仅在项目被信任后才加载。

| 位置 | 作用域 |
|----------|-------|
| `~/.pi/agent/extensions/*.ts` | 全局（所有项目） |
| `~/.pi/agent/extensions/*/index.ts` | 全局（子目录） |
| `.pi/extensions/*.ts` | 项目本地 |
| `.pi/extensions/*/index.ts` | 项目本地（子目录） |

通过 `settings.json` 添加额外路径：

```json
{
  "packages": [
    "npm:@foo/bar@1.0.0",
    "git:github.com/user/repo@v1"
  ],
  "extensions": [
    "/path/to/local/extension.ts",
    "/path/to/local/extension/dir"
  ]
}
```

要通过 npm 或 git 作为 pi 包共享扩展，参见 [packages.md](packages.md)。

## 可用导入

| 包 | 目的 |
|---------|---------|
| `@earendil-works/pi-coding-agent` | 扩展类型（`ExtensionAPI`、`ExtensionContext`、events） |
| `typebox` | 工具参数的 schema 定义 |
| `@earendil-works/pi-ai` | AI 工具（`StringEnum` 用于 Google 兼容的枚举） |
| `@earendil-works/pi-tui` | 自定义渲染的 TUI 组件 |

npm 依赖包同样可用。在扩展旁边（或父目录中）添加 `package.json`，运行 `npm install`，即可自动解析 `node_modules/` 中的导入。

对于通过 `pi install`（npm 或 git）安装的 pi 包，运行时依赖必须放在 `dependencies` 中。包安装默认使用生产安装（`npm install --omit=dev`），因此 `dependencies`在运行时不可用；当配置了 `npmCommand` 时，git 包使用普通 `install` 以保持与封装器的兼容性。

Node.js 内置模块（`node:fs`、`node:path` 等）同样可用。

## 编写扩展

扩展导出一个默认的工厂函数，该函数接收 `ExtensionAPI`。工厂可以是同步的也可以是异步的：

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // 订阅事件
  pi.on("event_name", async (event, ctx) => {
    // ctx.ui 用于用户交互
    const ok = await ctx.ui.confirm("标题", "确定吗?");
    ctx.ui.notify("完成!", "info");
    ctx.ui.setStatus("my-ext", "处理中...");  // 底部状态栏
    ctx.ui.setWidget("my-ext", ["第1行", "第2行"]);  // 编辑器上方的小部件（默认）
  });

  // 注册工具、命令、快捷键、标志
  pi.registerTool({ ... });
  pi.registerCommand("name", { ... });
  pi.registerShortcut("ctrl+x", { ... });
  pi.registerFlag("my-flag", { ... });
}
```

扩展通过 [jiti](https://github.com/unjs/jiti) 加载，因此 TypeScript 无需编译即可使用。

如果工厂返回 `Promise`，pi 会在继续启动前等待它完成。这意味着异步初始化在 `session_start`、`resources_discover` 和通过 `pi.registerProvider()` 排队的注册操作被刷新之前完成。

### 异步工厂函数

对于一次性启动工作（如获取远程配置或动态发现可用模型）使用异步工厂。

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default async function (pi: ExtensionAPI) {
  const response = await fetch("http://localhost:1234/v1/models");
  const payload = (await response.json()) as {
    data: Array<{
      id: string;
      name?: string;
      context_window?: number;
      max_tokens?: number;
    }>;
  };

  pi.registerProvider("local-openai", {
    baseUrl: "http://localhost:1234/v1",
    apiKey: "$LOCAL_OPENAI_API_KEY",
    api: "openai-completions",
    models: payload.data.map((model) => ({
      id: model.id,
      name: model.name ?? model.id,
      reasoning: false,
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: model.context_window ?? 128000,
      maxTokens: model.max_tokens ?? 4096,
    })),
  });
}
```

此模式使得抓取的模型在正常启动和 `pi --list-models` 期间都可用。

### 长期运行的资源和与关闭处理

扩展工厂可能在永不启动会话的调用中运行。不要在工厂中启动后台资源如进程、套接字、文件监听器或计时器。

将后台资源启动推迟到 `session_start` 或需要该资源的命令/工具/事件。注册一个幂等的 `session_shutdown` 处理器来关闭你启动的任何会话范围资源。

### 扩展风格

**单文件** - 最简单的，适合小型扩展：

```
~/.pi/agent/extensions/
└── my-extension.ts
```

**带有 index.ts 的目录** - 用于多文件扩展：

```
~/.pi/agent/extensions/
└── my-extension/
    ├── index.ts        # Entry point (exports default function)
    ├── tools.ts        # Helper module
    └── utils.ts        # Helper module
```

**带依赖的包** - 用于需要 npm 包的扩展：

```
~/.pi/agent/extensions/
└── my-extension/
    ├── package.json    # Declares dependencies and entry points
    ├── package-lock.json
    ├── node_modules/   # After npm install
    └── src/
        └── index.ts
```

```json
// package.json
{
  "name": "my-extension",
  "dependencies": {
    "zod": "^3.0.0",
    "chalk": "^5.0.0"
  },
  "pi": {
    "extensions": ["./src/index.ts"]
  }
}
```

在扩展目录中运行 `npm install`，然后 `node_modules/` 中的导入就能自动工作。

## 事件

### 生命周期概览

```
pi starts
  │
  ├─► project_trust (user/global and CLI extensions only, before project resources load)
  ├─► session_start { reason: "startup" }
  └─► resources_discover { reason: "startup" }
      │
      ▼
user sends prompt ─────────────────────────────────────────┐
  │                                                        │
  ├─► (extension commands checked first, bypass if found)  │
  ├─► input (can intercept, transform, or handle)          │
  ├─► (skill/template expansion if not handled)            │
  ├─► before_agent_start (can inject message, modify system prompt)
  ├─► agent_start                                          │
  ├─► message_start / message_update / message_end         │
  │                                                        │
  │   ┌─── turn (repeats while LLM calls tools) ───┐       │
  │   │                                            │       │
  │   ├─► turn_start                               │       │
  │   ├─► context (can modify messages)            │       │
  │   ├─► before_provider_headers (can mutate headers)     |
  │   ├─► before_provider_request (can inspect or replace payload)
  │   ├─► after_provider_response (status + headers, before stream consume)
  │   │                                            │       │
  │   │   LLM responds, may call tools:            │       │
  │   │     ├─► tool_execution_start               │       │
  │   │     ├─► tool_call (can block)              │       │
  │   │     ├─► tool_execution_update              │       │
  │   │     ├─► tool_result (can modify)           │       │
  │   │     └─► tool_execution_end                 │       │
  │   │                                            │       │
  │   └─► turn_end                                 │       │
  │                                                        │
  └─► agent_end                                            │
                                                           │
user sends another prompt ◄────────────────────────────────┘

/new (new session) or /resume (switch session)
  ├─► session_before_switch (can cancel)
  ├─► session_shutdown
  ├─► session_start { reason: "new" | "resume", previousSessionFile? }
  └─► resources_discover { reason: "startup" }

/fork or /clone
  ├─► session_before_fork (can cancel)
  ├─► session_shutdown
  ├─► session_start { reason: "fork", previousSessionFile }
  └─► resources_discover { reason: "startup" }

/name or pi.setSessionName()
  └─► session_info_changed

/compact or auto-compaction
  ├─► session_before_compact (can cancel or customize)
  └─► session_compact

/tree navigation
  ├─► session_before_tree (can cancel or customize)
  └─► session_tree

/model or Ctrl+P (model selection/cycling)
  ├─► thinking_level_select (if model change changes/clamps thinking level)
  └─► model_select

thinking level changes (settings, keybinding, pi.setThinkingLevel())
  └─► thinking_level_select

exit (Ctrl+C, Ctrl+D, SIGHUP, SIGTERM)
  └─► session_shutdown
```

### 启动事件

#### project_trust

在 pi 决定是否信任具有动态配置（`.pi` 或 `.agents/skills`）的项目之前触发。它在启动时以及会话替换（例如 `/resume`）进入一个在当前进程中尚未解析信任的 cwd 时运行。只有用户/全局扩展和 CLI `-e` 扩展参与；项目本地扩展在信任解析完成之前不会被加载。

```typescript
pi.on("project_trust", async (event, ctx) => {
  // event.cwd - current working directory
  // ctx has a limited trust context: cwd, mode, hasUI, and select/confirm/input/notify UI helpers
  if (await ctx.ui.confirm("Trust project?", event.cwd)) {
    return { trusted: "yes", remember: true };
  }
  return { trusted: "undecided" };
});
```

`project_trust` 处理器必须返回 `{ trusted: "yes" | "no" | "undecided" }`。返回 `"yes"` 或 `"no"` 的用户/全局或 CLI 扩展拥有该决策权；第一个是/否决定获胜并抑制内置的信任提示。使用 `remember: true` 以持久化是/否决定；否则它仅适用于当前进程。返回 `"undecided"` 让后续处理器或内置的信任流程决定。在提示前检查 `ctx.hasUI`。如果没有处理器返回是/否，则正常的信任解析继续：首先应用保存的 `trust.json` 决定，然后 `defaultProjectTrust` 控制 pi 的默认行为是询问、信任还是拒绝。

### 资源事件

#### resources_discover

在 `session_start` 之后触发，使扩展可以贡献额外的 skill、prompt 和 theme 路径。
启动路径使用 `reason: "startup"`。重载使用 `reason: "reload"`。

```typescript
pi.on("resources_discover", async (event, _ctx) => {
  // event.cwd - current working directory
  // event.reason - "startup" | "reload"
  return {
    skillPaths: ["/path/to/skills"],
    promptPaths: ["/path/to/prompts"],
    themePaths: ["/path/to/themes"],
  };
});
```

### 会话事件

参见 [Session Format](session-format.md) 了解会话存储内部结构和 SessionManager API。

#### session_start

当会话启动、加载或重载时触发。

```typescript
pi.on("session_start", async (event, ctx) => {
  // event.reason - "startup" | "reload" | "new" | "resume" | "fork"
  // event.previousSessionFile - present for "new", "resume", and "fork"
  ctx.ui.notify(`Session: ${ctx.sessionManager.getSessionFile() ?? "ephemeral"}`, "info");
});
```

#### session_info_changed

当通过 `/name`、RPC 或 `pi.setSessionName()` 设置当前会话显示名称时触发。

```typescript
pi.on("session_info_changed", async (event, ctx) => {
  // event.name - current normalized name, or undefined if cleared
  ctx.ui.notify(`Session renamed: ${event.name ?? "(none)"}`, "info");
});
```

#### session_before_switch

在启动新会话（`/new`）或切换会话（`/resume`）之前触发。

```typescript
pi.on("session_before_switch", async (event, ctx) => {
  // event.reason - "new" or "resume"
  // event.targetSessionFile - session we're switching to (only for "resume")

  if (event.reason === "new") {
    const ok = await ctx.ui.confirm("Clear?", "Delete all messages?");
    if (!ok) return { cancel: true };
  }
});
```

切换或新建操作成功后，pi 向下会话扩展实例发送 `session_shutdown`，重新加载并绑定新会话的扩展，然后以 `reason: "new" | "resume"` 和 `previousSessionFile` 发出 `session_start`。
在 `session_shutdown` 中做清理工作，然后在 `session_start` 中重新建立任何内存状态。

#### session_before_fork

当通过 `/fork` 分叉或 `/clone` 克隆时触发。

```typescript
pi.on("session_before_fork", async (event, ctx) => {
  // event.entryId - ID of the selected entry
  // event.position - "before" for /fork, "at" for /clone
  return { cancel: true }; // Cancel fork/clone
  // OR
  return { skipConversationRestore: true }; // Reserved for future conversation restore control
});
```

分叉或克隆成功后，pi 向下会话扩展实例发送 `session_shutdown`，重新加载并绑定新会话的扩展，然后以 `reason: "fork"` 和 `previousSessionFile` 发出 `session_start`。
在 `session_shutdown` 中做清理工作，然后在 `session_start` 中重新建立任何内存状态。

#### session_before_compact / session_compact

压缩时触发。详见 [compaction.md](compaction.md)。

```typescript
pi.on("session_before_compact", async (event, ctx) => {
  const { preparation, branchEntries, customInstructions, reason, willRetry, signal } = event;

  // reason - "manual" (/compact), "threshold", or "overflow"
  // willRetry - whether the aborted turn is retried after compaction (overflow recovery)

  // Cancel:
  return { cancel: true };

  // Custom summary:
  return {
    compaction: {
      summary: "...",
      firstKeptEntryId: preparation.firstKeptEntryId,
      tokensBefore: preparation.tokensBefore,
    }
  };
});

pi.on("session_compact", async (event, ctx) => {
  // event.compactionEntry - the saved compaction
  // event.fromExtension - whether extension provided it
  // event.reason - "manual" (/compact), "threshold", or "overflow"
  // event.willRetry - whether the aborted turn is retried after compaction (overflow recovery)
});
```

#### session_before_tree / session_tree

在 `/tree` 导航时触发。参见 [Sessions](sessions.md) 了解树导航概念。

```typescript
pi.on("session_before_tree", async (event, ctx) => {
  const { preparation, signal } = event;
  return { cancel: true };
  // OR provide custom summary:
  return { summary: { summary: "...", details: {} } };
});

pi.on("session_tree", async (event, ctx) => {
  // event.newLeafId, oldLeafId, summaryEntry, fromExtension
});
```

#### session_shutdown

在已启动的会话运行时被销毁之前触发。用于清理从 `session_start` 或其他会话范围钩子中打开的资源。

```typescript
pi.on("session_shutdown", async (event, ctx) => {
  // event.reason - "quit" | "reload" | "new" | "resume" | "fork"
  // event.targetSessionFile - destination session for session replacement flows
  // Cleanup, save state, etc.
});
```

### Agent 事件

#### before_agent_start

用户提交 prompt 之后、agent 循环之前触发。可以注入消息和/或修改系统提示词（system prompt）。

```typescript
pi.on("before_agent_start", async (event, ctx) => {
  // event.prompt - user's prompt text
  // event.images - attached images (if any)
  // event.systemPrompt - current chained system prompt for this handler
  //   (includes changes from earlier before_agent_start handlers)
  // event.systemPromptOptions - structured options used to build the system prompt
  //   .customPrompt - any custom system prompt (from --system-prompt, SYSTEM.md, or custom templates)
  //   .selectedTools - tools currently active in the prompt
  //   .toolSnippets - one-line descriptions for each tool
  //   .promptGuidelines - custom guideline bullets
  //   .appendSystemPrompt - text from --append-system-prompt flags
  //   .cwd - working directory
  //   .contextFiles - AGENTS.md files and other loaded context files
  //   .skills - loaded skills

  return {
    // Inject a persistent message (stored in session, sent to LLM)
    message: {
      customType: "my-extension",
      content: "Additional context for the LLM",
      display: true,
    },
    // Replace the system prompt for this turn (chained across extensions)
    systemPrompt: event.systemPrompt + "\n\nExtra instructions for this turn...",
  };
});
```

`systemPromptOptions` 字段为扩展提供了与 Pi 构建系统提示词时使用的相同结构化数据。这让你无需重新发现资源或重新解析标志，就能查看 Pi 已加载的内容——自定义提示词、指导方针、工具片段、上下文文件、skill。当你的扩展需要在尊重用户提供配置的情况下对系统提示词做深度、知情的更改时使用它。

在 `before_agent_start` 内部，`event.systemPrompt` 和 `ctx.getSystemPrompt()` 都反映了截至当前处理器的链式系统提示词。后续的 `before_agent_start` 处理器仍然可以再次修改。

#### agent_start / agent_end

每个用户 prompt 触发一次。

```typescript
pi.on("agent_start", async (_event, ctx) => {});

pi.on("agent_end", async (event, ctx) => {
  // event.messages - messages from this prompt
});
```

#### turn_start / turn_end

每轮触发（一次 LLM 响应 + 工具调用）。

```typescript
pi.on("turn_start", async (event, ctx) => {
  // event.turnIndex, event.timestamp
});

pi.on("turn_end", async (event, ctx) => {
  // event.turnIndex, event.message, event.toolResults
});
```

#### message_start / message_update / message_end

消息生命周期更新时触发。

- `message_start` 和 `message_end` 对用户、assistant 和 toolResult 消息都触发。
- `message_update` 对 assistant 流式更新触发。
- `message_end` 处理器可以返回 `{ message }` 来替换最终确定的消息。替换的消息必须保持相同的 `role`。

```typescript
pi.on("message_start", async (event, ctx) => {
  // event.message
});

pi.on("message_update", async (event, ctx) => {
  // event.message
  // event.assistantMessageEvent (token-by-token stream event)
});

pi.on("message_end", async (event, ctx) => {
  if (event.message.role !== "assistant") return;

  return {
    message: {
      ...event.message,
      usage: {
        ...event.message.usage,
        cost: {
          ...event.message.usage.cost,
          total: 0.123,
        },
      },
    },
  };
});
```

#### tool_execution_start / tool_execution_update / tool_execution_end

工具执行生命周期更新时触发。

在并行工具模式下：
- `tool_execution_start` 在预检阶段按 assistant 源顺序发出
- `tool_execution_update` 事件可能在各工具间交错
- `tool_execution_end` 在每个工具完成后按工具完成顺序发出
- 最终的 `toolResult` 消息事件仍按 assistant 源顺序稍后发出

```typescript
pi.on("tool_execution_start", async (event, ctx) => {
  // event.toolCallId, event.toolName, event.args
});

pi.on("tool_execution_update", async (event, ctx) => {
  // event.toolCallId, event.toolName, event.args, event.partialResult
});

pi.on("tool_execution_end", async (event, ctx) => {
  // event.toolCallId, event.toolName, event.result, event.isError
});
```

#### context

在每次 LLM 调用之前触发。非破坏性地修改消息。参见 [Session Format](session-format.md) 了解消息类型。

```typescript
pi.on("context", async (event, ctx) => {
  // event.messages - deep copy, safe to modify
  const filtered = event.messages.filter(m => !shouldPrune(m));
  return { messages: filtered };
});
```

#### before_provider_headers

在发送 HTTP 头部组装完成后触发。用于添加、覆盖或移除请求头部。

处理器在原位修改 `event.headers`。将键设置为字符串以添加或覆盖，设置为 `null` 以删除。

```typescript
pi.on("before_provider_headers", (event, ctx) => {
  // Add or override — e.g. a session id for gateway tracing/attribution
  event.headers["x-session-id"] = ctx.sessionManager.getSessionId();

  // Drop a tracking header pi adds for this call
  event.headers["X-OpenRouter-Title"] = null;
});
```

每次 provider 请求运行一次；重试复用相同的头部而不是重新触发钩子。

#### before_provider_request

在 provider 特定的 payload 构建完成后、请求即将发送之前触发。处理器按扩展加载顺序运行。返回 `undefined` 保持 payload 不变。返回任何其他值都会替换 payload 供后续处理器和实际请求使用。

此钩子可以重写 provider 级别的系统指令或完全移除它们。这些 payload 级别的更改不会被 `ctx.getSystemPrompt()` 反映，后者报告的是 Pi 的系统提示词字符串而不是最终序列化的 provider payload。

```typescript
pi.on("before_provider_request", (event, ctx) => {
  console.log(JSON.stringify(event.payload, null, 2));

  // Optional: replace payload
  // return { ...event.payload, temperature: 0 };
});
```

此钩子主要用于调试 provider 序列化和缓存行为。

#### after_provider_response

在收到 HTTP 响应之后、流式 body 被消费之前触发。处理器按扩展加载顺序运行。

```typescript
pi.on("after_provider_response", (event, ctx) => {
  // event.status - HTTP status code
  // event.headers - normalized response headers
  if (event.status === 429) {
    console.log("rate limited", event.headers["retry-after"]);
  }
});
```

头部可用性取决于 provider 和传输方式。抽象化 HTTP 响应的 provider 可能不会暴露头部。

### 模型事件

#### model_select

当模型通过 `/model` 命令、模型切换（`Ctrl+P`）或会话恢复改变时触发。

```typescript
pi.on("model_select", async (event, ctx) => {
  // event.model - newly selected model
  // event.previousModel - previous model (undefined if first selection)
  // event.source - "set" | "cycle" | "restore"

  const prev = event.previousModel
    ? `${event.previousModel.provider}/${event.previousModel.id}`
    : "none";
  const next = `${event.model.provider}/${event.model.id}`;

  ctx.ui.notify(`Model changed (${event.source}): ${prev} -> ${next}`, "info");
});
```

当活动模型改变时，使用此事件更新 UI 元素（状态栏、页脚）或执行模型特定初始化。

#### thinking_level_select

当思考级别（thinking level）改变时触发。仅供通知；处理器返回值被忽略。

```typescript
pi.on("thinking_level_select", async (event, ctx) => {
  // event.level - newly selected thinking level
  // event.previousLevel - previous thinking level

  ctx.ui.setStatus("thinking", `thinking: ${event.level}`);
});
```

当 `pi.setThinkingLevel()`、模型变化或内置思考级别控制更改活动思考级别时，使用此事件更新扩展 UI。

### 工具事件

#### tool_call

在 `tool_execution_start` 之后、工具执行之前触发。**可以阻止。** 使用 `isToolCallEventType` 进行类型收窄并获取类型化输入。

在 `tool_call` 运行之前，pi 等待先前发出的 Agent 事件通过 `AgentSession` 完成排出。这意味着 `ctx.sessionManager` 在当前 assistant 工具调用消息之前是最新的。

在默认的并行工具执行模式下，来自同一 assistant 消息的同级工具调用按顺序预检，然后并发执行。`tool_call` 不保证在 `ctx.sessionManager` 中看到来自同一 assistant 消息的同级工具结果。

`event.input` 是可变的。就地修改它以在执行前修补工具参数。

行为保证：
- 对 `event.input` 的修改影响实际工具执行
- 后续 `tool_call` 处理器看到先前处理器所做的修改
- 你的修改后不执行重新验证
- `tool_call` 的返回值仅通过 `{ block: true, reason?: string }` 阻止

```typescript
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

pi.on("tool_call", async (event, ctx) => {
  // event.toolName - "bash", "read", "write", "edit", etc.
  // event.toolCallId
  // event.input - tool parameters (mutable)

  // Built-in tools: no type params needed
  if (isToolCallEventType("bash", event)) {
    // event.input is { command: string; timeout?: number }
    event.input.command = `source ~/.profile\n${event.input.command}`;

    if (event.input.command.includes("rm -rf")) {
      return { block: true, reason: "Dangerous command" };
    }
  }

  if (isToolCallEventType("read", event)) {
    // event.input is { path: string; offset?: number; limit?: number }
    console.log(`Reading: ${event.input.path}`);
  }
});
```

#### 类型化自定义工具输入

自定义工具应导出其输入类型：

```typescript
// my-extension.ts
export type MyToolInput = Static<typeof myToolSchema>;
```

使用带有显式类型参数的 `isToolCallEventType`：

```typescript
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import type { MyToolInput } from "my-extension";

pi.on("tool_call", (event) => {
  if (isToolCallEventType<"my_tool", MyToolInput>("my_tool", event)) {
    event.input.action;  // typed
  }
});
```

#### tool_result

在工具执行完成之后、`tool_execution_end` 加上最终工具结果消息事件被发出之前触发。**可修改结果。**

在并行工具模式下，`tool_result` 和 `tool_execution_end` 可能以工具完成顺序交错，而最终的 `toolResult` 消息事件仍按 assistant 源顺序稍后发出。

`tool_result` 处理器像中间件一样链式执行：
- 处理器按扩展加载顺序运行
- 每个处理器看到前一个处理器更改后的最新结果
- 处理器可返回部分补丁（`content`、`details` 或 `isError`）；省略的字段保持当前值

使用 `ctx.signal` 进行处理器内的嵌套异步工作。这将使 Esc 能够取消扩展启动的模型调用、`fetch()` 及其他支持中止的操作。

```typescript
import { isBashToolResult } from "@earendil-works/pi-coding-agent";

pi.on("tool_result", async (event, ctx) => {
  // event.toolName, event.toolCallId, event.input
  // event.content, event.details, event.isError

  if (isBashToolResult(event)) {
    // event.details is typed as BashToolDetails
  }

  const response = await fetch("https://example.com/summarize", {
    method: "POST",
    body: JSON.stringify({ content: event.content }),
    signal: ctx.signal,
  });

  // Modify result:
  return { content: [...], details: {...}, isError: false };
});
```

### 用户 Bash 事件

#### user_bash

当用户执行 `!` 或 `!!` 命令时触发。**可拦截。**

```typescript
import { createLocalBashOperations } from "@earendil-works/pi-coding-agent";

pi.on("user_bash", (event, ctx) => {
  // event.command - the bash command
  // event.excludeFromContext - true if !! prefix
  // event.cwd - working directory

  // Option 1: Provide custom operations (e.g., SSH)
  return { operations: remoteBashOps };

  // Option 2: Wrap pi's built-in local bash backend
  const local = createLocalBashOperations();
  return {
    operations: {
      exec(command, cwd, options) {
        return local.exec(`source ~/.profile\n${command}`, cwd, options);
      }
    }
  };

  // Option 3: Full replacement - return result directly
  return { result: { output: "...", exitCode: 0, cancelled: false, truncated: false } };
});
```

### 输入事件

#### input

当用户输入被接收时触发，在扩展命令检查之后、skill 和模板扩展之前。事件看到的是原始输入文本，因此 `/skill:foo` 和 `/template` 尚未被扩展。

**处理顺序：**
1. 扩展命令（`/cmd`）首先检查 - 如果找到，处理器运行并跳过 input 事件
2. `input` 事件触发 - 可以拦截、转换或处理
3. 如果未处理：skill 命令（`/skill:name`）扩展为 skill 内容
4. 如果未处理：prompt 模板（`/template`）扩展为模板内容
5. Agent 处理开始（`before_agent_start` 等）

```typescript
pi.on("input", async (event, ctx) => {
  // event.text - raw input (before skill/template expansion)
  // event.images - attached images, if any
  // event.source - "interactive" (typed), "rpc" (API), or "extension" (via sendUserMessage)
  // event.streamingBehavior - "steer" | "followUp" | undefined
  //   undefined when idle, "steer" for mid-stream interrupts,
  //   "followUp" for messages queued until the agent finishes

  // Transform: rewrite input before expansion
  if (event.text.startsWith("?quick "))
    return { action: "transform", text: `Respond briefly: ${event.text.slice(7)}` };

  // Handle: respond without LLM (extension shows its own feedback)
  if (event.text === "ping") {
    ctx.ui.notify("pong", "info");
    return { action: "handled" };
  }

  // Route by source: skip processing for extension-injected messages
  if (event.source === "extension") return { action: "continue" };

  // Intercept skill commands before expansion
  if (event.text.startsWith("/skill:")) {
    // Could transform, block, or let pass through
  }

  return { action: "continue" };  // Default: pass through to expansion
});
```

**结果：**
- `continue` - 原样通过（如果处理器没有返回任何内容，则为默认值）
- `transform` - 修改文本/图像，然后继续扩展
- `handled` - 完全跳过 agent（第一个返回此值的处理器获胜）

转换在处理器间链式执行。参见 [input-transform.ts](../examples/extensions/input-transform.ts) 和 [input-transform-streaming.ts](../examples/extensions/input-transform-streaming.ts) 了解 `streamingBehavior` 感知的路由。

## ExtensionContext

所有处理器都接收 `ctx: ExtensionContext`。

### ctx.ui

用于用户交互的 UI 方法。详见 [自定义 UI](#custom-ui)。

### ctx.mode

当前运行模式：`"tui"`、`"rpc"`、`"json"` 或 `"print"`。使用 `ctx.mode === "tui"` 来保护仅终端可用的功能，如 `custom()`、组件工厂、终端输入和直接 TUI 渲染。

### ctx.hasUI

在 TUI 和 RPC 模式下为 `true`。在 print 模式（`-p`）和 JSON 模式下为 `false`。在 TUI 和 RPC 模式下都有效的对话框方法（`select`、`confirm`、`input`、`editor`）和即发即忘方法（`notify`、`setStatus`、`setWidget`、`setTitle`、`setEditorText`）之前使用此属性进行保护。在 RPC 模式下，某些 TUI 特定方法为无操作或返回默认值（参见 [rpc.md](rpc.md#extension-ui-protocol)）。

### ctx.cwd

当前工作目录。

在构建项目本地配置路径时使用 `CONFIG_DIR_NAME` 而不是硬编码 `.pi` 的名称。重新分发的版本可以使用不同的配置目录名称。

```typescript
import { CONFIG_DIR_NAME, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    const projectConfigPath = join(ctx.cwd, CONFIG_DIR_NAME, "my-extension.json");
    // ...
  });
}
```

### ctx.isProjectTrusted()

返回项目本地信任是否对当前会话上下文处于活动状态。这包括临时信任决策和 CLI 信任覆盖，不仅仅是全局信任存储中保存的决策。

在读取仅对受信任项目应被遵守的项目本地扩展配置之前，先使用此方法。

### ctx.sessionManager

对会话状态的只读访问。参见 [Session Format](session-format.md) 了解完整的 SessionManager API 和条目类型。

对于 `tool_call`，此状态在处理器运行之前通过当前 assistant 消息同步。在并行工具执行模式下，仍然不保证包含来自同一 assistant 消息的同级工具结果。

```typescript
ctx.sessionManager.getEntries()             // All entries
ctx.sessionManager.getBranch()              // Current branch
ctx.sessionManager.buildContextEntries()    // Active branch entries with compaction applied
ctx.sessionManager.getLeafId()              // Current leaf entry ID
```

### ctx.modelRegistry / ctx.model

访问模型和 API 密钥。

### ctx.signal

当前 agent 的中止信号（AbortSignal），当没有 agent 轮次处于活动状态时为 `undefined`。

用于扩展处理器启动的中止感知嵌套工作，例如：
- `fetch(..., { signal: ctx.signal })`
- 接受 `signal` 的模型调用
- 接受 `AbortSignal` 的文件或进程辅助函数

`ctx.signal` 通常在活动轮次事件（如 `tool_call`、`tool_result`、`message_update` 和 `turn_end`）期间定义。
在空闲或非轮次上下文（如会话事件、扩展命令以及 pi 空闲时触发的快捷键）中通常为 `undefined`。

```typescript
pi.on("tool_result", async (event, ctx) => {
  const response = await fetch("https://example.com/api", {
    method: "POST",
    body: JSON.stringify(event),
    signal: ctx.signal,
  });

  const data = await response.json();
  return { details: data };
});
```

### ctx.isIdle() / ctx.abort() / ctx.hasPendingMessages()

控制流辅助方法。

### ctx.shutdown()

请求 pi 优雅关闭。

- **交互模式：** 延迟到 agent 空闲（处理完所有排队的 steering 和 follow-up 消息后）。
- **RPC 模式：** 延迟到下一个空闲状态（完成当前命令响应后，等待下一个命令时）。
- **Print 模式：** 无操作。所有 prompt 处理完成后进程自动退出。

退出前向所有扩展发出 `session_shutdown` 事件。在所有上下文中可用（事件处理器、工具、命令、快捷键）。

```typescript
pi.on("tool_call", (event, ctx) => {
  if (isFatal(event.input)) {
    ctx.shutdown();
  }
});
```

### ctx.getContextUsage()

返回活动模型的当前上下文使用量。当有最后一次 assistant 使用量时优先使用，然后估算尾部消息的 token 数。

```typescript
const usage = ctx.getContextUsage();
if (usage && usage.tokens > 100_000) {
  // ...
}
```

### ctx.compact()

触发压缩而不等待完成。使用 `onComplete` 和 `onError` 进行后续操作。

```typescript
ctx.compact({
  customInstructions: "Focus on recent changes",
  onComplete: (result) => {
    ctx.ui.notify("Compaction completed", "info");
  },
  onError: (error) => {
    ctx.ui.notify(`Compaction failed: ${error.message}`, "error");
  },
});
```

### ctx.getSystemPrompt()

返回 Pi 当前的系统提示词字符串。

- 在 `before_agent_start` 期间，这反映了截至当前轮次已完成的链式系统提示词更改。
- 它不包括后续的 `context` 消息修改。
- 它不包括 `before_provider_request` payload 重写。
- 如果后续加载的扩展在你的之后运行，它们仍然可以改变最终发送的内容。

```typescript
pi.on("before_agent_start", (event, ctx) => {
  const prompt = ctx.getSystemPrompt();
  console.log(`System prompt length: ${prompt.length}`);
});
```

## ExtensionCommandContext

命令处理器接收 `ExtensionCommandContext`，它扩展了 `ExtensionContext` 并添加了会话控制方法。这些方法仅在命令中可用，因为如果从事件处理器中调用它们可能会导致死锁。

### ctx.getSystemPromptOptions()

返回 Pi 当前用于构建系统提示词的基础输入。

```typescript
const options = ctx.getSystemPromptOptions();
const contextPaths = options.contextFiles?.map((file) => file.path) ?? [];
```

其形状和可变性与 `before_agent_start` 的 `event.systemPromptOptions` 相同：自定义提示词、活动工具、工具片段、prompt 指导方针、附加的系统提示词文本、cwd、已加载的上下文文件和已加载的 skill。它可能包含完整的上下文文件内容，因此将其视为敏感的扩展本地数据，避免通过命令列表、日志或自动完成元数据暴露它。

此方法报告当前基础 prompt 输入。它不包括每轮 `before_agent_start` 的链式系统提示词更改、后续 `context` 事件的消息修改，或 `before_provider_request` payload 重写。

### ctx.waitForIdle()

等待 agent 完成流式输出：

```typescript
pi.registerCommand("my-cmd", {
  handler: async (args, ctx) => {
    await ctx.waitForIdle();
    // Agent is now idle, safe to modify session
  },
});
```

### ctx.newSession(options?)

创建一个新会话：

```typescript
const parentSession = ctx.sessionManager.getSessionFile();
const kickoff = "Continue in the replacement session";

const result = await ctx.newSession({
  parentSession,
  setup: async (sm) => {
    sm.appendMessage({
      role: "user",
      content: [{ type: "text", text: "Context from previous session..." }],
      timestamp: Date.now(),
    });
  },
  withSession: async (ctx) => {
    // Use only the replacement-session ctx here.
    await ctx.sendUserMessage(kickoff);
  },
});

if (result.cancelled) {
  // An extension cancelled the new session
}
```

选项：
- `parentSession`: 父会话文件，记录在新会话头中
- `setup`: 在 `withSession` 运行之前修改新会话的 `SessionManager`
- `withSession`: 在全新的替换会话上下文上运行切换后的工作。不要使用捕获的旧 `pi` / 命令 `ctx`;参见[会话替换生命周期和陷阱](#session-replacement-lifecycle-and-footguns)。

### ctx.fork(entryId, options?)

从特定条目分叉，创建新的会话文件：

```typescript
const result = await ctx.fork("entry-id-123", {
  withSession: async (ctx) => {
    // Use only the replacement-session ctx here.
    ctx.ui.notify("Now in the forked session", "info");
  },
});
if (result.cancelled) {
  // An extension cancelled the fork
}

const cloneResult = await ctx.fork("entry-id-456", { position: "at" });
if (cloneResult.cancelled) {
  // An extension cancelled the clone
}
```

选项：
- `position`: `"before"` (默认) 在所选用户消息之前分叉，将该 prompt 恢复到编辑器中
- `position`: `"at"` 复制通过所选条目的活动路径，不恢复编辑器文本
- `withSession`: 在全新的替换会话上下文上运行切换后的工作。不要使用捕获的旧 `pi` / 命令 `ctx`;参见[会话替换生命周期和陷阱](#session-replacement-lifecycle-and-footguns)。

### ctx.navigateTree(targetId, options?)

导航到会话树中的不同位置：

```typescript
const result = await ctx.navigateTree("entry-id-456", {
  summarize: true,
  customInstructions: "Focus on error handling changes",
  replaceInstructions: false, // true = replace default prompt entirely
  label: "review-checkpoint",
});
```

选项：
- `summarize`: 是否为被放弃的分支生成摘要
- `customInstructions`: 摘要器的自定义指令
- `replaceInstructions`: 如果为 true，`customInstructions` 将完全替换默认 prompt 而不是追加
- `label`: 附加到分支摘要条目（或如果不摘要则附加到目标条目）的标签

### ctx.switchSession(sessionPath, options?)

切换到不同的会话文件：

```typescript
const result = await ctx.switchSession("/path/to/session.jsonl", {
  withSession: async (ctx) => {
    await ctx.sendUserMessage("Resume work in the replacement session");
  },
});
if (result.cancelled) {
  // An extension cancelled the switch via session_before_switch
}
```

选项：
- `withSession`: 在全新的替换会话上下文上运行切换后的工作。不要使用捕获的旧 `pi` / 命令 `ctx`;参见[会话替换生命周期和陷阱](#session-replacement-lifecycle-and-footguns)。

要发现可用的会话，使用静态的 `SessionManager.list()` 或 `SessionManager.listAll()` 方法：

```typescript
import { SessionManager } from "@earendil-works/pi-coding-agent";

pi.registerCommand("switch", {
  description: "Switch to another session",
  handler: async (args, ctx) => {
    const sessions = await SessionManager.list(ctx.cwd);
    if (sessions.length === 0) return;
    const choice = await ctx.ui.select(
      "Pick session:",
      sessions.map(s => s.file),
    );
    if (choice) {
      await ctx.switchSession(choice, {
        withSession: async (ctx) => {
          ctx.ui.notify("Switched session", "info");
        },
      });
    }
  },
});
```

### 会话替换生命周期和陷阱

`withSession` 接收一个全新的 `ReplacedSessionContext`，它扩展了 `ExtensionCommandContext`，并绑定了替换会话的异步 `sendMessage()` 和 `sendUserMessage()` 辅助方法。

生命周期和陷阱：
- `withSession` 仅在旧会话已发出 `session_shutdown`、旧运行时已销毁、替换会话已重新绑定且新扩展实例已收到 `session_start` 之后运行。
- 回调仍在原始闭包中执行，而不是在新扩展实例内部。这意味着你的旧扩展实例可能在 `withSession` 开始之前已经运行了其关闭清理。
- 捕获的旧 `pi` / 旧命令 `ctx` 会话绑定对象在替换后已过时，如被使用将抛出错误。仅使用传递给 `withSession` 的 `ctx` 进行会话绑定工作。
- 先前提取的原始对象仍是你的责任。例如，如果你在替换前捕获 `const sm = ctx.sessionManager`，`sm` 仍是旧的 `SessionManager` 对象。替换后不要重复使用。
- `withSession` 中的代码应假设你的 `session_shutdown` 处理器已失效的任何状态都已消失。仅捕获能干净存活关闭的纯数据，如字符串、id 和序列化的配置。

安全模式：

```typescript
pi.registerCommand("handoff", {
  handler: async (_args, ctx) => {
    const kickoff = "Continue from the replacement session";
    await ctx.newSession({
      withSession: async (ctx) => {
        await ctx.sendUserMessage(kickoff);
      },
    });
  },
});
```

不安全模式：

```typescript
pi.registerCommand("handoff", {
  handler: async (_args, ctx) => {
    const oldSessionManager = ctx.sessionManager;
    await ctx.newSession({
      withSession: async (_ctx) => {
        // stale old objects: do not do this
        oldSessionManager.getSessionFile();
        pi.sendUserMessage("wrong");
      },
    });
  },
});
```

### ctx.reload()

运行与 `/reload` 相同的重载流程。

```typescript
pi.registerCommand("reload-runtime", {
  description: "Reload extensions, skills, prompts, and themes",
  handler: async (_args, ctx) => {
    await ctx.reload();
    return;
  },
});
```

重要行为：
- `await ctx.reload()` 为当前扩展运行时发出 `session_shutdown`
- 然后重新加载资源并以 `reason: "reload"` 发出 `session_start`，以 `"reload"` 为 reason 发出 `resources_discover`
- 当前运行的命令处理器仍在旧的调用帧中继续执行
- `await ctx.reload()` 之后的代码仍然从重载前的版本运行
- `await ctx.reload()` 之后的代码不得假设旧的内存中扩展状态仍然有效
- 处理器返回后，后续的命令/事件/工具调用将使用新的扩展版本

为实现可预测行为，将该处理器的重载视为终止操作（`await ctx.reload(); return;`）。

工具以 `ExtensionContext` 运行，因此无法直接调用 `ctx.reload()`。使用命令作为重载入口点，然后暴露一个将该命令作为 follow-up 用户消息排队的工具。

LLM 可调用以触发重载的示例工具：

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("reload-runtime", {
    description: "Reload extensions, skills, prompts, and themes",
    handler: async (_args, ctx) => {
      await ctx.reload();
      return;
    },
  });

  pi.registerTool({
    name: "reload_runtime",
    label: "Reload Runtime",
    description: "Reload extensions, skills, prompts, and themes",
    parameters: Type.Object({}),
    async execute() {
      pi.sendUserMessage("/reload-runtime", { deliverAs: "followUp" });
      return {
        content: [{ type: "text", text: "Queued /reload-runtime as a follow-up command." }],
      };
    },
  });
}
```

## ExtensionAPI Methods

### pi.on(event, handler)

订阅事件。参见 [事件](#events) 了解事件类型和返回值。

### pi.registerTool(definition)

注册 LLM 可调用的自定义工具。详见 [自定义工具](#custom-tools)。

`pi.registerTool()` 在扩展加载期间和启动后均可调用。可以在 `session_start`、命令处理器或其他事件处理器中调用。新工具会在同一会话中立即刷新，因此会出现在 `pi.getAllTools()` 中，LLM 无需 `/reload` 即可调用。

使用 `pi.setActiveTools()` 可在运行时启用或禁用工具（包括动态添加的工具）。

使用 `promptSnippet` 可将自定义工具作为单行条目加入默认系统提示的 `Available tools` 部分；使用 `promptGuidelines` 可在工具激活时将工具专属的要点追加到默认 `Guidelines` 部分。

**重要：** `promptGuidelines` 要点会平铺追加到 `Guidelines` 部分，不带工具名称前缀。每条准则必须指明其引用的工具——避免使用"Use this tool when..."，因为 LLM 无法判断"this"指哪个工具。应写为"Use my_tool when..."。

参见 [dynamic-tools.ts](../examples/extensions/dynamic-tools.ts) 了解完整示例。

```typescript
import { Type } from "typebox";
import { StringEnum } from "@earendil-works/pi-ai";

pi.registerTool({
  name: "my_tool",
  label: "My Tool",
  description: "What this tool does",
  promptSnippet: "Summarize or transform text according to action",
  promptGuidelines: ["Use my_tool when the user asks to summarize previously generated text."],
  parameters: Type.Object({
    action: StringEnum(["list", "add"] as const),
    text: Type.Optional(Type.String()),
  }),
  prepareArguments(args) {
    // Optional compatibility shim. Runs before schema validation.
    // Return the current schema shape, for example to fold legacy fields
    // into the modern parameter object.
    return args;
  },

  async execute(toolCallId, params, signal, onUpdate, ctx) {
    // Stream progress
    onUpdate?.({ content: [{ type: "text", text: "Working..." }] });

    return {
      content: [{ type: "text", text: "Done" }],
      details: { result: "..." },
    };
  },

  // Optional: Custom rendering
  renderCall(args, theme, context) { ... },
  renderResult(result, options, theme, context) { ... },
});
```

### pi.sendMessage(message, options?)

向会话中注入自定义消息。自定义消息会参与 LLM 上下文。对于不应发送给 LLM 的持久性 TUI 内容，请使用 [`pi.appendEntry()`](#piappendentrycustomtype-data) 配合 [`pi.registerEntryRenderer()`](#piregisterentryrenderercustomtype-renderer)。

```typescript
pi.sendMessage({
  customType: "my-extension",
  content: "Message text",
  display: true,
  details: { ... },
}, {
  triggerTurn: true,
  deliverAs: "steer",
});
```

**选项：**
- `deliverAs` - 投递模式：
  - `"steer"`（默认）- 流式传输期间排队。在当前助手轮次完成工具调用后、下一次 LLM 调用前投递。
  - `"followUp"` - 等待 agent 完成。仅在 agent 没有更多工具调用时投递。
  - `"nextTurn"` - 排队到下一次用户提示。不中断或触发任何操作。
- `triggerTurn: true` - 如果 agent 空闲，立即触发 LLM 响应。仅适用于 `"steer"` 和 `"followUp"` 模式（`"nextTurn"` 模式忽略此选项）。

### pi.sendUserMessage(content, options?)

向 agent 发送用户消息。与发送自定义消息的 `sendMessage()` 不同，此方法发送的是实际的用户消息，效果如同用户亲自输入。总会触发一轮对话。

```typescript
// Simple text message
pi.sendUserMessage("What is 2+2?");

// With content array (text + images)
pi.sendUserMessage([
  { type: "text", text: "Describe this image:" },
  { type: "image", source: { type: "base64", mediaType: "image/png", data: "..." } },
]);

// During streaming - must specify delivery mode
pi.sendUserMessage("Focus on error handling", { deliverAs: "steer" });
pi.sendUserMessage("And then summarize", { deliverAs: "followUp" });
```

**Options:**
- `deliverAs` - agent 流式传输时必填：
  - `"steer"` - 在当前助手轮次完成工具调用后投递
  - `"followUp"` - 等待 agent 完成所有工具

未流式传输时，消息会立即发送并触发新一轮对话。流式传输时未指定 `deliverAs` 会抛出错误。

参见 [send-user-message.ts](../examples/extensions/send-user-message.ts) 了解完整示例。

### pi.appendEntry(customType, data?)

持久化扩展数据。自定义条目不参与 LLM 上下文。在交互模式下，配合 `pi.registerEntryRenderer()` 也可在聊天记录中渲染。

```typescript
pi.appendEntry("my-state", { count: 42 });
pi.appendEntry("status-card", { title: "Indexed files", count: 17 });

// Restore on reload
pi.on("session_start", async (_event, ctx) => {
  for (const entry of ctx.sessionManager.getEntries()) {
    if (entry.type === "custom" && entry.customType === "my-state") {
      // Reconstruct from entry.data
    }
  }
});
```

### pi.setSessionName(name)

设置会话显示名称（在会话选择器中显示，替代首条消息）。

```typescript
pi.setSessionName("Refactor auth module");
```

### pi.getSessionName()

获取当前会话名称（如果已设置）。

```typescript
const name = pi.getSessionName();
if (name) {
  console.log(`Session: ${name}`);
}
```

### pi.setLabel(entryId, label)

设置或清除条目标签。标签是用户定义的标记，用于书签和导航（在 `/tree` 选择器中显示）。

```typescript
// 设置标签
pi.setLabel(entryId, "checkpoint-before-refactor");

// 清除标签
pi.setLabel(entryId, undefined);

// 通过 sessionManager 读取标签
const label = ctx.sessionManager.getLabel(entryId);
```

标签在会话中持久化，重启后仍保留。用于标记对话树中的重要节点（轮次、检查点）。

### pi.registerCommand(name, options)

注册命令。

如果多个扩展注册了相同的命令名称，pi 会保留所有命令，并按加载顺序分配数字调用后缀，例如 `/review:1` 和 `/review:2`。

```typescript
pi.registerCommand("stats", {
  description: "Show session statistics",
  handler: async (args, ctx) => {
    const count = ctx.sessionManager.getEntries().length;
    ctx.ui.notify(`${count} entries`, "info");
  }
});
```

可选：为 `/command ...` 添加参数自动补全：

```typescript
import type { AutocompleteItem } from "@earendil-works/pi-tui";

pi.registerCommand("deploy", {
  description: "Deploy to an environment",
  getArgumentCompletions: (prefix: string): AutocompleteItem[] | null => {
    const envs = ["dev", "staging", "prod"];
    const items = envs.map((e) => ({ value: e, label: e }));
    const filtered = items.filter((i) => i.value.startsWith(prefix));
    return filtered.length > 0 ? filtered : null;
  },
  handler: async (args, ctx) => {
    ctx.ui.notify(`Deploying: ${args}`, "info");
  },
});
```

### pi.getCommands()

获取当前会话中可通过 `prompt` 调用的斜杠命令。包括扩展命令、提示模板和技能命令。
列表顺序与 RPC `get_commands` 一致：扩展优先，然后是模板，最后是技能。

```typescript
const commands = pi.getCommands();
const bySource = commands.filter((command) => command.source === "extension");
const userScoped = commands.filter((command) => command.sourceInfo.scope === "user");
```

每个条目具有以下结构：

```typescript
{
  name: string; // Invokable command name without the leading slash. May be suffixed like "review:1"
  description?: string;
  source: "extension" | "prompt" | "skill";
  sourceInfo: {
    path: string;
    source: string;
    scope: "user" | "project" | "temporary";
    origin: "package" | "top-level";
    baseDir?: string;
  };
}
```

使用 `sourceInfo` 作为规范的来源字段。不要从命令名称或临时路径解析推断所有权。

内置交互命令（如 `/model` 和 `/settings`）不包含在此处。它们仅在交互模式下处理，通过 `prompt` 发送不会执行。

### pi.registerMessageRenderer(customType, renderer)

为指定 `customType` 的自定义消息注册 TUI 渲染器。自定义消息通过 `pi.sendMessage()` 创建，会参与 LLM 上下文。参见 [自定义 UI](#custom-ui)。

### pi.registerEntryRenderer(customType, renderer)

为指定 `customType` 的自定义条目注册 TUI 渲染器。自定义条目通过 `pi.appendEntry()` 创建，不参与 LLM 上下文。

```typescript
import { Box, Text } from "@earendil-works/pi-tui";

pi.registerEntryRenderer("status-card", (entry, { expanded }, theme) => {
  const data = entry.data as { title: string; count: number };
  const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
  box.addChild(new Text(`${theme.bold(data.title)}: ${data.count}`));
  if (expanded) {
    box.addChild(new Text(theme.fg("dim", JSON.stringify(data, null, 2))));
  }
  return box;
});

pi.appendEntry("status-card", { title: "Indexed files", count: 17 });
```

### pi.registerShortcut(shortcut, options)

注册键盘快捷键。参见 [keybindings.md](keybindings.md) 了解快捷键格式和内置键绑定。

```typescript
pi.registerShortcut("ctrl+shift+p", {
  description: "Toggle plan mode",
  handler: async (ctx) => {
    ctx.ui.notify("Toggled!");
  },
});
```

### pi.registerFlag(name, options)

注册 CLI 标志。

```typescript
pi.registerFlag("plan", {
  description: "Start in plan mode",
  type: "boolean",
  default: false,
});

// Check value
if (pi.getFlag("plan")) {
  // Plan mode enabled
}
```

### pi.exec(command, args, options?)

执行 shell 命令。

```typescript
const result = await pi.exec("git", ["status"], { signal, timeout: 5000 });
// result.stdout, result.stderr, result.code, result.killed
```

### pi.getActiveTools() / pi.getAllTools() / pi.setActiveTools(names)

管理活动工具。对内置工具和动态注册的工具均有效。`pi.getActiveTools()` 返回活动工具名称的 `string[]`；`pi.getAllTools()` 返回所有已配置工具的元数据。

```typescript
const active = pi.getActiveTools(); // ["read", "bash", ...]
const all = pi.getAllTools();
// all = [{
//   name: "read",
//   description: "Read file contents...",
//   parameters: ...,
//   promptGuidelines: ["Use read to examine files instead of cat or sed."],
//   sourceInfo: { path: "<builtin:read>", source: "builtin", scope: "temporary", origin: "top-level" }
// }, ...]
const builtinTools = all.filter((t) => t.sourceInfo.source === "builtin");
const extensionTools = all.filter((t) => t.sourceInfo.source !== "builtin" && t.sourceInfo.source !== "sdk");
pi.setActiveTools([...new Set([...active, "my_custom_tool"])]); // Keep current tools and enable my_custom_tool
pi.setActiveTools(["read", "bash"]); // Switch to read-only
```

`pi.getAllTools()` returns `name`, `description`, `parameters`, `promptGuidelines`, and `sourceInfo`.

`sourceInfo.source` 的典型值：
- `builtin` 表示内置工具
- `sdk` 表示通过 `createAgentSession({ customTools })` 传入的工具
- 扩展来源元数据表示由扩展注册的工具

### pi.setModel(model)

设置当前模型。如果模型没有可用的 API 密钥，返回 `false`。参见 [models.md](models.md) 了解自定义模型配置。

```typescript
const model = ctx.modelRegistry.find("anthropic", "claude-sonnet-4-5");
if (model) {
  const success = await pi.setModel(model);
  if (!success) {
    ctx.ui.notify("No API key for this model", "error");
  }
}
```

### pi.getThinkingLevel() / pi.setThinkingLevel(level)

获取或设置思考级别。级别会被限制在模型能力范围内（非推理模型始终使用"off"）。更改会触发 `thinking_level_select` 事件。

```typescript
const current = pi.getThinkingLevel();  // "off" | "minimal" | "low" | "medium" | "high" | "xhigh"
pi.setThinkingLevel("high");
```

### pi.events

用于扩展间通信的共享事件总线：

```typescript
pi.events.on("my:event", (data) => { ... });
pi.events.emit("my:event", { ... });
```

### pi.registerProvider(name, config)

动态注册或覆盖模型提供商。适用于代理、自定义端点或团队级模型配置。

在扩展工厂函数期间进行的调用会被排队，在运行器初始化时应用。之后的调用（例如来自用户设置流程中的命令处理器）会立即生效，无需 `/reload`。

如果需要从远程端点发现模型，建议使用异步扩展工厂，而不是将获取延迟到 `session_start`。pi 在启动继续前会等待工厂完成，因此注册的模型立即可用，包括对 `pi --list-models`。

```typescript
// Register a new provider with custom models
pi.registerProvider("my-proxy", {
  name: "My Proxy",
  baseUrl: "https://proxy.example.com",
  apiKey: "$PROXY_API_KEY",  // env var reference
  api: "anthropic-messages",
  models: [
    {
      id: "claude-sonnet-4-20250514",
      name: "Claude 4 Sonnet (proxy)",
      reasoning: false,
      input: ["text", "image"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 200000,
      maxTokens: 16384
    }
  ]
});

// Override baseUrl for an existing provider (keeps all models)
pi.registerProvider("anthropic", {
  baseUrl: "https://proxy.example.com"
});

// Register provider with OAuth support for /login
pi.registerProvider("corporate-ai", {
  baseUrl: "https://ai.corp.com",
  api: "openai-responses",
  models: [...],
  oauth: {
    name: "Corporate AI (SSO)",
    async login(callbacks) {
      // Custom OAuth flow
      callbacks.onAuth({ url: "https://sso.corp.com/..." });
      const code = await callbacks.onPrompt({ message: "Enter code:" });
      return { refresh: code, access: code, expires: Date.now() + 3600000 };
    },
    async refreshToken(credentials) {
      // Refresh logic
      return credentials;
    },
    getApiKey(credentials) {
      return credentials.access;
    }
  }
});
```

**配置选项：**
- `name` - 提供商在 UI 中的显示名称，如 `/login`。
- `baseUrl` - API 端点 URL。定义模型时为必填。
- `apiKey` - API 密钥字面量、环境变量插值（`$ENV_VAR` 或 `${ENV_VAR}`）或前导 `!command`。定义模型时为必填（除非提供了 `oauth`）。`$$` 转义 `$`，`$!` 转义字面量 `!` 而不触发命令执行。
- `api` - API 类型：`"anthropic-messages"`、`"openai-completions"`、`"openai-responses"` 等。
- `headers` - 请求中包含的自定义头部。
- `authHeader` - 如果为 true，自动添加 `Authorization: Bearer` 头部。
- `models` - 模型定义数组。如果提供，替换该提供商的所有现有模型。模型定义可以设置 `baseUrl` 以覆盖该模型的提供商端点。
- `oauth` - 用于 `/login` 支持的 OAuth 提供商配置。提供时，提供商出现在登录菜单中。
- `streamSimple` - 用于非标准 API 的自定义流式实现。

参见 [custom-provider.md](custom-provider.md) 了解高级主题：自定义流式 API、OAuth 详情、模型定义参考。

### pi.unregisterProvider(name)

移除之前注册的提供商及其模型。被该提供商覆盖的内置模型会被恢复。如果提供商未注册则无效果。

与 `registerProvider` 一样，在初始加载阶段后调用会立即生效，无需 `/reload`。

```typescript
pi.registerCommand("my-setup-teardown", {
  description: "Remove the custom proxy provider",
  handler: async (_args, _ctx) => {
    pi.unregisterProvider("my-proxy");
  },
});
```

## 状态管理

有状态的扩展应将其存储在工具结果的 `details` 中，以支持正确的分支处理：

```typescript
export default function (pi: ExtensionAPI) {
  let items: string[] = [];

  // Reconstruct state from session
  pi.on("session_start", async (_event, ctx) => {
    items = [];
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type === "message" && entry.message.role === "toolResult") {
        if (entry.message.toolName === "my_tool") {
          items = entry.message.details?.items ?? [];
        }
      }
    }
  });

  pi.registerTool({
    name: "my_tool",
    // ...
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      items.push("new item");
      return {
        content: [{ type: "text", text: "Added" }],
        details: { items: [...items] },  // Store for reconstruction
      };
    },
  });
}
```

## 自定义工具

通过 `pi.registerTool()` 注册 LLM 可调用的工具。工具会出现在系统提示中，并可以拥有自定义渲染。

使用 `promptSnippet` 在默认系统提示的 `Available tools` 部分中添加简短的单行条目。如果省略，自定义工具将不会出现在该部分。

使用 `promptGuidelines` 在默认系统提示的 `Guidelines` 部分添加工具特定的要点。这些要点仅在工具处于活动状态时（例如，在调用 `pi.setActiveTools([...])` 之后）才会被包含。

**重要：** `promptGuidelines` 要点平铺附加到 `Guidelines` 部分，没有工具名称前缀或分组。每条指南必须指明其所指的工具名称——避免"使用此工具时……"，因为 LLM 无法判断"此"指哪个工具。应写"使用 my_tool 时……"。

注意：有些模型比较愚蠢，在工具路径参数中包含 @ 前缀。内置工具在解析路径前会去除前导 @。如果你的自定义工具接受路径参数，也应同样去除前导 @。

如果你的自定义工具会修改文件，请使用 `withFileMutationQueue()`，使其与内置的 `edit` 和 `write` 同一个每文件队列。这很重要，因为工具调用默认是并行执行的。没有队列的情况下，两个工具可能读取相同的旧文件内容，计算不同的更新，然后后写入的那个会覆盖前面的更改。

示例故障场景：你的自定义工具编辑 `foo.ts`，而内置的 `edit` 工具也在同一个助手轮次中修改 `foo.ts`。如果你的工具没有参与队列，两者可能同时读取原始的 `foo.ts`，分别应用各自的修改，最终后写入的那一个会覆盖前者的变更。

向 `withFileMutationQueue()` 传入真实的绝对目标文件路径，而非原始的用户参数。先将其解析为绝对路径，相对于 `ctx.cwd` 或你的工具工作目录。对于已存在的文件，该辅助函数会通过 `realpath()` 进行规范化，因此同一文件的符号链接别名将共享一个队列。对于新建文件，由于尚无路径可供 `realpath()` 解析，将回退到已解析的绝对路径。

将整个变更窗口（mutation window）排入该目标路径的队列。这包括读取-修改-写入逻辑，而不仅仅是最终写入。

```typescript
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
  const absolutePath = resolve(ctx.cwd, params.path);

  return withFileMutationQueue(absolutePath, async () => {
    await mkdir(dirname(absolutePath), { recursive: true });
    const current = await readFile(absolutePath, "utf8");
    const next = current.replace(params.oldText, params.newText);
    await writeFile(absolutePath, next, "utf8");

    return {
      content: [{ type: "text", text: `Updated ${params.path}` }],
      details: {},
    };
  });
}
```

### Tool Definition（工具定义）

```typescript
import { Type } from "typebox";
import { StringEnum } from "@earendil-works/pi-ai";
import { Text } from "@earendil-works/pi-tui";

pi.registerTool({
  name: "my_tool",
  label: "My Tool",
  description: "What this tool does (shown to LLM)",  // 工具功能的描述（展示给 LLM）
  promptSnippet: "List or add items in the project todo list",  // 简短提示语
  promptGuidelines: [  // 使用指南（每条为一行提示）
    "Use my_tool for todo planning instead of direct file edits when the user asks for a task list."
  ],
  parameters: Type.Object({
    action: StringEnum(["list", "add"] as const),  // Use StringEnum for Google compatibility
    text: Type.Optional(Type.String()),
  }),
  prepareArguments(args) {
    if (!args || typeof args !== "object") return args;
    const input = args as { action?: string; oldAction?: string };
    if (typeof input.oldAction === "string" && input.action === undefined) {
      return { ...input, action: input.oldAction };
    }
    return args;
  },

  async execute(toolCallId, params, signal, onUpdate, ctx) {
    // Check for cancellation
    if (signal?.aborted) {
      return { content: [{ type: "text", text: "Cancelled" }] };
    }

    // Stream progress updates
    onUpdate?.({
      content: [{ type: "text", text: "Working..." }],
      details: { progress: 50 },
    });

    // Run commands via pi.exec (captured from extension closure)
    const result = await pi.exec("some-command", [], { signal });

    // Return result
    return {
      content: [{ type: "text", text: "Done" }],  // Sent to LLM
      details: { data: result },                   // For rendering & state
      // Optional: stop after this tool batch when every finalized tool result
      // in the batch also returns terminate: true.
      terminate: true,
    };
  },

  // Optional: Custom rendering（可选：自定义渲染）
  renderCall(args, theme, context) { ... },
  renderResult(result, options, theme, context) { ... },
});
```

**信号错误（Signaling errors）：** 若要将工具执行标记为失败（在结果上设置 `isError: true` 并报告给 LLM），请从 `execute` 抛出错误。无论返回对象中包含何种属性，仅返回值永远不会设置错误标记。

**提前终止（Early termination）：** 从 `execute()` 返回 `terminate: true`，提示在当前工具批次完成后跳过自动的后续 LLM 调用。仅当该批次中所有已完成的工具结果都返回 `terminate: true` 时，此设置才生效。参见 [examples/extensions/structured-output.ts](../examples/extensions/structured-output.ts)，其中提供了一个最小示例：agent 在最终的 structured-output 工具调用处结束。

```typescript
// Correct: throw to signal an error（正确方式：抛出异常以信号化错误）
async execute(toolCallId, params) {
  if (!isValid(params.input)) {
    throw new Error(`Invalid input: ${params.input}`);
  }
  return { content: [{ type: "text", text: "OK" }], details: {} };
}
```

**重要提示：** 对于字符串枚举，请使用 `@earendil-works/pi-ai` 中的 `StringEnum`。`Type.Union`/`Type.Literal` 不兼容 Google API。

**参数准备（Argument preparation）：** `prepareArguments(args)` 是可选的。如果定义了该方法，它会在 schema 验证及 `execute()` 之前执行。当 pi 恢复一个旧会话，其存储的工具调用参数不再匹配当前 schema 时，可使用此方法来模拟旧版本的输入形态。返回希望按 `parameters` 校验的对象。保持公共 schema 严格。不要为了让旧的恢复会话能在 `parameters` 中保留已过期的兼容字段。

示例：一个旧会话可能包含顶层结构为 `oldText` 和 `newText` 的 `edit` 工具调用，而当前 schema 只接受 `edits: [{ oldText, newText }]`。

```typescript
pi.registerTool({
  name: "edit",
  label: "Edit",
  description: "Edit a single file using exact text replacement",  // 使用精确文本替换编辑单个文件
  parameters: Type.Object({
    path: Type.String(),
    edits: Type.Array(
      Type.Object({
        oldText: Type.String(),
        newText: Type.String(),
      }),
    ),
  }),
  prepareArguments(args) {
    if (!args || typeof args !== "object") return args;

    const input = args as {
      path?: string;
      edits?: Array<{ oldText: string; newText: string }>;
      oldText?: unknown;
      newText?: unknown;
    };

    if (typeof input.oldText !== "string" || typeof input.newText !== "string") {
      return args;
    }

    return {
      ...input,
      edits: [...(input.edits ?? []), { oldText: input.oldText, newText: input.newText }],
    };
  },
  async execute(toolCallId, params, signal, onUpdate, ctx) {
    // params 现在匹配当前 schema
    return {
      content: [{ type: "text", text: `正在应用 ${params.edits.length} 个编辑块` }],
      details: {},
    };
  },
});
```

### 覆盖内置工具

扩展可以通过注册同名工具来覆盖内置工具（`read`、`bash`、`edit`、`write`、`grep`、`find`、`ls`）。发生此类情况时，交互模式会显示警告。

```bash
# 扩展的 read 工具替换内置 read
pi -e ./tool-override.ts
```

另外，也可以使用 `--no-builtin-tools` 在不加载任何内置工具的情况下启动，同时保留扩展工具功能：
```bash
# 无内置工具，仅有扩展工具
pi --no-builtin-tools -e ./my-extension.ts
```

参见 [examples/extensions/tool-override.ts](../examples/extensions/tool-override.ts)，其中包含一个使用日志记录和访问控制覆盖 `read` 的完整示例。

**渲染：** 内置渲染器的继承按槽位（slot）独立解析。执行覆盖和渲染覆盖相互独立。如果你的覆盖省略了 `renderCall`，将使用内置的 `renderCall`。如果你的覆盖省略了 `renderResult`，将使用内置的 `renderResult`。如果两者都省略，则自动使用内置渲染器（语法高亮、diff 等）。这使得你可以为日志记录或访问控制包装内置工具，而无需重新实现 UI。

**提示元数据（Prompt metadata）：** `promptSnippet` 和 `promptGuidelines` 不会从内置工具继承。如果希望你的覆盖保留这些提示指令，需要在覆盖中显式定义它们。

**你的实现必须匹配精确的结果形态**，包括 `details` 类型。UI 和会话逻辑依赖这些形态进行渲染和状态跟踪。

内置工具实现参考：
- [read.ts](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/core/tools/read.ts) - `ReadToolDetails`
- [bash.ts](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/core/tools/bash.ts) - `BashToolDetails`
- [edit.ts](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/core/tools/edit.ts)
- [write.ts](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/core/tools/write.ts)
- [grep.ts](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/core/tools/grep.ts) - `GrepToolDetails`
- [find.ts](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/core/tools/find.ts) - `FindToolDetails`
- [ls.ts](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/core/tools/ls.ts) - `LsToolDetails`

### 远程执行

内置工具支持可插拔的操作接口，用于将任务委托给远程系统（SSH、容器等）：

```typescript
import { createReadTool, createBashTool, type ReadOperations } from "@earendil-works/pi-coding-agent";

// Create tool with custom operations
const remoteRead = createReadTool(cwd, {
  operations: {
    readFile: (path) => sshExec(remote, `cat ${path}`),
    access: (path) => sshExec(remote, `test -r ${path}`).then(() => {}),
  }
});

// Register, checking flag at execution time
pi.registerTool({
  ...remoteRead,
  async execute(id, params, signal, onUpdate, _ctx) {
    const ssh = getSshConfig();
    if (ssh) {
      const tool = createReadTool(cwd, { operations: createRemoteOps(ssh) });
      return tool.execute(id, params, signal, onUpdate);
    }
    return localRead.execute(id, params, signal, onUpdate);
  },
});
```

**操作接口：** `ReadOperations`、`WriteOperations`、`EditOperations`、`BashOperations`、`LsOperations`、`GrepOperations`、`FindOperations`

对于 `user_bash`，扩展可以通过 `createLocalBashOperations()` 复用 pi 的本地 shell 后端，而无需重新实现本地进程派生（spawn）、shell 解析和进程树终止。

bash 工具还支持 spawn hook，用于在执行前调整命令、cwd 或 env：

```typescript
import { createBashTool } from "@earendil-works/pi-coding-agent";

const bashTool = createBashTool(cwd, {
  spawnHook: ({ command, cwd, env }) => ({
    command: `source ~/.profile\n${command}`,
    cwd: `/mnt/sandbox${cwd}`,
    env: { ...env, CI: "1" },
  }),
});
```

参见 [examples/extensions/ssh.ts](../examples/extensions/ssh.ts)，其中包含一个带 `--ssh` 标志的完整 SSH 示例。

### 输出截断

**工具必须对其输出进行截断**，以免压垮 LLM 上下文。大型输出可能导致：
- 上下文溢出错误（prompt 过长）
- 压缩（compaction）失败
- 模型性能下降

内置限制为 **50KB**（约 10k tokens）和 **2000 行**，以先到达者为准。可使用以下导出的截断工具：

```typescript
import {
  truncateHead,      // Keep first N lines/bytes (good for file reads, search results)
  truncateTail,      // Keep last N lines/bytes (good for logs, command output)
  truncateLine,      // Truncate a single line to maxBytes with ellipsis
  formatSize,        // Human-readable size (e.g., "50KB", "1.5MB")
  DEFAULT_MAX_BYTES, // 50KB
  DEFAULT_MAX_LINES, // 2000
} from "@earendil-works/pi-coding-agent";

async execute(toolCallId, params, signal, onUpdate, ctx) {
  const output = await runCommand();

  // Apply truncation
  const truncation = truncateHead(output, {
    maxLines: DEFAULT_MAX_LINES,
    maxBytes: DEFAULT_MAX_BYTES,
  });

  let result = truncation.content;

  if (truncation.truncated) {
    // Write full output to temp file
    const tempFile = writeTempFile(output);

    // Inform the LLM where to find complete output
    result += `\n\n[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines`;
    result += ` (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}).`;
    result += ` Full output saved to: ${tempFile}]`;
  }

  return { content: [{ type: "text", text: result }] };
}
```

**关键点：**
- 对开头重要的内容（搜索结果、文件读取）使用 `truncateHead`
**关键点：**
- 当输出被截断时，始终告知 LLM 并在哪里找到完整版本
- 在工具描述中记录截断限制

参见 [examples/extensions/truncated-tool.ts](../examples/extensions/truncated-tool.ts)，其中包含一个用正确截断方式包装 `rg`（ripgrep）的完整示例。

### 多工具注册

一个扩展可以注册多个共享状态的工具：

```typescript
export default function (pi: ExtensionAPI) {
  let connection = null;

  pi.registerTool({ name: "db_connect", ... });
  pi.registerTool({ name: "db_query", ... });
  pi.registerTool({ name: "db_close", ... });

  pi.on("session_shutdown", async () => {
    connection?.close();
  });
}
```

### 自定义渲染

工具可以提供 `renderCall` 和 `renderResult` 用于自定义 TUI 展示。完整组件 API 请参见 [tui.md](tui.md)，工具行的组合方式请参见 [tool-execution.ts](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/modes/interactive/components/tool-execution.ts)。

默认情况下，工具输出由 `Box` 包装，处理内边距和背景。已定义的 `renderCall` 或 `renderResult` 必须返回一个 `Component`。如果未定义某个槽位的渲染器，`tool-execution.ts` 将使用该槽位的回退渲染。

当工具应自行渲染 shell 而非使用默认 `Box` 时，请设置 `renderShell: "self"`。这对于需要对边框或背景行为有完全控制权的工具很有用，例如大型预览在工具结果稳定后必须保持视觉稳定的场景。

```typescript
pi.registerTool({
  name: "my_tool",
  label: "My Tool",
  description: "Custom shell example",
  parameters: Type.Object({}),
  renderShell: "self",
  async execute() {
    return { content: [{ type: "text", text: "ok" }], details: undefined };
  },
  renderCall(args, theme, context) {
    return new Text(theme.fg("accent", "my custom shell"), 0, 0);
  },
});
```

`renderCall` 和 `renderResult` 各自接收一个 `context` 对象，包含：
- `args` - 当前工具调用参数
- `state` - `renderCall` 和 `renderResult` 之间共享的行局部状态
- `lastComponent` - 该槽位之前返回的组件（如有）
- `invalidate()` - 请求重新渲染该工具行
- `toolCallId`、`cwd`、`executionStarted`、`argsComplete`、`isPartial`、`expanded`、`showImages`、`isError`

对跨槽位的共享状态使用 `context.state`。当你希望在多次渲染中复用和变更同一组件时，将槽位局部缓存保持在返回的组件实例上。

#### renderCall

渲染工具调用或头部信息：

```typescript
import { Text } from "@earendil-works/pi-tui";

renderCall(args, theme, context) {
  const text = (context.lastComponent as Text | undefined) ?? new Text("", 0, 0);
  let content = theme.fg("toolTitle", theme.bold("my_tool "));
  content += theme.fg("muted", args.action);
  if (args.text) {
    content += " " + theme.fg("dim", `"${args.text}"`);
  }
  text.setText(content);
  return text;
}
```

#### renderResult

渲染工具结果或输出：

```typescript
renderResult(result, { expanded, isPartial }, theme, context) {
  if (isPartial) {
    return new Text(theme.fg("warning", "Processing..."), 0, 0);
  }

  if (result.details?.error) {
    return new Text(theme.fg("error", `Error: ${result.details.error}`), 0, 0);
  }

  let text = theme.fg("success", "✓ Done");
  if (expanded && result.details?.items) {
    for (const item of result.details.items) {
      text += "\n  " + theme.fg("dim", item);
    }
  }
  return new Text(text, 0, 0);
}
```

如果某个槽位故意没有可见内容，则返回一个空的 `Component`，例如空 `Container`。

#### 键位提示（Keybinding Hints）

使用 `keyHint()` 显示遵循当前键位配置的键位提示：

```typescript
import { keyHint } from "@earendil-works/pi-coding-agent";

renderResult(result, { expanded }, theme, context) {
  let text = theme.fg("success", "✓ Done");
  if (!expanded) {
    text += ` (${keyHint("app.tools.expand", "to expand")})`;
  }
  return new Text(text, 0, 0);
}
```

可用函数：
- `keyHint(keybinding, description)` - 格式化已配置的键位 id，如 `"app.tools.expand"` 或 `"tui.select.confirm"`
- `keyText(keybinding)` - 返回键位 id 对应的原始配置键文本
- `rawKeyHint(key, description)` - 格式化原始键字符串

使用命名空间键位 id：
- Coding-agent id 使用 `app.*` 命名空间，例如 `app.tools.expand`、`app.editor.external`、`app.session.rename`
- 共享 TUI id 使用 `tui.*` 命名空间，例如 `tui.select.confirm`、`tui.select.cancel`、`tui.input.tab`

完整的键位 id 及默认值列表请参见 [keybindings.md](keybindings.md)。`keybindings.json` 使用相同的命名空间 id。

自定义编辑器和 `ctx.ui.custom()` 组件会接收 `keybindings: KeybindingsManager` 作为注入参数。它们应直接使用注入的管理器，而不是调用 `getKeybindings()` 或 `setKeybindings()`。

#### 最佳实践

- 使用 `Text` 并设置 padding 为 `(0, 0)`。默认的 Box 会处理内边距。
- 使用 `\n` 表示多行内容。
- 处理 `isPartial` 以应对流式进度。
- 支持 `expanded` 以实现按需展示详情。
- 保持默认视图紧凑。
- 在 `renderResult` 中读取 `context.args`，而不是将 args 复制到 `context.state` 中。
- 仅将 `context.state` 用于必须在调用和结果槽位之间共享的数据。
- 当同一组件实例可以原地更新时，复用 `context.lastComponent`。
- 仅在默认 box shell 妨碍时才使用 `renderShell: "self"`。在自 shell 模式下，工具需自行负责边框、内边距和背景。

#### 回退机制（Fallback）

如果某个槽位的渲染器未定义或抛出异常：
- `renderCall`：显示工具名称
- `renderResult`：显示 `content` 中的原始文本

## 自定义 UI

扩展可以通过 `ctx.ui` 方法与用户交互，并自定义消息/工具的渲染方式。

**关于自定义组件，请参见 [tui.md](tui.md)**，其中包含以下复制即用模式：
- 选择对话框（SelectList）
- 带取消功能的异步操作（BorderedLoader）
- 设置开关（SettingsList）
- 状态指示器（setStatus）
- 流式传输期间的工作消息、可见性和指示器（`setWorkingMessage`、`setWorkingVisible`、`setWorkingIndicator`）
- 编辑器上方/下方的小组件（setWidget）
- 在内置斜杠/路径补全之上叠加自动补全提供者（addAutocompleteProvider）
- 自定义页脚（setFooter）

### 对话框

```typescript
// 从选项中选择
const choice = await ctx.ui.select("Pick one:", ["A", "B", "C"]);

// 确认对话框
const ok = await ctx.ui.confirm("Delete?", "This cannot be undone");

// 文本输入
const name = await ctx.ui.input("Name:", "placeholder");

// 多行编辑器
const text = await ctx.ui.editor("Edit:", "prefilled text");

// 通知（非阻塞）
ctx.ui.notify("Done!", "info");  // "info" | "warning" | "error"
```

#### 带倒计时的限时对话框

对话框支持 `timeout` 选项，可在显示实时倒计时后自动关闭：

```typescript
// Dialog shows "Title (5s)" → "Title (4s)" → ... → auto-dismisses at 0
const confirmed = await ctx.ui.confirm(
  "Timed Confirmation",
  "This dialog will auto-cancel in 5 seconds. Confirm?",
  { timeout: 5000 }
);

if (confirmed) {
  // 用户已确认
} else {
  // 用户取消或超时
}
```

**超时时的返回值：**
- `select()` 返回 `undefined`
- `confirm()` 返回 `false`
- `input()` 返回 `undefined`

#### 使用 AbortSignal 手动关闭

如需更多控制（例如区分超时与用户取消），可使用 `AbortSignal`：

```typescript
const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), 5000);

const confirmed = await ctx.ui.confirm(
  "Timed Confirmation",
  "This dialog will auto-cancel in 5 seconds. Confirm?",
  { signal: controller.signal }
);

clearTimeout(timeoutId);

if (confirmed) {
  // 用户已确认
} else if (controller.signal.aborted) {
  // 对话框超时
} else {
  // 用户取消（按下 Escape 或选择 "No"）
}
```

完整示例请参见 [examples/extensions/timed-confirm.ts](../examples/extensions/timed-confirm.ts)。

### 小组件、状态和页脚

```typescript
// 页脚状态（持续到被清除为止）
ctx.ui.setStatus("my-ext", "Processing...");
ctx.ui.setStatus("my-ext", undefined);  // 清除

// 工作加载器（流式传输期间显示）
ctx.ui.setWorkingMessage("Thinking deeply...");
ctx.ui.setWorkingMessage();  // 恢复默认
ctx.ui.setWorkingVisible(false);  // 完全隐藏内置工作加载器行
ctx.ui.setWorkingVisible(true);   // 显示内置工作加载器行

// 工作指示器（流式传输期间显示）
ctx.ui.setWorkingIndicator({ frames: [ctx.ui.theme.fg("accent", "●")] });  // 静态圆点
ctx.ui.setWorkingIndicator({
  frames: [
    ctx.ui.theme.fg("dim", "·"),
    ctx.ui.theme.fg("muted", "•"),
    ctx.ui.theme.fg("accent", "●"),
    ctx.ui.theme.fg("muted", "•"),
  ],
  intervalMs: 120,
});
ctx.ui.setWorkingIndicator({ frames: [] });  // 隐藏指示器
ctx.ui.setWorkingIndicator();  // 恢复默认旋转指示器

// 编辑器上方小组件（默认）
ctx.ui.setWidget("my-widget", ["Line 1", "Line 2"]);
// 编辑器下方小组件
ctx.ui.setWidget("my-widget", ["Line 1", "Line 2"], { placement: "belowEditor" });
ctx.ui.setWidget("my-widget", (tui, theme) => new Text(theme.fg("accent", "Custom"), 0, 0));
ctx.ui.setWidget("my-widget", undefined);  // 清除

// 自定义页脚（完全替换内置页脚）
ctx.ui.setFooter((tui, theme) => ({
  render(width) { return [theme.fg("dim", "Custom footer")]; },
  invalidate() {},
}));
ctx.ui.setFooter(undefined);  // 恢复内置页脚

// 终端标题
ctx.ui.setTitle("pi - my-project");

// 编辑器文本
ctx.ui.setEditorText("Prefill text");
const current = ctx.ui.getEditorText();

// 粘贴到编辑器（触发粘贴处理，包括大型内容的折叠）
ctx.ui.pasteToEditor("pasted content");

// 在内置提供者之上叠加自定义自动补全行为
ctx.ui.addAutocompleteProvider((current) => ({
  triggerCharacters: ["#"],
  async getSuggestions(lines, line, col, options) {
    const beforeCursor = (lines[line] ?? "").slice(0, col);
    const match = beforeCursor.match(/(?:^|[ \t])#([^\s#]*)$/);
    if (!match) {
      return current.getSuggestions(lines, line, col, options);
    }

    return {
      prefix: `#${match[1] ?? ""}`,
      items: [{ value: "#2983", label: "#2983", description: "Extension API for autocomplete" }],
    };
  },
  applyCompletion(lines, line, col, item, prefix) {
    return current.applyCompletion(lines, line, col, item, prefix);
  },
  shouldTriggerFileCompletion(lines, line, col) {
    return current.shouldTriggerFileCompletion?.(lines, line, col) ?? true;
  },
}));

// 工具输出展开
const wasExpanded = ctx.ui.getToolsExpanded();
ctx.ui.setToolsExpanded(true);
ctx.ui.setToolsExpanded(wasExpanded);

// Custom editor (vim mode, emacs mode, etc.)
ctx.ui.setEditorComponent((tui, theme, keybindings) => new VimEditor(tui, theme, keybindings));
const currentEditor = ctx.ui.getEditorComponent();
ctx.ui.setEditorComponent((tui, theme, keybindings) =>
  new WrappedEditor(tui, theme, keybindings, currentEditor?.(tui, theme, keybindings))
);
ctx.ui.setEditorComponent(undefined);  // Restore default editor

// Theme management (see themes.md for creating themes)
const themes = ctx.ui.getAllThemes();  // [{ name: "dark", path: "/..." | undefined }, ...]
const lightTheme = ctx.ui.getTheme("light");  // Load without switching
const result = ctx.ui.setTheme("light");  // Switch by name
if (!result.success) {
  ctx.ui.notify(`Failed: ${result.error}`, "error");
}
ctx.ui.setTheme(lightTheme!);  // Or switch by Theme object
ctx.ui.theme.fg("accent", "styled text");  // Access current theme
```

自定义工作指示器帧按原样渲染。如需颜色，请自行将颜色添加到帧字符串中，例如使用 `ctx.ui.theme.fg(...)`。

### 自动补全提供者

使用 `ctx.ui.addAutocompleteProvider()` 在内置斜杠命令和路径提供者之上叠加自定义自动补全逻辑。为自定义自然触发字符（如 `$`）设置 `triggerCharacters`。

典型模式：

- 检查光标前的文本
- 当语法匹配扩展特有语法时返回自定义建议
- 否则委托给 `current.getSuggestions(...)`
- 委托 `applyCompletion(...)`，除非你需要自定义插入行为

```typescript
pi.on("session_start", (_event, ctx) => {
  ctx.ui.addAutocompleteProvider((current) => ({
    triggerCharacters: ["#"],
    async getSuggestions(lines, cursorLine, cursorCol, options) {
      const line = lines[cursorLine] ?? "";
      const beforeCursor = line.slice(0, cursorCol);
      const match = beforeCursor.match(/(?:^|[ \t])#([^\s#]*)$/);
      if (!match) {
        return current.getSuggestions(lines, cursorLine, cursorCol, options);
      }

      return {
        prefix: `#${match[1] ?? ""}`,
        items: [
          { value: "#2983", label: "#2983", description: "扩展 API：注册自定义 @ 自动补全提供者" },
          { value: "#2753", label: "#2753", description: "重新加载过时资源设置" },
        ],
      };
    },

    applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
      return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
    },

    shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
      return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
    },
  }));
});
```

参见 [github-issue-autocomplete.ts](../examples/extensions/github-issue-autocomplete.ts)，其中包含一个完整示例：通过 `gh issue list` 预加载最近的开放 GitHub issues，并在本地过滤以实现快速的 `#...` 补全。该示例依赖 GitHub CLI（`gh`）以及一个 GitHub 仓库的检出（checkout）。

### 自定义组件

对于复杂 UI，可使用 `ctx.ui.custom()`。该方法会临时用你的组件替换编辑器，直到调用 `done()` 为止：

```typescript
import { Text, Component } from "@earendil-works/pi-tui";

const result = await ctx.ui.custom<boolean>((tui, theme, keybindings, done) => {
  const text = new Text("Press Enter to confirm, Escape to cancel", 1, 1);

  text.onKey = (key) => {
    if (key === "return") done(true);
    if (key === "escape") done(false);
    return true;
  };

  return text;
});

if (result) {
  // 用户按下了 Enter
}
```

回调函数接收：
- `tui` - TUI 实例（用于屏幕尺寸、焦点管理）
- `theme` - 当前主题，用于样式设置
- `keybindings` - 应用键位管理器（用于检查快捷键）
- `done(value)` - 调用以关闭组件并返回值

参见 [tui.md](tui.md) 了解完整的组件 API。

#### 覆盖模式（Overlay Mode，实验性）

传入 `{ overlay: true }` 将组件渲染为悬浮模态框，覆盖在现有内容之上，而不清屏：

```typescript
const result = await ctx.ui.custom<string | null>(
  (tui, theme, keybindings, done) => new MyOverlayComponent({ onClose: done }),
  { overlay: true }
);
```

对于高级定位（锚点、边距、百分比、响应式可见性），可传入 `overlayOptions`。使用 `onHandle` 以编程方式控制焦点或可见性：

```typescript
const result = await ctx.ui.custom<string | null>(
  (tui, theme, keybindings, done) => new MyOverlayComponent({ onClose: done }),
  {
    overlay: true,
    overlayOptions: { anchor: "top-right", width: "50%", margin: 2 },
    onHandle: (handle) => {
      handle.focus(); // 聚焦此覆盖层并将其置于视觉最前方
      // handle.unfocus({ target: editorComponent }); // 将输入释放给指定组件
      // handle.setHidden(true/false); // 切换可见性
      // handle.hide(); // 永久移除
    }
  }
);
```

已聚焦的可见覆盖层可以在临时非覆盖自定义 UI 关闭后重新获取输入。如果你希望另一个组件在覆盖层保持可见的同时继续接收输入，请调用 `handle.unfocus({ target })`。传入 `{ target: null }` 会释放覆盖层而不聚焦其他组件。

完整的 `OverlayOptions` 和 `OverlayHandle` API 请参见 [tui.md](tui.md)，示例请参见 [overlay-qa-tests.ts](../examples/extensions/overlay-qa-tests.ts)。

### 自定义编辑器

使用自定义实现（vim 模式、emacs 模式等）替换主输入编辑器：

```typescript
import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey } from "@earendil-works/pi-tui";

class VimEditor extends CustomEditor {
  private mode: "normal" | "insert" = "insert";

  handleInput(data: string): void {
    if (matchesKey(data, "escape") && this.mode === "insert") {
      this.mode = "normal";
      return;
    }
    if (this.mode === "normal" && data === "i") {
      this.mode = "insert";
      return;
    }
    super.handleInput(data);  // 应用键位绑定 + 文本编辑
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setEditorComponent((_tui, theme, keybindings) =>
      new VimEditor(theme, keybindings)
    );
  });
}
```

**关键点：**
- 继承 `CustomEditor`（而非基础 `Editor`）以获取应用键位绑定（escape 取消、ctrl+d、模型切换）
- 对不处理的按键调用 `super.handleInput(data)`
- 工厂函数从应用接收 `theme` 和 `keybindings`
- 在 `setEditorComponent()` 之前使用 `ctx.ui.getEditorComponent()` 以包装先前配置的自定义编辑器
- 传入 `undefined` 可恢复默认：`ctx.ui.setEditorComponent(undefined)`

要与已替换编辑器的另一个扩展组合，请在设置你的工厂之前先捕获前一个工厂：

```typescript
const previous = ctx.ui.getEditorComponent();
ctx.ui.setEditorComponent((tui, theme, keybindings) =>
  new MyEditor(tui, theme, keybindings, { base: previous?.(tui, theme, keybindings) })
);
```

带模式指示器的完整示例请参见 [tui.md](tui.md) Pattern 7。

### 消息与条目渲染

为你的 `customType` 注册自定义消息渲染器。对需要参与 LLM 上下文的内容使用消息渲染器：

```typescript
import { Text } from "@earendil-works/pi-tui";

pi.registerMessageRenderer("my-extension", (message, options, theme) => {
  const { expanded } = options;
  let text = theme.fg("accent", `[${message.customType}] `);
  text += message.content;

  if (expanded && message.details) {
    text += "\n" + theme.fg("dim", JSON.stringify(message.details, null, 2));
  }

  return new Text(text, 0, 0);
});
```

消息通过 `pi.sendMessage()` 发送：

```typescript
pi.sendMessage({
  customType: "my-extension",  // 与 registerMessageRenderer 对应
  content: "Status update",
  display: true,               // 在 TUI 中显示
  details: { ... },            // 在渲染器中可用
});
```

对于不应发送给 LLM 的纯 TUI 内容，应渲染自定义条目：

```typescript
pi.registerEntryRenderer("my-card", (entry, options, theme) => {
  return new Text(theme.fg("accent", JSON.stringify(entry.data)));
});

pi.appendEntry("my-card", { status: "done" });
```

### 主题颜色

所有渲染函数都会接收一个 `theme` 对象。创建自定义主题和完整调色板请参见 [themes.md](themes.md)。

```typescript
// 前景色
theme.fg("toolTitle", text)   // 工具名称
theme.fg("accent", text)      // 高亮
theme.fg("success", text)     // 成功（绿色）
theme.fg("error", text)       // 错误（红色）
theme.fg("warning", text)     // 警告（黄色）
theme.fg("muted", text)       // 次要文本
theme.fg("dim", text)         // 三级文本

// 文本样式
theme.bold(text)
theme.italic(text)
theme.strikethrough(text)
```

在自定义工具渲染器中进行语法高亮：

```typescript
import { highlightCode, getLanguageFromPath } from "@earendil-works/pi-coding-agent";

// 使用指定语言高亮代码
const highlighted = highlightCode("const x = 1;", "typescript", theme);

// 从文件路径自动检测语言
const lang = getLanguageFromPath("/path/to/file.rs");  // "rust"
const highlighted = highlightCode(code, lang, theme);
```

## 错误处理

- 扩展错误会被记录，agent 继续运行
- `tool_call` 错误会阻塞工具（fail-safe）
- 工具 `execute` 中的错误必须通过抛出异常来信号化；抛出的错误会被捕获，以 `isError: true` 报告给 LLM，然后执行继续

## 模式行为

| 模式 | `ctx.mode` | `ctx.hasUI` | 说明 |
|------|------------|-------------|------|
| 交互模式（Interactive） | `"tui"` | `true` | 带终端渲染的完整 TUI |
| RPC（`--mode rpc`） | `"rpc"` | `true` | 通过 JSON 协议实现对话框和通知；`custom()` 返回 `undefined`。参见 [rpc.md](rpc.md) |
| JSON（`--mode json`） | `"json"` | `false` | 事件流输出到 stdout；UI 方法为空操作 |
| 打印模式（Print，`-p`） | `"print"` | `false` | 扩展可运行但无法提示用户 |

在使用 TUI 专属功能（`custom()`、组件工厂、终端输入）之前请检查 `ctx.mode === "tui"`。在使用同时适用于 TUI 和 RPC 模式的对话框和通知方法之前请检查 `ctx.hasUI`。

## 示例参考

所有示例位于 [examples/extensions/](../examples/extensions/)。

| 示例 | 说明 | 关键 API |
|---------|-------------|----------|
| **工具** |||
| `hello.ts` | 最基本的工具注册 | `registerTool` |
| `question.ts` | 带用户交互的工具 | `registerTool`, `ui.select` |
| `questionnaire.ts` | 多步骤向导工具 | `registerTool`, `ui.custom` |
| `todo.ts` | 带持久化的有状态工具 | `registerTool`, `appendEntry`, `renderResult`, session events |
| `dynamic-tools.ts` | 启动后及命令执行中注册工具 | `registerTool`, `session_start`, `registerCommand` |
| `structured-output.ts` | 带 `terminate: true` 的最终结构化输出工具 | `registerTool`, terminating tool results |
| `truncated-tool.ts` | 输出截断示例 | `registerTool`, `truncateHead` |
| `tool-override.ts` | 覆盖内置 read 工具 | `registerTool`（与内置同名） |
| **命令** |||
| `pirate.ts` | 每轮修改系统提示 | `registerCommand`, `before_agent_start` |
| `summarize.ts` | 对话摘要命令 | `registerCommand`, `ui.custom` |
| `handoff.ts` | 跨提供商模型切换 | `registerCommand`, `ui.editor`, `ui.custom` |
| `qna.ts` | 带自定义 UI 的问答 | `registerCommand`, `ui.custom`, `setEditorText` |
| `send-user-message.ts` | 注入用户消息 | `registerCommand`, `sendUserMessage` |
| `reload-runtime.ts` | 重载命令和 LLM 工具切换 | `registerCommand`, `ctx.reload()`, `sendUserMessage` |
| `shutdown-command.ts` | 优雅关闭命令 | `registerCommand`, `shutdown()` |
| **事件与门禁** |||
| `permission-gate.ts` | 阻止危险命令 | `on("tool_call")`, `ui.confirm` |
| `project-trust.ts` | 从用户/全局或 CLI 扩展决定或推迟项目信任 | `on("project_trust")`, trust UI, required trust result |
| `protected-paths.ts` | 阻止对特定路径的写入 | `on("tool_call")` |
| `confirm-destructive.ts` | 确认会话变更 | `on("session_before_switch")`, `on("session_before_fork")` |
| `dirty-repo-guard.ts` | 脏 git 仓库警告 | `on("session_before_*")`, `exec` |
| `input-transform.ts` | 转换用户输入 | `on("input")` |
| `input-transform-streaming.ts` | 感知流式传输的输入转换 | `on("input")`, `streamingBehavior` |
| `model-status.ts` | 响应模型变更 | `on("model_select")`, `setStatus` |
| `provider-payload.ts` | 检查载荷和提供商响应头 | `on("before_provider_request")`, `on("after_provider_response")` |
| `system-prompt-header.ts` | 显示系统提示信息 | `on("agent_start")`, `getSystemPrompt` |
| `claude-rules.ts` | 从文件加载规则 | `on("session_start")`, `on("before_agent_start")` |
| `prompt-customizer.ts` | 使用 `systemPromptOptions` 添加上下文感知的工具引导 | `on("before_agent_start")`, `BuildSystemPromptOptions` |
| `file-trigger.ts` | 文件监听触发消息 | `sendMessage` |
| **压缩与会话** |||
| `custom-compaction.ts` | 自定义压缩摘要 | `on("session_before_compact")` |
| `trigger-compact.ts` | 手动触发压缩 | `compact()` |
| `git-checkpoint.ts` | 每轮 Git stash | `on("turn_start")`, `on("session_before_fork")`, `exec` |
| `git-merge-and-resolve.ts` | 获取、合并并解决冲突 | `on("agent_end")`, `exec`, `sendUserMessage` |
| `auto-commit-on-exit.ts` | 关闭时自动提交 | `on("session_shutdown")`, `exec` |
| **UI 组件** |||
| `status-line.ts` | 页脚状态指示器 | `setStatus`, session events |
| `working-indicator.ts` | 自定义流式工作指示器 | `setWorkingIndicator`, `registerCommand` |
| `github-issue-autocomplete.ts` | 通过 `gh issue list` 预加载最近的开放 issues，在内置自动补全之上添加 `#1234` issue 补全 | `addAutocompleteProvider`, `on("session_start")`, `exec` |
| `custom-footer.ts` | 完全替换页脚 | `registerCommand`, `setFooter` |
| `custom-header.ts` | 替换启动头部 | `on("session_start")`, `setHeader` |
| `modal-editor.ts` | Vim 风格模态编辑器 | `setEditorComponent`, `CustomEditor` |
| `rainbow-editor.ts` | 自定义编辑器样式 | `setEditorComponent` |
| `widget-placement.ts` | 编辑器上方/下方小组件 | `setWidget` |
| `overlay-test.ts` | 覆盖层组件 | 带 overlay 选项的 `ui.custom` |
| `overlay-qa-tests.ts` | 全面覆盖层测试 | `ui.custom`，所有 overlay 选项 |
| `notify.ts` | 简单通知 | `ui.notify` |
| `timed-confirm.ts` | 带超时的对话框 | `ui.confirm` with timeout/signal |
| `mac-system-theme.ts` | 自动切换主题 | `setTheme`, `exec` |
| **复杂扩展** |||
| `plan-mode/` | 完整的计划模式实现 | 所有事件类型、`registerCommand`、`registerShortcut`、`registerFlag`、`setStatus`、`setWidget`、`sendMessage`、`setActiveTools` |
| `preset.ts` | 可保存的预设（模型、工具、思考级别） | `registerCommand`、`registerShortcut`、`registerFlag`、`setModel`、`setActiveTools`、`setThinkingLevel`、`appendEntry` |
| `tools.ts` | 工具开关 UI | `registerCommand`、`setActiveTools`、`SettingsList`、session events |
| **远程与沙箱** |||
| `ssh.ts` | SSH 远程执行 | `registerFlag`、`on("user_bash")`、`on("before_agent_start")`、tool operations |
| `interactive-shell.ts` | 持久化 shell 会话 | `on("user_bash")` |
| `sandbox/` | 沙箱化工具执行 | Tool operations |
| `gondolin/` | 将内置工具和 `!` 命令路由到 Gondolin 微虚拟机 | Tool operations, built-in tool overrides, `on("user_bash")` |
| `subagent/` | 派生子 agent | `registerTool`, `exec` |
| **游戏** |||
| `snake.ts` | 贪吃蛇游戏 | `registerCommand`、`ui.custom`、键盘处理 |
| `space-invaders.ts` | 太空侵略者游戏 | `registerCommand`、`ui.custom` |
| `doom-overlay/` | 覆盖层中的 Doom | `ui.custom` with overlay |
| **提供商（Providers）** |||
| `custom-provider-anthropic/` | 自定义 Anthropic 代理 | `registerProvider` |
| `custom-provider-gitlab-duo/` | GitLab Duo 集成 | `registerProvider` with OAuth |
| **消息与通信** |||
| `message-renderer.ts` | 自定义消息渲染 | `registerMessageRenderer`、`sendMessage` |
| `entry-renderer.ts` | 纯 TUI 自定义条目渲染 | `registerEntryRenderer`、`appendEntry` |
| `event-bus.ts` | 扩展间事件 | `pi.events` |
| **会话元数据** |||
| `session-name.ts` | 为选择器命名会话 | `setSessionName`、`getSessionName` |
| `bookmark.ts` | 为 /tree 设置条目书签 | `setLabel` |
| **杂项（Misc）** |||
| `inline-bash.ts` | 工具调用中的内联 bash | `on("tool_call")` |
| `bash-spawn-hook.ts` | 执行前调整 bash 命令、cwd 和 env | `createBashTool`、`spawnHook` |
| `with-deps/` | 带 npm 依赖的扩展 | 包含 `package.json` 的包结构 |
