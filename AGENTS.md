# AGENTS.md

Pi 官方文档的**中文翻译仓库**。不是 `pi-mono` 源码；上游文档与实现见 [earendil-works/pi-mono](https://github.com/earendil-works/pi-mono)。

## 仓库结构

- 根目录扁平 `*.md`：每页一篇文档
- `docs.json`：导航树与 `redirects`（改名/增删页面时必须同步）
- `images/`：文档插图（路径与正文引用一致）
- `UPSTREAM`：上游 pin（commit + path）
- `vendor/pi-mono`：**submodule**，指向 pi-mono，checkout 应等于 `UPSTREAM.commit`（勿用 `upstream/` 目录名——与 `UPSTREAM` 在 macOS 大小写不敏感盘冲突）
- `scripts/check-upstream.sh`：对照远端 docs 变更

无 `package.json`、无构建/测试/lint。验证 = 通读 diff + 检查 `docs.json` 链接仍有效。

## 翻译约定

- **正文中文**；代码块、CLI 标志、API/类型/字段名、包名、路径、JSON key **保持英文**
- 产品名保留 `Pi` / `pi`；术语首次可「中文（English）」，之后可只用中文或英文专名
- 标题：优先中文；专有名词/API 小节名可保留英文（与代码一致）
- **不要**改代码示例逻辑；注释可译为中文
- 表格中说明性文字译中文，标识符列保持英文
- 锚点 TOC（`#english-slug`）若与标题语言不一致，改标题时同步检查页内链接

## 链接

- 指向本仓库其它文档：用相对路径，如 `[Sessions](sessions.md)`
- 指向源码：用 pi-mono 的 **GitHub 绝对 URL**（`https://github.com/earendil-works/pi-mono/blob/main/...`）
- **禁止**依赖 monorepo 相对路径（如 `../src/...`、`../examples/...`）——本仓独立，这些链接会失效。若原文是相对路径，改为 GitHub URL 或删掉失效链接并注明上游路径
- `docs.json` 的 `redirects` 保留旧路径映射，勿随意删除

## 工作流

1. **上游版本**：`UPSTREAM.commit` 与 `vendor/pi-mono` 一致。克隆后：`git submodule update --init`
2. **有无更新 / 新增页**：
   ```bash
   ./scripts/check-upstream.sh          # pin vs 远端 main
   ./scripts/check-upstream.sh files    # M/A/D/R
   ./scripts/check-upstream.sh diff settings.md
   ./scripts/check-upstream.sh pages    # 文件名集合差
   ```
   不要在本仓对 `$PIN..main` 跑 git log（SHA 只存在于 pi-mono / submodule）
3. 取原文：`vendor/pi-mono/packages/coding-agent/docs/<file>.md`，或 raw URL 带 commit
4. 跟上游：按 `files` 列表改译文 → 更新 `UPSTREAM.commit` → `git -C vendor/pi-mono checkout --detach <newsha>` → `git add UPSTREAM vendor/pi-mono`
5. 大文件可分段提交；提交信息：`docs: 翻译 <file> 为中文` 或 `docs: 同步上游 <shortsha> …`
6. 新增/重命名页面：更新 `docs.json` 的 `navigation`，必要时加 `redirects`，并改 `index.md` 等交叉引用
7. 插图：放 `images/`，正文用相对路径引用


## 已知坑

- 部分标题/表头/注释可能仍残留英文——修到触及处即可，勿为「全库标题统一」做无关大改
- 长文（`extensions.md`、`sdk.md`）易漏译；改前用中英比例或未译小节扫一遍

## 不要做

- 不要把本仓当成可运行的 Pi 应用去 `npm install` / 跑测试
- 不要「改进」未要求翻译的技术内容或擅自与上游行为不一致
- 不要提交密钥或把上游 monorepo 的 `AGENTS.md` 开发规范整份拷进来（那是源码仓的）
