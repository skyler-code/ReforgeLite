local addonName, addonTable = ...
local ReforgeLite = addonTable.ReforgeLite

local FRAME_NAME = addonName .. "ExportImport"

local L = addonTable.L

local displayFrame, specialFrameTouched
local function GetDataFrame()
    if not displayFrame then
        local AceGUI = LibStub("AceGUI-3.0")

        displayFrame = AceGUI:Create("Frame")
        displayFrame:SetLayout("Flow")
        displayFrame:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            displayFrame = nil
            _G[FRAME_NAME] = nil
        end)
        displayFrame:SetWidth(525)
        displayFrame:SetHeight(275)

        displayFrame.editbox = AceGUI:Create("MultiLineEditBox")
        displayFrame.editbox.editBox:SetFontObject(GameFontHighlightSmall)
        displayFrame.editbox:SetFullWidth(true)
        displayFrame.editbox:SetFullHeight(true)
        displayFrame:AddChild(displayFrame.editbox)
        _G[FRAME_NAME] = displayFrame.frame
        if not specialFrameTouched then
            tinsert(UISpecialFrames, FRAME_NAME)
            specialFrameTouched = true
        end
    end
    return displayFrame
end

function ReforgeLite:DisplayMessage(name, message, noFocus)
    local frame = GetDataFrame()
    frame:SetTitle(L["Export"])
    frame:SetStatusText(name or "")
    frame.editbox:DisableButton(true)
    frame.editbox:SetLabel()
    frame.editbox:SetText(message)
    if not noFocus then
        frame.editbox.editBox:SetFocus()
        frame.editbox.editBox:HighlightText()
        frame.editbox:SetCallback("OnLeave", function(widget) widget.editBox:HighlightText() widget:SetFocus() end)
        frame.editbox:SetCallback("OnEnter", function(widget) widget.editBox:HighlightText() widget:SetFocus() end)
        frame.editbox:SetCallback("OnTextChanged", function(widget) widget.editBox:SetText(message) widget.editBox:HighlightText() end)
    end
end

function ReforgeLite:DebugMethod()
    self:DisplayMessage(C_AddOns.GetAddOnMetadata(addonName, "X-Website"), C_EncodingUtil.SerializeJSON(addonTable.methodDebug or {nty="<3"}))
end

function ReforgeLite:PrintLog()
    self:DisplayMessage("Print Log", table.concat(addonTable.printLog, "\n"), true)
end

function ReforgeLite:ExportJSON(preset, name)
    self:DisplayMessage(name, C_EncodingUtil.SerializeJSON(preset))
end

function ReforgeLite:ImportData(anchor)
    self:Initialize()
    self:UpdateItems()
    local frame = GetDataFrame()
    frame:SetTitle(L["Import"])
    if anchor then
        frame:SetPoint("TOP", anchor, "TOP")
    else
        frame:SetPoint("CENTER", self, "CENTER")
    end
    frame.editbox:DisableButton(true)
    frame.editbox:SetLabel(L["Enter WoWSims JSON or Pawn string"])
    frame.editbox.editBox:SetFocus()
    frame.editbox:SetCallback("OnTextChanged", function(widget)
        local values = self:ValidateWoWSimsString(widget:GetText())
        if values then
            local valueType = type(values)
            if valueType == "table" then
                self:ApplyWoWSimsImport(values)
                self:ShowMethodWindow(anchor ~= nil)
            elseif valueType == "string" then
                widget.parent:SetStatusText(values)
                return
            end
        else
            values = self:ValidatePawnString(widget:GetText())
            if values then
                self:ParsePawnString(values)
            end
        end
        if values then
            widget.parent:Hide()
        else
            widget.parent:SetStatusText(ERROR_CAPS)
        end
    end)
end