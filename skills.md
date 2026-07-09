> pi 可以创建 skills。让 pi 为你的使用场景构建一个。

# Skills（技能）

Skills 是智能体（agent）按需加载的自包含能力包。一个 skill 会为特定任务提供专门的工作流、设置说明、辅助脚本和参考文档。

Pi 实现了 [Agent Skills 标准](https://agentskills.io/specification)，对大多数违规情况发出警告但仍保持宽松。Pi 允许 skill 名称与其父目录名称不同，尽管该标准不允许；这一规则对于跨多个智能体框架（harness）使用的共享 skill 目录而言并不理想。

## 目录

- [存放位置](#存放位置)
- [Skills 工作原理](#skills-工作原理)
- [Skill 命令](#skill-命令)
- [Skill 结构](#skill-结构)
- [Frontmatter](#frontmatter)
- [校验](#校验)
- [示例](#示例)
- [Skill 仓库](#skill-仓库)

## 存放位置

> **安全提示：** Skills 可以指示模型执行任何操作，且可能包含模型调用执行的可执行代码。使用前请审查 skill 内容。

Pi 从以下位置加载 skills：

- 全局（Global）：
  - `~/.pi/agent/skills/`
  - `~/.agents/skills/`
- 项目（仅在被信任的项目中）：
  - `.pi/skills/`
  - `cwd` 及祖先目录中的 `.agents/skills/`（向上至 git 仓库根目录，若在仓库中则至文件系统根目录）
- 包（Packages）：`skills/` 目录或 `package.json` 中的 `pi.skills` 条目
- 设置（Settings）：包含文件或目录的 `skills` 数组
- 命令行：`--skill <path>`（可重复，即使使用 `--no-skills` 也会叠加加载）

发现规则：
- 在 `~/.pi/agent/skills/` 和 `.pi/skills/` 中，根目录下的 `.md` 文件会被作为独立 skill 发现
- 在所有 skill 位置中，包含 `SKILL.md` 的目录会被递归发现
- 在 `~/.agents/skills/` 和项目 `.agents/skills/` 中，根目录下的 `.md` 文件会被忽略

使用 `--no-skills` 禁用发现（显式指定的 `--skill` 路径仍会加载）。

### 使用来自其他框架的 Skills

要使用 Claude Code 或 OpenAI Codex 的 skills，将其目录添加到设置中：

```json
{
  "skills": [
    "~/.claude/skills",
    "~/.codex/skills"
  ]
}
```

对于项目级别的 Claude Code skills，添加到 `.pi/settings.json`：

```json
{
  "skills": ["../.claude/skills"]
}
```

## Skills 工作原理

1. 启动时，pi 扫描 skill 位置并提取名称和描述
2. 系统提示词（system prompt）按照[规范](https://agentskills.io/integrate-skills)以 XML 格式包含可用的 skills
3. 当任务匹配时，智能体使用 `read` 加载完整的 SKILL.md（模型并不总是会这样做；可使用提示或 `/skill:name` 强制加载）
4. 智能体遵循指令，使用相对路径引用脚本和资源

这是一种渐进式披露（progressive disclosure）：只有描述始终在上下文中，完整指令按需加载。

## Skill 命令

Skills 注册为 `/skill:name` 命令：

```bash
/skill:brave-search           # 加载并执行该 skill
/skill:pdf-tools extract      # 带参数加载 skill
```

命令后的参数会作为 `User: <args>` 追加到 skill 内容中。

在交互模式中通过 `/settings` 或在 `settings.json` 中切换 skill 命令：

```json
{
  "enableSkillCommands": true
}
```

## Skill 结构

一个 skill 是一个包含 `SKILL.md` 文件的目录。其他内容格式自由。

```
my-skill/
├── SKILL.md              # 必需：frontmatter + 指令
├── scripts/              # 辅助脚本
│   └── process.sh
├── references/           # 按需加载的详细文档
│   └── api-reference.md
└── assets/
    └── template.json
```

### SKILL.md 格式

````markdown
---
name: my-skill
description: 该 skill 的用途及使用场景。请写具体。
---

# My Skill

## 设置

首次使用前运行一次：
```bash
cd /path/to/skill && npm install
```

## 用法

```bash
./scripts/process.sh <input>
```
````

使用基于 skill 目录的相对路径：

```markdown
详见[参考指南](references/REFERENCE.md)。
```

## Frontmatter

遵循 [Agent Skills 规范](https://agentskills.io/specification#frontmatter-required)：

| 字段 | 是否必需 | 说明 |
|-------|----------|-------------|
| `name` | 是 | 最多 64 个字符。小写字母 a-z、数字 0-9、连字符。与标准不同的是，Pi 不要求此字段与父目录名称匹配，因为该标准要求对于共享 skill 目录而言并不理想。 |
| `description` | 是 | 最多 1024 个字符。说明该 skill 的用途及使用场景。 |
| `license` | 否 | 许可证名称或引用捆绑的文件。 |
| `compatibility` | 否 | 最多 500 个字符。环境要求。 |
| `metadata` | 否 | 任意键值对映射。 |
| `allowed-tools` | 否 | 以空格分隔的预批准工具列表（实验性）。 |
| `disable-model-invocation` | 否 | 设为 `true` 时，skill 对系统提示词隐藏。用户必须使用 `/skill:name` 调用。 |

### 命名规则

- 1-64 个字符
- 仅允许小写字母、数字、连字符
- 不能以连字符开头或结尾
- 不能有连续的连字符
Pi 不要求名称与父目录匹配。Agent Skills 标准有该要求，但对于多个工具使用的共享 skill 目录而言，该要求并不理想。

有效：`pdf-processing`、`data-analysis`、`code-review`
无效：`PDF-Processing`、`-pdf`、`pdf--processing`

### 描述最佳实践

描述决定了智能体何时加载该 skill。请写具体。

好的示例：
```yaml
description: 从 PDF 文件中提取文本和表格、填写 PDF 表单、合并多个 PDF。在处理 PDF 文档时使用。
```

差的示例：
```yaml
description: 帮助处理 PDF。
```

## 校验

Pi 根据 Agent Skills 标准校验 skills。大多数问题会产生警告但仍会加载该 skill：

- 名称超过 64 个字符或包含无效字符
- 名称以连字符开头/结尾或有连续连字符
- 描述超过 1024 个字符

未知的 frontmatter 字段会被忽略。

**例外：** 缺少 description 的 skill 不会被加载。

名称冲突（不同位置的同名 skill）会发出警告并保留首个发现的 skill。

## 示例

```
brave-search/
├── SKILL.md
├── search.js
└── content.js
```

**SKILL.md：**
````markdown
---
name: brave-search
description: 通过 Brave Search API 进行网页搜索和内容提取。用于搜索文档、事实或任何网页内容。
---

# Brave Search

## 设置

```bash
cd /path/to/brave-search && npm install
```

## 搜索

```bash
./search.js "query"              # 基础搜索
./search.js "query" --content    # 包含页面内容
```

## 提取页面内容

```bash
./content.js https://example.com
```
````

## Skill 仓库

- [Anthropic Skills](https://github.com/anthropics/skills) - 文档处理（docx、pdf、pptx、xlsx）、Web 开发
- [Pi Skills](https://github.com/badlogic/pi-skills) - 网页搜索、浏览器自动化、Google APIs、转录
