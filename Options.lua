-- Keys, the minimap button and the page in Blizzard's Settings (Esc > Options > AddOns).
local _, ns = ...
local TITLE = "Wardrobe Time Capsule"

-- Bindings.xml actions.
BINDING_HEADER_WARDROBETIMECAPSULE = TITLE
BINDING_NAME_WARDROBETIMECAPSULE_TOGGLE = "Open album"
BINDING_NAME_WARDROBETIMECAPSULE_SAVE = "Save look"
function WardrobeTimeCapsule_Toggle() SlashCmdList.WARDROBETIMECAPSULE("") end
function WardrobeTimeCapsule_Save() ns:QuickSave() end

ns.keyActions = {
    {action = "WARDROBETIMECAPSULE_TOGGLE", label = "Open album"},
    {action = "WARDROBETIMECAPSULE_SAVE", label = "Save look"},
}

-- Opens the album (built on first use), never closes it.
function ns:Open()
    if not self.album and not self:Initialize() then return end
    if not self.frame then self:Toggle() else self.frame:Show() end
end

------------------------------------------------------------------------
-- Keys
------------------------------------------------------------------------

local Keys = {}
ns.Keys = Keys
local MODIFIERS = {LSHIFT=true, RSHIFT=true, LCTRL=true, RCTRL=true, LALT=true, RALT=true, LMETA=true, RMETA=true}
local MOUSE = {LeftButton="BUTTON1", RightButton="BUTTON2", MiddleButton="BUTTON3"}

function Keys.Bound(action)
    local key = GetBindingKey and GetBindingKey(action)
    if not key then return nil end
    return GetBindingText and GetBindingText(key) or key
end

-- The key pressed with its held modifiers, as the bindings write it.
function Keys.Combo(key)
    local mods = ""
    if IsAltKeyDown() then mods = mods .. "ALT-" end
    if IsControlKeyDown() then mods = mods .. "CTRL-" end
    if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
    if IsMetaKeyDown and IsMetaKeyDown() then mods = mods .. "META-" end
    return mods .. key
end

-- Binds key to action in place of what had it, and of the action's old keys.
-- Returns ok, message: what the key did before, or why nothing changed.
function Keys.Bind(action, key)
    if InCombatLockdown() then return false, "Not in combat." end
    local before = GetBindingAction(key)
    for _, old in ipairs({GetBindingKey(action)}) do SetBinding(old) end
    SetBinding(key, action)
    SaveBindings(GetCurrentBindingSet())
    if before and before ~= "" and before ~= action then
        local shown = GetBindingText and GetBindingText(key) or key
        return true, shown .. " replaced: " .. (_G["BINDING_NAME_" .. before] or before)
    end
    return true
end

