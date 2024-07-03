local addonName, addonTable = ...
local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "title")
local CreateColor, WHITE_FONT_COLOR, ITEM_MOD_SPIRIT_SHORT = CreateColor, WHITE_FONT_COLOR, ITEM_MOD_SPIRIT_SHORT

local ReforgeLite = CreateFrame("Frame", addonName, UIParent, "BackdropTemplate")
addonTable.ReforgeLite = ReforgeLite

ReforgeLite.isDev = C_AddOns.GetAddOnMetadata(addonName, "Version") == "@project-version@"

local L = addonTable.L
local GUI = addonTable.GUI
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

local function DeepCopy (t, cache)
  if type (t) ~= "table" then
    return t
  end
  local copy = {}
  for i, v in pairs (t) do
    if type (v) ~= "table" then
      copy[i] = v
    else
      cache = cache or {}
      cache[t] = copy
      if cache[v] then
        copy[i] = cache[v]
      else
        copy[i] = DeepCopy (v, cache)
      end
    end
  end
  return copy
end
addonTable.DeepCopy = DeepCopy

local gprint = print
local function print(...)
    gprint("|cff33ff99"..addonName.."|r:",...)
end

local DefaultDB = {
  itemSize = 24,
  windowWidth = 800,
  windowHeight = 564,

  reforgeCheat = 1,

  openOnReforge = true,
  updateTooltip = true,

  activeWindowTitle = {0.6, 0, 0},
  inactiveWindowTitle = {0.5, 0.5, 0.5},

  customPresets = {
  },
  profiles = {
  },
  classProfiles = {
  },
}
local DefaultDBProfile = {
  targetLevel = 3,

  buffs = {
  },
  weights = {0, 0, 0, 0, 0, 0, 0, 0},
  caps = {
    {
      stat = 0,
      points = {
        {
          method = 1,
          value = 0,
          after = 0,
          preset = 1
        }
      }
    },
    {
      stat = 0,
      points = {
        {
          method = 1,
          value = 0,
          after = 0,
          preset = 1
        }
      }
    }
  },
  itemsLocked = {},
  categoryStates = { [SETTINGS] = true },
}
local DefaultDBClassProfile = {
  customPresets = {}
}
local function MergeTables (dst, src)
  for k, v in pairs (src) do
    if type (v) ~= "table" then
      if dst[k] == nil then
        dst[k] = v
      end
    else
      if type (dst[k]) ~= "table" then
        dst[k] = {}
      end
      MergeTables (dst[k], v)
    end
  end
end
addonTable.MergeTables = MergeTables

local function ReforgeFrameIsVisible()
  return ReforgingFrame and ReforgingFrame:IsShown()
end

ReforgeLite.dbkey = UnitName ("player") .. " - " .. GetRealmName ()
addonTable.localeClass, addonTable.playerClass, addonTable.playerClassID = UnitClass ("player")
addonTable.playerRace = select(2,UnitRace ("player"))
local playerClass, playerRace, localeClass = addonTable.playerClass, addonTable.playerRace, addonTable.localeClass
local missChance = (playerRace == "NightElf" and 7 or 5)
local UNFORGE_INDEX = -1
addonTable.StatCapMethods = {
  AtLeast = 1,
  AtMost = 2,
  NewValue = 3,
}

function ReforgeLite:UpgradeDBCaps (caps)
  for i = 1, #caps do
    if caps[i].points == nil or caps[i].value or caps[i].method or caps[i].after then
      caps[i].points = {}
      caps[i].points[1] = {
        method = caps[i].method or 1,
        value = caps[i].value or 0,
        after = caps[i].after or 0
      }
      for j = 1, #caps[i].points do
        if not caps[i].points[j].preset then
          caps[i].points[j].preset = 1
        end
      end
      caps[i].method = nil
      caps[i].value = nil
      caps[i].after = nil
    end
  end
end
function ReforgeLite:UpgradeDB ()
  if not ReforgeLiteDB then
    ReforgeLiteDB = DefaultDB
  else
    MergeTables (ReforgeLiteDB, DefaultDB)
  end
  local db = ReforgeLiteDB
  if not db.profiles[self.dbkey] then
    db.profiles[self.dbkey] = DefaultDBProfile
  else
    MergeTables (db.profiles[self.dbkey], DefaultDBProfile)
  end
  local pdb = db.profiles[self.dbkey]
  for k, v in pairs (pdb) do
    if db[k] ~= nil then
      pdb[k] = db[k]
      db[k] = nil
    end
  end
  if db.statCaps then
    pdb.caps = db.statCaps
    db.statCaps = nil
  end
  if db.statWeights then
    pdb.weights = db.statWeights
    db.statWeights = nil
  end
  self:UpgradeDBCaps (pdb.caps)
  db.convertSpirit = nil
  if pdb.storedMethod then
    pdb.storedMethod.caps = nil
    pdb.storedMethod.weights = nil
  end
  if pdb.method then
    pdb.method.caps = nil
    pdb.method.weights = nil
  end
  if not db.classProfiles[playerClass] then
    db.classProfiles[playerClass] = DefaultDBClassProfile
  else
    MergeTables (db.classProfiles[playerClass], DefaultDBClassProfile)
  end
end

-----------------------------------------------------------------

local function CreateStaticPopup(name, text, options)
  StaticPopupDialogs[name] = {
    text = text,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    editBoxWidth = 350,
    OnAccept = function (self)
      options.func(self.editBox:GetText ())
    end,
    EditBoxOnEnterPressed = function (self)
      local importStr = self:GetParent ().editBox:GetText ()
      if importStr ~= "" then
        options.func(importStr)
        self:GetParent ():Hide ()
      end
    end,
    EditBoxOnTextChanged = function (self, data)
      if data ~= "" then
        self:GetParent ().button1:Enable ()
      else
        self:GetParent ().button1:Disable ()
      end
    end,
    EditBoxOnEscapePressed = function(self)
      self:GetParent():Hide();
    end,
    OnShow = function (self)
      LibDD:CloseDropDownMenus()
      self.editBox:SetText ("")
      self.button1:Disable ()
      self.editBox:SetFocus ()
    end,
    OnHide = function (self)
      ChatEdit_FocusActiveWindow ()
      self.editBox:SetText ("")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true
  }
end

CreateStaticPopup("REFORGE_LITE_PARSE_PAWN", L["Enter pawn string"], { func = function(text) ReforgeLite:ParseImportString(text) end })
CreateStaticPopup("REFORGE_LITE_PARSE_WOWSIMS", L["Enter WoWSims JSON"], { func = function(text) ReforgeLite:ParseWoWSimsString(text) end } )
CreateStaticPopup("REFORGE_LITE_SAVE_PRESET", L["Enter the preset name"], { func = function(text)
  ReforgeLite.cdb.customPresets[text] = {
    caps = DeepCopy(ReforgeLite.pdb.caps),
    weights = DeepCopy(ReforgeLite.pdb.weights)
  }
  ReforgeLite:InitCustomPresets()
  ReforgeLite.deletePresetButton:Enable()
end })


ReforgeLite.itemSlots = {
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
  "RANGEDSLOT"
}
local ignoredSlots = { [INVSLOT_TABARD] = true, [INVSLOT_BODY] = true }

ReforgeLite.STATS = {
  SPIRIT = 1, DODGE = 2, PARRY = 3, HIT = 4, CRIT = 5, HASTE = 6, EXP = 7, MASTERY = 8, SPELLHIT = 9, CRITBLOCK = 1
}

local FIRE_SPIRIT = 4
local function HasFireBuff()
  return C_UnitAuras.GetPlayerAuraBySpellID(7353) ~= nil
end

function ReforgeLite:CreateItemStats()
  local function RatingStat (i, name_, tip_, id_, short)
    return {
      name = name_,
      tip = tip_,
      long = tip_,
      getter = function ()
        local rating = GetCombatRating (id_)
        if id_ == CR_HIT_SPELL and self.s2hFactor > 0 and HasFireBuff() then
          rating = rating - floor(FIRE_SPIRIT*(self.s2hFactor/100))
        end
        return rating
      end,
      mgetter = function (method, orig)
        return (orig and method.orig_stats and method.orig_stats[i]) or method.stats[i]
      end,
      parser = short and L["StatFormat"]:gsub("%%s", _G[name_]) or (ITEM_SPELL_TRIGGER_ONEQUIP .. " " .. _G[name_]:gsub("%%s", "(.+)"))
    }
  end
  local CR_HIT, CR_CRIT, CR_HASTE = CR_HIT_SPELL, CR_CRIT_SPELL, CR_HASTE_SPELL
  if playerClass == "HUNTER" then
    CR_HIT, CR_CRIT, CR_HASTE = CR_HIT_RANGED, CR_CRIT_RANGED, CR_HASTE_RANGED
  end
  self.itemStats = {
    {
      name = "ITEM_MOD_SPIRIT_SHORT",
      tip = ITEM_MOD_SPIRIT_SHORT,
      long = ITEM_MOD_SPIRIT_SHORT,
      getter = function ()
        local _, spirit = UnitStat("player", LE_UNIT_STAT_SPIRIT)
        if HasFireBuff() then
          spirit = spirit - FIRE_SPIRIT
        end
        return spirit
      end,
      mgetter = function (method, orig)
        return (orig and method.orig_stats and method.orig_stats[1]) or method.stats[1]
      end,
      parser = function(line)
        if CreateColor(line:GetTextColor()):IsEqualTo(WHITE_FONT_COLOR) then
          return strmatch(line:GetText(), L["StatFormat"]:gsub("%%s", ITEM_MOD_SPIRIT_SHORT))
        end
      end
    },
    RatingStat (self.STATS.DODGE,   "ITEM_MOD_DODGE_RATING",         STAT_DODGE,     CR_DODGE),
    RatingStat (self.STATS.PARRY,   "ITEM_MOD_PARRY_RATING",         STAT_PARRY,     CR_PARRY),
    RatingStat (self.STATS.HIT,     "ITEM_MOD_HIT_RATING",           HIT,            CR_HIT),
    RatingStat (self.STATS.CRIT,    "ITEM_MOD_CRIT_RATING",          CRIT_ABBR,      CR_CRIT),
    RatingStat (self.STATS.HASTE,   "ITEM_MOD_HASTE_RATING",         STAT_HASTE,     CR_HASTE),
    RatingStat (self.STATS.EXP,     "ITEM_MOD_EXPERTISE_RATING",     STAT_EXPERTISE, CR_EXPERTISE),
    RatingStat (self.STATS.MASTERY, "ITEM_MOD_MASTERY_RATING_SHORT", STAT_MASTERY,   CR_MASTERY, true)
  }
end
ReforgeLite:CreateItemStats()

local itemStatsLocale = {
  [6]  = ReforgeLite.STATS.SPIRIT, -- SPIRIT
  [13] = ReforgeLite.STATS.DODGE, -- DODGE
  [14] = ReforgeLite.STATS.PARRY, -- PARRY
  [31] = ReforgeLite.STATS.HIT, -- HIT
  [32] = ReforgeLite.STATS.CRIT, -- CRIT
  [36] = ReforgeLite.STATS.HASTE, -- HASTE
  [37] = ReforgeLite.STATS.EXP, -- EXPERTISE
  [49] = ReforgeLite.STATS.MASTERY, -- MASTERY
}

ReforgeLite.tankingStats = {
  ["DEATHKNIGHT"] = DeepCopy (ReforgeLite.itemStats),
  ["WARRIOR"] = {
    [ReforgeLite.STATS.CRITBLOCK] = {
      tip = L["Crit block"],
      long = L["Crit block"],
      percent = true,
      mgetter = function (method)
        return method.stats.critBlock or 0
      end,
      getter = function ()
        return GetMastery () * 1.5
      end
    },
    [ReforgeLite.STATS.DODGE] = {
      tip = STAT_DODGE,
      long = DODGE_CHANCE,
      percent = true,
      mgetter = function (method)
        return method.stats.dodge or 0
      end,
      getter = GetDodgeChance
    },
    [ReforgeLite.STATS.PARRY] = {
      tip = PARRY,
      long = PARRY_CHANCE,
      percent = true,
      mgetter = function (method)
        return method.stats.parry or 0
      end,
      getter = GetDodgeChance
    },
    [ReforgeLite.STATS.MASTERY] = {
      tip = BLOCK,
      long = BLOCK_CHANCE,
      percent = true,
      mgetter = function (method)
        return method.stats.block or 0
      end,
      getter = function ()
        return 20 + GetMastery () * 1.5
      end
    }
  },
  ["PALADIN"] = {
    [ReforgeLite.STATS.DODGE] = {
      tip = DODGE,
      long = DODGE_CHANCE,
      percent = true,
      mgetter = function (method)
        return method.stats.dodge or 0
      end,
      getter = GetDodgeChance
    },
    [ReforgeLite.STATS.PARRY] = {
      tip = PARRY,
      long = PARRY_CHANCE,
      percent = true,
      mgetter = function (method)
        return method.stats.parry or 0
      end,
      getter = GetDodgeChance
    },
    [ReforgeLite.STATS.MASTERY] = {
      tip = BLOCK,
      long = BLOCK_CHANCE,
      percent = true,
      mgetter = function (method)
        return method.stats.block or 0
      end,
      getter = function ()
        return 5 + GetMastery () * 2.25
      end
    }
  },
}
ReforgeLite.tankingStats["DEATHKNIGHT"][ReforgeLite.STATS.DODGE].long = DODGE_CHANCE
ReforgeLite.tankingStats["DEATHKNIGHT"][ReforgeLite.STATS.DODGE].percent = true
ReforgeLite.tankingStats["DEATHKNIGHT"][ReforgeLite.STATS.DODGE].mgetter = function (method)
  return method.stats.dodge
