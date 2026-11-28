--[[
  Window: the map window - instances on the left (yours marked), the map with its levels on the right.
  Window.Open([id]) the instance you are in, else the last one shown / Toggle() / Hide() / Shown()
  Window.ShowBoss(npc) the boss and its loot beside the map
  Looks (Catalog.Look, profile mapStyle): the rooms in the drawn look (default) or as pictures (levels, level
  changes, the portal, the player's room tinted), or the client's own drawn map (its floors in the level
  column; raids without room data always).
  Inside the instance shown: the player's arrow (Tracker), the level / floor following the player when it
  changes. Window.Tracking() -> on
  Window.Refresh() after a settings or language change.  Account: ns.module.db.window (point); a fixed size.
]]
local _, ns = ...
local T, W = Sendit.Theme, Sendit.Widgets
local L = ns.L
local Window = {}
ns.Window = Window

local WIDTH, HEIGHT = 1040, 680
local HEADER, PAD, SIDE, ROW = 64, 16, 230, 26

local frame, canvas, rooms, drawn, view, marks, levels, boss, player
local mode  -- "art" | "rooms" for the map shown
local FLOOR = { 0.85, 0.72, 0.45 }  -- the level column's stripe for a drawn map's floors
local PARCHMENT = { 0.62, 0.5, 0.33 }  -- the ground under the drawn look
local follow, lastLevel, room  -- follow the first fix's level, the last fix's level, the room shown
local current, level = nil, 0
local rows, heads = {}, {}

local function Profile() return ns.module.profile end

-- the drawn map: the room tiles' map only where the player picked them and they exist
local function Mode(id) return ns.Catalog.Look(id) end

local floorLevels = {}
local function Floors(n)  -- the level column's model of n drawn floors
    if not floorLevels[n] then
        local list = {}
        for i = 1, n do list[i] = FLOOR end
        floorLevels[n] = { levels = list }
    end
    return floorLevels[n]
end

local function SetLevel(value)
    if value ~= level and canvas.fade then canvas.fade:Restart() end  -- a new level blends in
    level = value
    if mode == "art" then
        local floors = ns.Art.Floors(current)
        if canvas.floor ~= floors[level] then
            canvas.floor = floors[level]
            canvas:Build(ns.Art.Floor(current, level))
            view:Fit()
        end
        marks:ShowArt(current, level)
        levels:Set(Floors(#floors), level, lastLevel, true)
        return
    end
    canvas:Paint(level, Profile().others ~= false, room)
    marks:Show(current, ns.maps[current], level, SetLevel)
    levels:Set(ns.maps[current], level, lastLevel)
end

-- the header: the instance's loading screen behind the title, fading into the window
local function Banner(id)
    local svc = Sendit.Service("dungeons")
    local info = svc and svc.Map and svc.Map(id)
    local art = info and info.art
    frame.banner:SetShown(art ~= nil and art ~= 0)
    if art and art ~= 0 then
        frame.banner:SetTexture(art)
        frame.banner:SetTexCoord(0, 1, 0.38, 0.52)
    end
end

local function PaintList()
    local here = ns.Catalog.Here()
    for _, row in ipairs(rows) do
        row.sel:SetShown(row.id == current)
        row.here:SetShown(row.id == here)
        T.Paint(row.text, row.id == current and "accent" or "text")
    end
end

-- the edges of the map darken (a vignette over the plain map background)
local function Vignette()
    for _, e in ipairs(frame.vignette) do
        local v, s = e.tex, e.side
        pcall(v.SetGradient, v, s[2], CreateColor(0, 0, 0, s[3]), CreateColor(0, 0, 0, s[4]))
    end
end

local function Show(id)
    if not ns.Catalog.Has(id) then return end
    current = id
    ns.module.db.last = id
    boss:Close()
    follow, lastLevel, room = true, nil, nil
    if player then player:Hide() end
    local style
    mode, style = Mode(id)
    rooms.style = style
    canvas = mode == "art" and drawn or rooms
    -- the drawn look lies on parchment
    if style == "drawn" and mode == "rooms" then
        T.Own(frame.mapBg)
        frame.mapBg:SetColorTexture(PARCHMENT[1], PARCHMENT[2], PARCHMENT[3], 1)
    else
        T.Paint(frame.mapBg, "panel")
    end
    view.canvas = canvas
    rooms:SetShown(mode == "rooms")
    drawn:SetShown(mode == "art")
    frame.title:SetText(ns.Catalog.Name(id))
    Banner(id)
    if mode == "art" then
        drawn.floor = nil
        level = 0
        SetLevel(1)
    else
        canvas:Build(ns.maps[id])
        level = 0
        view:Fit()
        SetLevel(0)
    end
    PaintList()
end

local function BuildList()
    local y, r, h = 0, 0, 0
    local lastRaid
    for _, e in ipairs(ns.Catalog.List()) do
        if e.raid ~= lastRaid then
            lastRaid = e.raid
            h = h + 1
            local head = heads[h] or T.Text(frame.list.content, "small", "textMuted")
            heads[h] = head
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", 8, -y - 8)
            head:SetText((e.raid and L.raids or L.dungeons):upper())
            head:Show()
            y = y + 28
        end
        r = r + 1
        local row = rows[r]
        if not row then
            row = CreateFrame("Button", nil, frame.list.content)
            row:SetHeight(ROW)
            row:SetPoint("RIGHT")
            row.sel = T.Fill(row, "selected", "BACKGROUND")
            row.sel:SetAllPoints()
            T.Fill(row, "hover", "HIGHLIGHT"):SetAllPoints()
            row.here = T.Circle(row, "accent", 6, "ARTWORK")
            row.here:SetPoint("LEFT", 8, 0)
            row.text = T.Text(row, "label", "text")
            row.text:SetPoint("LEFT", 20, 0)
            row.text:SetPoint("RIGHT", -36, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row.lvl = T.Text(row, "small", "textMuted")
            row.lvl:SetPoint("RIGHT", -8, 0)
            row:SetScript("OnClick", function(self) Show(self.id) end)
            rows[r] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT")
        row.id = e.id
        row.text:SetText(e.name)
        row.lvl:SetText(e.min > 0 and tostring(e.min) or "")
        row:Show()
        y = y + ROW
    end
    for i = r + 1, #rows do rows[i]:Hide() end
    for i = h + 1, #heads do heads[i]:Hide() end
    frame.list.content:SetHeight(y + 8)
    PaintList()
end

local function Create()
    local db = ns.module.db.window
    frame = CreateFrame("Frame", "SenditMaps", UIParent)
    Sendit.ownFrames[frame] = true
    Sendit.Widgets.Stacked(frame)
    tinsert(UISpecialFrames, "SenditMaps")
    frame:Hide()
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    T.Fill(frame, "bg", "BACKGROUND"):SetAllPoints()
    local borders = T.Border(frame, "border")
    T.Decorate(frame, "window", { level = 10, onApply = function(_, on)
        for _, edge in ipairs(borders) do edge:SetShown(not on) end
    end })
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT", -40, 0)
    drag:SetHeight(HEADER)
    W.Movable(frame, drag, { store = db, key = "point", default = { "CENTER", "CENTER", 0, 20 },
        onDrop = function() if boss:IsShown() then boss:Place() end end })  -- the boss panel may change sides

    frame.banner = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    frame.banner:SetPoint("TOPLEFT", 1, -1)
    frame.banner:SetPoint("TOPRIGHT", -1, -1)
    frame.banner:SetHeight(HEADER - 1)
    frame.banner:SetAlpha(0.55)
    local fade = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
    fade:SetTexture(T.WHITE)
    fade:SetPoint("TOPLEFT", frame.banner)
    fade:SetPoint("BOTTOMRIGHT", frame.banner)
    local function FadeColor()
        local r, g, b = T.Color("bg")
        pcall(fade.SetGradient, fade, "HORIZONTAL", CreateColor(r, g, b, 0.95), CreateColor(r, g, b, 0.2))
    end
    FadeColor()
    frame.fadeColor = FadeColor
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("TOPLEFT", PAD, -17)
    icon:SetTexture(ns.ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.title = T.Text(frame, "title", "text")
    frame.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 1)
    frame.sub = T.Text(frame, "small", "textMuted")
    frame.sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 0)
    local close = W.Close(frame, Window.Hide)
    close:SetPoint("TOPRIGHT", -10, -12)
    -- the compact map on / off (it shows inside an instance with a map)
    frame.compact = W.Button(frame, Sendit.Locale.Text(L, "compact"), function()
        local p = ns.module.profile
        p.overlay = not p.overlay
        Sendit.SettingsChanged()
        local here = ns.Catalog.Here()
        -- outside an instance nothing appears yet: say where it will
        if p.overlay and not ns.Catalog.Has(here) then frame.sub:SetText(L.compactLater) end
    end)
    frame.compact:SetPoint("RIGHT", close, "LEFT", -12, 0)
    frame.compact:SetFrameLevel(drag:GetFrameLevel() + 5)  -- above the drag area, or it never gets the click
    -- the client's own world map (inside an instance the map key opens this window instead)
    frame.world = W.Button(frame, Sendit.Locale.Text(L, "worldMap"), function()
        if InCombatLockdown() then return frame.sub:SetText(L.worldMapCombat) end
        Window.Hide()
        local toggle = _G["ToggleWorldMap"]
        if toggle then pcall(toggle) end
    end)
    frame.world:SetPoint("RIGHT", frame.compact, "LEFT", -8, 0)
    frame.world:SetFrameLevel(drag:GetFrameLevel() + 5)
    close:SetFrameLevel(drag:GetFrameLevel() + 5)
    frame.compact.on = T.Fill(frame.compact, "accent", "ARTWORK")
    frame.compact.on:SetPoint("BOTTOMLEFT", 1, 1)
    frame.compact.on:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.compact.on:SetHeight(2)
    local rule = T.Fill(frame, "divider", "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -HEADER)
    rule:SetPoint("TOPRIGHT", 0, -HEADER)

    frame.list = W.ScrollArea(frame)
    frame.list:SetPoint("TOPLEFT", 0, -HEADER - 4)
    frame.list:SetPoint("BOTTOMLEFT", 0, PAD)
    frame.list:SetWidth(SIDE)
    local split = T.Fill(frame, "divider", "ARTWORK")
    split:SetWidth(1)
    split:SetPoint("TOPLEFT", SIDE, -HEADER)
    split:SetPoint("BOTTOMLEFT", SIDE, 0)

    frame.mapArea = CreateFrame("Frame", nil, frame)
    frame.mapArea:SetPoint("TOPLEFT", SIDE + 1, -HEADER - 1)
    frame.mapArea:SetPoint("BOTTOMRIGHT", -1, 1)
    boss = ns.BossPanel.Create(frame)
    frame.mapBg = T.Fill(frame.mapArea, "panel", "BACKGROUND")
    frame.mapBg:SetAllPoints()
    frame.viewport = CreateFrame("Frame", nil, frame.mapArea)
    frame.viewport:SetAllPoints()
    rooms = ns.Canvas.Create(frame.viewport)
    drawn = ns.Art.CreateCanvas(frame.viewport)
    for _, c in ipairs({ rooms, drawn }) do
        c.fade = c:CreateAnimationGroup()
        local blend = c.fade:CreateAnimation("Alpha")
        blend:SetFromAlpha(0.25)
        blend:SetToAlpha(1)
        blend:SetDuration(0.22)
    end
    canvas = rooms
    -- the map's edges darken: a vignette over the plain map background
    frame.vignette = {}
    for _, side in ipairs({ { "TOP", "VERTICAL", 0, 0.55 }, { "BOTTOM", "VERTICAL", 0.55, 0 } }) do
        local v = frame.mapArea:CreateTexture(nil, "BACKGROUND", nil, 1)
        frame.vignette[#frame.vignette + 1] = { tex = v, side = side }
        v:SetTexture(T.WHITE)
        v:SetPoint(side[1] .. "LEFT")
        v:SetPoint(side[1] .. "RIGHT")
        v:SetHeight(90)
    end
    Vignette()
    levels = ns.LevelBar.Create(frame.mapArea, SetLevel)
    levels:SetPoint("TOPRIGHT", -10, -10)
    levels:SetFrameLevel(frame.viewport:GetFrameLevel() + 700)
    view = ns.View.Create(frame.viewport, canvas)
    marks = ns.Marks.Create(view)
    player = ns.Arrow.Create(view)
    frame:SetScript("OnShow", function() ns.Tracker.Want("window", true) end)
    frame:SetScript("OnHide", function() ns.Tracker.Want("window", false) end)
    frame.viewport:SetScript("OnSizeChanged", function() if view.canvas.map then view:Apply() end end)

end

function Window.Open(id)
    if not frame then Create() end
    BuildList()
    local here = ns.Catalog.Here()
    id = id or here or ns.module.db.last
    if not ns.Catalog.Has(id) then
        local first = ns.Catalog.List()[1]
        id = first and first.id
    end
    frame:Show()
    frame.sub:SetText(here and not ns.Catalog.Has(here) and L.noMap or L.subtitle)  -- inside one without a map
    if id and id ~= current then Show(id) else PaintList() end
end

local function Status(text) frame.sub:SetText(text) end

function Window.Tracking() return Window.Shown() and ns.Tracker.Running() == current end

-- the drawn map: the floor whose world box holds the player, the arrow on it
local function TrackArt(s)
    local floor, px, py = ns.Art.Player(current, s and s.wx, s and s.wy)  -- the client's own floor and transform
    if not floor and s and s.wx then floor, px, py = ns.Art.Locate(current, s.wx, s.wy, s.wz) end
    if not floor then
        player:Hide()
        Status(s and L.outside or (ns.Tracker.Locating() and L.locating or L.subtitle))
        return
    end
    local moved = floor ~= lastLevel
    lastLevel = floor
    if floor ~= level and (follow or moved) then SetLevel(floor) end
    follow = false
    if floor == level then player:Target(px, py, s.facing) else player:Hide() end
    local count = #ns.Art.Floors(current)
    Status(count > 1 and L.hereLevel:format(floor) or L.here)
    if moved then levels:Set(Floors(count), level, lastLevel, true) end
end

local function Track(s, id)
    if not Window.Shown() or id ~= current then return end
    if mode == "art" then return TrackArt(s) end
    if not s or s.outside or not s.x then
        player:Hide()
        Status(s and L.outside or (ns.Tracker.Locating() and L.locating or L.subtitle))
        if room then room = nil; SetLevel(level) end
        return
    end
    player:Target(s.x, s.y, s.facing)
    local count = #ns.maps[current].levels
    local moved = s.level ~= nil and s.level ~= lastLevel
    lastLevel = s.level or lastLevel
    if s.level and count > 1 and level ~= s.level and (follow or (moved and level ~= 0)) then
        follow, room = false, s.room
        SetLevel(s.level)
    elseif s.room ~= room then
        room = s.room
        SetLevel(level)
    end
    if s.level then follow = false end
    Status(s.level and count > 1 and L.hereLevel:format(s.level) or L.here)
    if moved then levels:Set(ns.maps[current], level, lastLevel) end
end
ns.Tracker.On(Track)

function Window.ShowBoss(npc)
    if not Window.Shown() then Window.Open() end
    boss:ShowBoss(npc)
end
function Window.Hide() if frame then frame:Hide() end end
function Window.Toggle() if frame and frame:IsShown() then Window.Hide() else Window.Open() end end
function Window.Shown() return frame ~= nil and frame:IsShown() end

function Window.Refresh()
    if frame then
        frame.compact.on:SetShown(ns.module.profile.overlay == true)  -- the compact map's switch state
        frame.fadeColor()
    end
    if not Window.Shown() then return end
    BuildList()
    frame.sub:SetText(L.subtitle)
    if current then
        local look, style = Mode(current)
        if look ~= mode or (look == "rooms" and style ~= rooms.style) then return Show(current) end  -- the style changed
        frame.title:SetText(ns.Catalog.Name(current))
        SetLevel(level)
    end
end

Sendit.OnSettingsChanged(function() Window.Refresh() end)
ns.Kills.OnChange(function() if Window.Shown() and current then SetLevel(level) end end)  -- cross out the dead

