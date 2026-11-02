local root = "Interface/AddOns/WardrobeTimeCapsule/"
local ns, events, timers = {}, {}, {}
local level, guid, missing = 1, "Player-A", false
local playerClass,petExists="DRUID",false
function UnitClass() return playerClass,playerClass end
function UnitExists(unit) return unit=="pet" and petExists end
local gear = {[5] = 100, [16] = 200, [17] = 201}
function CreateFrame() return {RegisterEvent=function() end, SetScript=function(_, event, fn) events[event]=fn end} end
function UnitGUID() return guid end
function UnitName() return "Adventurer" end
function UnitLevel() return level end
function time() return 1000 end
function GetRealZoneText() return "Elwynn Forest" end
function GetSubZoneText() return "Northshire" end
function GetInventoryItemID(_, slot) return gear[slot] end
function GetInventoryItemLink(_, slot) if gear[slot] and not missing then return "item:" .. gear[slot] end end
function GetInventoryItemTexture(_, slot) return gear[slot] end
function ShowingHelm() return false end
function ShowingCloak() return true end
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
SlashCmdList = {}
C_Timer = {After=function(_, fn) timers[#timers+1]=fn end}
assert(loadfile(root .. "Core.lua"))("WardrobeTimeCapsule", ns)
events.OnEvent(nil, "PLAYER_LOGIN")
assert(ns.album.auto == true, "Level-up saving starts on for a new album")
local first = assert(ns:Capture(false))
assert(first.level == 1 and first.zone == "Elwynn Forest" and first.subzone == "Northshire")
assert(first.items[5].link == "item:100" and first.items[1] == nil and first.showHelm == false)
gear[5] = 999
assert(first.items[5].link == "item:100", "Snapshots must not change with equipment")
missing = true
assert(ns:Capture(false) == nil and #ns.album.entries == 1, "Partial equipment must not be saved")
missing = false
ns:SaveCaption(first, "|cffff0000My outfit", "At the abbey")
assert(not first.title:find("|", 1, true) and first.note == "At the abbey")
ns:SaveCaption(first, "  ", string.rep("x", 600))
assert(first.title == "Level 1" and #first.note == 500)
ns.album.auto = true
events.OnEvent(nil, "PLAYER_LEVEL_UP", 2)
level = 2
table.remove(timers, 1)()
assert(#ns.album.entries == 2 and ns.album.lastAutoLevel == 2)
assert(ns:Capture(true) == nil, "Repeated events must not duplicate a level")
level = 11
local eleven = assert(ns:Capture(false))
level = 10
assert(ns:Capture(false))
assert(#ns:Entries(0) == 3 and #ns:Entries(1) == 1)
local sorted = ns:Entries()
assert(sorted[3].level == 10 and sorted[4].level == 11)
assert(ns:Delete(eleven.id) and not ns:Delete(eleven.id))
local oldAlbum = ns.album
ns:Initialize()
assert(ns.album == oldAlbum and #ns.album.entries == 3, "Initialization must preserve saved memories")
guid = "Player-B"
ns:Initialize()
assert(#ns.album.entries == 0 and ns.album ~= oldAlbum, "Albums must be isolated by character")
level = 60
assert(ns:Capture(false))
level = 61
assert(ns:Capture(false) == nil)
level = 20
ns.album.auto = true
events.OnEvent(nil, "PLAYER_LEVEL_UP", 20)
ns.album.auto = false
table.remove(timers, 1)()
assert(#ns.album.entries == 1, "Disabling automatic capture must cancel pending saves")
-- Check replay clears current equipment, preserves empty slots and honors hidden helm/cloak.
StaticPopupDialogs, CANCEL = {}, "Cancel"
assert(loadfile(root .. "UI.lua"))("WardrobeTimeCapsule", ns)
local replayed, cleared, unit = {}, false, false
local model = {
    SetPosition=function(_,x,y,z) assert(x==0 and y==0 and z==0) end,
    SetPortraitZoom=function(_,zoom) assert(zoom==0,'Replay resets full-body framing') end,
    ClearModel=function() cleared=true end,
    SetUnit=function(_, value) unit=value end,
    Undress=function() replayed={} end,
    TryOn=function(_, link, slot) replayed[#replayed+1]={link, slot} end,
}
ns.frame = {model=model}
first.items[1] = {link="item:777"}
ns:Replay(first)
assert(cleared and unit == "player" and #replayed == 3)
assert(replayed[3][2] == "SECONDARYHANDSLOT")
ns:Replay({items={}})
assert(#replayed == 0, "Naked snapshots must not retain live gear")
-- Transmog: the applied appearance is stored beside the real item and replayed by default.
local applied = {[5] = {appearanceID=5005, secondaryAppearanceID=0, illusionID=0},
    [16] = {appearanceID=0, secondaryAppearanceID=0, illusionID=0}}
local baseInfo = {[5] = {appearanceID=1005, secondaryAppearanceID=0, illusionID=0},
    [16] = {appearanceID=1016, secondaryAppearanceID=0, illusionID=0},
    [17] = {appearanceID=1017, secondaryAppearanceID=0, illusionID=0}}
ItemLocation = {CreateFromEquipmentSlot=function(_, slot) return {slot=slot} end}
C_Item = {
    GetAppliedItemTransmogInfo=function(loc) return applied[loc.slot] or baseInfo[loc.slot] end,
    GetBaseItemTransmogInfo=function(loc) return baseInfo[loc.slot] end,
}
C_TransmogCollection = {GetSourceIcon=function(id) return "icon" .. id end,
    GetAppearanceSourceInfo=function(id) return {itemLink="item:look" .. id} end}
gear[5] = 100
ns.frame.IsShown = function() return false end
local mogged = assert(ns:Capture(false))
assert(mogged.items[5].link == "item:100" and mogged.items[5].look.appearance == 5005, "Real item and transmog both stored")
assert(mogged.items[5].look.icon == "icon5005" and mogged.items[5].look.link == "item:look5005")
assert(mogged.items[16].look == nil and mogged.items[17].look == nil, "Untransmogged slots (0 or base) store no look")
assert(ns:HasTransmog(mogged) and not ns:HasTransmog(first))
ns:Replay(mogged)
assert(replayed[1][1] == 5005, "Transmog replays by default")
ns.showReal = true
ns:Replay(mogged)
assert(replayed[1][1] == "item:100", "Real gear view shows the item under the transmog")
ns.showReal = false
C_Item.GetAppliedItemTransmogInfo = function() error("secret") end
local fallback = assert(ns:Capture(false))
assert(fallback.items[5].look == nil, "API failure falls back to real gear")
ns:Delete(mogged.id); ns:Delete(fallback.id)
C_Item, ItemLocation, C_TransmogCollection = nil, nil, nil
-- Outfit-era transmog: read through C_Transmog.GetSlotVisualInfo per character slot.
local visuals = {["5:0:0"]={baseSourceID=1005, appliedSourceID=7005},
    ["3:0:0"]={baseSourceID=1003, appliedSourceID=1003}, ["3:0:1"]={baseSourceID=1003, appliedSourceID=7303},
    ["16:0:0"]={baseSourceID=1016, appliedSourceID=0}, ["16:1:0"]={baseSourceID=0, appliedSourceID=5900}}
C_Transmog = {GetSlotVisualInfo=function(loc)
    return visuals[loc.slotID .. ":" .. loc.type .. ":" .. loc.modification] or {baseSourceID=1, appliedSourceID=0}
end}
gear[3] = 300
local outfitLook = assert(ns:Capture(false))
assert(outfitLook.items[5].look.appearance == 7005, "Slot API transmog captured")
assert(outfitLook.items[3].look.appearance == 1003 and outfitLook.items[3].look.secondary == 7303, "Split shoulder keeps base main")
assert(outfitLook.items[16].look.appearance == 1016 and outfitLook.items[16].look.illusion == 5900, "Illusion-only weapon")
assert(outfitLook.items[17].look == nil, "Untransmogged slot stays real")
ns:Delete(outfitLook.id); gear[3] = nil; C_Transmog = nil
-- Outfit transmog: nothing is applied to items; a hidden player model reports what is drawn.
C_Transmog = {GetSlotVisualInfo=function(loc)
    return {baseSourceID = loc.slotID * 10, appliedSourceID = 0}
end}
C_TransmogOutfitInfo = {GetActiveOutfitID=function() return 2 end,
    IsEquippedGearOutfitDisplayed=function() return false end,
    GetOutfitInfo=function() return {name="Redemption", playerFacingOutfitIndex=1} end}
local drawnList = {[1]={appearanceID=0}, [3]={appearanceID=333}, [4]={appearanceID=40},
    [5]={appearanceID=104602, secondaryAppearanceID=0, illusionID=0},
    [16]={appearanceID=160, secondaryAppearanceID=-1, illusionID=0}, [17]={appearanceID=0}}
local probeModel
local stubCreateFrame = CreateFrame
CreateFrame = function(kind)
    if kind ~= "DressUpModel" then return stubCreateFrame(kind) end
    local m = {scripts={}}
    for _, name in ipairs({"SetSize", "SetPoint", "SetAlpha", "EnableMouse", "Show", "Hide"}) do m[name] = function() end end
    function m:SetScript(event, fn) self.scripts[event] = fn end
    function m:SetUnit(unit) self.unit = unit end
    function m:GetItemTransmogInfoList() return drawnList end
    probeModel = m
    return m
end
gear[1], gear[4] = 50, 60
local worn = assert(ns:Capture(false))
assert(worn.items[5].look == nil and probeModel.unit == "player", "Looks arrive after the model loads")
probeModel.scripts.OnModelLoaded(probeModel)
probeModel.scripts.OnUpdate(probeModel, .5)
assert(worn.drawn and worn.items[5].look.appearance == 104602, "Outfit appearance read from the drawn model")
assert(worn.items[1].look.hidden, "Equipped but undrawn slot is hidden")
assert(worn.items[4].look == nil and worn.items[16].look == nil, "Drawn base appearance is the real item")
assert(worn.extra[3].appearance == 333, "Appearance drawn over an empty slot is kept")
assert(worn.outfit.name == "Redemption" and worn.outfit.index == 1)
ns:Replay(worn)
local drew = {}
for _, call in ipairs(replayed) do drew[call[1]] = true end
assert(drew[104602] and drew[333] and not drew["item:50"] and drew["item:60"], "Replay draws the look as worn")
ns.showReal = true; ns:Replay(worn)
drew = {}
for _, call in ipairs(replayed) do drew[call[1]] = true end
assert(drew["item:100"] and not drew[333], "Real gear view drops transmog-only slots")
ns.showReal = false
CreateFrame = stubCreateFrame
ns:Delete(worn.id); gear[1], gear[4] = nil, nil; C_Transmog, C_TransmogOutfitInfo = nil, nil
print("PASS: capture, cache readiness, immutable gear, captions, automatic levels, filters, deletion, persistence, character isolation, level boundaries and replay")

-- UI lifecycle smoke test. Font strings deliberately do not accept frame scripts.
local F = {}; F.__index = F
local function widget(kind) return setmetatable({kind=kind, scripts={}, visible=true}, F) end
local noop = function() end
for method in ("SetPoint SetSize SetFrameStrata SetClampedToScreen EnableMouse SetMovable SetBackdrop " ..
    "SetScale SetAllPoints SetColorTexture SetTexture SetBackdropBorderColor SetWidth SetHeight " ..
    "SetJustifyH SetWordWrap SetHighlightTexture SetAlpha EnableMouseWheel RegisterForDrag " ..
    "StartMoving StopMovingOrSizing SetAutoFocus SetMaxLetters SetFontObject SetMultiLine " ..
    "SetFocus SetScrollChild SetVerticalScroll ClearModel SetUnit Undress TryOn SetPortraitZoom"):gmatch("%S+") do F[method]=noop end
function F:SetScript(event, fn) assert(self.kind ~= "FontString"); self.scripts[event]=fn end
function F:RegisterEvent(event) self.events=self.events or {};self.events[event]=true end
function F:SetUnit(unit) self.unit=unit end
function F:ClearModel() self.unit=nil end
function F:SetSize(w,h) self.width,self.height=w,h end
function F:SetPoint(...) self.anchor={...} end
function F:GetSize() return self.width or 100,self.height or 24 end
function F:ClearAllPoints() end
function F:GetFrameLevel() return 10 end
function F:SetFrameLevel(value) self.level=value end
function F:HookScript(event,fn)
 local prior=self.scripts[event]
 self.scripts[event]=function(...) if prior then prior(...) end; fn(...) end
end
function F:SetAtlas(name,size)
 self.atlas=name
 if size then local info=C_Texture.GetAtlasInfo(name);self:SetSize(info.width,info.height) end
end
function F:SetTexCoord() end
function F:SetVertexColor() end
function F:SetTextColor(...) self.ink={...} end
function F:IsEnabled() return self.enabled~=false end
function F:SetPosition(x,y,z) self.position={x,y,z} end
function F:SetPortraitZoom(value) self.zoomValue=value end
function F:CreateFontString() return widget("FontString") end
function F:CreateTexture() return widget("Texture") end
function F:SetText(text) self.text=text end
function F:SetTexture(texture) self.texture=texture end
function F:GetText() return self.text end
function F:GetStringHeight() return 50 end
function F:SetFacing(value) self.facing=value end
function F:GetFacing() return self.facing end
function F:SetEnabled(value) self.enabled=value end
function F:SetChecked(value) self.checked=value end
function F:GetChecked() return self.checked end
function F:IsShown() return self.visible end
function F:Show() self:SetShown(true) end
function F:Hide() self:SetShown(false) end
function F:SetShown(value)
    local changed=self.visible ~= value; self.visible=value
    local fn=self.scripts[value and "OnShow" or "OnHide"]
    if changed and fn then fn(self) end
end
function CreateFrame(kind) return widget(kind) end
UIParent = {GetWidth=function() return 1920 end, GetHeight=function() return 1080 end}
UISpecialFrames = {}
date = os.date
ns.frame = nil
C_Texture={GetAtlasInfo=function() return {file=123,width=300,height=25,
 leftTexCoord=.1,rightTexCoord=.9,topTexCoord=.2,bottomTexCoord=.8} end}
NineSliceUtil={ApplyLayoutByName=function(frame,name) frame.layout=name;frame.TopEdge=widget('Texture') end}
assert(loadfile(root..'LegacySkin.lua'))('WardrobeTimeCapsule',ns)
assert(loadfile(root..'BackgroundLab.lua'))('WardrobeTimeCapsule',ns)
function F:SetClipsChildren() end
function F:SetDesaturated(value) self.desaturated=value end
function F:GetFont() return self.fontPath or "Fonts\\FRIZQT__.TTF", self.fontSize or 12, "" end
function F:SetFont(path,size) self.fontPath,self.fontSize=path,size end
function F:GetTextColor() return unpack(self.ink or {1,1,1}) end
function F:SetParent(parent) self.parent=parent end
function F:GetChildren() end
function F:SetHighlightAtlas(atlas) self.highlight=atlas end
function F:SetHighlightTexture(texture) self.highlight=texture end
function UnitRace() return "Undead","Scourge" end
function F:SetRotation(value) self.rotation=value end
function F:SetGradient() end
function F:SetBlendMode() end
function CreateColor(r,g,b,a) return {r=r,g=g,b=b,a=a} end
assert(loadfile(root..'Compositions.lua'))('WardrobeTimeCapsule',ns)
ns:Toggle()
local selectedBefore=ns.selected
for i=1,10 do
 ns:ApplyBackgroundVariant(i)
 assert(ns.db.wholeSkinVariant==i and ns.selected==selectedBefore,'Live skins preserve selected memory')
 assert(ns.frame.heading.ink[1]==ns.backgroundVariants[i].accent[1],'Coordinated heading ink')
 assert(ns.OptionsSkin.current==ns.backgroundVariants[i],'Entire shell changes with the selected skin')
 assert(ns.frame.previewPanel.skinInset.visible==ns.backgroundVariants[i].inset,'Native inset treatment switches')
 assert(ns.frame.items[1].skinRim.visible==ns.backgroundVariants[i].slots,'Slot decoration switches')
end
ns:ApplyBackgroundVariant(999)
assert(ns.db.wholeSkinVariant==10 and ns.db.backgroundVariant==nil,'Invalid/retired variants fall back to Minimal Legacy')
ns:ApplyBackgroundVariant(3)
assert(ns.db.wholeSkinVariant==3,'Selection persists in saved settings')
assert(ns.frame.model.width==430 and ns.frame.model.height==450,'Taller full-body viewport')
assert(ns.frame.width==780 and ns.frame.height==750 and ns.frame.auto.anchor[3]==-715 and
    715+ns.frame.auto.height<=ns.frame.height-12,'Auto-save checkbox clears the metal footer')
assert(ns.frame.next.anchor[2]+ns.frame.next.width<=ns.frame.width-12,'Next button stays inside narrower window')
assert(#ns.frame.rows==9,'Taller list displays nine memories')
assert(ns.frame.model.zoomValue==0,'Initial replay uses full-body camera')
ns.frame.model.zoom=1
ns.frame.model.scripts.OnModelLoaded()
assert(ns.frame.model.zoomValue==0 and ns.frame.model.zoom==0,'Async load resets portrait zoom')
assert(ns.frame:IsShown() and ns.current.level == 60)
ns:Edit()
assert(ns.editor.entry == ns.current)
ns:Toggle()
assert(not ns.frame:IsShown() and not ns.editor:IsShown())
ns:Toggle()
assert(ns.frame:IsShown())
ns.filter=0; ns:Refresh()
assert(ns.current == nil and not ns.frame.model:IsShown() and not ns.frame.delete.enabled)
ns.filter=nil; ns:Refresh()
assert(ns.current.level == 60 and ns.frame.model:IsShown())
assert(not ns.frame.petModel:IsShown(),'Non-hunters have no companion preview')
playerClass,petExists='HUNTER',true
ns.frame.petModel.scripts.OnEvent(nil,'UNIT_PET','player')
assert(ns.frame.petModel:IsShown() and ns.frame.petModel.unit=='pet','Hunter pet shown when summoned')
assert(ns.frame.model.width==430 and ns.frame.model.anchor[4]==-25,'Hunter retains full character viewport')
ns.frame.petModel.scripts.OnModelLoaded()
assert(ns.frame.petModel.zoomValue==0,'Pet loads full-body rather than portrait')
petExists=false
ns.frame.petModel.scripts.OnEvent(nil,'UNIT_PET','player')
assert(not ns.frame.petModel:IsShown() and ns.frame.petModel.unit==nil,'Dismissal clears stale model')
assert(ns.frame.model.anchor[4]==50,'Solo character recenters')
petExists=true;ns:RefreshPetPreview()
ns.filter=0;ns:Refresh()
assert(not ns.frame.petModel:IsShown(),'Empty memories hide the pet too')
ns.filter=nil;playerClass='WARLOCK';ns:Refresh()
assert(not ns.frame.petModel:IsShown(),'Other classes do not show pets')
assert(ns.frame.previewHint.text=='' and not ns.frame.previewHint:IsShown(),'Rotation hint removed')
assert(ns.frame.underneath:IsShown() and not ns.frame.underneath.enabled and ns.frame.lookMode.text == "No transmog recorded", "Toggle disabled without transmog")
ns.current.items[5] = {link="item:100", look={appearance=5005, secondary=0, illusion=0, icon="mog"}}
ns:Refresh()
assert(ns.frame.underneath.enabled and ns.frame.underneath.text == "Show real gear")
assert(ns.frame.items[4].look and ns.frame.items[4].texture.texture == "mog", "Icons show the transmog")
ns.frame.underneath.scripts.OnClick()
assert(ns.showReal and ns.frame.underneath.text == "Show transmog" and ns.frame.items[4].look == nil)
ns:Toggle(); ns:Toggle()
assert(not ns.showReal, "Reopening returns to the transmog view")
-- Journal compositions: every style applies, and Current restores the Legacy journal.
local accent=ns.backgroundVariants[ns.db.wholeSkinVariant].accent
assert(ns.frame.stylesButton and ns.compositionMenu and not ns.compositionMenu:IsShown())
ns.frame.stylesButton.scripts.OnClick()
assert(ns.compositionMenu:IsShown() and ns.compositionMenu.choices[1].text=="> Current")
for _,key in ipairs(ns.compositionOrder) do
    ns:ApplyComposition(key)
    assert(ns.db.composition==key,'Composition persists')
end
assert(ns.frame.heading.fontPath=="Fonts\\MORPHEUS.TTF" and ns.frame.heading.ink[1]<.5,'Paper styles use ink headings')
ns:ApplyBackgroundVariant(ns.db.wholeSkinVariant)
assert(ns.frame.heading.fontPath=="Fonts\\MORPHEUS.TTF",'Skin lab keeps the chosen composition')
ns:ApplyComposition("current")
assert(ns.frame.heading.ink[1]==accent[1] and ns.frame.heading.fontPath~="Fonts\\MORPHEUS.TTF",'Current restores the Legacy journal')
assert(ns.frame.rows[1].highlight=="Interface\\QuestFrame\\UI-QuestTitleHighlight")
ns:ApplyComposition("nonsense")
assert(ns.db.composition=="current",'Unknown styles fall back to Current')
-- Opening shows the newest memory in its level range.
ns.album.entries[#ns.album.entries+1]={id=900,level=17,timestamp=5000,zone="",subzone="",items={},title="Level 17",note=""}
ns.filter,ns.selected=nil,nil
ns:Toggle(); ns:Toggle()
assert(ns.filter==1 and ns.selected==900 and ns.current.id==900,'Journal opens on the latest memory and its range')
assert(ns.frame.items[1].anchor[2]==16 and ns.frame.items[8].anchor[2]==482,'Slot icons keep air from the page edges')
ns:Delete(900); ns.filter=nil; ns:Refresh()
-- Backdrop scenes follow where each memory was saved.
function UnitFactionGroup() return "Horde" end
assert(ns:SceneRace({zone="Orgrimmar",subzone="The Drag"})=="Orc")
assert(ns:SceneRace({zone="Durotar",subzone="Echo Isles"})=="Troll")
assert(ns:SceneRace({zone="Stonetalon Mountains",subzone="",continent="Kalimdor"})=="Orc",'Continent fallback by faction')
assert(ns:SceneRace({zone="Deadmines",subzone=""})=="Scourge",'Unknown zones use the player race')
GetFileIDFromPath=function(path) if path:find("Gnome") then return nil end return 1 end
assert(ns:SceneRace({zone="Gnomeregan",subzone=""})=="Scourge",'Missing scene files fall back to the player race')
GetFileIDFromPath=nil
-- The memory list scrolls with the mouse wheel and keeps the selection in view.
for i=1,12 do ns.album.entries[#ns.album.entries+1]={id=1000+i,level=20+i,timestamp=6000+i,zone="",subzone="",items={},title="Scroll "..i,note=""} end
ns.filter,ns.selected,ns.listOffset=nil,1001,0; ns:Refresh()
local top=ns.frame.rows[1].entry
ns.frame.memoryPanel.scripts.OnMouseWheel(nil,-1)
assert(ns.listOffset==1 and ns.frame.rows[1].entry~=top,'Wheel scrolls the memory list')
for _=1,50 do ns.frame.memoryPanel.scripts.OnMouseWheel(nil,-1) end
assert(ns.listOffset==#ns.listEntries-9,'Scrolling stops at the last memory')
ns.selected=ns.listEntries[1].id; ns:Refresh()
assert(ns.listOffset==0,'Selecting a memory brings it into view')
for i=1,12 do ns:Delete(1000+i) end; ns.listOffset=0; ns:Refresh()
print("PASS: UI construction, opening, captions, closing, reopening and empty filters")
