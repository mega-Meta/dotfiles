-- ==============================================================================
-- CotEditor 一鍵安全開新檔 (強制前台操作版 - 100% 避免舊檔被取代)
-- ==============================================================================

hs.hotkey.bind({ "alt", "cmd"}, "M", function()
    -- 1. 率先出手：強制將 CotEditor 叫到全系統最前台（奪取 Safari 的焦點）
    -- 這樣就能徹底破除 Safari 對剪貼簿與系統時序的鎖定
    hs.application.launchOrFocus("CotEditor")
    
    -- 2. 給予系統 0.25 秒的微小反應時間，確保 CotEditor 視窗已經完全就位並聚焦
    hs.timer.doAfter(0.25, function()
        
        -- 3. 取得目前最前方的應用程式，確認是 CotEditor 沒錯
        local app = hs.application.frontmostApplication()
        if app and app:name() == "CotEditor" then
            
            -- 4. 【黃金安全防線】由系統級別幫您按下 Cmd + N (開新檔)
            -- 這保證接下來的所有貼上動作，都只會發生在這張剛出生的 Untitled 白紙上！
            hs.eventtap.keyStroke({"cmd"}, "n", 0)
            
            -- 5. 再等待 0.1 秒讓空白新視窗完全彈出
            hs.timer.doAfter(0.1, function()
                -- 6. 最後按下 Cmd + V (貼上剪貼簿內容)
                hs.eventtap.keyStroke({"cmd"}, "v", 0)
                hs.alert.show("📝 成功安全建立未命名新檔！", 1)
            end)
            
        else
            hs.alert.show("⚠️ 視窗聚焦失敗，請再試一次", 2)
        end
    end)
end)

-- 重新宣告快捷鍵就緒
--hs.alert.show("🛡️ (Opt+Cmd+M)開啟coteditor", 1.5)