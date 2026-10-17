-- AuctionHouse Forever: reading prices from the auction house. A full scan
-- (C_AuctionHouse.ReplicateItems) and the normal searches you make.

local _, ns = ...
local T, P, AHF = ns.Theme, ns.Prices, ns.AHF

AHF.SCAN_TIMEOUT = 60     -- seconds to wait for the auction house to answer a full scan
AHF.SCAN_REPEAT = 60      -- the list arriving again this soon is the same scan

local scan = { state = "idle" }   -- idle, waiting, reading
AHF.scan = scan

local function AHOpen()
    return AuctionHouseFrame and AuctionHouseFrame:IsShown() and true or false
end

-- Seconds until the next full scan is allowed (0 = now)
function AHF:ScanWait()
    local last = self:Realm().lastFull or 0
    return math.max(0, last + self.db.cooldown * 60 - self.Now())
end

---------------------------------------------------------------------------
-- Full scan
---------------------------------------------------------------------------
function AHF:StartFullScan()
    if scan.state ~= "idle" then
        self:Print("a full scan is already running.")
        return false
    end
    if not AHOpen() then
        self:Print("open the auction house first.")
        return false
    end
    local wait = self:ScanWait()
    if wait > 0 then
        self:Print("the next full scan is possible in " .. self.Clock(wait) .. ".")
        return false
    end
    scan.state, scan.asked, scan.mine = "waiting", self.Now(), true
    self:Realm().lastFull = self.Now()
    C_AuctionHouse.ReplicateItems()
    self:Print("full scan started. This can take a little while.")
    self:RefreshScanButton()
    return true
end

-- One listing of the full scan list (0-based, as the game numbers them)
local function ReadListing(i)
    local name, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
    if not itemID then return nil end
    local link = C_AuctionHouse.GetReplicateItemLink(i)
    local key = AHF.KeyFromLink(link) or AHF.KeyFor(itemID)
    return key, itemID, count or 0, buyout or 0, owner, link, name
end

function AHF:ReadFullScan()
    local realm = self:Realm()
    scan.state = "reading"
    scan.started = debugprofilestop()
    self:RefreshScanButton()
    self:RunJob("full scan", function()
        local total = C_AuctionHouse.GetNumReplicateItems() or 0
        local byKey, keys, ids, links, names = {}, {}, {}, {}, {}
        local listings, noBuyout, distinctIDs = 0, 0, 0
        scan.total, scan.done = total, 0
        for i = 0, total - 1 do
            local key, itemID, count, buyout, owner, link, name = ReadListing(i)
            if key then
                listings = listings + 1
                if not ids[itemID] then ids[itemID] = true; distinctIDs = distinctIDs + 1 end
                if buyout > 0 and count > 0 then
                    local list = byKey[key]
                    if not list then list = {}; byKey[key] = list; keys[#keys + 1] = key end
                    -- price per item, quantity, buyout, seller (the Resale tab uses the last two)
                    list[#list + 1] = { math.ceil(buyout / count), count, buyout, owner }
                    if link and not links[key] then links[key] = link end
                    if name and not names[key] then names[key] = name end
                else
                    noBuyout = noBuyout + 1
                end
            end
            scan.done = i + 1
            if i % 50 == 0 then self:Pause() end
        end
        local now = self.Now()
        for n, key in ipairs(keys) do
            local sum = P.Summarize(byKey[key])
            if sum then
                self:Observe(key, { min = sum.min, market = sum.market, qty = sum.qty, t = now, full = true }, realm)
            end
            if n % 20 == 0 then self:Pause() end
        end
        -- every listing of this scan, for the Resale tab (kept until the next scan or logout)
        self.lastScan = { t = now, byKey = byKey, keys = keys, links = links, names = names }
        scan.result = { t = now, listings = listings, items = distinctIDs, keys = #keys, noBuyout = noBuyout,
            secs = math.floor((debugprofilestop() - scan.started) / 100 + 0.5) / 10 }
    end, function()
        local r = scan.result
        table.insert(realm.scans, 1, r)
        while #realm.scans > 10 do table.remove(realm.scans) end
        scan.state, scan.lastRead = "idle", self.Now()
        if self.db.scanChat then
            self:Print(string.format("full scan done: %d listings of %d different items (%d with only a bid). Prices saved for %d items.",
                r.listings, r.items, r.noBuyout, r.keys))
        end
        self:RefreshScanButton()
        if self.RefreshWindow then self:RefreshWindow() end
        if self.RefreshResale then self:RefreshResale() end
    end)
end

-- The list is ready. Also arrives when another addon (Auctionator) asks for a
-- full scan, so its scans fill our prices too.
AHF:On("REPLICATE_ITEM_LIST_UPDATE", function()
    if scan.state == "reading" then return end
    if scan.state ~= "waiting" and scan.lastRead and AHF.Now() - scan.lastRead < AHF.SCAN_REPEAT then return end
    if scan.state ~= "waiting" then AHF:Realm().lastFull = AHF.Now() end
    AHF:ReadFullScan()
end)

-- No answer: most likely the auction house's own wait isn't over
function AHF:CheckScanTimeout()
    if scan.state == "waiting" and self.Now() - scan.asked >= self.SCAN_TIMEOUT then
        scan.state = "idle"
        self:Print("the auction house didn't send the full scan. Its own wait between scans may not be over; try again later.")
        self:RefreshScanButton()
    end
end

---------------------------------------------------------------------------
-- Normal searches
---------------------------------------------------------------------------
local function BrowseResult(info, now)
    if type(info) ~= "table" or type(info.itemKey) ~= "table" then return end
    local price = info.minPrice
    if not price or price <= 0 then return end
    local key = AHF.KeyFor(info.itemKey.itemID, info.itemKey.itemSuffix)
    if key then AHF:Observe(key, { min = price, qty = info.totalQuantity or 0, t = now }) end
end

function AHF:RecordBrowse(results)
    local now = self.Now()
    for _, info in ipairs(results or {}) do BrowseResult(info, now) end
end

AHF:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function()
    AHF:RecordBrowse(C_AuctionHouse.GetBrowseResults())
end)
AHF:On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function(added)
    AHF:RecordBrowse(added)
end)

