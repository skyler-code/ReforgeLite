local addonName, addonTable = ...
local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "title")

local ReforgeLite = CreateFrame("Frame", addonName, UIParent, "BackdropTemplate")
addonTable.ReforgeLite = ReforgeLite

local L = addonTable.L
local GUI = addonTable.GUI
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

local GetItemStats = addonTable.GetItemStatsUp

addonTable.printLog = {}
local function print(...)
    tinsert(addonTable.printLog, (" "):join(date("[%X]:"), tostringall(...)))
    getprinthandler()(TRANSMOGRIFY_FONT_COLOR:WrapTextInColorCode(addonName)..":",...)
end
addonTable.print = print

local ITEM_SLOTS = {
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
ReforgeLite.itemSlots = ITEM_SLOTS
local ITEM_SLOT_COUNT = #ITEM_SLOTS

local ignoredSlots = { [INVSLOT_TABARD] = true, [INVSLOT_BODY] = true }

local ITEM_SIZE = 24
addonTable.MAX_SPEED = 20

local DefaultDB = {
  global = {
    windowWidth = 800,
    windowHeight = 564,
    windowLocation = false,
    methodWindowLocation = false,
    openOnReforge = true,
    updateTooltip = false,
    accuracy = addonTable.MAX_SPEED,
    activeWindowTitle = {0.6, 0, 0},
    inactiveWindowTitle = {0.5, 0.5, 0.5},
    specProfiles = false,
    importButton = true,
  },
  char = {
    targetLevel = 3,
    ilvlCap = 0,
    meleeHaste = true,
    spellHaste = true,
    mastery = false,
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
    methodOrigin = addonName,
    itemsLocked = {},
    categoryStates = {},
  },
  class = {
    customPresets = {}
  },
}

local RFL_FRAMES = { ReforgeLite }
RFL_FRAMES.CloseAll = function(t)
  for _, frame in ipairs(t) do
    frame:Hide()
  end
end

local function ReforgingFrameIsVisible()
  return ReforgingFrame and ReforgingFrame:IsShown()
end

local PLAYER_ITEM_DATA = setmetatable({}, {
  __index = function(t, k)
    rawset(t, k, Item:CreateFromEquipmentSlot(k))
    return t[k]
  end
})
ReforgeLite.playerData = PLAYER_ITEM_DATA

addonTable.localeClass, addonTable.playerClass, addonTable.playerClassID = UnitClass("player")
local UNFORGE_INDEX = -1
addonTable.StatCapMethods = EnumUtil.MakeEnum("AtLeast", "AtMost", "NewValue", "Exactly")

function ReforgeLite:UpgradeDB()
  local db = ReforgeLiteDB
  if not db then return end
  if db.classProfiles then
    db.class = CopyTable(db.classProfiles)
    db.classProfiles = nil
  end
  if db.profiles then
    db.char = CopyTable(db.profiles)
    db.profiles = nil
  end
  if not db.global then
    db.global = {}
    for k, v in pairs(db) do
      local default = DefaultDB.global[k]
      if default ~= nil then
        if default ~= v then
          db.global[k] = CopyTable(v)
        end
        db[k] = nil
      end
    end
  end
end

-----------------------------------------------------------------

GUI.CreateStaticPopup("REFORGE_LITE_SAVE_PRESET", L["Enter the preset name"], { func = function(text)
  ReforgeLite.cdb.customPresets[text] = {
    caps = CopyTable(ReforgeLite.pdb.caps),
    weights = CopyTable(ReforgeLite.pdb.weights)
  }
  ReforgeLite:InitCustomPresets()
  ReforgeLite.deletePresetButton:ToggleStatus()
end })

local statIds = EnumUtil.MakeEnum("SPIRIT", "DODGE", "PARRY", "HIT", "CRIT", "HASTE", "EXP", "MASTERY", "SPELLHIT")
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

local StatAdditives = {
  [CR_HIT] = function(rating) return rating - GetFireSpirit() end,
  [CR_MASTERY] = function(rating)
    if ReforgeLite.pdb.mastery and not ReforgeLite:PlayerHasMasteryBuff() then
      rating = rating + (addonTable.MASTERY_BY_LEVEL[UnitLevel('player')] or 0)
    end
    return rating
  end
}

local function RatingStat (i, name_, tip_, long_, id_)
  return {
    name = name_,
    tip = tip_,
    long = long_,
    getter = function ()
      local rating = GetCombatRating(id_)
      if StatAdditives[id_] then
        rating = StatAdditives[id_](rating)
      end
      return rating
    end,
    mgetter = function (method, orig)
      return (orig and method.orig_stats and method.orig_stats[i]) or method.stats[i]
    end
  }
end

local ITEM_STATS = {
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
local ITEM_STAT_COUNT = #ITEM_STATS
addonTable.itemStats, addonTable.itemStatCount = ITEM_STATS, ITEM_STAT_COUNT

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

addonTable.WoWSimsOriginTag = "WoWSims"

local function IsItemSwapped(slot, wowsims)
  local SWAPPABLE_SLOTS = {
    [INVSLOT_FINGER1] = INVSLOT_FINGER2,
    [INVSLOT_FINGER2] = INVSLOT_FINGER1,
    [INVSLOT_TRINKET1] = INVSLOT_TRINKET2,
    [INVSLOT_TRINKET2] = INVSLOT_TRINKET1
  }
  local oppositeSlotId = SWAPPABLE_SLOTS[GetInventorySlotInfo(ITEM_SLOTS[slot])]
  if not oppositeSlotId then return end
  local slotItemId = (wowsims.player.equipment.items[slot] or {}).id or 0
  local oppositeSlotItemId = (wowsims.player.equipment.items[oppositeSlotId] or {}).id or 0
  if C_Item.IsEquippedItem(slotItemId) and C_Item.IsEquippedItem(oppositeSlotItemId) then
    return oppositeSlotId
  end
end

function ReforgeLite:ValidateWoWSimsString(importStr)
  local success, wowsims = pcall(function () return C_EncodingUtil.DeserializeJSON(importStr) end)
  if not success or type(wowsims) ~= "table" then return false, wowsims end
  if not (wowsims.player or {}).equipment then
    return false, L['This import is missing player equipment data! Please make sure "Gear" is selected when exporting from WoWSims.']
  end
  local newItems = CopyTable((self.pdb.method or self:InitializeMethod()).items)
  for slot, item in ipairs(newItems) do
    local simItemInfo = wowsims.player.equipment.items[slot] or {}
    if simItemInfo.id ~= self.itemData[slot].itemInfo.itemId then
      local swappedSlotId = IsItemSwapped(slot, wowsims)
      if swappedSlotId then
        simItemInfo = wowsims.player.equipment.items[swappedSlotId]
      else
        return false, { itemId = simItemInfo.id, slot = slot }
      end
    end
    if simItemInfo.reforging then
      item.src, item.dst = unpack(self.reforgeTable[simItemInfo.reforging - REFORGE_TABLE_BASE])
    else
      item.src, item.dst = nil, nil
    end
  end
  return true, newItems
end

function ReforgeLite:ApplyWoWSimsImport(newItems, attachToReforge)
  if not self.pdb.method then
    self.pdb.method = { items = newItems }
  else
    self.pdb.method.items = newItems
  end
  self.pdb.methodOrigin = addonTable.WoWSimsOriginTag
  self:FinalizeReforge(self.pdb)
  self:UpdateMethodCategory()
  self:ShowMethodWindow(attachToReforge)
end

--@debug@
addonTable.isDev = true
function ReforgeLite:ParsePresetString(presetStr)
  local success, preset = pcall(function () return C_EncodingUtil.DeserializeJSON(presetStr) end)
  if success and type(preset.caps) == "table" then
    DevTools_Dump(preset)
  end
end

function ReforgeLite:PreviewColors()
  for _, dbColor in ipairs(C_UIColor.GetColors()) do
    local color = _G[dbColor.baseTag]
    print(color:WrapTextInColorCode(string.join(", ", dbColor.baseTag, color:GetRGB())))
  end
end

--@end-debug@

function ReforgeLite:ValidatePawnString(importStr)
  local pos, _, version, name, values = strfind (importStr, "^%s*%(%s*Pawn%s*:%s*v(%d+)%s*:%s*\"([^\"]+)\"%s*:%s*(.+)%s*%)%s*$")
  version = tonumber (version)
  if version and version > 1 then return false end
  if not (pos and version and name and values) or name == "" or values == "" then
    return false
  end
  return true, values
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
  c.expanded = self.pdb.categoryStates[name] ~= 1
  c.name = c:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  c.catname = c.name
  c.name:SetPoint ("TOPLEFT", c, "TOPLEFT", 18, -1)
  c.name:SetTextColor(addonTable.FONTS.white:GetRGB())
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
    category.expanded = not category.expanded or nil
    self.pdb.categoryStates[name] = not category.expanded and 1 or nil
    for _, v in ipairs(category.frames) do
      v:SetShown(category.expanded and not v.chidden)
    end
    for _, v in ipairs(category.anchors) do
      v.frame:SetPoint(v.point, category.expanded and v.rel or category.button, v.relPoint, v.x, v.y)
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
    text:SetTextColor(addonTable.FONTS.grey:GetRGB())
  elseif override > 0 then
    text:SetTextColor(addonTable.FONTS.green:GetRGB())
  else
    text:SetTextColor(addonTable.FONTS.red:GetRGB())
  end
  text:SetFormattedText(value - cur > 0 and "+%s" or "%s", value - cur)
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

function ReforgeLite:SetNewTopWindow(newTopWindow)
  if not RFL_FRAMES[2] then return end
  newTopWindow = newTopWindow or self
  for _, frame in ipairs(RFL_FRAMES) do
    if frame == newTopWindow then
      frame:Raise()
      frame:SetFrameActive(true)
    else
      frame:Lower()
      frame:SetFrameActive(false)
    end
  end
end

function ReforgeLite:CreateFrame()
  self:InitPresets()
  self:SetFrameStrata ("DIALOG")
  self:ClearAllPoints ()
  self:SetToplevel(true)
  self:SetSize(self.db.windowWidth, self.db.windowHeight)
  self:SetResizeBounds(780, 500, 1000, 800)
  if self.db.windowLocation then
    self:SetPoint (SafeUnpack(self.db.windowLocation))
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
  self:SetBackdropColor(addonTable.FONTS.panel:GetRGB())
  self:SetBackdropBorderColor(addonTable.FONTS.panel:GetRGB())

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
    self:SetNewTopWindow()
    if arg == "LeftButton" then
      self:StartMoving ()
      self.moving = true
    end
  end)
  self:SetScript ("OnMouseUp", function (self)
    if self.moving then
      self:StopMovingOrSizing ()
      self.moving = false
      self.db.windowLocation = SafePack(self:GetPoint())
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
  self.title:SetTextColor (addonTable.FONTS.white:GetRGB())
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
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
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
    self.playerTalents[tier]:SetTexCoord(self.playerSpecTexture:GetTexCoord())
    self.playerTalents[tier]:SetScript("OnLeave", GameTooltip_Hide)
  end

  self:UpdatePlayerSpecInfo()

  self.itemTable = GUI:CreateTable (ITEM_SLOT_COUNT + 1, ITEM_STAT_COUNT, ITEM_SIZE, ITEM_SIZE + 4, {0.5, 0.5, 0.5, 1}, self)
  self.itemTable:SetPoint ("TOPLEFT", self.playerSpecTexture, "BOTTOMLEFT", 0, -6)
  self.itemTable:SetPoint ("BOTTOM", 0, 10)
  self.itemTable:SetWidth (400)

  self.itemLevel = self:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.itemLevel:SetPoint ("BOTTOMRIGHT", self.itemTable, "TOPRIGHT", 0, 8)
  self.itemLevel:SetTextColor(addonTable.FONTS.gold:GetRGB())
  self:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
  self:PLAYER_AVG_ITEM_LEVEL_UPDATE()

  self.itemLockHelpButton = CreateFrame("Button",nil, self,"MainHelpPlateButton")
  self.itemLockHelpButton:SetFrameLevel(self.itemLockHelpButton:GetParent():GetFrameLevel() + 1)
  self.itemLockHelpButton:SetScale(0.5)
  GUI:SetTooltip(self.itemLockHelpButton, L["The current state of your equipment.\nClicking an item icon will lock it. ReforgeLite will ignore the item(s) in future calculations."])

  self.itemTable:SetCell(0, 0, self.itemLockHelpButton, "TOPLEFT", -5, 10)

  for i, v in ipairs (ITEM_STATS) do
    self.itemTable:SetCellText (0, i, v.tip)
  end
  self.itemData = {}
  for i, v in ipairs (ITEM_SLOTS) do
    self.itemData[i] = CreateFrame("Frame", nil, self.itemTable)
    self.itemData[i].slot = v
    self.itemData[i]:ClearAllPoints()
    self.itemData[i]:SetSize(ITEM_SIZE, ITEM_SIZE)
    self.itemTable:SetCell(i, 0, self.itemData[i])
    self.itemData[i]:EnableMouse(true)
    self.itemData[i]:SetScript("OnEnter", function(frame)
      GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
      local hasItem = GameTooltip:SetInventoryItem("player", frame.slotId)
      if not hasItem then
        GameTooltip:SetText(_G[strupper(frame.slot)])
      end
      GameTooltip:Show()
    end)
    self.itemData[i]:SetScript ("OnLeave", GameTooltip_Hide)
    self.itemData[i]:SetScript ("OnMouseDown", function (frame)
      if not frame.itemInfo.itemGUID then return end
      self.pdb.itemsLocked[frame.itemInfo.itemGUID] = not self.pdb.itemsLocked[frame.itemInfo.itemGUID] and 1 or nil
      frame.locked:SetShown(self.pdb.itemsLocked[frame.itemInfo.itemGUID] ~= nil)
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
    self.itemData[i].itemInfo = {}
    self.itemData[i].stats = {}
    for j, s in ipairs (ITEM_STATS) do
      local statFontString = self.itemTable:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
      self.itemData[i].stats[j] = statFontString
      self.itemTable:SetCell (i, j, statFontString)
      statFontString.fontColors = { grey = addonTable.FONTS.lightgrey, red = addonTable.FONTS.red, green = addonTable.FONTS.green, white = addonTable.FONTS.white  }
      statFontString:SetTextColor(statFontString.fontColors.grey:GetRGB())
      statFontString:SetText ("-")
    end
  end
  self.statTotals = {}
  self.itemTable:SetCellText (ITEM_SLOT_COUNT + 1, 0, L["Sum"], "CENTER", {addonTable.FONTS.darkyellow:GetRGB()})
  for i, v in ipairs (ITEM_STATS) do
    self.statTotals[i] = self.itemTable:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
    self.itemTable:SetCell (ITEM_SLOT_COUNT + 1, i, self.statTotals[i])
    self.statTotals[i]:SetTextColor (addonTable.FONTS.darkyellow:GetRGB())
    self.statTotals[i]:SetText("0")
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
      rating = ("%s: %.2f%%\n%s: %.2f%%\n%s: %.2f%%"):format(MELEE, meleeHaste, RANGED, rangedHaste, STAT_CATEGORY_SPELL, spellHaste)
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
function ReforgeLite:RefreshCaps()
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
function ReforgeLite:CollapseStatCaps()
  local caps = CopyTable(self.pdb.caps)
  table.sort(caps, function(a,b)
    local aIsNone = a.stat == 0 and 1 or 0
    local bIsNone = b.stat == 0 and 1 or 0
    return aIsNone < bIsNone
  end)
  self:SetStatWeights(nil, caps)
end
function ReforgeLite:SetStatWeights (weights, caps)
  if weights then
    self.pdb.weights = CopyTable (weights)
    for i = 1, ITEM_STAT_COUNT do
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
        self.pdb.caps[i] = CopyTable (caps[i])
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
function ReforgeLite:UpdateStatWeightList ()
  local rows = ITEM_STAT_COUNT
  local extraRows = 0
  self.statWeights:ClearCells ()
  self.statWeights.inputs = {}
  rows = ceil(rows / 2) + extraRows
  while self.statWeights.rows > rows do
    self.statWeights:DeleteRow (1)
  end
  if self.statWeights.rows < rows then
    self.statWeights:AddRow (1, rows - self.statWeights.rows)
  end
  for i, v in ipairs (ITEM_STATS) do
    local col = floor ((i - 1) / (self.statWeights.rows - extraRows))
    local row = i - col * (self.statWeights.rows - extraRows) + extraRows
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
  self.deletePresetButton.ToggleStatus = function(btn)
    btn:SetEnabled(TableHasAnyEntries(self.cdb.customPresets))
  end
  self.deletePresetButton:ToggleStatus()

  --@debug@
  self.exportPresetButton = GUI:CreatePanelButton (self.content, L["Export"], function(btn)
    LibDD:ToggleDropDownMenu (nil, nil, self.exportPresetMenu, btn:GetName(), 0, 0)
  end)
  self.statWeightsCategory:AddFrame (self.exportPresetButton)
  self.exportPresetButton:SetPoint ("LEFT", self.deletePresetButton, "RIGHT", 5, 0)
  --@end-debug@

  self.pawnButton = GUI:CreatePanelButton (self.content, L["Import WoWSims/Pawn/QE"], function(btn) self:ImportData() end)
  self.statWeightsCategory:AddFrame (self.pawnButton)
  self:SetAnchor (self.pawnButton, "TOPLEFT", self.presetsButton, "BOTTOMLEFT", 0, -5)

  local levelList = function()
    return {
        {value=0,name=("%s (+%d)"):format(PVP, 0)},
        {value=1,name=("%d (+%d)"):format(UnitLevel('player') + 1, 1)},
        {value=2,name=("%s (+%d)"):format(LFG_TYPE_HEROIC_DUNGEON, 2)},
        {value=3,name=("%s %s (+%d)"):format(CreateSimpleTextureMarkup([[Interface\TargetingFrame\UI-TargetingFrame-Skull]], 16, 16), LFG_TYPE_RAID, 3)},
    }
  end

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

  local buffsContextValues = {
    spellHaste = { text = addonTable.CreateIconMarkup(136092) .. L["Spell Haste"], selected = self.PlayerHasSpellHasteBuff },
    meleeHaste = { text = addonTable.CreateIconMarkup(133076) .. L["Melee Haste"], selected = self.PlayerHasMeleeHasteBuff },
    mastery = { text = addonTable.CreateIconMarkup(136046) .. STAT_MASTERY, selected = self.PlayerHasMasteryBuff },
  }

  self.buffsContextMenu:SetupMenu(function(dropdown, rootDescription)
    local function IsSelected(value)
        return self.pdb[value] or buffsContextValues[value].selected(self)
    end
    local function SetSelected(value)
        self.pdb[value] = not self.pdb[value]
        self:QueueUpdate()
    end
    for key, box in pairs(buffsContextValues) do
        local checkbox = rootDescription:CreateCheckbox(box.text, IsSelected, SetSelected, key)
        checkbox.IsEnabled = function(chkbox) return not buffsContextValues[chkbox.data].selected(self) end
    end
  end)

  self.statWeights = GUI:CreateTable (ceil (ITEM_STAT_COUNT / 2), 4)
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
  for i, v in ipairs (ITEM_STATS) do
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
    addonTable.pauseRoutine = nil
    self.pauseButton:Enable()
    self.pauseButton:RenderText(KEY_PAUSE)
  end)

  self.pauseButton = GUI:CreatePanelButton (self.content, KEY_PAUSE, function(btn)
    if addonTable.pauseRoutine then
      addonTable.pauseRoutine = 'kill'
      self:EndCompute(addonTable.pauseRoutine)
    else
      addonTable.pauseRoutine = 'pause'
      btn:RenderText(CANCEL)
      self.computeButton:RenderText(CONTINUE)
      addonTable.GUI:UnlockFrame(self.computeButton)
    end
  end, {preventLock = true})
  self:SetAnchor (self.pauseButton, "LEFT", self.computeButton, "RIGHT", 4, 0)
  self.pauseButton:Disable()

  self:UpdateStatWeightList ()

  self.settingsCategory = self:CreateCategory (SETTINGS)
  self:SetAnchor (self.settingsCategory, "TOPLEFT", self.computeButton, "BOTTOMLEFT", 0, -10)
  self.settings = GUI:CreateTable (8, 1, nil, 200)
  self.settingsCategory:AddFrame (self.settings)
  self:SetAnchor (self.settings, "TOPLEFT", self.settingsCategory, "BOTTOMLEFT", 0, -10)
  self.settings:SetPoint ("RIGHT", self.content, -10, 0)
  self.settings:SetRowHeight (ITEM_SIZE + 2)

  self:FillSettings()

  self.lastElement = CreateFrame ("Frame", nil, self.content)
  self.lastElement:ClearAllPoints ()
  self.lastElement:SetSize(0, 0)
  self:SetAnchor (self.lastElement, "TOPLEFT", self.settings, "BOTTOMLEFT", 0, -10)
  self:UpdateContentSize ()

  if self.pdb.method then
    self:UpdateMethodCategory ()
  end
end

function ReforgeLite:GetActiveWindow()
  if not RFL_FRAMES[2] then
    return RFL_FRAMES[1]:IsShown() and RFL_FRAMES[1] or nil
  end
  local topWindow
  for _, frame in ipairs(RFL_FRAMES) do
    if frame:IsShown() and (not topWindow or frame:GetRaisedFrameLevel() > topWindow:GetRaisedFrameLevel()) then
      topWindow = frame
    end
  end
  return topWindow
end

function ReforgeLite:GetInactiveWindows()
  if(not RFL_FRAMES[2]) then
    return {}
  end
  local activeWindow = self:GetActiveWindow()
  local bottomWindows = {}
  for _, frame in ipairs(RFL_FRAMES) do
    if frame:IsShown() and frame:GetRaisedFrameLevel() < activeWindow:GetRaisedFrameLevel() then
      tinsert(bottomWindows, frame)
    end
  end
  return bottomWindows
end

function ReforgeLite:FillSettings()
  local accuracySlider = CreateFrame ("Slider", nil, self.settings, "UISliderTemplateWithLabels")
  accuracySlider:SetSize(150, 15)
  accuracySlider:SetMinMaxValues (1, addonTable.MAX_SPEED)
  accuracySlider:SetValueStep (1)
  accuracySlider:SetObeyStepOnDrag(true)
  accuracySlider:SetValue (self.db.accuracy)
  accuracySlider:EnableMouseWheel (false)
  accuracySlider:SetScript ("OnValueChanged", function (slider)
    self.db.accuracy = slider:GetValue ()
  end)
  accuracySlider.Text:SetText (L["Accuracy"])

  GUI:SetTooltip(accuracySlider, L["Setting to Low will result in lower accuracy but faster results! Set this back to High if you're not getting the results you expect."])

  self.settings:SetCell (getOrderId('settings'), 0, accuracySlider, "LEFT", 8)

  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton (self.settings, L["Open window when reforging"],
    self.db.openOnReforge, function (val) self.db.openOnReforge = val end), "LEFT")

  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton (self.settings, L["Summarize reforged stats on tooltip"],
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

  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton (self.settings, L["Show import button on Reforging window"],
    self.db.importButton, function (val)
      self.db.importButton = val
      if val then
        self:CreateImportButton()
      elseif self.importButton then
        self.importButton:Hide()
      end
    end),
    "LEFT")

  local activeWindowTitleOrderId = getOrderId('settings')
  self.settings:SetCellText (activeWindowTitleOrderId, 0, L["Active window color"], "LEFT", nil, "GameFontNormal")
  self.settings:SetCell (activeWindowTitleOrderId, 1, GUI:CreateColorPicker (self.settings, 20, 20, self.db.activeWindowTitle, function ()
    self:GetActiveWindow():SetFrameActive(true)
  end), "LEFT")

  local inactiveWindowTitleOrderId = getOrderId('settings')
  self.settings:SetCellText (inactiveWindowTitleOrderId, 0, L["Inactive window color"], "LEFT", nil, "GameFontNormal")
  self.settings:SetCell (inactiveWindowTitleOrderId, 1, GUI:CreateColorPicker (self.settings, 20, 20, self.db.inactiveWindowTitle, function ()
    for _, frame in ipairs(self:GetInactiveWindows()) do
      frame:SetFrameActive(false)
    end
  end), "LEFT")

  self.debugButton = GUI:CreatePanelButton (self.settings, L["Debug"], function(btn) self:DebugMethod () end)
  self.settings:SetCell (getOrderId('settings'), 0, self.debugButton, "LEFT")

--@debug@
  self.settings:AddRow()
  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreatePanelButton (self.settings, "Print Log", function(btn) self:PrintLog () end), "LEFT")

  self.settings:AddRow()
  self.settings:SetCell (getOrderId('settings'), 0, GUI:CreateCheckButton(
    self.settings,
    "Debug Mode",
    self.db.debug,
    function (val) self.db.debug = val or nil end
  ), "LEFT")
