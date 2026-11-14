#!/bin/bash
# 每天由 launchd（<LABEL_PREFIX>.repos.backup）呼叫：把 $GIT_STORE/*.git 裡「已經 commit」的東西 push 上 GitHub。
# 為什麼要 ${GIT_STORE}：macOS 不讓 launchd 讀 ~/Documents，所以把工作 repo 的 .git 搬出來（PITFALLS #1）：
#   cd "~/Documents/MY PROJECT" && git init --separate-git-dir "$GIT_STORE/my-project.git"
# 只 push，不 pull、不 force、不碰工作目錄。遠端比本機新就記 log 等人處理。
# log：~/Library/Logs/repos-backup.log
. "$(dirname "$0")/../lib.sh"
echo "=== $(date '+%F %T')"
shopt -s nullglob
dirs=("$GIT_STORE"/*.git)
[ ${#dirs[@]} -eq 0 ] && { echo "$GIT_STORE 底下沒有 *.git，沒事做"; exit 0; }
wait_net https://github.com || exit 0
for GIT_DIR in "${dirs[@]}"; do
  export GIT_DIR
  name="$(basename "$GIT_DIR" .git)"
  branch="$(git symbolic-ref --short HEAD 2>/dev/null)" || { echo "[$name] ❌ 讀不到 HEAD"; continue; }
  git remote get-url origin >/dev/null 2>&1 || { echo "[$name] 沒有 origin，跳過"; continue; }
  git fetch -q origin || { echo "[$name] ❌ fetch 失敗"; continue; }
  if git rev-parse -q --verify "origin/$branch" >/dev/null && [ -z "$(git log "origin/$branch..$branch" --oneline)" ]; then
    echo "[$name] 沒有未推的 commit"
  elif git push -q origin "$branch"; then
    echo "[$name] push 完成：$(git log --oneline -1 "$branch" | cut -c1-80)"
  else
    echo "[$name] ❌ push 失敗（多半是遠端有新 commit，到 repo 裡 git pull --rebase）"
  fi
done
