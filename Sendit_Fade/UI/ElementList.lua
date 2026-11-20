--[[
  ElementList: the Elements page - ElementTree as a virtual list: toolbar (search, show hidden, show on
  screen, rescan), counts and status filter, family / addon / element rows with switches; hovering an
  element outlines it on screen. page:Reveal(e) opens the path to an element.
]]
local _, ns = ...

local T, W, Names, Tree, L = ns.Theme, ns.Widgets, ns.Names, ns.ElementTree, ns.L
local SIZE = T.SIZE
local ROW = 34
local HEADER = 32
local INDENT = 18

local function ElementTooltip(row, e, status)
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:SetPoint("LEFT", row, "RIGHT", 16, 0)
    GameTooltip:SetText(e.label, 1, 1, 1)
    local r, g, b = T.Color("textMuted")
    GameTooltip:AddDoubleLine(L.TIP_ADDON, e.owner, r, g, b, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TIP_TYPE, Names.KindLabel(e.kind), r, g, b, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TIP_FRAME, e.name, r, g, b, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TIP_SIZE, ("%d x %d, %s"):format(e.width, e.height, e.strata), r, g, b, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.TIP_STATUS, status, r, g, b, 1, 1, 1)
    GameTooltip:Show()
end

local function HeaderSwitch(row)
    return W.Switch(row,
        function()
            local it = row.item
            if it and it.family then return Tree:FamilyIncluded(it.family) end
            return it and it.group and not ns.profile.exclude.addons[it.group.owner]
        end,
        function(v)
            local it = row.item
            ns.Fader:SetAddonExcluded(it.family and Tree:FamilyOwners(it.family) or it.group.owner, not v)
        end)
end

local function CreateRow(list, i)
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", 1, -HEADER - (i - 1) * ROW)
    row:SetPoint("RIGHT", list, "RIGHT", -14, 0)
    row.bg = T.Fill(row, "panelAlt", "BACKGROUND")
    row.bg:SetAllPoints()
    row.sel = T.Fill(row, "selected", "BACKGROUND", 1)
    row.sel:SetAllPoints()
    row.selBar = T.Fill(row, "accent", "ARTWORK")
    row.selBar:SetPoint("TOPLEFT")
    row.selBar:SetPoint("BOTTOMLEFT")
    row.selBar:SetWidth(2)
    T.Fill(row, "hover", "HIGHLIGHT"):SetAllPoints()
    local div = T.Fill(row, "divider", "BORDER")
    div:SetPoint("BOTTOMLEFT")
    div:SetPoint("BOTTOMRIGHT")
    div:SetHeight(1)

    row.chev = T.Text(row, "heading", "textMuted")
    row.gname = T.Text(row, "heading", "text")
    row.gname:SetPoint("LEFT", row.chev, "LEFT", 18, 0)
    row.gcount = T.Text(row, "small", "textMuted")
    row.gcount:SetPoint("LEFT", row.gname, "RIGHT", 10, 0)
    row.switch = HeaderSwitch(row)
    row.switch:SetPoint("RIGHT", -14, 0)

    row.label = T.Text(row, "body", "text")
    row.kind = T.Text(row, "small", "textMuted")
    row.kind:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
    row.toggle = W.Switch(row,
        function() return row.item and row.item.e and row.item.rule == nil end,
        function() Tree:ToggleElement(row.item) end)
    row.toggle:SetPoint("RIGHT", -14, 0)
    row.locked = T.Text(row, "small", "textMuted")
    row.locked:SetPoint("RIGHT", -14, 0)
    row.locked:SetJustifyH("RIGHT")

    row:SetScript("OnClick", function(self)
        local it = self.item
        if not it then return end
        local key = it.family and ("f:" .. it.family.key) or it.group and ("a:" .. it.group.owner)
        if key then
            Tree:ToggleOpen(key)
            self.page:Refresh()
        else
            Tree:ToggleElement(it)
        end
    end)
    row:SetScript("OnEnter", function(self)
        local it = self.item
        if it and it.e then
            ns.Highlight:Show(it.e)
            ElementTooltip(self, it.e, it.status)
        end
    end)
    row:SetScript("OnLeave", function()
        ns.Highlight:Hide()
        GameTooltip:Hide()
    end)
    return row
end

