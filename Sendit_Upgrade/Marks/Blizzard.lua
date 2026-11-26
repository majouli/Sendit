--[[
  Blizzard: green upgrade arrows on Blizzard's own item buttons - bags (each container frame's
  UpdateItems), loot (the loot list's elements), loot rolls (GroupLootFrame_SetupItemDisplay), the
  merchant (MerchantFrame_UpdateMerchantInfo) and quest rewards (QuestInfo_ShowRewards, the quest
  frame's and the map's). Only post-hooks and reads; the arrows are our own frames (Arrow.lua).
  Source: the client's UI code (game type camelot, mainline family), checked 2026-11-26.
]]
local _, ns = ...
local Arrow = ns.Arrow
local isSecret = issecretvalue or function() return false end

local function Plain(link) return type(link) == "string" and not isSecret(link) and link or nil end

local function Bags(frame)
    if not frame.EnumerateValidItems then return end
    for _, button in frame:EnumerateValidItems() do
        Arrow.Mark(button, Plain(C_Container.GetContainerItemLink(button:GetBagID(), button:GetID())))
    end
end

local function HookBags()
    local frames = { _G["ContainerFrameCombinedBags"] }
    for i = 1, _G["NUM_CONTAINER_FRAMES"] or 13 do frames[#frames + 1] = _G["ContainerFrame" .. i] end
    for _, frame in ipairs(frames) do
        if type(frame) == "table" and frame.UpdateItems then hooksecurefunc(frame, "UpdateItems", Bags) end
    end
end

local function Loot()
    local box = _G["LootFrame"] and _G["LootFrame"].ScrollBox
    if not (box and box.ForEachFrame) then return end
    box:ForEachFrame(function(element)
        if element.Item and element.GetSlotIndex then
            Arrow.Mark(element.Item, Plain(GetLootSlotLink(element:GetSlotIndex())))
        end
    end)
end

local function Roll(frame)
    if frame and frame.IconFrame and frame.rollID then
        Arrow.Mark(frame.IconFrame, Plain(GetLootRollItemLink(frame.rollID)))
    end
end

local function Merchant()
    for i = 1, _G["MERCHANT_ITEMS_PER_PAGE"] or 10 do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then Arrow.Mark(button, button:IsShown() and Plain(button.link) or nil) end
    end
end

local function Rewards()
    local log = _G["QuestInfoFrame"] and _G["QuestInfoFrame"].questLog
    for _, name in ipairs({ "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }) do
        local frame = _G[name]
        for _, button in ipairs(frame and frame.RewardButtons or {}) do
            local link
            if button:IsShown() and button.objectType == "item" and button.type then
                link = log and GetQuestLogItemLink(button.type, button:GetID()) or GetQuestItemLink(button.type, button:GetID())
            end
            Arrow.Mark(button, Plain(link))
        end
    end
end

local function Hook(name, fn)
    if type(_G[name]) == "function" then hooksecurefunc(name, fn) end
end

HookBags()
Hook("GroupLootFrame_SetupItemDisplay", Roll)
Hook("MerchantFrame_UpdateMerchantInfo", Merchant)
Hook("QuestInfo_ShowRewards", Rewards)

local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("LOOT_SLOT_CHANGED")
events:SetScript("OnEvent", function() C_Timer.After(0, Loot) end)
