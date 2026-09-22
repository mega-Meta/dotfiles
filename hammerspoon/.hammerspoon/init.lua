-- init.lua
-- For JIS keyboard IME Switcher & Shottr Premium Full Integration

-- ==============================================================================
-- 匯入外部延展區塊,若有相同設定,則會由後載入取代
-- 已調教完成的延展scripts,請參考以下連結:
-- https://github.com/mega-Meta/macos-jis-hammerspoon/tree/original-version
-- ==============================================================================
--require("fn_youtube") --已預含於section9不需再載入
--require("hs_clip2texteditor") --使用MACOS內建texteditor (使用熱鍵 cmd+opt+K) 已預含於section8不需再載入
--require("hs_clip2vimr")  --使用需先安裝VIMR (使用熱鍵 cmd+opt+K)
--require("auto_reload")  --測試script時開啟，程式異動時會自動執行hammerspoon reload config
--require("hs_esp_reload") -- 使用需先安裝espanso,自定snippets
--require("hs_clip2coteditor") --使用需先安裝coteditor(使用熱鍵 cmd+opt+M)
--local spoonsMgr = require("hs_spoonsmgr")
--require("text_conversion")
--hs.loadSpoon("Commander")

-- ==============================================================================
-- 終極完美簡易版 init.lua (第一部分：核心基礎、變數與純手動輸入法切換)
-- ==============================================================================

local DEBUG_FLAG = false  -- 偵錯開關，關閉為 false
local EISUU_KEY = 102
local KANA_KEY = 104
local LSHIFT_KEY = 56
local LCMD_KEY = 55
local RCMD_KEY = 54
local LALT_KEY = 58
local RALT_KEY = 61
local YEN_KEY = 93
local RFN_KEY = 179
local DOUBLE_CLICK_TIMER = 0.35 -- 0.35 秒黃金判定時間，讓所有雙擊操作更輕鬆
local ABC_IME_ID = "com.apple.keylayout.ABC"
local CLICK_IME_ID = "com.apple.inputmethod.TCIM.Cangjie" -- 預設切換倉頡
--local CLICK_IME_ID = "com.apple.inputmethod.TCIM.Zhuyin" --#繁體倚天注音

local FIXED_SNIPPETS = {
	{ title = "📧 我的電子郵件", text = "myemailk@gmail.com" },
	{ title = "🏢 公司統一編號", text = "12345678" },
	{ title = "📍 常用寄件地址", text = "台北市信義區信義路五段7號" },
	{ title = "✍️ 常用客套回覆", text = "收到，感謝您的協助！我會盡快確認後回覆您。" },
	{ title = "⭐️常用symbols", text = "✓✗♡⍺⍬⍵⭐️💡👍🍏⚡️🚀🔐🌐🔍️✈️📌"},
	{ title = "⭐️常用face", text = "😀😇🥰😍😜🫠😅😂🫥😶‍🌫️😴"},
	{ title = "MACOS", text = "⌘⇧⌃⌥⌥←→↑↓⇪⎋⏏↵⌅⇥⇤⇞⇟↖↘␣⌫⌦"},
}

local COOLDOWN_TIME = 0.1
local lastTriggerTime = 0

-- -----------------------------------------------------------------------------
-- 自製剪貼簿查詢功能，雙擊"英數鍵"
-- -----------------------------------------------------------------------------
local clipboardHistory = {}
local MAX_CLIPBOARD_ITEMS = 15
local lastCount = hs.pasteboard.changeCount()

-- 剪貼簿歷史監聽器
clipboardTimer = hs.timer.doEvery(0.5, function()
	local currentCount = hs.pasteboard.changeCount()
	if currentCount ~= lastCount then
		local nowContent = hs.pasteboard.getContents()
		if nowContent and nowContent ~= "" then
			local isFixed = false
			for _, fixed in ipairs(FIXED_SNIPPETS) do
				if nowContent == fixed.text then
					isFixed = true
					break
				end
			end
			if not isFixed and nowContent ~= clipboardHistory then
				table.insert(clipboardHistory, 1, nowContent)
				if #clipboardHistory > MAX_CLIPBOARD_ITEMS then
					table.remove(clipboardHistory)
				end
			end
		end
		lastCount = currentCount
	end
end):start()