end
ReforgeLite.tankingStats["DEATHKNIGHT"][ReforgeLite.STATS.DODGE].getter = GetDodgeChance
ReforgeLite.tankingStats["DEATHKNIGHT"][ReforgeLite.STATS.PARRY].long = PARRY_CHANCE
ReforgeLite.tankingStats["DEATHKNIGHT"][ReforgeLite.STATS.PARRY].percent = true
ReforgeLite.tankingStats["DEATHKNIGHT"][ReforgeLite.STATS.PARRY].mgetter = function (method)
  return method.stats.parry
end
ReforgeLite.tankingStats["DEATHKNIGHT"][ReforgeLite.STATS.PARRY].getter = GetParryChance

ReforgeLite.tankingStats["DRUID"] = ReforgeLite.tankingStats["DEATHKNIGHT"]

ReforgeLite.REFORGE_TABLE_BASE = 112
local reforgeTable = {}
do
  local tinsert = tinsert
  for firstStat in ipairs(ReforgeLite.itemStats) do
    for secondStat in ipairs(ReforgeLite.itemStats) do
      if firstStat ~= secondStat then
        tinsert(reforgeTable, {firstStat,secondStat})
      end
    end
  end
end

ReforgeLite.reforgeTable = reforgeTable

local REFORGE_COEFF = 0.4
ReforgeLite.spiritBonus = playerRace == "Human" and 1.03 or 1

function ReforgeLite:UpdateWindowSize ()
  self.db.windowWidth = self:GetWidth ()
  self.db.windowHeight = self:GetHeight ()
end

function ReforgeLite:GetCapScore (cap, value)
  local score = 0
  for i = #cap.points, 1, -1 do
    if value > cap.points[i].value then
      score = score + cap.points[i].after * (value - cap.points[i].value)
      value = cap.points[i].value
    end
  end
  score = score + self.pdb.weights[cap.stat] * value
  return score
end

function ReforgeLite:GetStatScore (stat, value)
  if self.pdb.tankingModel then
    return self.pdb.weights[stat] * value
  end
  if stat == self.pdb.caps[1].stat then
    return self:GetCapScore (self.pdb.caps[1], value)
  elseif stat == self.pdb.caps[2].stat then
    return self:GetCapScore (self.pdb.caps[2], value)
  else
    return self.pdb.weights[stat] * value
  end
end

function ReforgeLite:ParseWoWSimsString(importStr)
  local success, wowsims = pcall(function () return addonTable.json.decode(importStr) end)
  if success and (wowsims or {}).player then
    local newItems = DeepCopy(self.pdb.method.items)
    for slot,item in ipairs(newItems) do
      local simItemInfo = wowsims.player.equipment.items[slot] or {}
      local equippedItemInfo = self.itemData[slot]
      if simItemInfo.id ~= equippedItemInfo.itemId then
        local _, importItemLink = C_Item.GetItemInfo(simItemInfo.id)
        print(L["Item Import Mismatch"]:format(importItemLink, equippedItemInfo.item))
        return
      end
      item.reforge = nil
      if simItemInfo.reforging then
        item.reforge = simItemInfo.reforging - self.REFORGE_TABLE_BASE
        item.src, item.dst = unpack(self.reforgeTable[item.reforge])
      end
      item.stats = nil
    end
    self.pdb.method.items = newItems
    self:UpdateMethodStats(self.pdb.method)
    self:UpdateMethodCategory ()
  else -- error
    print(wowsims)
  end
end

function ReforgeLite:ParseImportString(importStr)
  local pos, _, version, name, values = strfind (importStr, "^%s*%(%s*Pawn%s*:%s*v(%d+)%s*:%s*\"([^\"]+)\"%s*:%s*(.+)%s*%)%s*$")
  version = tonumber (version)
  if version and version > 1 then return end
  if not (pos and version and name and values) or name == "" or values == "" then
    self:ParsePresetString(importStr)
    return
  end
  self:ParsePawnString(values)
end

function ReforgeLite:ParsePresetString(presetStr)
  local success, preset = pcall(function () return addonTable.json.decode(presetStr) end)
  if success then
    DevTools_Dump(preset)

  end
end

function ReforgeLite:ParsePawnString (values)

  local raw = {}
  local average = 0
  local total = 0
  gsub (values .. ",", "[^,]*,", function (pair)
    local pos, _, stat, value = strfind (pair, "^%s*([%a%d]+)%s*=%s*(%-?[%d%.]+)%s*,$")
    value = tonumber (value)
    if pos and stat and stat ~= "" and value then
      raw[stat] = value
      average = average + value
      total = total + 1
    end
  end)
  local factor = 1
  if average / total < 10 then
    factor = 100
  end
  for k, v in pairs (raw) do
    raw[k] = floor (v * factor + 0.5)
  end

  local weights = {}
  weights[self.STATS.SPIRIT] = raw["Spirit"] or 0
  weights[self.STATS.DODGE] = raw["DodgeRating"] or 0
  weights[self.STATS.PARRY] = raw["ParryRating"] or 0
  weights[self.STATS.HIT] = raw["HitRating"] or 0
  weights[self.STATS.CRIT] = raw["CritRating"] or 0
  weights[self.STATS.HASTE] = raw["HasteRating"] or 0
  weights[self.STATS.EXP] = raw["ExpertiseRating"] or 0
  weights[self.STATS.MASTERY] = raw["MasteryRating"] or 0

  self:SetStatWeights (weights)
end

local orderIds = {}
local function getOrderId(section)
  orderIds[section] = (orderIds[section] or 0) + 1
  return orderIds[section]
end

------------------------------------------------------------------------

function ReforgeLite:CreateCategory (name)
  local c = CreateFrame ("Frame", nil, self.content)
  c:ClearAllPoints ()
  c:SetSize(16,16)
  c.expanded = not self.pdb.categoryStates[name]
  c.name = c:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  c.catname = c.name
  c.name:SetPoint ("TOPLEFT", c, "TOPLEFT", 18, -1)
  c.name:SetTextColor (1, 1, 1)
  c.name:SetText (name)

  c.button = CreateFrame ("Button", nil, c)
  c.button:ClearAllPoints ()
  c.button:SetSize (14,14)
  c.button:SetPoint ("TOPLEFT", c, "TOPLEFT", 0, 0)
  c.button:SetHighlightTexture ("Interface\\Buttons\\UI-PlusButton-Hilight")
  c.button.UpdateTexture = function (self)
    if self:GetParent ().expanded then
      self:SetNormalTexture ("Interface\\Buttons\\UI-MinusButton-Up")
      self:SetPushedTexture ("Interface\\Buttons\\UI-MinusButton-Down")
    else
      self:SetNormalTexture ("Interface\\Buttons\\UI-PlusButton-Up")
      self:SetPushedTexture ("Interface\\Buttons\\UI-PlusButton-Down")
    end
  end
  c.button:UpdateTexture ()
  c.button:SetScript ("OnClick", function (btn) btn:GetParent():Toggle() end)
  c.button.anchor = {point = "TOPLEFT", rel = c, relPoint = "TOPLEFT", x = 0, y = 0}

  c.frames = {}
  c.anchors = {}
  c.AddFrame = function (cat, frame)
    tinsert (cat.frames, frame)
    frame.Show2 = function (f)
      if f.category.expanded then
        f:Show ()
      end
      f.chidden = nil
    end
    frame.Hide2 = function (f)
      f:Hide ()
      f.chidden = true
    end
    frame.category = cat
    if not cat.expanded then
      frame:Hide()
    end
  end

  c.Toggle = function (category)
    category.expanded = not category.expanded
    self.pdb.categoryStates[name] = not category.expanded or nil
    if c.expanded then
      for k, v in pairs (category.frames) do
        if not v.chidden then
          v:Show ()
        end
      end
      for k, v in pairs (category.anchors) do
        v.frame:SetPoint (v.point, v.rel, v.relPoint, v.x, v.y)
      end
    else
      for k, v in pairs (category.frames) do
        v:Hide ()
      end
      for k, v in pairs (category.anchors) do
        v.frame:SetPoint (v.point, category.button, v.relPoint, v.x, v.y)
      end
    end
    category.button:UpdateTexture ()
    self:UpdateContentSize ()
  end

  return c
end

function ReforgeLite:SetAnchor (frame_, point_, rel_, relPoint_, offsX, offsY)
  if rel_ and rel_.catname and rel_.button then
    rel_ = rel_.button
  end
  if rel_.category then
    tinsert (rel_.category.anchors, {frame = frame_, point = point_, rel = rel_, relPoint = relPoint_, x = offsX, y = offsY})
    if rel_.category.expanded then
      frame_:SetPoint (point_, rel_, relPoint_, offsX, offsY)
    else
      frame_:SetPoint (point_, rel_.category.button, relPoint_, offsX, offsY)
    end
  else
    frame_:SetPoint (point_, rel_, relPoint_, offsX, offsY)
  end
  frame_.anchor = {point = point_, rel = rel_, relPoint = relPoint_, x = offsX, y = offsY}
end
function ReforgeLite:GetFrameY (frame)
  local cur = frame
  local offs = 0
  while cur and cur ~= self.content do
    if cur.anchor == nil then
      return offs
    end
    if cur.anchor.point:find ("BOTTOM") then
      offs = offs + cur:GetHeight ()
    end
    local rel = cur.anchor.rel
    if rel.category and not rel.category.expanded then
      rel = rel.category.button
    end
    if cur.anchor.relPoint:find ("BOTTOM") then
      offs = offs - rel:GetHeight ()
    end
    offs = offs + cur.anchor.y
    cur = rel
  end
  return offs
end

local function SetTextDelta (text, value, cur, override)
  override = override or (value - cur)
  if override == 0 then
    text:SetTextColor (0.7, 0.7, 0.7)
  elseif override > 0 then
    text:SetTextColor (0.6, 1, 0.6)
  else
    text:SetTextColor (1, 0.4, 0.4)
  end
  text:SetText (format (value - cur >= 0 and "+%s" or "%s", value - cur))
end

------------------------------------------------------------------------

function ReforgeLite:SetScroll (value)
  local viewheight = self.scrollFrame:GetHeight ()
  local height = self.content:GetHeight ()
  local offset

  if viewheight > height then
    offset = 0
  else
    offset = floor ((height - viewheight) / 1000 * value)
  end
  self.content:ClearAllPoints ()
  self.content:SetPoint ("TOPLEFT", 0, offset)
  self.content:SetPoint ("TOPRIGHT", 0, offset)
  self.scrollOffset = offset
  self.scrollValue = value
end
function ReforgeLite:FixScroll ()
  local offset = self.scrollOffset
  local viewheight = self.scrollFrame:GetHeight ()
  local height = self.content:GetHeight ()
  if height < viewheight + 2 then
    if self.scrollBarShown then
      self.scrollBarShown = false
      self.scrollBar:Hide ()
      self.scrollBar:SetValue (0)
    end
  else
    if not self.scrollBarShown then
      self.scrollBarShown = true
      self.scrollBar:Show ()
    end
    local value = (offset / (height - viewheight) * 1000)
    if value > 1000 then value = 1000 end
    self.scrollBar:SetValue (value)
    self:SetScroll (value)
    if value < 1000 then
      self.content:ClearAllPoints ()
      self.content:SetPoint ("TOPLEFT", 0, offset)
      self.content:SetPoint ("TOPRIGHT", 0, offset)
    end
  end
end

