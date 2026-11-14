#!/bin/bash
# 共用：讀設定、等網路。被其他腳本 source。
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
LLM_BACKUP_CONFIG="${LLM_BACKUP_CONFIG:-$HOME/.config/llm-backup/config.env}"
if [ -f "$LLM_BACKUP_CONFIG" ]; then
  # shellcheck disable=SC1090
  . "$LLM_BACKUP_CONFIG"
fi
: "${LLM_HOME:=$HOME/llm-home}"
: "${GIT_STORE:=$HOME/git-store}"
: "${LABEL_PREFIX:=com.$(id -un)}"
: "${KC_RESTIC_PASSWORD:=restic-backup}"
: "${KC_S3_KEY_ID:=restic-s3-key-id}"
: "${KC_S3_SECRET:=restic-s3-secret}"

# 剛從睡眠醒來那幾十秒 DNS 常常還沒通，直接 push 會失敗、等到隔天。
# 用法：wait_net <URL> [最多秒數]。任何 HTTP 回應都算通。
wait_net() {
  local url="$1" max="${2:-300}" t=0
  while ! curl -s -m 5 -o /dev/null "$url"; do
    [ "$t" -eq 0 ] && echo "等網路…"
    if [ "$t" -ge "$max" ]; then echo "❌ 等了 ${max}s 網路還沒通，放棄（下次排程補）"; return 1; fi
    sleep 10; t=$((t + 10))
  done
  [ "$t" -gt 0 ] && echo "網路通了（等了 ${t}s）"
  return 0
}
