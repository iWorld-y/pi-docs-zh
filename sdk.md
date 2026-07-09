> pi 可以帮你使用 SDK。让它为你的使用场景构建集成方案。

# SDK

SDK 提供了对 pi 智能体（agent）能力的编程访问。可将其用于在其他应用中嵌入 pi、构建自定义界面，或集成到自动化工作流中。

**示例使用场景：**
- 构建自定义 UI（Web、桌面、移动端）
- 将智能体能力集成到现有应用中
- 创建带有智能体推理能力的自动化流水线
- 构建可生成子智能体（sub-agent）的自定义工具
- 以编程方式测试智能体行为

可查看 [examples/sdk/](../examples/sdk/) 获取从最小化示例到完整控制的工作示例。

## 快速开始

```typescript
import { AuthStorage, createAgentSession, ModelRegistry, SessionManager } from "@earendil-works/pi-coding-agent";

// 设置凭据存储和模型注册表
const authStorage = AuthStorage.create();
const modelRegistry = ModelRegistry.create(authStorage);

const { session } = await createAgentSession({
  sessionManager: SessionManager.inMemory(),
  authStorage,
  modelRegistry,
});

session.subscribe((event) => {
  if (event.type === "message_update" && event.assistantMessageEvent.type === "text_delta") {
    process.stdout.write(event.assistantMessageEvent.delta);
  }
});

await session.prompt("当前目录下有哪些文件？");
```

## 安装

```bash
npm install @earendil-works/pi-coding-agent
```

SDK 已包含在主包中，无需单独安装。

## 核心概念

### createAgentSession()

用于创建单个 `AgentSession` 的主工厂函数。

`createAgentSession()` 使用 `ResourceLoader` 来提供扩展（extensions）、技能（skills）、提示模板（prompt templates）、主题（themes）和上下文文件（context files）。如果未提供，则使用带有标准发现机制的 `DefaultResourceLoader`。

```typescript
import { createAgentSession, SessionManager } from "@earendil-works/pi-coding-agent";

// 最小化：使用 DefaultResourceLoader 的默认值
const { session } = await createAgentSession();

// 自定义：覆盖特定选项
const { session } = await createAgentSession({
  model: myModel,
  tools: ["read", "bash"],
  sessionManager: SessionManager.inMemory(),
});
```

### AgentSession

会话管理智能体生命周期、消息历史、模型状态、压缩（compaction）和事件流。

```typescript
interface AgentSession {
  // 发送提示并等待完成
  prompt(text: string, options?: PromptOptions): Promise<void>;

  // 在流式传输期间排队消息
  steer(text: string): Promise<void>;
  followUp(text: string): Promise<void>;

  // 订阅事件（返回取消订阅函数）
  subscribe(listener: (event: AgentSessionEvent) => void): () => void;

  // 会话信息
  sessionFile: string | undefined;
  sessionId: string;

  // 模型控制
  setModel(model: Model): Promise<void>;
  setThinkingLevel(level: ThinkingLevel): void;
  cycleModel(): Promise<ModelCycleResult | undefined>;
  cycleThinkingLevel(): ThinkingLevel | undefined;

  // 状态访问
  agent: Agent;
  model: Model | undefined;
  thinkingLevel: ThinkingLevel;
  messages: AgentMessage[];
  isStreaming: boolean;

  // 在当前会话文件中进行原地树导航
  navigateTree(targetId: string, options?: { summarize?: boolean; customInstructions?: string; replaceInstructions?: boolean; label?: string }): Promise<{ editorText?: string; cancelled: boolean }>;

  // 压缩
  compact(customInstructions?: string): Promise<CompactionResult>;
  abortCompaction(): void;

  // 中止当前操作
  abort(): Promise<void>;

  // 清理
  dispose(): void;
}
```

new-session、resume、fork 和 import 等会话替换 API 位于 `AgentSessionRuntime` 上，而非 `AgentSession` 上。

### createAgentSessionRuntime() 与 AgentSessionRuntime

当需要替换活动会话并重建绑定到 cwd 的运行时状态时使用运行时 API。这是内置的交互式（interactive）、打印（print）和 RPC 模式所使用的同一层。

`createAgentSessionRuntime()` 接收一个运行时工厂以及初始的 cwd/会话目标。该工厂闭包捕获进程全局固定输入，为有效的 cwd 重新创建绑定到 cwd 的服务，根据这些服务解析会话选项，并返回完整的运行时结果。

