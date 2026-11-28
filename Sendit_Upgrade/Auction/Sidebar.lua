--[[
  Sidebar: every filter of the upgrade scan in one narrow column - slots (with all / none), armor and
  weapon types the character can use, qualities, required level range, highest price in gold, least
  gain in %. Each change calls onChange at once (filters only change what is shown, Auction/Rank.lua).
  Empty fields: from 1 / up to the own level / any price / any upgrade.
  Sidebar.Create(parent, onChange) -> bar;  bar:Layout(width) -> height;  bar:Refresh() -> true when a
  section changed its toggles (lay out again)
]]
local _, ns = ...
local AL = ns.AL
local T, W, Slots = Sendit.Theme, Sendit.Widgets, Sendit.GearSlots
local Filter, Wearable, Chips = ns.AuctionFilter, ns.AuctionWearable, ns.AuctionChips
local Sidebar = {}
ns.AuctionSidebar = Sidebar

local CAPTION, CHECK_ROW, FIELD_H, SECTION_GAP, ROW_GAP = 22, 22, 24, 18, 8

local function Accent() return T.Color("accent") end

local function QualityColor(q)
    return function()
        local ok, r, g, b = pcall(C_Item.GetItemQualityColor, q)
        if ok and type(r) == "number" then return r, g, b end
        return 1, 1, 1
    end
end

local function Typed(list)
    local out = {}
    for i, t in ipairs(list) do out[i] = { key = t.key, name = t.name, color = Accent } end
    return out
end

