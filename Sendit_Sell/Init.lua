--[[
  Init: registers the Sell module - at a merchant, which bag items to sell there and which are worth more on
  the auction house (or disenchanted). Prices: Sendit Upgrade's auction prices (service "auctionPrices"),
  disenchanting: Sendit Harvest (service "disenchant"), upgrades kept: Sendit Upgrade (service "upgrade").
  Profile: autoOpen (the list opens at a merchant), margin (% the auction house must bring above the
  merchant), minGain (silver it must bring at least), disenchant (suggest it to an enchanter), secondSpec
  (a spec key of the class whose upgrades are kept too; nil = none), minUpgrade (% from which an upgrade is
  kept).
  Character data Sendit_SellCharDB: keep = { [itemID] = true } (items marked to keep). /sell toggles the list.
  ns.Money(copper) -> the client's coin text
]]
local _, ns = ...
ns.ICON = "Interface\\Icons\\INV_Misc_Coin_02"
ns.module = Sendit:RegisterModule({
    key = "sell", title = "Sell", addon = "Sendit_Sell",
    icon = ns.ICON,
    defaults = { autoOpen = true, margin = 30, minGain = 50, disenchant = true, minUpgrade = 1 },
})

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= "Sendit_Sell" then return end
    self:UnregisterEvent("ADDON_LOADED")
    Sendit_SellCharDB = Sendit_SellCharDB or {}
    Sendit_SellCharDB.keep = Sendit_SellCharDB.keep or {}
    ns.charDB = Sendit_SellCharDB
end)

local legacyCoins = "GetCoinTextureString"

function ns.Money(copper)
    copper = math.max(0, math.floor(copper or 0))
    local fn = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or _G[legacyCoins]
    if fn then return fn(copper) end
    return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

SLASH_SENDITSELL1 = "/sell"
SlashCmdList.SENDITSELL = function() if ns.Window then ns.Window.Toggle() end end
