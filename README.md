# llm-backup

**讓這台 Mac 隨時可以消失。** 一套給 Claude Code／Codex 使用者的整機備份做法：工作 repo、LLM 的記憶和設定、金鑰、大檔全部備份，換一台新電腦（甚至換一家 LLM）也能接著做。

> *English summary:* A battle-tested recipe for backing up a Mac that runs Claude Code / Codex — git for repos and LLM config (`~/.claude`, `~/.codex`, per-project memory), restic → S3-compatible storage for everything else (secrets, transcripts, raw data), launchd for scheduling. Includes templates, a dry-run-by-default installer, a prompt to hand to your own LLM, and a weekly Cowork job that exports claude.ai's server-side memory, and a list of 27 pitfalls we actually hit. Docs are in Traditional Chinese.

## 最快的用法：交給你的 LLM

把 [`PROMPT.md`](PROMPT.md) 那段貼進 Claude Code 或 Codex。它會先盤點你的電腦、等你核准，再照這裡的範本裝好。碰金鑰的指令會交給你自己跑。

## 自己裝

```bash
git clone https://github.com/33town/llm-backup && cd llm-backup
./install.sh            # dry-run：只印出會做什麼
./install.sh --apply    # 真的放範本到 ~/llm-home，最後印出你要自己跑的步驟
```

需要：macOS、`git`、`rsync`、`python3`、`curl`、`restic`、`gh`（`brew install restic gh`），一個密碼管理器，一個 S3 相容的 bucket（Cloudflare R2 免費額度 10 GB、沒有下載費）。

## 備份了什麼

| 層 | 內容 | 去哪 |
|---|---|---|
| A 知識＋程式 | 你的工作 repo | GitHub private |
| B LLM 設定 | `~/.claude`（CLAUDE.md、commands、skills、每個專案的 memory）、`~/.codex`、去金鑰的設定檔副本、排程 | `llm-home` private repo |
| B′ 隱藏記憶 | claude.ai 帳號層＋每個 Project 的記憶（含 Cowork） | Cowork 每週排程原文倒出到 `llm-home/cloud-memory/`，跟著 git 和 restic 備份 |
| C＋D 金鑰＋大檔 | 整個 `$HOME`（排除快取和雲端同步資料夾） | restic 加密 → R2／B2／S3 |

開門的鑰匙只有一組：密碼管理器裡的 restic 密碼和 S3 key。架構圖和設計理由在 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

## 文件

| 檔 | 內容 |
|---|---|
| [`PROMPT.md`](PROMPT.md) | 貼給 LLM 的完整指令 |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | 四層架構、為什麼這樣分、每天看哪三個 log |
| [`docs/PITFALLS.md`](docs/PITFALLS.md) | **27 個實際踩過的坑**：`~/Documents` 權限、剛醒來網路沒通、restic exit 3、殘留的鎖、IPv6、記憶資料夾用路徑命名、設定檔夾著 token… |
| [`docs/BOOTSTRAP.md`](docs/BOOTSTRAP.md) | 新電腦從零開始的 11 步 |
| [`docs/VERIFY.md`](docs/VERIFY.md) | 驗證清單：沒還原過就不算有備份 |
| [`docs/SECRETS-INVENTORY.template.md`](docs/SECRETS-INVENTORY.template.md) | 金鑰清單範本（只記名字和位置） |

## 範本（`templates/` → 安裝到 `~/llm-home`）

| 檔 | 做什麼 |
|---|---|
| `sync.sh` | `dry-run`／`backup`／`restore`：`~/.claude`、`~/.codex` ↔ repo，單向，排除金鑰 |
| `redact.py` | 產生去金鑰的 `~/.claude.json`、`config.toml`、`.zshrc` 副本；掃到疑似金鑰就不寫 |
| `auto-backup.sh` | sync → 有變動才 commit → 等網路 → push |
| `restic/nightly.sh` | 等網路 → preflight → 備份 `$HOME` → log 寫 snapshot id → 週日 prune |
| `restic/setup-secrets.sh` | 產生 restic 密碼、S3 key 存進鑰匙圈（你自己跑） |
| `restic/excludes.txt` | 排除清單起點 |
| `git/repos-push.sh` | push `~/git-store/*.git`（給 launchd 用，繞過 `~/Documents` 權限） |
| `git/push-if-stale.sh` | 另一種做法：post-commit hook 推 |
| `cloud-memory/EXPORT-PROMPT.md` | Cowork 每週排程讀的匯出指令（設定步驟寫在檔案最上面） |
| `git/check-repos.sh` | 唯讀檢查所有 repo 有沒有漏 commit、漏 push |
| `launchd/backup.plist.template` | 三個每日排程 |

設定在 `~/.config/llm-backup/config.env`（路徑、排程時間、launchd 前綴、要檢查的 repo）。

## 原則

- 預設 dry-run；不刪、不覆蓋既有檔案。
- 金鑰不進 git、不經過 LLM；鑰匙圈和 launchd 的指令只印出來，由人執行。
- 自動化只 push，不 pull、不 force。
- 沒還原過就不算有備份。

## 解除

`./uninstall.sh` 會印出停止排程的指令。它不會刪你的備份內容、雲端快照或鑰匙圈。

## License

MIT
