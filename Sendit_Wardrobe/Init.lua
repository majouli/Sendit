--[[
  Init: registers the Wardrobe module, its launcher and /wardrobe [search | probe]; ns.Read (safe client call),
  ns.Join(...) (detail texts without the missing parts).
  Account (Sendit): window size and the browse filter. Sendit_WardrobeDB (own saved variables):
  { outfits = { { name, items = { [slot] = itemID } } }, learned = { [itemID] = raw } } - the player's
  saved outfits and the looks learned from the auction data (Learn.lua).
]]
local _, ns = ...
ns.names = {}
ns.ICON = "Interface\\Icons\\INV_Shirt_White_01"

-- a client call's values, or nil when it fails or any value is secret
function ns.Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    if issecretvalue then
        for i = 1, 4 do if issecretvalue((select(i, a, b, c, d))) then return nil end end
    end
    return a, b, c, d
end

-- the given texts that are set (nil and "" skipped), joined by " · "
function ns.Join(...)
    local out = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil and v ~= "" then out[#out + 1] = tostring(v) end
    end
    return table.concat(out, "  ·  ")
end

ns.module = Sendit:RegisterModule({
    key = "wardrobe", title = "Wardrobe", addon = "Sendit_Wardrobe", icon = ns.ICON,
    accountDefaults = { width = 1240, height = 740,
        filter = { tab = "sets", slot = "all", armor = "mine", source = "all", have = "all" } },
})

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, addon)
    if addon ~= "Sendit_Wardrobe" then return end
    self:UnregisterEvent("ADDON_LOADED")
    Sendit_WardrobeDB = type(Sendit_WardrobeDB) == "table" and Sendit_WardrobeDB or {}
    Sendit_WardrobeDB.outfits = type(Sendit_WardrobeDB.outfits) == "table" and Sendit_WardrobeDB.outfits or {}
    ns.store = Sendit_WardrobeDB
    ns.Learn.Restore()
end)

Sendit:AddLauncher({
    module = ns.module,
    key = "wardrobe", order = 45, icon = ns.ICON, title = function() return ns.L.title end,
    toggle = function() ns.Window.Toggle() end,
    shown = function() return ns.Window.Shown() end,
})

SLASH_SENDITWARDROBE1 = "/wardrobe"
SLASH_SENDITWARDROBE2 = "/swr"
SlashCmdList.SENDITWARDROBE = function(text)
    if text and strtrim(text):lower() == "probe" then
        for _, line in ipairs(ns.Window.Probe()) do print("|cff66c2ffSendit Wardrobe|r: " .. line) end
        return
    end
    ns.Window.Open()
    if text and strtrim(text) ~= "" then ns.Window.Search(strtrim(text)) end
end
