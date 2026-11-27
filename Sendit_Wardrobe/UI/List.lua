--[[
  List: a long scrolling list that only builds the rows in view (thousands of looks), rows of
  different heights, a slim scroll bar on the right.
  List.Create(parent, kinds) -> list   kinds[type] = { height, create(parent) -> row, paint(row, entry) }
  list:SetEntries(entries, keepScroll) / list:Repaint() / list:ScrollToTop()
]]
local _, ns = ...
local T = Sendit.Theme
local List = {}
ns.List = List
local WHEEL, BAR = 72, 4

function List.Create(parent, kinds)
    local list = CreateFrame("Frame", nil, parent)
    list:SetClipsChildren(true)
    list.entries, list.tops, list.total, list.offset = {}, {}, 0, 0
    local pools, used = {}, {}
    local bar = CreateFrame("Slider", nil, list)
    bar:SetOrientation("VERTICAL")
    bar:SetPoint("TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar:SetWidth(BAR + 6)
    bar:SetMinMaxValues(0, 0)
    local track = T.Fill(bar, "track", "BACKGROUND")
    track:SetWidth(BAR)
    track:SetPoint("TOP")
    track:SetPoint("BOTTOM")
    local thumb = T.Fill(bar, "textMuted", "OVERLAY", 0, 0.6)
    thumb:SetSize(BAR, 40)
    bar:SetThumbTexture(thumb)
    list.bar = bar

    local function Max() return math.max(0, list.total - list:GetHeight()) end

    function list:Repaint()
        for _, row in pairs(used) do row:Hide() end
        wipe(used)
        local free = {}
        for kind in pairs(pools) do free[kind] = 1 end
        local top, bottom = self.offset, self.offset + self:GetHeight()
        local width = self:GetWidth() - (Max() > 0 and BAR + 8 or 0)
        for i, e in ipairs(self.entries) do
            local y = self.tops[i]
            local kind = kinds[e.type]
            if y + kind.height >= top and y <= bottom then
                pools[e.type] = pools[e.type] or {}
                local pool, n = pools[e.type], free[e.type] or 1
                local row = pool[n] or kind.create(self)
                pool[n], free[e.type] = row, n + 1
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -(y - top))
                row:SetSize(width, kind.height)
                kind.paint(row, e)
                row:Show()
                used[#used + 1] = row
            elseif y > bottom then
                break
            end
        end
        local max = Max()
        bar:SetShown(max > 0)
        bar:SetMinMaxValues(0, max)
        thumb:SetHeight(math.max(24, self:GetHeight() * self:GetHeight() / math.max(1, self.total)))
        if math.abs(bar:GetValue() - self.offset) > 0.5 then bar:SetValue(self.offset) end
    end

    function list:SetEntries(entries, keep)
        self.entries, self.tops, self.total = entries, {}, 0
        for i, e in ipairs(entries) do
            self.tops[i] = self.total
            self.total = self.total + kinds[e.type].height
        end
        self.offset = keep and math.min(self.offset, Max()) or 0
        self:Repaint()
    end

    function list:ScrollToTop()
        self.offset = 0
        self:Repaint()
    end

    local function ScrollTo(v)
        v = math.max(0, math.min(Max(), v))
        if math.abs(v - list.offset) < 0.5 then return end
        list.offset = v
        list:Repaint()
    end
    bar:SetScript("OnValueChanged", function(_, v) ScrollTo(v) end)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) ScrollTo(list.offset - delta * WHEEL) end)
    list:SetScript("OnSizeChanged", function() list:Repaint() end)
    return list
end
