--[[
  Options: the suite's settings window - sidebar (brand, search, then the scrolling Nav: modules that
  open into their pages or the sections of their one page - a second click folds them; a module without
  a page opens its window; switched-off modules; the suite's own pages), header
  (title, profile picker), body (the page), footer (Defaults, status, Reload UI, Close).
  Sendit.Options:Register{ key, module, title, subtitle, resetKeys, onReset, build(frame) -> page,
                           core, hidden }   page:Refresh() is required
  Options.SettingsPage(fn) / OnLeave(fn) / OnPage(fn) / Pages() / BuildPage(def) / Reveal(def, row)
]]
local _, ns = ...

local Options = {}
ns.Options = Options

local T, W, L = ns.Theme, ns.Widgets, ns.L
local Resolve = ns.Locale.Resolve
local SIZE = T.SIZE
local Nav = ns.Nav
local FOOT = 52  -- sidebar room below the list (version)

local pages = {}
local byKey = {}
local leaveHooks = {}
local pageHooks = {}
local win, current

function Options:Register(def)
    assert(def.key and not byKey[def.key], "Sendit: page key missing or taken")
    pages[#pages + 1] = def
    byKey[def.key] = def
    if win then self:Rebuild() end
end

function Options:Page(key)
    return byKey[key]
end

function Options:OnLeave(fn)
    leaveHooks[#leaveHooks + 1] = fn
end

function Options:OnPage(fn)
    pageHooks[#pageHooks + 1] = fn
end

function Options:Pages()
    return pages
end

function Options:FirstPage()
    for _, def in ipairs(pages) do
        if not def.hidden then return def end
    end
end

local function Leave()
    for _, fn in ipairs(leaveHooks) do fn() end
end

function Options.Changed()
    ns.SettingsChanged()
end

local function Stars(parent, count)
    -- deterministic sky, the same every time
    local seed = 7
    local function rnd()
        seed = (seed * 16807) % 2147483647
        return seed / 2147483647
    end
    local stars = {}
    for i = 1, count do
        local s = T.Fill(parent, "star", "BORDER", 0, 0.15 + rnd() * 0.45)
        local size = rnd() < 0.8 and 1 or 2
        s:SetSize(size, size)
        s:SetPoint("TOPLEFT", rnd() * (SIZE.width - SIZE.sidebar), -rnd() * (SIZE.header - 8))
        stars[i] = T.Twinkle(s, math.floor(rnd() * 1000))
    end
    return stars
end

-- modules with their pages in page order; a module with a window (app bar launcher) but no page still
-- gets its row
local function Groups()
    local groups, core, byModule = {}, {}, {}
    local function Group(m)
        local g = byModule[m]
        if not g then
            g = { module = m, pages = {}, apps = {} }
            byModule[m] = g
            groups[#groups + 1] = g
        end
        return g
    end
    for _, def in ipairs(pages) do
        if def.core then
            if not def.hidden then core[#core + 1] = def end  -- hidden: the search results
        else
            local g = Group(def.module)
            g.pages[#g.pages + 1] = def
        end
    end
    for _, def in ipairs(ns.AppBar.Launchers()) do
        if def.module then
            local g = Group(def.module)
            g.apps[#g.apps + 1] = def
        end
    end
    return groups, core
end

local function LauncherShown(def)
    if not def.shown then return false end
    local ok, on = pcall(def.shown)
    return ok and on == true
end

local function OpenWindow(def)
    def.toggle()
    C_Timer.After(0.05, function()
        if LauncherShown(def) then Options:Hide() end
    end)
end

local function Entry(frame, height) return { frame = frame, height = height } end

-- the section rows of a one-page module, made once its page exists (they come from its layout)
local function SectionRows(g)
    local def = g.pages[1]
    if #g.pages ~= 1 or not (def and def.page and def.page.Sections) then return {} end
    if not g.sectionRows then
        g.sectionRows = {}
        for i, sec in ipairs(def.page:Sections()) do
            g.sectionRows[i] = Nav.Row(win.list.content, sec.title, nil, true, function()
                if current ~= def then Options:ShowPage(def) end
                def.page:ScrollToSection(i)
                Options.SectionsMoved()
            end)
        end
    end
    return g.sectionRows
end

local function Children(g)
    local rows = {}
    if #g.pages > 1 then
        for _, def in ipairs(g.pages) do rows[#rows + 1] = win.nav[def.key] end
    else
        for _, r in ipairs(SectionRows(g)) do rows[#rows + 1] = r end
    end
    return rows
end

-- marks the section of the open page that is at the top of its view
function Options.SectionsMoved()
    if not (win and win:IsShown() and current and current.page and current.page.SectionAt) then return end
    for _, g in ipairs(win.groups) do
        if g.sectionRows and g.pages[1] == current then
            local at = current.page:SectionAt()
            for i, r in ipairs(g.sectionRows) do r:SetSelected(i == at) end
        end
    end
end

local function LayoutNav()
    local entries, focus = {}, nil
    if #win.groups > 0 then entries[#entries + 1] = Entry(win.caps.modules, Nav.CAPTION) end
    for _, g in ipairs(win.groups) do
        local here = current and current.module == g.module and not current.core
        local open = here and not g.folded
        local children = Children(g)
        g.button:SetSelected(here, #children == 0)
        -- a page not built yet is taken to have sections (they are known once it is built)
        local unknown = #g.pages == 1 and not g.pages[1].page
        g.button:SetOpen(open, #g.pages > 1 or #children > 0 or unknown)
        entries[#entries + 1] = Entry(g.button, Nav.ROW)
        if open then focus = g.button end
        for _, r in ipairs(g.allChildren or {}) do r:Hide() end
        g.allChildren = children
        if open then
            for _, r in ipairs(children) do
                r:SetSelected(r.page ~= nil and r.page == current)
                if r.page ~= nil and r.page == current then focus = r end
                entries[#entries + 1] = Entry(r, Nav.SUB)
            end
            if #children > 0 then entries[#entries + 1] = Entry(win.gap, 6) end
        end
    end
    if #win.off > 0 then entries[#entries + 1] = Entry(win.caps.off, Nav.CAPTION) end
    for _, o in ipairs(win.off) do
        local on = ns.ModulePage.Showing(o.name)
        o.button:SetSelected(on)
        if on then focus = o.button end
        entries[#entries + 1] = Entry(o.button, Nav.ROW)
    end
    entries[#entries + 1] = Entry(win.caps.suite, Nav.CAPTION)
    for _, def in ipairs(win.core) do
        local b = win.nav[def.key]
        b:SetSelected(def == current)
        if def == current then focus = b end
        entries[#entries + 1] = Entry(b, Nav.ROW)
    end
    win.list:Place(entries, focus)
    Options.SectionsMoved()
end

local function BuildNav()
    for _, b in pairs(win.nav or {}) do b:Hide() end
    for _, g in ipairs(win.groups or {}) do
        g.button:Hide()
        for _, r in ipairs(g.allChildren or {}) do r:Hide() end
    end
    for _, o in ipairs(win.off or {}) do o.button:Hide() end
    local parent = win.list.content
    win.nav = {}
    win.groups, win.core = Groups()
    for _, g in ipairs(win.groups) do
        local m = g.module
        g.button = Nav.Row(parent, m and m.title or "?", m and m.icon, false, function()
            if not g.pages[1] then return OpenWindow(g.apps[1]) end
            if current and current.module == g.module and not current.core then
                g.folded = not g.folded
                return LayoutNav()
            end
            g.folded = nil
            Options:ShowPage(g.pages[1])
        end)
        g.button.switch = ns.ModulePage.Switch(g.button, ns.Suite.ModuleAddon(m))
        if #g.pages > 1 then
            for _, def in ipairs(g.pages) do
                local b = Nav.Row(parent, def.title, nil, true, function() Options:ShowPage(def) end)
                b.page = def
                win.nav[def.key] = b
            end
        end
    end
    for _, def in ipairs(win.core) do
        win.nav[def.key] = Nav.Row(parent, def.title, nil, false, function() Options:ShowPage(def) end)
    end
    win.off = {}
    for _, a in ipairs(ns.Suite.Addons()) do
        if not a.loaded then
            local b = Nav.Row(parent, a.title, a.icon, false, function() ns.ModulePage.Show(a.name) end)
            b.dim = true
            b.switch = ns.ModulePage.Switch(b, a.name)
            win.off[#win.off + 1] = { button = b, name = a.name }
        end
    end
end

function Options._Nav() return win end  -- tests

function Options:Rebuild()
    BuildNav()
    LayoutNav()
end

StaticPopupDialogs["SENDIT_RESET_PAGE"] = {
    text = "",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, def)
        ns.Profiles:Reset(def.module, def.resetKeys)
        if def.onReset then def.onReset() end
        ns.SettingsChanged()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function Build()
    win = CreateFrame("Frame", "SenditOptions", UIParent)
    ns.ownFrames[win] = true
    tinsert(UISpecialFrames, "SenditOptions")  -- Escape closes it
    win:SetSize(SIZE.width, SIZE.height)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:Hide()

    local shadow = T.Fill(win, "shadow", "BACKGROUND", -8)
    shadow:SetPoint("TOPLEFT", -6, 6)
    shadow:SetPoint("BOTTOMRIGHT", 6, -6)
    local bg = T.Fill(win, "bg", "BACKGROUND", -7)
    bg:SetAllPoints()
    local edges = T.Border(win, "border")
    -- azeroth style: the gold edge replaces the hairline
    T.Decorate(win, "window", { level = 20, onApply = function(_, on)
        for _, e in ipairs(edges) do e:SetShown(not on) end
    end })

    local side = CreateFrame("Frame", nil, win)
    side:SetPoint("TOPLEFT")
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIZE.sidebar)
    T.Fill(side, "sidebar"):SetAllPoints()
    local sideEdge = T.Fill(side, "divider", "BORDER")
    sideEdge:SetPoint("TOPRIGHT")
    sideEdge:SetPoint("BOTTOMRIGHT")
    sideEdge:SetWidth(1)
    win.side = side

    local mark = T.Text(side, "title", "text")
    mark:SetPoint("TOPLEFT", 24, -30)
    mark:SetText("Send")
    local mark2 = T.Text(side, "title", "accent")
    mark2:SetPoint("LEFT", mark, "RIGHT", 0, 0)
    mark2:SetText("it")
    local tagline = T.Text(side, "small", "textMuted")
    tagline:SetPoint("TOPLEFT", mark, "BOTTOMLEFT", 0, -6)
    win.tagline = tagline
    local top = ns.Search and ns.Search.AttachBox(side, tagline) or tagline
    win.list = Nav.Create(side, top, FOOT)
    win.gap = CreateFrame("Frame", nil, win.list.content)
    win.gap:SetSize(1, 1)
    win.caps = {
        modules = Nav.Caption(win.list.content, function() return L.NAV_MODULES end),
        off = Nav.Caption(win.list.content, function() return L.NAV_OFF end),
        suite = Nav.Caption(win.list.content, function() return L.NAV_SUITE end),
    }
    local footEdge = T.Fill(side, "divider", "BORDER")
    footEdge:SetHeight(1)
    footEdge:SetPoint("BOTTOMLEFT", 20, FOOT - 1)
    footEdge:SetPoint("BOTTOMRIGHT", -20, FOOT - 1)

    local version = T.Text(side, "small", "textMuted")
    version:SetPoint("BOTTOMLEFT", 24, 22)
    win.version = version

    local header = CreateFrame("Frame", nil, win)
    header:SetPoint("TOPLEFT", side, "TOPRIGHT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(SIZE.header)
    local sky = T.Fill(header, "sky", "BACKGROUND")
    sky:SetAllPoints()
    T.Gradient(sky, "sky", "bg")
    win.stars = Stars(header, 26)
    local headerEdge = T.Fill(header, "divider", "BORDER")
    headerEdge:SetPoint("BOTTOMLEFT")
    headerEdge:SetPoint("BOTTOMRIGHT")
    headerEdge:SetHeight(1)
    W.Movable(win, header)

    win.eyebrow = T.Text(header, "caption", "accent")
    win.eyebrow:SetPoint("TOPLEFT", SIZE.pad, -16)
    win.title = T.Text(header, "hero", "text")
    win.title:SetPoint("TOPLEFT", SIZE.pad, -30)
    win.subtitle = T.Text(header, "note", "textDim")
    win.subtitle:SetPoint("TOPLEFT", win.title, "BOTTOMLEFT", 0, -8)

    local profileLabel = T.Text(header, "small", "textDim")
    win.profileLabel = profileLabel
    win.profile = W.Dropdown(header, 170, function()
        local list = {}
        for _, name in ipairs(ns.Profiles:List()) do list[#list + 1] = { name, name } end
        return list
    end, function() return ns.Profiles:Active() end, function(name) ns.Profiles:Use(name) end)
    win.profile:SetPoint("TOPRIGHT", -52, -32)
    profileLabel:SetPoint("BOTTOMLEFT", win.profile, "TOPLEFT", 0, 4)

    local close = CreateFrame("Button", nil, header)
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", -12, -12)
    local x = T.Text(close, "title", "textDim")
    x:SetPoint("CENTER")
    x:SetText("x")
    T.Fill(close, "hover", "HIGHLIGHT"):SetAllPoints()
    close:SetScript("OnClick", function() Options:Hide() end)

    local footer = CreateFrame("Frame", nil, win)
    footer:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT")
    footer:SetPoint("BOTTOMRIGHT")
    footer:SetHeight(SIZE.footer)
    T.Fill(footer, "footer"):SetAllPoints()
    local footEdge = T.Fill(footer, "divider", "BORDER")
    footEdge:SetPoint("TOPLEFT")
    footEdge:SetPoint("TOPRIGHT")
    footEdge:SetHeight(1)

    win.defaults = W.Button(footer, "", function()
        StaticPopupDialogs.SENDIT_RESET_PAGE.text = L.RESET_PAGE
        local dialog = StaticPopup_Show("SENDIT_RESET_PAGE")
        if dialog then dialog.data = current end
    end)
    win.defaults:SetPoint("LEFT", SIZE.pad, 0)
    local closeBtn = W.Button(footer, "", function() Options:Hide() end, "primary")
    win.closeBtn = closeBtn
    closeBtn:SetPoint("RIGHT", -SIZE.pad, 0)
    local reload = W.Button(footer, "", function() ReloadUI() end)
    win.reload = reload
    reload:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)

    win.status = T.Text(footer, "small", "textMuted")
    win.status:SetPoint("LEFT", win.defaults, "RIGHT", 16, 0)
    win.status:SetPoint("RIGHT", reload, "LEFT", -12, 0)

    win.body = CreateFrame("Frame", nil, win)
    win.body:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    win.body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT")

    win:SetScript("OnShow", function() Options:UpdateMotion() end)
    win:SetScript("OnHide", function()
        Leave()
        for _, ag in ipairs(win.stars) do ag:Stop() end
    end)

    BuildNav()
end

function Options:UpdateMotion()
    if not (win and win:IsShown()) then return end
    local animate = ns.profile.design.animations
    for _, ag in ipairs(win.stars) do
        if animate then ag:Play() else ag:Stop() end
    end
end

function Options:Refresh()
    if not (win and win:IsShown()) then return end
    local m = current and current.module
    local status = m and not current.core and m.status and m.status()
    win.tagline:SetText(L.TAGLINE)
    win.version:SetText(L.VERSION:format(ns.version))
    win.profileLabel:SetText(L.PROFILE)
    win.defaults:SetLabel(L.DEFAULTS)
    win.closeBtn:SetLabel(L.CLOSE)
    win.reload:SetLabel(L.RELOAD)
    if current then
        local mt = m and Resolve(m.title)
        local title = Resolve(current.title)
        win.eyebrow:SetText(not current.core and mt and mt ~= title and mt:upper() or "")
        win.title:SetText(title or "")
        win.subtitle:SetText(Resolve(current.subtitle) or "")
    end
    for _, b in pairs(win.nav) do b.text:SetText(Resolve(b.textSource) or "") end
    for _, g in ipairs(win.groups) do g.button.text:SetText(Resolve(g.button.textSource) or "") end
    for _, c in pairs(win.caps) do c:Refresh() end
    local reload = ns.Suite.ReloadNeeded() and ("  -  " .. L.RELOAD_NEEDED) or ""
    win.status:SetText(L.STATUS:format(ns.Profiles:Active()) .. (status and ("  -  " .. status) or "") .. reload)
    for _, g in ipairs(win.groups) do if g.button.switch then g.button.switch:Refresh() end end
    for _, o in ipairs(win.off) do o.button.switch:Refresh() end
    win.profile:Refresh()
    self:UpdateMotion()
    if current and current.page then current.page:Refresh() end
end

function Options:BuildPage(def)
    if not win then Build() end
    if not def.page then
        local frame = CreateFrame("Frame", nil, win.body)
        frame:SetAllPoints()
        frame:Hide()
        def.page = def.build(frame)
        def.page.frame = frame
    end
    return def.page
end

function Options:ShowPage(def)
    if current and current ~= def then Leave() end
    for _, d in ipairs(pages) do
        if d.page then d.page.frame:SetShown(d == def) end
    end
    self:BuildPage(def)
    def.page.frame:Show()
    if current ~= def then T.FadeIn(def.page.frame, 0.15) end
    current = def
    LayoutNav()
    win.defaults:SetShown(def.resetKeys ~= nil)
    self:Refresh()
    for _, fn in ipairs(pageHooks) do fn(def) end
end

function Options:Reveal(def, row)
    self:Show(def.key)
    if row and def.page.Reveal then
        def.page:Reveal(row)
    elseif def.page.Unpin then
        def.page:Unpin()
    end
    Options.SectionsMoved()
end

function Options:Show(key)
    if not win then Build() end
    if #pages == 0 then return end
    if not win:IsShown() then
        win:Show()
        T.FadeIn(win, 0.2, 10)
    end
    local def = byKey[key or ""] or current or self:FirstPage()
    self:ShowPage(def)
    return def
end

function Options:Hide()
    if win then win:Hide() end
end

function Options:IsShown()
    return win ~= nil and win:IsShown()
end

function Options:Current()
    return self:IsShown() and current or nil
end

function Options:Toggle()
    if win and win:IsShown() then self:Hide() else self:Show() end
end

ns.OnSettingsChanged(function() Options:Refresh() end)

function Options.SettingsPage(build)
    return function(frame)
        local area = W.ScrollArea(frame)
        area:SetPoint("TOPLEFT", SIZE.pad, -24)
        area:SetPoint("BOTTOMRIGHT", -SIZE.pad, 0)
        area.content:SetWidth(SIZE.width - SIZE.sidebar - SIZE.pad * 2)
        local layout = W.Layout(area.content)
        build(layout, area.content)
        area:HookScript("OnMouseWheel", function()
            layout:Unpin()
            Options.SectionsMoved()
        end)
        return layout
    end
end
