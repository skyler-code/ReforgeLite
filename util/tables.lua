local _, addonTable = ...

local function MergeTables(dst, src)
    for k, v in pairs(src) do
        if type(v) ~= "table" then
            if dst[k] == nil then
                dst[k] = v
            end
        else
        if type(dst[k]) ~= "table" then
            dst[k] = {}
        end
        MergeTables(dst[k], v)
        end
    end
end
addonTable.MergeTables = MergeTables

local function DeepCopy(t, cache)
    if type(t) ~= "table" then
        return t
    end
    local copy = {}
    for i, v in pairs(t) do
        if type(v) ~= "table" then
            copy[i] = v
        else
            cache = cache or {}
            cache[t] = copy
            if cache[v] then
                copy[i] = cache[v]
            else
                copy[i] = DeepCopy(v, cache)
            end
        end
    end
    return copy
end
addonTable.DeepCopy = DeepCopy