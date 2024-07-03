local _, addonTable = ...
local L = addonTable.L
local ReforgeLite = addonTable.ReforgeLite
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
local tsort, tinsert = table.sort, tinsert

----------------------------------------- CAP PRESETS ---------------------------------

function ReforgeLite:RatingPerPoint (stat, level)
  level = level or UnitLevel ("player")
  local factor
  if level <= 34 and (stat == self.STATS.DODGE or stat == self.STATS.PARRY) then
    factor = 0.5
  elseif level <= 10 then
    factor = 1 / 26
  elseif level <= 60 then
    factor = (level - 8) / 52
  elseif level <= 70 then
    factor = 82 / (262 - 3 * level)
  elseif level <= 80 then
    factor = (82 / 52) * ((131 / 63) ^ ((level - 70) / 10))
  else
    factor = (82 / 52) * (131 / 63)
    if level == 81 then
      factor = factor * 1.31309
    elseif level == 82 then
      factor = factor * 1.72430
    elseif level == 83 then
      factor = factor * 2.26519
    elseif level == 84 then
      factor = factor * 2.97430
    elseif level == 85 then
      factor = factor * 3.90537
    end
  end
  if stat == self.STATS.DODGE or stat == self.STATS.PARRY then
    return factor * 13.8
  elseif stat == self.STATS.HIT then
    return factor * 9.37931
  elseif stat == self.STATS.SPELLHIT then
    return factor * 8
  elseif stat == self.STATS.HASTE then
    return factor * 10
  elseif stat == self.STATS.CRIT then
    return factor * 14
  elseif stat == self.STATS.EXP then
    return factor * 2.34483
  elseif stat == self.STATS.MASTERY then
    return factor * 14
  end
  return 0
end
function ReforgeLite:GetMeleeHitBonus ()
  return GetHitModifier () or 0
end
function ReforgeLite:GetSpellHitBonus ()
  return GetSpellHitModifier () or 0
end
function ReforgeLite:GetExpertiseBonus ()
  local bonus = GetExpertise() - floor(GetCombatRatingBonus (CR_EXPERTISE))
  if addonTable.playerClass == "PALADIN" and IsPlayerSpell(56416) and not (C_UnitAuras.GetPlayerAuraBySpellID(31801) or C_UnitAuras.GetPlayerAuraBySpellID(20154)) then
    bonus = bonus + 10
  end
  return bonus
end
function ReforgeLite:GetNeededMeleeHit ()
  local diff = self.pdb.targetLevel
  if diff <= 2 then
    return max (0, 5 + 0.5 * diff)
  else
    return 2 + 2 * diff
  end
end
function ReforgeLite:GetNeededSpellHit ()
  local diff = self.pdb.targetLevel
  if diff <= 2 then
    return max (0, 4 + diff)
  else
    return 11 * diff - 16
  end
end
function ReforgeLite:GetNeededExpertiseSoft ()
  local diff = self.pdb.targetLevel
  return ceil (max (0, 5 + 0.5 * diff) / 0.25)
end
function ReforgeLite:GetNeededExpertiseHard ()
  local diff = self.pdb.targetLevel
  if diff <= 2 then
    return ceil (max (0, 5 + 0.5 * diff) / 0.25)
  else
    return ceil (14 / 0.25)
  end
end

local AtLeast = addonTable.StatCapMethods.AtLeast
local AtMost = addonTable.StatCapMethods.AtMost

local StatHit = ReforgeLite.STATS.HIT
local StatCrit = ReforgeLite.STATS.CRIT
local StatHaste = ReforgeLite.STATS.HASTE
local StatExp = ReforgeLite.STATS.EXP

