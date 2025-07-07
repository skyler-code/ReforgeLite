local _, addonTable = ...
local L = addonTable.L
local ReforgeLite = addonTable.ReforgeLite
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
local tsort, tinsert = table.sort, tinsert

local StatHit = addonTable.statIds.HIT
local StatCrit = addonTable.statIds.CRIT
local StatHaste = addonTable.statIds.HASTE
local StatExp = addonTable.statIds.EXP

local SPELL_HASTE_BUFFS = {
  [24907] = true, -- Moonkin Aura
  [49868] = true, -- Mind Quickening
  [51470] = true, -- Elemental Oath
  [135678] = true, -- Energizing Spores
}

local MELEE_HASTE_BUFFS = {
  [55610] = true, -- Unholy Aura
  [128432] = true, -- Cackling Howl
  [128433] = true, -- Serpent's Swiftness
  [113742] = true, -- Swiftblade's Cunning
  [30809] = true, -- Unleashed Rage
}

function ReforgeLite:GetPlayerBuffs()
  local spellHaste, meleeHaste
  local slots = {C_UnitAuras.GetAuraSlots('player','helpful')}
  for i = 2, #slots do
    local aura = C_UnitAuras.GetAuraDataBySlot('player',slots[i])
    if aura then
      local id = aura.spellId
      if SPELL_HASTE_BUFFS[id] then
        spellHaste = true
      elseif MELEE_HASTE_BUFFS[id] then
        meleeHaste = true
      end
    end
  end
  return spellHaste, meleeHaste
end

----------------------------------------- CAP PRESETS ---------------------------------

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
  if self.pdb.meleeHaste then
    local _, meleeHaste = self:GetPlayerBuffs()
    if not meleeHaste then
      baseBonus = baseBonus * 1.1
    end
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
  if self.pdb.spellHaste then
    local spellHaste = self:GetPlayerBuffs()
    if not spellHaste then
      baseBonus = baseBonus * 1.05
    end
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
  return math.max(0, 3 + 1.5 * self.pdb.targetLevel)
end
function ReforgeLite:GetNeededSpellHit ()
  local diff = self.pdb.targetLevel
  if diff <= 3 then
    return math.max(0, 6 + 3 * diff)
  else
    return 11 * diff - 18
  end
end

function ReforgeLite:GetNeededExpertiseSoft()
  return math.max(0, 3 + 1.5 * self.pdb.targetLevel)
end

function ReforgeLite:GetNeededExpertiseHard()
  return math.max(0, 6 + 3 * self.pdb.targetLevel)
end

local function CreateIconMarkup(icon)
  return CreateSimpleTextureMarkup(icon, 16, 16) .. " "
end

local AtLeast = addonTable.StatCapMethods.AtLeast
local AtMost = addonTable.StatCapMethods.AtMost