-- One item's listings. With the whole list there, it counts as a scan of that
-- item (market value too); with only part of it, just the lowest price.
local function Record(key, listings, full)
    local sum = P.Summarize(listings)
    if not sum then return end
    AHF:Observe(key, { min = sum.min, market = full and sum.market or nil, qty = sum.qty, t = AHF.Now() })
end

function AHF:RecordCommodity(itemID)
    local n = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    local listings = {}
    for i = 1, n do
        local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if r and r.unitPrice and r.quantity then listings[#listings + 1] = { r.unitPrice, r.quantity } end
    end
    Record(self.KeyFor(itemID), listings, C_AuctionHouse.HasFullCommoditySearchResults(itemID))
end

function AHF:RecordItem(itemKey)
    if type(itemKey) ~= "table" then return end
    local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    local listings = {}
    for i = 1, n do
        local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        -- buyoutAmount is the price of the whole auction; bid-only ones have none
        if r and r.buyoutAmount and r.quantity and r.quantity > 0 then
            listings[#listings + 1] = { math.ceil(r.buyoutAmount / r.quantity), r.quantity }
        end
    end
    Record(self.KeyFor(itemKey.itemID, itemKey.itemSuffix), listings, C_AuctionHouse.HasFullItemSearchResults(itemKey))
end

AHF:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID) AHF:RecordCommodity(itemID) end)
AHF:On("ITEM_SEARCH_RESULTS_UPDATED", function(itemKey) AHF:RecordItem(itemKey) end)

---------------------------------------------------------------------------
-- The Scan button, beside the auction house's search
---------------------------------------------------------------------------
function AHF:RefreshScanButton()
    local b = self.scanButton
    if not b then return end
    local text, off
    if scan.state == "waiting" then
        text, off = "...", true
    elseif scan.state == "reading" then
        local pct = scan.total and scan.total > 0 and math.floor((scan.done or 0) * 100 / scan.total) or 0
        text, off = pct .. "%", true
    else
        local wait = self:ScanWait()
        if wait > 0 then
            text, off = self.Clock(wait), true
        else
            text, off = "Scan", false
        end
    end
    b:SetText(text)
    if off then b:Disable() else b:Enable() end
end

-- A small red button like the game's Search button, in the gap between the
-- search box and Filter on the Buy tab's search bar (it shows and hides with it).
-- Its text: Scan, ... (waiting), 45% (reading), or the time left to wait.
AHF.SCAN_BUTTON_W = 80

function AHF:MakeScanButton()
    if self.scanButton or not AuctionHouseFrame then return end
    local bar = AuctionHouseFrame.SearchBar
    local filter = bar and (bar.FilterButton or bar.SearchButton)
    local b = CreateFrame("Button", nil, bar or AuctionHouseFrame, "UIPanelButtonTemplate")
    b:SetSize(self.SCAN_BUTTON_W, 22)
    if filter then
        b:SetPoint("RIGHT", filter, "LEFT", -10, 0)
    else
        b:SetPoint("TOPRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -4, -2)
    end
    b:SetText("Scan")
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", function() AHF:StartFullScan() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Full scan")
        GameTooltip:AddLine("Reads every listing in the auction house and saves the prices for AHF Market. Takes a few seconds.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local elapsed = 0
    b:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed < 0.5 then return end
        elapsed = 0
        AHF:CheckScanTimeout()
        AHF:RefreshScanButton()
    end)
    self.scanButton = b
    self:RefreshScanButton()
end

AHF:On("ADDON_LOADED", function(name)
    if name == "Blizzard_AuctionHouseUI" then AHF:MakeScanButton() end
end)
AHF:On("AUCTION_HOUSE_SHOW", function() AHF:MakeScanButton() end)
AHF:On("AUCTION_HOUSE_CLOSED", function()
    if scan.state == "waiting" then
        scan.state = "idle"
        AHF:Print("full scan stopped: the auction house was closed.")
    end
end)
