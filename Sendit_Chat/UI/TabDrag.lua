--[[
  TabDrag: while a tab is dragged its name follows the cursor and the target window lights up
  (alpha and position only).  TabDrag.Start(text, targetOf) / Stop()
]]
local _, ns = ...
local T = ns.Theme

local TabDrag = {}
ns.TabDrag = TabDrag

local ghost, glow, targetOf

local function Build()
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetHeight(24)
    ghost.bg = T.Tex(ghost, "BACKGROUND", "header", 0.95)
    ghost.bg:SetAllPoints()
    T.Border(ghost, 1, "accent", 0.8)
    ghost.text = T.Text(ghost, 11, "text")
    ghost.text:SetPoint("CENTER", 0, 1)
    ghost.line = T.Tex(ghost, "ARTWORK", "accent", 1)
    ghost.line:SetHeight(2)
    ghost.line:SetPoint("BOTTOMLEFT", 6, 0)
    ghost.line:SetPoint("BOTTOMRIGHT", -6, 0)
    ghost:Hide()

    glow = CreateFrame("Frame", nil, UIParent)
    glow:SetFrameStrata("HIGH")
    glow.fill = T.Tex(glow, "OVERLAY", "accent", 0.10)
    glow.fill:SetAllPoints()
    T.Border(glow, 1, "accent", 0.9)
    glow:Hide()

    ghost:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s + 8, y / s - 12)
        local target = targetOf and targetOf()
        if target then
            glow:ClearAllPoints()
            glow:SetAllPoints(target)
            glow:Show()
        else
            glow:Hide()
        end
    end)
end

function TabDrag.Start(text, fn)
    if not ghost then Build() end
    targetOf = fn
    ghost.text:SetText(text)
    ghost:SetWidth(math.floor((ghost.text:GetStringWidth() or 40) + 22))
    ghost:Show()
end

function TabDrag.Stop()
    if not ghost then return end
    ghost:Hide()
    glow:Hide()
    targetOf = nil
end
