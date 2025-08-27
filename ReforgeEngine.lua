local addonName, addonTable = ...
local REFORGE_COEFF = addonTable.REFORGE_COEFF

local ReforgeLite = addonTable.ReforgeLite
local L = addonTable.L
local playerClass, playerRace = addonTable.playerClass, addonTable.playerRace
local statIds = addonTable.statIds

local GetItemStats = addonTable.GetItemStatsUp

local dpChoices = nil

---------------------------------------------------------------------------------------

function ReforgeLite:GetStatMultipliers()
  local result = {}
  if playerRace == "HUMAN" then
    result[addonTable.statIds.SPIRIT] = (result[addonTable.statIds.SPIRIT] or 1) * 1.03
  end
  for _, v in ipairs (self.itemData) do
    if v.itemId then
      local id, iLvl = addonTable.GetItemInfoUp(v.itemId)
      if addonTable.AmplificationItems[id] then
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
    MergeTable(result, classConversionInfo.base)
  end

  local spec = C_SpecializationInfo.GetSpecialization()
  if spec and classConversionInfo.specs and classConversionInfo.specs[spec] then
    MergeTable(result, classConversionInfo.specs[spec])
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
  self.pdb.methodOrigin = addonName
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
  data.weights = CopyTable (self.pdb.weights)
  data.caps = CopyTable (self.pdb.caps)
  data.caps[1].init = 0
  data.caps[2].init = 0
  data.initial = {}

  data.mult = self:GetStatMultipliers()
  data.conv = CopyTable(self.conversion)

  for i = 1, 2 do
    for point = 1, #data.caps[i].points do
      local preset = data.caps[i].points[point].preset
      if self.capPresets[preset] == nil then
        preset = 1
      end
      if self.capPresets[preset].getter then
        data.caps[i].points[point].value = floor(self.capPresets[preset].getter())
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

--- Determines which stat cap should be prioritized during item ordering.
--- Calculates current distance from target for each cap and prioritizes the one furthest from its goal.
--- @param data table The reforge data structure containing caps configuration
--- @return number Cap index (1 or 2) indicating which cap has priority
function ReforgeLite:CalculatePriorityCap(data)
  -- Calculate total stats for each cap across all items
  local capDistances = {}
  
  for i = 1, 2 do
    local cap = data.caps[i]
    if cap.stat > 0 then
      local capTotal = 0
      -- Sum across all items for this cap stat
      for slot = 1, 16 do
        local itemStats = data.method.items[slot].stats
        capTotal = capTotal + (itemStats[cap.stat] or 0)
      end
      
      -- Add initial stats (character base stats without items)
      capTotal = capTotal + (data.initial[cap.stat] or 0)
      
      -- Calculate target value (use first constraint point for simplicity)
      local capTarget = 0
      if cap.points and cap.points[1] then
        capTarget = cap.points[1].value or 0
      end
      
      -- Calculate distance from target
      capDistances[i] = math.abs(capTotal - capTarget)
    else
      capDistances[i] = -1 -- No cap, lowest priority
    end
  end
  
  -- Determine which cap to prioritize (furthest from target)
  local priorityCap = 1
  if capDistances[2] > capDistances[1] then
    priorityCap = 2
  end
  
  return priorityCap
end

--- Orders items for optimal branch-and-bound processing to maximize early pruning.
--- Sorts items by primary cap contribution DESC, secondary cap contribution DESC, then total reforge potential DESC.
--- @param data table The reforge data structure containing item stats and caps
--- @param priorityCap number Which cap to prioritize (from CalculatePriorityCap)
--- @return table Array of slot numbers in processing order [slot5, slot12, slot3, ...]
function ReforgeLite:GetItemSortingOrder(data, priorityCap)
  local itemOrder = {}
  
  for slot = 1, 16 do
    local itemStats = data.method.items[slot].stats
    
    -- Primary cap contribution (the cap furthest from target)
    local primaryCapContrib = 0
    if data.caps[priorityCap].stat > 0 then
      primaryCapContrib = itemStats[data.caps[priorityCap].stat] or 0
    end
    
    -- Secondary cap contribution (the other cap)
    local secondaryCapContrib = 0
    local otherCap = priorityCap == 1 and 2 or 1
    if data.caps[otherCap].stat > 0 then
      secondaryCapContrib = itemStats[data.caps[otherCap].stat] or 0
    end
    
    -- Calculate sum of all reforgeable stats
    local reforgePotential = 0
    for stat = 1, #self.itemStats do
      reforgePotential = reforgePotential + (itemStats[stat] or 0)
    end
    
    table.insert(itemOrder, {
      slot = slot,
      primaryCapContrib = primaryCapContrib,
      secondaryCapContrib = secondaryCapContrib,
      reforgePotential = reforgePotential
    })
  end
  
  -- Sort by primary cap DESC, secondary cap DESC, then reforge potential DESC
  table.sort(itemOrder, function(a, b)
    if a.primaryCapContrib ~= b.primaryCapContrib then
      return a.primaryCapContrib > b.primaryCapContrib
    elseif a.secondaryCapContrib ~= b.secondaryCapContrib then
      return a.secondaryCapContrib > b.secondaryCapContrib
    else
      return a.reforgePotential > b.reforgePotential
    end
  end)
  
  -- Return slot order array: [slot14, slot3, slot7, ...]
  local sortedSlots = {}
  for i, entry in ipairs(itemOrder) do
    sortedSlots[i] = entry.slot
  end
  
  return sortedSlots
end

function ReforgeLite:ComputeReforgeCore(reforgeOptions)
  local char, floor = string.char, floor
  local TABLE_SIZE = floor(10000 * (self.db.accuracy / addonTable.MAX_SPEED))
  local scores, codes = {0}, {""}
  for i, opt in ipairs(reforgeOptions) do
    local newscores, newcodes = {}, {}
    for k, score in pairs(scores) do
      self:RunYieldCheck(200000)
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
    self:RunYieldCheck(500000)
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

local chooseLoops = 0

------------------------------------- SHARED SCORING FUNCTIONS ------------------------------

