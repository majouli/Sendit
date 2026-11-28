--[[
  Window: the macros of the player's class - one list, a section per talent tree after the ones for
  every specialization; a row is dragged (or clicked) onto an action bar. Unlearned macros only with
  "Show unlearned" (account: ns.module.db.showAll). Repaints when spells, macros or the language change.
  Window.Open() / Hide() / Toggle() / Shown()
]]
local _, ns = ...
local L = ns.L
local T, W = Sendit.Theme, Sendit.Widgets
local Build, Store = ns.Build, ns.Store
local Window = {}
ns.Window = Window

local WIDTH, HEIGHT, PAD, HEADER, ROW, ICON, NOTICE = 440, 600, 16, 60, 52, 32, 4
local frame
local rows, heads = {}, {}

local function Class()
    local ok, _, class = pcall(UnitClass, "player")
    return ok and type(class) == "string" and class or nil
end

local function Notice(text)
    frame.notice:SetText(text)
    frame.notice:Show()
    local mine = {}
    frame.noticeToken = mine
    C_Timer.After(NOTICE, function() if frame.noticeToken == mine then frame.notice:Hide() end end)
end

local function Pick(m)
    local ok, why = Store.Pickup(m)
    if not ok then Notice(why == "combat" and L.combat or L.full) end
end

