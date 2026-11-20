--[[
  Fonts: font families for every alphabet (a font file covers one: a deDE client's roman Friz has no
  Cyrillic). Fonts.Set builds a family per size: roman = the given file, the other alphabets from the
  base object's family; without CreateFontFamily the plain file. Cached per file, size and base.
  Fonts.Set(obj, size, file, base) - also Theme.SetFont
]]
local _, ns = ...

local Fonts = {}
ns.Fonts = Fonts

local function GameFont()
    local path = GameFontNormal and GameFontNormal:GetFont()
    return path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local ALPHABETS = { "roman", "korean", "simplifiedchinese", "traditionalchinese", "russian" }
local FALLBACK = { russian = "Fonts\\FRIZQT___CYR.TTF" }
local families, familyCount = {}, 0

local function AlphabetFile(base, alphabet)
    if not (base and base.GetFontObjectForAlphabet) then return FALLBACK[alphabet] end
    local ok, obj = pcall(base.GetFontObjectForAlphabet, base, alphabet)
    local file = ok and type(obj) == "table" and obj.GetFont and obj:GetFont()
    return file or FALLBACK[alphabet]
end

local function Family(file, size, base)
    local key = file .. "|" .. size .. "|" .. tostring(base)
    if families[key] ~= nil then return families[key] end
    local create = _G["CreateFontFamily"]
    local family = false ---@type Font|false
    if create then
        local members = {}
        for _, alphabet in ipairs(ALPHABETS) do
            local f = alphabet == "roman" and file or AlphabetFile(base, alphabet)
            if f then members[#members + 1] = { alphabet = alphabet, file = f, height = size, flags = "" } end
        end
        familyCount = familyCount + 1
        local ok, obj = pcall(create, "SenditFont" .. familyCount, members)
        family = ok and obj or false
    end
    families[key] = family
    return family
end

function Fonts.Set(obj, size, file, base)
    file = file or GameFont()
    local family = Family(file, size, base or GameFontNormal)
    if family then obj:SetFontObject(family) else obj:SetFont(file, size, "") end
end
