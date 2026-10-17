-- AuctionHouse Forever tests (run through tests/run.lua)

local function step(name) print("STEP " .. name) end
local function eq(got, want, what)
    if got ~= want then
        error((what or "value") .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2)
    end
end
local function has(text, part, what)
    if not tostring(text):find(part, 1, true) then
        error((what or "text") .. ": expected to find '" .. part .. "' in '" .. tostring(text) .. "'", 2)
    end
end
local function lastChat() return LOG[#LOG] or "" end
local function chatHas(part)
    for i = #LOG, math.max(1, #LOG - 10), -1 do
        if LOG[i]:find(part, 1, true) then return true end
    end
    return false
end

local ns = LoadAddon(".")
local AHF, P = ns.AHF, ns.Prices
local DAY = 86400

---------------------------------------------------------------------------
step("base 36 and the saved format")
for _, n in ipairs({ 0, 1, 35, 36, 1295, 123456789, 99999999999, -7 }) do
    eq(P.FromBase36(P.ToBase36(n)), n, "round trip " .. n)
end
local recs = {
    { d = 20000, s = 1, m = 260, v = 255, q = 40, n = 3, t = 1728000000 },
    { d = 20001, s = 1, m = 1, v = 0, q = 1, n = 0, t = 1728086400 },
}
local str = P.Encode(recs)
local back = P.Decode(str)
eq(#back, 2, "records back")
for i = 1, 2 do for k, v in pairs(recs[i]) do eq(back[i][k], v, "record " .. i .. " " .. k) end end
eq(#P.Decode("garbage;1,2;" .. str), 2, "broken records are skipped")
eq(#P.Decode(nil), 0, "nothing saved")

---------------------------------------------------------------------------
step("market value: middle of the cheapest listings, outliers ignored")
eq(P.MarketValue({ { 100, 1 } }), 100, "one listing")
-- 10 items: cheapest 30% = 3 items (100, 110, 120): middle 110
eq(P.MarketValue({ { 120, 1 }, { 100, 1 }, { 110, 1 }, { 130, 7 } }), 110, "cheapest share")
-- a pile of overpriced ones (more than 3x) doesn't push out the real prices
eq(P.MarketValue({ { 120, 1 }, { 100, 1 }, { 110, 1 }, { 500, 7 } }), 100, "pile of overpriced")
-- three silly cheap ones (1 copper) among 10 at 100 are ignored
eq(P.MarketValue({ { 1, 3 }, { 100, 10 } }), 100, "low outliers ignored")
-- and so are silly expensive ones
eq(P.MarketValue({ { 100, 2 }, { 101, 1 }, { 99999, 1 } }), 100, "high outlier ignored")
-- quantities count: a stack of 50 at 90 outweighs singles
eq(P.MarketValue({ { 90, 50 }, { 80, 1 }, { 85, 1 } }), 90, "weighted by quantity")
eq(P.MarketValue({}), nil, "no listings")
eq(P.MarketValue({ { 0, 5 } }), nil, "only bids")
local sum = P.Summarize({ { 120, 2 }, { 100, 3 }, { 0, 4 } })
eq(sum.min, 100, "lowest"); eq(sum.qty, 5, "quantity")

---------------------------------------------------------------------------
step("adding data: one record per day")
local T0 = 20000 * DAY + 3600
recs = {}
P.Add(recs, { min = 100, market = 110, qty = 10, t = T0, full = true })
P.Add(recs, { min = 90, market = 130, qty = 12, t = T0 + 7200, full = true })
eq(#recs, 1, "same day")
eq(recs[1].m, 90, "lowest of the day"); eq(recs[1].v, 120, "market averaged"); eq(recs[1].n, 2, "two scans")
eq(recs[1].q, 12, "newest quantity")
-- a browse result: only the lowest price
P.Add(recs, { min = 80, qty = 3, t = T0 + 7300 })
eq(recs[1].m, 80, "browse lowers the lowest"); eq(recs[1].v, 120, "browse leaves market"); eq(recs[1].n, 2, "not a scan")
-- a search minutes after the last data refines, doesn't count again
P.Add(recs, { min = 85, market = 150, qty = 4, t = T0 + 7400 })
eq(recs[1].n, 2, "search soon after isn't another scan")
eq(recs[1].v, 130, "but moves the market")
P.Add(recs, { min = 85, market = 130, qty = 4, t = T0 + 7400 + P.SEARCH_GAP })
eq(recs[1].n, 3, "a later search counts")
P.Add(recs, { min = 70, market = 75, qty = 4, t = T0 + DAY })
eq(#recs, 2, "next day, new record")
-- data for an earlier day goes before
P.Add(recs, { min = 70, market = 75, qty = 4, t = T0 - DAY })
eq(recs[1].d, 19999, "kept in order")

---------------------------------------------------------------------------
step("old days become weeks; very old weeks go")
recs = {}
local today = 20100
for d = today - 40, today do
    P.Add(recs, { min = 100 + (today - d), market = 200, qty = 10, t = d * DAY + 100, full = true })
end
local out, changed = P.Condense(recs, today)
eq(changed, true, "changed")
local days, weeks = 0, 0
for _, r in ipairs(out) do
    if r.s == 1 then days = days + 1; assert(r.d > today - P.KEEP_DAILY, "only recent days stay daily")
    else weeks = weeks + 1; eq(P.WeekStart(r.d), r.d, "weeks start on Monday") end
end
eq(days, P.KEEP_DAILY, "daily records kept")
assert(weeks >= 4 and weeks <= 5, "about 4 weeks, got " .. weeks)
local first = out[1]
eq(first.v, 200, "week market"); assert(first.n >= 1, "scans add up")
local lowest = math.huge
for _, r in ipairs(recs) do if P.WeekStart(r.d) == first.d and r.d <= today - P.KEEP_DAILY then lowest = math.min(lowest, r.m) end end
eq(first.m, lowest, "week keeps the lowest price")
assert(#P.Encode(out) < #P.Encode(recs), "smaller")
local again, changed2 = P.Condense(out, today)
eq(changed2, false, "nothing more to do"); eq(#again, #out, "same")
-- a day later, one more day joins an existing week
local later = P.Condense(out, today + 1)
local n1, n2 = 0, 0
for _, r in ipairs(out) do n1 = n1 + r.n end
for _, r in ipairs(later) do n2 = n2 + r.n end
eq(n2, n1, "no scans lost when joining")
eq(#P.Condense(out, today + P.KEEP_DAYS + 60), 0, "a year later all gone")

---------------------------------------------------------------------------
step("averages")
recs = {
    { d = 99, s = 1, m = 50, v = 100, q = 1, n = 1, t = 0 },
    { d = 100, s = 1, m = 50, v = 200, q = 1, n = 3, t = 0 },
}
local avg, scans = P.Average(recs, 3, 100)
eq(avg, 175, "weighted by scans"); eq(scans, 4, "scans")
eq(P.Average(recs, 3, 200), nil, "too old")

---------------------------------------------------------------------------
step("item keys from links")
eq(AHF.KeyFromLink(ItemLink(2589)), "2589", "plain")
eq(AHF.KeyFromLink(ItemLink(15210, 1018)), "15210:1018", "random suffix")
eq(AHF.KeyFromLink(ItemLink(15210, -42)), "15210:-42", "negative suffix")
eq(AHF.KeyFromLink("nonsense"), nil, "not a link")
eq(AHF.KeyFor(2589, 0), "2589"); eq(AHF.KeyFor(2589, 7), "2589:7")
eq(AHF.Money(26061, true), "2g 60s 61c"); eq(AHF.Money(250, true), "2s 50c"); eq(AHF.Money(0, true), "0c")
eq(AHF.Clock(754), "12:34")

---------------------------------------------------------------------------
step("full scan: needs the auction house open")
eq(AHF:StartFullScan(), false, "closed")
has(lastChat(), "open the auction house first")
OpenAuctionHouse()
local button = AHF.scanButton
assert(button, "Full scan button made")
eq(button.__parent, AuctionHouseFrame.SearchBar, "on the search bar")
eq(button.__points[1][2], AuctionHouseFrame.SearchBar.FilterButton, "beside Filter and Search")
eq(button:GetText(), "Scan", "button ready")
eq(button.__template, "UIPanelButtonTemplate", "the game's red button, like Search")
eq(button.__w, 80, "small enough for the gap")
eq(button.__points[1][4], -10, "same gap as Filter to Search")

step("full scan: reads every listing over several frames")
AH.replicate = {}
-- 3000 listings of 1000 items; item 3824 (Shadowgem) has a few
for i = 1, 2994 do AH.replicate[#AH.replicate + 1] = { 10000 + (i % 1000), 1, 500 + (i % 7) } end
table.insert(AH.replicate, { 3824, 2, 520 })      -- 260 each
table.insert(AH.replicate, { 3824, 1, 250 })
table.insert(AH.replicate, { 3824, 5, 1350 })     -- 270 each
table.insert(AH.replicate, { 3824, 1, 0 })        -- bid only
table.insert(AH.replicate, { 15210, 1, 9000, 1018 })
table.insert(AH.replicate, { 15210, 1, 5000, 1019 })
Click(button)
eq(AH.replicateCalls, 1, "asked the game")
eq(button:GetText(), "...", "waiting"); eq(button.__enabled, false, "greyed out while waiting")
FireEvent("REPLICATE_ITEM_LIST_UPDATE")
local frames = RunJobs()
assert(frames > 3, "spread over frames (took " .. frames .. ")")
assert(chatHas("full scan done: 3000 listings of 1002 different items (1 with only a bid)"), "chat line: " .. lastChat())
local r = AHF:Records("3824")
eq(r[1].m, 250, "Shadowgem lowest"); eq(r[1].q, 8, "Shadowgem quantity"); eq(r[1].n, 1, "one scan")
eq(r[1].v, 260, "Shadowgem market")
eq(AHF:Records("15210:1018")[1].m, 9000, "suffix kept apart")
eq(AHF:Records("15210:1019")[1].m, 5000, "other suffix")

step("full scan: no wait unless one is set")
eq(button:GetText(), "Scan", "ready straight away"); eq(button.__enabled, true, "clickable")
AHF.db.cooldown = 15
Tick(1)
eq(button:GetText(), "15:00", "counts down")
eq(button.__enabled, false, "greyed out during the wait")
local calls = AH.replicateCalls
Click(button)
eq(AH.replicateCalls, calls, "clicking it does nothing")
eq(AHF:StartFullScan(), false, "too soon")
has(lastChat(), "possible in 15:00")
SERVER_TIME = SERVER_TIME + 14 * 60
Tick(1)
eq(button:GetText(), "1:00")
SERVER_TIME = SERVER_TIME + 60
Tick(1)
eq(button:GetText(), "Scan", "ready again")
AHF.db.cooldown = 0
Tick(1)

step("full scan: no answer from the auction house")
Click(button)
eq(AH.replicateCalls, 2, "asked again")
SERVER_TIME = SERVER_TIME + AHF.SCAN_TIMEOUT
Tick(1)
assert(chatHas("didn't send the full scan"), "timeout message")
eq(AHF.scan.state, "idle", "back to idle")

step("full scan: Auctionator's scans count too")
SERVER_TIME = SERVER_TIME + 20 * 60
local before = AHF:Records("3824")[1].n
AH.replicate = { { 3824, 1, 240 } }
FireEvent("REPLICATE_ITEM_LIST_UPDATE")
RunJobs()
eq(AHF:Records("3824")[1].m, 240, "lowest from Auctionator's scan")
eq(AHF:Records("3824")[1].n, before + 1, "counted")
FireEvent("REPLICATE_ITEM_LIST_UPDATE")
eq(AHF:JobRunning("full scan"), false, "the same list again isn't read twice")

---------------------------------------------------------------------------
step("searches: commodities, items and browse results")
SERVER_TIME = SERVER_TIME + DAY
AH.commodities[2589] = { { 13, 20 }, { 14, 100 }, { 15, 200 }, { 99, 5 } }
FireEvent("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
r = AHF:Records("2589")
eq(r[1].m, 13, "commodity lowest"); eq(r[1].q, 325, "commodity quantity"); eq(r[1].n, 1, "a full list is a scan")
eq(r[1].v, 14, "commodity market")
AH.full[3829] = false
AH.commodities[3829] = { { 500, 2 } }
FireEvent("COMMODITY_SEARCH_RESULTS_UPDATED", 3829)
eq(AHF:Records("3829")[1].v, 0, "part of a list: lowest price only")
AH.items["15210:1018"] = { { 8000, 1 }, { false, 1 }, { 18000, 2 } }
FireEvent("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 15210, itemSuffix = 1018 })
r = AHF:Records("15210:1018")
eq(r[#r].m, 8000, "item search lowest"); eq(r[#r].q, 3, "bid-only skipped")
AH.browse = { { itemKey = { itemID = 4306, itemSuffix = 0 }, minPrice = 900, totalQuantity = 60 },
    { itemKey = { itemID = 4338, itemSuffix = 0 }, minPrice = 0, totalQuantity = 1 } }
FireEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
eq(AHF:Records("4306")[1].m, 900, "browse lowest"); eq(AHF:Records("4306")[1].v, 0, "no market from browse")
eq(AHF:Records("4338"), nil, "no price, nothing saved")
FireEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", { { itemKey = { itemID = 4339 }, minPrice = 5, totalQuantity = 1 } })
eq(AHF:Records("4339")[1].m, 5, "more browse results")

---------------------------------------------------------------------------
step("resale tab: listings below the usual price")
do
    local realm = AHF:Realm()
    local today = math.floor(SERVER_TIME / DAY)
    local hist = {}
    for d = today - 13, today - 1 do hist[#hist + 1] = { d = d, s = 1, m = 900, v = 1000, q = 9, n = 1, t = d * DAY } end
    realm.items["6000"] = P.Encode(hist)
    SERVER_TIME = SERVER_TIME + 120
    AH.replicate = {
        -- usual price 971: 13 days at 1000 and today's 600 (this scan's market value)
        { 6000, 1, 500 },        -- 971 x 0.95 - 500 = 422 profit, 84%
        { 6000, 5, 3000 },       -- 5 x 971 x 0.95 - 3000 = 1612, 53%
        { 6000, 1, 900 },        -- 22 profit: too small
        { 6000, 1, 2000 },       -- dearer than usual
        { 6001, 1, 100 },        -- no history, but 10 others at 1000 this scan
    }
    for _ = 1, 10 do table.insert(AH.replicate, { 6001, 1, 1000 }) end
    FireEvent("REPLICATE_ITEM_LIST_UPDATE")
    RunJobs()
    eq(AHF:UsualPrice("6001"), 1000, "usual price from this scan, the cheap one ignored")
    local list = AHF:ResaleRows()
    eq(#list, 3, "three worth reselling")
    eq(AHF:UsualPrice("6000"), 971, "14 day average with today")
    eq(list[1].key, "6000"); eq(list[1].profit, 1612); eq(math.floor(list[1].pct), 53); eq(list[1].qty, 5)
    eq(list[2].key, "6001"); eq(list[2].profit, 850)
    eq(list[3].profit, 422); eq(math.floor(list[3].pct), 84); eq(list[3].seller, "Seller")

    -- the tab
    local tab = AHF.resaleTab
    assert(tab, "Resale tab made")
    eq(tab:GetText(), "Resale")
    Click(tab)
    local panel = AHF.resalePanel
    eq(panel:IsShown(), true, "page shown")
    has(panel.info:GetText(), "3 listings below the usual price")
    has(panel.total:GetText(), AHF.Money(1612 + 850 + 422))
    local row1 = AHF.resaleRows[1]
    eq(row1:IsShown(), true); eq(row1.cells.pct:GetText(), "53%"); eq(row1.cells.profit:GetText(), AHF.Money(1612))
    eq(row1.cells.qty:GetText(), "5"); eq(row1.cells.usual:GetText(), AHF.Money(971)); eq(row1.cells.seller:GetText(), "Seller")
    eq(AHF.resaleRows[4]:IsShown(), false, "empty rows hidden")
    -- sort by percent
    Click(panel.headers.pct)
    eq(AHF.resaleRows[1].cells.pct:GetText(), "850%", "highest percent first")
    Click(panel.headers.pct)
    eq(AHF.resaleRows[1].cells.pct:GetText(), "53%", "and the other way")
    -- clicking a row finds it on the Buy tab (the page closes, as for any other tab)
    Click(AHF.resaleRows[1])
    eq(SEARCHES[#SEARCHES], "Item 6000", "searched for it")
    eq(AuctionHouseFrame.displayMode, AuctionHouseFrameDisplayMode.Buy, "on the Buy tab")
    eq(panel:IsShown(), false, "Resale page closed")
    -- before any full scan
    local keep = AHF.lastScan
    AHF.lastScan = nil
    Click(tab)
    has(panel.info:GetText(), "Do a full scan")
    eq(AHF.resaleRows[1]:IsShown(), false)
    AHF.lastScan = keep
    AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
end
eq(AHF.ResaleProfit(1000, 2, 1000), 900, "2 x 1000 less 5% less 1000")

---------------------------------------------------------------------------
step("tooltips: AHF Vendor and AHF Market")
local lines = HoverItem(ItemLink(3824))
eq(#lines, 6, "vendor, market, history header and three averages")
eq(lines[1][1], "AHF Vendor"); has(lines[1][2], "2|T", "vendor 2s 50c"); has(lines[1][2], "50|T")
eq(lines[2][1], "AHF Market (seen 1)", "how many were listed last"); has(lines[2][2], "2|T", "market about 2s 40-60c")
has(lines[3][1], "AHF seen in "); eq(lines[4][1], "  14 day average"); eq(lines[5][1], "  7 day average"); eq(lines[6][1], "  3 day average")
lines = HoverItem(ItemLink(4306))
eq(lines[1][1], "AHF Market (seen 60)"); has(lines[1][2], "9|T", "lowest price when there's no market value")
lines = HoverItem(ItemLink(15210, 1019))
eq(lines[1][1], "AHF Market (seen 1)"); has(lines[1][2], "50|T", "random suffix item")
eq(#HoverItem(ItemLink(77777)), 0, "nothing known, no lines")
AHF:Slash("tooltip")
eq(#HoverItem(ItemLink(3824)), 0, "turned off")
AHF:Slash("tooltip")
eq(#HoverItem(ItemLink(3824)), 6, "back on")

---------------------------------------------------------------------------
step("tooltips: history and averages")
do
    local realm = AHF:Realm()
    local today = math.floor(SERVER_TIME / DAY)
    -- 30 days ago 1g (2 scans a day), then 5g for the last 7 days
    local recs = {}
    for d = today - 29, today do
        recs[#recs + 1] = { d = d, s = 1, m = 1, v = d > today - 7 and 50000 or 10000, q = 5, n = 2, t = d * DAY }
    end
    realm.items["5000"] = recs
    lines = HoverItem(ItemLink(5000))
    eq(lines[2][1], "AHF seen in 60 scans over 30 days:", "header")
    eq(lines[3][1], "  14 day average"); eq(lines[3][2], AHF.Money((7 * 50000 + 7 * 10000) / 14), "14 days")
    eq(lines[4][1], "  7 day average"); eq(lines[4][2], AHF.Money(50000), "7 days")
    eq(lines[5][1], "  3 day average"); eq(lines[5][2], AHF.Money(50000), "3 days")
    -- only old data: no averages, no header
    realm.items["5001"] = { { d = today - 40, s = 7, m = 1, v = 9, q = 1, n = 1, t = 0 } }
    lines = HoverItem(ItemLink(5001))
    eq(#lines, 1, "just the market line")
end

---------------------------------------------------------------------------
step("disenchant value")
local M = AHF.DE_MATERIALS
-- the table: green armor at item level 58 (skill 200, as in AucAdvanced's tooltip)
local res = AHF.DisenchantResults(2, 58, 4)
eq(res[1][1], M.illusion); eq(res[1][2], 0.75); eq(res[1][3], 1.5)
eq(res[2][1], M.greaterEternal); eq(res[2][2], 0.20)
eq(res[3][1], M.largeBrilliant); eq(res[3][2], 0.05); eq(res[3][3], 1)
-- weapons: mostly essence
res = AHF.DisenchantResults(2, 58, 2)
eq(res[1][2], 0.20, "weapon dust"); eq(res[2][2], 0.75, "weapon essence")
eq(#AHF.DisenchantResults(2, 10, 4), 2, "low greens: no shard")
eq(AHF.DisenchantResults(3, 30, 4)[1][1], M.largeGlimmering, "blue: one shard")
eq(AHF.DisenchantResults(4, 60, 4)[1][1], M.nexus, "purple 60: nexus")
eq(AHF.DisenchantResults(1, 58, 4), nil, "white: no")
eq(AHF.DisenchantResults(2, 58, 7), nil, "trade goods: no")
-- every quality and level gives chances adding up to 1
for _, q in ipairs({ 2, 3, 4 }) do
    for lvl = 5, 70 do
        for _, class in ipairs({ 2, 4 }) do
            local r = AHF.DisenchantResults(q, lvl, class)
            if r then
                local sum = 0
                for _, m in ipairs(r) do sum = sum + m[2]; assert(m[1] and m[3] > 0, "material") end
                assert(math.abs(sum - 1) < 1e-9, "chances add up for " .. q .. "/" .. lvl)
            end
        end
    end
end
-- prices from AHF Market: 75% x 1.5 x 1g + 20% x 1.5 x 5g + 5% x 1 x 20g = 1.125 + 1.5 + 1 = 3.625g
ITEMS[19999] = { 2, 58, 4 }
SERVER_TIME = SERVER_TIME + 60
for id, price in pairs({ [M.illusion] = 10000, [M.greaterEternal] = 50000, [M.largeBrilliant] = 200000 }) do
    AH.commodities[id] = { { price, 10 } }
    FireEvent("COMMODITY_SEARCH_RESULTS_UPDATED", id)
end
local value, guessed = AHF:DisenchantValue(ItemLink(19999))
eq(value, 36250, "3g 62s 50c"); eq(guessed, false, "all priced")
lines = HoverItem(ItemLink(19999))
eq(lines[#lines][1], "AHF Disenchant"); eq(lines[#lines][2], AHF.Money(36250), "one line")
-- a material with no price: counted at its vendor price, marked with ~
ITEMS[19998] = { 2, 45, 4 }
SELL_PRICES[M.vision] = 100
value, guessed = AHF:DisenchantValue(ItemLink(19998))
eq(guessed, true, "guessed"); eq(value, math.floor(0.75 * 3.5 * 100 + 0.5), "vision dust at vendor price")
lines = HoverItem(ItemLink(19998))
eq(lines[#lines][2]:sub(1, 1), "~", "marked as a guess")
eq(lines[#lines][1], "AHF Disenchant")
lines = HoverItem(ItemLink(3824))
for _, l in ipairs(lines) do assert(l[1] ~= "AHF Disenchant", "not on materials") end

---------------------------------------------------------------------------
step("realms and factions keep their own prices")
FACTION = "Alliance"
eq(AHF:Records("3824"), nil, "Alliance has none")
eq(#HoverItem(ItemLink(3824)), 1, "only the vendor line")
FACTION = "Horde"
assert(AHF:Records("3824"), "Horde still has them")

---------------------------------------------------------------------------
step("the window")
AHF:Slash("")
local w = AHF.window
assert(w and w:IsShown(), "window open")
has(AHF.ui.where:GetText(), "Mega Server-Horde")
has(AHF.ui.stored:GetText(), "items")
has(AHF.ui.scanCounts:GetText(), "15 listings of 2 different items")
w:ShowTab("settings")
eq(AHF.ui.tooltip:IsOn(), true, "tooltip switch on")
Click(AHF.ui.tooltip)
eq(AHF.db.tooltip, false, "switch turns it off")
Click(AHF.ui.tooltip)
eq(AHF.db.tooltip, true)
has(AHF.ui.news:GetText(), "v" .. AHF.NEWS[1].version)
AHF:Slash("")
eq(w:IsShown(), false, "toggles closed")

---------------------------------------------------------------------------
step("saving and loading")
local itemsBefore = AHF:Stats()
FireEvent("PLAYER_LOGOUT")
for key, v in pairs(AuctionHouseForeverData.realms["Mega Server-Horde"].items) do
    eq(type(v), "string", "saved as text: " .. key)
end
local saved, settings = AuctionHouseForeverData, AuctionHouseForeverSettings
settings.cooldown = 10
-- a fresh start with the saved data
ALL_FRAMES = {}
AuctionHouseFrame = nil
TOOLTIP_CALLS = {}
AuctionHouseForeverData, AuctionHouseForeverSettings = saved, settings
ns = LoadAddon(".")
AHF = ns.AHF
eq(AHF.db.cooldown, 10, "settings kept")
eq(AHF:Stats(), itemsBefore, "items kept")
eq(AHF:Records("3824")[1].m, 240, "prices kept")
eq(#HoverItem(ItemLink(3824)), 6, "tooltips after loading")

step("broken saved data doesn't stop it")
ALL_FRAMES = {}
TOOLTIP_CALLS = {}
AuctionHouseForeverData = { v = 1, realms = { ["Mega Server-Horde"] = { items = { ["1"] = "x;;,", ["2"] = 5 }, scans = "no" } } }
AuctionHouseForeverSettings = { tooltip = "yes", cooldown = 9999 }
ns = LoadAddon(".")
AHF = ns.AHF
eq(AHF.db.tooltip, true, "bad setting back to default"); eq(AHF.db.cooldown, 60, "clamped")
eq(#HoverItem(ItemLink(1)), 0, "broken item ignored")
AHF:Slash("")
assert(AHF.window:IsShown(), "window still opens")

step("old days are tidied at login, in the background")
ALL_FRAMES = {}
TOOLTIP_CALLS = {}
local today = math.floor(SERVER_TIME / DAY)
local old = {}
for d = today - 30, today do old[#old + 1] = { d = d, s = 1, m = 100, v = 100, q = 1, n = 1, t = d * DAY } end
local items = {}
for i = 1, 300 do items[tostring(i)] = P.Encode(old) end
AuctionHouseForeverData = { v = 1, realms = { ["Mega Server-Horde"] = { items = items, scans = {} } } }
ns = LoadAddon(".")
AHF = ns.AHF
assert(AHF:JobRunning("condense"), "running")
frames = RunJobs()
assert(frames > 1, "spread over frames")
eq(AuctionHouseForeverData.condensed, today, "done for today")
local fewer = P.Decode(AuctionHouseForeverData.realms["Mega Server-Horde"].items["1"])
assert(#fewer < #old, "condensed: " .. #fewer)
eq(type(AuctionHouseForeverData.realms["Mega Server-Horde"].items["1"]), "string", "stays text")

---------------------------------------------------------------------------
step("What's new matches the changelog")
local f = assert(io.open("CHANGELOG.md"))
local log = f:read("*a")
f:close()
local top = log:match("\n## (%d+%.%d+%.%d+)") or log:match("^## (%d+%.%d+%.%d+)")
eq(AHF.NEWS[1].version, top, "News.lua's newest version")

print("ALL TESTS PASSED")
