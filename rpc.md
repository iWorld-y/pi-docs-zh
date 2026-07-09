# RPC 模式

RPC 模式通过 stdin/stdout 上的 JSON 协议，以无界面（headless）方式运行 coding agent。适用于将 agent 嵌入其他应用、IDE 或自定义 UI。

**给 Node.js/TypeScript 用户的说明**：若你在构建 Node.js 应用，可考虑直接使用 `@earendil-works/pi-coding-agent` 中的 `AgentSession`，而不是拉起子进程。API 见 [`src/core/agent-session.ts`](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/core/agent-session.ts)。基于子进程的 TypeScript 客户端见 [`src/modes/rpc/rpc-client.ts`](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/modes/rpc/rpc-client.ts)。

## 启动 RPC 模式

```bash
pi --mode rpc [options]
```

常用选项：
- `--provider <name>`：设置 LLM 提供商（anthropic、openai、google 等）
- `--model <pattern>`：模型 pattern 或 ID（支持 `provider/id`，以及可选的 `:<thinking>`）
- `--name <name>` / `-n <name>`：启动时设置会话显示名称
- `--no-session`：禁用会话持久化
- `--session-dir <path>`：自定义会话存储目录

## 协议概览

- **Commands（命令）**：以 JSON 对象发往 stdin，每行一条
- **Responses（响应）**：带 `type: "response"` 的 JSON 对象，表示命令成功/失败
- **Events（事件）**：agent 事件以 JSON lines 流式输出到 stdout

所有命令都支持可选的 `id` 字段，用于请求/响应关联。若提供了 `id`，对应响应会包含相同的 `id`。

### Framing（帧格式）

RPC 模式采用严格的 JSONL 语义，仅以 LF（`\n`）作为记录分隔符。

对客户端的含义：
- 仅按 `\n` 拆分记录
- 可接受可选的 `\r\n` 输入，去掉末尾 `\r` 即可
- 不要使用会把 Unicode 分隔符也当作换行的通用行读取器

尤其要注意：Node 的 `readline` 不符合 RPC 模式协议，因为它还会在 `U+2028` 和 `U+2029` 处拆分，而这两个字符在 JSON 字符串内是合法的。

## 命令

### 提示（Prompting）

#### prompt

向 agent 发送用户 prompt。命令响应在 prompt 被接受、入队或处理后发出。接受之后，事件会继续异步流式输出。

```json
{"id": "req-1", "type": "prompt", "message": "Hello, world!"}
```

带图片：
```json
{"type": "prompt", "message": "What's in this image?", "images": [{"type": "image", "data": "base64-encoded-data", "mimeType": "image/png"}]}
```

**流式输出期间**：若 agent 已在流式输出，必须指定 `streamingBehavior` 才能将消息入队：

```json
{"type": "prompt", "message": "New instruction", "streamingBehavior": "steer"}
```

- `"steer"`：在 agent 运行时将消息入队。会在当前 assistant turn 执行完其 tool calls 之后、下一次 LLM 调用之前送达。
- `"followUp"`：等到 agent 结束后再处理。仅在 agent 停止时送达。

若 agent 正在流式输出且未指定 `streamingBehavior`，命令会返回错误。

**扩展命令**：若消息是扩展命令（例如 `/mycommand`），即使在流式输出期间也会立即执行。扩展命令通过 `pi.sendMessage()` 自行管理与 LLM 的交互。

**输入展开**：Skill 命令（`/skill:name`）和 prompt 模板（`/template`）会在发送/入队前展开。

响应：
```json
{"id": "req-1", "type": "response", "command": "prompt", "success": true}
```

`success: true` 表示 prompt 已被接受、入队或立即处理。`success: false` 表示 prompt 在接受前被拒绝。接受之后的失败会通过正常的事件与消息流报告，不会对同一请求 id 再发一条 `response`。

`images` 字段可选。每张图片使用 `ImageContent` 格式：`{"type": "image", "data": "base64-encoded-data", "mimeType": "image/png"}`。

#### steer

在 agent 运行时将一条 steering 消息入队。会在当前 assistant turn 执行完其 tool calls 之后、下一次 LLM 调用之前送达。Skill 命令和 prompt 模板会被展开。不允许扩展命令（请改用 `prompt`）。

```json
{"type": "steer", "message": "Stop and do this instead"}
```

带图片：
```json
{"type": "steer", "message": "Look at this instead", "images": [{"type": "image", "data": "base64-encoded-data", "mimeType": "image/png"}]}
```

`images` 字段可选。每张图片使用 `ImageContent` 格式（与 `prompt` 相同）。

响应：
```json
{"type": "response", "command": "steer", "success": true}
```

