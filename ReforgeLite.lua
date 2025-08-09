local addonName, addonTable = ...
local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "title")

local ReforgeLite = CreateFrame("Frame", addonName, UIParent, "BackdropTemplate")
addonTable.ReforgeLite = ReforgeLite

local L = addonTable.L
local GUI = addonTable.GUI
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
addonTable.MAX_LOOPS = 200000
local MIN_LOOPS = 1000

local DeepCopy = addonTable.DeepCopy
local GetItemStats = addonTable.GetItemStatsUp

local gprint = print
local function print(...)
    gprint("|cff33ff99"..addonName.."|r:",...)
end
addonTable.print = print

local ITEM_SIZE = 24

local DefaultDB = {
  global = {
    windowWidth = 800,
    windowHeight = 564,
    windowY = false,
    windowX = false,
    methodWindowX = false,
    methodWindowY = false,
    openOnReforge = true,
    updateTooltip = false,
    speed = addonTable.MAX_LOOPS * 0.8,
    activeWindowTitle = {0.6, 0, 0},
    inactiveWindowTitle = {0.5, 0.5, 0.5},
    specProfiles = false,
  },
  char = {
    targetLevel = 3,
    ilvlCap = 0,
    meleeHaste = true,
    spellHaste = true,
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
    categoryStates = { [SETTINGS] = false },
  },
  class = {
    customPresets = {}
  },
}

local function ReforgeFrameIsVisible()
  return ReforgingFrame and ReforgingFrame:IsShown()
end

addonTable.localeClass, addonTable.playerClass, addonTable.playerClassID = UnitClass("player")
addonTable.playerRace = select(2, UnitRace("player"))
local UNFORGE_INDEX = -1
addonTable.StatCapMethods = {
  AtLeast = 1,
  AtMost = 2,
  NewValue = 3,
  Exactly = 4,
}

function ReforgeLite:UpgradeDB()
  local db = ReforgeLiteDB
  if not db then return end
  if db.classProfiles then
    db.class = DeepCopy(db.classProfiles)
    db.classProfiles = nil
  end
  if db.profiles then
    db.char = DeepCopy(db.profiles)
    db.profiles = nil
  end
  if not db.global then
    db.global = {}
    for k, v in pairs(db) do
      local default = DefaultDB.global[k]
      if default ~= nil then
        if default ~= v then
          db.global[k] = DeepCopy(v)
        end
        db[k] = nil
      end
    end
  end
end

-----------------------------------------------------------------

