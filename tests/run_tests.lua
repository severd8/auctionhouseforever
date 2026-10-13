-- Test scenarios for AuctionHouse Forever. Run via tests/run.lua (see DEVNOTES.md).
-- Drives the addon through its features against a fake Auction House. Any Lua
-- error aborts with a traceback.
local ADDON = "AuctionHouseForever"
local ns = {}
local SOURCES = {}
local function load_file(path)
    local f = assert(io.open(path)) local src = f:read("*a") f:close()
    SOURCES[path] = src
    local chunk = assert(loadstring(src, "@" .. path))
    chunk(ADDON, ns)
end
-- Load files in the same order as the .toc
local tocFile = assert(io.open(ADDON_DIR .. "/" .. ADDON .. ".toc"))
local toc = tocFile:read("*a")
tocFile:close()
for line in toc:gmatch("[^\n]+") do
    local file = line:match("^([%w_/]+%.lua)%s*$")
    if file then load_file(ADDON_DIR .. "/" .. file) end
end
local AHF = ns.AHF
-- AuctionHouse Forever's own columns are tested in their own step; the steps
-- before it work with Blizzard's columns only
local OUR_COLUMNS = AHF.EXTRA_COLUMNS
AHF.EXTRA_COLUMNS = {}

local function fire(event, ...)
    for _, f in ipairs(ALL_FRAMES) do
        if f.__events and f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end
local function step(name) print("STEP " .. name) end
local function assertEq(a, b, msg) if a ~= b then error(("ASSERT %s: got %s expected %s"):format(msg, tostring(a), tostring(b)), 2) end end
local function near(a, b, msg) if type(a) ~= "number" or math.abs(a - b) > 0.01 then error(("ASSERT %s: got %s expected %s"):format(msg, tostring(a), tostring(b)), 2) end end

step("toc")
assert(toc:find("## Interface: 16001", 1, true), "interface version")
assert(toc:find("## Author: severd8", 1, true), "author")
assert(toc:find("## SavedVariables: AuctionHouseForeverDB", 1, true), "saved variables")
assert(toc:find("## SavedVariablesPerCharacter: AuctionHouseForeverCharDB", 1, true), "per character saved variables")
assertEq(ns.Theme.NAME, "AuctionHouse Forever", "brand name")
assertEq(ns.Theme.LOGO, "Interface\\AddOns\\AuctionHouseForever\\Media\\logo", "logo path")

