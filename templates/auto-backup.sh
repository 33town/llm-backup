#!/bin/bash
# 每天由 launchd（<LABEL_PREFIX>.llm-home.backup）呼叫：sync.sh backup → 有變動才 commit → 等網路 → push。
# 只 push，不 pull、不 force。前幾次 push 失敗留下的 commit 這裡也會補推。
# log：~/Library/Logs/llm-home-backup.log
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
. "$REPO/lib.sh"
cd "$REPO" || exit 1

echo "=== $(date '+%F %T')"
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
