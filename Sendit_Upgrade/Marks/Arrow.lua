--[[
  Arrow: the green "upgrade" arrow in an item button's top right corner - Blizzard's own bag upgrade
  arrow where the client has it, else its green stream arrow turned upwards. Frames are named (UI suites
  sweep unnamed frames inside Blizzard windows) and kept in our own table, never as a field on the button.
  Arrow.Mark(target, link): the arrow on target (an item button or an icon frame) for the item, shown
  once Verdict says it is an upgrade; nil link clears it. Arrow.Make(parent) -> a loose arrow frame
  (for bag addons that place it themselves). Arrow.Repaint() after a verdict or a reset.
]]
local _, ns = ...
local Verdict = ns.Verdict
local Arrow = {}
ns.Arrow = Arrow

local SIZE, ATLAS, FALLBACK = 14, "bags-greenarrow", "Interface\\Buttons\\UI-MicroStream-Green"
local arrows = setmetatable({}, { __mode = "k" })  -- target -> { frame, link }
local count = 0

local function HasAtlas()
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ATLAS)
    return info ~= nil
end

function Arrow.Make(parent)
    count = count + 1
    local f = CreateFrame("Frame", "SenditUpgradeArrow" .. count, parent)
    f:SetSize(SIZE, SIZE)
    f:SetFrameLevel(parent:GetFrameLevel() + 5)
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    if HasAtlas() then
        tex:SetAtlas(ATLAS)
    else
        tex:SetTexture(FALLBACK)
        tex:SetTexCoord(0, 1, 1, 0)  -- the stream arrow points down
    end
    f:Hide()
    return f
end

local function Paint(target, entry)
    entry.frame:SetShown(entry.link ~= nil and Verdict.Of(entry.link) == true)
end

function Arrow.Mark(target, link)
    if not target then return end
    local entry = arrows[target]
    if not entry then
        if not link then return end
        local frame = Arrow.Make(target)
        frame:SetPoint("TOPRIGHT", target, "TOPRIGHT", -1, -1)
        entry = { frame = frame }
        arrows[target] = entry
    end
    entry.link = link
    Paint(target, entry)
end

function Arrow.Repaint(link)
    for target, entry in pairs(arrows) do
        if not link or entry.link == link then Paint(target, entry) end
    end
end

Verdict.OnReady(Arrow.Repaint)
Verdict.OnReset(function() Arrow.Repaint() end)
