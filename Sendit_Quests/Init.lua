--[[
  Init: registers the Quests tool with Sendit. Account layout stores window
  dimensions; the bundled reference is immutable, progress belongs to the
  client. /sq [name or ID] opens the independent browser; /sq boost prints
  why the gear boost list looks as it does.
]]
local _, ns = ...
ns.names = {}
ns.objectives = {}
ns.searchText = {}
ns.searchIds = {}
ns.module = Sendit:RegisterModule({
    key = "quests", title = "Quests", addon = "Sendit_Quests",
    icon = "Interface\\AddOns\\Sendit_Quests\\Media\\Icon",
    accountDefaults = { width = 960, height = 720, boostMin = 1, boostLocked = true, route = true },
})
SLASH_SENDITQUESTS1 = "/sq"
-- /sq boost: why the gear boost list looks as it does (diagnostics, English)
SlashCmdList.SENDITQUESTS = function(query)
    if query and query:lower():match("^%s*boost%s*$") then
        for _, line in ipairs(ns.Boost.Report()) do print("|cff66c2ffSendit Quests|r: " .. line) end
        return
    end
    ns.Window:Open(query)
end
Sendit.OnModuleSwitch(function(addon, on)
    if addon ~= "Sendit_Quests" then return end
    ns.disabled = not on
    if not on then
        ns.Window:Hide()
        if ns.questButton then ns.questButton:Hide() end
    elseif ns.questButton then
        ns.questButton:Show()
    end
end)
