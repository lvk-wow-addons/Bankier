Bankier = CreateFrame("Frame")

Bankier.Help = {
    ["usage"] = "Use '|y|/bankier help|<|' for general help",
    ["help"] = {
        "Use '|y|/bankier command [args]|<|'",
        "",
        "commands:",
        "  add <item-link> <level> [+<high threshold>] [-<low threshold>]",
        "  remove <item-link>",
        "  list [what]",
    },
    ["add"] = {
        "Help for: |y|/bankier add <item-link> <level> [+<high threshold>] [-<low threshold>]|<|",
        "|g|purpose:|<|",
        "  adds or updates an item with thresholds",
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
    },
    ["remove"] = {
        "Help for: |y|/bankier remove <item-link>|<|",
        "|g|purpose:|<|",
        "  removes an item from the list of tracked items",
        "|g|arguments:|<|",
        "  item-link: Shift-Click on an item in your inventory to get this",
    },
    ["list"] = {
        "Help for: |y|/banker list [what]|<|",
        "|g|purpose:|<|",
        "  lists items that are tracked for thresholds or deposit",
        "|g|arguments:|<|",
        "  what: optional, if left out will list both thresholds and deposits",
        "        if 'levels', will list item threshold levels",
        "        if 'deposits', will list all items that will be deposited to bank",
    },
}

local _bankWindowOpen = false
local _reQueueOnItemMove = false
local _scanRunning = false
local _chatPrefix = LVK:Colorize("|w|[|<||g|Bankier|<||w|]|<|")

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

function Bankier:HookTooltip()
    local function itemTooltip(tooltip)
        local _, itemLink = tooltip:GetItem()
        local itemString = LVK:GetItemString(itemLink)
        
        local itemData = BankierCharacterSavedData.items[itemString]
        if itemData then
            tooltip:AddLine(_chatPrefix .. " " .. Bankier:GetItemDataAsString(itemData, false))
            tooltip:AddLine("")
        end
    end

    GameTooltip:HookScript("OnTooltipSetItem", itemTooltip)
end

function Bankier:Init()
    self:RegisterEvent("ADDON_LOADED")
    self:SetScript("OnEvent", function(self, event, ...)
        self[event](self, ...)
    end)
    self:RegisterEvent("BANKFRAME_OPENED")
    self:RegisterEvent("BANKFRAME_CLOSED")
    self:RegisterEvent("ITEM_LOCK_CHANGED")
    self:RegisterEvent("BAG_UPDATE")

    SlashCmdList["BANKIER"] = function(str)
        LVK:ExecuteSlash(str, self)
    end
    SLASH_BANKIER1 = "/bankier"
    SLASH_BANKIER2 = "/bnk"

    Bankier:HookTooltip()
end

