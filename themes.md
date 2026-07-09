> pi 可以创建主题。让它为你的环境构建一个吧。

# 主题（Themes）

主题是 JSON 文件，用于定义 TUI 的色彩。

## 目录

- [位置](#位置)
- [选择主题](#选择主题)
- [创建自定义主题](#创建自定义主题)
- [主题格式](#主题格式)
- [颜色令牌（Color Tokens）](#颜色令牌color-tokens)
- [颜色值](#颜色值)
- [提示](#提示)

## 位置

Pi 从以下位置加载主题：

- 内置：`dark`、`light`
- 全局：`~/.pi/agent/themes/*.json`
- 项目：`.pi/themes/*.json`（仅在项目被信任后生效）
- 包：`themes/` 目录或 `package.json` 中的 `pi.themes` 条目
- 设置：包含文件或目录的 `themes` 数组
- CLI：`--theme <path>`（可重复）

使用 `--no-themes` 可禁用主题发现。

## 选择主题

通过 `/settings` 或在 `settings.json` 中选择主题：

```json
{
  "theme": "my-theme"
}
```

首次运行时，pi 会检测你的终端背景并默认选用 `dark` 或 `light`。

## 创建自定义主题

1. 创建主题文件：

```bash
mkdir -p ~/.pi/agent/themes
vim ~/.pi/agent/themes/my-theme.json
```

2. 定义主题并包含所有必需的颜色（参见 [颜色令牌](#颜色令牌color-tokens)）：

```json
{
  "$schema": "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
  "name": "my-theme",
  "vars": {
    "primary": "#00aaff",
    "secondary": 242
  },
  "colors": {
    "accent": "primary",
    "border": "primary",
    "borderAccent": "#00ffff",
    "borderMuted": "secondary",
    "success": "#00ff00",
    "error": "#ff0000",
    "warning": "#ffff00",
    "muted": "secondary",
    "dim": 240,
    "text": "",
    "thinkingText": "secondary",
    "selectedBg": "#2d2d30",
    "userMessageBg": "#2d2d30",
    "userMessageText": "",
    "customMessageBg": "#2d2d30",
    "customMessageText": "",
    "customMessageLabel": "primary",
    "toolPendingBg": "#1e1e2e",
    "toolSuccessBg": "#1e2e1e",
    "toolErrorBg": "#2e1e1e",
    "toolTitle": "primary",
    "toolOutput": "",
    "mdHeading": "#ffaa00",
    "mdLink": "primary",
    "mdLinkUrl": "secondary",
    "mdCode": "#00ffff",
    "mdCodeBlock": "",
    "mdCodeBlockBorder": "secondary",
    "mdQuote": "secondary",
    "mdQuoteBorder": "secondary",
    "mdHr": "secondary",
    "mdListBullet": "#00ffff",
    "toolDiffAdded": "#00ff00",
    "toolDiffRemoved": "#ff0000",
    "toolDiffContext": "secondary",
    "syntaxComment": "secondary",
    "syntaxKeyword": "primary",
    "syntaxFunction": "#00aaff",
    "syntaxVariable": "#ffaa00",
    "syntaxString": "#00ff00",
    "syntaxNumber": "#ff00ff",
    "syntaxType": "#00aaff",
    "syntaxOperator": "primary",
    "syntaxPunctuation": "secondary",
    "thinkingOff": "secondary",
    "thinkingMinimal": "primary",
    "thinkingLow": "#00aaff",
    "thinkingMedium": "#00ffff",
    "thinkingHigh": "#ff00ff",
    "thinkingXhigh": "#ff0000",
    "bashMode": "#ffaa00"
  }
}
```

3. 通过 `/settings` 选择该主题。

**热重载（Hot reload）：** 当你编辑当前处于活跃状态的自定义主题文件时，pi 会自动重新加载以即时呈现视觉效果。

## 主题格式

```json
{
  "$schema": "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
  "name": "my-theme",
  "vars": {
    "blue": "#0066cc",
    "gray": 242
  },
  "colors": {
    "accent": "blue",
    "muted": "gray",
    "text": "",
    ...
  }
}
```

- `name` 为必填项，必须唯一，且不得包含 `/`。
- `vars` 为可选项。在此定义可复用的颜色，然后在 `colors` 中引用。
- `colors` 必须定义全部 51 个必需令牌。

`$schema` 字段用于启用编辑器的自动补全和校验。

## 颜色令牌（Color Tokens）

每个主题必须定义全部 51 个颜色令牌，没有可选颜色。

### 核心 UI（11 个颜色）

| 令牌 | 用途 |
|-------|---------|
| `accent` | 主要强调色（Logo、选中项、光标） |
| `border` | 普通边框 |
| `borderAccent` | 高亮边框 |
| `borderMuted` | 弱化边框（编辑器） |
| `success` | 成功状态 |
| `error` | 错误状态 |
| `warning` | 警告状态 |
| `muted` | 次要文本 |
| `dim` | 第三级文本 |
| `text` | 默认文本（通常为 `""`） |
| `thinkingText` | 思考块文本 |

### 背景与内容（11 个颜色）

| 令牌 | 用途 |
|-------|---------|
| `selectedBg` | 选中行背景 |
| `userMessageBg` | 用户消息背景 |
| `userMessageText` | 用户消息文本 |
| `customMessageBg` | 扩展消息背景 |
| `customMessageText` | 扩展消息文本 |
| `customMessageLabel` | 扩展消息标签 |
| `toolPendingBg` | 工具框（待处理） |
| `toolSuccessBg` | 工具框（成功） |
| `toolErrorBg` | 工具框（错误） |
| `toolTitle` | 工具标题 |
| `toolOutput` | 工具输出文本 |

### Markdown（10 个颜色）

| 令牌 | 用途 |
|-------|---------|
| `mdHeading` | 标题 |
| `mdLink` | 链接文本 |
| `mdLinkUrl` | 链接 URL |
| `mdCode` | 行内代码 |
| `mdCodeBlock` | 代码块内容 |
| `mdCodeBlockBorder` | 代码块围栏 |
| `mdQuote` | 引用文本 |
| `mdQuoteBorder` | 引用边框 |
| `mdHr` | 水平分割线 |
| `mdListBullet` | 列表项目符号 |

### 工具差异对比（3 个颜色）

| 令牌 | 用途 |
|-------|---------|
| `toolDiffAdded` | 新增行 |
| `toolDiffRemoved` | 删除行 |
| `toolDiffContext` | 上下文行 |

### 语法高亮（9 个颜色）

| 令牌 | 用途 |
|-------|---------|
| `syntaxComment` | 注释 |
| `syntaxKeyword` | 关键字 |
| `syntaxFunction` | 函数名 |
| `syntaxVariable` | 变量 |
| `syntaxString` | 字符串 |
| `syntaxNumber` | 数字 |
| `syntaxType` | 类型 |
| `syntaxOperator` | 操作符 |
| `syntaxPunctuation` | 标点符号 |

### 思考级别边框（6 个颜色）

编辑器边框颜色，用于表示思考级别（视觉层次由弱到强）：

| 令牌 | 用途 |
|-------|---------|
| `thinkingOff` | 思考关闭 |
| `thinkingMinimal` | 最低思考 |
| `thinkingLow` | 低度思考 |
| `thinkingMedium` | 中度思考 |
| `thinkingHigh` | 高度思考 |
| `thinkingXhigh` | 超高思考 |

### Bash 模式（1 个颜色）

| 令牌 | 用途 |
|-------|---------|
| `bashMode` | bash 模式下的编辑器边框（`!` 前缀） |

### HTML 导出（可选）

`export` 部分控制 `/export` 输出的 HTML 颜色。若省略，颜色将从 `userMessageBg` 推导。

```json
{
  "export": {
    "pageBg": "#18181e",
    "cardBg": "#1e1e24",
    "infoBg": "#3c3728"
  }
}
```

## 颜色值

支持四种格式：

| 格式 | 示例 | 说明 |
|--------|---------|-------------|
| Hex | `"#ff0000"` | 6 位十六进制 RGB |
| 256 色 | `39` | xterm 256 色调色板索引（0-255） |
| 变量 | `"primary"` | 引用 `vars` 中的条目 |
| 默认 | `""` | 终端默认颜色 |

### 256 色调色板

- `0-15`：基础 ANSI 颜色（因终端而异）
- `16-231`：6×6×6 RGB 立方体（`16 + 36×R + 6×G + B`，其中 R、G、B 取值 0-5）
- `232-255`：灰阶渐变

### 终端兼容性

Pi 使用 24 位 RGB 颜色。大多数现代终端均支持此特性（iTerm2、Kitty、WezTerm、Windows Terminal、VS Code）。对于仅支持 256 色的旧终端，pi 将回退至最接近的近似值。

检查 truecolor 支持：

```bash
echo $COLORTERM  # 应输出 "truecolor" 或 "24bit"
```

## 提示

**暗色终端：** 使用明亮、饱和度较高的颜色，对比度适当提高。

**亮色终端：** 使用较暗、柔和的颜色，对比度适当降低。

**色彩协调：** 从一个基础调色板（Nord、Gruvbox、Tokyo Night）开始，在 `vars` 中定义并统一引用。

**测试：** 使用不同的消息类型、工具状态、Markdown 内容和长换行文本来检查主题效果。

**VS Code：** 将 `terminal.integrated.minimumContrastRatio` 设为 `1` 以获得准确的颜色呈现。

## 示例

参见内置主题：
- [dark.json](../src/modes/interactive/theme/dark.json)
- [light.json](../src/modes/interactive/theme/light.json)
