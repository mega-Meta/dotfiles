-- ========================================================
-- 1. 基礎快捷鍵：手動重載設定 (⌥ + ⌘ + C)
-- ========================================================
hs.hotkey.bind({"cmd", "alt"}, "C", function()
    hs.alert.show("手動重載設定中...")
    hs.timer.doAfter(0.2, function()
        hs.reload()
    end)
end)

-- ========================================================
-- 2. 進階功能：儲存檔案時自動重載 (Auto Reload)
-- ========================================================
function reloadConfig(files)
    local doReload = false
    for _, file in ipairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
            break
        end
    end
    if doReload then
        hs.timer.doAfter(0.2, function()
            hs.reload()
        end)
    end
end

-- 安全建立路徑監聽器
local configDir = hs.configdir .. "/"
myWatcher = hs.pathwatcher.new(configDir, reloadConfig)

-- 防呆檢查：確認物件成功建立才執行 start
if myWatcher then
    myWatcher:start()
else
    print("Hammerspoon 提示：路徑監聽器建立失敗")
end

-- ========================================================
-- 3. 選單列圖示與初始化通知
-- ========================================================
if hs.openConsoleOnLaunch then
    hs.settings.set("_showMenu", true)
end

hs.alert.show("Hammerspoon 已完全重整成功！🛠️")