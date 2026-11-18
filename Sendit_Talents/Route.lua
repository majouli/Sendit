--[[
  Route: the pure logic over Data/Routes.lua (no client calls, tested).
  A route is a list of trait node IDs, one per talent point in buying order:
  [1] is the point at level 10, [51] the one at level 60. The n-th time a
  node appears is its rank n.
  The route guides, the player decides. Plan reads the character's tree:
    done     route points the character has
    queue    the open route points in route order; points left out before
             the last done one (skipped) move to its end, so none is lost
    dropped  every point spent off the route (or above a route node's rank)
             takes one point off the end of the queue: 51 points in all
    picks    the next queue points Blizzard lets the player buy now, as many
             as points are free (at least one); a node that is locked (tier,
             prerequisite) is passed over. Later picks cannot see tiers the
             earlier ones would open; the next redraw does.
  Queue points are re-timed to the character: the first comes at level
  10 + points spent.
  Contract:
    Route.ForClass(class) -> { route, ... } (may be empty)
    Route.Find(class, key) -> route | nil
    Route.Plan(route, rankOf, opts) -> {
        target = { [nodeID] = rank at 60 (dropped points left out) },
        levels = { [nodeID] = { first, last } },
        steps  = { { node, rank, level, done, dropped }, ... } done points,
                 then the queue, then the dropped ones,
        picks  = { step, ... }, next = picks[1] | nil (route complete) }
      rankOf(nodeID) -> the node's current rank (staged points included)
      opts (optional): nodes = every node of the tree (to count points off the
        route), open(nodeID) -> false when Blizzard would refuse a point,
        free = free points.
    Route.Suggest(class, rankOf) -> route | nil: the route that already holds
      most of the spent points; the class's solo pick wins a tie (routes share
      their first talents) and stands when nothing is spent.
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

-- Points spent outside the route: on other nodes or above a route node's rank.
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
    -- queue: open points after the last done one, then the skipped ones
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
    -- dropped points: shown with the rank they would have had
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
