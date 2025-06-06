--[[
 Hotarublaze's Script Extender (HSX)
 Version: 1.0.0
 Description: HSX is a lightweight, customizable event hook extender for TES3MP.
   Designed for easy integration into existing setups, HSX allows users to inject custom script functionality, 
   reload or unload scripts dynamically, and manage script IDs without complex configuration. 
   
  **AI-Generated Comments:**
  This code has been annotated with comments generated by an AI. 
  While the AI aimed to make the comments clear and helpful, some of the explanations may not be entirely accurate or may lack some context specific to the code's intended use.
  Please review the comments for clarity and correctness before fully relying on them.
]]

local customEventHooks = customEventHooks or {}
local HSX = HSX or {}
local enableDebugger = false -- Set to true to enable debugging

-- Log message indicating that the hook override is loading
local scriptLogPrefix = "[HSX]: "
tes3mp.LogMessage(enumerations.log.INFO, "[Hotarublaze's Script Extender]: Initializing...")
hsxScriptName = debug.getinfo(1, "S").source:sub(2):normalizePath()


-- Create a table to manage script IDs and UUIDs
customEventHooks.scriptID = customEventHooks.scriptID or {
    handlers = {},
    validators = {},
    generatedScriptIDs = {},
    loadOrder = {}
}

local template = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

-- Function to normalize file paths for consistency
function string:normalizePath()
    local normalized = self:gsub("\\", "/")          -- Replace backslashes with forward slashes
                      :gsub("^%./", "")              -- Remove leading "./"
                      :gsub("%.lua$", "")            -- Remove ".lua" extension
                      :gsub("/", ".")                -- Replace slashes with dots
                      :lower()                       -- Convert the path to lowercase

    local customIndex = normalized:find("custom")
    if customIndex then
        normalized = normalized:sub(customIndex)
    end
    return normalized
end

function HSX.GenerateIngameInfo(message)
    return string.format(color.DarkGrey.."%s"..color.Grey.."%s", scriptLogPrefix, message)
end

function HSX.GenerateIngameError(message)
    return string.format(color.DarkGrey.."%s"..color.DarkRed.."%s", scriptLogPrefix, message)
end

-- Generate a unique ID (UUID) for a script
function HSX.generateScriptID(filePath)
    if not string.match(filePath, "%S") then
        tes3mp.LogMessage(enumerations.log.ERROR, '[EventHookOverride]: Invalid file path for ScriptID generation.')
        return nil
    end

    filePath = filePath:normalizePath()

    if enableDebugger then
        local stacktrace = debug.traceback("Stack trace:", 2)
        print(stacktrace)
    end


    -- Check if a ScriptID already exists for this path
    if customEventHooks.scriptID.generatedScriptIDs[filePath] then
        tes3mp.LogMessage(enumerations.log.WARN, scriptLogPrefix .. 'ScriptID already exists for: "' .. filePath .. '". Returning the existing ScriptID.')
        return customEventHooks.scriptID.generatedScriptIDs[filePath]
    end

    -- Generate a new UUID based on the file path
    local seed = 0
    for i = 1, #filePath do
        seed = seed + string.byte(filePath, i)
    end
    math.randomseed(os.time() + seed)

    local scriptID = template:gsub("x", function() return string.format("%x", math.random(0, 15)) end)
    customEventHooks.scriptID.generatedScriptIDs[filePath] = scriptID
    tes3mp.LogMessage(enumerations.log.VERBOSE, scriptLogPrefix .. 'Generated ScriptID for script: "' .. filePath .. '" is ' .. scriptID)

    return scriptID
end

-- Get the ScriptID for a given file path
function HSX.getScriptID(filePath)
    if not filePath then return nil end

    local normalizedPath = filePath:normalizePath()

    if customEventHooks.scriptID.generatedScriptIDs[normalizedPath] then
        tes3mp.LogMessage(enumerations.log.VERBOSE, scriptLogPrefix .. '[getScriptID]: Found ScriptID for "' .. normalizedPath .. '" is ' .. customEventHooks.scriptID.generatedScriptIDs[normalizedPath])
        return customEventHooks.scriptID.generatedScriptIDs[normalizedPath]
    else
        tes3mp.LogMessage(enumerations.log.VERBOSE, scriptLogPrefix .. 'ScriptID not found for "' .. normalizedPath .. '"')
        return nil
    end
