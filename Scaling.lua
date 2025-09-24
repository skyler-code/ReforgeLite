local _, addonTable = ...

local RandPropPoints, ItemStats, ItemStatsRef = addonTable.RandPropPoints, addonTable.ItemStats, addonTable.ItemStatsRef

function addonTable.GetRandPropPoints(iLvl, t)
    return (RandPropPoints[iLvl] and RandPropPoints[iLvl][t] or 0)
end

local function GetItemInfoUp(link, upgrade)
    local id = C_Item.GetItemInfoInstant(link)
    local iLvl = select(4, C_Item.GetItemInfo(link)) or 0
    if upgrade and upgrade > 0 then
        iLvl = iLvl + upgrade * 4
    end
    return id, iLvl
end

function addonTable.GetItemStatsUp(link, upgrade)
    local result = GetItemStats(link)
    if result and upgrade and upgrade > 0 then
        local id, iLvl = GetItemInfoUp(link, upgrade)
        local budget, ref
        if RandPropPoints[iLvl] and ItemStats[id] then
            budget = RandPropPoints[iLvl][ItemStats[id][1]]
            ref = ItemStatsRef[ItemStats[id][2] + 1]
        end
        for sid, sv in ipairs(ReforgeLite.itemStats) do
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