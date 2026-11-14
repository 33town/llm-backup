#!/usr/bin/env bash
# LLM 設定同步（單向）。放在 $LLM_HOME 根目錄。
#   ./sync.sh dry-run  只列出 backup 會動哪些檔，絕不寫任何東西
#   ./sync.sh backup   本機 ~/.claude、~/.codex → 這個 repo（只複製，不 commit）
#   ./sync.sh restore  這個 repo → 本機（換電腦用）。覆蓋同名檔，但不刪本機多出來的檔
# 金鑰、登入狀態、對話紀錄、cache 一律不進來（見 EXCLUDES；大檔與逐字稿交給 restic）。
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
. "$REPO/lib.sh"
MODE="${1:-dry-run}"

# (本機路徑, repo 路徑) 成對；資料夾結尾要加 /。沒有的檔會自動跳過。
PAIRS=(
  "$HOME/.claude/CLAUDE.md"        "claude/CLAUDE.md"
  "$HOME/.claude/settings.json"    "claude/settings.json"
  "$HOME/.claude/commands/"        "claude/commands/"
  "$HOME/.claude/skills/"          "claude/skills/"
  "$HOME/.claude/agents/"          "claude/agents/"
  "$HOME/.claude/scripts/"         "claude/scripts/"
  "$HOME/.claude/statusline.sh"    "claude/statusline.sh"
  "$HOME/.codex/AGENTS.md"         "codex/AGENTS.md"
  "$HOME/.codex/hooks.json"        "codex/hooks.json"
  "$HOME/.codex/memories/"         "codex/memories/"
  "$HOME/.codex/skills/"           "codex/skills/"
  "$HOME/.codex/prompts/"          "codex/prompts/"
)
# 需要多帶的檔案：在 $LLM_HOME/extra-pairs.txt 每行寫「本機路徑<TAB>repo 路徑」
if [ -f "$REPO/extra-pairs.txt" ]; then
  while IFS=$'\t' read -r a b; do
    [ -z "$a" ] || [ "${a:0:1}" = "#" ] && continue
    PAIRS+=("${a/#\~/$HOME}" "$b")
  done < "$REPO/extra-pairs.txt"
fi

