--[[
  Marks: what sits on the map at screen size.
  - level changes: a gold-rimmed disc in the target level's colour with its number (click: that level);
  - the instance portal: a round portal emblem, nudged aside when a level change sits on it;
  - bosses: round portraits from the "dungeons" service (rares silver). A click shows the boss and its loot
    beside the map (ns.Window.ShowBoss); a boss the service does not know gets no pin.
  A boss killed in this run (Kills) is greyed and crossed out.
  Marks.Create(view) -> marks;  marks:Show(id, map, level, onLevel(target)) on the room map;
  marks:ShowArt(id, floor) on the client's drawn map (bosses only)
]]
local _, ns = ...
local T = Sendit.Theme
local L = ns.L
local Marks = {}
ns.Marks = Marks

local LINK, PORTAL, PIN = 22, 26, 30
local NEAR = 12  -- map pixels: a level change this close pushes the portal emblem aside
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local PORTAL_ICON = "Interface\\Icons\\Spell_Arcane_PortalDarnassus"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function Has(list, value)
    for _, v in ipairs(list or {}) do if v == value then return true end end
    return false
end

local function Tip(owner, title, ...)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, T.Color("text"))
    local r, g, b = T.Color("textDim")
    for i = 1, select("#", ...) do GameTooltip:AddLine((select(i, ...)), r, g, b, true) end
    GameTooltip:Show()
end

local function Round(parent, size, ringRole)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(size, size)
    f.ring = T.Circle(f, ringRole, size + 3, "BACKGROUND")
    f.ring:SetPoint("CENTER")
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

local function LinkMark(parent)
    local m = Round(parent, LINK, "accent")
    m.disc = T.Circle(m, "text", LINK - 3, "ARTWORK")
    m.disc:SetPoint("CENTER")
    T.Own(m.disc)
    m.text = T.Text(m, "small", "text", "OVERLAY")
    m.text:SetPoint("CENTER", 0, 0)
    m:SetScript("OnEnter", function(self) Tip(self, self.title, L.goTip) end)
    return m
end

local function PortalMark(parent)
    local m = Round(parent, PORTAL, "accent")
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetSize(PORTAL - 2, PORTAL - 2)
    m.icon:SetPoint("CENTER")
    m.icon:SetTexture(PORTAL_ICON)
    pcall(m.icon.SetMask, m.icon, MASK)
    m:SetScript("OnEnter", function(self) Tip(self, L.portal, L.portalTip) end)
    m.label = T.Text(m, "label", "text", "OVERLAY")
    T.Own(m.label)
    m.label:SetTextColor(1, 0.85, 0.3)
    m.label:SetPoint("LEFT", m, "RIGHT", 6, 0)
    m.label:SetText(L.entrance)
    return m
end

local function Pin(parent)
    local pin = Round(parent, PIN, "accent")
    pin.face = pin:CreateTexture(nil, "ARTWORK")
    pin.face:SetSize(PIN, PIN)
    pin.face:SetPoint("CENTER")
    pin.dead = pin:CreateTexture(nil, "OVERLAY")
    pin.dead:SetSize(PIN - 6, PIN - 6)
    pin.dead:SetPoint("CENTER")
    pin.dead:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    pin.dead:Hide()
    pin:SetScript("OnEnter", function(self)
        Tip(self, self.title, self.killed and L.killed or (self.rare and L.rare or L.boss), L.bossTip)
    end)
    pin:SetScript("OnClick", function(self) ns.Window.ShowBoss(self.npc) end)
    return pin
end

local function Face(tex, display)
    local fn = _G["SetPortraitTextureFromCreatureDisplayID"]
    if fn and display and display > 0 and pcall(fn, tex, display) then return end
    tex:SetTexture(SKULL)
end

-- a boss killed in this run: the portrait greyed, a red cross over it
local function Dead(pin, id, info)
    pin.killed = ns.Kills.Killed(id, info.enc, pin.npc)
    pin.face:SetDesaturated(pin.killed == true)
    pin.dead:SetShown(pin.killed == true)
    pin:SetAlpha(pin.killed and 0.75 or 1)
end

local Methods = {}

function Methods:Pool(kind, make, i, level)
    local list = self[kind]
    local m = list[i]
    if not m then
        m = make(self.view.viewport)
        list[i] = m
        self.view:Add(m)
    end
    m:SetFrameLevel(self.view.viewport:GetFrameLevel() + level)
    m.dx, m.dy = 0, 0
    return m
