--[[
  Fonts: font families for every alphabet. A font FILE covers one alphabet:
  the roman Friz of a deDE client has no Cyrillic, so "Русский" showed as
  boxes. Blizzard's font objects are families (one file per alphabet);
  Fonts.Set builds the same for our sizes: roman = the given file, the other
  alphabets = the files of the base object's own family (fallback: the
  Cyrillic Friz every client ships). Without CreateFontFamily it falls back
  to the plain file. Families are cached per file, size and base.

  Fonts.Set(obj, size, file, base)   obj: FontString, EditBox or
      ScrollingMessageFrame; file: roman font file (default the game font);
      base: font object for the other alphabets (default GameFontNormal)
  Theme.SetFont is the same function (the way modules reach it).
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
