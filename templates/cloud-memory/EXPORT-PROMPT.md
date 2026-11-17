<!-- LLM: Cowork 每週排程讀這份做事。改匯出方式只改這裡，排程本身不用動。 -->
# 每週匯出 Claude 隱藏記憶

claude.ai 的記憶（帳號層、每個 Project，包括 Claude 桌面版 Cowork 的 space 記憶）存在 Anthropic 的伺服器上，本機沒有檔案，一般的備份抓不到。這份指令讓 Cowork 每週把它們原文倒出來，寫進 `$LLM_HOME`，之後跟著每天的 git 和 restic 一起備份。

## 怎麼設定（只做一次）

1. 在 Claude 桌面版 Cowork **不要進任何 Project**，建一個排程：
   - 名稱：`cloud-memory-weekly-export`
   - 時間：每週一次，排在每天備份**之前**的幾個小時（例：備份 12:30 → 週日 11:00）
   - 資料夾權限：選你的 `$LLM_HOME`（預設 `~/llm-home`）
   - 指令只要一行：`照 ~/llm-home/cloud-memory/EXPORT-PROMPT.md 做`
2. 建好後馬上手動跑一次（Run now），檢查 `cloud-memory/LAST-RUN.md` 的檔數和錯誤。

為什麼在 Project 外面：Project 外的 Cowork 對話看得到**全部**記憶，帳號層和每個 Project 都看得到（2026-11 實測）。在某個 Project 裡面只看得到那個 Project 加上帳號層，那樣每個 Project 都要各建一個排程。

---

## 給排程的指令

你是 Cowork 的每週排程，不在任何 Project 裡執行。

1. 用 memory 工具列出你看得到的**所有**目錄和檔案，包括帳號層 `/` 和每個 `/projects/<id>/`。
2. 逐檔讀出**全文**，原樣寫到 `~/llm-home/cloud-memory/snapshot/`：
   - 帳號層 → `snapshot/account/<原路徑>`
   - Project → `snapshot/projects/<Project 名稱>/<原路徑>`
   - 每檔第一行加：`<!-- source: <memory 原路徑> | scope: account 或 project:<名稱> | updated: <最後更新時間> -->`，第二行開始是**原文，不摘要、不改寫、不翻譯**。
3. **反映刪除**：快照裡有、但記憶裡已經不存在的檔，移到 `snapshot/_removed/<YYYY-MM-DD>/`（保留原路徑）。沒有刪除權限的話不要跳過，把這些檔列在 `LAST-RUN.md` 的 `removed_in_memory`。
4. 寫 `snapshot/INDEX.md`：表格欄位是 scope、檔案路徑、最後更新、一句話描述，最上面寫匯出時間和每個 scope 的檔數。
5. 最後寫 `~/llm-home/cloud-memory/LAST-RUN.md`（覆蓋）：
   ```
   last_run: <ISO 時間，含時區>
   total_files: <數字>
   per_scope: account=<n>, <Project 名>=<n>, ...
   removed_in_memory: <沒有就寫 none>
   errors: <沒有就寫 none>
   ```

規則：
- **只讀記憶，不改、不刪、不新增任何記憶。**
- 不要 commit 或 push，每天的備份排程會處理。
- 寫完檢查 `snapshot/` 的檔數（不含 `_removed/`、`INDEX.md`）等於第 1 步列出的總數，對不上就寫進 errors。
- 寫不進 `~/llm-home` 的話，不要寫到別的地方，在排程的執行結果裡說明原因。
