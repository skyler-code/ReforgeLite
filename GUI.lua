local addonName, addonTable = ...
local GUI = {}

local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

GUI.widgetCount = 0
function GUI:GenerateWidgetName ()
  self.widgetCount = self.widgetCount + 1
  return addonName .. "Widget" .. self.widgetCount
end
GUI.defaultParent = nil

function GUI:ClearEditFocus()
  LibDD:CloseDropDownMenus()
  for _,v in ipairs(self.editBoxes) do
    v:ClearFocus()
  end
end

function GUI:ClearFocus()
  LibDD:CloseDropDownMenus()
  self:ClearEditFocus()
end

function GUI:Lock()
  for _, frames in ipairs({self.panelButtons, self.imgButtons, self.editBoxes, self.checkButtons}) do
    for _, frame in ipairs(frames) do
      if frame:IsEnabled() then
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
          frame:SetTextColor (0.5, 0.5, 0.5)
        end
      end
    end
  end
  for _, dropdown in ipairs(self.dropdowns) do
    if not dropdown.isDisabled then
      LibDD:UIDropDownMenu_DisableDropDown(dropdown)
      dropdown.locked = true
    end
  end
end

function GUI:Unlock()
  for _, frames in ipairs({self.panelButtons, self.imgButtons, self.editBoxes, self.checkButtons}) do
    for _, frame in ipairs(frames) do
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
          frame:SetTextColor (unpack(frame.prevColor))
          frame.prevColor = nil
        end
      end
    end
  end
  for _, dropdown in ipairs(self.dropdowns) do
    if dropdown.locked then
      LibDD:UIDropDownMenu_EnableDropDown(dropdown)
      dropdown.locked = nil
    end
  end
end

function GUI:SetTooltip (widget, tip)
  if tip then
    widget:SetScript ("OnEnter", function (self)
      GameTooltip:SetOwner (self, "ANCHOR_LEFT")
      GameTooltip:SetText (tip)
      GameTooltip:Show ()
    end)
    widget:SetScript ("OnLeave", function ()
      GameTooltip:Hide ()
    end)
  else
    widget:SetScript ("OnEnter", nil)
    widget:SetScript ("OnLeave", nil)
  end
end

