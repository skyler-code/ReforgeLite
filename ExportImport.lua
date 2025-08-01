local addonName, addonTable = ...
local ReforgeLite = addonTable.ReforgeLite

local L = addonTable.L

local displayFrame = nil
local function GetDataFrame()
    if not displayFrame then
        local AceGUI = LibStub("AceGUI-3.0")

        displayFrame = AceGUI:Create("Frame")
        displayFrame:SetLayout("Flow")
        displayFrame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            displayFrame = nil
            collectgarbage()
        end)
        displayFrame:SetWidth(525)
        displayFrame:SetHeight(275)

        displayFrame.editbox = AceGUI:Create("MultiLineEditBox")
        displayFrame.editbox.editBox:SetFontObject(GameFontHighlightSmall)
        displayFrame.editbox:SetFullWidth(true)
        displayFrame.editbox:SetFullHeight(true)
        displayFrame:AddChild(displayFrame.editbox)
    end
    return displayFrame
end

function ReforgeLite:DisplayMessage(name, message)
    local frame = GetDataFrame()
    frame:SetTitle(L["Export"])
    frame:SetStatusText(name or "")
    frame.editbox:DisableButton(true)
    frame.editbox:SetLabel()
    frame.editbox:SetText(message)
    frame.editbox.editBox:SetFocus()
    frame.editbox.editBox:HighlightText()
    frame.editbox:SetCallback("OnLeave", function(widget) widget.editBox:HighlightText() widget:SetFocus() end)
    frame.editbox:SetCallback("OnEnter", function(widget) widget.editBox:HighlightText() widget:SetFocus() end)
    frame.editbox:SetCallback("OnTextChanged", function(widget) widget.editBox:SetText(message) widget.editBox:HighlightText() end)
end

function ReforgeLite:DebugMethod()
    local website = C_AddOns.GetAddOnMetadata(addonName, "X-Website")
    if self.methodDebug then
        self:DisplayMessage (website, C_EncodingUtil.SerializeJSON(self.methodDebug))
    else
        self:DisplayMessage (website, "<no data>\n nty <3")
    end
end

function ReforgeLite:ExportJSON(preset, name)
    self:DisplayMessage(name, C_EncodingUtil.SerializeJSON(preset))
end

function ReforgeLite:ImportData()
    local frame = GetDataFrame()
    frame:SetTitle(L["Import"])
    frame.editbox:DisableButton(false)
    frame.editbox:SetLabel(L["Enter WoWSims or Pawn string"])
    frame.editbox.editBox:SetFocus()
    frame.editbox.button:SetScript("OnClick", function()
        local function OnHide(values)
            if values then
                frame:Hide()
            else
                frame:SetStatusText(ERROR_CAPS)
            end
        end
        local userInput = frame.editbox.editBox:GetText()
        local values = self:ValidateWoWSimsString(userInput)
        if values then
            local valueType = type(values)
            if valueType == "table" then
                self:ApplyWoWSimsImport(values)
            elseif valueType == "string" then
                frame:SetStatusText(values)
                return
            end
        else
            values = self:ValidatePawnString(userInput)
            if values then
                self:ParsePawnString(values)
            end
        end
        OnHide(values)
    end)
end