local addonName, addonTable = ...
local REFORGE_COEFF = addonTable.REFORGE_COEFF

local ReforgeLite = addonTable.ReforgeLite
local L = addonTable.L
local DeepCopy = addonTable.DeepCopy
local playerClass, playerRace = addonTable.playerClass, addonTable.playerRace
local statIds = addonTable.statIds

local GetItemStats = addonTable.GetItemStatsUp

---------------------------------------------------------------------------------------

function ReforgeLite:GetStatMultipliers()
  local result = {}
  if playerRace == "HUMAN" then
    result[addonTable.statIds.SPIRIT] = (result[addonTable.statIds.SPIRIT] or 1) * 1.03
  end
  for _, v in ipairs (self.itemData) do
    if v.itemId then
      local id, iLvl = addonTable.GetItemInfoUp(v.itemId)
      if id and addonTable.AmplificationItems[id] then
        local factor = 1 + 0.01 * Round(addonTable.GetRandPropPoints(iLvl, 2) / 420)
        result[addonTable.statIds.HASTE] = (result[addonTable.statIds.HASTE] or 1) * factor
        result[addonTable.statIds.MASTERY] = (result[addonTable.statIds.MASTERY] or 1) * factor
        result[addonTable.statIds.SPIRIT] = (result[addonTable.statIds.SPIRIT] or 1) * factor
      end
    end
  end
  return result
end

local CASTER_SPEC = {[statIds.EXP] = {[statIds.HIT] = 1}}
local HYBRID_SPEC = {[statIds.SPIRIT] = {[statIds.HIT] = 1}, [statIds.EXP] = {[statIds.HIT] = 1}}
local STAT_CONVERSIONS = {
  DRUID = {
    specs = {
      [SPEC_DRUID_BALANCE] = HYBRID_SPEC,
      [4] = CASTER_SPEC -- Resto
    }
  },
  MAGE = { base = CASTER_SPEC },
  MONK = {
    specs = {
      [SPEC_MONK_MISTWEAVER] = {[statIds.SPIRIT] = {[statIds.HIT] = 0.5, [statIds.EXP] = 0.5}}
    }
  },
  PALADIN = {
    specs = {
      [1] = CASTER_SPEC -- Holy
    }
  },
  PRIEST = {
    base = CASTER_SPEC,
    specs = {
      [SPEC_PRIEST_SHADOW] = HYBRID_SPEC -- Shadow
    }
  },
  SHAMAN = {
    specs = {
      [1] = HYBRID_SPEC, -- Ele
      [SPEC_SHAMAN_RESTORATION] = CASTER_SPEC -- Resto
    }
  },
  WARLOCK = { base = CASTER_SPEC },
}

function ReforgeLite:GetConversion()
  local classConversionInfo = STAT_CONVERSIONS[playerClass]
  if not classConversionInfo then return end

  local result = {}

  if classConversionInfo.base then
    addonTable.MergeTables(result, classConversionInfo.base)
  end

  local spec = C_SpecializationInfo.GetSpecialization()
  if spec and classConversionInfo.specs and classConversionInfo.specs[spec] then
    addonTable.MergeTables(result, classConversionInfo.specs[spec])
  end

  self.conversion = result
end


function ReforgeLite:UpdateMethodStats (method)
  local mult = self:GetStatMultipliers()
  local oldstats = {}
  method.stats = {}
  for i = 1, #self.itemStats do
    oldstats[i] = self.itemStats[i].getter ()
    method.stats[i] = oldstats[i] / (mult[i] or 1)
  end
  method.items = method.items or {}
  for i = 1, #self.itemData do
    local item = self.itemData[i].item
    local orgstats = (item and GetItemStats(item) or {})
    local stats = (item and GetItemStats(item, self.pdb.ilvlCap) or {})
    local reforge = self.itemData[i].reforge

    method.items[i] = method.items[i] or {}

    method.items[i].stats = nil
    method.items[i].amount = nil

    for s, v in ipairs(self.itemStats) do
      method.stats[s] = method.stats[s] - (orgstats[v.name] or 0) + (stats[v.name] or 0)
    end
    if reforge then
      local src, dst = unpack(self.reforgeTable[reforge])
      local amount = floor ((orgstats[self.itemStats[src].name] or 0) * REFORGE_COEFF)
      method.stats[src] = method.stats[src] + amount
      method.stats[dst] = method.stats[dst] - amount
    end
    if method.items[i].src and method.items[i].dst then
      method.items[i].amount = floor ((stats[self.itemStats[method.items[i].src].name] or 0) * REFORGE_COEFF)
      method.stats[method.items[i].src] = method.stats[method.items[i].src] - method.items[i].amount
      method.stats[method.items[i].dst] = method.stats[method.items[i].dst] + method.items[i].amount
    end
  end

  for s, f in pairs(mult) do
    method.stats[s] = Round(method.stats[s] * f)
  end

  for src, c in pairs(self.conversion) do
    for dst, f in pairs(c) do
      method.stats[dst] = method.stats[dst] + Round((method.stats[src] - oldstats[src]) * f)
    end
  end