```typescript
import {
  type CreateAgentSessionRuntimeFactory,
  createAgentSessionFromServices,
  createAgentSessionRuntime,
  createAgentSessionServices,
  getAgentDir,
  SessionManager,
} from "@earendil-works/pi-coding-agent";

const createRuntime: CreateAgentSessionRuntimeFactory = async ({ cwd, sessionManager, sessionStartEvent }) => {
  const services = await createAgentSessionServices({ cwd });
  return {
    ...(await createAgentSessionFromServices({
      services,
      sessionManager,
      sessionStartEvent,
    })),
    services,
    diagnostics: services.diagnostics,
  };
};

const runtime = await createAgentSessionRuntime(createRuntime, {
  cwd: process.cwd(),
  agentDir: getAgentDir(),
  sessionManager: SessionManager.create(process.cwd()),
});
```

`AgentSessionRuntime` 负责在以下操作中替换活动运行时：

- `newSession()`
- `switchSession()`
- `fork()`
- 通过 `fork(entryId, { position: "at" })` 的克隆流程
- `importFromJsonl()`

重要行为：

- 上述操作后 `runtime.session` 会发生变化
- 事件订阅绑定到特定的 `AgentSession`，因此替换后需要重新订阅
- 如果使用了扩展，需要为新会话再次调用 `runtime.session.bindExtensions(...)`
- 创建时会在 `runtime.diagnostics` 上返回诊断信息
- 如果运行时创建或替换失败，方法会抛出异常，由调用方决定如何处理

```typescript
let session = runtime.session;
let unsubscribe = session.subscribe(() => {});

await runtime.newSession();

unsubscribe();
session = runtime.session;
unsubscribe = session.subscribe(() => {});
```

### 提示与消息排队

`PromptOptions` 控制提示展开、流式传输期间的排队行为以及提示预检通知：

```typescript
interface PromptOptions {
  expandPromptTemplates?: boolean;
  images?: ImageContent[];
  streamingBehavior?: "steer" | "followUp";
  source?: InputSource;
  preflightResult?: (success: boolean) => void;
}
```

`preflightResult` 每次调用 `prompt()` 时触发一次：

- 当提示被接受、排队或立即处理时为 `true`
- 当提示在预检阶段被拒绝时为 `false`

它在 `prompt()` 解析之前触发。`prompt()` 仍然只在整个已接受的运行（包括重试）完成后才解析。接受后的失败通过正常的事件和消息流报告，而非通过 `preflightResult(false)`。

`prompt()` 方法处理提示模板、扩展命令和消息发送：

```typescript
// 基本提示（非流式传输时）
await session.prompt("这里有哪些文件？");

// 带图片
await session.prompt("这张图片里有什么？", {
  images: [{ type: "image", source: { type: "base64", mediaType: "image/png", data: "..." } }]
});

// 流式传输期间：必须指定消息排队方式
await session.prompt("停下来改做这件事", { streamingBehavior: "steer" });
await session.prompt("完成后，也检查一下 X", { streamingBehavior: "followUp" });
```

**行为：**
- **扩展命令**（如 `/mycommand`）：立即执行，即使在流式传输期间也如此。它们通过 `pi.sendMessage()` 管理自己的 LLM 交互。
- **基于文件的提示模板**（来自 `.md` 文件）：在发送或排队之前展开为其内容。
- **流式传输期间未指定 `streamingBehavior`**：抛出错误。直接使用 `steer()` 或 `followUp()`，或指定该选项。
- **`preflightResult(true)`**：表示提示已被接受、排队或立即处理。
- **`preflightResult(false)`**：表示预检在拒绝接受之前已拒绝。

流式传输期间显式排队：

```typescript
// 排队一条转向消息，在当前助手轮次完成其工具调用后投递
await session.steer("新指令");

// 等待智能体完成（仅在智能体停止时投递）
await session.followUp("完成后，也做这件事");
```

`steer()` 和 `followUp()` 都会展开基于文件的提示模板，但对扩展命令会报错（扩展命令不能被排队）。

### Agent 与 AgentState

`Agent` 类（来自 `@earendil-works/pi-agent-core`）处理核心 LLM 交互。通过 `session.agent` 访问。

```typescript
// 访问当前状态
const state = session.agent.state;

// state.messages: AgentMessage[] - 对话历史
// state.model: Model - 当前模型
// state.thinkingLevel: ThinkingLevel - 当前思考级别
// state.systemPrompt: string - 系统提示
// state.tools: AgentTool[] - 可用工具
// state.streamingMessage?: AgentMessage - 当前部分助手消息
// state.errorMessage?: string - 最新助手错误

// 替换消息（用于分支或恢复）
session.agent.state.messages = messages; // 复制顶层数组

// 替换工具
session.agent.state.tools = tools; // 复制顶层数组

// 等待智能体完成处理
await session.agent.waitForIdle();
```

