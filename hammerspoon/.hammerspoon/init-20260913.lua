-- init.lua
-- For JIS keyboard IME Switcher & Shottr Premium Full Integration

local DEBUG_FLAG = false  --off is false
local EISUU_KEY = 102
local KANA_KEY = 104
local LSHIFT_KEY = 56
local LCMD_KEY = 55
local RCMD_KEY = 54
local LALT_KEY = 58
local RALT_KEY = 61
local YEN_KEY = 93
local RFN_KEY = 179
local DOUBLE_CLICK_TIMER = 0.35
local ABC_IME_ID = "com.apple.keylayout.ABC"
local CLICK_IME_ID = "com.apple.inputmethod.TCIM.Cangjie" --#倉頡
--local CLICK_IME_ID = "com.apple.inputmethod.TCIM.Zhuyin" --#繁體倚天注音

local FIXED_SNIPPETS = {
	{ title = "📧 我的電子郵件", text = "myemailk@gmail.com" },
	{ title = "🏢 公司統一編號", text = "12345678" },
	{ title = "📍 常用寄件地址", text = "台北市信義區信義路五段7號" },
	{ title = "✍️ 常用客套回覆", text = "收到，感謝您的協助！我會盡快確認後回覆您。" },
}

-- 白名單設定
local WHITE_LIST_IDS = {
	["com.apple.Notes"] = true,
	["com.apple.Terminal"] = false, --terminal應該以英文為主，所以要切換
	["com.qvacua.VimR"] = false,
	["com.mitchellh.ghostty"] = false,
	["jp.naver.line.mac"] = true,
	["net.machorro.roberto.Moped"] = true,
	["com.apple.appkit.xpc.openAndSavePanelService"] = true,
	["com.apple.print.PrinterProxy"] = true,
	["com.sublimetext.4"] = false,
}

local COOLDOWN_TIME = 0.2
local lastTriggerTime = 0

local clipboardHistory = {}
local MAX_CLIPBOARD_ITEMS = 10
local lastCount = hs.pasteboard.changeCount()
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
end)
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
		if string.len(summary) > 40 then
			summary = string.sub(summary, 1, 40) .. "..."
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
	if myChooser then
		myChooser:delete()
	end
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

-- 模擬按下系統「選取下一個輸入來源」快捷鍵 (Control + Space)
local function simulateSystemImeSwitch()
	local currentTime = hs.timer.secondsSinceEpoch()
	if currentTime - lastTriggerTime < COOLDOWN_TIME then
		return
	end
	lastTriggerTime = currentTime
	hs.eventtap.keyStroke({ "ctrl" }, "space", 10000)
end

-- 混合式精準切換
local function setSpecificIME(imeID)
	local frontApp = hs.application.frontmostApplication()
	local appBundleID = frontApp and frontApp:bundleID() or ""

	if appBundleID == "com.apple.Safari" then
		local current = hs.keycodes.currentSourceID()
		if current ~= imeID then
			simulateSystemImeSwitch()
		end
	else
		hs.keycodes.currentSourceID(imeID)
	end
end

-- 1. かな 鍵監聽 (包含輸入法切換、Cmd+かな區域截圖、Opt+かな滾動長截圖)
local clickCount = 0
local clickTimer = nil
--local DOUBLE_CLICK_TIMEOUT = 0.50

kanaTap = hs.eventtap
	.new({ hs.eventtap.event.types.keyDown }, function(event)
		local keyCode = event:getKeyCode()
		local flags = event:getFlags()

		if keyCode == KANA_KEY then
			if flags.alt then
				hs.eventtap.keyStroke({ "cmd", "shift" }, "2", 0) -- Opt + かな = 滾動長截圖
				return true
			end

			if flags.cmd then
				hs.eventtap.keyStroke({ "cmd", "shift" }, "4", 0) -- Cmd + かな = 區域截圖
				return true
			end

			if clickTimer then
				clickTimer:stop()
			end
			clickCount = clickCount + 1

			if clickCount == 1 then
				clickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
					setSpecificIME(CLICK_IME_ID) -- 單擊：智慧切倉頡
					clickCount = 0
				end)
			elseif clickCount == 2 then
				simulateSystemImeSwitch() -- 雙擊：系統切換下一個
				clickCount = 0
			end
			return true
		end
		return false
	end)
	:start()

