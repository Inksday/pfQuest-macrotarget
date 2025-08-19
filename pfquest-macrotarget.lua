-- pfquest-macrotarget.lua
local ADDON_NAME = ...
local TARGET_MACRO = "pfTarget"
local TARGET_ICON = 1
local ITEM_MACRO = "pfItem"
local lastMob, lastItem = nil, nil

-- Toggles
local autoDebug = true
local autoTarget = true
local autoItem = true

-- Utility function to print messages only to you if debug is on
local function Print(msg)
    if autoDebug and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99pfQuest-MacroTarget:|r " .. msg)
    end
end

-- Extract mob name from objective data
local function ExtractMobName(objData)
    if objData.spawn and objData.spawn[1] and objData.spawn[1].name then
        return objData.spawn[1].name
    elseif objData.type == "mob" and objData.title then
        return objData.title
    end
    return nil
end

-- Update or create the mob-target macro
local function UpdateTargetMacro(mobName)
    if not autoTarget then return end
    if not mobName or mobName == "" or mobName == lastMob then return end
    lastMob = mobName

    local body = string.format([[
/target %s
/run SetRaidTarget("target",8)
/stopmacro [nodead]
/targetlasttarget
]], mobName)

    local macroId = GetMacroIndexByName(TARGET_MACRO)
    if macroId == 0 then
        CreateMacro(TARGET_MACRO, TARGET_ICON, body, 1)
        Print("Created target macro for " .. mobName)
    else
        EditMacro(macroId, TARGET_MACRO, TARGET_ICON, body, 1, 1)
        Print("Updated target macro for " .. mobName)
    end
end

-- Update or create the item-use macro
local function UpdateItemMacro(itemID)
    if not autoItem then return end
    if not itemID or itemID == lastItem then return end
    lastItem = itemID

    local itemName, _, itemIcon, _, _, _, _, _, _, itemLink = GetItemInfo(itemID)
    if not itemLink then return end

    local body = string.format("#showtooltip %s\n/use %s", itemLink, itemLink)
    local macroId = GetMacroIndexByName(ITEM_MACRO)
    if macroId == 0 then
        CreateMacro(ITEM_MACRO, itemIcon or 1, body, 1)
        Print("Created item macro for " .. itemLink)
    else
        EditMacro(macroId, ITEM_MACRO, itemIcon or 1, body, 1, 1)
        Print("Updated item macro for " .. itemLink)
    end
end

-- Parse arrow description for kill or loot objectives
local function ParseArrowText(text)
    if not text or text == "" then return nil, nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")

    -- Loot [Item] from [Mob]
    local item, mob = text:match("[Ll]oot%s+%[(.-)%]%s+from%s+%[?(.-)%]?$")
    if item and mob then
        item = item:gsub("%[",""):gsub("%]",""):gsub("%.$",""):gsub("^%s+",""):gsub("%s+$","")
        mob = mob:gsub("%[",""):gsub("%]",""):gsub("%.$",""):gsub("^%s+",""):gsub("%s+$","")
        return mob, item
    end

    -- Kill MobName
    local kill = text:match("^[Kk]ill%s+(.+)$")
    if kill then
        kill = kill:gsub(":.*$",""):gsub("%.$",""):gsub("^%s+",""):gsub("%s+$","")
        return kill, nil
    end

    return nil, nil
end

-- Hook function to read the current first objective from pfQuest
local function OnArrowUpdate()
    if not pfQuest or not pfQuest.route or not pfQuest.route.coords then return end
    local target = pfQuest.route.coords[1]
    if not target or not target[3] then return end

    local objData = target[3]
    local mobName, itemID

    if objData.type == "mob" then
        mobName = ExtractMobName(objData)
    elseif objData.type == "useitem" and objData.itemreq then
        itemID = objData.itemreq
    end

    if pfQuest.route.arrow and pfQuest.route.arrow.description then
        local text = pfQuest.route.arrow.description:GetText() or ""
        local parsedMob, parsedItem = ParseArrowText(text)
        if parsedMob then mobName = parsedMob end
        if parsedItem and not itemID then
            itemID = tonumber(parsedItem) or parsedItem
        end
    end

    if mobName then UpdateTargetMacro(mobName) end
    if itemID then UpdateItemMacro(itemID) end
end

-- Check if arrow exists yet, and hook OnUpdate
local function CheckArrow()
    if pfQuest and pfQuest.route and pfQuest.route.arrow then
        pfQuest.route.arrow:HookScript("OnUpdate", OnArrowUpdate)
        Print("Hooked into pfQuest arrow OnUpdate")
        return true
    end
    return false
end

-- Polling frame until pfQuest arrow exists
local f = CreateFrame("Frame")
f.elapsed = 0
f:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 1 then
        self.elapsed = 0
        if CheckArrow() then
            self:SetScript("OnUpdate", nil)
        end
    end
end)

