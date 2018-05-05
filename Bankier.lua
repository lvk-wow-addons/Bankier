Bankier = CreateFrame("Frame")

function Bankier:LoadCharacterSavedData(data)
    if data == nil then
        return {
        }
    end

    return data
end

function Bankier:LoadSavedData(data)
    if data == nil then
        return {
        }
    end

    return data
end

function Bankier:Reset()
    BankierCharacterSavedData = nil
    BankierSavedData = nil
    self:Loaded()
end

function Bankier:Test()
    LVK:Print("--------------")
    self:Reset()
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
end

function Bankier:Loaded()
    BankierCharacterSavedData = self:LoadCharacterSavedData(BankierCharacterSavedData)
    BankierSavedData = self:LoadSavedData(BankierSavedData)
    LVK:PrintAddonLoaded("Bankier")

    LVK:DebugDump(BankierCharacterSavedData, "BankierCharacterSavedData")
    LVK:DebugDump(BankierSavedData, "BankierSavedData")
end

function Bankier:ADDON_LOADED(addon)
    if addon ~= "Bankier" then
        return
    end

    self:Loaded()
    self:UnregisterEvent("ADDON_LOADED")
end


Bankier:Init()
