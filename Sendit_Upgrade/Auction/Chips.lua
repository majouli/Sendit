--[[
  Chips: one filter section of the upgrade scan's sidebar - a caption over toggles (Auction/Pill.lua)
  that wrap to the width. The toggles come from opts.items() and are rebuilt when that list changes
  (a new weapon skill); a section without toggles takes no room.
  Chips.Create(parent, opts) with opts = { title() -> text, items() -> { { key, name, color() } },
    on(key) -> bool, toggle(key) } -> section
  section:Layout(width) -> height;  section:Refresh() -> true when the toggles changed (lay out again)
]]
local _, ns = ...
local T = Sendit.Theme
local Pill = ns.AuctionPill
local Chips = {}
ns.AuctionChips = Chips

local GAP, CAPTION = 4, 22

local function Signature(items)
    local keys = {}
    for i, item in ipairs(items) do keys[i] = item.key .. "=" .. item.name end
    return table.concat(keys, ",")
end

function Chips.Create(parent, opts)
    local s = CreateFrame("Frame", nil, parent)
    s.pills = {}
    s.caption = T.Text(s, "caption", "accent")
    s.caption:SetPoint("TOPLEFT")

    local function Build(items)
        for _, p in ipairs(s.pills) do p:Hide() end
        for i, item in ipairs(items) do
            local p = s.pills[i]
            if not p then
                p = Pill.Create(s, "", function() return s.colors[i]() end, function(self)
                    opts.toggle(self.key)
                    s:Refresh()
                end)
                s.pills[i] = p
            end
            p.key = item.key
            p.text:SetText(item.name)
            p:Show()
        end
        s.colors = {}
        for i, item in ipairs(items) do s.colors[i] = item.color end
        s.count = #items
    end

    function s:Layout(width)
        self:SetWidth(width)
        if (self.count or 0) == 0 then
            self:SetHeight(1)
            self:Hide()
            return 0
        end
        self:Show()
        local x, y = 0, CAPTION
        for i = 1, self.count do
            local p = self.pills[i]
            local w = math.min(p:Natural(), width)
            if x > 0 and x + w > width then x, y = 0, y + Pill.HEIGHT + GAP end
            p:SetWidth(w)
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", x, -y)
            x = x + w + GAP
        end
        local height = y + Pill.HEIGHT
        self:SetHeight(height)
        return height
    end

    function s:Refresh()
        local items = opts.items()
        local signature = Signature(items)
        local changed = signature ~= self.signature
        if changed then
            self.signature = signature
            Build(items)
        end
        self.caption:SetText(opts.title():upper())
        for i = 1, self.count or 0 do self.pills[i]:Set(opts.on(self.pills[i].key)) end
        return changed
    end

    s:Refresh()
    return s
end
