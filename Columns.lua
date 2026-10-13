-- AuctionHouse Forever: columns. Drag the divider between two column headers to
-- resize a column (double-click it for the column's default width); hide, show
-- and reorder columns in the settings; pick the row text size.
--
-- Every Auction House list is a table builder: Blizzard (and addons such as the
-- one adding the Median column) add columns in a layout function, then
-- tableBuilder:Arrange() gives each one its width. One "fill" column (Name)
-- takes whatever is left. After each layout, the saved settings are put on:
-- hidden columns are taken out of the table builder's list (kept here, and put
-- back when shown again), named columns are put in the saved order (columns
-- without a header, like the favourite star, keep their place), the saved
-- widths go on the fixed columns, and the table is arranged again. Columns are
-- known by their header text, so columns from other addons are handled the same
-- way and are never deleted or replaced.

local _, ns = ...
local AHF = ns.AHF
local Clamp = AHF.Clamp

-- The lists, by where they sit under AuctionHouseFrame. A list that doesn't
-- exist on this client is skipped.
AHF.COLUMN_LISTS = {
    { key = "browse",          path = { "BrowseResultsFrame", "ItemList" } },
    { key = "itemBuy",         path = { "ItemBuyFrame", "ItemList" } },
    { key = "commoditiesBuy",  path = { "CommoditiesBuyFrame", "ItemList" } },
    { key = "itemSell",        path = { "ItemSellList" } },
    { key = "commoditiesSell", path = { "CommoditiesSellList" } },
    { key = "allAuctions",     path = { "AuctionsFrame", "AllAuctionsList" } },
    { key = "bids",            path = { "AuctionsFrame", "BidsList" } },
    { key = "auctionsItem",    path = { "AuctionsFrame", "ItemList" } },
    { key = "auctionsCommodities", path = { "AuctionsFrame", "CommoditiesList" } },
}

local GRIP_W = 8
local seen = setmetatable({}, { __mode = "k" })   -- column objects whose default width is recorded
local defaults = {}                                -- [list key][column name] = Blizzard's width
local entries = {}                                 -- the lists found, in COLUMN_LISTS order
AHF.columnEntries = entries

local function Round(v) return math.floor(v + 0.5) end

local function Resolve(root, path)
    local f = root
    for _, k in ipairs(path) do
        f = f[k]
        if type(f) ~= "table" then return nil end
    end
    return f
end

-- A column's name: its header text without colour codes, or nil (no header,
-- like the favourite star; those keep Blizzard's width)
local function ColumnName(col)
    local h = col.GetHeaderFrame and col:GetHeaderFrame()
    local text = h and h.GetText and h:GetText()
    if type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
    if text == "" then return nil end
    return text
end

local function IsFill(col)
    local c = col.GetFillCoefficient and col:GetFillCoefficient()
    return type(c) == "number" and c > 0
end
AHF.IsFillColumn = IsFill

-- The table's (shown) columns, with their names
local function Columns(entry)
    local tb = entry.list.tableBuilder
    local cols = tb and tb.GetColumns and tb:GetColumns()
    if not cols or #cols == 0 then return nil, tb end
    local out, used = {}, {}
    for i, col in ipairs(cols) do
        out[i] = { col = col, name = entry.names[col], fill = IsFill(col) }
    end
    return out, tb
end

local function SetWidth(col, w)
    col:SetFixedConstraints(w, col:GetPadding() or 0)
end

-- Room the fill column (Name) gets with the current widths
local function FillWidth(entry, cols)
    local tableW = entry.list.ScrollBox and entry.list.ScrollBox:GetWidth() or 0
    local used = 0
    for _, c in ipairs(cols) do
        used = used + (c.col:GetPadding() or 0)
        if not c.fill then used = used + (c.col:GetFixedWidth() or 0) end
    end
    return tableW - used
end

local function HasFill(cols)
    for _, c in ipairs(cols) do if c.fill then return true end end
    return false
end

---------------------------------------------------------------------------
-- Divider grips on the header row
---------------------------------------------------------------------------
local function GripTarget(cols, headers, j)
    -- Left of the fill column (or with none), a divider resizes the column on
    -- its left; right of it, the column on its right. Either way the divider
    -- follows the mouse.
    local left, right = headers[j], headers[j + 1]
    local fillIndex
    for i, h in ipairs(headers) do if h.fill then fillIndex = i break end end
    if fillIndex and j + 1 > fillIndex then
        if not right.fill and right.name then return right, -1 end
    elseif not left.fill and left.name then
        return left, 1
    end
    return nil
