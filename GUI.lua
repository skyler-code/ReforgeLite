local addonName, addonTable = ...
local GUI = {}
addonTable.GUI = GUI

local callbacks = CreateFromMixins(CallbackRegistryMixin)
callbacks:OnLoad()
callbacks:GenerateCallbackEvents({ "OnCalculateFinish", "PreCalculateStart", "OnCalculateStart", "ToggleDebug" })

addonTable.callbacks = callbacks

addonTable.FONTS = {
  grey = INACTIVE_COLOR,
  lightgrey = TUTORIAL_FONT_COLOR,
  white = WHITE_FONT_COLOR,
  green = CreateColor(0.6, 1, 0.6),
  red = CreateColor(1, 0.4, 0.4),
  panel = PANEL_BACKGROUND_COLOR,
  gold = GOLD_FONT_COLOR,
  darkyellow = DARKYELLOW_FONT_COLOR,
  disabled = DISABLED_FONT_COLOR,
}

function GUI:GenerateWidgetName ()
  self.widgetCount = (self.widgetCount or 0) + 1
  return addonName .. "Widget" .. self.widgetCount
end

function GUI:ClearEditFocus()
  for _,v in ipairs(self.editBoxes) do
    v:ClearFocus()
  end
end

function GUI:ClearFocus()
  self:ClearEditFocus()
end

function GUI:Lock()
  for _, frames in ipairs({self.panelButtons, self.imgButtons, self.editBoxes, self.checkButtons, self.sliders}) do
    for _, frame in pairs(frames) do
      if frame:IsEnabled() and not frame.preventLock then
        frame.locked = true
        frame:Disable()
        if frame:IsMouseEnabled() then
          frame:EnableMouse(false)
          frame.mouseDisabled = true
        elseif frame:IsMouseMotionEnabled() then
          frame:SetMouseMotionEnabled(false)
          frame.mouseMotionDisabled = true
        end
        if frame.SetTextColor then
          frame.prevColor = {frame:GetTextColor()}
          frame:SetTextColor(addonTable.FONTS.grey:GetRGB())
        end
      end
    end
  end
  for _, dropdown in pairs(self.dropdowns) do
    if not dropdown.isDisabled then
      dropdown:DisableDropdown()
      dropdown.locked = true
    end
  end
end

function GUI:UnlockFrame(frame)
  if frame.locked then
    frame:Enable()
    frame.locked = nil
    if frame.mouseDisabled then
      frame:EnableMouse(true)
      frame.mouseDisabled = nil
    elseif frame.mouseMotionDisabled then
      frame:SetMouseMotionEnabled(true)
      frame.mouseMotionDisabled = nil
    end
    if frame.prevColor then
      frame:SetTextColor(unpack(frame.prevColor))
      frame.prevColor = nil
    end
  end
end

function GUI:Unlock()
  for _, frames in ipairs({self.panelButtons, self.imgButtons, self.editBoxes, self.checkButtons, self.sliders}) do
    for _, frame in pairs(frames) do
      self:UnlockFrame(frame)
    end
  end
  for _, dropdown in pairs(self.dropdowns) do
    if dropdown.locked then
      dropdown:EnableDropdown()
      dropdown.locked = nil
    end
  end
end

function GUI:SetTooltip (widget, tip)
  if tip then
    widget:SetScript ("OnEnter", function (tipFrame)
      local tooltipFunc = "AddLine"
      local tipText
      if type(tip) == "function" then
        tipText = tip(tipFrame)
      else
        tipText = tip
      end
      if type(tipText) == "table" then
        if tipText.spellID ~= nil then
          tooltipFunc = "SetSpellByID"
          tipText = tipText.spellID
        end
      end
      if tipText then
        GameTooltip:SetOwner(tipFrame, "ANCHOR_LEFT")
        GameTooltip[tooltipFunc](GameTooltip, tipText, nil, nil, nil, true)
        GameTooltip:Show()
      end
    end)
    widget:SetScript ("OnLeave", GameTooltip_Hide)
  else
    widget:SetScript ("OnEnter", nil)
    widget:SetScript ("OnLeave", nil)
  end
