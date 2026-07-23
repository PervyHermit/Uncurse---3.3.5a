local U = Uncurse

local TYPE_ORDER = {"Magic", "Curse", "Disease", "Poison"}

local function Label(parent, text, x, y, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local checkIndex = 0
local function CreateCheck(parent, text, x, y, onClick)
    checkIndex = checkIndex + 1
    local name = "UncurseOptionCheck" .. checkIndex
    local check = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y)
    local label = _G[name .. "Text"]
    label:SetText(text)
    check.Text = label
    check:SetScript("OnClick", onClick)
    return check
end

local function CreateSlider(parent, name, text, minValue, maxValue, step, x, y, onChanged)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(160)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + .5) * step
        _G[name .. "Text"]:SetText(text .. ": " .. value)
        onChanged(value)
    end)
    _G[name .. "Low"]:SetText(minValue)
    _G[name .. "High"]:SetText(maxValue)
    return slider
end

local function SetEnabledText(edit)
    if U.SpellExists(edit:GetText()) then edit:SetTextColor(.25, 1, .35)
    elseif edit:GetText() == "" then edit:SetTextColor(1, 1, 1)
    else edit:SetTextColor(1, .25, .25) end
end

local function CommitSpell(row)
    local text = row.edit:GetText()
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    row.edit:SetText(text)
    U.db.bindings[row.index].spell = text
    SetEnabledText(row.edit)
    U:ApplyLayout()
end

local function GetBindingType(binding)
    for _, cureType in ipairs(TYPE_ORDER) do
        if binding.types[cureType] then return cureType end
    end
    return TYPE_ORDER[1]
end

local function SetBindingType(index, cureType)
    U.db.bindings[index].types = {[cureType] = true}
    U:ApplyLayout()
end

