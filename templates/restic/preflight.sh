#!/bin/bash
# restic 開跑前檢查：① 沒有別的 restic 在跑（兩個同時跑會互搶鎖）② Wi-Fi IPv6（有些旅館／公共網路 IPv6 不通，restic 每塊先失敗再退避，慢到像當機）
# 用法：bash preflight.sh [--warn-only]   --warn-only：只警告不擋（nightly.sh 用）
warn=0; [ "${1:-}" = "--warn-only" ] && warn=1; bad=0
if pgrep -x restic >/dev/null; then
  echo "❌ 已有 restic 在跑（PID $(pgrep -x restic | tr '\n' ' ')）。不要再開第二個；確定它卡死才 pkill -x restic"; bad=1
fi
v6="$(/usr/sbin/networksetup -getinfo Wi-Fi 2>/dev/null | awk -F': ' '/^IPv6:/{print $2}')"
if [ -n "$v6" ] && [ "$v6" != "Off" ]; then
  echo "⚠️ Wi-Fi IPv6＝「${v6}」。若上傳極慢：sudo networksetup -setv6off Wi-Fi（回到正常網路再 -setv6automatic）"
fi
[ "$bad" = 1 ] && [ "$warn" = 0 ] && exit 1
[ "$bad" = 0 ] && echo "✓ preflight：沒有其他 restic 在跑"
exit 0
