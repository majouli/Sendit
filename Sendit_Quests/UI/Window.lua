--[[
  Window: the quest journal. Left: the quest list (search, place/category and
  progress filters; virtual rows, UI/QuestRow.lua). Right: the chain of the
  quest picked in the list - its name, "3 of 7 completed" with a slim bar,
  the timeline (UI/Timeline.lua) and what the whole chain is worth.

  Two selections, kept apart: `root` = the quest picked in the list (gold in
  the list, gold ring + edge in the chain); `open` = the step opened in the
  timeline (a click opens it, a second click closes it). Picking a quest in
  the list opens its own step and scrolls to it.
  Filters narrow the list, never the chain. Empty states are designed:
  nothing found, nothing picked, a quest without recorded links, a cycle.

  Right click on a quest (list or chain) continues its chain (Track.lua);
  what happened shows for a few seconds right of the chain title.

  Window:Open(text) / OpenQuest(id) / Search(text, keep) / Filter(group, status) / Track(id)
  Window:Refresh() / UpdateProgress() / Hide()
]]
local _, ns = ...
local L, DB, S = ns.L, ns.Database, ns.Style
local T, W = Sendit.Theme, Sendit.Widgets
local Window = {}
ns.Window = Window
local frame, root, open, query
local autoRoot = false  -- the chain shown was picked for the player (first result), not by a click
local group, status = "all", "all"
local results, chain = {}, {}
local rowPool = {}
local ROW = S.size.row + S.size.rowGap

local function StatusOptions()
    return { { "all", L.allProgress }, { "unfinished", L.unfinished }, { "active", L.active },
        { "done", L.done }, { "unknown", L.unknown } }
end

local function Pick(id)
    root, open, autoRoot = id, id, false
    if id then chain, Window.cycle = DB.Chain(id) else chain, Window.cycle = {}, false end
    Window.scrollToRoot = true
    Window:Refresh()
end

local function Toggle(id)
    open = open ~= id and id or nil
    Window:Refresh()
end

