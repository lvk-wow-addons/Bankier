
Bankier = {
    LoadCharacterSavedData = function(data)
        if data == nil then
            return {
            }
        end

        return data
    end,

    LoadSavedData = function(data)
        if data == nil then
            return {
            }
        end

        return data
    end,

    Load = function()
        BankierCharacterSavedData = Bankier.LoadCharacterSavedData(BankierCharacterSavedData)
        BankierSavedData = Bankier.LoadSavedData(BankierSavedData)

        LVK.PrintAddonLoaded("Bankier")
    end,

    Reset = function()
        BankierCharacterSavedData = nil
        BankierSavedData = nil
        Bankier.Load()
    end,

    Test = function()
        Bankier.Reset()
    end,

    Dump = function()
        LVK.Dump(BankierSavedData, "BankierSavedData")
        LVK.Dump(BankierCharacterSavedData, "BankierCharacterSavedData")
    end,
}

Bankier.Load()
