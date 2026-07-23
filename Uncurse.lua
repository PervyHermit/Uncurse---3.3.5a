local ADDON_NAME = ...

Uncurse = Uncurse or {}
local U = Uncurse

local floor, max, min = math.floor, math.max, math.min
local pairs, ipairs, type, tonumber = pairs, ipairs, type, tonumber
local tinsert, tremove = table.insert, table.remove
local CURE_TYPES = {"Magic", "Curse", "Disease", "Poison"}

U.version = "1.1.0"
U.frames = {}
U.unitOrder = {}
U.pendingSecureUpdate = false
U.pendingLayout = false
U.pendingPosition = false
U.pendingLocked = false

local DEFAULTS = {
    enabled = true,
    locked = false,
    showSolo = true,
    showNames = false,
    showTooltip = true,
    size = 18,
    spacing = 2,
    columns = 5,
    growth = "DOWN",
    inactiveAlpha = 0.08,
    activeAlpha = 0.95,
    outOfRangeAlpha = 0.45,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = -120,
    minimap = {
        hide = false,
        angle = 220,
    },
    colors = {
        Magic = {0.20, 0.55, 1.00},
        Curse = {0.65, 0.20, 1.00},
        Disease = {0.75, 0.45, 0.10},
        Poison = {0.15, 0.85, 0.20},
    },
    bindings = {
        { click = "LeftButton", label = "Left click", spell = "", types = { Magic = true } },
        { click = "RightButton", label = "Right click", spell = "", types = { Curse = true } },
        { click = "MiddleButton", label = "Middle click", spell = "", types = { Poison = true } },
    },
}

local function CopyDefaults(source, destination)
    if type(destination) ~= "table" then destination = {} end
    for key, value in pairs(source) do
        if type(value) == "table" then
            destination[key] = CopyDefaults(value, destination[key])
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
    return destination
end

local function NormalizeBindings(database)
    local bindings = database.bindings
    for index = 1, 3 do
        local binding = bindings[index]
        local defaultBinding = DEFAULTS.bindings[index]
        local defaultType
        for cureType in pairs(defaultBinding.types) do defaultType = cureType end

        local selectedType
        if binding.spell and binding.spell ~= "" then
            local nonDefault
            local nonDefaultCount = 0
            for _, cureType in ipairs(CURE_TYPES) do
                if binding.types[cureType] and cureType ~= defaultType then
                    nonDefault = cureType
                    nonDefaultCount = nonDefaultCount + 1
                end
            end
            if nonDefaultCount == 1 then
                selectedType = nonDefault
            elseif binding.types[defaultType] then
                selectedType = defaultType
            end
        end
        if not selectedType and (not binding.spell or binding.spell == "") then
            selectedType = defaultType
        end
        if not selectedType then
            for _, cureType in ipairs(CURE_TYPES) do
                if binding.types[cureType] then selectedType = cureType; break end
            end
        end

        binding.click = defaultBinding.click
        binding.label = defaultBinding.label
        binding.types = {[selectedType or defaultType] = true}
    end
    for index = #bindings, 4, -1 do bindings[index] = nil end
end

-- Saved variables are available while addon files load. Initialize here so the
-- options file can safely construct controls before ADDON_LOADED fires.
UncurseDB = CopyDefaults(DEFAULTS, UncurseDB)
NormalizeBindings(UncurseDB)
U.db = UncurseDB

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff67d5ffUncurse:|r " .. tostring(message))
end
U.Print = Print

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function SnapshotConfiguration()
    local bindings = {}
    for index, source in ipairs(U.db.bindings) do
        local binding = {
            click = source.click,
            label = source.label,
            spell = source.spell,
            types = {},
        }
        for cureType, enabled in pairs(source.types) do
            if enabled then binding.types[cureType] = true end
        end
        bindings[index] = binding
    end

    U.appliedBindings = bindings
    U.appliedEnabled = U.db.enabled
end

local function GetBindingForType(debuffType, debuffName)
    local bindings = U.appliedBindings or U.db.bindings
    if not debuffType or debuffType == "" then return end

    for index, binding in ipairs(bindings) do
        if binding.spell ~= "" and binding.types[debuffType] then
            return index, binding, debuffType
        end
    end