# Claude Code 自動記憶：每個專案一個資料夾，名字＝工作目錄絕對路徑把 / 換成 -
# ⚠️ 新電腦使用者名稱不同，資料夾名要改（docs/PITFALLS.md #12）
if [ "$MODE" = "restore" ]; then
  for d in "$REPO"/claude/memory/*/; do
    [ -d "$d" ] && PAIRS+=("$HOME/.claude/projects/$(basename "$d")/memory/" "claude/memory/$(basename "$d")/")
  done
else
  for d in "$HOME"/.claude/projects/*/memory/; do
    [ -d "$d" ] && PAIRS+=("$d" "claude/memory/$(basename "$(dirname "$d")")/")
  done
  # Claude 桌面版（Cowork）每個 space 的記憶：只備份、不自動還原（新帳號 space ID 不同，PITFALLS #14）
  # 想用名字當資料夾名：在 $LLM_HOME/cowork-spaces.tsv 寫「ID 前 8 碼<TAB>名稱」
  for d in "$HOME"/Library/Application\ Support/Claude/local-agent-mode-sessions/*/*/spaces/*/memory/; do
    [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ] || continue
    id="$(basename "$(dirname "$d")")"
    name="$( [ -f "$REPO/cowork-spaces.tsv" ] && awk -F'\t' -v k="${id:0:8}" '$1 == k {print $2}' "$REPO/cowork-spaces.tsv")"
    PAIRS+=("$d" "cowork/${name:-$id}/")
  done
fi

EXCLUDES=(--exclude '.git/' --exclude '.venv/' --exclude 'node_modules/' --exclude '__pycache__/' --exclude '*.pyc'
          --exclude '.DS_Store' --exclude 'auth.json' --exclude '*.token.json' --exclude '.env' --exclude '.env.*'
          --exclude '*.pem' --exclude '*.key' --exclude 'credentials*.json')

case "$MODE" in dry-run|backup|restore) ;; *) echo "用法：$0 [dry-run|backup|restore]"; exit 1;; esac

for ((i = 0; i < ${#PAIRS[@]}; i += 2)); do
  src="${PAIRS[i]}"; dst="$REPO/${PAIRS[i+1]}"
  case "$MODE" in
    dry-run)
      [ -e "$src" ] || { echo "跳過（本機沒有）：$src"; continue; }
      echo "## $src → $dst"
      rsync -ani --delete "${EXCLUDES[@]}" "$src" "$dst" 2>/dev/null | grep -v '^\.d' || true ;;
    backup)
      [ -e "$src" ] || continue
      mkdir -p "$(dirname "$dst")"
      # repo 要跟本機一樣：本機刪掉的檔 repo 也刪。單一項目失敗只警告，不中止整支（PITFALLS #18）
      rsync -a --delete "${EXCLUDES[@]}" "$src" "$dst" || echo "⚠️ 複製失敗：$src" >&2 ;;
    restore)
      [ -e "$dst" ] || continue
      mkdir -p "$(dirname "$src")"
      rsync -a "${EXCLUDES[@]}" "$dst" "$src" || echo "⚠️ 還原失敗：$dst" >&2 ;;
  esac
done

# 結構副本：去掉金鑰、保留鍵名，讓新電腦知道「要填哪些值」。掃到疑似金鑰就整份不寫（PITFALLS #15）
redact() { python3 -I "$REPO/redact.py" "$1" "$2" "$REPO/$3" >/dev/null || echo "⚠️ redact 略過（$1 $2）" >&2; }
copy_into() { local d="$1"; shift; mkdir -p "$REPO/$d"; for f in "$@"; do [ -f "$f" ] && { cp -p "$f" "$REPO/$d/" || echo "⚠️ 複製失敗：$f" >&2; }; done; }

if [ "$MODE" = "backup" ]; then
  [ -f "$HOME/.claude.json" ]       && redact claude-json "$HOME/.claude.json"       claude/claude.json.redacted
  [ -f "$HOME/.codex/config.toml" ] && redact toml        "$HOME/.codex/config.toml" codex/config.toml.redacted
  [ -f "$HOME/.zshrc" ]             && redact zshrc       "$HOME/.zshrc"             zshrc.names-only
  copy_into launchd "$HOME"/Library/LaunchAgents/"$LABEL_PREFIX".*.plist
  copy_into restic-config "$HOME"/.config/restic/excludes*.txt
  copy_into . "$LLM_BACKUP_CONFIG"   # config.env（不含金鑰），新電腦直接拿回來用
  # git hooks 不在 repo 裡、換電腦會消失；複製失敗（例如 symlink 指進 ~/Documents）保留舊副本（PITFALLS #2）
  for h in "$GIT_STORE"/*.git/hooks/post-commit "$GIT_STORE"/*.git/hooks/pre-push; do
    [ -f "$h" ] || continue
    mkdir -p "$REPO/git-store/hooks"
    cp -p "$h" "$REPO/git-store/hooks/$(basename "$(dirname "$(dirname "$h")")").$(basename "$h")" || echo "⚠️ hook 複製失敗：$h" >&2
  done
  # Python 套件清單：venv 壞了（brew 升級 python）就保留舊檔，不清空（PITFALLS #17）
  PIP="$HOME/.claude/scripts/.venv/bin/pip"
  if [ -x "$PIP" ]; then
    if tmp="$("$PIP" freeze 2>/dev/null)" && [ -n "$tmp" ]; then printf '%s\n' "$tmp" > "$REPO/claude/scripts/requirements.txt"
    else echo "⚠️ pip freeze 失敗，保留舊 requirements.txt" >&2; fi
  fi
elif [ "$MODE" = "dry-run" ]; then
  echo "## 另外會產生：claude/claude.json.redacted、codex/config.toml.redacted、zshrc.names-only；複製 LaunchAgents/$LABEL_PREFIX.*.plist、$GIT_STORE/*.git 的 hooks、~/.config/restic/excludes*.txt"
fi

echo "完成（${MODE}）。"
[ "$MODE" = "backup" ] && git -C "$REPO" status --short 2>/dev/null | head -20
exit 0
