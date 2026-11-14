#!/bin/bash
# 另一種做法：不搬 .git，改用 post-commit hook。commit 當下是前景程式、讀得到 ~/Documents（PITFALLS #1）。
# 距離這個 repo 上次成功 push 超過 N 天才在背景 push。只 push、不 pull、不 force。
# 安裝到某個 repo（hooks 不進 git，換電腦要重做；sync.sh 會備份一份）：
#   printf '#!/bin/bash\nbash "$HOME/llm-home/git/push-if-stale.sh"\n' > "$(git rev-parse --git-path hooks)/post-commit"
#   chmod +x "$(git rev-parse --git-path hooks)/post-commit"
# 天數：環境變數 PUSH_MAX_AGE_DAYS（預設 1）。log：~/Library/Logs/push-if-stale.log
TOP="$(git rev-parse --show-toplevel)" || exit 0
NAME="$(basename "$TOP")"
STAMP="$HOME/.cache/push-if-stale/$(echo "$TOP" | shasum | cut -c1-12).last"
LOCK="$STAMP.lock"
MAX_AGE=$(( ${PUSH_MAX_AGE_DAYS:-1} * 24 * 3600 ))
mkdir -p "$(dirname "$STAMP")"
last=$(cat "$STAMP" 2>/dev/null || echo 0)
[ $(( $(date +%s) - last )) -lt $MAX_AGE ] && exit 0
mkdir "$LOCK" 2>/dev/null || exit 0
(
  trap 'rmdir "$LOCK"' EXIT
  echo "=== $(date '+%F %T') [$NAME]"
  branch="$(git -C "$TOP" symbolic-ref --short HEAD)"
  if git -C "$TOP" push -q origin "$branch"; then
    date +%s > "$STAMP"; echo "push 完成：$(git -C "$TOP" log --oneline -1 | cut -c1-80)"
  else
    echo "❌ push 失敗（遠端有新 commit？git pull --rebase），下次 commit 再試"
  fi
) >> "$HOME/Library/Logs/push-if-stale.log" 2>&1 < /dev/null &
disown
exit 0
