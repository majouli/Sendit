local _, ns = ...

local Gathering = {}
ns.Gathering = Gathering

local PROFS = {
    { key = "mining", nodes = ns.MineNodes, byName = ns.MineByName },
    { key = "herbalism", nodes = ns.HerbNodes, byName = ns.HerbByName },
}

local Plain = ns.Plain

function Gathering.ObjectID(guid)
    if not Plain(guid) then return nil end
    return tonumber(guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
end

local function Result(prof, node)
    return ns.Loot.Expand(node, 4), {
        prof = prof, skill = math.max(1, node[1]), minUses = node[2], maxUses = node[3],
    }
end

function Gathering.Find(objectID, title)
    for _, p in ipairs(PROFS) do
        local node = objectID and p.nodes[objectID]
        if node then return Result(p.key, node) end
    end
    if not Plain(title) then return nil end
    for _, p in ipairs(PROFS) do
        local id = p.byName[title]
        if id then return Result(p.key, p.nodes[id]) end
    end
end
