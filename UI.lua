local _, ns = ...
local function Label(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y); label:SetText(text)
    return label
end
local function Button(parent, text, width, x, y, click)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24); button:SetPoint("TOPLEFT", x, y)
    button:SetText(text); button:SetScript("OnClick", click)
    if ns.OptionsSkin then ns.OptionsSkin.Button(button) end
    return button
end
local function Panel(parent, x, y, w, h, paper)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", x, y); panel:SetSize(w, h)
    panel:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, edgeSize = 16,
        insets = {left=4, right=4, top=4, bottom=4}})
    panel:SetBackdropBorderColor(.55, .45, .28)
    if ns.OptionsSkin then ns.OptionsSkin.Panel(panel) end
    return panel
end

function ns:Replay(entry)
    local model = self.frame.model
    model.entry = entry
    model:ClearModel()
    model:SetUnit("player")
    self:FitModel()
    self:ApplyOutfit()
    self:RefreshPetPreview()
end

function ns:RefreshPetPreview()
    local f=self.frame
    if not f or not f.petModel then return end
    local _,class=UnitClass("player")
    local show=class=="HUNTER" and f:IsShown() and f.model.entry~=nil and UnitExists("pet")
    local pet=f.petModel
    f.model:ClearAllPoints()
    f.model:SetPoint("TOPLEFT",f.previewPanel,"TOPLEFT",show and -25 or 50,-70)
    -- Preserve character scale: move its full-size viewport rather than shrink it.
    if show then
        pet:ClearModel()
        pet:SetUnit("pet")
        pet:SetPortraitZoom(0)
        pet:SetPosition(0,0,0)
        pet:SetFacing(f.model:GetFacing())
        pet:Show()
    else
        pet:Hide();pet:ClearModel()
    end
end

function ns:FitModel()
    local model = self.frame.model
    model.zoom = 0
    if model.SetPosition then model:SetPosition(0, 0, 0) end
    if model.SetPortraitZoom then model:SetPortraitZoom(0) end
    if self.frame.petModel then
        self.frame.petModel:SetPortraitZoom(0)
        self.frame.petModel:SetPosition(0,0,0)
    end
end

function ns:ApplyOutfit()
    local model = self.frame.model
    local entry = model.entry
    if not entry or model.applying then return end
    model.applying = true
    -- SetUnit loads the body; Undress ensures current equipment cannot leak into history.
    model:Undress()
    -- Looks read from a drawn model (entry.drawn) already reflect hidden helm/cloak.
    local asDrawn = entry.drawn and not self.showReal
    for _, slot in ipairs(self.slots) do
        local item = entry.items[slot]
        local look = not self.showReal and (item and item.look or entry.extra and entry.extra[slot])
        if (item or look) and (asDrawn or not ((slot == 1 and entry.showHelm == false) or
            (slot == 15 and entry.showCloak == false))) then
            local hand = slot == 17 and "SECONDARYHANDSLOT" or slot == 16 and "MAINHANDSLOT" or nil
            if look and look.hidden then
                -- The transmog hid this slot.
            elseif look and model.SetItemTransmogInfo and ItemUtil and ItemUtil.CreateItemTransmogInfo then
                model:SetItemTransmogInfo(ItemUtil.CreateItemTransmogInfo(look.appearance,
                    look.secondary, look.illusion), slot)
            elseif look then
                model:TryOn(look.appearance, hand, look.illusion ~= 0 and look.illusion or nil)
            else
                model:TryOn(item.link, hand)
            end
        end
    end
    model.applying = false
end

