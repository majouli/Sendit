--[[
  Window: the upgrade scan - filters in a sidebar (Auction/Sidebar.lua), the upgrades per slot on the
  right with their sort order, and in the header a data light (age of the auction data and where it came
  from) and "Scan again" (only at the auction house). The data is loaded and rated in the background
  (Auction/Live.lua, Auction/Rank.lua); a filter change only filters, so the list follows at once.
  Opened from its button in the core's auction dock (closes with the auction house) or from the
  launcher / "/upgrade ah". Resizable, size kept in Sendit_UpgradeDB.auctionWindow; it sits above the
  suite's other windows (DIALOG strata) and shares its place beside the auction house with the other
  dock windows. Repaints at most every REPAINT s. Once the first web stand newer than the shown data is due
  (the web data's stand + the server's cadence, + the app's look; Web.Timing) newer data is most likely on
  disk - also when the shown data is an own scan - the light turns yellow and "Reload" shows beside it;
  before that its tooltip names the time. Web data already two renewals old when the game read it: the app
  is not fetching, nothing is offered.
]]
local _, ns = ...
local AL = ns.AL
local T, W, Slots = Sendit.Theme, Sendit.Widgets, Sendit.GearSlots
local Filter, Scan, Rank, Buy, Row = ns.AuctionFilter, ns.AuctionScan, ns.AuctionRank, ns.AuctionBuy, ns.AuctionRow
local Live, Sidebar, Web = ns.AuctionLive, ns.AuctionSidebar, ns.AuctionWeb
local Window = {}
ns.AuctionWindow = Window

local WIDTH, HEIGHT, MIN_W, MIN_H = 900, 640, 720, 460
local PAD, HEADER, SIDE_W, LIST_HEAD, REPAINT = 18, 64, 232, 40, 0.2
local FRESH, STALE = 75 * 60, 6 * 3600  -- data age for a green / yellow light (the server renews hourly)
local ICON = "Interface\\AddOns\\Sendit_Upgrade\\Media\\Scan"
local HEAD_H, ROW_STEP = 30, Row.HEIGHT + 4
local frame
local rows, heads = {}, {}

local Big = BreakUpLargeNumbers or tostring

local function Saved()
    ns.db.auctionWindow = ns.db.auctionWindow or {}
    return ns.db.auctionWindow
end

local function Screen()
    local w, h = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
    return w > 0 and w or 1920, h > 0 and h or 1080
end

local function Age(at)
    local secs = math.max(0, time() - (at or time()))
    if secs < 3600 then return AL.ageMin:format(math.max(1, math.floor(secs / 60))) end
    if secs < 86400 then return AL.ageHour:format(math.floor(secs / 3600)) end
    return AL.ageDay:format(math.floor(secs / 86400))
end

local function ListWidth() return frame:GetWidth() - SIDE_W - 3 * PAD end

local function Status()
    local s = Scan.State()
    if s.phase == "loading" then return AL.loading, 0.02 end
    if s.phase == "reading" then return AL.reading:format(Big(s.done), Big(s.total)), s.done / math.max(1, s.total) end
    if s.phase == "items" then return AL.items:format(Big(s.open or 0)), 1 end
    local throttled = s.phase == "throttled" and AL.throttled:format(Scan.WaitMinutes())
    if not Live.Source() then return throttled or AL.noData, nil end
    local rated, total, running, missing = Rank.Progress()
    local n = Rank.Count()
    local text = n == 0 and (running and AL.seeking or AL.none) or AL.upgrades:format(n)
    local fraction
    if running then
        local pct = math.floor(100 * rated / math.max(1, total))
        text, fraction = text .. "  ·  " .. AL.ratingBg:format(pct), rated / math.max(1, total)
        local eta = Rank.Stats().eta
        if eta and eta >= 60 then text = text .. "  ·  " .. AL.ratingLeft:format(math.ceil(eta / 60)) end
    elseif missing > 0 then
        text = text .. "  ·  " .. AL.missing:format(missing)
    end
    if throttled then text = throttled .. "  ·  " .. text end
    return text, fraction
end

local loadedAt = time()  -- the game read the web data now (login or /reload)

-- when the app has most likely written web data newer than the shown data (the game cannot see the file,
-- only reload it): the next renewal after the shown stand, counted from the web data's stand
local function NextDue(src)
    local webAt = Web.At()
    if not (src and src.at and webAt) then return nil end
    local interval, every = Web.Timing()
    if interval <= 0 or webAt + 2 * interval + every < loadedAt then return nil end
    return webAt + interval * (math.max(0, math.floor((src.at - webAt) / interval)) + 1) + every
end

local function NewerLikely(src)
    local due = NextDue(src)
    return due ~= nil and time() > due
end

local function PaintFresh()
    local src = Live.Source()
    local role, text = "danger", AL.freshNone
    if src then
        local age = time() - (src.at or 0)
        role = age <= FRESH and "success" or age <= STALE and "warning" or "danger"
        if NewerLikely(src) and role == "success" then role = "warning" end
        text = AL.freshAt:format(date("%H:%M", src.at), Age(src.at))
    end
    frame.reload:SetShown(NewerLikely(src) == true)
    T.Paint(frame.dot, role)
    frame.fresh:SetText(text)
    frame.freshHit:SetWidth(frame.fresh:GetStringWidth() + 20)
end

local function FreshTooltip(self)
    local src = Live.Source()
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText(AL.freshTitle, 1, 1, 1, 1)
    if not src then
        GameTooltip:AddLine(AL.freshNoneHelp, 0.8, 0.8, 0.8, true)
    else
        GameTooltip:AddLine((src.web and AL.freshWeb or AL.freshScan):format(Big(src.auctions or 0)), 1, 0.82, 0, true)
        GameTooltip:AddLine(src.web and AL.freshWebHelp or AL.freshScanHelp, 0.8, 0.8, 0.8, true)
        if NewerLikely(src) then
            GameTooltip:AddLine(AL.freshReload, 1, 0.82, 0, true)
        elseif NextDue(src) then
            GameTooltip:AddLine(AL.freshNext:format(date("%H:%M", NextDue(src))), 0.8, 0.8, 0.8, true)
        end
    end
    GameTooltip:Show()
end

local function Head(i)
    local h = heads[i]
    if not h then
        h = T.Text(frame.list.content, "caption", "accent")
        heads[i] = h
    end
    return h
end

local function ListHeight(groups)
    local y = 0
    for _, g in ipairs(groups) do y = y + HEAD_H + #g.list * ROW_STEP end
    return y
end

-- only the rows inside the visible part get a frame; the scroll offset is clamped before painting,
-- never by painting again (the client reports offsets like 0.0002 back)
local function RenderList()
    local groups = Rank.Groups()
    local total, view = ListHeight(groups), frame.list:GetHeight() or HEIGHT
    frame.list.content:SetHeight(math.max(1, total))
    local max = math.max(0, total - view)
    local top = frame.list:GetVerticalScroll() or 0
    if top > max + 0.5 then
        frame.list:SetVerticalScroll(max)
        top = max
    end
    local bottom, width = top + view, ListWidth()
    local y, used, usedHeads = 0, 0, 0
    for _, g in ipairs(groups) do
        if y + HEAD_H >= top and y <= bottom then
            usedHeads = usedHeads + 1
            local h = Head(usedHeads)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 4, -(y + 10))
            h:SetText(Slots.Label(g.group, AL):upper() .. "  |cff8a8a8a" .. #g.list .. "|r")
            h:Show()
        end
        y = y + HEAD_H
        for _, c in ipairs(g.list) do
            if y + Row.HEIGHT >= top and y <= bottom then
                used = used + 1
                local r = rows[used] or Row.Create(frame.list.content)
                rows[used] = r
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                Row.Paint(r, c, width)
            end
            y = y + ROW_STEP
        end
    end
    for i = used + 1, #rows do rows[i]:Hide() end
    for i = usedHeads + 1, #heads do heads[i]:Hide() end
end

local function LayoutSidebar()
    local h = frame.sidebar:Layout(frame.side:GetWidth() or SIDE_W)
    frame.side.content:SetHeight(h)
end

local lastSpec  -- the spec last read: a context still loading keeps it (no flicker, the button stays)

-- status, data light, scan button and list: what the background work changes
local function Repaint()
    if not frame or not frame:IsShown() then return end
    local ok, ctx, reason = pcall(ns.Compare.Context)
    local spec = ok and ctx and ns.L.specs[ctx.specKey]
    if spec then
        lastSpec = spec
    elseif ok and (reason == "loading" or reason == "nodata") then
        spec = lastSpec
    end
    frame.sub:SetText(spec and AL.forSpec:format(spec) or AL.noUpgrade)
    PaintFresh()
    local text, fraction = Status()
    frame.status:SetText(text)
    frame.fill:SetShown(fraction ~= nil)
    frame.track:SetShown(fraction ~= nil)
    if fraction then frame.fill:SetWidth(math.max(2, frame:GetWidth() * math.min(1, fraction))) end
    local scanning = Live.Scanning()
    frame.scan:SetLabel(scanning and AL.stop or AL.rescan)
    local can = spec ~= nil and (scanning or Buy.AtHouse())
    frame.scan:SetEnabled(can)
    frame.scan:SetAlpha(can and 1 or 0.45)
    RenderList()
end

-- everything, the sidebar too (on show, filter and language changes)
function Window.Refresh()
    if not frame or not frame:IsShown() then return end
    if frame.sidebar:Refresh() then LayoutSidebar() end
    frame.sort:Refresh()
    Repaint()
end

local pending = false
local function Soon()
    if pending or not frame or not frame:IsShown() then return end
    pending = true
    C_Timer.After(REPAINT, function()
        pending = false
        Repaint()
    end)
end

local function FiltersChanged()
    Rank.Dirty()
    Window.Refresh()
end

local function Layout()
    local w = frame:GetWidth()
    frame.side:ClearAllPoints()
    frame.side:SetPoint("TOPLEFT", PAD, -(HEADER + PAD))
    frame.side:SetPoint("BOTTOMLEFT", PAD, PAD)
    frame.side:SetWidth(SIDE_W)
    frame.divider:ClearAllPoints()
    frame.divider:SetPoint("TOPLEFT", PAD + SIDE_W + PAD / 2, -HEADER)
    frame.divider:SetPoint("BOTTOMLEFT", PAD + SIDE_W + PAD / 2, 0)
    local x = SIDE_W + 2 * PAD
    frame.status:ClearAllPoints()
    frame.status:SetPoint("LEFT", frame, "TOPLEFT", x, -(HEADER + PAD + 13))
    frame.status:SetWidth(math.max(60, w - x - PAD - frame.sort:GetWidth() - 12))
    frame.sort:ClearAllPoints()
    frame.sort:SetPoint("TOPRIGHT", -PAD, -(HEADER + PAD - 1))
    frame.list:ClearAllPoints()
    frame.list:SetPoint("TOPLEFT", x, -(HEADER + PAD + LIST_HEAD))
    frame.list:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    LayoutSidebar()
end
Window.Layout = Layout

local function Header()
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT", -470, 0)
    drag:SetHeight(HEADER)
    W.Movable(frame, drag)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", PAD, -16)
    icon:SetTexture(ICON)
    frame.title = T.Text(frame, "title", "text")
    frame.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 1)
    frame.title:SetText(AL.title)
    frame.sub = T.Text(frame, "small", "textMuted")
    frame.sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 0)
    local close = W.Close(frame, Window.Hide)
    close:SetPoint("TOPRIGHT", -10, -19)
    frame.scan = W.Button(frame, AL.rescan, Live.ToggleScan, "primary")
    frame.scan:SetPoint("RIGHT", close, "LEFT", -10, 0)
    frame.scan:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(AL.rescan, 1, 1, 1, 1)
        GameTooltip:AddLine(Buy.AtHouse() and AL.rescanTip or AL.rescanAway, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    frame.scan:HookScript("OnLeave", function() GameTooltip:Hide() end)
    frame.freshHit = CreateFrame("Frame", nil, frame)
    frame.freshHit:SetHeight(24)
    frame.freshHit:SetPoint("RIGHT", frame.scan, "LEFT", -14, 0)
    frame.freshHit:EnableMouse(true)
    frame.freshHit:SetScript("OnEnter", FreshTooltip)
    frame.freshHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.dot = T.Circle(frame.freshHit, "success", 9, "ARTWORK")
    frame.dot:SetPoint("LEFT", 2, 0)
    frame.fresh = T.Text(frame.freshHit, "small", "textDim")
    frame.fresh:SetPoint("LEFT", frame.dot, "RIGHT", 7, 0)
    frame.reload = W.Button(frame, AL.reload, function() ReloadUI() end)
    frame.reload:SetHeight(24)
    frame.reload:SetPoint("RIGHT", frame.freshHit, "LEFT", -8, 0)
    frame.reload:HookScript("OnEnter", FreshTooltip)
    frame.reload:HookScript("OnLeave", function() GameTooltip:Hide() end)
    frame.reload:Hide()
    local rule = T.Fill(frame, "divider", "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -HEADER)
    rule:SetPoint("TOPRIGHT", 0, -HEADER)
    frame.track = T.Fill(frame, "track", "ARTWORK", 1)
    frame.track:SetHeight(2)
    frame.track:SetPoint("TOPLEFT", 0, -HEADER)
    frame.track:SetPoint("TOPRIGHT", 0, -HEADER)
    frame.fill = T.Fill(frame, "accent", "ARTWORK", 2)
    frame.fill:SetHeight(2)
    frame.fill:SetPoint("TOPLEFT", 0, -HEADER)
end

local function Body()
    frame.side = W.ScrollArea(frame)
    frame.sidebar = Sidebar.Create(frame.side.content, FiltersChanged)
    frame.sidebar:SetPoint("TOPLEFT")
    frame.divider = T.Fill(frame, "divider", "ARTWORK")
    frame.divider:SetWidth(1)
    frame.status = T.Text(frame, "label", "text")
    frame.status:SetJustifyH("LEFT")
    frame.status:SetWordWrap(false)
    local options = {}
    for i, mode in ipairs(Filter.SORTS) do
        local key = "sort" .. mode:sub(1, 1):upper() .. mode:sub(2)
        options[i] = { mode, function() return AL[key] end }
    end
    frame.sort = W.Segmented(frame, options, Filter.Sort, function(mode)
        Filter.SetSort(mode)
        FiltersChanged()
    end)
    for _, b in ipairs(frame.sort.buttons) do
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(AL.sortHint, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    frame.list = W.ScrollArea(frame)
    frame.list:HookScript("OnMouseWheel", RenderList)
end

local function Create()
    frame = CreateFrame("Frame", "SenditUpgradeAuction", UIParent)
    Sendit.ownFrames[frame] = true
    Sendit.AuctionDock.Panel(frame)
    frame:Hide()
    local screenW, screenH = Screen()
    local saved = Saved()
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(math.min(MIN_W, screenW), math.min(MIN_H, screenH), screenW, screenH)
    end
    frame:SetSize(math.min(screenW, math.max(MIN_W, tonumber(saved.w) or WIDTH)),
        math.min(screenH - 40, math.max(MIN_H, tonumber(saved.h) or HEIGHT)))
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    T.Fill(frame, "bg", "BACKGROUND"):SetAllPoints()
    local borders = T.Border(frame, "border")
    T.Decorate(frame, "window", { level = 10, onApply = function(_, on)
        for _, edge in ipairs(borders) do edge:SetShown(not on) end
    end })
    Header()
    Body()
    Layout()
    W.Grip(frame, function(w, h)
        local s = Saved()
        s.w, s.h = w, h
    end)
    frame:SetScript("OnSizeChanged", function()
        Layout()
        Window.Refresh()
    end)
    frame:HookScript("OnShow", function()  -- a hook: the auction dock hooks OnShow too
        Rank.SetFast(true)
        Window.Refresh()
    end)
    frame:HookScript("OnHide", function() Rank.SetFast(false) end)
end

function Window.Open()
    if not frame then Create() end
    local ah = _G["AuctionHouseFrame"]
    if not frame:IsShown() then
        frame:ClearAllPoints()
        if Buy.AtHouse() and ah then
            frame:SetPoint("TOPLEFT", ah, "TOPRIGHT", 48, 0)
        else  -- anchored top left: the grip sizes from there
            local screenW, screenH = Screen()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", math.max(0, (screenW - frame:GetWidth()) / 2),
                -math.max(0, (screenH - frame:GetHeight()) / 2))
        end
    end
    frame:Show()
    frame:Raise()
    if not Live.Source() and not Live.Scanning() then Live.Load() end
end

function Window.Hide()
    if frame then frame:Hide() end
end

function Window.Toggle()
    if frame and frame:IsShown() then Window.Hide() else Window.Open() end
end

function Window.Shown() return frame ~= nil and frame:IsShown() end

Buy.OnChange(Soon)
Rank.OnChange(Soon)
Live.OnChange(Soon)
-- /gc ah stats: what the background rating is doing (diagnostic output, English)
local function PrintStats()
    local s, src = Rank.Stats(), Live.Source()
    ns.Print(("upgrade scan: %d of %d done (%.0f%%), %d above the level top put aside, %d not loaded, %d queued, "
        .. "%d kept from the last session; %.1f items/s for %.0f s%s")
        :format(s.rated, s.total, 100 * s.rated / math.max(1, s.total), s.deferred, s.missing, s.queued, s.kept,
            s.perSecond, s.seconds, s.eta and (", about %.0f min left"):format(s.eta / 60) or ""))
    ns.Print(("item loads asked: %d, held back by the %d/s limit: %d; upgrades shown: %d; data: %s from %s")
        :format(s.loads, s.limit, s.throttled, Rank.Count(), src and (src.web and "web" or "scan") or "none",
            src and src.at and date("%H:%M", src.at) or "-"))
end

ns.commands.ah = function(rest)
    if rest == "stats" then return PrintStats() end
    Window.Toggle()
end

Sendit.AuctionDock.Add({
    name = "SenditUpgradeAuctionTab", order = 20, icon = ICON, onClick = Window.Toggle,
    tooltip = function(tip)
        tip:SetText(AL.title, 1, 1, 1, 1)
        tip:AddLine(AL.subtitle, 1, 1, 1, true)
    end,
})

Sendit:AddLauncher({
    module = ns.module,
    key = "upgradeAuction", order = 21, icon = ICON,
    title = function() return AL.title end,
    toggle = Window.Toggle,
    shown = Window.Shown,
})

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:SetScript("OnEvent", Window.Hide)
