local _, addonTable = ...
local L = addonTable.L
local ReforgeLite = addonTable.ReforgeLite
local GUI = addonTable.GUI
local tsort, tinsert = table.sort, tinsert

local StatHit = addonTable.statIds.HIT
local StatCrit = addonTable.statIds.CRIT
local StatHaste = addonTable.statIds.HASTE
local StatExp = addonTable.statIds.EXP

local SPELL_HASTE_BUFFS = {
  24907,  -- Moonkin Aura
  49868,  -- Mind Quickening
  51470,  -- Elemental Oath
  135678, -- Energizing Spores
}

local MELEE_HASTE_BUFFS = {
  55610,  -- Unholy Aura
  128432, -- Cackling Howl
  128433, -- Serpent's Swiftness
  113742, -- Swiftblade's Cunning
  30809,  -- Unleashed Rage
}

local MASTERY_BUFFS = {
  93435,  -- Roar of Courage
  128997, -- Spirit Beast Blessing
  19740,  -- Blessing of Might
  116956, -- Grace of Air
}

function ReforgeLite:PlayerHasSpellHasteBuff()
  for _, v in ipairs(SPELL_HASTE_BUFFS) do
    if C_UnitAuras.GetPlayerAuraBySpellID(v) then
      return true
    end
  end
end

function ReforgeLite:PlayerHasMeleeHasteBuff()
  for _, v in ipairs(MELEE_HASTE_BUFFS) do
    if C_UnitAuras.GetPlayerAuraBySpellID(v) then
      return true
    end
  end
end

function ReforgeLite:PlayerHasMasteryBuff()
  for _, v in ipairs(MASTERY_BUFFS) do
    if C_UnitAuras.GetPlayerAuraBySpellID(v) then
      return true
    end
  end
end

function ReforgeLite:RatingPerPoint (stat, level)
  level = level or UnitLevel("player")
  if stat == addonTable.statIds.SPELLHIT then
    stat = StatHit
  end
  return addonTable.ScalingTable[stat][level] or 0
end
function ReforgeLite:GetMeleeHitBonus ()
  return GetHitModifier () or 0
end
function ReforgeLite:GetSpellHitBonus ()
  return GetSpellHitModifier () or 0
end
function ReforgeLite:GetExpertiseBonus()
  if addonTable.playerClass == "HUNTER" then
    return select(3, GetExpertise()) - GetCombatRatingBonus(CR_EXPERTISE)
  else
    return GetExpertise() - GetCombatRatingBonus(CR_EXPERTISE)
  end
end
function ReforgeLite:GetNonSpellHasteBonus(hasteFunc, ratingBonusId)
  local baseBonus = RoundToSignificantDigits((hasteFunc()+100)/(GetCombatRatingBonus(ratingBonusId)+100), 4)
  if self.pdb.meleeHaste and not self:PlayerHasMeleeHasteBuff() then
    baseBonus = baseBonus * 1.1
  end
  return baseBonus
end
function ReforgeLite:GetMeleeHasteBonus()
  return self:GetNonSpellHasteBonus(GetMeleeHaste, CR_HASTE_MELEE)
end
function ReforgeLite:GetRangedHasteBonus()
  return self:GetNonSpellHasteBonus(GetRangedHaste, CR_HASTE_RANGED)
end
function ReforgeLite:GetSpellHasteBonus()
  local baseBonus = (UnitSpellHaste('PLAYER')+100)/(GetCombatRatingBonus(CR_HASTE_SPELL)+100)
  if self.pdb.spellHaste and not self:PlayerHasSpellHasteBuff() then
    baseBonus = baseBonus * 1.05
  end
  return RoundToSignificantDigits(baseBonus, 6)
end
function ReforgeLite:GetHasteBonuses()
  return self:GetMeleeHasteBonus(), self:GetRangedHasteBonus(), self:GetSpellHasteBonus()