function ReforgeLite:CreateFrame()
  self:InitPresets()
  self:SetFrameStrata ("DIALOG")
  self:ClearAllPoints ()
  self:SetSize(self.db.windowWidth, self.db.windowHeight)
  self:SetResizeBounds(780, 500, 1000, 800)
  if self.db.windowX and self.db.windowY then
    self:SetPoint ("TOPLEFT", UIParent, "BOTTOMLEFT", self.db.windowX, self.db.windowY)
  else
    self:SetPoint ("CENTER")
  end
  self.backdropInfo = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 22, bottom = 3 }
  }
  self:ApplyBackdrop()
  self:SetBackdropBorderColor (0.1,0.1,0.1)
  self:SetBackdropColor (0.1, 0.1, 0.1)

  self.titlebar = self:CreateTexture(nil,"BACKGROUND")
  self.titlebar:SetPoint("TOPLEFT", 3, -3)
  self.titlebar:SetPoint("TOPRIGHT", -3, 3)
  self.titlebar:SetHeight(20)
  self.SetFrameActive = function(frame, active)
    if active then
      frame.titlebar:SetColorTexture(unpack (self.db.activeWindowTitle))
    else
      frame.titlebar:SetColorTexture(unpack (self.db.inactiveWindowTitle))
    end
  end
  self:SetFrameActive(true)

  self:EnableMouse (true)
  self:SetMovable (true)
  self:SetResizable (true)
  self:SetScript ("OnMouseDown", function (self, arg)
    if self.methodWindow and self:GetFrameLevel () < self.methodWindow:GetFrameLevel () then
      self:SetFrameLevel (self.methodWindow:GetFrameLevel () + 10)
      self:SetFrameActive(true)
      self.methodWindow:SetFrameActive(false)
    end
    if arg == "LeftButton" then
      self:StartMoving ()
      self.moving = true
    end
  end)
  self:SetScript ("OnMouseUp", function (self)
    if self.moving then
      self:StopMovingOrSizing ()
      self.moving = false
      self.db.windowX = self:GetLeft ()
      self.db.windowY = self:GetTop ()
    end
  end)
  tinsert(UISpecialFrames, self:GetName()) -- allow closing with escape

  self.title = self:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.title:SetPoint ("TOPLEFT", 12, -9)
  self.title:SetTextColor (1, 1, 1)
  self.title:SetText (addonTitle)

  self.close = CreateFrame ("Button", nil, self, "UIPanelCloseButtonNoScripts")
  self.close:SetSize(28, 28)
  self.close:SetPoint("TOPRIGHT")
  self.close:SetScript("OnClick", function(btn) btn:GetParent():Hide() end)

  local function GripOnMouseDown(btn, arg)
    if arg == "LeftButton" then
      local anchorPoint = btn:GetPoint()
      btn:GetParent():StartSizing(anchorPoint)
      btn:GetParent().sizing = true
    end
  end

  local function GripOnMouseUp(btn, arg)
    if btn:GetParent().sizing then
      btn:GetParent():StopMovingOrSizing ()
      btn:GetParent().sizing = false
      btn:GetParent():UpdateWindowSize ()
    end
  end

  self.leftGrip = CreateFrame ("Button", nil, self, "PanelResizeButtonTemplate")
  self.leftGrip:SetSize(16, 16)
  self.leftGrip:SetRotationDegrees(-90)
  self.leftGrip:SetPoint("BOTTOMLEFT")
  self.leftGrip:SetScript("OnMouseDown", GripOnMouseDown)
  self.leftGrip:SetScript("OnMouseUp", GripOnMouseUp)

  self.rightGrip = CreateFrame ("Button", nil, self, "PanelResizeButtonTemplate")
  self.rightGrip:SetSize(16, 16)
  self.rightGrip:SetPoint("BOTTOMRIGHT")
  self.rightGrip:SetScript("OnMouseDown", GripOnMouseDown)
  self.rightGrip:SetScript("OnMouseUp", GripOnMouseUp)

  self:CreateItemTable ()

  self.scrollValue = 0
  self.scrollOffset = 0
  self.scrollBarShown = false

  self.scrollFrame = CreateFrame ("ScrollFrame", nil, self)
  self.scrollFrame:ClearAllPoints ()
  self.scrollFrame:SetPoint ("LEFT", self.itemTable, "RIGHT", 10, 0)
  self.scrollFrame:SetPoint ("TOP", 0, -28)
  self.scrollFrame:SetPoint ("BOTTOMRIGHT", -22, 15)
  self.scrollFrame:EnableMouseWheel (true)
  self.scrollFrame:SetScript ("OnMouseWheel", function (frame, value)
    if self.scrollBarShown then
      local diff = self.content:GetHeight() - frame:GetHeight ()
      local delta = (value > 0 and -1 or 1)
      self.scrollBar:SetValue (min (max (self.scrollValue + delta * (1000 / (diff / 45)), 0), 1000))
    end

  end)
  self.scrollFrame:SetScript ("OnSizeChanged", function (frame)
    RunNextFrame(function() self:FixScroll() end)
  end)

  self.scrollBar = CreateFrame ("Slider", "ReforgeLiteScrollBar", self.scrollFrame, "UIPanelScrollBarTemplate")
  self.scrollBar:SetPoint ("TOPLEFT", self.scrollFrame, "TOPRIGHT", 0, -14)
  self.scrollBar:SetPoint ("BOTTOMLEFT", self.scrollFrame, "BOTTOMRIGHT", 4, 16)
  self.scrollBar:SetMinMaxValues (0, 1000)
  self.scrollBar:SetValueStep (1)
  self.scrollBar:SetValue (0)
  self.scrollBar:SetWidth (16)
  self.scrollBar:SetScript ("OnValueChanged", function (bar, value)
    self:SetScroll (value)
  end)
  self.scrollBar:Hide ()

  self.scrollBg = self.scrollBar:CreateTexture (nil, "BACKGROUND")
  self.scrollBg:SetAllPoints (self.scrollBar)
  self.scrollBg:SetColorTexture (0, 0, 0, 0.4)

  self.content = CreateFrame ("Frame", nil, self.scrollFrame)
  self.scrollFrame:SetScrollChild (self.content)
  self.content:ClearAllPoints ()
  self.content:SetPoint ("TOPLEFT")
  self.content:SetPoint ("TOPRIGHT")
  self.content:SetHeight (1000)

  GUI.defaultParent = self.content

  self:CreateOptionList ()

  RunNextFrame(function() self:FixScroll() end)
end

