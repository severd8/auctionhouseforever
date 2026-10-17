-- AuctionHouse Forever: the Resale tab at the bottom of the auction house.
-- Lists the listings from your last full scan that sell below their usual
-- price: buy them and post them again for a profit. Clicking a row searches
-- for the item on the Buy tab; buying is always your own click on the game's
-- buttons.

local _, ns = ...
local T, P, AHF = ns.Theme, ns.Prices, ns.AHF
local C, Text = T.C, T.Text

AHF.AH_CUT = 0.05            -- the auction house keeps 5% of a sale
AHF.RESALE_MIN_PROFIT = 100  -- copper (1 silver): smaller ones aren't worth the trip
AHF.RESALE_MIN_PCT = 10      -- percent
AHF.RESALE_MAX = 500         -- rows kept (the best ones)
AHF.RESALE_DAYS = 14         -- the usual price: the 14 day average (else the newest market price)

local TAB_ID = "AuctionHouseForeverResale"
local ROWS, ROW_H = 22, 18

---------------------------------------------------------------------------
-- The numbers
---------------------------------------------------------------------------
-- The usual price of an item: its 14 day average, else its newest market price
function AHF:UsualPrice(key)
    local recs = self:Records(key)
    if not recs or #recs == 0 then return nil end
    local avg = P.Average(recs, self.RESALE_DAYS, P.Day(self.Now()))
    if avg then return avg end
    local last = recs[#recs]
    return last.v > 0 and last.v or nil
end

-- What reselling a listing makes: what it sells for at the usual price, less
-- the auction house's cut, less what you pay for it
function AHF.ResaleProfit(usual, qty, buyout)
    local profit = math.floor(usual * qty * (1 - AHF.AH_CUT)) - buyout
    return profit, buyout > 0 and profit * 100 / buyout or 0
end

-- Rows: { key, itemID, link, name, qty, buyout, usual, profit, pct }, best profit
-- first; and how many there were before keeping the best RESALE_MAX
function AHF:ResaleRows()
    local scan = self.lastScan
    if not scan then return nil end
    local rows = {}
    for _, key in ipairs(scan.keys) do
        local usual = self:UsualPrice(key)
        if usual then
            for _, l in ipairs(scan.byKey[key]) do
                local qty, buyout = l[2], l[3]
                local profit, pct = self.ResaleProfit(usual, qty, buyout)
                if profit >= self.RESALE_MIN_PROFIT and pct >= self.RESALE_MIN_PCT then
                    rows[#rows + 1] = { key = key, itemID = scan.itemIDs and scan.itemIDs[key], link = scan.links[key],
                        name = scan.names[key], qty = qty, buyout = buyout, usual = usual, profit = profit, pct = pct }
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.profit > b.profit end)
    local found = #rows
    for i = #rows, self.RESALE_MAX + 1, -1 do rows[i] = nil end
    return rows, found
end

---------------------------------------------------------------------------
-- Finding a row's item on the Buy tab
---------------------------------------------------------------------------
-- The scan doesn't always have an item's name and link (the game hadn't loaded
-- the item yet): ask the game for it, and draw again when it arrives
local waiting = {}
local function ItemName(row)
    if row.name then return row.name end
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name, link
    if get and (row.link or row.itemID) then name, link = get(row.link or row.itemID) end
    if name then
        row.name = name
        if not row.link then row.link = link end
        return name
    end
    if row.link then return row.link:match("%[(.-)%]") end
    if row.itemID and not waiting[row.itemID] and C_Item and C_Item.RequestLoadItemDataByID then
        waiting[row.itemID] = true
        C_Item.RequestLoadItemDataByID(row.itemID)
    end
    return nil
end

function AHF:FindOnBuyTab(row)
    local name = ItemName(row)
    local f = AuctionHouseFrame
    if not name or not f then return false end
    if f.SetDisplayMode and AuctionHouseFrameDisplayMode then
        pcall(f.SetDisplayMode, f, AuctionHouseFrameDisplayMode.Buy)
    end
    local bar = f.SearchBar
    if not bar or not bar.SetSearchText or not bar.StartSearch then return false end
    bar:SetSearchText(name)
    bar:StartSearch()
    return true
end

---------------------------------------------------------------------------
-- The tab's page
---------------------------------------------------------------------------
local COLUMNS = {
    { key = "name",   label = "Item",        w = 330, left = true },
    { key = "pct",    label = "Pct",         w = 56 },
    { key = "profit", label = "Profit",      w = 116 },
    { key = "qty",    label = "Qty",         w = 40 },
    { key = "buyout", label = "Buyout",      w = 116 },
    { key = "usual",  label = "Market each", w = 116 },
}

local panel, rows, shown = nil, {}, {}
local sortKey, sortDown, offset = "profit", true, 0

local function Sort()
    table.sort(shown, function(a, b)
        local x, y = a[sortKey], b[sortKey]
        if sortKey == "name" then x, y = ItemName(a) or "", ItemName(b) or "" end
        if x == y then return a.profit > b.profit end
        if sortDown then return x > y end
        return x < y
    end)
end

local function Cell(row, c, text)
    row.cells[c.key]:SetText(text)
end

