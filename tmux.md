# tmux 环境配置

Pi 可以在 tmux 内运行，但 tmux 默认会剥离某些按键的修饰键信息。未配置时，`Shift+Enter` 和 `Ctrl+Enter` 通常无法与普通 `Enter` 区分。

## 推荐配置

在 `~/.tmux.conf` 中添加：

```tmux
set -g extended-keys on
set -g extended-keys-format csi-u
```

然后完全重启 tmux：

```bash
tmux kill-server
tmux
```

当 Kitty 键盘协议不可用时，pi 会自动请求扩展键报告。配合 `extended-keys-format csi-u`，tmux 会以 CSI-u 格式转发修改键，这是最可靠的配置。`extended-keys-format` 选项需要 tmux 3.5 或更高版本。

## 为何推荐 `csi-u`

仅使用：

```tmux
set -g extended-keys on
```

时，tmux 默认采用 `extended-keys-format xterm`。当应用请求扩展键报告时，修改键以 xterm `modifyOtherKeys` 格式转发，例如：

- `Ctrl+C` → `\x1b[27;5;99~`
- `Ctrl+D` → `\x1b[27;5;100~`
- `Ctrl+Enter` → `\x1b[27;5;13~`

使用 `extended-keys-format csi-u` 时，相同按键被转发为：

- `Ctrl+C` → `\x1b[99;5u`
- `Ctrl+D` → `\x1b[100;5u`
- `Ctrl+Enter` → `\x1b[13;5u`

Pi 同时支持两种格式，但 `csi-u` 是推荐的 tmux 配置。

## 修复效果

未启用 tmux 扩展键时，修改的 Enter 键会退化为传统序列：

| 按键 | 无 extkeys | 启用 `csi-u` |
|-----|-----------|--------------|
| Enter | `\r` | `\r` |
| Shift+Enter | `\r` | `\x1b[13;2u` |
| Ctrl+Enter | `\r` | `\x1b[13;5u` |
| Alt/Option+Enter | `\x1b\r` | `\x1b[13;3u` |

这会影响默认键绑定（`Enter` 提交、`Shift+Enter` 换行）以及使用修改 Enter 键的任何自定义键绑定。

## 要求

- `extended-keys-format csi-u` 需要 tmux 3.5 或更高版本（运行 `tmux -V` 检查）
- 需要支持扩展键的终端模拟器（Ghostty、Kitty、iTerm2、WezTerm、Windows Terminal）

对于 tmux 3.2 至 3.4，省略 `extended-keys-format csi-u`；pi 仍支持 tmux 默认的 xterm `modifyOtherKeys` 格式。