end

function ReforgeLite:FinalizeReforge (data)
  for _,item in ipairs(data.method.items) do
    item.reforge = nil
    if item.src and item.dst then
      item.reforge = self:GetReforgeTableIndex(item.src, item.dst)
    end
    item.stats = nil
  end
  self:UpdateMethodStats (data.method)
end

function ReforgeLite:ResetMethod ()
  local method = { items = {} }
  for i = 1, #self.itemData do
    method.items[i] = {}
    if self.itemData[i].reforge then
      method.items[i].reforge = self.itemData[i].reforge
      method.items[i].src, method.items[i].dst = unpack(self.reforgeTable[self.itemData[i].reforge])
    end
  end
  self:UpdateMethodStats (method)
  self.pdb.method = method
  self:UpdateMethodCategory()
end

function ReforgeLite:CapAllows (cap, value)
  for _,v in ipairs(cap.points) do
    if v.method == addonTable.StatCapMethods.AtLeast and value < v.value then
      return false
    elseif v.method == addonTable.StatCapMethods.AtMost and value > v.value then
      return false
    elseif v.method == addonTable.StatCapMethods.Exactly and value ~= v.value then
      return false
    end
  end
  return true
end

function ReforgeLite:IsItemLocked (slot)
  local slotData = self.itemData[slot]
  return not slotData.item
  or slotData.ilvl < 200
  or self.pdb.itemsLocked[slotData.itemGUID]
end

------------------------------------- CLASSIC REFORGE ------------------------------

function ReforgeLite:MakeReforgeOption(item, data, src, dst)
  local delta1, delta2, dscore = 0, 0, 0
  if src and dst then
    local amountRaw = floor(item.stats[src] * REFORGE_COEFF)
    local amount = Round(amountRaw * (data.mult[src] or 1))
    if src == data.caps[1].stat then
      delta1 = delta1 - amount
    elseif src == data.caps[2].stat then
      delta2 = delta2 - amount
    else
      dscore = dscore - data.weights[src] * amount
    end
    if data.conv[src] then
      for to, factor in pairs(data.conv[src]) do
        local conv = Round(amount * factor)
        if data.caps[1].stat == to then
          delta1 = delta1 - conv
        elseif data.caps[2].stat == to then
          delta2 = delta2 - conv
        else
          dscore = dscore - data.weights[to] * conv
        end
      end
    end
    amount = Round(amountRaw * (data.mult[dst] or 1))
    if dst == data.caps[1].stat then
      delta1 = delta1 + amount
    elseif dst == data.caps[2].stat then
      delta2 = delta2 + amount
    else
      dscore = dscore + data.weights[dst] * amount
    end
    if data.conv[dst] then
      for to, factor in pairs(data.conv[dst]) do
        local conv = Round(amount * factor)
        if data.caps[1].stat == to then
          delta1 = delta1 + conv
        elseif data.caps[2].stat == to then
          delta2 = delta2 + conv
        else
          dscore = dscore + data.weights[to] * conv
        end
      end
    end
  end
  return {d1 = delta1, d2 = delta2, src = src, dst = dst, score = dscore}
end