function Window:RenderResults()
    local scroll = frame.resultScroll
    local first = math.floor((scroll:GetVerticalScroll() or 0) / ROW) + 1
    local last = math.min(#results, first + math.ceil(scroll:GetHeight() / ROW))
    local used = 0
    for i = first, last do
        used = used + 1
        local row = rowPool[used] or ns.QuestRow.Create(scroll.content, Pick)
        rowPool[used] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
        ns.QuestRow.Paint(row, results[i], frame.metrics.left, root == results[i])
    end
    for i = used + 1, #rowPool do rowPool[i]:Hide() end
end

local function ChainHead()
    local counts = ns.Progress.Summary(chain)
    frame.chainTitle:SetText(root and DB.Name(root) or "")
    local note = Window.cycle and L.cycle or (#chain == 1 and L.isolated or nil)
    frame.summary:SetText(root and (L.summary:format(counts.done, #chain) .. (note and ("   " .. note) or "")) or "")
    T.Paint(frame.summary, Window.cycle and "warning" or "textDim")
    frame.progress:SetShown(#chain > 1)
    frame.progressFill:SetWidth(math.max(1, frame.progress:GetWidth() * counts.done / math.max(1, #chain)))
    frame.progressFill:SetShown(counts.done > 0)
end

-- What the whole chain gives, below the timeline (catalog of all branches).
local function ChainTotal(y)
    local f = frame.total
    f:SetShown(#chain > 1)
    if #chain <= 1 then return y end
    local data = ns.Rewards.Chain(chain)
    local width = frame.metrics.right - 2 * S.space.inner
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", S.space.inner, -(y + S.space.section))
    f:SetWidth(width)
    f.head:SetText(L.chainRewards)
    local has = ns.MiniRewards.Render(f.bar, width, data)
    local notes = {}
    if data.branches then notes[#notes + 1] = L.branchRewards end
    if (data.missing or 0) > 0 or (data.missingXP or 0) > 0 then notes[#notes + 1] = L.partial end
    f.note:SetWidth(width)
    f.note:SetText(table.concat(notes, "  ·  "))
    f.note:ClearAllPoints()
    f.note:SetPoint("TOPLEFT", 0, -(18 + (has and S.size.icon + 6 or 0)))
    local h = 18 + (has and S.size.icon + 6 or 0) + (#notes > 0 and f.note:GetStringHeight() or 0)
    f:SetHeight(h)
    return y + S.space.section + h + S.space.pad
end

function Window:Refresh()
    if not frame or not frame:IsShown() then return end
    frame.search.hint:SetText(L.search)
    frame.group:Refresh()
    for _, o in ipairs(StatusOptions()) do
        if o[1] == status then frame.status:SetLabel(o[2], status ~= "all") end
    end
    Window:BoostHeader()
    ns.Layout.Apply(frame)
    frame.resultTitle:SetText(Window:ResultTitle())
    frame.resultScroll.content:SetHeight(math.max(1, #results * ROW))
    self:RenderResults()
    frame.listEmpty:SetShown(#results == 0)
    frame.listEmpty:SetText(ns.Boost.Active() and L.boostEmpty:format(S.Threshold()) or L.empty)
    ChainHead()
    local width = frame.metrics.right
    local y, positions = 0, {}
    frame.timeline:SetShown(#chain > 0)
    if #chain > 0 then
        y, positions = ns.Timeline.Render(frame.timeline, chain, width - S.space.inner, open, root, Toggle)
    end
    y = ChainTotal(y)
    frame.chainScroll.content:SetHeight(math.max(1, y))
    frame.questPositions = positions
    frame.chainEmpty:SetShown(#chain == 0)
    frame.chainEmpty:SetText(#results == 0 and "" or L.choose)
    local maxScroll = math.max(0, y - frame.chainScroll:GetHeight())
    local target = frame.chainScroll:GetVerticalScroll() or 0
    if self.scrollToRoot then
        self.scrollToRoot = false
        target = positions[root] and math.max(0, positions[root] - S.space.gap) or 0
    end
    frame.chainScroll:SetVerticalScroll(math.min(target, maxScroll))
end

-- Gear boost on: only quests whose best reward is an upgrade of at least
-- the threshold, the biggest upgrade first.
local function Boosted(list)
    local out, value = {}, {}
    for _, id in ipairs(list) do
        local r = ns.Boost.Get(id)
        if r then out[#out + 1], value[id] = id, r.pct end
    end
    table.sort(out, function(a, b)
        if value[a] ~= value[b] then return value[a] > value[b] end
        return a < b
    end)
    return out
end

function Window:ResultTitle()
    if not ns.Boost.Active() then return L.count:format(#results) end
    local done, total, running, missing = ns.Boost.Progress()
    local tail = running and ("   " .. L.boostRating:format(done + (missing or 0), total))
        or ((missing or 0) > 0 and ("   " .. L.boostMissing:format(missing)) or "")
    return (#results == 1 and L.boostCountOne or L.boostCount):format(#results, S.Threshold()) .. tail
end

-- The chip says what runs: "Gear boost" / "Gear boost >= 5 %" (gold) /
-- "... · stale" after a gear, level or spec change.
function Window:BoostHeader()
    local on, available = ns.Boost.Active(), ns.Boost.Available()
    local label = on and L.boostOn:format(S.Threshold()) or L.boost
    if on and ns.Boost.Stale() then label = label .. "  ·  " .. L.boostStale end
    frame.boost:SetLabel(label, on)
    T.Paint(frame.boost.text, available and (on and (ns.Boost.Stale() and "warning" or "accent") or "text") or "textMuted")
end

-- The boost's rating moves on: re-sort at most twice a second, at once when done.
function Window:BoostChanged()
    if not frame or not frame:IsShown() then return end
    local _, _, running = ns.Boost.Progress()
    local now = GetTime()
    if running and self.boostAt and now - self.boostAt < 0.5 then return end
    self.boostAt = now
    self:Search(query, true)
end

-- Started from the dialog. The boost looks at every quest possible now: the
-- search text left from before (often the quest-log button's quest) is
-- cleared; what the player types afterwards filters the boost list as usual.
local function StartBoost()
    if not ns.Boost.Start() then return end
    query = ""
    if frame.search:GetText() ~= "" then frame.search:SetText("") end
    Window:Search(query)
end

local function EndBoost()
    ns.Boost.Stop()
    Window:Search(query)
end

function Window:Search(text, keep)
    query = text or ""
    results = DB.Search(query, group, status)
    if ns.Boost.Active() then results = Boosted(results) end
    -- A progress update or setting change keeps the chain the player is reading;
    -- a chain picked for them follows the list's top (the boost re-sorts as it rates).
    if not (keep and root and #chain > 0) or (autoRoot and results[1] ~= root) then
        local id = (query ~= "" or group ~= "all" or ns.Boost.Active()) and results[1] or nil
        root, open, autoRoot = id, id, id ~= nil
        if id then chain, self.cycle = DB.Chain(id) else chain, self.cycle = {}, false end
        self.scrollToRoot = true
    end
    -- Quest-log events and the boost re-run the search all the time (keep):
    -- the list must stay where the player scrolled it (it jumped back in game).
    if keep then
        local max = math.max(0, #results * ROW - frame.resultScroll:GetHeight())
        frame.resultScroll:SetVerticalScroll(math.min(frame.resultScroll:GetVerticalScroll() or 0, max))
    else
        frame.resultScroll:SetVerticalScroll(0)
    end
    self:Refresh()
end

function Window:Filter(newGroup, newStatus)
    group, status = newGroup or group, newStatus or status
    self:Search(query)
end

function Window:UpdateProgress()
    ns.Boost.Invalidate()  -- a quest may be done now: its boost no longer counts
    if not frame or not frame:IsShown() then return end
    self:Search(query, true)
end

local function Pane(parent, role)
    local p = CreateFrame("Frame", nil, parent)
    T.Fill(p, role, "BACKGROUND"):SetAllPoints()
    return p
end

local function Header()
    local emblem = frame:CreateTexture(nil, "ARTWORK")
    emblem:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    emblem:SetSize(26, 26)
    emblem:SetPoint("TOPLEFT", S.space.pad, -13)
    emblem:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local title = T.Text(frame, S.font.window, "accent")
    title:SetPoint("LEFT", emblem, "RIGHT", 10, 0)
    title:SetText("Sendit Quests")
    frame.titleWidth = 36 + title:GetStringWidth()
    frame.close = Sendit.Widgets.Close(frame, function() frame:Hide() end)
    frame.close:SetPoint("TOPRIGHT", -10, -13)
    frame.search = W.Search(frame, L.search, function(text)
        -- Layout changes can repeat OnTextChanged without an edit: an
        -- unchanged search must not drop the quest the player picked.
        if text ~= query then Window:Search(text) end
    end)
    frame.search:SetHeight(26)
    frame.search:SetTextInsets(26, 8, 0, 0)
    frame.search.hint:ClearAllPoints()
    frame.search.hint:SetPoint("LEFT", 26, 0)
    T.SetFont(frame.search, 12)
    local lens = T.Circle(frame.search, "textMuted", 9, "OVERLAY", 1)
    lens:SetPoint("LEFT", 9, 1)
    T.Circle(frame.search, "panelAlt", 6, "OVERLAY", 2):SetPoint("CENTER", lens, "CENTER")
    local handle = T.Fill(frame.search, "textMuted", "OVERLAY", 1)
    handle:SetSize(4, 1.5)
    handle:SetPoint("CENTER", lens, "CENTER", 4, -4)
    handle:SetRotation(math.rad(-45))
    frame.group = ns.GroupPicker.Create(frame, function() return group end, function(key) Window:Filter(key) end)
    frame.status = Sendit.Widgets.Chip(frame, function(self)
        W.ShowMenu(self, StatusOptions(), status, function(key) Window:Filter(nil, key) end)
    end)
    frame.boost = Sendit.Widgets.Chip(frame, function(self)
        GameTooltip:Hide()
        ns.BoostDialog.Toggle(self, StartBoost, EndBoost)
    end)
    frame.boost:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.boost, 1, 0.82, 0)
        local svc = Sendit.Service("upgrade")
        GameTooltip:AddLine(svc and L.boostHelp:format(svc.Spec() or "?") or L.boostNeedsUpgrade, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.boost:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local line = T.Fill(frame, S.surface.hairline, "BORDER")
    line:SetPoint("TOPLEFT", 0, -S.size.header)
    line:SetPoint("TOPRIGHT", 0, -S.size.header)
    line:SetHeight(1)
    -- The drag area spans the header: the controls must sit above it or it
    -- swallows their clicks (the search box could not be focused).
    for _, control in ipairs({ frame.search, frame.group, frame.status, frame.boost, frame.close }) do
        control:SetFrameLevel(frame.drag:GetFrameLevel() + 2)
    end
end

local function ListPane()
    frame.list = Pane(frame, S.surface.list)
    frame.resultTitle = T.Text(frame.list, S.font.caption, "textMuted")
    frame.resultTitle:SetPoint("TOPLEFT", S.space.inner + 2, -10)
    frame.resultTitle:SetPoint("RIGHT", frame.list, "RIGHT", -S.space.inner, 0)  -- never into the chain pane
    frame.resultTitle:SetJustifyH("LEFT")
    frame.resultTitle:SetWordWrap(false)
    frame.resultScroll = W.ScrollArea(frame.list)
    frame.resultScroll:SetPoint("TOPLEFT", 0, -S.size.paneHead)
    frame.resultScroll:SetScript("OnVerticalScroll", function() Window:RenderResults() end)
    frame.listEmpty = T.Text(frame.list, S.font.meta, "textMuted")
    frame.listEmpty:SetPoint("TOP", 0, -S.size.paneHead - 40)
end

local function ChainPane()
    frame.chain = CreateFrame("Frame", nil, frame)
    local i = S.space.inner
    frame.chainTitle = T.Text(frame.chain, "heading", "text")
    frame.chainTitle:SetPoint("TOPLEFT", i, -6)
    frame.chainTitle:SetPoint("RIGHT", -i, 0)
    frame.summary = T.Text(frame.chain, S.font.meta, "textDim")
    frame.summary:SetPoint("TOPLEFT", frame.chainTitle, "BOTTOMLEFT", 0, -6)
    -- Feedback of a right click: a gold-edged bar over the chain head, a few seconds.
    local notice = CreateFrame("Frame", nil, frame.chain)
    notice:SetPoint("TOPLEFT", i, -4)
    notice:SetPoint("TOPRIGHT", -i, -4)
    notice:SetHeight(40)
    notice:SetFrameLevel(frame.chain:GetFrameLevel() + 20)
    T.Fill(notice, "panelAlt", "BACKGROUND"):SetAllPoints()
    local edge = T.Fill(notice, "accent", "ARTWORK")
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("BOTTOMLEFT")
    edge:SetWidth(3)
    T.Border(notice, "accent")
    notice.text = T.Text(notice, "body", "text")
    notice.text:SetPoint("LEFT", 14, 0)
    notice.text:SetPoint("RIGHT", -14, 0)
    notice:Hide()
    function notice:SetText(text) self.text:SetText(text) end
    function notice:GetText() return self.text:GetText() end
    frame.notice = notice
    frame.progress = CreateFrame("Frame", nil, frame.chain)
    frame.progress:SetPoint("TOPLEFT", i, -50)
    frame.progress:SetHeight(3)
    T.Fill(frame.progress, "track", "BACKGROUND"):SetAllPoints()
    frame.progressFill = T.Fill(frame.progress, "success", "ARTWORK")
    frame.progressFill:SetPoint("TOPLEFT")
    frame.progressFill:SetHeight(3)
    frame.chainScroll = W.ScrollArea(frame.chain)
    frame.chainScroll:SetPoint("TOPLEFT", 0, -S.size.chainHead)
    frame.timeline = ns.Timeline.Create(frame.chainScroll.content)
    frame.timeline:SetPoint("TOPLEFT", S.space.inner, 0)
    local total = CreateFrame("Frame", nil, frame.chainScroll.content)
    total.head = T.Text(total, S.font.section, "accent")
    total.head:SetPoint("TOPLEFT")
    total.bar = ns.MiniRewards.Create(total, S.size.icon)
    total.bar:SetPoint("TOPLEFT", 0, -18)
    total.note = T.Text(total, S.font.meta, "textMuted")
    total.note:SetWordWrap(true)
    frame.total = total
    frame.chainEmpty = T.Text(frame.chain, S.font.meta, "textMuted")
    frame.chainEmpty:SetPoint("CENTER")
end

local function Create()
    frame = CreateFrame("Frame", "SenditQuestsWindow", UIParent)
    Sendit.ownFrames[frame] = true
    frame:Hide()
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    local background = T.Fill(frame, S.surface.window, "BACKGROUND")
    background:SetAllPoints()
    local _, _, _, alpha = T.Color(S.surface.window)
    T.Paint(background, S.surface.window, 1 / math.max(0.01, alpha))  -- opaque: the game must not show through
    local borders = T.Border(frame, "border")
    T.Decorate(frame, "window", { level = 10, onApply = function(_, on)
        for _, edge in ipairs(borders) do edge:SetShown(not on) end
    end })
    tinsert(UISpecialFrames, "SenditQuestsWindow")
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT", -40, 0)
    drag:SetHeight(S.size.header)
    drag:SetFrameLevel(frame:GetFrameLevel() + 1)
    W.Movable(frame, drag)
    frame.drag = drag
    Header()
    ListPane()
    ChainPane()
    frame:SetScript("OnShow", function() Window:Refresh() end)
    frame:SetScript("OnHide", function() ns.GroupPicker.Hide() ns.BoostDialog.Hide() end)
    ns.Layout.Enable(frame)
end

function Window:OpenQuest(id)
    if not id then self:Open("") return end
    self:Open(tostring(id))
    if not frame or ns.disabled then return end
    Pick(id)  -- also for IDs the reference does not know (live quest log)
end

function Window:Open(text)
    if ns.disabled then return end
    if not frame then Create() end
    ns.Progress.Invalidate()
    frame:Show()
    if text ~= nil and ns.Boost.Active() then
        self:Search("", true)  -- the boost list stays; OpenQuest then shows the quest's chain
    elseif text ~= nil then
        group, status = "all", "all"
        frame.search:SetText(tostring(text))
        self:Search(tostring(text))
    elseif query == nil then self:Search("") else self:UpdateProgress() end
end

function Window:Hide() if frame then frame:Hide() end end

function Window:IsShown() return frame ~= nil and frame:IsShown() end

-- The menu opens at the mouse, not below the clicked row (an open step card is tall).
local cursor
local function AtCursor()
    cursor = cursor or CreateFrame("Frame", nil, UIParent)
    cursor:SetSize(1, 1)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursor:ClearAllPoints()
    cursor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x or 0) / scale, (y or 0) / scale)
    return cursor
end

-- Right click on a quest: a menu - follow the chain, or a map pin on its giver /
-- objective / turn-in (any quest, done or not). The result shows under the chain title.
function Window:Menu(id)
    local spots, options = ns.Track.Places(id), { { "chain", L.menuChain } }
    local g, f = spots.g, spots.f
    -- the same NPC gives and takes the quest: one entry, said so
    local same = g and f and g[1] == f[1] and g[2] == f[2] and g[3] == f[3]
    for _, entry in ipairs({ { "g", same and L.menuGiverTurnIn or L.menuGiver }, { "t", L.menuTarget },
                             { "f", L.menuTurnIn } }) do
        if spots[entry[1]] and not (same and entry[1] == "f") then options[#options + 1] = entry end
    end
    if ns.Guide.Following() then options[#options + 1] = { "stop", L.guideStop } end
    W.ShowMenu(AtCursor(), options, nil, function(key)
        if key == "chain" then self:Follow(id)
        elseif key == "stop" then ns.Guide.Stop() if ns.LogRoute then ns.LogRoute.Refresh() end
        else self:Notice(ns.Track.Pin(id, key)) end
    end)
end

-- Follow the chain: every known step (Guide.lua) - with Shortest Path Forever when it is there.
function Window:Follow(id)
    local text = self:Notice(ns.Guide.Start(id))
    if ns.LogRoute then ns.LogRoute.Refresh() end
    return text
end

function Window:Notice(text)
    if not frame then return text end
    frame.notice:SetText(text)
    frame.notice:Show()
    T.FadeIn(frame.notice, 0.2, 6)
    frame.noticeUntil = GetTime() + 6
    C_Timer.After(6.1, function()
        if frame.noticeUntil and GetTime() >= frame.noticeUntil then frame.notice:Hide() end
    end)
    return text
end

-- Settings change all the time in the suite (Fade rescans): repaint texts,
-- never search again (that re-sorted the boost list - "script ran too long").
Sendit.OnSettingsChanged(function()
    ns.GroupPicker.Hide()
    if frame then Window:Refresh() end
end)

Sendit:AddLauncher({
    key = "quests", order = 30, icon = "Interface\\AddOns\\Sendit_Quests\\Media\\Icon", title = "Quests",
    toggle = function() if Window:IsShown() then Window:Hide() else Window:Open() end end,
    shown = function() return Window:IsShown() end,
})