-- 剪貼簿模糊搜尋選單
local function showClipboardChooser()
	local choices = {}
	for _, fixed in ipairs(FIXED_SNIPPETS) do
		table.insert(choices, {
			text = fixed.title,
			subText = fixed.text,
			actualText = fixed.text,
		})
	end
	for i, item in ipairs(clipboardHistory) do
		local summary = string.gsub(item, "[\r\n]", " ")
		if string.len(summary) > 30 then
			summary = string.sub(summary, 1, 30) .. "..."
		end
		table.insert(choices, {
			text = string.format("[%d] 📋 %s", i, summary),
			subText = item,
			actualText = item,
		})
	end
	if #choices == 0 then
		hs.alert.show("📭 選單目前沒有內容")
		return
	end
	if myChooser then myChooser:delete() end
	myChooser = hs.chooser.new(function(choice)
		if choice then
			hs.pasteboard.setContents(choice.actualText)
			hs.timer.doAfter(0.02, function()
				hs.eventtap.keyStroke({ "cmd" }, "v", 0)
			end)
		end
	end)
	myChooser:choices(choices)
	myChooser:placeholderText("輸入關鍵字可模糊搜尋常用字或剪貼簿...")
	myChooser:show()
end

-- 模擬系統輸入法切換 (僅供雙擊使用)
local function simulateSystemImeSwitch()
	local currentTime = hs.timer.secondsSinceEpoch()
	if currentTime - lastTriggerTime < COOLDOWN_TIME then return end
	lastTriggerTime = currentTime
	hs.eventtap.keyStroke({ "ctrl" }, "space", 10000)
end

-- 基礎快捷鍵：手動重載設定 (⌥ + ⌘ + C)
hs.hotkey.bind({"cmd", "alt"}, "c", function()
    hs.timer.doAfter(0.2, function()
        hs.reload()
        --hs.alert.show("👍Hammerspoon手動重載完成。")
    end)
end)

-- -----------------------------------------------------------------------------
-- 1. かな (Kana) 鍵監聽
-- cmd+kana
-- -----------------------------------------------------------------------------
local kanaLastClickTime = 0
kanaTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()

	if keyCode == KANA_KEY then
		if flags.alt then
			hs.eventtap.keyStroke({ "cmd", "shift" }, "2", 0)
			return true
		end
		if flags.cmd then
			hs.eventtap.keyStroke({ "cmd", "shift" }, "4", 0)
			return true
		end

		local currentTime = hs.timer.secondsSinceEpoch()
		if (currentTime - kanaLastClickTime) < DOUBLE_CLICK_TIMER then
			simulateSystemImeSwitch()
			kanaLastClickTime = 0
		else
			hs.keycodes.currentSourceID(ABC_IME_ID)
			hs.timer.doAfter(0.06, function()
				hs.keycodes.currentSourceID(CLICK_IME_ID)
			end)
			kanaLastClickTime = currentTime
		end
		return true
	end
	return false
end):start()

-- -----------------------------------------------------------------------------
-- 2. 英數 (Eisuu) 鍵監聽
-- -----------------------------------------------------------------------------
local eisuuLastClickTime = 0
eisuuTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()

	if keyCode == EISUU_KEY then
		if flags.alt then
			hs.eventtap.keyStroke({ "cmd", "shift" }, "1", 0)
			return true
		end
		if flags.cmd then
			hs.eventtap.keyStroke({ "cmd", "shift" }, "3", 0)
			return true
		end

		local currentTime = hs.timer.secondsSinceEpoch()
		if (currentTime - eisuuLastClickTime) < DOUBLE_CLICK_TIMER then
			showClipboardChooser()
			eisuuLastClickTime = 0
		else
			hs.keycodes.currentSourceID(ABC_IME_ID)
			eisuuLastClickTime = currentTime
		end
		return true
	end
	return false