-- a number field bound to a setting; empty stores nil; decimal: "0,5" and "0.5" both read
local function Field(bar, key, width, letters, hint, decimal)
    local e = W.Search(bar, "", function() end)
    e:SetSize(width, FIELD_H)
    e:SetNumeric(not decimal)
    e:SetMaxLetters(letters)
    e:SetJustifyH("CENTER")
    e:SetTextInsets(4, 4, 0, 0)
    e.hint:ClearAllPoints()
    e.hint:SetPoint("CENTER")
    e:HookScript("OnTextChanged", function(self, user)
        if not user then return end
        Filter.Settings()[key] = tonumber((self:GetText():gsub(",", ".")))
        bar.onChange()
    end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    function e:Sync()
        e.hint:SetText(hint())
        if self:HasFocus() then return end
        local v = Filter.Settings()[key]
        self:SetText(v and (tostring(v):gsub("%.", ns.L.decimal)) or "")
    end
    return e
end

local function Link(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b.text = T.Text(b, "small", "textDim")
    b.text:SetPoint("CENTER")
    b:SetHeight(18)
    b:SetScript("OnEnter", function(self) T.Paint(self.text, "accent") end)
    b:SetScript("OnLeave", function(self) T.Paint(self.text, "textDim") end)
    b:SetScript("OnClick", onClick)
    function b:SetLabel(t)
        self.text:SetText(t)
        self:SetWidth(self.text:GetStringWidth() + 8)
    end
    b:SetLabel(text)
    return b
end

local function SlotSection(bar)
    local s = { caption = T.Text(bar, "caption", "accent"), checks = {} }
    local function All(on)
        for _, g in ipairs(Slots.GROUPS) do Slots.Set(Filter.Settings(), g.key, on) end
        bar:Refresh()
        bar.onChange()
    end
    s.none = Link(bar, AL.slotsNone, function() All(false) end)
    s.all = Link(bar, AL.slotsAll, function() All(true) end)
    for i, g in ipairs(Slots.GROUPS) do
        local check = W.Check(bar, function(self, on)
            Slots.Set(Filter.Settings(), g.key, on)
            self:Set(on)
            bar.onChange()
        end)
        check.group = g
        check.label = T.Text(bar, "small", "textDim")
        check.label:SetPoint("LEFT", check, "RIGHT", 6, 0)
        check.label:SetWordWrap(false)
        s.checks[i] = check
    end
    return s
end

local function NumberRow(bar, label, fields, unit)
    local row = { label = T.Text(bar, "label", "textDim"), fields = fields }
    row.label:SetText(label)
    if unit then
        row.unit = T.Text(bar, "label", "textDim")
        row.unit:SetText(unit)
    end
    return row
end

function Sidebar.Create(parent, onChange)
    local bar = CreateFrame("Frame", nil, parent)
    bar.onChange = onChange
    bar.slots = SlotSection(bar)
    local function TypeSection(title, which)
        return Chips.Create(bar, {
            title = function() return AL[title] end,
            items = function() return Typed(Wearable.Types()[which]) end,
            on = Filter.TypeOn,
            toggle = function(key)
                Filter.SetType(key, not Filter.TypeOn(key))
                onChange()
            end,
        })
    end
    bar.armor = TypeSection("armor", "armor")
    bar.weapons = TypeSection("weapons", "weapons")
    bar.quality = Chips.Create(bar, {
        title = function() return AL.quality end,
        items = function()
            local out = {}
            for i, q in ipairs(Filter.QUALITIES) do
                out[i] = { key = q, name = Sendit.Locale.Global("ITEM_QUALITY" .. q .. "_DESC") or tostring(q), color = QualityColor(q) }
            end
            return out
        end,
        on = Filter.Quality,
        toggle = function(q)
            Filter.SetQuality(q, not Filter.Quality(q))
            onChange()
        end,
    })
    bar.from = Field(bar, "minLevel", 40, 2, function() return "1" end)
    bar.to = Field(bar, "maxLevel", 40, 2, function() return tostring(Filter.Level()) end)
    bar.dash = T.Text(bar, "label", "textDim")
    bar.dash:SetText("–")
    bar.gold = Field(bar, "maxGold", 70, 6, function() return AL.any end)
    bar.gain = Field(bar, "minGain", 56, 4, function() return AL.any end, true)
    bar.rows = {
        NumberRow(bar, AL.level, { bar.from, bar.dash, bar.to }),
        NumberRow(bar, AL.price, { bar.gold }, "g"),
        NumberRow(bar, AL.gain, { bar.gain }, "%"),
    }
    bar.limits = T.Text(bar, "caption", "accent")

    function bar:Layout(width)
        self:SetWidth(width)
        local s, y = self.slots, 0
        s.caption:ClearAllPoints()
        s.caption:SetPoint("TOPLEFT", 0, -y)
        s.none:ClearAllPoints()
        s.none:SetPoint("TOPRIGHT", 0, -(y - 3))
        s.all:ClearAllPoints()
        s.all:SetPoint("RIGHT", s.none, "LEFT", -4, 0)
        y = y + CAPTION
        local colW = width / 2
        for i, check in ipairs(s.checks) do
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            check:ClearAllPoints()
            check:SetPoint("TOPLEFT", col * colW, -(y + row * CHECK_ROW))
            check.label:SetWidth(colW - 26)
        end
        y = y + math.ceil(#s.checks / 2) * CHECK_ROW
        for _, section in ipairs({ self.armor, self.weapons, self.quality }) do
            local h = section:Layout(width)
            if h > 0 then
                y = y + SECTION_GAP
                section:ClearAllPoints()
                section:SetPoint("TOPLEFT", 0, -y)
                y = y + h
            end
        end
        y = y + SECTION_GAP
        self.limits:ClearAllPoints()
        self.limits:SetPoint("TOPLEFT", 0, -y)
        y = y + CAPTION
        for i, row in ipairs(self.rows) do
            if i > 1 then y = y + ROW_GAP end
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", self, "TOPLEFT", 0, -(y + FIELD_H / 2))
            local x = width
            if row.unit then
                row.unit:ClearAllPoints()
                row.unit:SetPoint("RIGHT", self, "TOPLEFT", x, -(y + FIELD_H / 2))
                x = x - row.unit:GetStringWidth() - 6
            end
            for k = #row.fields, 1, -1 do
                local f = row.fields[k]
                f:ClearAllPoints()
                f:SetPoint("RIGHT", self, "TOPLEFT", x, -(y + FIELD_H / 2))
                local w = f:GetObjectType() == "FontString" and f:GetStringWidth() or f:GetWidth()
                x = x - w - 6
            end
            row.label:SetWidth(math.max(20, x))
            y = y + FIELD_H
        end
        self:SetHeight(y + 4)
        return y + 4
    end

    function bar:Refresh()
        local s = self.slots
        s.caption:SetText(AL.slots:upper())
        s.all:SetLabel(AL.slotsAll)
        s.none:SetLabel(AL.slotsNone)
        local db = Filter.Settings()
        for _, check in ipairs(s.checks) do
            check.label:SetText(Slots.Label(check.group, AL))
            check:Set(Slots.On(db, check.group.key))
        end
        local changed = false
        for _, section in ipairs({ self.armor, self.weapons, self.quality }) do
            if section:Refresh() then changed = true end
        end
        self.limits:SetText(AL.limits:upper())
        self.rows[1].label:SetText(AL.level)
        self.rows[2].label:SetText(AL.price)
        self.rows[3].label:SetText(AL.gain)
        for _, f in ipairs({ self.from, self.to, self.gold, self.gain }) do f:Sync() end
        return changed
    end

    bar:Refresh()
    return bar
end
