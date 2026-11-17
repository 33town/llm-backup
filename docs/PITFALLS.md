# 踩過的坑

真的跑一個月以上踩到的，每條附「症狀 → 原因 → 解法」。範本腳本已經處理掉的會註明。
編號是固定的（腳本註解用 `PITFALLS #n` 引用），依主題分組，所以不是照順序排。

## macOS 權限與排程

**1. launchd 讀不到 `~/Documents`**
- 症狀：手動跑沒事，排程跑 log 出現 `Operation not permitted`，git push 或 restic 備份到 `~/Documents` 就斷。
- 原因：macOS 隱私保護（TCC）不讓背景程式讀 `~/Documents`、`~/Desktop`、`~/Downloads`。
- 解法（三選一，可以混用）：
  - 系統設定 → 隱私權與安全性 → **完整磁碟取用**：加 `/bin/bash` 和 `restic` 執行檔（`which restic`）。restic 一定要這樣做。
  - git repo：把 `.git` 搬到外面，`git init --separate-git-dir ~/git-store/<名>.git`，launchd 只碰 `~/git-store`（`git/repos-push.sh`）。
  - 或者不用 launchd，改用 post-commit hook 推（`git/push-if-stale.sh`）；commit 當下是前景程式，讀得到。
  - `LLM_HOME` 本身不要放 `~/Documents`（`install.sh` 會擋）。
- 驗證：`launchctl kickstart gui/$(id -u)/<label>` 之後，log 裡不能有 `permission denied`。

**2. symlink 指進 `~/Documents` 的檔，背景程式複製會 EPERM，整支腳本中止**
- 例：git hook 是 symlink，指到 `~/Documents/…`。
- 解法：單一檔複製失敗只警告、保留舊副本，不讓整支停掉（`sync.sh` 已處理）。

**3. 剛從睡眠醒來，網路還沒通，push 失敗**
- 症狀：log 寫 `Could not resolve host`，那天沒推。
- 解法：push 和 restic 之前先等網路，每 10 秒試一次，最多等 5 分鐘（`lib.sh` 的 `wait_net`）。逾時就放棄，commit 留著，下次補推。

**4. 不需要 pmset 定時喚醒**
- launchd 的 `StartCalendarInterval` 錯過了（電腦在睡），醒來會補跑一次。把時間排在你通常已經開機的時段就好，新電腦也不用再設硬體喚醒。

## restic

**5. exit code 3 不是失敗**
- 意思是快照存好了，只是有幾個檔讀不到（`FileProvider`、某些 App 的鎖定檔，每天都會有）。視為成功並留警告；其他非 0 才是真的失敗（`nightly.sh` 已處理）。

**6. 殘留的鎖讓 prune 默默沒跑**
- 症狀：`repository is already locked`。手動備份中斷會留下鎖；backup 照樣能存，但每週的 `forget --prune` 要排他鎖，就會失敗。
- 解法：確認沒有 restic 在跑（`pgrep -x restic`）之後，跑 `restic unlock`。

**7. 兩個 restic 同時跑**
- 不同視窗各貼了一次指令，兩個互搶鎖。`preflight.sh` 會先檢查。**指令只貼一次**；看到「已有 restic 在跑」就不要再開，也不要急著 `pkill`。

**8. 旅館／公共 Wi-Fi 的 IPv6 不通**
- 症狀：上傳慢到像當機。restic 每一塊先試 IPv6，失敗了退避再試 IPv4。
- 解法：`sudo networksetup -setv6off Wi-Fi`，回到正常網路再 `-setv6automatic`。`preflight.sh` 會提醒。

**9. restic 的 exclude 檔不展開 `~`**
- 要寫完整路徑 `/Users/<你>/...`。範本用 `__HOME__`，`install.sh` 會幫你換。

**10. 雲端硬碟同步資料夾讓備份暴增**
- Synology Drive、iCloud、Google Drive、Dropbox 用「按需下載」時，磁碟上實際是 0，但 restic 會照完整大小去讀（我們遇過 296 GiB）。雲端已經有正本，直接排除 `~/Library/CloudStorage`、`~/Library/Mobile Documents`。

**11. 聊天 App 資料動輒上百 GiB**
- 例：微信加企業微信 185 GiB。先放進 `excludes-big.txt` 排除，想清楚再 `touch ~/.config/restic/include-big`。

**21. 第一次全量要跑好幾個小時**
- 用 `caffeinate -dims` 防止電腦睡著。中斷了重跑同一行就會接續（restic 有去重）。建議先做一個只含金鑰和文件的小「關鍵集」快照，再跑全量。

**23. log 不寫 snapshot id，就看不出有沒有真的存**
- 不要用 `--quiet`。`nightly.sh` 會把 `snapshot xxxxxxxx saved：新增／變動／上傳` 寫進 log。

## LLM 記憶與設定

