> pi 可以帮你使用 SDK。让它为你的用例构建集成即可。

# SDK

SDK 提供了对 pi 的 agent 能力的编程访问。可用来将 pi 嵌入其他应用、构建自定义界面，或与自动化工作流集成。

**示例用例：**
- 构建自定义 UI（Web、桌面、移动端）
- 将 agent 能力集成到现有应用中
- 创建带有 agent 推理的自动化流水线
- 构建能生成子 agent 的自定义工具
- 通过编程方式测试 agent 行为

参见 [examples/sdk/](../examples/sdk/)，可查看从最小实现到完整控制的各种可运行示例。

## 快速开始

```typescript
import { AuthStorage, createAgentSession, ModelRegistry, SessionManager } from "@earendil-works/pi-coding-agent";

// 设置凭证存储和模型注册表
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

await session.prompt("What files are in the current directory?");
```

## 安装

```bash
npm install @earendil-works/pi-coding-agent
```

SDK 已包含在主包中，无需单独安装。

## 核心概念

### createAgentSession()

单个 `AgentSession` 的主工厂函数。

`createAgentSession()` 使用 `ResourceLoader` 来提供扩展、技能（skills）、prompt 模板、主题和上下文文件。如果未提供，则使用带标准发现机制的 `DefaultResourceLoader`。

```typescript
import { createAgentSession, SessionManager } from "@earendil-works/pi-coding-agent";

// 最简：使用 DefaultResourceLoader 的默认值
const { session } = await createAgentSession();

// 自定义：覆盖特定选项
const { session } = await createAgentSession({
  model: myModel,
  tools: ["read", "bash"],
  sessionManager: SessionManager.inMemory(),
});
```

### AgentSession

会话负责管理 agent 生命周期、消息历史、模型状态、压缩（compaction）以及事件流。

```typescript
interface AgentSession {
  // 发送 prompt 并等待完成
  prompt(text: string, options?: PromptOptions): Promise<void>;

  // 在流式输出期间排队消息
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

  // 在当前会话文件中进行原地（in-place）树状导航
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

new-session、resume、fork、import 等会话替换 API 位于 `AgentSessionRuntime` 上，而非 `AgentSession` 上。

### createAgentSessionRuntime() 与 AgentSessionRuntime

当需要替换活动会话并重建 cwd 绑定的运行时状态时，使用 runtime API。
这也是内置 interactive、print 和 RPC 模式所使用的层级。

`createAgentSessionRuntime()` 接收一个运行时工厂加上初始 cwd/会话目标。该工厂会闭包进程级固定输入，为有效 cwd 重建 cwd 绑定的服务，针对这些服务解析会话选项，然后返回完整的运行时结果。

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

`AgentSessionRuntime` 在以下操作中负责活动运行时的替换：

- `newSession()`
- `switchSession()`
- `fork()`
- 通过 `fork(entryId, { position: "at" })` 的克隆流程
- `importFromJsonl()`

重要行为：

- `runtime.session` 会在上述操作后发生改变
- 事件订阅是绑定到特定 `AgentSession` 的，因此替换后需重新订阅
- 如果使用了扩展，需为新会话再次调用 `runtime.session.bindExtensions(...)`
- 创建时会在 `runtime.diagnostics` 上返回诊断信息
- 如果运行时创建或替换失败，该方法会抛出异常，由调用方决定如何处理

```typescript
let session = runtime.session;
let unsubscribe = session.subscribe(() => {});

await runtime.newSession();

unsubscribe();
session = runtime.session;
unsubscribe = session.subscribe(() => {});
```

### Prompt 与消息排队

`PromptOptions` 控制 prompt 展开、流式输出期间的排队行为以及 prompt 预检通知：

```typescript
interface PromptOptions {
  expandPromptTemplates?: boolean;
  images?: ImageContent[];
  streamingBehavior?: "steer" | "followUp";
  source?: InputSource;
  preflightResult?: (success: boolean) => void;
}
```

`preflightResult` 在每次调用 `prompt()` 时都会被触发一次：

- 当 prompt 被接受、排队或立即处理时为 `true`
- 当 prompt 预检在拒绝接受前被拒绝时为 `false`

它在 `prompt()` resolve 之前触发。`prompt()` 仍只有在被接受的完整运行（包括重试）完成后才会 resolve。接受后发生的故障通过正常的事件和消息流报告，而非通过 `preflightResult(false)`。

`prompt()` 方法处理 prompt 模板、扩展命令和消息发送：

```typescript
// 基础 prompt（不在流式输出时）
await session.prompt("What files are here?");

// 带图片
await session.prompt("What's in this image?", {
  images: [{ type: "image", source: { type: "base64", mediaType: "image/png", data: "..." } }]
});

