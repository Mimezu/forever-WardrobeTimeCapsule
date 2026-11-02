local ADDON, ns = ...
ns.slots = {1, 3, 4, 5, 6, 7, 8, 9, 10, 15, 19, 16, 17, 18}
ns.slotNames = { [1]="Head", [3]="Shoulders", [4]="Shirt", [5]="Chest", [6]="Waist",
    [7]="Legs", [8]="Feet", [9]="Wrists", [10]="Hands", [15]="Back", [19]="Tabard",
    [16]="Main hand", [17]="Off hand", [18]="Ranged" }

function ns:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Look Journal:|r " .. message)
end

function ns:Initialize()
    WardrobeTimeCapsuleDB = WardrobeTimeCapsuleDB or {}
    local db = WardrobeTimeCapsuleDB
    db.forever = db.forever or {characters = {}, nextID = 1}
    self.db = db.forever
    local guid = UnitGUID("player")
    if not guid then return false end
    -- New albums (fresh character or new install) save a look on each level up by default;
    -- an existing album keeps its own choice.
    self.db.characters[guid] = self.db.characters[guid] or {entries = {}, auto = true}
    self.album = self.db.characters[guid]
    self.album.name = UnitName("player")
    return true
end

-- Transmog appearance actually shown in a slot, or nil when the slot shows its real item.
-- IDs are itemModifiedAppearance (source) IDs; 0 means "none" in every field.
local APPEARANCE, ILLUSION, MAIN, SECONDARY = 0, 1, 0, 1

-- The outfit-based transmog reports per character slot; this is what Blizzard's own UI reads.
local function SlotVisual(slot, transmogType, modification)
    if not (C_Transmog and C_Transmog.GetSlotVisualInfo) then return end
    local ok, info = pcall(C_Transmog.GetSlotVisualInfo,
        {slotID = slot, type = transmogType, modification = modification})
    if ok and type(info) == "table" then return info end
end
ns.SlotVisual = SlotVisual

-- Applied source differing from the item's own appearance, or 0.
local function Applied(info)
    local applied = info and tonumber(info.appliedSourceID) or 0
    if applied == (info and tonumber(info.baseSourceID) or 0) then return 0 end
    return applied
end

local function ReadSlotLook(slot)
    local main = SlotVisual(slot, APPEARANCE, MAIN)
    if not main then return end
    local appearance = Applied(main)
    local secondary = slot == 3 and Applied(SlotVisual(slot, APPEARANCE, SECONDARY)) or 0
    local illusion = (slot == 16 or slot == 17) and Applied(SlotVisual(slot, ILLUSION, MAIN)) or 0
    if appearance == 0 and secondary == 0 and illusion == 0 then return end
    if appearance == 0 then appearance = tonumber(main.baseSourceID) or 0 end
    return {appearance = appearance, secondary = secondary, illusion = illusion}
end

