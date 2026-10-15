-- AuctionHouse Forever: the settings window (/ahf) and its Interface Options entry.

local _, ns = ...
local AHF = ns.AHF

-- refreshers repaint every control from the settings (window opened, a setting
-- changed elsewhere)
local refreshers = {}
local function AddRefresher(fn) table.insert(refreshers, fn) end
local function RunRefreshers() for _, fn in ipairs(refreshers) do fn() end end

---------------------------------------------------------------------------
-- Widget helpers, in the shared look (Theme.lua)
---------------------------------------------------------------------------
local T = ns.Theme
local Text, FlatButton, Card, MutedNote = T.Text, T.FlatButton, T.Card, T.Note

-- Page grid: cards fill the page body exactly, two half cards with a gap between
local PAGE_W = T.WINDOW.W - T.WINDOW.SIDE - 32
local GAP = 10
local HALF_W = (PAGE_W - GAP) / 2
local COL2 = HALF_W + 20      -- second column inside a full-width card
local ROW = 26                -- one switch row
local NOTE_X = 50             -- notes line up under a switch's label

-- Hover help on any control (a title line and a wrapped explanation)
local function Tip(widget, title, body)
    if title or body then T.Tooltip(widget, title, body) end
end
AHF.optionTips = {}   -- every control with hover help (a test checks they all have it)
local function TipAll(widget, title, body)
    Tip(widget, title, body)
    AHF.optionTips[#AHF.optionTips + 1] = { widget = widget, title = title, body = body }
end

-- On/off switch bound to a saved setting. set(v) saves and applies it.
local function Switch(parent, text, x, y, get, set, tip)
    local b = T.LabeledSwitch(parent, text, x, y)
    b:SetScript("OnClick", function(self)
        if self.disabled then return end
        set(not get())
        self:SetOn(get())
    end)
    TipAll(b, text, tip)
    AddRefresher(function() b:SetOn(get()) end)
    return b
end

-- Slider over a number setting; range from AHF.LIMITS[key]
local function FlatSlider(parent, text, x, y, width, key, set, tip, o)
    o = o or {}
    local r = AHF.LIMITS[key]
    local s = T.Slider(parent, text, x, y, width,
        function() return AHF.db[key] end, set, r[1], r[2], o.suffix or " px", o.step or 1)
    TipAll(s, text, tip)
    AddRefresher(s.Refresh)
    return s
end

-- A button that needs a second click within 4 seconds
local function ConfirmButton(parent, text, width, confirmText, onConfirm)
    local b = FlatButton(parent, text, width)
    b:SetScript("OnClick", function(self)
        if self.armed then
            self.armed = nil
            self:SetText(text)
            onConfirm()
            return
        end
        self.armed = true
        self:SetText(confirmText)
        if C_Timer and C_Timer.After then
            C_Timer.After(4, function()
                if b.armed then b.armed = nil; b:SetText(text) end
            end)
        end
    end)
    AddRefresher(function() b.armed = nil; b:SetText(text) end)
    return b
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local function BuildWindowTab(p)
    local sw = HALF_W - 20
    local size = Card(p, "Size", 0, 0, PAGE_W, 150)
    FlatSlider(size, "Width", 12, -30, sw, "width", function(v) AHF:SetSize(v, AHF.db.height) end,
        "How wide the Auction House is. Extra width goes to the Name column. "
        .. "You can also drag the grip at its bottom right corner.")
    FlatSlider(size, "Height", 12, -76, sw, "height", function(v) AHF:SetSize(AHF.db.width, v) end,
        "How tall the Auction House is. Taller shows more rows in every list.")
    -- Scale is saved as a factor (1.25) and shown as a percentage (125%)
    -- Applied when the slider is let go: inside the Auction House the slider
    -- grows with it, so scaling while dragging would move it under the mouse
    local pending
    local scale
    scale = T.Slider(size, "Scale", COL2, -30, sw,
        function() return pending or math.floor(AHF.db.scale * 100 + 0.5) end,
        function(v)
            if scale and scale.dragging then pending = v else pending = nil; AHF:SetScale(v / 100) end
        end,
        AHF.LIMITS.scale[1] * 100, AHF.LIMITS.scale[2] * 100, "%", 5)
    scale:HookScript("OnMouseDown", function(self) self.dragging = true end)
    scale:HookScript("OnMouseUp", function(self)
        self.dragging = false
        if pending then
            local v = pending
            pending = nil
            AHF:SetScale(v / 100)
        end
    end)
    TipAll(scale, "Scale", "The size of everything in the Auction House: text, icons and the window. "
        .. "Changes when you let go of the slider.")
    AddRefresher(scale.Refresh)
    MutedNote(size, "Never bigger than your screen. Blizzard's own size is 800 × 538.", 12, -124)
    local reset = FlatButton(size, "Reset", 54, 18)
    reset:SetPoint("TOPRIGHT", -8, -6)
    reset:SetScript("OnClick", function() AHF:ResetWindow() end)
    TipAll(reset, "Reset", "Size, scale and position back to the defaults. Same as /ahf reset.")

    local pos = Card(p, "Position", 0, -160, PAGE_W, 120)
    Switch(pos, "Keep window in place", 12, -30, function() return AHF.db.locked end,
        function(v) AHF:SetLocked(v) end,
        "Off: drag the Auction House by its title bar to move it. Until you do, it opens where Blizzard puts it. "
        .. "Same as /ahf lock and /ahf unlock.")
    MutedNote(pos, "The title bar won't move it. Your position is saved either way.", NOTE_X, -52, PAGE_W - NOTE_X - 12)
    local back = FlatButton(pos, "Reset position", 130)
    back:SetPoint("TOPLEFT", 12, -78)
    back:SetScript("OnClick", function() AHF:ResetPosition() end)
    TipAll(back, "Reset position", "Puts the window back where Blizzard opens it. Size and scale stay as they are.")
end

local function BuildColumnsTab(p)
    local side = Card(p, "Category list", 0, 0, PAGE_W, 140)
    FlatSlider(side, "Category list width", 12, -30, HALF_W - 20, "sidebarWidth",
        function(v) AHF:SetSidebarWidth(v) end,
        "How wide the list of categories on the left of the Buy tab is. The results list makes room.")
    MutedNote(side, "Blizzard's own width is " .. AHF.BLIZZARD_SIDEBAR .. ".", 12, -76)
    T.RowLabel(side, "Category text size", 12, -102)
    local catLabels = {}
    for _, v in ipairs(AHF.CATEGORY_TEXT_SCALES) do catLabels[v] = (v == 100) and "Default" or (v .. "%") end
    local catSize = T.Dropdown(side, 120, AHF.CATEGORY_TEXT_SCALES, catLabels,
        function() return AHF.db.categoryTextScale end, function(v) AHF:SetCategoryTextScale(v) end)
    catSize:SetPoint("TOPLEFT", 150, -100)
    catSize.menuTitle = "Category text size"
    TipAll(catSize, "Category text size", "The size of the text in the category list. The buttons get taller "
        .. "with bigger text. Default is the game's own size; the others are a percentage of it.")
    AddRefresher(catSize.Refresh)
    local reset = FlatButton(side, "Reset", 54, 18)
    reset:SetPoint("TOPRIGHT", -8, -6)
    reset:SetScript("OnClick", function()
        AHF:SetSidebarWidth(AHF.BLIZZARD_SIDEBAR)
        AHF:SetCategoryTextScale(100)
    end)
    TipAll(reset, "Reset", "The category list back to Blizzard's width and text size.")

    local cols = Card(p, "Columns", 0, -150, PAGE_W, 198)
    MutedNote(cols, "Drag the line between two column headers to resize a column. Double-click it for "
        .. "the column's default width. The Name column takes the rest of the room.", 12, -30, PAGE_W - 24)
    MutedNote(cols, "Hide, show and reorder columns on the Show & Order tab. Everything is saved for each "
        .. "character, for every list (Buy, Sell, Auctions), columns from other addons included.", 12, -62, PAGE_W - 24)

    T.RowLabel(cols, "Row text size", 12, -100)
    local labels = {}
    for _, v in ipairs(AHF.TEXT_SCALES) do labels[v] = (v == 100) and "Default" or (v .. "%") end
    local size = T.Dropdown(cols, 120, AHF.TEXT_SCALES, labels,
        function() return AHF.db.rowTextScale end, function(v) AHF:SetRowTextScale(v) end)
    size:SetPoint("TOPLEFT", 150, -98)
    size.menuTitle = "Row text size"
    TipAll(size, "Row text size", "The size of the text in every list's rows: names, prices, quantities. "
        .. "Rows get taller with bigger text. Default is the game's own size; the others are a percentage of it.")
    AddRefresher(size.Refresh)

    local count = Text(cols, "", "GameFontHighlightSmall")
    count:SetPoint("TOPLEFT", 12, -140)
    AddRefresher(function()
        local n = AHF:SavedColumnCount()
        count:SetText(n == 0 and "All columns have their default width."
            or (n == 1 and "1 column has its own width." or (n .. " columns have their own width.")))
    end)
    local resetCols = FlatButton(cols, "Reset all columns", 160)
    resetCols:SetPoint("TOPLEFT", 12, -164)
    resetCols:SetScript("OnClick", function() AHF:ResetColumns() end)
    TipAll(resetCols, "Reset all columns", "Every list back to Blizzard's columns: all shown, in their default "
        .. "order and width, for this character. Same as /ahf columns.")
end

-- Names of the lists, for the Show & Order tab
local LIST_LABELS = {
    browse = "Buy: search results",
    itemBuy = "Buy: item auctions",
    commoditiesBuy = "Buy: commodity auctions",
    itemSell = "Sell: your item's auctions",
    commoditiesSell = "Sell: your commodity's auctions",
    allAuctions = "Auctions: all",
    bids = "Auctions: bids",
    auctionsItem = "Auctions: one item",
    auctionsCommodities = "Auctions: one commodity",
}
AHF.LIST_LABELS = LIST_LABELS

local MAX_ROWS = 9
local ROW_H = 28
local function BuildOrderTab(p)
    local C = T.C
    local card = Card(p, "Columns shown", 0, 0, PAGE_W, 380)
    local selected = "browse"
    local keys = {}

    T.RowLabel(card, "List", 12, -32)
    local pick = T.Dropdown(card, 240, keys, function(k) return LIST_LABELS[k] or k end,
        function() return selected end,
        function(k) selected = k; RunRefreshers() end)
    pick:SetPoint("TOPLEFT", 52, -30)
    pick.menuTitle = "List"
    TipAll(pick, "List", "Which Auction House list to set up. Each list keeps its own columns.")

    local resetList = FlatButton(card, "Show all, default order", 170)
    T.Disabler(resetList, { resetList })
    resetList:SetPoint("TOPRIGHT", -12, -30)
    resetList:SetScript("OnClick", function(self)
        if not self.disabled then AHF:ResetColumnLayout(selected) end
    end)
    TipAll(resetList, "Show all, default order", "Shows every column of this list again, in Blizzard's "
        .. "order. Widths stay as they are.")

    -- Table: a header line, then one striped row per column
    local TOP, W = -66, PAGE_W - 24
    local head = CreateFrame("Frame", nil, card)
    head:SetPoint("TOPLEFT", 12, TOP)
    head:SetSize(W, 18)
    local hShown = Text(head, "SHOWN", "GameFontNormalSmall", C.orange)
    hShown:SetPoint("LEFT", 8, 0)
    local hName = Text(head, "COLUMN", "GameFontNormalSmall", C.orange)
    hName:SetPoint("LEFT", 60, 0)
    local hMove = Text(head, "MOVE", "GameFontNormalSmall", C.orange)
    hMove:SetPoint("RIGHT", -8, 0)
    hMove:SetJustifyH("RIGHT")
    local line = head:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    line:SetColorTexture(unpack(C.line))

    local rows = {}
    for i = 1, MAX_ROWS do
        local r = CreateFrame("Frame", nil, card)
        r:SetPoint("TOPLEFT", 12, TOP - 20 - (i - 1) * ROW_H)
        r:SetSize(W, ROW_H)
        if i % 2 == 0 then T.Fill(r, C.field) end
        r.switch = T.SwitchWidget(r)
        r.switch:SetPoint("LEFT", 10, 0)
        T.Disabler(r.switch, { r.switch })
        r.switch:SetScript("OnClick", function(self)
            if self.disabled or not r.name then return end
            AHF:SetColumnShown(selected, r.name, not self.on)
        end)
        TipAll(r.switch, "Show this column", "Off hides the column in this list; it comes back when you "
            .. "turn it on. The Name column always shows: it takes the rest of the room.")
        r.label = Text(r, "", "GameFontHighlight")
        r.label:SetPoint("LEFT", 60, 0)
        r.note = Text(r, "", "GameFontDisableSmall")
        r.note:SetPoint("LEFT", r.label, "RIGHT", 8, 0)
        r.right = FlatButton(r, "Right", 54, 20)
        r.right:SetPoint("RIGHT", -6, 0)
        T.Disabler(r.right, { r.right })
        r.right:SetScript("OnClick", function(self)
            if not self.disabled and r.name then AHF:MoveColumn(selected, r.name, 1) end
        end)
        TipAll(r.right, "Move right", "Moves this column one place to the right in the list.")
        r.left = FlatButton(r, "Left", 54, 20)
        r.left:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
        T.Disabler(r.left, { r.left })
        r.left:SetScript("OnClick", function(self)
            if not self.disabled and r.name then AHF:MoveColumn(selected, r.name, -1) end
        end)
        TipAll(r.left, "Move left", "Moves this column one place to the left in the list.")
        rows[i] = r
    end
    local foot = MutedNote(card, "", 12, TOP - 20 - MAX_ROWS * ROW_H - 8, PAGE_W - 24)
    local empty = MutedNote(card, "No lists yet. Open the Auction House and look at a list once (search, "
        .. "or pick an item); its columns then show up here.", 12, TOP - 28, PAGE_W - 24)

    AddRefresher(function()
        local known = AHF:KnownColumnLists()
        for i = #keys, 1, -1 do keys[i] = nil end
        local found = false
        for i, k in ipairs(known) do keys[i] = k; if k == selected then found = true end end
        if not found and keys[1] then selected = keys[1] end
        pick:Refresh()
        pick:SetDisabled(#keys == 0)
        resetList:SetDisabled(#keys == 0)
        local list = (#keys > 0) and AHF:ListColumns(selected) or {}
        empty:SetShown(#list == 0)
        head:SetShown(#list > 0)
        for i, r in ipairs(rows) do
            local c = list[i]
            r.name = c and c.name
            r:SetShown(c ~= nil)
            if c then
                r.label:SetText(c.name)
                r.note:SetText(c.fill and "always shown" or "")
                r.switch:SetOn(c.shown)
                r.switch:SetDisabled(c.fill)
                r.label:SetAlpha(c.shown and 1 or 0.5)
                r.left:SetDisabled(i == 1)
                r.right:SetDisabled(i == #list)
            end
        end
        foot:ClearAllPoints()
        foot:SetPoint("TOPLEFT", 12, TOP - 20 - math.min(#list, MAX_ROWS) * ROW_H - 10)
        if #list > MAX_ROWS then
            foot:SetText((#list - MAX_ROWS) .. " more columns: move them left to reach them.")
        elseif #list > 0 then
            foot:SetText("Changes show in the Auction House straight away. Saved for this character.")
        else
            foot:SetText("")
        end
    end)
end

local function BuildGeneralTab(p)
    local other = Card(p, "General", 0, 0, PAGE_W, 112)
    Switch(other, "Show welcome screen after updates", 12, -30,
        function() return AHF.db.showSplash end, function(v) AHF.db.showSplash = v end,
        "What's new, once after each update. /ahf news shows it anytime.")
    local all = ConfirmButton(other, "Reset to default", 150, "Click again to reset", function()
        AHF:ResetAll()
        RunRefreshers()
        AHF.Print("every setting is back to its default.")
    end)
    all:SetPoint("TOPLEFT", 12, -30 - ROW - 8)
    TipAll(all, "Reset to default", "Every setting back to its default: size, position, scale, lock, "
        .. "category list, row text size and this character's columns. Click twice to confirm.")

    local cmds = Card(p, "Commands", 0, -122, PAGE_W, 118)
    local half = math.ceil(#AHF.COMMANDS / 2)
    for i, c in ipairs(AHF.COMMANDS) do
        local col, row = (i <= half) and 0 or 1, (i - 1) % half
        local fs = Text(cmds, "|cff8fd3ff" .. c[1] .. "|r  " .. c[2], "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 12 + col * (COL2 - 12), -28 - row * 17)
        fs:SetWidth(COL2 - 30)
    end

    local support = Card(p, "Support", 0, -250, PAGE_W, 76)
    MutedNote(support, "Found a bug or have an idea? Report it on GitHub (link on the CurseForge page). "
        .. "Enjoying the addon? Tips on Ko-fi keep it updated: ko-fi.com/tauntmasterforever", 12, -30, PAGE_W - 24)
end

local TABS = {
    { key = "window",  label = "Window",  icon = "Interface\\Icons\\INV_Misc_Spyglass_03", build = BuildWindowTab },
    { key = "columns", label = "Columns", icon = "Interface\\Icons\\INV_Misc_Note_01",     build = BuildColumnsTab },
    { key = "order",   label = "Show & Order", icon = "Interface\\Icons\\INV_Misc_Book_09",  build = BuildOrderTab },
    { key = "general", label = "General", icon = "Interface\\Icons\\INV_Misc_Gear_01",     build = BuildGeneralTab },
}

local win

local function BuildWindow()
    win = T.Window({
        name = "AuctionHouseForeverConfig",
        tabs = TABS,
        hint = "/ahf opens these settings. /ahf news shows what's new.",
        version = function() return AHF.CurrentNewsVersion and AHF:CurrentNewsVersion() end,
        onShow = RunRefreshers,
        onHide = function() if AHF.embedded then AHF:HideTabPanel() end end,
    })
    -- The X (header) and Close (footer) buttons, hidden while the window sits
    -- in the Auction House's own tab
    win.closeButtons = {}
    for _, part in ipairs({ win.header, win.footer }) do
        for _, child in ipairs({ part:GetChildren() }) do
            if child.GetObjectType and child:GetObjectType() == "Button" then
                win.closeButtons[#win.closeButtons + 1] = child
            end
        end
    end
    AHF.configWindow = win
end

function AHF:GetConfigWindow()
    if not win then BuildWindow() end
    return win
end

-- A setting changed from a command: repaint the window if it's open
AHF.optionsRefresh = function()
    if win and win:IsShown() then RunRefreshers() end
end

-- nil toggles the window; a tab key opens that tab
function AHF:ToggleConfig(tab)
    if not win then BuildWindow() end
    -- With the Auction House open, the settings open in its own tab
    if self.frame and self.frame:IsShown() and self.ShowTabPanel then
        if not tab and self.embedded and win:IsShown() then self:HideTabPanel() return end
        if self:ShowTabPanel(tab) then return end
    end
    if not tab and win:IsShown() then win:Hide() return end
    win:Show()
    win:Raise()
    if tab and win.pages[tab] then win:ShowTab(tab) end
end

---------------------------------------------------------------------------
-- Interface Options entry (Options > AddOns): a short page with a button
-- that opens the settings window
---------------------------------------------------------------------------
function AHF:RegisterSettingsCategory()
    if self.settingsCategory then return end
    local panel = CreateFrame("Frame")
    panel.name = T.NAME
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(64, 64)
    logo:SetPoint("TOPLEFT", 16, -16)
    logo:SetTexture(T.LOGO)
    local title = Text(panel, T.NAME, "GameFontNormalLarge", T.C.gold, 20)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -8)
    local sub = Text(panel, "Resize, move and scale the Auction House, and drag its columns wider.",
        "GameFontHighlight", T.C.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    local open = FlatButton(panel, "Open settings", 140, 24)
    open:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -16)
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel.Hide then SettingsPanel:Hide() end
        AHF:ToggleConfig("window")
    end)
    local hint = Text(panel, "Or type /ahf", "GameFontDisableSmall")
    hint:SetPoint("LEFT", open, "RIGHT", 12, 0)
    self.settingsPanel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, T.NAME)
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
            self.settingsCategory = category
        end
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        self.settingsCategory = panel
    end
end
