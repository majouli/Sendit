--[[
  Highlight: outlines one element with its label (list hover, overlay jump); keeps it visible.
]]
local _, ns = ...

local Highlight = {}
ns.Highlight = Highlight

local T, Safe = ns.Theme, ns.Safe

local box = CreateFrame("Frame", nil, UIParent)
ns.ownFrames[box] = true
box:SetFrameStrata("TOOLTIP")
box:EnableMouse(false)
box:Hide()

T.Fill(box, "accent", "BACKGROUND", 0, 0.18):SetAllPoints()
T.Border(box, "accent")

local tag = CreateFrame("Frame", nil, box)
tag:SetHeight(20)
tag:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 2)
T.Fill(tag, "accent", "BACKGROUND"):SetAllPoints()
local tagText = T.Text(tag, "label", "onAccent")
T.NoShadow(tagText)
tagText:SetPoint("LEFT", 6, 0)

local current, peekAcc = nil, 0
box:SetScript("OnUpdate", function(_, elapsed)
    peekAcc = peekAcc + elapsed
    if current and peekAcc > 0.2 then
        peekAcc = 0
        ns.Fader:Peek(current.frame, 0.5)
    end
end)

function Highlight:Show(e)
    local l, b, w, h = Safe.Rect(e.frame)
    if not l then return self:Hide() end
    box:ClearAllPoints()
    box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
    box:SetSize(math.max(w, 6), math.max(h, 6))
    tagText:SetText(e.label)
    tag:SetWidth(tagText:GetStringWidth() + 12)
    current = e
    ns.Fader:Peek(e.frame, 0.5)
    box:Show()
end

function Highlight:Hide()
    current = nil
    box:Hide()
end

function Highlight:Flash(e, seconds)
    self:Show(e)
    C_Timer.After(seconds or 2, function()
        if current == e then self:Hide() end
    end)
end
