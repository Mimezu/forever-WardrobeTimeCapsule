local _,ns=...
local DEFAULT_SKIN=10 -- Minimal Legacy: selected after the skin comparison.
-- Coordinated window studies. All use neutral leather for the character;
-- materials, borders, inset panels, trim and emphasis differ across the shell.
local function Style(name,material,surface,wash,metal,accent,inset,slots,band,description)
    return {name,material=material,surface=surface,wash=wash,metal=metal,accent=accent,
        inset=inset,slots=slots,band=band,description=description}
end
local variants={
    Style("Legacy Neutral","leather",{.9,.95,1},{.55,.55,.55,.09},{1,1,1},{1,.82,0},true,true,0,"Native gold frame · neutral leather"),
    Style("Bronze Archive","leather",{1,.90,.75},{.46,.28,.12,.16},{.92,.73,.48},{1,.77,.40},true,true,26,"Bronze insets · warm chapter bands"),
    Style("Royal Ledger","dialog",{.72,.78,1},{.12,.20,.43,.24},{.9,.94,1},{.72,.84,1},true,true,32,"Blue dialog panels · pale metal"),
    Style("Ranger Fieldbook","leather",{.8,1,.8},{.15,.28,.12,.20},{.77,.85,.56},{.78,.94,.55},false,true,22,"Olive leather · restrained gold trim"),
    Style("Arcane Cabinet","dialog",{.88,.75,1},{.27,.13,.38,.23},{.83,.73,1},{.87,.72,1},true,true,32,"Violet panels · framed equipment"),
    Style("Iron Armory","dialog",{.85,.88,.92},{.3,.33,.37,.18},{.76,.82,.91},{.83,.89,1},true,true,0,"Steel insets · quiet chapter rows"),
    Style("Tavern Chronicle","leather",{1,.79,.57},{.51,.27,.10,.19},{1,.78,.46},{1,.82,.51},false,false,28,"Warm leather · broad chapter bands"),
    Style("Frost Reliquary","dialog",{.72,.94,1},{.13,.34,.40,.23},{.70,.94,1},{.64,.94,1},true,true,22,"Cool stone-like panels · silver trim"),
    Style("Ember Vault","leather",{1,.72,.61},{.40,.12,.07,.20},{1,.65,.42},{1,.65,.35},true,true,28,"Copper trim · ember chapter bands"),
    Style("Minimal Legacy","leather",{.85,.9,.95},{.45,.48,.52,.08},{.78,.78,.72},{.9,.85,.68},false,false,0,"Thin internal rims · subdued accents"),
}
ns.backgroundVariants=variants

function ns:ApplyBackgroundVariant(index)
    index=tonumber(index)
    if not index or not variants[index] then index=DEFAULT_SKIN end
    self.db.wholeSkinVariant=index
    self.db.backgroundVariant=nil -- Retire paper selections from the old lab.
    local f=self.frame
    if not f or not f.previewPanel then return end
    local v=variants[index]
    self.OptionsSkin.ApplyWholeStyle(v)
    local texture=f.previewPanel.legacyBackground
    local info=C_Texture.GetAtlasInfo("Legacy-Challenge-BG")
    if texture and info then
        local du,dv=info.rightTexCoord-info.leftTexCoord,info.bottomTexCoord-info.topTexCoord
        texture:SetTexture(info.file or info.filename)
        texture:SetTexCoord(info.leftTexCoord+.05*du,info.rightTexCoord-.05*du,
            info.topTexCoord+.20*dv,info.bottomTexCoord-.02*dv)
        texture:SetVertexColor(.9,.95,1)
    end
    f.backgroundWash:SetColorTexture(.55,.55,.55,.22)
    for _,label in ipairs({f.meta,f.location,f.note,f.previewHint}) do label:SetTextColor(.95,.90,.79) end
    for _,label in ipairs({f.heading,f.journalTitle,f.memoryTitle,f.page}) do label:SetTextColor(unpack(v.accent)) end
    for _,row in ipairs(f.rows) do
        row.title:SetTextColor(unpack(v.accent))
        row.selected:SetColorTexture(v.accent[1],v.accent[2],v.accent[3],.20)
        if not row.skinBand then
            row.skinBand=row:CreateTexture(nil,"BACKGROUND",nil,-1)
            row.skinBand:SetPoint("TOPLEFT");row.skinBand:SetPoint("TOPRIGHT")
        end
        row.skinBand:SetHeight(math.max(1,v.band))
        row.skinBand:SetColorTexture(v.accent[1],v.accent[2],v.accent[3],.07)
        row.skinBand:SetShown(v.band>0)
    end
    if not f.previewBand then
        f.previewBand=f.previewPanel:CreateTexture(nil,"BACKGROUND",nil,-2)
        f.previewBand:SetPoint("TOPLEFT",5,-5);f.previewBand:SetPoint("TOPRIGHT",-5,-5)
        f.previewBand:SetHeight(60)
    end
    f.previewBand:SetColorTexture(v.accent[1],v.accent[2],v.accent[3],.07)
    f.previewBand:SetShown(v.band>0)
    if self.backgroundMenu then self:RefreshBackgroundMenu() end