end):start()
-- -----------------------------------------------------------------------------
-- 3. 修飾鍵配合shottr (雙擊 left Cmd 喚出錄影、雙擊 Option 喚出 Shottr 截圖)
-- -----------------------------------------------------------------------------
local cmdClickCount = 0
local cmdClickTimer = nil
local altClickCount = 0
local altClickTimer = nil
local masks = hs.eventtap.event.rawFlagMasks

modifierTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()
	local rawflags = event:rawFlags()
	--local masks = event:rawFlagMasks

	if keyCode == LSHIFT_KEY and flags.shift and flags.cmd  then
	--if flags.shift and flags.cmd  then
		simulateSystemImeSwitch()
		return true
	end

	if keyCode == LCMD_KEY then -- or keyCode == RCMD_KEY then
		if flags.cmd and not flags.shift and not flags.ctrl and not flags.alt then
			if cmdClickTimer then cmdClickTimer:stop() end
			cmdClickCount = cmdClickCount + 1
			if cmdClickCount == 1 then
				cmdClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function() cmdClickCount = 0 end)
			elseif cmdClickCount == 2 then
				cmdClickCount = 0
				hs.eventtap.keyStroke({ "cmd", "shift" }, "5", 0)
				return true
			end
		end
	end
	-- double click right cmd-> cmd +shift + 0 = screeeshot for any selected window
	if (rawflags & masks.deviceRightCommand) ~= 0 then
		if flags.cmd and not flags.shift and not flags.ctrl and not flags.alt then
			if cmdClickTimer then cmdClickTimer:stop() end
			cmdClickCount = cmdClickCount + 1
			if cmdClickCount == 1 then
				cmdClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function() cmdClickCount = 0 end)
			elseif cmdClickCount == 2 then
				cmdClickCount = 0
				hs.eventtap.keyStroke({ "cmd", "shift" }, "0", 0)
				return true
			end
		end
	end
    
    if keyCode == LALT_KEY or keyCode == RALT_KEY then
		if flags.alt and not flags.cmd and not flags.shift and not flags.ctrl then
			if altClickTimer then altClickTimer:stop() end
			altClickCount = altClickCount + 1
			if altClickCount == 1 then
				altClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function() altClickCount = 0 end)
			elseif altClickCount == 2 then
				altClickCount = 0
				hs.eventtap.keyStroke({ "cmd", "shift" }, "8", 0)
				return true
			end
		end
	end
	return false
end):start()
-- -----------------------------------------------------------------------------
-- 4. JIS 特有實體鍵監聽 (Cmd + ¥ 重複區域截圖),配合shottr
-- -----------------------------------------------------------------------------
screenshotKeyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()
	if keyCode == YEN_KEY and flags.cmd then
		hs.eventtap.keyStroke({ "cmd", "shift" }, "7", 0)
		return true
	end
	return false
end):start()
-- -----------------------------------------------------------------------------
-- 5. App 狀態啟用監聽器
-- -----------------------------------------------------------------------------
--[[
appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
	if eventType == hs.application.watcher.activated then
		hs.timer.doAfter(0.1, function()
			if not hs.eventtap.isSecureInputEnabled() then
				if kanaTap then kanaTap:stop(); kanaTap:start() end
				if eisuuTap then eisuuTap:stop(); eisuuTap:start() end
				if modifierTap then modifierTap:stop(); modifierTap:start() end
				if screenshotKeyTap then screenshotKeyTap:stop(); screenshotKeyTap:start() end
			end
		end)
	end
end):start()
]]--
-- -----------------------------------------------------------------------------
-- 6. 每 3 秒 background 防護定時器
-- -----------------------------------------------------------------------------
--[[
secureInputTimer = hs.timer.doEvery(3, function()
	if not hs.eventtap.isSecureInputEnabled() then
		if kanaTap and not kanaTap:isEnabled() then kanaTap:start() end
		if eisuuTap and not eisuuTap:isEnabled() then eisuuTap:start() end
		if modifierTap and not modifierTap:isEnabled() then modifierTap:start() end
		if screenshotKeyTap and not screenshotKeyTap:isEnabled() then screenshotKeyTap:start() end
	end
end):start()
]]--