end

local originalRequire = require

-- Override the require function to handle custom modules
function require(moduleName, moduleTag, allowFailure)
    -- Only override if the module is a custom script
    local isCustomScript = type(moduleName) == "string" and (moduleName:sub(1, 7):lower() == "custom/" or moduleName:sub(1, 7):lower() == "custom.")
    if isCustomScript then
        local callingScript = debug.getinfo(4, "S").source:sub(2):normalizePath()
        moduleName = moduleName:normalizePath()

        -- Check if the module is already loaded
        -- This doesnt really work as intended so lets just comment it out for now
        -- if package.loaded[moduleName] then
        --     tes3mp.LogMessage(enumerations.log.WARN, scriptLogPrefix .. 'The script "' .. moduleName .. '" is already loaded.')
        --     tes3mp.LogMessage(enumerations.log.WARN, scriptLogPrefix .. "HSX will not register multiple eventHooks for the same script.")
        -- end

        tes3mp.LogMessage(enumerations.log.VERBOSE, scriptLogPrefix .. 'Loading script: "' .. moduleName .. '"')

        -- If the module hasn't been loaded before, generate a new ScriptID
        if not customEventHooks.scriptID.generatedScriptIDs[moduleName] then
            local scriptID = HSX.generateScriptID(moduleName)
            if scriptID then
                table.insert(customEventHooks.scriptID.loadOrder, { name = moduleName, scriptID = scriptID, moduleTag = moduleTag or nil })
            end
        end
    end

    -- Append the module to the global table

    -- Call the original require function
    local success, result = pcall(originalRequire, moduleName)

    if not success then
        tes3mp.LogMessage(enumerations.log.ERROR, scriptLogPrefix .. 'Failed to load script: "' .. moduleName .. '". Error: ' .. result)
        if not allowFailure then
            tes3mp.LogMessage(enumerations.log.ERROR, scriptLogPrefix .. 'Exiting server due to failed script load.')
            os.exit(1) -- Exit the server if the script fails to load
        else
            tes3mp.LogMessage(enumerations.log.INFO, scriptLogPrefix .. 'Allowing failure for script: "' .. moduleName .. '", proceeding without it.')
        end
        return nil
    end

    if type(result) == "table" and isCustomScript then
        -- Use last part of module name as global name (e.g., "custom/foo/bar" → "bar")
        local globalName = moduleName:match("([^/\\]+)$"):gsub("%.lua$", "")
        _G[globalName] = result
        tes3mp.LogMessage(enumerations.log.VERBOSE, scriptLogPrefix .. 'Injected "' .. globalName .. '" into _G')
    end

    if isCustomScript then
        tes3mp.LogMessage(enumerations.log.VERBOSE, scriptLogPrefix .. 'Loaded script: "' .. moduleName .. '"')
    end

    return result
end

-- Register a validator for a specific event
function customEventHooks.registerValidator(event, callback)
    local filePath = debug.getinfo(2, "S").source:sub(2):normalizePath()
    local scriptID = HSX.getScriptID(filePath) or HSX.generateScriptID(filePath)

    if not customEventHooks.validators[event] then
        customEventHooks.validators[event] = {}
    end

    table.insert(customEventHooks.validators[event], callback)
    customEventHooks.scriptID.validators[scriptID] = customEventHooks.scriptID.validators[scriptID] or {}
    table.insert(customEventHooks.scriptID.validators[scriptID], { event, callback })

    tes3mp.LogMessage(enumerations.log.VERBOSE, string.format(scriptLogPrefix..'[validator]: Registered event "%s" with ScriptID "%s"', event, scriptID))
    return scriptID
