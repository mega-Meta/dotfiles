-- 定義只在 YouTube 網頁（Chrome / Safari / Edge）啟用這些快捷鍵
-- 如果你使用其他瀏覽器，可以在下方的陣列中自由新增
local browserApps = {
    ["Google Chrome"] = true,
    ["Safari"] = true,
    ["Microsoft Edge"] = true,
    ["Brave Browser"] = true
}

-- 檢查目前是否在瀏覽器的 YouTube 頁面
local function isYouTube()
    local app = hs.application.frontmostApplication()
    if not app or not browserApps[app:title()] then return false end
    
    -- 取得視窗標題，檢查有沒有包含 YouTube
    local win = app:focusedWindow()
    if win and string.find(win:title(), "YouTube") then
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- 功能 1：雙擊 fn 鍵回到 YouTube 首頁
-------------------------------------------------------------------------------
local lastFnTime = 0
local doubleClickDelay = 0.3 -- 雙擊的時間判定間隔（秒）

local fnTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
    -- 偵測是否為控制鍵改變，且只有 fn 鍵被按下 (flags 內只有 fn)
    local flags = event:getFlags()
    if flags.fn and not (flags.cmd or flags.alt or flags.shift or flags.ctrl) then
        local currentTime = hs.timer.secondsSinceEpoch()
        if (currentTime - lastFnTime) < doubleClickDelay then
            -- 觸發雙擊
            if isYouTube() then
                -- 模擬按下 Alt+Left 再輸入網址，或是直接用網址導向（最保險做法：觸發瀏覽器網址列或用快速鍵）
                -- 這裡用最直接的：發送瀏覽器內「回到首頁」的常用方法，或者按「g」再按「h」（YouTube官方的 Go Home 快捷鍵）
                hs.eventtap.keyStroke({}, "g", 0)
                hs.timer.doAfter(0.05, function()
                    hs.eventtap.keyStroke({}, "h", 0)
                end)
            end
            lastFnTime = 0 -- 重置
        else
            lastFnTime = currentTime
        end
    end
    return false
end):start()

-------------------------------------------------------------------------------
-- 功能 2：fn + 方向鍵 映射
-------------------------------------------------------------------------------
local arrowTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()
    
    -- 必須同時按下 fn，且目前在 YouTube 網頁
    if flags.fn and isYouTube() then
        
        -- fn + 向右鍵 (Keycode 124) -> tab
        if keyCode == 124 then
            hs.eventtap.keyStroke({}, "tab", 0)
            return true -- 攔截原按鍵
            
        -- fn + 向左鍵 (Keycode 123) -> shift + tab
        elseif keyCode == 123 then
            hs.eventtap.keyStroke({"shift"}, "tab", 0)
            return true
            
        -- fn + 向下鍵 (Keycode 125) -> 進入全螢幕播放 (f)
        elseif keyCode == 125 then
            hs.eventtap.keyStroke({}, "f", 0)
            return true
            
        -- fn + 向上鍵 (Keycode 126) -> 退出全螢幕回到一般播放 (escape)
        elseif keyCode == 126 then
            hs.eventtap.keyStroke({}, "escape", 0)
            return true
        end
    end
    return false -- 不符合條件時，放行原本的按鍵動作
end):start()

-- 提示載入成功
hs.alert.show("YouTube Hammerspoon 快捷鍵已啟用 📺")