end

GUI.editBoxes = {}
GUI.unusedEditBoxes = {}
function GUI:CreateEditBox (parent, width, height, default, setter, opts)
  local box
  if #self.unusedEditBoxes > 0 then
    box = tremove(self.unusedEditBoxes)
    box:SetParent(parent)
    box:Show()
    box:SetTextColor(addonTable.FONTS.white:GetRGB())
    box:EnableMouse(true)
    self.editBoxes[box:GetName()] = box
  else
    box = CreateFrame ("EditBox", self:GenerateWidgetName (), parent, "InputBoxTemplate")
    self.editBoxes[box:GetName()] = box
    box:SetAutoFocus (false)
    box:SetFontObject(ChatFontNormal)
    box:SetTextColor(addonTable.FONTS.white:GetRGB())
    box:SetNumeric ()
    box:SetTextInsets (0, 0, 3, 3)
    box:SetMaxLetters (8)
    box.Recycle = function (box)
      box:Hide ()
      box:ClearScripts()
      self.editBoxes[box:GetName()] = nil
      tinsert (self.unusedEditBoxes, box)
    end
  end
  if width then
    box:SetWidth(width)
  end
  if height then
    box:SetHeight(height)
  end
  box:SetText(default)
  box:SetScript("OnEnterPressed", box.ClearFocus)
  box:SetScript("OnEditFocusGained", function(frame)
    frame.prevValue = tonumber(frame:GetText())
    frame:HighlightText()
  end)
  box:SetScript("OnEditFocusLost", function(frame)
    local value = tonumber(frame:GetText())
    if not value then
      value = frame.prevValue or 0
    end
    frame:SetText (value)
    if setter then
      setter (value)
    end
    frame.prevValue = nil
  end)
  box:SetScript("OnTabPressed", (opts or {}).OnTabPressed)
  return box
end


GUI.dropdowns = {}
GUI.unusedDropdowns = {}
function GUI:CreateDropdown (parent, values, options)
  local sel
  if #self.unusedDropdowns > 0 then
    sel = tremove (self.unusedDropdowns)
    sel:SetParent (parent)
    sel:Show ()
    sel:SetEnabled(true)
    self.dropdowns[sel:GetName()] = sel
  else
    sel = CreateFrame("DropdownButton", self:GenerateWidgetName(), parent, "WowStyle1DropdownTemplate")
    self.dropdowns[sel:GetName()] = sel

    -- Vertically center the text
    if sel.Text then
      sel.Text:ClearAllPoints()
      sel.Text:SetPoint("RIGHT", sel.Arrow, "LEFT")
      sel.Text:SetPoint("LEFT", sel, "LEFT", 9, 0)
    end

    sel.GetValues = function(frame) return GetValueOrCallFunction(frame, 'values') end

    sel.SetValue = function (dropdown, value)
      dropdown.value = value
      dropdown.selectedValue = value
      local values = dropdown:GetValues()
      if not values then
        if dropdown.Text then
          dropdown.Text:SetText("")
        end
        return
      end
      for _, v in ipairs(values) do
        if v.value == value then
          if dropdown.Text then
            dropdown.Text:SetText(v.name)
          end
          return
        end
      end
      if dropdown.Text then
        dropdown.Text:SetText("")
      end
    end

    sel.EnableDropdown = function(dropdown)
      dropdown:SetEnabled(true)
    end

    sel.DisableDropdown = function(dropdown)
      dropdown:SetEnabled(false)
    end

    sel.SetDropDownEnabled = function(dropdown, enabled)
      dropdown:SetEnabled(enabled)
    end

    sel:SetHeight(20)
    sel:SetEnabled(true)
    if sel.Text then
      sel.Text:SetTextColor(addonTable.FONTS.white:GetRGB())
    end

    sel.Recycle = function (frame)
      frame:Hide ()
      frame.setter = nil
      frame.value = nil
      frame.selectedName = nil
      frame.selectedID = nil
      frame.selectedValue = nil
      frame.menuItemDisabled = nil
      frame.menuItemHidden = nil
      frame.values = nil
      if frame.Text then
        frame.Text:SetText("")
      end
      self.dropdowns[frame:GetName()] = nil
      tinsert(self.unusedDropdowns, frame)
    end
  end

  sel.values = values
  sel.setter = options.setter
  sel.menuItemDisabled = options.menuItemDisabled
  sel.menuItemHidden = options.menuItemHidden

  -- Setup menu with MenuUtil (always needs to be called, even for recycled dropdowns)
  sel:SetupMenu(function(dropdown, rootDescription)
    GUI:ClearEditFocus()
    local values = dropdown:GetValues()
    if not values then
      return
    end
    for _, item in ipairs(values) do
      -- Skip hidden items
      if dropdown.menuItemHidden and dropdown.menuItemHidden(item) then
        -- Skip
      else
        local isSelected = function() return dropdown.value == item.value end
        local setSelected = function()
          local oldValue = dropdown.value
          dropdown.value = item.value
          dropdown.selectedValue = item.value
          if dropdown.Text then
            dropdown.Text:SetText(item.name)
          end
          if dropdown.setter then
            dropdown.setter(dropdown, item.value, oldValue)
          end
        end

        local button = rootDescription:CreateRadio(item.name, isSelected, setSelected, item.value)

        -- Handle disabled items
        if dropdown.menuItemDisabled and dropdown.menuItemDisabled(item.value) then
          button:SetEnabled(false)
        end
      end
    end
  end)

  sel:SetValue(options.default)
  if options.width then
    sel:SetWidth(options.width)
  end
  return sel
