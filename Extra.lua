-- AuctionHouse Forever: its own columns. Search results get iLvl, Req, Type and
-- Vendor; an item's auctions get Per unit and Seller. They're added to the
-- table builder after Blizzard's layout (and after other addons' columns), so
-- they can be hidden, moved and resized like any other column. The cells use
-- AuctionHouseForeverCellTemplate (Cells.xml); what they show comes from each
-- row's data and the item's info.

local _, ns = ...
local AHF = ns.AHF

-- after = "fill": right after the Name column; otherwise after the last column
-- with a header. hidden = starts hidden (shown from the Columns button or the
-- Show & Order tab).
AHF.EXTRA_COLUMNS = {
    browse = {
        { name = "iLvl",   kind = "ilvl",   width = 40, after = "fill" },
        { name = "Req Lvl", kind = "req",   width = 52 },
        { name = "Type",   kind = "type",   width = 120, hidden = true },
        { name = "Vendor", kind = "vendor", width = 100 },
    },
    itemBuy = {
        { name = "Per unit", kind = "unit",   width = 110 },
        { name = "Seller",   kind = "seller", width = 100 },
    },
}

local ours = setmetatable({}, { __mode = "k" })   -- our column objects
local CELL_PADDING = 10                            -- Blizzard's STANDARD_PADDING
local DEAL = { 0.25, 1, 0.25 }                     -- vendor pays more than the lowest buyout

function AHF:DefaultHidden(key, name)
    for _, def in ipairs(self.EXTRA_COLUMNS[key] or {}) do
        if def.name == name then return def.hidden or false end
    end
    return false
end

---------------------------------------------------------------------------
-- Item info
---------------------------------------------------------------------------
local waiting = {}   -- items asked for; their cells fill in when the game has them

local function ItemInfo(id)
    if type(id) ~= "number" then return nil end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, _, _, ilvl, req, _, _, _, _, _, sell = get(id)
    if not name then
        waiting[id] = true
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        return nil
    end
    return { ilvl = ilvl, req = req, sell = sell }
end

local function ItemInstant(id)
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(id) ~= "number" or not get then return nil end
    local _, itemType, subType, equipLoc, _, classID, subClassID = get(id)
    return { itemType = itemType, subType = subType, equipLoc = equipLoc, classID = classID, subClassID = subClassID }
end

local function Equippable(id, inst)
    local fn = (C_Item and C_Item.IsEquippableItem) or IsEquippableItem
    if fn then return fn(id) and true or false end
    return inst and inst.equipLoc ~= nil and inst.equipLoc ~= ""
end

local function Money(copper)
    if type(copper) ~= "number" or copper <= 0 then return "" end
    copper = math.floor(copper)
    if GetMoneyString then return GetMoneyString(copper, true) end
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(copper) end
    return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function KeyID(row)
    local key = type(row) == "table" and row.itemKey
    return type(key) == "table" and key.itemID or nil, key
end

---------------------------------------------------------------------------
-- What each kind of cell shows: text, and a colour (or nil for white)
---------------------------------------------------------------------------
local TEXT = {}

function TEXT.ilvl(row)
    local id, key = KeyID(row)
    if not id or not Equippable(id, ItemInstant(id)) then return "" end
    local lvl = key.itemLevel
    if type(lvl) ~= "number" or lvl <= 0 then
        local info = ItemInfo(id)
        lvl = info and info.ilvl
    end
    return (type(lvl) == "number" and lvl > 0) and tostring(lvl) or ""
end

function TEXT.req(row)
    local info = ItemInfo((KeyID(row)))
    local req = info and info.req
    return (type(req) == "number" and req > 1) and tostring(req) or ""
end

function TEXT.type(row)
    local inst = ItemInstant((KeyID(row)))
    if not inst then return "" end
    local slot = inst.equipLoc and inst.equipLoc ~= "" and _G[inst.equipLoc]
    if type(slot) ~= "string" then slot = nil end
    local armor = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4
    if slot and inst.classID == armor then
        -- Rings, necks, trinkets and cloaks are "Miscellaneous" armour: the slot says enough
        if inst.subClassID == 0 or not inst.subType or inst.subType == "" then return slot end
        return inst.subType .. " " .. slot
    end
    return inst.subType or inst.itemType or ""
end

