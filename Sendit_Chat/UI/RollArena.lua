--[[
  RollArena: Duels drawn above the chat, below the loot cards - one block per duel: choices, countdown,
  numbers counting up, the leader on top in gold (a new leader slides up and flashes), then the winner.
  Middle click hides a block; its duel and result card go on. Own top-level frame, hidden while empty.
]]
local _, ns = ...
local T, Loot = ns.Theme, ns.Loot

local RollArena = {}
ns.RollArena = RollArena

local W, HEAD, ROW, FOOT, PAD, GAP = 270, 26, 18, 14, 6, 6
local MAX_BLOCKS, MAX_ROWS = 3, 6
local COUNT_UP = 0.45
local GOLD = { 1, 0.82, 0.2 }

local arena, Release
local blocks, free, dismissed = {}, {}, {}   -- duel -> block; spare blocks; duel -> hidden by the player

local function Slide(frame, dx, dy, duration)
    local g = frame.move
    if not g then
        g = frame:CreateAnimationGroup()
        g.a = g:CreateAnimation("Translation")
        g.a:SetDuration(0)
        g.a:SetOrder(1)
        g.b = g:CreateAnimation("Translation")
        g.b:SetSmoothing("OUT")
        g.b:SetOrder(2)
        frame.move = g
    end
    g:Stop()
    g.a:SetOffset(dx, dy)
    g.b:SetOffset(-dx, -dy)
    g.b:SetDuration(duration)
    g:Play()
end

local function Fader(frame, from, to, duration, bounce)
    local g = frame:CreateAnimationGroup()
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(from)
    a:SetToAlpha(to)
    a:SetDuration(duration)
    a:SetSmoothing("IN_OUT")
    if bounce then g:SetLooping("BOUNCE") end
    g:SetToFinalAlpha(true)
    return g
end

-- rows ---------------------------------------------------------------------------