### 事件

订阅事件以接收流式输出和生命周期通知。

```typescript
session.subscribe((event) => {
  switch (event.type) {
    // 来自助手的流式文本
    case "message_update":
      if (event.assistantMessageEvent.type === "text_delta") {
        process.stdout.write(event.assistantMessageEvent.delta);
      }
      if (event.assistantMessageEvent.type === "thinking_delta") {
        // 思考输出（如果启用了思考）
      }
      break;

    // 工具执行
    case "tool_execution_start":
      console.log(`工具：${event.toolName}`);
      break;
    case "tool_execution_update":
      // 流式工具输出
      break;
    case "tool_execution_end":
      console.log(`结果：${event.isError ? "错误" : "成功"}`);
      break;

    // 消息生命周期
    case "message_start":
      // 新消息开始
      break;
    case "message_end":
      // 消息完成
      break;

    // 智能体生命周期
    case "agent_start":
      // 智能体开始处理提示
      break;
    case "agent_end":
      // 智能体完成（event.messages 包含新消息）
      break;

    // 轮次生命周期（一次 LLM 响应 + 工具调用）
    case "turn_start":
      break;
    case "turn_end":
      // event.message: 助手响应
      // event.toolResults: 本轮的工具结果
      break;

    // 会话事件（排队、压缩、重试）
    case "queue_update":
      console.log(event.steering, event.followUp);
      break;
    case "compaction_start":
    case "compaction_end":
    case "auto_retry_start":
    case "auto_retry_end":
      break;
  }
});
```

## 选项参考

### 目录

```typescript
const { session } = await createAgentSession({
  // DefaultResourceLoader 发现的工作目录
  cwd: process.cwd(), // 默认值

  // 全局配置目录
  agentDir: "~/.pi/agent", // 默认值（展开 ~）
});
```

`cwd` 被 `DefaultResourceLoader` 用于：
- 项目扩展（`.pi/extensions/`）
- 项目技能：
  - `.pi/skills/`
  - `cwd` 及其祖先目录中的 `.agents/skills/`（向上直到 git 仓库根目录，或不在仓库中时到文件系统根目录）
- 项目提示（`.pi/prompts/`）
- 上下文文件（从 cwd 向上遍历的 `AGENTS.md`）
- 会话目录命名

`agentDir` 被 `DefaultResourceLoader` 用于：
- 全局扩展（`extensions/`）
- 全局技能：
  - `agentDir` 下的 `skills/`（例如 `~/.pi/agent/skills/`）
  - `~/.agents/skills/`
- 全局提示（`prompts/`）
- 全局上下文文件（`AGENTS.md`）
- 设置（`settings.json`）
- 自定义模型（`models.json`）
- 凭据（`auth.json`）
- 会话（`sessions/`）

当传入自定义 `ResourceLoader` 时，`cwd` 和 `agentDir` 不再控制资源发现。它们仍然影响会话命名和工具路径解析。

### 模型

```typescript
import { getModel } from "@earendil-works/pi-ai";
import { AuthStorage, ModelRegistry } from "@earendil-works/pi-coding-agent";

const authStorage = AuthStorage.create();
const modelRegistry = ModelRegistry.create(authStorage);

// 查找特定内置模型（不检查 API key 是否存在）
const opus = getModel("anthropic", "claude-opus-4-5");
if (!opus) throw new Error("未找到模型");

// 通过 provider/id 查找任意模型，包括 models.json 中的自定义模型
// （不检查 API key 是否存在）
const customModel = modelRegistry.find("my-provider", "my-model");

// 仅获取已配置有效 API key 的模型
const available = await modelRegistry.getAvailable();

const { session } = await createAgentSession({
  model: opus,
  thinkingLevel: "medium", // off, minimal, low, medium, high, xhigh

  // 用于循环切换的模型（交互模式中的 Ctrl+P）
  scopedModels: [
    { model: opus, thinkingLevel: "high" },
    { model: haiku, thinkingLevel: "off" },
  ],

  authStorage,
  modelRegistry,
});
```

如果未提供模型：
1. 尝试从会话恢复（如果是继续会话）
2. 使用设置中的默认值
3. 回退到第一个可用模型

要匹配 CLI 模型解析，使用导出的解析器辅助函数：