local function Draw()
    if not panel then return end
    local range = math.max(0, #shown - ROWS)
    offset = math.max(0, math.min(offset, range))
    panel.bar:SetMinMaxValues(0, range)
    panel.bar:SetShown(range > 0)
    for i = 1, ROWS do
        local row, data = rows[i], shown[offset + i]
        row.data = data
        row:SetShown(data ~= nil)
        if data then
            local name = ItemName(data)
            Cell(row, COLUMNS[1], data.link or name or "|cff8a8078Loading item " .. (data.itemID or data.key) .. "...|r")
            Cell(row, COLUMNS[2], string.format("%d%%", data.pct))
            Cell(row, COLUMNS[3], AHF.Money(data.profit))
            Cell(row, COLUMNS[4], tostring(data.qty))
            Cell(row, COLUMNS[5], AHF.Money(data.buyout))
            Cell(row, COLUMNS[6], AHF.Money(data.usual))
        end
    end
end

function AHF:RefreshResale()
    if not panel or not panel:IsShown() then return end
    local list, found = self:ResaleRows()
    shown = list or {}
    Sort()
    offset = 0
    if not list then
        panel.info:SetText("Do a full scan (the Scan button on the Buy tab) to fill this list.")
        panel.total:SetText("")
    else
        local total = 0
        for _, r in ipairs(shown) do total = total + r.profit end
        local count = found > #shown and string.format("%d listings below the usual price (the best %d shown)", found, #shown)
            or string.format("%d listing%s below the usual price", found, found == 1 and "" or "s")
        panel.info:SetText(string.format("From your full scan %s: %s. Click one to find it on the Buy tab.",
            AHF.Now() - self.lastScan.t < 60 and "just now" or (AHF.Age(AHF.Now() - self.lastScan.t) .. " ago"), count))
        panel.total:SetText(#shown > 0 and ("Profit if you resell " .. (found > #shown and "these " .. #shown or "them all")
            .. ": " .. AHF.Money(total)) or "")
    end
    Draw()
end

local function BuildPanel(f)
    panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -22)
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    panel:SetFrameLevel((f:GetFrameLevel() or 0) + 40)
    panel:EnableMouse(true)
    T.Fill(panel, C.win)
    AHF.resalePanel = panel

    -- starts right of the auction house's round portrait, which overlaps the top left
    local info = Text(panel, "", "GameFontHighlight")
    info:SetPoint("TOPLEFT", 64, -10)
    info:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    panel.info = info

    -- Headers: click to sort, again to turn the order round
    local x = 12
    panel.headers = {}
    for _, c in ipairs(COLUMNS) do
        local h = CreateFrame("Button", nil, panel)
        h:SetSize(c.w, 20)
        h:SetPoint("TOPLEFT", x, -34)
        T.Fill(h, C.card)
        local fs = Text(h, c.label, "GameFontNormalSmall", C.orange)
        if c.left then fs:SetPoint("LEFT", 6, 0) else fs:SetPoint("RIGHT", -6, 0); fs:SetJustifyH("RIGHT") end
        h:SetScript("OnClick", function()
            if sortKey == c.key then sortDown = not sortDown
            else sortKey, sortDown = c.key, c.key ~= "name" end
            Sort()
            Draw()
        end)
        panel.headers[c.key] = h
        c.x = x
        x = x + c.w + 2
    end

    -- Rows
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(x - 14, ROW_H)
        row:SetPoint("TOPLEFT", 12, -56 - (i - 1) * ROW_H)
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        row.cells = {}
        for _, c in ipairs(COLUMNS) do
            local fs = Text(row, "", "GameFontHighlightSmall")
            fs:SetWidth(c.w - 12)
            fs:SetWordWrap(false)
            if c.left then
                fs:SetPoint("LEFT", row, "LEFT", c.x - 12 + 6, 0)
            else
                fs:SetPoint("RIGHT", row, "LEFT", c.x - 12 + c.w - 6, 0)
                fs:SetJustifyH("RIGHT")
            end
            row.cells[c.key] = fs
        end
        row:SetScript("OnClick", function(self) if self.data then AHF:FindOnBuyTab(self.data) end end)
        row:SetScript("OnEnter", function(self)
            if not self.data or not self.data.link then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.data.link)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = row
    end

    -- Scrolling: mouse wheel over the list, or the bar on the right
    local bar = CreateFrame("Slider", nil, panel)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(6)
    bar:SetPoint("TOPLEFT", panel, "TOPLEFT", x + 2, -56)
    bar:SetHeight(ROWS * ROW_H)
    T.Fill(bar, C.offTrack)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(6, 40)
    thumb:SetColorTexture(unpack(C.btnEdge))
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetScript("OnValueChanged", function(_, v)
        local new = math.floor(v + 0.5)
        if new ~= offset then offset = new; Draw() end
    end)
    panel.bar = bar
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta * 3)
        Draw()
        bar:SetValue(offset)
    end)

    local total = Text(panel, "", "GameFontNormal")
    total:SetPoint("BOTTOMLEFT", 12, 10)
    panel.total = total

    panel:SetScript("OnShow", function() AHF:RefreshResale() end)
    panel:Hide()
    AHF.resaleRows = rows
end

-- The tab itself comes from the bundled LibAHTab (the library Auctionator makes
-- its tabs with), so it sits in line with the game's tabs and Auctionator's
function AHF:MakeResaleTab()
    if panel or not AuctionHouseFrame then return end
    BuildPanel(AuctionHouseFrame)
    local lib = LibStub and LibStub("LibAHTab-1-0", true)
    if not lib then return end
    local ok, err = pcall(lib.CreateTab, lib, TAB_ID, panel, "Resale", "Resale")
    if ok then
        self.resaleTab = lib:GetButton(TAB_ID)
    else
        self.resaleTabError = err
    end
end

AHF:On("ADDON_LOADED", function(name)
    if name == "Blizzard_AuctionHouseUI" then AHF:MakeResaleTab() end
end)
AHF:On("GET_ITEM_INFO_RECEIVED", function(itemID)
    if not waiting[itemID] then return end
    waiting[itemID] = nil
    if panel and panel:IsShown() then Draw() end
end)
AHF:On("AUCTION_HOUSE_SHOW", function() AHF:MakeResaleTab() end)
