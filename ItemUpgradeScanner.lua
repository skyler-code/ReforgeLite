local addonName, addonTable = ...

local ITEM_UPGRADE_TOOLTIP_FORMAT_MSG = ITEM_UPGRADE_TOOLTIP_FORMAT:gsub("%%d", "(.+)")
local ITEM_UPGRADES_ENABLED = addonTable.isDev or select(7,GetBuildInfo()) > 50500

local reforgeIdTooltip
function addonTable.GetItemUpgradeId(item)
    if not ITEM_UPGRADES_ENABLED
    or item:IsItemEmpty()
    or not item:HasItemLocation()
    or item:GetItemQuality() < Enum.ItemQuality.Rare
    or item:GetCurrentItemLevel() < 458 then
        return 0, 0
    end
    if not reforgeIdTooltip then
        reforgeIdTooltip = CreateFrame("GameTooltip", addonName.."Tooltip", nil, "GameTooltipTemplate")
        reforgeIdTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    if item.itemLocation:IsEquipmentSlot() then
        reforgeIdTooltip:SetInventoryItem("player", item.itemLocation:GetEquipmentSlot())
    elseif item.itemLocation:IsBagAndSlot() then
        reforgeIdTooltip:SetBagItem(item.itemLocation:GetBagAndSlot())
    else
        reforgeIdTooltip:SetItemByID(item:GetItemID())
    end
    for _, region in pairs({reforgeIdTooltip:GetRegions()}) do
        if region.GetText and region:GetText() then
            local currentLevel, maxLevel = region:GetText():match(ITEM_UPGRADE_TOOLTIP_FORMAT_MSG)
            if currentLevel then
                return tonumber(currentLevel), tonumber(maxLevel)
            end
        end
    end
    return 0, 0
end