GUI.CreateStaticPopup("REFORGE_LITE_SAVE_PRESET", L["Enter the preset name"], { func = function(text)
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
}
local ignoredSlots = { [INVSLOT_TABARD] = true, [INVSLOT_BODY] = true }

local statIds = {
  SPIRIT = 1, DODGE = 2, PARRY = 3, HIT = 4, CRIT = 5, HASTE = 6, EXP = 7, MASTERY = 8, SPELLHIT = 9
}
addonTable.statIds = statIds
ReforgeLite.STATS = statIds

local FIRE_SPIRIT = 4
local function GetFireSpirit()
  local s2h = (ReforgeLite.conversion[statIds.SPIRIT] or {})[statIds.HIT]
  if s2h and C_UnitAuras.GetPlayerAuraBySpellID(7353) then
    return floor(FIRE_SPIRIT * s2h)
  end
  return 0
end

local CR_HIT, CR_CRIT, CR_HASTE = CR_HIT_SPELL, CR_CRIT_SPELL, CR_HASTE_SPELL
if addonTable.playerClass == "HUNTER" then
  CR_HIT, CR_CRIT, CR_HASTE = CR_HIT_RANGED, CR_CRIT_RANGED, CR_HASTE_RANGED
end

local function RatingStat (i, name_, tip_, long_, id_)
  return {
    name = name_,
    tip = tip_,
    long = long_,
    getter = function ()
      local rating = GetCombatRating(id_)
      if id_ == CR_HIT then
        rating = rating - GetFireSpirit()
      end
      return rating
    end,
    mgetter = function (method, orig)
      return (orig and method.orig_stats and method.orig_stats[i]) or method.stats[i]
    end
  }
end

ReforgeLite.itemStats = {
    {
      name = "ITEM_MOD_SPIRIT_SHORT",
      tip = SPELL_STAT5_NAME,
      long = ITEM_MOD_SPIRIT_SHORT,
      getter = function ()
        local _, spirit = UnitStat("player", LE_UNIT_STAT_SPIRIT)
        if GetFireSpirit() ~= 0 then
          spirit = spirit - FIRE_SPIRIT
        end
        return spirit
      end,
      mgetter = function (method, orig)
        return (orig and method.orig_stats and method.orig_stats[statIds.SPIRIT]) or method.stats[statIds.SPIRIT]
      end
    },
    RatingStat (statIds.DODGE,   "ITEM_MOD_DODGE_RATING",         STAT_DODGE,     STAT_DODGE,           CR_DODGE),
    RatingStat (statIds.PARRY,   "ITEM_MOD_PARRY_RATING",         STAT_PARRY,     STAT_PARRY,           CR_PARRY),
    --RatingStat (statIds.HIT,     "ITEM_MOD_HIT_RATING",           HIT,            HIT,                  CR_HIT),
    {
      name = "ITEM_MOD_HIT_RATING",
      tip = HIT,
      long = HIT,
      getter = function()
        local hit = GetCombatRating(CR_HIT)
        if (ReforgeLite.conversion[statIds.EXP] or {})[statIds.HIT] then
          hit = hit + (GetCombatRating(CR_EXPERTISE) * ReforgeLite.conversion[statIds.EXP][statIds.HIT])
        end
        return hit
      end,
      mgetter = function (method, orig)
        return (orig and method.orig_stats and method.orig_stats[statIds.HIT]) or method.stats[statIds.HIT]
      end
    },
    RatingStat (statIds.CRIT,    "ITEM_MOD_CRIT_RATING",          CRIT_ABBR,      CRIT_ABBR,            CR_CRIT),
    RatingStat (statIds.HASTE,   "ITEM_MOD_HASTE_RATING",         STAT_HASTE,     STAT_HASTE,           CR_HASTE),
    RatingStat (statIds.EXP,     "ITEM_MOD_EXPERTISE_RATING",     EXPERTISE_ABBR, STAT_EXPERTISE,       CR_EXPERTISE),
    RatingStat (statIds.MASTERY, "ITEM_MOD_MASTERY_RATING_SHORT", STAT_MASTERY,   STAT_MASTERY,         CR_MASTERY),
}

local REFORGE_TABLE_BASE = 112
local reforgeTable = {
  {statIds.SPIRIT, statIds.DODGE}, {statIds.SPIRIT, statIds.PARRY}, {statIds.SPIRIT, statIds.HIT}, {statIds.SPIRIT, statIds.CRIT}, {statIds.SPIRIT, statIds.HASTE}, {statIds.SPIRIT, statIds.EXP}, {statIds.SPIRIT, statIds.MASTERY},
  {statIds.DODGE, statIds.SPIRIT}, {statIds.DODGE, statIds.PARRY}, {statIds.DODGE, statIds.HIT}, {statIds.DODGE, statIds.CRIT}, {statIds.DODGE, statIds.HASTE}, {statIds.DODGE, statIds.EXP}, {statIds.DODGE, statIds.MASTERY},
  {statIds.PARRY, statIds.SPIRIT}, {statIds.PARRY, statIds.DODGE}, {statIds.PARRY, statIds.HIT}, {statIds.PARRY, statIds.CRIT}, {statIds.PARRY, statIds.HASTE}, {statIds.PARRY, statIds.EXP}, {statIds.PARRY, statIds.MASTERY},
  {statIds.HIT, statIds.SPIRIT}, {statIds.HIT, statIds.DODGE}, {statIds.HIT, statIds.PARRY}, {statIds.HIT, statIds.CRIT}, {statIds.HIT, statIds.HASTE}, {statIds.HIT, statIds.EXP}, {statIds.HIT, statIds.MASTERY},
  {statIds.CRIT, statIds.SPIRIT}, {statIds.CRIT, statIds.DODGE}, {statIds.CRIT, statIds.PARRY}, {statIds.CRIT, statIds.HIT}, {statIds.CRIT, statIds.HASTE}, {statIds.CRIT, statIds.EXP}, {statIds.CRIT, statIds.MASTERY},
  {statIds.HASTE, statIds.SPIRIT}, {statIds.HASTE, statIds.DODGE}, {statIds.HASTE, statIds.PARRY}, {statIds.HASTE, statIds.HIT}, {statIds.HASTE, statIds.CRIT}, {statIds.HASTE, statIds.EXP}, {statIds.HASTE, statIds.MASTERY},
  {statIds.EXP, statIds.SPIRIT}, {statIds.EXP, statIds.DODGE}, {statIds.EXP, statIds.PARRY}, {statIds.EXP, statIds.HIT}, {statIds.EXP, statIds.CRIT}, {statIds.EXP, statIds.HASTE}, {statIds.EXP, statIds.MASTERY},
  {statIds.MASTERY, statIds.SPIRIT}, {statIds.MASTERY, statIds.DODGE}, {statIds.MASTERY, statIds.PARRY}, {statIds.MASTERY, statIds.HIT}, {statIds.MASTERY, statIds.CRIT}, {statIds.MASTERY, statIds.HASTE}, {statIds.MASTERY, statIds.EXP},
}
ReforgeLite.reforgeTable = reforgeTable

addonTable.REFORGE_COEFF = 0.4

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
  if stat == self.pdb.caps[1].stat then
    return self:GetCapScore (self.pdb.caps[1], value)
  elseif stat == self.pdb.caps[2].stat then
    return self:GetCapScore (self.pdb.caps[2], value)
  else
    return self.pdb.weights[stat] * value
  end
end

function ReforgeLite:ValidateWoWSimsString(importStr)
  local success, wowsims = pcall(function () return C_EncodingUtil.DeserializeJSON(importStr) end)
  if success and (wowsims or {}).player then
    local newItems = DeepCopy((self.pdb.method or self:InitializeMethod()).items)
    for slot,item in ipairs(newItems) do
      local simItemInfo = wowsims.player.equipment.items[slot] or {}
      local equippedItemInfo = self.itemData[slot]
      if simItemInfo.id ~= equippedItemInfo.itemId then
        local _, importItemLink = C_Item.GetItemInfo(simItemInfo.id)
        return L["%s does not match your currently equipped %s. ReforgeLite only supports equipped items."]:format(importItemLink or ("item:"..simItemInfo.id), equippedItemInfo.item)
      end
      if simItemInfo.reforging then
        item.src, item.dst = unpack(self.reforgeTable[simItemInfo.reforging - REFORGE_TABLE_BASE])
      else
        item.src, item.dst = nil, nil
      end
    end
    return newItems
  end
end

function ReforgeLite:ApplyWoWSimsImport(newItems)
  if not self.pdb.method then
    self.pdb.method = { items = newItems }
  else
    self.pdb.method.items = newItems
  end
  self:FinalizeReforge(self.pdb)
  self:UpdateMethodCategory()
end

--@debug@
function ReforgeLite:ParsePresetString(presetStr)
  local success, preset = pcall(function () return C_EncodingUtil.DeserializeJSON(presetStr) end)
  if success and type(preset.caps) == "table" then
    DevTools_Dump(preset)
  end
end
--@end-debug@

function ReforgeLite:ValidatePawnString(importStr)
  local pos, _, version, name, values = strfind (importStr, "^%s*%(%s*Pawn%s*:%s*v(%d+)%s*:%s*\"([^\"]+)\"%s*:%s*(.+)%s*%)%s*$")
  version = tonumber (version)
  if version and version > 1 then return end
  if not (pos and version and name and values) or name == "" or values == "" then
    return
  end
  return values
end

function ReforgeLite:ParsePawnString(values)
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
    raw[k] = Round(v * factor)
  end

  self:SetStatWeights ({
    raw["Spirit"] or 0,
    raw["DodgeRating"] or 0,
    raw["ParryRating"] or 0,
    raw["HitRating"] or 0,
    raw["CritRating"] or 0,
    raw["HasteRating"] or 0,
    raw["ExpertiseRating"] or 0,
    raw["MasteryRating"] or 0
  })
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
  c.expanded = self.pdb.categoryStates[name] ~= false
  c.name = c:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  c.catname = c.name
  c.name:SetPoint ("TOPLEFT", c, "TOPLEFT", 18, -1)
  c.name:SetTextColor (1, 1, 1)
  c.name:SetText (name)

  c.button = CreateFrame ("Button", nil, c)
  c.button:ClearAllPoints ()
  c.button:SetSize (14,14)
  c.button:SetPoint ("TOPLEFT")
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
    self.pdb.categoryStates[name] = category.expanded
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
  text:SetFormattedText(value - cur >= 0 and "+%s" or "%s", value - cur)
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

function ReforgeLite:SwapFrameLevels(window)
  if not self.methodWindow then return end
  local topWindow, bottomWindow = self:GetFrameOrder()
  if (window or self) == topWindow then
    topWindow:SetFrameActive(true)
    return
  end
  bottomWindow:SetFrameLevel(topWindow:GetFrameLevel())
  topWindow:SetFrameLevel(max(bottomWindow:GetFrameLevel() - 10, 1))
  bottomWindow:SetFrameActive(true)
  topWindow:SetFrameActive(false)
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
    self:SwapFrameLevels()
    if arg == "LeftButton" then
      self:StartMoving ()
      self.moving = true
    end
  end)
  self:SetScript ("OnMouseUp", function (self)
    if self.moving then
      self:StopMovingOrSizing ()
      self.moving = false
      self.db.windowX = self:GetLeft()
      self.db.windowY = self:GetTop()
    end
  end)
  tinsert(UISpecialFrames, self:GetName()) -- allow closing with escape

  self.titleIcon = CreateFrame("Frame", nil, self)
  self.titleIcon:SetSize(16, 16)
  self.titleIcon:SetPoint ("TOPLEFT", 12, floor(self.titleIcon:GetHeight())-floor(self.titlebar:GetHeight()))

  self.titleIcon.texture = self.titleIcon:CreateTexture("ARTWORK")
  self.titleIcon.texture:SetAllPoints(self.titleIcon)
  self.titleIcon.texture:SetTexture([[Interface\Reforging\Reforge-Portrait]])


  self.title = self:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.title:SetText (addonTitle)
  self.title:SetTextColor (1, 1, 1)
  self.title:SetPoint ("BOTTOMLEFT", self.titleIcon, "BOTTOMRIGHT", 2, 1)

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
  self.playerSpecTexture = self:CreateTexture (nil, "ARTWORK")
  self.playerSpecTexture:SetPoint ("TOPLEFT", 10, -28)
  self.playerSpecTexture:SetSize(18, 18)
  self.playerSpecTexture:SetTexCoord(0.0825, 0.0825, 0.0825, 0.9175, 0.9175, 0.0825, 0.9175, 0.9175)

  self.playerTalents = {}
  for tier = 1, MAX_NUM_TALENT_TIERS do
    self.playerTalents[tier] = self:CreateTexture(nil, "ARTWORK")
    self.playerTalents[tier]:SetPoint("TOPLEFT", self.playerTalents[tier-1] or self.playerSpecTexture, "TOPRIGHT", 4, 0)
    self.playerTalents[tier]:SetSize(18, 18)
    self.playerTalents[tier]:SetTexCoord(0.0825, 0.0825, 0.0825, 0.9175, 0.9175, 0.0825, 0.9175, 0.9175)
    self.playerTalents[tier]:SetScript("OnLeave", GameTooltip_Hide)
  end

  self:UpdatePlayerSpecInfo()

  self.itemTable = GUI:CreateTable (#self.itemSlots + 1, #self.itemStats, ITEM_SIZE, ITEM_SIZE + 4, {0.5, 0.5, 0.5, 1}, self)
  self.itemTable:SetPoint ("TOPLEFT", self.playerSpecTexture, "BOTTOMLEFT", 0, -6)
  self.itemTable:SetPoint ("BOTTOM", 0, 10)
  self.itemTable:SetWidth (400)

  self.itemLevel = self:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  ReforgeLite.itemLevel:SetPoint ("BOTTOMRIGHT", ReforgeLite.itemTable, "TOPRIGHT", 0, 8)
  self.itemLevel:SetTextColor (1, 1, 0.8)

  self.itemLockHelpButton = CreateFrame("Button",nil, self,"MainHelpPlateButton")
  self.itemLockHelpButton:SetFrameLevel(self.itemLockHelpButton:GetParent():GetFrameLevel() + 1)
  self.itemLockHelpButton:SetScale(0.5)
  GUI:SetTooltip(self.itemLockHelpButton, L["The current state of your equipment.\nClicking an item icon will lock it. ReforgeLite will ignore the item(s) in future calculations."])

  self.itemTable:SetCell(0, 0, self.itemLockHelpButton, "TOPLEFT", -5, 10)

  for i, v in ipairs (self.itemStats) do
    self.itemTable:SetCellText (0, i, v.tip)
  end
  self.itemData = {}
  for i, v in ipairs (self.itemSlots) do
    self.itemData[i] = CreateFrame ("Frame", nil, self.itemTable)
    self.itemData[i].slot = v
    self.itemData[i]:ClearAllPoints ()
    self.itemData[i]:SetSize(ITEM_SIZE, ITEM_SIZE)
    self.itemTable:SetCell (i, 0, self.itemData[i])
    self.itemData[i]:EnableMouse (true)
    self.itemData[i]:SetScript ("OnEnter", function (frame)
      GameTooltip:SetOwner (frame, "ANCHOR_LEFT")
      if frame.item then
        GameTooltip:SetInventoryItem("player", frame.slotId)
      else
        GameTooltip:SetText(_G[strupper(frame.slot)])
      end
      GameTooltip:Show ()
    end)
    self.itemData[i]:SetScript ("OnLeave", GameTooltip_Hide)
    self.itemData[i]:SetScript ("OnMouseDown", function (frame)
      if not frame.itemGUID then return end
      self.pdb.itemsLocked[frame.itemGUID] = not self.pdb.itemsLocked[frame.itemGUID] and 1 or nil
      if self.pdb.itemsLocked[frame.itemGUID] then
        frame.locked:Show ()
      else
        frame.locked:Hide ()
      end
    end)
    self.itemData[i].slotId, self.itemData[i].slotTexture = GetInventorySlotInfo (v)
    self.itemData[i].texture = self.itemData[i]:CreateTexture (nil, "ARTWORK")
    self.itemData[i].texture:SetAllPoints (self.itemData[i])
    self.itemData[i].texture:SetTexture (self.itemData[i].slotTexture)
    self.itemData[i].locked = self.itemData[i]:CreateTexture (nil, "OVERLAY")
    self.itemData[i].locked:SetAllPoints (self.itemData[i])
    self.itemData[i].locked:SetTexture ("Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent")
    self.itemData[i].quality = self.itemData[i]:CreateTexture (nil, "OVERLAY")
    self.itemData[i].quality:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    self.itemData[i].quality:SetBlendMode("ADD")
    self.itemData[i].quality:SetAlpha(0.75)
    self.itemData[i].quality:SetSize(44,44)
    self.itemData[i].quality:SetPoint ("CENTER", self.itemData[i])

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
    "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent", nil, nil, function ()
    self:RemoveCapPoint (i, point)
  end)
  local methodList = {
    {value = addonTable.StatCapMethods.AtLeast, name = L["At least"]},
    {value = addonTable.StatCapMethods.AtMost, name = L["At most"]},
    {value = addonTable.StatCapMethods.Exactly, name = L["Exactly"]},
    {value = addonTable.StatCapMethods.NewValue, name = ""}
  }
  local method = GUI:CreateDropdown (self.statCaps, methodList, { default = 1, setter = function (_,val) self.pdb.caps[i].points[point].method = val end, width = 80 })
  local preset = GUI:CreateDropdown (self.statCaps, self.capPresets, {
    default = 1,
    width = 80,
    setter = function (_,val)
      self.pdb.caps[i].points[point].preset = val
      self:UpdateCapPreset (i, point)
      self:ReorderCapPoint (i, point)
      self:RefreshMethodStats ()
    end,
    menuItemHidden = function(info)
      return info.category and info.category ~= self.statCaps[i].stat.selectedValue
    end
  })
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
  GUI:SetTooltip (value, function()
    local cap = self.pdb.caps[i]
    if cap.stat == statIds.SPIRIT then return end
    local pointValue = (cap.points[point].value or 0)
    local rating = pointValue / self:RatingPerPoint(cap.stat)
    if cap.stat == statIds.HIT then
      local meleeHitBonus = self:GetMeleeHitBonus()
      rating = RoundToSignificantDigits(rating, 1)
      if meleeHitBonus > 0 then
        rating = ("%.2f%% + %s%% = %.2f"):format(rating, meleeHitBonus, rating + meleeHitBonus)
      else
        rating = ("%.2f"):format(rating)
      end
      local spellHitRating = RoundToSignificantDigits(pointValue / self:RatingPerPoint(statIds.SPELLHIT), 1)
      local spellHitBonus = self:GetSpellHitBonus()
      if spellHitBonus > 0 then
        spellHitRating = ("%.2f%% + %s%% = %.2f"):format(spellHitRating,spellHitBonus,spellHitRating+spellHitBonus)
      else
        spellHitRating = ("%.2f"):format(spellHitRating)
      end
      rating = ("%s: %s%%\n%s: %s%%"):format(MELEE, rating, STAT_CATEGORY_SPELL, spellHitRating)
    elseif cap.stat == statIds.EXP then
      rating = RoundToSignificantDigits(rating, 1)
      local expBonus = self:GetExpertiseBonus()
      if expBonus > 0 then
        rating = ("%.2f%% + %s%% = %.2f%%"):format(rating, expBonus, rating + expBonus)
      else
        rating = ("%.2f%%"):format(rating)
      end
    elseif cap.stat == statIds.HASTE then
      local meleeHaste, rangedHaste, spellHaste = self:CalcHasteWithBonuses(rating)
      rating = ("%s: %.2f\n%s: %.2f\n%s: %.2f"):format(MELEE, meleeHaste, RANGED, rangedHaste, STAT_CATEGORY_SPELL, spellHaste)
    else
      rating = ("%.2f"):format(rating)
    end
    return ("%s\n%s"):format(L["Cap value"], rating)
  end)
  GUI:SetTooltip (after, L["Weight after cap"])

  self.statCaps:SetCell (row, 0, rem)
  self.statCaps:SetCell (row, 1, method, "LEFT", -20, -10)
  self.statCaps:SetCell (row, 2, preset, "LEFT", -20, -10)
  self.statCaps:SetCell (row, 3, value)
  self.statCaps:SetCell (row, 4, after)

  if not loading then
    self:UpdateCapPoints (i)
    self:UpdateContentSize ()
  end
  self.statCaps[i].add:Enable()
  self.statCaps:OnUpdateFix()
