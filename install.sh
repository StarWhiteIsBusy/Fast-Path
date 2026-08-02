#!/usr/bin/env bash
# open-terminal-here 安装 / 卸载脚本 (单文件自包含版)
# 已安装时运行本脚本 = 卸载;未安装时 = 安装
# 用法: ./install.sh [--install | --uninstall]
#
# 安装路径与 AUR 包 (niri-open-terminal-here) 一致:
#   脚本 -> /usr/bin/open-terminal-here
#   绑定 -> Mod+Return  { spawn-sh "open-terminal-here"; }
# 需要 sudo 权限;脚本会先请求一次密码(sudo -v),随后静默执行。
# 本脚本自包含:核心脚本内嵌在文件底部标记区;若与 open-terminal-here.sh
# 同目录,则优先复制同目录文件(便于同步维护)。

set -u

# ---------- 配置 ----------
INSTALL_NAME="${INSTALL_NAME:-open-terminal-here}"
INSTALL_PATH="${INSTALL_PATH:-/usr/bin/$INSTALL_NAME}"
NIRI_CONFIG="$HOME/.config/niri/config.kdl"
NIRI_BACKUP="$NIRI_CONFIG.bak"
BINDING='Mod+Return  { spawn-sh "open-terminal-here"; }'
BINDING_LEGACY='Mod+Return  { spawn-sh "~/fast-path/open-terminal-here.sh"; }'
BINDING_OLD='Mod+Return  { spawn "kitty"; }'
MARKER_DIR="$HOME/.local/state"
MARKER="$MARKER_DIR/open-terminal-here-installed"
BAR_WIDTH=40
SKIPPED=0
INSTALL_MODE=""

# ---------- 颜色 ----------
C_RESET=$'\033[0m'
C_BAR=$'\033[0;36m'
C_FILL=$'\033[0;32m'
C_FILE=$'\033[0;33m'
C_OK=$'\033[1;32m'
C_WARN=$'\033[1;33m'
C_ERR=$'\033[1;31m'

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SRC_DIR/open-terminal-here.sh"
HAS_ALONGSIDE=0
[ -f "$SOURCE" ] && HAS_ALONGSIDE=1

