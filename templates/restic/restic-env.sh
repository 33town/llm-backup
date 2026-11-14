#!/bin/bash
# 被 source：設好 restic → S3 相容儲存（Cloudflare R2／Backblaze B2／AWS S3）的環境變數。
# 金鑰一律從 macOS 鑰匙圈取，不落地明文。非機密的 repo 位址放在 ~/.config/restic/repo.env：
#   RESTIC_REPOSITORY=s3:https://<accountid>.r2.cloudflarestorage.com/<bucket>
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
set -a; . "$HOME/.config/restic/repo.env"; set +a
export AWS_ACCESS_KEY_ID="$(security find-generic-password -s "$KC_S3_KEY_ID" -w)"
export AWS_SECRET_ACCESS_KEY="$(security find-generic-password -s "$KC_S3_SECRET" -w)"
export RESTIC_PASSWORD_COMMAND="security find-generic-password -s $KC_RESTIC_PASSWORD -w"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"   # R2 用 auto；B2／S3 改成實際 region