--@end-debug@
end

function ReforgeLite:CreateImportButton()
  if not self.db.importButton then return end
  if self.importButton then
    self.importButton:Show()
  else
    self.importButton = CreateFrame("Button", nil, ReforgingFrame.TitleContainer, "UIPanelButtonTemplate")
    self.importButton:SetPoint("TOPRIGHT")
    self.importButton:SetText(L["Import"])
    self.importButton.fitTextWidthPadding = 20
    self.importButton:FitToText()
    self.importButton:SetScript("OnClick", function(btn) self:ImportData(btn) end)
  end
end

function ReforgeLite:UpdateMethodCategory()
  if self.methodCategory == nil then
    self.methodCategory = self:CreateCategory (L["Result"])
    self:SetAnchor (self.methodCategory, "TOPLEFT", self.computeButton, "BOTTOMLEFT", 0, -10)

    self.methodStats = GUI:CreateTable (ITEM_STAT_COUNT - 1, 2, ITEM_SIZE, 60, {0.5, 0.5, 0.5, 1})
    self.methodCategory:AddFrame (self.methodStats)
    self:SetAnchor (self.methodStats, "TOPLEFT", self.methodCategory, "BOTTOMLEFT", 0, -5)
    self.methodStats:SetRowHeight (ITEM_SIZE + 2)
    self.methodStats:SetColumnWidth (60)

    for i, v in ipairs (ITEM_STATS) do
      self.methodStats:SetCellText (i - 1, 0, v.tip, "LEFT")

      self.methodStats[i] = {}

      self.methodStats[i].value = self.methodStats:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
      self.methodStats:SetCell (i - 1, 1, self.methodStats[i].value)
      self.methodStats[i].value:SetTextColor(addonTable.FONTS.white:GetRGB())
      self.methodStats[i].value:SetText ("0")

      self.methodStats[i].delta = self.methodStats:CreateFontString (nil, "OVERLAY", "GameFontNormalSmall")
      self.methodStats:SetCell (i - 1, 2, self.methodStats[i].delta)
      self.methodStats[i].delta:SetTextColor(addonTable.FONTS.grey:GetRGB())
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
      for i, v in ipairs (ITEM_STATS) do
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
  return GetReforgeIDFromString(PLAYER_ITEM_DATA[slotId]:GetItemLink())