end
function ReforgeLite:RemoveCapPoint (i, point, loading)
  local row = #self.pdb.caps[1].points + (i == 1 and 1 or #self.pdb.caps[2].points + 2)
  tremove (self.pdb.caps[i].points, point)
  self.statCaps:DeleteRow (row)
  if not loading then
    self:UpdateCapPoints (i)
    self:UpdateContentSize ()
  end
  if #self.pdb.caps[i].points == 0 then
    self.pdb.caps[i].stat = 0
    self.statCaps[i].add:Disable()
    self.statCaps[i].stat:SetValue(0)
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
    self.statCaps.cells[row][3]:SetMouseClickEnabled (false)
    self.statCaps.cells[row][3]:ClearFocus ()
    self.pdb.caps[i].points[point].value = max(0, floor(self.capPresets[preset].getter()))
  else
    self.statCaps.cells[row][3]:SetTextColor (1, 1, 1)
    self.statCaps.cells[row][3]:SetMouseClickEnabled (true)
  end
  self.statCaps.cells[row][3]:SetText(self.pdb.caps[i].points[point].value)
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
function ReforgeLite:CollapseStatCaps()
  local caps = DeepCopy(self.pdb.caps)
  table.sort(caps, function(a,b)
    local aIsNone = a.stat == 0 and 1 or 0
    local bIsNone = b.stat == 0 and 1 or 0
    return aIsNone < bIsNone
  end)
  self:SetStatWeights(nil, caps)
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
      end
    end
    for i=1,2 do
      self:UpdateCapPoints (i)
    end
    self.statCaps:ToggleStatDropdownToCorrectState()
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
  return next(ReforgeLite.cdb.customPresets) ~= nil