function TEXT.vendor(row)
    local info = ItemInfo((KeyID(row)))
    local sell = info and info.sell
    if type(sell) ~= "number" or sell <= 0 then return "" end
    local min = row.minPrice
    return Money(sell), (type(min) == "number" and min > 0 and min < sell) and DEAL or nil
end

function TEXT.unit(row)
    local buyout, qty = row.buyoutAmount, row.quantity
    if type(buyout) ~= "number" or buyout <= 0 then return "" end
    if type(qty) ~= "number" or qty < 1 then qty = 1 end
    return Money(buyout / qty)
end

function TEXT.seller(row)
    local owners = type(row.owners) == "table" and row.owners or {}
    local first = owners[1]
    if type(first) ~= "string" or first == "" then return "" end
    local n = row.totalNumberOfOwners
    if type(n) ~= "number" then n = #owners end
    if n > 1 then return first .. " +" .. (n - 1) end
    return first
end

function AHF:CellText(kind, row)
    local fn = TEXT[kind]
    if not fn or type(row) ~= "table" then return "" end
    local ok, text, color = pcall(fn, row)
    if not ok then return "" end
    return text or "", color
end

---------------------------------------------------------------------------
-- The cell template's code (Cells.xml)
---------------------------------------------------------------------------
-- Blizzard's table rows call Init, Populate, OnLineEnter and OnLineLeave on
-- every cell (TableBuilderCellMixin), so all four must exist
AuctionHouseForeverCellMixin = {}
function AuctionHouseForeverCellMixin:OnLineEnter() end
function AuctionHouseForeverCellMixin:OnLineLeave() end

function AuctionHouseForeverCellMixin:Init(kind)
    self.kind = kind
    if not self.fontSet and _G.Number14FontWhite and self.Text.SetFontObject then
        self.Text:SetFontObject(_G.Number14FontWhite)
        self.fontSet = true
    end
    local right = kind == "vendor" or kind == "unit"
    self.Text:SetJustifyH(right and "RIGHT" or (kind == "ilvl" or kind == "req") and "CENTER" or "LEFT")
end

function AuctionHouseForeverCellMixin:Populate(rowData)
    local text, color = AHF:CellText(self.kind, rowData)
    self.Text:SetText(text)
    if color then self.Text:SetTextColor(color[1], color[2], color[3])
    else self.Text:SetTextColor(1, 1, 1) end
end

---------------------------------------------------------------------------
-- Adding the columns to a list's table, once per new layout
---------------------------------------------------------------------------
function AHF:AddExtraColumns(entry, tb)
    local defs = self.EXTRA_COLUMNS[entry.key]
    local cols = tb:GetColumns()
    if not defs or not cols[1] or entry.known[cols[1]] then return end   -- not a new layout
    for _, col in ipairs(cols) do if ours[col] then return end end
    if not tb.AddColumn then return end
    local owner = entry.list.GetParent and entry.list:GetParent() or entry.list
    -- Where they go: after the Name column, or after the last column with a header
    local at
    for i, col in ipairs(cols) do
        if col.GetHeaderFrame and col:GetHeaderFrame() then at = i end
    end
    at = at or #cols
    for i, def in ipairs(defs) do
        if def.after == "fill" then
            for j, col in ipairs(cols) do if self.IsFillColumn(col) then at = j break end end
        end
        local before = #cols
        local ok, col = pcall(function()
            local c = tb:AddColumn()
            c:ConstructHeader("BUTTON", "AuctionHouseTableHeaderStringTemplate", owner, def.name, nil)
            c:ConstructCells("FRAME", "AuctionHouseForeverCellTemplate", def.kind)
            c:SetFixedConstraints(def.width, 0)
            if c.SetCellPadding then c:SetCellPadding(CELL_PADDING, 0) end
            return c
        end)
        if not ok then
            -- Leave Blizzard's table as it was
            if #cols > before then table.remove(cols) end
            return
        end
        ours[col] = def
        -- AddColumn put it at the end; move it into place
        for j = #cols, 1, -1 do if cols[j] == col then table.remove(cols, j) break end end
        at = at + 1
        table.insert(cols, at, col)
    end
end

---------------------------------------------------------------------------
-- Sorting the search results by our columns. The game sorts only by its own
-- columns (on the server); for ours, the results already loaded are sorted
-- here, again as more arrive. Clicking one of Blizzard's headers goes back to
-- the game's sort.
---------------------------------------------------------------------------
local SORT_VALUE = {}
function SORT_VALUE.ilvl(row)
    local id, key = KeyID(row)
    if not id or not Equippable(id, ItemInstant(id)) then return -1 end
    local lvl = key.itemLevel
    if type(lvl) ~= "number" or lvl <= 0 then
        local info = ItemInfo(id)
        lvl = info and info.ilvl
    end
    return type(lvl) == "number" and lvl or -1
