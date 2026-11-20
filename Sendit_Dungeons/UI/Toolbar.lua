--[[
  Toolbar: the browser's header - emblem, name, search, the Filter and Boost chips, close. Boost opens
  the suite's boost dialog (Sendit.BoostDialog: threshold, preview levels, slots).
  Toolbar.Create(frame, on)   on = { search(text), refilter(), restart() }
  Toolbar.Update(frame);  Toolbar.Filter() -> the list filter key
]]
local _, ns = ...
local L, S = ns.L, ns.Style
local T, W = Sendit.Theme, Sendit.Widgets
local Toolbar = {}
ns.Toolbar = Toolbar
local AHEAD = { { 0, "0" }, { 3, "+3" }, { 5, "+5" }, { 10, "+10" },  -- levels above yours; 60 = every level
    { 60, function() return L.aheadAll end } }

function Toolbar.Filter() return ns.module.db and ns.module.db.filter or "all" end

local function FilterOptions()
    return { { "all", L.filterAll }, { "fits", L.filterFits }, { "dungeons", L.filterDungeons }, { "raids", L.filterRaids } }
end

local function FilterLabel()
    for _, o in ipairs(FilterOptions()) do if o[1] == Toolbar.Filter() then return o[2] end end
    return L.filterAll
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

local cfg
local function BoostDialog(anchor, on)
    GameTooltip:Hide()
    cfg = cfg or { L = L, boost = ns.Boost,
        ahead = AHEAD,
        onChange = function() on.refilter() end,
        onStart = function()
            ns.Boost.Start()
            on.restart()
        end,
        onEnd = function()
            ns.Boost.Stop()
            on.refilter()
        end }
    Sendit.BoostDialog.Toggle(anchor, cfg)
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
    frame.boost = W.Chip(frame, function(self) BoostDialog(self, on) end)
    frame:HookScript("OnHide", function() Sendit.BoostDialog.Hide() end)
    Tip(frame.boost, L.boost, function()
        local svc = Sendit.Service("upgrade")
        return svc and L.boostHelp:format(svc.Spec() or "?") or L.boostNeedsUpgrade
    end)
    local line = T.Fill(frame, S.surface.hairline, "BORDER")
    line:SetPoint("TOPLEFT", 0, -S.size.header)
    line:SetPoint("TOPRIGHT", 0, -S.size.header)
    line:SetHeight(1)
    -- the drag area must not cover the controls
    for _, control in ipairs({ frame.search, frame.filter, frame.boost, frame.close }) do
        control:SetFrameLevel(frame.drag:GetFrameLevel() + 2)
    end
end

function Toolbar.Update(frame)
    frame.filter:SetLabel(FilterLabel(), Toolbar.Filter() ~= "all")
    local boosting = ns.Boost.Active()
    local label = boosting and L.boostOn:format(S.Threshold()) or L.boost
    if boosting and ns.Boost.Stale() then label = label .. " (" .. L.stale .. ")" end
    frame.boost:SetLabel(label, boosting)
end
