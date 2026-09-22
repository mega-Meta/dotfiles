-- macOS「服務」文字轉換熱鍵
-- 先在「系統設定 → 鍵盤 → 鍵盤快速鍵 → 服務 → 文字」啓用下列服務：
--   將文字轉換為繁體中文（⌃⇧⌘C）
--   將文字轉換為簡體中文（⌃⌥⇧⌘C）

local textConversion = {}

local function runService(serviceName, modifiers)
  -- 直接送出系統設定中已配置的「服務」快捷鍵。
  -- 不依賴各 App 的選單結構或顯示語言，也不會改寫剪貼簿。
  hs.eventtap.keyStroke(modifiers, "C", 0)
  hs.printf("已送出文字轉換服務快捷鍵：%s", serviceName)
end

-- 可依偏好調整按鍵；預設為 ⌃⌥⌘T（繁體）與 ⌃⌥⌘S（簡體）。
-- 若你在系統設定改了服務快捷鍵，也要同步修改下方 modifiers。
textConversion.hotkeys = {
  traditional = hs.hotkey.bind({ "ctrl", "shift" }, "T", function()
    runService("將文字轉換為繁體中文", { "ctrl", "shift", "cmd" })
  end),
  simplified = hs.hotkey.bind({ "ctrl", "shift" }, "S", function()
    runService("將文字轉換為簡體中文", { "ctrl", "alt", "shift", "cmd" })
  end),
}

return textConversion