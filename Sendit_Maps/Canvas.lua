--[[
  Canvas: one instance map drawn from its WMO group tiles (map pixels; View scales and moves it).
  Canvas.Create(parent) -> canvas
  canvas:Build(map)                        textures for every group (and the ground of terrain maps)
  canvas:Paint(level, others, room)        level 0 = all; others: the other levels faint behind; room:
                                           the group the player is in (tinted)
  canvas:SetZoom(zoom)                     keeps the lines the same width on screen
  Look: the chosen level warm, other levels cold and pale, the level's edge a faint accent line.
  canvas.style = "drawn" (set before Build): the classic drawn-map look made from the rooms' own pictures -
  each room's picture as a dark silhouette nudged four ways under it (an ink rim of its exact shape), the
  picture itself greyed and lifted towards parchment (the floor keeps its drawing).
  Groups of one building keep their draw order; the chosen level's groups lie above the rest.
]]
local _, ns = ...
local Canvas = {}
ns.Canvas = Canvas

local OTHER_ALPHA, CONTINUING_ALPHA = 0.28, 0.55
local GROUND_OVERLAP = 0.6  -- ground tiles overlap a little: no seams when scaled
local OUTLINE_WIDTH, OUTLINE_ALPHA = 1, 0.35
local WARM = { 1, 0.95, 0.86 }   -- the chosen level
local COLD = { 0.62, 0.68, 0.8 } -- the other levels
local HERE = { 0.5, 1, 0.55 }    -- the room the player is in
-- the drawn look (canvas.style "drawn"): ink rim, parchment floor
local INK = { 0.24, 0.15, 0.07 }
local INK_WIDTH = 2.5            -- map pixels the silhouette is nudged by
local NUDGE = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local FLOOR = { 0.93, 0.83, 0.64 }
local LIFT = { 0.3, 0.26, 0.19 } -- added light: the floor's picture fades towards parchment
local FLOOR_HERE = { 0.8, 0.95, 0.62 }
local CORNERS = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }

local function Has(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

-- texture coordinates of a tile turned by quarter turns (the map data's q)
local function TurnedCoords(q)
    local function Corner(i)
        local c = CORNERS[(i - q) % 4 + 1]
        return c[1], c[2]
    end
    local ulx, uly = Corner(0)
    local urx, ury = Corner(1)
    local lrx, lry = Corner(2)
    local llx, lly = Corner(3)
    return ulx, uly, llx, lly, urx, ury, lrx, lry
end

-- a rotated group: each tile's corners turn around the tile's centre
local function Rotate(texture, tile, angle)
    local cos, sin = math.cos(angle), math.sin(angle)
    local halfW, halfH = tile[4] / 2, tile[5] / 2
    local cx, cy = tile[2] + halfW, tile[3] + halfH
    for vertex = 1, 4 do
        local dx = vertex <= 2 and -halfW or halfW
        local dy = vertex % 2 == 1 and -halfH or halfH
        local x, y = cx + dx * cos - dy * sin, cy + dx * sin + dy * cos
        texture:SetVertexOffset(vertex, x - (cx + dx), (cy + dy) - y)
    end
end

-- a tile's texture: its file, turned coordinates, spot (nudged by dx, dy map pixels), the group's rotation
local function Place(canvas, tex, tile, coords, r, dx, dy)
    tex:SetTexture(tile[1])
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4], coords[5], coords[6], coords[7], coords[8])
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", canvas, "TOPLEFT", tile[2] + dx, -(tile[3] + dy))
    tex:SetSize(tile[4], tile[5])
    if r then
        Rotate(tex, tile, math.rad(r))
    else
        for v = 1, 4 do tex:SetVertexOffset(v, 0, 0) end
    end
    tex:Show()
end

local Methods = {}

