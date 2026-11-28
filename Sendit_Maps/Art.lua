--[[
  Art: the drawn dungeon and raid maps the client ships (Data/Art.lua), and where a world position lies on
  them. A floor's regions map a world box onto a part of its art (several boxes per floor, by height).
  Art.Has(id) / Art.Floors(id) -> floors | nil
  Art.Locate(id, wx, wy[, wz]) -> floor index, x, y (art pixels) | nil  (the floor whose box holds the
    point; with a height the box must hold that too, the smallest box wins)
  Art.Pins(id, floor) -> { { npc, x, y (art pixels) }, ... }  Blizzard's hand-set boss spots
  A world point goes through the box's mapping, the one the client itself uses for the player on these maps.
  The bosses sit at Blizzard's hand-set spots where there is one: the art is not everywhere to scale, and a
  boss's real spot can lie beside its drawn place.
  Art.FromTiles(map, mx, my) -> wx, wy  (a room-tile map pixel back to world, for the boss pins)
  Art.Player(id) -> floor index, x, y | nil  the player through the client's own map API: its floor
    (C_Map.GetBestMapForUnit) and its world -> map transform for Forever (C_Map.GetMapPosFromWorldPos)
  The client's map API comes first everywhere (its art layers, its transform); Data/Art.lua (the retail
  tables) only where the API gives nothing.
]]
local _, ns = ...
local Art = {}
ns.Art = Art

function Art.Has(id) return ns.art ~= nil and ns.art[id] ~= nil end
function Art.Floors(id) return ns.art and ns.art[id] and ns.art[id].floors end

local function Inside(r, wx, wy, wz)
    if wx < r[5] or wx > r[8] or wy < r[6] or wy > r[9] then return false end
    return wz == nil or (wz >= r[7] and wz <= r[10])
end

local MapPos  -- below: the client's world -> map transform

-- the floor and box that hold a world point (with a height: in its height range too; the smallest box)
local function Find(floors, wx, wy, wz)
    local best, bestArea, bestFloor
    for f, floor in ipairs(floors) do
        for _, r in ipairs(floor.regions) do
            if Inside(r, wx, wy, wz) then
                local area = (r[8] - r[5]) * (r[9] - r[6])
                if not bestArea or area < bestArea then best, bestArea, bestFloor = r, area, f end
            end
        end
    end
    return bestFloor, best
end

-- the plain mapping of a box: the art's x runs against world Y, its y against world X (north is up)
local function Plain(floor, r, wx, wy)
    local u = (r[9] - wy) / (r[9] - r[6])
    local v = (r[8] - wx) / (r[8] - r[5])
    return (r[1] + u * (r[3] - r[1])) * floor.w, (r[2] + v * (r[4] - r[2])) * floor.h
end

function Art.Locate(id, wx, wy, wz)
    local floors = Art.Floors(id)
    if not floors then return nil end
    local f, r = Find(floors, wx, wy, wz)
    if not f then return nil end
    local drawn = Art.Floor(id, f) or floors[f]
    local mx, my = MapPos(id, floors[f].ui, wx, wy)
    if mx and my then return f, mx * drawn.w, my * drawn.h end
    local x, y = Plain(floors[f], r, wx, wy)
    return f, x * drawn.w / floors[f].w, y * drawn.h / floors[f].h
end

local function Number(v)
    if type(v) ~= "number" or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