end

function Methods:Show(id, map, level, onLevel)
    local used, links = 0, {}
    if level > 0 then
        for _, link in ipairs(map.links or {}) do
            if link[1] == level then
                used = used + 1
                local m, target = self:Pool("links", LinkMark, used, 600), link[2]
                local c = map.levels[target] or { 1, 1, 1 }
                m.mapX, m.mapY = link[3], link[4]
                m.disc:SetVertexColor(c[1], c[2], c[3], 1)
                m.text:SetText(target)
                m.title = (target > level and L.upTip or L.downTip):format(target)
                m:SetScript("OnClick", function() onLevel(target) end)
                m:Show()
                links[#links + 1] = m
            end
        end
    end
    for i = used + 1, #self.links do self.links[i]:Hide() end

    used = 0
    for _, portal in ipairs(map.portals or {}) do
        if level == 0 or portal[1] == level or portal[1] == 0 then
            used = used + 1
            local m = self:Pool("portals", PortalMark, used, 610)
            m.mapX, m.mapY = portal[2], portal[3]
            for _, l in ipairs(links) do
                if math.abs(l.mapX - m.mapX) + math.abs(l.mapY - m.mapY) < NEAR then m.dy = PORTAL + 4 end
            end
            m:Show()
        end
    end
    for i = used + 1, #self.portals do self.portals[i]:Hide() end

    local shown = 0
    local svc = Sendit.Service("dungeons")
    for _, b in ipairs(ns.bossPins[id] or {}) do
        local info = svc and svc.Boss and svc.Boss(b.npc)
        if info and (level == 0 or not b.levels or #b.levels == 0 or Has(b.levels, level)) then
            shown = shown + 1
            local pin = self:Pool("pins", Pin, shown, 620)
            pin.mapX, pin.mapY = b.x, b.y
            pin.title, pin.npc, pin.rare = info.name, b.npc, info.rare
            Face(pin.face, info.display)
        Dead(pin, id, info)
            Dead(pin, id, info)
            T.Paint(pin.ring, info.rare and "textDim" or "accent")
            pin:Show()
        end
    end
    for i = shown + 1, #self.pins do self.pins[i]:Hide() end
    self.view:Apply()
end

-- the height of the room a boss stands in (the room map's group under its pin), for the drawn map's floors
local function PinHeight(map, b)
    local want = b.levels and b.levels[1]
    for _, g in ipairs(map.groups) do
        local box = g.box
        if box and g.z and b.x >= box[1] and b.x <= box[1] + box[3] and b.y >= box[2] and b.y <= box[2] + box[4]
            and (not want or Has(g.levels, want)) then
            return (g.z[1] + g.z[2]) / 2
        end
    end
    return nil
end

-- the drawn map: only the bosses (stairs and the entrance are drawn on it) - at Blizzard's hand-set spot,
-- else through the world (Art.Locate)
function Methods:ShowArt(id, floor)
    for _, m in ipairs(self.links) do m:Hide() end
    for _, m in ipairs(self.portals) do m:Hide() end
    local svc = Sendit.Service("dungeons")
    local shown, placed = 0, {}
    local function Put(npc, px, py)
        local info = svc and svc.Boss and svc.Boss(npc)
        if not info or placed[npc] then return end
        placed[npc] = true
        shown = shown + 1
        local pin = self:Pool("pins", Pin, shown, 620)
        pin.mapX, pin.mapY = px, py
        pin.title, pin.npc, pin.rare = info.name, npc, info.rare
        Face(pin.face, info.display)
        Dead(pin, id, info)
        T.Paint(pin.ring, info.rare and "textDim" or "accent")
        pin:Show()
    end
    for _, p in ipairs(ns.Art.Pins(id, floor)) do Put(p[1], p[2], p[3]) end
    local map = ns.maps[id]
    for _, b in ipairs(map and ns.bossPins[id] or {}) do
        if not placed[b.npc] then
            local wx, wy = ns.Art.FromTiles(map, b.x, b.y)
            local f, px, py
            if wx then f, px, py = ns.Art.Locate(id, wx, wy, PinHeight(map, b)) end
            if f == floor then Put(b.npc, px, py) end
        end
    end
    for i = shown + 1, #self.pins do self.pins[i]:Hide() end
    self.view:Apply()
end

function Marks.Create(view)
    local marks = { view = view, links = {}, portals = {}, pins = {} }
    for name, fn in pairs(Methods) do marks[name] = fn end
    return marks
end
