--[[
  Init: registers Dungeons. Account: window size, filter, boost threshold and range.
  /sd [name] opens the browser, /sd boost prints the boost diagnostics.
]]
local _, ns = ...
ns.module = Sendit:RegisterModule({
    key = "dungeons", title = "Dungeons", addon = "Sendit_Dungeons",
    icon = "Interface\\AddOns\\Sendit_Dungeons\\Media\\Icon",
    accountDefaults = { width = 980, height = 700, filter = "all", boostMin = 1, boostAhead = 0 },
})
SLASH_SENDITDUNGEONS1 = "/sd"
SlashCmdList.SENDITDUNGEONS = function(query)
    if query and query:lower():match("^%s*boost%s*$") then
        for _, line in ipairs(ns.Boost.Report()) do print("|cff66c2ffSendit Dungeons|r: " .. line) end
        return
    end
    ns.Window:Open(query)
end
Sendit.OnModuleSwitch(function(addon, on)
    if addon ~= "Sendit_Dungeons" then return end
    ns.disabled = not on
    if not on then ns.Window:Hide() end
end)
