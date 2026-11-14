#!/usr/bin/env python3
"""產生「去金鑰、保留結構與鍵名」的設定副本，給 sync.sh backup 用（llm-backup）。
用法：redact.py <模式> <來源> <輸出>    模式：claude-json | toml | zshrc
輸出前會掃一次疑似金鑰（長 token、私鑰、常見前綴），掃到就**不寫、exit 1**。--check 只檢查不寫。
"""
import json, re, sys
from pathlib import Path

SENSITIVE_KEY = re.compile(r"token|secret|password|passwd|auth|cookie|session|credential|api[-_]?key|private|bearer|userid|anonymousid|email|account|organization|machine|experiment|clientdata|paired", re.I)
KEEP_IN_MCP = {"type", "command"}
LEAK = re.compile(r"BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AIza[0-9A-Za-z_-]{35}|ghp_[0-9A-Za-z]{36}|github_pat_|sk-ant-[A-Za-z0-9_-]{20,}|sb_secret_|eyJhbGciOi|AKIA[0-9A-Z]{16}|(?<![\w/.-])[A-Za-z0-9_-]{40,}(?![\w/.-])")
R = "<REDACTED>"

def walk(o, in_mcp=False):
    if in_mcp and isinstance(o, str):
        return R
    if isinstance(o, dict):
        out = {}
        for k, v in o.items():
            if k.startswith("cached") or k.endswith("Cache") or k in ("additionalModelOptionsCache", "seenSecurityWarnings"):  # seenSecurityWarnings＝看過的警告雜湊（介面狀態，非金鑰；64 位 hex 會誤觸掃描）
                out[k] = "<dropped-cache>"
            elif k == "mcpServers" and isinstance(v, dict):
                out[k] = {n: {kk: (vv if kk in KEEP_IN_MCP else (walk(vv, True) if isinstance(vv, (dict, list)) else R)) for kk, vv in s.items()} if isinstance(s, dict) else R for n, s in v.items()}
            elif SENSITIVE_KEY.search(k) and not isinstance(v, (bool, int, float)) and v is not None:
                out[k] = R
            else:
                out[k] = walk(v, in_mcp) if not (in_mcp and k in KEEP_IN_MCP) else v
        return out
    if isinstance(o, list):
        return [walk(x, in_mcp) for x in o]
    return o

def red_claude_json(text):
    return json.dumps(walk(json.loads(text)), ensure_ascii=False, indent=1) + "\n"

def red_toml(text):
    out = []
    for line in text.splitlines():
        m = re.match(r"^(\s*)([A-Za-z0-9_.\"-]*(token|secret|key|password|auth|bearer)[A-Za-z0-9_.\"-]*)\s*=\s*(.+)$", line, re.I)
        out.append(f"{m.group(1)}{m.group(2)} = \"{R}\"" if m else line)
    return "\n".join(out) + "\n"

def red_zshrc(text):
    out = ["# ~/.zshrc 的 export 變數名（值已移除；真正的值在密碼管理器／~/.config）"]
    for line in text.splitlines():
        m = re.match(r"^\s*export\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line)
        if m:
            name, val = m.groups()
            out.append(f'export {name}={val if name == "PATH" else chr(34) + R + chr(34)}')
        elif re.match(r"^\s*alias\s+", line):
            out.append(re.sub(r"=.*", "=<...>", line))
    return "\n".join(out) + "\n"

def main():
    args = [a for a in sys.argv[1:] if a != "--check"]
    check = "--check" in sys.argv
    mode, src, dst = args
    text = Path(src).expanduser().read_text()
    res = {"claude-json": red_claude_json, "toml": red_toml, "zshrc": red_zshrc}[mode](text)
    m = None
    for cand in LEAK.finditer(res):
        t = cand.group(0)
        if mode == "toml" and not re.match(r"AIza|ghp_|github_pat_|sk-ant-|sb_secret_|eyJhbGciOi|AKIA|BEGIN", t):
            continue  # toml 的長字串多半是專案路徑 slug／sha256，只看強特徵
        if len(t) >= 40 and re.fullmatch(r"[A-Za-z0-9_-]+", t) and (not re.search(r"\d", t) or re.fullmatch(r"[A-Z0-9_]+", t)):
            continue  # 名稱類（無數字或全大寫底線），不是 token
        m = cand; break
    if m:
        print(f"❌ redact 後仍疑似含金鑰（{mode}，位置 {m.start()}，前綴 {m.group(0)[:4]}…）— 不寫入", file=sys.stderr); sys.exit(1)
    if not check:
        Path(dst).expanduser().parent.mkdir(parents=True, exist_ok=True)
        Path(dst).expanduser().write_text(res)
    print(f"OK {mode} {len(res)}B")

main()
