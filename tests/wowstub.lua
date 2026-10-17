-- A small fake of the game's API: enough to load AuctionHouse Forever outside
-- the game and drive it. Frames take any method; the ones the tests look at
-- remember what they were given.

LOG = {}
local realPrint = print
function print(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    LOG[#LOG + 1] = table.concat(t, " ")
end
REAL_PRINT = realPrint

ALL_FRAMES = {}
local Methods = {}
-- Methods the addon adds to its own widgets: a real frame doesn't have them, so
-- calling one that was never added is an error here too (as in the game)
local ADDON_METHODS = { SetDisabled = true, SetOn = true, IsOn = true, SetHover = true, Paint = true,
    Refresh = true, Choose = true, SetContent = true }
local MT = {
    __index = function(obj, k)
        if Methods[k] then return Methods[k] end
        if type(k) == "string" and k:sub(1, 2) == "__" then return nil end
        if ADDON_METHODS[k] then return nil end
        return function() end   -- anything else does nothing
    end,
}

local function newObj(kind, name, parent)
    local o = setmetatable({ __kind = kind, __name = name, __parent = parent, __scripts = {}, __children = {},
        __shown = true, __text = "", __w = 100, __h = 20 }, MT)
    if parent and parent.__children then table.insert(parent.__children, o) end
    if name then _G[name] = o end
    ALL_FRAMES[#ALL_FRAMES + 1] = o
    return o
end
NewObj = newObj

function Methods:CreateTexture() return newObj("Texture", nil, self) end
function Methods:CreateFontString() return newObj("FontString", nil, self) end
function Methods:CreateLine() return newObj("Line", nil, self) end
function Methods:Show()
    local was = self.__shown
    self.__shown = true
    if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end
function Methods:Hide()
    local was = self.__shown
    self.__shown = false
    if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self.__shown end
function Methods:IsVisible()
    local o = self
    while o do
        if not o.__shown then return false end
        o = o.__parent
    end
    return true
end
function Methods:SetScript(k, fn) self.__scripts[k] = fn end
function Methods:GetScript(k) return self.__scripts[k] end
function Methods:HookScript(k, fn)
    local old = self.__scripts[k]
    self.__scripts[k] = function(...) if old then old(...) end fn(...) end
end
function Methods:SetTexture(t) self.__texture = t end
function Methods:SetMaxLetters(n) self.__maxLetters = n end
function Methods:SetText(t) self.__text = t == nil and "" or tostring(t) end
function Methods:GetText() return self.__text end
function Methods:SetFontString(fs) self.__fs = fs end
function Methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Methods:GetStringWidth() return #(self.__text or "") * 6 end
function Methods:SetSize(w, h) self.__w, self.__h = w, h end
function Methods:SetWidth(w) self.__w = w end
function Methods:SetHeight(h) self.__h = h end
function Methods:GetWidth() return self.__w end
function Methods:GetHeight() return self.__h end
function Methods:GetEffectiveScale() return 1 end
function Methods:GetFrameLevel() return 1 end
function Methods:SetPoint(...) self.__points = self.__points or {} table.insert(self.__points, { ... }) end
function Methods:ClearAllPoints() self.__points = {} end
function Methods:GetName() return self.__name end
function Methods:GetObjectType() return self.__kind end
function Methods:RegisterEvent(e) self.__events = self.__events or {} self.__events[e] = true end
function Methods:SetValue(v)
    self.__value = v
    if self.__scripts.OnValueChanged then self.__scripts.OnValueChanged(self, v) end
end
function Methods:GetValue() return self.__value or 0 end
function Methods:SetColorTexture(r, g, b, a) self.__color = { r, g, b, a } end
function Methods:SetVertexColor(r, g, b, a) self.__color = { r, g, b, a } end
function Methods:SetThickness(t) self.__thickness = t end
function Methods:SetStartPoint(_, rel, x, y) self.__from = { x, y }; self.__rel = rel end
function Methods:SetEndPoint(_, rel, x, y) self.__to = { x, y } end
function Methods:SetAlpha(a) self.__alpha = a end
function Methods:GetAlpha() return self.__alpha or 1 end
function Methods:HasFocus() return self.__focus end
function Methods:SetFocus() self.__focus = true end
function Methods:ClearFocus()
    if self.__focus then
        self.__focus = false
        if self.__scripts.OnEditFocusLost then self.__scripts.OnEditFocusLost(self) end
    end
end
function Methods:GetCenter() return 500, 400 end

function CreateFrame(kind, name, parent, template)
    local o = newObj(kind, name, parent)
    o.__template = template
    return o
end
function Methods:Enable() self.__enabled = true end
function Methods:Disable() self.__enabled = false end
function Methods:IsEnabled() return self.__enabled ~= false end

-- Clicks a button the way the game does
function Click(b, which)
    assert(b.__scripts.OnClick, "nothing to click")
    if b.__enabled == false then return end   -- a disabled button ignores clicks
    b.__scripts.OnClick(b, which or "LeftButton")
end

UIParent = newObj("Frame", "UIParent")
GameTooltip = newObj("GameTooltip", "GameTooltip")
UISpecialFrames = {}
GameFontHighlightSmall = {}
SlashCmdList = {}

FAKE_TIME = 1000
function GetTime() return FAKE_TIME end
local profile = 0
function debugprofilestop() profile = profile + 0.5 return profile end

function CreateFromMixins(...)
    local t = {}
    for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do t[k] = v end end
    return t
end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end

-- Runs the frames' OnUpdate scripts (only shown ones, as the game does)
function Tick(seconds)
    for _, f in ipairs(ALL_FRAMES) do
        local fn = f.__scripts.OnUpdate
        if fn and f:IsVisible() then fn(f, seconds or 0.05) end
    end
end

function FireEvent(event, ...)
    for _, f in ipairs(ALL_FRAMES) do
        if f.__events and f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end

function Methods:GetStringHeight() return 14 end
function Methods:SetSpacing() end

---------------------------------------------------------------------------
-- Time, realm, items, tooltips
---------------------------------------------------------------------------
SERVER_TIME = 20000 * 86400 + 12 * 3600     -- midday on day 20000
function GetServerTime() return SERVER_TIME end
function time() return SERVER_TIME end
REALM, FACTION = "Mega Server", "Horde"
function GetRealmName() return REALM end
function UnitFactionGroup() return FACTION, FACTION end
C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end }

-- sell prices by item ID, and { quality, item level, classID } for weapons and armor
SELL_PRICES = { [3824] = 250, [3829] = 100, [2589] = 13 }
ITEMS = {}
C_Item = {}
UNLOADED, LOAD_REQUESTS = {}, {}   -- items the game hasn't loaded yet
EMPTY_LINKS = {}                   -- items whose scan link comes with an empty name: [...|h[]|h]
function C_Item.RequestLoadItemDataByID(id) LOAD_REQUESTS[#LOAD_REQUESTS + 1] = id end
function C_Item.GetItemInfo(item)
    local id = tonumber(item) or tonumber(tostring(item):match("item:(%d+)"))
    if not id or UNLOADED[id] then return nil end
    local i = ITEMS[id] or { 1, 1, 7 }
    local link = tonumber(item) and ItemLink(id) or tostring(item)
    return "Item " .. id, link, i[1], i[2], 1, "", "", 20, "", 0, SELL_PRICES[id] or 0, i[3]
end
function ItemLink(id, suffix)
    return "|cffffffff|Hitem:" .. id .. ":0:0:0:0:0:" .. (suffix or 0) .. ":0:20:0:0:0:0|h[Item " .. id .. "]|h|r"
end

Enum = { TooltipDataType = { Item = 0 } }
TOOLTIP_CALLS = {}
TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, fn) TOOLTIP_CALLS[#TOOLTIP_CALLS + 1] = { kind, fn } end,
}
-- Shows an item in GameTooltip and returns the lines added after it
function HoverItem(link)
    GameTooltip.__lines = {}
    GameTooltip.__item = link
    for _, c in ipairs(TOOLTIP_CALLS) do c[2](GameTooltip, {}) end
    return GameTooltip.__lines
end
function GameTooltip:GetItem() return self.__item and "Item", self.__item end
function GameTooltip:AddDoubleLine(l, r) table.insert(self.__lines, { l, r }) end
function GameTooltip:AddLine(l) self.__lines = self.__lines or {}; table.insert(self.__lines, { l }) end

---------------------------------------------------------------------------
-- A fake auction house
--   AH.replicate: list of { itemID, count, buyout, suffix }
--   AH.commodities[itemID] = { { unitPrice, quantity }, ... }, AH.full[itemID]
--   AH.items[itemID] = { { buyoutAmount or false, quantity }, ... }
---------------------------------------------------------------------------
AH = { replicate = {}, commodities = {}, items = {}, full = {}, replicateCalls = 0 }
C_AuctionHouse = {}
function C_AuctionHouse.ReplicateItems() AH.replicateCalls = AH.replicateCalls + 1 end
function C_AuctionHouse.GetNumReplicateItems() return #AH.replicate end
-- an item in UNLOADED comes without its name or link, as when the game hasn't loaded it
function C_AuctionHouse.GetReplicateItemInfo(i)
    local r = AH.replicate[i + 1]
    if not r then return nil end
    local loaded = not UNLOADED[r[1]]
    local name = EMPTY_LINKS[r[1]] and "" or loaded and ("Item " .. r[1]) or nil
    return name, 1, r[2], 1, true, 1, "", 0, 0, r[3], 0, nil, nil, nil, nil, 0, r[1], loaded
end
function C_AuctionHouse.GetReplicateItemLink(i)
    local r = AH.replicate[i + 1]
    if r and EMPTY_LINKS[r[1]] then return (ItemLink(r[1], r[4]):gsub("%[.-%]", "[]")) end
    return r and not UNLOADED[r[1]] and ItemLink(r[1], r[4]) or nil
end
function C_AuctionHouse.GetBrowseResults() return AH.browse or {} end
function C_AuctionHouse.GetNumCommoditySearchResults(id) return #(AH.commodities[id] or {}) end
function C_AuctionHouse.GetCommoditySearchResultInfo(id, i)
    local r = (AH.commodities[id] or {})[i]
    return r and { itemID = id, unitPrice = r[1], quantity = r[2], auctionID = i }
end
function C_AuctionHouse.HasFullCommoditySearchResults(id) return AH.full[id] ~= false end
local function itemList(key) return AH.items[key.itemID .. ":" .. (key.itemSuffix or 0)] or {} end
function C_AuctionHouse.GetNumItemSearchResults(key) return #itemList(key) end
function C_AuctionHouse.GetItemSearchResultInfo(key, i)
    local r = itemList(key)[i]
    return r and { itemKey = key, buyoutAmount = r[1] or nil, quantity = r[2], auctionID = i }
end
function C_AuctionHouse.HasFullItemSearchResults(key) return AH.full[key.itemID] ~= false end

SEARCHES = {}
AuctionHouseFrameDisplayMode = { Buy = { "Buy" } }
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
function Methods:IsObjectType(t) return t == "Frame" or t == self.__kind end
function hooksecurefunc(obj, name, fn)
    if type(obj) == "string" then
        local old = _G[obj]
        _G[obj] = function(...) local r = { old(...) } fn(...) return unpack(r) end
        return
    end
    if obj == AuctionHouseFrame and name == "SetDisplayMode" then
        obj.__modeHooks = obj.__modeHooks or {}
        table.insert(obj.__modeHooks, fn)
        return
    end
    local old = obj[name]
    obj[name] = function(...) local r = { old(...) } fn(...) return unpack(r) end
end
function PanelTemplates_TabResize() end
function PanelTemplates_SelectTab(tab) tab.__selected = true end
function PanelTemplates_DeselectTab(tab) tab.__selected = false end
function GameTooltip:SetHyperlink(link) self.__item = link end

-- The game's auction house window (made when it opens, as Blizzard_AuctionHouseUI loads)
function OpenAuctionHouse()
    if not AuctionHouseFrame then
        AuctionHouseFrame = newObj("Frame", "AuctionHouseFrame", UIParent)
        AuctionHouseFrame.SearchBar = newObj("Frame", nil, AuctionHouseFrame)
        AuctionHouseFrame.SearchBar.FilterButton = newObj("Button", nil, AuctionHouseFrame.SearchBar)
        AuctionHouseFrame.SearchBar.SearchButton = newObj("Button", nil, AuctionHouseFrame.SearchBar)
        local bar = AuctionHouseFrame.SearchBar
        function bar:SetSearchText(t) self.__search = t end
        function bar:StartSearch() SEARCHES[#SEARCHES + 1] = self.__search end
        AuctionHouseFrame.Tabs = {}
        for i, label in ipairs({ "Buy", "Sell", "Auctions" }) do
            local tab = newObj("Button", nil, AuctionHouseFrame)
            tab:SetText(label)
            AuctionHouseFrame.Tabs[i] = tab
        end
        function AuctionHouseFrame:SetDisplayMode(mode)
            self.displayMode = mode
            for _, fn in ipairs(self.__modeHooks or {}) do fn(self, mode) end
        end
        function AuctionHouseFrame:SetTitle(t) self.__title = t end
        FireEvent("ADDON_LOADED", "Blizzard_AuctionHouseUI")
    end
    AuctionHouseFrame:Show()
    FireEvent("AUCTION_HOUSE_SHOW")
end
function CloseAuctionHouse()
    AuctionHouseFrame:Hide()
    FireEvent("AUCTION_HOUSE_CLOSED")
end

-- Ticks until the background jobs are done (returns how many frames it took)
function RunJobs(limit)
    local frames = 0
    local ahf = AuctionHouseForever
    repeat
        Tick(0.05)
        frames = frames + 1
        assert(frames < (limit or 10000), "jobs never finished")
    until not ahf:JobRunning("full scan") and not ahf:JobRunning("condense")
    return frames
end

---------------------------------------------------------------------------
-- Chat channels and addon messages
---------------------------------------------------------------------------
PLAYER = "Tyler"
function UnitName() return PLAYER end
-- as the game: "none" keeps the realm, "short" drops it
function Ambiguate(name, mode) return mode == "none" and name or (name:gsub("%-.*$", "")) end
CHANNELS, SENT, PREFIXES, CHAT_FILTERS, REMOVED = {}, {}, {}, {}, {}
SEND_RESULTS = {}            -- results to give the next sends (default 0, success)
LOCKDOWN = false
NUM_CHAT_WINDOWS = 2
function GetChannelName(name) return CHANNELS[name] or 0, CHANNELS[name] and name or nil end
function JoinTemporaryChannel(name) CHANNELS[name] = CHANNELS[name] or 5 end
function LeaveChannelByName(name) CHANNELS[name] = nil end
for i = 1, 2 do
    local f = newObj("ScrollingMessageFrame", "ChatFrame" .. i)
    function f:RemoveChannel(name) REMOVED[#REMOVED + 1] = { i, name } end
end
function ChatFrame_AddMessageEventFilter(event, fn)
    CHAT_FILTERS[event] = CHAT_FILTERS[event] or {}
    table.insert(CHAT_FILTERS[event], fn)
end
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) PREFIXES[p] = true return 0 end,
    InChatMessagingLockdown = function() return LOCKDOWN end,
    SendAddonMessage = function(prefix, msg, chatType, target)
        assert(#msg <= 255, "message too long: " .. #msg)
        local r = table.remove(SEND_RESULTS, 1) or 0
        if r == 0 then SENT[#SENT + 1] = { prefix = prefix, msg = msg, chatType = chatType, target = target } end
        return r
    end,
}

-- Moves the clock on, a frame at a time
function Wait(seconds, step)
    step = step or 0.25
    local done = 0
    while done < seconds do
        FAKE_TIME = FAKE_TIME + step
        Tick(step)
        done = done + step
    end
end

ADDON_FILES = { "Libs/LibStub/LibStub.lua", "Libs/LibAHTab/LibAHTab.lua", "Theme.lua", "Prices.lua", "Core.lua", "Disenchant.lua", "Scan.lua", "Share.lua", "Resale.lua", "News.lua", "Options.lua" }

-- Loads the addon's files in .toc order, then the game's start-up events
strmatch = string.match
function LoadAddon(dir)
    LibStub = nil   -- a fresh game: the bundled libraries load again
    local ns = {}
    for _, f in ipairs(ADDON_FILES) do
        local chunk = assert(loadfile((dir or ".") .. "/" .. f))
        chunk("AuctionHouseForever", ns)
    end
    FireEvent("ADDON_LOADED", "AuctionHouseForever")
    FireEvent("PLAYER_LOGIN")
    return ns
end