local CAPS = {
  ManualCap = 1,
  MeleeHitCap = 2,
  SpellHitCap = 3,
  MeleeDWHitCap = 4,
  ExpSoftCap = 5,
  ExpHardCap = 6,
  FirstHasteBreak = 7,
  SecondHasteBreak = 8,
  ThirdHasteBreak = 9,
  FourthHasteBreak = 10,
  FifthHasteBreak = 11,
}

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
      return ReforgeLite:RatingPerPoint (StatHit) * (ReforgeLite:GetNeededMeleeHit () - ReforgeLite:GetMeleeHitBonus ())
    end,
    category = StatHit
  },
  {
    value = CAPS.SpellHitCap,
    name = L["Spell hit cap"],
    getter = function ()
      local result = ReforgeLite:RatingPerPoint (addonTable.statIds.SPELLHIT) * (ReforgeLite:GetNeededSpellHit () - ReforgeLite:GetSpellHitBonus ())
      if ReforgeLite.conversion[StatExp] and ReforgeLite.conversion[StatExp][StatHit] then
        result = result + math.floor(GetCombatRating(CR_EXPERTISE) * ReforgeLite.conversion[StatExp][StatHit])
      end
      return result
    end,
    category = StatHit
  },
  {
    value = CAPS.MeleeDWHitCap,
    name = L["Melee DW hit cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (StatHit) * (ReforgeLite:GetNeededMeleeHit () + 19 - ReforgeLite:GetMeleeHitBonus ())
    end,
    category = StatHit
  },
  {
    value = CAPS.ExpSoftCap,
    name = L["Expertise soft cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (StatExp) * (ReforgeLite:GetNeededExpertiseSoft () - ReforgeLite:GetExpertiseBonus ())
    end,
    category = StatExp
  },
  {
    value = CAPS.ExpHardCap,
    name = L["Expertise hard cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (StatExp) * (ReforgeLite:GetNeededExpertiseHard () - ReforgeLite:GetExpertiseBonus ())
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
      name = nameFormatWithTicks:format(CreateIconMarkup(136081)..CreateIconMarkup(136107), 7.16, 1, C_Spell.GetSpellName(774) .. " / " .. C_Spell.GetSpellName(740)),
      getter = GetSpellHasteRequired(7.16),
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
  end
end
----------------------------------------- WEIGHT PRESETS ------------------------------

local HitCap = {
  stat = StatHit,
  points = {
    {
      method = AtLeast,
      preset = CAPS.MeleeHitCap
    }
  }
}

local HitCapSpell = {
  stat = StatHit,
  points = {
    {
      method = AtLeast,
      preset = CAPS.SpellHitCap,
    }
  }
}

local SoftExpCap = {
  stat = StatExp,
  points = {
    {
      method = AtLeast,
      preset = CAPS.ExpSoftCap
    }
  }
}

local HardExpCap = {
  stat = StatExp,
  points = {
    {
      method = AtLeast,
      preset = CAPS.ExpHardCap
    }
  }
}

local MeleeCaps = {
  HitCap,
  SoftExpCap
}

local TankCaps = {
  HitCap,
  HardExpCap
}

local CasterCaps = { HitCapSpell }

local specInfo = {}

do

  local specs = {
    deathknight = {
      blood = 250,
      frost = 251,
      unholy = 252
    },
    druid = {
      balance = 102,
      feralcombat = 103,
      guardian = 104,
      restoration = 105
    },
    hunter = {
      beastmastery = 253,
      marksmanship = 254,
      survival = 255
    },
    mage = {
      arcane = 62,
      fire = 63,
      frost = 64,
    },
    monk = {
      brewmaster = 268,
      mistweaver = 270,
      windwalker = 269,
    },
    paladin = {
      holy = 65,
      protection = 66,
      retribution = 70,
    },
    priest = {
      discipline = 256,
      holy = 257,
      shadow = 258
    },
    rogue = {
      assassination = 259,
      combat = 260,
      subtlety = 261
    },
    shaman = {
      elemental = 262,
      enhancement = 263,
      restoration = 264
    },
    warlock = {
      afflication = 265,
      demonology = 266,
      destruction = 267,
    },
    warrior = {
      arms = 71,
      fury = 72,
      protection = 73,
    }
  }

  for _,ids in pairs(specs) do
    for _, id in pairs(ids) do
      local _, tabName, _, icon = GetSpecializationInfoByID(id)
      specInfo[id] = { name = tabName, icon = icon }
    end
  end

  local presets = {
    ["DEATHKNIGHT"] = {
      [specs.deathknight.blood] = {
        [PET_DEFENSIVE] = {
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtMost,
                  preset = CAPS.MeleeHitCap,
                }
              }
            },
            {
              stat = StatExp,
              points = {
                {
                  method = AtMost,
                  preset = CAPS.ExpSoftCap,
                }
              }
            }
          },
          weights = {
            0, 140, 150, 100, 50, 75, 95, 200
          },
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
      [specs.deathknight.frost] = {
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
      [specs.deathknight.unholy] = {
          weights = {
            0, 0, 0, 73, 47, 43, 73, 40
          },
          caps = MeleeCaps,
      },
    },
    ["DRUID"] = {
      [specs.druid.balance] = {
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
      [specs.druid.feralcombat] = {
          weights = {
            0, 0, 0, 127, 60, 40, 127, 80
          },
          caps = MeleeCaps,
      },
      [specs.druid.guardian] = {
          weights = {
            0, 0, 0, 127, 80, 60, 127, 40
          },
          caps = TankCaps,
      },
      [specs.druid.restoration] = {
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
      [specs.hunter.beastmastery] = {
          weights = {
            0, 0, 0, 63, 30, 37, 59, 32
          },
          caps = MeleeCaps,
      },
      [specs.hunter.marksmanship] = {
          weights = {
            0, 0, 0, 63, 40, 35, 59, 29
          },
          caps = MeleeCaps,
      },
      [specs.hunter.survival] = {
          weights = {
            0, 0, 0, 59, 33, 25, 57, 21
          },
          caps = MeleeCaps,
      },
    },
    ["MAGE"] = {
      [specs.mage.arcane] = {
          weights = {
            0, 0, 0, 131, 53, 70, 0, 68
          },
          caps = CasterCaps,
      },
      [specs.mage.fire] = {
          weights = {
            0, 0, 0, 121, 88, 73, 0, 73
          },
          caps = CasterCaps,
      },
      [specs.mage.frost] = {
          weights = {
            0, 0, 0, 115, 49, 60, 0, 47
          },
          caps = CasterCaps,
      },
    },
    ["MONK"] = {
      [specs.monk.brewmaster] = {
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
      [specs.monk.mistweaver] = {
        weights = {
          0, 0, 0, 141, 46, 57, 99, 39
        },
        caps = MeleeCaps,
      },
      [specs.monk.windwalker] = {
        weights = {
          0, 0, 0, 141, 46, 57, 99, 39
        },
        caps = MeleeCaps,
      },
    },
    ["PALADIN"] = {
      [specs.paladin.holy] = {
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
      [specs.paladin.protection] = {
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
      [specs.paladin.retribution] = {
        weights = {
          0, 0, 0, 100, 50, 52, 87, 51
        },
        caps = MeleeCaps,
      },
    },
    ["PRIEST"] = {
      [specs.priest.discipline] = {
        weights = {
          120, 0, 0, 0, 120, 40, 0, 80
        },
      },
      [specs.priest.holy] = {
        weights = {
          150, 0, 0, 0, 120, 40, 0, 80
        },
      },
      [specs.priest.shadow] = {
        weights = {
          0, 0, 0, 200, 80, 120, 0, 40
        },
        caps = CasterCaps
      },
    },
    ["ROGUE"] = {
      [specs.rogue.assassination] = {
        weights = {
          0, 0, 0, 120, 35, 37, 120, 41
        },
        caps = MeleeCaps,
      },
      [specs.rogue.combat] = {
        weights = {
          0, 0, 0, 70, 29, 39, 56, 32
        },
        caps = MeleeCaps,
      },
      [specs.rogue.subtlety] = {
        weights = {
          0, 0, 0, 54, 31, 32, 35, 26
        },
        caps = MeleeCaps,
      },
    },
    ["SHAMAN"] = {
      [specs.shaman.elemental] = {
        weights = {
          0, 0, 0, 60, 20, 40, 0, 30
        },
        caps = CasterCaps,
      },
      [specs.shaman.enhancement] = {
        weights = {
          0, 0, 0, 149, 66, 84, 130, 121
        },
        caps = MeleeCaps,
      },
      [specs.shaman.restoration] = {
        weights = {
          120, 0, 0, 0, 100, 150, 0, 75
        },
      },
    },
    ["WARLOCK"] = {
      [specs.warlock.afflication] = {
        weights = {
          0, 0, 0, 150, 50, 120, 0, 100
        },
        caps = CasterCaps,
      },
      [specs.warlock.destruction] = {
        weights = {
          0, 0, 0, 83, 59, 57, 0, 61
        },
        caps = CasterCaps,
      },
      [specs.warlock.demonology] = {
        weights = {
          0, 0, 0, 150, 50, 100, 0, 120
        },
        caps = CasterCaps,
      },
    },
    ["WARRIOR"] = {
      [specs.warrior.arms] = {
        weights = {
          0, 0, 0, 140, 59, 32, 120, 39
        },
        caps = MeleeCaps
      },
      [specs.warrior.fury] = {
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
      [specs.warrior.protection] = {
        weights = {
          0, 140, 150, 200, 25, 50, 200, 100
        },
        caps = TankCaps,
      },
    },
  }
  --[===[@non-debug@
  ReforgeLite.presets = presets[addonTable.playerClass]
  --@end-non-debug@]===]
  --@debug@
  ReforgeLite.presets = presets
  --@end-debug@
end

function ReforgeLite:InitCustomPresets()
  local customPresets = {}
  for k, v in pairs(self.cdb.customPresets) do
    local preset = addonTable.DeepCopy(v)
    preset.name = k
    tinsert(customPresets, preset)
  end
  self.presets[CUSTOM] = customPresets
end

function ReforgeLite:InitPresets()
  self:InitCustomPresets()
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
          for i = 1, #self.itemStats do
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
            for i = 1, #self.itemStats do
              preset.weights[i] = preset.weights[i] * factor
            end
            tinsert(result, preset)
          end
        end
      end
      return result
    end
  end

  local menuListInit = function(options)
    return function (menu, level)
      if not level then return end
      local list = menu.list
      if level > 1 then
        list = L_UIDROPDOWNMENU_MENU_VALUE
      else
        addonTable.GUI:ClearEditFocus()
      end
      local menuList = {}
      for k in pairs (list) do
        local v = GetValueOrCallFunction(list, k)
        local info = LibDD:UIDropDownMenu_CreateInfo()
        info.notCheckable = true
        info.sortKey = v.name or k
        info.text = info.sortKey
        info.prioritySort = v.prioritySort or 0
        info.value = v
        if specInfo[k] then
          info.text = CreateIconMarkup(specInfo[k].icon) .. specInfo[k].name
          info.sortKey = specInfo[k].name
          info.prioritySort = -1
        end
        if v.icon then
          info.text = CreateIconMarkup(v.icon) .. info.text
        end
        if v.tip then
          info.tooltipTitle = v.tip
          info.tooltipOnButton = true
        end
        if v.caps or v.weights then
          info.func = function()
            LibDD:CloseDropDownMenus()
            options.onClick(info)
          end
        else
          if next (v) then
            info.hasArrow = true
          else
            info.disabled = true
          end
          info.keepShownOnClick = true
        end
        tinsert(menuList, info)
      end
      tsort(menuList, function (a, b)
        if a.prioritySort ~= b.prioritySort then
          return a.prioritySort > b.prioritySort
        end
        return a.sortKey < b.sortKey
      end)
      for _,v in ipairs(menuList) do
        LibDD:UIDropDownMenu_AddButton (v, level)
      end
    end
  end

  self.presetMenu = LibDD:Create_UIDropDownMenu("ReforgeLitePresetMenu", self)
  self.presetMenu.list = self.presets
  LibDD:UIDropDownMenu_Initialize(self.presetMenu, menuListInit({
    onClick = function(info)
      if info.value.targetLevel then
        self.pdb.targetLevel = info.value.targetLevel
        self.targetLevel:SetValue(info.value.targetLevel)
      end
      self:SetStatWeights(info.value.weights, info.value.caps or {})
    end
  }), "MENU")

  local exportList = {
    [REFORGE_CURRENT] = function()
      local result = {
        prioritySort = 1,
        caps = self.pdb.caps,
        weights = self.pdb.weights,
      }
      return result
    end
  }
  addonTable.MergeTables(exportList, self.presets)

  --@debug@
  self.exportPresetMenu = LibDD:Create_UIDropDownMenu("ReforgeLiteExportPresetMenu", self)
  self.exportPresetMenu.list = exportList
  LibDD:UIDropDownMenu_Initialize(self.exportPresetMenu, menuListInit({
    onClick = function(info)
      local output = addonTable.DeepCopy(info.value)
      output.prioritySort = nil
      self:ExportJSON(output, info.sortKey)
    end
  }), "MENU")
  --@end-debug@

  self.presetDelMenu = LibDD:Create_UIDropDownMenu("ReforgeLitePresetDelMenu", self)
  LibDD:UIDropDownMenu_Initialize(self.presetDelMenu, function (menu, level)
    if level ~= 1 then return end
    addonTable.GUI:ClearEditFocus()
    local menuList = {}
    for _, db in ipairs({self.db, self.cdb}) do
      for k in pairs(db.customPresets or {}) do
        local info = LibDD:UIDropDownMenu_CreateInfo()
        info.notCheckable = true
        info.text = k
        info.func = function()
          db.customPresets[k] = nil
          self:InitCustomPresets()
          if not self:CustomPresetsExist() then
            self.deletePresetButton:Disable()
          end
          LibDD:CloseDropDownMenus()
        end
        tinsert(menuList, info)
      end
    end
    tsort(menuList, function (a, b) return a.text < b.text end)
    for _,v in ipairs(menuList) do
      LibDD:UIDropDownMenu_AddButton(v, level)
    end
  end, "MENU")

end
