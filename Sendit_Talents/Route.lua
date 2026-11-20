--[[
  Route: pure logic over Data/Routes.lua. A route lists trait node IDs, one per talent point in
  buying order ([1] = level 10); the n-th appearance of a node is its rank n.
  Plan: done = route points taken; queue = open points in route order, skipped ones moved to the
  end; every point spent off the route takes one off the queue's end; picks = the next queue points
  Blizzard lets the player buy now. Queue points are re-timed: the first at level 10 + points spent.
  Route.ForClass(class) -> { route, ... }
  Route.Find(class, key) -> route | nil
  Route.Plan(route, rankOf, opts) -> { target, levels, steps, picks, next }
    rankOf(nodeID) -> current rank; opts: nodes, open(nodeID), free
  Route.Suggest(class, rankOf) -> the route holding most spent points (solo pick wins a tie)
]]
local _, ns = ...

local Route = {}
ns.Route = Route

local FIRST_LEVEL = 10
local NONE = {}

function Route.ForClass(class)
    return ns.Routes[class] or NONE
end

function Route.Find(class, key)
    for _, route in ipairs(Route.ForClass(class)) do
        if route.key == key then return route end
    end
end

local function Counts(route)
    local counts = {}
    for _, node in ipairs(route) do counts[node] = (counts[node] or 0) + 1 end
    return counts
end

local function OffRoute(counts, rankOf, nodes)
    local off = 0
    for _, node in ipairs(nodes or NONE) do
        off = off + math.max(0, (rankOf(node) or 0) - (counts[node] or 0))
    end
    return off
end

function Route.Plan(route, rankOf, opts)
    opts = opts or NONE
    local counts, seen = Counts(route), {}
    local done, open, last = {}, {}, 0
    for i, node in ipairs(route) do
        seen[node] = (seen[node] or 0) + 1
        if (rankOf(node) or 0) >= seen[node] then
            done[#done + 1] = { node = node, rank = seen[node], level = FIRST_LEVEL + i - 1, done = true }
            last = i
        else
            open[#open + 1] = { node = node, index = i }
        end
    end
    local queue = {}
    for _, s in ipairs(open) do if s.index > last then queue[#queue + 1] = s end end
    for _, s in ipairs(open) do if s.index < last then queue[#queue + 1] = s end end
    local off = OffRoute(counts, rankOf, opts.nodes)
    local keep, spent = #queue - math.min(#queue, off), #done + off

    local steps, target, levels, sim = {}, {}, {}, {}
    local function Span(node, level)
        levels[node] = levels[node] or { level }
        levels[node][2] = math.max(levels[node][2] or level, level)
        levels[node][1] = math.min(levels[node][1], level)
    end
    for _, s in ipairs(done) do
        steps[#steps + 1] = s
        target[s.node] = math.max(target[s.node] or 0, s.rank)
        Span(s.node, s.level)
    end
    local kept = {}
    for k, s in ipairs(queue) do
        local node = s.node
        local step = { node = node, dropped = k > keep }
        if not step.dropped then
            sim[node] = (sim[node] or rankOf(node) or 0) + 1
            step.rank, step.level = sim[node], FIRST_LEVEL + spent + k - 1
            target[node] = step.rank
            Span(node, step.level)
            kept[#kept + 1] = step
        end
        steps[#steps + 1] = step
    end
    for _, step in ipairs(steps) do
        if step.dropped then
            sim[step.node] = (sim[step.node] or rankOf(step.node) or 0) + 1
            step.rank = sim[step.node]
        end
    end

    local picks, want, taken = {}, math.max(1, opts.free or 1), {}
    for _, step in ipairs(kept) do
        if #picks >= want then break end
        local node = step.node
        if taken[node] == nil then taken[node] = not opts.open or opts.open(node) ~= false end
        if taken[node] then picks[#picks + 1] = step end
    end
    if #picks == 0 and kept[1] then picks[1] = kept[1] end
    return { target = target, levels = levels, steps = steps, picks = picks, next = picks[1] }
end

function Route.Suggest(class, rankOf)
    local best, bestScore, solo
    for _, route in ipairs(Route.ForClass(class)) do
        if route.solo then solo = solo or route end
        local score = 0
        for node, rank in pairs(Counts(route)) do
            score = score + math.min(rankOf(node) or 0, rank)
        end
        if score > (bestScore or 0) or (score == bestScore and route.solo) then best, bestScore = route, score end
    end
    return best or solo or Route.ForClass(class)[1]
end