end

local function GetItemUpgradeLevel(item)
    if item:IsItemEmpty()
    or not item:HasItemLocation()
    or item:GetItemQuality() < Enum.ItemQuality.Rare
    or item:GetCurrentItemLevel() < 458 then
        return 0
    end
    local originalIlvl = C_Item.GetDetailedItemLevelInfo(item:GetItemID())
    if not originalIlvl then
        return 0
    end

    return (item:GetCurrentItemLevel() - originalIlvl) / 4
end

function ReforgeLite:UpdateItems()
  for _, v in ipairs (self.itemData) do
    local item = self.playerData[v.slotId]
    local stats = {}
    local reforgeSrc, reforgeDst
    if item:IsItemEmpty() then
      wipe(v.itemInfo)
      v.texture:SetTexture(v.slotTexture)
      v.quality:SetVertexColor(addonTable.FONTS.white:GetRGB())
    else
      v.itemInfo = {
        link = item:GetItemLink(),
        itemId = item:GetItemID(),
        ilvl = item:GetCurrentItemLevel(),
        itemGUID = item:GetItemGUID(),
        upgradeLevel = GetItemUpgradeLevel(item),
        reforge = GetReforgeID(v.slotId)
      }
      v.texture:SetTexture(item:GetItemIcon())
      v.quality:SetVertexColor(item:GetItemQualityColor().color:GetRGB())
      stats = GetItemStats(v.itemInfo.link, v.itemInfo.upgradeLevel)
      if v.itemInfo.reforge then
        local srcId, dstId = unpack(reforgeTable[v.itemInfo.reforge])
        reforgeSrc, reforgeDst = ITEM_STATS[srcId].name, ITEM_STATS[dstId].name
        local amount = floor ((stats[reforgeSrc] or 0) * addonTable.REFORGE_COEFF)
        stats[reforgeSrc] = (stats[reforgeSrc] or 0) - amount
        stats[reforgeDst] = (stats[reforgeDst] or 0) + amount
      end
    end
    v.quality:SetShown(not item:IsItemEmpty())
    v.locked:SetShown(self.pdb.itemsLocked[v.itemInfo.itemGUID])
    for j, s in ipairs (ITEM_STATS) do
      if stats[s.name] and stats[s.name] ~= 0 then
        v.stats[j]:SetText (stats[s.name])
        if s.name == reforgeSrc then
          v.stats[j]:SetTextColor(v.stats[j].fontColors.red:GetRGB())
          
        elseif s.name == reforgeDst then
          v.stats[j]:SetTextColor(v.stats[j].fontColors.green:GetRGB())
        else
          v.stats[j]:SetTextColor(v.stats[j].fontColors.white:GetRGB())
        end
      else
        v.stats[j]:SetText("-")
        v.stats[j]:SetTextColor(v.stats[j].fontColors.grey:GetRGB())
      end
    end
  end
  for i, v in ipairs (ITEM_STATS) do
    self.statTotals[i]:SetText(v.getter())
  end

  self:RefreshCaps()
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
    local tierAvailable, selectedTalentColumn = GetTalentTierInfo(tier, activeSpecGroup, false, "player")
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
    self.playerTalents[tier]:SetShown(tierAvailable)
  end
