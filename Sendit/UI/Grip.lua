--[[
  Grip: the drawn resize corner of the module windows (three hairlines, gold on hover). The frame must be
  resizable with its bounds set; onDone(width, height) runs after a drag (to store the size).
  Sendit.Widgets.Grip(frame, onDone) -> grip
]]
local _, ns = ...
local T, W = ns.Theme, ns.Widgets

function W.Grip(frame, onDone)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    local lines = {}
    for i = 1, 3 do
        local line = grip:CreateLine(nil, "ARTWORK")
        line:SetTexture(T.WHITE)
        line:SetThickness(1)
        line:SetStartPoint("BOTTOMRIGHT", grip, -2, 2 + i * 4)
        line:SetEndPoint("BOTTOMRIGHT", grip, -2 - i * 4, 2)
        lines[i] = line
    end
    local function Paint(role) for _, l in ipairs(lines) do T.Paint(l, role) end end
    Paint("textMuted")
    grip:SetScript("OnEnter", function() Paint("accent") end)
    grip:SetScript("OnLeave", function() Paint("textMuted") end)
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if onDone then onDone(frame:GetWidth(), frame:GetHeight()) end
    end)
    return grip
end
