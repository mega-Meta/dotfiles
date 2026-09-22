-- ========================================================================
-- 自動關閉 Shottr 購買提示 (視窗相對坐標・物理穿透雙擊版)
-- ========================================================================

-- 使用你本機已證實 100% 抓得到 Shottr 的應用程式監聽器
shottrWatcher = hs.application.watcher.new(function(appName, eventType, appObj)
    -- 當系統日誌跳出 Shottr 被活化或在背景觸發時
    if appObj and appObj:bundleID() == "cc.ffitch.shottr" and eventType == hs.application.watcher.activated then
        
        -- 給予 0.25 秒讓那個 Purchase Overlay 完全畫在螢幕上
        hs.timer.doAfter(0.25, function()
            -- 1. 直接用 BundleID 抓出 Shottr 所有的實體視窗物件 (無視焦點限制)
            local windows = appObj:allWindows()
            for _, win in ipairs(windows) do
                
                -- 2. 精準鎖定購買面板的標題
                if win and win:title() == "Purchase shottr" and win:isVisible() then
                    print("[Shottr] 成功鎖定目標，開始執行相對坐標穿透點擊...")
                    
                    local topLeft = win:topLeft()
                    
                    -- 💡 終極坐標修正：依據原廠 680x512 尺寸，"Maybe Later" 按鈕的絕對正中心點
                    -- 正好位於視窗左上角向右平移 340 像素，向下平移 335 像素的位置！
                    local clickX = topLeft.x + 340
                    local clickY = topLeft.y + 335
                    
                    -- 備份你當前的滑鼠，點擊完瞬間歸位，完全無感
                    local currentMousePos = hs.mouse.absolutePosition()
                    
                    -- 💡 物理穿透：發送極速左鍵點擊，確保穿透安全機制
                    hs.eventtap.leftClick({x = clickX, y = clickY})
                    
                    -- 瞬間物歸原主
                    hs.mouse.absolutePosition(currentMousePos)
                    break
                end
            end
        end)
    end
end):start()