end

GUI.checkButtons = {}
GUI.unusedCheckButtons = {}
function GUI:CreateCheckButton (parent, text, default, setter, opts)
  local btn
  if #self.unusedCheckButtons > 0 then
    btn = tremove (self.unusedCheckButtons)
    btn:SetParent (parent)
    btn:Show ()
    self.checkButtons[btn:GetName()] = btn
  else
    local name = self:GenerateWidgetName ()
    btn = CreateFrame ("CheckButton", name, parent, "UICheckButtonTemplate")
    self.checkButtons[name] = btn
    btn.Recycle = function (btn)
      btn:Hide ()
      btn:ClearScripts()
      self.checkButtons[btn:GetName()] = nil
      tinsert (self.unusedCheckButtons, btn)
    end
  end
  btn.Text:SetText(text)
  btn:SetChecked (default)
  if setter then
    btn:SetScript ("OnClick", function (self)
      setter(self:GetChecked ())
    end)
  end
  btn:SetScript("OnEnable", function(self)
    self.Text:SetTextColor(unpack(self.Text.originalFontColor))
    self.Text.originalFontColor = nil
  end)
  btn:SetScript("OnDisable", function(self)
    self.Text.originalFontColor = {self.Text:GetTextColor()}
    self.Text:SetTextColor(addonTable.FONTS.disabled:GetRGB())
  end)
  self:SetTooltip(btn, (opts or {}).tooltip)
  return btn
end

GUI.imgButtons = {}
GUI.unusedImgButtons = {}
function GUI:CreateImageButton (parent, width, height, img, pus, opts)
  local btn
  if #self.unusedImgButtons > 0 then
    btn = tremove (self.unusedImgButtons)
    btn:SetParent (parent)
    btn:Show ()
  else
    local name = self:GenerateWidgetName ()
    btn = CreateFrame ("Button", name, parent)
    self.imgButtons[btn:GetName()] = btn
    btn.Recycle = function (f)
      f:Hide ()
      f:ClearScripts()
      self.imgButtons[f:GetName()] = nil
      tinsert (self.unusedImgButtons, f)
    end
  end
  btn:SetNormalTexture (img)
  btn:SetPushedTexture (pus)
  btn:SetHighlightTexture ((opts or {}).hlt or img)
  btn:SetDisabledTexture((opts or {}).disabledTexture or img)
  btn:SetSize(width, height)
  btn:SetScript ("OnClick", (opts or {}).OnClick)
  self:SetTooltip(btn, (opts or {}).tooltip)
  return btn
end

