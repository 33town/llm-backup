#!/bin/bash
# 每天由 launchd（<LABEL_PREFIX>.restic）呼叫：restic backup 整個 ${HOME}（加密、增量）；週日再 forget --prune。
# log：~/Library/Logs/restic.log —— 每天要看到一行「snapshot xxxxxxxx saved」。
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/restic-env.sh"
echo "=== $(date '+%F %T')"

# 等網路：連得到儲存端點（任何 HTTP 回應）才開始（PITFALLS #3）
ENDPOINT=$(printf '%s' "${RESTIC_REPOSITORY#s3:}" | sed -E 's#^(https?://[^/]+).*#\1#')
wait_net "$ENDPOINT" || exit 1
bash "$DIR/preflight.sh" --warn-only

EXCL=(--exclude-file="$HOME/.config/restic/excludes.txt")
# 選用：特別大的資料夾另外一份清單，`touch ~/.config/restic/include-big` 才解除排除（PITFALLS #11）
[ -f "$HOME/.config/restic/excludes-big.txt" ] && [ ! -e "$HOME/.config/restic/include-big" ] \
  && EXCL+=(--exclude-file="$HOME/.config/restic/excludes-big.txt")

# 不用 --quiet：把 snapshot id 與摘要寫進 log，否則看不出每天有沒有真的存（PITFALLS #23）
OUT=$(mktemp)
restic backup "$HOME" "${EXCL[@]}" --tag nightly --json >"$OUT"
rc=$?
python3 -I - "$OUT" <<'PY'
import json, sys
for line in open(sys.argv[1]):
    try: d = json.loads(line)
    except ValueError: continue
    if d.get("message_type") == "error":
        print("error:", d.get("item", ""), "-", (d.get("error") or {}).get("message", ""))
    if d.get("message_type") == "summary":
        print(f"snapshot {d['snapshot_id'][:8]} saved：新增 {d['files_new']} 檔／變動 {d['files_changed']} 檔，上傳 {d['data_added']/2**30:.2f} GiB")
PY
rm -f "$OUT"

# exit 3＝快照存好了，只是有些檔讀不到（FileProvider 之類，每天都會有）→ 視為成功但留警告（PITFALLS #5）
if [ $rc -eq 3 ]; then echo "⚠️ backup 完成，但有檔案讀不到（exit 3，見上方 error 行）"
elif [ $rc -ne 0 ]; then echo "❌ backup 失敗 exit $rc"; exit 1
else echo "backup 完成"; fi

if [ "$(date +%u)" = 7 ]; then
  restic forget --keep-daily "${KEEP_DAILY:-14}" --keep-weekly "${KEEP_WEEKLY:-8}" --keep-monthly "${KEEP_MONTHLY:-12}" --prune --quiet \
    && echo "forget/prune 完成" \
    || echo "❌ forget/prune 失敗（看到 'already locked'：確認沒有 restic 在跑後 restic unlock，PITFALLS #6）"
fi
