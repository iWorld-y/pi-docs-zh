# 自定义模型 (Custom Models)

通过 `~/.pi/agent/models.json` 添加自定义提供商和模型（Ollama、vLLM、LM Studio、代理等）。

## 目录

- [最小化示例](#最小化示例)
- [完整示例](#完整示例)
- [Google AI Studio 示例](#google-ai-studio-示例)
- [支持的 API](#支持的-api)
- [提供商配置](#提供商配置)
- [模型配置](#模型配置)
- [覆盖内置提供商](#覆盖内置提供商)
- [按模型覆盖](#按模型覆盖)
- [Anthropic Messages 兼容性](#anthropic-messages-兼容性)
- [OpenAI 兼容性](#openai-兼容性)

## 最小化示例

对于本地模型（Ollama、LM Studio、vLLM），每个模型只需配置 `id`：

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://localhost:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "models": [
        { "id": "llama3.1:8b" },
        { "id": "qwen2.5-coder:7b" }
      ]
    }
  }
}
```

`apiKey` 的值是一个占位符，因为 Ollama 会忽略它。pi 仍会在 `/model` 中将需要认证才显示模型，因此无认证的本地服务器应保留一个虚拟值，通过 `/login` 为该提供商保存密钥，或在选择模型时传入 `--api-key`。

部分 OpenAI 兼容服务器不理解用于推理模型的 `developer` 角色。对于这些提供商，将 `compat.supportsDeveloperRole` 设为 `false`，以便 pi 将系统提示作为 `system` 消息发送。如果服务器同样不支持 `reasoning_effort`，也将 `compat.supportsReasoningEffort` 设为 `false`。

可在提供商级别设置 `compat` 以应用于所有模型，或在模型级别设置以覆盖特定模型。这通常适用于 Ollama、vLLM、SGLang 及类似的 OpenAI 兼容服务器。

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://localhost:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "compat": {
        "supportsDeveloperRole": false,
        "supportsReasoningEffort": false
      },
      "models": [
        {
          "id": "gpt-oss:20b",
          "reasoning": true
        }
      ]
    }
  }
}
```

## 完整示例

需要特定值时覆盖默认配置：

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://localhost:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "models": [
        {
          "id": "llama3.1:8b",
          "name": "Llama 3.1 8B (Local)",
          "reasoning": false,
          "input": ["text"],
          "contextWindow": 128000,
          "maxTokens": 32000,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    }
  }
}
```

该文件在每次打开 `/model` 时重新加载。会话期间可直接编辑，无需重启。

## Google AI Studio 示例

使用 `google-generative-ai` 并指定 `baseUrl` 来添加来自 Google AI Studio 的模型，包括自定义 Gemma 4 条目：

```json
{
  "providers": {
    "my-google": {
      "baseUrl": "https://generativelanguage.googleapis.com/v1beta",
      "api": "google-generative-ai",
      "apiKey": "$GEMINI_API_KEY",
      "models": [
        {
          "id": "gemma-4-31b-it",
          "name": "Gemma 4 31B",
          "input": ["text", "image"],
          "contextWindow": 262144,
          "reasoning": true
        }
      ]
    }
  }
}
```

向 `google-generative-ai` API 类型添加自定义模型时，`baseUrl` 是必填项。

## 支持的 API

| API | 说明 |
|-----|------|
| `openai-completions` | OpenAI Chat Completions（兼容性最佳） |
| `openai-responses` | OpenAI Responses API |
| `anthropic-messages` | Anthropic Messages API |
| `google-generative-ai` | Google Generative AI |

`api` 可在提供商级别设置（作为所有模型的默认值），也可在模型级别设置（按模型覆盖）。

## 提供商配置

| 字段 | 说明 |
|------|------|
| `baseUrl` | API 端点 URL |
| `api` | API 类型（见上文） |
| `apiKey` | 可选的 API 密钥配置（见下方值解析）。若通过 `/login`/`auth.json` 或 CLI `--api-key` 提供了认证信息，可省略该字段。 |
| `headers` | 自定义请求头（见下方值解析） |
| `authHeader` | 设为 `true` 时自动添加 `Authorization: Bearer <apiKey>` |
| `models` | 模型配置数组 |
| `modelOverrides` | 该提供商上内置模型的按模型覆盖配置 |

对于包含 `models` 的提供商，非内置提供商配置需要在提供商或模型级别提供 `baseUrl` 和 `api`。加载文件时 `apiKey` 不是必填项：当通过 `/login`/`auth.json`、CLI `--api-key` 或提供商 `apiKey` 配置了认证信息时，模型即变为可用。若未配置任何认证信息，模型会加载但在 `/model` 和 `--list-models` 中不可用。

### 值解析 (Value Resolution)

`apiKey` 和 `headers` 字段支持命令执行、环境变量插值和字面量：

- **Shell 命令：** 以 `"!command"` 开头时，将整个值作为命令执行并使用标准输出（stdout）
  ```json
  "apiKey": "!security find-generic-password -ws 'anthropic'"
  "apiKey": "!op read 'op://vault/item/credential'"
  ```
- **环境变量插值：** `"$ENV_VAR"` 或 `"${ENV_VAR}"` 使用命名变量的值。插值可在更大的字面量内部使用。
  ```json
  "apiKey": "$MY_API_KEY"
  "apiKey": "${KEY_PREFIX}_${KEY_SUFFIX}"
  ```
  `$FOO_BAR` 表示变量 `FOO_BAR`；当 `BAR` 是字面文本时使用 `${FOO}_BAR`。缺失的环境变量会导致值无法解析。
- **转义：** `"$$"` 输出字面量 `"$"`；`"$!"` 输出字面量 `"!"` 且不会触发命令执行。
  ```json
  "apiKey": "$$literal-dollar-prefix"
  "apiKey": "$!literal-bang-prefix"
  ```
- **字面量值：** 直接使用。纯大写字符串如 `MY_API_KEY` 为字面量；环境变量请使用 `$MY_API_KEY`。
  ```json
  "apiKey": "sk-..."
  ```

对于 `models.json`，Shell 命令在请求时解析。pi 有意不为任意命令应用内置的 TTL、过期复用或恢复逻辑。不同命令需要不同的缓存和失败策略，而 pi 无法推断出正确的策略。

如果你的命令执行缓慢、开销大、有限频要求，或者在瞬时失败时应继续使用先前的值，请将其包装到你自己的脚本或命令中，实现你期望的缓存或 TTL 行为。

`/model` 可用性检查使用已配置的认证信息存在性判断，不会执行 Shell 命令。

### 自定义请求头

```json
{
  "providers": {
    "custom-proxy": {
      "baseUrl": "https://proxy.example.com/v1",
      "apiKey": "$MY_API_KEY",
      "api": "anthropic-messages",
      "headers": {
        "x-portkey-api-key": "$PORTKEY_API_KEY",
        "x-secret": "!op read 'op://vault/item/secret'"
      },
      "models": [...]
    }
  }
}
```

## 模型配置

| 字段 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `id` | 是 | — | 模型标识符（传递给 API） |
| `name` | 否 | `id` | 人类可读的模型标签。用于匹配（`--model` 模式）并显示为辅助模型详情文本。 |
| `api` | 否 | 提供商的 `api` | 覆盖该模型的提供商 API |
| `reasoning` | 否 | `false` | 支持扩展思考（extended thinking） |
| `thinkingLevelMap` | 否 | 省略 | 将 pi 思考级别映射到提供商标识，并标记不支持的级别（见下文） |
| `input` | 否 | `["text"]` | 输入类型：`["text"]` 或 `["text", "image"]` |
| `contextWindow` | 否 | `128000` | 上下文窗口大小（token 数） |
| `maxTokens` | 否 | `16384` | 最大输出 token 数 |
| `cost` | 否 | 全零 | `{"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0}`（每百万 token） |
| `compat` | 否 | 提供商 `compat` | 提供商兼容性覆盖。两者均设置时，与提供商级 `compat` 合并。 |

当前行为：
- `/model`、`--list-models` 和交互式页脚按模型 `id` 显示条目。
- 配置的 `name` 用于模型匹配和辅助模型详情文本，不会替换页脚/状态栏中的模型 id。

### 思考级别映射 (Thinking Level Map)

在模型上使用 `thinkingLevelMap` 来描述模型特定的思考控制。键为 pi 思考级别：`off`、`minimal`、`low`、`medium`、`high`、`xhigh`。

值为三态：

| 值 | 含义 |
|-----|------|
| 省略 | 该级别受支持，使用提供商默认映射 |
| 字符串 | 该级别受支持，该值发送给提供商 |
| `null` | 该级别不受支持，隐藏/跳过/钳制 |

适用于仅支持关闭、高和最大推理的模型的示例：

```json
{
  "id": "deepseek-v4-pro",
  "reasoning": true,
  "thinkingLevelMap": {
    "minimal": null,
    "low": null,
    "medium": null,
    "high": "high",
    "xhigh": "max"
  }
}
```

适用于思考无法禁用的模型的示例：

```json
{
  "id": "always-thinking-model",
  "reasoning": true,
  "thinkingLevelMap": {
    "off": null
  }
}
```

迁移：使用 `compat.reasoningEffortMap` 的旧配置应将该映射移至模型级 `thinkingLevelMap`。对于不应出现在 UI 中的级别，使用 `null`。

## 覆盖内置提供商

通过代理路由内置提供商而无需重新定义模型：

```json
{
  "providers": {
    "anthropic": {
      "baseUrl": "https://my-proxy.example.com/v1"
    }
  }
}
```

所有内置 Anthropic 模型仍可用。现有的 OAuth 或 API 密钥认证继续生效。

若要将自定义模型合并到内置提供商中，需包含 `models` 数组：

```json
{
  "providers": {
    "anthropic": {
      "baseUrl": "https://my-proxy.example.com/v1",
      "apiKey": "$ANTHROPIC_API_KEY",
      "api": "anthropic-messages",
      "models": [...]
    }
  }
}
```

合并语义：
- 内置模型予以保留。
- 自定义模型按提供商内 `id` 进行更新插入（upsert）。
- 若自定义模型 `id` 与内置模型 `id` 匹配，则自定义模型替换该内置模型。
- 若自定义模型 `id` 为新值，则与内置模型并列添加。

## 按模型覆盖

使用 `modelOverrides` 来自定义特定内置模型，而无需替换提供商的完整模型列表。

```json
{
  "providers": {
    "openrouter": {
      "modelOverrides": {
        "anthropic/claude-sonnet-4": {
          "name": "Claude Sonnet 4 (Bedrock Route)",
          "compat": {
            "openRouterRouting": {
              "only": ["amazon-bedrock"]
            }
          }
        }
      }
    }
  }
}
```

`modelOverrides` 支持每个模型的以下字段：`name`、`reasoning`、`input`、`cost`（部分）、`contextWindow`、`maxTokens`、`headers`、`compat`。

行为说明：
- `modelOverrides` 应用于内置提供商的模型。
- 未知模型 ID 会被忽略。
- 可将提供商级 `baseUrl`/`headers` 与 `modelOverrides` 组合使用。
- 覆盖 `name` 仅改变模型匹配和辅助详情文本；页脚和主模型列表继续显示模型 `id`。
- 若同时为该提供商定义了 `models`，则在内置覆盖之后合并自定义模型。具有相同 `id` 的自定义模型会替换被覆盖的内置模型条目。

## Anthropic Messages 兼容性

对于使用 `api: "anthropic-messages"` 的提供商或代理，可使用 `compat` 来控制 Anthropic 特定的请求兼容性。

默认情况下，pi 会发送每个工具（per-tool）的 `eager_input_streaming: true`。如果代理或 Anthropic 兼容后端拒绝该字段，请将 `supportsEagerToolInputStreaming` 设为 `false`。pi 将省略 `tools[].eager_input_streaming`，并改用旧版 `fine-grained-tool-streaming-2025-05-14` beta 请求头来处理启用工具的请求。

某些 Anthropic 模型需要自适应思考（adaptive thinking）（`thinking.type: "adaptive"` 加上 `output_config.effort`），而非传统的基于 token 预算的思考负载。内置模型会自动设置此项。对于路由到这些模型的自定义提供商或别名，请将 `forceAdaptiveThinking` 设为 `true`。

部分 Anthropic 兼容提供商发出的思考块（thinking blocks）签名（signature）为空，且在回放时仍要求保留它们。请仅为这些提供商将 `allowEmptySignature` 设为 `true`；真实的 Anthropic 服务会拒绝空的思考签名。

```json
{
  "providers": {
    "anthropic-proxy": {
      "baseUrl": "https://proxy.example.com",
      "api": "anthropic-messages",
      "apiKey": "$ANTHROPIC_PROXY_KEY",
      "compat": {
        "supportsEagerToolInputStreaming": false,
        "supportsLongCacheRetention": true,
        "forceAdaptiveThinking": true,
        "allowEmptySignature": true
      },
      "models": [
        {
          "id": "claude-opus-4-7",
          "reasoning": true,
          "input": ["text", "image"]
        }
      ]
    }
  }
}
```

| 字段 | 说明 |
|------|------|
| `supportsEagerToolInputStreaming` | 提供商是否接受每个工具的 `eager_input_streaming`。默认：`true`。设为 `false` 可省略该字段，并在启用工具的请求上使用旧版细粒度工具流 beta 请求头。 |
| `supportsLongCacheRetention` | 提供商是否在缓存保留期为 `long` 时接受 Anthropic 长缓存保留（`cache_control.ttl: "1h"`）。默认：`true`。 |
| `sendSessionAffinityHeaders` | 启用缓存时是否从会话 id 发送 `x-session-affinity`。默认：自动检测已知提供商。 |
| `supportsCacheControlOnTools` | 提供商是否接受工具定义上 Anthropic 风格的 `cache_control` 标记。默认：`true`。 |
| `forceAdaptiveThinking` | 是否为此模型发送自适应思考（`thinking.type: "adaptive"` 加上 `output_config.effort`）。内置自适应模型会自动设置此项。默认：`false`。 |
| `allowEmptySignature` | 是否将空思考签名回放为 `signature: ""`，而非将思考转换为文本。默认：`false`。 |

## OpenAI 兼容性

对于具有部分 OpenAI 兼容性的提供商，可使用 `compat` 字段。

- 提供商级 `compat` 对该提供商下的所有模型应用默认值。
- 模型级 `compat` 对该模型覆盖提供商级值。

```json
{
  "providers": {
    "local-llm": {
      "baseUrl": "http://localhost:8080/v1",
      "api": "openai-completions",
      "compat": {
        "supportsUsageInStreaming": false,
        "maxTokensField": "max_tokens"
      },
      "models": [...]
    }
  }
}
```

| 字段 | 说明 |
|------|------|
| `supportsStore` | 提供商是否支持 `store` 字段 |
| `supportsDeveloperRole` | 使用 `developer` 还是 `system` 角色 |
| `supportsReasoningEffort` | 是否支持 `reasoning_effort` 参数 |
| `supportsUsageInStreaming` | 是否支持 `stream_options: { include_usage: true }`（默认：`true`） |
| `maxTokensField` | 使用 `max_completion_tokens` 还是 `max_tokens` |
| `requiresToolResultName` | 在工具结果消息上包含 `name` |
| `requiresAssistantAfterToolResult` | 工具结果后的用户消息前插入一条 assistant 消息 |
| `requiresThinkingAsText` | 将思考块转换为纯文本 |
| `requiresReasoningContentOnAssistantMessages` | 启用思考时，在所有回放的 assistant 消息上包含空的 `reasoning_content` |
| `thinkingFormat` | 使用 `reasoning_effort`、`openrouter`、`deepseek`、`together`、`zai`、`qwen`、`chat-template` 或 `qwen-chat-template` 思考参数 |
| `chatTemplateKwargs` | `thinkingFormat: "chat-template"` 时 `chat_template_kwargs` 的值；使用 `{ "$var": "thinking.enabled" }` 或 `{ "$var": "thinking.effort" }` 由 pi 控制思考值 |
| `cacheControlFormat` | 在系统提示、最后一个工具定义以及最后一个 user/assistant 文本内容上使用 Anthropic 风格的 `cache_control` 标记。当前仅支持 `anthropic`。 |
| `supportsStrictMode` | 在工具定义中包含 `strict` 字段 |
| `supportsLongCacheRetention` | 提供商是否在缓存保留期为 `long` 时接受长缓存保留：OpenAI 提示缓存使用 `prompt_cache_retention: "24h"`，或当 `cacheControlFormat` 为 `anthropic` 时使用 `cache_control.ttl: "1h"`。默认：`true`。 |
| `openRouterRouting` | OpenRouter 提供商路由偏好。该对象按原样在 [OpenRouter API 请求](https://openrouter.ai/docs/guides/routing/provider-selection)的 `provider` 字段中发送。 |
| `vercelGatewayRouting` | Vercel AI Gateway 用于提供商选择的路由配置（`only`、`order`） |

`openrouter` 使用 `reasoning: { effort }`。`together` 使用 `reasoning: { enabled }`，且在启用 `supportsReasoningEffort` 时还会使用 `reasoning_effort`。`qwen` 使用顶层 `enable_thinking`。对于需要 `chat_template_kwargs.enable_thinking` 和 `preserve_thinking` 的本地 Qwen 兼容服务器，使用 `qwen-chat-template`。对于需要可配置 `chat_template_kwargs` 的 vLLM/Hugging Face 聊天模板，使用 `chat-template`，例如 DeepSeek V3.x 模板使用 `chatTemplateKwargs: { "thinking": { "$var": "thinking.enabled" } }`。

`cacheControlFormat: "anthropic"` 适用于通过文本内容和工具定义上的 `cache_control` 标记暴露 Anthropic 风格提示缓存的 OpenAI 兼容提供商。

示例：

```json
{
  "providers": {
    "openrouter": {
      "baseUrl": "https://openrouter.ai/api/v1",
      "apiKey": "$OPENROUTER_API_KEY",
      "api": "openai-completions",
      "models": [
        {
          "id": "openrouter/anthropic/claude-3.5-sonnet",
          "name": "OpenRouter Claude 3.5 Sonnet",
          "compat": {
            "openRouterRouting": {
              "allow_fallbacks": true,
              "require_parameters": false,
              "data_collection": "deny",
              "zdr": true,
              "enforce_distillable_text": false,
              "order": ["anthropic", "amazon-bedrock", "google-vertex"],
              "only": ["anthropic", "amazon-bedrock"],
              "ignore": ["gmicloud", "friendli"],
              "quantizations": ["fp16", "bf16"],
              "sort": {
                "by": "price",
                "partition": "model"
              },
              "max_price": {
                "prompt": 10,
                "completion": 20
              },
              "preferred_min_throughput": {
                "p50": 100,
                "p90": 50
              },
              "preferred_max_latency": {
                "p50": 1,
                "p90": 3,
                "p99": 5
              }
            }
          }
        }
      ]
    }
  }
}
```

Vercel AI Gateway 示例：

```json
{
  "providers": {
    "vercel-ai-gateway": {
      "baseUrl": "https://ai-gateway.vercel.sh/v1",
      "apiKey": "$AI_GATEWAY_API_KEY",
      "api": "openai-completions",
      "models": [
        {
          "id": "moonshotai/kimi-k2.5",
          "name": "Kimi K2.5 (Fireworks via Vercel)",
          "reasoning": true,
          "input": ["text", "image"],
          "cost": { "input": 0.6, "output": 3, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 262144,
          "maxTokens": 262144,
          "compat": {
            "vercelGatewayRouting": {
              "only": ["fireworks", "novita"],
              "order": ["fireworks", "novita"]
            }
          }
        }
      ]
    }
  }
}
```
