--[[
  SpellLinks: spell links the server took away, put back for display.

  The Forever server turns a spell link whose text has a bracket part
  ("[Siegel des Kreuzfahrers (Rang 4)]", "[Parieren (Passiv)]") into plain
  text - from every chat, Blizzard's too (tested in game). What arrives is
  "Siegel des Kreuzfahrers (Rang 4)". Data/SpellNames_<locale>.lua (generated
  from the client's spell tables, tools/gen_spellnames.py) maps name + bracket
  text to the spell id, so the words become a spell link again: hover shows
  the tooltip, click pins it. Only outside existing links, only for a name
  that ends right before a known bracket text (the longest one of up to six
  words wins). The saved text stays as it arrived; this is display only.

  SpellLinks.Restore(text) -> text
]]
local _, ns = ...
local Safe, Links = ns.Safe, ns.Links

local SpellLinks = {}
ns.SpellLinks = SpellLinks

local MAX_WORDS = 6
local COLOR = "|cff71d5ff"  -- the client's spell link colour

local function Link(id, name, sub)
    return ("%s|Hspell:%d:0|h[%s (%s)]|h|r"):format(COLOR, id, name, sub)
end

-- One plain piece: every "words (sub)" whose last words name a known spell.
local function RestorePlain(piece)
    local names, subs = ns.SpellNames, ns.SpellSubtexts
    if not (names and subs) or not piece:find("(", 1, true) then return piece end
    return (piece:gsub("([^%(%)]-)%s*%(([^%(%)]+)%)", function(before, sub)
        if not subs[sub] then return nil end
        local words = {}
        for w in before:gmatch("%S+") do words[#words + 1] = w end
        for n = math.min(MAX_WORDS, #words), 1, -1 do
            local name = table.concat(words, " ", #words - n + 1)
            local ids = names[name]
            if ids and ids[sub] then
                local head = table.concat(words, " ", 1, #words - n)
                local lead = before:match("^(%s*)") or ""
                return lead .. head .. (head ~= "" and " " or "") .. Link(ids[sub], name, sub)
            end
        end
        return nil
    end))
end

function SpellLinks.Restore(text)
    if not Safe.Str(text) or not text:find("(", 1, true) or not ns.SpellNames then return text end
    return Links.MapPlain(text, RestorePlain)
end
