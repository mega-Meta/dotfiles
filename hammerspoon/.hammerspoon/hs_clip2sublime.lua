-- ==============================================================================
-- Sublime Text 一鍵安全開新檔 (強制前台操作版 - 100% 避免舊檔被取代)
-- ==============================================================================
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "C", function()
    -- 1. 強制將 Sublime Text 叫到全系統最前台（通常識別名稱為 Sublime Text 或 Sublime Text 3/4）
    hs.application.launchOrFocus("Sublime Text")
    
    -- 2. 等待 0.25 秒確保視窗就位
    hs.timer.doAfter(0.25, function()
        local app = hs.application.frontmostApplication()
        if app and (app:name():match("Sublime") or app:title():match("Sublime")) then
            -- 3. 強制按下 Cmd + N 建立全新未命名 Tab（安全防線）
            hs.eventtap.keyStroke({"cmd"}, "n", 0)
            
            -- 4. 等待 0.1 秒後按下 Cmd + V 貼上
            hs.timer.doAfter(0.1, function()
                hs.eventtap.keyStroke({"cmd"}, "v", 0)
                hs.alert.show("🧡 已成功在 Sublime Text 建立新分頁！", 1)
            end)
        else
            hs.alert.show("⚠️ Sublime Text 視窗聚焦失敗", 2)
        end
    end)
end)
