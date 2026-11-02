local _, ns = ...
-- Journal compositions built from Forever's native art. "Current" is the Legacy
-- metal-and-leather journal (with its Skin lab choice) and is always restored exactly.
local ORDER = {"current", "sheet", "tome", "scrapbook"}
local STYLES = {
    current = {name = "Current", note = "The journal as it is today: Legacy metal, leather panels."},
    sheet = {name = "Character Sheet", note = "Forever's character window: your race's dressing room, gear-slot frames, outfit cards and class art."},
    tome = {name = "Adventurer's Tome", note = "A spellbook spread: memories on the left page, your look on the right, in ink."},
    scrapbook = {name = "Scrapbook", note = "Quest parchment pages with a sepia photograph held by bronze corners."},
}
ns.compositionOrder, ns.compositions = ORDER, STYLES

local INK, INK_SOFT, INK_FAINT = {.24, .12, .03}, {.20, .15, .09}, {.36, .28, .19}
local RUBRIC = {.56, .09, .04} -- the red ink of a manuscript's headings
local MORPHEUS = "Fonts\\MORPHEUS.TTF"

local owned = {}
local function Own(key, region)
    owned[key] = owned[key] or {}
    owned[key][#owned[key] + 1] = region
    return region
end

local function HasAtlas(atlas)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
end

local function Atlas(texture, atlas, useSize)
    if not HasAtlas(atlas) then return false end
    texture:SetAtlas(atlas, useSize and true or false)
    return true
end

-- Crops an atlas like CSS "background-size: cover" so ornaments keep their proportions.
-- trim = {left, right, top, bottom} fractions of the atlas to discard first (empty margins).
local function Cover(texture, atlas, w, h, trim)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if not info or not info.width or info.width <= 0 or info.height <= 0 then return false end
    texture:SetTexture(info.file or info.filename)
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local aw, ah = info.width, info.height
    if trim then
        local du, dv = r - l, b - t
        l, r = l + du * trim[1], r - du * trim[2]
        t, b = t + dv * trim[3], b - dv * trim[4]
        aw, ah = aw * (1 - trim[1] - trim[2]), ah * (1 - trim[3] - trim[4])
    end
    local scale = math.max(w / aw, h / ah)
    local du = (r - l) * (1 - w / scale / aw) / 2
    local dv = (b - t) * (1 - h / scale / ah) / 2
    texture:SetTexCoord(l + du, r - du, t + dv, b - dv)
    return true
end

local function Tex(key, parent, layer, sublevel)
    return Own(key, parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0))
end

-- Forever's character window draws the race scene as four tiles on a 398x464 pane
-- (Camelot PaperDollFrame.xml). The same layout is scaled to cover the host, floor kept.
local PANE_W, PANE_H = 398, 464
local SCENE_PATH = "Interface\\DressUpFrame\\DressUpBackground-"

-- Every race's dressing-room scene shares one painted style and shows that race's
-- homeland, so a memory's backdrop follows where it was saved. Keys are lower-case
-- zone (or subzone) names from GetRealZoneText / GetSubZoneText.
local SCENE_BY_SUBZONE = {
    ["echo isles"] = "Troll", ["sen'jin village"] = "Troll", ["gnomeregan"] = "Gnome",
}
local SCENE_BY_ZONE = {
    ["tirisfal glades"] = "Scourge", ["undercity"] = "Scourge", ["silverpine forest"] = "Scourge",
    ["western plaguelands"] = "Scourge", ["eastern plaguelands"] = "Scourge",
    ["durotar"] = "Orc", ["orgrimmar"] = "Orc", ["the barrens"] = "Orc",
    ["northern barrens"] = "Orc", ["southern barrens"] = "Orc",
    ["mulgore"] = "Tauren", ["thunder bluff"] = "Tauren", ["thousand needles"] = "Tauren",
    ["stranglethorn vale"] = "Troll", ["the hinterlands"] = "Troll",
    ["elwynn forest"] = "Human", ["stormwind city"] = "Human", ["westfall"] = "Human",
    ["redridge mountains"] = "Human", ["duskwood"] = "Human", ["hillsbrad foothills"] = "Human",
    ["arathi highlands"] = "Human", ["alterac mountains"] = "Human",
    ["dun morogh"] = "Dwarf", ["ironforge"] = "Dwarf", ["loch modan"] = "Dwarf", ["wetlands"] = "Dwarf",
    ["gnomeregan"] = "Gnome",
    ["teldrassil"] = "NightElf", ["darnassus"] = "NightElf", ["darkshore"] = "NightElf",
    ["ashenvale"] = "NightElf", ["felwood"] = "NightElf", ["moonglade"] = "NightElf",
    ["eversong woods"] = "BloodElf", ["silvermoon city"] = "BloodElf", ["ghostlands"] = "BloodElf",
    ["azuremyst isle"] = "Draenei", ["the exodar"] = "Draenei", ["bloodmyst isle"] = "Draenei",
}
-- Zones with no homeland scene use their continent's capital for the player's faction.
local SCENE_BY_CONTINENT = {
    ["kalimdor"] = {Horde = "Orc", Alliance = "NightElf"},
    ["eastern kingdoms"] = {Horde = "Scourge", Alliance = "Human"},
}

