-- ========================================================================
-- hs_geminiai.lua - 核心控制邏輯模組 (支援圖片讀取與大輸入框)
-- ========================================================================
local hs = _G.hs
local pasteboard = require("hs.pasteboard")
local http       = require("hs.http")
local json       = require("hs.json")
local ui         = require("hs_gemini_ui")

local M = {}
local LOG_DIR = os.getenv("HOME") .. "/Documents/Gemini_Sessions/"
hs.fs.mkdir(LOG_DIR)

local webview = nil
local promptWebview = nil
local current_session_file = nil

local function getLogFiles()
    local files = {}
    for file in hs.fs.dir(LOG_DIR) do
        if file:match("%.log$") then table.insert(files, file) end
    end
    table.sort(files, function(a, b) return a > b end)
    return files
end

local function readLogContent(filename)
    if not filename then return "" end
    local file = io.open(LOG_DIR .. filename, "r")
    if not file then return "無法讀取檔案" end
    local content = file:read("*all")
    file:close()
    return content
end

local function pushToNotion(title, content)
    local NOTION_TOKEN = "" 
    local NOTION_DB_ID = ""
    if NOTION_TOKEN == "" or NOTION_DB_ID == "" then return end
    
    local headers = { ["Authorization"] = "Bearer " .. NOTION_TOKEN, ["Content-Type"] = "application/json", ["Notion-Version"] = "2022-06-28" }
    local body = json.encode({ parent = { database_id = NOTION_DB_ID }, properties = { Title = { title = { { text = { content = title } } } } }, children = { { object = "block", type = "heading_2", heading_2 = { rich_text = { { text = { content = "Gemini報告" } } } } }, { object = "block", type = "code", code = { language = "markdown", rich_text = { { text = { content = content } } } } } } })
    http.doAsyncRequest("https://notion.com", "POST", body, headers, function() end)
end

local function refreshWebview()
    if webview then webview:html(ui.generate(getLogFiles, readLogContent, current_session_file)) end
end

