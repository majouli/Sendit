--[[
  Burst: the effect of one gain - bubbles tumble down around the character, get drawn into it, then
  "+N XP" rises above its head. Burst.Play(amount, max) runs on every gain; Burst.Count(amount, max) = bubbles.
  The character point is the screen centre moved by profile.height (the camera keeps the character
  there). Pooled frames; the OnUpdate runs only while something moves. Motion = position + alpha.
]]
local _, ns = ...
local T = Sendit.Theme
local Burst = {}
ns.Burst = Burst

local FALL, PULL, STAGGER, RISE = 0.55, 0.32, 0.05, 1.4
local HEAD, LIFT = 55, 70
local MIN, MAX, PER_LEVEL = 3, 12, 40  -- PER_LEVEL: bubbles one whole level would add

local root = CreateFrame("Frame", nil, UIParent)
root:SetAllPoints()
root:SetFrameStrata("FULLSCREEN_DIALOG")  -- above the Sendit window, so the preview shows
Sendit.ownFrames[root] = true

local free, freeText, moving, rising = {}, {}, {}, {}

local function Profile() return ns.module.profile end

local function NewBubble()
    local f = CreateFrame("Frame", nil, root)
    f.glow = T.Circle(f, "accent", 1, "ARTWORK")
    T.Alpha(f.glow, 0.3)
    f.core = T.Circle(f, "accent", 1, "OVERLAY")
    f.shine = T.Circle(f, "star", 1, "OVERLAY", 1)
    T.Alpha(f.shine, 0.85)
    f.glow:SetPoint("CENTER")
    f.core:SetPoint("CENTER")
    return f
end

local function Size(f, s)
    f:SetSize(s, s)
    f.glow:SetSize(s * 2.2, s * 2.2)
    f.core:SetSize(s, s)
    f.shine:SetSize(s * 0.35, s * 0.35)
    f.shine:ClearAllPoints()
    f.shine:SetPoint("CENTER", -s * 0.18, s * 0.18)
end

local function NewText()
    local f = CreateFrame("Frame", nil, root)
    f:SetSize(1, 1)
    f.text = T.Text(f, "title", "accent")
    f.text:SetPoint("CENTER")
    return f
end

local function Place(f, x, y)
    f:ClearAllPoints()
    f:SetPoint("CENTER", root, "CENTER", x, y + Profile().height)
end

function Burst.Count(amount, max)
    local n = MIN + math.floor(PER_LEVEL * amount / math.max(1, max or amount))
    return math.min(MAX, n)
end

local function Label(amount)
    local n = BreakUpLargeNumbers and BreakUpLargeNumbers(amount) or tostring(amount)
    return ("+%s %s"):format(n, _G["XP"] or "XP")
end

local function Rise(burst)
    local f = table.remove(freeText) or NewText()
    T.SetFont(f.text, math.floor(20 * Profile().size + 0.5))
    f.text:SetText(Label(burst.amount))
    f.t0 = GetTime()
    f:SetAlpha(0)
    Place(f, 0, HEAD)
    f:Show()
    rising[#rising + 1] = f
end

local function StepBubble(b, now)
    local t = now - b.t0
    if t < 0 then return true end
    b:Show()
    local s = b.size
    if t < FALL then
        local u = t / FALL
        Place(b, b.sx + (b.lx - b.sx) * u, b.sy + (b.ly - b.sy) * u * u)
        b:SetAlpha(math.min(1, u * 4))
        return true
    end
    local v = math.min(1, (t - FALL) / PULL)
    local e = v * v * v
    Size(b, s * (1 - 0.6 * e))
    Place(b, b.lx * (1 - e), b.ly * (1 - e))
    b:SetAlpha(1 - 0.7 * e)
    return v < 1
end

local function StepText(f, now)
    local u = (now - f.t0) / RISE
    if u >= 1 then return false end
    Place(f, 0, HEAD + LIFT * (1 - (1 - u) * (1 - u)))
    f:SetAlpha(u < 0.12 and u / 0.12 or math.min(1, (1 - u) / 0.45))
    return true
end

local function Step()
    local now = GetTime()
    for i = #moving, 1, -1 do
        local b = moving[i]
        if not StepBubble(b, now) then
            b:Hide()
            table.remove(moving, i)
            free[#free + 1] = b
            local burst = b.burst
            burst.left = burst.left - 1
            if burst.left == 0 then Rise(burst) end
        end
    end
    for i = #rising, 1, -1 do
        local f = rising[i]
        if not StepText(f, now) then
            f:Hide()
            table.remove(rising, i)
            freeText[#freeText + 1] = f
        end
    end
    if #moving == 0 and #rising == 0 then root:SetScript("OnUpdate", nil) end
end

function Burst.Play(amount, max)
    local n = Burst.Count(amount, max)
    local burst = { amount = amount, left = n }
    local now, size = GetTime(), 10 * Profile().size
    for i = 1, n do
        local b = table.remove(free) or NewBubble()
        b.burst, b.size, b.t0 = burst, size * (0.8 + math.random() * 0.4), now + (i - 1) * STAGGER
        b.sx, b.sy = math.random(-140, 140), math.random(90, 190)
        b.lx, b.ly = b.sx * 0.55 + math.random(-15, 15), math.random(-55, -20)
        Size(b, b.size)
        b:Hide()
        moving[#moving + 1] = b
    end
    root:SetScript("OnUpdate", Step)
end

ns.Gain.On(Burst.Play)