-- Older per-item API; used only when the slot API is unavailable.
local function ReadItemLook(slot)
    if not (C_Item and C_Item.GetAppliedItemTransmogInfo and ItemLocation) then return end
    local ok, location = pcall(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
    if not ok or not location then return end
    local okApplied, applied = pcall(C_Item.GetAppliedItemTransmogInfo, location)
    if not okApplied or type(applied) ~= "table" then return end
    local base
    if C_Item.GetBaseItemTransmogInfo then
        local okBase, info = pcall(C_Item.GetBaseItemTransmogInfo, location)
        base = okBase and type(info) == "table" and info or nil
    end
    local function Changed(field)
        local value = tonumber(applied[field]) or 0
        return value ~= 0 and value ~= (base and tonumber(base[field]) or 0), value
    end
    local mainChanged, appearance = Changed("appearanceID")
    local secondaryChanged, secondary = Changed("secondaryAppearanceID")
    local illusionChanged, illusion = Changed("illusionID")
    if not (mainChanged or secondaryChanged or illusionChanged) then return end
    if appearance == 0 then appearance = base and tonumber(base.appearanceID) or 0 end
    return {appearance = appearance, secondary = secondary, illusion = illusion}
end

-- Adds the appearance icon and item link, when the client has them cached.
local function Decorate(look)
    if not C_TransmogCollection or look.appearance == 0 then return look end
    if C_TransmogCollection.GetSourceIcon then
        local okIcon, icon = pcall(C_TransmogCollection.GetSourceIcon, look.appearance)
        if okIcon then look.icon = icon end
    end
    if C_TransmogCollection.GetAppearanceSourceInfo then
        local okInfo, info = pcall(C_TransmogCollection.GetAppearanceSourceInfo, look.appearance)
        if okInfo and type(info) == "table" and info.itemLink ~= "" then look.link = info.itemLink end
    end
    return look
end

local function ReadLook(slot)
    local look
    if C_Transmog and C_Transmog.GetSlotVisualInfo then look = ReadSlotLook(slot) else look = ReadItemLook(slot) end
    if not look or look.appearance == 0 then return end
    return Decorate(look)
end
ns.ReadLook = ReadLook

local function Call(fn, ...)
    if not fn then return end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

-- Active outfit ID, when an outfit (rather than plain equipped gear) is what the world sees.
function ns:ActiveOutfit()
    local O = C_TransmogOutfitInfo
    if not (O and O.GetActiveOutfitID) then return end
    local active = tonumber(Call(O.GetActiveOutfitID)) or 0
    if active == 0 or Call(O.IsEquippedGearOutfitDisplayed) == true then return end
    return active
end

function ns:OutfitName(outfitID)
    local info = C_TransmogOutfitInfo and Call(C_TransmogOutfitInfo.GetOutfitInfo, outfitID)
    if type(info) ~= "table" then return end
    return info.name, info.playerFacingOutfitIndex
end

-- Outfit transmog is applied to the character, not to items, and the outfit API does not
-- expose every slot. A player model draws exactly what the world sees, so read it from one.
local probe
function ns:DrawnLooks(done)
    if not probe then
        local ok, frame = pcall(CreateFrame, "DressUpModel", nil, UIParent)
        if not ok or type(frame) ~= "table" or not frame.GetItemTransmogInfoList or not frame.SetUnit then
            return done(nil)
        end
        probe = frame
        probe:SetSize(64, 64); probe:SetPoint("BOTTOMLEFT"); probe:SetAlpha(0); probe:EnableMouse(false)
        probe.waiting = {}
        probe:SetScript("OnModelLoaded", function(model) model.loaded = true end)
    end
    probe.waiting[#probe.waiting + 1] = done
    if probe.busy then return end
    probe.busy, probe.loaded, probe.elapsed = true, false, 0
    probe:Show(); probe:SetUnit("player")
    probe:SetScript("OnUpdate", function(model, elapsed)
        model.elapsed = model.elapsed + elapsed
        if model.elapsed < (model.loaded and .3 or 1.5) then return end
        local list = Call(model.GetItemTransmogInfoList, model)
        local ready = false
        if type(list) == "table" then
            for _, info in pairs(list) do
                if type(info) == "table" and (tonumber(info.appearanceID) or 0) ~= 0 then ready = true; break end
            end
        end
        if not ready and model.elapsed < 5 then return end
        model:SetScript("OnUpdate", nil)
        model.busy = false
        model:Hide()
        local waiting = model.waiting
        model.waiting = {}
        for _, fn in ipairs(waiting) do fn(ready and list or nil) end
    end)
end

-- Stores the drawn appearance per slot: a look where it differs from the real item, a hidden
-- look where an equipped item is not drawn, and extra looks drawn over empty slots.
function ns:ApplyDrawn(entry, list)
    local found = 0
    entry.extra = nil
    for _, slot in ipairs(self.slots) do
        local drawn = list[slot]
        local item = entry.items[slot]
        local appearance = type(drawn) == "table" and tonumber(drawn.appearanceID) or 0
        local secondary = math.max(0, type(drawn) == "table" and tonumber(drawn.secondaryAppearanceID) or 0)
        local illusion = math.max(0, type(drawn) == "table" and tonumber(drawn.illusionID) or 0)
        if item and item.base then
            local baseIllusion = 0
            if slot == 16 or slot == 17 then
                local info = SlotVisual(slot, ILLUSION, MAIN)
                baseIllusion = info and tonumber(info.baseSourceID) or 0
            end
            if appearance == 0 then
                item.look = {appearance = 0, secondary = 0, illusion = 0, hidden = true}
            elseif appearance ~= item.base or secondary ~= 0 or (illusion ~= 0 and illusion ~= baseIllusion) then
                item.look = Decorate({appearance = appearance, secondary = secondary, illusion = illusion})
            else
                item.look = nil
            end
            if item.look then found = found + 1 end
        elseif not item and appearance ~= 0 then
            entry.extra = entry.extra or {}
            entry.extra[slot] = Decorate({appearance = appearance, secondary = secondary, illusion = illusion})
            found = found + 1
        end
    end
    entry.drawn = true
    return found
end

-- Fills a just-captured entry with the transmog as drawn, then refreshes the journal.
function ns:CaptureOutfit(entry, done)
    local active = self:ActiveOutfit()
    if active then
        local name, index = self:OutfitName(active)
        entry.outfit = {id = active, name = name, index = index}
    end
    self:DrawnLooks(function(list)
        local found = list and self:ApplyDrawn(entry, list) or nil
        if found and self.frame and self.frame.model and self.frame.model.entry == entry then self:ApplyOutfit() end
        if found and self.Refresh then self:Refresh() end
        if done then done(found, list) end
    end)
end

function ns:HasTransmog(entry)
    if not entry then return false end
    for _, item in pairs(entry.items) do if item.look then return true end end
    return entry.extra ~= nil and next(entry.extra) ~= nil
end

function ns:Capture(automatic, expectedLevel)
    if not self.album and not self:Initialize() then return nil, "Your character is not ready yet." end
    local level = UnitLevel("player")
    if level < 1 or level > 60 then return nil, "This album follows your journey from level 1 to 60." end
    if expectedLevel and level ~= expectedLevel then return nil, "Waiting for your new level." end
    if automatic and (not self.album.auto or self.album.lastAutoLevel == level) then return end
    local entry = {id = self.db.nextID, level = level, timestamp = time(),
        zone = GetRealZoneText() or "", subzone = GetSubZoneText() or "", items = {},
        title = "Level " .. level, note = "", automatic = automatic or false,
        showHelm = not ShowingHelm or ShowingHelm(), showCloak = not ShowingCloak or ShowingCloak()}
    -- Map and continent pick the memory's backdrop scene where the zone name alone
    -- has no homeland match; see ns:SceneRace.
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        entry.mapID = ok and mapID or nil
        local id, guard = entry.mapID, 0
        while id and id > 0 and guard < 10 do
            local okInfo, info = pcall(C_Map.GetMapInfo, id)
            if not okInfo or type(info) ~= "table" then break end
            if info.mapType == 2 then entry.continent = info.name; break end
            id, guard = info.parentMapID, guard + 1
        end
    end
    for _, slot in ipairs(self.slots) do
        local id = GetInventoryItemID("player", slot)
        local link = GetInventoryItemLink("player", slot)
        -- Never commit a partially loaded outfit. Empty slots are intentional.
        if id and not link then return nil, "Equipment is still loading. Try saving again in a moment." end
        if link then
            local visual = SlotVisual(slot, APPEARANCE, MAIN)
            entry.items[slot] = {link = link, id = id, icon = GetInventoryItemTexture("player", slot),
                base = visual and tonumber(visual.baseSourceID) or nil, look = ReadLook(slot)}
        end
    end
    self.db.nextID = self.db.nextID + 1
    self.album.entries[#self.album.entries + 1] = entry
    if automatic then self.album.lastAutoLevel = level end
    self.selected = entry.id
    if self.Refresh then self:Refresh() end
    self:CaptureOutfit(entry)
    return entry
end

function ns:Entries(filter)
    local entries = {}
    for _, entry in ipairs(self.album.entries) do
        if not filter or math.floor((entry.level - 1) / 10) == filter then entries[#entries + 1] = entry end
    end
    table.sort(entries, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        if a.timestamp ~= b.timestamp then return a.timestamp < b.timestamp end
        return a.id < b.id
    end)
    return entries
end

function ns:Delete(id)
    for index, entry in ipairs(self.album.entries) do
        if entry.id == id then table.remove(self.album.entries, index); return true end
    end
end

function ns:SaveCaption(entry, title, note)
    entry.title = (title or ""):gsub("|", ""):sub(1, 80)
    if entry.title:match("^%s*$") then entry.title = "Level " .. entry.level end
    entry.note = (note or ""):gsub("|", ""):sub(1, 500)
end

function ns:QueueLevel(level, attempt)
    if not self.album or not self.album.auto then return end
    C_Timer.After(2, function()
        local entry, err = self:Capture(true, level)
        if entry then
            self:Print("Saved your level " .. level .. " look.")
        elseif err and attempt < 5 then
            self:QueueLevel(level, attempt + 1)
        elseif err then
            self:Print("Could not save your level-up look. Use /looks save when ready.")
        end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event, level)
    if event == "PLAYER_LOGIN" then ns:Initialize()
    elseif level >= 1 and level <= 60 then ns:QueueLevel(level, 1) end
end)

SLASH_WARDROBETIMECAPSULE1 = "/looks"
SLASH_WARDROBETIMECAPSULE2 = "/wtc"
SlashCmdList.WARDROBETIMECAPSULE = function(command)
    if not ns.album and not ns:Initialize() then return end
    command = (command or ""):lower():match("^%s*(.-)%s*$")
    if command == "save" then
        local entry, err = ns:Capture(false)
        ns:Print(entry and "Look saved to your album." or err)
    elseif command == "lab" and ns.ToggleBackgroundLab then ns:ToggleBackgroundLab()
    elseif command == "debug" then ns:DebugTransmog()
    else ns:Toggle() end
end

-- /wtc debug: transmog readings, kept in WardrobeTimeCapsuleDB.forever.debugLog
-- (written to disk on /reload) so they can be inspected outside the game.
function ns:DebugTransmog()
    local log = {}
    self.db.debugLog = log
    local function V(v) return v == nil and "nil" or tostring(v) end
    local function Log(line) log[#log + 1] = line end
    local active = self:ActiveOutfit()
    Log(("showHelm %s showCloak %s | active outfit %s name %s"):format(V(ShowingHelm and ShowingHelm()),
        V(ShowingCloak and ShowingCloak()), V(active), V(active and self:OutfitName(active))))
    local probeEntry = {items = {}}
    for _, slot in ipairs(self.slots) do
        local info = SlotVisual(slot, APPEARANCE, MAIN)
        local id = GetInventoryItemID("player", slot)
        if id then probeEntry.items[slot] = {id = id, base = info and tonumber(info.baseSourceID)} end
        Log(("inv %d item %s | base %s applied %s"):format(slot, V(id), V(info and info.baseSourceID), V(info and info.appliedSourceID)))
    end
    self:Print("Collecting transmog debug...")
    self:DrawnLooks(function(list)
        if not list then Log("model: no appearances drawn")
        else
            for slot = 1, 19 do
                local info = list[slot]
                if info then
                    Log(("model inv %d: appearance %s secondary %s illusion %s"):format(slot,
                        V(info.appearanceID), V(info.secondaryAppearanceID), V(info.illusionID)))
                end
            end
            Log("looks found: " .. self:ApplyDrawn(probeEntry, list))
            for _, slot in ipairs(self.slots) do
                local look = probeEntry.items[slot] and probeEntry.items[slot].look or probeEntry.extra and probeEntry.extra[slot]
                if look then
                    Log(("  %s: appearance %s secondary %s illusion %s hidden %s"):format(self.slotNames[slot],
                        V(look.appearance), V(look.secondary), V(look.illusion), V(look.hidden)))
                end
            end
        end
        self:Print("Transmog debug saved. Type /reload so it is written to disk.")
    end)
end
