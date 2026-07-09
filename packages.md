> pi 可以帮助你创建 pi 包（package）。让它帮你打包扩展（extensions）、技能（skills）、提示模板（prompt templates）或主题（themes）。

# Pi 包

Pi 包（package）可以将扩展、技能、提示模板和主题打包在一起，以便通过 npm 或 git 分享。包可以在 `package.json` 的 `pi` 键下声明资源，也可以使用约定目录。

## 目录

- [安装与管理](#安装与管理)
- [包来源](#包来源)
- [创建 Pi 包](#创建-pi-包)
- [包结构](#包结构)
- [依赖](#依赖)
- [包过滤](#包过滤)
- [启用和禁用资源](#启用和禁用资源)
- [作用域与去重](#作用域与去重)

## 安装与管理

> **安全性：** Pi 包以完整系统权限运行。扩展可以执行任意代码，技能可以指示模型执行任何操作，包括运行可执行文件。安装第三方包之前请审查源代码。

```bash
pi install npm:@foo/bar@1.0.0
pi install git:github.com/user/repo@v1
pi install https://github.com/user/repo  # 也支持原始 URL
pi install /absolute/path/to/package
pi install ./relative/path/to/package

pi remove npm:@foo/bar
pi list                     # 显示设置中已安装的包
pi update                   # 仅更新 pi
pi update --all             # 更新 pi、更新包，并协调固定的 git ref
pi update --extensions      # 仅更新包并协调固定的 git ref
pi update --self            # 仅更新 pi
pi update --self --force    # 即使当前已是最新也重新安装 pi
pi update npm:@foo/bar      # 更新单个包
pi update --extension npm:@foo/bar
```

这些命令用于管理 pi 包，`pi update` 还可以更新 pi CLI 的安装。如需卸载 pi 本身，请参阅 [快速入门](quickstart.md#uninstall)。

默认情况下，`install` 和 `remove` 会写入用户设置（`~/.pi/agent/settings.json`）。使用 `-l` 可改为写入项目设置（`.pi/settings.json`）。项目设置可以与团队共享，pi 在项目受信任后启动时会自动安装任何缺失的包。

要在不安装的情况下试用某个包，使用 `--extension` 或 `-e`。这会将包安装到临时目录中，仅供当前运行使用：

```bash
pi -e npm:@foo/bar
pi -e git:github.com/user/repo
```

## 包来源

Pi 在设置和 `pi install` 中接受三种来源类型。

### npm

```
npm:@scope/pkg@1.2.3
npm:pkg
```

- 带有版本号的规格会被固定，包更新时会跳过（`pi update --extensions`、`pi update --all`）。
- 用户安装在 `~/.pi/agent/npm/` 下。
- 项目安装在 `.pi/npm/` 下。
- 在 `settings.json` 中设置 `npmCommand` 可以将 npm 包查找和安装操作固定到特定的封装命令（例如 `mise` 或 `asdf`）。

示例：

```json
{
  "npmCommand": ["mise", "exec", "node@20", "--", "npm"]
}
```

### git

```
git:github.com/user/repo@v1
git:git@github.com:user/repo@v1
https://github.com/user/repo@v1
ssh://git@github.com/user/repo@v1
```

- 不带 `git:` 前缀时，仅接受协议 URL（`https://`、`http://`、`ssh://`、`git://`）。
- 带 `git:` 前缀时，接受简写格式，包括 `github.com/user/repo` 和 `git@github.com:user/repo`。
- 同时支持 HTTPS 和 SSH URL。
- SSH URL 会自动使用你配置的 SSH 密钥（遵循 `~/.ssh/config`）。
- 对于非交互式运行（例如 CI），可以设置 `GIT_TERMINAL_PROMPT=0` 来禁用凭据提示，并设置 `GIT_SSH_COMMAND`（例如 `ssh -o BatchMode=yes -o ConnectTimeout=5`）以快速失败。
- Ref 是被固定的标签或提交。`pi update --extensions` 和 `pi update --all` 不会将其移动到更新的 ref，但会将现有的克隆协调到配置的 ref。
- 使用 `pi install git:host/user/repo@new-ref` 可更新设置并将现有包移动到新的固定 ref。
- 克隆到 `~/.pi/agent/git/<host>/<path>`（全局）或 `.pi/git/<host>/<path>`（项目）。
- 当协调更改了检出内容时，pi 会重置并清理克隆，然后如果存在 `package.json` 则运行 `npm install`。

**SSH 示例：**
```bash
# git@host:path 简写格式（需要 git: 前缀）
pi install git:git@github.com:user/repo

# ssh:// 协议格式
pi install ssh://git@github.com/user/repo

# 带版本 ref
pi install git:git@github.com:user/repo@v1.0.0
```

### 本地路径

```
/absolute/path/to/package
./relative/path/to/package
```

本地路径指向磁盘上的文件或目录，会被添加到设置中而不会复制。相对路径是相对于其所在设置文件解析的。如果路径是文件，则作为单个扩展加载。如果路径是目录，则 pi 会按包规则加载资源。

## 创建 Pi 包

在 `package.json` 中添加 `pi` 清单或使用约定目录。包含 `pi-package` 关键字以提高可发现性。

```json
{
  "name": "my-package",
  "keywords": ["pi-package"],
  "pi": {
    "extensions": ["./extensions"],
    "skills": ["./skills"],
    "prompts": ["./prompts"],
    "themes": ["./themes"]
  }
}
```

路径相对于包根目录。数组支持 glob 模式和 `!排除项`。

### 画廊元数据

[包画廊（package gallery）](https://pi.dev/packages) 展示标记了 `pi-package` 的包。添加 `video` 或 `image` 字段可显示预览：

```json
{
  "name": "my-package",
  "keywords": ["pi-package"],
  "pi": {
    "extensions": ["./extensions"],
    "video": "https://example.com/demo.mp4",
    "image": "https://example.com/screenshot.png"
  }
}
```

- **video**：仅限 MP4。在桌面端，鼠标悬停时自动播放。点击可打开全屏播放器。
- **image**：PNG、JPEG、GIF 或 WebP。以静态预览形式显示。

如果两者都设置，video 优先。

## 包结构

### 约定目录

如果没有 `pi` 清单，pi 会自动从以下目录发现资源：

- `extensions/` 加载 `.ts` 和 `.js` 文件
- `skills/` 递归查找 `SKILL.md` 文件夹并将顶层 `.md` 文件作为技能加载
- `prompts/` 加载 `.md` 文件
- `themes/` 加载 `.json` 文件

## 依赖

第三方运行时依赖应放在 `package.json` 的 `dependencies` 中。不注册扩展、技能、提示模板或主题的依赖也应放在 `dependencies` 中。当 pi 从 npm 或 git 安装包时会运行 `npm install`，因此这些依赖会被自动安装。

Pi 为扩展和技能捆绑了核心包。如果你导入了其中任何一个，请将它们列在 `peerDependencies` 中并使用 `"*"` 范围，且不要打包它们：`@earendil-works/pi-ai`、`@earendil-works/pi-agent-core`、`@earendil-works/pi-coding-agent`、`@earendil-works/pi-tui`、`typebox`。

其他 pi 包必须被打包进你的 tarball 中。将它们添加到 `dependencies` 和 `bundledDependencies` 中，然后通过 `node_modules/` 路径引用它们的资源。Pi 使用独立的模块根目录加载包，因此独立的安装不会冲突或共享模块。

示例：

```json
{
  "dependencies": {
    "shitty-extensions": "^1.0.1"
  },
  "bundledDependencies": ["shitty-extensions"],
  "pi": {
    "extensions": ["extensions", "node_modules/shitty-extensions/extensions"],
    "skills": ["skills", "node_modules/shitty-extensions/skills"]
  }
}
```

## 包过滤

使用设置中的对象形式来过滤包的加载内容：

```json
{
  "packages": [
    "npm:simple-pkg",
    {
      "source": "npm:my-package",
      "extensions": ["extensions/*.ts", "!extensions/legacy.ts"],
      "skills": [],
      "prompts": ["prompts/review.md"],
      "themes": ["+themes/legacy.json"]
    }
  ]
}
```

`+path` 和 `-path` 是相对于包根目录的精确路径。

- 省略某个键会加载该类型的所有资源。
- 使用 `[]` 不加载该类型的任何资源。
- `!pattern` 排除匹配项。
- `+path` 强制包含某个精确路径。
- `-path` 强制排除某个精确路径。
- 过滤器叠加在清单之上，用于缩小已允许的范围。

## 启用和禁用资源

使用 `pi config` 可以启用或禁用已安装包和本地目录中的扩展、技能、提示模板和主题。`pi config` 默认从全局设置（`~/.pi/agent/settings.json`）开始；按 Tab 可在全局和项目本地模式之间切换。使用 `pi config -l` 可从项目覆盖（`.pi/settings.json`）开始，继承的全局资源会变暗显示。

## 作用域与去重

包可以同时出现在全局和项目设置中。如果同一个包同时出现在两者中，项目条目优先，除非项目条目设置了 `autoload: false`，此时它将作为全局条目的增量应用。身份由以下方式确定：

- npm：包名
- git：不带 ref 的仓库 URL
- 本地：解析后的绝对路径
