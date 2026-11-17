#!/usr/bin/env bash
# llm-backup 安裝：把範本放到你的 ${LLM_HOME}、產生 restic 排除清單與 launchd plist。
#   ./install.sh            預設 dry-run：只印出會做什麼，不寫任何檔
#   ./install.sh --apply    真的寫（已存在的檔不覆蓋）
#   ./install.sh --apply --force   範本腳本覆蓋成最新版（不碰你的 config.env、excludes.txt、備份內容）
# 不會做的事：碰鑰匙圈、裝 launchd、建 GitHub repo、開始備份。這些最後會「印出指令」讓你自己跑。
# 可重複執行。
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)/templates"
APPLY=0; FORCE=0
for a in "$@"; do case "$a" in --apply) APPLY=1;; --force) FORCE=1;; -h|--help) sed -n '2,8p' "$0"; exit 0;; *) echo "不認得的參數：$a"; exit 1;; esac; done
say() { if [ $APPLY = 1 ]; then echo "  ✓ $*"; else echo "  [dry-run] $*"; fi; }
run() { [ $APPLY = 1 ] && "$@"; return 0; }

echo "== 1. 檢查工具"
missing=0
for c in git rsync python3 curl; do command -v "$c" >/dev/null || { echo "  ❌ 缺 $c"; missing=1; }; done
for c in restic gh; do command -v "$c" >/dev/null || echo "  ⚠️ 缺 ${c}（brew install ${c}）— 範本照樣裝，備份前要補"; done
[ "$(uname)" = Darwin ] || echo "  ⚠️ 這套範本是給 macOS（launchd、鑰匙圈）。Linux 要改用 systemd timer＋pass/secret-tool。"
[ $missing = 1 ] && { echo "先裝好上面缺的工具再跑。"; exit 1; }
echo "  OK"

echo "== 2. 設定檔"
CFG_DIR="$HOME/.config/llm-backup"; CFG="$CFG_DIR/config.env"
if [ -f "$CFG" ]; then echo "  已有 ${CFG}，沿用"
else say "建立 ${CFG}（從 config.example.env）"; run mkdir -p "$CFG_DIR"; run cp "$SRC/config.example.env" "$CFG"; fi
# shellcheck disable=SC1090
if [ -f "$CFG" ]; then . "$CFG"; else . "$SRC/config.example.env"; fi
echo "  LLM_HOME=$LLM_HOME  GIT_STORE=$GIT_STORE  LABEL_PREFIX=$LABEL_PREFIX  每天 $(printf '%02d:%02d' "$BACKUP_HOUR" "$BACKUP_MINUTE")"
case "$LLM_HOME/" in
  "$HOME/Documents/"*|"$HOME/Desktop/"*|"$HOME/Downloads/"*)
    echo "  ❌ LLM_HOME 不能放在 ~/Documents、~/Desktop、~/Downloads（launchd 讀不到，docs/PITFALLS.md #1）。改 $CFG 再跑。"; exit 1;;
esac

echo "== 3. 放範本到 $LLM_HOME"
put() {  # 範本相對路徑 目的相對路徑
  local s="$SRC/$1" d="$LLM_HOME/$2"
  if [ -e "$d" ] && [ $FORCE = 0 ]; then echo "  已存在，略過：$d"; return; fi
  say "$2"; run mkdir -p "$(dirname "$d")"; run cp "$s" "$d"
  case "$d" in *.sh|*.py) run chmod +x "$d";; esac
}
for f in lib.sh sync.sh auto-backup.sh redact.py; do put "$f" "$f"; done
for f in restic-env.sh nightly.sh preflight.sh setup-secrets.sh; do put "restic/$f" "restic/$f"; done
for f in repos-push.sh check-repos.sh push-if-stale.sh; do put "git/$f" "git/$f"; done
put cloud-memory/EXPORT-PROMPT.md cloud-memory/EXPORT-PROMPT.md
if [ ! -f "$LLM_HOME/.gitignore" ]; then
  say ".gitignore（金鑰、venv、Codex /import 產生的 .codex/ .agents/）"
  run tee "$LLM_HOME/.gitignore" >/dev/null <<'EOF'
