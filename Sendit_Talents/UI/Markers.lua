--[[
  Markers: what the route draws over Blizzard's talent buttons.
    next point   Blizzard's own talent glow (atlas talents-node-square-greenglow,
                 61 px around the 40 px node, additive) in the Sendit accent;
                 it pulses when a point is free to spend
    picks        with several free points, a number on each node to buy now
                 in that order ("1", "2·3" for two ranks)
    route node   a small badge with the rank the route ends at (accent while
                 open, success colour once reached)
                 and, below it, the levels its points come at ("10-14")
    other nodes  a light veil, only on nodes without points
    highlight    the same glow, steady, on the node a timeline row points at
  Every marker is our own frame on our overlay, anchored to Blizzard's
  button (anchoring writes nothing on it), a few frame levels above it: the
  buttons sit far above the talent window's own level. Markers never
  take the mouse, so clicks and tooltips stay Blizzard's.
  Contract: Markers.Draw(overlay, buttonOf, plan, nodes, rankOf, ready)
            Markers.Clear()
            Markers.Highlight(nodeID | nil)
    buttonOf(nodeID) -> Blizzard's button | nil; ready = the next point can
    be bought now.
]]
local _, ns = ...
local T = Sendit.Theme
local Call = ns.Call

local Markers = {}
ns.Markers = Markers

local pool, used = {}, {}
local BADGE, VEIL = 15, 0.45
local NODE, GLOW = 40, 61  -- Blizzard's square node and its glow atlas
local current = {}         -- overlay, buttonOf of the last Draw
local highlight

local function Glow(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("CENTER")
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetAtlas("talents-node-square-greenglow")
    f.tex:SetDesaturated(true)
    f.tex:SetBlendMode("ADD")
    T.Paint(f.tex, "accent")
    return f
end

-- Place `f` on Blizzard's button: same centre, a few levels above, glow sized
-- to the button (talent buttons may be scaled).
local function Place(f, button)
    f:ClearAllPoints()
    f:SetAllPoints(button)
    local level = Call(button.GetFrameLevel, button)
    f:SetFrameLevel((type(level) == "number" and level or 0) + 5)
    local w = Call(button.GetWidth, button)
    w = type(w) == "number" and w > 0 and w or NODE
    f.glow:SetSize(w * GLOW / NODE, w * GLOW / NODE)
end

local function New(overlay)
    local m = CreateFrame("Frame", nil, overlay)
    m.veil = T.Fill(m, "shadow", "ARTWORK", 0, VEIL)
    m.veil:SetPoint("TOPLEFT", 4, -4)
    m.veil:SetPoint("BOTTOMRIGHT", -4, 4)
    m.glow = Glow(m)
    m.pulse = m.glow:CreateAnimationGroup()
    m.pulse:SetLooping("BOUNCE")
    local fade = m.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.3)
    fade:SetDuration(0.8)
    m.badge = CreateFrame("Frame", nil, m)
    m.badge:SetSize(BADGE, BADGE)
    m.badge:SetPoint("TOPRIGHT", 4, 4)
    m.badge.ground = T.Circle(m.badge, "accent", BADGE, "OVERLAY")
    m.badge.ground:SetPoint("CENTER")
    m.badge.text = T.Text(m.badge, "caption", "onAccent")
    m.badge.text:SetPoint("CENTER", 0, 0)
    m.badge.text:SetJustifyH("CENTER")
    m.order = CreateFrame("Frame", nil, m)
    m.order:SetSize(BADGE, BADGE)
    m.order:SetPoint("TOPLEFT", -4, 4)
    m.order.ground = T.Circle(m.order, "success", BADGE, "OVERLAY")
    m.order.ground:SetPoint("CENTER")
    m.order.text = T.Text(m.order, "caption", "onAccent")
    m.order.text:SetPoint("CENTER", 0, 0)
    m.levels = CreateFrame("Frame", nil, m)
    m.levels:SetHeight(13)
    m.levels:SetPoint("TOP", m, "BOTTOM", 0, 1)
    m.levels.ground = T.Fill(m.levels, "bg", "ARTWORK", 0, 0.85)
    m.levels.ground:SetAllPoints()
    m.levels.text = T.Text(m.levels, "caption", "textDim", "OVERLAY")
    m.levels.text:SetPoint("CENTER", 0, 0)
    return m
end

function Markers.Clear()
    for i = #used, 1, -1 do
        local m = used[i]
        m.pulse:Stop()
        m:Hide()
        pool[#pool + 1] = m
        used[i] = nil
    end
    Markers.Highlight(nil)
end

function Markers.Draw(overlay, buttonOf, plan, nodes, rankOf, ready)
    Markers.Clear()
    current.overlay, current.buttonOf = overlay, buttonOf
    local nextNode = plan.next and plan.next.node
    local order = {}
    if ready and #plan.picks > 1 then
        for i, step in ipairs(plan.picks) do
            order[step.node] = order[step.node] and (order[step.node] .. "·" .. i) or tostring(i)
        end
    end
    for _, node in ipairs(nodes) do
        local target, rank = plan.target[node], rankOf(node)
        local button = (target or rank == 0) and buttonOf(node)
        if button then
            local m = table.remove(pool) or New(overlay)
            Place(m, button)
            m:Show()
            used[#used + 1] = m
            m.veil:SetShown(not target)
            m.badge:SetShown(target ~= nil)
            if target then
                m.badge.text:SetText(target)
                T.Paint(m.badge.ground, rank >= target and "success" or "accent")
                local span = plan.levels and plan.levels[node]
                if span then
                    m.levels.text:SetText(span[1] == span[2] and span[1] or (span[1] .. "-" .. span[2]))
                    m.levels:SetWidth(m.levels.text:GetStringWidth() + 8)
                end
            end
            m.levels:SetShown(target ~= nil and plan.levels ~= nil)
            m.order:SetShown(order[node] ~= nil)
            m.order.text:SetText(order[node] or "")
            m.order:SetWidth(math.max(BADGE, m.order.text:GetStringWidth() + 6))
            m.glow:SetShown(node == nextNode)
            m.glow:SetAlpha(1)
            if node == nextNode and ready then m.pulse:Play() end
        end
    end
end

function Markers.Highlight(node)
    local button = node and current.buttonOf and current.buttonOf(node)
    if not button then
        if highlight then highlight:Hide() end
        return
    end
    if not highlight then
        highlight = CreateFrame("Frame", nil, current.overlay)
        highlight.glow = Glow(highlight)
    end
    Place(highlight, button)
    highlight:SetFrameLevel(highlight:GetFrameLevel() + 2)
    highlight:Show()
end
