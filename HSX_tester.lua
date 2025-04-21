local HSX_tester = {}
local HSX_TESTER_PREFIX = "[HSX_tester] "

tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Loading, please wait...")

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus)
    tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: OnServerPostInit")

    tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Get Load Order")
    local loadOrderCopy = {}
    for _, script in ipairs(HSX.GetLoadOrder()) do
        table.insert(loadOrderCopy, script)
    end

    tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."Remove HSX and hsx_tester from Load Order")
    loadOrderCopy = removeScriptsByName(loadOrderCopy, {"custom.HSX", "custom.hsx_tester"})
    tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Get Load Order")

    local loadOrderMsg = printLoadOrder(loadOrderCopy)
    tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Attempting to unload all scripts")
    
    for _, script in ipairs(loadOrderCopy) do
        local scriptID = HSX.getScriptIDByFilename(script.name)
        if scriptID then
            HSX.unregisterAllByScriptID(scriptID)
            tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."Unregistered all events for script: " .. script.name)
        else
            tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."Failed to get script ID for: " .. script.name)
        end
    end

    tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Attempting to load all the previous scripts")
    for _, script in ipairs(loadOrderCopy) do
        require(script.name)
    end

    local updatedLoadOrder = HSX.GetLoadOrder()
    tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Finished reloading scripts, getting updated Load Order")
    loadOrderMsg = printLoadOrder(updatedLoadOrder)
    tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Attempting to load a script that doesn't exist")
    local success, err = pcall(function()
        require("custom.non_existent_script", "hsx_tester", true)
    end)
    if not success then
        tes3mp.LogMessage(enumerations.log.ERROR, HSX_TESTER_PREFIX.."Failed to load non_existent_script: \n" .. err)
    end

    tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Attempting to load a script already loaded")
    local success, err = pcall(function()
        require("custom.HotaruBlaze.chatUtils.chatUtils", "hsx_tester")
    end)
    if not success then
        tes3mp.LogMessage(enumerations.log.ERROR, HSX_TESTER_PREFIX.."Failed to load chatUtils: \n" .. err)
    else
        tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Successfully loaded chatUtils")
        tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Attempting to access chatUtils")
        local success, err = pcall(function()
            local chu = require("custom.HotaruBlaze.chatUtils.chatUtils", "hsx_tester")
            local getAllColors = chu.gatherColors()
            tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."HSX_tester: Color count: " .. #getAllColors)
        end)
        if not success then
            tes3mp.LogMessage(enumerations.log.ERROR, HSX_TESTER_PREFIX.."Failed to access chatUtils: \n" .. err)
        end 
    end
end)

function removeScriptsByName(loadOrder, scriptsToRemove)
    for i = #loadOrder, 1, -1 do
        local script = loadOrder[i]
        for _, name in ipairs(scriptsToRemove) do
            if script.name == name then
                table.remove(loadOrder, i)
                tes3mp.LogMessage(enumerations.log.INFO, HSX_TESTER_PREFIX.."Removed " .. name .. " from Load Order at index " .. i)
                break
            end
        end
    end
    return loadOrder
end

function printLoadOrder(loadOrder)
    local loadOrderMsg = "Load Order:\n"
    for index, script in ipairs(loadOrder) do
        loadOrderMsg = loadOrderMsg .. string.format("%d: %s\n", index, script.name)
    end
    print(loadOrderMsg)
    return loadOrderMsg
end