```typescript
import {
  resolveCliModel,
  resolveModelScopeWithDiagnostics,
} from "@earendil-works/pi-coding-agent";

const cliModel = resolveCliModel({
  cliModel: "anthropic/claude-opus-4-5:high",
  modelRegistry,
});
if (cliModel.error) throw new Error(cliModel.error);
if (cliModel.warning) console.warn(cliModel.warning);

const { scopedModels, diagnostics } = await resolveModelScopeWithDiagnostics(
  ["anthropic/*:high", "gpt-5"],
  modelRegistry,
);
for (const diagnostic of diagnostics) {
  console.warn(diagnostic.message);
}
```

`resolveCliModel()` 使用所有已注册的模型，以便 `--api-key` 风格的首次设置能在存储的凭据存在之前解析模型。`resolveModelScopeWithDiagnostics()` 匹配 `--models` 和 `enabledModels` 语义，同时返回警告而非打印它们。

> 参见 [examples/sdk/02-custom-model.ts](../examples/sdk/02-custom-model.ts)

### API Keys 与 OAuth

API key 解析优先级（由 AuthStorage 处理）：
1. 运行时覆盖（通过 `setRuntimeApiKey`，不持久化）
2. `auth.json` 中存储的凭据（API key 或 OAuth token）
3. 环境变量（`ANTHROPIC_API_KEY`、`OPENAI_API_KEY` 等）
4. 回退解析器（用于 `models.json` 中的自定义 provider key）

```typescript
import { AuthStorage, ModelRegistry } from "@earendil-works/pi-coding-agent";

// 默认：使用 ~/.pi/agent/auth.json 和 ~/.pi/agent/models.json
const authStorage = AuthStorage.create();
const modelRegistry = ModelRegistry.create(authStorage);

const { session } = await createAgentSession({
  sessionManager: SessionManager.inMemory(),
  authStorage,
  modelRegistry,
});

// 运行时 API key 覆盖（不持久化到磁盘）
authStorage.setRuntimeApiKey("anthropic", "sk-my-temp-key");

// 自定义 auth 存储位置
const customAuth = AuthStorage.create("/my/app/auth.json");
const customRegistry = ModelRegistry.create(customAuth, "/my/app/models.json");

const { session } = await createAgentSession({
  sessionManager: SessionManager.inMemory(),
  authStorage: customAuth,
  modelRegistry: customRegistry,
});

// 不使用自定义 models.json（仅内置模型）
const simpleRegistry = ModelRegistry.inMemory(authStorage);
```

> 参见 [examples/sdk/09-api-keys-and-oauth.ts](../examples/sdk/09-api-keys-and-oauth.ts)

### 系统提示

使用 `ResourceLoader` 覆盖系统提示：

```typescript
import { createAgentSession, DefaultResourceLoader } from "@earendil-works/pi-coding-agent";

const loader = new DefaultResourceLoader({
  systemPromptOverride: () => "你是一个乐于助人的助手。",
});
await loader.reload();

const { session } = await createAgentSession({ resourceLoader: loader });
```

> 参见 [examples/sdk/03-custom-prompt.ts](../examples/sdk/03-custom-prompt.ts)

### 工具

指定要启用的内置工具：

- 内置工具名称：`read`、`bash`、`edit`、`write`、`grep`、`find`、`ls`
- 默认内置工具：`read`、`bash`、`edit`、`write`
- `noTools: "all"` 禁用所有工具
- `noTools: "builtin"` 禁用默认内置工具，同时保持扩展和自定义工具启用
- `excludeTools` 在任何 `tools` 白名单应用后禁用特定的内置、扩展或自定义工具名称

`edit` 工具为 Pi 的 TUI 显示返回 `details.diff`，并为 SDK 消费者返回标准统一补丁格式的 `details.patch`。

```typescript
import { createAgentSession } from "@earendil-works/pi-coding-agent";

// 只读模式
const { session } = await createAgentSession({
  tools: ["read", "grep", "find", "ls"],
});

// 选择特定工具
const { session } = await createAgentSession({
  tools: ["read", "bash", "grep"],
});

// 禁用一个工具，同时保持其余工具可用
const { session } = await createAgentSession({
  excludeTools: ["ask_question"],
});
```

#### 带自定义 cwd 的工具

当传入自定义 `cwd` 时，`createAgentSession()` 会为该 cwd 构建选定的内置工具。

```typescript
import { createAgentSession, SessionManager } from "@earendil-works/pi-coding-agent";

const cwd = "/path/to/project";

// 为自定义 cwd 使用默认工具
const { session } = await createAgentSession({
  cwd,
  sessionManager: SessionManager.inMemory(cwd),
});

// 或为自定义 cwd 选择特定工具
const { session } = await createAgentSession({
  cwd,
  tools: ["read", "bash", "grep"],
  sessionManager: SessionManager.inMemory(cwd),
});
```

