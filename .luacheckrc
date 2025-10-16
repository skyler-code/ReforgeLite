-- Luacheck configuration for ReforgeLite

std = "lua51"
max_line_length = false
exclude_files = {
	".luacheckrc"
}

-- Variables the addon writes to
globals = {
    "ReforgeLiteDB",
}

-- WoW API functions and constants (read-only)
read_globals = {
    "_G",
    "AceGUI",
    "LibStub", 
    "EMPTY",
    "ERROR_CAPS",
    -- Blizzard UI Constants
    "UIParent",
    "TRANSMOGRIFY_FONT_COLOR",
    "INVSLOT_TABARD",
    "INVSLOT_BODY",
    "INVSLOT_FINGER1",
    "INVSLOT_FINGER2", 
    "INVSLOT_TRINKET1",
    "INVSLOT_TRINKET2",
    "INVSLOT_HEAD",
    "INVSLOT_NECK",
    "INVSLOT_SHOULDER",
    "INVSLOT_BACK",
    "INVSLOT_CHEST",
    "INVSLOT_WRIST",
    "INVSLOT_HAND",
    "INVSLOT_WAIST",
    "INVSLOT_LEGS",
    "INVSLOT_FEET",
    "INVSLOT_MAINHAND",
    "INVSLOT_OFFHAND",
    -- Item Slot Constants
    "HEADSLOT",
    "NECKSLOT", 
    "SHOULDERSLOT",
    "BACKSLOT",
    "CHESTSLOT",
    "WRISTSLOT",
    "HANDSSLOT",
    "WAISTSLOT",
    "LEGSSLOT",
    "FEETSLOT",
    "FINGER0SLOT",
    "FINGER1SLOT",
    "TRINKET0SLOT",
    "TRINKET1SLOT",
    "MAINHANDSLOT",
    "SECONDARYHANDSLOT",
    -- Stat Constants
    "ITEM_MOD_SPIRIT_SHORT",
    "ITEM_MOD_HIT_RATING_SHORT",
    "SPELL_STAT5_NAME",
    "STAT_DODGE",
    "STAT_PARRY",
    "HIT",
    "CRIT_ABBR",
    "STAT_HASTE",
    "EXPERTISE_ABBR",
    "STAT_EXPERTISE",
    "STAT_MASTERY",
    "ITEM_MOD_DODGE_RATING",
    "ITEM_MOD_PARRY_RATING",
    "ITEM_MOD_HIT_RATING",
    "ITEM_MOD_CRIT_RATING",
    "ITEM_MOD_HASTE_RATING",
    "ITEM_MOD_EXPERTISE_RATING",
    "ITEM_MOD_MASTERY_RATING_SHORT",
    -- Combat Rating Constants
    "CR_HIT_SPELL",
    "CR_HIT_RANGED",
    "CR_CRIT_SPELL",
    "CR_CRIT_RANGED",
    "CR_HASTE_SPELL",
    "CR_HASTE_RANGED",
    "CR_DODGE",
    "CR_PARRY",
    "CR_EXPERTISE",
    "CR_MASTERY",
    -- Unit Constants
    "LE_UNIT_STAT_SPIRIT",
    -- Other Constants
    "NONE",
    "SETTINGS",
    "CONTINUE",
    "RESET",
    "REFORGED",
    "REFORGE",
    "STAT_TARGET_LEVEL",
    "CHARACTER_LINK_ITEM_LEVEL_TOOLTIP",
    "ReforgingFrame",
    "ReforgeLiteDB",
    "MAX_NUM_TALENT_TIERS",
    "UISpecialFrames",
    "GameTooltip",
    "GameTooltip_Hide",
    "GameTooltip_AddNormalLine",
    "GameTooltip_AddColoredLine",
    "GameTooltip_AddBlankLineToTooltip",
    "RED_FONT_COLOR",
    "WHITE_FONT_COLOR",
    "GOLD_FONT_COLOR",
    "INACTIVE_COLOR",
    "TUTORIAL_FONT_COLOR",
    "NORMAL_FONT_COLOR",
    "PANEL_BACKGROUND_COLOR",
    "DARKYELLOW_FONT_COLOR",
    -- Additional constants used in ReforgeLite
    "C_AddOns",
    "C_EncodingUtil",
    "C_Item",
    "C_UnitAuras",
    "C_Reforge",
    "C_SpecializationInfo",
    "CreateFrame",
    "EnumUtil",
    "Item",
    "UnitClass",
    "UnitLevel",
    "UnitStat",
    "GetCombatRating",
    "GetInventorySlotInfo",
    "GetAverageItemLevel",
    "tinsert",
    "tremove",
    "wipe",
    "CopyTable",
    "floor",
    "abs",
    "Round",
    "date",
    "tostringall",
    "join",
    "GetItemStats",
    "debugprofilestop",
    "strupper",
    "SPEC_DRUID_BALANCE",
    "SPEC_MONK_MISTWEAVER",
    "SPEC_PRIEST_SHADOW",
    "SPEC_SHAMAN_RESTORATION",
    "MergeTable",
}

-- Allow accessing the vararg table (...) to get addon table
-- This is the standard WoW addon pattern: local _, addonTable = ...
allow_defined_top = true

-- Suppress undefined field warnings for AceGUI widgets and addonTable
-- These are false positives as:
-- - AceGUI creates properties dynamically
-- - addonTable fields are defined across multiple files
-- - ReforgeLite methods are injected across multiple files
ignore = {
    "113/undefined field",
    "143/addonTable",  -- Accessing undefined field of addonTable
    "inject-field",    -- Allow field injection (WoW addon pattern)
}
