local _, addonTable = ...
if addonTable.Locale ~= "koKR" then
  return
end

local L = addonTable.L

--@localization(locale="koKR", format="lua_additive_table")@
L["EquipPredicate"] = ITEM_SPELL_TRIGGER_ONEQUIP .. " "