function ReforgeLite:CreateItemTable ()
  self.itemLevel = self:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.itemLevel:SetPoint ("TOPLEFT", 12, -28)
  self.itemLevel:SetTextColor (1, 1, 0.8)
  self.itemLevel:SetText (STAT_AVERAGE_ITEM_LEVEL .. ": 0")

  self.itemTable = GUI:CreateTable (#self.itemSlots + 1, #self.itemStats, self.db.itemSize, self.db.itemSize + 4, {0.5, 0.5, 0.5, 1}, self)
  self.itemTable:SetPoint ("TOPLEFT", self.itemLevel, "BOTTOMLEFT", 0, -10)
  self.itemTable:SetPoint ("BOTTOM", 0, 10)
  self.itemTable:SetWidth (400)

  local lockTip = self:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  lockTip:SetTextColor (1, 1, 1)
  lockTip:SetText (L["Click an item to lock it"])
  lockTip:SetPoint ("BOTTOMRIGHT", self.itemTable, "TOPRIGHT", 0, 10)

  for i, v in ipairs (self.itemStats) do
    self.itemTable:SetCellText (0, i, v.tip)
  end
  self.itemData = {}
  for i, v in ipairs (self.itemSlots) do
    self.itemData[i] = CreateFrame ("Frame", nil, self.itemTable)
    self.itemData[i].slot = v
    self.itemData[i].originalStats = {}
    self.itemData[i]:ClearAllPoints ()
    self.itemData[i]:SetSize(self.db.itemSize, self.db.itemSize)
    self.itemTable:SetCell (i, 0, self.itemData[i])
    self.itemData[i]:EnableMouse (true)
    self.itemData[i]:SetScript ("OnEnter", function (self)
      GameTooltip:SetOwner (self, "ANCHOR_LEFT")
      local hasItem, hasCooldown, repairCost = GameTooltip:SetInventoryItem ("player", self.slotId)
      if not hasItem then
        local text = _G[strupper (self.slot)]
        if self.checkRelic then
          text = _G["RELICSLOT"]
        end
        GameTooltip:SetText (text)
      end
      GameTooltip:Show ()
    end)
    self.itemData[i]:SetScript ("OnLeave", function (self)
      GameTooltip:Hide ()
    end)
    self.itemData[i]:SetScript ("OnMouseDown", function ()
      self.pdb.itemsLocked[i] = not self.pdb.itemsLocked[i] or nil
      if self.pdb.itemsLocked[i] then
        self.itemData[i].locked:Show ()
      else
        self.itemData[i].locked:Hide ()
      end
    end)
    self.itemData[i].slotId, self.itemData[i].slotTexture, self.itemData[i].checkRelic = GetInventorySlotInfo (v)
    self.itemData[i].checkRelic = self.itemData[i].checkRelic and UnitHasRelicSlot ("player")
    if self.itemData[i].checkRelic then
      self.itemData[i].slotTexture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Relic.blp"
    end
    self.itemData[i].texture = self.itemData[i]:CreateTexture (nil, "ARTWORK")
    self.itemData[i].texture:SetAllPoints (self.itemData[i])
    self.itemData[i].texture:SetTexture (self.itemData[i].slotTexture)
    self.itemData[i].locked = self.itemData[i]:CreateTexture (nil, "OVERLAY")
    self.itemData[i].locked:SetAllPoints (self.itemData[i])
    self.itemData[i].locked:SetTexture ("Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent")
    if not self.pdb.itemsLocked[i] then
      self.itemData[i].locked:Hide ()
    end

    self.itemData[i].stats = {}
    for j, s in ipairs (self.itemStats) do
      self.itemData[i].stats[j] = self.itemTable:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
      self.itemTable:SetCell (i, j, self.itemData[i].stats[j])
      self.itemData[i].stats[j]:SetTextColor (0.8, 0.8, 0.8)
      self.itemData[i].stats[j]:SetText ("-")
    end
  end
  self.statTotals = {}
  self.itemTable:SetCellText (#self.itemSlots + 1, 0, L["Sum"], "CENTER", {1, 0.8, 0})
  for i, v in ipairs (self.itemStats) do
    self.statTotals[i] = self.itemTable:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
    self.itemTable:SetCell (#self.itemSlots + 1, i, self.statTotals[i])
    self.statTotals[i]:SetTextColor (1, 0.8, 0)
    self.statTotals[i]:SetText ("0")
  end
end

function ReforgeLite:AddCapPoint (i, loading)
  local row = (loading or #self.pdb.caps[i].points + 1) + (i == 1 and 1 or #self.pdb.caps[1].points + 2)
  local point = (loading or #self.pdb.caps[i].points + 1)
  self.statCaps:AddRow (row)

  if not loading then
    tinsert (self.pdb.caps[i].points, 1, {value = 0, method = 1, after = 0, preset = 1})
  end

  local rem = GUI:CreateImageButton (self.statCaps, 20, 20, "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent",
    "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent", nil, function ()
    self:RemoveCapPoint (i, point)
  end)
  local methodList = {
    {value = addonTable.StatCapMethods.AtLeast, name = L["At least"]},
    {value = addonTable.StatCapMethods.AtMost, name = L["At most"]},
    {value = addonTable.StatCapMethods.NewValue, name = ""}
  }
  local method = GUI:CreateDropdown (self.statCaps, methodList, 1,
    function (val) self.pdb.caps[i].points[point].method = val end, 80)
  local preset = GUI:CreateDropdown (self.statCaps, self.capPresets, 1, function (val)
    self.pdb.caps[i].points[point].preset = val
    self:UpdateCapPreset (i, point)
    self:ReorderCapPoint (i, point)
    self:RefreshMethodStats ()
  end, 80)
  local value = GUI:CreateEditBox (self.statCaps, 40, 30, 0, function (val)
    self.pdb.caps[i].points[point].value = val
    self:ReorderCapPoint (i, point)
    self:RefreshMethodStats ()
  end)
  local after = GUI:CreateEditBox (self.statCaps, 40, 30, 0, function (val)
    self.pdb.caps[i].points[point].after = val
    self:RefreshMethodStats ()
  end)

  GUI:SetTooltip (rem, L["Remove cap"])
  GUI:SetTooltip (value, L["Cap value"])
  GUI:SetTooltip (after, L["Weight after cap"])

  self.statCaps:SetCell (row, 0, rem)
  self.statCaps:SetCell (row, 1, method, "CENTER", 0, -10)
  self.statCaps:SetCell (row, 2, preset, "CENTER", 0, -10)
  self.statCaps:SetCell (row, 3, value)
  self.statCaps:SetCell (row, 4, after)

  if not loading then
    self:UpdateCapPoints (i)
    self:UpdateContentSize ()
  end
end
function ReforgeLite:RemoveCapPoint (i, point, loading)
  local row = #self.pdb.caps[1].points + (i == 1 and 1 or #self.pdb.caps[2].points + 2)
  tremove (self.pdb.caps[i].points, point)
  self.statCaps:DeleteRow (row)
  if not loading then
    self:UpdateCapPoints (i)
    self:UpdateContentSize ()
  end
end
function ReforgeLite:ReorderCapPoint (i, point)
  local newpos = point
  while newpos > 1 and self.pdb.caps[i].points[newpos - 1].value > self.pdb.caps[i].points[point].value do
    newpos = newpos - 1
  end
  while newpos < #self.pdb.caps[i].points and self.pdb.caps[i].points[newpos + 1].value < self.pdb.caps[i].points[point].value do
    newpos = newpos + 1
  end
  if newpos ~= point then
    local tmp = self.pdb.caps[i].points[point]
    tremove (self.pdb.caps[i].points, point)
    tinsert (self.pdb.caps[i].points, newpos, tmp)
    self:UpdateCapPoints (i)
  end
end
function ReforgeLite:UpdateCapPreset (i, point)
  local preset = self.pdb.caps[i].points[point].preset
  local row = point + (i == 1 and 1 or #self.pdb.caps[1].points + 2)
  if self.capPresets[preset] == nil then
    preset = 1
  end
  if self.capPresets[preset].getter then
    self.statCaps.cells[row][3]:SetTextColor (0.5, 0.5, 0.5)
    self.statCaps.cells[row][3]:EnableMouse (false)
    self.statCaps.cells[row][3]:ClearFocus ()
    self.pdb.caps[i].points[point].value = max(0, ceil (self.capPresets[preset].getter ()))
  else
    self.statCaps.cells[row][3]:SetTextColor (1, 1, 1)
    self.statCaps.cells[row][3]:EnableMouse (true)
  end
  self.statCaps.cells[row][3]:SetText (self.pdb.caps[i].points[point].value)
end
function ReforgeLite:UpdateCapPoints (i)
  local base = (i == 1 and 1 or #self.pdb.caps[1].points + 2)
  for point = 1, #self.pdb.caps[i].points do
    self.statCaps.cells[base + point][1]:SetValue (self.pdb.caps[i].points[point].method)
    self.statCaps.cells[base + point][2]:SetValue (self.pdb.caps[i].points[point].preset)
    self:UpdateCapPreset (i, point)
    self.statCaps.cells[base + point][4]:SetText (self.pdb.caps[i].points[point].after)
  end
end
function ReforgeLite:SetTankingModel (model)
  if self.tankingModel then
    self.pdb.tankingModel = model
    self.tankingModel:SetChecked (model)
    self:UpdateStatWeightList ()
    self:RefreshMethodStats ()
  end
end
function ReforgeLite:SetStatWeights (weights, caps)
  if weights then
    self.pdb.weights = DeepCopy (weights)
    for i = 1, #self.itemStats do
      if self.statWeights.inputs[i] then
        self.statWeights.inputs[i]:SetText (self.pdb.weights[i])
      end
    end
  end
  if caps then
    for i = 1, 2 do
      local count = 0
      if caps[i] then
        count = #caps[i].points
      end
      self.pdb.caps[i].stat = caps[i] and caps[i].stat or 0
      self.statCaps[i].stat:SetValue (self.pdb.caps[i].stat)
      while #self.pdb.caps[i].points < count do
        self:AddCapPoint (i)
      end
      while #self.pdb.caps[i].points > count do
        self:RemoveCapPoint (i, 1)
      end
      if caps[i] then
        self.pdb.caps[i] = DeepCopy (caps[i])
        for p = 1, #self.pdb.caps[i].points do
          self.pdb.caps[i].points[p].method = self.pdb.caps[i].points[p].method or 3
          self.pdb.caps[i].points[p].after = self.pdb.caps[i].points[p].after or 0
          self.pdb.caps[i].points[p].value = self.pdb.caps[i].points[p].value or 0
          self.pdb.caps[i].points[p].preset = self.pdb.caps[i].points[p].preset or 1
        end
      else
        self.pdb.caps[i].stat = 0
        self.pdb.caps[i].points = {}
        self:AddCapPoint (i)
      end
    end
    self:UpdateCapPoints (1)
    self:UpdateCapPoints (2)
    self.statCaps.onUpdate ()
    self:UpdateContentSize ()
    RunNextFrame(function() self:CapUpdater() end)
  end
  self:RefreshMethodStats ()
end
function ReforgeLite:CapUpdater ()
  self.statCaps[1].stat:SetValue (self.pdb.caps[1].stat)
  self.statCaps[2].stat:SetValue (self.pdb.caps[2].stat)
  self:UpdateCapPoints (1)
  self:UpdateCapPoints (2)
end
function ReforgeLite:CustomPresetsExist()
  return (next(ReforgeLite.db.customPresets) or next(ReforgeLite.cdb.customPresets)) ~= nil
end
function ReforgeLite:UpdateStatWeightList ()
  local stats = self.itemStats
  if self.pdb.tankingModel then
    stats = self.tankingStats[playerClass] or stats
  end
  local rows = 0
  for i, v in pairs (stats) do
    rows = rows + 1
  end
  local extraRows = 0
  if self.pdb.tankingModel then
    extraRows = 2
  end
  self.statWeights:ClearCells ()
  self.statWeights.inputs = {}
  rows = ceil (rows / 2) + extraRows
  while self.statWeights.rows > rows do
    self.statWeights:DeleteRow (1)
  end
  if self.statWeights.rows < rows then
    self.statWeights:AddRow (1, rows - self.statWeights.rows)
  end
  if self.pdb.tankingModel then
    self.statWeights.buffs = {}
    self.statWeights.buffs.kings = GUI:CreateCheckButton (self.statWeights, GetSpellInfo(20217), self.pdb.buffs.kings, function (val)
      self.pdb.buffs.kings = val
      self:RefreshMethodStats ()
    end)
    self.statWeights.buffs.strength = GUI:CreateCheckButton (self.statWeights, GetSpellInfo(57330), self.pdb.buffs.strength, function (val)
      self.pdb.buffs.strength = val
      self:RefreshMethodStats ()
    end)
    self.statWeights:SetCell (1, 1, self.statWeights.buffs.kings, "LEFT")
    self.statWeights:SetCell (1, 3, self.statWeights.buffs.strength, "LEFT")
    self.statWeights.buffs.flask = GUI:CreateDropdown (self.statWeights,
      {{value = 0, name = L["Other/No flask"]}, {value = 1, name = "300" .. ITEM_MOD_STRENGTH_SHORT},
       {value = 2, name = "225" .. ITEM_MOD_MASTERY_RATING_SHORT}}, self.pdb.buffs.flask or 0, function (val)
      self.pdb.buffs.flask = (val ~= 0 and val)
      self:RefreshMethodStats ()
    end, 125)
    self.statWeights.buffs.food = GUI:CreateDropdown (self.statWeights,
      {{value = 0, name = L["Other/No food"]}, {value = 1, name = "90" .. ITEM_MOD_MASTERY_RATING_SHORT},
       {value = 2, name = "90" .. ITEM_MOD_DODGE_RATING_SHORT}, {value = 3, name = "90" .. ITEM_MOD_PARRY_RATING_SHORT},
       {value = 4, name = "90" .. ITEM_MOD_STRENGTH_SHORT},{value = 5, name = "40" .. ITEM_MOD_STRENGTH_SHORT}}, self.pdb.buffs.food or 0, function (val)
      self.pdb.buffs.food = (val ~= 0 and val)
      self:RefreshMethodStats ()
    end, 125)
    self.statWeights:SetCell (2, 1, self.statWeights.buffs.flask, "LEFT", -10, -10)
    self.statWeights:SetCell (2, 3, self.statWeights.buffs.food, "LEFT", -10, -10)
  end
  local pos = 0
  for i, v in pairs (stats) do
    pos = pos + 1
    local col = floor ((pos - 1) / (self.statWeights.rows - extraRows))
    local row = pos - col * (self.statWeights.rows - extraRows) + extraRows
    col = 1 + 2 * col

    self.statWeights:SetCellText (row, col, v.long, "LEFT")
    self.statWeights.inputs[i] = GUI:CreateEditBox (self.statWeights, 60, self.db.itemSize, self.pdb.weights[i], function (val)
      self.pdb.weights[i] = val
      self:RefreshMethodStats ()
    end)
    self.statWeights.inputs[i]:SetScript("OnTabPressed", function(frame)
      if self.statWeights.inputs[i+1] then
        self.statWeights.inputs[i+1]:SetFocus()
      else
        frame:ClearFocus()
      end
    end)
    self.statWeights:SetCell (row, col + 1, self.statWeights.inputs[i])
  end

  if self.pdb.tankingModel then
    self.statCaps:Hide2 ()
    self:SetAnchor (self.computeButton, "TOPLEFT", self.statWeights, "BOTTOMLEFT", 0, -10)
  else
    self.statCaps:Show2 ()
    self:SetAnchor (self.computeButton, "TOPLEFT", self.statCaps, "BOTTOMLEFT", 0, -10)
  end

  self:UpdateBuffs ()
  self:UpdateContentSize ()
end
function ReforgeLite:UpdateBuffs ()
  if self.pdb.tankingModel then
    local kings, strength, flask, food = self:GetPlayerBuffs ()
    if kings then
      self.statWeights.buffs.kings:SetChecked (true)
      self.statWeights.buffs.kings:Disable ()
    else
      self.statWeights.buffs.kings:SetChecked (self.pdb.buffs.kings)
      self.statWeights.buffs.kings:Enable ()
    end
    if strength then
      self.statWeights.buffs.strength:SetChecked (true)
      self.statWeights.buffs.strength:Disable ()
    else
      self.statWeights.buffs.strength:SetChecked (self.pdb.buffs.strength)
      self.statWeights.buffs.strength:Enable ()
    end
    if flask then
      self.statWeights.buffs.flask:SetValue (flask)
      UIDropDownMenu_DisableDropDown (self.statWeights.buffs.flask)
    else
      self.statWeights.buffs.flask:SetValue (self.pdb.buffs.flask or 0)
      UIDropDownMenu_EnableDropDown (self.statWeights.buffs.flask)
    end
    if food then
      self.statWeights.buffs.food:SetValue (food)
      UIDropDownMenu_DisableDropDown (self.statWeights.buffs.food)
    else
      self.statWeights.buffs.food:SetValue (self.pdb.buffs.food or 0)
      UIDropDownMenu_EnableDropDown (self.statWeights.buffs.food)
    end
  end
end
function ReforgeLite:CreateOptionList ()
  self.statWeightsCategory = self:CreateCategory (L["Stat weights"])
  self:SetAnchor (self.statWeightsCategory, "TOPLEFT", self.content, "TOPLEFT", 2, -2)

  self.presetsButton = GUI:CreateImageButton (self.content, 24, 24, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
    "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down", "Interface\\Buttons\\UI-Common-MouseHilight", function (btn)
    LibDD:ToggleDropDownMenu (nil, nil, self.presetMenu, btn:GetName(), 0, 0)
  end)
  self.statWeightsCategory:AddFrame (self.presetsButton)
  self:SetAnchor (self.presetsButton, "TOPLEFT", self.statWeightsCategory, "BOTTOMLEFT", 0, -5)
  self.presetsButton.tip = self.presetsButton:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.presetsButton.tip:SetPoint ("LEFT", self.presetsButton, "RIGHT", 5, 0)
  self.presetsButton.tip:SetText (L["Presets"])

  self.savePresetButton = CreateFrame ("Button", "ReforgeLiteSavePresetButton", self.content, "UIPanelButtonTemplate")
  self.statWeightsCategory:AddFrame (self.savePresetButton)
  self.savePresetButton:SetText (SAVE)
  self.savePresetButton:SetSize (self.savePresetButton:GetFontString():GetStringWidth() + 20, 22)
  self.savePresetButton:SetScript ("OnClick", function() StaticPopup_Show ("REFORGE_LITE_SAVE_PRESET") end)
  self:SetAnchor (self.savePresetButton, "LEFT", self.presetsButton.tip, "RIGHT", 8, 0)

  self.deletePresetButton = CreateFrame ("Button", "ReforgeLiteDeletePresetButton", self.content, "UIPanelButtonTemplate")
  self.statWeightsCategory:AddFrame (self.deletePresetButton)
  self.deletePresetButton:SetText (DELETE)
  self.deletePresetButton:SetSize (self.deletePresetButton:GetFontString():GetStringWidth() + 20, 22)
  self.deletePresetButton:SetScript ("OnClick", function(btn)
    LibDD:ToggleDropDownMenu (nil, nil, self.presetDelMenu, btn:GetName(), 0, 0)
  end)
  self:SetAnchor (self.deletePresetButton, "LEFT", self.savePresetButton, "RIGHT", 5, 0)
  if not self:CustomPresetsExist() then
    self.deletePresetButton:Disable()
  end

  self.exportPresetButton = CreateFrame ("Button", "ReforgeLiteExportPresetButton", self.content, "UIPanelButtonTemplate")
  self.statWeightsCategory:AddFrame (self.exportPresetButton)
  self.exportPresetButton:SetText (L["Export"])
  self.exportPresetButton:SetSize (self.exportPresetButton:GetFontString():GetStringWidth() + 20, 22)
  self.exportPresetButton:SetScript ("OnClick", function (btn)
    LibDD:ToggleDropDownMenu (nil, nil, self.exportPresetMenu, btn:GetName (), 0, 0)
  end)
  self.exportPresetButton:SetPoint ("LEFT", self.deletePresetButton, "RIGHT", 5, 0)

  if not self.isDev then
    self.exportPresetButton:Hide()
  end

  self.pawnButton = CreateFrame ("Button", "ReforgeLiteImportPawnButton", self.content, "UIPanelButtonTemplate")
  self.statWeightsCategory:AddFrame (self.pawnButton)
  self.pawnButton:SetText (L["Import Pawn"])
  self.pawnButton:SetSize (self.pawnButton:GetFontString():GetStringWidth() + 20, 22)
  self.pawnButton:SetScript ("OnClick", function() StaticPopup_Show ("REFORGE_LITE_PARSE_PAWN") end)
  self:SetAnchor (self.pawnButton, "TOPLEFT", self.presetsButton, "BOTTOMLEFT", 0, -5)

  self.convertSpirit = CreateFrame ("Frame", nil, self.content)
  self.statWeightsCategory:AddFrame (self.convertSpirit)
  self.convertSpirit.text = self.convertSpirit:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.convertSpirit.text:SetPoint ("LEFT", self.pawnButton, "RIGHT", 8, 0)
  self.convertSpirit.text:SetText (L["Spirit to hit"] .. ": 0%")

  if playerClass == "PALADIN" or playerClass == "WARRIOR" or playerClass == "DEATHKNIGHT" then
    self.tankingModel = GUI:CreateCheckButton (self.content, STAT_AVOIDANCE .. " " ..PARENS_TEMPLATE:format(localeClass),
        self.pdb.tankingModel, function (val)
      self.pdb.tankingModel = val
      self:UpdateStatWeightList ()
      self:RefreshMethodStats ()
    end)
    self.statWeightsCategory:AddFrame (self.tankingModel)
    self:SetAnchor (self.tankingModel, "TOPLEFT", self.pawnButton, "BOTTOMLEFT", 0, -5)
  else
    self.pdb.tankingModel = nil
  end

  local playerLevel = UnitLevel("player")

  self.targetLevelText = self.statWeightsCategory:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self:SetAnchor(self.targetLevelText, "TOPLEFT", self.tankingModel or self.pawnButton, "BOTTOMLEFT", 0, -5)
  self.targetLevelText:SetTextColor (1, 1, 1)
  self.targetLevelText:SetText(STAT_TARGET_LEVEL..": "..playerLevel.. " +")
  self.statWeightsCategory:AddFrame (self.targetLevelText)

  self.targetLevel = GUI:CreateEditBox (self.content, 25, 30, self.pdb.targetLevel, function (val)
    self.pdb.targetLevel = val
    self.targetLevelResult:SetText("= "..playerLevel + self.pdb.targetLevel)
    self:UpdateItems()
  end, 3)
  self:SetAnchor (self.targetLevel, "LEFT", self.targetLevelText, "RIGHT", 10, 0)
  self.statWeightsCategory:AddFrame (self.targetLevel)

  self.targetLevelResult = self.statWeightsCategory:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self:SetAnchor(self.targetLevelResult, "LEFT", self.targetLevel, "RIGHT", 6, 0)
  self.targetLevelResult:SetTextColor (1, 1, 1)
  self.targetLevelResult:SetText("= "..playerLevel + self.pdb.targetLevel)
  self.statWeightsCategory:AddFrame (self.targetLevelResult)

  self.statWeights = GUI:CreateTable (ceil (#self.itemStats / 2), 4)
  self:SetAnchor (self.statWeights, "TOPLEFT", self.targetLevelText, "BOTTOMLEFT", 0, -8)
  self.statWeights:SetPoint ("RIGHT", -5, 0)
  self.statWeightsCategory:AddFrame (self.statWeights)
  self.statWeights:SetRowHeight (self.db.itemSize + 2)

  self.statCaps = GUI:CreateTable (2, 4, nil, self.db.itemSize + 2)
  self.statWeightsCategory:AddFrame (self.statCaps)
  self:SetAnchor (self.statCaps, "TOPLEFT", self.statWeights, "BOTTOMLEFT", 0, -10)
  self.statCaps:SetPoint ("RIGHT", -5, 0)
  self.statCaps:SetRowHeight (self.db.itemSize + 2)
  self.statCaps:SetColumnWidth (1, 100)
  self.statCaps:SetColumnWidth (3, 50)
  self.statCaps:SetColumnWidth (4, 50)
  local statList = {{value = 0, name = NONE}}
  for i, v in ipairs (self.itemStats) do
    tinsert (statList, {value = i, name = v.long})
  end
  for i = 1, 2 do
    self.statCaps[i] = {}
    self.statCaps[i].stat = GUI:CreateDropdown (self.statCaps, statList, self.pdb.caps[i].stat,
      function (val) self.pdb.caps[i].stat = val end, 110)
    self.statCaps[i].add = GUI:CreateImageButton (self.statCaps, 20, 20, "Interface\\Buttons\\UI-PlusButton-Up",
      "Interface\\Buttons\\UI-PlusButton-Down", "Interface\\Buttons\\UI-PlusButton-Hilight", function ()
      self:AddCapPoint (i)
    end)
    GUI:SetTooltip (self.statCaps[i].add, L["Add cap"])
    self.statCaps:SetCell (i, 0, self.statCaps[i].stat, "LEFT", -20, -10)
    self.statCaps:SetCell (i, 2, self.statCaps[i].add, "LEFT")
  end
  for i = 1, 2 do
    for point = 1, #self.pdb.caps[i].points do
      self:AddCapPoint (i, point)
    end
    self:UpdateCapPoints (i)
  end
  self.statCaps.onUpdate = function ()
    local row = 1
    for i = 1, 2 do
      row = row + 1
      for point = 1, #self.pdb.caps[i].points do
        if self.statCaps.cells[row][2] and self.statCaps.cells[row][2].values then
          UIDropDownMenu_SetWidth (self.statCaps.cells[row][2], self.statCaps:GetColumnWidth (2) - 20)
        end
        row = row + 1
      end
    end
  end
  self.statCaps.saveOnUpdate = self.statCaps.onUpdate
  self.statCaps.onUpdate ()
  RunNextFrame(function() self:CapUpdater() end)

  self.computeButton = CreateFrame ("Button", "ReforgeLiteConfirmButton", self.content, "UIPanelButtonTemplate")
  self.computeButton:SetText (L["Compute"])
  self.computeButton:SetSize (self.computeButton:GetFontString():GetStringWidth() + 20, 22)
  self.computeButton:SetScript ("OnClick", function (btn)
    if self.db.debug then btn.timeRan = GetTimePreciseSec() end
    local method = self:Compute ()
    if method then
      self.pdb.method = method
      self:UpdateMethodCategory ()
      if btn.timeRan then
        print(TIME_ELAPSED, GetTimePreciseSec() - btn.timeRan)
        btn.timeRan = nil
      end
    end
  end)

  self:UpdateStatWeightList ()

  self.quality = CreateFrame ("Slider", nil, self.content, "HorizontalSliderTemplate")
  self:SetAnchor (self.quality, "LEFT", self.computeButton, "RIGHT", 10, 0)
  self.quality:SetSize(150, 15)
  self.quality:SetMinMaxValues (1, 20)
  self.quality:SetValueStep (1)
  self.quality:SetValue (self.db.reforgeCheat)
  self.quality:EnableMouseWheel (false)
  self.quality:SetScript ("OnValueChanged", function (slider)
    self.db.reforgeCheat = slider:GetValue ()
  end)

  self.quality.label = self.quality:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.quality.label:SetPoint ("BOTTOM", self.quality, "TOP", 0, 0)
  self.quality.label:SetTextColor (1, 1, 1)
  self.quality.label:SetText (SPEED)
  self.quality.lowtext = self.quality:CreateFontString (nil, "ARTWORK", "GameFontHighlightSmall")
  self.quality.lowtext:SetPoint ("TOPLEFT", self.quality, "BOTTOMLEFT", 2, 3)
  self.quality.lowtext:SetText ("1")
  self.quality.hightext = self.quality:CreateFontString (nil, "ARTWORK", "GameFontHighlightSmall")
  self.quality.hightext:SetPoint ("TOPRIGHT", self.quality, "BOTTOMRIGHT", -2, 3)
  self.quality.hightext:SetText ("20")

  self.storedCategory = self:CreateCategory (L["Best result"])
  self:SetAnchor (self.storedCategory, "TOPLEFT", self.computeButton, "BOTTOMLEFT", 0, -10)
  self.storedScore = self.content:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.storedCategory:AddFrame (self.storedScore)
  self:SetAnchor (self.storedScore, "TOPLEFT", self.storedCategory, "BOTTOMLEFT", 0, -8)
  self.storedScore:SetTextColor (1, 1, 1)
  self.storedScore:SetText (L["Score"] .. ": ")
  self.storedScore.score = self.content:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.storedCategory:AddFrame (self.storedScore.score)
  self:SetAnchor (self.storedScore.score, "BOTTOMLEFT", self.storedScore, "BOTTOMRIGHT", 0, 0)
  self.storedScore.score:SetTextColor (1, 1, 1)
  self.storedScore.score:SetText ("0 (")
  self.storedScore.delta = self.content:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.storedCategory:AddFrame (self.storedScore.delta)
  self:SetAnchor (self.storedScore.delta, "BOTTOMLEFT", self.storedScore.score, "BOTTOMRIGHT", 0, 0)
  self.storedScore.delta:SetTextColor (0.7, 0.7, 0.7)
  self.storedScore.delta:SetText ("+0")
  self.storedScore.suffix = self.content:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.storedCategory:AddFrame (self.storedScore.suffix)
  self:SetAnchor (self.storedScore.suffix, "BOTTOMLEFT", self.storedScore.delta, "BOTTOMRIGHT", 0, 0)
  self.storedScore.suffix:SetTextColor (1, 1, 1)
  self.storedScore.suffix:SetText (")")

  self.storedClear = CreateFrame ("Button", "ReforgeLiteStoredClear", self.content, "UIPanelButtonTemplate")
  self.storedClear:SetText (KEY_NUMLOCK_MAC)
  self.storedClear:SetSize (self.storedClear:GetFontString():GetStringWidth() + 20, 22)
  self.storedClear:SetScript ("OnClick", function (self)
    ReforgeLite:ClearStoredMethod ()
  end)
  self.storedCategory:AddFrame (self.storedClear)
  self:SetAnchor (self.storedClear, "TOPLEFT", self.storedScore, "BOTTOMLEFT", 0, -8)

  self.storedRestore = CreateFrame ("Button", "ReforgeLiteStoredRestore", self.content, "UIPanelButtonTemplate")
  self.storedRestore:SetText (REFORGE_RESTORE)
  self.storedRestore:SetSize (self.storedRestore:GetFontString():GetStringWidth() + 20, 22)
  self.storedRestore:SetScript ("OnClick", function (self)
    ReforgeLite:RestoreStoredMethod ()
  end)
  self.storedCategory:AddFrame (self.storedRestore)
  self:SetAnchor (self.storedRestore, "BOTTOMLEFT", self.storedClear, "BOTTOMRIGHT", 8, 0)

  if self.pdb.storedMethod then
    local score = self:GetMethodScore (self.pdb.storedMethod)
    self.storedScore.score:SetText (score .. " (")
    SetTextDelta (self.storedScore.delta, score, self:GetCurrentScore ())
    self.storedClear:Enable ()
    self.storedRestore:Enable ()
  else
    self:ClearStoredMethod ()
  end

  self.settingsCategory = self:CreateCategory (SETTINGS)
  self:SetAnchor (self.settingsCategory, "TOPLEFT", self.storedClear, "BOTTOMLEFT", 0, -10)
  self.settings = GUI:CreateTable (5, 1, nil, 200)
  self.settingsCategory:AddFrame (self.settings)
  self:SetAnchor (self.settings, "TOPLEFT", self.settingsCategory, "BOTTOMLEFT", 0, -5)
  self.settings:SetPoint ("RIGHT", self.content, -10, 0)
  self.settings:SetRowHeight (self.db.itemSize + 2)

  self:FillSettings ()

  self.lastElement = CreateFrame ("Frame", nil, self.content)
  self.lastElement:ClearAllPoints ()
  self.lastElement:SetSize(0, 0)
  self:SetAnchor (self.lastElement, "TOPLEFT", self.settings, "BOTTOMLEFT", 0, -10)
  self:UpdateContentSize ()

  if self.pdb.method then
    ReforgeLite:UpdateMethodCategory ()
  end
end
function ReforgeLite:GetActiveFrame()
  if self.methodWindow and self.methodWindow:IsShown() and self.methodWindow:GetFrameLevel () > self:GetFrameLevel() then
    return self.methodWindow
  end
  return self
end
function ReforgeLite:FillSettings ()
  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton (self.settings, L["Open window when reforging"],
    self.db.openOnReforge, function (val) self.db.openOnReforge = val end), "LEFT")
  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton (self.settings, L["Show reforged stats in item tooltips"],
    self.db.updateTooltip, function (val) self.db.updateTooltip = val end), "LEFT")

  local activeWindowTitleOrderId = getOrderId('settings')
  self.settings:SetCellText (activeWindowTitleOrderId, 0, L["Active window color"], "LEFT", nil, "GameFontNormal")
  self.settings:SetCell (activeWindowTitleOrderId, 1, GUI:CreateColorPicker (self.settings, 20, 20, self.db.activeWindowTitle, function ()
    self:GetActiveFrame():SetFrameActive(true)
  end), "LEFT")

  local inactiveWindowTitleOrderId = getOrderId('settings')
  self.settings:SetCellText (inactiveWindowTitleOrderId, 0, L["Inactive window color"], "LEFT", nil, "GameFontNormal")
  self.settings:SetCell (inactiveWindowTitleOrderId, 1, GUI:CreateColorPicker (self.settings, 20, 20, self.db.inactiveWindowTitle, function ()
    self:GetActiveFrame():SetFrameActive(false)
  end), "LEFT")

  self.debugButton = CreateFrame ("Button", nil, self.settings, "UIPanelButtonTemplate")
  self.debugButton:SetText (L["Debug"])
  self.debugButton:SetSize (self.debugButton:GetFontString():GetStringWidth() + 20, 22)
  self.debugButton:SetScript ("OnClick", function (btn) self:DebugMethod() end)
  self.settings:SetCell (getOrderId('settings'), 0, self.debugButton, "LEFT")

  if self.isDev then
    self.settings:AddRow()
    self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton(
      self.settings,
      "Debug Mode",
      self.db.debug,
      function (val) self.db.debug = val or nil end
    ), "LEFT")
  end
end
function ReforgeLite:GetCurrentScore ()
  local score = 0
  local unhit = 100 + 0.8 * max (0, self.pdb.targetLevel)
  if self.pdb.tankingModel then
    local dodge = GetDodgeChance ()
    local parry = GetParryChance ()
    score = dodge * self.pdb.weights[self.STATS.DODGE] + parry * self.pdb.weights[self.STATS.PARRY]
    if playerClass == "WARRIOR" then
      local mastery = GetMastery ()
      local block = 20 + mastery * 1.5
      if missChance + dodge + parry + block > unhit then
        block = unhit - missChance - dodge - parry - block
      end
      score = score + block * self.pdb.weights[self.STATS.MASTERY] + (mastery * 1.5) * self.pdb.weights[self.STATS.CRITBLOCK]
    elseif playerClass == "PALADIN" then
      local mastery = GetMastery ()
      local block = 5 + mastery * 2.25
      if missChance + dodge + parry + block > unhit then
        block = unhit - missChance - dodge - parry - block
      end
      score = score + block * self.pdb.weights[self.STATS.MASTERY]
    else
      for i = 1, #self.itemStats do
        if i ~= self.STATS.DODGE and i ~= self.STATS.PARRY then
          score = score + self:GetStatScore (i, self.itemStats[i].getter ())
        end
      end
    end
  else
    for i = 1, #self.itemStats do
      score = score + self:GetStatScore (i, self.itemStats[i].getter ())
    end
  end
  return score
end
function ReforgeLite:UpdateMethodCategory ()
  if self.methodCategory == nil then
    self.methodCategory = self:CreateCategory (L["Result"])
    self:SetAnchor (self.methodCategory, "TOPLEFT", self.computeButton, "BOTTOMLEFT", 0, -10)

    self.importWowSims = CreateFrame ("Button", nil, self.methodCategory, "UIPanelButtonTemplate")
    self.methodCategory:AddFrame (self.importWowSims)
    self.importWowSims:SetText (L["Import WoWSims"])
    self.importWowSims:SetSize (self.importWowSims:GetFontString():GetStringWidth() + 20, 22)
    self.importWowSims:SetScript ("OnClick", function() StaticPopup_Show ("REFORGE_LITE_PARSE_WOWSIMS") end)
    self:SetAnchor (self.importWowSims, "TOPLEFT", self.methodCategory, "BOTTOMLEFT", 0, -5)

    self.methodStats = GUI:CreateTable (#self.itemStats, 2, self.db.itemSize, 60, {0.5, 0.5, 0.5, 1})
    self.methodCategory:AddFrame (self.methodStats)
    self:SetAnchor (self.methodStats, "TOPLEFT", self.importWowSims, "BOTTOMLEFT", 0, -5)
    self.methodStats:SetRowHeight (self.db.itemSize + 2)
    self.methodStats:SetColumnWidth (60)

    self.methodStats:SetCellText (0, 0, L["Score"], "LEFT", {1, 0.8, 0})
    self.methodStats.score = self.methodStats:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
    self.methodStats:SetCell (0, 1, self.methodStats.score)
    self.methodStats.score:SetTextColor (1, 0.8, 0)
    self.methodStats.score:SetText ("0")
    self.methodStats.scoreDelta = self.methodStats:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
    self.methodStats:SetCell (0, 2, self.methodStats.scoreDelta)
    self.methodStats.scoreDelta:SetTextColor (0.7, 0.7, 0.7)
    self.methodStats.scoreDelta:SetText ("+0")

    for i, v in ipairs (self.itemStats) do
      self.methodStats:SetCellText (i, 0, v.tip, "LEFT")

      self.methodStats[i] = {}

      self.methodStats[i].value = self.methodStats:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
      self.methodStats:SetCell (i, 1, self.methodStats[i].value)
      self.methodStats[i].value:SetTextColor (1, 1, 1)
      self.methodStats[i].value:SetText ("0")

      self.methodStats[i].delta = self.methodStats:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
      self.methodStats:SetCell (i, 2, self.methodStats[i].delta)
      self.methodStats[i].delta:SetTextColor (0.7, 0.7, 0.7)
      self.methodStats[i].delta:SetText ("+0")
    end

    self.methodShow = CreateFrame ("Button", nil, self.content, "UIPanelButtonTemplate")
    self.methodShow:SetSize(85, 22)
    self.methodShow:SetText (SHOW)
    self.methodShow:SetScript ("OnClick", function (btn) self:ShowMethodWindow() end)
    self.methodCategory:AddFrame (self.methodShow)
    self:SetAnchor (self.methodShow, "TOPLEFT", self.methodStats, "BOTTOMLEFT", 0, -5)

    self.methodReset = CreateFrame ("Button", nil, self.content, "UIPanelButtonTemplate")
    self.methodReset:SetSize(85, 22)
    self.methodReset:SetText (RESET)
    self.methodReset:SetScript ("OnClick", function (btn) self:ResetMethod() end)
    self.methodCategory:AddFrame (self.methodReset)
    self:SetAnchor (self.methodReset, "BOTTOMLEFT", self.methodShow, "BOTTOMRIGHT", 8, 0)

    self:SetAnchor (self.storedCategory, "TOPLEFT", self.methodShow, "BOTTOMLEFT", 0, -10)

    self.methodTank = CreateFrame ("Frame", nil, self.content)
    self.methodCategory:AddFrame (self.methodTank)
    self.methodTank:SetPoint ("TOPLEFT", self.methodStats, "TOPRIGHT", 10, 0)
    self.methodTank:SetPoint ("BOTTOMLEFT", self.methodStats, "BOTTOMRIGHT", 10, 0)
    self.methodTank:SetPoint ("RIGHT", self.content, "RIGHT", -2, 0)

    for i = 1, 10 do
      self.methodTank[i] = self.methodTank:CreateFontString (nil, "ARTWORK", "GameFontNormal")
      if i == 1 then
        self.methodTank[i]:SetPoint ("TOPLEFT", self.methodTank, "TOPLEFT", 0, 0)
      else
        self.methodTank[i]:SetPoint ("TOPLEFT", self.methodTank[i - 1], "BOTTOMLEFT", 0, -3)
      end
      self.methodTank[i]:SetPoint ("RIGHT", self.methodTank, "RIGHT", 0, 0)
      self.methodTank[i]:SetJustifyH ("LEFT")
      self.methodTank[i]:Hide ()
    end
    self.methodTank.ClearLines = function (m)
      for i = 1, 10 do
        m[i]:Hide ()
      end
      m.counter = 0
    end
    self.methodTank.PrintLine = function (m, text, ...)
      m.counter = m.counter + 1
      m[m.counter]:Show ()
      m[m.counter]:SetText (text:format(...))
    end
  end

  self:RefreshMethodStats (true)

  self:UpdateContentSize ()
end
function ReforgeLite:RefreshMethodStats (relax)
  local score, storedScore = 0, 0
  if self.pdb.method then
    self:UpdateMethodStats (self.pdb.method)
    score = self:GetMethodScore (self.pdb.method)
  end
  if self.pdb.storedMethod then
    self:UpdateMethodStats (self.pdb.storedMethod)
    storedScore = self:GetMethodScore (self.pdb.storedMethod)
  end
  if self.pdb.method then
    if self.methodStats then
      if self.pdb.tankingModel then
        self.methodTank:Show2 ()
        self.methodTank:ClearLines ()
        local ctc = missChance
        self.methodTank:PrintLine ("%s: %.2f%%", DODGE_CHANCE, self.pdb.method.stats.dodge or 0)
        ctc = ctc + (self.pdb.method.stats.dodge or 0)
        self.methodTank:PrintLine ("%s: %.2f%%", PARRY_CHANCE, self.pdb.method.stats.parry or 0)
        ctc = ctc + (self.pdb.method.stats.parry or 0)
        if playerClass == "WARRIOR" or playerClass == "PALADIN" then
          self.methodTank:PrintLine ("%s: %.2f%%", BLOCK_CHANCE, (self.pdb.method.stats.block or 0) +
                                                                      (self.pdb.method.stats.overcap or 0))
          ctc = ctc + (self.pdb.method.stats.block or 0) + (self.pdb.method.stats.overcap or 0)
        end
        if playerClass == "WARRIOR" then
          self.methodTank:PrintLine ("%s: %.2f%%", L["Crit block"], self.pdb.method.stats.critBlock or 0)
        end
        self.methodTank:PrintLine ("%s: %.2f%%", TOTAL, ctc)
      else
        self.methodTank:Hide2 ()
      end
      self.methodStats.score:SetText (floor (score + 0.5))
      SetTextDelta (self.methodStats.scoreDelta, score, self:GetCurrentScore ())
      for i, v in ipairs (self.itemStats) do
        local mvalue = v.mgetter (self.pdb.method)
        if v.percent then
          self.methodStats[i].value:SetText (format ("%.2f%%", mvalue))
        else
          self.methodStats[i].value:SetText (format ("%s", mvalue))
        end
        local override
        mvalue = v.mgetter (self.pdb.method, true)
        local value = v.getter ()
        if self:GetStatScore (i, mvalue) == self:GetStatScore (i, value) then
          override = 0
        end
        SetTextDelta (self.methodStats[i].delta, mvalue, value, override)
      end
    end
    if relax and (self.pdb.storedMethod == nil or score > storedScore) then
      self.pdb.storedMethod = DeepCopy (self.pdb.method)
      self:UpdateMethodStats (self.pdb.storedMethod)
      storedScore = score
      self.storedClear:Enable ()
      self.storedRestore:Enable ()
    end
  end
  if self.pdb.storedMethod then
    self.storedScore.score:SetText (format ("%s (", storedScore))
    SetTextDelta (self.storedScore.delta, storedScore, self:GetCurrentScore ())
  end
end
function ReforgeLite:ClearStoredMethod ()
  self.pdb.storedMethod = nil
  self.storedScore.score:SetTextColor (0.7, 0.7, 0.7)
  self.storedScore.score:SetText ("- (")
  self.storedScore.delta:SetTextColor (0.7, 0.7, 0.7)
  self.storedScore.delta:SetText ("+0")
  self.storedClear:Disable ()
  self.storedRestore:Disable ()
end
function ReforgeLite:RestoreStoredMethod ()
  if self.pdb.storedMethod then
    self.pdb.method = self.pdb.storedMethod
    self:UpdateMethodCategory ()
  end
end
function ReforgeLite:UpdateContentSize ()
  self.content:SetHeight (-self:GetFrameY (self.lastElement))
  RunNextFrame(function() self:FixScroll() end)
end

function ReforgeLite:GetReforgeTableIndex(src, dst)
  for k,v in ipairs(reforgeTable) do
    if v[1] == src and v[2] == dst then
      return k
    end
  end
  return UNFORGE_INDEX
end

local function SearchTooltipForReforgeID(tip)
  local _, item = tip:GetItem()
  local existingStats = GetItemStats(item)
  local srcStat, destStat
  for _, region in pairs({tip:GetRegions()}) do
    if region:GetObjectType() == "FontString" and region:GetText() then
      for statId, statInfo in ipairs(ReforgeLite.itemStats) do
        local statValue
        if type(statInfo.parser) == "function" then
          statValue = statInfo.parser(region)
        else
          statValue = strmatch(region:GetText(), statInfo.parser)
        end
        if statValue then
          if not existingStats[statInfo.name] then
            destStat = statId
          elseif existingStats[statInfo.name] - tonumber(statValue) > 0 then
            srcStat = statId
          end
        end
      end
      if srcStat and destStat then break end
    end
  end
  return ReforgeLite:GetReforgeTableIndex(srcStat, destStat)
end

local reforgeIdTooltip
function GetReforgeIdForInventorySlot(slotId)
    if ignoredSlots[slotId] then return end
    if not reforgeIdTooltip then
        reforgeIdTooltip = CreateFrame("GameTooltip", addonName.."Tooltip", nil, "GameTooltipTemplate")
        reforgeIdTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    reforgeIdTooltip:SetInventoryItem("player", slotId)
    return SearchTooltipForReforgeID(reforgeIdTooltip)
end

function ReforgeLite:GetReforgeID (slotId)
  local reforgeId = GetReforgeIdForInventorySlot(slotId)
  if reforgeId and reforgeId > UNFORGE_INDEX then
    return reforgeId
  end
end

local reforgeIdStringCache = setmetatable({}, {
  __index = function(self, key)
    local id = tonumber(key:match ("item:%d+:%d+:%d+:%d+:%d+:%d+:%-?%d+:%-?%d+:%d+:(%d+)")) or false
    rawset(self, key, id)
    return id
  end
})

function ReforgeLite:GetReforgeIDFromString(item)
  local id = reforgeIdStringCache[item]
  return ((id and id ~= UNFORGE_INDEX) and (id - self.REFORGE_TABLE_BASE) or nil)
end

function ReforgeLite:UpdateItems ()
  if not self.initialized then return end
  for i, v in ipairs (self.itemData) do
    local item = Item:CreateFromEquipmentSlot(v.slotId)
    local stats = {}
    local reforgeSrc, reforgeDst
    if not item:IsItemEmpty() then
      v.item = item:GetItemLink()
      v.itemId = item:GetItemID()
      v.ilvl = item:GetCurrentItemLevel()
      v.texture:SetTexture(item:GetItemIcon())
      stats = GetItemStats(v.item)
      v.reforge = self:GetReforgeID(v.slotId)
      if v.reforge then
        local srcId, dstId = unpack(reforgeTable[v.reforge])
        reforgeSrc, reforgeDst = self.itemStats[srcId].name, self.itemStats[dstId].name
        local amount = floor ((stats[reforgeSrc] or 0) * 0.4)
        stats[reforgeSrc] = (stats[reforgeSrc] or 0) - amount
        stats[reforgeDst] = (stats[reforgeDst] or 0) + amount
      end
    else
      v.item = nil
      v.texture:SetTexture (v.slotTexture)
    end
    for j, s in ipairs (self.itemStats) do
      if stats[s.name] and stats[s.name] ~= 0 then
        self.itemData[i].stats[j]:SetText (stats[s.name])
        if s.name == reforgeSrc then
          self.itemData[i].stats[j]:SetTextColor (1, 0.4, 0.4)
        elseif s.name == reforgeDst then
          self.itemData[i].stats[j]:SetTextColor (0.6, 1, 0.6)
        else
          self.itemData[i].stats[j]:SetTextColor (1, 1, 1)
        end
      else
        self.itemData[i].stats[j]:SetText ("-")
        self.itemData[i].stats[j]:SetTextColor (0.8, 0.8, 0.8)
      end
    end
  end
  for i, v in ipairs (self.itemStats) do
    self.statTotals[i]:SetText (v.getter ())
  end
  for i = 1, 2 do
    for point = 1, #self.pdb.caps[i].points do
      local value = self.pdb.caps[i].points[point].value
      self:UpdateCapPreset (i, point)
      if value ~= self.pdb.caps[i].points[point].value then
        self:ReorderCapPoint (i, point)
      end
    end
  end

  self.itemLevel:SetText (STAT_AVERAGE_ITEM_LEVEL .. ": " .. floor(select(2,GetAverageItemLevel())))

  self.s2hFactor = 0
  if playerClass == "PRIEST" then
    local pts = select(5, GetTalentInfo (3, 20))
    self.s2hFactor = pts * 50
  elseif playerClass == "DRUID" and GetPrimaryTalentTree () ~= 2 then
    local pts = select(5, GetTalentInfo (1, 7))
    self.s2hFactor = pts * 50
  elseif playerClass == "SHAMAN" and GetPrimaryTalentTree () ~= 2 then
    local pts = select(5, GetTalentInfo (1, 9))
    self.s2hFactor = (pts == 3 and 100 or pts * 33)
  elseif playerClass == "PALADIN" then
    local pts = select(5, GetTalentInfo (1, 4))
    self.s2hFactor = pts * 50
  end
  if self.s2hFactor > 0 then
    self.convertSpirit.text:SetText (L["Spirit to hit"] .. ": " .. self.s2hFactor .. "%")
    self.convertSpirit.text:Show ()
  else
    self.convertSpirit.text:Hide ()
  end

  self:UpdateBuffs ()
  self:RefreshMethodStats ()
end

local queueUpdateEvents = {
  ["COMBAT_RATING_UPDATE"] = true,
  ["MASTERY_UPDATE"] = true,
  ["PLAYER_EQUIPMENT_CHANGED"] = true,
  ["FORGE_MASTER_OPENED"] = true,
  ["FORGE_MASTER_CLOSED"] = true,
  ["FORGE_MASTER_ITEM_CHANGED"] = true,
}

function ReforgeLite:QueueUpdate()
  RunNextFrame(function() self:UpdateItems() end)
  if self.methodWindow then
    RunNextFrame(function() self:UpdateMethodChecks() end)
  end
end

--------------------------------------------------------------------------

function ReforgeLite:ShowMethodWindow ()
  if not self.methodWindow then
    self.methodWindow = CreateFrame ("Frame", "ReforgeLiteMethodWindow", UIParent, "BackdropTemplate")
    self.methodWindow:SetFrameStrata ("DIALOG")
    self.methodWindow:SetFrameLevel (self:GetFrameLevel () + 10)
    self.methodWindow:ClearAllPoints ()
    self.methodWindow:SetSize(250, 506)
    if self.db.methodWindowX and self.db.methodWindowY then
      self.methodWindow:SetPoint ("TOPLEFT", UIParent, "BOTTOMLEFT", self.db.methodWindowX, self.db.methodWindowY)
    else
      self.methodWindow:SetPoint ("CENTER")
    end
    self.methodWindow.backdropInfo = self.backdropInfo
    self.methodWindow:ApplyBackdrop()

    self.methodWindow.titlebar = self.methodWindow:CreateTexture(nil,"BACKGROUND")
    self.methodWindow.titlebar:SetPoint("TOPLEFT",self.methodWindow,"TOPLEFT",3,-3)
    self.methodWindow.titlebar:SetPoint("TOPRIGHT",self.methodWindow,"TOPRIGHT",-3,-3)
    self.methodWindow.titlebar:SetHeight(20)
    self.methodWindow.SetFrameActive = function(frame, active)
      if active then
        frame.titlebar:SetColorTexture(unpack (self.db.activeWindowTitle))
      else
        frame.titlebar:SetColorTexture(unpack (self.db.inactiveWindowTitle))
      end
    end
    self.methodWindow:SetFrameActive(true)

    self.methodWindow:SetBackdropColor (0.1, 0.1, 0.1)
    self.methodWindow:SetBackdropBorderColor (0, 0, 0)

    self.methodWindow:EnableMouse (true)
    self.methodWindow:SetMovable (true)
    self.methodWindow:SetScript ("OnMouseDown", function (window, arg)
      if window:GetFrameLevel () < self:GetFrameLevel () then
        window:SetFrameLevel (self:GetFrameLevel () + 10)
        window:SetFrameActive(true)
        self:SetFrameActive(false)
      end
      if arg == "LeftButton" then
        window:StartMoving ()
        window.moving = true
      end
    end)
    self.methodWindow:SetScript ("OnMouseUp", function (window)
      if window.moving then
        window:StopMovingOrSizing ()
        window.moving = false
        self.db.methodWindowX = window:GetLeft ()
        self.db.methodWindowY = window:GetTop ()
      end
    end)
    tinsert(UISpecialFrames, self.methodWindow:GetName()) -- allow closing with escape

    self.methodWindow.title = self.methodWindow:CreateFontString (nil, "OVERLAY", "GameFontNormal")
    self.methodWindow.title:SetPoint ("TOPLEFT", 10, -8)
    self.methodWindow.title:SetTextColor (1, 1, 1)
    self.methodWindow.title:SetText (addonTitle.." Output")

    self.methodWindow.close = CreateFrame ("Button", nil, self.methodWindow, "UIPanelCloseButtonNoScripts")
    self.methodWindow.close:SetPoint ("TOPRIGHT")
    self.methodWindow.close:SetSize(28, 28)
    self.methodWindow.close:SetScript ("OnClick", function (btn)
      btn:GetParent():Hide()
    end)
    self.methodWindow:SetScript ("OnHide", function (frame)
      self:SetFrameActive(true)
    end)
    self.methodWindow:SetScript ("OnShow", function (frame)
      self:SetFrameActive(false)
      frame:SetFrameActive(true)
    end)
    self:SetFrameActive(false)

    self.methodWindow.itemTable = GUI:CreateTable (#self.itemSlots + 1, 3, 0, 0, nil, self.methodWindow)
    self.methodWindow:ClearAllPoints ()
    self.methodWindow.itemTable:SetPoint ("TOPLEFT", 12, -28)
    self.methodWindow.itemTable:SetRowHeight (26)
    self.methodWindow.itemTable:SetColumnWidth (1, self.db.itemSize)
    self.methodWindow.itemTable:SetColumnWidth (2, self.db.itemSize + 2)
    self.methodWindow.itemTable:SetColumnWidth (3, 274 - self.db.itemSize * 2)

    self.methodOverride = {}
    for i = 1, #self.itemSlots do
      self.methodOverride[i] = 0
    end

    self.methodWindow.items = {}
    for i, v in ipairs (self.itemSlots) do
      self.methodWindow.items[i] = CreateFrame ("Frame", nil, self.methodWindow.itemTable)
      self.methodWindow.items[i].slot = v
      self.methodWindow.items[i]:ClearAllPoints ()
      self.methodWindow.items[i]:SetSize(self.db.itemSize, self.db.itemSize)
      self.methodWindow.itemTable:SetCell (i, 2, self.methodWindow.items[i])
      self.methodWindow.items[i]:EnableMouse (true)
      self.methodWindow.items[i]:RegisterForDrag("LeftButton")
      self.methodWindow.items[i]:SetScript ("OnEnter", function (itemSlot)
        GameTooltip:SetOwner(itemSlot, "ANCHOR_LEFT")
        if itemSlot.item then
          local slotId = GetInventorySlotInfo(v)
          GameTooltip:SetInventoryItem("player", slotId)
        else
          local text = _G[strupper (itemSlot.slot)]
          if itemSlot.checkRelic then
            text = _G["RELICSLOT"]
          end
          GameTooltip:SetText (text)
        end
        GameTooltip:Show ()
      end)
      self.methodWindow.items[i]:SetScript ("OnLeave", function () GameTooltip:Hide() end)
      self.methodWindow.items[i]:SetScript ("OnDragStart", function (itemSlot)
        if itemSlot.item and ReforgeFrameIsVisible() then
          PickupInventoryItem(GetInventorySlotInfo(v))
        end
      end)
      self.methodWindow.items[i].slotId, self.methodWindow.items[i].slotTexture, self.methodWindow.items[i].checkRelic = GetInventorySlotInfo (v)
      self.methodWindow.items[i].checkRelic = self.methodWindow.items[i].checkRelic and UnitHasRelicSlot ("player")
      if self.methodWindow.items[i].checkRelic then
        self.methodWindow.items[i].slotTexture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Relic.blp"
      end
      self.methodWindow.items[i].texture = self.methodWindow.items[i]:CreateTexture (nil, "OVERLAY")
      self.methodWindow.items[i].texture:SetAllPoints (self.methodWindow.items[i])
      self.methodWindow.items[i].texture:SetTexture (self.methodWindow.items[i].slotTexture)

      self.methodWindow.items[i].reforge = self.methodWindow.itemTable:CreateFontString (nil, "OVERLAY", "GameFontNormal")
      self.methodWindow.itemTable:SetCell (i, 3, self.methodWindow.items[i].reforge, "LEFT")
      self.methodWindow.items[i].reforge:SetTextColor (1, 1, 1)
      self.methodWindow.items[i].reforge:SetText ("")

      self.methodWindow.items[i].check = GUI:CreateCheckButton (self.methodWindow.itemTable, "", false,
        function (val) self.methodOverride[i] = (val and 1 or -1) self:UpdateMethodChecks () end)
      self.methodWindow.itemTable:SetCell (i, 1, self.methodWindow.items[i].check)
    end
    self.methodWindow.reforge = CreateFrame ("Button", nil, self.methodWindow, "UIPanelButtonTemplate")
    self.methodWindow.reforge:SetSize(114, 22)
    self.methodWindow.reforge:SetPoint ("BOTTOMLEFT", 12, 12)
    self.methodWindow.reforge:SetText (REFORGE)
    self.methodWindow.reforge:SetScript ("OnClick", function (btn)
      self:DoReforge ()
    end)
    self.methodWindow.reforgeTip = CreateFrame ("Frame", nil, self.methodWindow)
    self.methodWindow.reforgeTip:SetAllPoints (self.methodWindow.reforge)
    self.methodWindow.reforgeTip:EnableMouse (true)
    GUI:SetTooltip (self.methodWindow.reforgeTip, L["Reforging window must be open"])
    self.methodWindow.reforgeTip:SetFrameLevel (self.methodWindow.reforge:GetFrameLevel () + 5)
    self.methodWindow.reforgeTip:Hide ()

    self.methodWindow.cost = CreateFrame ("Frame", "ReforgeLiteReforgeCost", self.methodWindow, "SmallMoneyFrameTemplate")
    MoneyFrame_SetType (self.methodWindow.cost, "REFORGE")
    self.methodWindow.cost:SetPoint ("LEFT", self.methodWindow.reforge, "RIGHT", 5, 0)
  end

  for i = 1, #self.itemSlots do
    self.methodOverride[i] = 0
  end

  self.methodWindow:SetFrameLevel (self:GetFrameLevel () + 10)

  for i, v in ipairs (self.methodWindow.items) do
    local item = Item:CreateFromEquipmentSlot(v.slotId)
    if not item:IsItemEmpty() then
      v.item = item:GetItemLink()
      v.texture:SetTexture(item:GetItemIcon())
    else
      v.item = nil
      v.texture:SetTexture (v.slotTexture)
    end
    local slotInfo = self.pdb.method.items[i]
    if slotInfo.reforge then
      v.reforge:SetText (format ("%d %s > %s", slotInfo.amount, self.itemStats[slotInfo.src].long, self.itemStats[slotInfo.dst].long))
      v.reforge:SetTextColor (1, 1, 1)
    else
      v.reforge:SetText (L["No reforge"])
      v.reforge:SetTextColor (0.7, 0.7, 0.7)
    end
  end
  self:UpdateMethodChecks ()
  self.methodWindow:Show ()
end
function ReforgeLite:IsReforgeMatching (slotId, reforge, override)
  if override == 1 then
    return true
  end

  local oreforge = self:GetReforgeID (slotId)

  if override == -1 then
    return reforge == oreforge
  end

  local stats = GetItemStats(GetInventoryItemLink("player", slotId))

  local deltas = {}
  for i = 1, #self.itemStats do
    deltas[i] = 0
  end

  if oreforge then
    local osrc, odst = unpack(reforgeTable[oreforge])
    local oamount = floor ((stats[self.itemStats[osrc].name] or 0) * REFORGE_COEFF)
    deltas[osrc] = deltas[osrc] + oamount
    deltas[odst] = deltas[odst] - oamount
  end

  if reforge then
    local src, dst = unpack(reforgeTable[reforge])
    local amount = floor ((stats[self.itemStats[src].name] or 0) * REFORGE_COEFF)
    deltas[src] = deltas[src] - amount
    deltas[dst] = deltas[dst] + amount
  end

  deltas[self.STATS.SPIRIT] = floor (deltas[self.STATS.SPIRIT] * self.spiritBonus + 0.5)
  deltas[self.STATS.HIT] = deltas[self.STATS.HIT] + floor (deltas[self.STATS.SPIRIT] * self.s2hFactor / 100 + 0.5)

  for i = 1, #self.itemStats do
    if self:GetStatScore (i, self.pdb.method.stats[i]) ~= self:GetStatScore (i, self.pdb.method.stats[i] - deltas[i]) then
      return false
    end
  end
  return true
end

function ReforgeLite:UpdateMethodChecks ()
  if self.methodWindow and self.pdb.method then
    local cost = 0
    local anyDiffer = false
    for i, v in ipairs (self.methodWindow.items) do
      local item = Item:CreateFromEquipmentSlot(v.slotId)
      v.item = item:GetItemLink()
      v.texture:SetTexture (item:GetItemIcon() or v.slotTexture)
      if item:IsItemEmpty() or self:IsReforgeMatching (v.slotId, self.pdb.method.items[i].reforge, self.methodOverride[i]) then
        v.check:SetChecked (true)
      else
        anyDiffer = true
        v.check:SetChecked (false)
        if self.pdb.method.items[i].reforge then
          local itemCost = select (11, C_Item.GetItemInfo (v.item)) or 0
          cost = cost + (itemCost > 0 and itemCost or 100000)
        end
      end
    end
    self.methodWindow.reforge:Disable()
    self.methodWindow.reforgeTip:Hide()
    self.methodWindow.cost:Hide()
    if anyDiffer then
      local enoughMoney = GetMoney() >= cost
      SetMoneyFrameColorByFrame(self.methodWindow.cost, enoughMoney and "white" or "red")
      if not ReforgeFrameIsVisible() then
        self.methodWindow.reforgeTip:Show()
      elseif enoughMoney then
        self.methodWindow.reforge:Enable()
      end
      self.methodWindow.cost:Show()
    end
    MoneyFrame_Update (self.methodWindow.cost, cost)
  end
end

--------------------------------------------------------------------------

local function ClearReforgeWindow()
  ClearCursor()
  C_Reforge.SetReforgeFromCursorItem ()
  ClearCursor()
end

function ReforgeLite:StopReforging()
  self.curReforgeItem = nil
  self.reforgingNow = nil
  self.methodWindow.reforge:SetScript ("OnUpdate", nil)
  self.methodWindow.reforge:SetText (REFORGE)
  ClearReforgeWindow()
end

function ReforgeLite:DoReforgeUpdate ()
  if not (self.curReforgeItem and self.pdb.method and self.methodWindow.reforge:IsShown() and ReforgeFrameIsVisible()) then
    self:StopReforging()
  end
  if self.reforgeSent then return end
  while self.curReforgeItem <= #self.methodWindow.items do
    local slotInfo = self.methodWindow.items[self.curReforgeItem]
    local newReforge = self.pdb.method.items[self.curReforgeItem].reforge
    if slotInfo.item and not self:IsReforgeMatching(slotInfo.slotId, newReforge, self.methodOverride[self.curReforgeItem]) then
      if self.reforgingNow ~= slotInfo.slotId then
        self.reforgingNow = slotInfo.slotId
        PickupInventoryItem(self.reforgingNow)
        C_Reforge.SetReforgeFromCursorItem()
      end
      if newReforge then
        local id = UNFORGE_INDEX
        local stats = GetItemStats (slotInfo.item)
        for s, reforgeInfo in ipairs(reforgeTable) do
          local srcstat, dststat = unpack(reforgeInfo)
          if (stats[self.itemStats[srcstat].name] or 0) ~= 0 and (stats[self.itemStats[dststat].name] or 0) == 0 then
            id = id + 1
          end
          if srcstat == self.pdb.method.items[self.curReforgeItem].src and dststat == self.pdb.method.items[self.curReforgeItem].dst then
            self.reforgeSent = true
            C_Reforge.ReforgeItem (id)
            return
          end
        end
        self:StopReforging()
      elseif self:GetReforgeID(self.reforgingNow) then
        self.reforgeSent = true
        C_Reforge.ReforgeItem (UNFORGE_INDEX)
      end
      return
    end
    self.curReforgeItem = self.curReforgeItem + 1
  end
  self:StopReforging()
end

function ReforgeLite:DoReforge ()
  if self.pdb.method and self.methodWindow and ReforgeFrameIsVisible() then
    if self.curReforgeItem then
      self:StopReforging()
    else
      self.curReforgeItem = INVSLOT_FIRST_EQUIPPED
      ClearReforgeWindow()
      self.methodWindow.reforge:SetScript ("OnUpdate", function () self:DoReforgeUpdate() end)
      self.methodWindow.reforge:SetText (CANCEL)
    end
  end
end

--------------------------------------------------------------------------

function ReforgeLite:OnTooltipSetItem (tip)
  if not self.db.updateTooltip then return end
  local _, item = tip:GetItem()
  if not item then return end
  for _, region in pairs({tip:GetRegions()}) do
    if region:GetObjectType() == "FontString" and region:GetText() == REFORGED then
      local reforgeId = self:GetReforgeIDFromString(item) or SearchTooltipForReforgeID(tip)
      if not reforgeId or reforgeId == UNFORGE_INDEX then return end
      local srcId, destId = unpack(reforgeTable[reforgeId])
      region:SetText(("%s (%s > %s)"):format(REFORGED, self.itemStats[srcId].long, self.itemStats[destId].long))
      return
    end
  end
end

function ReforgeLite:SetUpHooks ()
  local tooltips = {
    "GameTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ItemRefTooltip",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
  }
  for _,tooltipName in ipairs(tooltips) do
    local tooltip = _G[tooltipName]
    if tooltip then
      tooltip:HookScript("OnTooltipSetItem", function(tip) self:OnTooltipSetItem(tip) end)
    end
  end
end

--------------------------------------------------------------------------

function ReforgeLite:FORGE_MASTER_ITEM_CHANGED()
  self.reforgeSent = nil
  self:UpdateItems()
end

function ReforgeLite:FORGE_MASTER_OPENED()
  if self.db.openOnReforge and (not self.methodWindow or not self.methodWindow:IsShown()) then
    self:Show()
  end
  self.reforgeSent = nil
end

function ReforgeLite:FORGE_MASTER_CLOSED()
  if self.db.openOnReforge then
    self:Hide()
    if self.methodWindow then
      self.methodWindow:Hide()
    end
  end
  self.reforgeSent = nil
end

function ReforgeLite:OnEvent(event, ...)
  if self[event] then
    self[event](self, ...)
  end
  if queueUpdateEvents[event] then
    self:QueueUpdate()
  end
end

function ReforgeLite:OnShow()
  if not self.initialized then
    self:CreateFrame()
    self.initialized = true
  end
  if not self.methodWindow or not self.methodWindow:IsShown() then
    self:SetFrameActive(true)
  end
  self:UpdateItems()
end

function ReforgeLite:OnCommand (cmd)
  self:Show ()
end

function ReforgeLite:ADDON_LOADED (addon)
  if addon ~= addonName then return end
  self:Hide()
  self:UpgradeDB()
  self.db = ReforgeLiteDB
  self.pdb = self.db.profiles[self.dbkey]
  self.cdb = self.db.classProfiles[playerClass]

  self.pdb.reforgeIDs = nil
  self.s2hFactor = 0

  self:SetUpHooks()

  for event in pairs(queueUpdateEvents) do
    self:RegisterEvent(event)
  end
  self:UnregisterEvent("ADDON_LOADED")

  self:SetScript("OnShow", self.OnShow)

  for k, v in pairs({ addonName, "reforge", REFORGE:lower() }) do
    _G["SLASH_"..addonName:upper()..k] = "/" .. v
  end
  SlashCmdList[addonName:upper()] = function(...) self:OnCommand(...) end
end

ReforgeLite:SetScript ("OnEvent", ReforgeLite.OnEvent)
ReforgeLite:RegisterEvent ("ADDON_LOADED")