end

local function FindSpellBookSlot(spellName)
    if not spellName or spellName == "" then return end
    local wanted = string.lower(spellName)
    for tab = 1, MAX_SKILLLINE_TABS do
        local _, _, offset, count = GetSpellTabInfo(tab)
        if not offset then break end
        for slot = offset + 1, offset + count do
            local name = GetSpellName(slot, BOOKTYPE_SPELL)
            if name and string.lower(name) == wanted then return slot end
        end
    end
end

local function SpellExists(spellName)
    return FindSpellBookSlot(spellName) ~= nil
end
U.SpellExists = SpellExists

function U:ScanSpellTooltip(spellName)
    local found = {}
    local spellIndex = FindSpellBookSlot(spellName)
    if not spellIndex then return found, false end

    if not self.scanTooltip then
        self.scanTooltip = CreateFrame("GameTooltip", "UncurseScanTooltip", nil, "GameTooltipTemplate")
    end
    self.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    self.scanTooltip:ClearLines()
    local populated = self.scanTooltip.SetSpell and pcall(self.scanTooltip.SetSpell, self.scanTooltip, spellIndex, BOOKTYPE_SPELL)
    if not populated or self.scanTooltip:NumLines() == 0 then
        local link = GetSpellLink and GetSpellLink(spellIndex, BOOKTYPE_SPELL)
        if link then self.scanTooltip:SetHyperlink(link) end
    end

    local keywords = {
        Magic = {"magic", "magical", "dispel"},
        Curse = {"curse", "hex"},
        Disease = {"disease", "plague"},
        Poison = {"poison", "venom", "toxin"},
    }
    local scanText = string.lower(spellName)
    local regions = {self.scanTooltip:GetRegions()}
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            local text = region:GetText()
            if text then scanText = scanText .. "\n" .. string.lower(text) end
        end
    end
    for cureType, words in pairs(keywords) do
        for _, word in ipairs(words) do
            if string.find(scanText, word, 1, true) then
                found[cureType] = true
            end
        end
    end
    return found, true
end

local function BuildUnitOrder()
    local order = U.unitOrder
    for i = #order, 1, -1 do tremove(order, i) end

    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do tinsert(order, "raid" .. i) end
    elseif GetNumPartyMembers() > 0 then
        tinsert(order, "player")
        for i = 1, GetNumPartyMembers() do tinsert(order, "party" .. i) end
    elseif U.db.showSolo then
        tinsert(order, "player")
    end
end

local function ButtonAttributeNames(click)
    if click == "LeftButton" then return "type1", "spell1" end
    if click == "RightButton" then return "type2", "spell2" end
    if click == "MiddleButton" then return "type3", "spell3" end
    if click == "Button4" then return "type4", "spell4" end
    if click == "Button5" then return "type5", "spell5" end
    local modifier, button = string.match(click, "^(.-)%-(.+)$")
    if modifier and button then
        local typeName, spellName = ButtonAttributeNames(button)
        if typeName then return modifier .. "-" .. typeName, modifier .. "-" .. spellName end
    end
end