local CAPS = {
  ManualCap = 1,
  MeleeHitCap = 2,
  SpellHitCap = 3,
  MeleeDWHitCap = 4,
  ExpSoftCap = 5,
  ExpHardCap = 6,
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
      return ReforgeLite:RatingPerPoint (ReforgeLite.STATS.HIT) * (ReforgeLite:GetNeededMeleeHit () - ReforgeLite:GetMeleeHitBonus ())
    end
  },
  {
    value = CAPS.SpellHitCap,
    name = L["Spell hit cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (ReforgeLite.STATS.SPELLHIT) * (ReforgeLite:GetNeededSpellHit () - ReforgeLite:GetSpellHitBonus ())
    end
  },
  {
    value = CAPS.MeleeDWHitCap,
    name = L["Melee DW hit cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (ReforgeLite.STATS.HIT) * (ReforgeLite:GetNeededMeleeHit () + 19 - ReforgeLite:GetMeleeHitBonus ())
    end
  },
  {
    value = CAPS.ExpSoftCap,
    name = L["Expertise soft cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (ReforgeLite.STATS.EXP) * (ReforgeLite:GetNeededExpertiseSoft () - ReforgeLite:GetExpertiseBonus ())
    end
  },
  {
    value = CAPS.ExpHardCap,
    name = L["Expertise hard cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (ReforgeLite.STATS.EXP) * (ReforgeLite:GetNeededExpertiseHard () - ReforgeLite:GetExpertiseBonus ())
    end
  },
}

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

local function CreateIconMarkup(icon)
  return CreateSimpleTextureMarkup(icon, 18, 18) .. " "
end

do
  local specs = {
    DEATHKNIGHTBlood = 398,
    DEATHKNIGHTFrost = 399,
    DEATHKNIGHTUnholy = 400,
    DRUIDBalance = 752,
    DRUIDFeralCombat = 750,
    DRUIDRestoration = 748,
    HUNTERBeastMastery = 811,
    HUNTERMarksmanship = 807,
    HUNTERSurvival = 809,
    MAGEArcane = 799,
    MAGEFire = 851,
    MAGEFrost = 823,
    PALADINHoly = 831,
    PALADINProtection = 839,
    PALADINRetribution = 855,
    PRIESTDiscipline = 760,
    PRIESTHoly = 813,
    PRIESTShadow = 795,
    ROGUEAssassination = 182,
    ROGUECombat = 181,
    ROGUESubtlety = 183,
    SHAMANElemental = 261,
    SHAMANEnhancement = 263,
    SHAMANRestoration = 262,
    WARLOCKAffliction = 871,
    WARLOCKDemonology = 867,
    WARLOCKDestruction = 865,
    WARRIORArms = 746,
    WARRIORFury = 815,
    WARRIORProtection = 845,
  }

  for _,v in pairs(specs) do
    local _, tabName, _, icon = GetSpecializationInfoForSpecID(v)
    specInfo[v] = { name = tabName, icon = icon }
  end

  local presets = {
    ["DEATHKNIGHT"] = {
      [specs.DEATHKNIGHTBlood] = {
        [RAID] = {
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
          weights = {
            0, 0, 0, 200, 0, 50, 200, 150
          },
          caps = MeleeCaps,
        },
      },
      [specs.DEATHKNIGHTFrost] = {
        [GetSpellInfo(49020)] = { -- Obliterate
          icon = 135771,
          weights = {
            0, 0, 0, 229, 116, 147, 164, 144
          },
          caps = { HitCap },
        },
        ["Masterfrost"] = {
          icon = 135833,
          weights = {
            0, 0, 0, 200, 120, 150, 100, 180
          },
          caps = CasterCaps
        },
      },
      [specs.DEATHKNIGHTUnholy] = {
        [VIDEO_OPTIONS_STANDARD] = {
          icon = 133572,
          prioritySort = 1,
          weights = {
            0, 0, 0, 200, 130, 160, 100, 110
          },
          caps = { HitCap },
        },
        [(C_Item.GetItemNameByID(78478) or "Gurthalak, Voice of the Deeps")] = {
          icon = 531208,
          weights = {
            0, 0, 0, 200, 120, 160, 100, 130
          },
          caps = { HitCap },
        },
      },
    },
    ["DRUID"] = {
      [specs.DRUIDBalance] = {
        weights = {
          0, 0, 0, 200, 100, 150, 0, 130
        },
        caps = CasterCaps,
      },
      [specs.DRUIDFeralCombat] = {
        [("%s (%s)"):format(GetSpellInfo(5487), TANK)] = { -- Bear
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
        [("%s (%s)"):format(GetSpellInfo(5487), STAT_DPS_SHORT)] = { -- Bear
          icon = 132276,
          weights = {
            0, -6, 0, 100, 50, 25, 100, -1
          },
          caps = MeleeCaps,
        },
        [("%s (%s)"):format(GetSpellInfo(768), "Monocat")] = { -- Cat
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
        [("%s (%s)"):format(GetSpellInfo(768), "Bearweave")] = { -- Cat
          icon = 132115,
          weights = {
            0, 0, 0, 33, 31, 26, 32, 30
          },
          caps = MeleeCaps,
        },
      },
      [specs.DRUIDRestoration] = {
        [MANA_REGEN_ABBR] = {
          weights = {
            150, 0, 0, 0, 130, 160, 0, 140
          },
          caps = {
            {
              stat = StatHaste,
              points = {
                {
                  preset = 1,
                  method = AtLeast,
                  value = ceil(ReforgeLite:RatingPerPoint (ReforgeLite.STATS.HASTE) * 15.65),
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
                  preset = 1,
                  method = AtLeast,
                  value = ceil(ReforgeLite:RatingPerPoint (ReforgeLite.STATS.HASTE) * 15.65),
                  after = 120,
                },
              },
            },
          },
        },
      }
    },
    ["HUNTER"] = {
      [specs.HUNTERBeastMastery] = {
        weights = {
          0, 0, 0, 200, 150, 80, 0, 110
        },
        caps = RangedCaps,
      },
      [specs.HUNTERMarksmanship] = {
        tip = "Sim it!",
        weights = {
          0, 0, 0, 200, 150, 110, 0, 80
        },
        caps = RangedCaps,
      },
      [specs.HUNTERSurvival] = {
        tip = "Sim it! Check WoWHead/Discord for Haste caps!!",
        weights = {
          0, 0, 0, 200, 110, 150, 0, 40
        },
        caps = {
          HitCap,
          {
            stat = StatHaste,
            points = {
              {
                method = AtLeast,
                value = 757,
                after = 80,
              },
            },
          },
        },
      },
    },
    ["MAGE"] = {
      [specs.MAGEArcane] = {
        [PLAYER_DIFFICULTY1] = {
          weights = {
            0, 0, 0, 5, 1, 4, -1, 3
          },
          caps = {
            HitCapSpell,
            {
              stat = StatHaste,
              points = {
                {
                  method = AtLeast,
                  value = addonTable.playerRace == "Goblin" and 1623 or 1767,
                  after = 2,
                },
              },
            },
          },
        },
        ["T11 4pc"] = {
          icon = 464778,
          weights = {
            0, 0, 0, 5, 1, 4, -1, 3
          },
          caps = {
            HitCapSpell,
            {
              stat = StatHaste,
              points = {
                {
                  method = AtLeast,
                  value = addonTable.playerRace == "Goblin" and 311 or 443,
                  after = 2,
                },
              },
            },
          },
        },
      },
      [specs.MAGEFire] = {
        [PERCENTAGE_STRING:format(15) .. " " .. STAT_HASTE] = {
          weights = {
            -1, -1, -1, 5, 3, 4, -1, 1
          },
          caps = {
            HitCapSpell,
            {
              stat = StatHaste,
              points = {
                {
                  method = AtLeast,
                  value = addonTable.playerRace == "Goblin" and 678 or 813,
                  after = 2,
                },
              },
            },
          },
        },
        [PERCENTAGE_STRING:format(25) .. " " .. STAT_HASTE] = {
          weights = {
            -1, -1, -1, 5, 3, 4, -1, 1
          },
          caps = {
            HitCapSpell,
            {
              stat = StatHaste,
              points = {
                {
                  method = AtLeast,
                  value = addonTable.playerRace == "Goblin" and 1858 or 2005,
                  after = 2,
                },
              },
            },
          },
        },
      },
      [specs.MAGEFrost] = {
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
    ["PALADIN"] = {
      [specs.PALADINHoly] = {
        weights = {
          160, 0, 0, 0, 80, 200, 0, 120
        },
      },
      [specs.PALADINProtection] = {
        [PET_DEFENSIVE] = {
          tanking = true,
          weights = {
            0, 4, 4, 3, 0, 0, 3, 5
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
      [specs.PALADINRetribution] = {
        weights = {
          0, 0, 0, 200, 135, 110, 180, 150
        },
        caps = MeleeCaps,
      },
    },
    ["PRIEST"] = {
      [specs.PRIESTDiscipline] = {
        weights = {
          150, 0, 0, 0, 100, 120, 0, 80
        },
      },
      [specs.PRIESTHoly] = {
        weights = {
          150, 0, 0, 0, 80, 120, 0, 100
        },
      },
      [specs.PRIESTShadow] = {
        weights = {
          0, 0, 0, 200, 100, 140, 0, 130
        },
        caps = CasterCaps
      },
    },
    ["ROGUE"] = {
      [specs.ROGUEAssassination] = {
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
              {
                preset = CAPS.MeleeDWHitCap,
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
      [specs.ROGUECombat] = {
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
              {
                preset = CAPS.MeleeDWHitCap,
              },
            },
          },
        },
      },
      [specs.ROGUESubtlety] = {
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
              {
                preset = CAPS.MeleeDWHitCap,
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
      [specs.SHAMANElemental] = {
        weights = {
          0, 0, 0, 200, 80, 140, 0, 120
        },
        caps = CasterCaps,
      },
      [specs.SHAMANEnhancement] = {
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
              {
                preset = CAPS.MeleeDWHitCap,
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
      [specs.SHAMANRestoration] = {
        weights = {
          130, 0, 0, 0, 100, 100, 0, 100
        },
      },
    },
    ["WARLOCK"] = {
      [specs.WARLOCKAffliction] = {
        weights = {
          0, 0, 0, 200, 140, 160, 0, 120
        },
        caps = CasterCaps,
      },
      [specs.WARLOCKDestruction] = {
        weights = {
          0, 0, 0, 200, 140, 160, 0, 120
        },
        caps = CasterCaps,
      },
      [specs.WARLOCKDemonology] = {
        weights = {
          0, 0, 0, 200, 120, 160, 0, 140
        },
        caps = CasterCaps,
      },
    },
    ["WARRIOR"] = {
      [specs.WARRIORArms] = {
        weights = {
          0, 0, 0, 200, 150, 100, 200, 120
        },
        caps = MeleeCaps
      },
      [specs.WARRIORFury] = {
        [GetSpellInfo(46917)] = { -- Titan's Grip
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
                {
                  value = 1300,
                  preset = 1,
                  after = 125
                },
                {
                  preset = CAPS.MeleeDWHitCap,
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
        [GetSpellInfo(81099)] = { -- Single-Minded Fury
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
                {
                  value = 1300,
                  preset = 1,
                  after = 125
                },
                {
                  preset = CAPS.MeleeDWHitCap,
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
      },
      [specs.WARRIORProtection] = {
        tanking = true,
        weights = {
          40, 100, 100, 0, 0, 0, 0, 40
        },
      },
    },
  }
  if ReforgeLite.isDev then
    ReforgeLite.presets = presets
  else
    ReforgeLite.presets = presets[addonTable.playerClass]
  end
end

function ReforgeLite:InitCustomPresets()
  local customPresets = {}
  for _, db in ipairs({self.db, self.cdb}) do
    for k, v in pairs(db.customPresets) do
      v.name = k
      tinsert(customPresets, v)
    end
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
          preset.weights[self.STATS.SPIRIT] = raw["Spirit"] or 0
          preset.weights[self.STATS.DODGE] = raw["DodgeRating"] or 0
          preset.weights[self.STATS.PARRY] = raw["ParryRating"] or 0
          preset.weights[self.STATS.HIT] = raw["HitRating"] or 0
          preset.weights[self.STATS.CRIT] = raw["CritRating"] or 0
          preset.weights[self.STATS.HASTE] = raw["HasteRating"] or 0
          preset.weights[self.STATS.EXP] = raw["ExpertiseRating"] or 0
          preset.weights[self.STATS.MASTERY] = raw["MasteryRating"] or 0
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
      self:SetStatWeights(info.value.weights, info.value.caps or {})
      self:SetTankingModel (info.value.tanking)
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

  self.exportPresetMenu = LibDD:Create_UIDropDownMenu("ReforgeLiteExportPresetMenu", self)
  self.exportPresetMenu.list = exportList
  LibDD:UIDropDownMenu_Initialize(self.exportPresetMenu, menuListInit({
    onClick = function(info)
      self:ExportPreset(info.sortKey, info.value)
    end
  }), "MENU")

  self.presetDelMenu = LibDD:Create_UIDropDownMenu("ReforgeLitePresetDelMenu", self)
  LibDD:UIDropDownMenu_Initialize(self.presetDelMenu, function (menu, level)
    if level ~= 1 then return end
    addonTable.GUI:ClearEditFocus()
    local menuList = {}
    for _, db in ipairs({self.db, self.cdb}) do
      for k in pairs(db.customPresets) do
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
