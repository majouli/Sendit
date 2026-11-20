--[[
  Commands: /chat - messages list; settings, reset (window positions), probe, trace, ids (diagnostics,
  English), off | on (after /reload).
]]
local _, ns = ...
local L = ns.L

SLASH_SENDITCHAT1 = "/chat"
SlashCmdList.SENDITCHAT = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "off" or cmd == "on" then
        if ns.acct then ns.acct.enabled, ns.acct.keepOther = cmd == "on", nil end
        ns.Print(cmd == "on" and L.TURNED_ON or L.TURNED_OFF)
    elseif cmd == "settings" then
        ns.OpenSettings()
    elseif cmd == "help" or cmd == "?" then
        ns.Print(L.HELP)
    elseif not ns.active then
        ns.Print(ns.yielding and L.YIELD:format(ns.Conflict.Title(ns.yielding)) or L.DISABLED)
    elseif cmd == "probe" then
        ns.Probe.Run()
    elseif cmd == "trace" then
        ns.Trace.Start(150)
        ns.Print("trace: recording the next 150 lines - /reload afterwards")
    elseif cmd == "ids" then
        local shared = ns.Mirror.SharedIDs()
        ns.Print(("%d shared chat type ids"):format(#shared))
        for _, e in ipairs(shared) do
            local parts = {}
            for _, t in ipairs(e[2]) do parts[#parts + 1] = t .. "=" .. tostring(ns.ChatKinds.KeyOf(t)) end
            ns.Print(("id %d: %s"):format(e[1], table.concat(parts, ", ")))
        end
    elseif cmd == "reset" then
        ns.acct.messenger = {}
        ns.Windows.Reset()
        ns.Print(L.RESET_DONE)
    else
        ns.Messenger.Toggle()
    end
end