function ReforgeLite:GetItemReforgeOptions (item, data, slot)
  if self:IsItemLocked (slot) then
    local src, dst = nil, nil
    if self.itemData[slot].reforge then
      src, dst = unpack(self.reforgeTable[self.itemData[slot].reforge])
    end
    return { self:MakeReforgeOption (item, data, src, dst) }
  end
  local aopt = {}
  aopt[0] = self:MakeReforgeOption (item, data)
  for src = 1, #self.itemStats do
    if item.stats[src] > 0 then
      for dst = 1, #self.itemStats do
        if item.stats[dst] == 0 then
          local o = self:MakeReforgeOption (item, data, src, dst)
          local pos = o.d1 + o.d2 * 10000
          if not aopt[pos] or aopt[pos].score < o.score then
            aopt[pos] = o
          end
        end
      end
    end
  end
  local opt = {}
  for _, v in pairs (aopt) do
    tinsert (opt, v)
  end
  return opt
end

function ReforgeLite:InitializeMethod()
  local method = { items = {} }
  local orgitems = {}
  for i = 1, #self.itemData do
    method.items[i] = {}
    method.items[i].stats = {}
    orgitems[i] = {}
    local item = self.itemData[i].item
    local stats = (item and GetItemStats(item, self.pdb.ilvlCap) or {})
    local orgstats = (item and GetItemStats(item) or {})
    for j, v in ipairs(self.itemStats) do
      method.items[i].stats[j] = (stats[v.name] or 0)
      orgitems[i][j] = (orgstats[v.name] or 0)
    end
  end
  return method, orgitems
end

function ReforgeLite:InitReforgeClassic()
  local method, orgitems = self:InitializeMethod()
  local data = {}
  data.method = method
  data.weights = DeepCopy (self.pdb.weights)
  data.caps = DeepCopy (self.pdb.caps)
  data.caps[1].init = 0
  data.caps[2].init = 0
  data.initial = {}

  data.mult = self:GetStatMultipliers()
  data.conv = DeepCopy(self.conversion)

  for i = 1, 2 do
    for point = 1, #data.caps[i].points do
      local preset = data.caps[i].points[point].preset
      if self.capPresets[preset] == nil then
        preset = 1
      end
      if self.capPresets[preset].getter then
        data.caps[i].points[point].value = ceil(self.capPresets[preset].getter())
      end
    end
  end

  for i = 1, #self.itemStats do
    data.initial[i] = self.itemStats[i].getter() / (data.mult[i] or 1)
    for j = 1, #orgitems do
      data.initial[i] = data.initial[i] - orgitems[j][i]
    end
  end
  local reforged = {}
  for i = 1, #self.itemStats do
    reforged[i] = 0
  end
  for i = 1, #data.method.items do
    local reforge = self.itemData[i].reforge
    if reforge then
      local src, dst = unpack(self.reforgeTable[reforge])
      local amount = floor (method.items[i].stats[src] * REFORGE_COEFF)
      data.initial[src] = data.initial[src] + amount
      data.initial[dst] = data.initial[dst] - amount
      reforged[src] = reforged[src] - amount
      reforged[dst] = reforged[dst] + amount
    end
  end
  for src, c in pairs(data.conv) do
    for dst, f in pairs(c) do
      data.initial[dst] = data.initial[dst] - Round(reforged[src] * (data.mult[src] or 1) * f)
    end
  end
  if data.caps[1].stat > 0 then
    data.caps[1].init = data.initial[data.caps[1].stat]
    for i = 1, #data.method.items do
      data.caps[1].init = data.caps[1].init + data.method.items[i].stats[data.caps[1].stat]
    end
  end
  if data.caps[2].stat > 0 then
    data.caps[2].init = data.initial[data.caps[2].stat]
    for i = 1, #data.method.items do
      data.caps[2].init = data.caps[2].init + data.method.items[i].stats[data.caps[2].stat]
    end
  end
  if data.caps[1].stat == 0 then
    data.caps[1], data.caps[2] = data.caps[2], data.caps[1]
  end
  if data.caps[2].stat == data.caps[1].stat then
    data.caps[2].stat = 0
    data.caps[2].init = 0
  end

  for src, conv in pairs(data.conv) do
    if data.weights[src] == 0 then
      if (data.caps[1].stat and conv[data.caps[1].stat]) or (data.caps[2].stat and conv[data.caps[2].stat]) then
        if src == addonTable.statIds.EXP then
          data.weights[src] = -1
        else
          data.weights[src] = 1
        end
      end
    end
  end

  return data
end