local function Tooltip(row)
    local m = row.m
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(m.name, 1, 1, 1)
    GameTooltip:AddLine(m.text, 1, 0.82, 0, true)
    if #m.lacks > 0 then GameTooltip:AddLine(L.lacks:format(table.concat(m.lacks, ", ")), 1, 0.4, 0.4, true) end
    GameTooltip:AddLine(" ")
    for line in m.body:gmatch("[^\n]+") do GameTooltip:AddLine(line, 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, frame.scroll.content)
    r:SetHeight(ROW)
    T.Fill(r, "panel", "BACKGROUND"):SetAllPoints()
    T.Fill(r, "hover", "HIGHLIGHT"):SetAllPoints()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.icon:SetPoint("LEFT", 10, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.state = T.Text(r, "small", "success")
    r.state:SetPoint("TOPRIGHT", -10, -8)
    r.name = T.Text(r, "body", "text")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, 0)
    r.name:SetPoint("RIGHT", r.state, "LEFT", -8, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.text = T.Text(r, "small", "textMuted")
    r.text:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.text:SetPoint("RIGHT", -10, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetJustifyV("TOP")
    r.text:SetHeight(26)
    r.text:SetWordWrap(true)
    r:RegisterForDrag("LeftButton")
    r:SetScript("OnClick", function(self) Pick(self.m) end)
    r:SetScript("OnDragStart", function(self) Pick(self.m) end)
    r:SetScript("OnEnter", Tooltip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
end

local function Head(i)
    local h = heads[i]
    if not h then
        h = T.Text(frame.scroll.content, "caption", "accent")
        heads[i] = h
    end
    return h
end

local function Paint(r, m, y)
    r.m = m
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", frame.scroll.content, "RIGHT")
    r.icon:SetTexture(m.icon)
    r.icon:SetDesaturated(not m.known)
    r.name:SetText(m.name)
    r.text:SetText(m.known and m.text or (L.unknown .. " - " .. m.text))
    r.state:SetText(Store.Find(m.body) and L.made or "")
    r:SetAlpha(m.known and 1 or 0.55)
    r:Show()
end

function Window.Refresh()
    if not frame or not frame:IsShown() then return end
    local class = Class()
    local showAll = ns.module.db.showAll
    frame.title:SetText(L.title)
    frame.sub:SetText(L.hint)
    frame.allLabel:SetText(L.showAll)
    local trees = class and L.trees[class] or {}
    local byTree = {}
    for _, m in ipairs(class and Build.List(class) or {}) do
        if m.known or showAll then
            local t = m.entry.tree
            byTree[t] = byTree[t] or {}
            table.insert(byTree[t], m)
        end
    end
    local y, used, usedHeads = 0, 0, 0
    for tree = 0, 3 do
        local list = byTree[tree]
        if list then
            usedHeads = usedHeads + 1
            local h = Head(usedHeads)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 4, -(y + 6))
            h:SetText((tree == 0 and L.general or trees[tree] or ""):upper())
            h:Show()
            y = y + 26
            for _, m in ipairs(list) do
                used = used + 1
                Paint(Row(used), m, y)
                y = y + ROW + 4
            end
            y = y + 8
        end
    end
    for i = used + 1, #rows do rows[i]:Hide() end
    for i = usedHeads + 1, #heads do heads[i]:Hide() end
    frame.empty:SetShown(used == 0)
    frame.empty:SetText(L.none)
    frame.scroll.content:SetHeight(math.max(1, y))
end

local function Create()
    frame = CreateFrame("Frame", "SenditMacros", UIParent)
    Sendit.ownFrames[frame] = true
    Sendit.Widgets.Stacked(frame)
    tinsert(UISpecialFrames, "SenditMacros")
    frame:Hide()
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", -200, 40)
    frame:SetFrameStrata("DIALOG")  -- above the app bar (HIGH)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    T.Fill(frame, "bg", "BACKGROUND"):SetAllPoints()
    local borders = T.Border(frame, "border")
    T.Decorate(frame, "window", { level = 10, onApply = function(_, on)
        for _, edge in ipairs(borders) do edge:SetShown(not on) end
    end })
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT", -40, 0)
    drag:SetHeight(HEADER)
    W.Movable(frame, drag)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("TOPLEFT", PAD, -15)
    icon:SetTexture("Interface\\AddOns\\Sendit_Macros\\Media\\Icon")
    icon:SetTexCoord(0, 1, 0, 1)
    frame.title = T.Text(frame, "title", "text")
    frame.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 1)
    frame.sub = T.Text(frame, "small", "textMuted")
    frame.sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 0)
    frame.sub:SetPoint("RIGHT", -44, 0)
    frame.sub:SetJustifyH("LEFT")
    W.Close(frame, Window.Hide):SetPoint("TOPRIGHT", -10, -12)
    local rule = T.Fill(frame, "divider", "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -HEADER)
    rule:SetPoint("TOPRIGHT", 0, -HEADER)
    local all = W.Switch(frame, function() return ns.module.db.showAll end, function(v)
        ns.module.db.showAll = v
        Window.Refresh()
    end)
    all:SetPoint("TOPLEFT", PAD, -(HEADER + 14))
    frame.allLabel = T.Text(frame, "label", "textDim")
    frame.allLabel:SetPoint("LEFT", all, "RIGHT", 8, 0)
    frame.notice = T.Text(frame, "small", "danger")
    frame.notice:SetPoint("LEFT", frame.allLabel, "RIGHT", 16, 0)
    frame.notice:SetPoint("RIGHT", -PAD, 0)
    frame.notice:SetJustifyH("RIGHT")
    frame.notice:Hide()
    frame.scroll = W.ScrollArea(frame)
    frame.scroll:SetPoint("TOPLEFT", PAD, -(HEADER + 46))
    frame.scroll:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    frame.empty = T.Text(frame.scroll.content, "body", "textMuted")
    frame.empty:SetPoint("TOPLEFT", 4, -8)
    frame:SetScript("OnShow", Window.Refresh)
end

function Window.Open()
    if not frame then Create() end
    frame:Show()
end

function Window.Hide() if frame then frame:Hide() end end

function Window.Toggle()
    if frame and frame:IsShown() then Window.Hide() else Window.Open() end
end

function Window.Shown() return frame ~= nil and frame:IsShown() end

local pending = false
local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        Window.Refresh()
    end)
end

Sendit.OnSettingsChanged(Soon)
local events = CreateFrame("Frame")
for _, e in ipairs({ "SPELLS_CHANGED", "UPDATE_MACROS", "PLAYER_LEVEL_UP" }) do events:RegisterEvent(e) end
events:RegisterUnitEvent("UNIT_PET", "player")
events:SetScript("OnEvent", Soon)
