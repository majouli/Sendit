--[[
  ToggleIcon: a small round on-screen button, never faded itself.
    left-click   fading on / off (grey icon = off)
    right-click  settings
    drag         move (unless locked); position saved in db.icon.point
  Rests at db.icon.alpha, fully visible under the mouse.
]]
local _, ns = ...

local ToggleIcon = {}
ns.ToggleIcon = ToggleIcon  -- .button once created

local T, W = ns.Theme, ns.Widgets

local SIZE = 32
local DEFAULT_POINT = { "TOP", "TOP", 0, -120 }
local CLICK_AFTER_DRAG = 0.2  -- a click this soon after a drag is the drag's mouse-up

local button

local function ShowTooltip(self)
    self:SetAlpha(1)
    local L = ns.L
    local hints = { L.ICON_LEFT, L.ICON_RIGHT }
    if not ns.db.icon.locked then hints[#hints + 1] = L.ICON_DRAG end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Sendit Fade", T.Color("accent"))
    GameTooltip:AddLine(ns.profile.enabled and L.ICON_ON or L.ICON_OFF, T.Color("text"))
    local r, g, b = T.Color("textDim")
    for _, hint in ipairs(hints) do GameTooltip:AddLine(hint, r, g, b) end
    GameTooltip:Show()
end

local function HideTooltip(self)
    self:SetAlpha(ns.db.icon.alpha)
    GameTooltip:Hide()
end

local function Create()
    button = CreateFrame("Button", nil, UIParent)
    ToggleIcon.button = button
    ns.ownFrames[button] = true
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("HIGH")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    T.Circle(button, "panel", SIZE, "BACKGROUND"):SetPoint("CENTER")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(ns.ICON)
    button.icon:SetSize(SIZE - 6, SIZE - 6)
    button.icon:SetPoint("CENTER")
    T.RoundOff(button.icon)
    local hover = T.Circle(button, "hover", SIZE, "HIGHLIGHT")
    hover:SetPoint("CENTER")

    button:SetScript("OnClick", function(_, mouse)
        if button.droppedAt and GetTime() - button.droppedAt < CLICK_AFTER_DRAG then return end
        if mouse == "RightButton" then
            ns.OpenSettings()
        else
            ns.commands.toggle()
        end
    end)
    W.Movable(button, button, {
        store = ns.db.icon, key = "point", default = DEFAULT_POINT,
        canMove = function() return not ns.db.icon.locked end,
        onDrop = function() button.droppedAt = GetTime() end,
    })
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", HideTooltip)
end

ns.OnSettingsChanged(function()
    if not ns.db then return end
    local show = ns.db.icon.show and not ns.switchedOff
    if not button then
        if not show then return end
        Create()
    end
    button:SetShown(show)
    button:SetAlpha(button:IsMouseOver() and 1 or ns.db.icon.alpha)
    button.icon:SetDesaturated(not ns.profile.enabled)
end)
