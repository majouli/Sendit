--[[
  TalentView: the inspected player's talents drawn like the talent window, in a window docked right
  of the inspect window, opened by our own side tab. Geometry is Blizzard's (Camelot frame 1218 x 708,
  node centre = ButtonsParent TOPLEFT + (posX / 10 - panX, -posY / 10 + panY), pan = (49, 24) -
  class pan (60, 31); headers at (140 + 400 * (i - 1), -100)) on a canvas scaled to the window;
  resizable (aspect kept), movable, right click docks it again.
  Named frames (skins sweep unnamed ones). Never opens Blizzard's talent frame (taints its commits),
  never hooks its tabs. Data: inspect config -1, redrawn on every Inspect change.
]]
local _, ns = ...
local L = ns.L
local Talents, Inspect = ns.Talents, ns.Inspect

local TalentView = {}
ns.TalentView = TalentView

local FRAME_W = 1218
local PAN_X, PAN_Y = 49 - 60, 24 - 31
local BG_TOP, BG_BOTTOM = 77, 672
local HEADER_X, HEADER_STEP, HEADER_Y = 140 - 2, 400, -(BG_TOP - 4) - 100
local VIEW_TOP, VIEW_BOTTOM = BG_TOP - 4, BG_BOTTOM + 4

local TAB_ICON = "Interface\\Icons\\Ability_Marksmanship"
local TITLE_HEIGHT = 28
local MARGIN = 6

local window, tab
local buttons, lines, headers = {}, {}, {}

local function G(name) return _G[name] end

local function InspectUnit()
    local frame = G("InspectFrame")
    return frame and frame.unit
end

