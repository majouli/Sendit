--[[
  Timeline: the chain as a vertical graph - one row per quest in prerequisite order, nodes in lanes
  (a quest continues its first prerequisite's lane when free, else the lowest free one; lines never
  cross a node; "one of" drawn fainter), the step cards right of the lanes.
  Timeline.Lanes(rows) -> { [id] = lane }, lanes;  Timeline.Create(parent)
  Timeline.Render(tl, rows, width, open, root, onClick) -> height, positions
]]
local _, ns = ...
local T, S, DB = Sendit.Theme, ns.Style, ns.Database
local Timeline = {}
ns.Timeline = Timeline
local NODE_Y = 15  -- node centre on the title line

function Timeline.Lanes(rows)
    local index, laneOf, busy, claimed, lanes = {}, {}, {}, {}, 0
    for i, row in ipairs(rows) do index[row.id] = i end
    for i, row in ipairs(rows) do
        local preds = {}
        for _, p in ipairs(DB.Links(row.id, "before")) do
            if index[p] and index[p] < i then preds[#preds + 1] = p end
        end
        table.sort(preds, function(a, b) return index[a] < index[b] end)
        local first = preds[1] and index[preds[1]] or i
        local function Free(l) return busy[l] == nil or busy[l] < first or (busy[l] == first and preds[1] and laneOf[preds[1]] == l) end
        local lane
        for _, p in ipairs(preds) do
            local l = laneOf[p]
            if not claimed[p] and busy[l] == index[p] and Free(l) then
                lane, claimed[p] = l, true
                break
            end
        end
        if not lane then
            lane = 0
            while not Free(lane) do lane = lane + 1 end
        end
        laneOf[row.id], busy[lane] = lane, i
        lanes = math.max(lanes, lane + 1)
    end
    return laneOf, lanes
end

function Timeline.Create(parent)
    local tl = CreateFrame("Frame", nil, parent)
    tl.steps, tl.nodes, tl.lines = {}, {}, {}
    return tl
end

local function Line(tl, used)
    local line = tl.lines[used]
    if not line then
        line = tl:CreateLine(nil, "BACKGROUND")
        line:SetTexture(T.WHITE)
        line:SetThickness(2)
        tl.lines[used] = line
    end
    return line
end

function Timeline.Render(tl, rows, width, open, root, onClick)
    local laneOf, lanes = Timeline.Lanes(rows)
    local laneW = lanes > 1 and math.max(10, math.min(S.size.lane, math.floor(width * 0.25 / lanes))) or S.size.lane
    local graph = 8 + lanes * laneW
    local cardX, y, positions, nodeAt = graph + 6, 0, {}, {}
    for i, row in ipairs(rows) do
        local id = row.id
        local state = S.Show(id, DB.Prerequisites(id))
        local step = tl.steps[i] or ns.TimelineStep.Create(tl, onClick)
        tl.steps[i] = step
        step:ClearAllPoints()
        step:SetPoint("TOPLEFT", cardX, -y)
        local h = ns.TimelineStep.Paint(step, id, width - cardX, open == id, root == id, state)
        local node = tl.nodes[i] or ns.Icons.Node(tl, S.surface.window)
        tl.nodes[i] = node
        local x = 8 + laneOf[id] * laneW + laneW / 2
        node:ClearAllPoints()
        node:SetPoint("CENTER", tl, "TOPLEFT", x, -(y + NODE_Y))
        node:Set(state, root == id)
        node:Show()
        positions[id], nodeAt[id] = y, { x = x, y = y + NODE_Y, state = state }
        y = y + h + S.space.line
    end
    for i = #rows + 1, #tl.steps do tl.steps[i]:Hide() end
    for i = #rows + 1, #tl.nodes do tl.nodes[i]:Hide() end
    local used = 0
    local half = S.size.node / 2 + 2
    for _, row in ipairs(rows) do
        local to = nodeAt[row.id]
        local prev = DB.Prerequisites(row.id)
        local oneOf = {}
        for _, p in ipairs(prev.any) do oneOf[p] = true end
        for _, p in ipairs(DB.Links(row.id, "before")) do
            local from = nodeAt[p]
            if from and from.y < to.y then
                local role = from.state == "done" and "success" or S.surface.hairline
                local alpha = oneOf[p] and 0.55 or 1
                local bend = from.y + half + 6
                local segments = from.x == to.x and { { from.x, from.y + half, to.x, to.y - half } }
                    or { { from.x, from.y + half, to.x, bend }, { to.x, bend, to.x, to.y - half } }
                for _, s in ipairs(segments) do
                    used = used + 1
                    local line = Line(tl, used)
                    line:SetStartPoint("TOPLEFT", tl, s[1], -s[2])
                    line:SetEndPoint("TOPLEFT", tl, s[3], -s[4])
                    T.Paint(line, role == "success" and "success" or "textMuted", (role == "success" and 0.8 or 0.45) * alpha)
                    line:Show()
                end
            end
        end
    end
    for i = used + 1, #tl.lines do tl.lines[i]:Hide() end
    tl:SetSize(width, math.max(1, y))
    tl:Show()
    return y, positions
end