step("load + login without the Auction House")
fire("ADDON_LOADED", ADDON)
assert(AHF.db and AHF.charDB, "settings ready")
assertEq(AHF.db.width, 1000, "default width")
assertEq(AHF.db.height, 620, "default height")
assertEq(AHF.db.scale, 1, "default scale")
assertEq(AHF.db.locked, false, "unlocked by default")
assertEq(AHF.db.sidebarWidth, 168, "Blizzard's sidebar width")
assertEq(AHF.db.point, nil, "Blizzard's position")
fire("PLAYER_LOGIN")
assertEq(AHF.frame, nil, "nothing to set up yet")
assertEq(#SETTINGS_CATEGORIES, 1, "Interface Options entry")
assertEq(SETTINGS_CATEGORIES[1].name, "AuctionHouse Forever", "entry name")
RunTimers()
assert(AuctionHouseForeverSplash and AuctionHouseForeverSplash:IsShown(), "welcome screen on first install")
assertEq(AHF.db.lastSeenVersion, AHF.NEWS[1].version, "welcome screen seen")
AuctionHouseForeverSplash:Hide()

step("Auction House loads")
local f = FakeAuctionHouse()
AH_LOADED = true
fire("ADDON_LOADED", "Blizzard_AuctionHouseUI")
assertEq(AHF.frame, f, "set up")
assert(AHF.grip and AHF.mover, "grip and title bar handle")
assertEq(f:GetWidth(), 1000, "saved width")
assertEq(f:GetHeight(), 620, "saved height")
assertEq(f.__bounds[1], 800, "min width")
assertEq(f.__bounds[2], 538, "min height")
assertEq(f.__bounds[3], 1600, "max width")
assertEq(f.__bounds[4], 1080, "max height: the screen")
AHF:OnAuctionHouseLoaded()   -- a second call (login) changes nothing
assertEq(#AHF.columnEntries, 2, "both fake lists found, once")

step("open: columns spread over the width")
f:Open()
local list = f.BrowseResultsFrame.ItemList
local tb = list.tableBuilder
assertEq(list.ScrollBox:GetWidth(), 1000 - 168 - 40, "list stretched")
assertEq(tb:Width("Price"), 146, "Blizzard's Price width")
assertEq(tb:Width("Available"), 83, "Blizzard's Available width")
near(tb:Width("Name"), 792 - 146 - 83 - 29, "Name takes the rest")
assertEq(f:GetPoint(1), "TOPLEFT", "Blizzard's position kept")
assertEq(select(4, f:GetPoint(1)), 20, "Blizzard's x")

step("Blizzard puts its own size back")
f:SetDisplayMode("Sell")
assertEq(f:GetWidth(), 1000, "width back after a tab switch")
assertEq(f:GetHeight(), 620, "height back after a tab switch")
f:SetWidth(700)
assertEq(f:GetWidth(), 1000, "SetWidth undone")
f:SetScale(0.8)
assertEq(f:GetScale(), 1, "SetScale undone")

step("move by the title bar")
assertEq(AHF.mover.__mouse, true, "title bar takes the mouse while unlocked")
f.__left, f.__top = 300, 800
AHF.mover.__scripts.OnDragStart(AHF.mover)
assert(f.__moving, "moving")
AHF.mover.__scripts.OnDragStop(AHF.mover)
assertEq(f.__moving, nil, "stopped")
assertEq(AHF.db.point[1], "TOPLEFT", "saved point")
assertEq(AHF.db.point[3], 300, "saved x")
assertEq(AHF.db.point[4], 800, "saved y")
UpdateUIPanelPositions()
local p, rel, rp, x, y = f:GetPoint(1)
assertEq(f:GetNumPoints(), 1, "one anchor")
assertEq(p .. rp .. x .. y, "TOPLEFTBOTTOMLEFT300800", "saved position wins over the panel manager")
assertEq(rel, UIParent, "anchored to the screen")
f:Hide(); f:Open()
assertEq(select(4, f:GetPoint(1)), 300, "saved position after reopening")

step("lock")
SlashCmdList.AUCTIONHOUSEFOREVER("lock")
assertEq(AHF.db.locked, true, "locked")
assertEq(AHF.mover.__mouse, false, "title bar lets clicks through when locked")
SlashCmdList.AUCTIONHOUSEFOREVER("unlock")
assertEq(AHF.mover.__mouse, true, "unlocked")

step("resize with the corner grip")
AHF.grip.__scripts.OnMouseDown(AHF.grip, "LeftButton")
assertEq(f.__sizing, "BOTTOMRIGHT", "sizing from the corner")
-- What the game does while dragging: resizes without calling SetSize
local ow, oh = f.__w, f.__h
f.__w, f.__h = 1200, 700
f.__scripts.OnSizeChanged(f, 1200, 700)
AHF.grip.__scripts.OnMouseUp(AHF.grip, "LeftButton")
assertEq(AHF.db.width, 1200, "saved width")
assertEq(AHF.db.height, 700, "saved height")
near(tb:Width("Name"), (1200 - 208) - 146 - 83 - 29, "Name grows with the window")
assertEq(tb:Width("Price"), 146, "fixed columns keep their width")
AHF:SetSize(5000, 100)
assertEq(AHF.db.width, 1600, "width limit")
assertEq(AHF.db.height, 538, "height limit")
AHF:SetSize(1200, 700)

step("scale")
AHF:SetScale(1.25)
assertEq(f:GetScale(), 1.25, "scaled")
near(AHF.db.point[3], 240, "top left stays put on screen (x)")
near(AHF.db.point[4], 640, "top left stays put on screen (y)")
AHF:SetSize(1600, 1100)
assertEq(f:GetWidth(), 1536, "never wider than the screen")
assertEq(f:GetHeight(), 864, "never taller than the screen")
AHF:SetScale(1)
AHF:SetSize(1200, 700)
AHF:SetScale(9)
assertEq(AHF.db.scale, 1.5, "scale limit")
AHF:SetScale(1)

step("drag a column divider")
local entry = AHF.columnEntries[1]
assertEq(entry.key, "browse", "browse list first")
local grips = {}
for _, g in ipairs(entry.grips) do if g.__shown then grips[#grips + 1] = g end end
assertEq(#grips, 2, "a divider after Price and after Name")
assertEq(grips[1].colName, "Price", "first divider resizes Price")
assertEq(grips[1].sign, 1, "Price grows to the right")
assertEq(grips[2].colName, "Available", "second divider resizes Available")
assertEq(grips[2].sign, -1, "Available grows to the left")
local function drag(g, dx)
    CURSOR_X = 500
    g.__scripts.OnMouseDown(g, "LeftButton")
    CURSOR_X = 500 + dx
    g.__scripts.OnUpdate(g, 0.01)
    g.__scripts.OnMouseUp(g, "LeftButton")
    assertEq(g.__scripts.OnUpdate, nil, "drag ends on mouse up")
end
drag(grips[1], 60)
assertEq(tb:Width("Price"), 206, "Price wider")
assertEq(AHF.charDB.columns.browse.widths.Price, 206, "saved per character")
drag(grips[2], -40)
assertEq(tb:Width("Available"), 123, "Available wider")
near(tb:Width("Name"), 992 - 206 - 123 - 29, "Name gives the room")
drag(grips[1], 2000)
assertEq(tb:Width("Price"), AHF.LIMITS.column[2], "column maximum")
drag(grips[1], -(400 - 206))
AHF:SetSize(800, 700)
drag(grips[1], 2000)
near(tb:Width("Name"), AHF.NAME_MIN, "Name never narrower than the minimum")
AHF:SetSize(1200, 700)
drag(grips[1], -2000)
assertEq(tb:Width("Price"), AHF.LIMITS.column[1], "column minimum")
drag(grips[1], 60 + 146 - 30)
assertEq(tb:Width("Price"), 206, "back to 206")

step("widths survive a new layout")
list:SetTableBuilderLayout(BrowseLayout)   -- what choosing a category does
tb = list.tableBuilder
assertEq(tb:Width("Price"), 206, "saved Price width put back")
assertEq(tb:Width("Available"), 123, "saved Available width put back")
assertEq(AHF:DefaultColumnWidth("browse", "Price"), 146, "Blizzard's width remembered")

step("a column from another addon (Median)")
local function WithMedian(t)
    BrowseLayout(t)
    table.insert(t.columns, 3, (function()
        local c = t:AddTestColumn("Median", 120, nil, 0)
        table.remove(t.columns)   -- AddColumn appended it; it goes after Name
        return c
    end)())
end
list:SetTableBuilderLayout(WithMedian)
tb = list.tableBuilder
assertEq(#tb.columns, 5, "Median kept")
assertEq(tb:Width("Median"), 120, "its own width")
grips = {}
for _, g in ipairs(entry.grips) do if g.__shown then grips[#grips + 1] = g end end
assertEq(#grips, 3, "three dividers")
assertEq(grips[2].colName, "Median", "Name | Median resizes Median")
assertEq(grips[3].colName, "Available", "Median | Available resizes Available")
drag(grips[2], -30)
assertEq(AHF.charDB.columns.browse.widths.Median, 150, "Median width saved")
list:SetTableBuilderLayout(WithMedian)
assertEq(list.tableBuilder:Width("Median"), 150, "Median width put back")
-- An addon adding its column right after Blizzard's layout, outside the layout
hooksecurefunc(list, "UpdateTableBuilderLayout", function(self)
    local t = self.tableBuilder
    if LATE_ON and not t:Column("Late") then t:AddTestColumn("Late", 50, nil, 0); t:Arrange() end
end)
LATE_ON = true
AHF.charDB.columns.browse.widths.Late = 70
list:SetTableBuilderLayout(BrowseLayout)
assertEq(list.tableBuilder:Width("Late"), 50, "late column has the addon's width at first")
RunTimers()
assertEq(list.tableBuilder:Width("Late"), 70, "and its saved width a frame later")
assertEq(AHF:DefaultColumnWidth("browse", "Late"), 50, "its own default remembered")
AHF.charDB.columns.browse.widths.Late = nil
LATE_ON = false
list:SetTableBuilderLayout(BrowseLayout)
RunTimers()
tb = list.tableBuilder

step("narrow window: Name keeps its minimum, saved widths stay")
AHF.charDB.columns.browse.widths.Price = 400
AHF:SetSize(800, 600)
near(tb:Width("Name"), AHF.NAME_MIN, "Name keeps its minimum")
assertEq(AHF.charDB.columns.browse.widths.Price, 400, "saved width unchanged")
AHF:SetSize(1200, 700)
assertEq(tb:Width("Price"), 400, "saved width back with room")
AHF.charDB.columns.browse.widths.Price = 206

step("double-click a divider")
grips = {}
for _, g in ipairs(entry.grips) do if g.__shown then grips[#grips + 1] = g end end
grips[1].__scripts.OnDoubleClick(grips[1])
assertEq(tb:Width("Price"), 146, "Price back to its default")
assertEq(AHF.charDB.columns.browse.widths.Price, nil, "no longer saved")

step("other lists keep their own widths")
local buy = f.ItemBuyFrame.ItemList
buy:UpdateTableBuilderLayout()
assertEq(buy.tableBuilder:Width("Bid"), 140, "Bid default")
local buyEntry = AHF.columnEntries[2]
assertEq(buyEntry.key, "itemBuy", "item buy list")
for _, g in ipairs(buyEntry.grips) do
    if g.__shown and g.colName == "Bid" then drag(g, 20) end
end
assertEq(buy.tableBuilder:Width("Bid"), 160, "Bid wider")
assertEq(AHF.charDB.columns.itemBuy.widths.Bid, 160, "saved for that list")
assertEq(AHF.charDB.columns.browse.widths.Bid, nil, "not for the browse list")

step("hide and show columns")
tb = list.tableBuilder
assertEq(tb:Names(), "Price,Name,Available,*", "Blizzard's columns")
local avail = tb:Column("Available")
AHF:SetColumnShown("browse", "Available", false)
assertEq(tb:Names(), "Price,Name,*", "Available hidden")
assertEq(avail.header.__shown, false, "its header hidden")
assert((avail.resets or 0) >= 1, "its cells let go")
near(tb:Width("Name"), list.ScrollBox:GetWidth() - 146 - 29, "Name takes the room")
assertEq(AHF.charDB.columns.browse.hidden.Available, true, "saved per character")
list:SetTableBuilderLayout(BrowseLayout)   -- a new layout: still hidden
tb = list.tableBuilder
assertEq(tb:Names(), "Price,Name,*", "still hidden after a new layout")
AHF:SetColumnShown("browse", "Available", true)
assertEq(tb:Names(), "Price,Name,Available,*", "shown again, in its place")
assertEq(tb:Column("Available").header.__shown, true, "header back")
AHF:SetColumnShown("browse", "Name", false)
assertEq(tb:Names(), "Price,Name,Available,*", "Name is never hidden")
AHF:SetColumnShown("browse", "Name", true)

step("reorder columns")
AHF:MoveColumn("browse", "Name", -1)
assertEq(tb:Names(), "Name,Price,Available,*", "Name first; the star keeps its place")
local lc = AHF:ListColumns("browse")
assertEq(lc[1].name .. lc[2].name .. lc[3].name, "NamePriceAvailable", "settings list in the new order")
assertEq(lc[1].fill, true, "Name is the fill column")
local g1
for _, g in ipairs(entry.grips) do if g.__shown then g1 = g break end end
assertEq(g1.colName, "Price", "Name | Price divider resizes Price")
assertEq(g1.sign, -1, "from its left edge")
list:SetTableBuilderLayout(BrowseLayout)
tb = list.tableBuilder
assertEq(tb:Names(), "Name,Price,Available,*", "order kept after a new layout")
AHF:MoveColumn("browse", "Available", -1)
assertEq(tb:Names(), "Name,Available,Price,*", "Available moved left")
AHF:MoveColumn("browse", "Name", -1)
assertEq(tb:Names(), "Name,Available,Price,*", "nothing left of the first")
-- A column another addon adds stays after the column it was built after
list:SetTableBuilderLayout(WithMedian)
tb = list.tableBuilder
assertEq(tb:Names(), "Name,Median,Available,Price,*", "Median follows Name")
AHF:SetColumnShown("browse", "Median", false)
assertEq(tb:Names(), "Name,Available,Price,*", "Median hidden")
AHF:ResetColumnLayout("browse")
assertEq(tb:Names(), "Price,Name,Median,Available,*", "one list back to all shown, Blizzard's order")
assertEq(AHF.charDB.columns.browse.widths.Median, 150, "widths stay")
list:SetTableBuilderLayout(BrowseLayout)
RunTimers()
tb = list.tableBuilder
assertEq(tb:Names(), "Price,Name,Available,*", "plain layout")

step("row text size")
-- A list never shown has no rows yet: changing the size must not touch it
local never = AHF.columnEntries[2].list
local hadView = never.ScrollBox.__view
never.ScrollBox.__view = nil
AHF:SetRowTextScale(125)
AHF:SetRowTextScale(100)
never.ScrollBox.__view = hadView
local row = list.ScrollBox.__rows[1]
local cellText = row.__children[1].Text
local deep = row.__children[1].__children[2].Gold
AHF:SetRowTextScale(150)
assertEq(select(2, cellText:GetFont()), 15, "row text 150%")
assertEq((list.ScrollBox:GetView().elementExtent or 20), 30, "rows taller with bigger text")
assertEq(row:GetHeight(), 30, "row frames taller")
AHF:SetRowTextScale(200)
assertEq((list.ScrollBox:GetView().elementExtent or 20), 40, "200%: 40 tall")
assertEq(select(2, cellText:GetFont()), 20, "200% of the game's size, not of the last size")
AHF:SetRowTextScale(150)
assertEq(select(2, deep:GetFont()), 15, "nested text too (prices)")
list:SetTableBuilderLayout(BrowseLayout)
assertEq(select(2, cellText:GetFont()), 15, "kept after a new layout")
list.ScrollBox.__callbacks.OnLayout()
AHF:SetRowTextScale(100)
assertEq(select(2, cellText:GetFont()), 10, "back to the game's own size")
assertEq((list.ScrollBox:GetView().elementExtent or 20), 20, "Blizzard's row height back")
AHF:SetRowTextScale(120)
assertEq(AHF.db.rowTextScale, 100, "only the listed sizes")

step("our own columns")
AHF.EXTRA_COLUMNS = OUR_COLUMNS
-- Fake item data: a level 20 cloth helm (ilvl 25, sells for 1g) and a herb
ITEMS = {
    [100] = { name = "Cowl", ilvl = 25, req = 20, sell = 10000, type = "Armor", sub = "Cloth", loc = "INVTYPE_HEAD", class = 4, subclass = 1 },
    [200] = { name = "Peacebloom", ilvl = 5, req = 0, sell = 4, type = "Trade Goods", sub = "Herb", loc = "", class = 7, subclass = 9 },
    [300] = { name = "Ring", ilvl = 30, req = 25, sell = 500, type = "Armor", sub = "Miscellaneous", loc = "INVTYPE_FINGER", class = 4, subclass = 0 },
}
INVTYPE_HEAD, INVTYPE_FINGER = "Head", "Finger"
function GetItemInfo(id)
    local i = ITEMS[id]
    if not i or i.uncached then return nil end
    return i.name, nil, 1, i.ilvl, i.req, i.type, i.sub, 20, i.loc, nil, i.sell
end
function GetItemInfoInstant(id)
    local i = ITEMS[id]
    if not i then return nil end
    return id, i.type, i.sub, i.loc, nil, i.class, i.subclass
end
function IsEquippableItem(id) local i = ITEMS[id] return i and i.loc ~= "" end
function GetMoneyString(c) return ("%dg%ds%dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100) end
list:SetTableBuilderLayout(BrowseLayout)
tb = list.tableBuilder
assertEq(tb:Names(), "Price,Name,iLvl,Req Lvl,Vendor,Available,*", "iLvl, Req, Vendor after Name; Type starts hidden")
assertEq(tb:Column("iLvl").cellTemplate, "AuctionHouseForeverCellTemplate", "our cell template")
assertEq(tb:Column("iLvl").cellArgs[1], "ilvl", "cells told their kind")
assertEq(tb:Column("Vendor"):GetFixedWidth(), 100, "Vendor width")
lc = AHF:ListColumns("browse")
local typeRow
for _, c in ipairs(lc) do if c.name == "Type" then typeRow = c end end
assertEq(typeRow.shown, false, "Type listed, hidden")
AHF:SetColumnShown("browse", "Type", true)
assertEq(tb:Names(), "Price,Name,iLvl,Req Lvl,Type,Vendor,Available,*", "Type shown")
AHF:SetColumnShown("browse", "iLvl", false)
assertEq(tb:Names(), "Price,Name,Req Lvl,Type,Vendor,Available,*", "iLvl hidden")
list:SetTableBuilderLayout(BrowseLayout)
tb = list.tableBuilder
assertEq(tb:Names(), "Price,Name,Req Lvl,Type,Vendor,Available,*", "kept after a new layout, added once")
AHF:ResetColumnLayout("browse")
assertEq(tb:Names(), "Price,Name,iLvl,Req Lvl,Vendor,Available,*", "defaults back")
-- What the cells show
local helm = { itemKey = { itemID = 100, itemLevel = 25 }, minPrice = 5000 }
local herb = { itemKey = { itemID = 200, itemLevel = 5 }, minPrice = 20 }
local ring = { itemKey = { itemID = 300, itemLevel = 30 }, minPrice = 9000 }
assertEq(AHF:CellText("ilvl", helm), "25", "helm iLvl")
assertEq(AHF:CellText("ilvl", herb), "", "no iLvl for a herb")
assertEq(AHF:CellText("req", helm), "20", "helm Req")
assertEq(AHF:CellText("req", herb), "", "no Req for a herb")
assertEq(AHF:CellText("type", helm), "Cloth Head", "armour: material and slot")
assertEq(AHF:CellText("type", ring), "Finger", "ring: slot only")
assertEq(AHF:CellText("type", herb), "Herb", "herb: its kind")
local text, color = AHF:CellText("vendor", helm)
assertEq(text, "1g0s0c", "vendor price")
assert(color and color[2] == 1, "under vendor price: green")
text, color = AHF:CellText("vendor", ring)
assertEq(color, nil, "above vendor price: white")
assertEq(AHF:CellText("unit", { buyoutAmount = 1000, quantity = 4 }), "0g2s50c", "per unit")
assertEq(AHF:CellText("unit", { buyoutAmount = 0, quantity = 4 }), "", "no buyout")
assertEq(AHF:CellText("seller", { owners = { "Grom" }, totalNumberOfOwners = 1 }), "Grom", "seller")
assertEq(AHF:CellText("seller", { owners = { "Grom", "Thrall" }, totalNumberOfOwners = 3 }), "Grom +2", "several sellers")
assertEq(AHF:CellText("seller", { owners = {} }), "", "seller hidden by the game")
assertEq(AHF:CellText("ilvl", "junk"), "", "bad row data")
-- Everything Blizzard's rows call on a cell (TableBuilderCellMixin)
for _, m in ipairs({ "Init", "Populate", "OnLineEnter", "OnLineLeave" }) do
    assertEq(type(AuctionHouseForeverCellMixin[m]), "function", "cells have " .. m)
end
-- An item the game hasn't loaded yet fills in when it arrives
ITEMS[100].uncached = true
assertEq(AHF:CellText("req", helm), "", "blank while loading")
local cell = { rowData = helm, Text = CreateFrame("Frame"):CreateFontString() }
for k, v in pairs(AuctionHouseForeverCellMixin) do cell[k] = v end
cell:Init("req")
tb:Column("Req Lvl").cells = { [{}] = cell }
ITEMS[100].uncached = nil
fire("GET_ITEM_INFO_RECEIVED", 100)
RunTimers()
assertEq(cell.Text:GetText(), "20", "filled in when the item arrives")
-- Item auctions: Per unit and Seller after Buyout
buy:SetTableBuilderLayout(buy.tableBuilderLayoutFunction)
assertEq(buy.tableBuilder:Names(), "Bid,Buyout,Per unit,Seller,*", "item auction columns")
-- Sorting the search results by our columns
local brf = f.BrowseResultsFrame
local mace = { itemKey = { itemID = 400, itemLevel = 12 }, minPrice = 300 }
ITEMS[400] = { name = "Mace", ilvl = 12, req = 7, sell = 50, type = "Weapon", sub = "One-Handed Maces", loc = "INVTYPE_WEAPON", class = 2, subclass = 4 }
local function names() local t = {} for _, r in ipairs(brf.browseResults) do t[#t + 1] = ITEMS[r.itemKey.itemID].name end return table.concat(t, ",") end
brf:UpdateBrowseResults({ helm, herb, ring, mace })
assertEq(names(), "Cowl,Peacebloom,Ring,Mace", "the game's order")
local sortButtons = AHF.columnEntries[1].sortButtons
local ilvlButton
for _, b in ipairs(sortButtons) do if b.__shown and b.kind == "ilvl" then ilvlButton = b end end
assert(ilvlButton, "iLvl header clickable")
ilvlButton.__scripts.OnClick(ilvlButton)
assertEq(names(), "Peacebloom,Mace,Cowl,Ring", "by iLvl, lowest first (no iLvl first)")
assertEq(ilvlButton.header.Arrow.__shown, true, "arrow on iLvl")
assertEq(tb:Column("Price").header.Arrow.__shown, false, "no arrow on Price")
ilvlButton.__scripts.OnClick(ilvlButton)
assertEq(names(), "Ring,Cowl,Mace,Peacebloom", "click again: highest first")
brf:UpdateBrowseResults({ { itemKey = { itemID = 300, itemLevel = 40 }, minPrice = 1 } })
assertEq(names(), "Ring,Ring,Cowl,Mace,Peacebloom", "more results sorted in")
local reqButton
for _, b in ipairs(sortButtons) do if b.__shown and b.kind == "req" then reqButton = b end end
reqButton.__scripts.OnClick(reqButton)
assertEq(names(), "Peacebloom,Mace,Cowl,Ring,Ring", "by Req Lvl")
brf:SetSortOrder(1)   -- a Blizzard header
assertEq(AHF.browseSort, nil, "Blizzard's sort takes over")
assertEq(reqButton.header.Arrow.__shown, false, "our arrow off")
-- The Columns button: a menu for the list on screen
local cb = AHF.columnsButton
assert(cb and cb.__template == "WowStyle1FilterDropdownTemplate", "Columns button in the Filter button's style")
assertEq(select(2, cb:GetPoint(1)), f.SearchBar.FavoritesSearchButton, "left of the favourites button")
local function OpenMenu()
    local root = { items = {} }
    local function desc(kind, text, a, b)
        local d = { kind = kind, text = text, a = a, b = b, sub = {} }
        function d:CreateButton(t, fn) table.insert(self.sub, { text = t, fn = fn }) end
        function d:SetEnabled(v) self.enabled = v end
        return d
    end
    function root:CreateTitle(t) table.insert(self.items, desc("title", t)) end
    function root:CreateDivider() table.insert(self.items, desc("divider")) end
    function root:CreateCheckbox(t, get, set) local d = desc("check", t, get, set) table.insert(self.items, d) return d end
    function root:CreateButton(t, fn) local d = desc("button", t, fn) table.insert(self.items, d) return d end
    cb.__menuGen(cb, root)
    return root.items
end
f.ItemBuyFrame.__shown = false
local items = OpenMenu()
assertEq(items[1].text, "Buy: search results", "menu for the search results")
local checks = {}
for _, it in ipairs(items) do if it.kind == "check" then checks[#checks + 1] = it end end
assertEq(#checks, 7, "every column listed, Type included")
assertEq(checks[2].text, "Name", "in the order shown")
assertEq(checks[2].enabled, false, "Name can't be unticked")
local typeCheck
for _, c in ipairs(checks) do if c.text == "Type" then typeCheck = c end end
assertEq(typeCheck.a(), false, "Type unticked")
typeCheck.b()
assertEq(tb:Names(), "Price,Name,iLvl,Req Lvl,Type,Vendor,Available,*", "ticking Type shows it")
assertEq(#checks[1].sub, 1, "first column: Move right only")
checks[1].sub[1].fn()
assertEq(tb:Names(), "Name,Price,iLvl,Req Lvl,Type,Vendor,Available,*", "Move right")
local last = items[#items]
assertEq(last.text, "More settings (/ahf)", "link to the settings")
items[#items - 1].a()
assertEq(tb:Names(), "Price,Name,iLvl,Req Lvl,Vendor,Available,*", "Show all, default order")
f.ItemBuyFrame.__shown = true
f.BrowseResultsFrame.__shown = false
assertEq(OpenMenu()[1].text, "Buy: item auctions", "menu follows the list on screen")
f.BrowseResultsFrame.__shown = true
-- The steps after this one work with Blizzard's columns again
AHF.EXTRA_COLUMNS = {}
list:SetTableBuilderLayout(BrowseLayout)
buy:SetTableBuilderLayout(buy.tableBuilderLayoutFunction)
tb = list.tableBuilder
assertEq(tb:Names(), "Price,Name,Available,*", "Blizzard's columns only")

step("category list width")
AHF:SetSidebarWidth(250)
local cat = f.CategoriesList
assertEq(cat:GetWidth(), 250, "wider category list")
assertEq(cat.Background:GetNumPoints(), 2, "its background fills it")
assertEq(select(3, cat.Background:GetPoint(2)), "BOTTOMRIGHT", "anchored at the bottom right too")
assertEq(list.Background:GetNumPoints(), 2, "results background fills the list")
assertEq(list.ScrollBox:GetWidth(), 1200 - 250 - 40, "results list makes room")
local btn = cat.ScrollBox.__buttons[1]
assertEq(btn.NormalTexture:GetWidth(), 136 + 82, "button art as wide as the list")
assertEq(btn.SelectedTexture:GetWidth(), 134 + 82, "selected art too")
assertEq(btn.HighlightTexture:GetWidth(), 132 + 82, "highlight too")
-- Blizzard sets the button up again (scrolling, a new category): fitted again, not added up
AuctionHouseFilterButton_SetUp(btn, btn.__data)
assertEq(btn.NormalTexture:GetWidth(), 136 + 82, "still as wide after Blizzard's setup")
-- Category text size: a percentage of the game's size; taller buttons
AHF:SetCategoryTextScale(150)
assertEq(select(2, btn.Text:GetFont()), 15, "category text 150%")
assertEq(btn:GetHeight(), 32, "category buttons taller")
assertEq(btn.NormalTexture:GetHeight(), 20 + 11, "button art taller too")
assertEq(cat.ScrollBox:GetView().elementExtent, 32, "category scroll range follows")
AuctionHouseFilterButton_SetUp(btn, btn.__data)
assertEq(select(2, btn.Text:GetFont()), 15, "kept after Blizzard's setup")
AHF:SetCategoryTextScale(100)
assertEq(select(2, btn.Text:GetFont()), 10, "category text back to the game's own")
assertEq(btn:GetHeight(), 21, "category buttons back")
AHF:SetCategoryTextScale(130)
assertEq(AHF.db.categoryTextScale, 100, "only the listed sizes")
AHF:SetSidebarWidth(1000)
assertEq(AHF.db.sidebarWidth, 320, "sidebar limit")
AHF:SetSidebarWidth(168)
AuctionHouseFilterButton_SetUp(btn, btn.__data)
assertEq(btn.NormalTexture:GetWidth(), 136, "Blizzard's width back")
assertEq(cat:GetHeight(), 438 + 700 - 538, "category list as tall as the window allows")
AHF.grip.__scripts.OnMouseDown(AHF.grip, "LeftButton")
f.__h = 800
f.__scripts.OnSizeChanged(f, f.__w, 800)
assertEq(cat:GetHeight(), 438 + 800 - 538, "follows the window while dragging")
AHF.grip.__scripts.OnMouseUp(AHF.grip, "LeftButton")
AHF:SetSize(1200, 700)
assertEq(cat:GetHeight(), 438 + 700 - 538, "and back")

step("settings window")
AHF:ToggleConfig()
local win = AHF.configWindow
assert(win and win:IsShown(), "window open")
assert(#AHF.optionTips >= 9, "controls registered")
for _, t in ipairs(AHF.optionTips) do
    assert(t.title and t.body and #t.body > 10, "every control has hover help: " .. tostring(t.title))
end
-- Every page builds and shows
for _, key in ipairs({ "window", "columns", "general" }) do
    win:ShowTab(key)
    assertEq(win.currentTab, key, "tab " .. key)
end
local function findTip(title)
    for _, t in ipairs(AHF.optionTips) do if t.title == title then return t.widget end end
    error("no control " .. title)
end
local lockSwitch = findTip("Keep window in place")
lockSwitch.__scripts.OnClick(lockSwitch)
assertEq(AHF.db.locked, true, "switch locks")
lockSwitch.__scripts.OnClick(lockSwitch)
assertEq(AHF.db.locked, false, "and unlocks")
findTip("Width"):SetValue(1300)
assertEq(AHF.db.width, 1300, "width slider")
assertEq(f:GetWidth(), 1300, "applied at once")
findTip("Scale"):SetValue(120)
near(AHF.db.scale, 1.2, "scale slider in %")
findTip("Scale"):SetValue(100)
findTip("Category list width"):SetValue(200)
assertEq(cat:GetWidth(), 200, "sidebar slider")
local resetCols = findTip("Reset all columns")
resetCols.__scripts.OnClick(resetCols)
assertEq(AHF:SavedColumnCount(), 0, "column widths reset")
assertEq(buy.tableBuilder:Width("Bid"), 140, "Bid back to default")
-- Show & Order tab
win:ShowTab("order")
local function findAll(title)
    local t = {}
    for _, x in ipairs(AHF.optionTips) do if x.title == title then t[#t + 1] = x.widget end end
    return t
end
local switches, ups, downs = findAll("Show this column"), findAll("Move left"), findAll("Move right")
local function rowName(i) return switches[i]:GetParent().label:GetText() end
assertEq(rowName(1), "Price", "first row is Price")
assertEq(switches[2].disabled, true, "Name can't be hidden")
assertEq(ups[1].disabled, true, "first can't move left")
assertEq(switches[4]:GetParent().__shown, false, "only as many rows as columns")
switches[3].__scripts.OnClick(switches[3])
assertEq(AHF.charDB.columns.browse.hidden.Available, true, "switch hides Available")
assertEq(switches[3].on, false, "switch repainted")
assertEq(list.tableBuilder:Names(), "Price,Name,*", "hidden in the list")
downs[1].__scripts.OnClick(downs[1])
assertEq(list.tableBuilder:Names(), "Name,Price,*", "Price moved right")
assertEq(rowName(1), "Name", "rows repainted in the new order")
local pick = findTip("List")
pick.__scripts.OnClick(pick)
local menu = MENUS[#MENUS]
assertEq(#menu.entries, 2, "both seen lists offered")
menu.entries[2].fn()
assertEq(rowName(1), "Bid", "item buy list shown")
menu.entries[1].fn()
local showAll = findTip("Show all, default order")
showAll.__scripts.OnClick(showAll)
assertEq(list.tableBuilder:Names(), "Price,Name,Available,*", "Show all, default order")
local fontPick = findTip("Row text size")
fontPick.__scripts.OnClick(fontPick)
MENUS[#MENUS].entries[3].fn()
assertEq(AHF.db.rowTextScale, 125, "row text size menu")
local splashSwitch = findTip("Show welcome screen after updates")
splashSwitch.__scripts.OnClick(splashSwitch)
assertEq(AHF.db.showSplash, false, "welcome screen off")
splashSwitch.__scripts.OnClick(splashSwitch)

step("reset to default needs two clicks")
AHF.charDB.columns.browse.widths.Price = 300
AHF:SetColumnShown("browse", "Available", false)
AHF:MoveColumn("browse", "Name", -1)
local resetAll = findTip("Reset to default")
resetAll.__scripts.OnClick(resetAll)
assertEq(AHF.db.width, 1300, "first click only asks")
assertEq(resetAll:GetFontString():GetText(), "Click again to reset", "asks to confirm")
resetAll.__scripts.OnClick(resetAll)
assertEq(AHF.db.width, 1000, "width default")
assertEq(AHF.db.height, 620, "height default")
assertEq(AHF.db.sidebarWidth, 168, "sidebar default")
assertEq(AHF.db.point, nil, "position default")
assertEq(AHF.db.showSplash, true, "welcome screen setting kept")
assertEq(AHF:SavedColumnCount(), 0, "columns default")
assertEq(list.tableBuilder:Names(), "Price,Name,Available,*", "all shown, Blizzard's order")
assertEq(AHF.db.rowTextScale, 100, "row text size default")
assertEq(select(2, list.ScrollBox.__rows[1].__children[1].Text:GetFont()), 10, "row text back")
assertEq(f:GetWidth(), 1000, "window resized")
assertEq(select(4, f:GetPoint(1)), 20, "back where Blizzard put it")
-- The confirmation runs out
resetAll.__scripts.OnClick(resetAll)
RunTimers()
assertEq(resetAll:GetFontString():GetText(), "Reset to default", "confirmation expires")
AHF:ToggleConfig()
assertEq(win:IsShown(), false, "toggles closed")

step("settings in the Auction House's own tab")
local tabB = AHF.tab
assert(tabB, "AH Forever tab")
assertEq(tabB:GetText(), "AH Forever", "tab name")
assertEq(select(2, tabB:GetPoint(1)), f.Tabs[4], "after the last tab (Auctionator's)")
tabB.__scripts.OnClick(tabB)
assert(AHF.tabPanel:IsShown(), "tab shows its panel")
assertEq(win:GetParent(), AHF.tabPanel, "settings inside the Auction House")
assertEq(AHF.embedded, true, "embedded")
assertEq(SELECTED_TABS[tabB], true, "our tab selected")
for _, b in ipairs(win.closeButtons) do assertEq(b.__shown, false, "no X / Close inside the Auction House") end
f.Tabs[1].__scripts.OnClick(f.Tabs[1])   -- Buy tab
assertEq(AHF.tabPanel:IsShown(), false, "another tab closes ours")
assertEq(win:GetParent(), UIParent, "window on its own again")
assertEq(win:IsShown(), false, "and hidden")
SlashCmdList.AUCTIONHOUSEFOREVER("")
assertEq(AHF.embedded, true, "/ahf opens the tab while the Auction House is open")
SlashCmdList.AUCTIONHOUSEFOREVER("")
assertEq(AHF.tabPanel:IsShown(), false, "/ahf again closes it")
SlashCmdList.AUCTIONHOUSEFOREVER("")
win:Hide()   -- Escape
assertEq(AHF.tabPanel:IsShown(), false, "Escape closes the tab")
f:SetDisplayMode("Sell")
f:Hide()
SlashCmdList.AUCTIONHOUSEFOREVER("")
assertEq(AHF.embedded, false, "with the Auction House closed: a window of its own")
assert(win:IsShown(), "window shown")
win:Hide()
f:Open()

step("Interface Options button")
local panel = AHF.settingsPanel
local openBtn
for _, c in ipairs(panel.__children) do if c.__fs and c.__fs.__text == "Open settings" then openBtn = c end end
assert(openBtn, "open button")
openBtn.__scripts.OnClick(openBtn)
assert(win:IsShown(), "opens the window")
assertEq(win.currentTab, "window", "on the Window tab")
win:Hide()

step("slash commands")
AHF:SetSize(1400, 900)
AHF.db.point = { "TOPLEFT", "BOTTOMLEFT", 5, 5 }
f:Hide(); f:Open()
assertEq(select(4, f:GetPoint(1)), 5, "dragged position")
SlashCmdList.AUCTIONHOUSEFOREVER("reset")
assertEq(AHF.db.width, 1000, "/ahf reset size")
assertEq(AHF.db.point, nil, "/ahf reset position")
assertEq(select(4, f:GetPoint(1)), 20, "moved back at once")
AHF.charDB.columns.browse.widths.Price = 250
SlashCmdList.AUCTIONHOUSEFOREVER("columns")
assertEq(AHF:SavedColumnCount(), 0, "/ahf columns")
SlashCmdList.AUCTIONHOUSEFOREVER("news")
assert(AuctionHouseForeverSplash:IsShown(), "/ahf news")
SlashCmdList.AUCTIONHOUSEFOREVER("news")
SlashCmdList.AUCTIONHOUSEFOREVER("")
assert(win:IsShown(), "/ahf opens settings")
SlashCmdList.AUCTIONHOUSEFOREVER("")
SlashCmdList.AUCTIONHOUSEFOREVER("help")
local helped = false
for _, l in ipairs(LOG) do if l:find("/ahf columns") then helped = true end end
assert(helped, "help lists the commands")

step("damaged saved settings")
local db = AHF.PrepareSettings({ width = "wide", height = 99999, scale = 0.1, locked = "yes",
    point = { 1, 2 }, sidebarWidth = 10 })
assertEq(db.width, 1000, "wrong type back to default")
assertEq(db.height, 1100, "too tall brought inside the limit")
assertEq(db.scale, 0.6, "scale limit")
assertEq(db.locked, false, "wrong type")
assertEq(db.point, nil, "broken position dropped")
assertEq(db.sidebarWidth, 168, "sidebar limit")
local okPoint = AHF.PrepareSettings({ point = { "TOPLEFT", "BOTTOMLEFT", 10, 20 } })
assertEq(okPoint.point[3], 10, "good position kept")
local char = AHF.PrepareCharSettings({ columns = { browse = { widths = { Price = "x", Name = 9999 } }, bad = 5 } })
assertEq(char.columns.bad, nil, "broken list dropped")
assertEq(char.columns.browse.widths.Price, nil, "broken width dropped")
assertEq(char.columns.browse.widths.Name, 400, "width limit")
assert(type(char.columns.browse.hidden) == "table" and type(char.columns.browse.order) == "table", "hidden and order made")
local char2 = AHF.PrepareCharSettings({ columns = { browse = { hidden = { Price = true, Name = "x" },
    order = { "Name", 5, "Price" } } } })
assertEq(char2.columns.browse.hidden.Price, true, "hidden kept")
assertEq(char2.columns.browse.hidden.Name, nil, "broken hidden dropped")
assertEq(table.concat(char2.columns.browse.order, ","), "Name,Price", "broken order entry dropped")
assertEq(AHF.PrepareSettings({ rowTextScale = 175 }).rowTextScale, 175, "row text size kept")
assertEq(AHF.PrepareSettings({ rowTextScale = 130 }).rowTextScale, 100, "unknown row text size")
assertEq(AHF.PrepareSettings({ categoryTextScale = 125 }).categoryTextScale, 125, "category text size kept")
assertEq(AHF.PrepareSettings({ rowFontSize = 16 }).rowFontSize, nil, "1.2 point sizes dropped")

step("never buys, bids or posts")
assertEq(#PURCHASES, 0, "no auction actions")
for path, src in pairs(SOURCES) do
    assert(not src:find("C_AuctionHouse", 1, true), path .. " must not call C_AuctionHouse")
    for _, fn in ipairs({ "PlaceBid", "Purchase", "PostItem", "PostCommodity", "CancelAuction", "StartItemBuyout",
            "StartItemBid", "BuyDialog" }) do
        assert(not src:find(fn, 1, true), path .. " must not touch " .. fn)
    end
end

step("news matches the changelog")
local cl = assert(io.open(ADDON_DIR .. "/CHANGELOG.md")):read("*a")
local top = cl:match("^## ([%d%.]+)") or cl:match("\n## ([%d%.]+)")
assertEq(AHF.NEWS[1].version, top, "News.lua top version = CHANGELOG.md top version")

print("ALL TESTS PASSED")