GUI.panelButtons = {}
GUI.unusedPanelButtons = {}
function GUI:CreatePanelButton(parent, text, handler, opts)
  local btn
  if #self.unusedPanelButtons > 0 then
    btn = tremove(self.unusedPanelButtons)
    btn:SetParent(parent)
    btn:Show()
    btn:Enable()
    self.panelButtons[btn:GetName()] = btn
  else
    local name = self:GenerateWidgetName ()
    btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    self.panelButtons[btn:GetName()] = btn
    btn.Recycle = function (f)
      f:SetText("")
      f:Hide ()
      f:ClearScripts()
      for event in pairs(callbacks.Event) do
          callbacks:UnregisterCallback(event, f:GetName())
      end
      self.panelButtons[f:GetName()] = nil
      tinsert (self.unusedPanelButtons, f)
    end
    btn.RenderText = function(f, ...)
      f:SetText(...)
      f:FitToText()
    end
  end
  btn.preventLock = (opts or {}).preventLock
  if opts then
    for event in pairs(callbacks.Event) do
      if opts[event] then
        callbacks:RegisterCallback(event, function(_, self) opts[event](self) end, btn:GetName(), btn)
      end
    end
  end
  btn:RenderText(text)
  btn:SetScript("OnClick", handler)
  btn:SetScript("PreClick", (opts or {}).PreClick)
  self:SetTooltip(btn, (opts or {}).tooltip)
  return btn
end

function GUI:CreateColorPicker (parent, width, height, color, handler)
  local box = CreateFrame ("Frame", nil, parent)
  box:SetSize(width, height)
  box:EnableMouse (true)
  box.texture = box:CreateTexture (nil, "OVERLAY")
  box.texture:SetAllPoints ()
  box.texture:SetColorTexture (unpack (color))
  box.glow = box:CreateTexture (nil, "BACKGROUND")
  box.glow:SetPoint ("TOPLEFT", -2, 2)
  box.glow:SetPoint ("BOTTOMRIGHT", 2, -2)
  
  box.glow:SetColorTexture (addonTable.FONTS.grey:GetRGB())
  box.glow:Hide ()

  box:SetScript ("OnEnter", function (b) b.glow:Show() end)
  box:SetScript ("OnLeave", function (b) b.glow:Hide() end)
  box:SetScript ("OnMouseDown", function (b)
    local function applyColor(func)
      return function()
        local prevR, prevG, prevB = func(ColorPickerFrame)
        color[1], color[2], color[3] = prevR, prevG, prevB
        b.texture:SetColorTexture(prevR, prevG, prevB)
        if handler then
          handler()
        end
      end
    end
    ColorPickerFrame:SetupColorPickerAndShow({
      r = color[1], g = color[2], b = color[3],
      swatchFunc = applyColor(ColorPickerFrame.GetColorRGB),
      cancelFunc = applyColor(ColorPickerFrame.GetPreviousValues),
    })
  end)

  return box
end

GUI.helpButtons = {}
function GUI:CreateHelpButton(parent, tooltip, opts)
  local btn = CreateFrame("Button", nil, parent, "MainHelpPlateButton")
  btn:SetFrameLevel(btn:GetParent():GetFrameLevel() + 1)
  btn:SetScale((opts or {}).scale or 0.6)
  self:SetTooltip(btn, tooltip)
  tinsert(self.helpButtons, btn)
  return btn
end

function GUI:SetHelpButtonsShown(shown)
  for _, btn in ipairs(self.helpButtons) do
    btn:SetShown(shown)
  end
end

