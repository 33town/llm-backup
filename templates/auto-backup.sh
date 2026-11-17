#!/bin/bash
# 每天由 launchd（<LABEL_PREFIX>.llm-home.backup）呼叫：sync.sh backup → 有變動才 commit → 等網路 → push。
# 只 push，不 pull、不 force。前幾次 push 失敗留下的 commit 這裡也會補推。
# log：~/Library/Logs/llm-home-backup.log
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
. "$REPO/lib.sh"
cd "$REPO" || exit 1

echo "=== $(date '+%F %T')"

# 隱藏記憶每週匯出的過期檢查：Cowork 排程每週寫 cloud-memory/LAST-RUN.md（見 cloud-memory/EXPORT-PROMPT.md）。
# 超過 CLOUD_MEMORY_MAX_AGE_DAYS（預設 8）天沒更新就在 log 寫 ⚠️。有 NOTIFY_CMD 的話也會呼叫它（例：發 Slack／ClickUp）。
if [ -f cloud-memory/LAST-RUN.md ]; then
  last="$(awk '/^last_run:/{sub(/^last_run: */, ""); print; exit}' cloud-memory/LAST-RUN.md)"
  if d="$(date -j -f '%Y-%m-%d' "${last:0:10}" +%s 2>/dev/null)"; then
    age=$(( ($(date +%s) - d) / 86400 ))
    if [ "$age" -gt "${CLOUD_MEMORY_MAX_AGE_DAYS:-8}" ]; then
      msg="⚠️ 隱藏記憶匯出已經 ${age} 天沒跑（last_run ${last}），檢查 Cowork 排程"
      echo "$msg"; [ -n "${NOTIFY_CMD:-}" ] && $NOTIFY_CMD "$msg" || true
    else
      echo "隱藏記憶匯出：${last}（${age} 天前）"
    fi
  else
    echo "⚠️ cloud-memory/LAST-RUN.md 的 last_run 讀不懂（${last}）"
  fi
fi

./sync.sh backup >/dev/null
git add -A
if git diff --cached --quiet; then
  echo "沒有變動"
else
  git commit -q -m "auto sync $(date +%F)" && echo "commit：$(git log --oneline -1)"
fi
branch="$(git symbolic-ref --short HEAD)"
if [ -n "$(git log "origin/$branch..HEAD" --oneline 2>/dev/null)" ] || ! git rev-parse -q --verify "origin/$branch" >/dev/null; then
  wait_net https://github.com || exit 0
  if git push -q -u origin "$branch"; then echo "push 完成"; else echo "❌ push 失敗（遠端比本機新？手動 git pull --rebase）"; fi
fi