local function ApplySecureAttributes(button, unit)
    if InCombat() then
        U.pendingSecureUpdate = true
        return
    end

    button:SetAttribute("unit", unit)
    button:SetAttribute("type1", nil)
    button:SetAttribute("type2", nil)
    button:SetAttribute("type3", nil)
    button:SetAttribute("type4", nil)
    button:SetAttribute("type5", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("spell2", nil)
    button:SetAttribute("spell3", nil)
    button:SetAttribute("spell4", nil)
    button:SetAttribute("spell5", nil)
    button:SetAttribute("shift-type1", nil)
    button:SetAttribute("shift-spell1", nil)
    button:SetAttribute("ctrl-type1", nil)
    button:SetAttribute("ctrl-spell1", nil)
    button:SetAttribute("alt-type1", nil)
    button:SetAttribute("alt-spell1", nil)

    for _, binding in ipairs(U.appliedBindings or U.db.bindings) do
        local typeName, spellName = ButtonAttributeNames(binding.click)
        if typeName and binding.spell and binding.spell ~= "" then
            button:SetAttribute(typeName, "spell")
            button:SetAttribute(spellName, binding.spell)
        end
    end
end

local function OnButtonEnter(self)
    if not U.db.showTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    local name = UnitName(self.unit) or self.unit
    GameTooltip:AddLine(name, 1, 1, 1)

    local foundAny
    for i = 1, 40 do
        local debuffName, _, _, count, debuffType, duration, expiration = UnitDebuff(self.unit, i)
        if not debuffName then break end
        local _, binding, resolvedType = GetBindingForType(debuffType, debuffName)
        if binding then
            foundAny = true
            local color = U.db.colors[resolvedType] or {1, .2, .2}
            local remaining = expiration and expiration > 0 and max(0, expiration - GetTime())
            local suffix = count and count > 1 and (" x" .. count) or ""
            if remaining then suffix = suffix .. string.format(" (%.1fs)", remaining) end
            GameTooltip:AddDoubleLine(debuffName .. suffix, binding.label, color[1], color[2], color[3], .8, .8, .8)
            GameTooltip:AddLine("Casts: " .. binding.spell, .65, .85, 1)
        end
    end
    if not foundAny then GameTooltip:AddLine("No configured curable debuff", .55, .55, .55) end
    GameTooltip:Show()
end

local function CreateUnitButton(index)
    local button = CreateFrame("Button", "UncurseUnitButton" .. index, U.anchor, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp")
    button:SetFrameStrata("MEDIUM")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.background:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.background:SetVertexColor(.15, .15, .15, 1)

    button.highlight = button:CreateTexture(nil, "ARTWORK")
    button.highlight:SetPoint("CENTER")
    button.highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.highlight:SetVertexColor(1, 1, 1, 1)

    button.shadow = button:CreateTexture(nil, "BORDER")
    button.shadow:SetPoint("CENTER", 1, -1)
    button.shadow:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.shadow:SetVertexColor(0, 0, 0, .9)

    button.pattern = button:CreateTexture(nil, "OVERLAY")
    button.pattern:SetPoint("CENTER")
    button.pattern:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    button.pattern:SetBlendMode("ADD")
    button.pattern:SetAlpha(.18)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetPoint("CENTER")
    button.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.border:SetBlendMode("ADD")
    button.border:SetAlpha(0)

    button.nameText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.nameText:SetPoint("CENTER")
    button.nameText:SetJustifyH("CENTER")

    button:RegisterEvent("UNIT_AURA")
    button:RegisterEvent("UNIT_HEALTH")
    button:SetScript("OnEvent", function(self, event, unit)
        if not unit or unit == self.unit then U:UpdateButton(self) end
    end)
    button:SetScript("OnEnter", OnButtonEnter)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    U.frames[index] = button
    return button
end

function U:UpdateButton(button)
    if not button.unit or not UnitExists(button.unit) or not self.appliedEnabled then
        button:SetAlpha(InCombat() and .01 or 0)
        if not InCombat() then button:Hide() end
        return
    end

    local bestBinding, bestType, bestName
    for i = 1, 40 do
        local debuffName, _, _, _, debuffType = UnitDebuff(button.unit, i)
        if not debuffName then break end
        local bindingIndex, _, resolvedType = GetBindingForType(debuffType, debuffName)
        if bindingIndex and (not bestBinding or bindingIndex < bestBinding) then
            bestBinding, bestType, bestName = bindingIndex, resolvedType, debuffName
        end
    end

    if bestBinding then
        local color = self.db.colors[bestType] or {1, .2, .2}
        button.highlight:SetVertexColor(color[1], color[2], color[3], 1)
        button:SetAlpha(self.db.activeAlpha)
        button.shadow:SetAlpha(.9)
        button.pattern:SetAlpha(.18)
        button.border:SetAlpha(.75)
        button.activeDebuff = bestName
        button.activeType = bestType
        if UnitIsDeadOrGhost(button.unit) or not UnitIsConnected(button.unit) then
            button:SetAlpha(.25)
        elseif IsSpellInRange and IsSpellInRange(self.appliedBindings[bestBinding].spell, button.unit) == 0 then
            button:SetAlpha(self.db.outOfRangeAlpha)
        end
        button.activeBinding = bestBinding
        if not InCombat() then button:Show() end
    else
        button.highlight:SetVertexColor(.12, .12, .12, 1)
        button.shadow:SetAlpha(.35)
        button.pattern:SetAlpha(.06)
        button.border:SetAlpha(0)
        button.activeDebuff = nil
        button.activeType = nil
        button.activeBinding = nil
        button:SetAlpha(max(.01, self.db.inactiveAlpha))
        if not InCombat() then button:Show() end
    end

    if self.db.showNames then
        local name = UnitName(button.unit) or ""
        button.nameText:SetText(string.sub(name, 1, 4))
        button.nameText:Show()
    else
        button.nameText:Hide()
    end
end

function U:ApplyLayout()
    if InCombat() then
        self.pendingLayout = true
        return
    end
    SnapshotConfiguration()
    BuildUnitOrder()

    local size, spacing, columns = self.db.size, self.db.spacing, self.db.columns
    local count = #self.unitOrder
    local rows = max(1, math.ceil(count / columns))
    local visibleColumns = max(1, min(columns, count))
    local horizontal = self.db.growth == "LEFT" or self.db.growth == "RIGHT"
    local widthUnits = horizontal and rows or visibleColumns
    local heightUnits = horizontal and visibleColumns or rows
    local width = widthUnits * size + max(0, widthUnits - 1) * spacing
    local height = heightUnits * size + max(0, heightUnits - 1) * spacing
    self.anchor:SetSize(max(size, width), max(size, height))

    for index = 1, 40 do
        local button = self.frames[index] or CreateUnitButton(index)
        local unit = self.unitOrder[index]
        button:ClearAllPoints()
        button:SetSize(size, size)
        local indicatorSize = max(4, floor(size * .75 + .5))
        button.highlight:SetSize(indicatorSize, indicatorSize)
        button.pattern:SetSize(indicatorSize, indicatorSize)
        button.shadow:SetSize(min(size, indicatorSize + 3), min(size, indicatorSize + 3))
        button.border:SetSize(min(size, indicatorSize + 5), min(size, indicatorSize + 5))
        if unit then
            local col = (index - 1) % columns
            local row = floor((index - 1) / columns)
            local x = col * (size + spacing)
            local y = -row * (size + spacing)
            if self.db.growth == "UP" then
                y = -(rows - 1 - row) * (size + spacing)
            elseif self.db.growth == "LEFT" then
                x, y = (rows - 1 - row) * (size + spacing), -col * (size + spacing)
            elseif self.db.growth == "RIGHT" then
                x, y = row * (size + spacing), -col * (size + spacing)
            end
            button:SetPoint("TOPLEFT", self.anchor, "TOPLEFT", x, y)
            button.unit = unit
            ApplySecureAttributes(button, unit)
            button:Show()
            self:UpdateButton(button)
        else
            button.unit = nil
            button:Hide()
        end
    end
    self.pendingLayout = false
    self.pendingSecureUpdate = false
end

function U:RefreshAll()
    for _, button in ipairs(self.frames) do self:UpdateButton(button) end
end

function U:RefreshRange()
    for _, button in ipairs(self.frames) do
        if button.activeBinding and button.unit and UnitExists(button.unit) then
            if UnitIsDeadOrGhost(button.unit) or not UnitIsConnected(button.unit) then
                button:SetAlpha(.25)
            else
                local binding = self.appliedBindings and self.appliedBindings[button.activeBinding]
                if binding and IsSpellInRange and IsSpellInRange(binding.spell, button.unit) == 0 then
                    button:SetAlpha(self.db.outOfRangeAlpha)
                else
                    button:SetAlpha(self.db.activeAlpha)
                end
            end
        end
    end
end

function U:ApplyPosition()
    if InCombat() then
        self.pendingPosition = true
        return
    end
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint(self.db.point, UIParent, self.db.relativePoint, self.db.x, self.db.y)
    self.pendingPosition = false
end

local function ApplyLockState()
    U.anchor:EnableMouse(not U.db.locked)
    if U.db.locked then U.anchor.handle:Hide() else U.anchor.handle:Show() end
    if U.options and U.options.lockCheck then U.options.lockCheck:SetChecked(U.db.locked) end
    U.pendingLocked = false
end

function U:SetLocked(locked)
    self.db.locked = locked and true or false
    if InCombat() then
        self.pendingLocked = true
        Print("lock change will apply when combat ends.")
        return
    end
    ApplyLockState()
    Print(self.db.locked and "frames locked." or "frames unlocked; drag the blue handle to move.")
end

local function SavePosition()
    local point, _, relativePoint, x, y = U.anchor:GetPoint(1)
    U.db.point, U.db.relativePoint = point, relativePoint
    U.db.x, U.db.y = floor(x + .5), floor(y + .5)
end

local function CreateAnchor()
    local anchor = CreateFrame("Frame", "UncurseAnchor", UIParent)
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function(self)
        if InCombat() then
            Print("frames cannot be moved during combat.")
        elseif not U.db.locked then
            self:StartMoving()
        end
    end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    local handle = CreateFrame("Frame", nil, anchor)
    handle:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 3)
    handle:SetSize(54, 14)
    local bg = handle:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(.1, .55, .85, .85)
    local text = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetText("Uncurse")
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if InCombat() then
            Print("frames cannot be moved during combat.")
        elseif not U.db.locked then
            anchor:StartMoving()
        end
    end)
    handle:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        SavePosition()
    end)
    anchor.handle = handle
    U.anchor = anchor