end

function customEventHooks.registerHandler(event, callback)
    local filePath = debug.getinfo(2, "S").source:sub(2):normalizePath()
    local scriptID = HSX.getScriptID(filePath) or HSX.generateScriptID(filePath)

    if not customEventHooks.handlers[event] then
        customEventHooks.handlers[event] = {}
    end

    table.insert(customEventHooks.handlers[event], callback)
    customEventHooks.scriptID.handlers[scriptID] = customEventHooks.scriptID.handlers[scriptID] or {}
    table.insert(customEventHooks.scriptID.handlers[scriptID], { event, callback })

    tes3mp.LogMessage(enumerations.log.VERBOSE, string.format(scriptLogPrefix..'[handler]: Registered event "%s" with ScriptID "%s"', event, scriptID))
    return scriptID
end

local originalTriggerValidators = customEventHooks.triggerValidators
function customEventHooks.triggerValidators(event, args)
    return originalTriggerValidators(event, args)
end

local originalTriggerHandlers = customEventHooks.triggerHandlers
function customEventHooks.triggerHandlers(event, eventStatus, args)
    return originalTriggerHandlers(event, eventStatus, args)
end

function customEventHooks.unregisterEventsByType(scriptID, registerType)
    local events = customEventHooks.scriptID[registerType][scriptID]
    if not events then return end

    for _, eventInfo in ipairs(events) do
        local event = eventInfo[1]
        local callback = eventInfo[2]

        local registrations = customEventHooks[registerType][event]
        for i, registeredCallback in ipairs(registrations) do
            if registeredCallback == callback then
                table.remove(registrations, i)
                break
            end
        end
    end

    customEventHooks.scriptID[registerType][scriptID] = nil
end

function HSX.unregisterAllByScriptID(scriptID)
    customEventHooks.unregisterEventsByType(scriptID, "validators")
    customEventHooks.unregisterEventsByType(scriptID, "handlers")

    local scriptName = nil
    for filePath, id in pairs(customEventHooks.scriptID.generatedScriptIDs) do
        if id == scriptID then
            scriptName = filePath:normalizePath()
            customEventHooks.scriptID.generatedScriptIDs[filePath] = nil
            tes3mp.LogMessage(enumerations.log.VERBOSE, scriptLogPrefix .. 'Removed ScriptID "' .. scriptID .. '" for file "' .. filePath .. '".')
            break
        end
    end

    for index, script in ipairs(customEventHooks.scriptID.loadOrder) do
        if script.scriptID == scriptID then
            table.remove(customEventHooks.scriptID.loadOrder, index)
            tes3mp.LogMessage(enumerations.log.VERBOSE, scriptLogPrefix .. 'Removed script "' .. script.name .. '" from load order.')
            break
        end
    end

    if scriptName and package.loaded[scriptName] then
        package.loaded[scriptName] = nil
        tes3mp.LogMessage(enumerations.log.INFO, scriptLogPrefix .. 'Removed script "' .. scriptName .. '" from package.loaded.')
    end
end

function HSX.getScriptIDByFilename(filename)
    if not filename then
        tes3mp.LogMessage(enumerations.log.ERROR, scriptLogPrefix .. 'Filename is nil. Cannot retrieve ScriptID.')
        return nil
    end

    local filename = filename:normalizePath()
    local scriptID = customEventHooks.scriptID.generatedScriptIDs[filename]
    if scriptID then
        tes3mp.LogMessage(enumerations.log.VERBOSE, scriptLogPrefix .. 'Found ScriptID for filename "' .. filename .. '": ' .. scriptID)
        return scriptID
    else
        tes3mp.LogMessage(enumerations.log.VERBOSE, scriptLogPrefix .. 'No ScriptID found for filename "' .. filename .. '".')
        return nil
    end
end

function HSX.GetLoadOrder()
    return customEventHooks.scriptID.loadOrder
end

