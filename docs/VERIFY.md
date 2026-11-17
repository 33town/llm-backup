# 驗證清單

下面每一項都要做過，才算「有備份」。

## 裝好當天

- [ ] `./sync.sh dry-run` 列出的檔案合理，沒有 `auth.json`、`.env`、`*.pem`
- [ ] `llm-home` 裡掃不到金鑰：
      `grep -rIE 'sk-ant-|ghp_|github_pat_|AKIA[0-9A-Z]{16}|BEGIN .*PRIVATE KEY|AIza[0-9A-Za-z_-]{35}' ~/llm-home --exclude-dir=.git`（要沒有輸出）
- [ ] `llm-home` 和所有工作 repo 都 push 了：`bash ~/llm-home/git/check-repos.sh` 全部 ✅
- [ ] restic 第一次全量完成，`restic snapshots` 看得到
- [ ] `restic check` 通過
- [ ] **真的還原一次**：挑 3 個不同地方的檔案（一個金鑰檔、一個文件、一個 LLM 記憶），
      `restic restore latest --target ~/restore-test --include <路徑>`，打開來看內容對不對，看完刪掉 `~/restore-test`
- [ ] 每個排程都 `launchctl kickstart gui/$(id -u)/<label>` 實際跑過一次，log 裡：
  - restic：有 `snapshot xxxxxxxx saved`，`~/Documents` 底下沒有 `permission denied`
  - repos／llm-home：有 `push 完成` 或 `沒有變動`
- [ ] Cowork 每週匯出排程 Run now 過一次：`cloud-memory/LAST-RUN.md` 的 `total_files` 跟 Cowork 列出的記憶總數一樣、`errors: none`
- [ ] restic 密碼、S3 key、GitHub PAT 都在密碼管理器裡，主密碼寫在紙上

## 之後

- [ ] 每週看一次三個 log（見 ARCHITECTURE.md「日常節奏」）
- [ ] 週一確認 restic.log 有 `forget/prune 完成`；沒有的話照 PITFALLS #6 處理
- [ ] 每季還原抽查一次
- [ ] 有條件的話，開一個新的 macOS 使用者帳號，照 BOOTSTRAP.md 從零重建一次（最完整的演練）
