-- ============================================================================
-- Hammerspoon Local Spoons Manager
-- File: hs_spoonsmgr.lua
-- Version: 0.1.0
--
-- Purpose:
--   Local Spoons discovery, lifecycle management, enable/disable state,
--   Manager-owned hotkeys, diagnostics, and a WebView GUI.
--
-- Public API:
--   local spoonsMgr = require("hs_spoonsmgr")
--   spoonsMgr.toggleGUI()
--   spoonsMgr.refresh()
--
-- Notes:
--   - Spoons are discovered from ~/.hammerspoon/Spoons by default.
--   - The Manager does not hard-code individual Spoon implementations.
--   - Spoon metadata is read from meta.json when available.
-- ============================================================================

local manager = {
    version = "0.3.1",
    webView = nil,
    ucc = nil,
    spoonPath = hs.configdir .. "/Spoons",
    configKey = "hs_spoonsmgr_config_v1",
    activeHotkeys = {},
    runtime = {},
    lastScan = nil,
    events = {},
    managerHotkey = nil,
    initialized = false,
    officialCatalog = {},
    officialCatalogLoaded = false,
    officialCatalogLoading = false,
    officialCatalogUpdated = nil,
    officialInstallBusy = {}
}

local DEFAULT_CONFIG = {
    version = 1,
    spoonsPath = hs.configdir .. "/Spoons",
    managerHotkey = {
        mods = {"ctrl", "alt"},
        key = "K"
    },
    spoons = {},
    officialCatalogUrl = "https://raw.githubusercontent.com/Hammerspoon/Spoons/master/docs/docs.json",
    officialDownloadBase = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/"
}

local function logEvent(level, message)
    local entry = {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        level = level or "INFO",
        message = tostring(message or "")
    }
    table.insert(manager.events, 1, entry)
    while #manager.events > 80 do
        table.remove(manager.events)
    end

    if level == "ERROR" then
        hs.printf("[hs_spoonsmgr][ERROR] %s", entry.message)
    else
        hs.printf("[hs_spoonsmgr][%s] %s", entry.level, entry.message)
    end
end

