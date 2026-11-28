--[[
  Overlay: the compact map - a small see-through map of the instance you are in, centred on you, on your
  level. Shown while the profile's "overlay" is on and you are inside an instance with a map.
  Drag moves it, the wheel zooms, a click opens the map window. Account: overlay = { point, zoom }.
  Overlay.Refresh() / Overlay.Shown()
]]
local _, ns = ...
local T, W = Sendit.Theme, Sendit.Widgets
local Overlay = {}
ns.Overlay = Overlay

local SIZE, MIN_ZOOM, MAX_ZOOM, STEP = 240, 0.4, 4, 1.2
local ALPHA = 0.85

local frame, rooms, drawn, view, marks, player
local shown, level, room, art

local function Store()
    local db = ns.module.db
    db.overlay = type(db.overlay) == "table" and db.overlay or {}
    return db.overlay
end

local function Create()
    local db = Store()
    frame = CreateFrame("Frame", "SenditMapsOverlay", UIParent)
    Sendit.ownFrames[frame] = true
    frame:SetSize(SIZE, SIZE)
    frame:SetFrameStrata("MEDIUM")
    frame:SetAlpha(ALPHA)
    frame:Hide()
    T.Fill(frame, "bg", "BACKGROUND", 0, 0.75):SetAllPoints()
    T.Border(frame, "border")
    frame.viewport = CreateFrame("Frame", nil, frame)
    frame.viewport:SetPoint("TOPLEFT", 1, -1)
    frame.viewport:SetPoint("BOTTOMRIGHT", -1, 1)
    rooms = ns.Canvas.Create(frame.viewport)
    drawn = ns.Art.CreateCanvas(frame.viewport)
    view = ns.View.Create(frame.viewport, rooms, true)
    view.zoom = db.zoom or 1.2
    marks = ns.Marks.Create(view)
    player = ns.Arrow.Create(view, function(x, y) view:CenterOn(x, y) end)  -- the map keeps you centred

    W.Movable(frame, frame.viewport, { store = db, key = "point", default = { "TOPRIGHT", "TOPRIGHT", -24, -240 } })
    frame.viewport:EnableMouseWheel(true)
    frame.viewport:SetScript("OnMouseWheel", function(_, delta)
        view.zoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, view.zoom * (delta > 0 and STEP or 1 / STEP)))
        db.zoom = view.zoom
        if player:IsShown() then view:CenterOn(player.mapX, player.mapY) else view:Apply() end
    end)
    frame.viewport:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and not frame.moved then ns.Window.Open() end
        frame.moved = nil
    end)
    frame.viewport:HookScript("OnDragStart", function() frame.moved = true end)
end

-- the same look as the window (Catalog.Look)
local function Build(id)
    local map = ns.maps[id]
    shown, level, room = id, nil, nil
    local look, style = ns.Catalog.Look(id)
    art = look == "art"
    rooms.style = style
    view.canvas = art and drawn or rooms
    rooms:SetShown(not art)
    drawn:SetShown(art)
    if art then
        drawn:Build(ns.Art.Floor(id, 1))
        level = 1
        marks:ShowArt(id, 1)
    else
        rooms:Build(map)
        rooms:Paint(0, false)
        marks:Show(id, map, 0, function() end)
    end
    player:Hide()
    view:Fit()
    view.zoom = Store().zoom or 1.2
    view:Apply()
end

local function Track(s, id)
    if not (frame and frame:IsShown()) then return end
    if id ~= shown then Build(id) end
    if art then
        local floor, px, py = ns.Art.Player(id, s and s.wx, s and s.wy)
        if not floor and s and s.wx then floor, px, py = ns.Art.Locate(id, s.wx, s.wy, s.wz) end
        if not floor then return player:Hide() end
        if floor ~= level then
            level = floor
            drawn:Build(ns.Art.Floor(id, floor))
            marks:ShowArt(id, floor)
        end
        return player:Target(px, py, s.facing)
    end
    if not s or s.outside or not s.x then
        player:Hide()
        return
    end
    local want = (#ns.maps[id].levels > 1 and s.level) or 0
    if want ~= level or s.room ~= room then  -- a repaint walks every tile: only on a change
        local moved = want ~= level
        level, room = want, s.room
        rooms:Paint(level, false, room)
        if moved then marks:Show(id, ns.maps[id], level, function() end) end
    end
    player:Target(s.x, s.y, s.facing)
end
ns.Tracker.On(Track)
ns.Kills.OnChange(function()  -- cross out the dead
    if not (frame and frame:IsShown() and shown) then return end
    if art then marks:ShowArt(shown, level or 1) else marks:Show(shown, ns.maps[shown], level or 0, function() end) end
end)

function Overlay.Refresh()
    local here = ns.Catalog.Here()
    local want = ns.module.profile and ns.module.profile.overlay == true and ns.Catalog.Has(here)
    if want and not frame then Create() end
    if frame then
        frame:SetShown(want)
        local style = ns.module.profile.mapStyle
        if want and (shown ~= here or style ~= frame.style) then
            frame.style = style
            Build(here)
        end
    end
    ns.Tracker.Want("overlay", want)
end

function Overlay.Shown() return frame ~= nil and frame:IsShown() end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", Overlay.Refresh)
Sendit.OnSettingsChanged(Overlay.Refresh)
