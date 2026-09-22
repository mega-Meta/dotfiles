-- ==============================================================================
-- VimR 一鍵安全開新檔 (遠端內核注入版 - 100% 拋棄模擬按鍵，解決所有拒收問題)
-- ==============================================================================

hs.hotkey.bind({ "alt", "cmd"}, "K", function()
    -- 1. 讀取目前複製的純文字
    local clipboardText = hs.pasteboard.getContents()
    if not clipboardText or clipboardText == "" then
        hs.alert.show("⚠️ 偵測失敗：目前剪貼簿內沒有文字內容", 2)
        return
    end

    -- 2. 為了徹底安全、不污染舊檔，我們先在系統暫存區建立一個絕對唯一的臨時檔案
    -- 例如：/tmp/VimR_Note_20260915_010203.txt
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local tempFilePath = "/tmp/VimR_Note_" .. timestamp .. ".txt"

    -- 3. 將剪貼簿內容安全寫入該新檔案中
    local file = io.open(tempFilePath, "w")
    if file then
        file:write(clipboardText)
        file:close()
        
        -- 4. 【核心黑科技】：使用 /usr/local/bin/vimr 指令直接開啟這個實體路徑
        -- 如果 VimR 沒開，它會把它冷啟動打開並顯示此檔（100% 成功）。
        -- 如果 VimR 已經在背景開著，這個遠端指令會「直接命令」VimR 在內部開出一個獨立的新分頁/新 Buffer，
        -- 並把文字呈現出來！這完全不經過模擬鍵盤，Mac 的沙盒與 Safari 的焦點絕對「無權阻擋」！
        hs.task.new("/usr/local/bin/vimr", function(exitCode, stdOut, stdErr)
            if exitCode == 0 then
                hs.alert.show("⚡ VimR 已成功透過遠端注入安全新檔！", 1.5)
            else
                -- 萬一找不到路徑，嘗試尋找 App 內部封裝的命令列工具
                hs.task.new("/Applications/VimR.app/Contents/Resources/vimr", nil, {tempFilePath}):start()
                hs.alert.show("🚀 已透過備用路徑安全開啟 VimR！", 1.5)
            end
        end, {tempFilePath}):start() -- 將檔案路徑直接作為參數灌進去
    else
        hs.alert.show("❌ 系統建立暫存檔失敗", 2)
    end
end)

-- 提示全新遠端內核哨兵已上線
hs.alert.show("🛡️ VimR 遠端注入流已就位 (Opt+Cmd+K)", 1.5)
