---@type string, AddonTable
local addonName, addonTable = ...

local ReforgeLite = addonTable.ReforgeLite

addonTable.isDev = true

---Compares execution time of two functions by running them multiple times
---@param func1 function First function to benchmark
---@param func2 function Second function to benchmark
---@param opts? table Options table with optional fields: label1 (string), label2 (string), loops (number, default: 10000)
---@return number time1, number time2 Total execution times in milliseconds
function addonTable.CompareFunctionTiming(func1, func2, opts)
  local label1 = (opts or {}).label1 or "Function 1"
  local label2 = (opts or {}).label2 or "Function 2"
  local loops = (opts or {}).loops or 10000

  local start1 = debugprofilestop()
  for i = 1, loops do
    func1()
  end
  local time1 = debugprofilestop() - start1

  local start2 = debugprofilestop()
  for i = 1, loops do
    func2()
  end
  local time2 = debugprofilestop() - start2

  print(("%s: %.3f ms"):format(label1, time1))
  print(("%s: %.3f ms"):format(label2, time2))
  print(("Difference: %.3f ms (%.1f%% %s)"):format(
    abs(time1 - time2),
    abs(time1 - time2) / min(time1, time2) * 100,
    time1 < time2 and "faster" or "slower"
  ))

  return time1, time2
end

function ReforgeLite:PreviewColors()
  for _, dbColor in ipairs(C_UIColor.GetColors()) do
    local color = _G[dbColor.baseTag]
    print(color:WrapTextInColorCode((", "):join(dbColor.baseTag, color:GetRGB())))
  end
end