GUI.sliders = {}
GUI.unusedSliders = {}
function GUI:CreateSlider(parent, text, value, max, onChange)
  local slider
  if #self.unusedSliders > 0 then
    slider = tremove(self.unusedSliders)
    slider:SetParent(parent)
    slider:Show()
    slider:Enable()
    self.sliders[slider:GetName()] = slider
  else
    local name = self:GenerateWidgetName()
    slider = CreateFrame("Slider", name, parent, "UISliderTemplateWithLabels")
    self.sliders[name] = slider
    slider:SetSize(150, 15)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouseWheel(false)
    slider:SetValueStep(1)
    slider.Recycle = function (f)
      f.Text:SetText("")
      f:Hide()
      f:ClearScripts()
      self.sliders[f:GetName()] = nil
      tinsert(self.unusedSliders, f)
    end
  end
  slider:SetMinMaxValues(1, max)
  slider:SetValue(value)
  slider:SetScript("OnValueChanged", onChange)
  slider.Text:SetText(text)
  slider:SetScript("OnEnable", function(self)
    for k, v in ipairs({self.Text, self.Low, self.High}) do
      v:SetTextColor(unpack(v.originalFontColor))
      v.originalFontColor = nil
    end
  end)
  slider:SetScript("OnDisable", function(self)
    for k, v in ipairs({self.Text, self.Low, self.High}) do
      v.originalFontColor = {v:GetTextColor()}
      v:SetTextColor(addonTable.FONTS.disabled:GetRGB())
    end
  end)

  return slider
end

-------------------------------------------------------------------------------

function GUI:CreateHLine (x1, x2, y, w, color, parent)
  parent = parent or self.defaultParent
  local line = parent:CreateTexture (nil, "ARTWORK")
  line:SetDrawLayer ("ARTWORK")
  line:SetColorTexture (unpack(color))
  if x1 > x2 then
    x1, x2 = x2, x1
  end
  line:ClearAllPoints ()
  line:SetTexCoord (0, 0, 0, 1, 1, 0, 1, 1)
  line.width = w
  line:SetPoint ("BOTTOMLEFT", parent, "TOPLEFT", x1, y - w / 2)
  line:SetPoint ("TOPRIGHT", parent, "TOPLEFT", x2, y + w / 2)
  line:Show ()
  line.SetPos = function (self, x1, x2, y)
    if x1 > x2 then
      x1, x2 = x2, x1
    end
    self:ClearAllPoints ()
    self:SetPoint ("BOTTOMLEFT", parent, "TOPLEFT", x1, y - self.width / 2)
    self:SetPoint ("TOPRIGHT", parent, "TOPLEFT", x2, y + self.width / 2)
  end
  return line
end

function GUI:CreateVLine (x, y1, y2, w, color, parent)
  parent = parent or self.defaultParent
  local line = parent:CreateTexture (nil, "ARTWORK")
  line:SetDrawLayer ("ARTWORK")
  line:SetColorTexture (unpack(color))
  if y1 > y2 then
    y1, y2 = y2, y1
  end
  line:ClearAllPoints ()
  line:SetTexCoord (1, 0, 0, 0, 1, 1, 0, 1)
  line.width = w
  line:SetPoint ("BOTTOMLEFT", parent, "TOPLEFT", x - w / 2, y1)
  line:SetPoint ("TOPRIGHT", parent, "TOPLEFT", x + w / 2, y2)
  line:Show ()
  line.SetPos = function (self, x, y1, y2)
    if y1 > y2 then
      y1, y2 = y2, y1
    end
    self:ClearAllPoints ()
    self:SetPoint ("BOTTOMLEFT", parent, "TOPLEFT", x - self.width / 2, y1)
    self:SetPoint ("TOPRIGHT", parent, "TOPLEFT", x + self.width / 2, y2)
  end
  return line
end

--------------------------------------------------------------------------------

