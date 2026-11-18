--[[
  Timeline: the whole route as a list docked to the right of the talent
  window, folded in and out by a side tab (UI/Tab.lua) on its right edge (state kept
  in the account section: module.db.timeline). It never covers the tree.
  One row per talent point (Route.Plan's steps): level, icon, talent, rank
  (2/5). Points taken are muted, then the open points re-timed to the
  character, the next one standing out; points dropped for the player's own
  choices come last, faded ("dropped"). The list opens scrolled to the next.
  Hovering a row lights its node in the tree (Markers.Highlight), so the
  route can be followed with the mouse. Rows are our own buttons; nothing
  here touches Blizzard's frames.
  Contract: Timeline.Create(overlay, dock) -> timeline   dock = the window
            timeline:Toggle() / :SetOpen(open) / :SetAvailable(on)
            timeline:Update(state) - state = { configID, routeName, steps, next }
    steps = Route.Plan(...).steps, next = the plan's next step (or nil).
]]
local _, ns = ...
local L = ns.L
local T, W = Sendit.Theme, Sendit.Widgets
local Tree, Markers = ns.Tree, ns.Markers

local Timeline = {}
ns.Timeline = Timeline

local WIDTH, HEADER, ROW = 300, 38, 26

local function Row(parent, i)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
    r:SetPoint("RIGHT")
    r.current = T.Fill(r, "selected", "BACKGROUND")
    r.current:SetAllPoints()
    T.Fill(r, "hover", "HIGHLIGHT"):SetAllPoints()
    r.level = T.Text(r, "small", "textMuted")
    r.level:SetPoint("LEFT", 10, 0)
    r.level:SetWidth(24)
    r.level:SetJustifyH("RIGHT")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 42, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.rank = T.Text(r, "small", "textDim")
    r.rank:SetPoint("RIGHT", -12, 0)
    r.name = T.Text(r, "label", "text")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.name:SetPoint("RIGHT", r.rank, "LEFT", -8, 0)
    r:SetScript("OnEnter", function(self) Markers.Highlight(self.node) end)
    r:SetScript("OnLeave", function() Markers.Highlight(nil) end)
    return r
end

function Timeline.Create(overlay, dock)
    local t = CreateFrame("Frame", nil, overlay)
    t:SetWidth(WIDTH)
    t:SetPoint("TOPLEFT", dock, "TOPRIGHT", 2, 0)
    t:SetPoint("BOTTOMLEFT", dock, "BOTTOMRIGHT", 2, 0)
    t:EnableMouse(true)
    T.Fill(t, "bg", "BACKGROUND"):SetAllPoints()
    T.Border(t, "border")
    t.title = T.Text(t, "heading", "text")
    t.title:SetPoint("TOPLEFT", 14, -12)
    t.title:SetPoint("RIGHT", -14, 0)
    local divider = T.Fill(t, "divider", "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 0, -HEADER)
    divider:SetPoint("TOPRIGHT", 0, -HEADER)
    t.scroll = W.ScrollArea(t)
    t.scroll:SetPoint("TOPLEFT", 0, -HEADER - 4)
    t.scroll:SetPoint("BOTTOMRIGHT", 0, 6)
    t.rows = {}
    t:Hide()

    -- The tab (UI/Tab.lua): on the window's edge when folded, on the list's edge when open.
    t.tab = ns.Tab.Create(overlay, function() t:Toggle() end)
    local state, available

    function t:Update(s)
        state = s
        if not self:IsShown() then return end
        local steps = s.steps or {}
        self.nextIndex = nil
        self.title:SetText(L.route .. (s.routeName and (" · " .. s.routeName) or ""))
        local talents = {}
        for i, step in ipairs(steps) do
            local r = self.rows[i] or Row(self.scroll.content, i)
            self.rows[i] = r
            local info = talents[step.node]
            if not info then
                local name, max, icon = Tree.Talent(s.configID, step.node)
                info = { name = name or "?", max = max or step.rank, icon = icon }
                talents[step.node] = info
            end
            local isNext = step == s.next
            if isNext then self.nextIndex = i end
            r.node = step.node
            r.level:SetText(step.dropped and "-" or step.level)
            r.icon:SetTexture(info.icon or 134400)  -- question mark icon
            r.icon:SetDesaturated(step.done or step.dropped)
            r:SetAlpha(step.dropped and 0.4 or 1)
            r.name:SetText(info.name)
            r.rank:SetText(step.dropped and L.dropped or (step.rank .. "/" .. info.max))
            T.Paint(r.name, isNext and "accent" or (step.done or step.dropped) and "textMuted" or "text")
            r.current:SetShown(isNext)
            r:Show()
        end
        for i = #steps + 1, #self.rows do self.rows[i]:Hide() end
        self.scroll.content:SetHeight(#steps * ROW)
    end

    -- Scroll so the next point sits in the middle of the list.
    local function ScrollToNext()
        local steps = state and state.steps or {}
        local index = t.nextIndex or #steps
        local height = t.scroll:GetHeight() or 0
        local max = math.max(0, #steps * ROW - height)
        t.scroll:SetVerticalScroll(math.min(max, math.max(0, index * ROW - height / 2)))
    end

    local function Place()
        local open = t:IsShown()
        t.tab:ClearAllPoints()
        t.tab:SetPoint("TOPLEFT", open and t or dock, "TOPRIGHT", open and 0 or 2, -60)
        t.tab:SetOpen(open)
    end

    function t:SetOpen(open)
        ns.module.db.timeline = open and true or false
        self:SetShown(open and available)
        Place()
        if self:IsShown() and state then
            self:Update(state)
            ScrollToNext()
        end
    end

    function t:Toggle() self:SetOpen(not self:IsShown()) end

    -- A route to show: the tab appears and the list keeps its saved state.
    function t:SetAvailable(on)
        if on == available then return end
        available = on
        self.tab:SetShown(on)
        self:SetOpen(ns.module.db.timeline)
    end

    t:SetScript("OnHide", function() Markers.Highlight(nil) end)
    return t
end