local function loadCustomScript(pid, cmd)
    if #cmd < 2 then
        tes3mp.SendMessage(pid, HSX.GenerateIngameInfo("Usage: /load <scriptName>\n"), false)
        return
    end

    local scriptName = tableHelper.concatenateFromIndex(cmd, 2):normalizePath()
    local scriptID = HSX.getScriptIDByFilename(scriptName)
    local actionMessage = ""

    if scriptID then
        HSX.unregisterAllByScriptID(scriptID)
        tes3mp.LogMessage(enumerations.log.INFO, scriptLogPrefix .. "Reloading script: " .. scriptName)
        actionMessage = "reloaded"
    else
        actionMessage = "loaded"
    end

    local success, result = pcall(function()
        return require(scriptName)
    end)

    if success and result then
        tes3mp.SendMessage(pid, HSX.GenerateIngameInfo("Successfully " .. actionMessage .. " script: " .. color.Grey .. scriptName .. "\n"), false)
    else
        tes3mp.SendMessage(pid, HSX.GenerateIngameError("Failed to load script: " .. scriptName .. ", See console log for more details.\n"), false)
    end
end

local function unloadCustomScript(pid, cmd)
    if #cmd < 2 then
        tes3mp.SendMessage(pid, HSX.GenerateIngameInfo("Usage: /unload <scriptName>\n"), false)
        return
    end

    local scriptName = tableHelper.concatenateFromIndex(cmd, 2):normalizePath()
    local scriptID = HSX.getScriptIDByFilename(scriptName)

    if scriptID then
        HSX.unregisterAllByScriptID(scriptID)
        tes3mp.SendMessage(pid, HSX.GenerateIngameInfo("Successfully unloaded script: " ..color.Grey.. scriptName .. "\n"), false)
    else
        tes3mp.SendMessage(pid, HSX.GenerateIngameInfo("Script not found or not loaded: " ..color.Grey.. scriptName .. "\n"), false)
    end
end

-- Add HSX to the load order as the first entry
local hsxScriptID = HSX.generateScriptID(hsxScriptName)
table.insert(customEventHooks.scriptID.loadOrder, 1, { name = hsxScriptName, scriptID = hsxScriptID, moduleTag = "M" })

-- Register a handler for the server's initialization
customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    local customScripts = {}
    local coreScripts = {}
    local scriptLog = {}

    local customIndex = 1
    local coreIndex = 1
    for scriptName in pairs(customEventHooks.scriptID.generatedScriptIDs) do
        if scriptName:sub(1, 7) == "custom." then
            customScripts[customIndex] = scriptName
            customIndex = customIndex + 1
        else
            coreScripts[coreIndex] = scriptName
            coreIndex = coreIndex + 1
        end
    end

    for index, script in ipairs(customEventHooks.scriptID.loadOrder) do
        if script.moduleTag then
            scriptLog[index] = string.format(scriptLogPrefix.."[%d][%s] %s (ScriptID: %s)", index, script.moduleTag, script.name, script.scriptID)
        else
            scriptLog[index] = string.format(scriptLogPrefix.."[%d][ ] %s (ScriptID: %s)", index, script.name, script.scriptID)
        end
    end

    tes3mp.LogMessage(enumerations.log.INFO, scriptLogPrefix .. 'Total core scripts loaded: ' .. #coreScripts)
    tes3mp.LogMessage(enumerations.log.INFO, scriptLogPrefix .. 'Total custom scripts loaded: ' .. #customScripts)
    tes3mp.LogMessage(enumerations.log.INFO, scriptLogPrefix .. 'Total ScriptIDs generated: ' .. (#coreScripts + #customScripts))

    tes3mp.LogMessage(enumerations.log.INFO, scriptLogPrefix .. 'Load Order:\n' .. table.concat(scriptLog, "\n"))
end)

customCommandHooks.registerCommand("load", loadCustomScript)
customCommandHooks.setRankRequirement("load", 2)

customCommandHooks.registerCommand("unload", unloadCustomScript)
customCommandHooks.setRankRequirement("unload", 2)

return HSX
