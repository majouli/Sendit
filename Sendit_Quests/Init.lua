--[[
  Init: registers Quests; ns.Read (safe client call). Account: window size, boost and route settings.
  /sq [name or ID] opens the browser, /sq boost prints the boost diagnostics.
]]
local _, ns = ...
ns.names = {}
ns.objectives = {}
ns.searchText = {}
ns.searchIds = {}

-- a client call's values, or nil when it fails or any value is secret (Forever)
function ns.Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok then return nil end
    if issecretvalue then
        for i = 1, 6 do if issecretvalue((select(i, a, b, c, d, e, f))) then return nil end end  -- nil holes too
    end
    return a, b, c, d, e, f
end
ns.module = Sendit:RegisterModule({
    key = "quests", title = "Quests", addon = "Sendit_Quests",
    icon = "Interface\\AddOns\\Sendit_Quests\\Media\\Icon",
    accountDefaults = { width = 960, height = 720, boostMin = 1, boostLocked = true, boostAhead = 0, route = true },
})
SLASH_SENDITQUESTS1 = "/sq"
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
