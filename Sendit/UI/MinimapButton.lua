--[[
  MinimapButton: the suite's minimap button (drag to move); left click the window, right click the
  modules' quick switches; also the addon compartment entry.
  Sendit:AddQuickToggle{ label, get, set(on) };  tooltip lines from module.status()
]]
local _, ns = ...

local T, W, L = ns.Theme, ns.Widgets, ns.L
local Resolve = ns.Locale.Resolve
local button
local toggles = {}

function ns:AddQuickToggle(def)
    toggles[#toggles + 1] = def
end

local function UpdatePosition()
    local angle = math.rad(ns.db.minimap.angle or 200)
    local radius = (Minimap:GetWidth() / 2) + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
    UpdatePosition()
end

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("Sendit", T.Color("accent"))
    local r, g, b = T.Color("text")
    for _, m in ipairs(ns.modules) do
        local status = m.status and m.status()
        if status then GameTooltip:AddDoubleLine(Resolve(m.title), status, r, g, b, r, g, b) end
    end
    r, g, b = T.Color("textDim")
    GameTooltip:AddLine(L.TIP_LEFT, r, g, b)
    if #toggles > 0 then GameTooltip:AddLine(L.TIP_RIGHT, r, g, b) end
    GameTooltip:AddLine(L.TIP_DRAG, r, g, b)
    GameTooltip:Show()
end

local function QuickMenu(anchor)
    local options = {}
    for i, t in ipairs(toggles) do
        options[i] = { i, ("%s: %s"):format(Resolve(t.label), t.get() and L.ON or L.OFF) }
    end
    W.ShowMenu(anchor, options, nil, function(i)
        local t = toggles[i]
        t.set(not t.get())
        ns.SettingsChanged()
    end)
end

local function OnClick(self, mouse)
    if mouse == "RightButton" and #toggles > 0 then
        QuickMenu(self or button)
    else
        ns.Options:Toggle()
    end
end

local function Create()
    -- named: minimap button collectors find it
    button = CreateFrame("Button", "SenditMinimapButton", Minimap)
    ns.ownFrames[button] = true
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(ns.ICON)
    button.icon:SetSize(17, 17)
    button.icon:SetPoint("TOPLEFT", 7, -6)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", OnClick)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    UpdatePosition()
end

ns.OnSettingsChanged(function()
    if not ns.db then return end
    if not button then
        if ns.db.minimap.hide then return end
        Create()
    end
    button:SetShown(not ns.db.minimap.hide)
end)

-- global: the .toc names it
function Sendit_OnAddonCompartmentClick(_, mouse)
    OnClick(nil, mouse)
end