local sceneExists = {}
local function HasScene(race)
    if sceneExists[race] == nil then
        local id = GetFileIDFromPath and GetFileIDFromPath(SCENE_PATH .. race .. "1")
        -- Without the lookup API, trust the table; Blizzard ships these for every race.
        sceneExists[race] = not GetFileIDFromPath or (id ~= nil and id ~= 0)
    end
    return sceneExists[race]
end

function ns:SceneRace(entry)
    local _, own = UnitRace("player")
    own = own or "Orc"
    if not entry then return own end
    local race = SCENE_BY_SUBZONE[(entry.subzone or ""):lower()] or SCENE_BY_ZONE[(entry.zone or ""):lower()]
    if not race and entry.continent then
        local byFaction = SCENE_BY_CONTINENT[entry.continent:lower()]
        race = byFaction and byFaction[UnitFactionGroup and UnitFactionGroup("player") or ""]
    end
    if race and race ~= own and not HasScene(race) then race = nil end
    return race or own
end

local scenes = {}
local function RaceScene(key, host, level)
    local w, h = host:GetSize()
    local clip = Own(key, CreateFrame("Frame", nil, host))
    clip:SetAllPoints(); clip:SetFrameLevel(level); clip:EnableMouse(false)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    local s = math.max(w / PANE_W, h / PANE_H)
    local scene = CreateFrame("Frame", nil, clip)
    scene:SetSize(PANE_W * s, PANE_H * s); scene:SetPoint("BOTTOM")
    clip.tiles = {}
    local function Tile(n, l, r, t, b)
        local tile = scene:CreateTexture(nil, "BACKGROUND")
        tile.index = n; tile:SetTexCoord(l, r, t, b)
        clip.tiles[#clip.tiles + 1] = tile
        return tile
    end
    local tl = Tile(1, .171875, 1, .0392, 1)
    tl:SetPoint("TOPLEFT"); tl:SetPoint("BOTTOMRIGHT", -79 * s, 129 * s)
    local tr = Tile(2, 0, .296875, .0392, 1)
    tr:SetWidth(80 * s); tr:SetPoint("TOPRIGHT"); tr:SetPoint("BOTTOMRIGHT", 0, 129 * s)
    local bl = Tile(3, .171875, 1, 0, .62)
    bl:SetHeight(130 * s); bl:SetPoint("BOTTOMLEFT"); bl:SetPoint("BOTTOMRIGHT", -79 * s, 0)
    local br = Tile(4, 0, .296875, 0, .62)
    br:SetSize(80 * s, 130 * s); br:SetPoint("BOTTOMRIGHT")
    local overlay = scene:CreateTexture(nil, "BORDER")
    if Atlas(overlay, "UI-Character-Info-RaceBG-Overlay") then overlay:SetAllPoints(clip) else overlay:Hide() end
    clip.overlay = overlay
    clip.scene = scene
    function clip:SetRace(race)
        if self.race == race then return end
        self.race = race
        for _, tile in ipairs(self.tiles) do tile:SetTexture(SCENE_PATH .. race .. tile.index) end
    end
    clip:SetRace(ns:SceneRace(ns.current))
    scenes[#scenes + 1] = clip
    return clip
end

-- Soft ground shadow under the character's feet.
local function FeetShadow(key, page, level, alpha)
    local holder = Own(key, CreateFrame("Frame", nil, page))
    holder:SetAllPoints(); holder:SetFrameLevel(level); holder:EnableMouse(false)
    local shadow = holder:CreateTexture(nil, "ARTWORK")
    if Atlas(shadow, "perks-char-shadow") then
        -- Soles land about 455px down the page with the full-body camera (measured in game).
        shadow:SetSize(190, 28); shadow:SetPoint("CENTER", page, "TOPLEFT", 272, -456)
        shadow:SetAlpha(alpha or .8)
    else
        shadow:Hide()
    end
    return holder
end

-- A thin ink frame around an equipment icon, for paper compositions.
local function InkFrames(key, f)
    for _, icon in ipairs(f.items) do
        local frame = Tex(key, icon, "BACKGROUND", -1)
        frame:SetPoint("TOPLEFT", -2, 2); frame:SetPoint("BOTTOMRIGHT", 2, -2)
        frame:SetColorTexture(INK[1], INK[2], INK[3], .55)
        icon.inkFrames = icon.inkFrames or {}
        icon.inkFrames[key] = frame
    end
end

local function RowDividers(key, f, color)
    for _, row in ipairs(f.rows) do
        -- Bookmark ribbon beside the selected memory; shown by StyleCompositionSlots.
        local ribbon = Tex(key, row, "ARTWORK", 1)
        ribbon:SetWidth(4); ribbon:SetPoint("TOPLEFT", 0, -3); ribbon:SetPoint("BOTTOMLEFT", 0, 3)
        ribbon:SetColorTexture(RUBRIC[1], RUBRIC[2], RUBRIC[3], .9)
        row.inkRibbons = row.inkRibbons or {}
        row.inkRibbons[key] = ribbon
        local line = Tex(key, row, "ARTWORK")
        line:SetHeight(1); line:SetPoint("BOTTOMLEFT", 6, 0); line:SetPoint("BOTTOMRIGHT", -6, 0)
        line:SetColorTexture(color[1], color[2], color[3], color[4])
    end
end

local builders = {}

function builders.sheet(f, key, levels)
    local list, page = f.memoryPanel, f.previewPanel
    local _, class = UnitClass("player")
    local classArt = Tex(key, list, "BACKGROUND", 2)
    classArt:SetPoint("TOPLEFT", 3, -3); classArt:SetPoint("BOTTOMRIGHT", -3, 3)
    if not Cover(classArt, "UI-Character-Info-" .. (class or "WARRIOR") .. "-BG", 202, 570) and
        not Cover(classArt, "UI-Character-Info-Stat-StoneBG", 202, 570) then
        classArt:SetColorTexture(.08, .07, .06, 1)
    end
    local shade = Tex(key, list, "BACKGROUND", 3)
    shade:SetAllPoints(classArt); shade:SetColorTexture(0, 0, 0, .45)
    local banner = Tex(key, list, "BACKGROUND", 4)
    if Atlas(banner, "UI-Character-Info-Title") then
        banner:SetPoint("TOPLEFT", 4, -6); banner:SetPoint("TOPRIGHT", -4, -6); banner:SetHeight(26)
    else
        banner:Hide()
    end
    for _, row in ipairs(f.rows) do
        local card = Tex(key, row, "BACKGROUND", -2)
        if Atlas(card, "UI-Character-Info-OutfitCard") then card:SetAllPoints() else card:SetColorTexture(0, 0, 0, .35); card:SetAllPoints() end
    end
    local scene = RaceScene(key, page, levels.scene)
    scene:ClearAllPoints(); scene:SetPoint("TOPLEFT", 4, -4); scene:SetPoint("BOTTOMRIGHT", -4, 4)
    -- Dark bands keep the heading and caption legible over the scene.
    local top = scene.scene:CreateTexture(nil, "ARTWORK")
    top:SetPoint("TOPLEFT", scene, "TOPLEFT"); top:SetPoint("TOPRIGHT", scene, "TOPRIGHT"); top:SetHeight(66)
    top:SetColorTexture(0, 0, 0, .55)
    local bottom = scene.scene:CreateTexture(nil, "ARTWORK")
    bottom:SetPoint("BOTTOMLEFT", scene, "BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT"); bottom:SetHeight(62)
    bottom:SetColorTexture(0, 0, 0, .55)
    local title = scene.scene:CreateTexture(nil, "OVERLAY")
    if Atlas(title, "UI-Character-Info-Title") then
        title:SetPoint("TOP", scene, "TOP", 0, -4); title:SetSize(440, 30)
    else
        title:Hide()
    end
    FeetShadow(key, page, levels.shadow)
    for _, icon in ipairs(f.items) do
        local slot = Tex(key, icon, "BACKGROUND", -1)
        if Atlas(slot, "UI-Character-Info-GearSlot", true) then
            slot:SetPoint("CENTER")
            local w, h = slot:GetSize()
            if not w or w < 36 then slot:SetSize(44, 44) end
        else
            slot:SetPoint("TOPLEFT", -3, 3); slot:SetPoint("BOTTOMRIGHT", 3, -3); slot:SetColorTexture(0, 0, 0, .6)
        end
    end
end

function builders.tome(f, key, levels)
    local list, page = f.memoryPanel, f.previewPanel
    -- Pages meet at the spine across the gap between the two panels. The spellbook page
    -- art carries an empty band above its paper edge (and a thin one below); trim both,
    -- and lay parchment underneath so any remaining margin still reads as paper.
    local PAGE_TRIM = {0, 0, .10, .035}
    for _, spec in ipairs({{list, "spellbook-Page-Left-C60", 0, 4}, {page, "spellbook-Page-Right-C60", -4, 0}}) do
        local panel, atlas, x0, x1 = spec[1], spec[2], spec[3], spec[4]
        local w, h = panel:GetSize()
        w = w - x0 + x1
        local under = Tex(key, panel, "BACKGROUND", 1)
        under:SetPoint("TOPLEFT", x0, 0); under:SetPoint("BOTTOMRIGHT", x1, 0)
        if not Cover(under, "QuestBG-Parchment", w, h) then under:SetColorTexture(.80, .69, .50, 1) end
        local sheet = Tex(key, panel, "BACKGROUND", 2)
        sheet:SetPoint("TOPLEFT", x0, 0); sheet:SetPoint("BOTTOMRIGHT", x1, 0)
        if not Cover(sheet, atlas, w, h, PAGE_TRIM) then sheet:Hide() end
    end
    local rule = Tex(key, page, "BACKGROUND", 3)
    rule:SetHeight(1); rule:SetPoint("TOPLEFT", 60, -70); rule:SetPoint("TOPRIGHT", -60, -70)
    rule:SetColorTexture(INK[1], INK[2], INK[3], .35)
    local footRule = Tex(key, page, "BACKGROUND", 3)
    footRule:SetHeight(1); footRule:SetPoint("TOPLEFT", 60, -540); footRule:SetPoint("TOPRIGHT", -60, -540)
    footRule:SetColorTexture(INK[1], INK[2], INK[3], .35)
    local titleRule = Tex(key, list, "BACKGROUND", 3)
    titleRule:SetHeight(1); titleRule:SetPoint("TOPLEFT", 12, -30); titleRule:SetPoint("TOPRIGHT", -12, -30)
    titleRule:SetColorTexture(INK[1], INK[2], INK[3], .35)
    FeetShadow(key, page, levels.shadow, .5)
    InkFrames(key, f)
    RowDividers(key, f, {INK[1], INK[2], INK[3], .18})
end

-- Deterministic noise, so a torn edge looks the same every time the journal opens.
local function Noise(seed)
    local state = seed
    return function()
        state = (state * 1103515245 + 12345) % 2147483648
        return state / 2147483648
    end
end

local function Gradient(texture, orientation, color, fromAlpha, toAlpha)
    texture:SetColorTexture(1, 1, 1, 1)
    if not (CreateColor and texture.SetGradient) then texture:SetColorTexture(color[1], color[2], color[3], (fromAlpha + toAlpha) / 2); return end
    pcall(texture.SetGradient, texture, orientation,
        CreateColor(color[1], color[2], color[3], fromAlpha), CreateColor(color[1], color[2], color[3], toAlpha))
end

-- Aged, torn paper edges for a sheet occupying (x, -y, w, h) inside `panel`: a darkened
-- rim, then irregular bites in the backdrop colour along every side.
local BACKDROP, AGED = {.10, .075, .05}, {.36, .20, .07}
-- tears: {side ("top", "bottom", "left", "right"), from, to} as fractions of that edge.
local function TornPaper(key, panel, x, y, w, h, seed, tears)
    local rnd = Noise(seed)
    local rim = 20
    local sides = {
        {"TOPLEFT", x, -y, w, rim, "VERTICAL", 0, .42},
        {"TOPLEFT", x, -(y + h - rim), w, rim, "VERTICAL", .42, 0},
        {"TOPLEFT", x, -y, rim, h, "HORIZONTAL", .42, 0},
        {"TOPLEFT", x + w - rim, -y, rim, h, "HORIZONTAL", 0, .42},
    }
    for _, side in ipairs(sides) do
        local tint = Tex(key, panel, "BACKGROUND", 3)
        tint:SetPoint(side[1], side[2], side[3]); tint:SetSize(side[4], side[5])
        Gradient(tint, side[6], AGED, side[7], side[8])
    end
    -- The tear is one continuous contour, like real torn paper: the edge is eaten away
    -- to a depth that wanders slowly (two long waves), with fine roughness and a rare
    -- small chip. Strips of backdrop colour run from the straight edge inward only, so
    -- nothing ever reaches outside the sheet.
    -- Each tear fades in and out (sine envelope) so it grows out of a clean edge.
    local STEP, OVER, CHIP_W = 3, 1.5, 15
    local function Edge(length, from, to, strip)
        local p1, p2, p3 = rnd() * 6.28, rnd() * 6.28, rnd() * 6.28
        local first, last = length * from, length * to
        local full = from == 0 and to == 1
        local chipFrom, chipDepth
        local chipAt = full and 60 + rnd() * 200 or first + 40 + rnd() * 120
        for pos = first, last - STEP, STEP do
            local envelope = full and 1 or math.sin(math.pi * (pos - first) / (last - first))
            local wave = .55 * math.sin(pos / 47 + p1) + .30 * math.sin(pos / 17 + p2) + .15 * math.sin(pos / 7 + p3)
            local depth = 1 + (wave + 1) + rnd() * .7 -- 1 to 3.7px at full strength
            -- A chip is a small rounded bite spread over CHIP_W px, not one deeper strip
            -- (which read as a perfect square notch).
            if pos >= chipAt then chipFrom, chipDepth = pos, 1.5 + rnd() * 1.5; chipAt = pos + 120 + rnd() * 260 end
            if chipFrom and pos - chipFrom < CHIP_W then
                depth = depth + chipDepth * math.sin(math.pi * (pos - chipFrom + STEP / 2) / CHIP_W)
            end
            depth = depth * envelope
            if depth >= .5 then strip(pos, depth) end
        end
    end
    local function Strip(px, py, sw, sh)
        local cut = Tex(key, panel, "BACKGROUND", 5)
        -- Neighbouring strips overlap by 1px along the edge: pixel snapping otherwise opens
        -- hairline gaps that let the paper show through as bright ticks.
        cut:SetPoint("TOPLEFT", px, py)
        cut:SetSize(sw == STEP and STEP + 1 or sw, sh == STEP and STEP + 1 or sh)
        cut:SetColorTexture(BACKDROP[1], BACKDROP[2], BACKDROP[3], 1)
    end
    for _, tear in ipairs(tears or {}) do
        local side, from, to = tear[1], tear[2], tear[3]
        -- Each strip also reaches OVER (1.5px) past the sheet's outer edge, into the dark
        -- margin: otherwise pixel rounding can leave the paper's outermost row uncovered,
        -- showing as bright specks. The inner (torn) side is unchanged.
        if side == "top" then Edge(w, from, to, function(p, d) Strip(x + p, -y + OVER, STEP, d + OVER) end)
        elseif side == "bottom" then Edge(w, from, to, function(p, d) Strip(x + p, -(y + h - d), STEP, d + OVER) end)
        elseif side == "left" then Edge(h, from, to, function(p, d) Strip(x - OVER, -(y + p), d + OVER, STEP) end)
        else Edge(h, from, to, function(p, d) Strip(x + w - d, -(y + p), d + OVER, STEP) end) end
    end
end



function builders.scrapbook(f, key, levels)
    local list, page = f.memoryPanel, f.previewPanel
    -- Both sheets are torn along all four edges.
    local ALL = {{"top", 0, 1}, {"bottom", 0, 1}, {"left", 0, 1}, {"right", 0, 1}}
    local tears = {ALL, ALL}
    for i, panel in ipairs({list, page}) do
        local w, h = panel:GetSize()
        local paper = Tex(key, panel, "BACKGROUND", 2)
        paper:SetPoint("TOPLEFT", 2, -2); paper:SetPoint("BOTTOMRIGHT", -2, 2)
        if not Cover(paper, "QuestBG-Parchment", w - 4, h - 4) then paper:SetColorTexture(.82, .72, .54, 1) end
        TornPaper(key, panel, 2, 2, w - 4, h - 4, 7919 * i, tears[i])
    end
    -- The photograph: soft shadow, an aged cream print margin, then a sepia dressing-room
    -- scene. It ends above the "Show real gear" row and keeps 8px of air from the ink
    -- frames of the slot icons (icons at x 16 and 482, 32 wide, frames 2px outside).
    local photo = Own(key, CreateFrame("Frame", nil, page))
    photo:SetPoint("TOPLEFT", 58, -72); photo:SetSize(414, 434)
    photo:SetFrameLevel(levels.scene); photo:EnableMouse(false)
    local shadow = photo:CreateTexture(nil, "BACKGROUND", nil, -3)
    shadow:SetPoint("TOPLEFT", 2, -3); shadow:SetPoint("BOTTOMRIGHT", 2, -3); shadow:SetColorTexture(0, 0, 0, .28)
    local margin = photo:CreateTexture(nil, "BACKGROUND", nil, -1)
    margin:SetAllPoints(); margin:SetColorTexture(.80, .72, .57, 1)
    local window = CreateFrame("Frame", nil, photo)
    window:SetPoint("TOPLEFT", 8, -8); window:SetSize(398, 418)
    local scene = RaceScene(key, window, levels.scene + 1)
    for _, tile in ipairs(scene.tiles) do tile:SetDesaturated(true); tile:SetVertexColor(1, .86, .64) end
    -- Dark race scenes print almost black: drop the vignette and lift the shadows a
    -- little with an additive sepia wash, like an old print (kept low so it stays moody).
    scene.overlay:Hide()
    local lift = scene.scene:CreateTexture(nil, "ARTWORK")
    lift:SetAllPoints(scene); lift:SetColorTexture(.15, .105, .05, 1)
    if lift.SetBlendMode then lift:SetBlendMode("ADD") end
    local fade = scene.scene:CreateTexture(nil, "ARTWORK", nil, 1)
    fade:SetAllPoints(scene); fade:SetColorTexture(.08, .05, .02, .26)
    -- Album photo corners: dark paper triangles tucked over each corner of the print,
    -- exactly on its edges. A 45-degree square centred on the corner is clipped to the
    -- print, leaving the triangle; a faint light line marks the paper fold. They sit above
    -- the character model so the photo reads as mounted in the album.
    local LEG = 30
    local mount = Own(key, CreateFrame("Frame", nil, page))
    mount:SetAllPoints(photo); mount:SetFrameLevel(levels.scene + 6); mount:EnableMouse(false)
    if mount.SetClipsChildren then mount:SetClipsChildren(true) end
    local paperCorners = CreateFrame("Frame", nil, mount)
    paperCorners:SetAllPoints(mount)
    for _, spec in ipairs({{"TOPLEFT", 1, -1, 45}, {"TOPRIGHT", -1, -1, -45}, {"BOTTOMLEFT", 1, 1, -45}, {"BOTTOMRIGHT", -1, 1, 45}}) do
        local point, sx, sy, fold = spec[1], spec[2], spec[3], spec[4]
        local tri = paperCorners:CreateTexture(nil, "ARTWORK")
        tri:SetSize(LEG * 1.4142, LEG * 1.4142); tri:SetPoint("CENTER", mount, point, 0, 0)
        tri:SetColorTexture(.13, .10, .07, 1)
        if tri.SetRotation then tri:SetRotation(math.rad(45)) end
        local edge = paperCorners:CreateTexture(nil, "ARTWORK", nil, 1)
        edge:SetSize(LEG * 1.4142, 1.2)
        edge:SetPoint("CENTER", mount, point, sx * LEG / 2, sy * LEG / 2)
        edge:SetColorTexture(.62, .52, .38, .55)
        if edge.SetRotation then edge:SetRotation(math.rad(fold)) end
    end
    InkFrames(key, f)
    RowDividers(key, f, {INK[1], INK[2], INK[3], .22})
end

-- Remembers a font string's native font and color before a composition restyles it.
local function Keep(fs)
    if not fs.wtcFont then fs.wtcFont = {fs:GetFont()} end
    if not fs.wtcColor then fs.wtcColor = {fs:GetTextColor()} end
    return fs
end

local function Ink(fs, color, font, size)
    Keep(fs)
    fs:SetTextColor(color[1], color[2], color[3])
    if font and fs.wtcFont[1] then pcall(fs.SetFont, fs, font, size or fs.wtcFont[2], "") end
end

local function Restore(fs)
    if fs.wtcFont and fs.wtcFont[1] then pcall(fs.SetFont, fs, fs.wtcFont[1], fs.wtcFont[2], fs.wtcFont[3]) end
    if fs.wtcColor then fs:SetTextColor(fs.wtcColor[1], fs.wtcColor[2], fs.wtcColor[3]) end
end

local function TextStrings(f)
    local list = {f.heading, f.meta, f.location, f.note, f.lookMode, f.memoryTitle, f.empty, f.previewHint}
    for _, row in ipairs(f.rows) do list[#list + 1] = row.title; list[#list + 1] = row.detail; list[#list + 1] = row.date end
    return list
end

local applyBase
function ns:ApplyComposition(key)
    key = STYLES[key] and key or self.db.composition or "current"
    if not STYLES[key] then key = "current" end
    self.db.composition = key
    local f = self.frame
    if not f or not f.previewPanel then return end
    for _, regions in pairs(owned) do for _, region in ipairs(regions) do region:Hide() end end
    for _, fs in ipairs(TextStrings(f)) do Restore(fs) end
    for _, row in ipairs(f.rows) do row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight") end
    applyBase(self, self.db.wholeSkinVariant)
    if key ~= "current" then
        for _, panel in ipairs({f.memoryPanel, f.previewPanel}) do
            if panel.legacyRim then panel.legacyRim:SetShown(false) end
            if panel.skinInset then panel.skinInset:Hide() end
        end
        for _, icon in ipairs(f.items) do if icon.skinRim then icon.skinRim:SetShown(false) end end
        for _, row in ipairs(f.rows) do if row.skinBand then row.skinBand:Hide() end end
        if not owned[key] then builders[key](f, key, f.compositionLevels) end
        for _, region in ipairs(owned[key]) do region:Show() end
        self:StyleCompositionText(key)
    end
    self:StyleCompositionSlots()
    if self.compositionMenu then self:RefreshCompositionMenu() end
end

function ns:StyleCompositionText(key)
    local f = self.frame
    if key == "sheet" then
        for _, row in ipairs(f.rows) do
            Ink(row.title, {1, .82, 0}); Ink(row.detail, {.95, .92, .85}); Ink(row.date, {.62, .58, .50})
            if not Atlas(row.selected, "UI-Character-Info-OutfitCard-Selected") then row.selected:SetColorTexture(1, .82, 0, .18) end
            if row.SetHighlightAtlas and HasAtlas("UI-Character-Info-OutfitCard-Hover") then pcall(row.SetHighlightAtlas, row, "UI-Character-Info-OutfitCard-Hover") end
        end
        Ink(f.heading, {1, .82, 0}); Ink(f.memoryTitle, {1, .82, 0})
        for _, fs in ipairs({f.meta, f.location, f.note}) do Ink(fs, {.96, .93, .86}) end
        Ink(f.lookMode, {.80, .76, .66}); Ink(f.empty, {.96, .93, .86})
        return
    end
    -- Paper compositions: dark ink, Morpheus headings like a hand-lettered page.
    for _, row in ipairs(f.rows) do
        Ink(row.title, INK, MORPHEUS, 15); Ink(row.detail, INK_SOFT); Ink(row.date, INK_FAINT)
        row.selected:SetColorTexture(.66, .40, .12, .34)
    end
    Ink(f.heading, INK, MORPHEUS, 24); Ink(f.memoryTitle, INK, MORPHEUS, 15)
    for _, fs in ipairs({f.meta, f.location}) do Ink(fs, INK_SOFT) end
    Ink(f.note, INK_SOFT); Ink(f.lookMode, INK_FAINT); Ink(f.empty, INK_SOFT)
end

-- Called after every journal refresh: empty equipment slots on paper become faint ink
-- marks instead of dark tiles.
function ns:StyleCompositionSlots()
    local f = self.frame
    local race = self:SceneRace(self.current)
    for _, scene in ipairs(scenes) do scene:SetRace(race) end
    local paper = self.db.composition == "tome" or self.db.composition == "scrapbook"
    for _, icon in ipairs(f.items) do
        local empty = not icon.item and not icon.look
        if paper and empty then
            icon.texture:SetDesaturated(true); icon.texture:SetVertexColor(.62, .50, .34); icon:SetAlpha(.45)
        else
            icon.texture:SetDesaturated(false); icon.texture:SetVertexColor(1, 1, 1)
        end
        local inkFrame = icon.inkFrames and icon.inkFrames[self.db.composition]
        if inkFrame then inkFrame:SetAlpha(empty and .35 or 1) end
    end
    if not paper then return end
    for _, row in ipairs(f.rows) do
        local selected = row.selected:IsShown()
        local ribbon = row.inkRibbons and row.inkRibbons[self.db.composition]
        if ribbon then ribbon:SetShown(selected) end
        local ink = selected and RUBRIC or INK
        row.title:SetTextColor(ink[1], ink[2], ink[3])
    end
end

function ns:RefreshCompositionMenu()
    local menu = self.compositionMenu
    local current = self.db.composition or "current"
    for i, key in ipairs(ORDER) do
        menu.choices[i]:SetText((key == current and "> " or "") .. STYLES[key].name)
    end
    menu.description:SetText(STYLES[current].note)
end

function ns:BuildCompositions(Button, Label)
    local f = self.frame
    local page = f.previewPanel
    -- Composition art sits between the panel and its contents. Lift the contents and the
    -- text above it; font strings otherwise draw beneath any child frame of the page.
    local base = page:GetFrameLevel()
    f.compositionLevels = {scene = base + 1, shadow = base + 5}
    for _, child in ipairs({page:GetChildren()}) do
        if child:GetFrameLevel() < base + 6 then child:SetFrameLevel(base + 6) end
    end
    local text = CreateFrame("Frame", nil, page)
    text:SetAllPoints(); text:SetFrameLevel(base + 8); text:EnableMouse(false)
    for _, fs in ipairs({f.heading, f.meta, f.location, f.lookMode, f.previewHint}) do fs:SetParent(text) end
    f.textLayer = text

    local styles = Button(f, "Styles", 90, 530, -40, function()
        self.compositionMenu:SetShown(not self.compositionMenu:IsShown())
        self:RefreshCompositionMenu()
    end)
    f.stylesButton = styles
    local menu = CreateFrame("Frame", nil, f, "BackdropTemplate")
    menu:SetSize(236, 212); menu:SetPoint("TOPRIGHT", styles, "BOTTOMRIGHT", 0, -4)
    menu:SetFrameStrata("DIALOG"); menu:EnableMouse(true)
    if self.OptionsSkin then self.OptionsSkin.Panel(menu) end
    Label(menu, "Journal style", 12, -12, "GameFontNormal")
    menu.choices = {}
    for i, key in ipairs(ORDER) do
        menu.choices[i] = Button(menu, STYLES[key].name, 212, 12, -34 - (i - 1) * 28, function()
            self:ApplyComposition(key)
        end)
    end
    menu.description = Label(menu, "", 14, -152, "GameFontHighlightSmall")
    menu.description:SetWidth(208); menu.description:SetJustifyH("LEFT"); menu.description:SetWordWrap(true)
    menu:Hide()
    self.compositionMenu = menu
    f:HookScript("OnHide", function() menu:Hide() end)

    -- The Skin lab recolors "Current"; keep a chosen composition on top of it.
    applyBase = self.ApplyBackgroundVariant
    function self:ApplyBackgroundVariant(index)
        applyBase(self, index)
        if (self.db.composition or "current") ~= "current" and not self.applyingComposition then
            self.applyingComposition = true
            self:ApplyComposition(self.db.composition)
            self.applyingComposition = false
        end
    end
    self:ApplyComposition(self.db.composition or "current")
end
