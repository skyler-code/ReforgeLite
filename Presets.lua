local _, addonTable = ...
local L = addonTable.L
local ReforgeLite = addonTable.ReforgeLite

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

ReforgeLite.capPresets = {
  {
    value = 1,
    name = TRACKER_SORT_MANUAL,
    getter = nil
  },
  {
    value = 2,
    name = L["Melee hit cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (ReforgeLite.STATS.HIT) * (ReforgeLite:GetNeededMeleeHit () - ReforgeLite:GetMeleeHitBonus ())
    end
  },
  {
    value = 3,
    name = L["Spell hit cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (ReforgeLite.STATS.SPELLHIT) * (ReforgeLite:GetNeededSpellHit () - ReforgeLite:GetSpellHitBonus ())
    end
  },
  {
    value = 4,
    name = L["Melee DW hit cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (ReforgeLite.STATS.HIT) * (ReforgeLite:GetNeededMeleeHit () + 19 - ReforgeLite:GetMeleeHitBonus ())
    end
  },
  {
    value = 5,
    name = L["Expertise soft cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (ReforgeLite.STATS.EXP) * (ReforgeLite:GetNeededExpertiseSoft () - ReforgeLite:GetExpertiseBonus ())
    end
  },
  {
    value = 6,
    name = L["Expertise hard cap"],
    getter = function ()
      return ReforgeLite:RatingPerPoint (ReforgeLite.STATS.EXP) * (ReforgeLite:GetNeededExpertiseHard () - ReforgeLite:GetExpertiseBonus ())
    end
  },
}

----------------------------------------- WEIGHT PRESETS ------------------------------

local StatSpirit = 1
local StatDodge = 2
local StatParry = 3
local StatHit = 4
local StatCrit = 5
local StatHaste = 6
local StatExp = 7
local StatMastery = 8
local MeleeHitCap = 2
local SpellHitCap = 3
local MeleeDWHitCap = 4
local ExpSoftCap = 5
local ExpHardCap = 6
local AtLeast = addonTable.StatCaps.AtLeast
local AtMost = addonTable.StatCaps.AtMost

local HitCap = {
  stat = StatHit,
  points = {
    {
      method = AtLeast,
      preset = MeleeHitCap
    }
  }
}

local HitCapSpell = {
  stat = StatHit,
  points = {
    {
      method = AtLeast,
      preset = SpellHitCap,
    }
  }
}

local SoftExpCap = {
  stat = StatExp,
  points = {
    {
      method = AtLeast,
      preset = ExpSoftCap
    }
  }
}

local MeleeCaps = {
  HitCap,
  SoftExpCap
}

local RangedCaps = { HitCap }

local CasterCaps = { HitCapSpell }

do
  local specNames = {
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

  for k,v in pairs(specNames) do
    local _, tabName, _, icon = GetSpecializationInfoForSpecID(v)
    specNames[k] = "|T"..(icon or "error")..":0|t " .. tabName
  end

  local function GetSpellString(spellID)
    local spellName, _, icon = GetSpellInfo(spellID)
    return "|T"..(icon or "error")..":0|t " .. spellName
  end
  ReforgeLite.presetOrder = {
    [L["DEATHKNIGHT"]] = 1,
    [L["DRUID"]] = 2,
    [L["HUNTER"]] = 3,
    [L["MAGE"]] = 4,
    [L["PALADIN"]] = 5,
    [L["PRIEST"]] = 6,
    [L["ROGUE"]] = 7,
    [L["SHAMAN"]] = 8,
    [L["WARLOCK"]] = 9,
    [L["WARRIOR"]] = 10,
  }
  ReforgeLite.presets = {
    ["DEATHKNIGHT"] = {
      [specNames.DEATHKNIGHTBlood] = {
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
                  preset = MeleeHitCap,
                }
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  method = AtMost,
                  preset = ExpSoftCap,
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
      [specNames.DEATHKNIGHTFrost] = {
        [ENCHSLOT_2HWEAPON] = {
          weights = {
            0, 0, 0, 201, 115, 129, 163, 126
          },
          caps = MeleeCaps,
        },
        [GetSpellInfo(674) .. " (Oblit)"] = {
          weights = {
            0, 0, 0, 229, 116, 147, 164, 144
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = MeleeHitCap,
                  after = 106,
                },
                {
                  preset = MeleeDWHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  method = AtLeast,
                  preset = ExpSoftCap,
                },
              },
            },
          },
        },
        [GetSpellInfo(674) .. " (Masterfrost)"] = {
          weights = {
            0, 0, 0, 200, 120, 150, 100, 180
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = SpellHitCap,
                  after = 106,
                },
                {
                  method = AtMost,
                  preset = MeleeHitCap,
                },
              },
            },
          },
        },
      },
      [specNames.DEATHKNIGHTUnholy] = {
        [PLAYER_DIFFICULTY1] = {
          weights = {
            0, 0, 0, 200, 130, 160, 100, 110
          },
          caps = { HitCap },
        },
        ["|T"..(C_Item.GetItemIconByID(78478) or "error")..":0|t " .. (C_Item.GetItemNameByID(78478) or "Gurthalak, Voice of the Deeps")] = {
          weights = {
            0, 0, 0, 200, 120, 160, 100, 130
          },
          caps = { HitCap },
        },
      },
    },
    ["DRUID"] = {
      [specNames.DRUIDBalance] = {
        weights = {
          0, 0, 0, 200, 100, 150, 0, 130
        },
        caps = CasterCaps,
      },
      [specNames.DRUIDFeralCombat] = {
        ["Bear"] = {
          weights = {
            0, 150, 0, 40, 60, 10, 60, 90
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  preset = MeleeHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  preset = ExpSoftCap,
                  after = 30,
                },
                {
                  preset = ExpHardCap,
                },
              },
            },
          },
        },
        ["Cat"] = {
          weights = {
            0, 0, 0, 115, 110, 110, 115, 110
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  preset = MeleeHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  preset = ExpSoftCap,
                },
              },
            },
          },
        },
      },
      [specNames.DRUIDRestoration] = {
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
      [specNames.HUNTERBeastMastery] = {
        weights = {
          0, 0, 0, 200, 150, 100, 0, 100
        },
        caps = RangedCaps,
      },
      [specNames.HUNTERMarksmanship] = {
        [GetSpellString(3044)] = { -- Arcane Shot
          weights = {
            0, 0, 0, 200, 150, 140, 0, 110
          },
          caps = RangedCaps,
        },
        [GetSpellString(82928)] = { -- Aimed Shot
          weights = {
            0, 0, 0, 200, 140, 150, 0, 110
          },
          caps = RangedCaps,
        },
      },
      [specNames.HUNTERSurvival] = {
        weights = {
          0, 0, 0, 200, 140, 130, 0, 120
        },
        caps = RangedCaps,
      },
    },
    ["MAGE"] = {
      [specNames.MAGEArcane] = {
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
      [specNames.MAGEFire] = {
        ["15% " .. STAT_HASTE] = {
          weights = {
            -1, -1, -1, 2, 3, 1, -1, -1
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
        ["25% " .. STAT_HASTE] = {
          weights = {
            -1, -1, -1, 2, 3, 1, -1, -1
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
      [specNames.MAGEFrost] = {
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
      [specNames.PALADINHoly] = {
        weights = {
          160, 0, 0, 0, 80, 200, 0, 120
        },
      },
      [specNames.PALADINProtection] = {
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
                  preset = ExpSoftCap,
                  after = 3,
                },
                {
                  method = AtMost,
                  preset = ExpHardCap,
                },
              },
            },
            {
              stat = StatHit,
              points = {
                {
                  method = AtMost,
                  preset = MeleeHitCap,
                }
              },
            },
          },
        },
      },
      [specNames.PALADINRetribution] = {
        weights = {
          0, 0, 0, 200, 135, 110, 180, 150
        },
        caps = MeleeCaps,
      },
    },
    ["PRIEST"] = {
      [specNames.PRIESTDiscipline] = {
        weights = {
          150, 0, 0, 0, 80, 100, 0, 120
        },
      },
      [specNames.PRIESTHoly] = {
        weights = {
          150, 0, 0, 0, 80, 120, 0, 100
        },
      },
      [specNames.PRIESTShadow] = {
        weights = {
          0, 0, 0, 200, 100, 140, 0, 130
        },
        caps = CasterCaps
      },
    },
    ["ROGUE"] = {
      ["Tier 12"] = {
        [specNames.ROGUEAssassination] = {
          weights = {
            0, 0, 0, 200, 120, 130, 120, 140
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = MeleeHitCap,
                  after = 160,
                },
                {
                  preset = SpellHitCap,
                  after = 82,
                },
                {
                  preset = MeleeDWHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  preset = ExpSoftCap,
                },
              },
            },
          },
        },
        [specNames.ROGUECombat] = {
          weights = {
            0, 0, 0, 215, 125, 170, 185, 150
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = MeleeHitCap,
                  after = 150,
                },
                {
                  preset = SpellHitCap,
                  after = 120,
                },
                {
                  preset = MeleeDWHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  method = AtLeast,
                  preset = ExpSoftCap,
                },
              },
            },
          },
        },
        [specNames.ROGUESubtlety] = {
          weights = {
            0, 0, 0, 155, 145, 155, 130, 90
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = MeleeHitCap,
                  after = 110,
                },
                {
                  preset = SpellHitCap,
                  after = 80,
                },
                {
                  preset = MeleeDWHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  preset = ExpSoftCap,
                },
              },
            },
          },
        },
      },
      ["Tier 13"] = {
        [specNames.ROGUEAssassination] = {
          weights = {
            0, 0, 0, 225, 120, 140, 140, 160
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = MeleeHitCap,
                  after = 170,
                },
                {
                  preset = SpellHitCap,
                  after = 90,
                },
                {
                  preset = MeleeDWHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  preset = ExpSoftCap,
                },
              },
            },
          },
        },
        [specNames.ROGUECombat] = {
          weights = {
            0, 0, 0, 240, 120, 190, 210, 150
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = MeleeHitCap,
                  after = 170,
                },
                {
                  preset = SpellHitCap,
                  after = 135,
                },
                {
                  preset = MeleeDWHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  method = AtLeast,
                  preset = ExpSoftCap,
                },
              },
            },
          },
        },
        [specNames.ROGUESubtlety] = {
          weights = {
            0, 0, 0, 180, 150, 175, 155, 95
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = MeleeHitCap,
                  after = 115,
                },
                {
                  preset = SpellHitCap,
                  after = 90,
                },
                {
                  preset = MeleeDWHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  preset = ExpSoftCap,
                },
              },
            },
          },
        },
      },
    },
    ["SHAMAN"] = {
      [specNames.SHAMANElemental] = {
        weights = {
          0, 0, 0, 200, 80, 140, 0, 120
        },
        caps = CasterCaps,
      },
      [specNames.SHAMANEnhancement] = {
        weights = {
          0, 0, 0, 250, 120, 80, 190, 150
        },
        caps = {
          {
            stat = StatHit,
            points = {
              {
                method = AtLeast,
                preset = SpellHitCap,
                after = 50,
              },
              {
                preset = MeleeDWHitCap,
              },
            },
          },
          {
            stat = StatExp,
            points = {
              {
                method = AtLeast,
                preset = ExpSoftCap,
              },
            },
          },
        },
      },
      [specNames.SHAMANRestoration] = {
        weights = {
          130, 0, 0, 0, 100, 100, 0, 100
        },
      },
    },
    ["WARLOCK"] = {
      [specNames.WARLOCKAffliction .. '/' .. specNames.WARLOCKDestruction] = {
        weights = {
          0, 0, 0, 200, 140, 160, 0, 120
        },
        caps = CasterCaps,
      },
      [specNames.WARLOCKDemonology] = {
        weights = {
          0, 0, 0, 200, 120, 160, 0, 140
        },
        caps = CasterCaps,
      },
    },
    ["WARRIOR"] = {
      [specNames.WARRIORArms] = {
        weights = {
          0, 0, 0, 200, 150, 100, 200, 120
        },
        caps = MeleeCaps
      },
      [specNames.WARRIORFury] = {
        [GetSpellString(46917)] = { -- Titan's Grip
          weights = {
            0, 0, 0, 200, 150, 100, 180, 130
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = MeleeHitCap,
                  after = 140,
                },
                {
                  value = 1300,
                  preset = 1,
                  after = 125
                },
                {
                  preset = MeleeDWHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  method = AtLeast,
                  preset = ExpSoftCap,
                },
              },
            },
          },
        },
        [GetSpellString(81099)] = { -- Single-Minded Fury
          weights = {
            0, 0, 0, 200, 150, 100, 180, 130
          },
          caps = {
            {
              stat = StatHit,
              points = {
                {
                  method = AtLeast,
                  preset = MeleeHitCap,
                  after = 140,
                },
                {
                  value = 1300,
                  preset = 1,
                  after = 125
                },
                {
                  preset = MeleeDWHitCap,
                },
              },
            },
            {
              stat = StatExp,
              points = {
                {
                  method = AtLeast,
                  preset = ExpSoftCap,
                },
              },
            },
          },
        },
      },
      [specNames.WARRIORProtection] = {
        tanking = true,
        weights = {
          40, 100, 100, 0, 0, 0, 0, 40
        },
      },
    },
  }
