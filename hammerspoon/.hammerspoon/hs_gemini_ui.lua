-- ========================================================================
-- hs_gemini_ui.lua - UI 樣式範本模組
-- ========================================================================
local M = {}
function M.generate(getLogFiles, readLogContent, current_session_file)
    local fileListHtml = ""
    for _, f in ipairs(getLogFiles()) do
        local activeClass = (current_session_file and current_session_file:match(f)) and "active" or ""
        fileListHtml = fileListHtml .. string.format([[<div class="log-item %s" onclick="hsCall('selectLog', '%s')">%s</div>]], activeClass, f, f)
    end
    local currentLogContent = current_session_file and readLogContent(current_session_file:match("[^/]+$")) or "💡 提示：請點擊左側「歷史 Log」延續對話，或直接在下方點擊輸入開啟對話。"
    
    return [[<!DOCTYPE html><html><head><meta charset="utf-8"><style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, sans-serif; }
        body { display: flex; height: 100vh; background: #1e1e2e; color: #cdd6f4; overflow: hidden; }
        #sidebar { width: 250px; background: #11111b; border-right: 1px solid #313244; display: flex; flex-direction: column; }
        .sidebar-header { padding: 12px; font-weight: bold; border-bottom: 1px solid #313244; color: #a6e3a1; display: flex; justify-content: space-between; align-items: center; }
        .log-list { flex: 1; overflow-y: auto; padding: 8px; }
        .log-item { padding: 8px; margin-bottom: 6px; background: #181825; border-radius: 6px; cursor: pointer; font-size: 12px; text-overflow: ellipsis; overflow: hidden; white-space: nowrap; }
        .log-item:hover { background: #313244; }
        .log-item.active { background: #2f334d; border: 1px solid #89b4fa; color: #89b4fa; }
        #main { flex: 1; display: flex; flex-direction: column; background: #1e1e2e; }
        #chat-output { flex: 1; padding: 15px; overflow-y: auto; font-size: 13px; line-height: 1.5; white-space: pre-wrap; background: #1e1e2e; border-bottom: 1px solid #313244; }
        #input-area { padding: 12px; background: #181825; display: flex; flex-direction: column; gap: 8px; }
        textarea { width: 100%; height: 70px; background: #313244; border: 1px solid #45475a; border-radius: 6px; color: #cdd6f4; padding: 10px; font-size: 13px; resize: none; cursor: pointer; }
        .btn-group { display: flex; justify-content: flex-end; gap: 8px; }
        button { padding: 6px 12px; border: none; border-radius: 6px; cursor: pointer; font-weight: bold; font-size: 12px; }
        .btn-prompt { background: #cba6f7; color: #11111b; }
        .btn-submit { background: #89b4fa; color: #11111b; }
        .btn-new { background: #a6e3a1; color: #11111b; }
        .btn-close { background: #f38ba8; color: #11111b; }
        .btn-refresh { background: #45475a; color: #cdd6f4; padding: 3px 8px; font-size: 11px; }
    </style><script>
        function hsCall(act, val) { window.webkit.messageHandlers.geminiSystemBridge.postMessage({action: act, data: val}); }
        function openPrompt() { hsCall('openPrompt', document.getElementById('user-input').value); }
        function submitChat(isNew) { 
            const el = document.getElementById('user-input'); 
            hsCall(isNew ? 'v3StartChat' : 'v3NextChat', el.value); 
            el.value = ''; 
        }
    </script></head><body>
        <div id="sidebar">
            <div class="sidebar-header">
                <span>歷史 Log</span>
                <button class="btn-refresh" onclick="hsCall('refresh', '')">🔄 整理</button>
            </div>
            <div class="log-list">]] .. fileListHtml .. [[</div>
        </div>
        <div id="main">
            <div id="chat-output">]] .. currentLogContent .. [[</div>
            <div id="input-area">
                <textarea id="user-input" readonly onclick="openPrompt()" placeholder="點擊此處開啟大文字輸入框 (自動附帶剪貼簿中的文字與圖片送出)..."></textarea>
                <div class="btn-group">
                    <button class="btn-close" onclick="hsCall('close', '')">關閉</button>
                    <button class="btn-prompt" onclick="openPrompt()">⌨️ 大對話框輸入</button>
                    <button class="btn-new" onclick="submitChat(true)">🆕 新對話並送出</button>
                    <button class="btn-submit" onclick="submitChat(false)">🚀 送出 (對話 + 圖片/剪貼簿)</button>
                </div>
            </div>
        </div>
        <script>var d = document.getElementById("chat-output"); d.scrollTop = d.scrollHeight;</script>
    </body></html>]]
end
return M