local function cloneTable(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do
        out[k] = cloneTable(v)
    end
    return out
end

local function mergeDefaults(value, defaults)
    if type(value) ~= "table" then
        return cloneTable(defaults)
    end

    local out = cloneTable(value)
    for k, v in pairs(defaults) do
        if out[k] == nil then
            out[k] = cloneTable(v)
        elseif type(v) == "table" and type(out[k]) == "table" then
            out[k] = mergeDefaults(out[k], v)
        end
    end
    return out
end

local saveConfig

local function loadConfig()
    local saved = hs.settings.get(manager.configKey)
    local cfg = mergeDefaults(saved, DEFAULT_CONFIG)

    -- Migrate the original manager shortcut (Ctrl+Alt+Cmd+K) to the current
    -- default (Ctrl+Alt+K). Preserve an explicitly customized shortcut.
    if type(saved) == "table" and type(saved.managerHotkey) == "table" then
        local oldMods = saved.managerHotkey.mods
        local oldKey = saved.managerHotkey.key
        if oldKey == "K" and type(oldMods) == "table" then
            local isOldDefault = (#oldMods == 3)
            if isOldDefault then
                local seen = {}
                for _, mod in ipairs(oldMods) do seen[mod] = true end
                isOldDefault = seen.ctrl and seen.alt and seen.cmd
            end
            if isOldDefault then
                cfg.managerHotkey = cloneTable(DEFAULT_CONFIG.managerHotkey)
                saveConfig(cfg)
            end
        end
    end

    if type(cfg.spoonsPath) ~= "string" or cfg.spoonsPath == "" then
        cfg.spoonsPath = hs.configdir .. "/Spoons"
    end

    manager.spoonPath = cfg.spoonsPath
    return cfg
end

saveConfig = function(cfg)
    hs.settings.set(manager.configKey, cfg)
end

local function ensureDirectoryPath(path)
    if type(path) ~= "string" or path == "" then return nil end
    if path:sub(1, 1) == "~" then
        path = os.getenv("HOME") .. path:sub(2)
    end
    return path:gsub("/+$", "")
end

local function spoonPackagePath(path)
    local clean = ensureDirectoryPath(path)
    if not clean then return nil end
    return clean .. "/?.spoon/init.lua"
end

local function ensurePackagePath(path)
    local pattern = spoonPackagePath(path)
    if not pattern then return false end

    if not package.path:find(pattern, 1, true) then
        package.path = package.path .. ";" .. pattern
    end
    return true
end

local function readJSONFile(path)
    local file = io.open(path, "r")
    if not file then return nil end

    local content = file:read("*a")
    file:close()

    if not content or content == "" then return nil end

    local ok, result = pcall(hs.json.decode, content)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

local function isSpoonDirectory(name)
    return type(name) == "string"
        and name:sub(-6) == ".spoon"
        and #name > 6
end

local function normalizeSpoonName(directoryName)
    return directoryName:sub(1, -7)
end

local function discoverSpoons()
    local cfg = loadConfig()
    local basePath = ensureDirectoryPath(cfg.spoonsPath)
    if not basePath then
        logEvent("ERROR", "Invalid Spoons directory.")
        return {}
    end

    ensurePackagePath(basePath)

    local found = {}

    -- hs.fs.dir() returns (iterator_function, directory_object, nil, directory_object).
    -- Keep the iterator function and its directory object separate; passing the
    -- directory object itself as the generic-for iterator causes:
    -- "directory metatable expected, got nil".
    local ok, iterFn, dirObj = pcall(hs.fs.dir, basePath)

    if not ok or type(iterFn) ~= "function" or not dirObj then
        logEvent("ERROR", "Unable to scan Spoons directory: " .. basePath)
        manager.lastScan = os.date("%Y-%m-%d %H:%M:%S")
        return found
    end

    for item in iterFn, dirObj do
        if isSpoonDirectory(item) then
            local name = normalizeSpoonName(item)
            local path = basePath .. "/" .. item
            local metadata = readJSONFile(path .. "/meta.json") or {}

            found[name] = {
                name = name,
                path = path,
                metadata = metadata,
                description = metadata.description or "",
                version = metadata.version or "Unknown",
                author = metadata.author or "Unknown",
                homepage = metadata.homepage or "",
                license = metadata.license or "",
                loaded = hs.spoons.isLoaded(name) == true,
                installed = true
            }
        end
    end

    manager.lastScan = os.date("%Y-%m-%d %H:%M:%S")
    return found
end


-- ============================================================================
-- Official Hammerspoon Spoons catalog / installer
-- Source: official Hammerspoon/Spoons repository.
-- The catalog is docs/docs.json; downloads are restricted to the official
-- repository URL configured above.
-- ============================================================================

local function normalizeOfficialRecord(record)
    if type(record) ~= "table" or type(record.name) ~= "string" then return nil end
    return {
        name = record.name,
        description = record.desc or record.description or "",
        type = record.type or "Module",
        downloadURL = record.download_url,
        homepage = "https://www.hammerspoon.org/Spoons/" .. record.name .. ".html"
    }
end

local function loadOfficialCatalogFromBody(body)
    if type(body) ~= "string" or body == "" then return false, "Empty catalog response" end
    local ok, decoded = pcall(hs.json.decode, body)
    if not ok or type(decoded) ~= "table" then
        return false, "Invalid official Spoons catalog JSON"
    end

    local catalog = {}
    for _, record in ipairs(decoded) do
        local item = normalizeOfficialRecord(record)
        if item then
            -- docs.json may contain module/method/variable entries for the same
            -- Spoon. Keep the first Module description as the catalog item.
            if not catalog[item.name] or catalog[item.name].description == "" then
                catalog[item.name] = item
            end
        end
    end

    local list = {}
    for _, item in pairs(catalog) do
        item.downloadURL = item.downloadURL
            or (loadConfig().officialDownloadBase .. item.name .. ".spoon.zip")
        table.insert(list, item)
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)

    manager.officialCatalog = list
    manager.officialCatalogLoaded = true
    manager.officialCatalogLoading = false
    manager.officialCatalogUpdated = os.date("%Y-%m-%d %H:%M:%S")
    return true
end

local function fetchOfficialCatalog(callback)
    if manager.officialCatalogLoading then return false end
    local cfg = loadConfig()
    local url = cfg.officialCatalogUrl
    if type(url) ~= "string" or url == "" then
        logEvent("ERROR", "Official Spoons catalog URL is not configured.")
        return false
    end

    manager.officialCatalogLoading = true
    logEvent("INFO", "Fetching official Spoons catalog")

    hs.http.asyncGet(url, nil, function(status, body)
        if status < 100 or status >= 400 then
            manager.officialCatalogLoading = false
            logEvent("ERROR", "Official Spoons catalog request failed: HTTP " .. tostring(status))
            if callback then callback(false) end
            return
        end

        local ok, err = loadOfficialCatalogFromBody(body)
        if not ok then
            logEvent("ERROR", "Official Spoons catalog parse failed: " .. tostring(err))
            if callback then callback(false) end
            return
        end

        logEvent("INFO", "Official Spoons catalog loaded: " .. tostring(#manager.officialCatalog) .. " Spoons")
        if callback then callback(true) end
    end)
    return true
end

local function getOfficialCatalogState()
    local installed = discoverSpoons()
    local installedSet = {}
    for name, _ in pairs(installed) do installedSet[name] = true end

    local result = {}
    for _, item in ipairs(manager.officialCatalog or {}) do
        local copy = cloneTable(item)
        copy.installed = installedSet[copy.name] == true
        copy.enabled = copy.installed and ((loadConfig().spoons[copy.name] or {}).enabled == true) or false
        table.insert(result, copy)
    end
    return result
end

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function removePath(path)
    if type(path) ~= "string" or path == "" then return false end
    if not hs.fs.attributes(path) then return true end
    local _, success = hs.execute("/bin/rm -rf " .. shellQuote(path))
    return success == true
end

local sendState
local safeStop
local deleteHotkey

-- Spoon names come from local folders / the official catalog. Allow dots (some
-- official Spoons use names such as Seal.plugins.screencapture), while rejecting
-- path separators and traversal sequences before any filesystem operation.
local function isSafeSpoonName(name)
    return type(name) == "string"
        and name ~= ""
        and not name:find("..", 1, true)
        and not name:find("/", 1, true)
        and not name:find("\\", 1, true)
        and name:match("^[%w_.%-]+$") ~= nil
end

-- Remove a locally installed Spoon from the configured Spoons directory.
-- This intentionally does NOT remove Official Spoons from the catalog; it only
-- deletes the local <Name>.spoon directory under ~/.hammerspoon/Spoons.
local function removeLocalSpoon(name)
    if not isSafeSpoonName(name) then
        logEvent("ERROR", "Invalid local Spoon name: " .. tostring(name))
        return false, "Invalid Spoon name"
    end

    local cfg = loadConfig()
    local base = ensureDirectoryPath(cfg.spoonsPath)
    if type(base) ~= "string" or base == "" then
        logEvent("ERROR", "Invalid Spoons directory.")
        return false, "Invalid Spoons directory"
    end

    local target = base .. "/" .. name .. ".spoon"
    if not hs.fs.attributes(target) then
        logEvent("ERROR", "Local Spoon not found: " .. name)
        return false, "Spoon not found"
    end

    -- Stop it before removing its files. There is no need to alter init.lua.
    if hs.spoons.isLoaded(name) then
        safeStop(name)
    end
    deleteHotkey(name)

    -- Only delete the exact <name>.spoon path inside the configured Spoons dir.
    -- The name validation above prevents path traversal.
    local ok = removePath(target)
    if not ok then
        logEvent("ERROR", "Unable to remove local Spoon: " .. name)
        return false, "Unable to remove Spoon"
    end

    cfg.spoons[name] = nil
    saveConfig(cfg)
    manager.runtime[name] = nil
    logEvent("INFO", "Removed local Spoon: " .. name)
    return true
end

local function installOfficialSpoon(name)
    if not isSafeSpoonName(name) then
        logEvent("ERROR", "Invalid official Spoon name: " .. tostring(name))
        return false
    end

    if manager.officialInstallBusy[name] then return false end

    local target = nil
    for _, item in ipairs(manager.officialCatalog or {}) do
        if item.name == name then target = item break end
    end
    if not target then
        logEvent("ERROR", "Official Spoon not found in catalog: " .. name)
        return false
    end

    local cfg = loadConfig()
    local downloadURL = target.downloadURL
        or (cfg.officialDownloadBase .. name .. ".spoon.zip")
    local expectedPrefix = cfg.officialDownloadBase
    if downloadURL:sub(1, #expectedPrefix) ~= expectedPrefix then
        logEvent("ERROR", "Refused non-official Spoon download URL: " .. tostring(downloadURL))
        return false
    end

    manager.officialInstallBusy[name] = true
    logEvent("INFO", "Downloading official Spoon: " .. name)

    hs.http.asyncGet(downloadURL, nil, function(status, body)
        local function finish(success, message)
            manager.officialInstallBusy[name] = nil
            if success then
                logEvent("INFO", "Installed official Spoon: " .. name)
            elseif message then
                logEvent("ERROR", message)
            end
            if manager.webView then sendState() end
        end

        if status < 100 or status >= 400 or type(body) ~= "string" then
            finish(false, "Download failed for " .. name .. ": HTTP " .. tostring(status))
            return
        end

        local tempBase = hs.configdir .. "/.hs_spoonsmgr_downloads"
        hs.fs.mkdir(tempBase)
        local zipPath = tempBase .. "/" .. name .. ".spoon.zip"
        local extractPath = tempBase .. "/extract-" .. name
        removePath(extractPath)
        pcall(function() os.remove(zipPath) end)
        hs.fs.mkdir(extractPath)

        local file = io.open(zipPath, "wb")
        if not file then
            finish(false, "Unable to create temporary download file for " .. name)
            return
        end
        file:write(body)
        file:close()

        -- Some Hammerspoon builds have inconsistent hs.task.new argument-table
        -- handling. To avoid passing an arguments table through that API, run the
        -- command through /bin/sh and feed the command on stdin. This also avoids
        -- any dependency on shell PATH resolution for unzip/mv.
        local function shellQuote(value)
            return "'" .. tostring(value):gsub("'", "'\"'\"'") .. "'"
        end

        local task = hs.task.new("/bin/sh", function(exitCode)
            if exitCode ~= 0 then
                removePath(extractPath)
                pcall(function() os.remove(zipPath) end)
                finish(false, "Unable to extract official Spoon: " .. name)
                return
            end

            local extracted = extractPath .. "/" .. name .. ".spoon"
            local initPath = extracted .. "/init.lua"
            local attrs = hs.fs.attributes(initPath)
            if not attrs then
                removePath(extractPath)
                pcall(function() os.remove(zipPath) end)
                finish(false, "Downloaded archive is not a valid Spoon: " .. name)
                return
            end

            local destination = ensureDirectoryPath(cfg.spoonsPath) .. "/" .. name .. ".spoon"
            if hs.fs.attributes(destination) then
                removePath(destination)
            end

            local moveTask = hs.task.new("/bin/sh", function(moveExit)
                removePath(extractPath)
                pcall(function() os.remove(zipPath) end)
                if moveExit ~= 0 then
                    finish(false, "Unable to install official Spoon: " .. name)
                    return
                end
                discoverSpoons()
                finish(true)
            end)

            if not moveTask then
                removePath(extractPath)
                pcall(function() os.remove(zipPath) end)
                finish(false, "Unable to create installation task for " .. name)
                return
            end

            moveTask:setInput("/bin/mv " .. shellQuote(extracted) .. " " .. shellQuote(ensureDirectoryPath(cfg.spoonsPath)) .. "\n")
            if not moveTask:start() then
                removePath(extractPath)
                pcall(function() os.remove(zipPath) end)
                finish(false, "Unable to start installation task for " .. name)
            end
        end)

        if not task then
            removePath(extractPath)
            pcall(function() os.remove(zipPath) end)
            finish(false, "Unable to create unzip task for " .. name)
            return
        end

        task:setInput("/usr/bin/unzip -q -o " .. shellQuote(zipPath) .. " -d " .. shellQuote(extractPath) .. "\n")
        if not task:start() then
            removePath(extractPath)
            pcall(function() os.remove(zipPath) end)
            finish(false, "Unable to start unzip task for " .. name)
        end
    end)

    return true
end

local function getConfigEntry(cfg, name)
    cfg.spoons[name] = cfg.spoons[name] or {
        enabled = false,
        hotkey = nil
    }
    return cfg.spoons[name]
end

local function safeStart(spoonObj, name)
    if not spoonObj or type(spoonObj.start) ~= "function" then
        return true, nil
    end

    local ok, err = pcall(function()
        spoonObj:start()
    end)

    if not ok then
        logEvent("ERROR", "Failed to start " .. name .. ": " .. tostring(err))
        manager.runtime[name] = manager.runtime[name] or {}
        manager.runtime[name].error = tostring(err)
        manager.runtime[name].status = "error"
        return false, err
    end

    manager.runtime[name] = manager.runtime[name] or {}
    manager.runtime[name].status = "running"
    manager.runtime[name].error = nil
    return true, nil
end

safeStop = function(name)
    local spoonObj = _G.spoon and _G.spoon[name]
    if not spoonObj then
        manager.runtime[name] = manager.runtime[name] or {}
        manager.runtime[name].status = "stopped"
        return true
    end

    if type(spoonObj.stop) == "function" then
        local ok, err = pcall(function()
            spoonObj:stop()
        end)
        if not ok then
            logEvent("ERROR", "Failed to stop " .. name .. ": " .. tostring(err))
            manager.runtime[name] = manager.runtime[name] or {}
            manager.runtime[name].error = tostring(err)
            manager.runtime[name].status = "error"
            return false
        end
    end

    manager.runtime[name] = manager.runtime[name] or {}
    manager.runtime[name].status = "stopped"
    manager.runtime[name].error = nil
    return true
end

local function loadSpoon(name)
    local cfg = loadConfig()
    ensurePackagePath(cfg.spoonsPath)

    local ok, result = pcall(function()
        return hs.loadSpoon(name)
    end)

    if not ok or not result then
        local err = tostring(result)
        logEvent("ERROR", "Failed to load " .. name .. ": " .. err)
        manager.runtime[name] = manager.runtime[name] or {}
        manager.runtime[name].status = "error"
        manager.runtime[name].error = err
        return nil, err
    end

    manager.runtime[name] = manager.runtime[name] or {}
    manager.runtime[name].status = "loaded"
    manager.runtime[name].error = nil
    return result
end

local function unloadSpoon(name)
    safeStop(name)

    if _G.spoon then
        _G.spoon[name] = nil
    end
    package.loaded[name] = nil

    manager.runtime[name] = manager.runtime[name] or {}
    manager.runtime[name].status = "unloaded"
    manager.runtime[name].error = nil
    return true
end

local function reloadSpoon(name)
    unloadSpoon(name)
    local spoonObj, err = loadSpoon(name)
    if not spoonObj then return false, err end

    local ok, startErr = safeStart(spoonObj, name)
    if not ok then return false, startErr end

    logEvent("INFO", "Reloaded " .. name)
    return true
end

local function startSpoon(name)
    local spoonObj = (_G.spoon and _G.spoon[name]) or loadSpoon(name)
    if not spoonObj then return false end

    local ok = safeStart(spoonObj, name)
    if ok then logEvent("INFO", "Started " .. name) end
    return ok
end

local function stopSpoon(name)
    local ok = safeStop(name)
    if ok then logEvent("INFO", "Stopped " .. name) end
    return ok
end

local function enableSpoon(name)
    local cfg = loadConfig()
    local entry = getConfigEntry(cfg, name)
    entry.enabled = true
    saveConfig(cfg)

    local ok = startSpoon(name)
    if ok then
        logEvent("INFO", "Enabled " .. name)
    end
    return ok
end

local function disableSpoon(name)
    local cfg = loadConfig()
    local entry = getConfigEntry(cfg, name)
    entry.enabled = false
    saveConfig(cfg)

    local ok = stopSpoon(name)
    if ok then
        logEvent("INFO", "Disabled " .. name)
    end
    return ok
end

deleteHotkey = function(name)
    local bind = manager.activeHotkeys[name]
    if bind then
        pcall(function() bind:delete() end)
        manager.activeHotkeys[name] = nil
    end
end

local function setSpoonHotkey(name, mods, key)
    local cfg = loadConfig()
    local entry = getConfigEntry(cfg, name)

    deleteHotkey(name)

    if type(mods) ~= "table" or type(key) ~= "string" or key == "" then
        entry.hotkey = nil
        saveConfig(cfg)
        return true
    end

    entry.hotkey = {
        mods = cloneTable(mods),
        key = key
    }
    saveConfig(cfg)

    return true
end

local function bindSpoonHotkey(name, spoonObj)
    local cfg = loadConfig()
    local entry = cfg.spoons[name]
    if not entry or type(entry.hotkey) ~= "table" then return end
    if type(entry.hotkey.key) ~= "string" or entry.hotkey.key == "" then return end

    deleteHotkey(name)

    local mods = entry.hotkey.mods or {}
    local ok, bindOrErr = pcall(function()
        return hs.hotkey.bind(mods, entry.hotkey.key, name, function()
            if type(spoonObj.toggle) == "function" then
                spoonObj:toggle()
            elseif type(spoonObj.start) == "function" and type(spoonObj.stop) == "function" then
                local status = manager.runtime[name] and manager.runtime[name].status
                if status == "running" then
                    stopSpoon(name)
                else
                    startSpoon(name)
                end
            else
                hs.alert.show(name)
            end
        end)
    end)

    if ok and bindOrErr then
        manager.activeHotkeys[name] = bindOrErr
    else
        logEvent("ERROR", "Failed to bind hotkey for " .. name .. ": " .. tostring(bindOrErr))
    end
end

local function refreshHotkeys(spoons)
    for name, _ in pairs(manager.activeHotkeys) do
        deleteHotkey(name)
    end

    for name, info in pairs(spoons) do
        if info.loaded and _G.spoon and _G.spoon[name] then
            bindSpoonHotkey(name, _G.spoon[name])
        end
    end
end

local function synchronizeRuntime(spoons)
    local cfg = loadConfig()

    for name, info in pairs(spoons) do
        local entry = getConfigEntry(cfg, name)

        if entry.enabled then
            if not hs.spoons.isLoaded(name) then
                loadSpoon(name)
            end
            if _G.spoon and _G.spoon[name] then
                local runtime = manager.runtime[name] or {}
                if runtime.status ~= "running" then
                    safeStart(_G.spoon[name], name)
                end
            end
        else
            if hs.spoons.isLoaded(name) then
                safeStop(name)
            else
                manager.runtime[name] = manager.runtime[name] or {}
                manager.runtime[name].status = "disabled"
            end
        end
    end

    saveConfig(cfg)
end

local function getSpoonsState()
    local cfg = loadConfig()
    local discovered = discoverSpoons()
    synchronizeRuntime(discovered)

    for name, info in pairs(discovered) do
        info.loaded = hs.spoons.isLoaded(name) == true
        local entry = cfg.spoons[name] or {}
        info.enabled = entry.enabled == true

        local runtime = manager.runtime[name] or {}
        info.status = runtime.status
        if info.enabled and not info.status then
            info.status = info.loaded and "loaded" or "enabled"
        elseif not info.enabled and not info.status then
            info.status = "disabled"
        end

        info.error = runtime.error
        info.hotkey = entry.hotkey
    end

    refreshHotkeys(discovered)
    return discovered
end

local function jsonEncode(value)
    local ok, encoded = pcall(hs.json.encode, value)
    if ok then return encoded end
    return "{}"
end

sendState = function()
    if not manager.webView then return end

    local state = {
        type = "state_update",
        manager = {
            version = manager.version,
            spoonPath = loadConfig().spoonsPath,
            lastScan = manager.lastScan,
            events = manager.events,
            officialCatalogLoaded = manager.officialCatalogLoaded,
            officialCatalogLoading = manager.officialCatalogLoading,
            officialCatalogUpdated = manager.officialCatalogUpdated
        },
        spoons = getSpoonsState(),
        officialSpoons = getOfficialCatalogState(),
        officialInstallBusy = manager.officialInstallBusy
    }

    local script = "window.hsSpoonMgrReceive(" .. jsonEncode(state) .. ");"
    pcall(function()
        manager.webView:evaluateJavaScript(script)
    end)
end

local function parseKeyString(value)
    if type(value) ~= "string" then return {}, "" end

    local mods = {}
    local key = ""

    for token in value:gmatch("[^,]+") do
        token = token:match("^%s*(.-)%s*$")
        if token == "cmd" or token == "alt" or token == "ctrl" or token == "shift" then
            table.insert(mods, token)
        elseif token ~= "" then
            key = token
        end
    end

    return mods, key
end

local function trimText(value)
    if type(value) ~= "string" then return "" end
    return value:match("^%s*(.-)%s*$") or ""
end

local function readSpoonSource(name)
    local cfg = loadConfig()
    local base = ensureDirectoryPath(cfg.spoonsPath)
    if not base or type(name) ~= "string" then return nil end
    local path = base .. "/" .. name .. ".spoon/init.lua"
    local file = io.open(path, "r")
    if not file then return nil end
    local source = file:read("*a") or ""
    file:close()
    return source, path
end

local function extractSpoonSummary(name)
    local spoons = discoverSpoons()
    local info = spoons[name]
    local officialInfo = nil
    for _, item in ipairs(manager.officialCatalog or {}) do
        if item.name == name then officialInfo = item break end
    end
    local source, sourcePath = readSpoonSource(name)
    local summary = {
        name = name,
        description = (info and info.description) or (officialInfo and officialInfo.description) or "",
        version = (info and info.version) or "Not installed locally",
        author = (info and info.author) or "Not installed locally",
        license = (info and info.license) or "",
        path = info and info.path or sourcePath or "Not installed locally",
        managerHotkey = nil,
        configuredHotkey = info and info.hotkey or nil,
        methods = {},
        sourceHotkeys = {},
        officialDocs = "https://www.hammerspoon.org/Spoons/" .. tostring(name) .. ".html"
    }

    local cfg = loadConfig()
    summary.managerHotkey = cfg.managerHotkey

    if not source then return summary end

    local seenMethods = {}
    for method in source:gmatch("function%s+obj%s*[:%.]%s*([%w_]+)%s*%(") do
        if not seenMethods[method] then
            seenMethods[method] = true
            table.insert(summary.methods, method)
        end
    end
    table.sort(summary.methods)

    local seenHotkeys = {}
    for line in source:gmatch("[^\r\n]+") do
        local clean = trimText(line)
        local lower = clean:lower()
        if lower:find("hotkey", 1, true) or lower:find("defaultmapping", 1, true) then
            -- Keep the source declaration/comment so the Summary shows the
            -- Spoon's documented/default hotkey information without guessing
            -- how the Spoon interprets its mapping.
            if #clean <= 220 and not seenHotkeys[clean] then
                seenHotkeys[clean] = true
                table.insert(summary.sourceHotkeys, clean)
            end
        end
    end
    return summary
end

local function sendSummary(name)
    if not manager.webView then return end
    local summary = extractSpoonSummary(name)
    local script = "window.hsSpoonMgrSummary(" .. jsonEncode(summary) .. ");"
    pcall(function() manager.webView:evaluateJavaScript(script) end)
end

local function handleMessage(message)
    if type(message) ~= "table" then return end
    local body = message.body or message
    if type(body) ~= "table" then return end

    local t = body.type
    local name = body.name

    if t == "scan" or t == "refresh" then
        logEvent("INFO", "Refresh requested")
        sendState()

    elseif t == "spoon_enable" and name then
        enableSpoon(name)
        sendState()

    elseif t == "spoon_disable" and name then
        disableSpoon(name)
        sendState()

    elseif t == "spoon_start" and name then
        startSpoon(name)
        sendState()

    elseif t == "spoon_stop" and name then
        stopSpoon(name)
        sendState()

    elseif t == "spoon_reload" and name then
        reloadSpoon(name)
        sendState()

    elseif t == "spoon_remove" and name then
        removeLocalSpoon(name)
        sendState()

    elseif t == "save_hotkey" and name then
        local mods = body.mods
        local key = body.key
        if type(mods) ~= "table" then
            mods, key = parseKeyString(body.hotkey)
        end
        setSpoonHotkey(name, mods, key)
        local cfg = loadConfig()
        local obj = _G.spoon and _G.spoon[name]
        if obj then bindSpoonHotkey(name, obj) end
        sendState()

    elseif t == "remove_hotkey" and name then
        local cfg = loadConfig()
        local entry = getConfigEntry(cfg, name)
        entry.hotkey = nil
        saveConfig(cfg)
        deleteHotkey(name)
        sendState()

    elseif t == "official_refresh" then
        fetchOfficialCatalog(function() sendState() end)

    elseif t == "official_install" and name then
        installOfficialSpoon(name)
        sendState()

    elseif t == "spoon_summary" and name then
        sendSummary(name)

    elseif t == "open_official_site" then
        hs.urlevent.openURL("https://www.hammerspoon.org/Spoons/")

    elseif t == "open_official_spoon" and name then
        if isSafeSpoonName(name) then
            hs.urlevent.openURL("https://www.hammerspoon.org/Spoons/" .. name .. ".html")
        end

    elseif t == "open_spoon_homepage" and name then
        local spoons = discoverSpoons()
        local info = spoons[name]
        if info and info.homepage and info.homepage ~= "" then
            hs.urlevent.openURL(info.homepage)
        end
    end
end

local function generateHTML()
    return [[
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Hammerspoon Spoons Manager</title>
<style>
:root {
  color-scheme: dark;
  --bg:#17181d; --panel:#20222a; --panel2:#292c36; --border:#3a3e4b;
  --text:#f4f5f7; --muted:#9aa1b2; --cyan:#8be9fd; --green:#50fa7b;
  --red:#ff5555; --purple:#bd93f9; --yellow:#f1fa8c;
}
* { box-sizing:border-box; }
body { margin:0; font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display",sans-serif;
       background:var(--bg); color:var(--text); }
.app { display:flex; height:100vh; min-width:920px; }
.sidebar { width:220px; padding:22px 16px; background:#14151a; border-right:1px solid var(--border); }
.brand { font-size:18px; font-weight:700; margin-bottom:22px; }
.brand small { display:block; color:var(--muted); font-size:11px; margin-top:4px; font-weight:400; }
.nav-title { color:#72798a; font-size:10px; text-transform:uppercase; letter-spacing:1px; margin:18px 8px 7px; }
.nav button { width:100%; border:0; background:transparent; color:var(--text); text-align:left;
              padding:9px 10px; border-radius:7px; cursor:pointer; }
.nav button:hover,.nav button.active { background:var(--panel2); }
.content { flex:1; display:flex; flex-direction:column; min-width:0; min-height:0; }
.topbar { padding:18px 24px 12px; border-bottom:1px solid var(--border); display:flex; gap:12px; align-items:center; }
.search { flex:1; background:var(--panel); border:1px solid var(--border); color:var(--text);
          padding:9px 12px; border-radius:8px; outline:none; }
.count { color:var(--muted); font-size:12px; white-space:nowrap; }
.main { flex:1; min-height:0; padding:20px 24px; overflow-y:auto; overflow-x:hidden; -webkit-overflow-scrolling:touch; overscroll-behavior:contain; }
h1 { margin:0 0 5px; font-size:24px; }
.subtitle { color:var(--muted); font-size:12px; margin-bottom:18px; }
.grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(330px,1fr)); gap:14px; }
.card { background:var(--panel); border:1px solid var(--border); border-radius:11px; padding:16px; }
.card-head { display:flex; align-items:center; gap:10px; }
.icon { width:36px; height:36px; border-radius:9px; background:#303441; display:grid; place-items:center; font-size:18px; }
.name { font-weight:700; flex:1; }
.status { font-size:11px; color:var(--muted); }
.dot { display:inline-block; width:7px; height:7px; border-radius:50%; margin-right:5px; background:#72798a; }
.dot.active { background:var(--green); }
.dot.error { background:var(--red); }
.desc { color:var(--muted); min-height:34px; margin:13px 0; font-size:12px; line-height:1.45; }
.hotkey { color:var(--cyan); font-family:ui-monospace,monospace; font-size:11px; }
.actions { display:flex; gap:7px; margin-top:13px; }
button.action { border:1px solid var(--border); background:#303441; color:var(--text); border-radius:7px;
                padding:7px 10px; cursor:pointer; font-size:11px; }
button.action:hover { border-color:#687083; }
button.primary { background:var(--purple); color:#17181d; border-color:var(--purple); font-weight:700; }
button.danger { color:#fff; background:#4a262c; border-color:#6c333b; }
.empty { padding:40px; text-align:center; color:var(--muted); }
.drawer { position:fixed; inset:0; background:rgba(0,0,0,.35); display:none; }
.drawer.open { display:block; }
.panel { position:absolute; right:0; top:0; height:100%; width:430px; background:#1b1d23;
         border-left:1px solid var(--border); padding:22px; overflow:auto; }
.panel h2 { margin:0; }
.field { margin:16px 0; }
.field label { display:block; color:var(--muted); font-size:11px; margin-bottom:6px; }
.field input { width:100%; background:var(--panel); border:1px solid var(--border); color:var(--text);
               padding:9px; border-radius:7px; }
.kbd { color:var(--cyan); font-family:ui-monospace,monospace; }
.close { float:right; border:0; background:transparent; color:var(--muted); font-size:20px; cursor:pointer; }
pre { white-space:pre-wrap; color:#b8c0cf; font-size:10px; }
</style>
</head>
<body>
<div class="app">
  <aside class="sidebar">
    <div class="brand">⚡ Spoons Manager<small id="version">v0.3.1</small></div>
    <div class="nav-title">Spoons</div>
    <div class="nav">
      <button class="active" data-view="local">◉ Local Spoons</button>
      <button data-view="official">☁ Official Spoons</button>
    </div>
    <div id="localFilters">
      <div class="nav-title">Local Filters</div>
      <div class="nav">
        <button class="active" data-filter="all">◉ All <span id="allCount"></span></button>
        <button data-filter="active">● Active <span id="activeCount"></span></button>
        <button data-filter="disabled">○ Disabled <span id="disabledCount"></span></button>
        <button data-filter="error">⚠ Error <span id="errorCount"></span></button>
      </div>
    </div>
    <div class="nav-title">Manager</div>
    <div class="nav">
      <button onclick="refresh()">↻ Refresh</button>
      <button onclick="showDiagnostics()">🩺 Diagnostics</button>
    </div>
  </aside>
  <section class="content">
    <div class="topbar">
      <input id="search" class="search" placeholder="Search Spoons..." oninput="render()">
      <div class="count" id="path"></div>
    </div>
    <main class="main">
      <div id="localView">
        <h1>Local Spoons</h1>
        <div class="subtitle" id="subtitle">Discovering local Spoons…</div>
        <div id="grid" class="grid"></div>
      </div>
      <div id="officialView" style="display:none">
        <h1>Official Spoons</h1>
        <div class="subtitle" id="officialSubtitle">Official Hammerspoon/Spoons catalog</div>
        <div class="actions" style="margin:0 0 16px">
          <button class="action primary" onclick="refreshOfficial()">↻ Update Official Catalog</button>
          <button class="action" onclick="openOfficialSite()">Open Official Spoons</button>
        </div>
        <div id="officialGrid" class="grid"></div>
      </div>
    </main>
  </section>
</div>

<div id="drawer" class="drawer" onclick="if(event.target===this)closeDrawer()">
  <div class="panel">
    <button class="close" onclick="closeDrawer()">×</button>
    <div id="detail"></div>
  </div>
</div>

<script>
let state = {manager:{}, spoons:{}, officialSpoons:[], officialInstallBusy:{}};
let currentFilter = "all";
let currentView = "local";

function send(obj) {
  try {
    window.webkit.messageHandlers.hammerspoon.postMessage(obj);
  } catch(e) {
    console.error(e);
  }
}
function refresh(){ send({type:"refresh"}); }
function closeDrawer(){ document.getElementById("drawer").classList.remove("open"); }

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, c => ({
    "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"
  }[c]));
}
function hotkeyText(h) {
  if (!h) return "No hotkey";
  return (h.mods || []).map(x => ({cmd:"⌘",alt:"⌥",ctrl:"⌃",shift:"⇧"}[x] || x)).join(" ") +
         (h.key ? " " + h.key : "");
}
function filteredItems() {
  const q = document.getElementById("search").value.toLowerCase().trim();
  return Object.values(state.spoons || {}).filter(s => {
    const matchFilter =
      currentFilter === "all" ||
      (currentFilter === "active" && s.enabled) ||
      (currentFilter === "disabled" && !s.enabled) ||
      (currentFilter === "error" && s.status === "error");
    const text = [s.name,s.description,s.author,s.version].join(" ").toLowerCase();
    return matchFilter && (!q || text.includes(q));
  }).sort((a,b)=>a.name.localeCompare(b.name));
}

function fuzzyScore(text, query) {
  text = String(text || "").toLowerCase();
  query = String(query || "").toLowerCase().trim();
  if (!query) return 0;
  if (text === query) return 10000;
  if (text.startsWith(query)) return 7000 - text.length;
  const pos = text.indexOf(query);
  if (pos >= 0) return 5000 - pos - text.length * 0.01;
  let qi = 0, score = 0, last = -1;
  for (let i = 0; i < text.length && qi < query.length; i++) {
    if (text[i] === query[qi]) {
      score += (last + 1 === i ? 8 : 2);
      if (i === 0 || text[i-1] === "-" || text[i-1] === "_" || text[i-1] === " ") score += 6;
      last = i; qi++;
    }
  }
  return qi === query.length ? 1000 + score - text.length * 0.01 : -1;
}
function refreshOfficial() { send({type:"official_refresh"}); }
function openOfficialSite() { send({type:"open_official_site"}); }
function renderOfficial() {
  const grid = document.getElementById("officialGrid");
  const q = document.getElementById("search").value.trim();
  const items = (state.officialSpoons || []).map(s => ({...s, _score:fuzzyScore(s.name, q)}))
    .filter(s => !q || s._score >= 0)
    .sort((a,b) => b._score - a._score || a.name.localeCompare(b.name));
  document.getElementById("path").textContent = "Official: Hammerspoon/Spoons";
  document.getElementById("officialSubtitle").textContent = state.manager.officialCatalogLoading
    ? "Loading official catalog…"
    : `${items.length} matching · ${Object.keys(state.spoons||{}).length} installed locally · Updated ${state.manager.officialCatalogUpdated || "—"}`;
  grid.innerHTML = "";
  if (!items.length) {
    grid.innerHTML = '<div class="empty">No matching official Spoons. Try a partial name such as "window", "clip", or "clock".</div>';
    return;
  }
  for (const s of items) {
    const busy = state.officialInstallBusy && state.officialInstallBusy[s.name];
    const button = s.installed
      ? `<button class="action" disabled>✓ Installed</button>`
      : `<button class="action primary" ${busy ? "disabled" : ""} onclick="installOfficial('${esc(s.name)}')">${busy ? "Downloading…" : "⬇ Download"}</button>`;
    grid.innerHTML += `
      <article class="card">
        <div class="card-head">
          <div class="icon">☁️</div>
          <div class="name">${esc(s.name)}</div>
          <div class="status">${s.installed ? "Installed" : "Available"}</div>
        </div>
        <div class="desc">${esc(s.description || "No description available.")}</div>
        <div class="actions">
          <button class="action" onclick="openSummary('${esc(s.name)}')">Summary</button>
          ${button}
          <button class="action" onclick="openOfficialSpoon('${esc(s.name)}')">Official Page</button>
        </div>
      </article>`;
  }
}
function installOfficial(name) { send({type:"official_install",name:name}); }
function openOfficialSpoon(name) { send({type:"open_official_spoon",name:name}); }

function render() {
  document.getElementById("localView").style.display = currentView === "local" ? "block" : "none";
  document.getElementById("officialView").style.display = currentView === "official" ? "block" : "none";
  document.getElementById("localFilters").style.display = currentView === "local" ? "block" : "none";
  if (currentView === "official") { renderOfficial(); return; }
  const items = filteredItems();
  const grid = document.getElementById("grid");
  document.getElementById("path").textContent = state.manager.spoonPath || "";
  document.getElementById("subtitle").textContent =
    `${Object.keys(state.spoons||{}).length} Spoons found · Last scan ${state.manager.lastScan || "—"}`;
  grid.innerHTML = "";
  if (!items.length) {
    grid.innerHTML = '<div class="empty">No matching Spoons.</div>';
    return;
  }
  for (const s of items) {
    const active = s.status === "running" || (s.enabled && s.status === "loaded");
    const dot = s.status === "error" ? "error" : (active ? "active" : "");
    const statusText = s.status || (s.enabled ? "enabled" : "disabled");
    const button = s.enabled
      ? `<button class="action danger" onclick="action('${esc(s.name)}','spoon_disable')">Disable</button>`
      : `<button class="action primary" onclick="action('${esc(s.name)}','spoon_enable')">Enable</button>`;
    grid.innerHTML += `
      <article class="card">
        <div class="card-head">
          <div class="icon">🧩</div>
          <div class="name">${esc(s.name)}</div>
          <div class="status"><span class="dot ${dot}"></span>${esc(statusText)}</div>
        </div>
        <div class="desc">${esc(s.description || "No description available.")}</div>
        <div class="hotkey">${esc(hotkeyText(s.hotkey))}</div>
        <div class="actions">
          <button class="action" onclick="openSummary('${esc(s.name)}')">Summary</button>
          <button class="action" onclick="openDetail('${esc(s.name)}')">Configure</button>
          ${button}
          <button class="action" onclick="action('${esc(s.name)}','spoon_reload')">↻ Reload</button>
          <button class="action danger" onclick="removeLocal('${esc(s.name)}')">Remove</button>
        </div>
      </article>`;
  }
}
function action(name,type){ send({type:type,name:name}); }
function removeLocal(name) {
  const s = state.spoons && state.spoons[name];
  if (!s) return;
  const path = s.path || `${name}.spoon`;
  if (!window.confirm(`Remove local Spoon "${name}"?\n\nThis will delete:\n${path}\n\nIt will not edit init.lua.`)) return;
  send({type:"spoon_remove",name:name});
  closeDrawer();
}
function renderSummary(summary) {
  const managerHK = hotkeyText(summary.managerHotkey);
  const configuredHK = hotkeyText(summary.configuredHotkey);
  const methods = (summary.methods || []).map(x => `<li><code>${esc(x)}()</code></li>`).join("") || "<li>No public obj methods detected in init.lua.</li>";
  const sourceHotkeys = (summary.sourceHotkeys || []).map(x => `<li><code>${esc(x)}</code></li>`).join("") || "<li>No hotkey declarations/comments detected in init.lua.</li>";
  const installed = !!state.spoons[summary.name];
  document.getElementById("detail").innerHTML = `
    <h2>📋 ${esc(summary.name)} Summary</h2>
    <p class="subtitle">${esc(summary.description || "No description available.")}</p>
    <div class="field"><label>Version</label><div>${esc(summary.version || "Unknown")}</div></div>
    <div class="field"><label>Author</label><div>${esc(summary.author || "Unknown")}</div></div>
    <div class="field"><label>Manager Hotkey</label><div class="kbd">${esc(managerHK)}</div></div>
    <div class="field"><label>Configured Spoon Hotkey</label><div class="kbd">${installed ? esc(configuredHK) : "Not installed / not configured in Manager"}</div></div>
    <div class="field"><label>Functions / Methods</label><ul>${methods}</ul></div>
    <div class="field"><label>Hotkey Declarations / Defaults Found in init.lua</label><ul>${sourceHotkeys}</ul></div>
    <div class="field"><label>Local Path</label><pre>${esc(summary.path || "Not installed locally")}</pre></div>
    <div class="actions">
      <button class="action primary" onclick="openOfficialSpoon('${esc(summary.name)}')">Open Official Documentation</button>
      ${installed ? `<button class="action" onclick="openDetail('${esc(summary.name)}')">Configure</button>` : ""}
    </div>
  `;
  document.getElementById("drawer").classList.add("open");
}
function openSummary(name) { send({type:"spoon_summary",name:name}); }
window.hsSpoonMgrSummary = renderSummary;

function openDetail(name) {
  const s = state.spoons[name];
  if (!s) return;
  document.getElementById("detail").innerHTML = `
    <h2>🧩 ${esc(s.name)}</h2>
    <p class="subtitle">${esc(s.description || "No description available.")}</p>
    <div class="field"><label>Version</label><div>${esc(s.version)}</div></div>
    <div class="field"><label>Author</label><div>${esc(s.author)}</div></div>
    <div class="field"><label>Status</label><div>${esc(s.status || "unknown")}</div></div>
    <div class="field"><label>Global Hotkey</label>
      <input id="hk" value="${esc((s.hotkey?.mods || []).join(",") + (s.hotkey?.mods?.length ? "," : "") + (s.hotkey?.key || ""))}"
             placeholder="cmd,alt,M">
    </div>
    <div class="actions">
      <button class="action primary" onclick="saveHotkey('${esc(s.name)}')">Save Shortcut</button>
      <button class="action" onclick="action('${esc(s.name)}','remove_hotkey')">Remove Shortcut</button>
    </div>
    <div class="field"><label>Path</label><pre>${esc(s.path)}</pre></div>
    ${s.homepage ? `<button class="action" onclick="send({type:'open_spoon_homepage',name:'${esc(s.name)}'})">Open Homepage</button>` : ""}
    <div class="actions">
      <button class="action" onclick="action('${esc(s.name)}','spoon_start')">▶ Start</button>
      <button class="action" onclick="action('${esc(s.name)}','spoon_stop')">■ Stop</button>
      <button class="action" onclick="action('${esc(s.name)}','spoon_reload')">↻ Reload</button>
    </div>
  `;
  document.getElementById("drawer").classList.add("open");
}
function saveHotkey(name) {
  const value = document.getElementById("hk").value.trim();
  if (!value) send({type:"remove_hotkey",name:name});
  else {
    const parts = value.split(",").map(x=>x.trim()).filter(Boolean);
    const key = parts.pop() || "";
    send({type:"save_hotkey",name:name,mods:parts,key:key});
  }
}
function showDiagnostics() {
  const events = (state.manager.events || []).map(e =>
    `${e.time} [${e.level}] ${e.message}`).join("\n");
  document.getElementById("detail").innerHTML =
    `<h2>🩺 Diagnostics</h2>
     <div class="field"><label>Manager</label><div>v${esc(state.manager.version)}</div></div>
     <div class="field"><label>Spoons Directory</label><pre>${esc(state.manager.spoonPath)}</pre></div>
     <div class="field"><label>Last Scan</label><div>${esc(state.manager.lastScan || "—")}</div></div>
     <div class="field"><label>Recent Events</label><pre>${esc(events || "No events.")}</pre></div>`;
  document.getElementById("drawer").classList.add("open");
}
function hsSpoonMgrReceive(payload) {
  state = payload || state;
  render();
}
window.hsSpoonMgrReceive = hsSpoonMgrReceive;

document.querySelectorAll(".nav button[data-view]").forEach(btn => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".nav button[data-view]").forEach(b=>b.classList.remove("active"));
    btn.classList.add("active");
    currentView = btn.dataset.view;
    if (currentView === "official" && !state.manager.officialCatalogLoaded) refreshOfficial();
    render();
  });
});

document.querySelectorAll(".nav button[data-filter]").forEach(btn => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".nav button[data-filter]").forEach(b=>b.classList.remove("active"));
    btn.classList.add("active");
    currentFilter = btn.dataset.filter;
    render();
  });
});

send({type:"scan"});
</script>
</body>
</html>
]]
end