> 参见 [examples/sdk/05-tools.ts](../examples/sdk/05-tools.ts)

### 自定义工具

```typescript
import { Type } from "typebox";
import { createAgentSession, defineTool } from "@earendil-works/pi-coding-agent";

// 内联自定义工具
const myTool = defineTool({
  name: "my_tool",
  label: "My Tool",
  description: "做一些有用的事情",
  parameters: Type.Object({
    input: Type.String({ description: "输入值" }),
  }),
  execute: async (_toolCallId, params) => ({
    content: [{ type: "text", text: `结果：${params.input}` }],
    details: {},
  }),
});

// 直接传入自定义工具
const { session } = await createAgentSession({
  customTools: [myTool],
});
```

对独立定义和 `customTools: [myTool]` 这样的数组使用 `defineTool()`。内联的 `pi.registerTool({ ... })` 已能正确推断参数类型。

通过 `customTools` 传入的自定义工具会与扩展注册的工具合并。由 ResourceLoader 加载的扩展也可以通过 `pi.registerTool()` 注册工具。

如果传入了 `tools`，请包含每个你想启用的自定义或扩展工具名称，例如 `tools: ["read", "bash", "my_tool"]`。

> 参见 [examples/sdk/05-tools.ts](../examples/sdk/05-tools.ts)

### 扩展

扩展由 `ResourceLoader` 加载。`DefaultResourceLoader` 从 `~/.pi/agent/extensions/`、`.pi/extensions/` 和 settings.json 扩展源中发现扩展。

```typescript
import { createAgentSession, DefaultResourceLoader } from "@earendil-works/pi-coding-agent";

const loader = new DefaultResourceLoader({
  additionalExtensionPaths: ["/path/to/my-extension.ts"],
  extensionFactories: [
    (pi) => {
      pi.on("agent_start", () => {
        console.log("[内联扩展] 智能体启动中");
      });
    },
  ],
});
await loader.reload();

const { session } = await createAgentSession({ resourceLoader: loader });
```

扩展可以注册工具、订阅事件、添加命令等。完整 API 参见 [extensions.md](extensions.md)。

**命名内联扩展：** 默认情况下，内联工厂在启动扩展列表中显示为 `<inline:1>`、`<inline:2>` 等。若要显示描述性名称，请包装工厂：

```typescript
import type { InlineExtension } from "@earendil-works/pi-coding-agent";

const myProvider: InlineExtension = {
  name: "my-provider",
  factory: (pi) => {
    pi.on("agent_start", () => {
      console.log("[my-provider] 智能体启动中");
    });
  },
};

const loader = new DefaultResourceLoader({
  extensionFactories: [myProvider],
});
```

这会显示为 `<inline:my-provider>` 而非 `<inline:1>`。纯工厂函数仍然被接受以保持向后兼容。

**事件总线：** 扩展可以通过 `pi.events` 进行通信。如果需要从外部发射或监听事件，请向 `DefaultResourceLoader` 传入共享的 `eventBus`：

```typescript
import { createEventBus, DefaultResourceLoader } from "@earendil-works/pi-coding-agent";

const eventBus = createEventBus();
const loader = new DefaultResourceLoader({
  eventBus,
});
await loader.reload();

eventBus.on("my-extension:status", (data) => console.log(data));
```

> 参见 [examples/sdk/06-extensions.ts](../examples/sdk/06-extensions.ts) 和 [docs/extensions.md](extensions.md)

### 技能

```typescript
import {
  createAgentSession,
  DefaultResourceLoader,
  type Skill,
} from "@earendil-works/pi-coding-agent";

const customSkill: Skill = {
  name: "my-skill",
  description: "自定义指令",
  filePath: "/path/to/SKILL.md",
  baseDir: "/path/to",
  source: "custom",
};

const loader = new DefaultResourceLoader({
  skillsOverride: (current) => ({
    skills: [...current.skills, customSkill],
    diagnostics: current.diagnostics,
  }),
});
await loader.reload();

const { session } = await createAgentSession({ resourceLoader: loader });
```

> 参见 [examples/sdk/04-skills.ts](../examples/sdk/04-skills.ts)

### 上下文文件

```typescript
import { createAgentSession, DefaultResourceLoader } from "@earendil-works/pi-coding-agent";

const loader = new DefaultResourceLoader({
  agentsFilesOverride: (current) => ({
    agentsFiles: [
      ...current.agentsFiles,
      { path: "/virtual/AGENTS.md", content: "# 指南\n\n- 保持简洁" },
    ],
  }),
});
await loader.reload();

const { session } = await createAgentSession({ resourceLoader: loader });
```

