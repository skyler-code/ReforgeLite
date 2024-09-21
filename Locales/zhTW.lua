if (GAME_LOCALE or GetLocale()) ~= "zhTW" then
  return
end

local _, addonTable = ...
local L = addonTable.L

--@localization(locale="zhTW", format="lua_additive_table")@

L["EquipPredicate"] = ITEM_SPELL_TRIGGER_ONEQUIP .. " "