-- 2. 英數 (Eisuu) 鍵監聽：移入集中式狀態機，支援「單擊英文、雙擊選單」
local eisuuClickCount = 0
local eisuuClickTimer = nil
--local EISUU_DOUBLE_TIMEOUT = 0.40
eisuuTap = hs.eventtap
	.new({ hs.eventtap.event.types.keyDown }, function(event)
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
			if eisuuClickTimer then
				eisuuClickTimer:stop()
			end
			eisuuClickCount = eisuuClickCount + 1
			eisuuClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
				if eisuuClickCount == 1 then
					hs.keycodes.currentSourceID(ABC_IME_ID)
				elseif eisuuClickCount == 2 then
					showClipboardChooser()
				end
				eisuuClickCount = 0
			end)
			return true
		end
		return false
	end)
	:start()

-- 3. 修飾鍵監聽 (Cmd+LShift切換、雙擊Cmd工具列、🌟新增：雙擊Option自訂截圖)
local cmdClickCount = 0
local cmdClickTimer = nil
local altClickCount = 0
local altClickTimer = nil

modifierTap = hs.eventtap
	.new({ hs.eventtap.event.types.flagsChanged }, function(event)
		local keyCode = event:getKeyCode()
		local flags = event:getFlags()

		-- 情境 A：Cmd + Left Shift 切換輸入法
		if keyCode == LSHIFT_KEY and flags.shift and flags.cmd then
			simulateSystemImeSwitch()
			return true
		end

		-- 情境 B：單獨雙擊 left Cmd 鍵 $\rightarrow$ 喚出工具列 (Cmd+Shift+5)
		if keyCode == LCMD_KEY or keyCode == RCMD_KEY then
			if flags.cmd and not flags.shift and not flags.ctrl and not flags.alt then
				if cmdClickTimer then
					cmdClickTimer:stop()
				end
				cmdClickCount = cmdClickCount + 1
				if cmdClickCount == 1 then
					cmdClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
						cmdClickCount = 0
					end)
				elseif cmdClickCount == 2 then
					cmdClickCount = 0
					hs.eventtap.keyStroke({ "cmd", "shift" }, "5", 0)
					return true
				end
			end
		end

		-- 情境 B2：單獨雙擊 right Cmd 鍵 $\rightarrow$ 喚出工具列 (Cmd+Shift+H) for youtube show Home
		--[[
		if keyCode == RCMD_KEY then
			if flags.cmd and not flags.shift and not flags.ctrl and not flags.alt then
				if cmdClickTimer then
					cmdClickTimer:stop()
				end
				cmdClickCount = cmdClickCount + 1
				if cmdClickCount == 1 then
					cmdClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
						cmdClickCount = 0
					end)
				elseif cmdClickCount == 2 then
					cmdClickCount = 0
					hs.eventtap.keyStroke({ "cmd", "shift" }, "H", 0)
					return true
				end
			end
		end
		]]--

		-- 🌟 情境 C【全新新增】：單獨雙擊 Option 鍵 $\rightarrow$ 觸發 Shottr 功能 (Cmd+Shift+8)
		if keyCode == LALT_KEY or keyCode == RALT_KEY then
			-- 當按下 Option，且此時沒有混雜其他的修飾鍵 (如 Cmd、Shift、Ctrl)
			if flags.alt and not flags.cmd and not flags.shift and not flags.ctrl then
				if altClickTimer then
					altClickTimer:stop()
				end
				altClickCount = altClickCount + 1
				if altClickCount == 1 then
					altClickTimer = hs.timer.doAfter(DOUBLE_CLICK_TIMER, function()
						altClickCount = 0
					end)
				elseif altClickCount == 2 then
					altClickCount = 0
					hs.eventtap.keyStroke({ "cmd", "shift" }, "8", 0) -- 模擬發送 Cmd+Shift+8
					return true
				end
			end
		end

		return false
	end)
	:start()