end

local function MinimapPosition()
    local angle = math.rad(U.db.minimap.angle or 220)
    U.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function CreateMinimapButton()
    local button = CreateFrame("Button", "UncurseMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Spell_Holy_DispelMagic")
    icon:SetTexCoord(.08, .92, .08, .92)

    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            px, py = px / scale, py / scale
            U.db.minimap.angle = math.deg(math.atan2(py - my, px - mx))
            MinimapPosition()
        end)
    end)
    button:SetScript("OnDragStop", function() button:SetScript("OnUpdate", nil) end)
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then U:SetLocked(not U.db.locked)
        else U:OpenOptions() end
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Uncurse", .4, .85, 1)
        GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: lock/unlock", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    U.minimapButton = button
    MinimapPosition()
    if U.db.minimap.hide then button:Hide() end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        UncurseDB = CopyDefaults(DEFAULTS, UncurseDB)
        NormalizeBindings(UncurseDB)
        U.db = UncurseDB
        CreateAnchor()
        U:ApplyPosition()
        CreateMinimapButton()
        U:SetLocked(U.db.locked)
        U:ApplyLayout()
    elseif event == "PLAYER_LOGIN" then
        U:ApplyLayout()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if U.pendingPosition then U:ApplyPosition() end
        if U.pendingLocked then
            ApplyLockState()
            Print(U.db.locked and "frames locked." or "frames unlocked; drag the blue handle to move.")
        end
        if U.pendingLayout or U.pendingSecureUpdate then U:ApplyLayout() end
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        if InCombat() then
            U.pendingLayout = true
            U:RefreshAll()
        else
            U:ApplyLayout()
        end
    elseif event == "SPELLS_CHANGED" and U.options and U.options:IsShown() then
        U:RefreshOptions()
    end
end)

local rangeElapsed = 0
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed >= .25 then
        rangeElapsed = 0
        if U.db and (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0) then
            U:RefreshRange()
        end
    end
end)

SLASH_UNCURSE1 = "/uncurse"
SLASH_UNCURSE2 = "/uc"
SlashCmdList.UNCURSE = function(message)
    message = string.lower(message or "")
    if message == "lock" then U:SetLocked(true)
    elseif message == "unlock" then U:SetLocked(false)
    elseif message == "reset" then
        U.db.point, U.db.relativePoint, U.db.x, U.db.y = "CENTER", "CENTER", 0, -120
        U:ApplyPosition()
        Print("position reset.")
    else U:OpenOptions() end
end
