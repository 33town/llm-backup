#!/usr/bin/env bash
# 解除 llm-backup 的排程。只「印出」指令，不自動刪任何東西——
# 你的 ${LLM_HOME}（備份內容）、雲端快照、鑰匙圈金鑰都要你自己決定留不留。
set -euo pipefail
CFG="$HOME/.config/llm-backup/config.env"
# shellcheck disable=SC1090
[ -f "$CFG" ] && . "$CFG"
LABEL_PREFIX="${LABEL_PREFIX:-com.$(id -un)}"; LLM_HOME="${LLM_HOME:-$HOME/llm-home}"
cat <<EOF
停排程：
  for n in llm-home.backup repos.backup restic; do
    launchctl bootout gui/\$(id -u)/$LABEL_PREFIX.\$n 2>/dev/null; rm -f ~/Library/LaunchAgents/$LABEL_PREFIX.\$n.plist
  done
選擇性（確定不要了才做）：
  rm -rf ~/.config/llm-backup            # 設定
  security delete-generic-password -s ${KC_RESTIC_PASSWORD:-restic-backup}   # ⚠️ 刪了就解不開雲端快照，先確認密碼管理器有一份
  # $LLM_HOME 是你的備份 repo，通常留著
EOF
