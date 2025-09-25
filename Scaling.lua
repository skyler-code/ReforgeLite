local _, addonTable = ...

local RandPropPoints, ItemUpgradeStats, ItemStatsRef = addonTable.RandPropPoints, addonTable.ItemUpgradeStats, addonTable.ItemStatsRef

function addonTable.GetRandPropPoints(iLvl, t)
    return (RandPropPoints[iLvl] and RandPropPoints[iLvl][t] or 0)
end

local function GetItemInfoUp(link, upgrade)
    local id = C_Item.GetItemInfoInstant(link)
    local iLvl = C_Item.GetDetailedItemLevelInfo(id)
    return id, iLvl + (upgrade or 0) * 4, iLvl
end

function addonTable.GetItemStatsUp(link, upgrade)
    local result = GetItemStats(link)
    if result and upgrade and upgrade > 0 then
        local id, iLvl, iLvlBase = GetItemInfoUp(link, upgrade)
        local budget, ref
        if RandPropPoints[iLvl] and ItemUpgradeStats[id] then
            budget = RandPropPoints[iLvl][ItemUpgradeStats[id][1]]
            ref = ItemStatsRef[ItemUpgradeStats[id][2] + 1]
        end
        for sid, sv in ipairs(addonTable.itemStats) do
            if result[sv.name] then
                if budget and ref and ref[sid] then
                    result[sv.name] = floor(ref[sid][1] * budget * 0.0001 - ref[sid][2] * 160 + 0.5)
                else
                    result[sv.name] = floor(tonumber(result[sv.name]) * math.pow(1.15, (iLvl - iLvlBase) / 15))
                end
            end
        end
    end
    return result
end