end
function ns:RefreshBackgroundMenu()
    local menu=self.backgroundMenu
    local current=self.db.wholeSkinVariant or DEFAULT_SKIN
    for i,button in ipairs(menu.choices) do
        button:SetText((i==current and "> " or "")..i..". "..variants[i][1])
    end
    menu.description:SetText(variants[current].description)
    menu.status:SetText("Showing "..current.."  |  A: "..(self.backgroundA or "—").."  B: "..(self.backgroundB or "—"))
end

function ns:ToggleBackgroundLab()
    if not self.frame then self:Build(); self:Refresh(true)
    elseif not self.frame:IsShown() then self.frame:Show() end
    local menu=self.backgroundMenu
    if not menu then return end
    menu:SetShown(not menu:IsShown())
    self:RefreshBackgroundMenu()
end

function ns:BuildBackgroundLab(Button,Label)
    local f=self.frame
    local wash=f.previewPanel:CreateTexture(nil,"BACKGROUND",nil,-3)
    wash:SetPoint("TOPLEFT",3,-3); wash:SetPoint("BOTTOMRIGHT",-3,3)
    f.backgroundWash=wash
    local menu=CreateFrame("Frame",nil,f,"BackdropTemplate")
    menu:SetSize(214,382); menu:SetPoint("TOPLEFT",16,-100)
    menu:SetFrameStrata("DIALOG"); menu:EnableMouse(true)
    self.OptionsSkin.Panel(menu)
    self.backgroundMenu=menu
    Label(menu,"Skin lab",12,-12,"GameFontNormalLarge")
    Label(menu,"Live preview · entire journal",12,-35,"GameFontHighlightSmall")
    menu.choices={}
    for i,v in ipairs(variants) do
        local index=i
        menu.choices[i]=Button(menu,i..". "..v[1],194,10,-54-(i-1)*24,function()
            self:ApplyBackgroundVariant(index)
        end)
    end
    menu.description=Label(menu,"",12,-293,"GameFontHighlightSmall")
    menu.description:SetWidth(190);menu.description:SetWordWrap(true)
    menu.status=Label(menu,"",12,-327,"GameFontHighlightSmall")
    Button(menu,"Set A",58,10,-348,function()
        self.backgroundA=self.db.wholeSkinVariant; self:RefreshBackgroundMenu()
    end)
    Button(menu,"Set B",58,76,-348,function()
        self.backgroundB=self.db.wholeSkinVariant; self:RefreshBackgroundMenu()
    end)
    Button(menu,"A / B",62,142,-348,function()
        local a,b=self.backgroundA or 1,self.backgroundB or 2
        self.backgroundA,self.backgroundB=a,b
        self:ApplyBackgroundVariant(self.db.wholeSkinVariant==a and b or a)
    end)
    menu:Hide()
    -- The skin comparison is finished; the lab stays available through /wtc lab.
    f:HookScript("OnHide",function() menu:Hide() end)
    -- Adopt the chosen skin once, without overriding future lab selections.
    if not self.db.minimalLegacyChosen then
        self.db.wholeSkinVariant=DEFAULT_SKIN
        self.db.minimalLegacyChosen=true
    end
    self:ApplyBackgroundVariant(self.db.wholeSkinVariant or DEFAULT_SKIN)
end


