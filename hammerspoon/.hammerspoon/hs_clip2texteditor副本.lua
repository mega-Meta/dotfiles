-- ==============================================================================
-- TextEdit 一鍵安全開新檔 (實體隔離完美相容版 - 100% 避免舊檔被取代)
-- ==============================================================================

hs.hotkey.bind({ "alt", "cmd"}, "K", function()
    -- 1. [無損脫殼機制] 率先讀取剪貼簿文字
    local clipboardText = hs.pasteboard.getContents()
    
    if not clipboardText or clipboardText == "" then
        hs.alert.show("⚠️ 偵測失敗：目前剪貼簿內沒有文字內容", 2)
        return
    end

    -- 2. 獲取當下的精準時間戳記，在系統暫存區建立一個絕對唯一的全新檔案
    -- 這個檔案在硬碟上是獨立存在的，絕對不會與您已開啟的舊檔案產生任何關聯
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local tempFilePath = "/tmp/TextEdit_Note_" .. timestamp .. ".txt"

    -- 3. 將剪貼簿內容安全地寫入這個新建立的臨時檔
    local file = io.open(tempFilePath, "w")
    if file then
        file:write(clipboardText)
        file:close()
        
        -- 4. 【核心指令】：使用 macOS 原生最高權限的 open -e 
        -- 參數 -e 會強制系統「直接用文字編輯 (TextEdit) 開啟此新路徑」
        -- 因為路徑是全新的，Mac 100% 必定只會為它開出獨立新視窗，Safari 的焦點也絕對無法攔截！
        hs.task.new("/usr/bin/open", function(exitCode, stdOut, stdErr)
            if exitCode == 0 then
                hs.alert.show("🍏 已成功用 TextEdit 安全建立獨立新檔案！", 1.5)
            else
                hs.alert.show("❌ 執行失敗: " .. (stdErr or "未知錯誤"), 2)
            end
        end, {"-e", tempFilePath}):start() -- 將 -e 與新檔案路徑作為參數傳入
    else
        hs.alert.show("❌ 系統建立暫存檔失敗", 2)
    end
end)

-- 重新宣告快捷鍵就緒
hs.alert.show("🛡️ TextEdit 安全隔離流已就位 (Opt+Cmd+K)", 1.5)