end

local queueUpdateEvents = {
  COMBAT_RATING_UPDATE = true,
  MASTERY_UPDATE = true,
  PLAYER_EQUIPMENT_CHANGED = true,
  FORGE_MASTER_ITEM_CHANGED = true,
  UNIT_AURA = "player",
  UNIT_SPELL_HASTE = "player",
}

local queueEventsRegistered = false
function ReforgeLite:RegisterQueueUpdateEvents()
  if queueEventsRegistered then return end
  for event, unitID in pairs(queueUpdateEvents) do
    if unitID == true then
      self:RegisterEvent(event)
    else
      self:RegisterUnitEvent(event, unitID)
    end
  end
  queueEventsRegistered = true
end

function ReforgeLite:UnregisterQueueUpdateEvents()
  if not queueEventsRegistered then return end
  for event in pairs(queueUpdateEvents) do
    self:UnregisterEvent(event)
  end
  queueEventsRegistered = false
end

function ReforgeLite:QueueUpdate()
  local time = GetTime()
  if self.lastRan == time then return end
  self.lastRan = time
  RunNextFrame(function()
    self:UpdateItems()
    self:RefreshMethodWindow()
  end)
end

--------------------------------------------------------------------------

function ReforgeLite:CreateMethodWindow()
  self.methodWindow = CreateFrame ("Frame", "ReforgeLiteMethodWindow", UIParent, "BackdropTemplate")
  self.methodWindow:SetFrameStrata ("DIALOG")
  self.methodWindow:SetToplevel(true)
  self.methodWindow:ClearAllPoints ()
  self.methodWindow:SetSize(250, 480)
  if self.db.methodWindowLocation then
    self.methodWindow:SetPoint (SafeUnpack(self.db.methodWindowLocation))
  else
    self.methodWindow:SetPoint ("CENTER", self, "CENTER")
  end
  self.methodWindow.backdropInfo = self.backdropInfo
  self.methodWindow:ApplyBackdrop()

  self.methodWindow.titlebar = self.methodWindow:CreateTexture(nil,"BACKGROUND")
  self.methodWindow.titlebar:SetPoint("TOPLEFT",self.methodWindow,"TOPLEFT",3,-3)
  self.methodWindow.titlebar:SetPoint("TOPRIGHT",self.methodWindow,"TOPRIGHT",-3,-3)
  self.methodWindow.titlebar:SetHeight(20)
  self.methodWindow.SetFrameActive = self.SetFrameActive
  self.methodWindow:SetFrameActive(true)

  self.methodWindow:SetBackdropColor(self:GetBackdropColor())
  self.methodWindow:SetBackdropBorderColor(self:GetBackdropBorderColor())

  self.methodWindow:EnableMouse (true)
  self.methodWindow:SetMovable (true)
  self.methodWindow:SetScript ("OnMouseDown", function (window, arg)
    self:SetNewTopWindow(window)
    if arg == "LeftButton" then
      window:StartMoving ()
      window.moving = true
    end
  end)
  self.methodWindow:SetScript ("OnMouseUp", function (window)
    if window.moving then
      window:StopMovingOrSizing ()
      window.moving = false
      self.db.methodWindowLocation = SafePack(window:GetPoint())
    end
  end)

  tinsert(UISpecialFrames, self.methodWindow:GetName()) -- allow closing with escape
  tinsert(RFL_FRAMES, self.methodWindow)

  self.methodWindow.title = self.methodWindow:CreateFontString (nil, "OVERLAY", "GameFontNormal")
  self.methodWindow.title:SetTextColor(addonTable.FONTS.white:GetRGB())
  self.methodWindow.title.RefreshText = function(frame)
    frame:SetFormattedText(L["Apply %s Output"], self.pdb.methodOrigin)
  end
  self.methodWindow.title:RefreshText()
  self.methodWindow.title:SetPoint ("TOPLEFT", 12, self.methodWindow.title:GetHeight()-self.methodWindow.titlebar:GetHeight())

  self.methodWindow.close = CreateFrame ("Button", nil, self.methodWindow, "UIPanelCloseButtonNoScripts")
  self.methodWindow.close:SetPoint ("TOPRIGHT")
  self.methodWindow.close:SetSize(28, 28)
  self.methodWindow.close:SetScript ("OnClick", function (btn)
    btn:GetParent():Hide()
  end)
  self.methodWindow:SetScript ("OnShow", function (frame)
    self:SetNewTopWindow(frame)
    self:RefreshMethodWindow()
    self:RegisterQueueUpdateEvents()
  end)
  self.methodWindow:SetScript ("OnHide", function (frame)
    if self:GetActiveWindow() then
      self:SetFrameActive(true)
    else
      self:UnregisterQueueUpdateEvents()
    end
  end)

  self.methodWindow.itemTable = GUI:CreateTable (ITEM_SLOT_COUNT + 1, 3, 0, 0, nil, self.methodWindow)
  self.methodWindow.itemTable:SetPoint ("TOPLEFT", 12, -28)
  self.methodWindow.itemTable:SetRowHeight (26)
  self.methodWindow.itemTable:SetColumnWidth (1, ITEM_SIZE)
  self.methodWindow.itemTable:SetColumnWidth (2, ITEM_SIZE + 2)
  self.methodWindow.itemTable:SetColumnWidth (3, 274 - ITEM_SIZE * 2)

  self.methodOverride = {}
  for i = 1, ITEM_SLOT_COUNT do
    self.methodOverride[i] = 0
  end

  self.methodWindow.items = {}
  for i, v in ipairs (ITEM_SLOTS) do
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
      if itemSlot.item and ReforgingFrameIsVisible() then
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
    self.methodWindow.items[i].reforge:SetTextColor(addonTable.FONTS.white:GetRGB())
    self.methodWindow.items[i].reforge:SetText ("")

    self.methodWindow.items[i].check = GUI:CreateCheckButton (self.methodWindow.itemTable, "", false,
      function (val) self.methodOverride[i] = (val and 1 or -1) self:UpdateMethodChecks () end, true)
    self.methodWindow.itemTable:SetCell (i, 1, self.methodWindow.items[i].check)
  end

  self.methodWindow.reforge = GUI:CreatePanelButton(self.methodWindow, REFORGE, function(btn) self:DoReforge() end)
  self.methodWindow.reforge:SetPoint("BOTTOMLEFT", 12, 12)
  GUI:SetTooltip (self.methodWindow.reforge, function() return not ReforgingFrameIsVisible() and L["Reforging window must be open"] end)

  self.methodWindow.cost = CreateFrame("Frame", "ReforgeLiteReforgeCost", self.methodWindow, "SmallMoneyFrameTemplate")
  MoneyFrame_SetType(self.methodWindow.cost, "REFORGE")
  self.methodWindow.cost:SetPoint ("LEFT", self.methodWindow.reforge, "RIGHT", 5, 0)

  self.methodWindow.AttachToReforgingFrame = function(frame)
    frame:ClearAllPoints()
    frame:SetPoint("LEFT", ReforgingFrame, "RIGHT")
  end

  self:RefreshMethodWindow()
  self:SetNewTopWindow(self.methodWindow)