# ---------- 权限 ----------
sudocmd() {
  if [ "${NO_SUDO:-0}" = 1 ] || [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi
}

ask_sudo() {
  [ "$(id -u)" = 0 ] && return 0
  [ "${NO_SUDO:-0}" = 1 ] && return 0
  sudo -v || { printf '%s需要 sudo 权限,无法继续%s\n' "$C_ERR" "$C_RESET"; return 1; }
}

# ---------- 进度条 ----------
FIRST_DRAW=1

draw() {
  local pct=$1 label=$2
  local filled=$((pct * BAR_WIDTH / 100))
  local bar=""
  for ((i = 0; i < filled; i++)); do bar+="#"; done
  for ((i = filled; i < BAR_WIDTH; i++)); do bar+="."; done
  if [ "$FIRST_DRAW" = 1 ]; then
    FIRST_DRAW=0
  else
    printf '\033[1A'
  fi
  printf '\r\033[K'
  printf "${C_BAR}[%s${C_BAR}]${C_RESET} ${C_FILL}%3d%%${C_RESET}" "$bar" "$pct"
  printf '\n\033[K'
  printf "${C_FILE}→${C_RESET} %s" "$label"
}

animate() {
  local start=$1 end=$2 label=$3
  local pct=$start
  while [ "$pct" -lt "$end" ]; do
    pct=$((pct + 1))
    draw "$pct" "$label"
    sleep 0.02
  done
}

clear_progress() {
  printf '\033[1A\r\033[K'
}

finish_bar() {
  local bar=""
  for ((i = 0; i < BAR_WIDTH; i++)); do bar+="#"; done
  printf '\033[1A\r\033[K'
  printf "${C_BAR}[%s${C_BAR}]${C_RESET} ${C_FILL}%3d%%${C_RESET}\n" "$bar" 100
}

countdown() {
  local i
  for ((i = $1; i >= 1; i--)); do
    printf '\r\033[K%s%d 秒后自动退出...%s' "$C_BAR" "$i" "$C_RESET"
    sleep 1
  done
  printf '\r\033[K'
}

# ---------- 依赖检查 ----------
check_deps() {
  local missing=""
  for d in kitty jq niri; do
    command -v "$d" >/dev/null 2>&1 || missing="$missing $d"
  done
  if [ -n "$missing" ]; then
    printf '%s缺少运行依赖:%s%s\n' "$C_WARN" "$missing" "$C_RESET"
    printf '%s可安装:sudo pacman -S --needed%s%s\n' "$C_WARN" "$missing" "$C_RESET"
    return 1
  fi
  printf '依赖检查:kitty ✓ jq ✓ niri ✓\n'
  return 0
}

# ---------- 提取内嵌的核心脚本 ----------
extract_embedded() {
  awk '/^# >>>>> open-terminal-here.sh >>>>>>/{f=1;next}
       /^# <<<<< open-terminal-here.sh <<<<</{f=0}
       f' "$0" > "$1"
  chmod +x "$1"
}

# ---------- 安装脚本到 /usr/bin ----------
install_script() {
  local src note
  if [ "$HAS_ALONGSIDE" = 1 ]; then
    src="$SOURCE"
    note="(同目录副本)"
  else
    src=$(mktemp)
    extract_embedded "$src"
    note="(内置内容)"
  fi
  sudocmd install -Dm755 "$src" "$INSTALL_PATH" || { rm -f "$src"; return 1; }
  [ "$src" != "$SOURCE" ] && rm -f "$src"
  printf '%s' "$note"
}

# ---------- 检测 / 配置修改 ----------
is_installed() {
  [ -f "$MARKER" ] && return 0
  grep -qF "open-terminal-here" "$NIRI_CONFIG" 2>/dev/null && return 0
  return 1
}

patch_niri_config() {
  if grep -qF "open-terminal-here" "$NIRI_CONFIG" 2>/dev/null; then
    SKIPPED=1
    INSTALL_MODE="existing"
    return 0
  fi
  [ -f "$NIRI_BACKUP" ] || cp "$NIRI_CONFIG" "$NIRI_BACKUP" 2>/dev/null
  if grep -qF "$BINDING_OLD" "$NIRI_CONFIG" 2>/dev/null; then
    sed -i "s|$BINDING_OLD|$BINDING|" "$NIRI_CONFIG"
    INSTALL_MODE="replaced"
  else
    awk -v ins="$BINDING" '
      /^[ \t]*binds[ \t]*\{/ { in_binds = 1; print; next }
      in_binds && /^[ \t]*\}/ { print ins; in_binds = 0; print; next }
      { print }
    ' "$NIRI_CONFIG" > "$NIRI_CONFIG.tmp" && mv "$NIRI_CONFIG.tmp" "$NIRI_CONFIG"
    INSTALL_MODE="inserted"
  fi
}

unpatch_niri_config() {
  local mode="$1"
  case "$mode" in
    replaced)
      sed -i "s|$BINDING|$BINDING_OLD|" "$NIRI_CONFIG"
      sed -i "s|$BINDING_LEGACY|$BINDING_OLD|" "$NIRI_CONFIG"
      ;;
    inserted)
      sed -i "/open-terminal-here/d" "$NIRI_CONFIG"
      ;;
    *)
      sed -i "s|$BINDING|$BINDING_OLD|" "$NIRI_CONFIG"
      sed -i "s|$BINDING_LEGACY|$BINDING_OLD|" "$NIRI_CONFIG"
      if ! grep -qF "$BINDING_OLD" "$NIRI_CONFIG" 2>/dev/null; then
        sed -i "/open-terminal-here/d" "$NIRI_CONFIG"
      fi
      ;;
  esac
}

# ---------- 安装流程 ----------
run_install() {
  check_deps
  ask_sudo

  animate 0 35 "$INSTALL_PATH"
  local note
  note=$(install_script) || { clear_progress; printf '%s安装脚本失败:%s%s\n' "$C_ERR" "$INSTALL_PATH" "$C_RESET"; return 1; }
  draw 35 "$INSTALL_PATH $note"
  sleep 0.3

  animate 35 70 "$NIRI_CONFIG"
  patch_niri_config
  if [ "$SKIPPED" = 1 ]; then
    draw 70 "$NIRI_CONFIG (已配置,跳过修改)"
    sleep 0.5
  fi

  animate 70 100 "niri IPC (reload-config)"
  niri msg action load-config-file >/dev/null 2>&1 || true
  mkdir -p "$MARKER_DIR"
  printf '%s\n' "$INSTALL_MODE" > "$MARKER"

  finish_bar
  printf "\n${C_OK}✔ 安装成功${C_RESET}\n"
}

# ---------- 卸载流程 ----------
run_uninstall() {
  local mode=""
  ask_sudo

  animate 0 40 "$NIRI_CONFIG"
  if grep -qF "open-terminal-here" "$NIRI_CONFIG" 2>/dev/null; then
    [ -f "$MARKER" ] && mode=$(cat "$MARKER" 2>/dev/null)
    unpatch_niri_config "$mode"
    draw 40 "$NIRI_CONFIG (已移除绑定)"
  else
    draw 40 "$NIRI_CONFIG (无绑定可移除)"
  fi
  sleep 0.4

  animate 40 75 "$INSTALL_PATH"
  if [ -f "$INSTALL_PATH" ]; then
    sudocmd rm -f "$INSTALL_PATH"
    draw 75 "$INSTALL_PATH (已删除)"
  else
    draw 75 "$INSTALL_PATH (不存在,跳过)"
  fi
  sleep 0.4

  animate 75 100 "niri IPC (reload-config)"
  niri msg action load-config-file >/dev/null 2>&1 || true
  rm -f "$MARKER"

  finish_bar
  printf "\n${C_OK}✔ 卸载完成${C_RESET}\n"
}