function GUI:CreateTable (rows, cols, firstRow, firstColumn, gridColor, parent)
  parent = parent or self.defaultParent
  firstRow = firstRow or 0
  firstColumn = firstColumn or 0

  local t = CreateFrame ("Frame", nil, parent)
  t:ClearAllPoints ()
  t:SetSize(400, 400)
  t:SetPoint ("TOPLEFT")

  t.rows = rows
  t.cols = cols
  t.gridColor = gridColor
  t.rowPos = {}
  t.colPos = {}
  t.rowHeight = {}
  t.colWidth = {}
  t.rowPos[-1] = 0
  t.rowPos[0] = firstRow
  t.colPos[-1] = 0
  t.colPos[0] = firstColumn
  t.rowHeight[0] = firstRow
  t.colWidth[0] = firstColumn

  t.SetRowHeight = function (self, n, h)
    if h then
      if n < 0 or n > self.rows then
        return
      end
      self.rowHeight[n] = h
      if n == 0 and self.hlines then
        self.hlines[-1]:SetShown(h ~= 0)
      end
    else
      for i = 1, self.rows do
        self.rowHeight[i] = n
      end
    end
    self:OnUpdateFix ()
  end
  t.SetColumnWidth = function (self, n, w)
    if w then
      if n < 0 or n > self.cols then
        return
      end
      self.colWidth[n] = w
      if n == 0 and self.vlines then
        self.vlines[-1]:SetShown(w ~= 0)
      end
    else
      for i = 1, self.cols do
        self.colWidth[i] = n
      end
    end
    self:OnUpdateFix ()
  end
  t.AddRow = function (self, i, n)
    i = i or (self.rows + 1)
    n = n or 1
    local height = ((i == self.rows + 1) and self.rowHeight[i - 1] or self.rowHeight[i])
    for r = self.rows, i, -1 do
      self.cells[r + n] = self.cells[r]
      self.rowHeight[r + n] = self.rowHeight[r]
    end
    for r = i, i + n - 1 do
      self.cells[r] = {}
      self.rowHeight[r] = height
      self.rows = self.rows + 1
      if self.gridColor then
        if self.hlines[self.rows] then
          self.hlines[self.rows]:Show ()
        else
          self.hlines[self.rows] = GUI:CreateHLine (0, 0, 0, 1.5, self.gridColor, self)
        end
      end
    end
    self:OnUpdateFix ()
  end
  t.MoveRow = function (self, i, to)
    local height = self.row[i] - self.rowPos[i - 1]
    local cells = self.cells[i]
    if to > i then
      for r = i + 1, to do
        self.cells[r - 1] = self.cells[r]
        self.rowHeight[r - 1] = self.rowHeight[r]
      end
    elseif to < i then
      for r = i - 1, to, -1 do
        self.cells[r + 1] = self.cells[r]
        self.rowHeight[r + 1] = self.rowHeight[r]
      end
    end
    self.cells[to] = cells
    self.rowHeight[to] = height
    self:OnUpdateFix ()
  end
  t.DeleteRow = function (self, i)
    for j = 0, self.cols do
      if self.cells[i][j] then
        if type (self.cells[i][j].Recycle) == "function" then
          self.cells[i][j]:Recycle ()
        else
          self.cells[i][j]:Hide ()
        end
      end
    end
    for r = i + 1, self.rows do
      self.cells[r - 1] = self.cells[r]
      self.rowHeight[r - 1] = self.rowHeight[r]
    end
    if self.hlines and self.hlines[self.rows] then
      self.hlines[self.rows]:Hide ()
    end
    self.rows = self.rows - 1
    self:OnUpdateFix ()
  end
  t.ClearCells = function (self)
    for i = 0, self.rows do
      for j = 0, self.cols do
        if self.cells[i][j] then
          if type (self.cells[i][j].Recycle) == "function" then
            self.cells[i][j]:Recycle ()
          else
            self.cells[i][j]:Hide ()
          end
        end
      end
      self.cells[i] = {}
    end
  end

  t.GetCellY = function (self, i)
    local n = ceil (i)
    if n < 0 then n = 0 end
    if n > self.rows then n = self.rows end
    return - (self.rowPos[n] + (self.rowPos[n - 1] - self.rowPos[n]) * (n - i))
  end
  t.GetCellX = function (self, j)
    local n = ceil (j)
    if n < 0 then n = 0 end
    if n > self.cols then n = self.cols end
    return self.colPos[n] + (self.colPos[n - 1] - self.colPos[n]) * (n - j)
  end
  t.GetRowHeight = function (self, i)
    return self.rowPos[i] - self.rowPos[i - 1]
  end
  t.GetColumnWidth = function (self, j)
    return self.colPos[j] - self.colPos[j - 1]
  end
  t.AlignCell = function (self, i, j)
    local cell = self.cells[i][j]
    local x = cell.offsX or 0
    local y = cell.offsY or 0
    if cell.align == "FILL" then
      cell:SetPoint ("TOPLEFT", self, "TOPLEFT", self:GetCellX (j - 1) + x, self:GetCellY (i - 1) + y)
      cell:SetPoint ("BOTTOMRIGHT", self, "BOTTOMRIGHT", self:GetCellX (j) + x, self:GetCellY (i) + y)

    elseif cell.align == "TOPLEFT" then
      cell:SetPoint ("TOPLEFT", self, "TOPLEFT", self:GetCellX (j - 1) + 2 + x, self:GetCellY (i - 1) - 2 + y)
    elseif cell.align == "LEFT" then
      cell:SetPoint ("LEFT", self, "TOPLEFT", self:GetCellX (j - 1) + 2 + x, self:GetCellY (i - 0.5) + y)
    elseif cell.align == "BOTTOMLEFT" then
      cell:SetPoint ("BOTTOMLEFT", self, "TOPLEFT", self:GetCellX (j - 1) + 2 + x, self:GetCellY (i) + 2 + y)

    elseif cell.align == "TOP" then
      cell:SetPoint ("TOP", self, "TOPLEFT", self:GetCellX (j - 0.5) + x, self:GetCellY (j - 1) - 2 + y)
    elseif cell.align == "CENTER" then
      cell:SetPoint ("CENTER", self, "TOPLEFT", self:GetCellX (j - 0.5) + x, self:GetCellY (i - 0.5) + y)
    elseif cell.align == "BOTTOM" then
      cell:SetPoint ("BOTTOM", self, "TOPLEFT", self:GetCellX (j - 0.5) + x, self:GetCellY (j) + 2 + y)

    elseif cell.align == "TOPRIGHT" then
      cell:SetPoint ("TOPRIGHT", self, "TOPLEFT", self:GetCellX (j) - 2 + x, self:GetCellY (i - 1) - 2 + y)
    elseif cell.align == "RIGHT" then
      cell:SetPoint ("RIGHT", self, "TOPLEFT", self:GetCellX (j) - 2 + x, self:GetCellY (i - 0.5) + y)
    elseif cell.align == "BOTTOMRIGHT" then
      cell:SetPoint ("BOTTOMRIGHT", self, "TOPLEFT", self:GetCellX (j) - 2 + x, self:GetCellY (i) + 2 + y)
    end
  end
  t.OnUpdateFix = function (self)
    self:SetScript ("OnSizeChanged", nil)

    local numAutoRows = 0
    local totalHeight = 0
    for i = 0, self.rows do
      if self.rowHeight[i] == "AUTO" then
        numAutoRows = numAutoRows + 1
      else
        totalHeight = totalHeight + self.rowHeight[i]
      end
    end
    if numAutoRows == 0 then
      self:SetHeight (totalHeight)
    end
    local remHeight = self:GetHeight () - totalHeight
    for i = 0, self.rows do
      if self.rowHeight[i] == "AUTO" then
        self.rowPos[i] = self.rowPos[i - 1] + remHeight / numAutoRows
      else
        self.rowPos[i] = self.rowPos[i - 1] + self.rowHeight[i]
      end
    end
    local numAutoCols = 0
    local totalWidth = 0
    for i = 0, self.cols do
      if self.colWidth[i] == "AUTO" then
        numAutoCols = numAutoCols + 1
      else
        totalWidth = totalWidth + self.colWidth[i]
      end
    end
    if numAutoCols == 0 then
      self:SetWidth (totalWidth)
    end
    local remWidth = self:GetWidth () - totalWidth
    for i = 0, self.cols do
      if self.colWidth[i] == "AUTO" then
        self.colPos[i] = self.colPos[i - 1] + remWidth / numAutoCols
      else
        self.colPos[i] = self.colPos[i - 1] + self.colWidth[i]
      end
    end

    if self.gridColor then
      for i = -1, self.rows do
        self.hlines[i]:SetPos (0, self.colPos[self.cols], -self.rowPos[i])
      end
      for i = -1, self.cols do
        self.vlines[i]:SetPos (self.colPos[i], 0, -self.rowPos[self.rows])
      end
    end
    for i = -1, self.rows do
      for j = -1, self.cols do
        if self.cells[i][j] then
          self:AlignCell (i, j)
        end
      end
    end

    self:SetScript ("OnSizeChanged", function (self)
      RunNextFrame(function() self:OnUpdateFix() end)
    end)

    if self.OnUpdate then
      self:OnUpdate ()
    end
  end

  if gridColor then
    t.hlines = {}
    t.vlines = {}
    for i = -1, rows do
      t.hlines[i] = self:CreateHLine (0, 0, 0, 1.5, gridColor, t)
    end
    for i = -1, cols do
      t.vlines[i] = self:CreateVLine (0, 0, 0, 1.5, gridColor, t)
    end
    if firstRow == 0 then
      t.hlines[-1]:Hide ()
    end
    if firstColumn == 0 then
      t.vlines[-1]:Hide ()
    end
  end
  t.cells = {}
  for i = -1, rows do
    t.cells[i] = {}
  end

  for i = 1, t.rows do
    t.rowHeight[i] = "AUTO"
  end
  for j = 1, t.cols do
    t.colWidth[j] = "AUTO"
  end
  t:OnUpdateFix ()

  t:SetScript ("OnSizeChanged", function (self)
    RunNextFrame(function() self:OnUpdateFix() end)
  end)

  t.SetCell = function (self, i, j, value, align, offsX, offsY)
    align = align or "CENTER"
    self.cells[i][j] = value
    self.cells[i][j].align = align
    self.cells[i][j].offsX = offsX
    self.cells[i][j].offsY = offsY
    self:AlignCell (i, j)
  end
  t.textTagPool = {}
  t.SetCellText = function (self, i, j, text, align, color, font)
    align = align or "CENTER"
    color = color or addonTable.FONTS.white
    font = font or "GameFontNormalSmall"

    if self.cells[i][j] and not self.cells[i][j].istag then
      if type (self.cells[i][j].Recycle) == "function" then
        self.cells[i][j]:Recycle ()
      else
        self.cells[i][j]:Hide ()
      end
      self.cells[i][j] = nil
    end

    if self.cells[i][j] then
      self.cells[i][j]:SetFontObject (font)
      self.cells[i][j]:Show ()
    elseif #self.textTagPool > 0 then
      self.cells[i][j] = tremove (self.textTagPool)
      self.cells[i][j]:SetFontObject (font)
      self.cells[i][j]:Show ()
    else
      self.cells[i][j] = self:CreateFontString (nil, "OVERLAY", font)
      self.cells[i][j].Recycle = function (tag)
        tag:Hide ()
        tinsert (self.textTagPool, tag)
      end
    end
    self.cells[i][j].istag = true
    self.cells[i][j]:SetTextColor(color:GetRGB())
    self.cells[i][j]:SetText (text)
    self.cells[i][j].align = align
    self:AlignCell (i, j)
  end

  return t
