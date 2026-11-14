#!/bin/bash
# 一次性：產生 restic 密碼、輸入儲存空間 API key，全部放進 macOS 鑰匙圈；寫 ~/.config/restic/repo.env（只有位址，非機密）。
# ⚠️ 由「你自己」在一般 Terminal 視窗跑（要能輸入），不要讓 LLM 跑，也不要用 Claude Code 的 ! 前綴。
# ⚠️ 跑完一定要把 restic 密碼存進密碼管理器——鑰匙圈跟著這台電腦，電腦不見就沒了；密碼遺失＝備份永遠解不開。
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
asks() { local v; read -r -s -p "$1: " v; echo >&2; printf '%s' "$v"; }
ask()  { local v; read -r -p "$1: " v; printf '%s' "$v"; }

if security find-generic-password -s "$KC_RESTIC_PASSWORD" >/dev/null 2>&1; then
  echo "鑰匙圈已有 ${KC_RESTIC_PASSWORD}，沿用（不重新產生，避免跟既有 repo 對不上）"
else
  PW="$(openssl rand -base64 32)"
  security add-generic-password -a "$USER" -s "$KC_RESTIC_PASSWORD" -w "$PW" -U
  echo "✓ 鑰匙圈：${KC_RESTIC_PASSWORD}（已產生）"
  echo "👉 現在把它存進密碼管理器：security find-generic-password -s $KC_RESTIC_PASSWORD -w | pbcopy  （貼上後清空剪貼簿）"
  unset PW
fi

echo "S3 端點範例：R2＝https://<accountid>.r2.cloudflarestorage.com、B2＝https://s3.<region>.backblazeb2.com"
EP="$(ask 'S3 端點 URL')"; BUCKET="$(ask 'bucket 名')"
KID="$(asks 'Access Key ID（建議只授權這個 bucket 的讀寫）')"; SEC="$(asks 'Secret Access Key')"
security add-generic-password -a "$USER" -s "$KC_S3_KEY_ID" -w "$KID" -U
security add-generic-password -a "$USER" -s "$KC_S3_SECRET" -w "$SEC" -U
unset KID SEC
mkdir -p "$HOME/.config/restic"
printf 'RESTIC_REPOSITORY=s3:%s/%s\n' "${EP%/}" "$BUCKET" > "$HOME/.config/restic/repo.env"
echo "✓ 鑰匙圈：$KC_S3_KEY_ID / ${KC_S3_SECRET}；~/.config/restic/repo.env 已寫"
echo "👉 API key 也存一份到密碼管理器。下一步：source $(cd "$(dirname "$0")" && pwd)/restic-env.sh && restic init"
