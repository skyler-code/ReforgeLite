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
function ReforgeLite:GetMeleeHasteBonus()
  local baseBonus = RoundToSignificantDigits((GetMeleeHaste()+100)/(GetCombatRatingBonus(CR_HASTE_MELEE)+100), 4)
  if self.pdb.meleeHaste then
    local _, meleeHaste = self:GetPlayerBuffs()
    if self.pdb.spellHaste and not meleeHaste then
      baseBonus = baseBonus * 1.1
    end
  end
  return baseBonus
end
function ReforgeLite:GetRangedHasteBonus()
  local baseBonus = RoundToSignificantDigits((GetRangedHaste()+100)/(GetCombatRatingBonus(CR_HASTE_RANGED)+100), 4)
  if self.pdb.meleeHaste then
    local _, meleeHaste = self:GetPlayerBuffs()
    if self.pdb.spellHaste and not meleeHaste then
      baseBonus = baseBonus * 1.1
    end
  end
  return baseBonus
end
function ReforgeLite:GetSpellHasteBonus()
  local baseBonus = (UnitSpellHaste('PLAYER')+100)/(GetCombatRatingBonus(CR_HASTE_SPELL)+100)
  if self.pdb.spellHaste then
    local spellHaste = self:GetPlayerBuffs()
    if self.pdb.spellHaste and not spellHaste then
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
      local conv = ReforgeLite:GetConversion()
      local result = ReforgeLite:RatingPerPoint (addonTable.statIds.SPELLHIT) * (ReforgeLite:GetNeededSpellHit () - ReforgeLite:GetSpellHitBonus ())
      if conv[StatExp] and conv[StatExp][StatHit] then
        result = result + math.floor(GetCombatRating(CR_EXPERTISE) * conv[StatExp][StatHit])
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

-- local function GetSpellHasteRequired(percentNeeded)
--   return function()
--     local hasteMod = ReforgeLite:GetSpellHasteBonus()
--     return ceil((percentNeeded - (hasteMod - 1) * 100) * ReforgeLite:RatingPerPoint(addonTable.statIds.HASTE) / hasteMod)
--   end
-- end

-- local function GetRangedHasteRequired(percentNeeded)
--   return function()
--     local hasteMod = ReforgeLite:GetRangedHasteBonus()
--     return ceil((percentNeeded - (hasteMod - 1) * 100) * ReforgeLite:RatingPerPoint(addonTable.statIds.HASTE) / hasteMod)
--   end
-- end

-- do
--   local nameFormat = "%s%s%% +%s %s "
--   local nameFormatWithTicks = nameFormat..L["ticks"]
--   if addonTable.playerClass == "DRUID" then
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.FirstHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(CreateIconMarkup(136081), 18.74, 2, C_Spell.GetSpellName(774)),
--       getter = GetSpellHasteRequired(12.51),
--     })
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.SecondHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(CreateIconMarkup(236153)..CreateIconMarkup(134222), 21.43, 1, C_Spell.GetSpellName(48438) .. " / " .. C_Spell.GetSpellName(81269)),
--       getter = GetSpellHasteRequired(21.4345),
--     })
--   elseif addonTable.playerClass == "PRIEST" then
--     local devouringPlague, devouringPlagueMarkup = C_Spell.GetSpellName(2944), CreateIconMarkup(252997)
--     local shadowWordPain, shadowWordPainMarkup = C_Spell.GetSpellName(589), CreateIconMarkup(136207)
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.FirstHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(devouringPlagueMarkup, 18.74, 2, devouringPlague),
--       getter = GetSpellHasteRequired(18.74),
--     })
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.SecondHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(shadowWordPainMarkup, 24.97, 2, shadowWordPain),
--       getter = GetSpellHasteRequired(24.97),
--     })
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.ThirdHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(CreateIconMarkup(135978), 30.01, 2, C_Spell.GetSpellName(589)),
--       getter = GetSpellHasteRequired(30.01),
--     })
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.FourthHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(devouringPlagueMarkup, 31.26, 3, devouringPlague),
--       getter = GetSpellHasteRequired(31.26),
--     })
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.FifthHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(shadowWordPainMarkup, 41.67, 3, shadowWordPain),
--       getter = GetSpellHasteRequired(41.675),
--     })
--   elseif addonTable.playerClass == "MAGE" then
--     local combustion, combustionMarkup = C_Spell.GetSpellName(11129), CreateIconMarkup(135824)
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.FirstHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(combustionMarkup, 15, 2, combustion),
--       getter = GetSpellHasteRequired(15.01),
--     })
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.SecondHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(combustionMarkup, 25, 3, combustion),
--       getter = GetSpellHasteRequired(25.08),
--     })
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.ThirdHasteBreak,
--       category = StatHaste,
--       name = ("%s %s %s"):format(CreateIconMarkup(135735), D_SECONDS:format(1), C_Spell.GetSpellName(30451)),
--       getter = function()
--         local percentNeeded = 13.86
--         local firelordCount = GetActiveItemSet()[931] or 0
--         if addonTable.playerRace == "Goblin" then
--           if firelordCount >= 4 then
--             percentNeeded = 2.43
--           else
--             percentNeeded = 12.68
--           end
--         elseif firelordCount >= 4 then
--           percentNeeded = 3.459
--         end
--         return ceil(ReforgeLite:RatingPerPoint (addonTable.statIds.HASTE) * percentNeeded)
--       end,
--     })
--   elseif addonTable.playerClass == "HUNTER" then
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.FirstHasteBreak,
--       category = StatHaste,
--       name = nameFormat:format(CreateIconMarkup(461114), 20, 3, C_Spell.GetSpellName(77767)),
--       getter = GetRangedHasteRequired(19.99),
--     })
--   elseif addonTable.playerClass == "SHAMAN" then
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.FirstHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(CreateIconMarkup(462328), 12.51, 1, C_Spell.GetSpellName(51730)),
--       getter = GetSpellHasteRequired(12.51),
--     })
--     tinsert(ReforgeLite.capPresets, {
--       value = CAPS.SecondHasteBreak,
--       category = StatHaste,
--       name = nameFormatWithTicks:format(CreateIconMarkup(252995), 21.44, 2, C_Spell.GetSpellName(61295)),
--       getter = GetSpellHasteRequired(21.4345),
--     })
--   end
-- end
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

