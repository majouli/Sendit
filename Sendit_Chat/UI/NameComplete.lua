--[[
  NameComplete: suggestions under the messenger's name field - our conversations, then the client's
  whisper completion (C_AutoComplete WHISPER); prefix matches first. Up / Down, Tab completes, Enter
  opens, Escape closes.  NameComplete.Attach(eb, openTyped) / Suggest(text)
]]
local _, ns = ...
local T, W, Safe = ns.Theme, ns.Whispers, ns.Safe
local L = ns.L

local NameComplete = {}
ns.NameComplete = NameComplete

local MAX = 6
local ROW = 22

local function Lower(s) return type(s) == "string" and s:lower() or "" end

local function OpenConv(conv)
    return function() if ns.Messenger then ns.Messenger.Open(conv, true) end end
end

local function OpenBNID(id, name)
    return function()
        local bn = _G["C_BattleNet"]
        local info = bn and bn.GetAccountInfoByID and Safe.Call(bn.GetAccountInfoByID, id)
        local account = type(info) == "table" and Safe.Str(info.accountName)
        local c = account and W.OpenBN(account)
        if c and ns.Messenger then ns.Messenger.Open(c, true) elseif name then ns.OpenWhisper(name) end
    end
end

local function ClientResults(text)
    local ac, lists = _G["C_AutoComplete"], _G["AUTOCOMPLETE_LIST"]
    local list = type(lists) == "table" and lists.WHISPER
    if type(ac) ~= "table" or type(ac.GetAutoCompleteResults) ~= "function" or type(list) ~= "table" then return {} end
    local ok, results = pcall(ac.GetAutoCompleteResults, text, MAX * 2, #text, true, list.include, list.exclude)
    return ok and type(results) == "table" and results or {}
end

function NameComplete.Suggest(text)
    text = Safe.Str(text)
    text = text and strtrim(text) or ""
    if text == "" then return {} end
    local want = text:lower()
    local seen, starts, contains = {}, {}, {}
    local function Add(entry, name)
        local key = Lower(name)
        if key == "" or seen[key] then return end
        local at = key:find(want, 1, true)
        if not at then return end
        seen[key] = true
        if at == 1 then starts[#starts + 1] = entry else contains[#contains + 1] = entry end
    end
    for _, c in ipairs(W.List()) do
        Add({ label = c.name, sub = c.bn and L.BATTLENET or L.SRC_CONV, class = c.class, bn = c.bn, open = OpenConv(c) }, c.name)
    end
    for _, c in ipairs(W.Archived()) do
        Add({ label = c.name, sub = L.TAB_ARCHIVE, class = c.class, bn = c.bn, open = OpenConv(c) }, c.name)
    end
    for _, r in ipairs(ClientResults(text)) do
        local name = type(r) == "table" and Safe.Str(r.name)
        if name and name ~= "" then
            local id = Safe.Num(r.bnetID)
            if id and id ~= 0 then
                Add({ label = name, sub = L.BATTLENET, bn = true, open = OpenBNID(id, nil) }, name)
            else
                local short = name:gsub("%-.*$", "")
                local entry = { label = name, sub = "", open = function() ns.OpenWhisper(name) end }
                if seen[Lower(short)] then entry = nil end  -- already a conversation
                if entry then Add(entry, name) end
            end
        end
    end
    local out = {}
    for _, e in ipairs(starts) do if #out < MAX then out[#out + 1] = e end end
    for _, e in ipairs(contains) do if #out < MAX then out[#out + 1] = e end end
    return out
end

local function BuildBox(eb)
    local box = CreateFrame("Frame", nil, eb)
    box:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", 0, -2)
    box:SetPoint("TOPRIGHT", eb, "BOTTOMRIGHT", 0, -2)
    box:SetFrameStrata("DIALOG")
    box.bg = T.Tex(box, "BACKGROUND", "bg", 0.98)
    box.bg:SetAllPoints()
    T.Border(box, 1)
    box.rows = {}
    for i = 1, MAX do
        local r = CreateFrame("Button", nil, box)
        r:SetHeight(ROW)
        r:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW)
        r:SetPoint("TOPRIGHT", -1, -1 - (i - 1) * ROW)
        r.hl = T.Tex(r, "BACKGROUND", "ink", 0)
        r.hl:SetAllPoints()
        r.name = T.Text(r, 12, "text", "OVERLAY", true)
        T.Own(r.name)
        r.name:SetPoint("LEFT", 8, 0)
        r.name:SetPoint("RIGHT", r, "RIGHT", -70, 0)
        r.name:SetWordWrap(false)
        r.sub = T.Text(r, 10, "textMuted")
        r.sub:SetPoint("RIGHT", -8, 0)
        r.sub:SetJustifyH("RIGHT")
        r:SetScript("OnEnter", function(self) box:Select(self.index) end)
        r:SetScript("OnClick", function(self)
            local e = box.items[self.index]
            box:Close()
            eb:SetText("")
            eb:ClearFocus()
            if e then e.open() end
        end)
        r.index = i
        box.rows[i] = r
    end
    box.items, box.sel = {}, 0

    function box:Select(i)
        self.sel = i
        for k, r in ipairs(self.rows) do T.Color(r.hl, "ink", k == i and 0.10 or 0) end
    end
    function box:Close()
        self.items, self.sel = {}, 0
        self:Hide()
    end
    function box:Fill(items)
        self.items = items
        for i, r in ipairs(self.rows) do
            local e = items[i]
            r:SetShown(e ~= nil)
            if e then
                r.name:SetText(e.label)
                local cr, cg, cb = T.ClassRGB(e.class)
                if e.bn then cr, cg, cb = T.RGB("bn") end
                r.name:SetTextColor(cr, cg, cb, 1)
                r.sub:SetText(e.sub or "")
            end
        end
        self:SetHeight(#items * ROW + 2)
        self:SetShown(#items > 0)
        self:Select(0)
    end
    box:Hide()
    return box
end

function NameComplete.Attach(eb, openTyped)
    local box = BuildBox(eb)
    eb.complete = box
    eb:HookScript("OnTextChanged", function(self, user)
        if user == false then return end
        if not self:HasFocus() then return box:Close() end
        box:Fill(NameComplete.Suggest(self:GetText()))
    end)
    eb:SetScript("OnArrowPressed", function(_, key)
        local n = #box.items
        if n == 0 then return end
        if key == "DOWN" then box:Select(box.sel % n + 1)
        elseif key == "UP" then box:Select((box.sel - 2) % n + 1) end
    end)
    eb:SetScript("OnTabPressed", function(self)
        local e = box.items[box.sel > 0 and box.sel or 1]
        if e then
            self:SetText(e.label)
            self:SetCursorPosition(#e.label)
            box:Select(box.sel > 0 and box.sel or 1)
        end
    end)
    eb:SetScript("OnEnterPressed", function(self)
        local e = box.sel > 0 and box.items[box.sel] or nil
        local text = self:GetText()
        box:Close()
        self:SetText("")
        self:ClearFocus()
        if e then e.open() elseif text and strtrim(text) ~= "" then openTyped(text) end
    end)
    eb:SetScript("OnEscapePressed", function(self)
        box:Close()
        self:ClearFocus()
    end)
    -- a click takes the focus first: close a moment later
    eb:HookScript("OnEditFocusLost", function()
        C_Timer.After(0.2, function() if not eb:HasFocus() then box:Close() end end)
    end)
    return box
end
