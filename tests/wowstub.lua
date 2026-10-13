-- Minimal WoW API stub for exercising AuctionHouse Forever outside the game.
-- Methods (CamelCase keys) default to no-ops; lowercase fields read as nil like real frames.
-- Also fakes the parts of Blizzard_AuctionHouseUI the addon touches: AuctionHouseFrame,
-- its category list and its item lists with a table builder (FakeAuctionHouse()).

LOG = {}
local function log(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end LOG[#LOG + 1] = table.concat(t, " ") end
print = function(...) log(...) end

ALL_FRAMES = {}
PURCHASES = {}   -- any bid, buyout, purchase or post the addon makes (must stay empty)

local ObjMT = {}
local Methods = {}
STUB_METHODS = Methods   -- tests/render.lua adds layout tracking
-- Methods the addon's own widgets add (Theme.lua); a widget without them must
-- fail here like in the game, not quietly do nothing
local ADDON_METHODS = { SetDisabled = true, SetOn = true, SetHover = true, Refresh = true, Choose = true,
    SetContent = true, ShowTab = true, FitLogo = true }
ObjMT.__index = function(t, k)
    if Methods[k] then return Methods[k] end
    if ADDON_METHODS[k] then return nil end
    if type(k) == "string" and k:match("^%u") then return function() return nil end end
    return nil
end

function newObj(kind, name, parent, template)
    local o = setmetatable({ __kind = kind, __name = name, __parent = parent, __template = template,
        __scripts = {}, __shown = true, __children = {}, __w = 100, __h = 20, __scale = 1 }, ObjMT)
    if parent and parent.__children then table.insert(parent.__children, o) end
    ALL_FRAMES[#ALL_FRAMES + 1] = o
    if name then _G[name] = o end
    return o
end

function Methods:CreateTexture() return newObj("Texture", nil, self) end
function Methods:CreateFontString() local f = newObj("FontString", nil, self); f.__text = "" return f end
function Methods:Show() local was = self.__shown self.__shown = true if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end end
function Methods:Hide() local was = self.__shown self.__shown = false if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self.__shown end
function Methods:IsVisible()
    local f = self
    while f do if f.__shown == false then return false end f = f.__parent end
    return true
end
function Methods:SetScript(k, fn) self.__scripts[k] = fn end
function Methods:GetScript(k) return self.__scripts[k] end
function Methods:HookScript(k, fn)
    local old = self.__scripts[k]
    self.__scripts[k] = function(...) if old then old(...) end fn(...) end
end
function Methods:SetText(t) self.__text = t if self.__fs then self.__fs.__text = t end end
function Methods:GetText() return self.__text end
function Methods:GetStringWidth() return #(self.__text or "") * 6 end
function Methods:GetStringHeight() return 12 end
function Methods:GetFont() if self.__fontset then return unpack(self.__fontset) end return "Fonts\\FRIZQT__.TTF", 10, "" end
function Methods:SetFont(f, size, flags) self.__fontset = { f, size, flags } end
function Methods:GetChildren() local r = {} for _, c in ipairs(self.__children) do if c.__kind ~= "Texture" and c.__kind ~= "FontString" then r[#r + 1] = c end end return unpack(r) end
function Methods:GetRegions() local r = {} for _, c in ipairs(self.__children) do if c.__kind == "Texture" or c.__kind == "FontString" then r[#r + 1] = c end end return unpack(r) end
function Methods:GetObjectType() return self.__kind end
function Methods:GetName() return self.__name end
function Methods:GetParent() return self.__parent end
function Methods:SetParent(p) self.__parent = p end
function Methods:GetChildren() local r = {} for _, c in ipairs(self.__children) do if c.__kind ~= "Texture" and c.__kind ~= "FontString" then r[#r + 1] = c end end return unpack(r) end
function Methods:SetFontString(fs) self.__fs = fs end
function Methods:SetupMenu(fn) self.__menuGen = fn end
function Methods:GetFontString() return self.__fs end
function Methods:SetTexture(t) self.__texture = t end
function Methods:SetAlpha(a) self.__alpha = a end
function Methods:GetAlpha() return self.__alpha or 1 end
function Methods:SetFrameLevel(l) self.__level = l end
function Methods:GetFrameLevel() return self.__level or 1 end
function Methods:EnableMouse(v) self.__mouse = v and true or false end
function Methods:IsMouseEnabled() return self.__mouse end
function Methods:IsMouseOver() return false end
function Methods:GetEffectiveScale() return self.__scale end
function Methods:RegisterEvent(e) self.__events = self.__events or {} self.__events[e] = true end
function Methods:SetValue(v) self.__value = v if self.__scripts.OnValueChanged then self.__scripts.OnValueChanged(self, v) end end
function Methods:GetValue() return self.__value end
function Methods:SetVerticalScroll(v) self.__scroll = v end
function Methods:GetVerticalScroll() return self.__scroll or 0 end
function Methods:GetVerticalScrollRange() return 0 end

-- Size, position and scale are tracked; OnSizeChanged fires like the real game
local function sizeChanged(self, ow, oh)
    if (ow ~= self.__w or oh ~= self.__h) and self.__scripts.OnSizeChanged then
        self.__scripts.OnSizeChanged(self, self.__w, self.__h)
    end
end
function Methods:SetSize(w, h) local ow, oh = self.__w, self.__h self.__w, self.__h = w, h sizeChanged(self, ow, oh) end
function Methods:SetWidth(w) local ow, oh = self.__w, self.__h self.__w = w sizeChanged(self, ow, oh) end
function Methods:SetHeight(h) local ow, oh = self.__w, self.__h self.__h = h sizeChanged(self, ow, oh) end
function Methods:GetWidth() return self.__w end
function Methods:GetHeight() return self.__h end
function Methods:GetSize() return self.__w, self.__h end
function Methods:SetScale(s) self.__scale = s end
function Methods:GetScale() return self.__scale end
function Methods:ClearAllPoints() self.__points = {} end
function Methods:SetPoint(p, rel, rp, x, y)
    self.__points = self.__points or {}
    if type(rel) == "number" then rel, rp, x, y = nil, p, rel, rp end
    if type(rel) == "string" then rel = nil end
    table.insert(self.__points, { p, rel, rp or p, x or 0, y or 0 })
end
function Methods:GetPoint(i)
    local pt = self.__points and self.__points[i or 1]
    if not pt then return nil end
    return pt[1], pt[2], pt[3], pt[4], pt[5]
end
function Methods:GetNumPoints() return self.__points and #self.__points or 0 end
function Methods:GetLeft() return self.__left or 100 end
function Methods:GetTop() return self.__top or 700 end
function Methods:SetResizeBounds(a, b, c, d) self.__bounds = { a, b, c, d } end
function Methods:StartSizing(point) self.__sizing = point end
function Methods:StartMoving() self.__moving = true end
function Methods:StopMovingOrSizing() self.__sizing, self.__moving = nil, nil end

function CreateFrame(kind, name, parent, template) return newObj(kind, name, parent, template) end
UIParent = newObj("Frame", "UIParent")
UIParent.__w, UIParent.__h = 1920, 1080
GameTooltip = newObj("GameTooltip", "GameTooltip")
GameFontHighlightSmall = newObj("Font", "GameFontHighlightSmall")

-- hooksecurefunc: global function or a table's method
function hooksecurefunc(a, b, c)
    local tbl, name, fn = _G, a, b
    if type(a) == "table" then tbl, name, fn = a, b, c end
    local old = tbl[name]
    assert(type(old) == "function", "hooksecurefunc: no function " .. tostring(name))
    tbl[name] = function(...)
        local r = { old(...) }
        fn(...)
        return unpack(r)
    end
end
SELECTED_TABS = {}
function PanelTemplates_SelectTab(t) SELECTED_TABS[t] = true end
function PanelTemplates_DeselectTab(t) SELECTED_TABS[t] = nil end
function PanelTemplates_UpdateTabs(f) end
function PanelTemplates_SetTab(f, i) f.selectedTab = i end
function PanelTemplates_TabResize() end
function geterrorhandler() return function(err) error(err, 0) end end

FAKE_TIME = 100
function GetTime() return FAKE_TIME end
CURSOR_X = 500
function GetCursorPosition() return CURSOR_X, 300 end
PENDING_TIMERS = {}
C_Timer = { After = function(_, fn) PENDING_TIMERS[#PENDING_TIMERS + 1] = fn end }
function RunTimers()
    local t = PENDING_TIMERS
    PENDING_TIMERS = {}
    for _, fn in ipairs(t) do fn() end
end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
AH_LOADED = false
C_AddOns = {
    GetAddOnMetadata = function() return "@project-version@" end,
    IsAddOnLoaded = function(name) return name == "Blizzard_AuctionHouseUI" and AH_LOADED end,
}
UISpecialFrames = {}
SlashCmdList = {}
MENUS = {}
MenuUtil = { CreateContextMenu = function(owner, builder)
    local root = { entries = {} }
    function root:CreateTitle() end
    function root:CreateRadio(t, get, set) table.insert(self.entries, { text = t, get = get, fn = set }) end
    builder(owner, root)
    MENUS[#MENUS + 1] = root
end }
SETTINGS_CATEGORIES = {}
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, name = name } end,
    RegisterAddOnCategory = function(cat) SETTINGS_CATEGORIES[#SETTINGS_CATEGORIES + 1] = cat end,
}
-- The real purchase calls; the addon must never call them
C_AuctionHouse = {}
for _, fn in ipairs({ "PlaceBid", "ConfirmCommoditiesPurchase", "StartCommoditiesPurchase", "PostItem",
        "PostCommodity", "CancelAuction" }) do
    C_AuctionHouse[fn] = function() PURCHASES[#PURCHASES + 1] = fn end
end

UIPANEL_POSITIONS = 0
-- The panel manager puts doublewide panels back in their place
function UpdateUIPanelPositions()
    UIPANEL_POSITIONS = UIPANEL_POSITIONS + 1
    local f = AuctionHouseFrame
    if f and f:IsShown() then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -104)
    end
end

---------------------------------------------------------------------------
-- Fake table builder: the same width math as Blizzard's TableBuilder.lua
---------------------------------------------------------------------------
local Column = {}
Column.__index = Column
function Column:GetHeaderFrame() return self.header end
function Column:SetFixedConstraints(w, pad) self.fixedWidth, self.fill, self.padding = w, 0, pad or 0 end
function Column:SetFillConstraints(c, pad) self.fixedWidth, self.fill, self.padding = 0, c, pad or 0 end
function Column:GetFixedWidth() return self.fixedWidth end
function Column:GetFillCoefficient() return self.fill end
function Column:GetPadding() return self.padding end
function Column:GetCalculatedWidth() return self.calculatedWidth end
function Column:Reset() self.resets = (self.resets or 0) + 1 end
function Column:ConstructHeader(kind, template, owner, text, sortOrder)
    self.header = newObj("Button", nil, self.table.headerContainer, template)
    self.header.__text = text
    self.header.__h = 19
    self.header.Arrow = newObj("Texture", nil, self.header)
    self.header.Arrow.__shown = false
    self.headerOwner = owner
end
function Column:ConstructCells(kind, template, ...) self.cellTemplate, self.cellArgs = template, { ... } end
function Column:SetCellPadding(l, r) self.cellPadding = { l, r } end

local Builder = {}
Builder.__index = Builder
function NewTableBuilder(headerContainer)
    return setmetatable({ columns = {}, tableWidth = 0, arranged = 0, headerContainer = headerContainer }, Builder)
end
function Builder:GetColumns() return self.columns end
function Builder:SetTableWidth(w) self.tableWidth = w end
function Builder:GetTableWidth() return self.tableWidth end
function Builder:Reset()
    for _, c in ipairs(self.columns) do if c.header then c.header:Hide() end end
    self.columns = {}
end
-- Like the real builder: a bare column, set up by the caller
function Builder:AddColumn()
    local c = setmetatable({ padding = 0, fill = 0, fixedWidth = 0, table = self }, Column)
    table.insert(self.columns, c)
    return c
end
-- header: nil for a column without one (the favourite star)
function Builder:AddTestColumn(header, width, fill, padding)
    local c = setmetatable({ padding = padding or 0 }, Column)
    if header then
        c.header = newObj("Button", nil, self.headerContainer)
        c.header.__text = header
        c.header.__h = 19
        c.header.Arrow = newObj("Texture", nil, c.header)
        c.header.Arrow.__shown = false
    end
    if fill then c:SetFillConstraints(fill, padding) else c:SetFixedConstraints(width, padding) end
    table.insert(self.columns, c)
    return c
end
function Builder:Arrange()
    local pad, fillTotal, fixed = 0, 0, 0
    for _, c in ipairs(self.columns) do
        if c.fill > 0 then fillTotal = fillTotal + c.fill else fixed = fixed + c.fixedWidth end
        pad = pad + c.padding
    end
    local fillW = self.tableWidth - pad - fixed
    local x = 0
    for _, c in ipairs(self.columns) do
        c.calculatedWidth = (c.fill > 0 and fillTotal > 0) and (c.fill / fillTotal * fillW) or c.fixedWidth
        x = x + c.padding
        c.left = x
        x = x + c.calculatedWidth
        if c.header then c.header.__w = c.calculatedWidth end
    end
    self.arranged = self.arranged + 1
end
function Builder:Width(name)
    for _, c in ipairs(self.columns) do if c.header and c.header.__text == name then return c.calculatedWidth end end
end
function Builder:Names()
    local t = {}
    for _, c in ipairs(self.columns) do t[#t + 1] = c.header and c.header.__text or "*" end
    return table.concat(t, ",")
end
function Builder:Column(name)
    for _, c in ipairs(self.columns) do if c.header and c.header.__text == name then return c end end
end

-- An item list like AuctionHouseItemListTemplate: header container, scroll box,
-- table builder made on first show, and the layout function run when dirty
local function NewItemList(parent, layout)
    local list = newObj("Frame", nil, parent)
    list.HeaderContainer = newObj("Frame", nil, list)
    list.Background = newObj("Texture", nil, list)
    list.Background:SetPoint("TOPLEFT", 3, -3)
    list.ScrollBox = newObj("Frame", nil, list)
    list.ScrollBox.__w = 600
    -- Two rows, each with a cell holding a font string (and one nested deeper)
    list.ScrollBox.__rows = {}
    for i = 1, 2 do
        local row = newObj("Button", nil, list.ScrollBox)
        local cell = newObj("Frame", nil, row)
        cell.Text = cell:CreateFontString()
        local money = newObj("Frame", nil, cell)
        money.Gold = money:CreateFontString()
        list.ScrollBox.__rows[i] = row
    end
    -- Like the game: no view (and ForEachFrame errors) until the list is first shown
    function list.ScrollBox:GetView() return self.__view end
    function list.ScrollBox:ForEachFrame(fn)
        assert(self.__view, "ForEachFrame without a view")
        for _, r in ipairs(self.__rows) do fn(r) end
    end
    list.ScrollBox.__callbacks = {}
    function list.ScrollBox:RegisterCallback(event, fn) self.__callbacks[event] = fn end
    function list:GetHeaderContainer() return self.HeaderContainer end
    list.tableBuilderLayoutFunction = layout
    list.tableBuilderLayoutDirty = true
    function list:UpdateTableBuilderLayout()
        if not self.tableBuilder then self.tableBuilder = NewTableBuilder(self.HeaderContainer) end
        if not self.ScrollBox.__view then
            -- Like the game: no row extent until the first rows, and asking for
            -- it without a row index errors until then
            local view = {}
            function view:GetElementExtent(i)
                if not self.elementExtent then return i < 0 end
                return self.elementExtent
            end
            function view:SetElementExtent(e) self.elementExtent = e end
            self.ScrollBox.__view = view
        end
        if self.tableBuilderLayoutDirty then
            self.tableBuilder:Reset()
            self.tableBuilderLayoutFunction(self.tableBuilder)
            self.tableBuilder:SetTableWidth(self.ScrollBox:GetWidth())
            self.tableBuilder:Arrange()
            self.tableBuilderLayoutDirty = false
        end
    end
    function list:SetTableBuilderLayout(fn)
        self.tableBuilderLayoutFunction = fn
        self.tableBuilderLayoutDirty = true
        if self:IsShown() then self:UpdateTableBuilderLayout() end
    end
    return list
end

-- Blizzard's browse layout: Price 146, Name fills, Available 83, favourite star 29
function BrowseLayout(tb)
    tb:AddTestColumn("Price", 146, nil, 0)
    tb:AddTestColumn("Name", nil, 1, 0)
    tb:AddTestColumn("Available", 83, nil, 0)
    tb:AddTestColumn(nil, 29, nil, 0)
end

function FakeAuctionHouse()
    local f = newObj("Frame", "AuctionHouseFrame", UIParent)
    f.__w, f.__h = 800, 538
    f.__shown = false
    f:SetPoint("CENTER")
    f.CategoriesList = newObj("Frame", nil, f)
    f.CategoriesList.__w, f.CategoriesList.__h = 168, 438
    f.CategoriesList.Background = newObj("Texture", nil, f.CategoriesList)
    f.CategoriesList.Background.__w = 162
    f.CategoriesList.Background:SetPoint("TOPLEFT", 3, -3)
    local box = newObj("Frame", nil, f.CategoriesList)
    box.__buttons = {}
    for i = 1, 3 do
        local b = newObj("Button", nil, box)
        b.__w = 132
        b.NormalTexture = newObj("Texture", nil, b)
        b.NormalTexture.__w, b.NormalTexture.__h = 136, 32
        b.__h = 21
        b.Text = b:CreateFontString()
        b.HighlightTexture = newObj("Texture", nil, b)
        b.HighlightTexture.__w = 130
        b.SelectedTexture = newObj("Texture", nil, b)
        b.__data = { type = "category", name = "Weapons" }
        function b:GetElementData() return self.__data end
        function b:GetNormalFontObject() return self.__fontObject end
        box.__buttons[i] = b
    end
    -- Like Blizzard's (Classic): every draw puts fixed sizes and its font back
    function AuctionHouseFilterButton_SetUp(button, info)
        button.NormalTexture:SetSize(136, 20)
        button.SelectedTexture:SetSize(134, 20)
        button.HighlightTexture:SetSize(132, 21)
        -- SetNormalFontObject: the font object's size; a size set on the text
        -- itself stays (like the game)
        button.__fontObject = button.__fontObject or { GetFont = function() return "Fonts\\FRIZQT__.TTF", 10, "" end }
        button.setUps = (button.setUps or 0) + 1
    end
    function box:ForEachFrame(fn) for _, b in ipairs(self.__buttons) do fn(b) end end
    -- The category list has its view from the start
    box.__view = { elementExtent = 21 }
    function box.__view:SetElementExtent(e) self.elementExtent = e end
    function box:GetView() return self.__view end
    box.__callbacks = {}
    function box:RegisterCallback(event, fn, owner) self.__callbacks[event] = fn end
    f.CategoriesList.ScrollBox = box
    f.Tabs = {}
    for i, name in ipairs({ "Buy", "Sell", "Auctions", "Auctionator" }) do
        local t = newObj("Button", nil, f)
        t.__text = name
        t.__right = 100 * i
        function t:GetRight() return self.__right end
        function t:GetBottom() return 10 end
        f.Tabs[i] = t
    end
    f.SearchBar = newObj("Frame", nil, f)
    f.SearchBar.FavoritesSearchButton = newObj("Button", nil, f.SearchBar)
    f.BrowseResultsFrame = newObj("Frame", nil, f)
    f.BrowseResultsFrame.ItemList = NewItemList(f.BrowseResultsFrame, BrowseLayout)
    f.BrowseResultsFrame.browseResults = {}
    -- Like Blizzard's: a new search replaces the results, more results add to them
    function f.BrowseResultsFrame:UpdateBrowseResults(added)
        if added then for _, r in ipairs(added) do table.insert(self.browseResults, r) end end
    end
    function f.BrowseResultsFrame:SetSortOrder(order) self.sortOrder = order end
    f.ItemBuyFrame = newObj("Frame", nil, f)
    f.ItemBuyFrame.ItemList = NewItemList(f.ItemBuyFrame, function(tb)
        tb:AddTestColumn("Bid", 140, nil, 0)
        tb:AddTestColumn("Buyout", 140, nil, 0)
        tb:AddTestColumn(nil, 40, 1, 0)   -- quantity: fills, no header (like Blizzard's)
    end)
    -- What the game's anchors do: the lists stretch with the window and make
    -- room for the category list
    local function relayout()
        local w = f.__w - f.CategoriesList.__w - 40
        f.BrowseResultsFrame.ItemList.ScrollBox:SetWidth(w)
        f.ItemBuyFrame.ItemList.ScrollBox:SetWidth(w + f.CategoriesList.__w)
    end
    f:SetScript("OnSizeChanged", relayout)
    f.CategoriesList:SetScript("OnSizeChanged", relayout)
    relayout()
    f.displayMode = "Buy"
    function f:SetDisplayMode(mode)
        self.displayMode = mode
        self:SetSize(800, 538)   -- worst case: Blizzard puts its own size back
    end
    function f:GetDisplayMode() return self.displayMode end
    -- What a real Show does: OnShow, panel manager, lists laid out
    function f:Open()
        self:Show()
        UpdateUIPanelPositions()
        self.BrowseResultsFrame.ItemList:UpdateTableBuilderLayout()
    end
    return f
end
