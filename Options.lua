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
    local scale = T.Slider(size, "Scale", COL2, -30, sw,
        function() return math.floor(AHF.db.scale * 100 + 0.5) end,
        function(v) AHF:SetScale(v / 100) end,
        AHF.LIMITS.scale[1] * 100, AHF.LIMITS.scale[2] * 100, "%", 5)
    TipAll(scale, "Scale", "The size of everything in the Auction House: text, icons and the window.")
    AddRefresher(scale.Refresh)
    MutedNote(size, "Never bigger than your screen. Blizzard's own size is 800 × 538.", 12, -124)
    local reset = FlatButton(size, "Reset", 54, 18)
    reset:SetPoint("TOPRIGHT", -8, -6)
    reset:SetScript("OnClick", function() AHF:ResetWindow() end)
    TipAll(reset, "Reset", "Size, scale and position back to the defaults. Same as /ahf reset.")

    local pos = Card(p, "Position", 0, -160, PAGE_W, 120)
    Switch(pos, "Lock the window", 12, -30, function() return AHF.db.locked end,
        function(v) AHF:SetLocked(v) end,
        "Unlocked: drag the Auction House by its title bar. Same as /ahf lock and /ahf unlock.")
    MutedNote(pos, "Until you drag it, the window opens where Blizzard puts it.", NOTE_X, -52, PAGE_W - NOTE_X - 12)
    local back = FlatButton(pos, "Reset position", 130)
    back:SetPoint("TOPLEFT", 12, -78)
    back:SetScript("OnClick", function() AHF:ResetPosition() end)
    TipAll(back, "Reset position", "Puts the window back where Blizzard opens it. Size and scale stay as they are.")
end

local function BuildColumnsTab(p)
    local side = Card(p, "Category list", 0, 0, PAGE_W, 104)
    FlatSlider(side, "Category list width", 12, -30, HALF_W - 20, "sidebarWidth",
        function(v) AHF:SetSidebarWidth(v) end,
        "How wide the list of categories on the left of the Buy tab is. The results list makes room.")
    MutedNote(side, "Blizzard's own width is " .. AHF.BLIZZARD_SIDEBAR .. ".", 12, -76)
    local reset = FlatButton(side, "Reset", 54, 18)
    reset:SetPoint("TOPRIGHT", -8, -6)
    reset:SetScript("OnClick", function() AHF:SetSidebarWidth(AHF.BLIZZARD_SIDEBAR) end)
    TipAll(reset, "Reset", "The category list back to Blizzard's width.")

    local cols = Card(p, "Column widths", 0, -114, PAGE_W, 150)
    MutedNote(cols, "Drag the line between two column headers to resize a column. Double-click it for "
        .. "the column's default width. The Name column takes the rest of the room.", 12, -30, PAGE_W - 24)
    MutedNote(cols, "Widths are saved for each character, for every list (Buy, Sell, Auctions). "
        .. "Columns added by other addons can be resized too.", 12, -62, PAGE_W - 24)
    local count = Text(cols, "", "GameFontHighlightSmall")
    count:SetPoint("TOPLEFT", 12, -96)
    AddRefresher(function()
        local n = AHF:SavedColumnCount()
        count:SetText(n == 0 and "All columns have their default width."
            or (n == 1 and "1 column has its own width." or (n .. " columns have their own width.")))
    end)
    local resetCols = FlatButton(cols, "Reset column widths", 160)
    resetCols:SetPoint("TOPLEFT", 12, -116)
    resetCols:SetScript("OnClick", function() AHF:ResetColumns() end)
    TipAll(resetCols, "Reset column widths", "Every column back to its default width, for this character. "
        .. "Same as /ahf columns.")
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
        .. "category list and this character's column widths. Click twice to confirm.")

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
    })
    AHF.configWindow = win
end

-- A setting changed from a command: repaint the window if it's open
AHF.optionsRefresh = function()
    if win and win:IsShown() then RunRefreshers() end
end

-- nil toggles the window; a tab key opens that tab
function AHF:ToggleConfig(tab)
    if not win then BuildWindow() end
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
