--[[
  Commands: /sendit (the window), /sendit profile [name], /sendit <page key>;
  modules add sub commands through Sendit.commands[name] = function(rest) end.
]]
local _, ns = ...

local Profiles, L = ns.Profiles, ns.L

function ns.commands.profile(rest)
    if rest == "" then
        ns.Print(L.ACTIVE_LIST:format(Profiles:Active(), table.concat(Profiles:List(), ", ")))
        return
    end
    local ok, err = Profiles:Use(rest)
    ns.Print(ok and L.USING:format(rest) or err)
end

function ns.commands.help()
    ns.Print(L.HELP)
end

SLASH_SENDIT1 = "/sendit"
SlashCmdList.SENDIT = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then return ns.Options:Toggle() end
    if ns.commands[cmd] then return ns.commands[cmd](rest) end
    if ns.Options:Page(cmd) then return ns.Options:Show(cmd) end
    ns.commands.help()
end