end
function SORT_VALUE.req(row)
    local info = ItemInfo((KeyID(row)))
    return info and type(info.req) == "number" and info.req or -1
end
function SORT_VALUE.vendor(row)
    local info = ItemInfo((KeyID(row)))
    return info and type(info.sell) == "number" and info.sell or -1
end
SORT_VALUE.type = function(row) return (AHF:CellText("type", row)) or "" end

function AHF:SortBrowseResults()
    local brf = self.frame and self.frame.BrowseResultsFrame
    local sort = self.browseSort
    local results = brf and brf.browseResults
    if not sort or type(results) ~= "table" or #results < 2 then return end
    local fn = SORT_VALUE[sort.kind]
    local keyed = {}
    for i, row in ipairs(results) do
        local ok, v = pcall(fn, row)
        keyed[i] = { row = row, v = ok and v or -1, price = type(row) == "table" and row.minPrice or 0, i = i }
    end
    table.sort(keyed, function(a, b)
        if a.v ~= b.v then
            if type(a.v) ~= type(b.v) then return type(a.v) == "number" end
            if sort.reverse then return a.v > b.v end
            return a.v < b.v
        end
        if a.price ~= b.price then return (a.price or 0) < (b.price or 0) end
        return a.i < b.i
    end)
    for i, k in ipairs(keyed) do results[i] = k.row end
    if brf.ItemList and brf.ItemList.DirtyScrollFrame then brf.ItemList:DirtyScrollFrame() end
end

