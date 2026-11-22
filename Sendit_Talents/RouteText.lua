--[[
  RouteText: what a route is called and how it explains itself, from the route data alone
  (purpose, role, the guide's variant, points per tree, deepest talents, talents no sibling takes).
  treeNames = { [tree index] = client name }; talent(nodeID, rank) -> client name | nil, what it does | nil
  RouteText.Points(route) -> { n1, n2, n3 }
  RouteText.Section(route, treeNames) -> "Protection" (· form)
  RouteText.Name(route, treeNames) -> "Threat" | "Leveling · Solo" | "Hybrid with Holy" | "PvP"
  RouteText.Use(route) -> "Tank · Dungeons & raids" | "From level 10 to 60" | "Damage · PvP"
  RouteText.Title(route, treeNames) -> "Protection · Threat"
  RouteText.Tip(route, treeNames, talent) -> { { text, role }, ... } (role: Theme colour, {} = gap);
    what the build gains: its own talents (none: its deepest) with the client's effect text
]]
local _, ns = ...
local L = ns.L

local RouteText = {}
ns.RouteText = RouteText

function RouteText.Points(route)
    local points = {}
    for n in (route.points or ""):gmatch("%d+") do points[#points + 1] = tonumber(n) end
    return points
end

-- the tree after the main one: what a hybrid build mixes in
local function Second(route, treeNames)
    local best
    for i, n in ipairs(RouteText.Points(route)) do
        if i ~= route.tree and (not best or n > best[2]) then best = { i, n } end
    end
    return best and treeNames[best[1]] or "?"
end

local function Variant(route, treeNames)
    local v = route.variant
    if v == "hybrid" then return L.hybrid:format(Second(route, treeNames)) end
    return v and L["v_" .. v]
end

function RouteText.Section(route, treeNames)
    local name = treeNames[route.tree] or ("#" .. route.tree)
    local form = route.form and C_Spell and ns.Call(C_Spell.GetSpellName, route.form)
    return form and (name .. " · " .. form) or name
end

function RouteText.Name(route, treeNames)
    local v = Variant(route, treeNames)
    if route.use == "level" then return v and (L.leveling .. " · " .. v) or L.leveling end
    if route.use == "pvp" then return v and (L.pvp .. " · " .. v) or L.pvp end
    return v or L.v_standard
end

function RouteText.Use(route)
    if route.use == "level" then return L.use_level end
    return L["role_" .. route.role] .. " · " .. (route.use == "pvp" and L.pvp or L.group)
end

function RouteText.Title(route, treeNames)
    return RouteText.Section(route, treeNames) .. " · " .. RouteText.Name(route, treeNames)
end

function RouteText.Tip(route, treeNames, talent)
    local lines = { { RouteText.Title(route, treeNames), "accent" }, { RouteText.Use(route), "textDim" } }
    local v = route.variant
    if v == "hybrid" then
        lines[#lines + 1] = { L.t_hybrid:format(Second(route, treeNames)), "text" }
    elseif v then
        lines[#lines + 1] = { L["t_" .. v], "text" }
    elseif route.use == "level" then
        lines[#lines + 1] = { L.tip_level, "text" }
    end
    lines[#lines + 1] = {}
    local points = {}
    for i, n in ipairs(RouteText.Points(route)) do
        if n > 0 then points[#points + 1] = (treeNames[i] or ("#" .. i)) .. " " .. n end
    end
    if #points > 0 then lines[#lines + 1] = { L.tip_points .. ": " .. table.concat(points, " · "), "text" } end
    local nodes = route.own or route.core
    if nodes then
        lines[#lines + 1] = {}
        lines[#lines + 1] = { route.own and L.tip_own or L.tip_core, "textDim" }
        for _, node in ipairs(nodes) do
            local rank = 0
            for _, n in ipairs(route) do if n == node then rank = rank + 1 end end
            local name, effect = talent(node, rank)
            lines[#lines + 1] = { name or "?", "success" }
            if effect then lines[#lines + 1] = { effect, "text" } end
        end
    end
    lines[#lines + 1] = {}
    lines[#lines + 1] = { route.derived and L.tip_derived or L.tip_guide, "textDim" }
    return lines
end
