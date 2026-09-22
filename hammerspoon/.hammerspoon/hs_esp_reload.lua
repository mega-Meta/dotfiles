-- ==============================================================================
-- Hammerspoon & Espanso 雙向連動重載腳本 (Hammerspoon 端)
-- ==============================================================================

-- 定義一個全域的雙重重載函式
function reloadBothServices()
    hs.alert.show("⚡ 開始連動重載：Hammerspoon & Espanso...", 1.5)
    
    -- 1. 執行 Hammerspoon 自我重載 (注意：hs.reload() 會讓後續的 Lua 程式碼中斷，所以先呼叫外部指令)
    -- 我們透過 hs.task 呼叫終端機的 espanso restart 指令
    hs.task.new("/opt/homebrew/bin/espanso", function(exitCode, stdOut, stdErr)
        if exitCode == 0 then
            hs.printf("Espanso 重啟成功")
        else
            -- 如果預設路徑找不到，嘗試丟給通用環境變數執行
            hs.execute("espanso restart")
        end
    end, {"restart"}):start()

    -- 2. 延遲 0.5 秒後，執行 Hammerspoon 的自我重載，避免兩者同時卡住 I/O
    hs.timer.doAfter(0.5, function()
        hs.reload()
    end)
end

-- 綁定快捷鍵：按下 Ctrl + Cmd + Option + Shift + R 觸發
-- (您可以修改 {"ctrl", "cmd", "alt", "shift"} 為您喜歡的組合，例如 {"cmd", "alt", "r"})
hs.hotkey.bind({"ctrl", "cmd", "alt", "shift"}, "R", function()
    reloadBothServices()
end)

-- 當 Hammerspoon 重載成功完成時，在螢幕畫面上跳出漂亮的提示
hs.alert.show("✨ Hammerspoon 與 Espanso 連動配置載入成功！", 2)