end
function ReforgeLite:CalcHasteWithBonus(haste, hasteBonus)
  return ((hasteBonus - 1) * 100) + haste * hasteBonus
end
function ReforgeLite:CalcHasteWithBonuses(haste)
  local meleeBonus, rangedBonus, spellBonus = self:GetHasteBonuses()
  return self:CalcHasteWithBonus(haste, meleeBonus), self:CalcHasteWithBonus(haste, rangedBonus), self:CalcHasteWithBonus(haste, spellBonus)
end

function ReforgeLite:GetNeededMeleeHit ()
  return max(0, 3 + 1.5 * self.pdb.targetLevel)
end
function ReforgeLite:GetNeededSpellHit ()
  local diff = self.pdb.targetLevel
  if diff <= 3 then
    return max(0, 6 + 3 * diff)
  else
    return 11 * diff - 18
  end
end

function ReforgeLite:GetNeededExpertiseSoft()
  return max(0, 3 + 1.5 * self.pdb.targetLevel)
end

function ReforgeLite:GetNeededExpertiseHard()
  return max(0, 6 + 3 * self.pdb.targetLevel)
end

local function CreateIconMarkup(icon)
  return CreateTextureMarkup(icon, 64, 64, 18, 18, 0.07, 0.93, 0.07, 0.93, 0, 0) .. " "
end
addonTable.CreateIconMarkup = CreateIconMarkup

local AtLeast = addonTable.StatCapMethods.AtLeast
local AtMost = addonTable.StatCapMethods.AtMost
local CAPS = EnumUtil.MakeEnum("ManualCap", "MeleeHitCap", "SpellHitCap", "MeleeDWHitCap", "ExpSoftCap", "ExpHardCap", "FirstHasteBreak", "SecondHasteBreak", "ThirdHasteBreak", "FourthHasteBreak", "FifthHasteBreak")

