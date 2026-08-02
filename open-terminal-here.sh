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