local function RenderHeaderRow(row, it)
    row.chev:ClearAllPoints()
    row.chev:SetPoint("LEFT", 14 + it.depth * INDENT, 0)
    if it.family then
        local fam = it.family
        row.chev:SetText(Tree:IsOpen("f:" .. fam.key) and "-" or "+")
        row.gname:SetText(fam.title)
        row.gcount:SetText(L.COUNT_FAMILY:format(#fam.groups, fam.count, fam.faded))
    else
        local g = it.group
        row.chev:SetText(Tree:IsOpen("a:" .. g.owner) and "-" or "+")
        row.gname:SetText(it.depth > 0 and g.subtitle or g.title)
        row.gcount:SetText(L.COUNT_GROUP:format(#g.items, g.faded))
    end
    T.Paint(row.bg, it.depth > 0 and "panel" or "panelAlt")
    row.switch:Refresh()
end

local function RenderElementRow(row, it)
    local e = it.e
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", 32 + (it.depth - 1) * INDENT, 0)
    row.label:SetText(e.label)
    row.label:SetWidth(0)  -- unbounded, to measure
    row.label:SetWidth(math.min(row.label:GetStringWidth(), 300))
    T.Paint(row.label, it.rule and "textDim" or "text")
    local kind = Names.KindLabel(e.kind)
    row.kind:SetText(ns.Safe.IsVisible(e.frame) and kind or L.HIDDEN:format(kind))
    local lockedText = Tree.LockedText(it.rule)
    row.toggle:SetShown(not lockedText)
    row.locked:SetShown(lockedText ~= nil)
    if lockedText then
        row.locked:SetText(lockedText)
    else
        row.toggle:Refresh()
    end
end

local function RenderRow(row, it, selected)
    row.item = it
    if not it then return row:Hide() end
    row:Show()
    local isHeader = it.e == nil
    for _, part in ipairs({ row.chev, row.gname, row.gcount, row.switch, row.bg }) do part:SetShown(isHeader) end
    for _, part in ipairs({ row.label, row.kind }) do part:SetShown(not isHeader) end
    local isSel = not isHeader and it.e == selected
    row.sel:SetShown(isSel)
    row.selBar:SetShown(isSel)
    if isHeader then
        row.toggle:Hide()
        row.locked:Hide()
        RenderHeaderRow(row, it)
    else
        RenderElementRow(row, it)
    end
end

local function CreateHeader(list, page)
    local h = CreateFrame("Frame", nil, list)
    h:SetPoint("TOPLEFT", 1, -1)
    h:SetPoint("TOPRIGHT", -1, -1)
    h:SetHeight(HEADER - 1)
    T.Fill(h, "panelAlt", "BACKGROUND"):SetAllPoints()
    local div = T.Fill(h, "border", "BORDER")
    div:SetPoint("BOTTOMLEFT")
    div:SetPoint("BOTTOMRIGHT")
    div:SetHeight(1)

    page.count = T.Text(h, "small", "textMuted")
    page.count:SetPoint("LEFT", 14, 0)

    local status = CreateFrame("Button", nil, h)
    status:SetHeight(HEADER - 1)
    status:SetPoint("RIGHT", -8, 0)
    status.text = T.Text(status, "small", "textMuted")
    T.NoShadow(status.text)
    status.text:SetPoint("RIGHT", -18, 0)
    W.Chevron(status, "textMuted"):SetPoint("RIGHT", -6, 0)
    T.Fill(status, "hover", "HIGHLIGHT"):SetAllPoints()
    status:SetScript("OnClick", function(self)
        W.ShowMenu(self, Tree.Filters(), Tree.view.filter, function(value)
            Tree:SetFilter(value)
            page.offset = 0
            page:Refresh()
        end)
    end)

    function h:Refresh()
        local filter = Tree.view.filter
        status.text:SetText(L.FILTER:format(Tree.FilterText(filter)):upper())
        T.Paint(status.text, filter == "all" and "textMuted" or "accent")
        status:SetWidth(status.text:GetStringWidth() + 30)
    end
    return h
end

local function Build(frame)
    local page = { items = {}, rows = {}, offset = 0 }

    local searchBox = W.Search(frame, L.SEARCH, function(text)
        if Tree:SetSearch(text) then
            page.offset = 0
            page:Refresh()
        end
    end)
    searchBox:SetPoint("TOPLEFT", SIZE.pad, -20)
    searchBox:SetWidth(220)

    local hidden = W.Check(frame, function(self, checked)
        self:Set(checked)
        Tree:SetShowHidden(checked)
        page:Refresh()
    end)
    hidden:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
    hidden:Set(Tree.view.showHidden)
    local hiddenLabel = T.Text(frame, "label", "textDim")
    hiddenLabel:SetPoint("LEFT", hidden, "RIGHT", 8, 0)
    hiddenLabel:SetText(L.SHOW_HIDDEN)

    local rescan = W.Button(frame, L.RESCAN, function() ns:Rescan() end)
    rescan:SetPoint("TOPRIGHT", -SIZE.pad, -20)
    local onScreen = W.Button(frame, L.SHOW_ON_SCREEN, function() ns.Overlay:Show() end, "primary")
    onScreen:SetPoint("RIGHT", rescan, "LEFT", -8, 0)

    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", SIZE.pad, -60)
    list:SetPoint("BOTTOMRIGHT", -SIZE.pad, 16)
    T.Fill(list, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(list, "border")
    list:EnableMouseWheel(true)
    local header = CreateHeader(list, page)

    page.empty = T.Text(list, "note", "textMuted")
    page.empty:SetPoint("CENTER", 0, -HEADER / 2)

    local bar = CreateFrame("Slider", nil, list)
    bar:SetOrientation("VERTICAL")
    bar:SetPoint("TOPRIGHT", -4, -HEADER - 4)
    bar:SetPoint("BOTTOMRIGHT", -4, 4)
    bar:SetWidth(6)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    local thumb = T.Fill(bar, "box", "OVERLAY")
    thumb:SetSize(6, 40)
    bar:SetThumbTexture(thumb)
    bar:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        if v ~= page.offset then
            page.offset = v
            page:Render()
        end
    end)
    list:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(math.max(0, bar:GetValue() - delta * 3))
    end)

    local function VisibleRows()
        return math.max(1, math.floor((list:GetHeight() - HEADER - 2) / ROW))
    end

    local function ScrollTo(offset)
        page.offset = offset
        bar:SetValue(offset)
    end

    function page:Render()
        local n = VisibleRows()
        for i = #self.rows + 1, n do
            local row = CreateRow(list, i)
            row.page = self
            self.rows[i] = row
        end
        for i, row in ipairs(self.rows) do
            RenderRow(row, i <= n and self.items[self.offset + i] or nil, self.selected)
        end
        local maxOffset = math.max(0, #self.items - n)
        bar:SetMinMaxValues(0, maxOffset)
        bar:SetShown(maxOffset > 0)
        thumb:SetHeight(math.max(24, (list:GetHeight() - HEADER - 8) * n / math.max(n, #self.items)))
    end

    function page:Refresh()
        local shown, faded
        self.items, shown, faded = Tree:Build()
        self.count:SetText(L.COUNT_LIST:format(shown, faded))
        self.empty:SetText(ns.Scanner.last and (#self.items == 0 and L.NOTHING or "") or L.SCANNING)
        ScrollTo(math.min(self.offset, math.max(0, #self.items - VisibleRows())))
        hidden:Set(Tree.view.showHidden)
        header:Refresh()
        self:Render()
    end

    function page:Reveal(e)
        if Tree:Open(e) then searchBox:SetText("") end
        self.selected = e
        self:Refresh()
        for i, it in ipairs(self.items) do
            if it.e == e then
                local n = VisibleRows()
                ScrollTo(math.max(0, math.min(i - math.floor(n / 2), #self.items - n)))
                self:Render()
                break
            end
        end
        ns.Highlight:Flash(e, 2)
    end

    list:SetScript("OnSizeChanged", function() page:Render() end)
    return page
end

ns.Options:Register({
    key = "fade.elements",
    module = ns.module,
    title = Sendit.Locale.Text(ns.L, "ELEMENTS"),
    subtitle = Sendit.Locale.Text(ns.L, "ELEMENTS_SUB"),
    resetKeys = { "exclude" },
    build = Build,
})

function ns.RevealElement(e)
    local def = ns.Options:Show("fade.elements")
    if def and def.key == "fade.elements" and def.page then def.page:Reveal(e) end
end

ns.Options:OnLeave(function() ns.Highlight:Hide() end)
