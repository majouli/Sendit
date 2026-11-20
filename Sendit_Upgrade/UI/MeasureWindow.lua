--[[
  MeasureWindow: /gc measure's live counts - one row per outcome with the measured share and a marker
  at the model's value (green when they agree, amber when not, muted below MIN_N attacks), for the
  target's level difference. Movable, resizable, saved in Sendit_UpgradeDB.measureWindow.
]]
local _, ns = ...
local L = ns.L
local T = Sendit.Theme

local MeasureWindow = {}
ns.MeasureWindow = MeasureWindow

local MIN_W, MIN_H, DEF_W, DEF_H = 240, 170, 300, 196
local PAD, HEAD, ROW, LABEL_W, VALUE_W = 10, 44, 22, 78, 92
local MIN_N = 100
local ROWS = { { key = "miss", label = "mMiss" }, { key = "dodge", label = "mDodge" }, { key = "parry", label = "mParry" },
               { key = "glance", label = "mGlance" }, { key = "crit", label = "mCrit" } }

local frame, dirty

local function Saved()
    ns.db.measureWindow = ns.db.measureWindow or {}
    return ns.db.measureWindow
end

local function Num(v) return (("%.1f"):format(v):gsub("%.", L.decimal or ".")) end

-- this character's bucket for the target's level difference, else its fullest
local function PickBucket()
    local m = ns.Measure.Char()
    if not m then return nil end
    local level, mine = UnitLevel("target"), UnitLevel("player")
    if type(level) == "number" and level > 0 and not (issecretvalue and (issecretvalue(level) or issecretvalue(mine))) then
        local d = level - mine
        local key = (d >= 0 and "+" or "") .. d
        if m.buckets[key] then return key, m.buckets[key] end
    end
    local bestKey, best
    for k, b in pairs(m.buckets) do
        if (b.physical.n or 0) > ((best and best.physical.n) or 0) then bestKey, best = k, b end
    end
    return bestKey, best
end

local function ModelValues(key, t)
    local level = UnitLevel("player")
    local target = ns.Model.Target({ level = level, targetLevel = level + math.max(0, tonumber(key) or 0) })
    return { miss = target.miss, dodge = target.dodge, parry = target.parry, glance = target.glance,
             crit = (t.sheetN or 0) > 0 and t.sheetCrit / t.sheetN or 0 }
end

local function Draw()
    if not frame or not frame:IsShown() then return end
    local key, b = PickBucket()
    local t = b and b.physical
    if not t or (t.n or 0) == 0 then
        frame.sub:SetText(L.mNone)
        for _, r in ipairs(frame.rows) do r:Hide() end
        frame.foot:SetText("")
        return
    end
    frame.sub:SetText(L.mTarget:format(key, t.n))
    local model = ModelValues(key, t)
    local track = frame:GetWidth() - 2 * PAD - LABEL_W - VALUE_W - 8
    local top = 0
    for _, row in ipairs(ROWS) do
        local measured = (t[row.key] or 0) / t.n * 100
        top = math.max(top, measured, model[row.key] or 0)
    end
    local scale = math.max(10, top * 1.15)
    for i, row in ipairs(ROWS) do
        local r = frame.rows[i]
        local measured, expect = (t[row.key] or 0) / t.n * 100, model[row.key] or 0
        r.bar:SetWidth(math.max(1, track * measured / scale))
        r.marker:ClearAllPoints()
        r.marker:SetPoint("LEFT", r.track, "LEFT", math.min(track - 2, track * expect / scale), 0)
        local agree = math.abs(measured - expect) <= math.max(1, expect * 0.15)
        T.Paint(r.bar, t.n < MIN_N and "textMuted" or agree and "success" or "warning")
        r.value:SetText(("%s%% / %s%%"):format(Num(measured), Num(expect)))
        r:Show()
    end
    local hit, glance = t.hitDmgN and t.hitDmg / t.hitDmgN, t.glanceDmgN and t.glanceDmg / t.glanceDmgN
    if hit and glance and hit > 0 then
        frame.foot:SetText(L.mGlanceDmg:format(Num(glance / hit * 100)))
    elseif (t.secretAmounts or 0) > 0 then
        frame.foot:SetText(L.mSecret)
    else
        frame.foot:SetText("")
    end
end

