local addonName, addonTable = ...
local ReforgeLite = addonTable.ReforgeLite

local L = addonTable.L

local function CreateDataFrame()
    local AceGUI = LibStub("AceGUI-3.0")

    local frame = AceGUI:Create("Frame")
    frame:SetLayout("Flow")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetWidth(525)
    frame:SetHeight(275)

    local editbox = AceGUI:Create("MultiLineEditBox")
    editbox.editBox:SetFontObject(GameFontHighlightSmall)
    editbox:SetFullWidth(true)
    editbox:SetFullHeight(true)
    frame:AddChild(editbox)

    return frame,editbox
end

function ReforgeLite:DisplayMessage(name, message)
    local frame, editbox = CreateDataFrame()
    frame:SetTitle(L["Export"])
    frame:SetStatusText(name)
    editbox:DisableButton(true)
    editbox:SetLabel()
    editbox:SetText(message)
    editbox.editBox:SetFocus()
    editbox.editBox:HighlightText()
    editbox:SetCallback("OnLeave", function(widget) widget.editBox:HighlightText() widget:SetFocus() end)
    editbox:SetCallback("OnEnter", function(widget) widget.editBox:HighlightText() widget:SetFocus() end)
    editbox:SetCallback("OnTextChanged", function(widget) widget.editBox:SetText(message) widget.editBox:HighlightText() end)
end

function ReforgeLite:DebugMethod()
    local website = C_AddOns.GetAddOnMetadata(addonName, "X-Website")
    if self.methodDebug then
        self:DisplayMessage (website, addonTable.json.encode(self.methodDebug))
    else
        self:DisplayMessage (website, "<no data>\n nty <3")
    end
end

function ReforgeLite:ExportJSON(name, preset)
    self:DisplayMessage(name, addonTable.json.encode(preset))
end

function ReforgeLite:ImportPawn()
    local frame, editbox = CreateDataFrame()
    frame:SetTitle(L["Import Pawn"])
    editbox:DisableButton(false)
    editbox:SetLabel(L["Enter pawn string"])
    editbox.editBox:SetFocus()
    editbox.button:SetScript("OnClick", function()
        local values = self:ValidatePawnString(editbox.editBox:GetText())
        if values then
            frame:Hide()
            self:ParsePawnString(values)
        else
            frame:SetStatusText(ERROR_CAPS)
        end
        collectgarbage()
    end)
end

function ReforgeLite:ImportWoWSims()
    local frame, editbox = CreateDataFrame()
    frame:SetTitle(L["Import WoWSims"])
    editbox:DisableButton(false)
    editbox:SetLabel(L["Enter WoWSims JSON"])
    editbox.editBox:SetFocus()
    editbox.button:SetScript("OnClick", function()
        local values = self:ValidateWoWSimsString(editbox.editBox:GetText())
        if values then
            local valueType = type(values)
            if valueType == "table" then
                frame:Hide()
                self:ApplyWoWSimsImport(values)
            elseif valueType == "string" then
                frame:SetStatusText(values)
            end
        else
            frame:SetStatusText(ERROR_CAPS)
        end
        collectgarbage()
    end)
end