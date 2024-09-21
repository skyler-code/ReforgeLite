if (GAME_LOCALE or GetLocale()) ~= "koKR" then
  return
end

local _, addonTable = ...
local L = addonTable.L

--@localization(locale="koKR", format="lua_additive_table")@

L["EquipPredicate"] = ITEM_SPELL_TRIGGER_ONEQUIP .. " "