-- -----------------------------------------------------------------------------
-- 7. Debug 偵錯區 for hammerspoon, control by var DEBUG_FLAG
-- -----------------------------------------------------------------------------
keyLogger = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	if DEBUG_FLAG then
		local keyCode = event:getKeyCode()
		local flags = event:getFlags()
		print(string.format("Key Code: %s | Modifiers: %s", keyCode, hs.inspect(flags)))
	end
	return false
end):start()

testWatcher = hs.application.watcher.new(function(name, event, app)
   if event == hs.application.watcher.activated and app and DEBUG_FLAG then
      print("App名稱: " .. name .. " | BundleID: " .. tostring(app:bundleID()))
   end
end):start()

-- ==============================================================================
-- 8.TextEdit 一鍵安全開新檔 (系統剪貼簿直通版 - 100% 相容、支援直接 Cmd+S 另存)
-- ==============================================================================

hs.hotkey.bind({ "alt", "cmd"}, "K", function()
    -- 1. [無損脫殼機制] 率先讓系統剪貼簿有足夠的時間完成 Safari 網頁富文本清洗
    hs.timer.usleep(150000)

    -- 2. 智能時間動態分流：檢查 TextEdit 是否已經在背景運行中
    local textEditApp = hs.application.get("com.apple.TextEdit")
    local isRunning = textEditApp ~= nil and textEditApp:isRunning()
    
    -- 如果已啟動等 0.15 秒；如果是冷啟動，則給予 1.2 秒讓原廠視窗充分初始化
    local waitDelay = isRunning and 0.15 or 1.20
    
    if not isRunning then
        hs.alert.show("🚀 正在啟動系統文字編輯器 (TextEdit)...", 1.2)
    end

    -- 3. 透過最高權限 AppleScript 直接控制 TextEdit，並強制奪取 Safari 與前台焦點
    hs.osascript.applescript([[
        tell application "TextEdit"
            activate
        end tell
    ]])

    -- 4. 寬限時間到，由 AppleScript 直擊系統記憶體注入，完全不用 Lua 轉義字串
    hs.timer.doAfter(waitDelay, function()
        
        -- 【核心黑科技】：直接命令 AppleScript 抓取系統當前的 (the clipboard as text)
        -- 這在 macOS 底層是最高安全層級，完全不怕引號或換行，100% 必定成功
        local textEditScript = [[
            tell application "TextEdit"
                -- 100% 強制開出一張全新型態、獨立的 Untitled 未命名文件視窗
                set newDoc to make new document
                -- 直接從系統剪貼簿搬運純文字寫入這張白紙，不經過硬碟、也不需模擬按鍵
                set text of newDoc to (the clipboard as text)
            end tell
        ]]

        -- 5. 核心執行
        local success, _, errorTable = hs.osascript.applescript(textEditScript)
        
        if success then
            hs.alert.show("🍏 成功由剪貼簿建立新檔！(請按 Cmd+S 存檔)", 1.5)
        else
            -- 萬一出錯，透過提示框抓出錯誤，不再死轉
            local errStr = errorTable and errorTable.NSLocalizedDescription or "未知錯誤"
            hs.alert.show("❌ 系統注入失敗: " .. errStr, 3)
        end
    end)
end)
-- 重新宣告快捷鍵就緒
--hs.alert.show("✨ TextEdit (Opt+Cmd+K) 就位，可由剪貼簿建立新檔", 1.5)

-- -----------------------------------------------------------------------------
-- 9. YouTube 網頁專用熱鍵區
-- -----------------------------------------------------------------------------
local browserApps = {
	["YouTube"] = true,
    ["Google Chrome"] = true,
    ["Safari"] = true,
    ["Microsoft Edge"] = true,
    ["Brave Browser"] = true
}

