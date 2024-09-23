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

local function DeepCopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[DeepCopy(orig_key, copies)] = DeepCopy(orig_value, copies)
            end
            setmetatable(copy, DeepCopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

addonTable.DeepCopy = DeepCopy