local MeleeCaps = {
  HitCap,
  SoftExpCap
}

local RangedCaps = { HitCap }

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
        [RAID] = {
          targetLevel = 3,
          weights = {
            0, 110, 100, 150, 20, 50, 120, 200
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtMost,
                  preset = CAPS.MeleeHitCap,
                }
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  method = AtMost,
                  preset = CAPS.ExpSoftCap,
                },
              },
            },
          },
        },
        [LFG_TYPE_DUNGEON] = {
          targetLevel = 2,
          weights = {
            0, 0, 0, 200, 0, 50, 200, 150
          },
          caps = MeleeCaps,
        },
      },
      [specs.deathknight.frost] = {
        [C_Spell.GetSpellName(49020)] = { -- Obliterate
          icon = 135771,
          weights = {
            0, 0, 0, 200, 120, 160, 50, 90
          },
          caps = { HitCap },
        },
        [L["Masterfrost"]] = {
          icon = 135833,
          weights = {
            0, 0, 0, 200, 120, 150, 100, 180
          },
          caps = CasterCaps
        },
      },
      [specs.deathknight.unholy] = function()
        local gurth = C_Item.IsEquippedItem(77191) or C_Item.IsEquippedItem(78478) or C_Item.IsEquippedItem(78487)
        return {
          weights = gurth and {
            0, 0, 0, 350, 263, 301, 165, 248
          } or {
            0, 0, 0, 261, 233, 240, 113, 187
          },
          caps = { HitCap },
        }
      end,
    },
    ["DRUID"] = {
      [specs.druid.balance] = {
        weights = {
          0, 0, 0, 200, 100, 150, 0, 130
        },
        caps = CasterCaps,
      },
      [specs.druid.feralcombat] = {
        [("%s (%s)"):format(C_Spell.GetSpellName(768), L["Monocat"])] = { -- Cat Form (Monocat)
          icon = 132115,
          weights = {
            0, 0, 0, 30, 31, 28, 30, 31
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtMost,
                  preset = CAPS.MeleeHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  method = AtMost,
                  preset = CAPS.ExpSoftCap,
                },
              },
            },
          },
        },
        [("%s (%s)"):format(C_Spell.GetSpellName(768), L["Bearweave"])] = { -- Cat Form (Bearweave)
          icon = 132115,
          weights = {
            0, 0, 0, 33, 31, 26, 32, 30
          },
          caps = MeleeCaps,
        },
      },
      [specs.druid.guardian] = {
        [("%s (%s)"):format(C_Spell.GetSpellName(5487), TANK)] = { -- Bear Form (Tank)
          icon = 132276,
          weights = {
            0, 54, 0, 25, 53, 7, 48, 37
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtMost,
                  preset = CAPS.MeleeHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  method = AtMost,
                  preset = CAPS.ExpSoftCap,
                },
              },
            },
          },
        },
        [("%s (%s)"):format(C_Spell.GetSpellName(5487), STAT_DPS_SHORT)] = { -- Bear Form (DPS)
          icon = 132276,
          weights = {
            0, -6, 0, 100, 50, 25, 100, -1
          },
          caps = MeleeCaps,
        },
      },
      [specs.druid.restoration] = {
        [MANA_REGEN_ABBR] = {
          weights = {
            150, 0, 0, 0, 130, 160, 0, 140
          },
          caps = {
            {
              stat = StatHaste,
              points = {
                {
                  method = AtLeast,
                  preset = CAPS.FirstHasteBreak,
                  after = 120,
                },
              },
            },
          },
        },
        [BONUS_HEALING] = {
          weights = {
            140, 0, 0, 0, 130, 160, 0, 150
          },
          caps = {
            {
              stat = StatHaste,
              points = {
                {
                  method = AtLeast,
                  preset = CAPS.FirstHasteBreak,
                  after = 120,
                },
              },
            },
          },
        },
      }
    },
    ["HUNTER"] = {
      [specs.hunter.beastmastery] = {
        weights = {
          0, 0, 0, 200, 150, 80, 0, 110
        },
        caps = RangedCaps,
      },
      [specs.hunter.marksmanship] = {
        weights = {
          0, 0, 0, 200, 150, 110, 0, 80
        },
        caps = RangedCaps,
      },
      [specs.hunter.survival] = {
        weights = {
          0, 0, 0, 200, 110, 80, 0, 40
        },
        caps = {
          HitCap,
          {
            stat = StatHaste,
            points = {
              {
                method = AtMost,
                preset = CAPS.FirstHasteBreak,
                after = 0,
              },
            },
          },
        },
      },
    },
    ["MAGE"] = {
      [specs.mage.arcane] = {
        weights = {
          0, 0, 0, 5, 1, 4, 0, 3
        },
        caps = {
          HitCapSpell,
          {
            stat = StatHaste,
            points = {
              {
                method = AtLeast,
                preset = CAPS.ThirdHasteBreak,
                after = 2,
              },
            },
          },
        },
      },
      [specs.mage.fire] = {
        [PERCENTAGE_STRING:format(15) .. " " .. STAT_HASTE] = {
          weights = {
            0, 0, 0, 5, 3, 4, 0, 1
          },
          caps = {
            HitCapSpell,
            {
              stat = StatHaste,
              points = {
                {
                  method = AtLeast,
                  preset = CAPS.FirstHasteBreak,
                  after = 2,
                },
              },
            },
          },
        },
        [PERCENTAGE_STRING:format(25) .. " " .. STAT_HASTE] = {
          weights = {
            0, 0, 0, 5, 3, 4, 0, 1
          },
          caps = {
            HitCapSpell,
            {
              stat = StatHaste,
              points = {
                {
                  method = AtLeast,
                  preset = CAPS.SecondHasteBreak,
                  after = 2,
                },
              },
            },
          },
        },
      },
      [specs.mage.frost] = {
        weights = {
          0, 0, 0, 200, 180, 140, 0, 130
        },
        caps = {
          HitCapSpell,
          {
            stat = StatCrit,
            points = {
              {
                method = AtMost,
                value = addonTable.playerRace == "Worgen" and 2922 or 3101,
                after = 100,
              }
            }
          }
        },
      },
    },
    ["MONK"] = {
      [specs.monk.brewmaster] = {
        weights = {
          0, 0, 0, 0, 0, 0, 0, 0
        },
      },
      [specs.monk.mistweaver] = {
        weights = {
          0, 0, 0, 0, 0, 0, 0, 0
        },
      },
      [specs.monk.windwalker] = {
        weights = {
          0, 0, 0, 0, 0, 0, 0, 0
        },
      },
    },
    ["PALADIN"] = {
      [specs.paladin.holy] = {
        weights = {
          160, 0, 0, 0, 80, 200, 0, 120
        },
      },
      [specs.paladin.protection] = {
        [PET_DEFENSIVE] = {
          weights = {
            -1, 100, 100, 20, 0, 0, 50, 80
          },
        },
        [DAMAGE] = {
          weights = {
            0, 0, 0, 4, 0, 0, 5, 2
          },
          caps = {
            {
              stat = StatExp,
              points = {
                {
                  method = AtLeast,
                  preset = CAPS.ExpSoftCap,
                  after = 3,
                },
                {
                  method = AtMost,
                  preset = CAPS.ExpHardCap,
                },
              },
            },
            {
              stat = StatHit,
              points = {
                {
                  method = AtMost,
                  preset = CAPS.MeleeHitCap,
                }
              },
            },
          },
        },
      },
      [specs.paladin.retribution] = {
        weights = {
          0, 0, 0, 200, 135, 110, 180, 150
        },
        caps = MeleeCaps,
      },
    },
    ["PRIEST"] = {
      [specs.priest.discipline] = {
        weights = {
          150, 0, 0, 0, 100, 120, 0, 80
        },
      },
      [specs.priest.holy] = {
        weights = {
          150, 0, 0, 0, 80, 120, 0, 100
        },
      },
      [specs.priest.shadow] = {
        weights = {
          0, 0, 0, 200, 100, 140, 0, 130
        },
        caps = CasterCaps
      },
    },
    ["ROGUE"] = {
      [specs.rogue.assassination] = {
        weights = {
          0, 0, 0, 200, 110, 130, 120, 140
        },
        caps = {
          {
            stat = StatHit,
            points = {
              {
                method = AtLeast,
                preset = CAPS.SpellHitCap,
                after = 82,
              },
            },
          },
          {
            stat = StatExp,
            points = {
              {
                method = AtMost,
                preset = CAPS.ExpSoftCap,
              },
            },
          },
        },
      },
      [specs.rogue.combat] = {
        weights = {
          0, 0, 0, 200, 125, 170, 215, 150
        },
        caps = {
          {
            stat = StatExp,
            points = {
              {
                method = AtLeast,
                preset = CAPS.ExpSoftCap,
              },
            },
          },
          {
            stat = StatHit,
            points = {
              {
                method = AtLeast,
                preset = CAPS.SpellHitCap,
                after = 100,
              },
            },
          },
        },
      },
      [specs.rogue.subtlety] = {
        weights = {
          0, 0, 0, 155, 145, 155, 130, 90
        },
        caps = {
          {
            stat = StatHit,
            points = {
              {
                method = AtLeast,
                preset = CAPS.MeleeHitCap,
                after = 110,
              },
              {
                preset = CAPS.SpellHitCap,
                after = 80,
              },
            },
          },
          {
            stat = StatExp,
            points = {
              {
                preset = CAPS.ExpSoftCap,
              },
            },
          },
        },
      },
    },
    ["SHAMAN"] = {
      [specs.shaman.elemental] = {
        weights = {
          0, 0, 0, 200, 80, 140, 0, 120
        },
        caps = CasterCaps,
      },
      [specs.shaman.enhancement] = {
        weights = {
          0, 0, 0, 250, 120, 80, 190, 150
        },
        caps = {
          {
            stat = StatHit,
            points = {
              {
                method = AtLeast,
                preset = CAPS.SpellHitCap,
                after = 50,
              },
            },
          },
          {
            stat = StatExp,
            points = {
              {
                method = AtLeast,
                preset = CAPS.ExpSoftCap,
              },
            },
          },
        },
      },
      [specs.shaman.restoration] = {
        weights = {
          130, 0, 0, 0, 100, 100, 0, 100
        },
      },
    },
    ["WARLOCK"] = {
      [specs.warlock.afflication] = {
        weights = {
          0, 0, 0, 200, 140, 160, 0, 120
        },
        caps = CasterCaps,
      },
      [specs.warlock.destruction] = {
        weights = {
          0, 0, 0, 200, 140, 160, 0, 120
        },
        caps = CasterCaps,
      },
      [specs.warlock.demonology] = {
        weights = {
          0, 0, 0, 200, 120, 160, 0, 140
        },
        caps = CasterCaps,
      },
    },
    ["WARRIOR"] = {
      [specs.warrior.arms] = {
        weights = {
          0, 0, 0, 200, 150, 100, 200, 120
        },
        caps = MeleeCaps
      },
      [specs.warrior.fury] = {
        [C_Spell.GetSpellName(46917)] = { -- Titan's Grip
          icon = 236316,
          weights = {
            0, 0, 0, 200, 150, 100, 180, 130
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = CAPS.MeleeHitCap,
                  after = 140,
                },
              },
            },
            SoftExpCap
          },
        },
        [C_Spell.GetSpellName(81099)] = { -- Single-Minded Fury
          icon = 458974,
          weights = {
            0, 0, 0, 200, 150, 100, 180, 130
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = CAPS.MeleeHitCap,
                  after = 140,
                },
              },
            },
            SoftExpCap
          },
        },
      },
      [specs.warrior.protection] = {
        weights = {
          40, 100, 100, 0, 0, 0, 0, 40
        },
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