local function isYouTube()
    local app = hs.application.frontmostApplication()
    if not app or not browserApps[app:title()] then return false end
    local win = app:focusedWindow()
    if win and string.find(win:title(), "YouTube") then return true end
    return false
end

-- 功能 1：雙擊 fn 鍵回到 YouTube 首頁
local lastFnTime = 0
fnTap = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.flagsChanged}, function(event)
    local keyCode = event:getKeyCode()
    if keyCode == RFN_KEY then
        local currentTime = hs.timer.secondsSinceEpoch()
        if (currentTime - lastFnTime) > 0.05 then
            if (currentTime - lastFnTime) < (DOUBLE_CLICK_TIMER + 0.10) then
                if isYouTube() then
                    hs.eventtap.keyStroke({}, "g", 0)
                    hs.timer.doAfter(0.05, function()
                        hs.eventtap.keyStroke({"cmd", "shift"}, "h", 0)
                    end)
                    --hs.alert.show("📺 已自動返回 YouTube 首頁")
                end
                lastFnTime = 0
                return true
            else
                lastFnTime = currentTime
            end
        end
    end
    return false
end):start()

-- 功能 2：fn + 方向鍵 映射
arrowTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local keyCode = event:getKeyCode()
    
    -- 【核心防禦】：179 綠色通道放行
    if keyCode == RFN_KEY then return false end
    
    if isYouTube() then    
        -- fn + 向下鍵 = PageDown (121) -> 進入全螢幕播放 (f)
        if keyCode == 121 or keyCode == 125 then
            hs.eventtap.keyStroke({}, "f", 0)
            return true
            
        -- fn + 向上鍵 = PageUp (116) -> 退出全螢幕回到一般播放 (escape)
        elseif keyCode == 116 or keyCode == 126 then
            hs.eventtap.keyStroke({}, "escape", 0)
            return true
            
        -- fn + 向右鍵 (Keycode 124) -> 映射為小寫 j (YouTube 原生下一部影片)
        elseif keyCode == 124 then
            --hs.eventtap.keyStroke({}, "j", 0)
            hs.eventtap.keyStroke({}, "f", 0)
            return true
            
        -- fn + 向左鍵 (Keycode 123) -> 映射為小寫 k (YouTube 原生上一部影片)
        elseif keyCode == 123 then
            --hs.eventtap.keyStroke({}, "k", 0)
            hs.eventtap.keyStroke({}, "escape", 0)
            return true
        end
    end
    return false
end):start()

-- -----------------------------------------------------------------------------
-- macOS「服務」文字轉換熱鍵
-- 先在「系統設定 → 鍵盤 → 鍵盤快速鍵 → 服務 → 文字」啓用下列服務：
--   將文字轉換為繁體中文（⌃⇧⌘C）
--   將文字轉換為簡體中文（⌃⌥⇧⌘C）
-- -----------------------------------------------------------------------------
hs.hotkey.bind({ "ctrl", "shift" }, "T", function()
  hs.eventtap.keyStroke({ "cmd" }, "a", 0)
  hs.timer.doAfter(0.05, function()
    hs.eventtap.keyStroke({ "ctrl", "shift", "cmd" }, "C", 0)
    hs.alert.show("將文字轉換為繁體中文")
  end)
end)

hs.hotkey.bind({ "ctrl", "shift" }, "S", function()
  hs.eventtap.keyStroke({ "cmd" }, "a", 0)
  hs.timer.doAfter(0.05, function()
    hs.eventtap.keyStroke({ "ctrl", "alt", "shift", "cmd" }, "C", 0)
    hs.alert.show("將文字轉換為簡體中文")
  end)
end)

-- -----------------------------------------------------------------------------
-- END of script
-- -----------------------------------------------------------------------------
hs.autoLaunch(true)
-- 每次載入設定時，自動清空 Console 視窗
hs.console.clearConsole()
hs.alert.show("Hammerspoon優化配置已啟用 📺")