-- The arrow on the sorted header: ours, or none of ours (Blizzard's own then)
function AHF:UpdateSortArrows()
    local entry
    for _, e in ipairs(self.columnEntries or {}) do if e.key == "browse" then entry = e end end
    if not entry then return end
    local sort = self.browseSort
    for _, b in ipairs(entry.sortButtons or {}) do
        local arrow = b:IsShown() and b.header and type(b.header.Arrow) == "table" and b.header.Arrow
        if arrow then
            local on = sort and sort.kind == b.kind
            arrow:SetShown(on and true or false)
            if on then
                if sort.reverse then arrow:SetTexCoord(0, 1, 0, 1) else arrow:SetTexCoord(0, 1, 1, 0) end
            end
        end
    end
    -- While ours sorts, Blizzard's headers don't show an arrow
    local tb = entry.list.tableBuilder
    if sort and tb then
        for _, col in ipairs(tb:GetColumns()) do
            local h = not ours[col] and col.GetHeaderFrame and col:GetHeaderFrame()
            if h and type(h.Arrow) == "table" then h.Arrow:Hide() end
        end
    end
end

local function MakeSortButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    b:SetScript("OnClick", function(self)
        local sort = AHF.browseSort
        if sort and sort.kind == self.kind then
            sort.reverse = not sort.reverse
        else
            AHF.browseSort = { kind = self.kind, reverse = false }
        end
        AHF:SortBrowseResults()
        AHF:UpdateSortArrows()
    end)
    ns.Theme.Tooltip(b, "Sort", "Click to sort the results by this column; click again to reverse. "
        .. "Sorts the results loaded so far (more load as you scroll).")
    return b
end

-- Click areas over our sortable headers (Blizzard's header buttons are shared
-- with its own columns, so they aren't changed)
function AHF:PlaceSortButtons(entry, cols)
    if entry.key ~= "browse" then return end
    entry.sortButtons = entry.sortButtons or {}
    local n = 0
    for _, c in ipairs(cols or {}) do
        local def = ours[c.col]
        local h = def and SORT_VALUE[def.kind] and c.col:GetHeaderFrame()
        if h and h:IsShown() then
            n = n + 1
            local b = entry.sortButtons[n]
            if not b then
                b = MakeSortButton(h:GetParent())
                entry.sortButtons[n] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", h, "TOPLEFT")
            b:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT")
            b.kind, b.header = def.kind, h
            b:Show()
        end
    end
    for i = n + 1, #entry.sortButtons do entry.sortButtons[i]:Hide() end
    self:UpdateSortArrows()
end

function AHF:SetupSorting(f)
    local brf = type(f.BrowseResultsFrame) == "table" and f.BrowseResultsFrame or nil
    if not brf then return end
    if type(brf.UpdateBrowseResults) == "function" then
        hooksecurefunc(brf, "UpdateBrowseResults", function() AHF:SortBrowseResults() end)
    end
    if type(brf.SetSortOrder) == "function" then
        hooksecurefunc(brf, "SetSortOrder", function()
            AHF.browseSort = nil
            AHF:UpdateSortArrows()
        end)
    end
end

-- Fills in cells that were waiting for an item's info
local function RefreshExtraCells()
    if AHF.browseSort then AHF:SortBrowseResults() end
    for _, entry in ipairs(AHF.columnEntries or {}) do
        local tb = entry.list.tableBuilder
        for _, col in ipairs(tb and tb:GetColumns() or {}) do
            if ours[col] and type(col.cells) == "table" then
                for _, cell in pairs(col.cells) do
                    if cell.Populate and cell.rowData then cell:Populate(cell.rowData) end
                end
            end
        end
    end
end
AHF.RefreshExtraCells = RefreshExtraCells

local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
local queued = false
events:SetScript("OnEvent", function(_, _, id)
    if not waiting[id] then return end
    waiting[id] = nil
    if queued then return end
    queued = true
    local function run() queued = false; RefreshExtraCells() end
    if C_Timer and C_Timer.After then C_Timer.After(0.1, run) else run() end
end)

---------------------------------------------------------------------------
-- The Columns button beside the search box, in the style of Blizzard's Filter
-- button: tick columns on or off, and move them, for the list on screen
---------------------------------------------------------------------------
-- The list the player is looking at (search results, or an item's auctions)
function AHF:CurrentListKey()
    for _, e in ipairs(self.columnEntries or {}) do
        if e.list:IsVisible() and #e.natural > 0 then return e.key end
    end
    return "browse"
end

local function Reopen(dropdown)
    -- Rebuild the open menu so it shows the new order
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if dropdown.IsMenuOpen and dropdown:IsMenuOpen() and dropdown.GenerateMenu then dropdown:GenerateMenu() end
        end)
    end
    return MenuResponse and MenuResponse.Refresh
end

function AHF:BuildColumnsMenu(dropdown, root)
    local key = self:CurrentListKey()
    root:CreateTitle(self.LIST_LABELS and self.LIST_LABELS[key] or "Columns")
    local list = self:ListColumns(key)
    if #list == 0 then
        root:CreateTitle("Search first, then pick the columns here.")
        return
    end
    for i, c in ipairs(list) do
        local name, fill = c.name, c.fill
        local box = root:CreateCheckbox(name,
            function() return fill or not self:IsColumnHidden(key, name) end,
            function()
                if not fill then self:SetColumnShown(key, name, self:IsColumnHidden(key, name)) end
            end)
        if fill and box.SetEnabled then box:SetEnabled(false) end
        if i > 1 then
            box:CreateButton("Move left", function() self:MoveColumn(key, name, -1) return Reopen(dropdown) end)
        end
        if i < #list then
            box:CreateButton("Move right", function() self:MoveColumn(key, name, 1) return Reopen(dropdown) end)
        end
    end
    root:CreateDivider()
    root:CreateButton("Show all, default order", function() self:ResetColumnLayout(key) end)
    root:CreateButton("More settings (/ahf)", function() self:ToggleConfig("order") end)
end

function AHF:SetupColumnsButton(f)
    local bar = type(f.SearchBar) == "table" and f.SearchBar or nil
    if not bar or self.columnsButton then return end
    local ok, b = pcall(CreateFrame, "DropdownButton", nil, bar, "WowStyle1FilterDropdownTemplate")
    if not ok or not b or not b.SetupMenu then return end
    b:SetSize(93, 22)
    -- The template's own SetText (DropdownTextMixin): setting only the font
    -- string would be put back to "Filter" the next time the menu updates
    b:SetText("Columns")
    local left = type(bar.FavoritesSearchButton) == "table" and bar.FavoritesSearchButton or bar.SearchBox
    if left then b:SetPoint("RIGHT", left, "LEFT", -10, 0) else b:SetPoint("LEFT", bar, "LEFT", -103, 0) end
    b:SetupMenu(function(dropdown, root) AHF:BuildColumnsMenu(dropdown, root) end)
    self.columnsButton = b
end
