# 新電腦重建順序

前提：密碼管理器的主密碼寫在紙上。新電腦最好用**同一個使用者名稱、同樣的路徑**，否則 Claude 記憶資料夾要改名（PITFALLS #12）。

碰金鑰的步驟（2、4、6）由你自己在 Terminal 跑，不交給 LLM。

1. **密碼管理器**：裝 app 或 CLI（`brew install bitwarden-cli`），登入。取出：restic 密碼、S3 access key／secret、GitHub PAT。
2. **工具**：`brew install git gh restic jq python uv node rsync`；Codex：`npm i -g @openai/codex`；Claude Code 照官網裝。
3. **GitHub**：`gh auth login`。
4. **鑰匙圈還原 restic 存取**：
   ```bash
   git clone https://github.com/<你>/llm-home ~/llm-home      # 或 gh repo clone
   mkdir -p ~/.config/llm-backup && cp ~/llm-home/config.env ~/.config/llm-backup/ 2>/dev/null  # 有備份的話
   bash ~/llm-home/restic/setup-secrets.sh   # 已有密碼時：先手動 security add-generic-password -s <KC_RESTIC_PASSWORD> -w '<密碼>'，腳本會沿用
   ```
   ⚠️ 不要讓 `setup-secrets.sh` 產生**新的** restic 密碼，那樣會打不開舊快照。先把舊密碼放進鑰匙圈再跑。
5. **還原 LLM 設定**：`cd ~/llm-home && ./sync.sh dry-run`（如果 repo 裡沒有 `sync.sh`，先從 llm-backup 跑 `./install.sh --apply`）→ `./sync.sh restore`。
   `claude.json.redacted`、`config.toml.redacted`、`zshrc.names-only` 只有鍵名，值要自己填（看 `SECRETS-INVENTORY.md`）。
6. **用 restic 拉回金鑰和大檔**（最重要的一步）：
   ```bash
   source ~/llm-home/restic/restic-env.sh
   restic snapshots
   restic restore latest --target ~/restore-tmp \
     --include "$HOME/.config" --include "$HOME/.ssh" --include "$HOME/.claude.json"
   # 確認後再搬回原位；要其他資料夾就加 --include
   ```
   沒有 restic 可用時，照 `SECRETS-INVENTORY.md` 逐項重發金鑰。
7. **clone 工作 repo 到同樣的路徑**：`gh repo clone <你>/<repo> ~/Documents/<名>`。
   在 `~/Documents` 裡、要讓 launchd push 的 repo，`.git` 要搬到 `~/git-store`：
   `cd <repo> && git init --separate-git-dir ~/git-store/<名>.git`（PITFALLS #1）。git hooks 從 `~/llm-home/git-store/hooks/` 複製回去。
8. **Python 環境**：各專案 `uv venv && uv pip install -e .`；`~/.claude/scripts/.venv` 用 `llm-home/claude/scripts/requirements.txt` 裝回。
9. **排程**：`cp ~/llm-home/launchd/<prefix>.*.plist ~/Library/LaunchAgents/`，再逐個 `launchctl bootstrap gui/$(id -u) <plist>`。到「完整磁碟取用」加入 `/bin/bash` 和 restic。
10. **LLM 登入**：`claude`、`codex login`。Codex skills 已經由 `sync.sh restore` 帶回 `~/.codex/skills/`。
    Claude 桌面版的 space 記憶要手動匯入（PITFALLS #14）；claude.ai 雲端記憶從 repo 的匯出檔貼回去。
11. **驗證**：照 `VERIFY.md` 做一遍。再請 LLM 讀某個 repo 的 `AGENTS.md`／`CLAUDE.md`，問它三個只有你的規則才答得出來的問題，答對才算接上。
