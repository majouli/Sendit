--[[
  Icons: drawn status nodes and the resize grip. Geometry from client
  primitives (masked circles, lines) - no font glyphs (boxes in some fonts),
  no textures the client might not ship.

  Icons.Node(parent, ground) -> node (Style.size.node square)
    node:Set(state, root)   state = Style display state; root = gold outer
                            ring (the quest picked in the list)
    ground = colour role behind the node (hollow rings are cut out with it)
  Icons.Resize(grip) -> paint(hover)
]]
local _, ns = ...
local T = Sendit.Theme
local Icons = {}
ns.Icons = Icons

local function Line(parent, layer)
    local line = parent:CreateLine(nil, layer or "OVERLAY")
    line:SetTexture(T.WHITE)
    line:SetThickness(1.5)
    return line
end

local function Place(line, parent, x1, y1, x2, y2)
    line:SetStartPoint("TOPLEFT", parent, x1, -y1)
    line:SetEndPoint("TOPLEFT", parent, x2, -y2)
end

-- Glyph strokes on a 16 x 16 node: { x1, y1, x2, y2 }.
local GLYPHS = {
    done = { { 4.5, 8.5, 7, 11 }, { 7, 11, 11.5, 5.5 } },
    active = { { 8, 4, 8, 9 }, { 8, 11, 8, 12.5 } },
    unknown = { { 5, 8, 11, 8 } },
    locked = { { 5.5, 7.5, 5.5, 5.5 }, { 10.5, 7.5, 10.5, 5.5 }, { 5.5, 5, 10.5, 5 } },
}
local FILLED = { done = true, active = true }

function Icons.Node(parent, ground)
    local size = ns.Style.size.node
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.root = T.Circle(f, "accent", size + 6, "BACKGROUND", 1)
    f.root:SetPoint("CENTER")
    f.rootCut = T.Circle(f, ground or "bg", size + 3, "BACKGROUND", 2)
    f.rootCut:SetPoint("CENTER")
    f.disc = T.Circle(f, "textDim", size, "ARTWORK", 0)
    f.disc:SetPoint("CENTER")
    f.hole = T.Circle(f, ground or "bg", size - 3, "ARTWORK", 1)
    f.hole:SetPoint("CENTER")
    f.lockBody = T.Fill(f, "textMuted", "OVERLAY")
    f.lockBody:SetSize(7, 5)
    f.lockBody:SetPoint("TOPLEFT", 4.5, -7.5)
    f.lines = {}
    function f:Set(state, root)
        local role = ns.Style.Role(state)
        local filled = FILLED[state]
        T.Paint(self.disc, role)
        self.hole:SetShown(not filled)
        self.root:SetShown(root == true)
        self.rootCut:SetShown(root == true)
        self.lockBody:SetShown(state == "locked")
        local glyph = GLYPHS[state] or {}
        for i, p in ipairs(glyph) do
            local line = self.lines[i] or Line(self)
            self.lines[i] = line
            Place(line, self, p[1], p[2], p[3], p[4])
            T.Paint(line, filled and "onAccent" or role)
            line:Show()
        end
        for i = #glyph + 1, #self.lines do self.lines[i]:Hide() end
        self.state = state
    end
    return f
end

function Icons.Resize(parent)
    local lines = {}
    for _, length in ipairs({ 1, 5, 9 }) do
        local line = Line(parent)
        line:SetThickness(1)
        line:SetStartPoint("BOTTOMRIGHT", parent, -1 - length, 1)
        line:SetEndPoint("BOTTOMRIGHT", parent, -1, 1 + length)
        lines[#lines + 1] = line
    end
    local function Paint(hover)
        for _, line in ipairs(lines) do T.Paint(line, hover and "accent" or "textDim", hover and 1 or 0.6) end
    end
    Paint(false)
    return Paint
end