end

function ReforgeLite:InitPresets()
  self.presets[CUSTOM] = self.db.customPresets

  if PawnVersion then
    self.presets["Pawn scales"] = function ()
      if PawnCommon == nil or PawnCommon.Scales == nil then return {} end
      local result = {}
      for k, v in pairs (PawnCommon.Scales) do
        local preset = {leaf = "import"}
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
          result[v.LocalizedName or k] = preset
        end
      end
      return result
    end
  end

  self.presetMenu = CreateFrame ("Frame", "ReforgeLitePresetMenu")
  self.presetMenu.info = {}
  self.presetMenu.initialize = function (menu, level)
    if not level then return end
    local list = self.presets
    if level > 1 then
      list = UIDROPDOWNMENU_MENU_VALUE
    end
    local sortedList = {}
    for k, v in pairs (list) do
      if type (v) == "function" then
        v = v ()
      end
      local info = UIDropDownMenu_CreateInfo()
      info.notCheckable = true
      info.text = ((list == self.db.customPresets or v.leaf == "import") and k or L[k])
      info.value = v
      if v.tip then
        info.tooltipTitle = v.tip
        info.tooltipOnButton = true
      end
      if v.caps or v.weights or v.leaf then
        info.func = function ()
          CloseDropDownMenus ()
          if v.leaf == "import" then
            self:SetStatWeights (v.weights, v.caps)
          else
            self:SetStatWeights (v.weights, v.caps or {})
          end
          self:SetTankingModel (v.tanking)
        end
        info.hasArrow = nil
        info.keepShownOnClick = nil
      else
        info.func = nil
        if next (v) then
          info.hasArrow = true
        else
          info.hasArrow = nil
        end
        info.keepShownOnClick = true
      end
      if level > 1 or not self.presetOrder[info.text] then
        UIDropDownMenu_AddButton (info, level)
      else
        sortedList[self.presetOrder[info.text]] = info
      end
    end
    for _,v in ipairs(sortedList) do
      UIDropDownMenu_AddButton (v, 1)
    end
  end

  self.presetDelMenu = CreateFrame ("Frame", "ReforgeLitePresetDelMenu")
  self.presetDelMenu.info = {}
  self.presetDelMenu.initialize = function (menu, level)
    if level ~= 1 then return end
    local info = menu.info
    wipe (info)
    info.notCheckable = true
    for k, v in pairs (self.db.customPresets) do
      info.text = k
      info.func = function ()
        self.db.customPresets[k] = nil
        if next (self.db.customPresets) == nil then
          self.deletePresetButton:Disable ()
        end
      end
      UIDropDownMenu_AddButton (info, level)
    end
  end
end