GUI.editBoxes = {}
GUI.editBoxes.insert = tinsert
GUI.unusedEditBoxes = {}
function GUI:CreateEditBox (parent, width, height, default, setter)
  local box
  if #self.unusedEditBoxes > 0 then
    box = tremove (self.unusedEditBoxes, 1)
    box:SetParent (parent)
    box:Show ()
    box:SetTextColor (1, 1, 1)
    box:EnableMouse (true)
  else
    box = CreateFrame ("EditBox", self:GenerateWidgetName (), parent, "InputBoxTemplate")
    self.editBoxes:insert(box)
    box:SetAutoFocus (false)
    box:SetFontObject (ChatFontNormal)
    box:SetNumeric ()
    box:SetTextInsets (0, 0, 3, 3)
    box:SetMaxLetters (8)
    box:SetScript ("OnEnterPressed", box.ClearFocus)
    box:SetScript ("OnEditFocusGained", function(frame)
      LibDD:CloseDropDownMenus()
      frame.prevValue = tonumber(frame:GetText())
      frame:HighlightText()
    end)
    box.Recycle = function (box)
      box:Hide ()
      box:SetScript ("OnEditFocusLost", nil)
      box:SetScript ("OnEnter", nil)
      box:SetScript ("OnLeave", nil)
      tinsert (self.unusedEditBoxes, box)
    end
  end
  if width then
    box:SetWidth (width)
  end
  if height then
    box:SetHeight (height)
  end
  box:SetText (default)
  box:SetScript ("OnEditFocusLost", function (frame)
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
  return box
end


GUI.dropdowns = {}
GUI.dropdowns.insert = tinsert
GUI.unusedDropdowns = {}
function GUI:CreateDropdown (parent, values, options)
  local sel
  if #self.unusedDropdowns > 0 then
    sel = tremove (self.unusedDropdowns, 1)
    sel:SetParent (parent)
    sel:Show ()
  else
    sel = LibDD:Create_UIDropDownMenu(self:GenerateWidgetName(), parent)
    self.dropdowns:insert(sel)
    LibDD:UIDropDownMenu_SetInitializeFunction(sel, function (dropdown)
      self:ClearEditFocus()
      for _, value in ipairs(dropdown.values) do
        local info = LibDD:UIDropDownMenu_CreateInfo()
        info.text = value.name
        info.value = value.value
        info.checked = (dropdown.value == value.value)
        info.category = value.category
        info.func = function (inf)
          LibDD:UIDropDownMenu_SetSelectedValue (dropdown, inf.value)
          if dropdown.setter then dropdown.setter (dropdown,inf.value) end
          dropdown.value = inf.value
        end
        if dropdown.menuItemDisabled then
          info.disabled = dropdown.menuItemDisabled(info.value)
        end
        if not dropdown.menuItemHidden or not dropdown.menuItemHidden(info) then
          LibDD:UIDropDownMenu_AddButton(info)
        end
      end
    end)
    sel.SetValue = function (dropdown, value)
      dropdown.value = value
      dropdown.selectedValue = value
      for i = 1, #dropdown.values do
        if dropdown.values[i].value == value then
          LibDD:UIDropDownMenu_SetText (dropdown, dropdown.values[i].name)
          return
        end
      end
      LibDD:UIDropDownMenu_SetText (dropdown, "")
    end
    LibDD:UIDropDownMenu_JustifyText (sel, "LEFT")
    sel:SetHeight (50)
    sel.Left:SetHeight(50)
    sel.Middle:SetHeight(50)
    sel.Right:SetHeight(50)
    sel.Text:SetPoint ("LEFT", sel.Left, "LEFT", 27, 1)
    sel.Button:SetSize(22, 22)
    sel.Button:SetPoint ("TOPRIGHT", sel.Right, "TOPRIGHT", -16, -13)
    sel.Recycle = function (frame)
      frame:Hide ()
      frame:SetScript ("OnEnter", nil)
      frame:SetScript ("OnLeave", nil)
      frame.setter = nil
      frame.value = nil
      frame.selectedName = nil
      frame.selectedID = nil
      frame.selectedValue = nil
      frame.menuItemDisabled = nil
      frame.menuItemHidden = nil
      tinsert (self.unusedDropdowns, frame)
    end
  end
  sel.values = values
  sel.setter = options.setter
  sel.menuItemDisabled = options.menuItemDisabled
  sel.menuItemHidden = options.menuItemHidden

  LibDD:UIDropDownMenu_Initialize (sel, sel.Initialize)
  sel:SetValue (options.default)
  if options.width then
    LibDD:UIDropDownMenu_SetWidth (sel, options.width)
  end
  return sel
end

GUI.checkButtons = {}
GUI.checkButtons.insert = tinsert
GUI.unusedCheckButtons = {}
function GUI:CreateCheckButton (parent, text, default, setter)
  local btn
  if #self.unusedCheckButtons > 0 then
    btn = tremove (self.unusedCheckButtons, 1)
    btn:SetParent (parent)
    btn:Show ()
  else
    local name = self:GenerateWidgetName ()
    btn = CreateFrame ("CheckButton", name, parent, "UICheckButtonTemplate")
    self.checkButtons:insert(btn)
    btn.Recycle = function (btn)
      btn:Hide ()
      btn:SetScript ("OnEnter", nil)
      btn:SetScript ("OnLeave", nil)
      btn:SetScript ("OnClick", nil)
      tinsert (self.unusedCheckButtons, btn)
    end
  end
  btn.Text:SetText(text)
  btn:SetChecked (default)
  if setter then
    btn:SetScript ("OnClick", function (self)
      setter (self:GetChecked ())
    end)
  end
  return btn
end

GUI.imgButtons = {}
GUI.imgButtons.insert = tinsert
GUI.unusedImgButtons = {}
function GUI:CreateImageButton (parent, width, height, img, pus, hlt, disabledTexture, handler)
  local btn
  if #self.unusedImgButtons > 0 then
    btn = tremove (self.unusedImgButtons, 1)
    btn:SetParent (parent)
    btn:Show ()
  else
    local name = self:GenerateWidgetName ()
    btn = CreateFrame ("Button", name, parent)
    self.imgButtons:insert(btn)
    btn.Recycle = function (f)
      f:Hide ()
      f:SetScript ("OnEnter", nil)
      f:SetScript ("OnLeave", nil)
      f:SetScript ("OnClick", nil)
      tinsert (self.unusedImgButtons, f)
    end
  end
  btn:SetNormalTexture (img)
  btn:SetPushedTexture (pus)
  btn:SetHighlightTexture (hlt or img)
  btn:SetDisabledTexture(disabledTexture or img)
  btn:SetSize(width, height)
  if handler then
    btn:SetScript ("OnClick", handler)
  end
  return btn
end

GUI.panelButtons = {}
GUI.panelButtons.insert = tinsert
GUI.unusedPanelButtons = {}
function GUI:CreatePanelButton(parent, text, handler)
  local btn
  if #self.unusedPanelButtons > 0 then
    btn = tremove(self.unusedPanelButtons, 1)
    btn:SetParent(parent)
    btn:Show()
  else
    local name = self:GenerateWidgetName ()
    btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    self.panelButtons:insert(btn)
    btn.Recycle = function (f)
      f:SetText("")
      f:Hide ()
      f:SetScript ("OnEnter", nil)
      f:SetScript ("OnLeave", nil)
      f:SetScript ("OnPreClick", nil)
      f:SetScript ("OnClick", nil)
      tinsert (self.unusedPanelButtons, f)
    end
    btn.RenderText = function(f, ...)
      f:SetText(...)
      f:SetSize(f:GetFontString():GetStringWidth() + 20, 22)
    end
  end
  btn:RenderText(text)
  btn:SetScript("OnClick", handler)
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
  box.glow:SetColorTexture (1, 1, 1, 0.3)
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
        if h == 0 then
          self.hlines[-1]:Hide ()
        else
          self.hlines[-1]:Show ()
        end
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
        if w == 0 then
          self.vlines[-1]:Hide ()
        else
          self.vlines[-1]:Show ()
        end
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
    local x = self.cells[i][j].offsX or 0
    local y = self.cells[i][j].offsY or 0
    if self.cells[i][j].align == "FILL" then
      self.cells[i][j]:SetPoint ("TOPLEFT", self, "TOPLEFT", self:GetCellX (j - 1) + x, self:GetCellY (i - 1) + y)
      self.cells[i][j]:SetPoint ("BOTTOMRIGHT", self, "BOTTOMRIGHT", self:GetCellX (j) + x, self:GetCellY (i) + y)

    elseif self.cells[i][j].align == "TOPLEFT" then
      self.cells[i][j]:SetPoint ("TOPLEFT", self, "TOPLEFT", self:GetCellX (j - 1) + 2 + x, self:GetCellY (i - 1) - 2 + y)
    elseif self.cells[i][j].align == "LEFT" then
      self.cells[i][j]:SetPoint ("LEFT", self, "TOPLEFT", self:GetCellX (j - 1) + 2 + x, self:GetCellY (i - 0.5) + y)
    elseif self.cells[i][j].align == "BOTTOMLEFT" then
      self.cells[i][j]:SetPoint ("BOTTOMLEFT", self, "TOPLEFT", self:GetCellX (j - 1) + 2 + x, self:GetCellY (i) + 2 + y)

    elseif self.cells[i][j].align == "TOP" then
      self.cells[i][j]:SetPoint ("TOP", self, "TOPLEFT", self:GetCellX (j - 0.5) + x, self:GetCellY (j - 1) - 2 + y)
    elseif self.cells[i][j].align == "CENTER" then
      self.cells[i][j]:SetPoint ("CENTER", self, "TOPLEFT", self:GetCellX (j - 0.5) + x, self:GetCellY (i - 0.5) + y)
    elseif self.cells[i][j].align == "BOTTOM" then
      self.cells[i][j]:SetPoint ("BOTTOM", self, "TOPLEFT", self:GetCellX (j - 0.5) + x, self:GetCellY (j) + 2 + y)

    elseif self.cells[i][j].align == "TOPRIGHT" then
      self.cells[i][j]:SetPoint ("TOPRIGHT", self, "TOPLEFT", self:GetCellX (j) - 2 + x, self:GetCellY (i - 1) - 2 + y)
    elseif self.cells[i][j].align == "RIGHT" then
      self.cells[i][j]:SetPoint ("RIGHT", self, "TOPLEFT", self:GetCellX (j) - 2 + x, self:GetCellY (i - 0.5) + y)
    elseif self.cells[i][j].align == "BOTTOMRIGHT" then
      self.cells[i][j]:SetPoint ("BOTTOMRIGHT", self, "TOPLEFT", self:GetCellX (j) - 2 + x, self:GetCellY (i) + 2 + y)
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

    if self.onUpdate then
      self.onUpdate ()
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
    color = color or {1, 1, 1}
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
      self.cells[i][j] = tremove (self.textTagPool, 1)
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
    self.cells[i][j]:SetTextColor (unpack(color))
    self.cells[i][j]:SetText (text)
    self.cells[i][j].align = align
    self:AlignCell (i, j)
  end

  return t
end

addonTable.GUI = GUI