local function Layout()
    if not frame or not frame.rows then return end  -- size events fire while it is built
    local track = frame:GetWidth() - 2 * PAD - LABEL_W - VALUE_W - 8
    for i, r in ipairs(frame.rows) do
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", PAD, -HEAD - (i - 1) * ROW)
        r:SetPoint("TOPRIGHT", -PAD, -HEAD - (i - 1) * ROW)
        r.track:SetWidth(math.max(10, track))
    end
    Draw()
end

local function Row(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW)
    r.label = T.Text(r, "small", "textDim")
    r.label:SetPoint("LEFT")
    r.label:SetWidth(LABEL_W)
    r.track = CreateFrame("Frame", nil, r)
    r.track:SetPoint("LEFT", LABEL_W, 0)
    r.track:SetHeight(8)
    T.Fill(r.track, "panelAlt", "BACKGROUND"):SetAllPoints()
    r.bar = T.Fill(r.track, "success", "ARTWORK")
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMLEFT")
    r.marker = T.Fill(r.track, "text", "OVERLAY")
    r.marker:SetSize(2, 12)
    r.value = T.Text(r, "small", "text")
    r.value:SetPoint("RIGHT")
    r.value:SetWidth(VALUE_W)
    r.value:SetJustifyH("RIGHT")
    return r
end

local function Grip(f)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(f:GetFrameLevel() + 20)
    local lines = {}
    for i = 1, 3 do
        local line = grip:CreateLine(nil, "ARTWORK")
        line:SetTexture(T.WHITE)
        line:SetThickness(1)
        line:SetStartPoint("BOTTOMRIGHT", grip, -2, 2 + i * 4)
        line:SetEndPoint("BOTTOMRIGHT", grip, -2 - i * 4, 2)
        T.Paint(line, "textMuted")
        lines[i] = line
    end
    grip:SetScript("OnEnter", function() for _, l in ipairs(lines) do T.Paint(l, "accent") end end)
    grip:SetScript("OnLeave", function() for _, l in ipairs(lines) do T.Paint(l, "textMuted") end end)
    grip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        local s = Saved()
        s.w, s.h = f:GetWidth(), f:GetHeight()
        Layout()
    end)
end

local function Create()
    local s = Saved()
    frame = CreateFrame("Frame", "SenditUpgradeMeasure", UIParent)
    frame:SetSize(math.max(MIN_W, tonumber(s.w) or DEF_W), math.max(MIN_H, tonumber(s.h) or DEF_H))
    if s.x and s.y then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", s.x, s.y)
    else
        frame:SetPoint("CENTER", 300, 0)
    end
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(MIN_W, MIN_H, 700, 400) end
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        s.x, s.y = f:GetLeft(), f:GetTop()
    end)
    frame:SetScript("OnSizeChanged", Layout)
    T.Fill(frame, "bg", "BACKGROUND"):SetAllPoints()
    local edges = T.Border(frame, "border")
    T.Decorate(frame, "panel", { onApply = function(_, on) for _, e in ipairs(edges) do e:SetShown(not on) end end })

    local title = T.Text(frame, "label", "accent")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(L.mTitle)
    frame.sub = T.Text(frame, "caption", "textMuted")
    frame.sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    frame.sub:SetPoint("RIGHT", -PAD, 0)
    local close = Sendit.Widgets.Close(frame, function() MeasureWindow.SetShown(false) end)
    close:SetPoint("TOPRIGHT", -4, -4)

    frame.rows = {}
    for i, row in ipairs(ROWS) do
        frame.rows[i] = Row(frame)
        frame.rows[i].label:SetText(L[row.label])
    end
    frame.foot = T.Text(frame, "caption", "textMuted")
    frame.foot:SetPoint("BOTTOMLEFT", PAD, PAD - 2)
    frame.foot:SetPoint("RIGHT", -22, 0)

    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if dirty and elapsed >= 0.25 then
            elapsed, dirty = 0, false
            Draw()
        end
    end)
    frame:SetScript("OnShow", Layout)
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:SetScript("OnEvent", function() dirty = true end)
    Grip(frame)
    frame:Hide()
end

function MeasureWindow.SetShown(show)
    if show and not frame then Create() end
    if frame then frame:SetShown(show) end
    Saved().shown = show or nil
end

function MeasureWindow.Toggle() MeasureWindow.SetShown(not (frame and frame:IsShown())) end

function MeasureWindow.Changed() dirty = true end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
    if ns.db and ns.db.measureWindow and ns.db.measureWindow.shown then MeasureWindow.SetShown(true) end
end)