end

local function StopDrag(grip)
    grip:SetScript("OnUpdate", nil)
    grip.drag = nil
    if not grip:IsMouseOver() then grip:SetHover(false) end
end

local function CursorX(grip)
    local x = GetCursorPosition()
    return x / (grip:GetEffectiveScale() or 1)
end

local function MakeGrip(entry, parent)
    local g = CreateFrame("Button", nil, parent)
    g:SetSize(GRIP_W, 20)
    g:SetFrameLevel((parent:GetFrameLevel() or 0) + 10)
    g:RegisterForClicks("LeftButtonUp")
    local line = g:CreateTexture(nil, "OVERLAY")
    line:SetPoint("TOP")
    line:SetPoint("BOTTOM")
    line:SetWidth(2)
    line:SetColorTexture(1, 0.82, 0, 0.9)
    line:SetAlpha(0)
    g.line = line
    function g:SetHover(on) self.line:SetAlpha((on or self.drag) and 1 or 0) end
    ns.Theme.Tooltip(g, "Column width", "Drag to resize this column. Double-click for its default width.")

    g:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not self.col then return end
        local cols = Columns(entry)
        if not cols then return end
        self.drag = {
            startX = CursorX(self),
            startW = self.col:GetFixedWidth() or 0,
            room = HasFill(cols) and (FillWidth(entry, cols) - AHF.NAME_MIN) or math.huge,
        }
        self:SetHover(true)
        self:SetScript("OnUpdate", function(s)
            local d = s.drag
            if not d or not s.col then return StopDrag(s) end
            local w = Round(d.startW + s.sign * (CursorX(s) - d.startX))
            w = Clamp(w, { AHF.LIMITS.column[1], math.min(AHF.LIMITS.column[2], d.startW + math.max(0, d.room)) })
            if w ~= (s.col:GetFixedWidth() or 0) then
                AHF:ColumnState(entry.key).widths[s.colName] = w
                SetWidth(s.col, w)
                AHF:ArrangeColumns(entry)
            end
        end)
    end)
    g:SetScript("OnMouseUp", function(self) StopDrag(self) end)
    g:SetScript("OnDoubleClick", function(self)
        StopDrag(self)
        if not self.col then return end
        AHF:ColumnState(entry.key).widths[self.colName] = nil
        local def = defaults[entry.key] and defaults[entry.key][self.colName]
        if def then SetWidth(self.col, def) end
        AHF:ArrangeColumns(entry)
    end)
    return g
end