function manager.refresh()
    local spoons = getSpoonsState()
    sendState()
    return spoons
end

function manager.getSpoons()
    return getSpoonsState()
end

function manager.getSpoon(name)
    return getSpoonsState()[name]
end

function manager.getOfficialSpoons()
    return getOfficialCatalogState()
end

function manager.refreshOfficialSpoons(callback)
    return fetchOfficialCatalog(callback)
end

function manager.installOfficialSpoon(name)
    return installOfficialSpoon(name)
end

function manager.loadSpoon(name)
    return loadSpoon(name)
end

function manager.startSpoon(name)
    return startSpoon(name)
end

function manager.stopSpoon(name)
    return stopSpoon(name)
end

function manager.reloadSpoon(name)
    return reloadSpoon(name)
end

function manager.enableSpoon(name)
    return enableSpoon(name)
end

function manager.disableSpoon(name)
    return disableSpoon(name)
end

function manager.setSpoonHotkey(name, mods, key)
    return setSpoonHotkey(name, mods, key)
end

function manager.removeSpoonHotkey(name)
    local cfg = loadConfig()
    local entry = getConfigEntry(cfg, name)
    entry.hotkey = nil
    saveConfig(cfg)
    deleteHotkey(name)
    sendState()
    return true
end

function manager.toggleGUI()
    if manager.webView then
        local ok, visible = pcall(function()
            return manager.webView:hswindow() and manager.webView:hswindow():isVisible()
        end)
        if ok and visible then
            manager.webView:delete()
            manager.webView = nil
            manager.ucc = nil
            return
        end
    end

    manager.ucc = hs.webview.usercontent.new("hammerspoon")
    manager.ucc:setCallback(handleMessage)

    local rect = {x = 100, y = 70, w = 1180, h = 780}
    local view = hs.webview.new(rect, {
        javaScriptEnabled = true,
        developerExtrasEnabled = true
    }, manager.ucc)

    -- hs.webview defaults allowTextEntry and trackpad gestures to false.
    -- Explicitly enable both so HTML inputs accept keyboard input and the main
    -- pane can scroll naturally with a trackpad.
    local textEntryOK, textEntryErr = pcall(function() view:allowTextEntry(true) end)
    if not textEntryOK then
        logEvent("ERROR", "Unable to enable WebView text entry: " .. tostring(textEntryErr))
    end
    local gesturesOK, gesturesErr = pcall(function() view:allowGestures(true) end)
    if not gesturesOK then
        logEvent("ERROR", "Unable to enable WebView gestures: " .. tostring(gesturesErr))
    end
    view:windowStyle({"titled", "closable", "resizable"})
    view:windowTitle("Hammerspoon Spoons Manager")
    view:html(generateHTML())
    view:show()

    manager.webView = view
    hs.timer.doAfter(0.20, function()
        -- Explicitly make the WebView window key so HTML inputs and trackpad
        -- scroll events are delivered to the page on macOS.
        pcall(function()
            local window = view:hswindow()
            if window then window:focus() end
        end)
        manager.refresh()
        hs.timer.doAfter(0.10, function()
            if manager.webView then
                pcall(function()
                    manager.webView:evaluateJavaScript("document.getElementById('search')?.focus();")
                end)
            end
        end)
    end)
