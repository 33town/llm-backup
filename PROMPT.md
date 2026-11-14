# 貼給你的 LLM

把下面整段貼進 Claude Code 或 Codex（在你的家目錄或任一工作資料夾開啟都可以）。
如果它看得到這個 repo，先叫它讀 `docs/ARCHITECTURE.md` 和 `docs/PITFALLS.md`。

---

````markdown
# 任務：幫我做一套「這台電腦隨時可以消失」的完整備份

參考實作：https://github.com/33town/llm-backup（先讀 README、docs/ARCHITECTURE.md、docs/PITFALLS.md，
照它的範本做，不要自己從零發明）。

## 目標
這台 Mac 明天整台不見，我只要有三樣東西就能在新電腦接著工作：
1. 密碼管理器（Bitwarden／1Password），主密碼另外寫在紙上
2. GitHub（private repo）
3. S3 相容雲端儲存（Cloudflare R2／Backblaze B2／S3），用 restic 加密

新電腦用任何一個 LLM（Claude Code 或 Codex，換帳號也行）都要能接手，不能只靠某一家的雲端記憶。

## 規則（一定要遵守）
- 先**盤點**，不要動手：列出我的工作資料夾、git repo（哪些在 ~/Documents）、LLM 設定
  （~/.claude、~/.codex、~/.claude.json）、launchd／cron 排程、金鑰放哪（~/.config、.env、~/.ssh）、
  前 20 大的資料夾（du）。做成表格給我看，我核准之後才開始。
- **金鑰不准進 git**，也不准出現在對話或紀錄裡，只能記名字和放在哪。
- 碰憑證、`security`（鑰匙圈）、密碼管理器、launchd 的指令，**寫出來讓我自己在 Terminal 跑**。
- 會寫檔的腳本先跑 dry-run（只看不寫的版本）。llm-backup 的 install.sh 預設就是 dry-run。
- 不刪、不搬我現有的檔案。要動之前先列出路徑，等我同意。

## 要做的四層
| 層 | 內容 | 備份到哪 | 頻率 |
|---|---|---|---|
| A 知識＋程式 | 所有工作 repo | GitHub private | 每天自動 push |
| B LLM 設定 | ~/.claude（CLAUDE.md、commands、skills、projects/*/memory）、~/.codex（AGENTS.md、skills、memories）、去金鑰的設定檔副本、launchd plist | 單獨一個 llm-home repo，用 sync.sh 單向同步 | 每天 |
| B′ 雲端記憶 | claude.ai Project／帳號層記憶（本機看不到） | 請 Claude 桌面版／網頁版倒出成 md 放進 repo | 手動，偶爾 |
| C＋D 金鑰＋大檔 | 整個 $HOME：金鑰、gitignore 掉的資料、對話逐字稿 | restic 加密增量 → 雲端 | 每天，每週 forget --prune |

restic 排除：雲端硬碟同步資料夾、快取、Photos、Mail、特別大的聊天 App 資料（先問我）。

## 一定會踩到的坑（先處理，細節在 docs/PITFALLS.md）
- macOS 不讓 launchd 讀 ~/Documents → /bin/bash 和 restic 要給「完整磁碟取用」；
  要自動 push 的 repo 把 .git 搬到 ~/git-store（git init --separate-git-dir），llm-home 放在 ~/Documents 外面。
- 剛醒來網路還沒通 → push 和 restic 之前先等網路，最多 5 分鐘。睡著錯過的排程醒來會補跑，不用 pmset。
- Claude Code 記憶資料夾名＝工作目錄絕對路徑 → 新電腦使用者名稱不同要改名。
- 有金鑰的設定檔只備份「去掉金鑰」的副本，掃到疑似金鑰就整份不寫。
- Codex /import 產生的 .codex/、.agents/ 可能有金鑰明文 → 加進 .gitignore。
- restic exit 3 是部分檔案讀不到，不是失敗；殘留的鎖會讓 prune 默默沒跑 → restic unlock。

## 交付
1. llm-home/BOOTSTRAP.md：新電腦從零開始的步驟（照 docs/BOOTSTRAP.md 改成我的版本）
2. llm-home/SECRETS-INVENTORY.md：每把金鑰的名字、用途、放哪、遺失時怎麼重發（不寫值）
3. 每個工作 repo 根目錄放 AGENTS.md，寫「先讀 CLAUDE.md」，讓 Codex 也接得上
4. 三個 launchd 排程（repo push、llm-home sync、restic），log 寫到 ~/Library/Logs/
5. **驗證**（docs/VERIFY.md 全部打勾才算完成）：restic check 通過；抽 3 個檔 restore 回暫存資料夾打開看；
   所有 repo 都 push 了；每個排程用 kickstart 實際跑過一次，log 裡有 snapshot id
6. 最後給我一段白話說明：每天看哪三個 log、怎麼檢查有沒有漏推、最多會丟多少
````