local function NewRow(block)
    local r = CreateFrame("Frame", nil, block)
    r:SetSize(W - 2 * PAD, ROW)
    -- the flash fades as a frame: a texture's alpha is its colour
    r.flash = CreateFrame("Frame", nil, r)
    r.flash:SetAllPoints()
    r.flash:SetAlpha(0)
    local glow = r.flash:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(T.WHITE)
    glow:SetAllPoints()
    glow:SetGradient("HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.45), CreateColor(GOLD[1], GOLD[2], GOLD[3], 0))
    r.flashAnim = Fader(r.flash, 0, 1, 0.25, true)
    r.lead = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.lead:SetTexture(T.WHITE)
    r.lead:SetAllPoints()
    r.lead:SetGradient("HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], 0.16), CreateColor(GOLD[1], GOLD[2], GOLD[3], 0))
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("LEFT", 2, 0)
    r.name = T.Text(r, 12, "text")
    T.Own(r.name)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetPoint("RIGHT", r, "RIGHT", -40, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.value = T.Text(r, 13, "text")
    T.Own(r.value)
    r.value:SetPoint("RIGHT", -4, 0)
    r.value:SetJustifyH("RIGHT")
    r.inAnim = Fader(r, 0, 1, 0.3)
    return r
end

local function RowFrame(block, key)
    local r = block.rows[key]
    if r then return r, false end
    r = table.remove(block.spare) or NewRow(block)
    r.key, r.y, r.rollingUntil = key, nil, nil
    block.rows[key] = r
    return r, true
end

local function StopFlash(r)
    r.flashAnim:Stop()
    r.flash:SetAlpha(0)
end

-- after the count-up: one flash, unless the row went elsewhere meanwhile
local function Flash(b, r, key)
    StopFlash(r)
    C_Timer.After(COUNT_UP, function()
        if b.rows[key] ~= r then return end
        r.flashAnim:Play()
        C_Timer.After(0.5, function() StopFlash(r) end)
    end)
end

local function CountUp(r, final)
    r.rollingUntil = GetTime() + COUNT_UP
    r:SetScript("OnUpdate", function(self)
        if GetTime() >= self.rollingUntil then
            self:SetScript("OnUpdate", nil)
            self.rollingUntil = nil
            self.value:SetText(final)
            return
        end
        self.value:SetText(math.random(1, 100))
    end)
end

local function PaintRow(r, row, leader, done)
    r.icon:SetTexture(ns.Rolls.ICONS[row.kind] or ns.Rolls.ICONS.need)
    local cr, cg, cb = T.ClassRGB(row.class)
    if row.me then cr, cg, cb = 1, 1, 1 end
    r.name:SetText(row.name)
    r.name:SetTextColor(cr, cg, cb, 1)
    local isLead = leader == row
    r.lead:SetShown(isLead)
    if not r.rollingUntil then
        if row.value then
            r.value:SetText(row.value)
        else
            r.value:SetText(row.pending and "?" or "·")
        end
    end
    if isLead then
        r.value:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
    else
        local vr, vg, vb = T.RGB(row.value and "text" or "textMuted")
        r.value:SetTextColor(vr, vg, vb, 1)
    end
    r:SetAlpha(done and not isLead and 0.6 or 1)
end

-- blocks -------------------------------------------------------------------------

local function NewBlock()
    local b = CreateFrame("Button", nil, arena)
    b:SetWidth(W)
    b.bg = T.Tex(b, "BACKGROUND", "bg", 0.94)
    b.bg:SetAllPoints()
    b.bar = T.Tex(b, "ARTWORK", "accent", 1)
    T.Own(b.bar)
    b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(3)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("TOPLEFT", PAD + 4, -PAD + 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.title = T.Text(b, 13, "text")
    T.Own(b.title)
    b.title:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.title:SetPoint("RIGHT", b, "TOPRIGHT", -84, -PAD - 9)
    b.title:SetJustifyH("LEFT")
    b.title:SetWordWrap(false)
    b.status = T.Text(b, 11, "textMuted")
    b.status:SetPoint("RIGHT", b, "TOPRIGHT", -PAD - 4, -PAD - 9)
    b.status:SetJustifyH("RIGHT")
    b.timer = T.Tex(b, "ARTWORK", "accent", 0.9)
    b.timer:SetPoint("TOPLEFT", PAD + 4, -HEAD)
    b.timer:SetHeight(2)
    b.foot = T.Text(b, 10, "textMuted")
    b.foot:SetPoint("BOTTOMLEFT", PAD + 4, PAD - 1)
    b.foot:SetPoint("RIGHT", -PAD, 0)
    b.foot:SetJustifyH("LEFT")
    b.foot:SetWordWrap(false)
    b.inAnim = Fader(b, 0, 1, 0.3)
    b.outAnim = Fader(b, 1, 0, 0.4)
    b.rows, b.spare = {}, {}
    b:SetScript("OnEnter", function(self)
        if not self.duel or not self.duel.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        if pcall(GameTooltip.SetHyperlink, GameTooltip, self.duel.link) then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForClicks("MiddleButtonUp")
    b:SetScript("OnClick", function(self)
        if not self.duel then return end
        GameTooltip:Hide()
        dismissed[self.duel] = true
        Release(self.duel)
    end)
    return b
end

local function Countdown(b)
    local d = b.duel
    if not d or d.state ~= "live" or not d.ends then
        b.timer:Hide()
        b:SetScript("OnUpdate", nil)
        return
    end
    b.total = b.total or math.max(d.ends - GetTime(), 1)
    b.timer:Show()
    b:SetScript("OnUpdate", function(self)
        local left = self.duel.ends and (self.duel.ends - GetTime()) or 0
        if left <= 0 or self.duel.state ~= "live" then
            self.timer:Hide()
            self.status:SetText("")
            self:SetScript("OnUpdate", nil)
            return
        end
        self.timer:SetWidth(math.max(1, (W - 2 * PAD - 8) * left / self.total))
        self.status:SetText(math.ceil(left) .. " s")
    end)
end

local function Sorted(d)
    local list, passed = {}, {}
    for _, row in ipairs(d.rows) do
        if row.kind == "pass" then passed[#passed + 1] = row.name else list[#list + 1] = row end
    end
    table.sort(list, function(a, b)
        if d.winner and (a == d.winner) ~= (b == d.winner) then return a == d.winner end
        local sa, sb = ns.Duels.Score(a), ns.Duels.Score(b)
        if (sa ~= nil) ~= (sb ~= nil) then return sa ~= nil end
        if sa and sb and sa ~= sb then return sa > sb end
        return a.name < b.name
    end)
    return list, passed
end

local function Header(b, d)
    local L = ns.L
    if d.link then
        local item = Loot.Item(d.link)
        b.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.title:SetText(d.link:match("|h%[?(.-)%]?|h") or d.link)
        b.title:SetTextColor(item.r or 1, item.g or 1, item.b or 1, 1)
    else
        b.icon:SetTexture(ns.Rolls.ICONS.need)
        b.title:SetText("/roll " .. d.range)
        b.title:SetTextColor(1, 1, 1, 1)
    end
    local mr, mg, mb = T.RGB("textMuted")
    if d.state == "done" then
        local w = d.winner
        b.status:SetText(not w and L.ALL_PASSED or (w.me and L.WON) or L.WINS:format(w.name))
        if w then b.status:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1) else b.status:SetTextColor(mr, mg, mb, 1) end
        b.bar:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    else
        if d.state == "reveal" then b.status:SetText("") end
        b.status:SetTextColor(mr, mg, mb, 1)
        b.bar:SetVertexColor(T.RGB("accent"))
    end
end

local function Paint(b, what, changed)
    local d = b.duel
    Header(b, d)
    local list, passed = Sorted(d)
    local leader = ns.Duels.Leader(d)
    if d.state == "done" then leader = d.winner end
    local seen = {}
    local y = -(HEAD + 4)
    for i, row in ipairs(list) do
        if i > MAX_ROWS then break end
        local r, fresh = RowFrame(b, row.key)
        seen[row.key] = true
        if r.y and r.y ~= y then Slide(r, 0, r.y - y, 0.3) end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", PAD, y)
        r.y = y
        r:Show()
        if fresh then
            Slide(r, -16, 0, 0.3)
            r.inAnim:Play()
        end
        if what == "reveal" and row == changed then
            CountUp(r, row.value)
            if row.led then Flash(b, r, row.key) end
        end
        PaintRow(r, row, leader, d.state == "done")
        y = y - ROW
    end
    for key, r in pairs(b.rows) do
        if not seen[key] then
            r:Hide()
            r:SetScript("OnUpdate", nil)
            b.rows[key] = nil
            b.spare[#b.spare + 1] = r
        end
    end
    local more = #list - MAX_ROWS
    local foot = {}
    if more > 0 then foot[#foot + 1] = "+" .. more end
    if #passed > 0 then foot[#foot + 1] = ns.L.PASS .. ": " .. table.concat(passed, ", ") end
    b.foot:SetText(table.concat(foot, "  ·  "))
    b.foot:SetShown(#foot > 0)
    local rows = math.min(#list, MAX_ROWS)
    b:SetHeight(HEAD + 4 + rows * ROW + (#foot > 0 and FOOT or 0) + PAD)
    b.timer:SetWidth(W - 2 * PAD - 8)
    Countdown(b)
end

local function Layout()
    if not arena then return end
    local list = ns.Duels.List()
    local y, shown = 0, 0
    for i = #list, 1, -1 do
        local b = blocks[list[i]]
        if b then
            if shown < MAX_BLOCKS then
                b:ClearAllPoints()
                b:SetPoint("BOTTOMLEFT", arena, "BOTTOMLEFT", 0, y)
                y = y + b:GetHeight() + GAP
                b:Show()
                shown = shown + 1
            else
                b:Hide()
            end
        end
    end
    arena:SetHeight(math.max(y - GAP, 1))
    local was = arena:IsShown()
    arena:SetShown(shown > 0)
    if was ~= arena:IsShown() and ns.LootCards then ns.LootCards.Anchor() end
end

function Release(d)
    local b = blocks[d]
    if not b then return end
    blocks[d] = nil
    b:SetScript("OnUpdate", nil)
    b.outAnim:Play()
    C_Timer.After(0.4, function()
        if b.duel ~= d then return end
        b.duel = nil
        b:Hide()
        for key, r in pairs(b.rows) do
            r:Hide()
            r:SetScript("OnUpdate", nil)
            b.rows[key] = nil
            b.spare[#b.spare + 1] = r
        end
        free[#free + 1] = b
        Layout()
    end)
end

local function OnChange(d, what, row)
    if not arena then return end
    if what == "gone" then
        dismissed[d] = nil
        return Release(d)
    end
    if dismissed[d] then return end
    local b = blocks[d]
    if not b then
        b = table.remove(free) or NewBlock()
        b.duel, b.total = d, nil
        b.outAnim:Stop()
        b:SetAlpha(1)
        blocks[d] = b
        b.inAnim:Play()
    end
    Paint(b, what, row)
    Layout()
end

function RollArena.Frame() return arena end
RollArena._Blocks = blocks

ns.OnReady(function()
    arena = CreateFrame("Frame", "SenditRollArena", UIParent)
    arena:SetSize(W, 1)
    arena:SetFrameStrata("MEDIUM")
    arena:Hide()
    ns.Duels.OnChange(OnChange)
    if ns.LootCards then ns.LootCards.Anchor() end
end)
