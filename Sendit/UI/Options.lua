--[[
  Options: the one settings window of the suite (layout after Polestar's shell).
    sidebar  wordmark, one entry per module (its pages unfold under it while
             it is selected), then Design and Profiles, version
    header   night-sky band, module + page title, subtitle, profile picker
             (every page edits the active profile)
    body     the current page
    footer   Defaults (resets the page's resetKeys), status, Reload UI, Close

  Pages register with Sendit.Options:Register{
    key,                 -- unique, e.g. "fade.general"
    module,              -- the registered module (its sections are edited)
    title, subtitle,     -- strings or functions (follow a language switch)
    resetKeys = { keys of the module's sections } or nil,
    onReset = fn or nil, -- after a reset (e.g. restart fading)
    build = function(frame) -> page   -- page:Refresh() is required
  }. Core pages (Design, Profiles) have core = true and sit below the modules.
  hidden = true keeps a page out of the sidebar (the search results page).
  Options.SettingsPage(fn) builds a scrolling page of setting rows.
  Options:OnLeave(fn) runs when the page changes or the window closes.
  Options:OnPage(fn) runs with the new page after every page change.
  Options:Pages() / BuildPage(def) / Reveal(def, row): the search lists every
  page's rows (built on first use) and jumps to one (UI/Search.lua).
]]
local _, ns = ...

local Options = {}
ns.Options = Options

local T, W, L = ns.Theme, ns.Widgets, ns.L
local Resolve = ns.Locale.Resolve
local SIZE = T.SIZE
local NAV_TOP, NAV_H, SUB_H = -120, 36, 28

local pages = {}      -- registration order
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

-- The first page of the sidebar (hidden pages are never a default).
function Options:FirstPage()
    for _, def in ipairs(pages) do
        if not def.hidden then return def end
    end
end

local function Leave()
    for _, fn in ipairs(leaveHooks) do fn() end
end

-- Persisted setting changed: everything refreshes.
function Options.Changed()
    ns.SettingsChanged()
end

---------------------------------------------------------------------------
-- Shell
---------------------------------------------------------------------------
local function Stars(parent, count)
    -- deterministic pseudo-random sky, same every time
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

local function NavButton(parent, text, icon, sub, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIZE.sidebar, sub and SUB_H or NAV_H)
    b.sel = T.Fill(b, sub and "hover" or "selected", "BACKGROUND")
    b.sel:SetAllPoints()
    b.bar = T.Fill(b, "accent", "ARTWORK")
    b.bar:SetPoint("TOPLEFT")
    b.bar:SetPoint("BOTTOMLEFT")
    b.bar:SetWidth(2)
    T.Fill(b, "hover", "HIGHLIGHT"):SetAllPoints()
    local x = sub and 44 or 24
    if icon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetTexture(icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.icon:SetSize(18, 18)
        b.icon:SetPoint("LEFT", 22, 0)
        x = 48
    end
    b.text = T.Text(b, sub and "label" or "body", "textDim")
    b.text:SetPoint("LEFT", x, 0)
    b.textSource = text
    b.text:SetText(Resolve(text) or "")
    function b:SetSelected(on, strong)
        self.text:SetText(Resolve(self.textSource) or "")
        self.sel:SetShown(on)
        self.bar:SetShown(on and strong ~= false)
        T.Paint(self.text, on and "text" or (self.dim and "textMuted" or "textDim"))
        if self.icon then self.icon:SetDesaturated(self.dim == true) end
        if self.switch then self.switch:Refresh() end
    end
    b:SetScript("OnClick", onClick)
    return b
end

-- Sidebar groups: one per module with pages (registration order), then core.
local function Groups()
    local groups, core, byModule = {}, {}, {}
    for _, def in ipairs(pages) do
        if def.core then
            if not def.hidden then core[#core + 1] = def end  -- hidden: the search results
        else
            local m = def.module
            local g = byModule[m]
            if not g then
                g = { module = m, pages = {} }
                byModule[m] = g
                groups[#groups + 1] = g
            end
            g.pages[#g.pages + 1] = def
        end
    end
    return groups, core
end

-- Place the sidebar entries: the selected module unfolds its pages.
local function LayoutNav()
    local y = NAV_TOP
    for _, g in ipairs(win.groups) do
        local open = current and current.module == g.module and not current.core
        g.button:ClearAllPoints()
        g.button:SetPoint("TOPLEFT", 0, y)
        g.button:SetSelected(open, #g.pages == 1)
        y = y - NAV_H - 2
        for _, def in ipairs(g.pages) do
            local b = win.nav[def.key]
            if b then
                b:SetShown(open)
                if open then
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", 0, y)
                    b:SetSelected(def == current)
                    y = y - SUB_H
                end
            end
        end
        if open and #g.pages > 1 then y = y - 4 end
    end
    -- modules switched off: dimmed, their switch brings them back
    for _, o in ipairs(win.off) do
        o.button:ClearAllPoints()
        o.button:SetPoint("TOPLEFT", 0, y)
        o.button:SetSelected(ns.ModulePage.Showing(o.name))
        y = y - NAV_H - 2
    end
    y = y - 14
    win.coreEdge:ClearAllPoints()
    win.coreEdge:SetPoint("TOPLEFT", 24, y + 7)
    win.coreEdge:SetShown(#win.groups > 0)
    for _, def in ipairs(win.core) do
        local b = win.nav[def.key]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 0, y)
        b:SetSelected(def == current)
        y = y - NAV_H - 2
    end
end

local function BuildNav()
    for _, b in pairs(win.nav or {}) do b:Hide() end
    for _, g in ipairs(win.groups or {}) do g.button:Hide() end
    for _, o in ipairs(win.off or {}) do o.button:Hide() end
    win.nav = {}
    win.groups, win.core = Groups()
    for _, g in ipairs(win.groups) do
        local m = g.module
        g.button = NavButton(win.side, m and m.title or "?", m and m.icon, false,
            function() Options:ShowPage(g.pages[1]) end)
        g.button.switch = ns.ModulePage.Switch(g.button, ns.Suite.ModuleAddon(m))
        if #g.pages > 1 then
            for _, def in ipairs(g.pages) do
                win.nav[def.key] = NavButton(win.side, def.title, nil, true, function() Options:ShowPage(def) end)
            end
        end
    end
    for _, def in ipairs(win.core) do
        win.nav[def.key] = NavButton(win.side, def.title, nil, false, function() Options:ShowPage(def) end)
    end
    win.off = {}
    for _, a in ipairs(ns.Suite.Addons()) do
        if not a.loaded then
            local b = NavButton(win.side, a.title, a.icon, false, function() ns.ModulePage.Show(a.name) end)
            b.dim = true
            b.switch = ns.ModulePage.Switch(b, a.name)
            win.off[#win.off + 1] = { button = b, name = a.name }
        end
    end
end

function Options._Nav() return win end  -- tests: the sidebar entries

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
    -- azeroth frame style: the game's gold edge replaces the hairline
    T.Decorate(win, "window", { level = 20, onApply = function(_, on)
        for _, e in ipairs(edges) do e:SetShown(not on) end
    end })

    -- sidebar
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
    if ns.Search then ns.Search.AttachBox(side, tagline) end

    win.coreEdge = T.Fill(side, "divider", "BORDER")
    win.coreEdge:SetSize(SIZE.sidebar - 48, 1)

    local version = T.Text(side, "small", "textMuted")
    version:SetPoint("BOTTOMLEFT", 24, 22)
    win.version = version

    -- header
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

    -- footer
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

    -- body
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

-- Star twinkle follows the window and the animations setting.
function Options:UpdateMotion()
    if not (win and win:IsShown()) then return end
    local animate = ns.profile.design.animations
    for _, ag in ipairs(win.stars) do
        if animate then ag:Play() else ag:Stop() end
    end
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
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
    local reload = ns.Suite.ReloadNeeded() and ("  -  " .. L.RELOAD_NEEDED) or ""
    win.status:SetText(L.STATUS:format(ns.Profiles:Active()) .. (status and ("  -  " .. status) or "") .. reload)
    for _, g in ipairs(win.groups) do if g.button.switch then g.button.switch:Refresh() end end
    for _, o in ipairs(win.off) do o.button.switch:Refresh() end
    win.profile:Refresh()
    self:UpdateMotion()
    if current and current.page then current.page:Refresh() end
end

-- A page's content, built on first use (hidden until shown).
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

-- Open a page and bring one of its rows into view (search results).
function Options:Reveal(def, row)
    self:Show(def.key)
    if row and def.page.Reveal then def.page:Reveal(row) end
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

-- The page on screen (nil while the window is closed).
function Options:Current()
    return self:IsShown() and current or nil
end

function Options:Toggle()
    if win and win:IsShown() then self:Hide() else self:Show() end
end

ns.OnSettingsChanged(function() Options:Refresh() end)

-- A scrolling page of setting sections; build(layout, content) adds rows.
function Options.SettingsPage(build)
    return function(frame)
        local area = W.ScrollArea(frame)
        area:SetPoint("TOPLEFT", SIZE.pad, -24)
        area:SetPoint("BOTTOMRIGHT", -SIZE.pad, 0)
        area.content:SetWidth(SIZE.width - SIZE.sidebar - SIZE.pad * 2)
        local layout = W.Layout(area.content)
        build(layout, area.content)
        return layout
    end
end
