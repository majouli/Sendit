--[[
  ChatColors: a chat type's colour - read from ChatTypeInfo, changed like Blizzard's settings
  (ChangeChatColor; Blizzard updates ChatTypeInfo, Sendit never writes it).
  ChatColors.Get(chatType) / Pick(chatType, onDone, also) / Swatch(parent)
]]
local _, ns = ...
local T = ns.Theme

local ChatColors = {}
ns.ChatColors = ChatColors

function ChatColors.Get(chatType)
    local info = _G["ChatTypeInfo"]
    local t = type(info) == "table" and chatType and info[chatType]
    if type(t) ~= "table" then return nil end
    local r, g, b = ns.Safe.Num(t.r), ns.Safe.Num(t.g), ns.Safe.Num(t.b)
    if not (r and g and b) then return nil end
    return r, g, b
end

local function Change(chatType, r, g, b)
    local fn = _G["ChangeChatColor"]
    if type(fn) == "function" then pcall(fn, chatType, r, g, b) end
end

function ChatColors.Pick(chatType, onDone, also)
    local picker = _G["ColorPickerFrame"]
    local r, g, b = ChatColors.Get(chatType)
    if not (r and picker and picker.SetupColorPickerAndShow) then return false end
    local types, before = { chatType }, {}
    for _, t in ipairs(also or {}) do if t ~= chatType then types[#types + 1] = t end end
    for _, t in ipairs(types) do before[t] = { ChatColors.Get(t) } end
    local function Done() if onDone then onDone() end end
    picker:SetupColorPickerAndShow({
        r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = function()
            local nr, ng, nb = picker:GetColorRGB()
            for _, t in ipairs(types) do Change(t, nr, ng, nb) end
            Done()
        end,
        cancelFunc = function()
            for _, t in ipairs(types) do
                local c = before[t]
                if c[1] then Change(t, c[1], c[2], c[3]) end
            end
            Done()
        end,
    })
    return true
end

function ChatColors.Swatch(parent)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(14, 14)
    s.edge = T.Tex(s, "BACKGROUND", "ink", 0.5)
    s.edge:SetAllPoints()
    s.fill = s:CreateTexture(nil, "ARTWORK")
    s.fill:SetPoint("TOPLEFT", 1, -1)
    s.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    function s:Set(chatType, onDone, also)
        self.chatType, self.onDone, self.also = chatType, onDone, also
        local r, g, b = ChatColors.Get(chatType)
        self:SetShown(r ~= nil)
        if r and g and b then self.fill:SetColorTexture(r, g, b, 1) end
    end
    s:SetScript("OnClick", function(self)
        ChatColors.Pick(self.chatType, function()
            self:Set(self.chatType, self.onDone, self.also)
            if self.onDone then self.onDone() end
        end, self.also)
    end)
    return s
end