// 在流式输出期间：必须指定消息排队方式
await session.prompt("Stop and do this instead", { streamingBehavior: "steer" });
await session.prompt("After you're done, also check X", { streamingBehavior: "followUp" });
```

**行为：**
- **扩展命令**（例如 `/mycommand`）：立即执行，即使在流式输出期间也能执行。它们通过 `pi.sendMessage()` 自行管理 LLM 交互。
- **基于文件的 prompt 模板**（来自 `.md` 文件）：在发送或排队前展开为其内容。
- **在流式输出期间未指定 `streamingBehavior`**：抛出错误。直接使用 `steer()` 或 `followUp()`，或指定该选项。
- **`preflightResult(true)`**：表示 prompt 已被接受、排队或立即处理。
- **`preflightResult(false)`**：表示预检在拒绝接受前被拒绝。

用于流式输出期间的显式排队：

```typescript
// 排队一条转向消息，在当前 assistant 回合完成工具调用后投递
await session.steer("New instruction");

// 等待 agent 完成（仅在 agent 停止时投递）
await session.followUp("After you're done, also do this");
```

`steer()` 和 `followUp()` 都会展开基于文件的 prompt 模板，但对扩展命令会报错（扩展命令不能排队）。

### Agent 与 AgentState

`Agent` 类（来自 `@earendil-works/pi-agent-core`）处理核心的 LLM 交互。通过 `session.agent` 访问。

```typescript
// 访问当前状态
const state = session.agent.state;

// state.messages: AgentMessage[] - 会话历史
// state.model: Model - 当前模型
// state.thinkingLevel: ThinkingLevel - 当前思考级别
// state.systemPrompt: string - 系统提示
// state.tools: AgentTool[] - 可用工具
// state.streamingMessage?: AgentMessage - 当前部分 assistant 消息
// state.errorMessage?: string - 最近的 assistant 错误

// 替换消息（用于分支或恢复）
session.agent.state.messages = messages; // 复制顶层数组

// 替换工具
session.agent.state.tools = tools; // 复制顶层数组

// 等待 agent 完成处理
await session.agent.waitForIdle();
```

### 事件

订阅事件以接收流式输出和生命周期通知。

```typescript
session.subscribe((event) => {
  switch (event.type) {
    // assistant 的流式文本
    case "message_update":
      if (event.assistantMessageEvent.type === "text_delta") {
        process.stdout.write(event.assistantMessageEvent.delta);
      }
      if (event.assistantMessageEvent.type === "thinking_delta") {
        // 思考输出（如果已启用 thinking）
      }
      break;
    
    // 工具执行
    case "tool_execution_start":
      console.log(`Tool: ${event.toolName}`);
      break;
    case "tool_execution_update":
      // 流式工具输出
      break;
    case "tool_execution_end":
      console.log(`Result: ${event.isError ? "error" : "success"}`);
      break;
    
    // 消息生命周期
    case "message_start":
      // 新消息开始
      break;
    case "message_end":
      // 消息完成
      break;
    
    // Agent 生命周期
    case "agent_start":
      // agent 开始处理 prompt
      break;
    case "agent_end":
      // agent 完成（event.messages 包含新消息）
      break;
    
    // 回合（Turn）生命周期（一次 LLM 响应 + 工具调用）
    case "turn_start":
      break;
    case "turn_end":
      // event.message: assistant 响应
      // event.toolResults: 本回合的工具结果
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
  // DefaultResourceLoader 发现机制的默认工作目录
  cwd: process.cwd(), // 默认值
  
  // 全局配置目录
  agentDir: "~/.pi/agent", // 默认值（会展开 ~）
});
```

`cwd` 由 `DefaultResourceLoader` 用于：
- 项目扩展（`.pi/extensions/`）
- 项目技能：
  - `.pi/skills/`
  - `cwd` 及其祖先目录中的 `.agents/skills/`（向上直到 git 仓库根目录，或不在仓库中时的文件系统根目录）
- 项目 prompt（`.pi/prompts/`）
- 上下文文件（从 cwd 向上遍历的 `AGENTS.md`）
- 会话目录命名

`agentDir` 由 `DefaultResourceLoader` 用于：
- 全局扩展（`extensions/`）
- 全局技能：
  - `agentDir` 下的 `skills/`（例如 `~/.pi/agent/skills/`）
  - `~/.agents/skills/`
- 全局 prompt（`prompts/`）
- 全局上下文文件（`AGENTS.md`）
- 设置（`settings.json`）
- 自定义模型（`models.json`）
- 凭证（`auth.json`）
- 会话（`sessions/`）

当你传入自定义 `ResourceLoader` 时，`cwd` 和 `agentDir` 不再控制资源发现。它们仍会影响会话命名和工具路径解析。

### 模型

```typescript
import { getModel } from "@earendil-works/pi-ai";
import { AuthStorage, ModelRegistry } from "@earendil-works/pi-coding-agent";

const authStorage = AuthStorage.create();
const modelRegistry = ModelRegistry.create(authStorage);

// 查找特定的内置模型（不检查 API key 是否存在）
const opus = getModel("anthropic", "claude-opus-4-5");
if (!opus) throw new Error("Model not found");

// 按 provider/id 查找任意模型，包括来自 models.json 的自定义模型
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
1. 尝试从会话恢复（如果是继续已有会话）
2. 使用设置中的默认值
3. 回退到第一个可用模型

为匹配 CLI 模型解析逻辑，可使用导出的解析器辅助函数：

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

`resolveCliModel()` 使用所有已注册的模型，因此在存储的 auth 存在之前，`--api-key` 风格的首次设置就能解析出模型。`resolveModelScopeWithDiagnostics()` 匹配 `--models` 和 `enabledModels` 语义，但将警告返回而非直接打印。

> 参见 [examples/sdk/02-custom-model.ts](../examples/sdk/02-custom-model.ts)

### API Keys 与 OAuth

API key 解析优先级（由 AuthStorage 处理）：
1. 运行时覆盖（通过 `setRuntimeApiKey`，不持久化）
2. `auth.json` 中存储的凭证（API keys 或 OAuth tokens）
3. 环境变量（`ANTHROPIC_API_KEY`、`OPENAI_API_KEY` 等）
4. 回退解析器（用于来自 `models.json` 的自定义 provider 的 key）

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
  systemPromptOverride: () => "You are a helpful assistant.",
});
await loader.reload();