-- 4. JIS 特有實體鍵監聽 (包含：Cmd + ¥ 重複區域截圖)
screenshotKeyTap = hs.eventtap
	.new({ hs.eventtap.event.types.keyDown }, function(event)
		local keyCode = event:getKeyCode()
		local flags = event:getFlags()

		if keyCode == YEN_KEY and flags.cmd then
			hs.eventtap.keyStroke({ "cmd", "shift" }, "7", 0) -- Cmd + ¥ = 重複上一次截圖
			return true
		end

		if keyCode == RFN_KEY then
		  hs.eventtap.keyStroke({ "cmd", "shift" }, "H", 0) -- Cmd + ¥ = 重複上一次截圖
			return true
		end

		return false
	end)
	:start()

-- 5. App 監聽器
appWatcher = hs.application.watcher
	.new(function(appName, eventType, appObject)
		if eventType == hs.application.watcher.activated then
			if appObject then
				local appBundleID = appObject:bundleID()
				local isWhitelisted = WHITE_LIST_IDS[appBundleID] or false
				if not isWhitelisted then
					hs.timer.doAfter(0.05, function()
						hs.keycodes.currentSourceID(ABC_IME_ID)
					end)
				end
			end
			hs.timer.doAfter(0.1, function()
				if not hs.eventtap.isSecureInputEnabled() then
					if kanaTap then
						kanaTap:stop()
						kanaTap:start()
					end
					if eisuuTap then
						eisuuTap:stop()
						eisuuTap:start()
					end
					if modifierTap then
						modifierTap:stop()
						modifierTap:start()
					end
					if screenshotKeyTap then
						screenshotKeyTap:stop()
						screenshotKeyTap:start()
					end
				end
			end)
		end
	end)
	:start()

-- 6. 每 3 秒背景防護（防卡死）
secureInputTimer = hs.timer.doEvery(3, function()
	if not hs.eventtap.isSecureInputEnabled() then
		if kanaTap and not kanaTap:isEnabled() then
			kanaTap:start()
		end
		if eisuuTap and not eisuuTap:isEnabled() then
			eisuuTap:start()
		end
		if modifierTap and not modifierTap:isEnabled() then
			modifierTap:start()
		end
		if screenshotKeyTap and not screenshotKeyTap:isEnabled() then
			screenshotKeyTap :start()
		end
	end
end)
:start()

-- below function show info. when debug_flag is ON
-- Create a key logger to show keycodes and modifiers
keyLogger = hs.eventtap
   .new({ hs.eventtap.event.types.keyDown }, function(event)
	local keyCode = event:getKeyCode()
	local flags = event:getFlags()

	-- Format and print the key details to the Hammerspoon Console
	if DEBUG_FLAG then
	   print(string.format("Key Code: %s | Modifiers: %s", keyCode, hs.inspect(flags)))
    end
	return false -- Return false so the key press still reaches the OS/apps
end)
:start()

--[[
 --Show application system ID on console when Debug_flag is ON
 1.點擊畫面右上角選單列的 Hammerspoon 圖示，選擇 「Open Console」（打開主控台）。
 2.在主控台最下方的輸入框中，複製並貼上以下這行程式碼，然後按下 Enter 鍵執行：
 testWatcher = hs.application.watcher.new(function(name, event, app) if event == hs.application.watcher.activated and app then print("App名稱: " .. name .. " | BundleID: " .. tostring(app:bundleID())) end end):start()
 3.執行後，你可以直接用滑鼠去點擊你想查詢的 App（例如微信、Discord 或備忘錄）。這時 Hammerspoon 主控台就會立刻即時印出該 App 的準確 ID，例如：App名稱: 備忘錄 | BundleID: com.apple.NotesApp名稱: WeChat | BundleID: com.tencent.xinWeChat
 4.關閉偵測：查詢完畢後，在主控台輸入 testWatcher:stop() 即可關閉這個臨時偵測器。
]]
--
testWatcher = hs.application.watcher.new(function(name, event, app)
   if event == hs.application.watcher.activated and app and DEBUG_FLAG then
      print("App名稱: " .. name .. " | BundleID: " .. tostring(app:bundleID()))
   end
end)
:start()

hs.autoLaunch(true)
