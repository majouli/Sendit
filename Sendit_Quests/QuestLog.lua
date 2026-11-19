--[[
  QuestLog: an owned button just below the modern quest-log pane opens the
  latest explicitly viewed/tracked quest. Blizzard's GetSelectedQuest retains
  an old detail quest when tracking changes, so secure post-hooks remember
  the IDs passed to those actions in our own namespace. No foreign
  frame fields/scripts are modified. Late-loaded Blizzard UI is supported;
  combat defers attachment. No dependence on another quest addon.
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
    -- Mixins are copied onto existing frames; hook both load orders.
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
    -- Named boundary: other UI addons must not mistake this for Blizzard UI.
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