function Methods:Build(map)
    self.map = map
    self:SetSize(map.w, map.h)
    local coords = { TurnedCoords(map.q or 0) }
    local building, order = nil, 0
    for i, group in ipairs(map.groups) do
        local holder = self.holders[i]
        if not holder then
            holder = CreateFrame("Frame", nil, self)
            holder:SetAllPoints(self)
            holder.tiles = {}
            self.holders[i] = holder
        end
        if group.b then
            if group.b ~= building then building, order = group.b, 0 end
            order = order % 200 + 1
            holder.order = order
        else
            holder.order = i
        end
        holder.inks, holder.lifts = holder.inks or {}, holder.lifts or {}
        for t, tile in ipairs(group.tiles) do
            local tex = holder.tiles[t] or holder:CreateTexture(nil, "ARTWORK")
            holder.tiles[t] = tex
            Place(self, tex, tile, coords, group.r, 0, 0)
            if self.style == "drawn" then
                -- the drawn look: the room's own picture as a dark silhouette, four times nudged, under it
                local inks = holder.inks[t] or {}
                holder.inks[t] = inks
                for k, d in ipairs(NUDGE) do
                    local ink = inks[k] or holder:CreateTexture(nil, "BORDER")
                    inks[k] = ink
                    Place(self, ink, tile, coords, group.r, d[1] * INK_WIDTH, d[2] * INK_WIDTH)
                    ink:SetVertexColor(INK[1], INK[2], INK[3], 1)
                end
                local lift = holder.lifts[t] or holder:CreateTexture(nil, "ARTWORK", nil, 1)
                holder.lifts[t] = lift
                Place(self, lift, tile, coords, group.r, 0, 0)
                lift:SetBlendMode("ADD")
                lift:SetDesaturated(true)
                lift:SetVertexColor(LIFT[1], LIFT[2], LIFT[3], 1)
            end
        end
        for t = #group.tiles + 1, #holder.tiles do holder.tiles[t]:Hide() end
        local drawn = self.style == "drawn"
        for t, inks in pairs(holder.inks) do
            for _, ink in ipairs(inks) do ink:SetShown(drawn and t <= #group.tiles) end
        end
        for t, lift in pairs(holder.lifts) do lift:SetShown(drawn and t <= #group.tiles) end
    end
    for i = #map.groups + 1, #self.holders do self.holders[i]:Hide() end

    local ground = map.terrain or {}
    for i, tile in ipairs(ground) do
        local tex = self.ground.tiles[i] or self.ground:CreateTexture(nil, "BACKGROUND")
        self.ground.tiles[i] = tex
        tex:SetTexture(tile[1])
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", self, "TOPLEFT", tile[2], -tile[3])
        tex:SetSize(tile[4] + GROUND_OVERLAP, tile[4] + GROUND_OVERLAP)
        tex:Show()
    end
    for i = #ground + 1, #self.ground.tiles do self.ground.tiles[i]:Hide() end
    self.ground:SetShown(#ground > 0)
end

function Methods:Paint(level, others, room)
    local map = self.map
    if not map then return end
    local base = self:GetFrameLevel()
    for i, group in ipairs(map.groups) do
        local holder = self.holders[i]
        local on = level == 0 or Has(group.levels, level)
        -- a group reaching into this level from the one below or above
        local here = i == room
        local continuing = on and level > 0 and group.levels[1] ~= level and not here
        if on or others or here then
            local full = here or (on and not continuing)
            holder:SetFrameLevel(base + 2 + holder.order + ((on or here) and 250 or 0))
            holder:SetAlpha(full and 1 or (on and CONTINUING_ALPHA or OTHER_ALPHA))
            local drawn = self.style == "drawn"
            for _, tex in ipairs(holder.tiles) do
                tex:SetDesaturated(drawn or (not here and (not on or continuing)))
                local c = drawn and (here and FLOOR_HERE or FLOOR) or (here and HERE or (full and WARM or COLD))
                tex:SetVertexColor(c[1], c[2], c[3], 1)
            end
            holder:Show()
        else
            holder:Hide()
        end
    end
    self:Outline(level)
end

function Methods:Outline(level)
    local used = 0
    local loops = self.style ~= "drawn" and level > 0 and self.map.outlines and self.map.outlines[level] or {}  -- drawn: the ink rim is the edge
    local r, g, b = Sendit.Theme.Color("accent")
    local a, width = OUTLINE_ALPHA, OUTLINE_WIDTH
    for _, loop in ipairs(loops) do
        local points = #loop / 2
        for i = 1, points do
            local j = i % points + 1
            used = used + 1
            local line = self.lines[used]
            if not line then
                line = self.edge:CreateLine(nil, "OVERLAY")
                line:SetTexture(Sendit.Theme.WHITE)
                self.lines[used] = line
            end
            line:SetVertexColor(r, g, b, a)
            line:SetStartPoint("TOPLEFT", self, loop[i * 2 - 1], -loop[i * 2])
            line:SetEndPoint("TOPLEFT", self, loop[j * 2 - 1], -loop[j * 2])
            line:SetThickness(width / (self.zoom or 1))
            line:Show()
        end
    end
    for i = used + 1, #self.lines do self.lines[i]:Hide() end
    self.edge:SetFrameLevel(self:GetFrameLevel() + 510)
end

function Methods:SetZoom(zoom)
    if zoom == self.zoom then return end
    self.zoom = zoom
    for _, line in ipairs(self.lines) do line:SetThickness(OUTLINE_WIDTH / zoom) end
end

function Canvas.Create(parent)
    local canvas = CreateFrame("Frame", nil, parent)
    canvas.holders, canvas.lines = {}, {}
    canvas.ground = CreateFrame("Frame", nil, canvas)
    canvas.ground:SetAllPoints(canvas)
    canvas.ground.tiles = {}
    canvas.edge = CreateFrame("Frame", nil, canvas)
    canvas.edge:SetAllPoints(canvas)
    for name, fn in pairs(Methods) do canvas[name] = fn end
    return canvas
end