local function PlaceGrips(entry, cols)
    local parent = entry.list.GetHeaderContainer and entry.list:GetHeaderContainer() or entry.list.HeaderContainer
    local headers = {}
    if parent and cols then
        for _, c in ipairs(cols) do
            local h = c.col:GetHeaderFrame()
            if h and h.IsShown and h:IsShown() then
                headers[#headers + 1] = { col = c.col, name = c.name, fill = c.fill, header = h }
            end
        end
    end
    local n = 0
    for j = 1, #headers - 1 do
        local target, sign = GripTarget(cols, headers, j)
        if target then
            n = n + 1
            local g = entry.grips[n]
            if not g then
                g = MakeGrip(entry, parent)
                entry.grips[n] = g
            end
            local h = headers[j].header
            g:ClearAllPoints()
            g:SetPoint("CENTER", h, "RIGHT", 0, 0)
            g:SetHeight(math.max(12, h:GetHeight() or 20))
            g.col, g.colName, g.sign = target.col, target.name, sign
            g:Show()
        end
    end
    for i = n + 1, #entry.grips do
        local g = entry.grips[i]
        g.col, g.drag = nil, nil
        g:SetScript("OnUpdate", nil)
        g:Hide()
    end
end

---------------------------------------------------------------------------
-- Hidden columns and order
---------------------------------------------------------------------------
-- Names for a list of columns, by header text (a second column with the same
-- name gets " 2" added)
local function NameColumns(cols)
    local names, used = setmetatable({}, { __mode = "k" }), {}
    for _, col in ipairs(cols) do
        local name = ColumnName(col)
        if name then
            if used[name] then
                used[name] = used[name] + 1
                name = name .. " " .. used[name]
            else
                used[name] = 1
            end
            names[col] = name
        end
    end
    return names
end

-- Keeps entry.natural: every column of the list in the order it was built,
-- hidden ones included. A layout made of new column objects is a new build;
-- a few new columns among ours were added by another addon and go after the
-- column before them.
local function SyncNatural(entry, cur)
    local new = 0
    for _, col in ipairs(cur) do if not entry.known[col] then new = new + 1 end end
    if new == 0 then return false end
    if new == #cur then
        entry.natural = {}
        entry.known = setmetatable({}, { __mode = "k" })
        for i, col in ipairs(cur) do entry.natural[i] = col; entry.known[col] = true end
    else
        for i, col in ipairs(cur) do
            if not entry.known[col] then
                local at = 1
                for j, c in ipairs(entry.natural) do if c == cur[i - 1] then at = j + 1 break end end
                table.insert(entry.natural, at, col)
                entry.known[col] = true
            end
        end
    end
    entry.names = NameColumns(entry.natural)
    return true
end

-- Named columns sorted by the saved order. A column missing from it (new, or
-- from another addon) stays right after the column it was built after.
local function SortNamed(cols, names, order)
    local rankOf = {}
    for i, n in ipairs(order) do rankOf[n] = i end
    local ranked, last = {}, 0
    for i, col in ipairs(cols) do
        local r = rankOf[names[col]]
        if r then last = r else r = last + i / 1000 end
        ranked[#ranked + 1] = { col = col, r = r, i = i }
    end
    table.sort(ranked, function(a, b)
        if a.r ~= b.r then return a.r < b.r end
        return a.i < b.i
    end)
    local out = {}
    for k, v in ipairs(ranked) do out[k] = v.col end
    return out
end

-- Puts the shown columns, in the saved order, into the table builder's list.
-- The fill column (Name) is never hidden.
local function ShapeColumns(entry, tb)
    local cur = tb:GetColumns()
    if SyncNatural(entry, cur) then AHF:RefreshOptions() end
    local state = AHF:ColumnState(entry.key)
    local names = entry.names
    local shown, hidden = {}, {}
    for _, col in ipairs(entry.natural) do
        local name = names[col]
        if name and AHF:IsColumnHidden(entry.key, name) and not IsFill(col) then
            hidden[#hidden + 1] = col
        else
            shown[#shown + 1] = col
        end
    end
    local named, slots = {}, {}
    for i, col in ipairs(shown) do
        if names[col] then named[#named + 1] = col; slots[#slots + 1] = i end
    end
    named = SortNamed(named, names, state.order)
    for k, i in ipairs(slots) do shown[i] = named[k] end

    local same = #shown == #cur
    for i = 1, #shown do if shown[i] ~= cur[i] then same = false break end end
    if not same then
        for i = #cur, 1, -1 do cur[i] = nil end
        for i, col in ipairs(shown) do cur[i] = col end
    end
    -- Hidden columns let go of their cells; shown ones get their header back
    for _, col in ipairs(hidden) do
        if col.Reset then col:Reset() end
        local h = col:GetHeaderFrame()
        if h then h:Hide() end
    end
    for _, col in ipairs(shown) do
        local h = col:GetHeaderFrame()
        if h and not h:IsShown() then h:Show() end
    end
end

---------------------------------------------------------------------------
-- Row text size
---------------------------------------------------------------------------
local fontBase = setmetatable({}, { __mode = "k" })   -- font strings changed, and their own font

local function SetRowFonts(frame, size, depth)
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" and r.SetFont then
            if not fontBase[r] then
                local font, base, flags = r:GetFont()
                if font then fontBase[r] = { font, base, flags } end
            end
            local b = fontBase[r]
            if b then r:SetFont(b[1], size, b[3]) end
        end
    end
    if depth > 0 and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do SetRowFonts(child, size, depth - 1) end
    end
end

-- Row height for the text size: Blizzard's 20 at Default, taller for big text
function AHF:RowHeight()
    local size = self.db.rowFontSize
    if size == 0 then return self.ROW_HEIGHT end
    return math.max(self.ROW_HEIGHT, size + 10)
end

-- The list's rows (and the scroll range, via the view's row extent) at the
-- current row height. A new row gets it as it's handed out (OnAcquiredFrame),
-- before Blizzard lays its cells out.
local function ApplyRowHeight(entry)
    local box = entry.list.ScrollBox
    if not AHF.HasRows(box) or not box.GetView then return end
    local h = AHF:RowHeight()
    local view = box:GetView()
    -- view.elementExtent is nil until the list's first rows (GetElementExtent
    -- then needs a row index and errors without one), so read the field
    local current = type(view) == "table" and view.elementExtent or AHF.ROW_HEIGHT
    if view.SetElementExtent and current ~= h then
        view:SetElementExtent(h)
        box:ForEachFrame(function(row) row:SetHeight(h) end)
        if box.FullUpdate then box:FullUpdate(true) elseif box.Update then box:Update() end
    end
end

local function ApplyRowFonts(entry)
    local size = AHF.db.rowFontSize
    local box = entry.list.ScrollBox
    if not AHF.HasRows(box) then return end
    ApplyRowHeight(entry)
    if size == 0 then return end
    box:ForEachFrame(function(row) SetRowFonts(row, size, 3) end)
end

-- After a change of the setting: every list's rows, and back to the game's own
-- font (pooled cells included) at Default
function AHF:ApplyRowFonts()
    if self.db.rowFontSize == 0 then
        for fs, b in pairs(fontBase) do fs:SetFont(b[1], b[2], b[3]) end
        fontBase = setmetatable({}, { __mode = "k" })
    end
    for _, entry in ipairs(entries) do
        ApplyRowFonts(entry)
        -- Cells take the row's height when arranged
        if entry.list.tableBuilder then self:ArrangeColumns(entry) end
    end
end

function AHF:SetRowFontSize(size)
    local ok = false
    for _, v in ipairs(self.ROW_FONT_SIZES) do if v == size then ok = true end end
    self.db.rowFontSize = ok and size or 0
    self:ApplyRowFonts()
    self:RefreshOptions()
end

---------------------------------------------------------------------------
-- Widths
---------------------------------------------------------------------------
-- Lays the columns out across the list's current width, keeping at least
-- NAME_MIN for the fill column: dragged columns give way first (back towards
-- Blizzard's width) when the window is too narrow. Saved widths don't change.
function AHF:ArrangeColumns(entry)
    local tb = entry.list.tableBuilder
    local cur = tb and tb.GetColumns and tb:GetColumns()
    if not cur or #cur == 0 then PlaceGrips(entry, nil) return end
    if self.AddExtraColumns then self:AddExtraColumns(entry, tb) end
    ShapeColumns(entry, tb)
    local cols = Columns(entry)
    -- Blizzard's width of each column seen for the first time, before any change
    defaults[entry.key] = defaults[entry.key] or {}
    local def = defaults[entry.key]
    local saved = self:ColumnState(entry.key).widths
    for _, c in ipairs(cols) do
        if c.name and not c.fill then
            if not seen[c.col] then
                seen[c.col] = true
                def[c.name] = c.col:GetFixedWidth()
            end
            local w = saved[c.name]
            if w and w ~= c.col:GetFixedWidth() then SetWidth(c.col, w) end
        end
    end
    if HasFill(cols) then
        local short = self.NAME_MIN - FillWidth(entry, cols)
        for i = #cols, 1, -1 do
            if short <= 0 then break end
            local c = cols[i]
            local d = c.name and def[c.name]
            local w = c.col:GetFixedWidth() or 0
            if not c.fill and d and w > d then
                local give = math.min(short, w - d)
                SetWidth(c.col, w - give)
                short = short - give
            end
        end
    end
    local box = entry.list.ScrollBox
    if box and tb.SetTableWidth then tb:SetTableWidth(box:GetWidth() or 0) end
    tb:Arrange()
    PlaceGrips(entry, cols)
    ApplyRowFonts(entry)
end

function AHF:DefaultColumnWidth(listKey, name)
    return defaults[listKey] and defaults[listKey][name]
end

-- Every list back to Blizzard's columns: widths, all shown, Blizzard's order
function AHF:ResetColumns()
    for _, state in pairs(self.charDB.columns) do
        state.widths, state.hidden, state.order = {}, {}, {}
    end
    for _, entry in ipairs(entries) do
        local cols = Columns(entry)
        if cols then
            local def = defaults[entry.key] or {}
            for _, c in ipairs(cols) do
                if c.name and not c.fill and def[c.name] then SetWidth(c.col, def[c.name]) end
            end
            self:ArrangeColumns(entry)
        end
    end
    self:RefreshOptions()
end

-- How many column widths are saved (for the settings window)
function AHF:SavedColumnCount()
    local n = 0
    for _, state in pairs(self.charDB.columns) do
        for _ in pairs(state.widths) do n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- For the settings window: which lists have been seen, and their columns
---------------------------------------------------------------------------
local function Entry(key)
    for _, e in ipairs(entries) do if e.key == key then return e end end
end

-- Keys of the lists whose columns are known (shown at least once)
function AHF:KnownColumnLists()
    local keys = {}
    for _, e in ipairs(entries) do
        for _, col in ipairs(e.natural) do
            if e.names[col] then keys[#keys + 1] = e.key break end
        end
    end
    return keys
end

-- A list's named columns in the order shown: { name =, fill =, shown = }
function AHF:ListColumns(key)
    local e = Entry(key)
    if not e then return {} end
    local named = {}
    for _, col in ipairs(e.natural) do if e.names[col] then named[#named + 1] = col end end
    local state = self:ColumnState(key)
    local out = {}
    for i, col in ipairs(SortNamed(named, e.names, state.order)) do
        local name, fill = e.names[col], IsFill(col)
        out[i] = { name = name, fill = fill, shown = fill or not self:IsColumnHidden(key, name) }
    end
    return out
end

-- Hidden: the player's choice, or the column's default (Type starts hidden)
function AHF:IsColumnHidden(key, name)
    local v = self:ColumnState(key).hidden[name]
    if v ~= nil then return v end
    return self.DefaultHidden and self:DefaultHidden(key, name) or false
end

local function Rearrange(key)
    local e = Entry(key)
    if e then AHF:ArrangeColumns(e) end
    AHF:RefreshOptions()
end

function AHF:SetColumnShown(key, name, shown)
    self:ColumnState(key).hidden[name] = not shown
    Rearrange(key)
end

-- Moves a column one place left (-1) or right (+1) among the named columns
function AHF:MoveColumn(key, name, delta)
    local list = self:ListColumns(key)
    local order = {}
    for i, c in ipairs(list) do order[i] = c.name end
    for i, n in ipairs(order) do
        if n == name then
            local j = i + delta
            if j >= 1 and j <= #order then order[i], order[j] = order[j], order[i] end
            break
        end
    end
    self:ColumnState(key).order = order
    Rearrange(key)
end

-- One list: every column shown, in Blizzard's order (widths stay)
function AHF:ResetColumnLayout(key)
    local state = self:ColumnState(key)
    state.hidden, state.order = {}, {}
    Rearrange(key)
end

---------------------------------------------------------------------------
-- Setup when the Auction House loads
---------------------------------------------------------------------------
function AHF:SetupColumns(f)
    for _, def in ipairs(self.COLUMN_LISTS) do
        local list = Resolve(f, def.path)
        if list and type(list.UpdateTableBuilderLayout) == "function" then
            local entry = { key = def.key, list = list, grips = {}, natural = {},
                known = setmetatable({}, { __mode = "k" }), names = {} }
            entries[#entries + 1] = entry
            -- After every layout Blizzard (or another addon) builds
            hooksecurefunc(list, "UpdateTableBuilderLayout", function()
                AHF:ArrangeColumns(entry)
                -- An addon that adds its column right after Blizzard's layout
                -- gets its saved width on the next frame
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function() AHF:ArrangeColumns(entry) end)
                end
            end)
            -- Blizzard only works the widths out when the layout changes, not
            -- when the list changes size: spread them over the new width
            local box = list.ScrollBox
            if box and box.HookScript then
                box:HookScript("OnSizeChanged", function()
                    if list:IsVisible() then AHF:ArrangeColumns(entry) end
                end)
            end
            -- Rows are reused as the list scrolls: give new ones the text size
            if box and box.RegisterCallback then
                pcall(box.RegisterCallback, box, "OnLayout", function() ApplyRowFonts(entry) end, entry)
                pcall(box.RegisterCallback, box, "OnAcquiredFrame", function(_, row)
                    local h = AHF:RowHeight()
                    if row and row.SetHeight and row:GetHeight() ~= h then row:SetHeight(h) end
                end, entry)
            end
        end
    end
end
