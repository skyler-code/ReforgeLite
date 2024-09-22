local addonName, addonTable = ...
local ReforgeLite = addonTable.ReforgeLite

local ExportMixin = {}

function ExportMixin:CreateFrame()
    self:SetPoint ("CENTER")
    self:SetFrameStrata ("TOOLTIP")
    self:SetSize(320, 400)
    self.backdropInfo = BACKDROP_TUTORIAL_16_16
    self:ApplyBackdrop()
    self:SetMovable(true)
    self:SetClampedToScreen(true)
    self:EnableMouse(true)
    self:SetScript("OnMouseDown", self.StartMoving)
    self:SetScript("OnMouseUp", self.StopMovingOrSizing)
    self:SetScript("OnHide", self.Hide)

    self.close = CreateFrame ("Button", nil, self, "UIPanelCloseButtonNoScripts")
    self.close:SetSize (24, 24)
    self.close:SetPoint("TOPRIGHT", -4, -4)
    self.close:SetScript("OnClick", function (btn) btn:GetParent():Hide () end)
    self.message = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.message:SetPoint("TOPLEFT", 15, -15)
    self.message:SetPoint("TOPRIGHT", -15, -15)
    self.message:SetJustifyH("LEFT")
    self.message:SetTextColor(1, 1, 1)
    self.message:SetText("")
    self.scroll = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
    self.scroll:SetPoint("TOPLEFT", self.message, "BOTTOMLEFT", 0, -10)
    self.scroll:SetPoint("TOPRIGHT", self.message, "BOTTOMRIGHT", -16, -10)
    self.scroll:SetPoint("BOTTOM", self, "BOTTOMRIGHT", 0, 8)
    self.text = CreateFrame("EditBox", nil, self.scroll)
    self.scroll:SetScrollChild(self.text)
    self.text:SetSize(274, 100)
    self.text:SetMultiLine(true)
    self.text:SetAutoFocus(false)
    self.text:SetFontObject(GameFontHighlight)
    self.text:SetScript("OnEscapePressed", function(frame) frame:ClearHighlightText(); frame:ClearFocus() end)
    tinsert(UISpecialFrames, self:GetName()) -- allow closing with escape
    self.text:SetScript("OnTextChanged", function(btn) self:UpdateText() end)
    self.text:SetScript("OnEditFocusGained", function(btn) btn:HighlightText() end)
end

function ExportMixin:UpdateText()
    self.text:SetText(self.err)
    self.scroll:UpdateScrollChildRect()
    self.text:ClearFocus()
end

function ExportMixin:DisplayMessage(message, err)
    self.message:SetText(message)
    self.err = err
    self:UpdateText()
    self:Show()
end

local ExportFrame
local function CreateErrorFrame()
    if ExportFrame then return end
    ExportFrame = CreateFrame("Frame", "ReforgeLiteExportFrame", ReforgeLite, "BackdropTemplate")
    Mixin(ExportFrame, ExportMixin)
    ExportFrame:CreateFrame()
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

function ReforgeLite:ExportJSON(name, preset)
    self:DisplayMessage(name, addonTable.json.encode(preset))
end
