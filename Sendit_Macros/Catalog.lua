--[[
  Catalog: the macros per class. A macro = { tree, kind, body }: tree 0 = every specialization, 1-3 =
  the talent tree it belongs to (client order); kind = its description (Locale "kind_<kind>", "{1}" ...
  = the spells in order of appearance) and, for kinds without a spell to name it, its name and icon
  (Locale "name_<kind>", ICONS); body = the macro text with {id} for a spell's client name ({a|b}: the
  first one the character knows). The first spell names the macro. Every id is a spell of the Forever
  client (checked against its spell tables). stance:1-3 = battle / defensive / berserker stance.
]]
local _, ns = ...

local HELP = "[@mouseover,help,nodead][help,nodead][@player]"
local HARM = "[@mouseover,harm,nodead][]"
local REZ = "[@mouseover,help,dead][]"

local function Help(id) return "#showtooltip\n/cast [mod:alt,@player]" .. HELP .. " {" .. id .. "}" end
local function Harm(id) return "#showtooltip\n/cast " .. HARM .. " {" .. id .. "}" end
local function Kick(id) return "#showtooltip\n/stopcasting\n/cast " .. HARM .. " {" .. id .. "}" end
local function Rez(id) return "#showtooltip\n/cast " .. REZ .. " {" .. id .. "}" end
local function Hit(id) return "#showtooltip\n/startattack\n/cast {" .. id .. "}" end
local function Stance(id, n, stance)
    return "#showtooltip {" .. id .. "}\n/cast [stance:" .. n .. "] {" .. id .. "}; {" .. stance .. "}"
end
local function Then(first, id, unit)
    return "#showtooltip {" .. id .. "}\n/cast {" .. first .. "}\n/cast " .. (unit and unit .. " " or "") .. "{" .. id .. "}"
end
local function Toggle(id) return "#showtooltip\n/cancelaura {" .. id .. "}\n/cast {" .. id .. "}" end
local function Trinket(id) return "#showtooltip {" .. id .. "}\n/use 13\n/use 14\n/cast {" .. id .. "}" end
local function Form(id) return "#showtooltip\n/cast !{" .. id .. "}" end
local PET_ATTACK = "/petattack " .. HARM

local function M(tree, kind, body) return { tree = tree, kind = kind, body = body } end

ns.ICONS = { petAttack = "Ability_Hunter_Pet_Wolf", totems = "Spell_Nature_Windfury" }

