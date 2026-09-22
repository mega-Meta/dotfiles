-- ==============================================================================
-- 方案 B：VimR 一鍵安全開新檔貼上 (安全開新 Buffer/分頁)
-- ==============================================================================
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "C", function()
    local clipboardText = hs.pasteboard.getContents()
    if not clipboardText or clipboardText == "" then
        hs.alert.show("⚠️ 剪貼簿內沒有文字內容", 2)
        return
    end

    -- 呼叫 VimR 執行。參數 "-" 代表從管道安全接收純文字，100% 獨立，絕不影響舊緩衝區
    -- (若您的 vimr 安裝在其他路徑，可改為 /Applications/VimR.app/Contents/Resources/vimr)
    local vimrTask = hs.task.new("/usr/local/bin/vimr", function(exitCode, stdOut, stdErr)
        if exitCode == 0 then
            hs.alert.show("⚡ 已用 VimR 安全開新 Buffer！", 1)
        else
            -- 萬一找不到 /usr/local/bin/vimr，嘗試改呼叫 App 套件內建的路徑
            hs.task.new("/Applications/VimR.app/Contents/Resources/vimr", nil, {"-"}):setInput(clipboardText):start()
        end
    end, {"-"})
    
    vimrTask:setInput(clipboardText)
    vimrTask:start()
end)