end

function ReforgeLite:RefreshMethodWindow()
  if not self.methodWindow then
    return
  end
  for i = 1, ITEM_SLOT_COUNT do
    self.methodOverride[i] = 0
  end

  for i, v in ipairs (self.methodWindow.items) do
    local item = self.playerData[v.slotId]
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
      v.quality:SetVertexColor(addonTable.FONTS.white:GetRGB())
      v.quality:Hide()
    end
    local slotInfo = self.pdb.method.items[i]
    if slotInfo.reforge and not item:IsItemEmpty() then
      v.reforge:SetFormattedText("%d %s > %s", slotInfo.amount, ITEM_STATS[slotInfo.src].long, ITEM_STATS[slotInfo.dst].long)
      v.reforge:SetTextColor(addonTable.FONTS.white:GetRGB())
    else
      v.reforge:SetText (L["No reforge"])
      v.reforge:SetTextColor(addonTable.FONTS.grey:GetRGB())
    end
  end
  self.methodWindow.title:RefreshText()
  self:UpdateMethodChecks ()
end

function ReforgeLite:ShowMethodWindow(attachToReforge)
  if not self.methodWindow then
    self:CreateMethodWindow()
  end

  GUI:ClearFocus()
  if self.methodWindow:IsShown() then
    self:SetNewTopWindow(self.methodWindow)
  else
    self.methodWindow:Show()
  end
  if attachToReforge then
      self.methodWindow:AttachToReforgingFrame()
  end