end

local function bindManagerHotkey()
    local cfg = loadConfig()
    local hk = cfg.managerHotkey or DEFAULT_CONFIG.managerHotkey

    if manager.managerHotkey then
        pcall(function() manager.managerHotkey:delete() end)
        manager.managerHotkey = nil
    end

    local ok, bind = pcall(function()
        return hs.hotkey.bind(hk.mods, hk.key, "Spoons Manager", manager.toggleGUI)
    end)

    if ok then
        manager.managerHotkey = bind
    else
        logEvent("ERROR", "Unable to bind Manager hotkey: " .. tostring(bind))
    end
end

-- Module initialization.
-- require("hs_spoonsmgr") should only initialize the manager itself;
-- it must not own unrelated init.lua functionality or open the GUI.
local function restoreEnabledSpoons()
    -- Restore persisted Enabled state during require(), not only when the GUI opens.
    -- This makes Enable survive Hammerspoon Reload Config while keeping init.lua clean.
    local ok, discovered = pcall(discoverSpoons)
    if not ok or type(discovered) ~= "table" then
        logEvent("ERROR", "Unable to restore enabled Spoons during initialization: " .. tostring(discovered))
        return false
    end

    local syncOK, syncErr = pcall(function()
        synchronizeRuntime(discovered)
        refreshHotkeys(discovered)
    end)

    if not syncOK then
        logEvent("ERROR", "Unable to restore enabled Spoons: " .. tostring(syncErr))
        return false
    end

    return true
end

local function initialize()
    if manager.initialized then return manager end

    loadConfig()
    ensurePackagePath(manager.spoonPath)
    bindManagerHotkey()
    restoreEnabledSpoons()
    manager.initialized = true
    return manager
end

initialize()

return manager
