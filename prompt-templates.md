> pi 可以创建提示词模板。让它为你的工作流构建一个。

# 提示词模板

提示词模板是 Markdown 片段，可展开为完整提示词。在编辑器中键入 `/name` 即可调用模板，其中 `name` 是不含 `.md` 的文件名。

## 加载位置

Pi 从以下位置加载提示词模板：

- 全局：`~/.pi/agent/prompts/*.md`
- 项目：`.pi/prompts/*.md`（仅项目被信任后）
- 包：`prompts/` 目录或 `package.json` 中的 `pi.prompts` 条目
- 设置：包含文件或目录的 `prompts` 数组
- CLI：`--prompt-template <path>`（可重复）

使用 `--no-prompt-templates` 禁用发现。

## 格式

```markdown
---
description: 审查暂存的 git 变更
---
审查暂存的变更（`git diff --cached`）。重点关注：
- Bug 和逻辑错误
- 安全问题
- 错误处理遗漏
```

- 文件名即命令名。`review.md` 变为 `/review`。
- `description` 可选。缺失时使用首个非空行。
- `argument-hint` 可选。设置后，在自动补全下拉框中显示在描述之前。

### 参数提示

在 frontmatter 中使用 `argument-hint` 在自动补全中展示预期参数。使用 `<尖括号>` 表示必需参数，`[方括号]` 表示可选参数：

```markdown
---
description: 通过 URL 审查 PR，包含结构化问题和代码分析
argument-hint: "<PR-URL>"
---
```

在自动补全下拉框中渲染为：

```
→ pr   <PR-URL>       — 通过 URL 审查 PR，包含结构化问题和代码分析
  is   <issue>        — 分析 GitHub issues（Bug 或功能请求）
  wr   [instructions] — 端到端完成当前任务
  cl   — 发布前审计变更日志条目
```

## 使用方法

在编辑器中键入 `/` 后跟模板名称。自动补全会显示可用模板及其描述。

```
/review                           # 展开 review.md
/component Button                 # 带参数展开
/component Button "click handler" # 多参数
```

## 参数

模板支持位置参数、默认值和简单切片：

- `$1`, `$2`, ... 位置参数
- `$@` 或 `$ARGUMENTS` 表示所有参数拼接
- `${1:-default}` 在参数 1 存在/非空时使用，否则使用 `default`
- `${@:N}` 表示从第 N 个位置开始的参数（从 1 开始计数）
- `${@:N:L}` 表示从 N 开始的 L 个参数

示例：

```markdown
---
description: 创建一个组件
---
创建一个名为 $1 的 React 组件，功能包括：$@
```

默认值对可选参数很有用：

```markdown
用 ${1:-7} 个要点总结当前状态。
```

用法：`/component Button "onClick handler" "disabled support"`

## 加载规则

- `prompts/` 中的模板发现是非递归的。
- 如需子目录中的模板，请通过 `prompts` 设置或包清单显式添加。
