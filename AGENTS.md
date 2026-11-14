# 給 LLM（Claude Code／Codex）

你被請來幫人做「整台電腦＋LLM 設定」的備份。照這個順序：

1. 讀 `PROMPT.md`（任務、規則、交付項目），那就是你的指令。
2. 讀 `docs/ARCHITECTURE.md`（四層架構）和 `docs/PITFALLS.md`（踩過的坑），再開始。
3. 先盤點、列表給使用者核准；`./install.sh` 預設是 dry-run，看過輸出、使用者同意了才加 `--apply`。
4. 金鑰、鑰匙圈（`security`）、密碼管理器、launchd、`restic init` 的指令一律交給使用者自己在 Terminal 跑，你只產生指令。
5. 完成的標準是 `docs/VERIFY.md` 全部打勾，不是「腳本裝好了」。

`templates/` 裡是範本，install.sh 會把它們複製到使用者的 `$LLM_HOME`（預設 `~/llm-home`）。要改行為，改使用者那份，不要改這個 repo。
