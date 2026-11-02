local _, A = ...
local S = {}
S.panels=setmetatable({}, {__mode="k"})
S.buttons=setmetatable({}, {__mode="k"})
A.OptionsSkin = S

-- Standalone Legacy artwork: no dependency on Frame Gambit or BindCards.

local function Texture(frame, atlas, layer, sub)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetAtlas(atlas, true)
    return t
end

-- The smooth rail uses a center texel of the native atlas. Repeating the
-- entire ornamented edge produces the seams found during Frame Gambit QA.
local function Plate(frame, atlas, borderOnly)
    local art = { pieces = {} }
    function art:Update()
        local info = C_Texture.GetAtlasInfo(atlas)
        if not info then return end
        local w,h = frame:GetSize()
        if w <= 0 or h <= 0 then return end
        if self.w == w and self.h == h then return end
        self.w,self.h = w,h
        local x,y = math.min(5,w/2,info.width/2),math.min(5,h/2,info.height/2)
        local iw,ih = info.width,info.height
        local sections = {
            {0,0,x,y,0,0,x,y}, {w-x,0,x,y,iw-x,0,x,y},
            {0,h-y,x,y,0,ih-y,x,y}, {w-x,h-y,x,y,iw-x,ih-y,x,y},
            {x,0,w-2*x,y,math.floor(iw/2),0,1,y},
            {x,h-y,w-2*x,y,math.floor(iw/2),ih-y,1,y},
            {0,y,x,h-2*y,0,math.floor(ih/2),x,1},
            {w-x,y,x,h-2*y,iw-x,math.floor(ih/2),x,1},
            {x,y,w-2*x,h-2*y,x,y,iw-2*x,ih-2*y},
        }
        for i,p in ipairs(sections) do
            if borderOnly and i==9 then break end
            local t = self.pieces[i] or frame:CreateTexture(nil,borderOnly and "BORDER" or "BACKGROUND",nil,borderOnly and 1 or -2)
            self.pieces[i] = t
            t:SetTexture(info.file or info.filename)
            local du,dv = info.rightTexCoord-info.leftTexCoord,info.bottomTexCoord-info.topTexCoord
            t:SetTexCoord(info.leftTexCoord+du*p[5]/iw,info.leftTexCoord+du*(p[5]+p[7])/iw,
                info.topTexCoord+dv*p[6]/ih,info.topTexCoord+dv*(p[6]+p[8])/ih)
            t:ClearAllPoints(); t:SetPoint("TOPLEFT",frame,"TOPLEFT",p[1],-p[2])
            t:SetSize(math.max(.01,p[3]),math.max(.01,p[4]))
            t:SetShown(self.visible ~= false)
        end
    end
    function art:SetShown(show)
        self.visible=show
        if show then self:Update() end
        for _,t in ipairs(self.pieces) do t:SetAlpha(1); t:SetShown(show) end
    end
    function art:Tint(color)
        for _,t in ipairs(self.pieces) do t:SetVertexColor(color[1],color[2],color[3],color[4] or 1) end
    end
    art:Update()
    return art
end

local function Leather(frame)
    local t = Texture(frame,"Legacy-Challenge-BG","BACKGROUND",-4)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT",3,-3); t:SetPoint("BOTTOMRIGHT",-3,3)
    local info = C_Texture.GetAtlasInfo("Legacy-Challenge-BG")
    if info then
        local du,dv=info.rightTexCoord-info.leftTexCoord,info.bottomTexCoord-info.topTexCoord
        t:SetTexture(info.file or info.filename)
        t:SetTexCoord(info.leftTexCoord+.05*du,info.rightTexCoord-.05*du,
            info.topTexCoord+.20*dv,info.bottomTexCoord-.02*dv)
    end
    return t
end

function S.Panel(frame)
    if frame.SetBackdrop then frame:SetBackdrop(nil) end
    local background=Leather(frame)
    frame.legacyBackground=background
    local rim=Plate(frame,"common-button-list-collapseExpand",true)
    frame.legacyRim=rim
    frame:HookScript("OnSizeChanged",function() rim:Update() end)
    S.panels[frame]=true
    if S.current then S.StylePanel(frame,S.current) end
    return background
end