end

local function IsReforgeMatching (slotId, reforge, override)
  return override == 1 or reforge == GetReforgeID(slotId)
end

function ReforgeLite:UpdateMethodChecks ()
  if self.methodWindow and self.pdb.method then
    local cost = 0
    local anyDiffer
    for i, v in ipairs (self.methodWindow.items) do
      local item = self.playerData[v.slotId]
      v.item = item:GetItemLink()
      v.texture:SetTexture (item:GetItemIcon() or v.slotTexture)
      local isMatching = item:IsItemEmpty() or IsReforgeMatching(v.slotId, self.pdb.method.items[i].reforge, self.methodOverride[i])
      v.check:SetChecked(isMatching)
      anyDiffer = anyDiffer or not isMatching
      if not isMatching and self.pdb.method.items[i].reforge then
        local itemCost = select (11, C_Item.GetItemInfo(v.item)) or 0
        cost = cost + (itemCost > 0 and itemCost or 100000)
      end
    end
    self.methodWindow.cost:SetShown(anyDiffer)
    local enoughMoney = anyDiffer and GetMoney() >= cost
    self.methodWindow.reforge:SetEnabled(enoughMoney)
    SetMoneyFrameColorByFrame(self.methodWindow.cost, enoughMoney and "white" or "red")
    MoneyFrame_Update(self.methodWindow.cost, cost)
  end