function Bankier:Slash_List(args)
    function list(filter, title)
        LVK:Print("|y|Bankier|<| %s", title)

        local any = false
        for itemString, itemData in pairs(BankierCharacterSavedData.items) do
            if filter(itemData.level) then
                any = true
                LVK:Print("   %s", self:GetItemDataAsString(itemData, true))
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
    elseif (#args == 0) then
        list(function(lvl) return lvl > 0 end, "levels")
        list(function(lvl) return lvl == 0 end, "deposits")
    else
        LVK:ShowHelp(Bankier.Help, "list")
    end
end

function Bankier:Slash_Set(args)
    return self:Slash_Add(args)
end

function Bankier:GetItemDataAsString(itemData, includeItemLink)
    local prefix = ""
    if includeItemLink then
        prefix = itemData.itemLink .. ": "
    end
    if (itemData.level == 0) then
        if (itemData.highThreshold or 0) ~= 0 then
            return LVK:Colorize("%s(..|g|+%d|<|)", prefix, itemData.highThreshold)
        end

        if includeItemLink then
            return LVK:Colorize("%s", itemData.itemLink)
        else
            return LVK:Colorize("|R|Auto-deposit|<|")
        end
    elseif ((itemData.highThreshold or 0) ~= 0) and ((itemData.lowThreshold or 0) ~= 0) then
        return LVK:Colorize("%s%d (|r|%d|<|..|g|+%d|<|)", prefix, itemData.level, itemData.lowThreshold, itemData.highThreshold)
    elseif (itemData.highThreshold or 0) ~= 0 then
        return LVK:Colorize("%s%d (..|g|+%d|<|)", prefix, itemData.level, itemData.highThreshold)
    elseif (itemData.lowThreshold or 0) ~= 0 then
        return LVK:Colorize("%s%d (|r|%d|<|..)", prefix, itemData.level, itemData.lowThreshold)
    end

    return LVK:Colorize("%s%d", prefix, itemData.level)
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
    LVK:Print("|g|Removed|<| %s from bankier list", self:GetItemDataAsString(itemData, true))
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
    LVK:Print("Added '%s'", self:GetItemDataAsString(itemData, true))
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
    Bankier:QueueScan()
end

function Bankier:QueueScan()
    if _scanRunning then
        return
    end
    
    _scanRunning = true
    LVK:AddTimer(function()
        Bankier:Scan()
        _scanRunning = false
    end, 0.1)
end

function Bankier:BANKFRAME_OPENED()
    _bankWindowOpen = true
    Bankier:QueueScan()
end

function Bankier:BANKFRAME_CLOSED()
    _bankWindowOpen = false
    Bankier:QueueScan()
end

function Bankier:QueueFromEvent()
    if _reQueueOnItemMove then
        _reQueueOnItemMove = false
        Bankier:QueueScan()
    end
end

function Bankier:ITEM_LOCK_CHANGED()
    Bankier:QueueFromEvent()
end

function Bankier:BAG_UPDATE()
    Bankier:QueueFromEvent()
end

function Bankier:CountItem(itemLink, containers)
    local count = 0
    itemLink = LVK:GetItemString(itemLink)
    for _, containerId in ipairs(containers) do
        local slots = GetContainerNumSlots(containerId)
        if slots > 0 then
            for slotIndex = 1, slots do
                local texture, bagItemCount, locked, quality, readable, lootable, bagItemLink = GetContainerItemInfo(containerId, slotIndex)
                if bagItemLink then
                    if itemLink == LVK:GetItemString(bagItemLink) then
                        count = count + bagItemCount
                    end
                end
            end
        end
    end
    return count
end

function Bankier:LocateEmptySlot(containers)
    for _, containerId in ipairs(containers) do
        local slots = GetContainerNumSlots(containerId)
        if slots > 0 then
            for slotIndex = 1, slots do
                local texture, bagItemCount, locked, quality, readable, lootable, bagItemLink = GetContainerItemInfo(containerId, slotIndex)
                if not bagItemLink then
                    return containerId, slotIndex
                end
            end
        end
    end
end

function Bankier:LocateItem(itemString, containers, predicate)
    for _, containerId in ipairs(containers) do
        local slots = GetContainerNumSlots(containerId)
        if slots > 0 then
            for slotIndex = 1, slots do
                local texture, bagItemCount, locked, quality, readable, lootable, bagItemLink = GetContainerItemInfo(containerId, slotIndex)
                if bagItemLink and itemString == LVK:GetItemString(bagItemLink) and (not locked) then
                    if predicate(texture, bagItemCount, locked, quality, readable, lootable, bagItemLink) then
                        return containerId, slotIndex, bagItemCount
                    end
                end
            end
        end
    end
end

function Bankier:TryFindSourceItem(itemString, requiredCount, containers)
    local containerId, slotIndex, count

    -- See if we have a stack with the exact number of items
    containerId, slotIndex, count = Bankier:LocateItem(itemString, containers, function(_, bagItemCount)
        return bagItemCount == requiredCount
    end)
    if containerId then
        return containerId, slotIndex, count
    end

    -- If not, then just try to find the item
    return Bankier:LocateItem(itemString, containers, function()
        return true
    end)
end

function Bankier:GetMaxStackSize(itemString)
    local _, _, _, _, _, _, _, maxStackSize = GetItemInfo(itemString)
    return maxStackSize
end

function Bankier:TryFindTargetItem(itemString, requiredSpace, containers)
    local containerId, slotIndex, count
    local maxStackSize = Bankier:GetMaxStackSize(itemString)
    requiredSpace = math.min(maxStackSize, requiredSpace)

    -- See if we have a stack with room for the exact number of items
    containerId, slotIndex, count = Bankier:LocateItem(itemString, containers, function(texture, bagItemCount, locked, quality, readable, lootable, bagItemLink)
        return bagItemCount + requiredSpace == maxStackSize
    end)
    if containerId then
        return containerId, slotIndex, maxStackSize - count
    end

    -- See if we have a stack with room for the number of items (but will not fill it)
    containerId, slotIndex, count = Bankier:LocateItem(itemString, containers, function(texture, bagItemCount, locked, quality, readable, lootable, bagItemLink)
        return bagItemCount + requiredSpace <= maxStackSize
    end)
    if containerId then
        return containerId, slotIndex, maxStackSize - count
    end

    -- Find an empty slot
    containerId, slotIndex = Bankier:LocateEmptySlot(containers)
    if not containerId then
        return
    end

    return containerId, slotIndex, requiredSpace
end

function Bankier:TryMoveItems(itemLink, amount, sourceContainers, targetContainers)
    local itemString = LVK:GetItemString(itemLink)

    local toMove = amount

    local sourceContainerId, sourceSlotIndex, sourceCount = Bankier:TryFindSourceItem(itemString, amount, sourceContainers)
    if not sourceContainerId then
        -- LVK:Print("Unable to locate source")
        return 0
    end
    -- LVK:Dump({["containerId"] = sourceContainerId, ["slotIndex"] = sourceSlotIndex, ["sourceCount"] = sourceCount}, "source")

    if sourceCount < amount then
        toMove = sourceCount
    end

    -- Attempt to find a stack to fill
    local targetContainerId, targetSlotIndex, targetSpace = Bankier:TryFindTargetItem(itemString, toMove, targetContainers)
    if not targetContainerId then
        -- LVK:Print("Unable to locate target")
        return 0
    end
    -- LVK:Dump({["containerId"] = targetContainerId, ["slotIndex"] = targetSlotIndex, ["targetSpace"] = targetSpace}, "target")

    -- Attempt to move
    toMove = math.min(toMove, targetSpace)
    if toMove == 0 then
        LVK:Print("Error: infinite loop when moving items detected")
        return 0
    end

    if toMove < sourceCount then
        SplitContainerItem(sourceContainerId, sourceSlotIndex, toMove)
    else
        PickupContainerItem(sourceContainerId, sourceSlotIndex)
    end

    PickupContainerItem(targetContainerId, targetSlotIndex)
    return toMove
end

function Bankier:CheckItemLevels(mode)
    for _, itemData in pairs(BankierCharacterSavedData.items) do
        local inBags = Bankier:CountItem(itemData.itemLink, { 0, 1, 2, 3, 4 })
        if inBags ~= itemData.level then
            if mode == "REPORT" then
                local diff = inBags - itemData.level
                if diff > 0 and diff > (itemData.highThreshold or 0) then
                    LVK:Print("%s %s: |g|%d|<| in bags, allowed level is |g|%d|<|, |y|surplus of %d|<|", _chatPrefix, itemData.itemLink, inBags, itemData.level, inBags - itemData.level)
                elseif diff < 0 and diff < (itemData.lowThreshold or 0) then
                    LVK:Print("%s %s: |g|%d|<| in bags, required level is |g|%d|<|, |R|missing |r|%d|<|", _chatPrefix, itemData.itemLink, inBags, itemData.level, itemData.level - inBags)
                end
            elseif _bankWindowOpen then
                if inBags > itemData.level then
                    local moved = Bankier:TryMoveItems(itemData.itemLink, inBags - itemData.level, { 0, 1, 2, 3, 4 }, { -1, 5, 6, 7, 8, 9, 10, 11, 12 })
                    if moved > 0 then
                        LVK:Print("%s |y|moved|<| %dx %s to bank", _chatPrefix, moved, itemData.itemLink)
                        return true
                    --else
                    --    LVK:Print("%s |R|unable|<| to move %s to bank, still got %d too many in bags", _chatPrefix, itemData.itemLink, inBags - itemData.level)
                    end
                elseif itemData.level > 0 then
                    local moved = Bankier:TryMoveItems(itemData.itemLink, itemData.level - inBags, { -1, 5, 6, 7, 8, 9, 10, 11, 12 }, { 0, 1, 2, 3, 4 })
                    if moved > 0 then
                        LVK:Print("%s |y|withdrew|<| %dx %s from bank", _chatPrefix, moved, itemData.itemLink)
                        return true
                    --else
                    --    LVK:Print("%s |R|unable|<| to withdraw %s from bank, still missing %d", _chatPrefix, itemData.itemLink, itemData.level - inBags)
                    end
                end
            end
        end
    end
    return false
end

function Bankier:Scan()
    if _bankWindowOpen then
        if Bankier:CheckItemLevels("MOVE") then
            _reQueueOnItemMove = true
            return true
        else
            Bankier:CheckItemLevels("REPORT")
        end
    else
        Bankier:CheckItemLevels("REPORT")
    end
    return false
end

Bankier:Init()