**12. Claude Code 的記憶資料夾名稱＝工作目錄的絕對路徑**
- `~/.claude/projects/-Users-alice-Documents-MyProject/memory/`。新電腦的使用者名稱或專案位置不一樣，還原後要把資料夾改名才對得上。最簡單的做法：新電腦用同一個使用者名稱、同樣的路徑。

**13. claude.ai 隱藏記憶（帳號層、每個 Project）本機看不到**
- 檔案備份抓不到。只有 Cowork 讀得到（memory 工具），Claude Code 和雲端 routine 都看不到。
- 解法：Cowork 每週排程照 `templates/cloud-memory/EXPORT-PROMPT.md` 原文倒出到 `llm-home/cloud-memory/`，跟著每天的 git 和 restic 備份。

**14. 隱藏記憶不能自動還原**
- 新帳號或新電腦的 Project／space ID 會不一樣。從 `cloud-memory/snapshot/`（或舊的 `cowork/<名>/`）挑要的貼回去，或者用 import-memory 匯入。

**15. 設定檔裡夾著 token**
- `~/.claude.json`（MCP 金鑰、帳號 ID）、`~/.codex/config.toml`、`~/.zshrc` 的 `export XXX_KEY=`。
- 解法：只備份「去掉金鑰、保留鍵名」的副本（`redact.py`）；輸出前會再掃一次，掃到疑似金鑰就整份不寫。新電腦照副本知道要填哪些值。

**16. Codex `/import` 會在專案裡產生 `.codex/`、`.agents/`**
- `.codex/config.toml` 可能有 MCP 金鑰明文。這兩個資料夾一定要列進每個 repo 的 `.gitignore`。

**17. brew 升級 python 之後 venv 壞掉**
- `pip freeze` 失敗，結果把 `requirements.txt` 清空。解法：失敗就保留舊檔，不清空、也不中止備份。

**18. 一個小錯讓整支同步停掉**
- 只要用 `set -e`，任何一個 `cp` 失敗就整天沒備份。同步腳本裡單一項目失敗要「警告後繼續」。

## 流程與安全

**19. 金鑰不要經過 LLM**
- 碰鑰匙圈、密碼管理器、`security` 的指令由人在一般 Terminal 視窗跑。LLM 只產生指令，值用 `<填值>` 佔位。Bitwarden CLI 的 `bw create` 重跑會建出重複項目，只跑一次。
- restic 密碼存兩份：鑰匙圈一份（給排程用），密碼管理器一份（電腦不見時用）。主密碼寫在紙上。**restic 密碼遺失＝備份永遠解不開。**

**20. 有客戶或機密檔的 repo 不要整包上 GitHub**
- 做「過濾鏡像」（只推不含機密的部分），完整版只靠 restic 加密備份。

**22. 沒還原過，就不算有備份**
- 至少做一次：`restic check`，再隨便挑幾個檔 `restic restore` 到暫存資料夾、打開來看（見 `VERIFY.md`）。

**24. 自動化只 push，不 pull、不 force**
- 遠端比本機新（別台電腦或 CI 推過）就讓它失敗、記 log，等人處理。自動 pull 或 force 遲早會蓋掉東西。

## 隱藏記憶（2026-11 新增）

**25. Cowork 的 space 記憶在 2026-09 搬上了雲端，本機備份會默默停住**
- 症狀：`llm-home/cowork/` 從某天起再也沒有更新，但備份 log 一切正常。
- 原因：Claude 桌面版把每個 space 的記憶從 `~/Library/Application Support/Claude/local-agent-mode-sessions/…/spaces/*/memory/` 搬到伺服器端（`space-memory-copy/` 留有搬遷紀錄）。本機資料夾還在，只是不再更新。
- 解法：改用每週匯出（#13）。本機那份當成舊快照保留。

**26. 在 Project 外面建排程，一個就看得到全部記憶**
- Project 裡面的 Cowork 只看得到那個 Project＋帳號層；Project 外面的看得到全部（實測：帳號層 22＋9 個 Project 共 160 檔）。所以只要建**一個**排程，不用每個 Project 各建一個。也會順便抓到你已經忘記的舊 Project。

**27. 匯出排程沒有刪除權限 → 記憶刪掉了，快照還留著**
- Cowork 排程常常不能刪檔，只能覆寫，結果記憶裡已經刪掉的檔，快照裡會一直留著舊版本。對備份是好事（救得回來），但快照會跟實際記憶對不上。
- 解法：`EXPORT-PROMPT.md` 要求把這些檔移到 `snapshot/_removed/<日期>/`，做不到就列在 `LAST-RUN.md` 的 `removed_in_memory`。另外排程最好也只重讀 `updated` 有變的檔，160 個檔每週全讀很花時間。
- 另外一定要有過期警報：`auto-backup.sh` 檢查 `LAST-RUN.md`，超過 8 天沒更新就寫 ⚠️（可接 `NOTIFY_CMD` 推通知）。排程停了不會有人告訴你。