end

function ReforgeLite:SwapSpecProfiles()
  if not self.db.specProfiles then return end

  local currentSettings = {
    caps = CopyTable(self.pdb.caps),
    weights = CopyTable(self.pdb.weights),
  }

  if self.pdb.prevSpecSettings then
    if self.initialized then
      self:SetStatWeights(self.pdb.prevSpecSettings.weights, self.pdb.prevSpecSettings.caps or {})
    else
      self.pdb.weights = CopyTable(self.pdb.prevSpecSettings.weights)
      self.pdb.caps = CopyTable(self.pdb.prevSpecSettings.caps)
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
  if self.pdb.method and self.methodWindow and ReforgingFrameIsVisible() then
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
  if not (self.pdb.method and self.methodWindow and self.methodWindow:IsShown() and ReforgingFrameIsVisible()) then
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
          local stats = GetItemStats (slotInfo.item, self.itemData[slotId].upgradeLevel)
          for s, reforgeInfo in ipairs(reforgeTable) do
            local srcstat, dststat = unpack(reforgeInfo)
            if (stats[ITEM_STATS[srcstat].name] or 0) ~= 0 and (stats[ITEM_STATS[dststat].name] or 0) == 0 then
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
      region:SetFormattedText("%s (%s > %s)", REFORGED, ITEM_STATS[srcId].long, ITEM_STATS[destId].long)
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