function ReforgeLite:CalculateMethodScore(method)
  if not method or not method.stats or not self.pdb.weights then return 0 end
  
  local stats = method.stats
  local score = 0
  local maxIndex = math.min(#stats, #self.pdb.weights)
  
  -- Identify which stats have caps to avoid double-counting
  local cappedStats = {}
  if self.pdb.caps then
    if self.pdb.caps[1] and self.pdb.caps[1].stat > 0 then
      cappedStats[self.pdb.caps[1].stat] = true
    end
    if self.pdb.caps[2] and self.pdb.caps[2].stat > 0 then
      cappedStats[self.pdb.caps[2].stat] = true
    end
  end
  
  -- Score non-capped stats with base weights
  for i = 1, maxIndex do
    if not cappedStats[i] then
      score = score + (self.pdb.weights[i] or 0) * (stats[i] or 0)
    end
  end
  
  -- Score capped stats using GetCapScore
  for capIndex = 1, 2 do
    local cap = self.pdb.caps and self.pdb.caps[capIndex]
    if cap and cap.stat > 0 and cap.stat <= #stats then
      local statValue = stats[cap.stat]
      if statValue then
        score = score + self:GetCapScore(cap, statValue)
      end
    end
  end
  
  return score
end

function ReforgeLite:CheckConstraintsSatisfied(method)
  if not method or not method.stats or not self.pdb.caps then return false end
  
  local stats = method.stats
  for capIndex = 1, 2 do
    local cap = self.pdb.caps[capIndex]
    if cap and cap.stat > 0 and cap.stat <= #stats then
      local statValue = stats[cap.stat]
      if statValue and not self:CapAllows(cap, statValue) then
        return false
      end
    end
  end
  
  return true
end

------------------------------------- BRANCH AND BOUND ------------------------------

--[[
BRANCH AND BOUND REFORGE OPTIMIZATION

Overview:
The branch-and-bound algorithm provides an alternative to dynamic programming for solving
the reforge optimization problem. While dynamic programming explores all possible stat
combinations systematically, branch-and-bound uses intelligent search tree pruning to
avoid exploring provably suboptimal solutions.

Algorithm Characteristics:
- Best Case: O(n) when aggressive pruning eliminates most branches early
- Average Case: O(n * b^d) where n=items, b=branching factor, d=depth
- Worst Case: O(b^n) - exponential when pruning is ineffective
- Memory: O(n) for the current path + O(n²) for precomputed bounds

Key Advantages:
1. Can find optimal solutions much faster than DP when pruning is effective
2. Memory usage scales linearly with problem size

Key Disadvantages:
1. Performance highly dependent on problem characteristics
2. Worst-case exponential runtime when bounds are loose
3. More complex implementation and debugging

Implementation Details:
The algorithm works by:
1. Ordering items by their potential impact on constrained stats
2. Generating "smart" reforge options based on mathematical reforging rules
3. Precomputing suffix bounds for aggressive pruning
4. Exploring reforge combinations depth-first with constraint/bound pruning
5. Maintaining the best feasible solution found so far

Pruning Strategies:
- Constraint Propagation: Eliminates branches that cannot satisfy stat caps
- Upper Bound Pruning: Uses very generous upper score bounds to eliminate suboptimal branches

When to Use:
Branch-and-bound typically outperforms DP when:
- Stat weights have significant differences (enables tighter bounds)
- Items have large amounts of capped stats (enables early good solutions)
- There are clear "best" reforge choices (reduces branching factor)

It may underperform DP when:
- Many stats have similar weights (loose bounds, poor pruning)
- Items have small stat amounts (weak early solutions)
- Configuration creates uniform reforge value distribution
--]]

----------------------------------------------------------------------------------------------

--- Generates a curated set of reforge options based on mathematical optimality rules.
--- Implements the 6 mathematical reforge rules while handling tied weights by canonical selection.
--- 
--- The Six Reforge Rules:
--- 1. No reforge - always consider leaving the item unchanged
--- 2. Capped stat on item → another capped stat not on item
--- 3. Capped stat on item → conversion source for a different capped stat also on item
--- 4. Capped stat on item → highest-weighted non-capped stat not on item
--- 5. Best delta stat on item → capped stat not on item
--- 6. Best delta stat on item → highest-weighted non-capped stat not on item
---
--- Key optimizations:
--- - For tied weights, only explores the first canonical option (avoids redundant search space explosion)
--- - Prioritizes reforges involving cap stats for better branch-and-bound performance
--- - Uses "best delta" calculation: 0.4 × stat_amount × (destination_weight - source_weight)
---
--- @param data table The reforge data structure containing weights, caps, and conversions
--- @param slot number Item slot number (1-16)
--- @param priorityCap number Which cap to prioritize (from CalculatePriorityCap)
--- @return table Array of reforge option objects {src, dst, score, d1, d2}
function ReforgeLite:GetSmartReforgeOptions(data, slot, priorityCap)
  local item = data.method.items[slot]
  if self:IsItemLocked(slot) then
    local src, dst = nil, nil
    if self.itemData[slot].reforge then
      src, dst = unpack(self.reforgeTable[self.itemData[slot].reforge])
    end
    return { self:MakeReforgeOption(item, data, src, dst) }
  end
  
  local options = {}
  local itemStats = item.stats
  
  -- Pre-compute key values
  local cappedStatsOnItem = {}
  local cappedStatsNotOnItem = {}
  local conversionSources = {} -- stat -> {target_stat -> ratio}
  
  -- Identify capped stats and their positions
  for i = 1, 2 do
    local capStat = data.caps[i].stat
    if capStat > 0 then
      if itemStats[capStat] > 0 then
        cappedStatsOnItem[capStat] = true
      else
        cappedStatsNotOnItem[capStat] = true
      end
    end
  end
  
  -- Build conversion map
  for src, convTable in pairs(data.conv) do
    for target, ratio in pairs(convTable) do
      if ratio > 0 then
        conversionSources[src] = conversionSources[src] or {}
        conversionSources[src][target] = ratio
      end
    end
  end
  
  -- Find highest-weighted non-capped stat not on item (pick first for ties)
  local highestWeight = -math.huge
  local highestWeightedStatNotOnItem = nil
  
  for stat = 1, #data.weights do
    if not cappedStatsOnItem[stat] and not cappedStatsNotOnItem[stat] and itemStats[stat] == 0 then
      local weight = data.weights[stat] or 0
      if weight > highestWeight then
        highestWeight = weight
        highestWeightedStatNotOnItem = stat
      -- Skip tied weights - we already have the first one
      end
    end
  end
  
  -- Find best delta stat on item (pick first for ties)
  local bestDelta = -math.huge
  local bestDeltaStat = nil
  
  if highestWeightedStatNotOnItem then
    for stat = 1, #data.weights do
      if itemStats[stat] > 0 and not cappedStatsOnItem[stat] and not cappedStatsNotOnItem[stat] then
        local srcWeight = data.weights[stat] or 0
        local delta = 0.4 * itemStats[stat] * (highestWeight - srcWeight)
        if delta > bestDelta then
          bestDelta = delta
          bestDeltaStat = stat
        -- Skip tied deltas - we already have the first one
        end
      end
    end
  end
  
  -- Rule 1: No reforge
  table.insert(options, self:MakeReforgeOption(item, data, nil, nil))
  
  -- Rule 2: Capped stat on item → another capped stat not on item
  for src, _ in pairs(cappedStatsOnItem) do
    for dst, _ in pairs(cappedStatsNotOnItem) do
      table.insert(options, self:MakeReforgeOption(item, data, src, dst))
    end
  end
  
  -- Rule 3: Capped stat on item → conversion source for different capped stat also on item
  for src, _ in pairs(cappedStatsOnItem) do
    for otherCappedStat, _ in pairs(cappedStatsOnItem) do
      if src ~= otherCappedStat then
        -- Find conversion sources for otherCappedStat that aren't on the item
        for convSrc, targets in pairs(conversionSources) do
          if targets[otherCappedStat] and itemStats[convSrc] == 0 then
            table.insert(options, self:MakeReforgeOption(item, data, src, convSrc))
          end
        end
      end
    end
  end
  
  -- Rule 4: Capped stat on item → highest-weighted non-capped stat not on item
  for src, _ in pairs(cappedStatsOnItem) do
    if highestWeightedStatNotOnItem then
      table.insert(options, self:MakeReforgeOption(item, data, src, highestWeightedStatNotOnItem))
    end
    
    -- Also consider conversion sources to capped stats
    for _, cappedStat in ipairs({data.caps[1].stat, data.caps[2].stat}) do
      if cappedStat > 0 then
        for convSrc, targets in pairs(conversionSources) do
          if targets[cappedStat] and itemStats[convSrc] == 0 then
            table.insert(options, self:MakeReforgeOption(item, data, src, convSrc))
          end
        end
      end
    end
  end
  
  -- Rule 5: Best delta stat on item → capped stat not on item
  if bestDeltaStat then
    for dst, _ in pairs(cappedStatsNotOnItem) do
      table.insert(options, self:MakeReforgeOption(item, data, bestDeltaStat, dst))
    end
    
    -- Conversion sources as fallback
    for _, cappedStat in ipairs({data.caps[1].stat, data.caps[2].stat}) do
      if cappedStat > 0 and cappedStatsOnItem[cappedStat] then
        for convSrc, targets in pairs(conversionSources) do
          if targets[cappedStat] and itemStats[convSrc] == 0 then
            table.insert(options, self:MakeReforgeOption(item, data, bestDeltaStat, convSrc))
          end
        end
      end
    end
  end
  
  -- Rule 6: Best delta stat on item → highest-weighted non-capped stat not on item
  if bestDeltaStat and highestWeightedStatNotOnItem then
    table.insert(options, self:MakeReforgeOption(item, data, bestDeltaStat, highestWeightedStatNotOnItem))
  end
  
  -- Remove duplicates
  local seen = {}
  local uniqueOptions = {}
  for _, opt in ipairs(options) do
    local key = (opt.src or 0) .. ":" .. (opt.dst or 0)
    if not seen[key] then
      seen[key] = true
      table.insert(uniqueOptions, opt)
    end
  end
  
  -- Sort reforge options by cap priority
  local otherCap = priorityCap == 1 and 2 or 1
  
  table.sort(uniqueOptions, function(a, b)
    -- Priority 1: Reforges involving priority cap stat (TO or FROM)
    local aInvolvesPriorityCap = (a.src == data.caps[priorityCap].stat) or (a.dst == data.caps[priorityCap].stat)
    local bInvolvesPriorityCap = (b.src == data.caps[priorityCap].stat) or (b.dst == data.caps[priorityCap].stat)
    
    if aInvolvesPriorityCap ~= bInvolvesPriorityCap then
      return aInvolvesPriorityCap -- priority cap reforges first
    end
    
    -- Priority 2: Reforges involving secondary cap stat (TO or FROM)  
    local aInvolvesSecondaryCap = (a.src == data.caps[otherCap].stat) or (a.dst == data.caps[otherCap].stat)
    local bInvolvesSecondaryCap = (b.src == data.caps[otherCap].stat) or (b.dst == data.caps[otherCap].stat)
    
    if aInvolvesSecondaryCap ~= bInvolvesSecondaryCap then
      return aInvolvesSecondaryCap -- secondary cap reforges next
    end
    
    -- Priority 3: Higher source stat weight to lower source stat weight
    -- (reforge from high-value stats to low-value stats first for better bounds)
    local aSourceWeight = (a.src and data.weights[a.src]) or 0
    local bSourceWeight = (b.src and data.weights[b.src]) or 0
    
    if aSourceWeight ~= bSourceWeight then
      return aSourceWeight > bSourceWeight -- higher source weight first
    end
    
    -- Priority 4: Fall back to score comparison
    return (a.score or 0) > (b.score or 0)
  end)
  
  return uniqueOptions
end

--- Precomputes tight upper bounds for constraint and score pruning.
--- Works backwards from position 16 to 1, accumulating best-case contributions for aggressive pruning.
--- @param data table The reforge data structure containing caps and weights
--- @param allItemOptions table Pre-computed reforge options for all items [slot] = {options}
--- @param sortedSlots table Array of slot numbers in processing order
--- @return table Array of bound objects with cap1/cap2 min/max and maxScore for each suffix position
function ReforgeLite:PrecomputeSuffixBounds(data, allItemOptions, sortedSlots)
  local suffixBounds = {}
  
  -- Calculate bounds in sorted order (from position 16 to 1)
  for pos = 16, 1, -1 do
    suffixBounds[pos] = {
      cap1 = {min = 0, max = 0},
      cap2 = {min = 0, max = 0},
      maxScore = 0
    }
    
    -- Use pre-computed reforge options for this item
    local slot = sortedSlots[pos]
    local options = allItemOptions[slot]
    
    -- Find min/max contributions for this item
    -- For constraint pruning: track true min/max for each cap independently
    local minCap1, maxCap1 = math.huge, -math.huge
    local minCap2, maxCap2 = math.huge, -math.huge
    
    -- For score pruning: use max score contribution (non-cap stats only)
    local maxScore = -math.huge
    
    for _, opt in ipairs(options) do
      local cap1Contrib = opt.d1 or 0
      local cap2Contrib = opt.d2 or 0
      local scoreContrib = opt.score or 0
      
      -- Track true min/max for constraint pruning
      minCap1 = math.min(minCap1, cap1Contrib)
      maxCap1 = math.max(maxCap1, cap1Contrib)
      minCap2 = math.min(minCap2, cap2Contrib)
      maxCap2 = math.max(maxCap2, cap2Contrib)
      
      -- Use only non-cap score contribution for frankenitem bound
      maxScore = math.max(maxScore, scoreContrib)
    end
    
    -- Ensure we have valid bounds even if no options
    if minCap1 == math.huge then minCap1 = 0 end
    if maxCap1 == -math.huge then maxCap1 = 0 end
    if minCap2 == math.huge then minCap2 = 0 end
    if maxCap2 == -math.huge then maxCap2 = 0 end
    
    -- Set bounds for this suffix
    if pos == 16 then
      -- Base case: just this item
      suffixBounds[pos].cap1.min = minCap1
      suffixBounds[pos].cap1.max = maxCap1
      suffixBounds[pos].cap2.min = minCap2
      suffixBounds[pos].cap2.max = maxCap2
      suffixBounds[pos].maxScore = maxScore
    else
      -- Cumulative: this item plus suffix
      suffixBounds[pos].cap1.min = minCap1 + suffixBounds[pos + 1].cap1.min
      suffixBounds[pos].cap1.max = maxCap1 + suffixBounds[pos + 1].cap1.max
      suffixBounds[pos].cap2.min = minCap2 + suffixBounds[pos + 1].cap2.min
      suffixBounds[pos].cap2.max = maxCap2 + suffixBounds[pos + 1].cap2.max
      suffixBounds[pos].maxScore = maxScore + suffixBounds[pos + 1].maxScore
    end
  end
  
  return suffixBounds
end

--- Determines if remaining items can possibly satisfy stat cap constraints.
--- Uses precomputed suffix bounds to check if AtLeast/AtMost/Exactly constraints can be met.
--- @param position number Current search position in the item processing order
--- @param currentStats table Current stat totals accumulated so far
--- @param suffixBounds table Precomputed bounds for remaining positions
--- @param data table The reforge data structure containing cap constraints
--- @return boolean True if constraints can be satisfied, false if impossible
function ReforgeLite:CanSatisfyConstraints(position, currentStats, suffixBounds, data)
  -- If we've processed all items, no more flexibility
  if position > 16 then
    return true
  end
  
  -- Check each cap
  for capIdx = 1, 2 do
    local cap = data.caps[capIdx]
    if cap and cap.stat > 0 then
      local currentValue = currentStats[cap.stat] or 0
      
      -- Check each constraint point
      for _, point in ipairs(cap.points or {}) do
        if point.method == addonTable.StatCapMethods.AtLeast then
          -- Need to reach at least this value
          local maxPossible = currentValue
          if capIdx == 1 then
            maxPossible = maxPossible + (suffixBounds[position].cap1.max or 0)
          else
            maxPossible = maxPossible + (suffixBounds[position].cap2.max or 0)
          end
          if maxPossible < point.value then
            return false -- Can't reach minimum
          end
        elseif point.method == addonTable.StatCapMethods.AtMost then
          -- Need to stay below this value
          local minPossible = currentValue
          if capIdx == 1 then
            minPossible = minPossible + (suffixBounds[position].cap1.min or 0)
          else
            minPossible = minPossible + (suffixBounds[position].cap2.min or 0)
          end
          if minPossible > point.value then
            return false -- Will exceed maximum
          end
        elseif point.method == addonTable.StatCapMethods.Exactly then
          -- Need to hit exactly this value
          local minPossible, maxPossible = currentValue, currentValue
          if capIdx == 1 then
            minPossible = minPossible + (suffixBounds[position].cap1.min or 0)
            maxPossible = maxPossible + (suffixBounds[position].cap1.max or 0)
          else
            minPossible = minPossible + (suffixBounds[position].cap2.min or 0)
            maxPossible = maxPossible + (suffixBounds[position].cap2.max or 0)
          end
          if maxPossible < point.value or minPossible > point.value then
            return false -- Can't hit exact value
          end
        end
      end
    end
  end
  
  return true
end

-- Branch and Bound state tracking
local bbBestSolution = nil
local bbNodesExplored = 0
local bbBranchesPruned = 0
local bbConstraintPrunes = 0
local bbScorePrunes = 0
local bbFoundExactDPPath = false

--- Core recursive search function that explores reforge combinations with pruning.
--- Uses depth-first search with constraint propagation and upper bound pruning to find optimal solutions.
--- @param position number Current item position in the search (1-16)
--- @param currentStats table Running stat totals accumulated so far
--- @param currentPath table Current reforge choices made [position] = {src, dst}
--- @param data table The reforge data structure containing all problem parameters
--- @param suffixBounds table Precomputed bounds for pruning decisions
--- @param allItemOptions table Pre-computed reforge options for all items
--- @param sortedSlots table Array of slot numbers in processing order
--- @return nil Updates global bbBestSolution with the best solution found
function ReforgeLite:BranchAndBoundSearch(position, currentStats, currentPath, data, suffixBounds, allItemOptions, sortedSlots)
  self:RunYieldCheck(50000) -- Cheap operation
  bbNodesExplored = bbNodesExplored + 1
  
  -- Base case: all items processed
  if position > 16 then
    -- Check if this solution is better than current best
    local constraintsMet = true
    for capIdx = 1, 2 do
      local cap = data.caps[capIdx]
      if cap and cap.stat > 0 then
        local statValue = currentStats[cap.stat] or 0
        if not self:CapAllows(cap, statValue) then
          constraintsMet = false
          break
        end
      end
    end
    
    -- Calculate the actual total score for this complete solution
    -- We need to create a temporary method object to use CalculateMethodScore
    local tempMethod = { stats = currentStats }
    local actualTotalScore = self:CalculateMethodScore(tempMethod)
    
    -- Check if this is the exact DP path
    local isExactDPPath = true
    if dpChoices then
      for pos = 1, position - 1 do
        local slot = sortedSlots[pos]
        if dpChoices[slot] then
          local pathChoice = currentPath[pos]
          if not pathChoice or pathChoice.src ~= dpChoices[slot].src or pathChoice.dst ~= dpChoices[slot].dst then
            isExactDPPath = false
            break
          end
        end
      end
    else
      isExactDPPath = false
    end
    
    if isExactDPPath then
      bbFoundExactDPPath = true
      if self.db.debug then
        print(string.format("B&B: Evaluating exact DP path - B&B thinks total score is %.1f", actualTotalScore))
      end
    end
    
    -- Update best if this is better
    if constraintsMet or not bbBestSolution or not bbBestSolution.constraintsMet then
      if not bbBestSolution or 
         (constraintsMet and not bbBestSolution.constraintsMet) or
         (constraintsMet == bbBestSolution.constraintsMet and actualTotalScore > bbBestSolution.score) then
        local previousBestScore = bbBestSolution and bbBestSolution.score or 0
        bbBestSolution = {
          score = actualTotalScore,  -- Use the actual total score
          path = CopyTable(currentPath),
          stats = CopyTable(currentStats),
          constraintsMet = constraintsMet
        }
        if self.db.debug then
          -- Show path summary for the solution we just found
          local pathStr = ""
          for pos = 1, position - 1 do
            local slot = sortedSlots[pos]
            if currentPath[pos] and currentPath[pos].src then
              pathStr = pathStr .. string.format(" pos%d(slot%d):%d->%d", pos, slot, currentPath[pos].src, currentPath[pos].dst)
            end
          end
          local pathNote = isExactDPPath and " ← EXACT DP PATH!" or ""
          local scoreDelta = actualTotalScore - previousBestScore
          print(string.format("B&B: Found better solution, score: %.1f (delta: %.1f), constraints: %s, path:%s%s", 
            actualTotalScore, scoreDelta, constraintsMet and "✓" or "✗", pathStr, pathNote))
        end
      end
    end
    return
  end

  self:RunYieldCheck(10000) -- Expensive operation coming
  
  -- Use pre-computed reforge options for current item
  local slot = sortedSlots[position]
  local options = allItemOptions[slot]

  for _, opt in ipairs(options) do
    -- Debug: Check if we're considering the DP choice for this item
    local isDPChoice = false
    if self.db.debug and dpChoices and dpChoices[slot] then
      local dpChoice = dpChoices[slot]
      isDPChoice = (opt.src == dpChoice.src and opt.dst == dpChoice.dst)
    end
    
    -- Apply reforge to stats
    local newStats = CopyTable(currentStats)
    
    -- Update ALL stats based on the reforge option, not just cap stats
    -- This is critical for accurate score calculation
    if opt.src and opt.dst then
      local itemStats = data.method.items[slot].stats
      local amountRaw = floor(itemStats[opt.src] * REFORGE_COEFF)
      
      -- Apply stat multipliers
      local srcAmount = Round(amountRaw * (data.mult[opt.src] or 1))
      local dstAmount = Round(amountRaw * (data.mult[opt.dst] or 1))
      
      -- Remove from source stat
      newStats[opt.src] = (newStats[opt.src] or 0) - srcAmount
      -- Add to destination stat  
      newStats[opt.dst] = (newStats[opt.dst] or 0) + dstAmount
      
      -- Handle conversions
      if data.conv[opt.src] then
        for to, factor in pairs(data.conv[opt.src]) do
          local conv = Round(srcAmount * factor)
          newStats[to] = (newStats[to] or 0) - conv
        end
      end
      if data.conv[opt.dst] then
        for to, factor in pairs(data.conv[opt.dst]) do
          local conv = Round(dstAmount * factor)
          newStats[to] = (newStats[to] or 0) + conv
        end
      end
    end
    
    -- Check if this branch can be pruned
    local shouldPrune = false
    local pruneReason = ""
    
    -- Constraint propagation check first
    local canSatisfyConstraints = self:CanSatisfyConstraints(position + 1, newStats, suffixBounds, data)
    if not canSatisfyConstraints then
      shouldPrune = true
      pruneReason = "constraint violation"
      bbConstraintPrunes = bbConstraintPrunes + 1
    end
    
    -- Upper bound pruning check with frankenitem cap-aware scoring
    if not shouldPrune and bbBestSolution and position <= 16 and suffixBounds[position + 1] then
      local tempMethod = { stats = newStats }
      local currentActualScore = self:CalculateMethodScore(tempMethod)
      
      -- Calculate frankenitem upper bound: max score + cap-adjusted max cap contributions
      local upperBound = currentActualScore + (suffixBounds[position + 1] and suffixBounds[position + 1].maxScore or 0)
      
      -- Add max possible cap contributions with cap scoring
      if suffixBounds[position + 1] then
        if data.caps[1].stat > 0 then
          local maxCap1Contrib = suffixBounds[position + 1].cap1.max or 0
          local projectedCap1Value = (newStats[data.caps[1].stat] or 0) + maxCap1Contrib
          local currentCap1Score = self:GetCapScore(data.caps[1], newStats[data.caps[1].stat] or 0)
          local maxCap1Score = self:GetCapScore(data.caps[1], projectedCap1Value)
          upperBound = upperBound + (maxCap1Score - currentCap1Score)
        end
        
        if data.caps[2].stat > 0 then
          local maxCap2Contrib = suffixBounds[position + 1].cap2.max or 0
          local projectedCap2Value = (newStats[data.caps[2].stat] or 0) + maxCap2Contrib
          local currentCap2Score = self:GetCapScore(data.caps[2], newStats[data.caps[2].stat] or 0)
          local maxCap2Score = self:GetCapScore(data.caps[2], projectedCap2Value)
          upperBound = upperBound + (maxCap2Score - currentCap2Score)
        end
      end
      
      if upperBound <= bbBestSolution.score then
        shouldPrune = true
        pruneReason = string.format("upper bound %.1f <= best %.1f", upperBound, bbBestSolution.score)
        bbScorePrunes = bbScorePrunes + 1
      end
    end
    
    -- Debug: Log when we prune a DP choice (but only if we're on the DP path so far)
    if self.db.debug and isDPChoice and shouldPrune then
      -- Check if we're actually on the DP path up to this point
      local onDPPath = true
      for prevPos = 1, position - 1 do
        local prevSlot = sortedSlots[prevPos]
        if dpChoices[prevSlot] then
          local prevChoice = currentPath[prevPos]
          if not prevChoice or prevChoice.src ~= dpChoices[prevSlot].src or prevChoice.dst ~= dpChoices[prevSlot].dst then
            onDPPath = false
            break
          end
        end
      end
      
      if onDPPath then
        local choiceStr = opt.src and string.format("%d->%d", opt.src, opt.dst) or "none"
        
        local tempMethod = { stats = newStats }
        local currentActualScore = self:CalculateMethodScore(tempMethod)
        local suffixMaxScore = suffixBounds[position + 1] and suffixBounds[position + 1].maxScore or 0
        local upperBound = currentActualScore + suffixMaxScore
        
        if upperBound == bbBestSolution.score then
          -- Equal scores - just a brief note
          print(string.format("B&B: Pruning equivalent DP choice at pos%d(slot%d) (%s)", position, slot, choiceStr))
        else
          -- Different scores - show full debug
          print(string.format("B&B: PRUNING DP choice at pos%d(slot%d) (%s) - %s", position, slot, choiceStr, pruneReason))
          if pruneReason:find("upper bound") then
            print(string.format("  Upper bound debug: currentActualScore=%.1f + suffixMaxScore=%.1f = upperBound=%.1f", 
              currentActualScore, suffixMaxScore, upperBound))
            print(string.format("  Best solution score: %.1f", bbBestSolution.score))
            print(string.format("  Pruning because: %.1f <= %.1f is %s", upperBound, bbBestSolution.score, upperBound <= bbBestSolution.score and "true" or "false"))
          end
        end
      end
    end
    
    if not shouldPrune then
      -- Update path
      currentPath[position] = {src = opt.src, dst = opt.dst}
      
      -- Debug: Check if we're following the DP path
      if self.db.debug and dpChoices and isDPChoice then
        local onDPPath = true
        for prevPos = 1, position do
          local prevSlot = sortedSlots[prevPos]
          if dpChoices[prevSlot] then
            local pathChoice = currentPath[prevPos]
            if not pathChoice or pathChoice.src ~= dpChoices[prevSlot].src or pathChoice.dst ~= dpChoices[prevSlot].dst then
              onDPPath = false
              break
            end
          end
        end
        if onDPPath then
          local pathStr = ""
          for pos = 1, position do
            local debugSlot = sortedSlots[pos]
            if currentPath[pos] and currentPath[pos].src then
              pathStr = pathStr .. string.format(" pos%d(slot%d):%d->%d", pos, debugSlot, currentPath[pos].src, currentPath[pos].dst)
            end
          end
          print(string.format("B&B: Following DP path at pos%d(slot%d), path so far:%s", position, slot, pathStr))
        end
      end

      -- Recursive search
      self:BranchAndBoundSearch(position + 1, newStats, currentPath, data, suffixBounds, allItemOptions, sortedSlots)

      -- Backtrack
      currentPath[position] = nil
    else
      bbBranchesPruned = bbBranchesPruned + 1
    end
  end
end

--- Main entry point for branch-and-bound optimization.
--- Orchestrates the complete B&B process: initialization, precomputation, search, and result application.
--- @return nil Updates self.pdb.method with the optimal reforge solution
function ReforgeLite:ComputeReforgeBranchBound()
  if self.db.debug then
    print("B&B: Starting Branch and Bound search")
  end
  
  -- Initialize data structures
  local data = self:InitReforgeClassic()
  
  -- Reset B&B state
  bbBestSolution = nil
  bbNodesExplored = 0
  bbBranchesPruned = 0
  bbConstraintPrunes = 0
  bbScorePrunes = 0
  bbFoundExactDPPath = false
  bbLastDebugTime = 0
  bbFoundDPOptimal = false
  
  -- Calculate priority cap once at the beginning
  local priorityCap = self:CalculatePriorityCap(data)
  
  -- Pre-compute all smart reforge options for all items
  local allItemOptions = {}
  for slot = 1, 16 do
    allItemOptions[slot] = self:GetSmartReforgeOptions(data, slot, priorityCap)
  end
  
  -- Get item sorting order using the same priority cap
  local sortedSlots = self:GetItemSortingOrder(data, priorityCap)
  
  -- Debug: Show item processing order
  if self.db.debug then
    local priorityCapStat = data.caps[priorityCap].stat
    local otherCap = priorityCap == 1 and 2 or 1
    local otherCapStat = data.caps[otherCap].stat
    print(string.format("B&B: Priority cap %d (stat %d), secondary cap %d (stat %d)", 
      priorityCap, priorityCapStat, otherCap, otherCapStat))
    
    local orderStr = "B&B: Item processing order:"
    for pos = 1, 16 do
      local slot = sortedSlots[pos]
      local itemStats = data.method.items[slot].stats
      local primaryContrib = (priorityCapStat > 0) and (itemStats[priorityCapStat] or 0) or 0
      local secondaryContrib = (otherCapStat > 0) and (itemStats[otherCapStat] or 0) or 0
      local reforgeSum = 0
      for stat = 1, #self.itemStats do
        reforgeSum = reforgeSum + (itemStats[stat] or 0)
      end
      orderStr = orderStr .. string.format(" slot%d(%d/%d/%d)", slot, primaryContrib, secondaryContrib, reforgeSum)
    end
    print(orderStr)
  end
  
  -- Precompute suffix bounds using pre-computed options and sorted order
  local suffixBounds = self:PrecomputeSuffixBounds(data, allItemOptions, sortedSlots)
  
  
  -- Initialize starting stats
  local initialStats = {}
  for i = 1, #self.itemStats do
    initialStats[i] = data.initial[i] or 0
  end
  
  -- Add base item stats to initial
  for i = 1, #data.method.items do
    for stat = 1, #self.itemStats do
      initialStats[stat] = (initialStats[stat] or 0) + (data.method.items[i].stats[stat] or 0)
    end
  end
  
  -- Add initial cap values
  if data.caps[1].stat > 0 then
    initialStats[data.caps[1].stat] = data.caps[1].init or 0
  end
  if data.caps[2].stat > 0 then
    initialStats[data.caps[2].stat] = data.caps[2].init or 0
  end
  
  -- Run branch and bound search
  local currentPath = {}
  self:BranchAndBoundSearch(1, initialStats, currentPath, data, suffixBounds, allItemOptions, sortedSlots)
  
  if self.db.debug then
    print(string.format("B&B: Completed - nodes explored: %d, branches pruned: %d (constraints: %d, score: %d)", 
      bbNodesExplored, bbBranchesPruned, bbConstraintPrunes, bbScorePrunes))
    if not bbFoundExactDPPath and dpChoices then
      print("B&B: WARNING - Never evaluated the exact DP path!")
    end
  end
  
  -- Apply best solution if found
  if bbBestSolution and bbBestSolution.path then
    -- Map position-based solution back to slot-based structure
    for position = 1, 16 do
      local slot = sortedSlots[position]
      local reforge = bbBestSolution.path[position]
      if reforge then
        -- Handle spirit->hit conversion special case
        if data.conv[addonTable.statIds.SPIRIT] and data.conv[addonTable.statIds.SPIRIT][addonTable.statIds.HIT] == 1 then
          if reforge.dst == addonTable.statIds.HIT and data.method.items[slot].stats[addonTable.statIds.SPIRIT] == 0 then
            reforge.dst = addonTable.statIds.SPIRIT
          end
        end
        data.method.items[slot].src = reforge.src
        data.method.items[slot].dst = reforge.dst
      else
        data.method.items[slot].src = nil
        data.method.items[slot].dst = nil
      end
    end
    
    self.methodDebug = { data = CopyTable(data) }
    self:FinalizeReforge(data)
    self.methodDebug.method = CopyTable(data.method)
    
    if data.method then
      self.pdb.method = data.method
      self.pdb.methodOrigin = addonName
      self:UpdateMethodCategory()
    end
  else
    if self.db.debug then
      print("B&B: No solution found, falling back to DP")
    end
    self:ComputeReforgeClassic()
  end
end

function ReforgeLite:ComputeReforgeClassic()
  local data = self:InitReforgeClassic()
  local reforgeOptions = {}
  for i = 1, #self.itemData do
    reforgeOptions[i] = self:GetItemReforgeOptions(data.method.items[i], data, i)
  end

  chooseLoops = 0

  local scores, codes = self:ComputeReforgeCore(reforgeOptions)

  chooseLoops = 0

  local code = self:ChooseReforgeClassic(data, reforgeOptions, scores, codes)

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
  self.methodDebug = { data = CopyTable(data) }
  self:FinalizeReforge (data)
  self.methodDebug.method = CopyTable(data.method)
  if data.method then
    self.pdb.method = data.method
    self.pdb.methodOrigin = addonName
    self:UpdateMethodCategory ()
  end
end

--- Runs both Dynamic Programming and Branch-and-Bound algorithms for performance comparison.
--- Prints detailed debug output comparing execution times, scores, and individual reforge choices.
--- Used for algorithm validation and performance analysis during development.
--- @return nil Updates self.pdb.method with the better solution and prints comparison results
function ReforgeLite:RunAlgorithmComparison()
  print("=== Algorithm Comparison Starting ===")
  
  -- Initialize conversions
  self:GetConversion()
  
  -- Print stat weights for debugging
  print("=== Stat Weights ===")
  for i = 1, #self.pdb.weights do
    if self.pdb.weights[i] and self.pdb.weights[i] ~= 0 then
      local statName = self.itemStats[i] and self.itemStats[i].name or ("stat" .. i)
      print(string.format("Stat %d (%s): %.1f", i, statName, self.pdb.weights[i]))
    end
  end
  
  -- Print caps configuration
  print("=== Caps Configuration ===")
  for i = 1, 2 do
    local cap = self.pdb.caps[i]
    if cap and cap.stat > 0 then
      local statName = self.itemStats[cap.stat] and self.itemStats[cap.stat].name or ("stat" .. cap.stat)
      print(string.format("Cap %d: Stat %d (%s)", i, cap.stat, statName))
    else
      print(string.format("Cap %d: None", i))
    end
  end
  
  -- Print stat conversions
  print("=== Stat Conversions ===")
  local hasConversions = false
  if self.conversion then
    for srcStat, conversions in pairs(self.conversion) do
      for dstStat, ratio in pairs(conversions) do
        if ratio and ratio > 0 then
          hasConversions = true
          local srcName = self.itemStats[srcStat] and self.itemStats[srcStat].name or ("stat" .. srcStat)
          local dstName = self.itemStats[dstStat] and self.itemStats[dstStat].name or ("stat" .. dstStat)
          print(string.format("Conversion: %d (%s) -> %d (%s) at ratio %.3f", 
            srcStat, srcName, dstStat, dstName, ratio))
        end
      end
    end
  end
  if not hasConversions then
    print("No stat conversions configured")
  end
  
  -- Print item information
  print("=== Item Information ===")
  for i = 1, #self.itemData do
    local itemData = self.itemData[i]
    local isLocked = self:IsItemLocked(i)
    
    -- Get item stats
    local item = itemData.item
    local stats = (item and GetItemStats(item, self.pdb.ilvlCap) or {})
    local statsStr = ""
    for statIdx = 1, #self.itemStats do
      local statValue = stats[self.itemStats[statIdx].name] or 0
      if statValue > 0 then
        statsStr = statsStr .. string.format(" %d:%d", statIdx, statValue)
      end
    end
    if statsStr == "" then
      statsStr = " (no stats)"
    end
    
    -- Get current reforge if locked
    local reforgeStr = ""
    if isLocked and itemData.reforge then
      local src, dst = unpack(self.reforgeTable[itemData.reforge])
      reforgeStr = string.format(", reforge: %d->%d", src, dst)
    elseif isLocked then
      reforgeStr = ", reforge: none"
    end
    
    print(string.format("Item %d:%s, locked: %s%s", i, statsStr, isLocked and "yes" or "no", reforgeStr))
  end
  
  -- Store original method
  local originalMethod = CopyTable(self.pdb.method)
  
  -- Run DP algorithm
  print("Running Dynamic Programming...")
  local dpStart = GetTime()
  self:ComputeReforgeClassic()
  local dpTime = GetTime() - dpStart
  local dpMethod = CopyTable(self.pdb.method)
  local dpScore = self:CalculateMethodScore(dpMethod)
  local dpConstraintsMet = self:CheckConstraintsSatisfied(dpMethod)
  
  -- Store DP choices for debugging
  dpChoices = {}
  local dpPathStr = ""
  for i = 1, #dpMethod.items do
    dpChoices[i] = {src = dpMethod.items[i].src, dst = dpMethod.items[i].dst}
    if dpMethod.items[i].src and dpMethod.items[i].dst then
      dpPathStr = dpPathStr .. string.format(" %d:%d->%d", i, dpMethod.items[i].src, dpMethod.items[i].dst)
    end
  end
  print(string.format("DP: Found solution, score: %.1f, constraints: %s, path:%s", 
    dpScore, dpConstraintsMet and "✓" or "✗", dpPathStr))
  
  -- Check if smart options will be able to generate all DP choices
  if self.db.debug then
    print("=== Smart Options Coverage ===")
    local data = self:InitReforgeClassic()
    
    -- Calculate priority cap for smart options
    local priorityCap = self:CalculatePriorityCap(data)
    
    for i = 1, #dpMethod.items do
      local dpChoice = dpChoices[i]
      if dpChoice.src or dpChoice.dst then -- Skip "no reforge" choices
        local smartOptions = self:GetSmartReforgeOptions(data, i, priorityCap)
        
        local foundDPChoice = false
        for _, opt in ipairs(smartOptions) do
          if opt.src == dpChoice.src and opt.dst == dpChoice.dst then
            foundDPChoice = true
            break
          end
        end
        if not foundDPChoice then
          local dpStr = dpChoice.src and string.format("%d->%d", dpChoice.src, dpChoice.dst) or "none"
          print(string.format("Item %d: DP choice %s NOT in smart options", i, dpStr))
        end
      end
    end
  end
  
  -- Reset to original
  self.pdb.method = CopyTable(originalMethod)
  
  -- Run Branch and Bound
  print("Running Branch and Bound...")
  local bbStart = GetTime()
  self:ComputeReforgeBranchBound()
  local bbTime = GetTime() - bbStart
  local bbMethod = CopyTable(self.pdb.method)
  local bbScore = self:CalculateMethodScore(bbMethod)
  local bbConstraintsMet = self:CheckConstraintsSatisfied(bbMethod)
  
  -- Print comparison
  print("=== Results ===")
  print(string.format("DP: Score %.1f, Time %.3fs, Constraints %s", 
    dpScore, dpTime, dpConstraintsMet and "✓" or "✗"))
  print(string.format("B&B: Score %.1f, Time %.3fs, Constraints %s",
    bbScore, bbTime, bbConstraintsMet and "✓" or "✗"))
  
  -- Compare individual choices
  if self.db.debug then
    print("=== Choice Comparison ===")
    for i = 1, #dpMethod.items do
      local dpChoice = dpChoices[i]
      local bbChoice = {src = bbMethod.items[i].src, dst = bbMethod.items[i].dst}
      
      local dpStr = dpChoice.src and string.format("%d->%d", dpChoice.src, dpChoice.dst) or "none"
      local bbStr = bbChoice.src and string.format("%d->%d", bbChoice.src, bbChoice.dst) or "none"
      
      if dpChoice.src ~= bbChoice.src or dpChoice.dst ~= bbChoice.dst then
        print(string.format("Item %d: DP=%s, B&B=%s (DIFFERENT)", i, dpStr, bbStr))
      end
    end
  end
  
  -- Determine winner
  local winner = "Tie"
  if dpConstraintsMet ~= bbConstraintsMet then
    winner = dpConstraintsMet and "DP (constraints)" or "B&B (constraints)"
  elseif math.abs(dpScore - bbScore) > 0.1 then
    winner = dpScore > bbScore and "DP" or "B&B"
  end
  print("Winner: " .. winner)
  
  -- Use better solution
  if bbConstraintsMet and (not dpConstraintsMet or bbScore > dpScore) then
    self.pdb.method = bbMethod
  else
    self.pdb.method = dpMethod
  end
  
  -- Clear debug state
  dpChoices = nil
  
  self:UpdateMethodCategory()
end

function ReforgeLite:ComputeReforge()
  if self.pdb.algorithmComparison then
    self:RunAlgorithmComparison()
    return
  end
  
  if self.db.useBranchBound then
    self:ComputeReforgeBranchBound()
  else
    self:ComputeReforgeClassic()
  end
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

function ReforgeLite:RunYieldCheck(maxLoops)
  if addonTable.pauseRoutine then
    chooseLoops = 0
    coroutine.yield()
  else
    if chooseLoops >= maxLoops then
      chooseLoops = 0
      self:ResumeComputeNextFrame()
      coroutine.yield()
    else
      chooseLoops = chooseLoops + 1
    end
  end
end

function ReforgeLite:StartCompute()
  if routine and addonTable.pauseRoutine == 'pause' and NORMAL_STATUS_CODES[coroutine.status(routine)]  then
    coroutine.resume(routine)
  else
    routine = coroutine.create(function() self:ComputeReforge() end)
  end
  self:ResumeComputeNextFrame()
end

function ReforgeLite:EndCompute()
  self.computeButton:RenderText(L["Compute"])
  addonTable.GUI:Unlock()
  self.pauseButton:RenderText(KEY_PAUSE)
  self.pauseButton:Disable()
  routine = nil
  collectgarbage('collect')
end