function ReforgeLite:ComputeReforgeCore(reforgeOptions)
  local char, floor = string.char, floor
  local TABLE_SIZE = 10000
  local scores, codes = {0}, {""}
  for i, opt in ipairs(reforgeOptions) do
    local newscores, newcodes = {}, {}
    for k, score in pairs(scores) do
      self:RunYieldCheck()
      local s1, s2 = k % TABLE_SIZE, floor(k / TABLE_SIZE)
      for j = 1, #opt do
        local nscore = score + opt[j].score
        local nk = s1 + opt[j].d1 + (s2 + opt[j].d2) * TABLE_SIZE
        if not newscores[nk] or nscore > newscores[nk] then
          newscores[nk] = nscore
          newcodes[nk] = codes[k] .. char(j)
        end
      end
    end
    scores, codes = newscores, newcodes
  end
  return scores, codes
end

function ReforgeLite:ChooseReforgeClassic (data, reforgeOptions, scores, codes)
  local bestCode = {nil, nil, nil, nil}
  local bestScore = {0, 0, 0, 0}
  for k, score in pairs(scores) do
    self:RunYieldCheck()
    local s1 = data.caps[1].init
    local s2 = data.caps[2].init
    local code = codes[k]
    for i = 1, #code do
      local b = code:byte (i)
      s1 = s1 + reforgeOptions[i][b].d1
      s2 = s2 + reforgeOptions[i][b].d2
    end
    local a1, a2 = true, true
    if data.caps[1].stat > 0 then
      a1 = a1 and self:CapAllows (data.caps[1], s1)
      score = score + self:GetCapScore (data.caps[1], s1)
    end
    if data.caps[2].stat > 0 then
      a2 = a2 and self:CapAllows (data.caps[2], s2)
      score = score + self:GetCapScore (data.caps[2], s2)
    end
    local allow = a1 and (a2 and 1 or 2) or (a2 and 3 or 4)
    if not bestCode[allow] or score > bestScore[allow] then
      bestCode[allow] = code
      bestScore[allow] = score
    end
  end
  return bestCode[1] or bestCode[2] or bestCode[3] or bestCode[4]
end

function ReforgeLite:ComputeReforge()
  local data = self:InitReforgeClassic()
  local reforgeOptions = {}
  for i = 1, #self.itemData do
    reforgeOptions[i] = self:GetItemReforgeOptions(data.method.items[i], data, i)
  end

  self.__chooseLoops = nil

  local scores, codes = self:ComputeReforgeCore(reforgeOptions)

  local code = self:ChooseReforgeClassic(data, reforgeOptions, scores, codes)
  scores, codes = nil, nil
  collectgarbage ("collect")
  for i = 1, #data.method.items do
    local opt = reforgeOptions[i][code:byte(i)]
    if data.conv[addonTable.statIds.SPIRIT] and data.conv[addonTable.statIds.SPIRIT][addonTable.statIds.HIT] == 1 then
      if opt.dst == addonTable.statIds.HIT and data.method.items[i].stats[addonTable.statIds.SPIRIT] == 0 then
        opt.dst = addonTable.statIds.SPIRIT
      end
    end
    data.method.items[i].src = opt.src
    data.method.items[i].dst = opt.dst
  end
  self.methodDebug = { data = DeepCopy(data) }
  self:FinalizeReforge (data)
  self.methodDebug.method = DeepCopy(data.method)
  if data.method then
    self.pdb.method = data.method
    self:UpdateMethodCategory ()
  end
end

function ReforgeLite:Compute()
  self:ComputeReforge()
  self:EndCompute()
end

local NORMAL_STATUS_CODES = { suspended = true, running = true }
local routine

function ReforgeLite:ResumeCompute()
  coroutine.resume(routine)
  if not NORMAL_STATUS_CODES[coroutine.status(routine)] then
    self:EndCompute()
  end
end

function ReforgeLite:ResumeComputeNextFrame()
  RunNextFrame(function() self:ResumeCompute() end)
end

function ReforgeLite:RunYieldCheck()
  if (self.__chooseLoops or 0) >= self.db.speed then
    self.__chooseLoops = nil
    self:ResumeComputeNextFrame()
    coroutine.yield()
  else
    self.__chooseLoops = (self.__chooseLoops or 0) + 1
  end
end

function ReforgeLite:StartCompute()
  routine = coroutine.create(function() self:Compute() end)
  self:ResumeComputeNextFrame()
end

function ReforgeLite:EndCompute()
  self.computeButton:RenderText(L["Compute"])
  addonTable.GUI:Unlock()
end