-- Slash command to manually force macro update or toggle settings
SLASH_PFQUESTMACRO1 = "/pfmacro"
SlashCmdList["PFQUESTMACRO"] = function(msg)
    msg = msg:lower()
    if msg == "debug" then
        autoDebug = not autoDebug
        Print("Debug messages " .. (autoDebug and "enabled" or "disabled"))
        return
    elseif msg == "target" then
        autoTarget = not autoTarget
        Print("Target macro " .. (autoTarget and "enabled" or "disabled"))
        return
    elseif msg == "item" then
        autoItem = not autoItem
        Print("Item macro " .. (autoItem and "enabled" or "disabled"))
        return
    end

    -- Manual update
    if not pfQuest or not pfQuest.route or not pfQuest.route.coords then
        Print("pfQuest arrow not ready yet.")
        return
    end
    local target = pfQuest.route.coords[1]
    if not target or not target[3] then
        Print("No active quest objective found.")
        return
    end

    local objData = target[3]
    local mobName, itemID

    if objData.type == "mob" then
        mobName = ExtractMobName(objData)
    elseif objData.type == "useitem" and objData.itemreq then
        itemID = objData.itemreq
    end

    if pfQuest.route.arrow and pfQuest.route.arrow.description then
        local text = pfQuest.route.arrow.description:GetText() or ""
        local parsedMob, parsedItem = ParseArrowText(text)
        if parsedMob then mobName = parsedMob end
        if parsedItem then
            itemID = tonumber(parsedItem) or parsedItem
        end
    end

    if mobName and autoTarget then
        UpdateTargetMacro(mobName)
        Print("Manual target update executed for " .. mobName)
    elseif itemID and autoItem then
        UpdateItemMacro(itemID)
        Print("Manual item update executed for item ID " .. itemID)
    else
        Print("Current objective is not targetable or useable.")
    end
end

-- Add the panel safely on PLAYER_LOGIN
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not pfQuest then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99pfQuest-MacroTarget:|r Error: pfQuest not detected. Options panel not registered.")
        return
    end

    -- Ensure saved table exists
    pfMacroConfig = pfMacroConfig or {}
    pfMacroConfig.autoDebug  = pfMacroConfig.autoDebug  ~= false -- default true
    pfMacroConfig.autoTarget = pfMacroConfig.autoTarget ~= false -- default true
    pfMacroConfig.autoItem   = pfMacroConfig.autoItem   ~= false -- default true

    -- Initialize local toggle variables from saved table
    autoDebug  = pfMacroConfig.autoDebug
    autoTarget = pfMacroConfig.autoTarget
    autoItem   = pfMacroConfig.autoItem

    -- Create options panel
    PFQuestMacroTargetOptions = CreateFrame("Frame", "PFQuestMacroTargetOptionsFrame")
    PFQuestMacroTargetOptions.name = "pfQuest-MacroTarget"

    -- Title
    local title = PFQuestMacroTargetOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("pfQuest-MacroTarget Options")

    -- Debug checkbox
    local debugCheckbox = CreateFrame("CheckButton", nil, PFQuestMacroTargetOptions, "InterfaceOptionsCheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    debugCheckbox.Text:SetText("Enable debug messages")
    debugCheckbox:SetChecked(autoDebug)
    debugCheckbox:SetScript("OnClick", function(self)
        autoDebug = self:GetChecked()
        pfMacroConfig.autoDebug = autoDebug
        if autoDebug then 
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99pfQuest-MacroTarget:|r Debug messages enabled") 
        else 
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99pfQuest-MacroTarget:|r Debug messages disabled") 
        end
    end)

    -- Target macro checkbox
    local targetCheckbox = CreateFrame("CheckButton", nil, PFQuestMacroTargetOptions, "InterfaceOptionsCheckButtonTemplate")
    targetCheckbox:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 0, -8)
    targetCheckbox.Text:SetText("Enable target macro")
    targetCheckbox:SetChecked(autoTarget)
    targetCheckbox:SetScript("OnClick", function(self)
        autoTarget = self:GetChecked()
        pfMacroConfig.autoTarget = autoTarget
        if autoDebug then 
            Print("Target macro " .. (autoTarget and "enabled" or "disabled")) 
        end
    end)

    -- Item macro checkbox
    local itemCheckbox = CreateFrame("CheckButton", nil, PFQuestMacroTargetOptions, "InterfaceOptionsCheckButtonTemplate")
    itemCheckbox:SetPoint("TOPLEFT", targetCheckbox, "BOTTOMLEFT", 0, -8)
    itemCheckbox.Text:SetText("Enable item macro")
    itemCheckbox:SetChecked(autoItem)
    itemCheckbox:SetScript("OnClick", function(self)
        autoItem = self:GetChecked()
        pfMacroConfig.autoItem = autoItem
        if autoDebug then 
            Print("Item macro " .. (autoItem and "enabled" or "disabled")) 
        end
    end)

    -- Manual refresh button
    local refreshButton = CreateFrame("Button", nil, PFQuestMacroTargetOptions, "UIPanelButtonTemplate")
    refreshButton:SetPoint("TOPLEFT", itemCheckbox, "BOTTOMLEFT", -2, -16)
    refreshButton:SetSize(140, 24)
    refreshButton:SetText("Refresh Macro")
    refreshButton:SetScript("OnClick", function()
        SlashCmdList["PFQUESTMACRO"]("") -- call manual update
    end)

    -- Initialize panel settings
    PFQuestMacroTargetOptions.okay = function()
        pfMacroConfig.autoDebug = autoDebug
        pfMacroConfig.autoTarget = autoTarget
        pfMacroConfig.autoItem = autoItem
    end
    PFQuestMacroTargetOptions.refresh = function()
        debugCheckbox:SetChecked(autoDebug)
        targetCheckbox:SetChecked(autoTarget)
        itemCheckbox:SetChecked(autoItem)
    end

    InterfaceOptions_AddCategory(PFQuestMacroTargetOptions)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99pfQuest-MacroTarget:|r Options panel registered")
end)