.env
.env.*
*.pem
*.key
auth.json
*.token.json
credentials*.json
.venv/
__pycache__/
.DS_Store
.codex/
.agents/
EOF
fi
if [ ! -d "$LLM_HOME/.git" ]; then say "git init $LLM_HOME"; run git -C "$LLM_HOME" init -q -b main; fi
[ -d "$GIT_STORE" ] || { say "建立 $GIT_STORE"; run mkdir -p "$GIT_STORE"; }

echo "== 4. restic 排除清單"
EXC="$HOME/.config/restic/excludes.txt"
if [ -f "$EXC" ]; then echo "  已有 ${EXC}，不動"
else say "${EXC}（__HOME__ → ${HOME}）"; run mkdir -p "$(dirname "$EXC")"
  [ $APPLY = 1 ] && sed "s#__HOME__#$HOME#g" "$SRC/restic/excludes.txt" > "$EXC"; fi

echo "== 5. 產生 launchd plist 到 $LLM_HOME/launchd/（不安裝）"
gen() {  # 名稱 腳本 log
  local label="$LABEL_PREFIX.$1" out="$LLM_HOME/launchd/$LABEL_PREFIX.$1.plist"
  say "$out"
  [ $APPLY = 1 ] || return 0
  mkdir -p "$LLM_HOME/launchd"
  sed -e "s#__LABEL__#$label#" -e "s#__SCRIPT__#$2#" -e "s#__LOG__#$HOME/Library/Logs/$3#g" \
      -e "s#__HOUR__#$BACKUP_HOUR#" -e "s#__MINUTE__#$BACKUP_MINUTE#" "$SRC/launchd/backup.plist.template" > "$out"
  if command -v plutil >/dev/null && ! plutil -lint "$out" >/dev/null; then echo "  ❌ plist 格式錯：$out"; exit 1; fi
}
gen llm-home.backup "$LLM_HOME/auto-backup.sh"     llm-home-backup.log
gen repos.backup    "$LLM_HOME/git/repos-push.sh"  repos-backup.log
gen restic          "$LLM_HOME/restic/nightly.sh"  restic.log

echo
if [ $APPLY = 0 ]; then echo "以上是 dry-run，什麼都沒寫。確認後跑：./install.sh --apply"; exit 0; fi
cat <<EOF
== 安裝完成。接下來這些要「你自己」在 Terminal 跑（碰金鑰／系統排程，不交給 LLM）：

 1) 先預覽、再第一次同步 LLM 設定：
      cd "$LLM_HOME" && ./sync.sh dry-run && ./sync.sh backup
    看一眼 git status，確認沒有金鑰（grep -rIE 'sk-ant-|ghp_|AKIA|BEGIN .*PRIVATE KEY' . ）
 2) 建 private GitHub repo 並推上去：
      cd "$LLM_HOME" && git add -A && git commit -m "first sync" && gh repo create llm-home --private --source . --push
 3) restic 金鑰（會要你輸入；跑完把密碼存進密碼管理器）：
      bash "$LLM_HOME/restic/setup-secrets.sh"
      source "$LLM_HOME/restic/restic-env.sh" && restic init
 4) 第一次全量（可能好幾小時；中斷了重跑同一行會接續）：
      bash "$LLM_HOME/restic/preflight.sh" && caffeinate -dims bash "$LLM_HOME/restic/nightly.sh"
 5) 系統設定 → 隱私權與安全性 → 完整磁碟取用：加入 /bin/bash 和 $(command -v restic || echo '<restic 路徑>')
 6) 裝排程（全量成功後再裝）：
      for p in "$LLM_HOME"/launchd/$LABEL_PREFIX.*.plist; do cp "\$p" ~/Library/LaunchAgents/ && launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/"\$(basename "\$p")"; done
      launchctl kickstart gui/\$(id -u)/$LABEL_PREFIX.restic     # 立刻跑一次，看 ~/Library/Logs/restic.log
 7) 隱藏記憶每週匯出：照 $LLM_HOME/cloud-memory/EXPORT-PROMPT.md 最上面的步驟，在 Cowork（不進任何 Project）建一個每週排程，Run now 一次
 8) 驗證（docs/VERIFY.md）：restic check、抽幾個檔 restore 回暫存資料夾打開看。
EOF
