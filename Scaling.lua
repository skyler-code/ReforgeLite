---@type string, AddonTable
local _, addonTable = ...

local RandPropPoints, ItemUpgradeStats, ItemStatsRef = addonTable.RandPropPoints, addonTable.ItemUpgradeStats, addonTable.ItemStatsRef

---Gets random property points for an item level and slot type
---@param iLvl number Item level
---@param t number Slot type index
---@return number points Random property points for the item level and slot
function addonTable.GetRandPropPoints(iLvl, t)
    return (RandPropPoints[iLvl] and RandPropPoints[iLvl][t] or 0)
end

---Gets item stats adjusted for upgrade level
---Calculates base stats and applies upgrade scaling based on item level
---@param itemInfo table Item information with link, itemId, ilvl, upgradeLevel
---@return table<string, number> stats Table of stat names to values
function addonTable.GetItemStatsUp(itemInfo)
    if not (itemInfo or {}).link then return {} end
    local result = GetItemStats(itemInfo.link)
    if result and itemInfo.upgradeLevel > 0 then
        local iLvlBase = C_Item.GetDetailedItemLevelInfo(itemInfo.itemId)
        local budget, ref
        if RandPropPoints[itemInfo.ilvl] and ItemUpgradeStats[itemInfo.itemId] then
            budget = RandPropPoints[itemInfo.ilvl][ItemUpgradeStats[itemInfo.itemId][1]]
            ref = ItemStatsRef[ItemUpgradeStats[itemInfo.itemId][2] + 1]
        end
        for sid, sv in ipairs(addonTable.itemStats) do
            if result[sv.name] then
                if budget and ref and ref[sid] then
                    result[sv.name] = floor(ref[sid][1] * budget * 0.0001 - ref[sid][2] * 160 + 0.5)
                else
                    result[sv.name] = floor(tonumber(result[sv.name]) * math.pow(1.15, (itemInfo.ilvl - iLvlBase) / 15))
                end
            end
        end
    end
    return result
end