如何控制 steering 消息的处理方式，见 [set_steering_mode](#set_steering_mode)。

#### follow_up

将一条 follow-up 消息入队，在 agent 结束后再处理。仅在 agent 没有更多 tool calls 或 steering 消息时送达。Skill 命令和 prompt 模板会被展开。不允许扩展命令（请改用 `prompt`）。

```json
{"type": "follow_up", "message": "After you're done, also do this"}
```

带图片：
```json
{"type": "follow_up", "message": "Also check this image", "images": [{"type": "image", "data": "base64-encoded-data", "mimeType": "image/png"}]}
```

`images` 字段可选。每张图片使用 `ImageContent` 格式（与 `prompt` 相同）。

响应：
```json
{"type": "response", "command": "follow_up", "success": true}
```

如何控制 follow-up 消息的处理方式，见 [set_follow_up_mode](#set_follow_up_mode)。

#### abort

中止当前 agent 操作。

```json
{"type": "abort"}
```

响应：
```json
{"type": "response", "command": "abort", "success": true}
```

#### new_session

开启全新会话。可被 `session_before_switch` 扩展事件处理器取消。

```json
{"type": "new_session"}
```

可选的父会话追踪：
```json
{"type": "new_session", "parentSession": "/path/to/parent-session.jsonl"}
```

响应：
```json
{"type": "response", "command": "new_session", "success": true, "data": {"cancelled": false}}
```

若扩展取消了操作：
```json
{"type": "response", "command": "new_session", "success": true, "data": {"cancelled": true}}
```

### 状态（State）

#### get_state

获取当前会话状态。

```json
{"type": "get_state"}
```

响应：
```json
{
  "type": "response",
  "command": "get_state",
  "success": true,
  "data": {
    "model": {...},
    "thinkingLevel": "medium",
    "isStreaming": false,
    "isCompacting": false,
    "steeringMode": "all",
    "followUpMode": "one-at-a-time",
    "sessionFile": "/path/to/session.jsonl",
    "sessionId": "abc123",
    "sessionName": "my-feature-work",
    "autoCompactionEnabled": true,
    "messageCount": 5,
    "pendingMessageCount": 0
  }
}
```

`model` 字段为完整的 [Model](#model) 对象或 `null`。`sessionName` 字段为通过 `set_session_name` 设置的显示名称；若未设置则省略。

#### get_messages

获取对话中的全部消息。

```json
{"type": "get_messages"}
```

响应：
```json
{
  "type": "response",
  "command": "get_messages",
  "success": true,
  "data": {"messages": [...]}
}
```

消息为 `AgentMessage` 对象（见 [Message Types](#message-types)）。

### 模型（Model）

#### set_model

切换到指定模型。

```json
{"type": "set_model", "provider": "anthropic", "modelId": "claude-sonnet-4-20250514"}
```

响应包含完整的 [Model](#model) 对象：
```json
{
  "type": "response",
  "command": "set_model",
  "success": true,
  "data": {...}
}
```

#### cycle_model

切换到下一个可用模型。若只有一个可用模型，则 `data` 为 `null`。

```json
{"type": "cycle_model"}
```

响应：
```json
{
  "type": "response",
  "command": "cycle_model",
  "success": true,
  "data": {
    "model": {...},
    "thinkingLevel": "medium",
    "isScoped": false
  }
}
```

`model` 字段为完整的 [Model](#model) 对象。

#### get_available_models

列出全部已配置模型。

```json
{"type": "get_available_models"}
```

响应包含完整 [Model](#model) 对象数组：
```json
{
  "type": "response",
  "command": "get_available_models",
  "success": true,
  "data": {
    "models": [...]
  }
}
```

### 思考级别（Thinking）

#### set_thinking_level

为支持 reasoning/thinking 的模型设置思考级别。

```json
{"type": "set_thinking_level", "level": "high"}
```

级别：`"off"`、`"minimal"`、`"low"`、`"medium"`、`"high"`、`"xhigh"`

注意：`"xhigh"` 仅 OpenAI codex-max 模型支持。

响应：
```json
{"type": "response", "command": "set_thinking_level", "success": true}
```

#### cycle_thinking_level

在可用 thinking 级别间循环切换。若模型不支持 thinking，则 `data` 为 `null`。

```json
{"type": "cycle_thinking_level"}
```

响应：
```json
{
  "type": "response",
  "command": "cycle_thinking_level",
  "success": true,
  "data": {"level": "high"}
}
```

### 队列模式（Queue Modes）

#### set_steering_mode

控制 steering 消息（来自 `steer`）如何送达。

```json
{"type": "set_steering_mode", "mode": "one-at-a-time"}
```

模式：
- `"all"`：在当前 assistant turn 执行完其 tool calls 之后，送达全部 steering 消息
- `"one-at-a-time"`：每个已完成的 assistant turn 只送达一条 steering 消息（默认）

响应：
```json
{"type": "response", "command": "set_steering_mode", "success": true}
```

#### set_follow_up_mode

控制 follow-up 消息（来自 `follow_up`）如何送达。

```json
{"type": "set_follow_up_mode", "mode": "one-at-a-time"}
```

模式：
- `"all"`：agent 结束时送达全部 follow-up 消息
- `"one-at-a-time"`：每次 agent 完成只送达一条 follow-up 消息（默认）

响应：
```json
{"type": "response", "command": "set_follow_up_mode", "success": true}
```

### 压缩（Compaction）

#### compact

手动压缩对话上下文以降低 token 用量。

```json
{"type": "compact"}
```

带自定义说明：
```json
{"type": "compact", "customInstructions": "Focus on code changes"}
```

响应：
```json
{
  "type": "response",
  "command": "compact",
  "success": true,
  "data": {
    "summary": "Summary of conversation...",
    "firstKeptEntryId": "abc123",
    "tokensBefore": 150000,
    "estimatedTokensAfter": 32000,
    "details": {}
  }
}
```

`estimatedTokensAfter` 是压缩后立刻对重建消息上下文的启发式估算，并非提供商精确的 token 计数。

#### set_auto_compaction

启用或禁用在上下文接近满时的自动压缩。

```json
{"type": "set_auto_compaction", "enabled": true}
```

响应：
```json
{"type": "response", "command": "set_auto_compaction", "success": true}
```

### 重试（Retry）

#### set_auto_retry

启用或禁用在瞬时错误（overloaded、rate limit、5xx）时的自动重试。

```json
{"type": "set_auto_retry", "enabled": true}
```

响应：
```json
{"type": "response", "command": "set_auto_retry", "success": true}
```

#### abort_retry

中止进行中的重试（取消延迟并停止重试）。

```json
{"type": "abort_retry"}
```

响应：
```json
{"type": "response", "command": "abort_retry", "success": true}
```

### Bash（Shell）

#### bash

执行 shell 命令，并将输出加入对话上下文。

```json
{"type": "bash", "command": "ls -la"}
```

响应：
```json
{
  "type": "response",
  "command": "bash",
  "success": true,
  "data": {
    "output": "total 48\ndrwxr-xr-x ...",
    "exitCode": 0,
    "cancelled": false,
    "truncated": false
  }
}
```

若输出被截断，会包含 `fullOutputPath`：
```json
{
  "type": "response",
  "command": "bash",
  "success": true,
  "data": {
    "output": "truncated output...",
    "exitCode": 0,
    "cancelled": false,
    "truncated": true,
    "fullOutputPath": "/tmp/pi-bash-abc123.log"
  }
}
```

**bash 结果如何进入 LLM：**

`bash` 命令会立即执行并返回 `BashResult`。内部会创建一条 `BashExecutionMessage` 并写入 agent 的消息状态。该消息**不会**发出事件。

当下一次发送 `prompt` 命令时，所有消息（包括 `BashExecutionMessage`）会在送往 LLM 前做转换。`BashExecutionMessage` 会转成如下格式的 `UserMessage`：

````
Ran `ls -la`
```
total 48
drwxr-xr-x ...
```
````

这意味着：
1. Bash 输出在**下一次 prompt** 时才会进入 LLM 上下文，而非立即
2. 可在一次 prompt 前执行多条 bash 命令；所有输出都会被包含
3. `BashExecutionMessage` 本身不会发出事件

#### abort_bash

中止正在运行的 bash 命令。

```json
{"type": "abort_bash"}
```

响应：
```json
{"type": "response", "command": "abort_bash", "success": true}
```

### 会话（Session）

#### get_session_stats

获取 token 用量、费用统计，以及当前上下文窗口占用。

```json
{"type": "get_session_stats"}
```

响应：
```json
{
  "type": "response",
  "command": "get_session_stats",
  "success": true,
  "data": {
    "sessionFile": "/path/to/session.jsonl",
    "sessionId": "abc123",
    "userMessages": 5,
    "assistantMessages": 5,
    "toolCalls": 12,
    "toolResults": 12,
    "totalMessages": 22,
    "tokens": {
      "input": 50000,
      "output": 10000,
      "cacheRead": 40000,
      "cacheWrite": 5000,
      "total": 105000
    },
    "cost": 0.45,
    "contextUsage": {
      "tokens": 60000,
      "contextWindow": 200000,
      "percent": 30
    }
  }
}
```

`tokens` 为当前会话状态下 assistant 用量合计。`contextUsage` 为用于压缩与页脚显示的当前上下文窗口实际估算。

在没有可用模型或上下文窗口时，会省略 `contextUsage`。压缩后立刻，`contextUsage.tokens` 与 `contextUsage.percent` 为 `null`，直到压缩后有新的 assistant 响应提供有效用量数据。

#### export_html

将会话导出为 HTML 文件。

```json
{"type": "export_html"}
```

指定自定义路径：
```json
{"type": "export_html", "outputPath": "/tmp/session.html"}
```

响应：
```json
{
  "type": "response",
  "command": "export_html",
  "success": true,
  "data": {"path": "/tmp/session.html"}
}
```

#### switch_session

加载另一个会话文件。可被 `session_before_switch` 扩展事件处理器取消。

```json
{"type": "switch_session", "sessionPath": "/path/to/session.jsonl"}
```

响应：
```json
{"type": "response", "command": "switch_session", "success": true, "data": {"cancelled": false}}
```

若扩展取消了切换：
```json
{"type": "response", "command": "switch_session", "success": true, "data": {"cancelled": true}}
```

#### fork

从当前活动分支上某条先前的用户消息创建新 fork。可被 `session_before_fork` 扩展事件处理器取消。返回被 fork 的那条消息文本。

```json
{"type": "fork", "entryId": "abc123"}
```

响应：
```json
{
  "type": "response",
  "command": "fork",
  "success": true,
  "data": {"text": "The original prompt text...", "cancelled": false}
}
```

若扩展取消了 fork：
```json
{
  "type": "response",
  "command": "fork",
  "success": true,
  "data": {"text": "The original prompt text...", "cancelled": true}
}
```

#### clone

在当前位置将当前活动分支复制到新会话。可被 `session_before_fork` 扩展事件处理器取消。

```json
{"type": "clone"}
```

响应：
```json
{
  "type": "response",
  "command": "clone",
  "success": true,
  "data": {"cancelled": false}
}
```

若扩展取消了 clone：
```json
{
  "type": "response",
  "command": "clone",
  "success": true,
  "data": {"cancelled": true}
}
```

#### get_fork_messages

获取可用于 fork 的用户消息。

```json
{"type": "get_fork_messages"}
```

响应：
```json
{
  "type": "response",
  "command": "get_fork_messages",
  "success": true,
  "data": {
    "messages": [
      {"entryId": "abc123", "text": "First prompt..."},
      {"entryId": "def456", "text": "Second prompt..."}
    ]
  }
}
```

#### get_entries

按追加顺序获取全部会话条目（不含 session header）。会话是带稳定 id 的仅追加（append-only）条目树，因此 entry id 可作为持久游标：将你已见过的最后一个 entry id 作为 `since` 传入，即可只获取严格晚于它的条目，即使客户端重启也适用。与 `get_messages` 不同，这会包含压缩前的历史以及已放弃的分支。

```json
{"type": "get_entries"}
```

带游标：
```json
{"type": "get_entries", "since": "abc123"}
```

响应：
```json
{
  "type": "response",
  "command": "get_entries",
  "success": true,
  "data": {
    "entries": [
      {"type": "message", "id": "def456", "parentId": "abc123", "timestamp": "...", "message": {"role": "user", "...": "..."}}
    ],
    "leafId": "def456"
  }
}
```

`leafId` 为当前叶节点条目的 id（空会话为 `null`），客户端一次往返即可判断活动分支是否移动。若 `since` 与任何 entry id 都不匹配，响应为 `success: false`。

#### get_tree

将会话以条目树形式返回。每个节点为 `{entry, children, label?, labelTimestamp?}`。结构完好的会话有单一根；孤立条目（父链断裂）也会作为根出现。

```json
{"type": "get_tree"}
```

响应：
```json
{
  "type": "response",
  "command": "get_tree",
  "success": true,
  "data": {
    "tree": [
      {
        "entry": {"type": "message", "id": "abc123", "parentId": null, "...": "..."},
        "children": [
          {"entry": {"type": "message", "id": "def456", "parentId": "abc123", "...": "..."}, "children": []}
        ]
      }
    ],
    "leafId": "def456"
  }
}
```

#### get_last_assistant_text

获取最后一条 assistant 消息的文本内容。

```json
{"type": "get_last_assistant_text"}
```

响应：
```json
{
  "type": "response",
  "command": "get_last_assistant_text",
  "success": true,
  "data": {"text": "The assistant's response..."}
}
```

若不存在 assistant 消息，返回 `{"text": null}`。

#### set_session_name

为当前会话设置显示名称。名称会出现在会话列表中，便于识别会话。

```json
{"type": "set_session_name", "name": "my-feature-work"}
```

响应：
```json
{
  "type": "response",
  "command": "set_session_name",
  "success": true
}
```

当前会话名称可通过 `get_state` 的 `sessionName` 字段获取。启动 RPC 模式时若要设置初始名称，向 `pi --mode rpc` 进程传入 `--name <name>` 或 `-n <name>`。

### 命令列表（Commands）

#### get_commands

获取可用命令（扩展命令、prompt 模板与 skills）。可通过 `prompt` 命令以 `/` 前缀调用。

```json
{"type": "get_commands"}
```

响应：
```json
{
  "type": "response",
  "command": "get_commands",
  "success": true,
  "data": {
    "commands": [
      {"name": "session-name", "description": "Set or clear session name", "source": "extension", "path": "/home/user/.pi/agent/extensions/session.ts"},
      {"name": "fix-tests", "description": "Fix failing tests", "source": "prompt", "location": "project", "path": "/home/user/myproject/.pi/agent/prompts/fix-tests.md"},
      {"name": "skill:brave-search", "description": "Web search via Brave API", "source": "skill", "location": "user", "path": "/home/user/.pi/agent/skills/brave-search/SKILL.md"}
    ]
  }
}
```

每条命令包含：
- `name`：命令名（用 `/name` 调用）
- `description`：人类可读说明（扩展命令可选）
- `source`：命令类型：
  - `"extension"`：在扩展中通过 `pi.registerCommand()` 注册
  - `"prompt"`：从 prompt 模板 `.md` 文件加载
  - `"skill"`：从 skill 目录加载（名称带 `skill:` 前缀）
- `location`：加载来源（可选，扩展没有此字段）：
  - `"user"`：用户级（`~/.pi/agent/`）
  - `"project"`：项目级（`./.pi/agent/`）
  - `"path"`：通过 CLI 或设置显式指定的路径
- `path`：命令源文件的绝对路径（可选）

**注意**：内置 TUI 命令（`/settings`、`/hotkeys` 等）不包含在内。它们仅在交互模式下处理；若通过 `prompt` 发送也不会执行。

## 事件


Agent 运行期间，事件以 JSON lines 形式流式输出到 stdout。事件**不**包含 `id` 字段（仅响应包含）。

### 事件类型

| 事件 | 描述 |
|-------|-------------|
| `agent_start` | Agent 开始处理 |
| `agent_end` | 一次底层 agent 运行完成（之后仍可能有重试、压缩或排队的后续） |
| `agent_settled` | Agent 运行已完全稳定；不再有自动重试、压缩重试或排队的后续 |
| `turn_start` | 新回合开始 |
| `turn_end` | 回合完成（包含 assistant 消息与工具结果） |
| `message_start` | 消息开始 |
| `message_update` | 流式更新（text/thinking/toolcall 增量） |
| `message_end` | 消息完成 |
| `tool_execution_start` | 工具开始执行 |
| `tool_execution_update` | 工具执行进度（流式输出） |
| `tool_execution_end` | 工具完成 |
| `queue_update` | 待处理的 steering/follow-up 队列发生变化 |
| `compaction_start` | 压缩开始 |
| `compaction_end` | 压缩完成 |
| `auto_retry_start` | 自动重试开始（瞬时错误之后） |
| `auto_retry_end` | 自动重试完成（成功或最终失败） |
| `extension_error` | 扩展抛出错误 |

### agent_start

在 agent 开始处理 prompt 时发出。

```json
{"type": "agent_start"}
```

### agent_end

在一次底层 agent 运行完成时发出。包含该次运行期间生成的全部消息。若 `willRetry` 为 true，随后会进行自动重试。

```json
{
  "type": "agent_end",
  "messages": [...],
  "willRetry": false
}
```

### agent_settled

在完整的会话级运行稳定后发出。此时 Pi 不会再通过重试、压缩重试或排队的 follow-up 消息自动继续。

```json
{"type": "agent_settled"}
```

### turn_start / turn_end

一个回合由一次 assistant 响应，以及由此产生的工具调用与结果组成。

```json
{"type": "turn_start"}
```

```json
{
  "type": "turn_end",
  "message": {...},
  "toolResults": [...]
}
```

### message_start / message_end

在消息开始与完成时发出。`message` 字段包含一个 `AgentMessage`。

```json
{"type": "message_start", "message": {...}}
{"type": "message_end", "message": {...}}
```

### message_update（流式）

在 assistant 消息流式输出期间发出。同时包含部分消息与流式增量事件。

```json
{
  "type": "message_update",
  "message": {...},
  "assistantMessageEvent": {
    "type": "text_delta",
    "contentIndex": 0,
    "delta": "Hello ",
    "partial": {...}
  }
}
```

`assistantMessageEvent` 字段包含以下增量类型之一：

| 类型 | 描述 |
|------|-------------|
| `start` | 消息生成开始 |
| `text_start` | 文本内容块开始 |
| `text_delta` | 文本内容片段 |
| `text_end` | 文本内容块结束 |
| `thinking_start` | 思考块开始 |
| `thinking_delta` | 思考内容片段 |
| `thinking_end` | 思考块结束 |
| `toolcall_start` | 工具调用开始 |
| `toolcall_delta` | 工具调用参数片段 |
| `toolcall_end` | 工具调用结束（包含完整 `toolCall` 对象） |
| `done` | 消息完成（reason：`"stop"`、`"length"`、`"toolUse"`） |
| `error` | 发生错误（reason：`"aborted"`、`"error"`） |

流式文本响应示例：
```json
{"type":"message_update","message":{...},"assistantMessageEvent":{"type":"text_start","contentIndex":0,"partial":{...}}}
{"type":"message_update","message":{...},"assistantMessageEvent":{"type":"text_delta","contentIndex":0,"delta":"Hello","partial":{...}}}
{"type":"message_update","message":{...},"assistantMessageEvent":{"type":"text_delta","contentIndex":0,"delta":" world","partial":{...}}}
{"type":"message_update","message":{...},"assistantMessageEvent":{"type":"text_end","contentIndex":0,"content":"Hello world","partial":{...}}}
```

### tool_execution_start / tool_execution_update / tool_execution_end

在工具开始、流式输出进度以及执行完成时发出。

```json
{
  "type": "tool_execution_start",
  "toolCallId": "call_abc123",
  "toolName": "bash",
  "args": {"command": "ls -la"}
}
```

执行期间，`tool_execution_update` 事件会流式输出部分结果（例如 bash 输出随到随发）：

```json
{
  "type": "tool_execution_update",
  "toolCallId": "call_abc123",
  "toolName": "bash",
  "args": {"command": "ls -la"},
  "partialResult": {
    "content": [{"type": "text", "text": "partial output so far..."}],
    "details": {"truncation": null, "fullOutputPath": null}
  }
}
```

完成时：

```json
{
  "type": "tool_execution_end",
  "toolCallId": "call_abc123",
  "toolName": "bash",
  "result": {
    "content": [{"type": "text", "text": "total 48\n..."}],
    "details": {...}
  },
  "isError": false
}
```

使用 `toolCallId` 关联事件。`tool_execution_update` 中的 `partialResult` 是截至目前的累计输出（而非仅增量），客户端每次更新时直接替换显示即可。

### queue_update

每当待处理的 steering 或 follow-up 队列发生变化时发出。

```json
{
  "type": "queue_update",
  "steering": ["Focus on error handling"],
  "followUp": ["After that, summarize the result"]
}
```

### compaction_start / compaction_end

在压缩运行时发出，无论手动还是自动。

```json
{"type": "compaction_start", "reason": "threshold"}
```

`reason` 字段为 `"manual"`、`"threshold"` 或 `"overflow"`。

```json
{
  "type": "compaction_end",
  "reason": "threshold",
  "result": {
    "summary": "Summary of conversation...",
    "firstKeptEntryId": "abc123",
    "tokensBefore": 150000,
    "estimatedTokensAfter": 32000,
    "details": {}
  },
  "aborted": false,
  "willRetry": false
}
```

若 `reason` 为 `"overflow"` 且压缩成功，则 `willRetry` 为 `true`，agent 会自动重试该 prompt。

若压缩被中止，`result` 为 `null`，且 `aborted` 为 `true`。

若压缩失败（例如 API 配额超限），`result` 为 `null`，`aborted` 为 `false`，`errorMessage` 包含错误描述。

### auto_retry_start / auto_retry_end

在瞬时错误（过载、限流、5xx）之后触发自动重试时发出。

```json
{
  "type": "auto_retry_start",
  "attempt": 1,
  "maxAttempts": 3,
  "delayMs": 2000,
  "errorMessage": "529 {\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"Overloaded\"}}"
}
```

```json
{
  "type": "auto_retry_end",
  "success": true,
  "attempt": 2
}
```

最终失败时（超过最大重试次数）：
```json
{
  "type": "auto_retry_end",
  "success": false,
  "attempt": 3,
  "finalError": "529 overloaded_error: Overloaded"
}
```

### extension_error

在扩展抛出错误时发出。

```json
{
  "type": "extension_error",
  "extensionPath": "/path/to/extension.ts",
  "event": "tool_call",
  "error": "Error message..."
}
```

## 扩展 UI 协议（Extension UI Protocol）

扩展可通过 `ctx.ui.select()`、`ctx.ui.confirm()` 等方法请求用户交互。在 RPC 模式下，这些调用会映射为叠加在基础命令/事件流之上的请求/响应子协议。

扩展 UI 方法分为两类：

- **对话框方法**（`select`、`confirm`、`input`、`editor`）：在 stdout 上发出 `extension_ui_request`，并阻塞直到客户端在 stdin 上返回带有匹配 `id` 的 `extension_ui_response`。
- **即发即弃方法**（`notify`、`setStatus`、`setWidget`、`setTitle`、`set_editor_text`）：在 stdout 上发出 `extension_ui_request`，但不期望响应。客户端可以展示该信息，也可以忽略。

若对话框方法包含 `timeout` 字段，超时后 agent 端会以默认值自动解析。客户端无需自行跟踪超时。

部分 `ExtensionUIContext` 方法在 RPC 模式下不受支持或能力降级，因为它们需要直接访问 TUI：
- `custom()` 返回 `undefined`
- `setWorkingMessage()`、`setWorkingIndicator()`、`setFooter()`、`setHeader()`、`setEditorComponent()`、`setToolsExpanded()` 为空操作
- `getEditorText()` 返回 `""`
- `getToolsExpanded()` 返回 `false`
- `pasteToEditor()` 委托给 `setEditorText()`（无粘贴/折叠处理）
- `getAllThemes()` 返回 `[]`
- `getTheme()` 返回 `undefined`
- `setTheme()` 返回 `{ success: false, error: "..." }`

注意：在 RPC 模式下，`ctx.mode` 为 `"rpc"`，且 `ctx.hasUI` 为 `true`，因为对话框与即发即弃方法可通过扩展 UI 子协议正常工作。请用 `ctx.mode === "tui"` 保护需要真实终端的 TUI 专属功能（如 `custom()`）。

### 扩展 UI 请求（stdout）

所有请求都包含 `type: "extension_ui_request"`、唯一的 `id`，以及 `method` 字段。

#### select

提示用户从列表中选择。带有 `timeout` 字段的对话框方法会包含以毫秒为单位的超时；若客户端未及时响应，agent 会以 `undefined` 自动解析。

```json
{
  "type": "extension_ui_request",
  "id": "uuid-1",
  "method": "select",
  "title": "Allow dangerous command?",
  "options": ["Allow", "Block"],
  "timeout": 10000
}
```

期望响应：`extension_ui_response`，带有 `value`（所选选项字符串）或 `cancelled: true`。

#### confirm

提示用户进行是/否确认。

```json
{
  "type": "extension_ui_request",
  "id": "uuid-2",
  "method": "confirm",
  "title": "Clear session?",
  "message": "All messages will be lost.",
  "timeout": 5000
}
```

期望响应：`extension_ui_response`，带有 `confirmed: true/false` 或 `cancelled: true`。

#### input

提示用户输入自由文本。

```json
{
  "type": "extension_ui_request",
  "id": "uuid-3",
  "method": "input",
  "title": "Enter a value",
  "placeholder": "type something..."
}
```

期望响应：`extension_ui_response`，带有 `value`（输入的文本）或 `cancelled: true`。

#### editor

打开多行文本编辑器，可带预填内容。

```json
{
  "type": "extension_ui_request",
  "id": "uuid-4",
  "method": "editor",
  "title": "Edit some text",
  "prefill": "Line 1\nLine 2\nLine 3"
}
```

期望响应：`extension_ui_response`，带有 `value`（编辑后的文本）或 `cancelled: true`。

#### notify

显示通知。即发即弃，不期望响应。

```json
{
  "type": "extension_ui_request",
  "id": "uuid-5",
  "method": "notify",
  "message": "Command blocked by user",
  "notifyType": "warning"
}
```

`notifyType` 字段为 `"info"`、`"warning"` 或 `"error"`。省略时默认为 `"info"`。

#### setStatus

在页脚/状态栏中设置或清除状态条目。即发即弃。

```json
{
  "type": "extension_ui_request",
  "id": "uuid-6",
  "method": "setStatus",
  "statusKey": "my-ext",
  "statusText": "Turn 3 running..."
}
```

发送 `statusText: undefined`（或省略该字段）可清除对应 key 的状态条目。

#### setWidget

设置或清除显示在编辑器上方或下方的 widget（文本行块）。即发即弃。

```json
{
  "type": "extension_ui_request",
  "id": "uuid-7",
  "method": "setWidget",
  "widgetKey": "my-ext",
  "widgetLines": ["--- My Widget ---", "Line 1", "Line 2"],
  "widgetPlacement": "aboveEditor"
}
```

发送 `widgetLines: undefined`（或省略该字段）可清除 widget。`widgetPlacement` 字段为 `"aboveEditor"`（默认）或 `"belowEditor"`。RPC 模式仅支持字符串数组；组件工厂会被忽略。

#### setTitle

设置终端窗口/标签页标题。即发即弃。

```json
{
  "type": "extension_ui_request",
  "id": "uuid-8",
  "method": "setTitle",
  "title": "pi - my project"
}
```

#### set_editor_text

设置输入编辑器中的文本。即发即弃。

```json
{
  "type": "extension_ui_request",
  "id": "uuid-9",
  "method": "set_editor_text",
  "text": "prefilled text for the user"
}
```

### 扩展 UI 响应（stdin）

仅对话框方法（`select`、`confirm`、`input`、`editor`）需要发送响应。`id` 必须与请求匹配。

#### 值响应（select、input、editor）

```json
{"type": "extension_ui_response", "id": "uuid-1", "value": "Allow"}
```

#### 确认响应（confirm）

```json
{"type": "extension_ui_response", "id": "uuid-2", "confirmed": true}
```

#### 取消响应（任意对话框）

关闭任意对话框方法。扩展会收到 `undefined`（对于 select/input/editor）或 `false`（对于 confirm）。

```json
{"type": "extension_ui_response", "id": "uuid-3", "cancelled": true}
```

## 错误处理

失败的命令会返回 `success: false` 的响应：

```json
{
  "type": "response",
  "command": "set_model",
  "success": false,
  "error": "Model not found: invalid/model"
}
```

解析错误：

```json
{
  "type": "response",
  "command": "parse",
  "success": false,
  "error": "Failed to parse command: Unexpected token..."
}
```

## 类型

源文件：
- [`packages/ai/src/types.ts`](https://github.com/earendil-works/pi-mono/blob/main/packages/ai/src/types.ts) - `Model`、`UserMessage`、`AssistantMessage`、`ToolResultMessage`
- [`packages/agent/src/types.ts`](https://github.com/earendil-works/pi-mono/blob/main/packages/agent/src/types.ts) - `AgentMessage`、`AgentEvent`
- [`src/core/messages.ts`](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/core/messages.ts) - `BashExecutionMessage`
- [`src/modes/rpc/rpc-types.ts`](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/modes/rpc/rpc-types.ts) - RPC 命令/响应类型、扩展 UI 请求/响应类型

### Model

```json
{
  "id": "claude-sonnet-4-20250514",
  "name": "Claude Sonnet 4",
  "api": "anthropic-messages",
  "provider": "anthropic",
  "baseUrl": "https://api.anthropic.com",
  "reasoning": true,
  "input": ["text", "image"],
  "contextWindow": 200000,
  "maxTokens": 16384,
  "cost": {
    "input": 3.0,
    "output": 15.0,
    "cacheRead": 0.3,
    "cacheWrite": 3.75
  }
}
```

### UserMessage

```json
{
  "role": "user",
  "content": "Hello!",
  "timestamp": 1733234567890,
  "attachments": []
}
```

`content` 字段可以是字符串，或 `TextContent`/`ImageContent` 块的数组。

### AssistantMessage

```json
{
  "role": "assistant",
  "content": [
    {"type": "text", "text": "Hello! How can I help?"},
    {"type": "thinking", "thinking": "User is greeting me..."},
    {"type": "toolCall", "id": "call_123", "name": "bash", "arguments": {"command": "ls"}}
  ],
  "api": "anthropic-messages",
  "provider": "anthropic",
  "model": "claude-sonnet-4-20250514",
  "usage": {
    "input": 100,
    "output": 50,
    "cacheRead": 0,
    "cacheWrite": 0,
    "cost": {"input": 0.0003, "output": 0.00075, "cacheRead": 0, "cacheWrite": 0, "total": 0.00105}
  },
  "stopReason": "stop",
  "timestamp": 1733234567890
}
```

停止原因：`"stop"`、`"length"`、`"toolUse"`、`"error"`、`"aborted"`

### ToolResultMessage

```json
{
  "role": "toolResult",
  "toolCallId": "call_123",
  "toolName": "bash",
  "content": [{"type": "text", "text": "total 48\ndrwxr-xr-x ..."}],
  "isError": false,
  "timestamp": 1733234567890
}
```

### BashExecutionMessage

由 `bash` RPC 命令创建（非 LLM 工具调用）：

```json
{
  "role": "bashExecution",
  "command": "ls -la",
  "output": "total 48\ndrwxr-xr-x ...",
  "exitCode": 0,
  "cancelled": false,
  "truncated": false,
  "fullOutputPath": null,
  "timestamp": 1733234567890
}
```

### Attachment

```json
{
  "id": "img1",
  "type": "image",
  "fileName": "photo.jpg",
  "mimeType": "image/jpeg",
  "size": 102400,
  "content": "base64-encoded-data...",
  "extractedText": null,
  "preview": null
}
```

## 示例：基础客户端（Python）

```python
import subprocess
import json

proc = subprocess.Popen(
    ["pi", "--mode", "rpc", "--no-session"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    text=True
)

def send(cmd):
    proc.stdin.write(json.dumps(cmd) + "\n")
    proc.stdin.flush()

def read_events():
    for line in proc.stdout:
        yield json.loads(line)

# 发送 prompt
send({"type": "prompt", "message": "Hello!"})

# 处理事件
for event in read_events():
    if event.get("type") == "message_update":
        delta = event.get("assistantMessageEvent", {})
        if delta.get("type") == "text_delta":
            print(delta["delta"], end="", flush=True)
    
    if event.get("type") == "agent_end":
        print()
        break
```

## 示例：交互式客户端（Node.js）

完整交互式示例见 [`test/rpc-example.ts`](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/test/rpc-example.ts)，带类型的客户端实现见 [`src/modes/rpc/rpc-client.ts`](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/src/modes/rpc/rpc-client.ts)。

处理扩展 UI 协议的完整示例见 [`examples/rpc-extension-ui.ts`](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/examples/rpc-extension-ui.ts)，可与扩展 [`examples/extensions/rpc-demo.ts`](https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/examples/extensions/rpc-demo.ts) 配合使用。

```javascript
const { spawn } = require("child_process");
const { StringDecoder } = require("string_decoder");

const agent = spawn("pi", ["--mode", "rpc", "--no-session"]);

function attachJsonlReader(stream, onLine) {
    const decoder = new StringDecoder("utf8");
    let buffer = "";

    stream.on("data", (chunk) => {
        buffer += typeof chunk === "string" ? chunk : decoder.write(chunk);

        while (true) {
            const newlineIndex = buffer.indexOf("\n");
            if (newlineIndex === -1) break;

            let line = buffer.slice(0, newlineIndex);
            buffer = buffer.slice(newlineIndex + 1);
            if (line.endsWith("\r")) line = line.slice(0, -1);
            onLine(line);
        }
    });

    stream.on("end", () => {
        buffer += decoder.end();
        if (buffer.length > 0) {
            onLine(buffer.endsWith("\r") ? buffer.slice(0, -1) : buffer);
        }
    });
}

attachJsonlReader(agent.stdout, (line) => {
    const event = JSON.parse(line);

    if (event.type === "message_update") {
        const { assistantMessageEvent } = event;
        if (assistantMessageEvent.type === "text_delta") {
            process.stdout.write(assistantMessageEvent.delta);
        }
    }
});

// 发送 prompt
agent.stdin.write(JSON.stringify({ type: "prompt", message: "Hello" }) + "\n");

// Ctrl+C 时中止
process.on("SIGINT", () => {
    agent.stdin.write(JSON.stringify({ type: "abort" }) + "\n");
});
```