> 参见 [examples/sdk/07-context-files.ts](../examples/sdk/07-context-files.ts)

### 斜杠命令

```typescript
import {
  createAgentSession,
  DefaultResourceLoader,
  type PromptTemplate,
} from "@earendil-works/pi-coding-agent";

const customCommand: PromptTemplate = {
  name: "deploy",
  description: "部署应用",
  source: "(custom)",
  content: "# 部署\n\n1. 构建\n2. 测试\n3. 部署",
};

const loader = new DefaultResourceLoader({
  promptsOverride: (current) => ({
    prompts: [...current.prompts, customCommand],
    diagnostics: current.diagnostics,
  }),
});
await loader.reload();

const { session } = await createAgentSession({ resourceLoader: loader });
```

> 参见 [examples/sdk/08-prompt-templates.ts](../examples/sdk/08-prompt-templates.ts)

### 会话管理

会话使用带有 `id`/`parentId` 链接的树结构，支持原地分支。

```typescript
import {
  type CreateAgentSessionRuntimeFactory,
  createAgentSession,
  createAgentSessionFromServices,
  createAgentSessionRuntime,
  createAgentSessionServices,
  getAgentDir,
  SessionManager,
} from "@earendil-works/pi-coding-agent";

// 内存模式（无持久化）
const { session } = await createAgentSession({
  sessionManager: SessionManager.inMemory(),
});

// 新的持久化会话
const { session: persisted } = await createAgentSession({
  sessionManager: SessionManager.create(process.cwd()),
});

// 继续最近的会话
const { session: continued, modelFallbackMessage } = await createAgentSession({
  sessionManager: SessionManager.continueRecent(process.cwd()),
});
if (modelFallbackMessage) {
  console.log("注意：", modelFallbackMessage);
}

// 打开特定文件
const { session: opened } = await createAgentSession({
  sessionManager: SessionManager.open("/path/to/session.jsonl"),
});

// 列出会话
const currentProjectSessions = await SessionManager.list(process.cwd());
const allSessions = await SessionManager.listAll(process.cwd());

// 用于 /new、/resume、/fork、/clone 和导入流程的会话替换 API。
const createRuntime: CreateAgentSessionRuntimeFactory = async ({ cwd, sessionManager, sessionStartEvent }) => {
  const services = await createAgentSessionServices({ cwd });
  return {
    ...(await createAgentSessionFromServices({
      services,
      sessionManager,
      sessionStartEvent,
    })),
    services,
    diagnostics: services.diagnostics,
  };
};

const runtime = await createAgentSessionRuntime(createRuntime, {
  cwd: process.cwd(),
  agentDir: getAgentDir(),
  sessionManager: SessionManager.create(process.cwd()),
});

// 用新会话替换活动会话
await runtime.newSession();

// 用另一个已保存的会话替换活动会话
await runtime.switchSession("/path/to/session.jsonl");

// 从特定用户条目分叉替换活动会话
await runtime.fork("entry-id");

// 克隆通过特定条目的活动路径
await runtime.fork("entry-id", { position: "at" });
```

**SessionManager 树 API：**

```typescript
const sm = SessionManager.open("/path/to/session.jsonl");

// 会话列表
const currentProjectSessions = await SessionManager.list(process.cwd());
const allSessions = await SessionManager.listAll(process.cwd());

// 树遍历
const entries = sm.getEntries();        // 所有条目（不含头部）
const tree = sm.getTree();              // 完整树结构
const path = sm.getPath();              // 从根到当前叶节点的路径
const leaf = sm.getLeafEntry();         // 当前叶节点条目
const entry = sm.getEntry(id);          // 按 ID 获取条目
const children = sm.getChildren(id);    // 条目的直接子节点

// 标签
const label = sm.getLabel(id);          // 获取条目标签
sm.appendLabelChange(id, "checkpoint"); // 设置标签

// 分支
sm.branch(entryId);                     // 将叶节点移动到更早的条目
sm.branchWithSummary(id, "Summary...");  // 带上下文摘要的分支
sm.createBranchedSession(leafId);       // 将路径提取到新文件
```

> See [examples/sdk/11-sessions.ts](../examples/sdk/11-sessions.ts) and [Session Format](session-format.md)

### Settings Management

