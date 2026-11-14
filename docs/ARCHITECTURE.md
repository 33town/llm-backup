# 架構

## 目標

這台電腦隨時可以消失。只要有下面三樣，就能在新電腦（或新帳號）接著工作，用 Claude Code 或 Codex 都可以接手：

1. **密碼管理器**（Bitwarden／1Password），主密碼寫在紙上
2. **GitHub** private repo
3. **S3 相容的雲端儲存**（Cloudflare R2／Backblaze B2／AWS S3），用 restic 加密

## 全貌

```
┌───────────────────────────── 你的 Mac（隨時可丟）─────────────────────────────┐
│                                                                              │
│  工作 repo（~/Documents/…）   ~/git-store/*.git   ~/llm-home   ~/.claude ~/.codex │
│        │  commit                  │                  ▲  sync.sh backup   │      │
│        └──────────────────────────┘                  └───────────────────┘      │
│                                                                              │
│  每天 HH:MM，launchd：                                                         │
│   ① <prefix>.repos.backup     git/repos-push.sh   → push ~/git-store/*.git      │
│   ② <prefix>.llm-home.backup  auto-backup.sh      → sync → commit → push        │
│   ③ <prefix>.restic           restic/nightly.sh   → 整個 $HOME 加密增量           │
└───────┬──────────────────────────────┬───────────────────────────┬───────────┘
        │ git push                     │ git push                  │ restic（加密）
        ▼                              ▼                           ▼
 ┌──────────────┐             ┌────────────────┐          ┌──────────────────────┐
 │ GitHub       │             │ GitHub         │          │ R2／B2／S3 bucket      │
 │ 各工作 repo   │             │ llm-home       │          │ 每日快照；週日 prune   │
 │ (private)    │             │ (private)      │          │ 14 天／8 週／12 個月   │
 └──────────────┘             └────────────────┘          └──────────────────────┘
        ▲                                                            ▲
        │ 手動匯出                                                    │ 開門鑰匙
 ┌──────┴────────────────┐                                ┌──────────┴───────────┐
 │ claude.ai 雲端記憶      │                                │ 密碼管理器（＋紙本）    │
 │ Projects／帳號層        │                                │ restic 密碼、S3 key、   │
 │ → 倒出成 md 進 repo     │                                │ GitHub PAT             │
 └───────────────────────┘                                └──────────────────────┘
```

## 四層

| 層 | 內容 | 正本 | 備份到哪 | 頻率 | 最多丟多少 |
|---|---|---|---|---|---|
| **A 知識＋程式** | 你所有工作 repo | 本機 | GitHub private（也會在 restic 裡） | commit 後每天 push | 當天沒 commit 的改動 |
| **B LLM 設定** | `~/.claude`（CLAUDE.md、commands、skills、agents、`projects/*/memory`）、`~/.codex`（AGENTS.md、skills、memories）、去金鑰的 `~/.claude.json`／`config.toml`／`.zshrc`、launchd plist、git hooks | 本機 | `llm-home` repo（也會在 restic 裡） | 每天 | 不到 24 小時 |
| **B′ 雲端記憶** | claude.ai 的 Project 記憶、帳號層記憶、Project 說明 | Anthropic 伺服器 | 手動倒出成 md 放進 repo | 偶爾 | 小（重要決策本來就該寫在 repo） |
| **C 金鑰** | `~/.config/*`、`.env`、`~/.ssh`、`~/.claude.json` | 本機 | 跟著 restic 加密備份；開門鑰匙在密碼管理器；清單在 `SECRETS-INVENTORY.md` | 每天 | — |
| **D 大檔＋其他** | gitignore 掉的原始資料、Claude／Codex 對話逐字稿、瀏覽器 profile、個人檔案 | 本機 | restic 全量加密 | 每天 | 不到 24 小時 |

## 為什麼這樣分

- **git 存「會讀的」，restic 存「全部」**。git 有歷史、能 diff、新電腦 clone 下來馬上能用；restic 去重加密，什麼都丟得進去，包括金鑰和逐字稿（這些絕對不能進 git）。
- **LLM 設定單獨開一個 repo**（`llm-home`），因為它的正本散在 `~/.claude`、`~/.codex`，不屬於任何工作 repo。用 `sync.sh` 單向複製：本機是正本，repo 只是備份；換電腦時才反過來 `restore`。
- **金鑰只靠一把鑰匙開**：所有金鑰都在 restic 快照裡（加密），只要記得 restic 密碼和 S3 key（放在密碼管理器）就能全部拿回來。`SECRETS-INVENTORY.md` 記每把金鑰叫什麼、放哪、遺失了怎麼重發，是最後一道防線。
- **不依賴特定一家 LLM**：每個工作 repo 根目錄都放一份 `AGENTS.md`（Codex 會讀），內容寫「先讀 CLAUDE.md」，再附 Claude 和 Codex 的指令對照。這樣只有 Codex 也接得下去。

## 日常節奏

每段工作結束 commit（或在 Claude Code 跑你的收尾指令）→ 每天排程自動 push repo 和 llm-home → 同一時間 restic 增量。

每天看三個 log 就夠：

| log | 要看到 |
|---|---|
| `~/Library/Logs/llm-home-backup.log` | `push 完成` 或 `沒有變動` |
| `~/Library/Logs/repos-backup.log` | 每個 repo 一行 `push 完成` 或 `沒有未推的 commit` |
| `~/Library/Logs/restic.log` | `snapshot xxxxxxxx saved：…` |

一次檢查所有 repo 有沒有漏推：`bash ~/llm-home/git/check-repos.sh`。
