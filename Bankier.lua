Bankier = CreateFrame("Frame")

Bankier.Help = {
    ["usage"] = "Use '|y|/bankier help|<|' for general help",
    ["help"] = {
        "Use '|y|/bankier command [args]|<|'",
        "",
        "commands:",
        "  add <item-link> <level> [+<high threshold>] [-<low threshold>]"
    },
    ["add"] = {
        "Help for: |y|/bankier add <item-link> <level> [+<high threshold>] [-<low threshold>]|<|",
        "|g|arguments:|<|",
        "  item-link: Shift-Click on an item in your inventory to get this",
        "  level: The number of units to keep in your inventory",
        "  high threshold: How many |Y|extra|<| units before the addon starts notifying you of surplus",
        "  low threshold: How many |Y|fewer|<| units before the addon starts notifying you of a deficit",
        "|g|examples:|<|",
        "  |y|/bankier add [Healing Potion] 20 +5 -3|<|",
        "    * Will try to keep 20 units of [Healing Potion] at all times",
        "    * Will start notifying you if you get above 25 (20 + 5)",
        "    * Will start notifying you if you get below 17 (20 - 3)",
    }
}

function Bankier:LoadCharacterSavedData(data)
    if data == nil then
        return {
            version = 1,
            items = { },
        }
    end

    return data
end

function Bankier:LoadSavedData(data)
    if data == nil then
        return {
            version = 1,
        }
    end

    return data
end

function Bankier:Reset()
    BankierCharacterSavedData = nil
    BankierSavedData = nil
    self:Loaded()
end

function Bankier:Dump()
    LVK:DebugDump(BankierSavedData, "BankierSavedData")
    LVK:DebugDump(BankierCharacterSavedData, "BankierCharacterSavedData")
end

function Bankier:Init()
    self:RegisterEvent("ADDON_LOADED")
    self:SetScript("OnEvent", function(self, event, ...)
        self[event](self, ...);
    end);

    SlashCmdList["BANKIER"] = function(str)
        LVK:ExecuteSlash(str, self)
    end
    SLASH_BANKIER1 = "/bankier"
    SLASH_BANKIER2 = "/bnk"
end

function Bankier:Slash_List(args)
    function list(filter, title)
        LVK:Print("|y|Bankier|<| %s", title)

        local any = false
        for itemString, itemData in pairs(BankierCharacterSavedData.items) do
            if filter(itemData.level) then
                any = true
                LVK:Print("   %s", self:GetItemDataAsString(itemData))
            end
        end
        if not any then
            LVK:Print("|r|- none configured|<|")
        end
    end

    if (args[1] == "deposit") or (args[1] == "deposits") then
        list(function(lvl) return lvl == 0 end, "deposits")
    elseif (args[1] == "levels") then
        list(function(lvl) return lvl > 0 end, "levels")
    else
        list(function(lvl) return lvl > 0 end, "levels")
        list(function(lvl) return lvl == 0 end, "deposits")
    end
end

function Bankier:Slash_Set(args)
    return self:Slash_Add(args)
end

function Bankier:GetItemDataAsString(itemData)
    if (itemData.level == 0) then
        if (itemData.highThreshold or 0) ~= 0 then
            return LVK:Colorize("%s (..|g|+%d|<|)", itemData.itemLink, itemData.highThreshold)
        end

        return LVK:Colorize("%s", itemData.itemLink)
    elseif ((itemData.highThreshold or 0) ~= 0) and ((itemData.lowThreshold or 0) ~= 0) then
        return LVK:Colorize("%s: %d (|r|%d|<|..|g|+%d|<|)", itemData.itemLink, itemData.level, itemData.lowThreshold, itemData.highThreshold)
    elseif (itemData.highThreshold or 0) ~= 0 then
        return LVK:Colorize("%s: %d (..|g|+%d|<|)", itemData.itemLink, itemData.level, itemData.highThreshold)
    elseif (itemData.lowThreshold or 0) ~= 0 then
        return LVK:Colorize("%s: %d (|r|%d|<|..)", itemData.itemLink, itemData.level, itemData.lowThreshold)
    end

    return LVK:Colorize("%s: %d", itemData.itemLink, itemData.level)
end

function Bankier:Slash_Remove(args)
    local itemLink = args[1]
    if (itemLink or "") == "" then
        LVK:Error("No item link provided")
        LVK:ShowHelp(Bankier.Help, "remove")
        return
    end

    local itemString = LVK:GetItemString(itemLink)
    if (itemString or "") == nil then
        LVK:Error("No item link provided")
        LVK:ShowHelp(Bankier.Help, "remove")
        return
    end

    local itemData = BankierCharacterSavedData.items[itemString]
    BankierCharacterSavedData.items[itemString] = nil
    LVK:Print("|g|Removed|<| %s from bankier list", self:GetItemDataAsString(itemData))
end

function Bankier:Slash_Add(args)
    local itemLink = ""
    local level = nil
    local highThreshold = nil
    local lowThreshold = nil

    for i, v in ipairs(args) do
        local c = v:sub(1, 1)
        if c == '|' then
            itemLink = v
        elseif c == '-' then
            lowThreshold = tonumber(v)
        elseif c == '+' then
            highThreshold = tonumber(v)
        elseif c >= '0' and c <= '9' then
            level = tonumber(v)
        else
            LVK:Print("|r|Invalid argument to '|y|/bankier add|<|': '%s'", v)
            return
        end
    end

    if itemLink == "" then
        LVK:Error("No item link provided")
        LVK:ShowHelp(Bankier.Help, "add")
        return
    end

    if level == nil then
        LVK:Error("No level provided")
        LVK:ShowHelp(Bankier.Help, "add")
        return
    end

    local itemData = Bankier:SetItem(itemLink, level, highThreshold, lowThreshold)
    LVK:Print("Added '%s'", self:GetItemDataAsString(itemData))
end

function Bankier:SetItem(itemLink, level, highThreshold, lowThreshold)
    local itemString = LVK:GetItemString(itemLink)

    local itemData = {
        itemString = itemString,
        itemLink = itemLink,
        level = level,
        highThreshold = highThreshold,
        lowThreshold = lowThreshold
    }
    BankierCharacterSavedData.items[itemString] = itemData
    return itemData
end

function Bankier:ShowUsageHelp()
    LVK:ShowHelp(Bankier.Help, "usage")
end

function Bankier:Slash_Help(key)
    LVK:ShowHelp(Bankier.Help, "help")
end

function Bankier:Loaded()
    BankierCharacterSavedData = self:LoadCharacterSavedData(BankierCharacterSavedData)
    BankierSavedData = self:LoadSavedData(BankierSavedData)
    LVK:AnnounceAddon("Bankier")

    -- LVK:DebugDump(BankierCharacterSavedData, "BankierCharacterSavedData")
    -- LVK:DebugDump(BankierSavedData, "BankierSavedData")
end

function Bankier:ADDON_LOADED(addon)
    if addon ~= "Bankier" then
        return
    end

    self:Loaded()
    self:UnregisterEvent("ADDON_LOADED")
end


Bankier:Init()