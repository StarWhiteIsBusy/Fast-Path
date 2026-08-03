# Fast-Path · 快速路径

A context-aware terminal launcher for the **niri** Wayland compositor.

为 **niri** Wayland 合成器编写的上下文感知终端启动器。

**Super + Enter** opens a new kitty window — in the folder you are currently browsing when **GNOME Files (Nautilus)** is focused, otherwise in `$HOME`.

**Super + Enter** 打开一个新的 kitty 窗口——当焦点在**文件(GNOME Nautilus)**时,在新窗口的当前浏览目录中打开;其他任何情况下,在 `$HOME` 中打开。

## Features · 特性

- Context-aware: opens in the current Nautilus folder only when Nautilus is focused (focus detection via `niri msg --json focused-window`)
- 上下文感知:仅当焦点在 Nautilus 时才使用当前浏览目录(通过 `niri msg --json focused-window` 检测焦点)
- No D-Bus dependency: Nautilus removed the `org.gnome.Nautilus.Window.GetCurrentLocation` D-Bus interface; this script resolves the current folder via `/proc/<pid>/fd` (Nautilus keeps the displayed directory open as a monitor fd) plus window-title matching
- 无 D-Bus 依赖:Nautilus 已移除 `org.gnome.Nautilus.Window.GetCurrentLocation` D-Bus 接口;本脚本通过 `/proc/<pid>/fd`(Nautilus 会以监控 fd 的形式保持当前目录打开)配合窗口标题匹配来解析当前目录
- Handles the localized home window title (e.g. `主文件夹`)
- 处理本地化主文件夹窗口标题(如 `主文件夹`)
- Safe fallback: everything else (other apps, desktop/no window, special views like Trash / Search) opens in `$HOME`
- 安全回退:其他所有情况(其他应用、桌面/无窗口、回收站/搜索等特殊视图)均在 `$HOME` 打开
- Opens a **new** kitty window via `--directory`(每次新开窗口,不复用现有实例)
- One-command installer / uninstaller: `install.sh` installs with a progress bar; re-running it when already installed performs a clean uninstall
- 一键安装/卸载:`install.sh` 带进度条完成安装;已安装时再次运行即为干净的卸载

## Requirements · 依赖

