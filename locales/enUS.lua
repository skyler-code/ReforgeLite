local _, addonTable = ...
addonTable.Locale = GetLocale()
addonTable.L = setmetatable({}, {
  __index = function(self, key)
    rawset(self, key, key or "")
    return self[key]
end})

local L = addonTable.L

--@localization(locale="enUS", format="lua_additive_table")@