ReforgeLite.capPresets = {
  {
    value = CAPS.ManualCap,
    name = TRACKER_SORT_MANUAL,
    getter = nil
  },
  {
    value = CAPS.MeleeHitCap,
    name = L["Melee hit cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint(StatHit) * (ReforgeLite:GetNeededMeleeHit() - ReforgeLite:GetMeleeHitBonus())
    end,
    category = StatHit
  },
  {
    value = CAPS.SpellHitCap,
    name = L["Spell hit cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (addonTable.statIds.SPELLHIT) * (ReforgeLite:GetNeededSpellHit () - ReforgeLite:GetSpellHitBonus ())
    end,
    category = StatHit
  },
  {
    value = CAPS.MeleeDWHitCap,
    name = L["Melee DW hit cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint(StatHit) * (ReforgeLite:GetNeededMeleeHit() + 19 - ReforgeLite:GetMeleeHitBonus())
    end,
    category = StatHit
  },
  {
    value = CAPS.ExpSoftCap,
    name = L["Expertise soft cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (StatExp) * (ReforgeLite:GetNeededExpertiseSoft() - ReforgeLite:GetExpertiseBonus())
    end,
    category = StatExp
  },
  {
    value = CAPS.ExpHardCap,
    name = L["Expertise hard cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (StatExp) * (ReforgeLite:GetNeededExpertiseHard() - ReforgeLite:GetExpertiseBonus())
    end,
    category = StatExp
  },
}

-- local function GetActiveItemSet()
--   local itemSets = {}
--   for _,v in ipairs({INVSLOT_HEAD,INVSLOT_SHOULDER,INVSLOT_CHEST,INVSLOT_LEGS,INVSLOT_HAND}) do
--     local item = Item:CreateFromEquipmentSlot(v)
--     if not item:IsItemEmpty() then
--       local itemSetId = select(16, C_Item.GetItemInfo(item:GetItemID()))
--       if itemSetId then
--         itemSets[itemSetId] = (itemSets[itemSetId] or 0) + 1
--       end
--     end
--   end
--   return itemSets
-- end

local function GetSpellHasteRequired(percentNeeded)
  return function()
    local hasteMod = ReforgeLite:GetSpellHasteBonus()
    return ceil((percentNeeded - (hasteMod - 1) * 100) * ReforgeLite:RatingPerPoint(addonTable.statIds.HASTE) / hasteMod)
  end
end

do
  local nameFormat = "%s%s%% +%s %s "
  local nameFormatWithTicks = nameFormat..L["ticks"]
  if addonTable.playerClass == "DRUID" then
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.FirstHasteBreak,
      category = StatHaste,
      name = ("%s%s %s%%"):format(CreateIconMarkup(236152), C_Spell.GetSpellName(79577), 24.22),
      getter = GetSpellHasteRequired(24.215),
    })
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.SecondHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(CreateIconMarkup(136081)..CreateIconMarkup(136107), 12.52, 1, C_Spell.GetSpellName(774) .. " / " .. C_Spell.GetSpellName(740)),
      getter = GetSpellHasteRequired(12.52),
    })
  elseif addonTable.playerClass == "PALADIN" then
    local eternalFlame, eternalFlameMarkup = C_Spell.GetSpellName(114163), CreateIconMarkup(135433)
    local sacredShield, sacredShieldMarkup = C_Spell.GetSpellName(20925), CreateIconMarkup(236249)
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.FirstHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(eternalFlameMarkup, 8.25, 1, eternalFlame),
      getter = GetSpellHasteRequired(8.245)
    })
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.SecondHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(sacredShieldMarkup, 12.55, 1, sacredShield),
      getter = GetSpellHasteRequired(12.55),
    })
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.ThirdHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(eternalFlameMarkup, 16.87, 2, eternalFlame),
      getter = GetSpellHasteRequired(16.87),
    })
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.FourthHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(eternalFlameMarkup, 25.57, 3, eternalFlame),
      getter = GetSpellHasteRequired(25.57),
    })
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.FifthHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(sacredShieldMarkup, 29.85, 2, sacredShield),
      getter = GetSpellHasteRequired(29.85),
    })
  elseif addonTable.playerClass == "PRIEST" then
    local renew, renewMarkup = C_Spell.GetSpellName(139), CreateIconMarkup(135953)
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.FirstHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(renewMarkup, 12.51, 1, renew),
      getter = GetSpellHasteRequired(12.51),
    })
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.SecondHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(renewMarkup, 37.52, 2, renew),
      getter = GetSpellHasteRequired(37.52),
    })
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.ThirdHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(renewMarkup, 62.53, 3, renew),
      getter = GetSpellHasteRequired(62.53),
    })
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.FourthHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(renewMarkup, 87.44, 4, renew),
      getter = GetSpellHasteRequired(87.44),
    })
  elseif addonTable.playerClass == "WARLOCK" then
    local doom, doomMarkup = C_Spell.GetSpellName(603), CreateIconMarkup(136122)
    local shadowflame, shadowflameMarkup = C_Spell.GetSpellName(47960), CreateIconMarkup(425954)
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.FirstHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(doomMarkup, 12.51, 1, doom),
      getter = GetSpellHasteRequired(12.51),
    })
    tinsert(ReforgeLite.capPresets, {
      value = CAPS.SecondHasteBreak,
      category = StatHaste,
      name = nameFormatWithTicks:format(shadowflameMarkup, 25, 2, shadowflame),
      getter = GetSpellHasteRequired(25),
    })
  end
end
local HitCap = { stat = StatHit, points = { { method = AtLeast, preset = CAPS.MeleeHitCap } } }

local HitCapSpell = { stat = StatHit, points = { { method = AtLeast, preset = CAPS.SpellHitCap } } }

local SoftExpCap = { stat = StatExp, points = { { method = AtLeast, preset = CAPS.ExpSoftCap } } }

local HardExpCap = { stat = StatExp, points = { { method = AtLeast, preset = CAPS.ExpHardCap } } }

