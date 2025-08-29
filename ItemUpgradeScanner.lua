local addonName, addonTable = ...

local ITEM_UPGRADE_TOOLTIP_FORMAT_MSG = ITEM_UPGRADE_TOOLTIP_FORMAT:gsub("%%d", "(.+)")
local ITEM_UPGRADES_ENABLED = select(7,GetBuildInfo()) > 50500

local reforgeIdTooltip
function addonTable.GetUpgradeIdForInventorySlot(slotId)
    if not ITEM_UPGRADES_ENABLED then return 0, 2 end
    if not reforgeIdTooltip then
        reforgeIdTooltip = CreateFrame("GameTooltip", addonName.."Tooltip", nil, "GameTooltipTemplate")
        reforgeIdTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    reforgeIdTooltip:SetInventoryItem("player", slotId)
    for _, region in pairs({reforgeIdTooltip:GetRegions()}) do
        if region:GetObjectType() == "FontString" and region:GetText() then
            local currentLevel, maxLevel = region:GetText():match(ITEM_UPGRADE_TOOLTIP_FORMAT_MSG)
            if currentLevel then
                return tonumber(currentLevel), tonumber(maxLevel)
            end
        end
    end
end