local listening
-- A keycap button: shows the bound key; click, then press a key (modifiers
-- combine, Esc or a left/right click cancels). Answers through ns:Print.
function Keys.Setter(parent, action, width, skin)
    local cap = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    cap:SetSize(width or 100, 22)
    cap.action = action
    if skin and ns.OptionsSkin then ns.OptionsSkin.Button(cap) end
    local catcher = CreateFrame("Frame", nil, cap)
    catcher:SetAllPoints(UIParent); catcher:SetFrameStrata("FULLSCREEN_DIALOG"); catcher:Hide()
    cap.catcher = catcher

    function cap:Refresh()
        self:SetText(self.listening and "Press a key" or Keys.Bound(self.action) or "Not set")
    end
    function cap:Stop()
        if not self.listening then return end
        self.listening = false
        if listening == self then listening = nil end
        catcher:EnableKeyboard(false); catcher:EnableMouse(false); catcher:EnableMouseWheel(false)
        catcher:Hide()
        self:Refresh()
    end
    function cap:Take(key)
        self:Stop()
        local ok, message = Keys.Bind(self.action, key)
        if message then ns:Print(message) end
        self:Refresh()
        if ok and Keys.onBound then Keys.onBound() end
    end
    function cap:Listen()
        if InCombatLockdown() then ns:Print("Not in combat."); return end
        if listening and listening ~= self then listening:Stop() end
        listening, self.listening = self, true
        catcher:Show()
        catcher:EnableKeyboard(true)
        if catcher.SetPropagateKeyboardInput then catcher:SetPropagateKeyboardInput(false) end
        catcher:EnableMouse(true); catcher:EnableMouseWheel(true)
        self:Refresh()
    end
    catcher:SetScript("OnKeyDown", function(_, key)
        if MODIFIERS[key] then return end
        if key == "ESCAPE" then cap:Stop() else cap:Take(Keys.Combo(key)) end
    end)
    catcher:SetScript("OnMouseDown", function(_, button)
        local key = MOUSE[button] or button:upper()
        if key == "BUTTON1" or key == "BUTTON2" then cap:Stop() else cap:Take(Keys.Combo(key)) end
    end)
    catcher:SetScript("OnMouseWheel", function(_, delta)
        cap:Take(Keys.Combo(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
    end)
    cap:SetScript("OnClick", function(self) if self.listening then self:Stop() else self:Listen() end end)
    cap:SetScript("OnHide", function(self) self:Stop() end)
    cap:Refresh()
    return cap
end

------------------------------------------------------------------------
-- Minimap button
------------------------------------------------------------------------

local function MinimapDB()
    if not ns.db then ns:Initialize() end
    local db = ns.db
    if type(db.minimap) ~= "table" then db.minimap = {} end
    return db.minimap
end

function ns:PlaceMinimapButton()
    local button = self.minimapButton
    if not button then return end
    local angle = math.rad(MinimapDB().angle or 200)
    local rx, ry = Minimap:GetWidth() / 2 + 2, Minimap:GetHeight() / 2 + 2
    local x, y = math.cos(angle) * rx, math.sin(angle) * ry
    if type(GetMinimapShape) == "function" and tostring(GetMinimapShape()):upper() == "SQUARE" then
        x = math.max(-rx, math.min(rx, x * 1.4142))
        y = math.max(-ry, math.min(ry, y * 1.4142))
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function Drag(button)
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    if not cx then return end
    MinimapDB().angle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
    ns:PlaceMinimapButton()
end

function ns:BuildMinimapButton()
    if self.minimapButton or not Minimap then return end
    local button = CreateFrame("Button", "WardrobeTimeCapsuleMinimapButton", Minimap)
    self.minimapButton = button
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM"); button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    back:SetSize(20, 20); back:SetPoint("CENTER")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetSize(20, 20); icon:SetPoint("CENTER")
    if button.CreateMaskTexture then
        local mask = button:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon); icon:AddMaskTexture(mask)
    end
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54); border:SetPoint("TOPLEFT")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        self.dragging = true; GameTooltip:Hide()
        self:SetScript("OnUpdate", Drag)
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = false; self:SetScript("OnUpdate", nil); ns:PlaceMinimapButton()
    end)
    button:SetScript("OnClick", function() WardrobeTimeCapsule_Toggle() end)
    button:SetScript("OnEnter", function(self)
        if self.dragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(TITLE); GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if Minimap.HookScript then Minimap:HookScript("OnSizeChanged", function() ns:PlaceMinimapButton() end) end
    self:PlaceMinimapButton()
end

function ns:MinimapShown() return not MinimapDB().hide end

function ns:SetMinimapShown(shown)
    MinimapDB().hide = not shown or nil
    if shown then self:BuildMinimapButton() end
    if self.minimapButton then self.minimapButton:SetShown(shown) end
    self:RefreshOptions()
end

------------------------------------------------------------------------
-- Controls on both pages
------------------------------------------------------------------------

ns.optionControls = {}
function ns:RefreshOptions()
    for _, control in ipairs(self.optionControls) do
        if control.Refresh then control:Refresh() else control:SetChecked(self:MinimapShown()) end
    end
end
Keys.onBound = function() ns:RefreshOptions() end

local function MinimapCheck(parent)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetScript("OnClick", function(self) ns:SetMinimapShown(self:GetChecked() and true or false) end)
    check:SetChecked(ns:MinimapShown())
    ns.optionControls[#ns.optionControls + 1] = check
    return check
end

local function Setter(parent, action, width, skin)
    local cap = Keys.Setter(parent, action, width, skin)
    ns.optionControls[#ns.optionControls + 1] = cap
    return cap
end

-- Album footer, right of "Save a look on each level up". Called from ns:Build.
function ns:BuildOptions(Button, Label)
    local f = self.frame
    f.minimapCheck = MinimapCheck(f)
    f.minimapCheck:SetPoint("TOPLEFT", 250, -715)
    Label(f, "Minimap icon", 274, -720, "GameFontHighlightSmall")
    f.keys = {}
    for i, key in ipairs({{"Open", 400}, {"Save", 560}}) do
        Label(f, key[1], key[2], -720, "GameFontHighlightSmall")
        local cap = Setter(f, self.keyActions[i].action, 110, true)
        cap:SetPoint("TOPLEFT", key[2] + 40, -714)
        f.keys[i] = cap
    end
    f:HookScript("OnShow", function() ns:RefreshOptions() end)
end

------------------------------------------------------------------------
-- Blizzard Settings page
------------------------------------------------------------------------

function ns:RegisterSettings()
    if self.settingsCategory or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    self.settingsPanel = panel
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16); heading:SetText(TITLE)
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(140, 26); open:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
    open:SetText("Open")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        ns:Open()
    end)
    panel.open = open
    local slash = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    slash:SetPoint("LEFT", open, "RIGHT", 12, 0); slash:SetText("/looks")
    local check = MinimapCheck(panel)
    check:SetSize(26, 26); check:SetPoint("TOPLEFT", open, "BOTTOMLEFT", -2, -14)
    panel.minimapCheck = check
    local checkLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkLabel:SetPoint("LEFT", check, "RIGHT", 4, 0); checkLabel:SetText("Minimap icon")
    local keysHeading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    keysHeading:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 2, -18); keysHeading:SetText("Keys")
    panel.keys = {}
    for i, key in ipairs(self.keyActions) do
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", keysHeading, "BOTTOMLEFT", 0, -14 - (i - 1) * 30)
        label:SetText(key.label)
        local cap = Setter(panel, key.action, 140, false)
        cap:SetPoint("LEFT", label, "LEFT", 110, 0)
        panel.keys[i] = cap
    end
    panel:SetScript("OnShow", function() ns:RefreshOptions() end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("UPDATE_BINDINGS")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if ns:MinimapShown() then ns:BuildMinimapButton() end
        pcall(ns.RegisterSettings, ns)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if listening then listening:Stop() end
    else
        ns:RefreshOptions()
    end
end)
