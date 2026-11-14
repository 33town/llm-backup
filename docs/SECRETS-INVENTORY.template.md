# 金鑰清單（範本）

複製到你的 `llm-home/SECRETS-INVENTORY.md` 填寫。**只寫名字和位置，絕對不寫值。**
用途：新電腦知道要拿回哪些金鑰；restic 打不開時，照這份逐項重發。

| 名稱 | 用途 | 本機放在哪 | 原件在哪 | 遺失時怎麼重發 |
|---|---|---|---|---|
| restic 密碼 | 解開所有雲端快照 | 鑰匙圈 `restic-backup` | 密碼管理器 | ⚠️ **不能重發**，遺失＝快照全部解不開 |
| S3 access key／secret | restic 讀寫 bucket | 鑰匙圈 `restic-s3-key-id`／`restic-s3-secret` | 密碼管理器 | 儲存服務後台 → API tokens 重建（只授權這個 bucket） |
| GitHub PAT | gh、push | `gh auth` 的鑰匙圈 | 密碼管理器 | GitHub → Settings → Developer settings |
| Anthropic API key | | `~/.zshrc` 的 `ANTHROPIC_API_KEY` | | console.anthropic.com |
| OpenAI／Codex 登入 | | `~/.codex/auth.json` | — | `codex login` |
| MCP server token（每個一列） | | `~/.claude.json` → `mcpServers` | | |
| Google service account JSON | | `~/.config/…` | | GCP console → IAM → Service accounts |
| SSH key | | `~/.ssh/` | restic | 重產後到各服務更新公鑰 |
| 專案 `.env`（每個一列） | | `<repo>/.env` | restic | |

最後更新：YYYY-MM-DD
