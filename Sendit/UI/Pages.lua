--[[
  Pages: the core pages - Design (palette, frame style, animations, language; minimap button and app
  bar) and Profiles (pick, create, duplicate, delete).
]]
local _, ns = ...

local Options, T, W, Profiles, L = ns.Options, ns.Theme, ns.Widgets, ns.Profiles, ns.L
local Changed, SettingsPage = Options.Changed, Options.SettingsPage
local design = ns:Module("design")
local function Tx(key) return ns.Locale.Text(L, key) end

local function LanguageChoices()
    local list = { { "auto", L.LANG_AUTO } }
    for _, lang in ipairs(ns.Locale.LANGUAGES) do list[#list + 1] = { lang.code, lang.name } end
    return list
end

local function DesignSwitch(key)
    return function() return design.profile[key] end, function(v)
        design.profile[key] = v
        Changed()
    end
end

Options:Register({
    key = "design",
    core = true,
    module = design,
    title = Tx("DESIGN"),
    subtitle = Tx("DESIGN_SUB"),
    resetKeys = { "palette", "style", "animations", "language" },
    build = SettingsPage(function(Lay, c)
        Lay:Section(Tx("APPEARANCE"))
        local choices = {}
        for _, key in ipairs(T.PALETTE_ORDER) do choices[#choices + 1] = { key, Tx("PAL_" .. key) } end
        local get, set = DesignSwitch("palette")
        Lay:Row(Tx("PALETTE"), Tx("PALETTE_DESC"), W.Segmented(c, choices, function() return T.PaletteKey() end, set))
        get, set = DesignSwitch("style")
        Lay:Row(Tx("STYLE"), Tx("STYLE_DESC"),
            W.Segmented(c, { { "modern", Tx("MODERN") }, { "azeroth", Tx("AZEROTH") } }, get, set))
        get, set = DesignSwitch("animations")
        Lay:Row(Tx("ANIMATIONS"), Tx("ANIMATIONS_DESC"), W.Switch(c, get, set))
        get, set = DesignSwitch("language")
        Lay:Row(Tx("LANGUAGE"), Tx("LANGUAGE_DESC"), W.Dropdown(c, 180, LanguageChoices, get, set))
        Lay:EndSection()

        Lay:Section(Tx("INTERFACE"))
        Lay:Row(Tx("MINIMAP"), Tx("MINIMAP_DESC"),
            W.Switch(c, function() return not ns.db.minimap.hide end, function(v)
                ns.db.minimap.hide = not v
                Changed()
            end))
        Lay:Row(Tx("APPBAR"), Tx("APPBAR_DESC"),
            W.Switch(c, function() return not ns.db.appbar.hide end, function(v)
                ns.db.appbar.hide = not v
                Changed()
            end))
        Lay:EndSection()
    end),
})

local message  -- feedback line under the sections
local toDelete  -- profile picked in the delete dropdown

local function Say(text, role)
    message:SetText(text or "")
    T.Paint(message, role or "textMuted")
end

local function ProfileChoices(exclude)
    local list = {}
    for _, name in ipairs(Profiles:List()) do
        if name ~= exclude then list[#list + 1] = { name, name } end
    end
    return list
end

StaticPopupDialogs["SENDIT_DELETE_PROFILE"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, name)
        local ok, err = Profiles:Delete(name)
        toDelete = nil
        Say(ok and L.DELETED:format(name) or err, ok and "textMuted" or "danger")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

Options:Register({
    key = "profiles",
    core = true,
    title = Tx("PROFILES"),
    subtitle = Tx("PROFILES_SUB"),
    build = SettingsPage(function(Lay, c)
        Lay:Section(Tx("THIS_CHAR"))
        Lay:Row(Tx("ACTIVE"), Tx("ACTIVE_DESC"),
            W.Dropdown(c, 200, ProfileChoices,
                function() return Profiles:Active() end,
                function(name)
                    Profiles:Use(name)
                    Say(L.USING:format(name))
                end))
        Lay:EndSection()

        Lay:Section(Tx("MANAGE"))
        local nameBox = W.Search(c, L.NAME, function() end)
        nameBox:SetWidth(150)
        local function Create(copy)
            local name = strtrim(nameBox:GetText())
            local ok, err = Profiles:Create(name, copy)
            if ok then
                nameBox:SetText("")
                nameBox:ClearFocus()
                Say(L.CREATED:format(name))
            else
                Say(err, "danger")
            end
        end
        nameBox:SetScript("OnEnterPressed", function() Create(false) end)
        local create = W.Button(c, L.CREATE, function() Create(false) end)
        local duplicate = W.Button(c, L.DUPLICATE, function() Create(true) end)
        Lay:Row(Tx("NEW"), Tx("NEW_DESC"), W.Inline(c, { nameBox, create, duplicate }))

        local deleteBox = W.Dropdown(c, 150, function() return ProfileChoices(Profiles.DEFAULT) end,
            function()
                if not Profiles:Exists(toDelete) then toDelete = nil end
                return toDelete
            end,
            function(name) toDelete = name end)
        local deleteButton = W.Button(c, L.DELETE, function()
            if not toDelete then return Say(L.DELETE_PICK, "danger") end
            local dialog = StaticPopup_Show("SENDIT_DELETE_PROFILE", L.DELETE_ASK:format(toDelete))
            if dialog then dialog.data = toDelete end
        end)
        Lay:Row(Tx("DELETE_ROW"), Tx("DELETE_DESC"), W.Inline(c, { deleteBox, deleteButton }))
        Lay:EndSection()

        message = Lay:Note("")
    end),
})