local MeleeCaps = { HitCap, SoftExpCap }

local AtMostMeleeCaps = {
  { stat = StatHit, points = { { method = AtMost, preset = CAPS.MeleeHitCap } } },
  { stat = StatExp, points = { { method = AtMost, preset = CAPS.ExpSoftCap } } }
}

local TankCaps = { HitCap, HardExpCap }

local CasterCaps = { HitCapSpell }

local specInfo = {}

function ReforgeLite:InitClassPresets()
  local specs = {
    DEATHKNIGHT = { blood = 250, frost = 251, unholy = 252 },
    DRUID = { balance = 102, feralcombat = 103, guardian = 104, restoration = 105 },
    HUNTER = { beastmastery = 253, marksmanship = 254, survival = 255 },
    MAGE = { arcane = 62, fire = 63, frost = 64 },
    MONK = { brewmaster = 268, mistweaver = 270, windwalker = 269 },
    PALADIN = { holy = 65, protection = 66, retribution = 70 },
    PRIEST = { discipline = 256, holy = 257, shadow = 258 },
    ROGUE = { assassination = 259, combat = 260, subtlety = 261 },
    SHAMAN = { elemental = 262, enhancement = 263, restoration = 264 },
    WARLOCK = { afflication = 265, demonology = 266, destruction = 267 },
    WARRIOR = { arms = 71, fury = 72, protection = 73 }
  }

  local presets = {
    ["DEATHKNIGHT"] = {
      [specs.DEATHKNIGHT.blood] = {
        [PET_DEFENSIVE] = {
          weights = {
            0, 140, 150, 100, 50, 75, 95, 200
          },
          caps = AtMostMeleeCaps,
        },
        [BALANCE] = {
          weights = {
            0, 140, 150, 200, 125, 100, 200, 25
          },
          caps = MeleeCaps,
        },
        [PET_AGGRESSIVE] = {
          weights = {
            0, 90, 100, 200, 150, 125, 200, 25
          },
          caps = MeleeCaps,
        },
      },
      [specs.DEATHKNIGHT.frost] = {
        [C_Spell.GetSpellName(49020)] = { -- Obliterate
          icon = 135771,
          weights = {
            0, 0, 0, 87, 44, 35, 87, 39
          },
          caps = MeleeCaps,
        },
        [L["Masterfrost"]] = {
          icon = 135833,
          weights = {
            0, 0, 0, 84, 36, 37, 83, 53
          },
          caps = MeleeCaps,
        }
      },
      [specs.DEATHKNIGHT.unholy] = {
          weights = {
            0, 0, 0, 73, 47, 43, 73, 40
          },
          caps = MeleeCaps,
      },
    },
    ["DRUID"] = {
      [specs.DRUID.balance] = {
        weights = {
          0, 0, 0, 127, 56, 80, 0, 41
        },
        caps = {
          HitCapSpell,
          {
            stat = StatHaste,
            points = {
              {
                method = AtLeast,
                preset = CAPS.FirstHasteBreak,
                after = 46,
              }
            }
          }
        },
      },
      [specs.DRUID.feralcombat] = {
          weights = {
            0, 0, 0, 330, 320, 220, 330, 380
          },
          caps = AtMostMeleeCaps,
      },
      [specs.DRUID.guardian] = {
          weights = {
            0, 53, 0, 116, 105, 37, 116, 73
          },
          caps = TankCaps,
      },
      [specs.DRUID.restoration] = {
          weights = {
            150, 0, 0, 0, 100, 200, 0, 150
          },
        caps = {
          {
            stat = StatHaste,
            points = {
              {
                method = AtLeast,
                preset = CAPS.SecondHasteBreak,
                after = 50,
              }
            }
          }
        },
      },
    },
    ["HUNTER"] = {
      [specs.HUNTER.beastmastery] = {
          weights = {
            0, 0, 0, 63, 30, 37, 59, 32
          },
          caps = MeleeCaps,
      },
      [specs.HUNTER.marksmanship] = {
          weights = {
            0, 0, 0, 63, 40, 35, 59, 29
          },
          caps = MeleeCaps,
      },
      [specs.HUNTER.survival] = {
          weights = {
            0, 0, 0, 59, 33, 25, 57, 21
          },
          caps = MeleeCaps,
      },
    },
    ["MAGE"] = {
      [specs.MAGE.arcane] = {
          weights = {
            0, 0, 0, 131, 53, 70, 0, 68
          },
          caps = CasterCaps,
      },
      [specs.MAGE.fire] = {
          weights = {
            0, 0, 0, 121, 88, 73, 0, 73
          },
          caps = CasterCaps,
      },
      [specs.MAGE.frost] = {
          weights = {
            0, 0, 0, 115, 49, 60, 0, 47
          },
          caps = CasterCaps,
      },
    },
    ["MONK"] = {
      [specs.MONK.brewmaster] = {
        [PET_DEFENSIVE] = {
          weights = {
            0, 0, 0, 150, 50, 50, 130, 100
          },
          caps = TankCaps,
        },
        [PET_AGGRESSIVE] = {
          weights = {
            0, 0, 0, 141, 46, 57, 99, 39
          },
          caps = TankCaps,
        },
      },
      [specs.MONK.mistweaver] = {
        weights = {
          80, 0, 0, 0, 200, 40, 0, 30
        },
      },
      [specs.MONK.windwalker] = {
        [C_Spell.GetSpellName(114355)] = { -- Dual Wield
          icon = 132147,
          weights = {
            0, 0, 0, 141, 46, 57, 99, 39
          },
          caps = MeleeCaps,
        },
        [AUCTION_SUBCATEGORY_TWO_HANDED] = { -- Two-Handed
          icon = 135145,
          weights = {
            0, 0, 0, 138, 46, 54, 122, 38
          },
          caps = MeleeCaps,
        },
      },
    },
    ["PALADIN"] = {
      [specs.PALADIN.holy] = {
          weights = {
            200, 0, 0, 0, 50, 125, 0, 100
          },
        caps = {
          {
            stat = StatHaste,
            points = {
              {
                method = AtLeast,
                preset = CAPS.ThirdHasteBreak,
                after = 75,
              }
            }
          }
        },
      },
      [specs.PALADIN.protection] = {
        [PET_DEFENSIVE] = {
          weights = {
            0, 50, 50, 200, 25, 100, 200, 125
          },
          caps = TankCaps,
        },
        [PET_AGGRESSIVE] = {
          weights = {
            0, 5, 5, 200, 75, 125, 200, 25
          },
          caps = TankCaps,
        },
      },
      [specs.PALADIN.retribution] = {
        weights = {
          0, 0, 0, 100, 50, 52, 87, 51
        },
        caps = MeleeCaps,
      },
    },
    ["PRIEST"] = {
      [specs.PRIEST.discipline] = {
        weights = {
          120, 0, 0, 0, 120, 40, 0, 80
        },
      },
      [specs.PRIEST.holy] = {
        weights = {
          150, 0, 0, 0, 120, 40, 0, 80
        },
      },
      [specs.PRIEST.shadow] = {
        weights = {
          0, 0, 0, 85, 42, 76, 0, 48
        },
        caps = CasterCaps
      },
    },
    ["ROGUE"] = {
      [specs.ROGUE.assassination] = {
        weights = {
          0, 0, 0, 120, 35, 37, 120, 41
        },
        caps = MeleeCaps,
      },
      [specs.ROGUE.combat] = {
        weights = {
          0, 0, 0, 70, 29, 39, 56, 32
        },
        caps = MeleeCaps,
      },
      [specs.ROGUE.subtlety] = {
        weights = {
          0, 0, 0, 54, 31, 32, 35, 26
        },
        caps = MeleeCaps,
      },
    },
    ["SHAMAN"] = {
      [specs.SHAMAN.elemental] = {
        weights = {
          0, 0, 0, 60, 20, 40, 0, 30
        },
        caps = CasterCaps,
      },
      [specs.SHAMAN.enhancement] = {
        weights = {
          0, 0, 0, 149, 66, 84, 130, 121
        },
        caps = MeleeCaps,
      },
      [specs.SHAMAN.restoration] = {
        weights = {
          120, 0, 0, 0, 100, 150, 0, 75
        },
      },
    },
    ["WARLOCK"] = {
      [specs.WARLOCK.afflication] = {
        weights = {
          0, 0, 0, 93, 38, 58, 0, 80
        },
        caps = CasterCaps,
      },
      [specs.WARLOCK.destruction] = {
        weights = {
          0, 0, 0, 83, 59, 57, 0, 61
        },
        caps = CasterCaps,
      },
      [specs.WARLOCK.demonology] = {
        weights = {
          0, 0, 0, 400, 51, 275, 0, 57
        },
        caps = CasterCaps,
      },
    },
    ["WARRIOR"] = {
      [specs.WARRIOR.arms] = {
        weights = {
          0, 0, 0, 140, 59, 32, 120, 39
        },
        caps = MeleeCaps
      },
      [specs.WARRIOR.fury] = {
        [C_Spell.GetSpellName(46917)] = { -- Titan's Grip
          icon = 236316,
          weights = {
            0, 0, 0, 162, 107, 41, 142, 70
          },
          caps = MeleeCaps,
        },
        [C_Spell.GetSpellName(81099)] = { -- Single-Minded Fury
          icon = 458974,
          weights = {
            0, 0, 0, 137, 94, 41, 119, 59
          },
          caps = MeleeCaps,
        },
      },
      [specs.WARRIOR.protection] = {
        weights = {
          0, 140, 150, 200, 25, 50, 200, 100
        },
        caps = TankCaps,
      },
    },
  }

  if self.db.debug then
    self.presets = presets
    for _,ids in pairs(specs) do
      for _, id in pairs(ids) do
        local _, tabName, _, icon = GetSpecializationInfoByID(id)
        specInfo[id] = { name = tabName, icon = icon }
      end
    end
  else
    self.presets = presets[addonTable.playerClass]
    for _, id in pairs(specs[addonTable.playerClass]) do
      local _, tabName, _, icon = GetSpecializationInfoByID(id)
      specInfo[id] = { name = tabName, icon = icon }
    end
  end

  --[===[@non-debug@
  self.presets = presets[addonTable.playerClass]
  for _, id in pairs(specs[addonTable.playerClass]) do
    local _, tabName, _, icon = GetSpecializationInfoByID(id)
    specInfo[id] = { name = tabName, icon = icon }
  end
  --@end-non-debug@]===]
  --@debug@
  --@end-debug@
