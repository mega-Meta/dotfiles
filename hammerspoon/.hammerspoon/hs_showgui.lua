-- ========================================================================
-- Hammerspoon 快捷鍵 GUI 管理器 (第一部分：高階 Raycast UI 前端)
-- ========================================================================

local hotkeyManager = {}
hotkeyManager.webView = nil

local function generateHTML()
    return [[
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Hammerspoon 快捷鍵管理面板</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; background: #1e1e24; color: #f8f8f2; }
            .card { background: #2a2a35; padding: 15px; border-radius: 8px; margin-bottom: 15px; border: 1px solid #3a3a4c; }
            .card h3 { margin-top: 0; color: #ff79c6; border-bottom: 1px solid #3a3a4c; padding-bottom: 8px; }
            table { width: 100%; border-collapse: collapse; margin-top: 10px; background: #23232e; border-radius: 6px; overflow: hidden; }
            th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid #3a3a4c; font-size: 13px; }
            th { background: #323242; color: #8be9fd; }
            input, button, select { padding: 6px 10px; background: #424255; color: white; border: none; border-radius: 6px; box-sizing: border-box; }
            input { background: #f8f8f2; color: #1e1e24; font-weight: 500; }
            button { cursor: pointer; font-weight: bold; }
            .btn-save { background: #50fa7b; color: #1e1e24; }
            .btn-save:hover { background: #69ff94; }
            .btn-del { background: #ff5555; color: white; }
            .btn-del:hover { background: #ff6e6e; }
            .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }
            .form-group { margin-bottom: 10px; }
            .form-group label { display: block; font-size: 12px; color: #6272a4; margin-bottom: 4px; }
            .form-group input { width: 100%; }
        </style>
    </head>
    <body>
        <h2>Hammerspoon 系統核心高階管理主控台</h2>
        
        <!-- 區塊一：核心高階參數調校 -->
        <div class="grid-2">
            <div class="card">
                <h3>⚙️ 輸入法與核心參數配置</h3>
                <div class="form-group">
                    <label>雙擊黃金判定時間 (秒)</label>
                    <input type="text" id="cfg-timer" value="0.35">
                </div>
                <div class="form-group">
                    <label>預設英文輸入法 ID (ABC_IME_ID)</label>
                    <input type="text" id="cfg-abc" value="com.apple.keylayout.ABC">
                </div>
                <div class="form-group">
                    <label>預設中文輸入法 ID (CLICK_IME_ID)</label>
                    <input type="text" id="cfg-click" value="com.apple.inputmethod.TCIM.Cangjie">
                </div>
                <button class="btn-save" onclick="saveCoreConfig()">儲存核心參數</button>
            </div>
            
            <div class="card">
                <h3>➕ 新增自訂常用字串 (Snippets)</h3>
                <div class="form-group"><label>快捷選單標題</label><input type="text" id="snip-title" placeholder="如: 📧 我的電子郵件"></div>
                <div class="form-group"><label>替換文字內容</label><input type="text" id="snip-text" placeholder="如: myemail@gmail.com"></div>
                <button class="btn-save" style="background:#8be9fd; color:#1e1e24;" onclick="addSnippet()">新增至剪貼簿選單</button>
            </div>
        </div>

        <!-- 區塊二：快捷鍵控制面板 -->
        <div class="card">
            <h3>⌨️ 全域快捷鍵配置 (Raycast 矩構)</h3>
            <table>
                <thead>
                    <tr><th>功能套件名稱</th><th>配置快捷鍵组合</th><th>詳細描述說明</th><th>操作</th></tr>
                </thead>
                <tbody id="key-table"></tbody>
            </table>
        </div>

        <!-- 區塊三：動態 Snippets 庫管理 -->
        <div class="card">
            <h3>📋 常用字串庫動態管理 (CRUD)</h3>
            <table>
                <thead>
                    <tr><th>選單標題</th><th>替換文字內容</th><th>管理操作</th></tr>
                </thead>
                <tbody id="snip-table"></tbody>
            </table>
        </div>

        <script>
            function sendToHammerspoon(data) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hammerspoon) {
                    window.webkit.messageHandlers.hammerspoon.postMessage(data);
                }
            }

            // 💡 接收 Lua 傳過來的所有高階複雜設定資訊
            function updateAllData(configStr, keysStr, snipStr) {
                // 1. 解析核心參數
                let cfg = configStr.split("|||");
                if(cfg.length >= 3) {
                    document.getElementById("cfg-timer").value = cfg[0];
                    document.getElementById("cfg-abc").value = cfg[1];
                    document.getElementById("cfg-click").value = cfg[2];
                }
                
                // 2. 渲染快捷鍵表格
                const kBody = document.getElementById("key-table");
                kBody.innerHTML = "";
                if(keysStr) {
                    keysStr.split("@@@").forEach(row => {
                        let cols = row.split("|||");
                        if(cols.length >= 4) {
                            kBody.innerHTML += `<tr>
                                <td style="font-weight:bold; color:#8be9fd;">${cols[1]}</td>
                                <td><input type="text" id="key-${cols[0]}" value="${cols[2]}" style="width:130px;"></td>
                                <td style="color:#6272a4;">${cols[3]}</td>
                                <td><button class="btn-save" onclick="updateKey('${cols[0]}')">修改</button></td>
                            </tr>`;
                        }
                    });
                }

                // 3. 渲染 Snippets 表格
                const sBody = document.getElementById("snip-table");
                sBody.innerHTML = "";
                if(snipStr) {
                    snipStr.split("@@@").forEach((row, idx) => {
                        let cols = row.split("|||");
                        if(cols.length >= 2) {
                            sBody.innerHTML += `<tr>
                                <td><input type="text" id="snip-t-${idx}" value="${cols[0]}" style="width:180px;"></td>
                                <td><input type="text" id="snip-x-${idx}" value="${cols[1]}" style="width:350px;"></td>
                                <td>
                                    <button class="btn-save" onclick="updateSnippet(${idx})">儲存</button>
                                    <button class="btn-del" onclick="deleteSnippet(${idx})">刪除</button>
                                </td>
                            </tr>`;
                        }
                    });
                }
            }

            function saveCoreConfig() {
                sendToHammerspoon({
                    type: "save_config",
                    timer: document.getElementById("cfg-timer").value,
                    abc: document.getElementById("cfg-abc").value,
                    click: document.getElementById("cfg-click").value
                });
            }

            function updateKey(id) {
                sendToHammerspoon({ type: "update_key", id: id, key: document.getElementById("key-" + id).value });
            }

            function addSnippet() {
                sendToHammerspoon({
                    type: "add_snip",
                    title: document.getElementById("snip-title").value,
                    text: document.getElementById("snip-text").value
                });
                document.getElementById("snip-title").value = "";
                document.getElementById("snip-text").value = "";
            }

            function updateSnippet(idx) {
                sendToHammerspoon({
                    type: "update_snip", index: idx,
                    title: document.getElementById("snip-t-" + idx).value,
                    text: document.getElementById("snip-x-" + idx).value
                });
            }

            function deleteSnippet(idx) {
                if(confirm("確定要刪除此字串組合嗎？")) { sendToHammerspoon({ type: "delete_snip", index: idx }); }
            }
        </script>
    </body>
    </html>
    ]]
end
-- ========================================================================
-- Hammerspoon 快捷鍵 GUI 管理器 (第二部分：Lua 核心控制引擎)
-- ========================================================================

local activeBinds = {}

-- 1. 核心參數初始化防護
local function loadCoreParams()
    local cfg = hs.settings.get("raycast_core_configs")
    if not cfg then
        cfg = { timer = "0.35", abc = "com.apple.keylayout.ABC", click = "com.apple.inputmethod.TCIM.Cangjie" }
        hs.settings.set("raycast_core_configs", cfg)
    end
    -- 💡 自動同步並改寫 init.lua 裡的全域變數！
    if DOUBLE_CLICK_TIMER then DOUBLE_CLICK_TIMER = tonumber(cfg.timer) end
    if ABC_IME_ID then ABC_IME_ID = cfg.abc end
    if CLICK_IME_ID then CLICK_IME_ID = cfg.click end
    return cfg
end

-- 2. 常用字串庫初始化防護
local function loadSnippets()
    local snips = hs.settings.get("raycast_gui_snippets")
    if not snips then
        snips = {
            { title = "📧 我的電子郵件", text = "myemailk@gmail.com" },
            { title = "🏢 公司統一編號", text = "12345678" },
            { title = "📍 常用寄件地址", text = "台北市信義區信義路五段7號" }
        }
        hs.settings.set("raycast_gui_snippets", snips)
    end
    -- 💡 全自動同步至 init.lua 裡的智慧選單資料槽！
    if FIXED_SNIPPETS then FIXED_SNIPPETS = snips end
    return snips
end

local function loadCentralExtensions()
    local saved = hs.settings.get("raycast_gui_extensions")
    if not saved then
        saved = {
            { id = "ext_reload", title = "Hammerspoon Config Reload", key = "cmd,alt,C", desc = "重新載入設定檔並刷新記憶體暫存" },
            { id = "ext_textedit", title = "TextEdit Quick Creator", key = "cmd,alt,K", desc = "由系統剪貼簿純文字直通建立未命名新文件" }
        }
        hs.settings.set("raycast_gui_extensions", saved)
    end
    return saved
end

local function refreshHotkeys()
    for _, bind in ipairs(activeBinds) do pcall(function() bind:delete() end) end
    activeBinds = {}
    local extensions = loadCentralExtensions()
    for _, ext in ipairs(extensions) do
        local modsTable, targetKey = {}, ""
        for token in string.gmatch(ext.key, "[^,]+") do
            token = token:match("^%s*(.-)%s*$")
            if token == "cmd" or token == "alt" or token == "ctrl" or token == "shift" then table.insert(modsTable, token) else targetKey = token end
        end
        local actionCode = ""
        if ext.id == "ext_reload" then actionCode = "hs.timer.doAfter(0.2, function() hs.reload() hs.alert.show('手動重載設定完成。') end)"
        elseif ext.id == "ext_textedit" then actionCode = "hs.timer.usleep(150000); local tApp = hs.application.get('com.apple.TextEdit'); local isR = tApp ~= nil and tApp:isRunning(); local delay = isR and 0.15 or 1.20; hs.osascript.applescript('tell application \"TextEdit\"\\nactivate\\nend tell'); hs.timer.doAfter(delay, function() local script = 'tell application \"TextEdit\"\\nset newDoc to make new document\\nset text of newDoc to (the clipboard as text)\\nend tell'; hs.osascript.applescript(script); hs.alert.show('🍏 成功由剪貼簿建立新檔！', 1.5) end)" end
        local func = load("return function() " .. actionCode .. " end")
        if func and #modsTable > 0 and targetKey ~= "" then
            local status, boundKey = pcall(hs.hotkey.bind, modsTable, targetKey, ext.title, func())
            if status then table.insert(activeBinds, boundKey) end
        end
    end
end

local function pushDataToWebview()
    if not hotkeyManager.webView then return end
    
    local cfg = loadCoreParams()
    local configStr = cfg.timer .. "|||" .. cfg.abc .. "|||" .. cfg.click
    
    local lines = {}
    for _, ext in ipairs(loadCentralExtensions()) do table.insert(lines, ext.id .. "|||" .. ext.title .. "|||" .. ext.key .. "|||" .. ext.desc) end
    local keysStr = table.concat(lines, "@@@"):gsub("'", "\\'")
    
    local slines = {}
    for _, snip in ipairs(loadSnippets()) do table.insert(slines, snip.title .. "|||" .. snip.text) end
    local snipStr = table.concat(slines, "@@@"):gsub("'", "\\'")
    
    hotkeyManager.webView:evaluateJavaScript(string.format("updateAllData('%s', '%s', '%s');", configStr, keysStr, snipStr))
end

-- 4. 核心增刪改查回呼
local function guiCallback(message)
    if not message or type(message) ~= "table" then return end
    local body = message.body
    if not body then return end

    if body.type == "save_config" then
        hs.settings.set("raycast_core_configs", { timer = body.timer, abc = body.abc, click = body.click })
    elseif body.type == "update_key" then
        local exts = loadCentralExtensions()
        for _, ext in ipairs(exts) do if ext.id == body.id then ext.key = body.key; break end end
        hs.settings.set("raycast_gui_extensions", exts)
    elseif body.type == "add_snip" then
        local snips = loadSnippets()
        table.insert(snips, { title = body.title, text = body.text })
        hs.settings.set("raycast_gui_snippets", snips)
    elseif body.type == "update_snip" then
        local snips = loadSnippets()
        local idx = body.index + 1
        if snips[idx] then snips[idx].title, snips[idx].text = body.title, body.text end
        hs.settings.set("raycast_gui_snippets", snips)
    elseif body.type == "delete_snip" then
        local snips = loadSnippets()
        table.remove(snips, body.index + 1)
        hs.settings.set("raycast_gui_snippets", snips)
    end

    loadCoreParams()
    loadSnippets()
    refreshHotkeys()
    pushDataToWebview()
    hs.alert.show("⚡ 設定更新已即時全面同步生效！")
end

function hotkeyManager.toggleGUI()
    if hotkeyManager.webView and hotkeyManager.webView:hswindow() and hotkeyManager.webView:hswindow():isVisible() then
        hotkeyManager.webView:delete()
        hotkeyManager.webView = nil
    else
        local ucc = hs.webview.usercontent.new("hammerspoon")
        ucc:setCallback(guiCallback)
        local rect = {x = 100, y = 100, w = 1100, h = 750}
        local view = hs.webview.new(rect, { developerExtrasEnabled = true }, ucc)
        view:windowStyle({"titled", "closable", "resizable", "utility"})
        view:html(generateHTML())
        view:windowTitle("Hammerspoon 全方位核心調校面板")
        view:show()
        hotkeyManager.webView = view
        hs.timer.doAfter(0.15, function() pushDataToWebview() end)
    end
end

-- 全自動執行生命週期同步
loadCoreParams()
loadSnippets()
refreshHotkeys()

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "K", function() hotkeyManager.toggleGUI() end)