ns.Catalog = {
    WARRIOR = {
        M(0, "charge", "#showtooltip\n/cast [nocombat,stance:1] {100}; [combat,stance:3] {20252}; [nocombat] {2457}; {2458}"),
        M(0, "stance", Stance(7384, 1, 2457)),
        M(0, "interruptStance", "#showtooltip\n/stopcasting\n/cast [stance:3] {6552}; {72}"),
        M(0, "stanceNot", "#showtooltip {5308}\n/cast [stance:2] {2457}; {5308}"),
        M(0, "attack", Hit(78)),
        M(0, "attack", Hit(845)),
        M(0, "attack", Hit(7386)),
        M(0, "stance", Stance(694, 1, 2457)),
        M(0, "stance", Stance(20230, 1, 2457)),
        M(0, "stance", Stance(1719, 3, 2458)),
        M(0, "stance", Stance(18499, 3, 2458)),
        M(0, "stance", Stance(1680, 3, 2458)),
        M(1, "attack", Hit(12294)),
        M(2, "attack", Hit(23881)),
        M(3, "stance", Stance(355, 2, 71)),
        M(3, "stance", Stance(6572, 2, 71)),
        M(3, "stance", Stance(2565, 2, 71)),
        M(3, "stance", Stance(871, 2, 71)),
        M(3, "stance", Stance(676, 2, 71)),
        M(3, "attack", Hit(23922)),
    },
    ROGUE = {
        M(0, "opener", "#showtooltip\n/cast [nostealth,nocombat] {1784}; [stealth] {1833}; {1752}"),
        M(0, "attack", Hit(1752)),
        M(0, "interrupt", Kick(1766)),
        M(0, "harm", Harm(6770)),
        M(0, "harm", Harm(2094)),
        M(0, "harm", Harm(1776)),
        M(0, "harm", Harm(921)),
        M(1, "opener", "#showtooltip\n/cast [nostealth,nocombat] {1784}; [stealth] {703}; {1752}"),
        M(1, "then", Then(14177, 2098)),
        M(2, "trinket", Trinket(13750)),
        M(2, "trinket", Trinket(13877)),
        M(3, "opener", "#showtooltip\n/cast [nostealth,nocombat] {1784}; [stealth] {8676}; {53}"),
        M(3, "attack", Hit(53)),
        M(3, "attack", Hit(16511)),
    },
    HUNTER = {
        M(0, "shot", "#showtooltip\n/petattack\n/cast !{75}"),
        M(0, "pet", "#showtooltip\n/cast [nopet] {883}; [@pet,dead] {982}; [@pet] {136}"),
        M(0, "petAttack", PET_ATTACK),
        M(0, "harm", Harm(1130)),
        M(0, "harm", Harm(1978)),
        M(0, "harm", Harm(19801)),
        M(0, "feign", "#showtooltip\n/stopattack\n/petfollow\n/cast {5384}"),
        M(0, "shift", "#showtooltip\n/cast [nomod:shift] {13165}; {5118}"),
        M(0, "attack", Hit(2973)),
        M(0, "attack", Hit(1495)),
        M(0, "attack", Hit(2974)),
        M(0, "trinket", Trinket(3045)),
        M(1, "trinket", Trinket(19574)),
        M(1, "harm", Harm(19577)),
        M(2, "harm", Harm(19503)),
    },
    MAGE = {
        M(0, "harm", Harm(118)),
        M(0, "interrupt", Kick(2139)),
        M(0, "help", Help(1459)),
        M(0, "help", Help(475)),
        M(1, "then", Then(12043, 11366, HARM)),
        M(1, "trinket", Trinket(12042)),
        M(2, "trinket", Trinket(11129)),
        M(3, "toggle", Toggle(11958)),
        M(3, "then", Then(12472, 122)),
    },
    PRIEST = {
        M(0, "help", Help(2061)),
        M(0, "help", Help(2060)),
        M(0, "help", Help(2054)),
        M(0, "help", Help(139)),
        M(0, "help", Help(17)),
        M(0, "help", Help(1243)),
        M(0, "help", Help(976)),
        M(0, "help", Help(528)),
        M(0, "help", Help(552)),
        M(0, "dispel", "#showtooltip\n/cast [@mouseover,exists,nodead][] {527}"),
        M(0, "rez", Rez(2006)),
        M(0, "harm", Harm(589)),
        M(0, "harm", Harm(9484)),
        M(1, "then", Then(14751, 2060, HELP)),
        M(1, "help", Help(14752)),
        M(1, "help", Help(10060)),
        M(3, "interrupt", Kick(15487)),
        M(3, "harm", Harm(15407)),
        M(3, "harm", Harm(15286)),
    },
    PALADIN = {
        M(0, "help", Help(635)),
        M(0, "help", Help(19750)),
        M(0, "help", Help(4987)),
        M(0, "help", Help(1152)),
        M(0, "help", Help(19740)),
        M(0, "help", Help(19742)),
        M(0, "help", Help(1022)),
        M(0, "help", Help(1044)),
        M(0, "help", Help(6940)),
        M(0, "help", Help(633)),
        M(0, "rez", Rez(7328)),
        M(0, "harm", Harm(853)),
        M(0, "toggle", Toggle(642)),
        M(0, "attack", Hit(20271)),
        M(1, "then", Then(20216, 635, HELP)),
        M(1, "help", Help(20473)),
        M(2, "help", Help(20217)),
        M(3, "harm", Harm(20066)),
    },
    SHAMAN = {
        M(0, "interrupt", Kick(8042)),
        M(0, "harm", Harm(370)),
        M(0, "harm", Harm(8050)),
        M(0, "help", Help(331)),
        M(0, "help", Help(8004)),
        M(0, "help", Help(526)),
        M(0, "help", Help(2870)),
        M(0, "rez", Rez(2008)),
        M(0, "totems", "#showtooltip\n/castsequence reset=combat/120 {5394}, {8071}, {3599}, {8184}"),
        M(2, "attack", Hit(17364)),
        M(2, "totems", "#showtooltip\n/castsequence reset=combat/120 {8512}, {8075}, {5675}, {3599}"),
        M(3, "help", Help(1064)),
        M(3, "then", Then(16188, 331, HELP)),
    },
    WARLOCK = {
        M(0, "harm", Harm(172)),
        M(0, "harm", Harm(980)),
        M(0, "harm", Harm(348)),
        M(0, "harm", Harm(5782)),
        M(0, "harm", Harm(710)),
        M(0, "harm", Harm(702)),
        M(0, "harm", Harm(440892)),
        M(0, "petAttack", PET_ATTACK),
        M(0, "interrupt", Kick(19244)),
        M(1, "harm", Harm(18265)),
        M(1, "harm", Harm(18223)),
        M(2, "then", Then(18708, 697)),
        M(2, "then", Then(18708, 691)),
        M(3, "harm", Harm(17877)),
        M(3, "harm", Harm(17962)),
    },
    DRUID = {
        M(0, "form", Form("9634|5487")),
        M(0, "form", Form(768)),
        M(0, "form", Form(783)),
        M(0, "help", Help(774)),
        M(0, "help", Help(5185)),
        M(0, "help", Help(8936)),
        M(0, "help", Help(1126)),
        M(0, "help", Help(467)),
        M(0, "help", Help(2782)),
        M(0, "help", Help(2893)),
        M(0, "help", Help(29166)),
        M(0, "rez", Rez(20484)),
        M(0, "harm", Harm(8921)),
        M(0, "harm", Harm(770)),
        M(0, "harm", Harm(339)),
        M(0, "harm", Harm(2637)),
        M(1, "form", Form(24858)),
        M(2, "opener", "#showtooltip\n/cast [nostealth,nocombat] {5215}; [stealth] {6785}; {5221}"),
        M(2, "powershift", "#showtooltip {768}\n/cancelform [form]\n/cast !{768}"),
        M(2, "attack", Hit(6807)),
        M(2, "attack", Hit(1082)),
        M(3, "harm", Harm(5570)),
        M(3, "then", Then(17116, 5185, HELP)),
        M(3, "help", Help(18562)),
    },
}