end

local DYNAMIC_PRESETS = tInvert( { "Pawn", CUSTOM, REFORGE_CURRENT } )

function ReforgeLite:InitCustomPresets()
  local customPresets = {}
  for k, v in pairs(self.cdb.customPresets) do
    local preset = CopyTable(v)
    preset.name = k
    tinsert(customPresets, preset)
  end
  self.presets[CUSTOM] = customPresets
end

function ReforgeLite:InitDynamicPresets()
  self:InitClassPresets()
  self:InitCustomPresets()
end

function ReforgeLite:InitPresets()
  self:InitDynamicPresets()
  if PawnVersion then
    self.presets["Pawn"] = function ()
      if not PawnCommon or not PawnCommon.Scales then return {} end
      local result = {}
      for k, v in pairs (PawnCommon.Scales) do
        if v.ClassID == addonTable.playerClassID then
          local preset = {name = v.LocalizedName or k}
          preset.weights = {}
          local raw = v.Values or {}
          preset.weights[addonTable.statIds.SPIRIT] = raw["Spirit"] or 0
          preset.weights[addonTable.statIds.DODGE] = raw["DodgeRating"] or 0
          preset.weights[addonTable.statIds.PARRY] = raw["ParryRating"] or 0
          preset.weights[StatHit] = raw["HitRating"] or 0
          preset.weights[StatCrit] = raw["CritRating"] or 0
          preset.weights[StatHaste] = raw["HasteRating"] or 0
          preset.weights[StatExp] = raw["ExpertiseRating"] or 0
          preset.weights[addonTable.statIds.MASTERY] = raw["MasteryRating"] or 0
          local total = 0
          local average = 0
          for i = 1, addonTable.itemStatCount do
            if preset.weights[i] ~= 0 then
              total = total + 1
              average = average + preset.weights[i]
            end
          end
          if total > 0 and average > 0 then
            local factor = 1
            while factor * average / total < 10 do
              factor = factor * 100
            end
            while factor * average / total > 1000 do
              factor = factor / 10
            end
            for i = 1, addonTable.itemStatCount do
              preset.weights[i] = preset.weights[i] * factor
            end
            tinsert(result, preset)
          end
        end
      end
      return result
    end
  end

  self.presetMenuGenerator = function(owner, rootDescription)
    GUI:ClearEditFocus()

    rootDescription:CreateButton(SAVE, function()
      GUI.CreateStaticPopup("REFORGE_LITE_SAVE_PRESET",
        L["Enter the preset name"],
        function(popup)
          self.cdb.customPresets[popup:GetEditBox():GetText()] = {
            caps = CopyTable(self.pdb.caps),
            weights = CopyTable(self.pdb.weights)
          }
          self:InitCustomPresets()
        end, { hasEditBox = 1 })
      StaticPopup_Show("REFORGE_LITE_SAVE_PRESET")
    end)

    rootDescription:CreateDivider()

    local function AddPresetButton(desc, info)
      if info.hasDelete then
        local button = desc:CreateButton(info.text, function(mouseButton)
          if IsShiftKeyDown() then
            GUI.CreateStaticPopup("REFORGE_LITE_DELETE_PRESET",
              L["Delete preset '%s'?"]:format(info.presetName),
              function()
                self.cdb.customPresets[info.presetName] = nil
                self:InitCustomPresets()
              end, { button1 = DELETE })
            StaticPopup_Show("REFORGE_LITE_DELETE_PRESET")
          else
            if info.value.targetLevel then
              self.pdb.targetLevel = info.value.targetLevel
              self.targetLevel:SetValue(info.value.targetLevel)
            end
            self:SetStatWeights(info.value.weights, info.value.caps or {})
          end
        end)
        button:SetTooltip(function(tooltip, elementDescription)
          GameTooltip_AddNormalLine(tooltip, L["Click to load preset"])
          GameTooltip_AddColoredLine(tooltip, L["Shift+Click to delete"], RED_FONT_COLOR)
        end)
      else
        desc:CreateButton(info.text, function()
          if info.value.targetLevel then
            self.pdb.targetLevel = info.value.targetLevel
            self.targetLevel:SetValue(info.value.targetLevel)
          end
          self:SetStatWeights(info.value.weights, info.value.caps or {})
        end)
      end
    end

    local menuList = {}
    for k in pairs(self.presets) do
      local v = GetValueOrCallFunction(self.presets, k)
      local isClassMenu = type(v) == "table" and not v.weights and not v.caps

      if isClassMenu then
        local classInfo = {
          sortKey = specInfo[k] and specInfo[k].name or k,
          text = specInfo[k] and specInfo[k].name or k,
          prioritySort = DYNAMIC_PRESETS[k] or 0,
          key = k,
          isSubmenu = true,
          submenuItems = {}
        }
        if specInfo[k] then
          classInfo.text = CreateIconMarkup(specInfo[k].icon) .. specInfo[k].name
        end

        for specId, preset in pairs(v) do
          local hasSubPresets = type(preset) == "table" and not preset.weights and not preset.caps

          if hasSubPresets then
            local specSubmenu = {
              sortKey = (specInfo[specId] and specInfo[specId].name) or tostring(specId),
              text = (specInfo[specId] and specInfo[specId].name) or tostring(specId),
              prioritySort = 0,
              isSubmenu = true,
              submenuItems = {}
            }
            if specInfo[specId] then
              specSubmenu.text = CreateIconMarkup(specInfo[specId].icon) .. specInfo[specId].name
            end

            for subK, subPreset in pairs(preset) do
              if type(subPreset) == "table" and (subPreset.weights or subPreset.caps) then
                local subSubInfo = {
                  sortKey = subK,
                  text = subK,
                  prioritySort = DYNAMIC_PRESETS[subK] or 0,
                  value = subPreset,
                }
                if subPreset.icon then
                  subSubInfo.text = CreateIconMarkup(subPreset.icon) .. subSubInfo.text
                end
                tinsert(specSubmenu.submenuItems, subSubInfo)
              end
            end

            if #specSubmenu.submenuItems > 0 then
              tsort(specSubmenu.submenuItems, function (a, b)
                if a.prioritySort ~= b.prioritySort then
                  return a.prioritySort > b.prioritySort
                end
                return tostring(a.sortKey) < tostring(b.sortKey)
              end)
              tinsert(classInfo.submenuItems, specSubmenu)
            end
          else
            local subInfo = {
              sortKey = preset.name or (specInfo[specId] and specInfo[specId].name) or tostring(specId),
              text = preset.name or (specInfo[specId] and specInfo[specId].name) or tostring(specId),
              prioritySort = DYNAMIC_PRESETS[k] or 0,
              value = preset,
              hasDelete = (k == CUSTOM),
              presetName = preset.name,
            }
            if specInfo[specId] then
              subInfo.text = CreateIconMarkup(specInfo[specId].icon) .. specInfo[specId].name
              subInfo.sortKey = specInfo[specId].name
            end
            if preset.icon then
              subInfo.text = CreateIconMarkup(preset.icon) .. subInfo.text
            end
            tinsert(classInfo.submenuItems, subInfo)
          end
        end

        tsort(classInfo.submenuItems, function (a, b)
          if a.prioritySort ~= b.prioritySort then
            return a.prioritySort > b.prioritySort
          end
          return tostring(a.sortKey) < tostring(b.sortKey)
        end)

        tinsert(menuList, classInfo)
      else
        local info = {
          sortKey = v.name or k,
          text = v.name or k,
          prioritySort = DYNAMIC_PRESETS[k] or 0,
          value = v,
        }
        if specInfo[k] then
          info.text = CreateIconMarkup(specInfo[k].icon) .. specInfo[k].name
          info.sortKey = specInfo[k].name
        end
        if v.icon then
          info.text = CreateIconMarkup(v.icon) .. info.text
        end
        tinsert(menuList, info)
      end
    end

    tsort(menuList, function (a, b)
      if a.prioritySort ~= b.prioritySort then
        return a.prioritySort > b.prioritySort
      end
      return tostring(a.sortKey) < tostring(b.sortKey)
    end)

    local function AddMenuItems(desc, items)
      for _, info in ipairs(items) do
        if info.isSubmenu then
          local submenu = desc:CreateButton(info.text)
          if #info.submenuItems == 0 then
            submenu:SetEnabled(false)
          end
          AddMenuItems(submenu, info.submenuItems)
        elseif info.value and (info.value.caps or info.value.weights) then
          AddPresetButton(desc, info)
        end
      end
    end

    AddMenuItems(rootDescription, menuList)
  end

  --@debug@
  addonTable.callbacks:RegisterCallback("ToggleDebug", function() self:InitDynamicPresets() end)
  --@end-debug@
end