function S.Button(button)
    -- Remove only template-owned textures; labels and preview colors survive.
    for _,key in ipairs({"Left","Middle","Right","LeftSeparator","RightSeparator"}) do
        if button[key] then button[key]:Hide() end
    end
    for _,key in ipairs({"GetNormalTexture","GetPushedTexture","GetDisabledTexture","GetHighlightTexture"}) do
        local texture=button[key] and button[key](button)
        if texture then texture:SetAlpha(0) end
    end
    local art=Plate(button,"common-button-list-collapseExpand")
    local hover=button:CreateTexture(nil,"HIGHLIGHT")
    hover:SetPoint("TOPLEFT",4,-4); hover:SetPoint("BOTTOMRIGHT",-4,4)
    hover:SetColorTexture(1,.7,.2,.12)
    local pressed=false
    local function Update()
        local shade=not button:IsEnabled() and .45 or pressed and .7 or 1
        local tint=S.current and S.current.metal or {1,1,1}
        art:Tint({shade*tint[1],shade*tint[2],shade*tint[3],1})
        local label=button.GetFontString and button:GetFontString()
        if label and S.current then
            local ink=S.current.accent
            label:SetTextColor(ink[1]*shade,ink[2]*shade,ink[3]*shade)
        end
    end
    button:HookScript("OnSizeChanged",function() art:Update() end)
    button:HookScript("OnMouseDown",function() pressed=true; Update() end)
    button:HookScript("OnMouseUp",function() pressed=false; Update() end)
    button:HookScript("OnHide",function() pressed=false; Update() end)
    button:HookScript("OnEnable",Update); button:HookScript("OnDisable",Update)
    S.buttons[button]=Update
    Update()
    return art
end

function S.StylePanel(frame,style)
    local bg=frame.legacyBackground
    if not frame.skinBase then
        frame.skinBase=frame:CreateTexture(nil,"BACKGROUND",nil,-5)
        frame.skinBase:SetAllPoints(bg);frame.skinBase:SetColorTexture(.055,.045,.035,1)
    end
    if frame~=A.frame.previewPanel then
        if bg.SetHorizTile then bg:SetHorizTile(style.material=="dialog");bg:SetVertTile(style.material=="dialog") end
        if style.material=="dialog" then
            bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
            bg:SetTexCoord(0,1,0,1)
        else
            local info=C_Texture.GetAtlasInfo("Legacy-Challenge-BG")
            if info then
                bg:SetTexture(info.file or info.filename)
                local du,dv=info.rightTexCoord-info.leftTexCoord,info.bottomTexCoord-info.topTexCoord
                bg:SetTexCoord(info.leftTexCoord+.05*du,info.rightTexCoord-.05*du,
                    info.topTexCoord+.20*dv,info.bottomTexCoord-.02*dv)
            end
        end
        bg:SetVertexColor(unpack(style.surface))
    end
    if not frame.skinWash then
        frame.skinWash=frame:CreateTexture(nil,"BACKGROUND",nil,-3)
        frame.skinWash:SetPoint("TOPLEFT",12,-13);frame.skinWash:SetPoint("BOTTOMRIGHT",-6,6)
    end
    frame.skinWash:SetColorTexture(unpack(style.wash))
    frame.skinWash:SetShown(frame~=A.frame.previewPanel)
    frame.legacyRim:Tint(style.metal)
    if frame==A.frame.previewPanel or frame==A.frame.memoryPanel then
        if not frame.skinInset then
            local inset=CreateFrame("Frame",nil,frame)
            inset:SetPoint("TOPLEFT",2,-2);inset:SetPoint("BOTTOMRIGHT",-2,2)
            inset:EnableMouse(false)
            NineSliceUtil.ApplyLayoutByName(inset,"InsetFrameTemplate")
            frame.skinInset=inset
        end
        frame.skinInset:SetShown(style.inset)
        frame.legacyRim:SetShown(not style.inset)
        for _,key in ipairs({"TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner","TopEdge","BottomEdge","LeftEdge","RightEdge"}) do
            if frame.skinInset[key] then frame.skinInset[key]:SetVertexColor(unpack(style.metal)) end
        end
    end
end

function S.ApplyWholeStyle(style)
    S.current=style
    for panel in pairs(S.panels) do S.StylePanel(panel,style) end
    for _,update in pairs(S.buttons) do update() end
    local f=A.frame
    for _,key in ipairs({"TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner","TopEdge","BottomEdge","LeftEdge","RightEdge"}) do
        if f.legacyBorder[key] then f.legacyBorder[key]:SetVertexColor(unpack(style.metal)) end
    end
    for _,icon in ipairs(f.items) do
        if not icon.skinRim then
            icon.skinRim=Plate(icon,"common-button-list-collapseExpand",true)
            icon.texture:ClearAllPoints();icon.texture:SetPoint("TOPLEFT",3,-3);icon.texture:SetPoint("BOTTOMRIGHT",-3,3)
        end
        icon.skinRim:Tint(style.metal)
        icon.skinRim:SetShown(style.slots)
    end
end



function S.WindowBorder(frame)
    if frame.legacyRim then frame.legacyRim:SetShown(false) end
    local border=CreateFrame("Frame",nil,frame)
    -- Compensate the native layout's external offsets, preserving its artwork.
    border:SetPoint("TOPLEFT",8,-16); border:SetPoint("BOTTOMRIGHT",-4,3)
    border:SetFrameLevel(frame:GetFrameLevel()+1); border:EnableMouse(false)
    NineSliceUtil.ApplyLayoutByName(border,"ButtonFrameTemplateNoPortrait")
    frame.legacyBorder=border
    local chrome=CreateFrame("Frame",nil,frame)
    chrome:SetAllPoints(frame); chrome:SetFrameLevel(frame:GetFrameLevel()+2)
    chrome:EnableMouse(false)
    return chrome
end