-- 彈出專用的多行大輸入框視窗
-- 彈出專用的多行大輸入框視窗 (解決鍵盤無法輸入修正版)
local function openLargePromptWindow(initialText)
    if promptWebview then promptWebview:delete() promptWebview = nil end

    local mainScreen = hs.screen.mainScreen():fullFrame()
    local width, height = 600, 400
    local rect = hs.geometry.rect((mainScreen.w - width)/2, (mainScreen.h - height)/2, width, height)

    local promptController = hs.webview.usercontent.new("geminiPromptBridge"):setCallback(function(msg)
        local act, data = msg.body.action, msg.body.data
        if act == "submitPrompt" then
            if promptWebview then promptWebview:delete() promptWebview = nil end
            local cleanInput = (data or ""):gsub("\\", "\\\\"):gsub("'", "\\'"):gsub("\n", "\\n"):gsub("\r", "")
            if webview then
                webview:evaluateJavaScript(string.format("document.getElementById('user-input').value = '%s';", cleanInput))
            end
        elseif act == "closePrompt" then
            if promptWebview then promptWebview:delete() promptWebview = nil end
        end
    end)

    promptWebview = hs.webview.new(rect, { developerExtrasEnabled = true, ignoreCache = true }, promptController)
    
    -- 【關鍵修正 1】：改為標準視窗 masks (去掉 utility)，並使用 normal 層級讓 macOS 賦予鍵盤焦點
    promptWebview:windowStyle(hs.webview.windowMasks.titled | hs.webview.windowMasks.closable)
    promptWebview:windowTitle("⌨️ 輸入對話內容")
    promptWebview:level(hs.drawing.windowLevels.normal)

    local safeInit = (initialText or ""):gsub("\\", "\\\\"):gsub("`", "\\`"):gsub("\n", "\\n"):gsub("\r", "")
    local html = string.format([[<!DOCTYPE html><html><head><meta charset="utf-8"><style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, sans-serif; }
        body { background: #181825; color: #cdd6f4; padding: 15px; display: flex; flex-direction: column; height: 100vh; gap: 10px; }
        textarea { flex: 1; width: 100%%; background: #313244; border: 1px solid #45475a; border-radius: 8px; color: #cdd6f4; padding: 12px; font-size: 14px; resize: none; outline: none; }
        textarea:focus { border-color: #89b4fa; box-shadow: 0 0 5px rgba(137, 180, 250, 0.5); }
        .btn-group { display: flex; justify-content: flex-end; gap: 10px; }
        button { padding: 8px 16px; border: none; border-radius: 6px; cursor: pointer; font-weight: bold; font-size: 13px; }
        .btn-ok { background: #89b4fa; color: #11111b; }
        .btn-cancel { background: #f38ba8; color: #11111b; }
    </style></head><body>
        <textarea id="prompt-input" placeholder="請輸入對話內容... (支援 Cmd+Enter 送出)">%s</textarea>
        <div class="btn-group">
            <button class="btn-cancel" onclick="hsCall('closePrompt', '')">取消</button>
            <button class="btn-ok" onclick="submit()">確定</button>
        </div>
        <script>
            function hsCall(act, val) { window.webkit.messageHandlers.geminiPromptBridge.postMessage({action: act, data: val}); }
            function submit() { hsCall('submitPrompt', document.getElementById('prompt-input').value); }
            
            // 自動聚焦輸入框
            window.onload = function() {
                var el = document.getElementById('prompt-input');
                el.focus();
                el.setSelectionRange(el.value.length, el.value.length);
            }
            
            document.addEventListener('keydown', function(e) {
                if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
                    submit();
                }
            });
        </script>
    </body></html>]], safeInit)

    promptWebview:html(html)
    promptWebview:show()

    -- 【關鍵修正 2】：強迫 macOS 關注並啟動 Hammerspoon 視窗焦點
    hs.focus(true)
    local win = promptWebview:hswindow()
    if win then
        win:focus()
    end

    -- 【關鍵修正 3】：微延遲再次補強焦點，確保 WebKit 完全渲染後輸入光標激活
    hs.timer.doAfter(0.15, function()
        if promptWebview then
            hs.focus(true)
            local pWin = promptWebview:hswindow()
            if pWin then pWin:focus() end
            promptWebview:evaluateJavaScript("document.getElementById('prompt-input').focus();")
        end
    end)
end

local function handleWebActions(message)
    local body = message.body
    local action, data = body.action, body.data

    if action == "close" then
        if webview then webview:delete() webview = nil end
    elseif action == "refresh" then
        refreshWebview()
    elseif action == "selectLog" then
        current_session_file = LOG_DIR .. data
        refreshWebview()
    elseif action == "openPrompt" then
        openLargePromptWindow(data)
    elseif action == "v3StartChat" or action == "v3NextChat" then
        local userText = data or ""
        local isNew = (action == "v3StartChat")

        if isNew or not current_session_file then
            current_session_file = LOG_DIR .. "session_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
            isNew = true
        end

        -- 建立 Parts 陣列 (支援文字與圖片)
        local parts = {}
        local fullPromptText = userText

        -- 1. 讀取剪貼簿文字
        local clipboardText = pasteboard.getContents() or ""
        if clipboardText ~= "" then
            fullPromptText = fullPromptText .. "\n\n[附帶剪貼簿文字]:\n" .. clipboardText
        end

        local apiPrompt = isNew and fullPromptText or ("歷史紀錄：\n" .. readLogContent(current_session_file:match("[^/]+$")) .. "\n\n新問題：\n" .. fullPromptText)
        table.insert(parts, { text = apiPrompt })

        -- 2. 讀取剪貼簿圖片並轉為 Base64
        local clipboardImg = pasteboard.readImage()
        local hasImage = false
        if clipboardImg then
            local bitmap = clipboardImg:encodeAsBytes(hs.image.format.png)
            if bitmap then
                local base64Data = hs.base64.encode(bitmap)
                table.insert(parts, {
                    inline_data = {
                        mime_type = "image/png",
                        data = base64Data
                    }
                })
                hasImage = true
            end
        end

        local contentsPayload = { contents = { { role = "user", parts = parts } } }

        webview:evaluateJavaScript("document.getElementById('chat-output').innerText = '🤖 Gemini 正在思考中 (包含圖片處理)...';")
        
        -- 請填入你在 Google AI Studio 申請的真實 API Key
        local mySecretKey = "AQ.Ab8RN6LfQ9HQZYiR4wkjAoAX5jCG3TxLNh7CnWezC-qWZNLVqg"
        local cleanKey = string.gsub(mySecretKey, "%s+", "")

        local finalUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=" .. cleanKey
        local postBody = json.encode(contentsPayload)

        http.doAsyncRequest(finalUrl, "POST", postBody, { ["Content-Type"] = "application/json" }, function(status, responseBody, headers)
            if status == 200 and responseBody then
                local success, decoded = pcall(json.decode, responseBody)
                if success and decoded and decoded.candidates and decoded.candidates[1] 
                   and decoded.candidates[1].content and decoded.candidates[1].content.parts 
                   and decoded.candidates[1].content.parts[1] then
                    
                    local aiResponse = decoded.candidates[1].content.parts[1].text
                    local currentTime = os.date("%Y-%m-%d %H:%M:%S")

                    local logFile = io.open(current_session_file, "a")
                    if logFile then
                        if isNew then logFile:write("====================\n🤖 START: " .. currentTime .. "\n====================\n") end
                        local logText = fullPromptText .. (hasImage and "\n[已附帶剪貼簿圖片送出]" or "")
                        logFile:write("\n👤 USER:\n" .. logText .. "\n\n🤖 GEMINI:\n" .. aiResponse .. "\n\n--------------------\n")
                        logFile:close()
                    end
                    pushToNotion("Gemini對話 - " .. os.date("%m/%d %H:%M"), "【問題】:\n" .. fullPromptText .. "\n\n【回應】:\n" .. aiResponse)
                    refreshWebview()
                    return
                end
            end

            local cleanErr = responseBody and string.gsub(responseBody, "['\"\n\r]", " ") or "無回應"
            if #cleanErr > 200 then cleanErr = string.sub(cleanErr, 1, 200) .. "..." end
            webview:evaluateJavaScript(string.format("alert('連線失敗！\\n狀態碼: %s\\n回傳內容: %s');", status, cleanErr))
            refreshWebview()
        end)
    end
end

function M.toggleConsole()
    if webview then webview:delete() webview = nil return end
    
    local cres = hs.screen.mainScreen():fullFrame()
    local width, height = 900, 600
    local rect = hs.geometry.rect((cres.w - width)/2, (cres.h - height)/2, width, height)
    
    local userContentController = hs.webview.usercontent.new("geminiSystemBridge"):setCallback(handleWebActions)
    webview = hs.webview.new(rect, { developerExtrasEnabled = true, ignoreCache = true }, userContentController)
    webview:windowStyle(hs.webview.windowMasks.titled | hs.webview.windowMasks.closable | hs.webview.windowMasks.resizable)
    webview:windowTitle("Hammerspoon AI 工作台")
    webview:level(hs.drawing.windowLevels.normal)
    
    refreshWebview()
    webview:show()
    hs.focus()
end

return M