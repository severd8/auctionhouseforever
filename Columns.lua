-- AuctionHouse Forever: column widths. Drag the divider between two column
-- headers to resize a column; double-click it for the column's default width.
--
-- Every Auction House list is a table builder: Blizzard (and addons such as the
-- one adding the Median column) add columns in a layout function, then
-- tableBuilder:Arrange() gives each one its width. One "fill" column (Name)
-- takes whatever is left. After each layout, the saved widths are put on the
-- fixed columns and the table is arranged again. Columns are known by their
-- header text, so columns from other addons are resized the same way and are
-- never removed, replaced or moved.
--
-- Room for v1.1: ColumnState() also holds hidden = {} and order = {} per list;
-- hiding and reordering would go in ApplyWidths, next to the widths.

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

-- The table's columns with their names (a second column with the same name
-- gets " 2" added)
local function Columns(entry)
    local tb = entry.list.tableBuilder
    local cols = tb and tb.GetColumns and tb:GetColumns()
    if not cols or #cols == 0 then return nil, tb end
    local out, used = {}, {}
    for i, col in ipairs(cols) do
        local name = ColumnName(col)
        if name then
            if used[name] then
                used[name] = used[name] + 1
                name = name .. " " .. used[name]
            else
                used[name] = 1
            end
        end
        out[i] = { col = col, name = name, fill = IsFill(col) }
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
-- Widths
---------------------------------------------------------------------------
-- Lays the columns out across the list's current width, keeping at least
-- NAME_MIN for the fill column: dragged columns give way first (back towards
-- Blizzard's width) when the window is too narrow. Saved widths don't change.
function AHF:ArrangeColumns(entry)
    local cols, tb = Columns(entry)
    if not cols then PlaceGrips(entry, nil) return end
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
end

function AHF:DefaultColumnWidth(listKey, name)
    return defaults[listKey] and defaults[listKey][name]
end

-- Every list back to Blizzard's column widths
function AHF:ResetColumns()
    for key in pairs(self.charDB.columns) do
        local state = self.charDB.columns[key]
        state.widths = {}
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
-- Setup when the Auction House loads
---------------------------------------------------------------------------
function AHF:SetupColumns(f)
    for _, def in ipairs(self.COLUMN_LISTS) do
        local list = Resolve(f, def.path)
        if list and type(list.UpdateTableBuilderLayout) == "function" then
            local entry = { key = def.key, list = list, grips = {} }
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
        end
    end
end
