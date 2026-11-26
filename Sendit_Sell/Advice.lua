--[[
  Advice: where each bag item (every bag, the reagent bag too) is worth most.
    vendor = sell price x stack;  ah = cheapest unit buyout (service "auctionPrices") less UNDERCUT and the
    AH_CUT, x stack, unbound items only;  de = expected mats (service "disenchant"), enchanters, profile switch
  The auction house or disenchanting wins only with margin % and minGain silver over the merchant (profile).
  Actions: "keep" - marked (Sendit_SellCharDB.keep), quest items, keys, no value anywhere, upgrades from
  minUpgrade % (service "upgrade", also from a later level), with a second spec its upgrades and its best
  weapon per kind (Upgrade's WeaponScore, both hands empty);  "use" - consumables, bags, items with a use
  spell;  "mats" - trade goods, reagents, crafting reagents;  else "vendor" | "ah" | "de" | "unknown" (no
  auction price) | "loading". Upgrade answers are cached per link until Upgrade reports a change.
  Advice.For(entry) -> advice;  Advice.Bags() -> { advice } for every filled bag slot
    entry  = { bag, slot, link, itemID, count, bound, noValue, quality }
    advice = entry + { action, reason, vendor, ah, de, equipLoc, useful, material } (copper)
]]
local _, ns = ...
local Advice = {}
ns.Advice = Advice

Advice.AH_CUT = 0.05    -- the auction house keeps 5% of a sale (Classic auction house cut)
Advice.UNDERCUT = 0.05  -- assumption: a listing has to undercut the cheapest one by about 5% to sell
local GREY = 0
local CONSUMABLE, CONTAINER, WEAPON, ARMOR, REAGENT, TRADE_GOODS, QUEST, KEY = 0, 1, 2, 4, 5, 7, 12, 13
local legacySpell = "GetItemSpell"
local KIND = {  -- equip location -> weapon kind for the second spec's best weapons
    INVTYPE_WEAPON = "one", INVTYPE_WEAPONMAINHAND = "one", INVTYPE_2HWEAPON = "two",
    INVTYPE_SHIELD = "off", INVTYPE_HOLDABLE = "off", INVTYPE_WEAPONOFFHAND = "off",
}
local isSecret = issecretvalue or function() return false end

local function Service(name)
    local s = Sendit.Service(name)
    return type(s) == "table" and s or nil
end

local function Pays(other, vendor, p)
    return other and other >= vendor * (1 + (p.margin or 0) / 100) and other - vendor >= (p.minGain or 0) * 100
end

local upgrades = {}  -- link .. "|" .. second spec -> reason | false
local scores = {}    -- link .. "|" .. second spec -> weapon score | false
local hooked = false

local function Gain(r, least)
    return type(r) == "table" and r.status == "ok" and type(r.pct) == "number" and r.pct > 0 and r.pct >= least
end

local function SpecName(up, key)
    for _, s in ipairs(up.Specs and up.Specs() or {}) do
        if s.key == key then return s.name end
    end
    return key
end

local function UpgradeReason(link)
    local up = Service("upgrade")
    if not up then return nil end
    if not hooked and up.OnChange then
        hooked = true
        up.OnChange(function() upgrades, scores = {}, {} end)
    end
    local second, least = ns.module.profile.secondSpec, ns.module.profile.minUpgrade or 0
    local cacheKey = link .. "|" .. tostring(second) .. "|" .. least
    local known = upgrades[cacheKey]
    if known ~= nil then return known or nil end
    local ok, r = pcall(up.Rate, link)
    if ok and type(r) == "table" and r.status == "loading" then return nil end
    local reason = false
    if ok and Gain(r, least) then
        reason = r.gate and ns.L.rUpgradeLater:format(r.gate) or ns.L.rUpgrade
    elseif second and up.RateFor then
        local ok2, r2 = pcall(up.RateFor, link, second)
        if ok2 and Gain(r2, least) then reason = ns.L.rUpgradeFor:format(SpecName(up, second)) end
    end
    upgrades[cacheKey] = reason
    return reason or nil
end

function Advice.For(e)
    local p = ns.module.profile
    local _, _, _, _, _, _, _, _, _, _, sellPrice, _, _, _, _, _, crafting = C_Item.GetItemInfo(e.link)
    if sellPrice == nil then
        e.action = "loading"
        return e
    end
    e.vendor = (sellPrice or 0) * e.count
    if ns.charDB and ns.charDB.keep[e.itemID] then
        e.action, e.reason = "keep", ns.L.rKept
        return e
    end
    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(e.itemID)
    e.equipLoc = equipLoc
    if classID == QUEST or classID == KEY then
        e.action, e.reason = "keep", ns.L.rQuest
        return e
    end
    local upgrade = UpgradeReason(e.link)
    if upgrade then
        e.action, e.reason = "keep", upgrade
        return e
    end
    local spellFn = (C_Item and C_Item.GetItemSpell) or _G[legacySpell]
    local spell = classID ~= WEAPON and classID ~= ARMOR and spellFn and spellFn(e.link)
    local hasUse = type(spell) == "string" and spell ~= ""
    e.useful = classID == CONSUMABLE or classID == CONTAINER or hasUse
    e.material = classID == TRADE_GOODS or classID == REAGENT or crafting == true
    local prices = Service("auctionPrices")
    local unit = not e.bound and prices and prices.Get(e.itemID)
    if unit then e.ah = math.floor(unit * (1 - Advice.UNDERCUT) * e.count * (1 - Advice.AH_CUT)) end
    local de = Service("disenchant")
    if p.disenchant and de and de.Knows() then
        local ok, value, priced = pcall(de.Value, e.link)
        if ok and priced and type(value) == "number" and value > 0 then e.de = math.floor(value) end
    end
    local best, bestValue = "vendor", e.vendor
    if Pays(e.ah, e.vendor, p) then best, bestValue = "ah", e.ah end
    if Pays(e.de, e.vendor, p) and e.de > bestValue then best = "de" end
    if e.useful then
        e.action = "use"
    elseif e.material then
        e.action = "mats"
    elseif best ~= "vendor" then
        e.action = best
    elseif e.vendor > 0 and (e.ah or e.bound or e.quality == GREY) then
        e.action = "vendor"
        if e.bound then e.reason = ns.L.rBound end
    elseif e.vendor == 0 and e.ah and e.ah > 0 then
        e.action = "ah"
    elseif e.vendor == 0 then
        e.action, e.reason = "keep", ns.L.rNoValue
    else
        e.action = "unknown"
    end
    return e
end

-- the second spec's best weapon of each kind among the bag items (weighed with both hands empty)
local function KeepBestWeapons(list)
    local second, up = ns.module.profile.secondSpec, Service("upgrade")
    if not second or not up or not up.WeaponScore then return end
    local best = {}
    for _, e in ipairs(list) do
        local kind = e.action ~= "keep" and e.action ~= "loading" and KIND[e.equipLoc or ""]
        if kind then
            local key = e.link .. "|" .. second
            local score = scores[key]
            if score == nil then
                local ok, v, status = pcall(up.WeaponScore, e.link, second)
                score = ok and type(v) == "number" and v or (ok and status == "loading" and nil) or false
                if score ~= nil then scores[key] = score end
            end
            if score and score > 0 and (not best[kind] or score > best[kind].score) then
                best[kind] = { e = e, score = score }
            end
        end
    end
    local name = SpecName(up, second)
    for _, b in pairs(best) do
        b.e.action, b.e.reason = "keep", ns.L.rBestFor:format(name)
    end
end

function Advice.Bags()
    local out = {}
    -- every equipped bag, the reagent bag too (it holds the crafting materials)
    local last = _G["NUM_TOTAL_EQUIPPED_BAG_SLOTS"] or ((_G["NUM_BAG_SLOTS"] or 4) + 1)
    for bag = 0, last do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and info.hyperlink
            if link and not isSecret(link) then
                out[#out + 1] = Advice.For({
                    bag = bag, slot = slot, link = link, itemID = info.itemID, count = info.stackCount or 1,
                    bound = info.isBound == true, noValue = info.hasNoValue == true, quality = info.quality,
                })
            end
        end
    end
    KeepBestWeapons(out)
    return out
end
