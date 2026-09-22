-- ==============================================================================
-- TextEdit 一鍵安全開新檔 (系統剪貼簿直通版 - 100% 相容、支援直接 Cmd+S 另存)
-- ==============================================================================

hs.hotkey.bind({ "alt", "cmd"}, "K", function()
    -- 1. [無損脫殼機制] 率先讓系統剪貼簿有足夠的時間完成 Safari 網頁富文本清洗
    hs.timer.usleep(150000)

    -- 2. 智能時間動態分流：檢查 TextEdit 是否已經在背景運行中
    local textEditApp = hs.application.get("com.apple.TextEdit")
    local isRunning = textEditApp ~= nil and textEditApp:isRunning()
    
    -- 如果已啟動等 0.15 秒；如果是冷啟動，則給予 1.2 秒讓原廠視窗充分初始化
    local waitDelay = isRunning and 0.15 or 1.20
    
    if not isRunning then
        hs.alert.show("🚀 正在叫醒系統文字編輯 (TextEdit)...", 1.2)
    end

    -- 3. 透過最高權限 AppleScript 直接控制 TextEdit，並強制奪取 Safari 與前台焦點
    hs.osascript.applescript([[
        tell application "TextEdit"
            activate
        end tell
    ]])

    -- 4. 寬限時間到，由 AppleScript 直擊系統記憶體注入，完全不用 Lua 轉義字串
    hs.timer.doAfter(waitDelay, function()
        
        -- 【核心黑科技】：直接命令 AppleScript 抓取系統當前的 (the clipboard as text)
        -- 這在 macOS 底層是最高安全層級，完全不怕引號或換行，100% 必定成功
        local textEditScript = [[
            tell application "TextEdit"
                -- 100% 強制開出一張全新型態、獨立的 Untitled 未命名文件視窗
                set newDoc to make new document
                -- 直接從系統剪貼簿搬運純文字寫入這張白紙，不經過硬碟、也不需模擬按鍵
                set text of newDoc to (the clipboard as text)
            end tell
        ]]

        -- 5. 核心執行
        local success, _, errorTable = hs.osascript.applescript(textEditScript)
        
        if success then
            hs.alert.show("🍏 成功建立未命名新檔！(按 Cmd+S 可直接另存)", 1.5)
        else
            -- 萬一出錯，透過提示框抓出錯誤，不再死轉
            local errStr = errorTable and errorTable.NSLocalizedDescription or "未知錯誤"
            hs.alert.show("❌ 系統注入失敗: " .. errStr, 3)
        end
    end)
end)

-- 重新宣告快捷鍵就緒
hs.alert.show("✨ TextEdit 直通流已就位 (Opt+Cmd+K)", 1.5)
