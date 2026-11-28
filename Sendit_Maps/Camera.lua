--[[
  Camera: where the camera looks inside an instance, where the client gives no facing. The locator tracks
  flight masters with known world spots; on each checked reading the client's navigation target is that
  flight master. Only a target in view counts (a target held at the screen's edge does not say where it
  lies precisely enough). Its spot (x, y in half screen widths from the middle) is a ray in the camera:
    (right, up, ahead) = (x * SPREAD, y * SPREAD, 1), normalised
  and the ray must point at the flight master, bearing b and elevation e (its height against the player's):
    pitch phi:  up * cos(phi) - ahead * sin(phi) = sin(e)          (down positive; the solution nearest the last)
    yaw psi:    psi = b + atan2(right, ahead * cos(phi) + up * sin(phi))
  The yaw given out is the median of the last three (a stray reading does not jump). While the mouse steers
  (mouselook) the player faces where the camera looks; with no target in view the last yaw stays.
  SPREAD = tan(half the horizontal field of view), measured by itself: standing still with the camera at
  rest, the targets seen must agree on one yaw - the SPREAD where they agree best (account cameraView).
  Camera.Yaw() -> facing (radians), time | nil (mouselook only);  Camera.Sample(anchor) on a reading
  Camera.Solve(b, e, x, y, spread, lastPitch?) -> yaw, pitch | nil;  Camera.Calibrate(samples) -> spread | nil
]]
local _, ns = ...
local Camera = {}
ns.Camera = Camera

local REST_SPAN = 3      -- seconds of readings the field of view is measured from
local LEARN = 0.5        -- share of a new field of view measurement
local atan2 = math.atan2 or math.atan
local PI2 = math.pi * 2

local yaws, pitch, at = {}, nil, nil
local rest = {}

local function Plain(v) return type(v) == "number" and not (issecretvalue and issecretvalue(v)) end
local function Wrap(a) return (a + math.pi) % PI2 - math.pi end

local function Call(name, ...)
    local fn = _G[name]
    if not fn then return nil end
    local ok, r = pcall(fn, ...)
    return ok and r or nil
end

local function Looking() return Call("IsMouselooking") == true end

local function Spread(aspect)
    local db = ns.module.db
    return db and db.cameraView or 0.75 * aspect  -- the default: 90 degrees across a 4:3 screen
end

function Camera.Solve(b, e, x, y, spread, lastPitch)
    local r, u, a = x * spread, y * spread, 1
    local n = math.sqrt(r * r + u * u + a * a)
    r, u, a = r / n, u / n, a / n
    local amp = math.sqrt(u * u + a * a)
    local s = math.sin(e) / amp
    if s > 1 or s < -1 then return nil end
    local delta = atan2(a, u)
    local best
    for _, phi in ipairs({ math.acos(s) - delta, -math.acos(s) - delta }) do
        phi = Wrap(phi)
        if phi > -1.5 and phi < 1.55 and (not best or math.abs(phi - (lastPitch or 0.3)) < math.abs(best - (lastPitch or 0.3))) then
            best = phi
        end
    end
    if not best then return nil end
    local ahead = a * math.cos(best) + u * math.sin(best)
    return Wrap(b + atan2(r, ahead)), best
end

-- the spread where the readings of a camera at rest agree best on one yaw (golden section search)
function Camera.Calibrate(samples)
    if #samples < 4 then return nil end
    local distinct, lo, hi = {}, math.huge, -math.huge
    for _, s in ipairs(samples) do
        distinct[s[1]] = true
        lo, hi = math.min(lo, s[3]), math.max(hi, s[3])
    end
    local count = 0
    for _ in pairs(distinct) do count = count + 1 end
    if count < 2 or hi - lo < 0.3 then return nil end
    local function Disagreement(spread)
        local sx, sy, list = 0, 0, {}
        for _, s in ipairs(samples) do
            local psi = Camera.Solve(s[1], s[2], s[3], s[4], spread)
            if not psi then return math.huge end
            list[#list + 1] = psi
            sx, sy = sx + math.cos(psi), sy + math.sin(psi)
        end
        local mean, sum = atan2(sy, sx), 0
        for _, psi in ipairs(list) do sum = sum + Wrap(psi - mean) ^ 2 end
        return sum
    end
    local a, b, g = 0.27, 3.7, (math.sqrt(5) - 1) / 2
    local c, d = b - g * (b - a), a + g * (b - a)
    for _ = 1, 40 do
        if Disagreement(c) < Disagreement(d) then b, d = d, c; c = b - g * (b - a)
        else a, c = c, d; d = a + g * (b - a) end
    end
    local best = (a + b) / 2
    if best <= 0.28 or best >= 3.69 then return nil end
    return best
end

local function AtRest()
    if Call("IsMouseButtonDown", "LeftButton") or Call("IsMouseButtonDown", "RightButton") then return false end
    if ns.Motion.Offset() or ns.Motion.Turning() ~= 0 then return false end
    local _, _, _, _, _, speed = ns.Locator.Get()
    return not speed or speed < 0.3
end

local function Median3(list)
    local n = #list
    if n < 3 then return list[n] end
    local a, b, c = list[n - 2], list[n - 1], list[n]
    -- the median on the circle: the one whose distances to the others sum least
    local function Cost(v, p, q) return math.abs(Wrap(v - p)) + math.abs(Wrap(v - q)) end
    local best, cost = a, Cost(a, b, c)
    if Cost(b, a, c) < cost then best, cost = b, Cost(b, a, c) end
    if Cost(c, a, b) < cost then best = c end
    return best
end

function Camera.Sample(anchor)
    local nav = C_Navigation
    if not (nav and nav.GetFrame and nav.WasClampedToScreen) then return end
    local okC, clamped = pcall(nav.WasClampedToScreen)
    if not okC or clamped ~= false then return end  -- only a target in view
    local okF, frame = pcall(nav.GetFrame)
    if not (okF and frame and frame.GetCenter) then return end
    local okX, x, y = pcall(frame.GetCenter, frame)
    if not (okX and Plain(x) and Plain(y)) then return end
    -- in screen pixels: the target's spot and the screen (frames may sit at different scales)
    local okS, scale = pcall(frame["GetEffectiveScale"], frame)
    scale = (okS and Plain(scale)) and scale or 1
    x, y = x * scale, y * scale
    local ui = UIParent:GetEffectiveScale()
    local w, h = GetScreenWidth() * ui, GetScreenHeight() * ui
    if not (Plain(w) and Plain(h) and w > 0 and h > 0) then return end
    local px, py, pz = ns.Locator.Get()
    if not px then return end
    local dx, dy = anchor.x - px, anchor.y - py
    local now = GetTime()
    local sample = { atan2(dy, dx), atan2((anchor.z or 0) - (pz or anchor.z or 0), math.sqrt(dx * dx + dy * dy)),
        (x - w / 2) / (w / 2), (y - h / 2) / (w / 2), now }

    local psi, phi = Camera.Solve(sample[1], sample[2], sample[3], sample[4], Spread(w / h), pitch)
    if psi then
        pitch, at = phi, now
        yaws[#yaws + 1] = psi
        if #yaws > 3 then table.remove(yaws, 1) end
    end

    if AtRest() then
        while rest[1] and now - rest[1][5] > REST_SPAN do table.remove(rest, 1) end
        rest[#rest + 1] = sample
        local spread = Camera.Calibrate(rest)
        if spread and ns.module.db then
            local old = ns.module.db.cameraView
            ns.module.db.cameraView = old and (old + (spread - old) * LEARN) or spread
            wipe(rest)
        end
    else
        wipe(rest)
    end
end
ns.Locator.OnReading(Camera.Sample)

function Camera.Yaw()
    if #yaws == 0 or not Looking() then return nil end
    return Median3(yaws), at
end