end
function ReforgeLite:UpdateStatWeightList ()
  local stats = self.itemStats
  local rows = 0
  for i, v in pairs (stats) do
    rows = rows + 1
  end
  local extraRows = 0
  self.statWeights:ClearCells ()
  self.statWeights.inputs = {}
  rows = ceil (rows / 2) + extraRows
  while self.statWeights.rows > rows do
    self.statWeights:DeleteRow (1)
  end
  if self.statWeights.rows < rows then
    self.statWeights:AddRow (1, rows - self.statWeights.rows)
  end
  local pos = 0
  for i, v in pairs (stats) do
    pos = pos + 1
    local col = floor ((pos - 1) / (self.statWeights.rows - extraRows))
    local row = pos - col * (self.statWeights.rows - extraRows) + extraRows
    col = 1 + 2 * col

    self.statWeights:SetCellText (row, col, v.long, "LEFT")
    self.statWeights.inputs[i] = GUI:CreateEditBox (self.statWeights, 60, ITEM_SIZE, self.pdb.weights[i], function (val)
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

  self.statCaps:Show2 ()
  self:SetAnchor (self.computeButton, "TOPLEFT", self.statCaps, "BOTTOMLEFT", 0, -10)

  self:UpdateContentSize ()
end

function ReforgeLite:CreateOptionList ()
  self.statWeightsCategory = self:CreateCategory (L["Stat Weights"])
  self:SetAnchor (self.statWeightsCategory, "TOPLEFT", self.content, "TOPLEFT", 2, -2)

  self.presetsButton = GUI:CreateImageButton (self.content, 24, 24, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
    "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down", "Interface\\Buttons\\UI-Common-MouseHilight", nil, function (btn)
    LibDD:ToggleDropDownMenu (nil, nil, self.presetMenu, btn:GetName(), 0, 0)
  end)
  self.statWeightsCategory:AddFrame (self.presetsButton)
  self:SetAnchor (self.presetsButton, "TOPLEFT", self.statWeightsCategory, "BOTTOMLEFT", 0, -5)
  self.presetsButton.tip = self.presetsButton:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.presetsButton.tip:SetPoint ("LEFT", self.presetsButton, "RIGHT", 5, 0)
  self.presetsButton.tip:SetText (L["Presets"])

  self.savePresetButton = GUI:CreatePanelButton (self.content, SAVE, function() StaticPopup_Show ("REFORGE_LITE_SAVE_PRESET") end)
  self.statWeightsCategory:AddFrame (self.savePresetButton)
  self:SetAnchor (self.savePresetButton, "LEFT", self.presetsButton.tip, "RIGHT", 8, 0)

  self.deletePresetButton = GUI:CreatePanelButton (self.content, DELETE, function(btn)
    LibDD:ToggleDropDownMenu (nil, nil, self.presetDelMenu, btn:GetName(), 0, 0)
  end)
  self.statWeightsCategory:AddFrame (self.deletePresetButton)
  self:SetAnchor (self.deletePresetButton, "LEFT", self.savePresetButton, "RIGHT", 5, 0)
  if not self:CustomPresetsExist() then
    self.deletePresetButton:Disable()
  end

  --@debug@
  self.exportPresetButton = GUI:CreatePanelButton (self.content, L["Export"], function(btn)
    LibDD:ToggleDropDownMenu (nil, nil, self.exportPresetMenu, btn:GetName(), 0, 0)
  end)
  self.statWeightsCategory:AddFrame (self.exportPresetButton)
  self.exportPresetButton:SetPoint ("LEFT", self.deletePresetButton, "RIGHT", 5, 0)
  --@end-debug@

  self.pawnButton = GUI:CreatePanelButton (self.content, L["Import"], function(btn) self:ImportData() end)
  self.statWeightsCategory:AddFrame (self.pawnButton)
  self:SetAnchor (self.pawnButton, "TOPLEFT", self.presetsButton, "BOTTOMLEFT", 0, -5)

  local levelList = {
    {value=0,name=("%s (+%d)"):format(PVP, 0)},
  --@debug@
    {value=1,name=("%s (+%d)"):format("Normal", 1)},
  --@end-debug@
    {value=2,name=("%s (+%d)"):format(LFG_TYPE_HEROIC_DUNGEON, 2)},
    {value=3,name=("%s (+%d)"):format(LFG_TYPE_RAID, 3)}
  }

  self.targetLevel = GUI:CreateDropdown(self.content, levelList, {
    default =  self.pdb.targetLevel,
    setter = function(_,val) self.pdb.targetLevel = val; self:UpdateItems() end,
    width = 150,
  })
  self.statWeightsCategory:AddFrame(self.targetLevel)
  self.targetLevel.text = self.targetLevel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  self.targetLevel.text:SetText(STAT_TARGET_LEVEL)
  self:SetAnchor(self.targetLevel.text, "TOPLEFT", self.pawnButton, "BOTTOMLEFT", 0, -8)
  self.targetLevel:SetPoint("BOTTOMLEFT", self.targetLevel.text, "BOTTOMLEFT", self.targetLevel.text:GetStringWidth(), -20)

  self.buffsContextMenu = CreateFrame("DropdownButton", nil, self.content, "WowStyle1FilterDropdownTemplate")
  self.buffsContextMenu:SetText(L["Buffs"])
  self.buffsContextMenu.resizeToTextPadding = 25
  self.statWeightsCategory:AddFrame(self.buffsContextMenu)
  self:SetAnchor(self.buffsContextMenu, "TOPLEFT", self.targetLevel, "TOPRIGHT", 0 , 5)

  self.buffsContextMenu:SetupMenu(function(dropdown, rootDescription)
    local function IsSelected(value)
        return self.pdb[value]
    end
    local function SetSelected(value)
        self.pdb[value] = not self.pdb[value]
        for capIndex, cap in ipairs(self.pdb.caps) do
          for pointIndex, point in ipairs(cap.points) do
            local oldValue = point.value
            self:UpdateCapPreset(capIndex, pointIndex)
            if oldValue ~= point.value then
              self:ReorderCapPoint (capIndex, pointIndex)
            end
          end
        end
    end
    local buffsContextValues = {
      { text = CreateSimpleTextureMarkup(136092, 20, 20) .. " " .. L["Spell Haste"], key = "spellHaste"},
      { text = CreateSimpleTextureMarkup(133076, 20, 20) .. " " .. L["Melee Haste"], key = "meleeHaste"}
    }
    for _, box in ipairs(buffsContextValues) do
        rootDescription:CreateCheckbox(box.text, IsSelected, SetSelected, box.key)
    end
  end)

  self.statWeights = GUI:CreateTable (ceil (#self.itemStats / 2), 4)
  self:SetAnchor (self.statWeights, "TOPLEFT", self.targetLevel.text, "BOTTOMLEFT", 0, -8)
  self.statWeights:SetPoint ("RIGHT", -5, 0)
  self.statWeightsCategory:AddFrame (self.statWeights)
  self.statWeights:SetRowHeight (ITEM_SIZE + 2)

  self.statCaps = GUI:CreateTable (2, 4, nil, ITEM_SIZE + 2)
  self.statWeightsCategory:AddFrame (self.statCaps)
  self:SetAnchor (self.statCaps, "TOPLEFT", self.statWeights, "BOTTOMLEFT", 0, -10)
  self.statCaps:SetPoint ("RIGHT", -5, 0)
  self.statCaps:SetRowHeight (ITEM_SIZE + 2)
  self.statCaps:SetColumnWidth (1, 100)
  self.statCaps:SetColumnWidth (3, 50)
  self.statCaps:SetColumnWidth (4, 50)
  local statList = {{value = 0, name = NONE}}
  for i, v in ipairs (self.itemStats) do
    tinsert (statList, {value = i, name = v.long})
  end
  self.statCaps.ToggleStatDropdownToCorrectState = function(caps)
    for i = 2, #caps do
      if self.pdb.caps[i-1].stat == 0  then
        caps[i].stat:DisableDropdown()
      else
        caps[i].stat:EnableDropdown()
      end
    end
  end
  for i = 1, 2 do
    self.statCaps[i] = {}
    self.statCaps[i].stat = GUI:CreateDropdown (self.statCaps, statList, {
      default = self.pdb.caps[i].stat,
      setter = function (dropdown, val)
        if val == 0 then
          while #self.pdb.caps[i].points > 0 do
            self:RemoveCapPoint (i, 1)
          end
        elseif dropdown.value == 0 then
          self:AddCapPoint(i)
        end
        self.pdb.caps[i].stat = val
        if val == 0 then
          self:CollapseStatCaps()
        end
        self.statCaps:ToggleStatDropdownToCorrectState()
      end,
      width = 110,
      menuItemDisabled = function(val)
        return val > 0 and self.statCaps[3-i].stat.value == val
      end
    })
    self.statCaps[i].add = GUI:CreateImageButton (self.statCaps, 20, 20, "Interface\\Buttons\\UI-PlusButton-Up",
      "Interface\\Buttons\\UI-PlusButton-Down", "Interface\\Buttons\\UI-PlusButton-Hilight", "Interface\\Buttons\\UI-PlusButton-Disabled", function()
      self:AddCapPoint (i)
    end)
    GUI:SetTooltip (self.statCaps[i].add, L["Add cap"])
    self.statCaps:SetCell (i, 0, self.statCaps[i].stat, "LEFT", -20, -10)
    self.statCaps:SetCell (i, 2, self.statCaps[i].add, "LEFT")
  end
  for i = 1, 2 do
    for point in ipairs(self.pdb.caps[i].points) do
      self:AddCapPoint (i, point)
    end
    self:UpdateCapPoints (i)
    if self.pdb.caps[i].stat == 0 then
      self:RemoveCapPoint(i)
    end
  end
  self.statCaps:ToggleStatDropdownToCorrectState()
  self.statCaps.onUpdate = function ()
    local row = 1
    for i = 1, 2 do
      row = row + 1
      for point = 1, #self.pdb.caps[i].points do
        if self.statCaps.cells[row][2] and self.statCaps.cells[row][2].values then
          LibDD:UIDropDownMenu_SetWidth (self.statCaps.cells[row][2], self.statCaps:GetColumnWidth (2) - 20)
        end
        row = row + 1
      end
    end
  end
  self.statCaps.saveOnUpdate = self.statCaps.onUpdate
  self.statCaps.onUpdate ()
  RunNextFrame(function() self:CapUpdater() end)

  self.computeButton = GUI:CreatePanelButton (self.content, L["Compute"], function() self:StartCompute() end)
  self.computeButton:SetScript ("PreClick", function (btn)
    GUI:Lock()
    GUI:ClearFocus()
    btn:RenderText(IN_PROGRESS)
  end)

  self:UpdateStatWeightList ()

  self.quality = CreateFrame ("Slider", nil, self.content, "UISliderTemplateWithLabels")
  self:SetAnchor (self.quality, "LEFT", self.computeButton, "RIGHT", 10, 0)
  self.quality:SetSize(150, 15)
  self.quality:SetMinMaxValues (MIN_LOOPS, addonTable.MAX_LOOPS)
  self.quality:SetValueStep ((addonTable.MAX_LOOPS - MIN_LOOPS) / 20)
  self.quality:SetObeyStepOnDrag(true)
  self.quality:SetValue (self.db.speed)
  self.quality:EnableMouseWheel (false)
  self.quality:SetScript ("OnValueChanged", function (slider)
    self.db.speed = slider:GetValue ()
  end)

  self.quality.Text:SetText (SPEED)
  self.quality.Low:SetText (SLOW)
  self.quality.High:SetText (FAST)

  self.quality.helpButton = CreateFrame("Button",nil,self.quality,"MainHelpPlateButton")
  self.quality.helpButton:SetPoint("BOTTOMLEFT",self.quality.Text, "BOTTOMRIGHT",0,-20)
  self.quality.helpButton:SetScale(0.45)
  GUI:SetTooltip(self.quality.helpButton, L["Slide to the left if the calculation slows your game too much."])

  self.settingsCategory = self:CreateCategory (SETTINGS)
  self:SetAnchor (self.settingsCategory, "TOPLEFT", self.computeButton, "BOTTOMLEFT", 0, -10)
  self.settings = GUI:CreateTable (6, 1, nil, 200)
  self.settingsCategory:AddFrame (self.settings)
  self:SetAnchor (self.settings, "TOPLEFT", self.settingsCategory, "BOTTOMLEFT", 0, -5)
  self.settings:SetPoint ("RIGHT", self.content, -10, 0)
  self.settings:SetRowHeight (ITEM_SIZE + 2)

  self:FillSettings()

  self.lastElement = CreateFrame ("Frame", nil, self.content)
  self.lastElement:ClearAllPoints ()
  self.lastElement:SetSize(0, 0)
  self:SetAnchor (self.lastElement, "TOPLEFT", self.settings, "BOTTOMLEFT", 0, -10)
  self:UpdateContentSize ()

  if self.pdb.method then
    ReforgeLite:UpdateMethodCategory ()
  end
end
function ReforgeLite:GetFrameOrder()
  if self.methodWindow and self.methodWindow:IsShown() and self.methodWindow:GetFrameLevel () > self:GetFrameLevel() then
    return self.methodWindow, self
  end
  return self, self.methodWindow
end

function ReforgeLite:FillSettings()
  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton (self.settings, L["Open window when reforging"],
    self.db.openOnReforge, function (val) self.db.openOnReforge = val end), "LEFT")

  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton (self.settings, L["Summarize reforged stats"],
    self.db.updateTooltip,
    function (val)
      self.db.updateTooltip = val
      if val then
        self:HookTooltipScripts()
      end
    end),
    "LEFT")

  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton (self.settings, L["Enable spec profiles"],
    self.db.specProfiles, function (val)
      self.db.specProfiles = val
      if val then
        self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
      else
        self.pdb.prevSpecSettings = nil
        self:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
      end
    end),
    "LEFT")

  local activeWindowTitleOrderId = getOrderId('settings')
  self.settings:SetCellText (activeWindowTitleOrderId, 0, L["Active window color"], "LEFT", nil, "GameFontNormal")
  self.settings:SetCell (activeWindowTitleOrderId, 1, GUI:CreateColorPicker (self.settings, 20, 20, self.db.activeWindowTitle, function ()
    self:GetFrameOrder():SetFrameActive(true)
  end), "LEFT")

  local inactiveWindowTitleOrderId = getOrderId('settings')
  self.settings:SetCellText (inactiveWindowTitleOrderId, 0, L["Inactive window color"], "LEFT", nil, "GameFontNormal")
  self.settings:SetCell (inactiveWindowTitleOrderId, 1, GUI:CreateColorPicker (self.settings, 20, 20, self.db.inactiveWindowTitle, function ()
    local _, inactiveWindow = self:GetFrameOrder()
    if inactiveWindow then
      inactiveWindow:SetFrameActive(false)
    end
  end), "LEFT")

  self.debugButton = GUI:CreatePanelButton (self.settings, L["Debug"], function(btn) self:DebugMethod () end)
  self.settings:SetCell (getOrderId('settings'), 0, self.debugButton, "LEFT")