local function NodeButton(canvas, i)
    local b = buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, canvas)
    b:SetSize(40, 40)
    b.shadow = b:CreateTexture(nil, "BACKGROUND")
    b.shadow:SetAtlas("talents-node-square-shadow", true)
    b.shadow:SetPoint("CENTER")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(36, 36)
    b.icon:SetPoint("CENTER")
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetPoint("CENTER")
    b.rank = b:CreateFontString(nil, "OVERLAY", "SystemFont16_Shadow_ThickOutline")
    b.rank:SetPoint("CENTER", b, "BOTTOMRIGHT", -2, 2)
    b:SetScript("OnEnter", function(self)
        local n = self.node
        if not n then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok = n.spellID and pcall(GameTooltip.SetSpellByID, GameTooltip, n.spellID)
        if not ok then GameTooltip:SetText(n.name or "?", 1, 1, 1, 1, true) end
        GameTooltip:AddLine(L.rank:format(n.rank, n.maxRanks), 1, 0.82, 0)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[i] = b
    return b
end

local function Header(canvas, i)
    local h = headers[i]
    if h then return h end
    h = CreateFrame("Frame", nil, canvas)
    h:SetSize(48, 48)
    h:SetFrameLevel(canvas:GetFrameLevel() + 20)
    h.icon = h:CreateTexture(nil, "BORDER")
    h.icon:SetSize(36, 36)
    h.icon:SetPoint("CENTER", -3, 3)
    local mask = h:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(40, 40)
    mask:SetPoint("CENTER", -2, 2)
    h.icon:AddMaskTexture(mask)
    h.ring = h:CreateTexture(nil, "OVERLAY")
    h.ring:SetAtlas("Talents-Main-Ring-c60", true)
    h.ring:SetPoint("CENTER", h.icon, "CENTER")
    h.box = h:CreateTexture(nil, "OVERLAY", nil, 1)
    h.box:SetAtlas("talents-main-ring-box-c60", true)
    h.box:SetPoint("CENTER", 14, -12)
    h.points = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.points:SetPoint("CENTER", h.box, "CENTER")
    h.name = h:CreateFontString(nil, "OVERLAY", "GameFontWhiteLarge")
    h.name:SetPoint("LEFT", h, "LEFT", 54, 2)
    headers[i] = h
    return h
end

local function Line(canvas, i)
    local l = lines[i]
    if l then return l end
    l = canvas:CreateLine(nil, "ARTWORK")
    l:SetThickness(5)
    lines[i] = l
    return l
end

local function HideAll()
    for _, b in ipairs(buttons) do b:Hide() end
    for _, l in ipairs(lines) do l:Hide() end
    for _, h in ipairs(headers) do h:Hide() end
end

local function X(n) return n.x - PAN_X end
local function Y(n) return -n.y + PAN_Y end

local function Draw(layout)
    HideAll()
    local canvas = window.canvas
    local count = 0
    local byID = {}
    for _, n in ipairs(layout and layout.nodes or {}) do
        count = count + 1
        local b = NodeButton(canvas, count)
        b.node = n
        b:ClearAllPoints()
        b:SetPoint("CENTER", canvas, "TOPLEFT", X(n), Y(n))
        b.icon:SetTexture(n.icon or 134400)
        local spent = n.rank > 0
        b.icon:SetDesaturated(not spent)
        b.icon:SetVertexColor(spent and 1 or 0.6, spent and 1 or 0.6, spent and 1 or 0.6)
        b.border:SetAtlas(spent and "talents-node-square-yellow" or "talents-node-square-gray", true)
        b.rank:SetText(n.rank .. "/" .. n.maxRanks)
        b.rank:SetTextColor(spent and 1 or 0.6, spent and 0.82 or 0.6, spent and 0 or 0.6)
        b:Show()
        byID[n.id] = b
    end
    window.empty:SetShown(count == 0)
    if count == 0 then return end

    local li = 0
    for _, n in ipairs(layout.nodes) do
        for _, e in ipairs(n.edges) do
            local target = byID[e.target]
            if target then
                li = li + 1
                local l = Line(canvas, li)
                local on = e.active or (n.rank > 0 and target.node.rank > 0)
                l:SetAtlas(on and "talents-arrow-line-yellow" or "talents-arrow-line-gray", false)
                l:SetStartPoint("CENTER", byID[n.id])
                l:SetEndPoint("CENTER", target)
                l:Show()
            end
        end
    end

    for i, t in ipairs(layout.trees) do
        local hd = Header(canvas, i)
        hd:ClearAllPoints()
        hd:SetPoint("CENTER", canvas, "TOPLEFT", HEADER_X + HEADER_STEP * (i - 1), HEADER_Y)
        hd.icon:SetTexture(t.icon or 134400)
        hd.name:SetText(t.name)
        hd.points:SetText(t.points)
        hd:Show()
    end
end

function TalentView.Refresh()
    if not (window and window:IsShown()) then return end
    local unit = InspectUnit()
    local name = unit and ns.Call(UnitName, unit)
    local class = unit and ns.ClassOf(unit)
    window.title:SetText(name and L.talentsOf:format(name) or L.talents)
    if class then window.bg:SetAtlas("talent-background-" .. class:lower(), false) end
    local valid = not C_Traits.HasValidInspectData or ns.Call(C_Traits.HasValidInspectData) ~= false
    Draw(valid and unit and Talents.Layout(Talents.InspectConfigID(), class) or nil)
end

local VIEW_H = VIEW_BOTTOM - VIEW_TOP
local MIN_HEIGHT, MAX_HEIGHT = 300, 1100

local function Rescale(width, height)
    local scale = math.min((width - 2 * MARGIN) / FRAME_W, (height - TITLE_HEIGHT - MARGIN) / VIEW_H)
    if scale <= 0 then return end
    window.canvas:SetScale(scale)
    window.canvas:ClearAllPoints()
    window.canvas:SetPoint("TOPLEFT", window.content, "TOPLEFT", 0, VIEW_TOP)
end

local function Size(height)
    height = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, height))
    local scale = (height - TITLE_HEIGHT - MARGIN) / VIEW_H
    local width = FRAME_W * scale + 2 * MARGIN
    window:SetSize(width, height)
    Rescale(width, height)
end

local function Grip()
    local grip = CreateFrame("Button", nil, window)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() window:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
        local h = window:GetHeight()
        if ns.data then ns.data.talentHeight = math.floor(h + 0.5) end
        Size(h)
        TalentView.Position()
    end)
    window:SetResizable(true)
    if window.SetResizeBounds then window:SetResizeBounds(MIN_HEIGHT, MIN_HEIGHT, 2400, MAX_HEIGHT) end
    window:SetScript("OnSizeChanged", function(_, w, h) Rescale(w, h) end)
end