-- the client's art for a floor: { w, h, tw, th, cols, tiles } | nil
local function ClientArt(ui)
    local api = C_Map
    if not (api and api.GetMapArtLayers and api.GetMapArtLayerTextures) then return nil end
    local ok, layers = pcall(api.GetMapArtLayers, ui)
    local layer = ok and type(layers) == "table" and layers[1]
    if not layer then return nil end
    local ok2, textures = pcall(api.GetMapArtLayerTextures, ui, 1)
    if not (ok2 and type(textures) == "table" and #textures > 0) then return nil end
    local w, h = Number(layer.layerWidth), Number(layer.layerHeight)
    local tw, th = Number(layer.tileWidth), Number(layer.tileHeight)
    if not (w and h and tw and th) then return nil end
    return { w = w, h = h, tw = tw, th = th, cols = math.ceil(w / tw), tiles = textures }
end

-- a floor as drawn: the client's art when it has it, else the bundled one
function Art.Floor(id, f)
    local floor = Art.Floors(id) and Art.Floors(id)[f]
    if not floor then return nil end
    if floor.client == nil then floor.client = ClientArt(floor.ui) or false end
    local c = floor.client
    if c then return { ui = floor.ui, w = c.w, h = c.h, tw = c.tw, th = c.th, cols = c.cols, tiles = c.tiles } end
    return floor
end

function MapPos(id, ui, wx, wy)
    local api = C_Map
    if not (api and api.GetMapPosFromWorldPos) then return nil end
    local vec = CreateVector2D and CreateVector2D(wx, wy) or { x = wx, y = wy }
    local ok, _, pos = pcall(api.GetMapPosFromWorldPos, id, vec, ui)
    if not ok or type(pos) ~= "table" then return nil end
    local x, y = pos.x, pos.y
    if (x == nil or y == nil) and pos.GetXY then x, y = pos:GetXY() end
    return Number(x), Number(y)
end

function Art.Player(id, wx, wy)
    local floors, api = Art.Floors(id), C_Map
    if not (floors and api and api.GetBestMapForUnit) then return nil end
    local ok, ui = pcall(api.GetBestMapForUnit, "player")
    ui = ok and Number(ui) or nil
    if not ui then return nil end
    for f, floor in ipairs(floors) do
        if floor.ui == ui then
            local x, y
            if api.GetPlayerMapPosition then
                local ok2, pos = pcall(api.GetPlayerMapPosition, ui, "player")
                if ok2 and type(pos) == "table" then
                    x, y = pos.x, pos.y
                    if (x == nil or y == nil) and pos.GetXY then x, y = pos:GetXY() end
                    x, y = Number(x), Number(y)
                end
            end
            if not x and wx then x, y = MapPos(id, ui, wx, wy) end
            if not x then return nil end
            local drawn = Art.Floor(id, f) or floor
            return f, x * drawn.w, y * drawn.h
        end
    end
    return nil
end

function Art.Pins(id, f)
    local floor, drawn = Art.Floors(id) and Art.Floors(id)[f], Art.Floor(id, f)
    local out = {}
    if not (floor and drawn) then return out end
    for _, pin in ipairs(floor.pins or {}) do
        out[#out + 1] = { pin[1], pin[2] * drawn.w, pin[3] * drawn.h }
    end
    return out
end

function Art.FromTiles(map, mx, my)
    local t = map.w2p
    local det = t[1] * t[5] - t[2] * t[4]
    if det == 0 then return nil end
    return ((mx - t[3]) * t[5] - t[2] * (my - t[6])) / det, (t[1] * (my - t[6]) - (mx - t[3]) * t[4]) / det
end

-- ArtCanvas: one floor's art as a canvas the View can zoom and move (same calls as Canvas)
local Methods = {}

function Methods:Build(floor)
    self.map = { w = floor.w, h = floor.h }
    self:SetSize(floor.w, floor.h)
    for i, file in ipairs(floor.tiles) do
        local tex = self.tiles[i] or self:CreateTexture(nil, "ARTWORK")
        self.tiles[i] = tex
        local col, row = (i - 1) % floor.cols, math.floor((i - 1) / floor.cols)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", self, "TOPLEFT", col * floor.tw, -row * floor.th)
        tex:SetSize(floor.tw, floor.th)
        tex:SetTexture(tonumber(file))
        tex:SetShown(file ~= "0" and file ~= 0)
    end
    for i = #floor.tiles + 1, #self.tiles do self.tiles[i]:Hide() end
end

function Methods:SetZoom() end

function Art.CreateCanvas(parent)
    local canvas = CreateFrame("Frame", nil, parent)
    canvas.tiles = {}
    for name, fn in pairs(Methods) do canvas[name] = fn end
    return canvas
end