```typescript
import { createAgentSession, SettingsManager, SessionManager } from "@earendil-works/pi-coding-agent";

// Default: load from files (global + project merged)
const { session } = await createAgentSession({
  settingsManager: SettingsManager.create(),
});

// With overrides
const settingsManager = SettingsManager.create();
settingsManager.applyOverrides({
  compaction: { enabled: false },
  retry: { enabled: true, maxRetries: 5 },
});
const { session } = await createAgentSession({ settingsManager });

// In-memory (no file I/O, for testing)
const { session } = await createAgentSession({
  settingsManager: SettingsManager.inMemory({ compaction: { enabled: false } }),
  sessionManager: SessionManager.inMemory(),
});

// Custom directories
const { session } = await createAgentSession({
  settingsManager: SettingsManager.create("/custom/cwd", "/custom/agent"),
});
```

**Static factory methods:**
- `SettingsManager.create(cwd?, agentDir?)` - load from files
- `SettingsManager.inMemory(settings?)` - no file I/O

**Project-level settings:**

Settings load from two locations and merge:
1. Global: `~/.pi/agent/settings.json`
2. Project: `<cwd>/.pi/settings.json`

Project overrides global. Nested objects merge by key. Setters modify global by default.

**Persistence and error handling semantics:**

- Settings getter/setter are synchronous against in-memory state.
- Setters enqueue async persistence writes.
- When durability boundaries matter (for example, before process exit or before asserting file contents in tests), call `await settingsManager.flush()`.
- `SettingsManager` does not print settings I/O errors. Use `settingsManager.drainErrors()` and report them at the application layer.

> See [examples/sdk/10-settings.ts](../examples/sdk/10-settings.ts)

## ResourceLoader

Use `DefaultResourceLoader` to discover extensions, skills, prompts, themes, and context files.

```typescript
import {
  DefaultResourceLoader,
  getAgentDir,
} from "@earendil-works/pi-coding-agent";

const loader = new DefaultResourceLoader({
  cwd,
  agentDir: getAgentDir(),
});
await loader.reload();

const extensions = loader.getExtensions();
const skills = loader.getSkills();
const prompts = loader.getPrompts();
const themes = loader.getThemes();
const contextFiles = loader.getAgentsFiles().agentsFiles;
```

## Return Value

`createAgentSession()` returns:

```typescript
interface CreateAgentSessionResult {
  // The session
  session: AgentSession;

  // Extension results (for runner setup)
  extensionsResult: LoadExtensionsResult;

  // Warning if session model could not be restored
  modelFallbackMessage?: string;
}

interface LoadExtensionsResult {
  extensions: Extension[];
  errors: Array<{ path: string; error: string }>;
  runtime: ExtensionRuntime;
}
```

## Complete Example

```typescript
import { getModel } from "@earendil-works/pi-ai";
import { Type } from "typebox";
import {
  AuthStorage,
  createAgentSession,
  DefaultResourceLoader,
  defineTool,
  ModelRegistry,
  SessionManager,
  SettingsManager,
} from "@earendil-works/pi-coding-agent";

// Setup auth storage (custom location)
const authStorage = AuthStorage.create("/custom/agent/auth.json");

// Runtime API key override (not persisted)
if (process.env.MY_KEY) {
  authStorage.setRuntimeApiKey("anthropic", process.env.MY_KEY);
}

// Model registry (no custom models.json)
const modelRegistry = ModelRegistry.create(authStorage);

// Inline tool
const statusTool = defineTool({
  name: "status",
  label: "Status",
  description: "Get system status",
  parameters: Type.Object({}),
  execute: async () => ({
    content: [{ type: "text", text: `Uptime: ${process.uptime()}s` }],
    details: {},
  }),
});

const model = getModel("anthropic", "claude-opus-4-5");
if (!model) throw new Error("Model not found");

// In-memory settings with overrides
const settingsManager = SettingsManager.inMemory({
  compaction: { enabled: false },
  retry: { enabled: true, maxRetries: 2 },
});

const loader = new DefaultResourceLoader({
  cwd: process.cwd(),
  agentDir: "/custom/agent",
  settingsManager,
  systemPromptOverride: () => "You are a minimal assistant. Be concise.",
});
await loader.reload();

const { session } = await createAgentSession({
  cwd: process.cwd(),
  agentDir: "/custom/agent",

  model,
  thinkingLevel: "off",
  authStorage,
  modelRegistry,

  tools: ["read", "bash", "status"],
  customTools: [statusTool],
  resourceLoader: loader,

  sessionManager: SessionManager.inMemory(),
  settingsManager,
});

session.subscribe((event) => {
  if (event.type === "message_update" && event.assistantMessageEvent.type === "text_delta") {
    process.stdout.write(event.assistantMessageEvent.delta);
  }
});

await session.prompt("Get status and list files.");
```

## Run Modes

The SDK exports run mode utilities for building custom interfaces on top of `createAgentSession()`:

### InteractiveMode

Full TUI interactive mode with editor, chat history, and all built-in commands:

