--[[
  Commands: /chat
    (no args)  messages list
    settings   the Chat page of the Sendit window
    reset      default window positions
    probe      records the chat input's visibility for a few seconds
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
    elseif cmd == "reset" then
        ns.acct.messenger = {}
        ns.Windows.Reset()
        ns.Print(L.RESET_DONE)
    else
        ns.Messenger.Toggle()
    end
end