- [niri](https://github.com/YaLTeR/niri) (Wayland compositor)
- [kitty](https://sw.kovidgoyal.net/kitty/) terminal emulator
- `jq` (JSON parsing) and `bash`
- Tested with Nautilus 50.2.2; should work on Nautilus 45+ (any version without the per-window D-Bus interface)

- 需要 [niri](https://github.com/YaLTeR/niri)、[kitty](https://sw.kovidgoyal.net/kitty/)、`jq` 和 `bash`
- 已在 Nautilus 50.2.2 上测试;适用于 Nautilus 45+(即任何不再提供按窗口 D-Bus 接口的版本)

## Installation · 安装

### One-command install · 一键安装 (recommended · 推荐)

```bash
./install.sh
```

Or install directly from GitHub · 或直接从 GitHub 安装:

```bash
curl -fsSL https://raw.githubusercontent.com/StarWhiteIsBusy/Fast-Path/refs/heads/main/install.sh | bash
```

All files are embedded in the single-file installer (heredoc), so piping works — no file path or extra files needed. Running the **same command again** performs a clean uninstall.

所有文件均内嵌在单文件安装脚本中(heredoc 形式),管道直接运行即可,无需真实文件路径或额外文件。**再次运行同一条命令即为干净的卸载**。

- **Self-contained**: `install.sh` is a single file — the core script is embedded inside it, so you can copy just this one file to a new machine and run it (no other files needed; only bash + coreutils are required to run the installer itself)
- **自包含**:`install.sh` 是单文件——核心脚本内嵌在其中,新电脑上只需拷这一个文件即可使用(运行安装脚本本身只需要 bash + coreutils)
- If `open-terminal-here.sh` sits next to `install.sh`, that copy is preferred (so the repo copy stays canonical); otherwise the embedded content is extracted
- 若 `install.sh` 旁边有 `open-terminal-here.sh`,则优先复制该文件(仓库内副本为准);否则提取内置内容
- **Install path matches the AUR package**: the script is installed to `/usr/bin/open-terminal-here` (via `sudo`; the script asks for the password once up front), so the binding works the same whether installed by `install.sh` or by the `niri-open-terminal-here` AUR package
- **安装路径与 AUR 包一致**:脚本安装到 `/usr/bin/open-terminal-here`(通过 sudo,脚本开头会先请求一次密码),因此无论用 `install.sh` 还是 AUR 包 `niri-open-terminal-here` 安装,绑定完全一致
- Runtime dependencies (`kitty`, `jq`, `niri`) are checked before installing; missing ones are reported with the pacman command to install them, then installation continues
- 安装前会检查运行依赖(`kitty`、`jq`、`niri`);缺失时提示并给出 pacman 安装命令,然后继续安装
- Interactive mode (run in a terminal): a single overwriting progress bar with the file currently being written/modified shown below it; ends with **✔ 安装成功** and auto-exits after a 3-second countdown
- 交互模式(终端中运行):单条覆盖式进度条,进度条下方实时显示当前写入/修改的文件;完成后显示 **✔ 安装成功**,3 秒倒计时自动退出
- Non-interactive mode (piped/scripted): falls back to plain text `[1/3] ... [3/3]` steps
- 非交互模式(管道/脚本调用):自动降级为纯文本步骤输出
- It installs `open-terminal-here` to `/usr/bin`, patches `~/.config/niri/config.kdl` (backing it up to `config.kdl.bak`), reloads niri and records an install marker at `~/.local/state/open-terminal-here-installed`
- 安装过程:安装 `/usr/bin/open-terminal-here`、修改 `~/.config/niri/config.kdl`(备份为 `config.kdl.bak`)、重载 niri 配置,并在 `~/.local/state/open-terminal-here-installed` 记录安装标记

The config patch is smart · 配置修改很智能:

- If your terminal binding is the stock `Mod+Return { spawn "kitty"; }`, it is replaced in place
- 如果原绑定是 `Mod+Return { spawn "kitty"; }`,直接原位替换
- Otherwise the binding is inserted into the `binds` block
- 否则将绑定插入 `binds` 块

### Manual install · 手动安装

```bash
sudo install -Dm755 open-terminal-here.sh /usr/bin/open-terminal-here
```

Add to `~/.config/niri/config.kdl` (replace your existing terminal binding, e.g. `Mod+Return { spawn "kitty"; }`):

在 `~/.config/niri/config.kdl` 中添加(替换原有的终端绑定,例如 `Mod+Return { spawn "kitty"; }`):

```kdl
Mod+Return  { spawn-sh "open-terminal-here"; }
```

Reload niri config · 重载 niri 配置:

```bash
niri msg action load-config-file
```

That's it. Press **Super + Enter** to try it out.

完成。按 **Super + Enter** 即可体验。

## Uninstall · 卸载

Running `install.sh` again when the plugin is already installed turns it into an uninstaller — same progress bar style, same file names, ending with **✔ 卸载完成** and the same 3-second countdown:

已安装时再次运行 `install.sh`(或上面同一条 GitHub curl 命令)会变成卸载脚本——同样式进度条、同样的文件名显示,结束显示 **✔ 卸载完成**,同样 3 秒倒计时:

- Restores the niri config: if the stock kitty binding was replaced, it is restored; if the binding was inserted, only that line is removed (based on the recorded install marker; falls back to restoring the kitty binding when no marker exists). Bindings from older versions (the `~/fast-path/...` form) are restored too
- 还原 niri 配置:替换过 kitty 绑定则原样还原;纯插入则只删除绑定行(依据安装标记判断;无标记时回退为还原 kitty 绑定)。旧版本(带 `~/fast-path/...` 路径)的绑定同样会被还原
- Removes `/usr/bin/open-terminal-here` (via `sudo`) and the install marker
- 删除 `/usr/bin/open-terminal-here`(通过 sudo)和安装标记
- Reloads niri
- 重载 niri 配置

Forced modes · 强制模式:

```bash
./install.sh --install     # 强制安装
./install.sh --uninstall   # 强制卸载
```

## Usage · 使用

| Focus · 焦点 | Behavior · 行为 |
|---|---|
| GNOME Files (Nautilus) in a subfolder · 文件管理器(子目录) | kitty opens in the browsed folder · 在浏览目录打开 |
| GNOME Files showing home · 文件管理器(主文件夹) | kitty opens in `$HOME` · 在 `$HOME` 打开 |
| Any other app · 其他应用 | kitty opens in `$HOME` |
| Desktop / no window · 桌面 / 无窗口 | kitty opens in `$HOME` |
| Nautilus special views (Trash / Search / network) · 特殊视图(回收站/搜索/网络) | falls back to `$HOME` · 回退到 `$HOME` |

## How it works · 工作原理

1. `niri msg --json focused-window` returns the focused window's `app_id`, `title` and `pid` via the niri IPC socket.
2. If `app_id` is `org.gnome.Nautilus`, the script scans `/proc/<pid>/fd/*` and follows each fd with `readlink`, collecting paths that point to real directories. Nautilus keeps a file descriptor (inotify monitor) open on the folder currently displayed in each window.
3. The fd path whose basename matches the window title (the folder name) is the current folder of the focused window.
4. The home window is a special case: its title is the localized name (e.g. `主文件夹`) instead of a path basename, so it is resolved directly to `$HOME`.
5. kitty is spawned with `--directory "$dir"`. If anything fails or the focus is not Nautilus, kitty opens in `$HOME`.

1. 通过 niri IPC 套接字,`niri msg --json focused-window` 返回焦点窗口的 `app_id`、`title` 和 `pid`。
2. 如果 `app_id` 是 `org.gnome.Nautilus`,脚本遍历 `/proc/<pid>/fd/*`,用 `readlink` 解析每个 fd,收集指向真实目录的路径。Nautilus 会在每个窗口当前显示的目录上保持一个文件描述符(inotify 监控)。
3. fd 路径的 basename 与窗口标题(文件夹名)匹配的那个,就是焦点窗口的当前目录。
4. 主文件夹窗口是特例:其标题是本地化名称(如 `主文件夹`)而非路径 basename,因此直接解析为 `$HOME`。
5. 以 `--directory "$dir"` 启动 kitty。任何失败或焦点不是 Nautilus 时,kitty 在 `$HOME` 打开。

## Why not D-Bus? · 为什么不用 D-Bus?

Nautilus used to export `org.gnome.Nautilus.Window.GetCurrentLocation` for exactly this use case. It was removed in newer Nautilus versions (45+). Both the Nautilus extension APIs (Python and C) also lack a window-location extension point, so this script uses the fd-based heuristic described above.

Nautilus 过去正是通过 `org.gnome.Nautilus.Window.GetCurrentLocation` 提供此功能,但在较新版本(45+)中已被移除。Nautilus 的扩展 API(Python 和 C)也没有窗口位置扩展点,因此本脚本采用上述基于 fd 的启发式方法。

## Files · 文件

```
fast-path/
├── install.sh                 # 自包含安装/卸载脚本 · self-contained installer
├── open-terminal-here.sh      # 核心脚本 · core script (Super+Enter 执行)
├── README.md                  # 文档 · documentation
├── LICENSE                    # MIT 许可证
├── config/
│   └── niri-snippet.kdl       # niri 绑定片段 · binding snippet
└── aur/
    ├── PKGBUILD               # AUR 打包脚本
    └── .SRCINFO               # AUR 源信息
```

| File · 文件 | Purpose · 作用 |
|---|---|
| `open-terminal-here.sh` | Core script: resolves the focused Nautilus folder and launches kitty there — the program executed by **Super + Enter** · 核心脚本:解析焦点 Nautilus 的浏览目录并在其中启动 kitty——**Super+Enter** 实际执行的程序 |
| `install.sh` | Self-contained installer / uninstaller with an overwriting progress bar; installs to `/usr/bin/open-terminal-here` (AUR-style path) and auto-switches to uninstall when the plugin is already installed · 自包含的单文件安装/卸载脚本,带覆盖式进度条;安装到 `/usr/bin/open-terminal-here`(AUR 风格路径),已安装时自动切换为卸载 |
| `config/niri-snippet.kdl` | The niri binding snippet for manual configuration · 手动配置用的 niri 绑定片段 |
| `README.md` | This documentation · 本文档 |
| `LICENSE` | MIT license · MIT 许可证 |

## License · 许可证

[MIT](LICENSE)
