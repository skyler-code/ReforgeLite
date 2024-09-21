local _, addonTable = ...
if addonTable.Locale ~= "zhTW" then
  return
end

local L = addonTable.L

--@localization(locale="zhTW", format="lua_additive_table")@
L["EquipPredicate"] = ITEM_SPELL_TRIGGER_ONEQUIP .. " "
