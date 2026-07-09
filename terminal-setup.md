# 终端配置

Pi 使用 [Kitty 键盘协议](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)实现可靠的修饰键检测。大多数现代终端支持此协议，但部分需要配置。

## Kitty、iTerm2

开箱即用。

## Apple Terminal

Pi 在可用时会启用增强键报告。如果 Terminal.app 对 `Shift+Enter` 仍发送普通 Return，pi 会使用本地 macOS 修饰键回退，将该 Return 视为 `Shift+Enter`。

此回退仅在 pi 与 Terminal.app 运行在同一台 Mac 上时有效。通过远程 SSH 无法检测本地键盘。

## Ghostty

在 Ghostty 配置中添加（macOS 为 `~/Library/Application Support/com.mitchellh.ghostty/config`，Linux 为 `~/.config/ghostty/config`）：

```
keybind = alt+backspace=text:\x1b\x7f
```

旧版 Claude Code 可能已添加过此 Ghostty 映射：

```
keybind = shift+enter=text:\n
```

该映射发送原始换行字节，在 pi 内部与 `Ctrl+J` 无法区分，因此 tmux 和 pi 不再看到真正的 `Shift+Enter` 键事件。

如果 Claude Code 2.x 或更高版本是你添加该映射的唯一原因，可以将其移除，除非你想在 tmux 中使用 Claude Code，此时仍需要该 Ghostty 映射。

Pi 将 `Ctrl+J` 绑定为默认的换行别名，因此 `Shift+Enter` 通过该重映射在 tmux 中继续工作，无需额外配置 pi。

## WezTerm

WezTerm 通常通过 xterm modifyOtherKeys 开箱即用地支持 `Shift+Enter`。要显式使用 Kitty 键盘协议，创建 `~/.wezterm.lua`：

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
config.enable_kitty_keyboard = true
return config
```

在 macOS 上，WezTerm 默认将 `Option+Enter` 绑定为全屏。要将 `Option+Enter` 用于 pi 的后续消息排队，请添加此键覆盖：

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
config.keys = {
  {
    key = 'Enter',
    mods = 'ALT',
    action = wezterm.action.SendString('\x1b[13;3u'),
  },
}
return config
```

如果你已有 `config.keys` 表，将条目添加到其中即可。

在 WSL 上，WezTerm 可能需要可见的硬件光标来定位 IME 候选窗口。如果 CJK IME 候选框不跟随文本光标，请在运行 pi 前设置 `PI_HARDWARE_CURSOR=1`，或在设置中将 `showHardwareCursor` 设为 `true`。

## Alacritty

Alacritty 通常开箱即用地支持 `Shift+Enter`。在 macOS 上，`Option+Enter` 可能作为普通 `Enter` 到达。要将 `Option+Enter` 用于 pi 的后续消息排队，请在 `~/.config/alacritty/alacritty.toml` 中添加：

```toml
[[keyboard.bindings]]
key = "Enter"
mods = "Alt"
chars = "[13;3u"
```

修改配置后重启 Alacritty。

## VS Code（集成终端）

VS Code 1.109.5 及更高版本默认在集成终端中启用 Kitty 键盘协议，因此 `Shift+Enter` 应开箱即用。

低于 1.109.5 的 VS Code 版本需要为 `Shift+Enter` 显式配置终端键绑定。

`keybindings.json` 位置：
- macOS：`~/Library/Application Support/Code/User/keybindings.json`
- Linux：`~/.config/Code/User/keybindings.json`
- Windows：`%APPDATA%\\Code\\User\\keybindings.json`

在 `keybindings.json` 中添加：

```json
{
  "key": "shift+enter",
  "command": "workbench.action.terminal.sendSequence",
  "args": { "text": "[13;2u" },
  "when": "terminalFocus"
}
```

## Windows Terminal

在 `settings.json` 中添加（Ctrl+Shift+, 或 Settings → Open JSON file），转发 pi 使用的修改 Enter 键：

```json
{
  "actions": [
    {
      "command": { "action": "sendInput", "input": "[13;2u" },
      "keys": "shift+enter"
    },
    {
      "command": { "action": "sendInput", "input": "[13;3u" },
      "keys": "alt+enter"
    }
  ]
}
```

- `Shift+Enter` 插入新行。
- Windows Terminal 默认将 `Alt+Enter` 绑定为全屏，这会阻止 pi 接收 `Alt+Enter` 用于后续消息排队。
- 将 `Alt+Enter` 重映射为 `sendInput` 会将真正的键和弦转发给 pi。

如果你已有 `actions` 数组，将对象添加到其中。如果旧的全屏行为仍然存在，请完全关闭并重新打开 Windows Terminal。

## xfce4-terminal、terminator

这些终端的转义序列支持有限。修改的 Enter 键（如 `Ctrl+Enter` 和 `Shift+Enter`）无法与普通 `Enter` 区分，导致 `submit: ["ctrl+enter"]` 等自定义键绑定无法工作。

为获得最佳体验，请使用支持 Kitty 键盘协议的终端：
- [Kitty](https://sw.kovidgoyal.net/kitty/)
- [Ghostty](https://ghostty.org/)
- [WezTerm](https://wezfurlong.org/wezterm/)
- [iTerm2](https://iterm2.com/)
- [Alacritty](https://github.com/alacritty/alacritty)（需要编译支持 Kitty 协议）

## IntelliJ IDEA（集成终端）

内置终端的转义序列支持有限。在 IntelliJ 终端中，Shift+Enter 无法与 Enter 区分。

如果需要显示硬件光标，请在运行 pi 前设置 `PI_HARDWARE_CURSOR=1`（默认禁用以保证兼容性）。

为获得最佳体验，建议使用专用终端模拟器。