local function Build(inspect)
    window = CreateFrame("Frame", "SenditGearScoreTalents", inspect, "BackdropTemplate")
    window:Hide()
    window:SetFrameStrata("HIGH")
    window:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                         edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    window:SetBackdropColor(0.04, 0.04, 0.05, 0.97)
    window:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    local bar = CreateFrame("Frame", nil, window)
    bar:SetPoint("TOPLEFT", 4, -2)
    bar:SetPoint("TOPRIGHT", -28, -2)
    bar:SetHeight(TITLE_HEIGHT - 2)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() window:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        if ns.data then ns.data.talentPos = { left = window:GetLeft(), top = window:GetTop() } end
        TalentView.Position()
    end)
    bar:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and ns.data then
            ns.data.talentPos = nil
            TalentView.Position()
        end
    end)
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.talents, 1, 1, 1)
        GameTooltip:AddLine(L.moveHint, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    window.title:SetPoint("TOP", 0, -8)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() TalentView.Toggle(false) end)
    window.content = CreateFrame("Frame", nil, window)
    window.content:SetPoint("TOPLEFT", MARGIN, -TITLE_HEIGHT)
    window.content:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN)
    window.content:SetClipsChildren(true)
    local canvas = CreateFrame("Frame", nil, window.content)
    canvas:SetSize(FRAME_W, VIEW_BOTTOM)
    window.canvas = canvas
    window.bg = canvas:CreateTexture(nil, "BACKGROUND")
    window.bg:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -BG_TOP)
    window.bg:SetPoint("BOTTOMRIGHT", canvas, "TOPLEFT", FRAME_W, -BG_BOTTOM)
    local border = canvas:CreateTexture(nil, "BORDER")
    border:SetAtlas("Talents-inner-frame-c60", false)
    border:SetPoint("TOPLEFT", window.bg, "TOPLEFT", -2, 4)
    border:SetPoint("BOTTOMRIGHT", window.bg, "BOTTOMRIGHT", 2, -4)
    window.empty = window.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.empty:SetPoint("CENTER")
    window.empty:SetText(L.noInspectData)
    Size(500)
    Grip()
    window:SetScript("OnShow", TalentView.Refresh)
    window:SetScript("OnHide", function() if tab then tab:SetChecked(false) end end)
end

local function Place(inspect)
    local last
    local modeTabs = inspect.ModeTabs
    local tabs = type(modeTabs) == "table" and modeTabs.Tabs
    for _, t in ipairs(type(tabs) == "table" and tabs or {}) do
        if t:IsShown() then last = t end
    end
    local tabWidth = 0
    if tab then
        tab:ClearAllPoints()
        if last then
            tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT")
        else
            tab:SetPoint("TOPLEFT", inspect, "TOPRIGHT", 0, -30)
        end
        tabWidth = tab:GetWidth() or 0
    end
    window.dockX = tabWidth + 2
    TalentView.Position()
    Size(ns.data and ns.data.talentHeight or inspect:GetHeight() or 500)
end

function TalentView.Position()
    local pos = ns.data and ns.data.talentPos
    window:ClearAllPoints()
    if type(pos) == "table" and pos.left and pos.top then
        window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.left, pos.top)
    else
        window:SetPoint("TOPLEFT", G("InspectFrame"), "TOPRIGHT", window.dockX or 2, 0)
    end
end

function TalentView.Toggle(show)
    if not window then return end
    if show == nil then show = not window:IsShown() end
    if show then Place(G("InspectFrame")) end
    window:SetShown(show)
    if tab then tab:SetChecked(show) end
end

local function BuildTab(inspect)
    local ok, t = pcall(CreateFrame, "Frame", "SenditGearScoreTalentTab", inspect, "LargeSideTabButtonTemplate")
    if not ok or type(t) ~= "table" or type(t.Icon) ~= "table" then return end
    tab = t
    if tab.SetFillToInterior then tab:SetFillToInterior(true) end
    tab.Icon:SetTexture(TAB_ICON)
    tab:SetChecked(false)
    tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button == "LeftButton" and upInside then TalentView.Toggle() end
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.talents, 1, 1, 1)
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tab:SetScript("OnShow", function() Place(inspect) end)
end

function TalentView.Counts()
    local function n(list)
        local c = 0
        for _, x in ipairs(list) do if x:IsShown() then c = c + 1 end end
        return c
    end
    return n(buttons), n(lines), n(headers)
end

function TalentView.Attach()
    local inspect = G("InspectFrame")
    if not inspect or window then return end
    Build(inspect)
    BuildTab(inspect)
    Place(inspect)
end

Inspect.OnChange(function(guid)
    local unit = InspectUnit()
    if not (window and unit and ns.GUID(unit) == guid) then return end
    Place(G("InspectFrame"))
    TalentView.Refresh()
end)
