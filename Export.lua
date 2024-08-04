local addonName, addonTable = ...
local ReforgeLite = addonTable.ReforgeLite
local ExportFrame
local function CreateErrorFrame()
    if ExportFrame then return end
    ExportFrame = CreateFrame ("Frame", "ReforgeLiteExportFrame", UIParent, "BackdropTemplate")
    ExportFrame:SetPoint ("CENTER")
    ExportFrame:SetFrameStrata ("TOOLTIP")
    ExportFrame:SetSize(320, 400)
    ExportFrame.backdropInfo = BACKDROP_TUTORIAL_16_16
    ExportFrame:ApplyBackdrop()
    ExportFrame:SetMovable (true)
    ExportFrame:SetClampedToScreen (true)
    ExportFrame:EnableMouse (true)
    ExportFrame:SetScript ("OnMouseDown", function (frame) frame:StartMoving () end)
    ExportFrame:SetScript ("OnMouseUp", function (frame) frame:StopMovingOrSizing () end)

    ExportFrame.close = CreateFrame ("Button", nil, ExportFrame, "UIPanelCloseButtonNoScripts")
    ExportFrame.close:SetSize (24, 24)
    ExportFrame.close:SetPoint ("TOPRIGHT", -4, -4)
    ExportFrame.close:SetScript ("OnClick", function (btn) btn:GetParent():Hide () end)
    ExportFrame.message = ExportFrame:CreateFontString (nil, "OVERLAY", "GameFontNormal")
    ExportFrame.message:SetPoint ("TOPLEFT", 15, -15)
    ExportFrame.message:SetPoint ("TOPRIGHT", -15, -15)
    ExportFrame.message:SetJustifyH ("LEFT")
    ExportFrame.message:SetTextColor (1, 1, 1)
    ExportFrame.message:SetText ("")
    ExportFrame.scroll = CreateFrame ("ScrollFrame", nil, ExportFrame, "UIPanelScrollFrameTemplate")
    ExportFrame.scroll:SetPoint ("TOPLEFT", ExportFrame.message, "BOTTOMLEFT", 0, -10)
    ExportFrame.scroll:SetPoint ("TOPRIGHT", ExportFrame.message, "BOTTOMRIGHT", -16, -10)
    ExportFrame.scroll:SetPoint ("BOTTOM", ExportFrame, "BOTTOMRIGHT", 0, 8)
    ExportFrame.text = CreateFrame ("EditBox", nil, ExportFrame.scroll)
    ExportFrame.scroll:SetScrollChild (ExportFrame.text)
    ExportFrame.text:SetSize(274, 100)
    ExportFrame.text:SetMultiLine (true)
    ExportFrame.text:SetAutoFocus (false)
    ExportFrame.text:SetFontObject (GameFontHighlight)
    ExportFrame.text:SetScript ("OnEscapePressed", function (frame) frame:ClearHighlightText(); frame:ClearFocus() end)
    tinsert(UISpecialFrames, ExportFrame:GetName()) -- allow closing with escape
    function ExportFrame:UpdateText()
        self.text:SetText(self.err)
        self.scroll:UpdateScrollChildRect ()
        self.text:ClearFocus()
    end
    ExportFrame.text:SetScript ("OnTextChanged", function(btn) ExportFrame:UpdateText() end)
    ExportFrame.text:SetScript ("OnEditFocusGained", function (btn) btn:HighlightText() end)
    function ExportFrame:DisplayMessage (message, err)
        self.message:SetText (message)
        self.err = err
        self:UpdateText ()
        self:Show()
    end
end

function ReforgeLite:DisplayMessage(name, message)
    CreateErrorFrame()
    ExportFrame:DisplayMessage(name, message)
end

function ReforgeLite:DebugMethod()
    local website = C_AddOns.GetAddOnMetadata(addonName, "X-Website")
    if self.methodDebug then
        self:DisplayMessage (website, addonTable.json.encode(self.methodDebug))
    else
        self:DisplayMessage (website, "<no data>\n nty <3")
    end
end


function ReforgeLite:ExportPreset(name, preset)
    self:DisplayMessage(name, addonTable.json.encode(preset))
end