```typescript
import {
  type CreateAgentSessionRuntimeFactory,
  createAgentSessionFromServices,
  createAgentSessionRuntime,
  createAgentSessionServices,
  getAgentDir,
  InteractiveMode,
  SessionManager,
} from "@earendil-works/pi-coding-agent";

const createRuntime: CreateAgentSessionRuntimeFactory = async ({ cwd, sessionManager, sessionStartEvent }) => {
  const services = await createAgentSessionServices({ cwd });
  return {
    ...(await createAgentSessionFromServices({ services, sessionManager, sessionStartEvent })),
    services,
    diagnostics: services.diagnostics,
  };
};
const runtime = await createAgentSessionRuntime(createRuntime, {
  cwd: process.cwd(),
  agentDir: getAgentDir(),
  sessionManager: SessionManager.create(process.cwd()),
});

const mode = new InteractiveMode(runtime, {
  migratedProviders: [],
  modelFallbackMessage: undefined,
  initialMessage: "Hello",
  initialImages: [],
  initialMessages: [],
});

await mode.run();
```

### runPrintMode

One-shot mode: send a prompt, print the result, exit:

```typescript
import {
  type CreateAgentSessionRuntimeFactory,
  createAgentSessionFromServices,
  createAgentSessionRuntime,
  createAgentSessionServices,
  getAgentDir,
  runPrintMode,
  SessionManager,
} from "@earendil-works/pi-coding-agent";

const createRuntime: CreateAgentSessionRuntimeFactory = async ({ cwd, sessionManager, sessionStartEvent }) => {
  const services = await createAgentSessionServices({ cwd });
  return {
    ...(await createAgentSessionFromServices({ services, sessionManager, sessionStartEvent })),
    services,
    diagnostics: services.diagnostics,
  };
};
const runtime = await createAgentSessionRuntime(createRuntime, {
  cwd: process.cwd(),
  agentDir: getAgentDir(),
  sessionManager: SessionManager.create(process.cwd()),
});

await runPrintMode(runtime, {
  mode: "text",
  initialMessage: "Hello",
  initialImages: [],
  messages: ["Follow up"],
});
```

### runRpcMode

JSON-RPC mode for subprocess integration:

```typescript
import {
  type CreateAgentSessionRuntimeFactory,
  createAgentSessionFromServices,
  createAgentSessionRuntime,
  createAgentSessionServices,
  getAgentDir,
  runRpcMode,
  SessionManager,
} from "@earendil-works/pi-coding-agent";

const createRuntime: CreateAgentSessionRuntimeFactory = async ({ cwd, sessionManager, sessionStartEvent }) => {
  const services = await createAgentSessionServices({ cwd });
  return {
    ...(await createAgentSessionFromServices({ services, sessionManager, sessionStartEvent })),
    services,
    diagnostics: services.diagnostics,
  };
};
const runtime = await createAgentSessionRuntime(createRuntime, {
  cwd: process.cwd(),
  agentDir: getAgentDir(),
  sessionManager: SessionManager.create(process.cwd()),
});

await runRpcMode(runtime);
```

See [RPC documentation](rpc.md) for the JSON protocol.

## RPC Mode Alternative

For subprocess-based integrations that don't use the SDK, use the CLI directly:

```bash
pi --mode rpc --no-session
```

See [RPC documentation](rpc.md) for the JSON protocol.

SDK-first is better when:
- You need type safety
- In the same Node.js process
- You need direct access to agent state
- You want to customize tools/extensions programmatically

RPC-first is better when:
- Integrating from other languages
- You need process isolation
- Building language-agnostic clients

## Exports

Main entry point exports:

```typescript
// Factories
createAgentSession
createAgentSessionRuntime
AgentSessionRuntime

// Auth & Model
AuthStorage
ModelRegistry
resolveCliModel
resolveModelScopeWithDiagnostics

// Resource loading
DefaultResourceLoader
type ResourceLoader
createEventBus

// Constants & helpers
CONFIG_DIR_NAME
defineTool
getAgentDir
getPackageDir
getReadmePath
getDocsPath
getExamplesPath

// Session management
SessionManager
SettingsManager

// Tool factories
createCodingTools
createReadOnlyTools
createReadTool, createBashTool, createEditTool, createWriteTool
createGrepTool, createFindTool, createLsTool

// Types
type CreateAgentSessionOptions
type CreateAgentSessionResult
type ExtensionFactory
type InlineExtension
type ExtensionAPI
type ToolDefinition
type Skill
type PromptTemplate
type Tool
```

See [extensions.md](extensions.md) for the full extension API.
