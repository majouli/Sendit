--[[
  Picker: route choice and next-point line at the talent window's bottom left (ends before
  Blizzard's "Apply changes"), plus the docked timeline. Build panel: one column per tree (form),
  leveling first, then dungeons & raids, then PvP; names, uses and tooltips from RouteText.
  Picker.Create(overlay, dock, get, set) -> picker;  picker:Update(state)
  state = { class, configID, route, plan, rankOf, reached, ready }
]]
local _, ns = ...
local L = ns.L
local T = Sendit.Theme
local Route, Tree, Timeline, RouteText, RouteMenu = ns.Route, ns.Tree, ns.Timeline, ns.RouteText, ns.RouteMenu

local Picker = {}
ns.Picker = Picker

local APPLY_HALF = 112  -- half of Blizzard's "Apply changes" button + a gap
local BAR_Y = 16  -- level with "Apply changes"

local USES = { level = 1, group = 2, pvp = 3 }

-- talent(nodeID, rank) -> client name, what it does at that rank
local function Namer(configID)
    return function(node, rank)
        return (Tree.Talent(configID, node)), rank and Tree.Effect(configID, node, rank)
    end
end

-- one column per tree (and druid form), purposes in play order, the guide's plain build first
local function Columns(routes, names, talentName)
    local list, text = {}, {}
    for _, route in ipairs(routes) do
        list[#list + 1] = route
        text[route] = RouteText.Name(route, names)
    end
    table.sort(list, function(a, b)
        if a.tree ~= b.tree then return a.tree < b.tree end
        if (a.form or 0) ~= (b.form or 0) then return (a.form or 0) < (b.form or 0) end
        if a.use ~= b.use then return USES[a.use] < USES[b.use] end
        if (a.variant == nil) ~= (b.variant == nil) then return a.variant == nil end
        return text[a] < text[b]
    end)
    local columns, column = { off = { "off", L.off } }, nil
    for _, route in ipairs(list) do
        local section = RouteText.Section(route, names)
        if not column or column[1] ~= section then
            column = { section }
            columns[#columns + 1] = column
        end
        column[#column + 1] = { route.key, text[route], use = RouteText.Use(route), points = RouteText.Points(route),
            main = route.tree, label = section .. " · " .. text[route], tip = RouteText.Tip(route, names, talentName) }
    end
    return columns
end
Picker._Columns = Columns

function Picker.Create(overlay, dock, get, set)
    local p = CreateFrame("Frame", nil, overlay)
    p:SetSize(260, 44)
    p:SetPoint("BOTTOMLEFT", 18, BAR_Y - 14)
    p.label = T.Text(p, "small", "textDim")
    p.label:SetPoint("TOPLEFT", 0, 0)
    p.label:SetText(L.route)
    local state = {}
    p.dropdown = RouteMenu.Create(p, 260, function()
        return Columns(Route.ForClass(state.class), Tree.Names(state.configID), Namer(state.configID))
    end, get, set)
    p.dropdown:SetPoint("TOPLEFT", p.label, "BOTTOMLEFT", 0, -3)
    p.status = T.Text(p, "label", "text")
    p.status:SetPoint("LEFT", p.dropdown, "RIGHT", 16, 0)
    p.status:SetPoint("RIGHT", overlay, "BOTTOM", -APPLY_HALF, BAR_Y)
    p.timeline = Timeline.Create(overlay, dock)

    function p:Update(s)
        state = s
        self.dropdown:Refresh()
        local step = s.plan and s.plan.next
        self.timeline:SetAvailable(s.route ~= nil)
        if not s.route then
            self.status:SetText("")
            return
        end
        if not step then
            self.status:SetText(L.done)
            T.Paint(self.status, "success")
        else
            local name, max = Tree.Talent(s.configID, step.node)
            name, max = name or "?", max or s.plan.target[step.node]
            local picks = s.plan.picks
            if s.ready and #picks > 1 then
                local list = {}
                for i, p in ipairs(picks) do list[i] = (Tree.Talent(s.configID, p.node) or "?") .. " " .. p.rank end
                self.status:SetText(L.free:format(#picks, table.concat(list, ", ")))
            else
                self.status:SetText(s.reached and L.next:format(name, step.rank, max)
                    or L.nextAt:format(step.level, name, step.rank, max))
            end
            T.Paint(self.status, s.ready and "accent" or "textDim")
        end
        self.timeline:Update({ configID = s.configID, routeName = RouteText.Title(s.route, Tree.Names(s.configID)),
            steps = s.plan.steps, next = step })
    end
    return p
end
