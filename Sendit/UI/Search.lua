--[[
  Search: find any setting from the Sendit window - every row a page adds through the Layout plus every
  page. All typed words must appear in "module, page, section, label, description"; label matches first.
  Results are a hidden page (crumb, label, description); a click opens the page and lights up the row.
  Search.AttachBox(sidebar, below) / Query(text) -> results / Open(result)
]]
local _, ns = ...
local T, W, O = ns.Theme, ns.Widgets, ns.Options
local Resolve = ns.Locale.Resolve
local L = ns.L

local Search = {}
ns.Search = Search

local MAX = 60
local ROW_H = 58
local SEP = "  >  "

local box, resultsPage, back
local query, results = "", {}
local muted = false

local function Lower(s) return type(s) == "string" and s:lower() or "" end

local function Words(text)
    local out = {}
    for w in Lower(text):gmatch("%S+") do out[#out + 1] = w end
    return out
end

-- module > page > section (each only when it differs)
local function Crumb(page, section)
    local parts = {}
    local m = page.module
    local mt = not page.core and m and Resolve(m.title) or nil
    local pt = Resolve(page.title)
    if mt and mt ~= "" then parts[#parts + 1] = mt end
    if pt and pt ~= "" and pt ~= mt then parts[#parts + 1] = pt end
    local st = section and Resolve(section)
    if st and st ~= "" and st ~= parts[#parts] then parts[#parts + 1] = st end
    return parts
end

local function Entries()
    local out = {}
    for _, page in ipairs(O:Pages()) do
        if not page.hidden then
            local built = O:BuildPage(page)
            -- the page itself
            local crumb = Crumb(page)
            table.remove(crumb)
            if #crumb == 0 then crumb[1] = L.SEARCH_PAGE end
            out[#out + 1] = { crumb = crumb, label = Resolve(page.title) or "", desc = Resolve(page.subtitle), page = page }
            for _, e in ipairs(built.entries or {}) do
                out[#out + 1] = {
                    crumb = Crumb(page, e.section),
                    label = Resolve(e.label) or "",
                    desc = Resolve(e.desc),
                    page = page,
                    row = e.row,
                }
            end
        end
    end
    return out
end

local function Score(e, words)
    local label = Lower(e.label)
    local hay = Lower(table.concat(e.crumb, " ") .. " " .. e.label .. " " .. (e.desc or ""))
    for _, w in ipairs(words) do
        if not hay:find(w, 1, true) then return nil end
    end
    local first = words[1]
    if label:sub(1, #first) == first then return 0 end
    if label:find(first, 1, true) then return 1 end
    return 2
end

function Search.Query(text)
    local words = Words(text)
    if #words == 0 then return {} end
    local found = {}
    for i, e in ipairs(Entries()) do
        local score = Score(e, words)
        if score then
            e.score, e.order = score, i
            found[#found + 1] = e
        end
    end
    table.sort(found, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        return a.order < b.order
    end)
    for i = #found, MAX + 1, -1 do found[i] = nil end
    return found
end

local function SetText(text)
    muted = true
    box:SetText(text)
    muted = false
end

function Search.Open(r)
    if not r then return end
    query = ""
    SetText("")
    box:ClearFocus()
    O:Reveal(r.page, r.row)
end

local function OnChange(text)
    if muted then return end
    query = text or ""
    if strtrim(query) == "" then
        if O:Current() == resultsPage then O:ShowPage(back or O:FirstPage()) end
        return
    end
    local cur = O:Current()
    if cur ~= resultsPage then back = cur end
    results = Search.Query(query)  -- the header's count is read before the page refreshes
    O:ShowPage(resultsPage)
end

function Search.AttachBox(sidebar, below)
    box = W.Search(sidebar, L.SEARCH, OnChange)
    box:SetPoint("TOPLEFT", below, "BOTTOMLEFT", -8, -14)
    box:SetPoint("RIGHT", sidebar, "RIGHT", -16, 0)
    box:SetScript("OnEnterPressed", function() Search.Open(results[1]) end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    Search.box = box
    return box
end

ns.OnSettingsChanged(function()
    if box then box.hint:SetText(L.SEARCH) end
end)

O:OnPage(function(def)
    if def ~= resultsPage and box and query ~= "" then
        query = ""
        SetText("")
    end
end)

local function NewRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW_H)
    T.Fill(r, "hover", "HIGHLIGHT"):SetAllPoints()
    local line = T.Fill(r, "divider", "BORDER")
    line:SetPoint("BOTTOMLEFT", 16, 0)
    line:SetPoint("BOTTOMRIGHT", -16, 0)
    line:SetHeight(1)
    r.crumb = T.Text(r, "caption", "accent")
    r.crumb:SetPoint("TOPLEFT", 16, -8)
    r.label = T.Text(r, "body", "text")
    r.label:SetPoint("TOPLEFT", r.crumb, "BOTTOMLEFT", 0, -4)
    r.desc = T.Text(r, "note", "textMuted")
    r.desc:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -3)
    r.desc:SetPoint("RIGHT", r, "RIGHT", -16, 0)
    r:SetScript("OnClick", function(self) Search.Open(self.result) end)
    return r
end

local function BuildResults(frame)
    local area = W.ScrollArea(frame)
    area:SetPoint("TOPLEFT", T.SIZE.pad, -16)
    area:SetPoint("BOTTOMRIGHT", -T.SIZE.pad, 0)
    local content = area.content
    content:SetWidth(T.SIZE.width - T.SIZE.sidebar - T.SIZE.pad * 2)
    local panel = CreateFrame("Frame", nil, content)
    panel:SetPoint("TOPLEFT")
    panel:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    T.Fill(panel, "panel", "BACKGROUND"):SetAllPoints()
    T.Border(panel, "border")
    local empty = T.Text(content, "note", "textMuted")
    empty:SetPoint("TOPLEFT", 0, -8)
    local rows = {}
    local page = { rows = rows }

    function page:Refresh()
        results = Search.Query(query)
        for i, r in ipairs(results) do
            local row = rows[i] or NewRow(panel)
            rows[i] = row
            row.result = r
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
            row.crumb:SetText(table.concat(r.crumb, SEP):upper())
            row.label:SetText(r.label)
            row.desc:SetText(r.desc or "")
            row:Show()
        end
        for i = #results + 1, #rows do
            rows[i]:Hide()
            rows[i].result = nil
        end
        panel:SetHeight(math.max(1, #results * ROW_H))
        panel:SetShown(#results > 0)
        empty:SetText(#results == 0 and L.SEARCH_NONE:format(strtrim(query)) or "")
        content:SetHeight(math.max(1, #results * ROW_H + 16))
        area:SetVerticalScroll(0)
    end
    return page
end

resultsPage = {
    key = "search",
    core = true,
    hidden = true,
    title = function() return L.SEARCH_TITLE end,
    subtitle = function()
        if #results == 0 then return "" end
        return L.SEARCH_SUB:format(#results, strtrim(query))
    end,
    build = BuildResults,
}
O:Register(resultsPage)
Search._results = function() return results end
