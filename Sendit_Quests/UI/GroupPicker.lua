--[[
  GroupPicker: a searchable, scrolling place / category menu behind a header chip (the shared menu
  cannot fit every zone). Click outside or Escape closes it.
]]
local _, ns = ...
local T, W, DB, L = Sendit.Theme, Sendit.Widgets, ns.Database, ns.L
local Picker = {}
ns.GroupPicker = Picker
local menu

function Picker.Hide() if menu then menu:Hide() end end

function Picker.Create(parent, get, set)
    local button
    local function Open()
        if menu and menu:IsShown() then menu:Hide() return end
        if not menu then
            menu = CreateFrame("Button", "SenditQuestsGroupMenu", UIParent)
            menu:SetAllPoints(UIParent)
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:SetScript("OnClick", Picker.Hide)
            Sendit.ownFrames[menu] = true
            tinsert(UISpecialFrames, "SenditQuestsGroupMenu")
            menu.panel = CreateFrame("Frame", nil, menu)
            menu.panel:SetSize(380, 370)
            menu.panel:SetClampedToScreen(true)
            menu.panel:EnableMouse(true)
            T.Fill(menu.panel, "bg", "BACKGROUND"):SetAllPoints()
            T.Border(menu.panel, "border")
            menu.scroll = W.ScrollArea(menu.panel)
            menu.scroll:SetPoint("TOPLEFT", 10, -52)
            menu.scroll:SetSize(360, 300)
            menu.pool = {}
            local function Render()
                local first = math.floor((menu.scroll:GetVerticalScroll() or 0) / 38) + 1
                local used = 0
                for i = first, math.min(#menu.options, first + 8) do
                    used = used + 1
                    local b = menu.pool[used]
                    if not b then
                        b = W.Button(menu.scroll.content, "", function(self)
                            menu.choose(self.key)
                            menu:Hide()
                        end)
                        menu.pool[used] = b
                    end
                    b.key = menu.options[i][1]
                    b:SetLabel(menu.options[i][2])
                    b:SetWidth(360)
                    b.text:SetWidth(336)
                    b.text:SetMaxLines(1)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", 0, -(i - 1) * 38)
                    T.Paint(b.text, b.key == menu.current and "accent" or "text")
                    b:Show()
                end
                for i = used + 1, #menu.pool do menu.pool[i]:Hide() end
            end
            menu.scroll:SetScript("OnVerticalScroll", Render)
            menu.search = W.Search(menu.panel, L.findGroup, function(text)
                local needle = (strlower or string.lower)(strtrim(text or ""))
                menu.options = {}
                for _, option in ipairs(DB.Groups()) do
                    if (strlower or string.lower)(option[2]):find(needle, 1, true) then
                        menu.options[#menu.options + 1] = option
                    end
                end
                menu.scroll.content:SetHeight(math.max(1, #menu.options * 38))
                menu.scroll:SetVerticalScroll(0)
                Render()
            end)
            menu.search:SetPoint("TOPLEFT", 10, -12)
            menu.search:SetWidth(360)
            T.SetFont(menu.search, 12)
        end
        menu.panel:ClearAllPoints()
        menu.panel:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4)
        menu.current, menu.choose = get(), set
        menu.search.hint:SetText(L.findGroup)
        menu.search:SetText("")
        menu:Show()
        menu.search:SetFocus()
    end
    button = Sendit.Widgets.Chip(parent, Open)
    function button:Refresh()
        self:SetLabel(DB.GroupName(get()), get() ~= "all")
    end
    button:Refresh()
    return button
end
