#!/bin/bash
# 唯讀：config.env 的 REPO_PATHS 逐一檢查「沒有未 commit 的檔、沒有未 push 的 commit」。全乾淨才 exit 0。不 fetch、不寫任何東西。
# 用法：bash $LLM_HOME/git/check-repos.sh
. "$(dirname "$0")/../lib.sh"
bad=0
for p in "${REPO_PATHS[@]:-$LLM_HOME}"; do
  n="$(basename "$p")"
  [ -e "$p" ] || { echo "❌ ${n}：找不到 $p"; bad=1; continue; }
  st="$(git -C "$p" status --porcelain 2>&1)"
  un="$(git -C "$p" log --oneline '@{u}..HEAD' 2>/dev/null | wc -l | tr -d ' ')"
  git -C "$p" rev-parse -q --verify '@{u}' >/dev/null 2>&1 || un="沒有 upstream"
  if [ -z "$st" ] && [ "$un" = 0 ]; then echo "✅ ${n}：乾淨、無未推"
  else echo "❌ ${n}：未提交 $(printf '%s' "$st" | grep -c .) 檔；未推 $un"; printf '%s\n' "$st" | head -5 | sed 's/^/     /'; bad=1; fi
done
exit $bad