-- Fills the nine memory rows from listOffset and syncs the scroll bar.
function ns:UpdateRows()
    local f = self.frame
    local entries = self.listEntries or {}
    local visible = #f.rows
    local maxOffset = math.max(0, #entries - visible)
    self.listOffset = math.max(0, math.min(maxOffset, self.listOffset or 0))
    for i, row in ipairs(f.rows) do
        local value = entries[self.listOffset + i]
        row.entry = value
        row:SetShown(value ~= nil)
        if value then
            row.title:SetText(value.title)
            row.detail:SetText("Level " .. value.level .. "  -  " .. (value.zone ~= "" and value.zone or "Azeroth"))
            row.date:SetText(date("%b %d, %Y", value.timestamp))
            row.selected:SetShown(value.id == self.selected)
        end
    end
    local bar = f.listScroll
    if bar and bar.SetVisibleExtentPercentage then
        self.syncingScroll = true
        bar:SetVisibleExtentPercentage(#entries > 0 and math.min(1, visible / #entries) or 1)
        bar:SetPanExtentPercentage(maxOffset > 0 and 1 / maxOffset or 1)
        bar:SetScrollPercentage(maxOffset > 0 and self.listOffset / maxOffset or 0, true)
        self.syncingScroll = false
    end
    if self.StyleCompositionSlots then self:StyleCompositionSlots() end
end

function ns:ScrollList(rows)
    self.listOffset = (self.listOffset or 0) + rows
    self:UpdateRows()
end

-- force reloads the model even when the selected entry is unchanged (window opened).
function ns:Refresh(force)
    local f = self.frame
    if not f or not f:IsShown() then return end
    local entries = self:Entries(self.filter)
    local selectedIndex = 1
    for i, entry in ipairs(entries) do if entry.id == self.selected then selectedIndex = i; break end end
    local entry = entries[selectedIndex]
    self.selected = entry and entry.id
    self.current = entry
    -- A pending Remove confirmation belongs to the memory it was clicked on.
    if self.removeArmed and (not entry or self.removeArmed ~= entry.id) then
        self.removeArmed = nil; f.delete:SetText("Remove")
    end
    -- Keep the selected memory in view; wheel and scroll bar move listOffset freely.
    local visible = #f.rows
    local offset = self.listOffset or 0
    if entry then
        if selectedIndex <= offset then offset = selectedIndex - 1
        elseif selectedIndex > offset + visible then offset = selectedIndex - visible end
    end
    self.listOffset = offset
    self.listEntries = entries
    f.count:SetText(self.album.name .. "'s journey  |  " .. #self.album.entries .. " memories")
    f.page:SetText(#entries > 0 and (selectedIndex .. " / " .. #entries) or "Your first page awaits")
    f.auto:SetChecked(self.album.auto)
    for _, button in ipairs(f.filters) do button:SetEnabled(button.filter ~= self.filter) end
    self:UpdateRows()
    f.empty:SetShown(not entry)
    f.model:SetShown(entry ~= nil)
    f.edit:SetEnabled(entry ~= nil); f.delete:SetEnabled(entry ~= nil)
    f.previous:SetEnabled(entry ~= nil and selectedIndex > 1)
    f.next:SetEnabled(entry ~= nil and selectedIndex < #entries)
    f.heading:SetText(entry and entry.title or "The road to level 60")
    f.meta:SetText(entry and ("Level " .. entry.level .. "  |  " .. date("%B %d, %Y", entry.timestamp)) or "Every outfit tells a story.")
    local location = entry and entry.zone or ""
    if entry and entry.subzone ~= "" and entry.subzone ~= entry.zone then location = entry.subzone .. ", " .. location end
    f.location:SetText(location)
    f.note:SetText(entry and entry.note or "Save your first look to begin your album.\nReturn as your character grows from a new adventurer into a hero.")
    f.noteChild:SetHeight(math.max(56, f.note:GetStringHeight()))
    f.noteScroll:SetVerticalScroll(0)
    local transmogged = self:HasTransmog(entry)
    f.underneath:SetShown(entry ~= nil)
    f.underneath:SetEnabled(transmogged)
    f.underneath:SetText(transmogged and self.showReal and "Show transmog" or "Show real gear")
    f.lookMode:SetText(not transmogged and "No transmog recorded" or
        self.showReal and "Real gear (under the transmog)" or
        entry.outfit and entry.outfit.name and entry.outfit.name ~= "" and ("Outfit: " .. entry.outfit.name) or "Transmog as worn")
    for i, icon in ipairs(f.items) do
        local slot = self.slots[i]
        local item = entry and entry.items[slot]
        icon.item = item
        local look = not self.showReal and entry and (item and item.look or entry.extra and entry.extra[slot])
        if look and not look.icon and C_TransmogCollection and C_TransmogCollection.GetSourceIcon then
            local ok, texture = pcall(C_TransmogCollection.GetSourceIcon, look.appearance)
            if ok then look.icon = texture end
        end
        icon.look = look or nil
        icon.texture:SetTexture(look and look.icon or item and item.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        icon:SetAlpha((item or look) and not (look and look.hidden) and 1 or .35)
    end
    -- Reloading the model flickers; only do it when a different look is shown.
    if entry then
        if force or f.model.entry ~= entry then self:Replay(entry) end
    elseif f.model.entry ~= nil or force then
        f.model.entry = nil; self:RefreshPetPreview()
    end
    if self.StyleCompositionSlots then self:StyleCompositionSlots() end
end

function ns:Step(direction)
    local entries = self:Entries(self.filter)
    for i, entry in ipairs(entries) do
        if entry.id == self.selected then
            local nextEntry = entries[i + direction]
            if nextEntry then self.selected = nextEntry.id; self:Refresh() end
            return
        end
    end
end

function ns:Edit()
    if not self.current then return end
    local dialog = self.editor
    if not dialog then
        dialog = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        dialog:SetSize(410, 270); dialog:SetPoint("CENTER"); dialog:SetFrameStrata("DIALOG")
        dialog:EnableMouse(true)
        dialog:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32,
            insets={left=11,right=12,top=12,bottom=11}})
        if ns.OptionsSkin then ns.OptionsSkin.Panel(dialog) end
        Label(dialog, "Caption this memory", 24, -22, "GameFontNormalLarge")
        Label(dialog, "Title", 26, -55)
        dialog.title = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        dialog.title:SetSize(348, 25); dialog.title:SetPoint("TOPLEFT", 30, -72)
        dialog.title:SetAutoFocus(false); dialog.title:SetMaxLetters(80)
        Label(dialog, "A note from your travels", 26, -112)
        local box = Panel(dialog, 24, -132, 362, 78, false)
        -- Scrollable: a 500-character note does not fit the visible box.
        local noteScroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        noteScroll:SetPoint("TOPLEFT", 9, -8); noteScroll:SetPoint("BOTTOMRIGHT", -28, 8)
        dialog.note = CreateFrame("EditBox", nil, noteScroll)
        dialog.note:SetSize(325, 62)
        dialog.note:SetFontObject("GameFontHighlightSmall"); dialog.note:SetMultiLine(true)
        dialog.note:SetAutoFocus(false); dialog.note:SetMaxLetters(500)
        noteScroll:SetScrollChild(dialog.note)
        if ScrollingEdit_OnCursorChanged then
            dialog.note:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
            dialog.note:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, noteScroll) end)
        end
        box:EnableMouse(true); box:SetScript("OnMouseDown", function() dialog.note:SetFocus() end)
        local function close() dialog:Hide() end
        local function save()
            ns:SaveCaption(dialog.entry, dialog.title:GetText(), dialog.note:GetText())
            dialog:Hide(); ns:Refresh()
        end
        dialog.title:SetScript("OnEscapePressed", close); dialog.note:SetScript("OnEscapePressed", close)
        dialog.title:SetScript("OnEnterPressed", save)
        dialog.title:SetScript("OnTabPressed", function() dialog.note:SetFocus() end)
        dialog.note:SetScript("OnTabPressed", function() dialog.title:SetFocus() end)
        Button(dialog, "Save caption", 130, 114, -226, save)
        Button(dialog, "Cancel", 110, 258, -226, close)
        self.editor = dialog
    end
    dialog.entry = self.current
    dialog.title:SetText(self.current.title); dialog.note:SetText(self.current.note)
    dialog:Show(); dialog.title:SetFocus()
end

function ns:Build()
    local f = CreateFrame("Frame", "WardrobeTimeCapsuleFrame", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(780, 750); f:SetPoint("CENTER"); f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true); f:EnableMouse(true); f:SetMovable(true)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32,
        insets={left=11,right=12,top=12,bottom=11}})
    local chrome=f
    if ns.OptionsSkin then
        local background=ns.OptionsSkin.Panel(f)
        background:ClearAllPoints()
        background:SetPoint("TOPLEFT",12,-13); background:SetPoint("BOTTOMRIGHT",-6,6)
        chrome=ns.OptionsSkin.WindowBorder(f)
    end
    -- Fit the fixed-size journal on small screens; follow later UI scale changes.
    local function FitScale()
        f:SetScale(math.min(1, UIParent:GetWidth() / 810, UIParent:GetHeight() / 780))
    end
    FitScale()
    f:RegisterEvent("UI_SCALE_CHANGED"); f:RegisterEvent("DISPLAY_SIZE_CHANGED")
    f:SetScript("OnEvent", FitScale)
    local title = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP",f,"TOP",0,-18)
    title:SetText("Look Journal")
    f.journalTitle=title
    local drag = CreateFrame("Frame", nil, chrome)
    drag:SetPoint("TOPLEFT", 25, -13); drag:SetPoint("TOPRIGHT", -40, -13); drag:SetHeight(24)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local close = CreateFrame("Button", nil, chrome, "UIPanelCloseButton")
    close:ClearAllPoints()
    if f.legacyBorder then
        -- Native Forever geometry: ButtonFrameTemplate's close button sits at the border
        -- frame's TOPRIGHT (0, 3) at the template's own size (28 px since build 70532) (Camelot SharedUIPanelTemplates).
        close:SetPoint("TOPRIGHT",f.legacyBorder,"TOPRIGHT",0,3)
    else
        close:SetSize(24,24)
        close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-8,-12)
    end
    close:SetScript("OnClick", function() f:Hide() end)
    UISpecialFrames[#UISpecialFrames + 1] = "WardrobeTimeCapsuleFrame"
    f.count = Label(f, "", 24, -49, "GameFontHighlightSmall")
    Button(f, "Save this look", 140, 626, -40, function()
        ns.filter = nil
        local entry, err = ns:Capture(false)
        if entry then ns:Edit() else ns:Print(err) end
    end)
    Label(f, "LEVEL", 24, -78, "GameFontNormalSmall")
    local ranges = {"All", "1-10", "11-20", "21-30", "31-40", "41-50", "51-60"}
    f.filters = {}
    for i, range in ipairs(ranges) do
        local value = i > 1 and i - 2 or nil
        local b = Button(f, range, 68, 68 + (i-1)*74, -71, function()
            ns.filter = value; ns.selected = nil; ns:Refresh()
        end)
        f.filters[i] = b
        b.filter = value
    end
    local list = Panel(f, 22, -102, 208, 576, false)
    f.memoryPanel=list
    f.memoryTitle=Label(list, "YOUR MEMORIES", 12, -14, "GameFontNormalSmall")
    f.rows = {}
    for i = 1, 9 do
        local row = CreateFrame("Button", nil, list)
        row:SetSize(180, 55); row:SetPoint("TOPLEFT", 8, -34 - (i-1)*57)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.selected = row:CreateTexture(nil, "BACKGROUND")
        row.selected:SetAllPoints(); row.selected:SetColorTexture(.55, .38, .10, .35)
        row.title = Label(row, "", 8, -4, "GameFontNormal")
        row.title:SetWidth(166); row.title:SetJustifyH("LEFT"); row.title:SetWordWrap(false)
        row.detail = Label(row, "", 8, -23, "GameFontHighlightSmall")
        row.detail:SetWidth(166); row.detail:SetJustifyH("LEFT"); row.detail:SetWordWrap(false)
        row.date = Label(row, "", 8, -38, "GameFontDisableSmall")
        row:SetScript("OnClick", function() ns.selected = row.entry.id; ns:Refresh() end)
        f.rows[i] = row
    end
    -- Mouse wheel anywhere over the memories scrolls one memory per notch.
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) ns:ScrollList(-delta) end)
    -- Blizzard's slim scroll bar, hidden while every memory fits.
    local ok, bar = pcall(CreateFrame, "EventFrame", nil, list, "MinimalScrollBar")
    if ok and bar and bar.RegisterCallback then
        bar:SetPoint("TOPRIGHT", -9, -38); bar:SetPoint("BOTTOMRIGHT", -9, 10)
        bar:SetHideIfUnscrollable(true)
        bar:RegisterCallback(bar.Event.OnScroll, function(_, percentage)
            if ns.syncingScroll then return end
            local maxOffset = math.max(0, #(ns.listEntries or {}) - #f.rows)
            local offset = math.floor(percentage * maxOffset + .5)
            if offset ~= ns.listOffset then ns.listOffset = offset; ns:UpdateRows() end
        end, ns)
        f.listScroll = bar
        -- The thumb reads poorly against its track: lay an additive copy of each thumb
        -- piece on top (same atlas and crop, following hover/press states) to brighten it.
        local thumb = bar.GetThumb and bar:GetThumb()
        if thumb and thumb.Middle then
            local glows = {}
            for _, key in ipairs({"Begin", "Middle", "End"}) do
                local part = thumb[key]
                local glow = thumb:CreateTexture(nil, "OVERLAY")
                glow:SetAllPoints(part); glow:SetBlendMode("ADD"); glow:SetAlpha(.45)
                glows[part] = glow
            end
            local function SyncGlow()
                for part, glow in pairs(glows) do
                    local atlas = part:GetAtlas()
                    if atlas then glow:SetAtlas(atlas); glow:SetTexCoord(part:GetTexCoord()) end
                end
            end
            if thumb.OnButtonStateChanged then hooksecurefunc(thumb, "OnButtonStateChanged", SyncGlow) end
            thumb:HookScript("OnSizeChanged", SyncGlow)
            SyncGlow()
        end
    end
    f.empty = Label(list, "No memories here yet.\n\nWear a look you love, then\nchoose Save this look.", 20, -120, "GameFontHighlight")
    f.empty:SetWidth(168); f.empty:SetJustifyH("CENTER")
    local page = Panel(f, 238, -102, 530, 576, true)
    f.previewPanel=page
    f.heading = Label(page, "", 65, -12, "GameFontNormalLarge")
    f.heading:SetWidth(400); f.heading:SetWordWrap(false); f.heading:SetJustifyH("CENTER")
    f.meta = Label(page, "", 65, -34, "GameFontHighlightSmall")
    f.meta:SetWidth(400); f.meta:SetJustifyH("CENTER")
    f.location = Label(page, "", 65, -51, "GameFontHighlightSmall")
    f.location:SetWidth(400); f.location:SetJustifyH("CENTER")
    local model = CreateFrame("DressUpModel", nil, page)
    f.model = model
    model:SetPoint("TOPLEFT", 50, -70); model:SetSize(430, 450)
    model:SetFacing(.25); model:EnableMouse(true); model:EnableMouseWheel(true)
    model:SetScript("OnModelLoaded", function() ns:FitModel(); ns:ApplyOutfit() end)
    -- The rotation handler exists only while the left button is held.
    local function RotateModel()
        if not model.dragX or not IsMouseButtonDown("LeftButton") then
            model.dragX = nil; model:SetScript("OnUpdate", nil); return
        end
        local x = GetCursorPosition()
        model:SetFacing(model:GetFacing() + (x-model.dragX)*.012); model.dragX = x
        if f.petModel:IsShown() then f.petModel:SetFacing(model:GetFacing()) end
    end
    local function StopRotate() model.dragX = nil; model:SetScript("OnUpdate", nil) end
    model:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            model.dragX = GetCursorPosition()
            model:SetScript("OnUpdate", RotateModel)
        end
    end)
    model:SetScript("OnMouseUp", StopRotate)
    model:SetScript("OnHide", StopRotate)
    model:SetScript("OnMouseWheel", function(_, delta)
        model.zoom = math.max(0, math.min(1, (model.zoom or 0) + delta*.1))
        model:SetPortraitZoom(model.zoom)
    end)
    local hint = Label(page, "", 100, -525, "GameFontHighlightSmall")
    f.previewHint=hint
    hint:SetWidth(330); hint:SetJustifyH("CENTER")
    hint:Hide()
    local pet=CreateFrame("PlayerModel",nil,page)
    f.petModel=pet
    pet:SetSize(180,220);pet:SetPoint("BOTTOMRIGHT",page,"TOPLEFT",472,-520)
    pet:EnableMouse(false);pet:Hide()
    pet:SetScript("OnModelLoaded",function()
        pet:SetPortraitZoom(0);pet:SetPosition(0,0,0);pet:SetFacing(model:GetFacing())
    end)
    pet:RegisterEvent("UNIT_PET")
    pet:RegisterEvent("UNIT_MODEL_CHANGED")
    pet:RegisterEvent("PLAYER_ENTERING_WORLD")
    pet:SetScript("OnEvent",function(_,event,unit)
        if f:IsShown() and (event=="PLAYER_ENTERING_WORLD" or
            (event=="UNIT_PET" and unit=="player") or
            (event=="UNIT_MODEL_CHANGED" and unit=="pet")) then ns:RefreshPetPreview() end
    end)
    Button(page, "Fit", 38, 483, -10, function() ns:FitModel() end)
    -- Memories replay the transmog as worn; this peeks at the real items beneath it.
    f.underneath = Button(page, "Show real gear", 120, 10, -518, function()
        ns.showReal = not ns.showReal
        ns:ApplyOutfit(); ns:Refresh()
    end)
    f.lookMode = Label(page, "", 136, -524, "GameFontDisableSmall")
    f.items = {}
    for i, slot in ipairs(self.slots) do
        local icon = CreateFrame("Button", nil, page)
        icon:SetSize(32, 32); icon:SetPoint("TOPLEFT", i <= 7 and 16 or 482, -84 - ((i-1)%7)*62)
        icon.texture = icon:CreateTexture(nil, "ARTWORK"); icon.texture:SetAllPoints()
        icon:SetScript("OnEnter", function()
            GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
            local look = icon.look
            if look and not look.link and C_TransmogCollection and C_TransmogCollection.GetAppearanceSourceInfo then
                local ok, info = pcall(C_TransmogCollection.GetAppearanceSourceInfo, look.appearance)
                if ok and type(info) == "table" and info.itemLink ~= "" then look.link = info.itemLink end
            end
            if look and look.hidden then
                GameTooltip:SetText(ns.slotNames[slot] .. " (hidden by transmog)")
                GameTooltip:AddLine(icon.item.link, 1, 1, 1)
            elseif look then
                if look.link then GameTooltip:SetHyperlink(look.link) else GameTooltip:SetText(ns.slotNames[slot]) end
                if icon.item then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Transmogrified from:", 1, .82, 0)
                    GameTooltip:AddLine(icon.item.link, 1, 1, 1)
                end
            elseif icon.item then GameTooltip:SetHyperlink(icon.item.link) else GameTooltip:SetText(ns.slotNames[slot]) end
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.items[i] = icon
    end
    local noteScroll = CreateFrame("ScrollFrame", nil, page)
    noteScroll:SetPoint("TOPLEFT", 14, -545); noteScroll:SetSize(502, 24)
    noteScroll:EnableMouseWheel(true)
    noteScroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*20)))
    end)
    local noteChild = CreateFrame("Frame", nil, noteScroll)
    noteChild:SetSize(502, 24); noteScroll:SetScrollChild(noteChild)
    f.noteChild = noteChild; f.noteScroll = noteScroll
    f.note = Label(noteChild, "", 0, 0, "GameFontHighlightSmall")
    f.note:SetWidth(498); f.note:SetJustifyH("CENTER")
    f.previous = Button(f, "Previous", 94, 238, -683, function() ns:Step(-1) end)
    f.next = Button(f, "Next", 94, 674, -683, function() ns:Step(1) end)
    f.page = Label(f, "", 340, -690, "GameFontNormal")
    f.page:SetWidth(320); f.page:SetJustifyH("CENTER")
    f.edit = Button(f, "Edit caption", 100, 22, -683, function() ns:Edit() end)
    -- Confirmation is a second click on the same button (as in Petal and Map
    -- Mementos), not a StaticPopup: Blizzard's popup code runs gamepad binding
    -- setup, and run from addon code in the gamepad interface it taints that
    -- path (the stuck A/B buttons). The armed state clears after 3 seconds, on
    -- a different memory, or when the journal closes.
    f.delete = Button(f, "Remove", 104, 126, -683, function(self)
        local entry = ns.current
        if not entry then return end
        if ns.removeArmed ~= entry.id then
            ns.removeArmed = entry.id
            self:SetText("|cffff8040Confirm?|r")
            C_Timer.After(3, function()
                if ns.removeArmed == entry.id then ns.removeArmed = nil; self:SetText("Remove") end
            end)
            return
        end
        ns.removeArmed = nil
        self:SetText("Remove")
        ns:RemoveEntry(entry.id)
    end)
    f.auto = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.auto:SetSize(20, 20); f.auto:SetPoint("TOPLEFT", 22, -715)
    Label(f, "Save a look on each level up", 46, -720, "GameFontHighlightSmall")
    f.auto:SetScript("OnClick", function(self) ns.album.auto = self:GetChecked() and true or false end)
    f:SetScript("OnShow", function() ns.showReal = false; ns:SelectLatest(); ns:Refresh(true) end)
    f:SetScript("OnHide", function()
        if ns.editor then ns.editor:Hide() end
        ns.removeArmed = nil; f.delete:SetText("Remove")
    end)
    if self.BuildBackgroundLab then self:BuildBackgroundLab(Button,Label) end
    if self.BuildCompositions then self:BuildCompositions(Button, Label) end
end

-- Removes a memory and keeps the reader's place: the next memory is selected
-- (or the previous one at the end).
function ns:RemoveEntry(id)
    local entries = self:Entries(self.filter)
    for i, entry in ipairs(entries) do
        if entry.id == id then
            local neighbor = entries[i + 1] or entries[i - 1]
            self.selected = neighbor and neighbor.id or nil
            break
        end
    end
    self:Delete(id); self:Refresh()
end

-- Opening the journal shows the most recent memory, with its level range selected.
function ns:SelectLatest()
    local latest
    for _, entry in ipairs(self.album and self.album.entries or {}) do
        if not latest or entry.timestamp > latest.timestamp or
            (entry.timestamp == latest.timestamp and entry.id > latest.id) then latest = entry end
    end
    if not latest then return end
    self.filter = math.floor((latest.level - 1) / 10)
    self.selected = latest.id
end

function ns:Toggle()
    if not self.frame then self:SelectLatest(); self:Build(); self:Refresh()
    else self.frame:SetShown(not self.frame:IsShown()) end
end

