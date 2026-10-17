-- AuctionHouse Forever: the window (/ahf). Prices (what's saved, full scans),
-- Settings and What's new.

local _, ns = ...
local T, AHF = ns.Theme, ns.AHF
local C, Text = T.C, T.Text
local PAGE_W = T.WINDOW.PAGE_W

local refreshers = {}
local function AddRefresher(fn) refreshers[#refreshers + 1] = fn end

function AHF:RefreshWindow()
    if not self.window or not self.window:IsShown() then return end
    for _, fn in ipairs(refreshers) do fn() end
end

AHF.ui = {}

---------------------------------------------------------------------------
-- Prices tab
---------------------------------------------------------------------------
local function KB(bytes)
    if bytes < 1024 then return bytes .. " bytes" end
    return string.format("%.1f KB", bytes / 1024)
end

local function BuildPrices(p)
    local card = T.Card(p, "This auction house", 0, 0, PAGE_W, 130)
    local where = Text(card, "", "GameFontHighlight")
    where:SetPoint("TOPLEFT", 12, -30)
    local stored = Text(card, "", "GameFontHighlight")
    stored:SetPoint("TOPLEFT", 12, -52)
    local size = Text(card, "", "GameFontDisableSmall")
    size:SetPoint("TOPLEFT", 12, -74)
    T.Note(card, "Each realm and faction keeps its own prices, since their auction houses are separate.", 12, -96, PAGE_W - 24)

    local scanCard = T.Card(p, "Full scan", 0, -140, PAGE_W, 150)
    local last = Text(scanCard, "", "GameFontHighlight")
    last:SetPoint("TOPLEFT", 12, -30)
    local counts = Text(scanCard, "", "GameFontHighlight")
    counts:SetPoint("TOPLEFT", 12, -52)
    local nextScan = Text(scanCard, "", "GameFontNormal")
    nextScan:SetPoint("TOPLEFT", 12, -74)
    T.Note(scanCard, "Start a full scan with the red Scan button beside Search in the auction house, or type /ahf scan there. "
        .. "Searches you make in the auction house are saved too.", 12, -100, PAGE_W - 24)
    AHF.ui.where, AHF.ui.stored, AHF.ui.lastScan, AHF.ui.scanCounts, AHF.ui.nextScan = where, stored, last, counts, nextScan

    AddRefresher(function()
        local realm = AHF:Realm()
        where:SetText("Realm and faction: |cffffd100" .. AHF:RealmKey() .. "|r")
        local items, recs, bytes = AHF:Stats(realm)
        stored:SetText(string.format("Prices saved for |cffffd100%d|r items (%d days and weeks)", items, recs))
        size:SetText("About " .. KB(bytes) .. " in your saved file")
        local s = realm.scans[1]
        if s then
            last:SetText("Last full scan: " .. AHF.Age(AHF.Now() - s.t) .. (AHF.Now() - s.t >= 60 and " ago" or ""))
            counts:SetText(string.format("%d listings of %d different items, read in %.1f s", s.listings, s.items, s.secs or 0))
        else
            last:SetText("No full scan yet")
            counts:SetText("")
        end
        local wait = AHF:ScanWait()
        nextScan:SetText(wait > 0 and ("Next full scan possible in " .. AHF.Clock(wait)) or "A full scan is possible now")
    end)
end

---------------------------------------------------------------------------
-- Settings tab
---------------------------------------------------------------------------
local function Setting(parent, text, x, y, key, tip)
    local sw = T.LabeledSwitch(parent, text, x, y)
    sw:SetScript("OnClick", function(self)
        AHF.db[key] = not self:IsOn()
        AHF:RefreshWindow()
    end)
    if tip then T.Tooltip(sw, text, tip) end
    AddRefresher(function() sw:SetOn(AHF.db[key]) end)
    return sw
end

local function BuildSettings(p)
    local card = T.Card(p, "Tooltips", 0, 0, PAGE_W, 70)
    AHF.ui.tooltip = Setting(card, "Show AHF prices in item tooltips", 12, -32, "tooltip",
        "Adds AHF Vendor (what a vendor pays), AHF Market (the usual auction price) and, on weapons and armor, AHF Disenchant under items.")

    local card2 = T.Card(p, "Full scan", 0, -80, PAGE_W, 130)
    AHF.ui.scanChat = Setting(card2, "Say in chat when a full scan is done", 12, -32, "scanChat",
        "One line with how many listings and items it read.")
    local s = T.Slider(card2, "Wait between full scans", 12, -64, 300,
        function() return AHF.db.cooldown end,
        function(v) AHF.db.cooldown = v; AHF:RefreshScanButton() end,
        0, 60, " min", 1, "%d", "None")
    T.Tooltip(s, "Wait between full scans", "Forever lets you scan again straight away, so there's no wait to start with. "
        .. "If the auction house starts making you wait, set it here and the button counts down.")
    AddRefresher(s.Refresh)
    AHF.ui.cooldown = s
end

---------------------------------------------------------------------------
-- What's new tab
---------------------------------------------------------------------------
local function BuildNews(p)
    local scroll = T.ScrollArea(p, T.WINDOW.BODY_H)
    local lines = {}
    for _, entry in ipairs(AHF.NEWS or {}) do
        lines[#lines + 1] = "|cffffd100v" .. entry.version .. "|r  |cff8a8078" .. entry.date .. "|r"
        for _, item in ipairs(entry.items) do lines[#lines + 1] = "  - " .. item end
        lines[#lines + 1] = " "
    end
    local fs = Text(scroll.child, table.concat(lines, "\n"), "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 0, 0)
    fs:SetWidth(PAGE_W - 30)
    fs:SetWordWrap(true)
    fs:SetSpacing(3)
    local h = fs:GetStringHeight()
    scroll:SetContent(PAGE_W - 30, math.max(type(h) == "number" and h or 0, #lines * 17))
    AHF.ui.news = fs
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
function AHF:MakeWindow()
    if self.window then return self.window end
    self.window = T.Window({
        name = "AuctionHouseForeverWindow",
        tabs = {
            { key = "prices", label = "Prices", icon = "Interface\\Icons\\INV_Misc_Coin_01", build = BuildPrices },
            { key = "settings", label = "Settings", icon = "Interface\\Icons\\INV_Misc_Gear_01", build = BuildSettings },
            { key = "news", label = "What's new", icon = "Interface\\Icons\\INV_Misc_Note_01", build = BuildNews },
        },
        hint = "/ahf opens this window",
        version = function() return AHF:Version() end,
        onShow = function() AHF:RefreshWindow() end,
        onTab = function() AHF:RefreshWindow() end,
    })
    return self.window
end

function AHF:ToggleWindow()
    local w = self:MakeWindow()
    if w:IsShown() then w:Hide() else w:Show() end
end
