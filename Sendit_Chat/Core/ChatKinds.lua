--[[
  ChatKinds: the message kinds a tab can show, laid out like Blizzard's chat settings (Chat / Other).
  Key = Blizzard's chat type group name; members from ChatTypeGroup (else the key alone).
  ChatKinds.Sections() / Label(key) / KeyOf(chatType) / All() / ColorType(key) / Types(key)
]]
local _, ns = ...
local L = ns.L

local ChatKinds = {}
ns.ChatKinds = ChatKinds

local SECTIONS = {
    { id = "chat", label = "KINDS_CHAT", heads = {
        { label = "KINDS_PLAYERS", keys = { "SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "GUILD_DISCORD",
            "GUILD_ACHIEVEMENT", "ACHIEVEMENT", "WHISPER", "BN_WHISPER", "PARTY", "PARTY_LEADER", "RAID",
            "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" } },
        { label = "KINDS_CREATURES", keys = { "MONSTER_SAY", "MONSTER_EMOTE", "MONSTER_YELL",
            "MONSTER_WHISPER", "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER" } },
    } },
    { id = "other", label = "KINDS_OTHER", heads = {
        { label = "KINDS_COMBAT", keys = { "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE",
            "SKILL", "LOOT", "CURRENCY", "MONEY", "TRADESKILLS", "OPENING", "PET_INFO", "COMBAT_MISC_INFO" } },
        { label = "KINDS_PVP", keys = { "BG_HORDE", "BG_ALLIANCE", "BG_NEUTRAL" } },
        { label = "KINDS_SYSTEM", keys = { "SYSTEM", "ERRORS", "IGNORED", "CHANNEL", "TARGETICONS", "BN_INLINE_TOAST_ALERT" } },
    } },
}

function ChatKinds.Sections() return SECTIONS end

function ChatKinds.Label(key) return L["KIND_" .. key] end

function ChatKinds.All()
    local out = {}
    for _, s in ipairs(SECTIONS) do
        for _, h in ipairs(s.heads) do
            for _, key in ipairs(h.keys) do out[#out + 1] = key end
        end
    end
    return out
end

-- members under another chat type (ChatTypeGroup), in case that table is missing
local MEMBERS = {
    TEXT_EMOTE = "EMOTE", WHISPER_INFORM = "WHISPER", AFK = "WHISPER", DND = "WHISPER",
    SMART_WHISPER = "WHISPER", REPLY = "WHISPER",
    BN_WHISPER_INFORM = "BN_WHISPER", BN_WHISPER_PLAYER_OFFLINE = "BN_WHISPER",
    MONSTER_PARTY = "PARTY",
    CHANNEL_JOIN = "CHANNEL", CHANNEL_LEAVE = "CHANNEL", CHANNEL_NOTICE = "CHANNEL",
    CHANNEL_NOTICE_USER = "CHANNEL", CHANNEL_LIST = "CHANNEL",
    RAID_BOSS_EMOTE = "MONSTER_BOSS_EMOTE", RAID_BOSS_WHISPER = "MONSTER_BOSS_WHISPER",
    QUEST_BOSS_EMOTE = "MONSTER_BOSS_EMOTE",
    BG_SYSTEM_HORDE = "BG_HORDE", BG_SYSTEM_ALLIANCE = "BG_ALLIANCE", BG_SYSTEM_NEUTRAL = "BG_NEUTRAL",
    FILTERED = "ERRORS", RESTRICTED = "ERRORS",
    BN_INLINE_TOAST_BROADCAST = "BN_INLINE_TOAST_ALERT", BN_INLINE_TOAST_BROADCAST_INFORM = "BN_INLINE_TOAST_ALERT",
}

-- a kind whose own name is no chat type: the type whose colour it shows
local COLOR = {
    MONSTER_BOSS_EMOTE = "RAID_BOSS_EMOTE", MONSTER_BOSS_WHISPER = "RAID_BOSS_WHISPER",
    BG_HORDE = "BG_SYSTEM_HORDE", BG_ALLIANCE = "BG_SYSTEM_ALLIANCE", BG_NEUTRAL = "BG_SYSTEM_NEUTRAL",
}
function ChatKinds.ColorType(key) return COLOR[key] or key end

-- chat type -> kind key, built on first use (ChatTypeGroup is complete once chat loaded)
local kindOf
local function Build()
    kindOf = {}
    local groups = _G["ChatTypeGroup"]
    -- a kind's own chat type stays its own; then the other members of Blizzard's groups
    for _, key in ipairs(ChatKinds.All()) do kindOf[key] = key end
    for _, key in ipairs(ChatKinds.All()) do
        local events = type(groups) == "table" and groups[key]
        if type(events) == "table" then
            for _, event in ipairs(events) do
                local chatType = type(event) == "string" and event:match("^CHAT_MSG_(.+)$")
                if chatType and not kindOf[chatType] then kindOf[chatType] = key end
            end
        end
    end
    for chatType, key in pairs(MEMBERS) do kindOf[chatType] = kindOf[chatType] or key end
end

-- every chat type of the kind with a colour: what Blizzard's swatch changes
function ChatKinds.Types(key)
    if not kindOf then Build() end
    local info, out = _G["ChatTypeInfo"], {}
    if type(info) ~= "table" then return out end
    for chatType, k in pairs(kindOf) do
        if k == key and info[chatType] then out[#out + 1] = chatType end
    end
    table.sort(out)
    return out
end

function ChatKinds._Rebuild() Build(); return true end  -- tests

function ChatKinds.KeyOf(chatType)
    if type(chatType) ~= "string" then return nil end
    if not kindOf then Build() end
    return kindOf[chatType]
end
