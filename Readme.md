# Overview

**HSX (Hotarublaze's Script Extender)** is a specialized script extender for [TES3MP](https://github.com/TES3MP/TES3MP) designed to **replace** the default server-side event hooking system. It provides a more robust and developer-friendly foundation for managing custom scripts.

# Why Use HSX?
TES3MP’s built-in scripting system allows you to load scripts with `customScripts.lua` or at ingame using the `/load` command. However, it doesn’t support unloading scripts, and reloading them can result in duplicate event hooks being registered each time a script is loaded. There’s no native mechanism to unregister event hooks.

HSX enhances this system by introducing:

*   **Safely Unload & Reload Scripts:** Fully remove old script instances and reload new versions cleanly *during runtime*.
*   **Automatic Hook Management**: Prevents duplicate event registration by unregistering old hooks before reloading.
*   **Unified Require Paths:** Normalizes all script paths so they resolve consistently (custom/example will always be required as custom.example), avoiding accidental misloads from path variations.
*   **Extended Require Tracking**: Modifies Lua's require to track load order and prevent accidental re-requires.

## Installation

1.  **Copy `HSX.lua`:**
    Place the `HSX.lua` file into your server's primary custom scripts directory (usually `server/scripts/custom/`).

2.  **Edit `customScripts.lua`:**
    Open your `server/scripts/customScripts.lua` file (or the main file where you `require` your custom scripts).
    Add the following line **at the very top** of the file:

    ```lua
    HSX = require("custom.HSX")
    ```

    ⚠️ **Important:** HSX **must** be the first script required in your `customScripts.lua` to ensure it correctly overwrites the default functions before other scripts attempt to use them.

---

# Additional API provided by HSX
HSX provides several utility functions to support script management, hook cleanup, and diagnostics.

---

### `HSX.generateScriptID(filePath)`
Generates a **unique script ID** (UUID-like string) for the provided file path, or returns the existing ID if the script is already loaded.

This function ensures that each script has a consistent ID across reloads and restarts. If a script ID already exists for a given path, it simply returns that ID instead of regenerating it.

**Example:**
```lua
local id = HSX.generateScriptID("custom.myscript")
-- returns an existing ID if already loaded, or generates a new one like "a14b9661-6138-068a-df80-3f325fb09fd1"
```

**Note:** If the filePath is invalid, the function will return `nil`.

---

### `HSX.getScriptID(filePath)`
Returns the script ID if the script is currently loaded, or `nil` otherwise.

**Example:**
```lua
local id = HSX.getScriptID("custom.myscript")
if id then
    tes3mp.LogMessage(enumerations.log.INFO, "Script ID: " .. id)
end
```

---

### `HSX.getScriptIDByFilename(filename)`
Returns the associated script ID based on a raw filename (e.g., `"custom.myscript.lua"`). Useful when you only have the file name.

**Example:**
```lua
local id = HSX.getScriptIDByFilename("custom.myscript.lua")
if id then
    tes3mp.LogMessage(enumerations.log.INFO, "Script ID: " .. id)
end
```

---

### `HSX.unregisterAllByScriptID(scriptID)`
Unregisters all validator and handler hooks associated with a script ID. This is called automatically on script unload, but can also be used manually.

**Example:**
```lua
HSX.unregisterAllByScriptID("a14b9661-6138-068a-df80-3f325fb09fd1")
```

---

### `HSX.GetLoadOrder()`
-- Returns an ordered list (table) of all currently loaded script IDs.

**Example:**
```lua
local loadOrder = HSX.GetLoadOrder()
local scriptLog = {}

for index, script in ipairs(loadOrder) do
    if script.moduleTag then
        scriptLog[index] = string.format(scriptLogPrefix.."[%d][%s] %s (ScriptID: %s)", index, script.moduleTag, script.name, script.scriptID)
    else
        scriptLog[index] = string.format(scriptLogPrefix.."[%d][ ] %s (ScriptID: %s)", index, script.name, script.scriptID)
    end
end

tes3mp.LogMessage(enumerations.log.INFO, 'Load Order:\n' .. table.concat(scriptLog, "\n"))
-- Example Output:
-- [2025-04-21 13:21:40] [INFO]: [Script]: [HSX]: Load Order:
-- [HSX]: [1][M] custom.hotarublaze.hsx (ScriptID: a14b9661-6138-068a-df80-3f325fb09fd1)
-- [HSX]: [2][ ] custom.rickoff.preventequipmerchant.preventmerchantequipfix (ScriptID: b4f0a591-c072-c86a-134f-499d7c0d4983)
-- [HSX]: [3][ ] custom.rickoff.bagscript.bagscript (ScriptID: 928b0d5d-baab-1d97-d280-e9bc43fc112a)
-- [HSX]: [4][ ] custom.hotarublaze.chatutils (ScriptID: b24ba857-89ab-c9e5-2283-29aadc73d9a4)

```