local function CreateBindingRow(parent, index, y)
    local binding = U.db.bindings[index]
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 14, y)
    row:SetSize(590, 72)
    row.index = index

    Label(row, binding.label, 0, -5, "GameFontNormalSmall")
    local edit = CreateFrame("EditBox", "UncurseSpellEdit" .. index, row, "InputBoxTemplate")
    edit:SetPoint("TOPLEFT", 110, 0)
    edit:SetSize(260, 22)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(80)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusLost", function() CommitSpell(row) end)
    row.edit = edit

    local fieldBackground = row:CreateTexture(nil, "BACKGROUND")
    fieldBackground:SetPoint("TOPLEFT", edit, "TOPLEFT", -2, 0)
    fieldBackground:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", 2, 0)
    fieldBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
    fieldBackground:SetVertexColor(.015, .015, .015, .9)

    local detect = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    detect:SetPoint("LEFT", edit, "RIGHT", 10, 0)
    detect:SetSize(82, 22)
    detect:SetText("Auto-detect")
    detect:SetScript("OnClick", function()
        CommitSpell(row)
        local found, spellFound = U:ScanSpellTooltip(U.db.bindings[index].spell)
        if not spellFound then
            U.Print("spell not found in your spellbook; check its exact name.")
            return
        end

        local detected = {}
        for _, cureType in ipairs(TYPE_ORDER) do
            if found[cureType] then table.insert(detected, cureType) end
        end

        if #detected == 1 then
            SetBindingType(index, detected[1])
            UIDropDownMenu_SetText(row.typeDropdown, detected[1])
            U.Print("detected cure type: " .. detected[1] .. ".")
        elseif #detected > 1 then
            U.Print("tooltip mentions " .. table.concat(detected, ", ") .. "; please choose the intended type.")
        else
            U.Print("no cure type found in the tooltip; please choose it manually.")
        end
    end)

    Label(row, "Cure type", 110, -37, "GameFontHighlightSmall")
    local dropdown = CreateFrame("Frame", "UncurseBindingTypeDropdown" .. index, row, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 174, -22)
    UIDropDownMenu_SetWidth(dropdown, 130)
    UIDropDownMenu_Initialize(dropdown, function()
        for _, cureType in ipairs(TYPE_ORDER) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = cureType
            info.checked = GetBindingType(U.db.bindings[index]) == cureType
            info.func = function()
                SetBindingType(index, cureType)
                UIDropDownMenu_SetText(dropdown, cureType)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    row.typeDropdown = dropdown
    return row
end

local panel = CreateFrame("Frame", "UncurseOptionsPanel", UIParent)
panel.name = "Uncurse"
U.options = panel

Label(panel, "Uncurse", 16, -16, "GameFontNormalLarge")
Label(panel, "Custom-spell click-to-cure frames for WoW 3.3.5a", 16, -42, "GameFontHighlightSmall")

panel.enabledCheck = CreateCheck(panel, "Enable Uncurse", 16, -67, function(self)
    U.db.enabled = self:GetChecked() and true or false
    U:ApplyLayout()
end)
panel.lockCheck = CreateCheck(panel, "Lock frames", 180, -67, function(self)
    U:SetLocked(self:GetChecked())
end)
panel.soloCheck = CreateCheck(panel, "Show while solo", 330, -67, function(self)
    U.db.showSolo = self:GetChecked() and true or false
    U:ApplyLayout()
end)

Label(panel, "Appearance", 16, -110)
panel.sizeSlider = CreateSlider(panel, "UncurseSizeSlider", "Frame size", 8, 50, 1, 20, -137, function(value)
    if U.db.size ~= value then U.db.size = value; U:ApplyLayout() end
end)
panel.spacingSlider = CreateSlider(panel, "UncurseSpacingSlider", "Spacing", 0, 12, 1, 230, -137, function(value)
    if U.db.spacing ~= value then U.db.spacing = value; U:ApplyLayout() end
end)
panel.columnsSlider = CreateSlider(panel, "UncurseColumnsSlider", "Columns", 1, 10, 1, 440, -137, function(value)
    if U.db.columns ~= value then U.db.columns = value; U:ApplyLayout() end
end)
panel.alphaSlider = CreateSlider(panel, "UncurseAlphaSlider", "Idle opacity %", 1, 100, 1, 20, -194, function(value)
    local alpha = value / 100
    if U.db.inactiveAlpha ~= alpha then U.db.inactiveAlpha = alpha; U:RefreshAll() end
end)
panel.activeSlider = CreateSlider(panel, "UncurseActiveSlider", "Active opacity %", 20, 100, 1, 230, -194, function(value)
    local alpha = value / 100
    if U.db.activeAlpha ~= alpha then U.db.activeAlpha = alpha; U:RefreshAll() end
end)

panel.namesCheck = CreateCheck(panel, "Show abbreviated names", 440, -192, function(self)
    U.db.showNames = self:GetChecked() and true or false
    U:RefreshAll()
end)
panel.tooltipCheck = CreateCheck(panel, "Show frame tooltips", 440, -220, function(self)
    U.db.showTooltip = self:GetChecked() and true or false
end)
panel.minimapCheck = CreateCheck(panel, "Hide minimap button", 440, -248, function(self)
    U.db.minimap.hide = self:GetChecked() and true or false
    if U.db.minimap.hide then U.minimapButton:Hide() else U.minimapButton:Show() end
end)

Label(panel, "Click bindings and curable types", 16, -263)
Label(panel, "Enter the exact spellbook name. Auto-detect inspects its tooltip; verify the selected type.", 16, -285, "GameFontHighlightSmall")

panel.bindingRows = {}
for index = 1, 3 do
    panel.bindingRows[index] = CreateBindingRow(panel, index, -310 - (index - 1) * 75)
end

local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetPoint("BOTTOMLEFT", 16, 18)
reset:SetSize(115, 24)
reset:SetText("Reset position")
reset:SetScript("OnClick", function()
    U.db.point, U.db.relativePoint, U.db.x, U.db.y = "CENTER", "CENTER", 0, -120
    U:ApplyPosition()
end)

local note = Label(panel, "Changes to spells or layout made during combat take effect when combat ends.", 150, -570, "GameFontHighlightSmall")
note:SetTextColor(1, .75, .25)

function U:RefreshOptions()
    if not self.db then return end
    panel.enabledCheck:SetChecked(self.db.enabled)
    panel.lockCheck:SetChecked(self.db.locked)
    panel.soloCheck:SetChecked(self.db.showSolo)
    panel.namesCheck:SetChecked(self.db.showNames)
    panel.tooltipCheck:SetChecked(self.db.showTooltip)
    panel.minimapCheck:SetChecked(self.db.minimap.hide)
    panel.sizeSlider:SetValue(self.db.size)
    panel.spacingSlider:SetValue(self.db.spacing)
    panel.columnsSlider:SetValue(self.db.columns)
    panel.alphaSlider:SetValue(math.floor(self.db.inactiveAlpha * 100 + .5))
    panel.activeSlider:SetValue(math.floor(self.db.activeAlpha * 100 + .5))
    for index, row in ipairs(panel.bindingRows) do
        local binding = self.db.bindings[index]
        row.edit:SetText(binding.spell or "")
        SetEnabledText(row.edit)
        UIDropDownMenu_SetText(row.typeDropdown, GetBindingType(binding))
    end
end

panel:SetScript("OnShow", function() U:RefreshOptions() end)
InterfaceOptions_AddCategory(panel)

local advanced = CreateFrame("Frame", "UncurseAdvancedOptionsPanel", UIParent)
advanced.name = "Colors & Layout"
advanced.parent = "Uncurse"
Label(advanced, "Colors & Layout", 16, -16, "GameFontNormalLarge")
Label(advanced, "Additional layout and indicator color controls.", 16, -42, "GameFontHighlightSmall")

Label(advanced, "Growth direction", 16, -82)
local growth = CreateFrame("Frame", "UncurseGrowthDropdown", advanced, "UIDropDownMenuTemplate")
growth:SetPoint("TOPLEFT", 130, -67)
UIDropDownMenu_SetWidth(growth, 120)
local growthLabels = { DOWN = "Down", UP = "Up", LEFT = "Left", RIGHT = "Right" }
UIDropDownMenu_Initialize(growth, function()
    for _, direction in ipairs({"DOWN", "UP", "LEFT", "RIGHT"}) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = growthLabels[direction]
        info.checked = U.db.growth == direction
        info.func = function()
            U.db.growth = direction
            UIDropDownMenu_SetText(growth, growthLabels[direction])
            CloseDropDownMenus()
            U:ApplyLayout()
        end
        UIDropDownMenu_AddButton(info)
    end
end)

Label(advanced, "Debuff colors", 16, -132)
local colorButtons = {}
local function RefreshColorButton(button, cureType)
    local color = U.db.colors[cureType]
    button.texture:SetVertexColor(color[1], color[2], color[3], 1)
end

local function OpenColor(cureType, button)
    local color = U.db.colors[cureType]
    local old = {color[1], color[2], color[3]}
    local function ApplyColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        color[1], color[2], color[3] = r, g, b
        RefreshColorButton(button, cureType)
        U:RefreshAll()
    end
    ColorPickerFrame.func = ApplyColor
    ColorPickerFrame.opacityFunc = nil
    ColorPickerFrame.cancelFunc = function()
        color[1], color[2], color[3] = old[1], old[2], old[3]
        RefreshColorButton(button, cureType)
        U:RefreshAll()
    end
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame:SetColorRGB(color[1], color[2], color[3])
    ColorPickerFrame:Show()
end

for index, cureType in ipairs(TYPE_ORDER) do
    local button = CreateFrame("Button", nil, advanced)
    button:SetPoint("TOPLEFT", 18 + (index - 1) * 112, -158)
    button:SetSize(102, 28)
    local texture = button:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.texture = texture
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetText(cureType)
    text:SetTextColor(1, 1, 1)
    button:SetScript("OnClick", function() OpenColor(cureType, button) end)
    colorButtons[cureType] = button
end

advanced:SetScript("OnShow", function()
    UIDropDownMenu_SetText(growth, growthLabels[U.db.growth] or U.db.growth)
    for cureType, button in pairs(colorButtons) do RefreshColorButton(button, cureType) end
end)
InterfaceOptions_AddCategory(advanced)

function U:OpenOptions()
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end