# ---------- 非交互模式 ----------
plain_install() {
  check_deps
  ask_sudo
  printf '[1/3] 安装脚本: %s\n' "$INSTALL_PATH"
  local note
  note=$(install_script) || return 1
  printf '      %s\n' "$note"
  printf '[2/3] 修改配置: %s\n' "$NIRI_CONFIG"
  patch_niri_config
  [ "$SKIPPED" = 1 ] && printf '      (已配置,跳过修改)\n'
  printf '[3/3] 重载 niri 配置\n'
  niri msg action load-config-file >/dev/null 2>&1 || true
  mkdir -p "$MARKER_DIR"
  printf '%s\n' "$INSTALL_MODE" > "$MARKER"
  printf '%s安装成功%s\n' "$C_OK" "$C_RESET"
}

plain_uninstall() {
  ask_sudo
  local mode=""
  printf '[1/3] 修改配置: %s\n' "$NIRI_CONFIG"
  if grep -qF "open-terminal-here" "$NIRI_CONFIG" 2>/dev/null; then
    [ -f "$MARKER" ] && mode=$(cat "$MARKER" 2>/dev/null)
    unpatch_niri_config "$mode"
    printf '      (已移除绑定)\n'
  else
    printf '      (无绑定可移除)\n'
  fi
  printf '[2/3] 删除脚本: %s\n' "$INSTALL_PATH"
  if [ -f "$INSTALL_PATH" ]; then
    sudocmd rm -f "$INSTALL_PATH"
    printf '      (已删除)\n'
  else
    printf '      (不存在,跳过)\n'
  fi
  printf '[3/3] 重载 niri 配置\n'
  niri msg action load-config-file >/dev/null 2>&1 || true
  rm -f "$MARKER"
  printf '%s卸载完成%s\n' "$C_OK" "$C_RESET"
}

# ---------- 主流程 ----------
ACTION=""
case "${1:-}" in
  --install) ACTION="install" ;;
  --uninstall) ACTION="uninstall" ;;
  "") if is_installed; then ACTION="uninstall"; else ACTION="install"; fi ;;
  *) printf '%s未知参数: %s (支持: --install / --uninstall)%s\n' "$C_ERR" "$1" "$C_RESET"; exit 1 ;;
esac

if [ -t 1 ]; then
  if [ "$ACTION" = "install" ]; then
    run_install || exit 1
  else
    run_uninstall || exit 1
  fi
  countdown 3
else
  if [ "$ACTION" = "install" ]; then
    plain_install
  else
    plain_uninstall
  fi
fi

exit 0

# >>>>> open-terminal-here.sh >>>>>>
#!/usr/bin/env bash
set -o pipefail

TARGET="$HOME"

get_focused() {
  niri msg --json focused-window 2>/dev/null
}

find_nautilus_dir() {
  local pid="$1" title="$2"
  local fd target base

  for fd in /proc/"$pid"/fd/*; do
    target=$(readlink "$fd" 2>/dev/null) || continue
    case "$target" in
      */.last_cwd|/dev/*|/proc/*|/sys/*|*.so*|/usr/lib*|/memfd:*|pipe:*|socket:*)
        continue
        ;;
    esac
    if [ -d "$target" ]; then
      base=${target##*/}
      if [ "$base" = "$title" ]; then
        echo "$target"
        return 0
      fi
    fi
  done
  return 1
}

focused=$(get_focused)

if [ -n "$focused" ]; then
  app_id=$(printf '%s' "$focused" | jq -r '.app_id // empty')
  if [ "$app_id" = "org.gnome.Nautilus" ]; then
    pid=$(printf '%s' "$focused" | jq -r '.pid // empty')
    title=$(printf '%s' "$focused" | jq -r '.title // empty')
    if [ -n "$pid" ] && [ -n "$title" ]; then
      if [ "$title" = "主文件夹" ]; then
        TARGET="$HOME"
      else
        dir=$(find_nautilus_dir "$pid" "$title")
        if [ -n "$dir" ]; then
          TARGET="$dir"
        fi
      fi
    fi
  fi
fi

exec kitty --directory "$TARGET"
# <<<<< open-terminal-here.sh <<<<<
