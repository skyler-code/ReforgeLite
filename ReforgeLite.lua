local addonName, addonTable = ...
local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "title")
local CreateColor, WHITE_FONT_COLOR, ITEM_MOD_SPIRIT_SHORT = CreateColor, WHITE_FONT_COLOR, ITEM_MOD_SPIRIT_SHORT

local ReforgeLite = CreateFrame("Frame", addonName, UIParent, "BackdropTemplate")
addonTable.ReforgeLite = ReforgeLite
ReforgeLite:Hide ()
ReforgeLiteDB = nil

local L = addonTable.L
local GUI = addonTable.GUI

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

local AddonPath = "Interface\\AddOns\\" .. addonName .. "\\"
local DefaultDB = {
  itemSize = 24,
  windowWidth = 800,
  windowHeight = 564,

  reforgeCheat = 1,

  openOnReforge = true,
  updateTooltip = true,

  activeWindowTitle = {0.8, 0, 0},
  inactiveWindowTitle = {0.5, 0.5, 0.5},

  customPresets = {
  },
  profiles = {
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

local function ReforgeFrameIsVisible()
  return ReforgingFrame and ReforgingFrame:IsShown()
end

ReforgeLite.dbkey = UnitName ("player") .. " - " .. GetRealmName ()
addonTable.localeClass, addonTable.playerClass = UnitClass ("player")
addonTable.playerRace = select(2,UnitRace ("player"))
local playerClass, playerRace, localeClass = addonTable.playerClass, addonTable.playerRace, addonTable.localeClass
local missChance = (playerRace == "NightElf" and 7 or 5)
local UNFORGE_INDEX = -1
addonTable.StatCaps = {
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
end

-----------------------------------------------------------------

StaticPopupDialogs["REFORGE_LITE_SAVE_PRESET"] = {
  text = L["Enter the preset name"],
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = true,
  maxLetters = 31,
  OnAccept = function (self)
    local name = self.editBox:GetText ()
    ReforgeLite.db.customPresets[name] = {
      caps = DeepCopy (ReforgeLite.pdb.caps),
      weights = DeepCopy (ReforgeLite.pdb.weights)
    }
    ReforgeLite.deletePresetButton:Enable ()
  end,
  EditBoxOnEnterPressed = function (self)
    local name = self:GetParent ().editBox:GetText ()
    if name ~= "" then
      ReforgeLite.db.customPresets[name] = {
        caps = DeepCopy (ReforgeLite.pdb.caps),
        weights = DeepCopy (ReforgeLite.pdb.weights)
      }
      ReforgeLite.deletePresetButton:Enable ()
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
  local function RatingStat (i, name_, tip_, id_, hid_, short)
    if hid_ then
      if playerClass == "HUNTER" then
        id_ = hid_
      end
    end
    return {
      name = name_,
      tip = tip_,
      long = tip_,
      getter = function ()
        local rating = GetCombatRating (id_)
        if id_ == CR_HIT_SPELL and self.s2hFactor and self.s2hFactor > 0 and HasFireBuff() then
          rating = rating - floor(FIRE_SPIRIT*(self.s2hFactor/100))
        end
        return rating
      end,
      mgetter = function (method, orig)
        return (orig and method.orig_stats and method.orig_stats[i]) or method.stats[i]
      end,
      parser = short and "^+(%d+) " .. _G[name_].."$" or _G[name_]:gsub("%%s", "(.+)")
    }
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
          return strmatch(line:GetText(), "^+(%d+) "..ITEM_MOD_SPIRIT_SHORT.."$")
        end
      end
    },
    RatingStat (self.STATS.DODGE, "ITEM_MOD_DODGE_RATING", STAT_DODGE, CR_DODGE),
    RatingStat (self.STATS.PARRY, "ITEM_MOD_PARRY_RATING", STAT_PARRY, CR_PARRY),
    RatingStat (self.STATS.HIT, "ITEM_MOD_HIT_RATING", HIT, CR_HIT_SPELL, CR_HIT_RANGED),
    RatingStat (self.STATS.CRIT, "ITEM_MOD_CRIT_RATING", CRIT_ABBR, CR_CRIT_SPELL, CR_CRIT_RANGED),
    RatingStat (self.STATS.HASTE, "ITEM_MOD_HASTE_RATING", STAT_HASTE, CR_HASTE_SPELL, CR_HASTE_RANGED),
    RatingStat (self.STATS.EXP, "ITEM_MOD_EXPERTISE_RATING", STAT_EXPERTISE, CR_EXPERTISE),
    RatingStat (self.STATS.MASTERY, "ITEM_MOD_MASTERY_RATING_SHORT", STAT_MASTERY, CR_MASTERY, nil, true)
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

function ReforgeLite:ParsePawnString (pawn)
  local pos, _, version, name, values = strfind (pawn, "^%s*%(%s*Pawn%s*:%s*v(%d+)%s*:%s*\"([^\"]+)\"%s*:%s*(.+)%s*%)%s*$")
  version = tonumber (version)
  if not (pos and version and name and values) or name == "" or values == "" or version > 1 then
    return
  end

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

StaticPopupDialogs["REFORGE_LITE_PARSE_PAWN"] = {
  text = L["Enter pawn string"],
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = true,
  editBoxWidth = 350,
  maxLetters = 1024,
  OnAccept = function (self)
    local pawn = self.editBox:GetText ()
    ReforgeLite:ParsePawnString (pawn)
  end,
  EditBoxOnEnterPressed = function (self)
    local pawn = self:GetParent ().editBox:GetText ()
    if pawn ~= "" then
      ReforgeLite:ParsePawnString (pawn)
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


local orderIds = {}
local function getOrderId(section)
  orderIds[section] = (orderIds[section] or 0) + 1
  return orderIds[section]
end

------------------------------------------------------------------------

function ReforgeLite:CreateCategory (name)
  local c = CreateFrame ("Frame", nil, self.content)
  c:ClearAllPoints ()
  c:SetWidth (16)
  c:SetHeight (16)
  c.expanded = true

  c.name = c:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  c.catname = c.name
  c.name:SetPoint ("TOPLEFT", c, "TOPLEFT", 18, -1)
  c.name:SetTextColor (1, 1, 1)
  c.name:SetText (name)

  c.button = CreateFrame ("Button", nil, c)
  c.button:ClearAllPoints ()
  c.button:SetWidth (14)
  c.button:SetHeight (14)
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
  c.button:SetScript ("OnClick", function (self)
    self:GetParent ():Toggle ()
  end)
  c.button.anchor = {point = "TOPLEFT", rel = c, relPoint = "TOPLEFT", x = 0, y = 0}

  c.frames = {}
  c.anchors = {}
  c.AddFrame = function (self, frame)
    table.insert (self.frames, frame)
    frame.Show2 = function (self)
      if self.category.expanded then
        self:Show ()
      end
      self.chidden = nil
    end
    frame.Hide2 = function (self)
      self:Hide ()
      self.chidden = true
    end
    frame.category = self
  end

  c.Toggle = function (self)
    self.expanded = not self.expanded
    if c.expanded then
      for k, v in pairs (self.frames) do
        if not v.chidden then
          v:Show ()
        end
      end
      for k, v in pairs (self.anchors) do
        v.frame:SetPoint (v.point, v.rel, v.relPoint, v.x, v.y)
      end
    else
      for k, v in pairs (self.frames) do
        v:Hide ()
      end
      for k, v in pairs (self.anchors) do
        v.frame:SetPoint (v.point, self.button, v.relPoint, v.x, v.y)
      end
    end
    self.button:UpdateTexture ()
    ReforgeLite:UpdateContentSize ()
  end

  return c
end

function ReforgeLite:SetAnchor (frame_, point_, rel_, relPoint_, offsX, offsY)
  if rel_ and rel_.catname and rel_.button then
    rel_ = rel_.button
  end
  if rel_.category then
    table.insert (rel_.category.anchors, {frame = frame_, point = point_, rel = rel_, relPoint = relPoint_, x = offsX, y = offsY})
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
function ReforgeLite:MoveScroll (value)
  local viewheight = self.scrollFrame:GetHeight ()
  local height = self.content:GetHeight ()
  if self.scrollBarShown then
    local diff = height - viewheight
    local delta = (value > 0 and -1 or 1)
    self.scrollBar:SetValue (min (max (self.scrollValue + delta * (1000 / (diff / 45)), 0), 1000))
  end
end
function ReforgeLite:FixScroll ()
  self:SetScript ("OnUpdate", nil)

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

function ReforgeLite:CreateFrame ()
  self:SetFrameStrata ("DIALOG")
  self:ClearAllPoints ()
  self:SetWidth (self.db.windowWidth)
  self:SetHeight (self.db.windowHeight)
  self:SetResizeBounds(780, 500, 1000, 800)
  if self.db.windowX and self.db.windowY then
    self:SetPoint ("TOPLEFT", UIParent, "BOTTOMLEFT", self.db.windowX, self.db.windowY)
  else
    self:SetPoint ("CENTER")
  end
  self:SetBackdrop ({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
    edgeFile = AddonPath .. "textures\\frameborder", edgeSize = 32,
    insets = {left = 1, right = 1, top = 20, bottom = 1}
  })
  self:SetBackdropBorderColor (unpack (self.db.activeWindowTitle))
  self:SetBackdropColor (0.1, 0.1, 0.1)

  self:EnableMouse (true)
  self:SetMovable (true)
  self:SetResizable (true)
  self:SetScript ("OnMouseDown", function (self, arg)
    if self.methodWindow and self:GetFrameLevel () < self.methodWindow:GetFrameLevel () then
      self:SetFrameLevel (self.methodWindow:GetFrameLevel () + 10)
      self:SetBackdropBorderColor (unpack (self.db.activeWindowTitle))
      self.methodWindow:SetBackdropBorderColor (unpack (self.db.inactiveWindowTitle))
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

  self.title = self:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.title:SetPoint ("TOPLEFT", self, "TOPLEFT", 6, -15)
  self.title:SetTextColor (1, 1, 1)
  self.title:SetText (addonTitle)

  self.close = CreateFrame ("Button", nil, self)
  self.close:SetNormalTexture ("Interface\\Buttons\\UI-Panel-MinimizeButton-Up.blp")
  self.close:SetPushedTexture ("Interface\\Buttons\\UI-Panel-MinimizeButton-Down.blp")
  self.close:SetHighlightTexture ("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight.blp")
  self.close:SetWidth (20)
  self.close:SetHeight (20)
  self.close:SetPoint ("TOPRIGHT", self, "TOPRIGHT", -4, -12)
  self.close:SetScript ("OnClick", function (self)
    self:GetParent ():Hide ()
  end)

  self.leftGrip = CreateFrame ("Button", nil, self)
  self.leftGrip:SetNormalTexture (AddonPath .. "textures\\leftgrip")
  self.leftGrip:SetHighlightTexture (AddonPath .. "textures\\leftgrip")
  self.leftGrip:SetWidth (20)
  self.leftGrip:SetHeight (20)
  self.leftGrip:SetPoint ("BOTTOMLEFT", self, "BOTTOMLEFT", -4, -4)
  self.leftGrip:SetScript ("OnMouseDown", function (self, arg)
    if arg == "LeftButton" then
      self:GetParent ():StartSizing ("BOTTOMLEFT")
      self:GetParent ().sizing = true
    end
  end)
  self.leftGrip:SetScript ("OnMouseUp", function (self)
    if self:GetParent ().sizing then
      self:GetParent ():StopMovingOrSizing ()
      self:GetParent ().sizing = false
      self:GetParent ():UpdateWindowSize ()
    end
  end)

  self.rightGrip = CreateFrame ("Button", nil, self)
  self.rightGrip:SetNormalTexture (AddonPath .. "textures\\rightGrip")
  self.rightGrip:SetHighlightTexture (AddonPath .. "textures\\rightGrip")
  self.rightGrip:SetWidth (20)
  self.rightGrip:SetHeight (20)
  self.rightGrip:SetPoint ("BOTTOMRIGHT", self, "BOTTOMRIGHT", 4, -4)
  self.rightGrip:SetScript ("OnMouseDown", function (self, arg)
    if arg == "LeftButton" then
      self:GetParent ():StartSizing ("BOTTOMRIGHT")
      self:GetParent ().sizing = true
    end
  end)
  self.rightGrip:SetScript ("OnMouseUp", function (self)
    if self:GetParent ().sizing then
      self:GetParent ():StopMovingOrSizing ()
      self:GetParent ().sizing = false
      self:GetParent ():UpdateWindowSize ()
    end
  end)

  self:CreateItemTable ()

  self.scrollValue = 0
  self.scrollOffset = 0
  self.scrollBarShown = false

  self.scrollFrame = CreateFrame ("ScrollFrame", nil, self)
  self.scrollFrame:ClearAllPoints ()
  self.scrollFrame:SetPoint ("LEFT", self.itemTable, "RIGHT", 10, 0)
  self.scrollFrame:SetPoint ("TOP", self, "TOP", 0, -40)
  self.scrollFrame:SetPoint ("BOTTOMRIGHT", self, "BOTTOMRIGHT", -22, 15)
  self.scrollFrame:EnableMouseWheel (true)
  self.scrollFrame:SetScript ("OnMouseWheel", function (self, value)
    ReforgeLite:MoveScroll (value)
  end)
  self.scrollFrame:SetScript ("OnSizeChanged", function (self)
    ReforgeLite:SetScript ("OnUpdate", ReforgeLite.FixScroll)
  end)

  self.scrollBar = CreateFrame ("Slider", "ReforgeLiteScrollBar", self.scrollFrame, "UIPanelScrollBarTemplate")
  self.scrollBar:SetPoint ("TOPLEFT", self.scrollFrame, "TOPRIGHT", 4, -16)
  self.scrollBar:SetPoint ("BOTTOMLEFT", self.scrollFrame, "BOTTOMRIGHT", 4, 16)
  self.scrollBar:SetMinMaxValues (0, 1000)
  self.scrollBar:SetValueStep (1)
  self.scrollBar:SetValue (0)
  self.scrollBar:SetWidth (16)
  self.scrollBar:SetScript ("OnValueChanged", function (self, value)
    ReforgeLite:SetScroll (value)
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

  self:SetScript ("OnUpdate", self.FixScroll)
end

function ReforgeLite:CreateItemTable ()
  self.itemLevel = self:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.itemLevel:SetPoint ("TOPLEFT", self, "TOPLEFT", 12, -40)
  self.itemLevel:SetTextColor (1, 1, 0.8)
  self.itemLevel:SetText (STAT_AVERAGE_ITEM_LEVEL .. ": 0")
  
  self.itemTable = GUI:CreateTable (#self.itemSlots + 1, #self.itemStats, self.db.itemSize, self.db.itemSize + 4, {0.5, 0.5, 0.5, 1}, self)
  self.itemTable:SetPoint ("TOPLEFT", self.itemLevel, "BOTTOMLEFT", 0, -10)
  self.itemTable:SetPoint ("BOTTOM", self, "BOTTOM", 0, 10)
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
    self.itemData[i]:ClearAllPoints ()
    self.itemData[i]:SetWidth (self.db.itemSize)
    self.itemData[i]:SetHeight (self.db.itemSize)
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
      self.pdb.itemsLocked[i] = not self.pdb.itemsLocked[i]
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
    table.insert (self.pdb.caps[i].points, 1, {value = 0, method = 1, after = 0, preset = 1})
  end

  local rem = GUI:CreateImageButton (self.statCaps, 20, 20, "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent",
    "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent", nil, function ()
    self:RemoveCapPoint (i, point)
  end)
  local methodList = {
    {value = addonTable.StatCaps.AtLeast, name = L["At least"]},
    {value = addonTable.StatCaps.AtMost, name = L["At most"]},
    {value = addonTable.StatCaps.NewValue, name = ""}
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
  table.remove (self.pdb.caps[i].points, point)
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
    table.remove (self.pdb.caps[i].points, point)
    table.insert (self.pdb.caps[i].points, newpos, tmp)
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
      local cur = #self.pdb.caps[i].points
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
    self.presetsButton:SetScript ("OnUpdate", function ()
      self.presetsButton:SetScript ("OnUpdate", nil)
      self:CapUpdater ()
    end)
  end
  self:RefreshMethodStats ()
end
function ReforgeLite:CapUpdater ()
  self.statCaps[1].stat:SetValue (self.pdb.caps[1].stat)
  self.statCaps[2].stat:SetValue (self.pdb.caps[2].stat)
  self:UpdateCapPoints (1)
  self:UpdateCapPoints (2)
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
    "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down", "Interface\\Buttons\\UI-Common-MouseHilight", function ()
    ToggleDropDownMenu (1, nil, self.presetMenu, self.presetsButton:GetName (), 0, 0)
  end)
  self.statWeightsCategory:AddFrame (self.presetsButton)
  self:SetAnchor (self.presetsButton, "TOPLEFT", self.statWeightsCategory, "BOTTOMLEFT", 0, -5)
  self.presetsButton.tip = self.presetsButton:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.presetsButton.tip:SetPoint ("LEFT", self.presetsButton, "RIGHT", 5, 0)
  self.presetsButton.tip:SetText (L["Presets"])

  self.savePresetButton = CreateFrame ("Button", "ReforgeLiteSavePresetButton", self.content, "UIPanelButtonTemplate")
  self.statWeightsCategory:AddFrame (self.savePresetButton)
  self.savePresetButton:SetWidth (114)
  self.savePresetButton:SetHeight (22)
  self.savePresetButton:SetText (SAVE)
  self.savePresetButton:SetScript ("OnClick", function (self)
    StaticPopup_Show ("REFORGE_LITE_SAVE_PRESET")
  end)
  self:SetAnchor (self.savePresetButton, "LEFT", self.presetsButton.tip, "RIGHT", 8, 0)

  self.deletePresetButton = CreateFrame ("Button", "ReforgeLiteDeletePresetButton", self.content, "UIPanelButtonTemplate")
  self.statWeightsCategory:AddFrame (self.deletePresetButton)
  self.deletePresetButton:SetWidth (114)
  self.deletePresetButton:SetHeight (22)
  self.deletePresetButton:SetText (DELETE)
  self.deletePresetButton:SetScript ("OnClick", function ()
    if next (self.db.customPresets) then
      ToggleDropDownMenu (1, nil, self.presetDelMenu, self.deletePresetButton:GetName (), 0, 0)
    end
  end)
  self:SetAnchor (self.deletePresetButton, "LEFT", self.savePresetButton, "RIGHT", 5, 0)
  if next (self.db.customPresets) == nil then
    self.deletePresetButton:Disable ()
  end

  self.pawnButton = CreateFrame ("Button", "ReforgeLiteDeletePresetButton", self.content, "UIPanelButtonTemplate")
  self.statWeightsCategory:AddFrame (self.pawnButton)
  self.pawnButton:SetWidth (114)
  self.pawnButton:SetHeight (22)
  self.pawnButton:SetText (L["Import Pawn"])
  self.pawnButton:SetScript ("OnClick", function (self)
    StaticPopup_Show ("REFORGE_LITE_PARSE_PAWN")
  end)
  self:SetAnchor (self.pawnButton, "TOPLEFT", self.presetsButton, "BOTTOMLEFT", 0, -5)

  self.convertSpirit = CreateFrame ("Frame", nil, self.content)
  self.statWeightsCategory:AddFrame (self.convertSpirit)
  self.convertSpirit.text = self.convertSpirit:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.convertSpirit.text:SetPoint ("LEFT", self.pawnButton, "RIGHT", 8, 0)
  self.convertSpirit.text:SetText (L["Spirit to hit"] .. ": 0%")
  self.convertSpirit.text:Hide ()

  if playerClass == "PALADIN" or playerClass == "WARRIOR" or playerClass == "DEATHKNIGHT" then
    self.tankingModel = GUI:CreateCheckButton (self.content, STAT_AVOIDANCE .. " " ..PARENS_TEMPLATE:format(localeClass),
        self.pdb.tankingModel, function (val)
      self.pdb.tankingModel = val
      self:UpdateStatWeightList ()
      self:RefreshMethodStats ()
    end)
    self.statWeightsCategory:AddFrame (self.tankingModel)
    self:SetAnchor (self.tankingModel, "TOPLEFT", self.pawnButton, "BOTTOMLEFT", 0, -5)
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
  self.statWeights:SetPoint ("RIGHT", self.content, "RIGHT", -5, 0)
  self.statWeightsCategory:AddFrame (self.statWeights)
  self.statWeights:SetRowHeight (self.db.itemSize + 2)

  self.statCaps = GUI:CreateTable (2, 4, nil, self.db.itemSize + 2)
  self.statWeightsCategory:AddFrame (self.statCaps)
  self:SetAnchor (self.statCaps, "TOPLEFT", self.statWeights, "BOTTOMLEFT", 0, -10)
  self.statCaps:SetPoint ("RIGHT", self.content, "RIGHT", -5, 0)
  self.statCaps:SetRowHeight (self.db.itemSize + 2)
  self.statCaps:SetColumnWidth (1, 100)
  self.statCaps:SetColumnWidth (3, 50)
  self.statCaps:SetColumnWidth (4, 50)
  local statList = {{value = 0, name = NONE}}
  for i, v in ipairs (self.itemStats) do
    table.insert (statList, {value = i, name = v.long})
  end
  for i = 1, 2 do
    self.statCaps[i] = {}
    self.statCaps[i].stat = GUI:CreateDropdown (self.statCaps, statList, self.pdb.caps[i].stat,
      function (val) self.pdb.caps[i].stat = val end, 110)
    self.statCaps[i].cover = CreateFrame ("Frame", nil, self.statCaps)
    self.statCaps[i].cover:SetAllPoints (self.statCaps[i].stat)
    self.statCaps[i].cover:SetFrameLevel (self.statCaps[i].stat:GetFrameLevel () + 10)
    self.statCaps[i].cover:EnableMouse (true)
    GUI:SetTooltip (self.statCaps[i].cover, L["Only one cap allowed with spirit-to-hit conversion"])
    self.statCaps[i].cover:Hide ()
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
  self.presetsButton:SetScript ("OnUpdate", function ()
    self.presetsButton:SetScript ("OnUpdate", nil)
    self:CapUpdater ()
  end)

  self.computeButton = CreateFrame ("Button", "ReforgeLiteConfirmButton", self.content, "UIPanelButtonTemplate")
  self.computeButton:SetWidth (114)
  self.computeButton:SetHeight (22)
  self.computeButton:SetText (L["Compute"])
  self.computeButton:SetScript ("OnClick", function (self)
    local method = ReforgeLite:Compute ()
    if method then
      ReforgeLite.pdb.method = method
      ReforgeLite:UpdateMethodCategory ()
    end
  end)

  self:UpdateStatWeightList ()

  self.quality = CreateFrame ("Slider", nil, self.content, "BackdropTemplate")
  self:SetAnchor (self.quality, "LEFT", self.computeButton, "RIGHT", 15, 0)
  self.quality:SetOrientation ("HORIZONTAL")
  self.quality:SetWidth (150)
  self.quality:SetHeight (15)
  self.quality:SetHitRectInsets (0, 0, -10, 0)
  self.quality:SetBackdrop ({bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", tile = true, tileSize = 8, edgeSize = 8,
    insets = {left = 3, right = 3, top = 6, bottom = 6}
  })
  self.quality:SetThumbTexture ("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
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
  self.storedClear:SetWidth (114)
  self.storedClear:SetHeight (22)
  self.storedClear:SetText (L["Clear"])
  self.storedClear:SetScript ("OnClick", function (self)
    ReforgeLite:ClearStoredMethod ()
  end)
  self.storedCategory:AddFrame (self.storedClear)
  self:SetAnchor (self.storedClear, "TOPLEFT", self.storedScore, "BOTTOMLEFT", 0, -8)

  self.storedRestore = CreateFrame ("Button", "ReforgeLiteStoredRestore", self.content, "UIPanelButtonTemplate")
  self.storedRestore:SetWidth (114)
  self.storedRestore:SetHeight (22)
  self.storedRestore:SetText (REFORGE_RESTORE)
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
  self.settings:SetPoint ("RIGHT", self.content, "RIGHT", -10, 0)
  self.settings:SetRowHeight (self.db.itemSize + 2)

  self:FillSettings ()
  self.settingsCategory:Toggle ()

  self.lastElement = CreateFrame ("Frame", nil, self.content)
  self.lastElement:ClearAllPoints ()
  self.lastElement:SetWidth (0)
  self.lastElement:SetHeight (0)
  self:SetAnchor (self.lastElement, "TOPLEFT", self.settings, "BOTTOMLEFT", 0, -10)
  self:UpdateContentSize ()

  if self.pdb.method then
    ReforgeLite:UpdateMethodCategory ()
  end
end
function ReforgeLite:FillSettings ()
  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton (self.settings, L["Open window when reforging"],
    self.db.openOnReforge, function (val) self.db.openOnReforge = val end), "LEFT")
  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton (self.settings, L["Show reforged stats in item tooltips"],
    self.db.updateTooltip, function (val) self.db.updateTooltip = val end), "LEFT")

  local activeWindowTitleOrderId = getOrderId('settings')
  self.settings:SetCellText (activeWindowTitleOrderId, 0, L["Active window color"], "LEFT", nil, "GameFontNormal")
  self.settings:SetCell (activeWindowTitleOrderId, 1, GUI:CreateColorPicker (self.settings, 20, 20, self.db.activeWindowTitle, function ()
    if self.methodWindow and self.methodWindow:IsShown () and self.methodWindow:GetFrameLevel () > self:GetFrameLevel () then
      self.methodWindow:SetBackdropBorderColor (unpack (self.db.activeWindowTitle))
    else
      self:SetBackdropBorderColor (unpack (self.db.activeWindowTitle))
    end
  end), "LEFT")

  local inactiveWindowTitleOrderId = getOrderId('settings')
  self.settings:SetCellText (inactiveWindowTitleOrderId, 0, L["Inactive window color"], "LEFT", nil, "GameFontNormal")
  self.settings:SetCell (inactiveWindowTitleOrderId, 1, GUI:CreateColorPicker (self.settings, 20, 20, self.db.inactiveWindowTitle, function ()
    if self.methodWindow and self.methodWindow:IsShown () and self.methodWindow:GetFrameLevel () > self:GetFrameLevel () then
      self:SetBackdropBorderColor (unpack (self.db.inactiveWindowTitle))
    elseif self.methodWindow then
      self.methodWindow:SetBackdropBorderColor (unpack (self.db.inactiveWindowTitle))
    end
  end), "LEFT")

  self.debugButton = CreateFrame ("Button", "ReforgeLiteDebugButton", self.content, "UIPanelButtonTemplate")
  self.debugButton:SetWidth (114)
  self.debugButton:SetHeight (22)
  self.debugButton:SetText (L["Debug"])
  self.debugButton:SetScript ("OnClick", function (self)
    ReforgeLite:DebugMethod ()
  end)
  self.settings:SetCell (getOrderId('settings'), 0, self.debugButton, "LEFT")
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

    self.methodStats = GUI:CreateTable (#self.itemStats, 2, self.db.itemSize, 60, {0.5, 0.5, 0.5, 1})
    self.methodCategory:AddFrame (self.methodStats)
    self:SetAnchor (self.methodStats, "TOPLEFT", self.methodCategory, "BOTTOMLEFT", 0, -5)
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

    self.methodShow = CreateFrame ("Button", "ReforgeLiteMethodShowButton", self.content, "UIPanelButtonTemplate")
    self.methodShow:SetWidth (114)
    self.methodShow:SetHeight (22)
    self.methodShow:SetText (SHOW)
    self.methodShow:SetScript ("OnClick", function (self)
      ReforgeLite:ShowMethodWindow ()
    end)
    self.methodCategory:AddFrame (self.methodShow)
    self:SetAnchor (self.methodShow, "TOPLEFT", self.methodStats, "BOTTOMLEFT", 0, -5)

    self.methodReset = CreateFrame ("Button", "ReforgeLiteMethodResetButton", self.content, "UIPanelButtonTemplate")
    self.methodReset:SetWidth (114)
    self.methodReset:SetHeight (22)
    self.methodReset:SetText (RESET)
    self.methodReset:SetScript ("OnClick", function (self)
      ReforgeLite:ResetMethod ()
    end)
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
      m[m.counter]:SetText (format (text, ...))
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
        self.methodTank:PrintLine ("%s: %.2f%%", L["Total"], ctc)
      else
        self.methodTank:Hide2 ()
      end
      local stats = self.itemStats
--[[      if self.pdb.tankingModel then
        stats = self.tankingStats[self.pdb.tankingModel] or stats
      end
      
      local rows = 0
      for i, _ in pairs (stats) do
        rows = rows + 1
      end
      
      self.methodStats:ClearCells ()
      while self.methodStats.rows > rows do
        self.methodStats:DeleteRow (1)
      end
      if self.methodStats.rows < rows then
        self.methodStats:AddRow (1, rows - self.methodStats.rows)
      end
      self.methodStats:SetRowHeight (self.db.itemSize + 2)
      
      self.methodStats:SetCellText (0, 0, L["Score"], "LEFT", {1, 0.8, 0})
      self.methodStats:SetCell (0, 1, self.methodStats.score)
      self.methodStats:SetCell (0, 2, self.methodStats.scoreDelta)
      self.methodStats.score:Show ()
      self.methodStats.scoreDelta:Show ()]]

      self.methodStats.score:SetText (floor (score + 0.5))
      SetTextDelta (self.methodStats.scoreDelta, score, self:GetCurrentScore ())
--      local pos = 0
--      for i, v in pairs (stats) do
      for i, v in ipairs (stats) do
--        pos = pos + 1
--        self.methodStats:SetCellText (pos, 0, v.tip, "LEFT")

        local mvalue = v.mgetter (self.pdb.method)
        if v.percent then
          self.methodStats[i].value:SetText (format ("%.2f%%", mvalue))
        else
          self.methodStats[i].value:SetText (format ("%s", mvalue))
        end
        local override = nil
        mvalue = v.mgetter (self.pdb.method, true)
        local value = v.getter ()
        if self:GetStatScore (i, mvalue) == self:GetStatScore (i, value) then
          override = 0
        end
        SetTextDelta (self.methodStats[i].delta, mvalue, value, override)
        
--        self.methodStats:SetCell (pos, 1, self.methodStats[pos].value)
--        self.methodStats:SetCell (pos, 2, self.methodStats[pos].delta)
--        self.methodStats[pos].value:Show ()
--        self.methodStats[pos].delta:Show ()
      end
    end
    if relax and (self.pdb.storedMethod == nil or score > storedScore) then
      self.pdb.storedMethod = DeepCopy (self.pdb.method)
      storedScore = score
      self.storedClear:Enable ()
      self.storedRestore:Enable ()
    end
  end
  if self.pdb.storedMethod then
    self:UpdateMethodStats (self.pdb.storedMethod)
    local storedScore = self:GetMethodScore (self.pdb.storedMethod)
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
  self:SetScript ("OnUpdate", self.FixScroll)
end

function ReforgeLite:GetReforgeTableIndex(stat1, stat2)
  for k,v in ipairs(reforgeTable) do
    if v[1] == stat1 and v[2] == stat2 then
      return k
    end
  end
  return UNFORGE_INDEX
end

local function SearchTooltipForReforgeID(tip)
  local _, item = tip:GetItem()
  local existingStats = GetItemStats(item)
  local srcStat, destStat
  for i = 1, tip:NumLines() do
    local tipName = ("%sText%%s%s"):format(tip:GetName(), i)
    local leftLine = _G[tipName:format("Left")]
    for statId, statInfo in ipairs(ReforgeLite.itemStats) do
      local statValue
      if type(statInfo.parser) == "function" then
        statValue = statInfo.parser(leftLine)
      else
        statValue = strmatch(leftLine:GetText(), statInfo.parser)
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
  for i, v in ipairs (self.itemData) do
    local texture = GetInventoryItemTexture ("player", v.slotId)
    local stats = {}
    local reforgeSrc, reforgeDst
    if texture then
      v.item = GetInventoryItemLink ("player", v.slotId)
      v.texture:SetTexture (texture)
      stats = GetItemStats (v.item)
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
  self:SetScript ("OnUpdate", function (frame)
    frame:SetScript ("OnUpdate", nil)
    frame:UpdateItems ()
  end)
  if self.methodWindow then
    self.methodWindow:SetScript ("OnUpdate", function (window)
      window:SetScript ("OnUpdate", nil)
      self:UpdateMethodChecks ()
    end)
  end
end

--------------------------------------------------------------------------

function ReforgeLite:ShowMethodWindow ()
  if not self.methodWindow then
    self.methodWindow = CreateFrame ("Frame", nil, UIParent, "BackdropTemplate")
    self.methodWindow:SetFrameStrata ("DIALOG")
    self.methodWindow:SetFrameLevel (self:GetFrameLevel () + 10)
    self.methodWindow:ClearAllPoints ()
    self.methodWindow:SetWidth (300)
    self.methodWindow:SetHeight (520)
    if self.db.methodWindowX and self.db.methodWindowY then
      self.methodWindow:SetPoint ("TOPLEFT", UIParent, "BOTTOMLEFT", self.db.methodWindowX, self.db.methodWindowY)
    else
      self.methodWindow:SetPoint ("CENTER")
    end
    self.methodWindow:SetBackdrop ({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
      edgeFile = AddonPath .. "textures\\frameborder", edgeSize = 32,
      insets = {left = 1, right = 1, top = 20, bottom = 1}
    })
    self.methodWindow:SetBackdropBorderColor (unpack (self.db.activeWindowTitle))
    self.methodWindow:SetBackdropColor (0.1, 0.1, 0.1)

    self.methodWindow:EnableMouse (true)
    self.methodWindow:SetMovable (true)
    self.methodWindow:SetScript ("OnMouseDown", function (self, arg)
      if self:GetFrameLevel () < ReforgeLite:GetFrameLevel () then
        self:SetFrameLevel (ReforgeLite:GetFrameLevel () + 10)
        self:SetBackdropBorderColor (unpack (ReforgeLite.db.activeWindowTitle))
        ReforgeLite:SetBackdropBorderColor (unpack (ReforgeLite.db.inactiveWindowTitle))
      end
      if arg == "LeftButton" then
        self:StartMoving ()
        self.moving = true
      end
    end)
    self.methodWindow:SetScript ("OnMouseUp", function (self)
      if self.moving then
        self:StopMovingOrSizing ()
        self.moving = false
        ReforgeLite.db.methodWindowX = self:GetLeft ()
        ReforgeLite.db.methodWindowY = self:GetTop ()
      end
    end)

    self.methodWindow.title = self.methodWindow:CreateFontString (nil, "OVERLAY", "GameFontNormal")
    self.methodWindow.title:SetPoint ("TOPLEFT", self.methodWindow, "TOPLEFT", 6, -15)
    self.methodWindow.title:SetTextColor (1, 1, 1)
    self.methodWindow.title:SetText (addonTitle.." Output")

    self.methodWindow.close = CreateFrame ("Button", nil, self.methodWindow)
    self.methodWindow.close:SetNormalTexture ("Interface\\Buttons\\UI-Panel-MinimizeButton-Up.blp")
    self.methodWindow.close:SetPushedTexture ("Interface\\Buttons\\UI-Panel-MinimizeButton-Down.blp")
    self.methodWindow.close:SetHighlightTexture ("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight.blp")
    self.methodWindow.close:SetWidth (20)
    self.methodWindow.close:SetHeight (20)
    self.methodWindow.close:SetPoint ("TOPRIGHT", self.methodWindow, "TOPRIGHT", -4, -12)
    self.methodWindow.close:SetScript ("OnClick", function (self)
      self:GetParent ():Hide ()
      ReforgeLite:SetBackdropBorderColor (unpack (ReforgeLite.db.activeWindowTitle))
    end)

    self.methodWindow.itemTable = GUI:CreateTable (#self.itemSlots + 1, 3, 0, 0, nil, self.methodWindow)
    self.methodWindow:ClearAllPoints ()
    self.methodWindow.itemTable:SetPoint ("TOPLEFT", self.methodWindow, "TOPLEFT", 12, -40)
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
      self.methodWindow.items[i]:SetWidth (self.db.itemSize)
      self.methodWindow.items[i]:SetHeight (self.db.itemSize)
      self.methodWindow.itemTable:SetCell (i, 2, self.methodWindow.items[i])
      self.methodWindow.items[i]:EnableMouse (true)
      self.methodWindow.items[i]:RegisterForDrag("LeftButton")
      self.methodWindow.items[i]:SetScript ("OnEnter", function (self)
        GameTooltip:SetOwner (self, "ANCHORLEFT")
        if self.item then
          local slotId = GetInventorySlotInfo(v)
          GameTooltip:SetInventoryItem("player", slotId)
        else
          local text = _G[strupper (self.slot)]
          if self.checkRelic then
            text = _G["RELICSLOT"]
          end
          GameTooltip:SetText (text)
        end
        GameTooltip:Show ()
      end)
      self.methodWindow.items[i]:SetScript ("OnLeave", function (self)
        GameTooltip:Hide ()
      end)
      self.methodWindow.items[i]:SetScript ("OnDragStart", function (self)
        if self.item then
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
--      self.methodWindow.items[i].check = self.methodWindow.itemTable:CreateTexture (nil, "OVERLAY")
--      self.methodWindow.items[i].check:SetWidth (self.db.itemSize)
--      self.methodWindow.items[i].check:SetHeight (self.db.itemSize)
      self.methodWindow.itemTable:SetCell (i, 1, self.methodWindow.items[i].check)
--      self.methodWindow.items[i].check:SetTexture ("Interface\\Buttons\\UI-CheckBox-Check")
--      self.methodWindow.items[i].check:Hide ()
    end
    self.methodWindow.reforge = CreateFrame ("Button", "ReforgeLiteReforgeButton", self.methodWindow, "UIPanelButtonTemplate")
    self.methodWindow.reforge:SetWidth (114)
    self.methodWindow.reforge:SetHeight (22)
    self.methodWindow.reforge:SetPoint ("BOTTOMLEFT", self.methodWindow, "BOTTOMLEFT", 12, 12)
    self.methodWindow.reforge:SetText (REFORGE)
    self.methodWindow.reforge:SetScript ("OnClick", function (self)
      ReforgeLite:DoReforge ()
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

  self.methodWindow:SetFrameLevel (ReforgeLite:GetFrameLevel () + 10)
  self.methodWindow:SetBackdropBorderColor (unpack (self.db.activeWindowTitle))
  self:SetBackdropBorderColor (unpack (self.db.inactiveWindowTitle))

  for i, v in ipairs (self.methodWindow.items) do
    local item = GetInventoryItemLink ("player", v.slotId)
    local texture = GetInventoryItemTexture ("player", v.slotId)
    if texture then
      v.item = item
      v.texture:SetTexture (texture)
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
      v.item = GetInventoryItemLink ("player", v.slotId)
      local texture = GetInventoryItemTexture ("player", v.slotId)
      v.texture:SetTexture (texture or v.slotTexture)
      if not v.item or self:IsReforgeMatching (v.slotId, self.pdb.method.items[i].reforge, self.methodOverride[i]) then
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
      region:SetText(format("%s (%s > %s)", REFORGED, self.itemStats[srcId].long, self.itemStats[destId].long))
      return
    end
  end
end

local tooltips = {
  "GameTooltip",
  "ShoppingTooltip1",
  "ShoppingTooltip2",
  "ItemRefTooltip",
  "ItemRefShoppingTooltip1",
  "ItemRefShoppingTooltip2",
}

function ReforgeLite:SetUpHooks ()
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
  self:UpdateItems ()
end

function ReforgeLite:FORGE_MASTER_OPENED()
  if self.db.openOnReforge and (not self.methodWindow or not self.methodWindow:IsShown()) then
    self:UpdateItems()
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

function ReforgeLite:OnEvent (event, ...)
  if self[event] then
    self[event](self, ...)
  end
  if queueUpdateEvents[event] then
    self:QueueUpdate()
  end
end

function ReforgeLite:ADDON_LOADED (addon)
  if addon ~= addonName then return end
  self:UpgradeDB ()
  self.db = ReforgeLiteDB
  self.pdb = ReforgeLiteDB.profiles[self.dbkey]

  self.pdb.reforgeIDs = nil

  self:InitPresets ()
  self:CreateFrame ()
  self:FixScroll ()
  self:SetUpHooks()

  for event in pairs(queueUpdateEvents) do
    self:RegisterEvent(event)
  end
  self:UnregisterEvent("ADDON_LOADED")

  for k, v in pairs({ addonName, "reforge" }) do
    _G["SLASH_"..addonName:upper()..k] = "/" .. v
  end
  SlashCmdList[addonName:upper()] = function(...) self:OnCommand(...) end
end

ReforgeLite:SetScript ("OnEvent", function(self, ...) self:OnEvent(...) end)
ReforgeLite:RegisterEvent ("ADDON_LOADED")

function ReforgeLite:OnCommand (cmd)
  self:UpdateItems ()
  self:Show ()
end
