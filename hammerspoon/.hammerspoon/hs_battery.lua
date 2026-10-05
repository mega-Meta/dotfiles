-- 將監聽器變數設為全域（Global），防止被系統自動回收
batteryWatcher = nil 
sleepWatcher = nil
batteryTimer = nil  -- 新增：定時器全域變數

local lowBatteryAlertTriggered = false
local highBatteryActionTriggered = false
local unpersistActionTriggered = false 

---------------------------------------------------------
-- 🛡️ 防呆機制：檢查 init.lua 是否有設定全域變數，若無則套用預設值
---------------------------------------------------------
local lowBatteryPercentage = lowBatteryPercentage or 30
local topBatteryPercentage = topBatteryPercentage or 85

print(string.format("🔋 電池守護者參數設定 -> 低電量警告: %d%%, 充電上限: %d%%", lowBatteryPercentage, topBatteryPercentage))

---------------------------------------------------------
-- 🔍 自動偵測 bclm 的實際檔案路徑
---------------------------------------------------------
local function getBcalmPath()
    local possiblePaths = {
        "/usr/local/bin/bclm",  
        "/opt/homebrew/bin/bclm" 
    }
    for _, path in ipairs(possiblePaths) do
        if hs.fs.attributes(path) then return path end
    end
    return nil
end

local bclmPath = getBcalmPath()

if not bclmPath then
    hs.dialog.alert(100, 100, function() end, 
        "⚠️ 找不到 bclm 工具", 
        "Hammerspoon 無法在預設路徑中找到 bclm，自動停止充電功能將無法運作。", 
        "我知道了", nil, "critical")
else
    print("🔋 電池守護者：成功偵測到 bclm 路徑為 -> " .. bclmPath)
end

---------------------------------------------------------
-- ⚡ 核心充電控制函式
---------------------------------------------------------
local function enforceBatteryLimits()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage then return end

    -- 狀況 A：低於設定值 且沒在充電 -> 播放警示音 + 彈窗警告
    if percentage < lowBatteryPercentage and not isCharging then
        if not lowBatteryAlertTriggered then
            local sound = hs.sound.getByName("Sosumi")
            if sound then sound:play() end

            hs.dialog.alert(100, 100, function() end, 
                "🔋 電量過低！", 
                "目前電量已降至 " .. string.format("%.0f", percentage) .. "%。請盡快接上電源。", 
                "確定", nil, "warning")
            lowBatteryAlertTriggered = true
        end
    else
        if percentage >= lowBatteryPercentage or isCharging then
            lowBatteryAlertTriggered = false
        end
    end

    -- 狀況 B：高於設定值 且正接上電源 -> 停止系統充電
    if percentage >= topBatteryPercentage and powerSource == "AC Power" and bclmPath then
        if not highBatteryActionTriggered then
            hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)
                if exitCode == 0 then
                    hs.notify.new({
                        title="🔋 電池守護者", 
                        informativeText="電量已達 " .. string.format("%.0f", percentage) .. "%，已自動鎖定充電上限至 " .. topBatteryPercentage .. "%。"
                    }):send()
                    unpersistActionTriggered = false 
                else
                    print("BCLM 錯誤: " .. (stdErr or "未知原因"))
                end
            end, {bclmPath, "write", tostring(topBatteryPercentage)}):start()

            highBatteryActionTriggered = true
        end
    else
        if percentage < topBatteryPercentage then
            highBatteryActionTriggered = false
        end
    end

    -- 狀況 C：拔掉電源（使用電池） -> 強制回復預設 100% 充電設定
    if powerSource == "Battery Power" and bclmPath then
        if not unpersistActionTriggered then
            hs.task.new("/usr/bin/sudo", function(exitCode, stdOut, stdErr)
                if exitCode == 0 then
                    print("🔋 電池守護者：已拔除電源，SMC 充電限制已重設回 100%。")
                    unpersistActionTriggered = true
                    highBatteryActionTriggered = false 
                else
                    print("BCLM 重設錯誤: " .. (stdErr or "未知原因"))
                end
            end, {bclmPath, "write", "100"}):start()
        end
    end
end

---------------------------------------------------------
-- 🕒 監聽器 1：常態電池狀態監聽
---------------------------------------------------------
batteryWatcher = hs.battery.watcher.new(enforceBatteryLimits)
batteryWatcher:start()

---------------------------------------------------------
-- 💤 監聽器 2：防止休眠偷充電的防禦機制
---------------------------------------------------------
sleepWatcher = hs.caffeinate.watcher.new(function(eventType)
    local powerSource = hs.battery.powerSource()
    
    if eventType == hs.caffeinate.watcher.systemWillSleep then
        if powerSource == "AC Power" and bclmPath then
            print("💤 系統即將休眠，強制鎖定 BCLM 為 " .. topBatteryPercentage .. "%...")
            hs.task.new("/usr/bin/sudo", nil, {bclmPath, "write", tostring(topBatteryPercentage)}):start()
        end
        
    elseif eventType == hs.caffeinate.watcher.systemDidWake or 
           eventType == hs.caffeinate.watcher.screensDidWake then
        print("☀️ 系統已喚醒，重新檢查電池狀態並修正限制...")
        highBatteryActionTriggered = false
        unpersistActionTriggered = false
        enforceBatteryLimits()
    end
end)
sleepWatcher:start()

---------------------------------------------------------
-- 🔄 🚀 新增防線 3：每 60 秒主動巡邏檢查，防止錯過跳字點
---------------------------------------------------------
batteryTimer = hs.timer.doEvery(60, function()
    local percentage = hs.battery.percentage()
    local powerSource = hs.battery.powerSource()

    -- 如果插著電且電量已經超過上限，但高電量旗標卻沒被觸發（說明剛才漏掉了）
    -- 或者防止系統自己在背景把暫存器洗回 100
    if percentage and percentage >= topBatteryPercentage and powerSource == "AC Power" then
        -- 解開開關，強制重新執行一次執法，把 100 壓回設定值
        highBatteryActionTriggered = false 
        enforceBatteryLimits()
    end
end)

-- 啟動提示
hs.notify.new({title="Hammerspoon", informativeText="終極電池守護模組（含定時巡邏）已成功啟動！"}):send()
