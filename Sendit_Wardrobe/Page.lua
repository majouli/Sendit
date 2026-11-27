--[[
  Page: the Wardrobe page in the Sendit window - opens the wardrobe and says where its sources
  come from (which other modules add quests, dungeons and auction prices).
]]
local _, ns = ...
local L = ns.L
local O, W = Sendit.Options, Sendit.Widgets
local function Tx(key) return Sendit.Locale.Text(L, key) end

local function Linked()
    local on = {}
    for _, s in ipairs({ { "quests", L.linkQuests }, { "dungeons", L.linkDungeons }, { "auctionPrices", L.linkAuction } }) do
        if Sendit.Service(s[1]) then on[#on + 1] = s[2] end
    end
    return #on > 0 and L.pageLinked:format(table.concat(on, ", ")) or L.pageNoLinks
end

O:Register({
    key = "wardrobe",
    module = ns.module,
    title = Tx("title"),
    subtitle = Tx("pageSubtitle"),
    build = O.SettingsPage(function(Lay, c)
        Lay:Section(Tx("title"))
        Lay:Row(Tx("pageWindow"), Tx("pageWindowDesc"), W.Button(c, L.pageOpen, function()
            O:Hide()
            ns.Window.Open()
        end))
        Lay:EndSection()
        Lay:Note(Linked)
    end),
})