end

function GUI.CreateStaticPopup(name, text, onAccept, opts)
  StaticPopupDialogs[name] = {
    text = text,
    button1 = (opts or {}).button1 or ACCEPT,
    button2 = CANCEL,
    hasEditBox = (opts or {}).hasEditBox,
    timeout = 0,
    whileDead = 1,
    OnAccept = function(self)
      onAccept(self)
    end,
    OnShow = function(self)
      if self:GetEditBox():IsVisible() then
        self:GetButton1():Disable()
        self:GetEditBox():SetFocus()
      end
      self:GetButton2():Enable()
    end,
    OnHide = function(self)
      ChatEdit_FocusActiveWindow()
      self:GetEditBox():SetText("")
    end,
    EditBoxOnEnterPressed = function(self)
      if self:GetParent():GetButton1():IsEnabled() then
        onAccept(self:GetText())
        self:GetParent():Hide()
      end
    end,
    EditBoxOnTextChanged = function(self)
      self:GetParent():GetButton1():SetEnabled(self:GetText() ~= "")
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  }
end

callbacks:RegisterCallback("PreCalculateStart", function(_, self) self:Lock() end, "GUI", GUI)
callbacks:RegisterCallback("OnCalculateFinish", function(_, self) self:Unlock() end, "GUI", GUI)
