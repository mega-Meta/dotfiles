-- 將監聽器變數設為全域（Global），防止被系統自動回收
batteryWatcher = nil 
sleepWatcher = nil
batteryTimer = nil  

local lowBatteryAlertTriggered = false
-- 💡 新增：追蹤上一次真正成功寫入硬體的值
local lastWrittenValue = nil 

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
end

---------------------------------------------------------
-- ⚙️ 封裝：智慧型 bclm 寫入函式（即時讀取硬體值比對，防重複寫入）
---------------------------------------------------------
local function writeBclmValue(targetValue, reason)
    if not bclmPath then return end
    
    -- 🔍 第一步：先非同步讀取目前 SMC 硬體內真正的限制值（免 sudo，速度極快）
    hs.task.new(bclmPath, function(readExitCode, readStdOut, readStdErr)
        if readExitCode == 0 and readStdOut then
            -- 清除多餘的換行與空白，取得乾淨的硬體現值
            local currentHardwareValue = string.gsub(readStdOut, "%s+", "")
            
            -- 💡 第二步：即時智慧比對！
            -- 如果目前硬體值已經等於目標值，直接攔截不重寫，避免重複點火
            if currentHardwareValue == tostring(targetValue) then
                -- print(string.format("ℹ️ 電池守護者 [%s]：硬體值已是 %s%%，無需重複寫入。", reason, targetValue))
                return 
            end
            
            -- 💡 第三步：數值有異動，才真正發動寫入
            hs.task.new("/usr/bin/sudo", function(writeExitCode, writeStdOut, writeStdErr)
                if writeExitCode == 0 then
                    print(string.format("🔋 電池守護者 [%s]：偵測到異動（原為 %s%%），已成功將硬體充電限制修改為 %s%%。", reason, currentHardwareValue, targetValue))
                else
                    print("BCLM 寫入錯誤: " .. (writeStdErr or "未知原因"))
                end
            end, {bclmPath, "write", tostring(targetValue)}):start()
        else
            print("BCLM 讀取錯誤: " .. (readStdErr or "未知原因"))
        end
    end, {"read"}):start()
end


---------------------------------------------------------
-- ⚡ 核心充電控制邏輯
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

    -- 狀況 B：【提早 10% 預警防禦】與狀況 C（拔電恢復 100%）
    local earlyTriggerPercentage = topBatteryPercentage - 10
    if percentage >= earlyTriggerPercentage and powerSource == "AC Power" then
        writeBclmValue(topBatteryPercentage, "電量達預警區")
    --elseif powerSource == "Battery Power" then
    --    writeBclmValue(100, "拔除電源線")
    end
end

---------------------------------------------------------
-- 🕒 監聽器啟動
---------------------------------------------------------
batteryWatcher = hs.battery.watcher.new(enforceBatteryLimits)
batteryWatcher:start()

sleepWatcher = hs.caffeinate.watcher.new(function(eventType)
    local powerSource = hs.battery.powerSource()
    if eventType == hs.caffeinate.watcher.systemWillSleep then
        if powerSource == "AC Power" then
            lastWrittenValue = nil -- 休眠前清除緩存，強制允許寫入一次
            writeBclmValue(topBatteryPercentage, "系統即將休眠")
        end
    elseif eventType == hs.caffeinate.watcher.systemDidWake or eventType == hs.caffeinate.watcher.screensDidWake then
        lastWrittenValue = nil -- 喚醒時清除緩存，強制重新檢查
        enforceBatteryLimits()
    end
end)
sleepWatcher:start()

---------------------------------------------------------
-- 🔄 🚀【智慧型 60 秒定時巡邏：先讀再寫，雙重保險】
---------------------------------------------------------
batteryTimer = hs.timer.doEvery(60, function()
    local percentage = hs.battery.percentage()
    local isCharging = hs.battery.isCharging()
    local powerSource = hs.battery.powerSource()

    if not percentage or not bclmPath then return end

    if percentage >= (topBatteryPercentage - 10) and powerSource == "AC Power" then
        
        -- 🔍 第一步：先執行 bclm read 讀取目前的實際硬體值
        hs.task.new(bclmPath, function(exitCode, stdOut, stdErr)
            if exitCode == 0 and stdOut then
                local currentHardwareValue = string.gsub(stdOut, "%s+", "")
                
                -- 🔍 第二步：智慧比對！如果發現硬體值跟設定的上限不同
                if currentHardwareValue ~= tostring(topBatteryPercentage) then
                    print(string.format("⚠️ 偵測到硬體值異動！目前為 %s%%，與設定值 %d%% 不符，發動修正...", currentHardwareValue, topBatteryPercentage))
                    lastWrittenValue = nil -- 清除鎖，允許定時器修正
                    writeBclmValue(topBatteryPercentage, "定時巡邏修正")
                end
            end
        end, {"read"}):start()
        
        -- 🚨【硬體晶片卡死完全捕獲】高於目標值 3% 且持續顯示正在充電
        if percentage >= (topBatteryPercentage + 3) and isCharging then
            local sound = hs.sound.getByName("Blow")
            if sound then sound:play() end
            hs.speech.new():speak("電池已超出限制，請重新插拔電源線")
            hs.dialog.alert(100, 100, function() end, 
                "🚨 SMC 硬體充電卡死！", 
                "目前已達 " .. string.format("%.0f", percentage) .. "%（上限為 " .. topBatteryPercentage .. "%）。\n\n硬體暫存器值雖正確，但晶片卡死，請【拔掉 Mac 電源線，等待3秒再插回】強制重設硬體狀態！", 
                "我知道了", nil, "critical")
        end
    end
end)

---------------------------------------------------------
-- 🚀【一開機/重載配置立刻首次初始化檢查】
---------------------------------------------------------
local initialPowerSource = hs.battery.powerSource()
local initialPercentage = hs.battery.percentage()
if initialPowerSource == "AC Power" and initialPercentage and initialPercentage >= (topBatteryPercentage - 10) then
    writeBclmValue(topBatteryPercentage, "開機初始化鎖定")
end

-- 啟動提示
hs.notify.new({title="Hammerspoon", informativeText="電池智慧守護模組已成功啟動！"}):send()
