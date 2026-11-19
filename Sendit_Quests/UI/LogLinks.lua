--[[
  LogLinks: a small Sendit Quests icon on every quest of Blizzard's quest log
  (QuestScrollFrame's title buttons); a click opens Sendit Quests on that
  quest, at its place in the chain.

  Taint-free: hooksecurefunc on QuestLogQuests_Update only; Blizzard's title
  buttons are read (their questID), never written - our icons live in our own
  table keyed by the button, are our own named frames (EllesmereUI sweeps
  unnamed ones) and only parented to the title button so they move and hide
  with it. Blizzard_WorldMap may load late: attached when it does.

  LogLinks.Refresh() places the icons (the hook calls it).
]]
local _, ns = ...
local T = Sendit.Theme
local LogLinks = {}
ns.LogLinks = LogLinks

local SIZE = 14
local ICON = "Interface\\AddOns\\Sendit_Quests\\Media\\Icon"
local links = setmetatable({}, { __mode = "k" })
local count, hooked = 0, false

local function QuestOf(button)
    local ok, id = pcall(function() return button.questID end)
    if not ok or (issecretvalue and issecretvalue(id)) or type(id) ~= "number" or id <= 0 then return nil end
    return id
end

local function Link(button)
    local link = links[button]
    if link then return link end
    count = count + 1
    link = CreateFrame("Button", "SenditQuestsLogLink" .. count, button)
    link:SetSize(SIZE, SIZE)
    link:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    link:SetFrameLevel(button:GetFrameLevel() + 5)
    link.icon = link:CreateTexture(nil, "ARTWORK")
    link.icon:SetAllPoints()
    link.icon:SetTexture(ICON)
    link:SetAlpha(0.75)
    link:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L.logLink, 1, 0.82, 0, 1, true)
        GameTooltip:Show()
    end)
    link:SetScript("OnLeave", function(self)
        self:SetAlpha(0.75)
        GameTooltip:Hide()
    end)
    link:SetScript("OnClick", function(self)
        if self.questID then ns.Window:OpenQuest(self.questID) end
    end)
    links[button] = link
    return link
end

function LogLinks.Refresh()
    local scroll = _G["QuestScrollFrame"]
    local pool = scroll and scroll.titleFramePool
    if ns.disabled or not pool or type(pool.EnumerateActive) ~= "function" then return end
    for _, link in pairs(links) do link:Hide() end
    for button in pool:EnumerateActive() do
        local id = QuestOf(button)
        if id then
            local link = Link(button)
            link.questID = id
            link:Show()
        end
    end
end

local function Attach()
    if hooked or type(_G["QuestLogQuests_Update"]) ~= "function" then return end
    hooksecurefunc("QuestLogQuests_Update", LogLinks.Refresh)
    hooked = true
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", Attach)
Attach()