const { session } = await createAgentSession({ resourceLoader: loader });
```

> 参见 [examples/sdk/03-custom-prompt.ts](../examples/sdk/03-custom-prompt.ts)

### 工具

指定要启用哪些内置工具：

- 内置工具名称：`read`、`bash`、`edit`、`write`、`grep`、`find`、`ls`
- 默认内置：`read`、`bash`、`edit`、`write`
- `noTools: "all"` 禁用所有工具
- `noTools: "builtin"` 禁用默认内置工具，同时保持扩展工具和自定义工具启用
- `excludeTools` 在任何 `tools` 白名单应用后禁用特定的内置、扩展或自定义工具名称

`edit` 工具为 Pi 的 TUI 显示返回 `details.diff`，并为 SDK 消费者返回 `details.patch` 作为标准 unified patch。

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

// 禁用一个工具同时保持其余可用
const { session } = await createAgentSession({
  excludeTools: ["ask_question"],
});
```

#### 使用自定义 cwd 的工具

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
  description: "Does something useful",
  parameters: Type.Object({
    input: Type.String({ description: "Input value" }),
  }),
  execute: async (_toolCallId, params) => ({
    content: [{ type: "text", text: `Result: ${params.input}` }],
    details: {},
  }),
});

// 直接传入自定义工具
const { session } = await createAgentSession({
  customTools: [myTool],
});
```

使用 `defineTool()` 进行独立定义，以及类似 `customTools: [myTool]` 的数组。内联 `pi.registerTool({ ... })` 已经能正确推断参数类型。

通过 `customTools` 传入的自定义工具会与扩展注册的工具合并。由 ResourceLoader 加载的扩展也可以通过 `pi.registerTool()` 注册工具。

如果你传入了 `tools`，需包含你要启用的每个自定义或扩展工具名称，例如 `tools: ["read", "bash", "my_tool"]`。

> 参见 [examples/sdk/05-tools.ts](../examples/sdk/05-tools.ts)

### 扩展

扩展由 `ResourceLoader` 加载。`DefaultResourceLoader` 从 `~/.pi/agent/extensions/`、`.pi/extensions/` 和 settings.json 的扩展源中发现扩展。

```typescript
import { createAgentSession, DefaultResourceLoader } from "@earendil-works/pi-coding-agent";

const loader = new DefaultResourceLoader({
  additionalExtensionPaths: ["/path/to/my-extension.ts"],
  extensionFactories: [
    (pi) => {
      pi.on("agent_start", () => {
        console.log("[Inline Extension] Agent starting");
      });
    },
  ],
});
await loader.reload();

const { session } = await createAgentSession({ resourceLoader: loader });
```

扩展可以注册工具、订阅事件、添加命令等。完整 API 参见 [extensions.md](extensions.md)。

**带命名的内联扩展：** 默认情况下，内联工厂在启动 Extensions 列表中显示为 `<inline:1>`、`<inline:2>` 等。如需显示描述性名称，请包装工厂：

```typescript
import type { InlineExtension } from "@earendil-works/pi-coding-agent";

const myProvider: InlineExtension = {
  name: "my-provider",
  factory: (pi) => {
    pi.on("agent_start", () => {
      console.log("[my-provider] Agent starting");
    });
  },
};

const loader = new DefaultResourceLoader({
  extensionFactories: [myProvider],
});
```

这会显示为 `<inline:my-provider>` 而非 `<inline:1>`。出于向后兼容考虑，仍接受裸工厂函数。

**事件总线（Event Bus）：** 扩展可以通过 `pi.events` 通信。如果需要在外部发送或监听，请将共享的 `eventBus` 传递给 `DefaultResourceLoader`：

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