--[[
  Picker: the route choice and the next-point line at the bottom left of
  Blizzard's talent window (our own frames on our overlay), plus the route
  timeline (UI/Timeline.lua) docked to the window's right. The next-point
  line is plain text that ends before Blizzard's centred "Apply changes"
  button (about 200 px wide); a long talent name is cut with "...". With
  several free points it lists them in buying order ("3 points free: ...").
  Route names come from the client: the route's main tree as the talent
  window names it ("Retribution"); the two feral druid routes add their form.
  Contract: Picker.Create(overlay, dock, get, set) -> picker   dock = the window
            picker:Update(state) - state = { class, configID, route, plan, rankOf, reached, ready }
    reached = the level allows the next point, ready = and a point is free.
    get() -> current key | "off"; set(key) stores the choice and redraws.
]]
local _, ns = ...
local L = ns.L
local T, W = Sendit.Theme, Sendit.Widgets
local Route, Tree, Timeline = ns.Route, ns.Tree, ns.Timeline

local Picker = {}
ns.Picker = Picker

local APPLY_HALF = 112  -- half of Blizzard's "Apply changes" button + a gap
local BAR_Y = 16  -- the dropdown's centre above the window bottom: level with "Apply changes"

local function RouteName(route, names)
    local name = names[route.tree] or ("#" .. route.tree)
    local form = route.form and C_Spell and ns.Call(C_Spell.GetSpellName, route.form)
    return form and (name .. " · " .. form) or name
end

function Picker.Create(overlay, dock, get, set)
    local p = CreateFrame("Frame", nil, overlay)
    p:SetSize(260, 44)
    p:SetPoint("BOTTOMLEFT", 18, BAR_Y - 14)
    p.label = T.Text(p, "small", "textDim")
    p.label:SetPoint("TOPLEFT", 0, 0)
    p.label:SetText(L.route)
    local state = {}
    p.dropdown = W.Dropdown(p, 260, function()
        local names = Tree.Names(state.configID)
        local options = {}
        for _, route in ipairs(Route.ForClass(state.class)) do
            options[#options + 1] = { route.key, RouteName(route, names) }
        end
        options[#options + 1] = { "off", L.off }
        return options
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
        self.timeline:Update({ configID = s.configID, routeName = RouteName(s.route, Tree.Names(s.configID)),
            steps = s.plan.steps, next = step })
    end
    return p
end
