--[[
  QuestLog: remembers the quest last viewed / tracked in Blizzard's quest log (post-hooks; Blizzard's
  GetSelectedQuest keeps an old one) and adds our "Sendit - chain" button below the log.
  No fields or scripts of Blizzard's frames are written; combat defers attaching.
]]
local _, ns = ...
local lastSelection
local hooked = {}
local function Remember(id)
    if issecretvalue and issecretvalue(id) then return end
    if type(id) == "number" and id > 0 then
        lastSelection = id
        if ns.LogRoute then ns.LogRoute.Show(id) end
    end
end
local function Hooks()
    for _, name in ipairs({ "QuestMapFrame_ShowQuestDetails", "QuestMapQuestOptions_TrackQuest" }) do
        if not hooked[name] and type(_G[name]) == "function" then
            hooksecurefunc(name, Remember)
            hooked[name] = true
        end
    end
    local api = _G["C_SuperTrack"]
    if not hooked.super and api and type(api.SetSuperTrackedQuestID) == "function" then
        hooksecurefunc(api, "SetSuperTrackedQuestID", Remember)
        hooked.super = true
    end
    for _, name in ipairs({ "QuestLogPopupDetailMixin", "QuestLogPopupDetailFrame" }) do
        local popup = _G[name]
        if not hooked[name] and popup then
            local ok = pcall(hooksecurefunc, popup, "ShowQuest", function(_, id) Remember(id) end)
            if ok then hooked[name] = true end
        end
    end
end
local function Attach()
    Hooks()
    if ns.questButton or ns.disabled or InCombatLockdown() then return end
    local parent = _G["QuestMapFrame"]
    if not parent then return end
    local holder = CreateFrame("Frame", "SenditQuestsQuestLogEntry", parent)
    holder:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 4, -4)
    Sendit.ownFrames[holder] = true
    local b = Sendit.Widgets.Button(holder, "Sendit · " .. ns.L.chain, function()
        ns.Window:OpenQuest(lastSelection or ns.Progress.Selected())
    end)
    b:SetPoint("TOPLEFT")
    holder:SetSize(b:GetWidth(), b:GetHeight())
    ns.questButton = b
    Sendit.ownFrames[b] = true
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", Attach)
Sendit.OnSettingsChanged(function()
    if ns.questButton then
        ns.questButton:SetLabel("Sendit · " .. ns.L.chain)
        ns.questButton:GetParent():SetWidth(ns.questButton:GetWidth())
    end
end)
