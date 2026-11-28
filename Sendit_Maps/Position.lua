--[[
  Position: where the player is on an instance map - map pixels, facing, the room (WMO group) and level.
  The client's own position when it gives one, else the Locator's fix.
  Position.New(id, map) -> pos;  pos:Read() -> state | nil (nothing known yet)
    state = { x, y (map pixels), wx, wy, wz (world), facing, outside (beyond the plan), room (group index),
    level }; without a room map (a raid with drawn art only) just the world position and facing
  Facing: the client's; else the located heading turned back by the movement keys (Motion); nil while no
  movement key is held (the arrow keeps its own and turns with the turn keys).
  A room or level only counts once it held ROOM_HOLD seconds; the room already held is kept while a
  candidate is not clearly smaller (a doorway between two rooms must not flicker).
]]
local _, ns = ...
local Position = {}
ns.Position = Position

local FIX_MAX_AGE = 2      -- seconds: an older fix is no position
local OUTSIDE = 60         -- map pixels beyond the plan's edge: outside it
local ROOM_SLACK = 3       -- world yards a room's box and height range are widened by
local ROOM_HOLD = 0.4      -- seconds a new room must hold before it counts
local ROOM_KEEP = 1.5      -- the held room stays unless a candidate is this much smaller
local ROOM_TRUST = 2       -- a fix whose residual is above this does not change the room

local function Plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function HeightLevel(cuts, z)
    local found = 1
    for _, cut in ipairs(cuts) do if z >= cut then found = found + 1 end end
    return found
end

local Methods = {}

function Methods:RoomAt(x, y, z)
    local map = self.map
    local best, bestRank, bestSize, kept, keptRank, keptSize
    local slack = ROOM_SLACK * 2
    for i, group in ipairs(map.groups) do
        local range, box = group.z, group.box
        if range and box and z >= range[1] - ROOM_SLACK and z <= range[2] + ROOM_SLACK then
            local halfW, halfH = box[3] / 2, box[4] / 2
            local dx, dy = x - (box[1] + halfW), y - (box[2] + halfH)
            if group.r then
                local a = math.rad(group.r)
                local cos, sin = math.cos(a), math.sin(a)
                dx, dy = dx * cos + dy * sin, dy * cos - dx * sin
            end
            dx, dy = math.abs(dx), math.abs(dy)
            if dx <= halfW + slack and dy <= halfH + slack then
                local inside = dx <= halfW and dy <= halfH and z >= range[1] and z <= range[2]
                local rank = inside and 0 or 2
                local size = (box[3] + 1) * (box[4] + 1) * (range[2] - range[1] + 1)
                if not best or rank < bestRank or (rank == bestRank and size < bestSize) then
                    best, bestRank, bestSize = i, rank, size
                end
                if i == self.room then kept, keptRank, keptSize = i, rank, size end
            end
        end
    end
    if not best then return nil end
    if kept and keptRank == bestRank and keptSize <= bestSize * ROOM_KEEP then best = kept end
    local group = map.groups[best]
    local found = group.levels[1]
    if #group.levels > 1 then
        local building = group.b and map.buildings and map.buildings[group.b]
        local cuts = building and building.cuts or map.cuts
        if cuts and #cuts > 0 then
            local want, gap = HeightLevel(cuts, z), nil
            for _, candidate in ipairs(group.levels) do
                local d = math.abs(candidate - want)
                if not gap or d < gap then found, gap = candidate, d end
            end
        end
    end
    return best, found
end

function Methods:Settle(px, py, z, residual)
    if residual > ROOM_TRUST then return end
    local room, level = self:RoomAt(px, py, z)
    local now = GetTime()
    if room ~= self.candidate or level ~= self.candidateLevel then
        self.candidate, self.candidateLevel, self.since = room, level, now
    end
    if now - self.since < ROOM_HOLD then return end
    self.room = self.candidate
    if self.candidateLevel then self.level = self.candidateLevel end
end

function Methods:ToMap(wx, wy)
    local t = self.map.w2p
    return t[1] * wx + t[2] * wy + t[3], t[4] * wx + t[5] * wy + t[6]
end

function Methods:Read()
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not Plain(facing) then facing = nil end
    local wx, wy, z = UnitPosition("player")
    if Plain(wx) and Plain(wy) then
        local wz = Plain(z) and z or nil
        local x, y
        if self.map then x, y = self:ToMap(wx, wy) end
        return { x = x, y = y, wx = wx, wy = wy, wz = wz, facing = facing, level = self.level }
    end
    local L = ns.Locator
    if not (L and L.IsRunning()) then return nil end
    local fx, fy, fz, heading, age, _, residual = L.Get()
    if not fx or age > FIX_MAX_AGE then return nil end
    local map, x, y, outside = self.map, nil, nil, false
    if map then
        x, y = self:ToMap(fx, fy)
        outside = x < -OUTSIDE or y < -OUTSIDE or x > map.w + OUTSIDE or y > map.h + OUTSIDE
        if outside then
            self.room, self.candidate = nil, nil
        else
            self:Settle(x, y, fz, residual or 0)
        end
    end
    if not facing and heading then
        -- the heading is the walk's direction: take out how the keys turn the walk against the facing
        local offset = ns.Motion.Offset()
        facing = offset and heading - offset or nil  -- standing: the arrow keeps (and key-turns) its own
    end
    return { x = x, y = y, wx = fx, wy = fy, wz = fz, facing = facing, outside = outside, room = self.room,
        level = self.level }
end

function Position.New(id, map)
    local pos = { id = id, map = map, since = 0 }
    for name, fn in pairs(Methods) do pos[name] = fn end
    return pos
end
