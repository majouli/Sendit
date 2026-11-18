--[[
  Init: registers the Dungeons tool with Sendit. Account layout stores the
  window size, the list filter and the gear boost threshold and range; the bundled
  dungeon data is immutable. /sd [name] opens the browser, /sd boost prints
  why the boost list looks as it does (diagnostics, English).
]]
local _, ns = ...
ns.module = Sendit:RegisterModule({
    key = "dungeons", title = "Dungeons", addon = "Sendit_Dungeons",
    icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
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
