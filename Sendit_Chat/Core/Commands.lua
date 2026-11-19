--[[
  Commands: /chat
    (no args)  messages list
    settings   the Chat page of the Sendit window
    reset      default window positions
    probe      records the chat input's visibility for a few seconds
    trace      records how the next 150 lines are sorted into tabs
               (SavedVariables, read after /reload; diagnostic, English)
    ids        chat types that share one type id, and the kind each line
               type resolves to (diagnostic, English)
    off | on   turn Sendit Chat off / on (takes effect after /reload; the client
               does not let addons reload the UI)
]]
local _, ns = ...
local L = ns.L

SLASH_SENDITCHAT1 = "/chat"
SlashCmdList.SENDITCHAT = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "off" or cmd == "on" then
        if ns.acct then ns.acct.enabled = cmd == "on" end
        ns.Print(cmd == "on" and L.TURNED_ON or L.TURNED_OFF)
    elseif cmd == "settings" then
        ns.OpenSettings()
    elseif cmd == "help" or cmd == "?" then
        ns.Print(L.HELP)
    elseif not ns.active then
        ns.Print(ns.yielding and L.YIELD_EUI or L.DISABLED)
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