function ReforgeLite:OnEvent(event, ...)
  if self[event] then
    self[event](self, ...)
  end
  if queueUpdateEvents[event] then
      self:QueueUpdate()
  end
end

function ReforgeLite:Initialize()
  if not self.initialized then
    self:CreateFrame()
    self.initialized = true
  end
end

function ReforgeLite:OnShow()
  self:Initialize()
  self:SetNewTopWindow()
  self:UpdateItems()
  self:RegisterQueueUpdateEvents()
end

function ReforgeLite:OnHide()
  local activeWindow = self:GetActiveWindow()
  if activeWindow then
    self:SetNewTopWindow(activeWindow)
  else
    self:UnregisterQueueUpdateEvents()
  end
end

function ReforgeLite:OnCommand (cmd)
  if InCombatLockdown() then print(ERROR_CAPS, ERR_AFFECTING_COMBAT) return end
  self:Show()
end

function ReforgeLite:FORGE_MASTER_ITEM_CHANGED()
  self:ContinueReforge()
end

function ReforgeLite:FORGE_MASTER_OPENED()
  if self.db.openOnReforge and not self:GetActiveWindow() then
    self.autoOpened = true
    self:Show()
  end
  if self.methodWindow then
    self:RefreshMethodWindow()
  end
  self:CreateImportButton()
  self:StopReforging()
end

function ReforgeLite:FORGE_MASTER_CLOSED()
  if self.autoOpened then
    RFL_FRAMES:CloseAll()
    self.autoOpened = nil
  end
  self:StopReforging()
end

function ReforgeLite:PLAYER_REGEN_DISABLED()
  RFL_FRAMES:CloseAll()
end

local currentSpec -- hack because this event likes to fire twice
function ReforgeLite:ACTIVE_TALENT_GROUP_CHANGED(curr)
  if currentSpec ~= curr then
    currentSpec = curr
    self:SwapSpecProfiles()
  end
end

function ReforgeLite:PLAYER_SPECIALIZATION_CHANGED()
  self:GetConversion()
  self:UpdatePlayerSpecInfo()
end

function ReforgeLite:PLAYER_ENTERING_WORLD()
  self:GetConversion()
end

function ReforgeLite:PLAYER_AVG_ITEM_LEVEL_UPDATE()
  self.itemLevel:SetFormattedText(CHARACTER_LINK_ITEM_LEVEL_TOOLTIP, select(2,GetAverageItemLevel()))
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

  self.conversion = setmetatable({}, {
    __index = function(t, k)
      rawset(t, k, {})
      return t[k]
    end
  })

  if self.db.updateTooltip then
    self:HookTooltipScripts()
  end
  self:RegisterEvent("FORGE_MASTER_OPENED")
  self:RegisterEvent("FORGE_MASTER_CLOSED")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
  if self.db.specProfiles then
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
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
