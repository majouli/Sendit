--[[
  Toolbar: the browser's header - emblem and name, the search, three chips
  and the close button (their places: UI/Layout.lua).
    Filter   all / for my level / dungeons / raids (account layout: filter)
    Range    standard (what you can do now) or a preview of dungeons and
             items up to 3 / 5 / 10 / all levels above you (Boost.Ahead)
    Boost    a menu of thresholds (the same number as Upgrade's item
             tooltip): picking one starts the gear boost, "Off" ends it,
             "Rate again" when gear, level or spec changed meanwhile

  Toolbar.Create(frame, on)   on = { search(text), refilter(), restart() }
  Toolbar.Update(frame)       chip labels from the current state
  Toolbar.Filter() -> the list filter key
]]
local _, ns = ...
local L, S = ns.L, ns.Style
local T, W = Sendit.Theme, Sendit.Widgets
local Toolbar = {}
ns.Toolbar = Toolbar
local THRESHOLDS = { 0.5, 1, 2, 3, 5 }
local AHEAD = { 0, 3, 5, 10, 60 }  -- levels above yours; 60 = every level

function Toolbar.Filter() return ns.module.db and ns.module.db.filter or "all" end

local function FilterOptions()
    return { { "all", L.filterAll }, { "fits", L.filterFits }, { "dungeons", L.filterDungeons }, { "raids", L.filterRaids } }
end

local function FilterLabel()
    for _, o in ipairs(FilterOptions()) do if o[1] == Toolbar.Filter() then return o[2] end end
    return L.filterAll
end

local function AheadLabel(n)
    if n == 0 then return L.aheadStandard end
    if n >= 60 then return L.aheadAll end
    return L.aheadPlus:format(n)
end

local function Tip(chip, title, text)
    chip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(title, 1, 0.82, 0)
        GameTooltip:AddLine(text(), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function BoostMenu(anchor, on)
    GameTooltip:Hide()
    local active = ns.Boost.Active()
    local options = {}
    for _, v in ipairs(THRESHOLDS) do options[#options + 1] = { v, L.boostAt:format(S.Threshold(v)) } end
    if active then
        table.insert(options, 1, { "again", L.boostAgain })
        options[#options + 1] = { "off", L.boostOff }
    end
    W.ShowMenu(anchor, options, active and ns.Boost.Min() or "off", function(key)
        if key == "off" then
            ns.Boost.Stop()
            on.refilter()
            return
        end
        if key ~= "again" then ns.Boost.SetMin(key) end
        if key == "again" or not ns.Boost.Active() or ns.Boost.Stale() then ns.Boost.Start() end
        on.restart()
    end)
end

local function AheadMenu(anchor, on)
    GameTooltip:Hide()
    local options = {}
    for _, n in ipairs(AHEAD) do options[#options + 1] = { n, AheadLabel(n) } end
    W.ShowMenu(anchor, options, ns.Boost.Ahead(), function(n)
        ns.Boost.SetAhead(n)
        on.refilter()
    end)
end

function Toolbar.Create(frame, on)
    local emblem = frame:CreateTexture(nil, "ARTWORK")
    emblem:SetTexture("Interface\\Icons\\INV_Misc_Head_Dragon_01")
    emblem:SetSize(26, 26)
    emblem:SetPoint("TOPLEFT", S.space.pad, -13)
    emblem:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local title = T.Text(frame, S.font.window, "accent")
    title:SetPoint("LEFT", emblem, "RIGHT", 10, 0)
    title:SetText("Sendit Dungeons")
    frame.titleWidth = 36 + title:GetStringWidth()
    frame.close = W.Close(frame, function() frame:Hide() end)
    frame.close:SetPoint("TOPRIGHT", -10, -13)
    frame.search = W.Search(frame, L.search, on.search)
    frame.search:SetHeight(26)
    T.SetFont(frame.search, 12)
    frame.filter = W.Chip(frame, function(self)
        W.ShowMenu(self, FilterOptions(), Toolbar.Filter(), function(key)
            if ns.module.db then ns.module.db.filter = key end
            on.refilter()
        end)
    end)
    frame.ahead = W.Chip(frame, function(self) AheadMenu(self, on) end)
    Tip(frame.ahead, L.ahead, function() return L.aheadHelp end)
    frame.boost = W.Chip(frame, function(self) if ns.Boost.Available() then BoostMenu(self, on) end end)
    Tip(frame.boost, L.boost, function()
        local svc = Sendit.Service("upgrade")
        return svc and L.boostHelp:format(svc.Spec() or "?") or L.boostNeedsUpgrade
    end)
    local line = T.Fill(frame, S.surface.hairline, "BORDER")
    line:SetPoint("TOPLEFT", 0, -S.size.header)
    line:SetPoint("TOPRIGHT", 0, -S.size.header)
    line:SetHeight(1)
    -- the drag area spans the header: the controls sit above it or it swallows their clicks
    for _, control in ipairs({ frame.search, frame.filter, frame.ahead, frame.boost, frame.close }) do
        control:SetFrameLevel(frame.drag:GetFrameLevel() + 2)
    end
end

function Toolbar.Update(frame)
    frame.filter:SetLabel(FilterLabel(), Toolbar.Filter() ~= "all")
    local boosting = ns.Boost.Active()
    local label = boosting and L.boostOn:format(S.Threshold()) or L.boost
    if boosting and ns.Boost.Stale() then label = label .. " (" .. L.stale .. ")" end
    frame.boost:SetLabel(label, boosting)
    frame.ahead:SetLabel(L.ahead .. ": " .. AheadLabel(ns.Boost.Ahead()), ns.Boost.Ahead() > 0)
end