--@debug@
  self.settings:AddRow()
  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton(
    self.settings,
    "Debug Mode",
    self.db.debug,
    function (val) self.db.debug = val or nil end
  ), "LEFT")
--@end-debug@
end

function ReforgeLite:UpdateMethodCategory()
  if self.methodCategory == nil then
    self.methodCategory = self:CreateCategory (L["Result"])
    self:SetAnchor (self.methodCategory, "TOPLEFT", self.computeButton, "BOTTOMLEFT", 0, -10)

    self.methodStats = GUI:CreateTable (#self.itemStats - 1, 2, ITEM_SIZE, 60, {0.5, 0.5, 0.5, 1})
    self.methodCategory:AddFrame (self.methodStats)
    self:SetAnchor (self.methodStats, "TOPLEFT", self.methodCategory, "BOTTOMLEFT", 0, -5)
    self.methodStats:SetRowHeight (ITEM_SIZE + 2)
    self.methodStats:SetColumnWidth (60)

    for i, v in ipairs (self.itemStats) do
      self.methodStats:SetCellText (i - 1, 0, v.tip, "LEFT")

      self.methodStats[i] = {}

      self.methodStats[i].value = self.methodStats:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
      self.methodStats:SetCell (i - 1, 1, self.methodStats[i].value)
      self.methodStats[i].value:SetTextColor (1, 1, 1)
      self.methodStats[i].value:SetText ("0")

      self.methodStats[i].delta = self.methodStats:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
      self.methodStats:SetCell (i - 1, 2, self.methodStats[i].delta)
      self.methodStats[i].delta:SetTextColor (0.7, 0.7, 0.7)
      self.methodStats[i].delta:SetText ("+0")
    end

    self.methodShow = GUI:CreatePanelButton (self.content, SHOW, function(btn) self:ShowMethodWindow() end)
    self.methodShow:SetSize(85, 22)
    self.methodCategory:AddFrame (self.methodShow)
    self:SetAnchor (self.methodShow, "TOPLEFT", self.methodStats, "BOTTOMLEFT", 0, -5)

    self.methodReset = GUI:CreatePanelButton (self.content, RESET, function(btn) self:ResetMethod() end)
    self.methodReset:SetSize(85, 22)
    self.methodCategory:AddFrame (self.methodReset)
    self:SetAnchor (self.methodReset, "BOTTOMLEFT", self.methodShow, "BOTTOMRIGHT", 8, 0)

    self:SetAnchor (self.settingsCategory, "TOPLEFT", self.methodShow, "BOTTOMLEFT", 0, -10)
  end

  self:RefreshMethodStats()

  self:RefreshMethodWindow()
  self:UpdateContentSize ()
end
function ReforgeLite:RefreshMethodStats()
  if self.pdb.method then
    self:UpdateMethodStats (self.pdb.method)
  end
  if self.pdb.method then
    if self.methodStats then
      for i, v in ipairs (self.itemStats) do
        local mvalue = v.mgetter (self.pdb.method)
        if v.percent then
          self.methodStats[i].value:SetFormattedText("%.2f%%", mvalue)
        else
          self.methodStats[i].value:SetText (mvalue)
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

local reforgeIdStringCache = setmetatable({}, {
  __index = function(self, key)
    local _, itemOptions = GetItemInfoFromHyperlink(key)
    if not itemOptions then return false end
    local reforgeId = select(10, LinkUtil.SplitLinkOptions(itemOptions))
    reforgeId = tonumber(reforgeId)
    if not reforgeId then
      reforgeId = UNFORGE_INDEX
    else
      reforgeId = reforgeId - REFORGE_TABLE_BASE
    end
    rawset(self, key, reforgeId)
    return reforgeId
  end
})

local function GetReforgeIDFromString(item)
  local id = reforgeIdStringCache[item]
  if id and id ~= UNFORGE_INDEX then
    return id
  end
end

local function GetReforgeID(slotId)
  if ignoredSlots[slotId] then return end
  return GetReforgeIDFromString(GetInventoryItemLink('player', slotId))
end

function ReforgeLite:UpdateItems()
  for _, v in ipairs (self.itemData) do
    local item = Item:CreateFromEquipmentSlot(v.slotId)
    local stats = {}
    local reforgeSrc, reforgeDst
    if not item:IsItemEmpty() then
      v.item = item:GetItemLink()
      v.itemId = item:GetItemID()
      v.ilvl = item:GetCurrentItemLevel()
      v.itemGUID = item:GetItemGUID()
      v.texture:SetTexture(item:GetItemIcon())
      v.qualityColor = item:GetItemQualityColor()
      v.quality:SetVertexColor(v.qualityColor.r, v.qualityColor.g, v.qualityColor.b)
      v.quality:Show()
      stats = GetItemStats(v.item, self.pdb.ilvlCap)
      v.reforge = GetReforgeID(v.slotId)
      if v.reforge then
        local srcId, dstId = unpack(reforgeTable[v.reforge])
        reforgeSrc, reforgeDst = self.itemStats[srcId].name, self.itemStats[dstId].name
        local amount = floor ((stats[reforgeSrc] or 0) * 0.4)
        stats[reforgeSrc] = (stats[reforgeSrc] or 0) - amount
        stats[reforgeDst] = (stats[reforgeDst] or 0) + amount
      end
    else
      v.item = nil
      v.itemId = nil
      v.ilvl = nil
      v.reforge = nil
      v.itemGUID = nil
      v.qualityColor = nil
      v.texture:SetTexture (v.slotTexture)
      v.quality:SetVertexColor(1,1,1)
      v.quality:Hide()
    end
    if self.pdb.itemsLocked[v.itemGUID] then
      v.locked:Show()
    else
      v.locked:Hide()
    end
    for j, s in ipairs (self.itemStats) do
      if stats[s.name] and stats[s.name] ~= 0 then
        v.stats[j]:SetText (stats[s.name])
        if s.name == reforgeSrc then
          v.stats[j]:SetTextColor (1, 0.4, 0.4)
        elseif s.name == reforgeDst then
          v.stats[j]:SetTextColor (0.6, 1, 0.6)
        else
          v.stats[j]:SetTextColor (1, 1, 1)
        end
      else
        v.stats[j]:SetText ("-")
        v.stats[j]:SetTextColor (0.8, 0.8, 0.8)
      end
    end
  end
  for i, v in ipairs (self.itemStats) do
    self.statTotals[i]:SetText(v.getter())
  end

  for capIndex, cap in ipairs(self.pdb.caps) do
    for pointIndex, point in ipairs(cap.points) do
      local oldValue = point.value
      self:UpdateCapPreset (capIndex, pointIndex)
      if oldValue ~= point.value then
        self:ReorderCapPoint (capIndex, pointIndex)
      end
    end
  end
  self.itemLevel:SetFormattedText(CHARACTER_LINK_ITEM_LEVEL_TOOLTIP, select(2,GetAverageItemLevel()))
  self:RefreshMethodStats()
end

function ReforgeLite:UpdatePlayerSpecInfo()
  if not self.playerSpecTexture then return end
  local _, specName, _, icon = C_SpecializationInfo.GetSpecializationInfo(C_SpecializationInfo.GetSpecialization())
  if specName == "" then
    specName, icon = NONE, 132222
  end
  self.playerSpecTexture:SetTexture(icon)
  local activeSpecGroup = C_SpecializationInfo.GetActiveSpecGroup()
  for tier = 1, MAX_NUM_TALENT_TIERS do
    self.playerTalents[tier]:Show()
    local tierAvailable, selectedTalentColumn = GetTalentTierInfo(tier, activeSpecGroup, false, "player")
    if tierAvailable then
      if selectedTalentColumn > 0 then
        local talentInfo = C_SpecializationInfo.GetTalentInfo({
          tier = tier,
          column = selectedTalentColumn,
          groupIndex = activeSpecGroup,
          target = 'player'
        })
        self.playerTalents[tier]:SetTexture(talentInfo.icon)
        self.playerTalents[tier]:SetScript("OnEnter", function(f)
          GameTooltip:SetOwner(f, "ANCHOR_LEFT")
          GameTooltip:SetTalent(talentInfo.talentID, false, false, activeSpecGroup)
          GameTooltip:Show()
        end)
      else
        self.playerTalents[tier]:SetTexture(132222)
        self.playerTalents[tier]:SetScript("OnEnter", nil)
      end
    else
      self.playerTalents[tier]:Hide()
    end
  end
end

local queueUpdateEvents = {
  ["COMBAT_RATING_UPDATE"] = true,
  ["MASTERY_UPDATE"] = true,
  ["PLAYER_EQUIPMENT_CHANGED"] = true,
  ["FORGE_MASTER_ITEM_CHANGED"] = true,
}

function ReforgeLite:QueueUpdate()
  if not self:GetFrameOrder():IsShown() then return end
  local time = GetTime()
  if self.lastRan == time then return end
  self.lastRan = time
  RunNextFrame(function() self:UpdateItems() end)
  if self.methodWindow then
    RunNextFrame(function() self:UpdateMethodChecks() end)
  end
end

--------------------------------------------------------------------------

function ReforgeLite:CreateMethodWindow()
  self.methodWindow = CreateFrame ("Frame", "ReforgeLiteMethodWindow", UIParent, "BackdropTemplate")
  self.methodWindow:SetFrameStrata ("DIALOG")
  self.methodWindow:ClearAllPoints ()
  self.methodWindow:SetSize(250, 480)
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
    self:SwapFrameLevels(window)
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
  self.methodWindow.title:SetText (addonTitle.." Output")
  self.methodWindow.title:SetTextColor (1, 1, 1)
  self.methodWindow.title:SetPoint ("TOPLEFT", 12, self.methodWindow.title:GetHeight()-self.methodWindow.titlebar:GetHeight())

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
    self:RefreshMethodWindow()
  end)
  self:SetFrameActive(false)

  self.methodWindow.itemTable = GUI:CreateTable (#self.itemSlots + 1, 3, 0, 0, nil, self.methodWindow)
  self.methodWindow:ClearAllPoints ()
  self.methodWindow.itemTable:SetPoint ("TOPLEFT", 12, -28)
  self.methodWindow.itemTable:SetRowHeight (26)
  self.methodWindow.itemTable:SetColumnWidth (1, ITEM_SIZE)
  self.methodWindow.itemTable:SetColumnWidth (2, ITEM_SIZE + 2)
  self.methodWindow.itemTable:SetColumnWidth (3, 274 - ITEM_SIZE * 2)

  self.methodOverride = {}
  for i = 1, #self.itemSlots do
    self.methodOverride[i] = 0
  end

  self.methodWindow.items = {}
  for i, v in ipairs (self.itemSlots) do
    self.methodWindow.items[i] = CreateFrame ("Frame", nil, self.methodWindow.itemTable)
    self.methodWindow.items[i].slot = v
    self.methodWindow.items[i]:ClearAllPoints ()
    self.methodWindow.items[i]:SetSize(ITEM_SIZE, ITEM_SIZE)
    self.methodWindow.itemTable:SetCell (i, 2, self.methodWindow.items[i])
    self.methodWindow.items[i]:EnableMouse (true)
    self.methodWindow.items[i]:RegisterForDrag("LeftButton")
    self.methodWindow.items[i]:SetScript ("OnEnter", function (itemSlot)
      GameTooltip:SetOwner(itemSlot, "ANCHOR_LEFT")
      if itemSlot.item then
        GameTooltip:SetInventoryItem("player", itemSlot.slotId)
      else
        GameTooltip:SetText(_G[itemSlot.slot:upper()])
      end
      GameTooltip:Show()
    end)
    self.methodWindow.items[i]:SetScript ("OnLeave", GameTooltip_Hide)
    self.methodWindow.items[i]:SetScript ("OnDragStart", function (itemSlot)
      if itemSlot.item and ReforgeFrameIsVisible() then
        PickupInventoryItem(itemSlot.slotId)
      end
    end)
    self.methodWindow.items[i].slotId, self.methodWindow.items[i].slotTexture = GetInventorySlotInfo(v)
    self.methodWindow.items[i].texture = self.methodWindow.items[i]:CreateTexture (nil, "OVERLAY")
    self.methodWindow.items[i].texture:SetAllPoints (self.methodWindow.items[i])
    self.methodWindow.items[i].texture:SetTexture (self.methodWindow.items[i].slotTexture)

    self.methodWindow.items[i].quality = self.methodWindow.items[i]:CreateTexture(nil, "OVERLAY")
    self.methodWindow.items[i].quality:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    self.methodWindow.items[i].quality:SetBlendMode("ADD")
    self.methodWindow.items[i].quality:SetAlpha(0.75)
    self.methodWindow.items[i].quality:SetSize(44,44)
    self.methodWindow.items[i].quality:SetPoint("CENTER", self.methodWindow.items[i])

    self.methodWindow.items[i].reforge = self.methodWindow.itemTable:CreateFontString (nil, "OVERLAY", "GameFontNormal")
    self.methodWindow.itemTable:SetCell (i, 3, self.methodWindow.items[i].reforge, "LEFT")
    self.methodWindow.items[i].reforge:SetTextColor (1, 1, 1)
    self.methodWindow.items[i].reforge:SetText ("")

    self.methodWindow.items[i].check = GUI:CreateCheckButton (self.methodWindow.itemTable, "", false,
      function (val) self.methodOverride[i] = (val and 1 or -1) self:UpdateMethodChecks () end, true)
    self.methodWindow.itemTable:SetCell (i, 1, self.methodWindow.items[i].check)
  end
  self.methodWindow.reforge = GUI:CreatePanelButton (self.methodWindow, REFORGE, function(btn) self:DoReforge() end)
  self.methodWindow.reforge:SetSize(114, 22)
  self.methodWindow.reforge:SetPoint ("BOTTOMLEFT", 12, 12)
  self.methodWindow.reforgeTip = CreateFrame ("Frame", nil, self.methodWindow)
  self.methodWindow.reforgeTip:SetAllPoints (self.methodWindow.reforge)
  self.methodWindow.reforgeTip:EnableMouse (true)
  GUI:SetTooltip (self.methodWindow.reforgeTip, L["Reforging window must be open"])
  self.methodWindow.reforgeTip:SetFrameLevel (self.methodWindow.reforge:GetFrameLevel () + 5)
  self.methodWindow.reforgeTip:Hide ()

  self.methodWindow.cost = CreateFrame ("Frame", "ReforgeLiteReforgeCost", self.methodWindow, "SmallMoneyFrameTemplate")
  MoneyFrame_SetType (self.methodWindow.cost, "REFORGE")
  self.methodWindow.cost:SetPoint ("LEFT", self.methodWindow.reforge, "RIGHT", 5, 0)
  self:RefreshMethodWindow()
end

function ReforgeLite:RefreshMethodWindow()
  if not self.methodWindow then
    return
  end
  for i = 1, #self.itemSlots do
    self.methodOverride[i] = 0
  end

  for i, v in ipairs (self.methodWindow.items) do
    local item = Item:CreateFromEquipmentSlot(v.slotId)
    if not item:IsItemEmpty() then
      v.item = item:GetItemLink()
      v.texture:SetTexture(item:GetItemIcon())
      v.qualityColor = item:GetItemQualityColor()
      v.quality:SetVertexColor(v.qualityColor.r, v.qualityColor.g, v.qualityColor.b)
      v.quality:Show()
    else
      v.item = nil
      v.texture:SetTexture (v.slotTexture)
      v.qualityColor = nil
      v.quality:SetVertexColor(1,1,1)
      v.quality:Hide()
    end
    local slotInfo = self.pdb.method.items[i]
    if slotInfo.reforge then
      v.reforge:SetFormattedText("%d %s > %s", slotInfo.amount, self.itemStats[slotInfo.src].long, self.itemStats[slotInfo.dst].long)
      v.reforge:SetTextColor (1, 1, 1)
    else
      v.reforge:SetText (L["No reforge"])
      v.reforge:SetTextColor (0.7, 0.7, 0.7)
    end
  end
  self:UpdateMethodChecks ()
end

function ReforgeLite:ShowMethodWindow()
  if not self.methodWindow then
    self:CreateMethodWindow()
  end

  self.methodWindow:SetFrameLevel(self:GetFrameLevel() + 10)

  GUI:ClearFocus()
  self.methodWindow:Show()
end

local function IsReforgeMatching (slotId, reforge, override)
  return override == 1 or reforge == GetReforgeID(slotId)
end

function ReforgeLite:UpdateMethodChecks ()
  if self.methodWindow and self.pdb.method then
    local cost = 0
    local anyDiffer = false
    for i, v in ipairs (self.methodWindow.items) do
      local item = Item:CreateFromEquipmentSlot(v.slotId)
      v.item = item:GetItemLink()
      v.texture:SetTexture (item:GetItemIcon() or v.slotTexture)
      if item:IsItemEmpty() or IsReforgeMatching(v.slotId, self.pdb.method.items[i].reforge, self.methodOverride[i]) then
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

function ReforgeLite:SwapSpecProfiles()
  if not self.db.specProfiles then return end

  local currentSettings = {
    caps = DeepCopy(self.pdb.caps),
    weights = DeepCopy(self.pdb.weights),
  }

  if self.pdb.prevSpecSettings then
    if self.initialized then
      self:SetStatWeights(self.pdb.prevSpecSettings.weights, self.pdb.prevSpecSettings.caps or {})
    else
      self.pdb.weights = DeepCopy(self.pdb.prevSpecSettings.weights)
      self.pdb.caps = DeepCopy(self.pdb.prevSpecSettings.caps)
    end
  end

  self.pdb.prevSpecSettings = currentSettings
end

--------------------------------------------------------------------------

local function ClearReforgeWindow()
  ClearCursor()
  C_Reforge.SetReforgeFromCursorItem ()
  ClearCursor()
end

local reforgeCo

function ReforgeLite:DoReforge()
  if self.pdb.method and self.methodWindow and ReforgeFrameIsVisible() then
    if reforgeCo then
      self:StopReforging()
    else
      ClearReforgeWindow()
      self.methodWindow.reforge:SetText (CANCEL)
      reforgeCo = coroutine.create( function() self:DoReforgeUpdate() end )
      coroutine.resume(reforgeCo)
    end
  end
end

function ReforgeLite:StopReforging()
  if reforgeCo then
    reforgeCo = nil
    ClearReforgeWindow()
    collectgarbage()
  end
  if self.methodWindow then
    self.methodWindow.reforge:SetText(REFORGE)
  end
end

function ReforgeLite:ContinueReforge()
  if not (self.pdb.method and self.methodWindow and self.methodWindow:IsShown() and ReforgeFrameIsVisible()) then
    self:StopReforging()
    return
  end
  if reforgeCo then
    coroutine.resume(reforgeCo)
  end
end

function ReforgeLite:DoReforgeUpdate()
  if self.methodWindow then
    for slotId, slotInfo in ipairs(self.methodWindow.items) do
      local newReforge = self.pdb.method.items[slotId].reforge
      if slotInfo.item and not IsReforgeMatching(slotInfo.slotId, newReforge, self.methodOverride[slotId]) then
        PickupInventoryItem(slotInfo.slotId)
        C_Reforge.SetReforgeFromCursorItem()
        if newReforge then
          local id = UNFORGE_INDEX
          local stats = GetItemStats (slotInfo.item, self.pdb.ilvlCap)
          for s, reforgeInfo in ipairs(reforgeTable) do
            local srcstat, dststat = unpack(reforgeInfo)
            if (stats[self.itemStats[srcstat].name] or 0) ~= 0 and (stats[self.itemStats[dststat].name] or 0) == 0 then
              id = id + 1
            end
            if srcstat == self.pdb.method.items[slotId].src and dststat == self.pdb.method.items[slotId].dst then
              C_Reforge.ReforgeItem (id)
              coroutine.yield()
            end
          end
        elseif GetReforgeID(slotInfo.slotId) then
          C_Reforge.ReforgeItem (UNFORGE_INDEX)
          coroutine.yield()
        end
      end
    end
  end
  self:StopReforging()
end

--------------------------------------------------------------------------

local function HandleTooltipUpdate(tip)
  if not ReforgeLite.db.updateTooltip then return end
  local _, item = tip:GetItem()
  if not item then return end
  local reforgeId = GetReforgeIDFromString(item)
  if not reforgeId then return end
  for _, region in pairs({tip:GetRegions()}) do
    if region:GetObjectType() == "FontString" and region:GetText() == REFORGED then
      local srcId, destId = unpack(reforgeTable[reforgeId])
      region:SetFormattedText("%s (%s > %s)", REFORGED, ReforgeLite.itemStats[srcId].long, ReforgeLite.itemStats[destId].long)
      return
    end
  end
end

function ReforgeLite:HookTooltipScripts()
  if self.tooltipsHooked then return end
  local tooltips = {
    "GameTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ItemRefTooltip",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
  }
  for _, tooltipName in ipairs(tooltips) do
    local tooltip = _G[tooltipName]
    if tooltip then
      tooltip:HookScript("OnTooltipSetItem", HandleTooltipUpdate)
    end
  end
  self.tooltipsHooked = true
end

--------------------------------------------------------------------------

function ReforgeLite:FORGE_MASTER_ITEM_CHANGED()
  self:ContinueReforge()
end

function ReforgeLite:FORGE_MASTER_OPENED()
  if self.db.openOnReforge and not self:IsShown() and (not self.methodWindow or not self.methodWindow:IsShown()) then
    self.autoOpened = true
    self:Show()
  end
  if self.methodWindow then
    self:RefreshMethodWindow()
  end
  self:StopReforging()
end

function ReforgeLite:FORGE_MASTER_CLOSED()
  if self.autoOpened then
    self:Hide()
    if self.methodWindow then
      self.methodWindow:Hide()
    end
    self.autoOpened = nil
  end
  self:StopReforging()
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
  self:SwapFrameLevels()
  self:UpdateItems()
end

function ReforgeLite:OnHide()
  self:SwapFrameLevels(self.methodWindow)
end

function ReforgeLite:OnCommand (cmd)
  if InCombatLockdown() then print(ERROR_CAPS, ERR_AFFECTING_COMBAT) return end
  self:Show ()
end

function ReforgeLite:PLAYER_REGEN_DISABLED()
  if self.methodWindow then
    self.methodWindow:Hide()
  end
  self:Hide()
end

local currentSpec -- hack because this event likes to fire twice
function ReforgeLite:ACTIVE_TALENT_GROUP_CHANGED(curr)
  if currentSpec ~= curr then
    currentSpec = curr
    self:SwapSpecProfiles()
  end
end

function ReforgeLite:PLAYER_SPECIALIZATION_CHANGED(unitId)
  if unitId == 'player' then
    self:GetConversion()
    self:UpdatePlayerSpecInfo()
  end
end

function ReforgeLite:PLAYER_ENTERING_WORLD()
  self:GetConversion()
end


function ReforgeLite:ADDON_LOADED (addon)
  if addon ~= addonName then return end
  self:Hide()
  self:UpgradeDB()

  local db = LibStub("AceDB-3.0"):New(addonName.."DB", DefaultDB)

  self.db = db.global
  self.pdb = db.char
  self.cdb = db.class

  while #self.pdb.caps > #DefaultDB.char.caps do
    tremove(self.pdb.caps)
  end

  self.conversion = {}

  if self.db.updateTooltip then
    self:HookTooltipScripts()
  end
  self:RegisterEvent("FORGE_MASTER_OPENED")
  self:RegisterEvent("FORGE_MASTER_CLOSED")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  if self.db.specProfiles then
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
  end

  for event in pairs(queueUpdateEvents) do
    self:RegisterEvent(event)
  end
  self:UnregisterEvent("ADDON_LOADED")

  self:SetScript("OnShow", self.OnShow)
  self:SetScript("OnHide", self.OnHide)

  for k, v in ipairs({ addonName, "reforge", REFORGE:lower(), "rfl" }) do
    _G["SLASH_"..addonName:upper()..k] = "/" .. v
  end
  SlashCmdList[addonName:upper()] = function(...) self:OnCommand(...) end
end

ReforgeLite:SetScript ("OnEvent", ReforgeLite.OnEvent)
ReforgeLite:RegisterEvent ("ADDON_LOADED")
