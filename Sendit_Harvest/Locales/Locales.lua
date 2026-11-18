local _, ns = ...

ns.LANGUAGES = {
    { code = "deDE", name = "Deutsch" },
    { code = "enUS", name = "English" },
    { code = "frFR", name = "Français" },
    { code = "esES", name = "Español" },
    { code = "ruRU", name = "Русский" },
}

local Locales = {}
ns.Locales = Locales

local CLIENT_TO_MENU = { enGB = "enUS", esMX = "esES" }
local override

local function Resolve(code)
    if code == "auto" or not Locales[code] then
        local game = GetLocale and GetLocale() or "deDE"
        code = CLIENT_TO_MENU[game] or game
    end
    return Locales[code] and code or "enUS"
end

local function Current()
    return Resolve(override or (Sendit.Locale and Sendit.Locale.Code()) or "auto")
end

function ns.SetLanguage(code)
    override = code ~= "auto" and code or nil
end

function ns.Language() return Current() end

local function NameColumn()
    local current = Current()
    for i, lang in ipairs(ns.ItemNameLanguages or {}) do
        if lang == current then return i end
    end
    return 1
end

ns.L = setmetatable({}, {
    __index = function(_, key)
        local v = Locales[Current()][key]
        if v == nil then v = Locales.enUS[key] end
        if v == nil then v = Locales.deDE[key] end
        return v
    end,
})

function ns.ItemName(id)
    local names = ns.ItemNames and ns.ItemNames[id]
    local name = names and names[NameColumn()]
    return name ~= "" and name or nil
end

ns.ClientNames = {
    professions = {
        disenchant = { "Verzauberkunst", "Enchanting", "Enchantement", "Encantamiento", "Наложение чар" },
        skinning   = { "Kürschnerei", "Skinning", "Dépeçage", "Desuello", "Снятие шкур" },
        mining     = { "Bergbau", "Mining", "Minage", "Minería", "Горное дело" },
        herbalism  = { "Kräuterkunde", "Herbalism", "Herboristerie", "Herboristería", "Травничество" },
    },
    beasts = { ["Wildtier"] = true, ["Beast"] = true, ["Bête"] = true, ["Bestia"] = true, ["Животное"] = true },
}
