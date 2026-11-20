--[[
  Window: the dungeon browser - list left (level order; while the boost runs the upgrades first,
  biggest first, then the other dungeons for your level, dimmed), the picked dungeon right (loading-screen banner, one card per boss).
  Window:Open(text) / Search(text, keep) / Pick(id) / Refresh() / BoostChanged() / Hide()
]]
local _, ns = ...
local L, DB, S = ns.L, ns.Database, ns.Style
local T, W = Sendit.Theme, Sendit.Widgets
local Window = {}
ns.Window = Window
local frame, picked, query
local results, rowPool, cards = {}, {}, {}
local boosted = 0
local ROW = S.size.row + S.size.rowGap
local BANNER = 150
function Window:Pick(id)
    picked = id
    if frame then frame.detailScroll:SetVerticalScroll(0) end
    self:Refresh()
end

function Window:RenderResults()
    local scroll = frame.resultScroll
    local first = math.floor((scroll:GetVerticalScroll() or 0) / ROW) + 1
    local last = math.min(#results, first + math.ceil(scroll:GetHeight() / ROW))
    local used = 0
    for i = first, last do
        used = used + 1
        local row = rowPool[used] or ns.DungeonRow.Create(scroll.content, function(id) Window:Pick(id) end)
        rowPool[used] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
        ns.DungeonRow.Paint(row, results[i], frame.metrics.left, picked == results[i].id)
    end
    for i = used + 1, #rowPool do rowPool[i]:Hide() end
end

local function ResultTitle()
    if not ns.Boost.Active() then return "" end
    local done, total, running, missing = ns.Boost.Progress()
    if running then return L.boostRating:format(done + (missing or 0), total) end
    return (boosted == 1 and L.boostCountOne or L.boostCount):format(boosted, S.Threshold())
end

local function Detail()
    local d = picked and DB.Get(picked)
    frame.detailEmpty:SetShown(d == nil)
    frame.detailEmpty:SetText(#results == 0 and "" or L.pick)
    frame.detailTitle:SetText(d and DB.Name(d) or "")
    for _, c in ipairs(cards) do c:Hide() end
    local art = ns.Art.Screen(frame.banner, d, frame.metrics.right, BANNER)
    frame.bannerFade:SetShown(art)
    if art then
        local r, g, b = T.Color(S.surface.window)
        pcall(frame.bannerFade.SetGradient, frame.bannerFade, "VERTICAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 0))
    end
    local head = art and (BANNER + 6) or S.size.detailHead
    frame.detailTitle:ClearAllPoints()
    frame.detailTitle:SetPoint("TOPLEFT", S.space.inner, art and -(BANNER - 52) or -6)
    frame.detailTitle:SetPoint("RIGHT", -S.space.inner, 0)
    frame.detailScroll:ClearAllPoints()
    frame.detailScroll:SetPoint("TOPLEFT", 0, -head)
    frame.detailScroll:SetSize(frame.metrics.right, frame.metrics.height - head)
    if not d then frame.detailMeta:SetText("") return end
    local fit = DB.Fit(d, DB.Level())
    local _, _, _, hex = S.Hex(S.FitRole(fit))
    local level = d.min > 0 and L.levels:format(d.min, d.max) or L.levelUnknown
    local fitWord = ({ fits = L.fitsYou, above = L.aboveYou, below = L.belowYou })[fit]
    local parts = { hex .. level .. (fitWord and (" (" .. fitWord .. ")") or "") .. "|r",
        (d.raid and d.map ~= 0) and (L.raid .. "  ·  " .. L.players:format(d.players)) or DB.Kind(d),
        L.bosses:format(#d.bosses) }
    frame.detailMeta:SetText(table.concat(parts, "   ·   "))
    local width, y = frame.metrics.right - 2 * S.space.inner, 0
    for i, boss in ipairs(d.bosses) do
        local card = cards[i] or ns.BossCard.Create(frame.detailScroll.content)
        cards[i] = card
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", S.space.inner, -y)
        y = y + card:Set(i, boss, width) + 8
    end
    frame.detailScroll.content:SetHeight(math.max(1, y))
end

function Window:Refresh()
    if not frame or not frame:IsShown() then return end
    local boosting = ns.Boost.Active()
    ns.Toolbar.Update(frame)
    ns.Layout.Apply(frame)  -- after the labels: chips size to their text
    frame.resultTitle:SetText(ResultTitle())
    frame.resultScroll.content:SetHeight(math.max(1, #results * ROW))
    frame.listEmpty:SetShown(#results == 0)
    frame.listEmpty:SetText(boosting and not select(3, ns.Boost.Progress()) and L.boostEmpty:format(S.Threshold())
        or (boosting and "" or L.empty))
    self:RenderResults()
    Detail()
end

function Window:Search(text, keep)
    query = text or ""
    local level = DB.Level()
    results, boosted = DB.Search(query, ns.Toolbar.Filter(), level), 0
    if ns.Boost.Active() then
        local out, rest = {}, {}
        for _, d in ipairs(results) do
            if ns.Boost.Get(d.id) then
                out[#out + 1] = d
            elseif DB.Fit(d, level) == "fits" then
                rest[#rest + 1] = d
            end
        end
        table.sort(out, function(a, b)
            local x, y = ns.Boost.Get(a.id), ns.Boost.Get(b.id)
            if x.pct ~= y.pct then return x.pct > y.pct end
            return a.min < b.min
        end)
        boosted = #out
        for _, d in ipairs(rest) do out[#out + 1] = d end
        results = out
    end
    local still = false
    for _, d in ipairs(results) do if d.id == picked then still = true break end end
    if not still and not keep then picked = results[1] and results[1].id or nil end
    if keep then
        local max = math.max(0, #results * ROW - frame.resultScroll:GetHeight())
        frame.resultScroll:SetVerticalScroll(math.min(frame.resultScroll:GetVerticalScroll() or 0, max))
    else
        frame.resultScroll:SetVerticalScroll(0)
    end
    self:Refresh()
end

function Window:BoostChanged()
    if frame and frame:IsShown() then self:Search(query, true) end
end

local function ListPane()
    frame.list = CreateFrame("Frame", nil, frame)
    T.Fill(frame.list, S.surface.list, "BACKGROUND"):SetAllPoints()
    frame.resultTitle = T.Text(frame.list, S.font.caption, "textMuted")
    frame.resultTitle:SetPoint("TOPLEFT", S.space.inner + 2, -10)
    frame.resultScroll = W.ScrollArea(frame.list)
    frame.resultScroll:SetPoint("TOPLEFT", 0, -S.size.paneHead)
    frame.resultScroll:SetScript("OnVerticalScroll", function() Window:RenderResults() end)
    frame.listEmpty = T.Text(frame.list, S.font.meta, "textMuted")
    frame.listEmpty:SetPoint("TOPLEFT", S.space.inner, -S.size.paneHead - 30)
    frame.listEmpty:SetPoint("RIGHT", -S.space.inner, 0)
    frame.listEmpty:SetWordWrap(true)
end

local function DetailPane()
    frame.detail = CreateFrame("Frame", nil, frame)
    pcall(frame.detail.SetClipsChildren, frame.detail, true)
    local i = S.space.inner
    frame.banner = frame.detail:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.banner:SetPoint("TOPLEFT")
    frame.banner:SetPoint("TOPRIGHT")
    frame.banner:SetHeight(BANNER)
    frame.bannerFade = frame.detail:CreateTexture(nil, "BACKGROUND", nil, 2)
    frame.bannerFade:SetColorTexture(1, 1, 1, 1)
    frame.bannerFade:SetPoint("BOTTOMLEFT", frame.banner, "BOTTOMLEFT")
    frame.bannerFade:SetPoint("BOTTOMRIGHT", frame.banner, "BOTTOMRIGHT")
    frame.bannerFade:SetHeight(BANNER * 0.7)
    frame.detailTitle = T.Text(frame.detail, S.font.heading, "text")
    frame.detailTitle:SetPoint("TOPLEFT", i, -6)
    frame.detailTitle:SetPoint("RIGHT", -i, 0)
    frame.detailTitle:SetJustifyH("LEFT")
    frame.detailMeta = T.Text(frame.detail, S.font.meta, "textDim")
    frame.detailMeta:SetPoint("TOPLEFT", frame.detailTitle, "BOTTOMLEFT", 0, -6)
    frame.detailScroll = W.ScrollArea(frame.detail)
    frame.detailScroll:SetPoint("TOPLEFT", 0, -S.size.detailHead)
    frame.detailEmpty = T.Text(frame.detail, S.font.meta, "textMuted")
    frame.detailEmpty:SetPoint("CENTER")
end

local pendingPaint = false
local function ItemArrived()
    if pendingPaint or not frame or not frame:IsShown() then return end
    pendingPaint = true
    C_Timer.After(0.3, function()
        pendingPaint = false
        Window:Refresh()
    end)
end

local function Create()
    frame = CreateFrame("Frame", "SenditDungeonsWindow", UIParent)
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
    tinsert(UISpecialFrames, "SenditDungeonsWindow")
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT", -40, 0)
    drag:SetHeight(S.size.header)
    drag:SetFrameLevel(frame:GetFrameLevel() + 1)
    W.Movable(frame, drag)
    frame.drag = drag
    ns.Toolbar.Create(frame, {
        search = function(text) if text ~= query then Window:Search(text) end end,
        refilter = function() Window:Search(query) end,
        restart = function()
            frame.search:SetText("")
            Window:Search("")
        end,
    })
    ListPane()
    DetailPane()
    frame:SetScript("OnShow", function() Window:Refresh() end)
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnEvent", ItemArrived)
    ns.Layout.Enable(frame)
end

function Window:Open(text)
    if ns.disabled then return end
    if not frame then Create() end
    frame:Show()
    if text and text ~= "" then
        frame.search:SetText(text)
        self:Search(text)
    elseif query == nil then
        self:Search("")
    else
        self:Search(query, true)
    end
end

function Window:Hide() if frame then frame:Hide() end end

function Window:IsShown() return frame ~= nil and frame:IsShown() end

Sendit.OnSettingsChanged(function() if frame then Window:Refresh() end end)

Sendit:AddLauncher({
    key = "dungeons", order = 40, icon = "Interface\\AddOns\\Sendit_Dungeons\\Media\\Icon", title = "Dungeons",
    toggle = function() if Window:IsShown() then Window:Hide() else Window:Open() end end,
    shown = function() return Window:IsShown() end,
})
