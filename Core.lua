-- AuctionHouse Forever
-- Makes the Auction House (Blizzard_AuctionHouseUI) resizable, movable and
-- scalable, with draggable column widths and a wider category list, for
-- World of Warcraft: Forever (interface 16001).
-- Only layout, size and styling: tabs, columns and buttons from Blizzard or other
-- addons (Auctionator, price columns) are left in place, and nothing is ever
-- bought, bid on or posted for you.

local ADDON, ns = ...
local AHF = {}
ns.AHF = AHF

local function Print(msg) print(ns.Theme.CHAT_PREFIX .. ": " .. msg) end
AHF.Print = Print

AHF.AH_ADDON = "Blizzard_AuctionHouseUI"

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
-- Blizzard's own size of the Auction House (Blizzard_AuctionHouseFrame.xml)
AHF.BLIZZARD_WIDTH, AHF.BLIZZARD_HEIGHT = 800, 538
-- Blizzard's own width of the category list (AuctionHouseCategoriesListTemplate)
AHF.BLIZZARD_SIDEBAR = 168

AHF.SCHEMA = 1

-- Account-wide settings. point: nil = where Blizzard puts the window, or
-- { point, relativePoint, x, y } on UIParent once it has been dragged.
AHF.DEFAULTS = {
    width = 1000,          -- 200 more than Blizzard's, all of it for the Name column
    height = 620,
    scale = 1,
    locked = false,
    sidebarWidth = AHF.BLIZZARD_SIDEBAR,
    rowFontSize = 0,       -- text size in the lists' rows; 0 = the game's own
    showSplash = true,
    lastSeenVersion = "",
}

-- Allowed range of every number setting
AHF.LIMITS = {
    width = { AHF.BLIZZARD_WIDTH, 1600 },
    height = { AHF.BLIZZARD_HEIGHT, 1100 },
    scale = { 0.6, 1.5 },
    sidebarWidth = { AHF.BLIZZARD_SIDEBAR, 320 },
    rowFontSize = { 0, 16 },
    column = { 30, 400 },   -- a column dragged by its divider
}
AHF.NAME_MIN = 150          -- the Name column never gets narrower than this
AHF.ROW_FONT_SIZES = { 0, 11, 12, 13, 14, 15, 16 }   -- the row text size choices (0 = Default)
AHF.ROW_HEIGHT = 20   -- Blizzard's row height; rows grow with bigger text (RowHeight)

local function Clamp(v, range)
    if v < range[1] then return range[1] end
    if v > range[2] then return range[2] end
    return v
end
AHF.Clamp = Clamp

-- A ScrollBox's rows can only be walked once Blizzard has given it a view
-- (a list that has never been shown has none, and ForEachFrame errors)
function AHF.HasRows(box)
    return type(box) == "table" and box.ForEachFrame ~= nil
        and (box.GetView == nil or box:GetView() ~= nil)
end

local function ValidPoint(p)
    return type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string"
        and type(p[3]) == "number" and type(p[4]) == "number"
end

-- Fills in missing or damaged settings and brings numbers inside their limits
local function PrepareSettings(db)
    for k, v in pairs(AHF.DEFAULTS) do
        if type(db[k]) ~= type(v) then db[k] = v end
    end
    for k, range in pairs(AHF.LIMITS) do
        if type(db[k]) == "number" then db[k] = Clamp(db[k], range) end
    end
    if db.point ~= nil and not ValidPoint(db.point) then db.point = nil end
    local sizeOk = false
    for _, v in ipairs(AHF.ROW_FONT_SIZES) do if v == db.rowFontSize then sizeOk = true end end
    if not sizeOk then db.rowFontSize = 0 end
    db.schema = AHF.SCHEMA
    return db
end
AHF.PrepareSettings = PrepareSettings

-- Per character: columns, per list. Each list keeps
--   widths = { [column name] = width }
--   hidden = { [column name] = true / false }   (nil: the column's default)
--   order  = { column name, ... }   (the named columns, left to right)
local function PrepareCharSettings(db)
    if type(db.columns) ~= "table" then db.columns = {} end
    for key, state in pairs(db.columns) do
        if type(state) ~= "table" then
            db.columns[key] = nil
        else
            if type(state.widths) ~= "table" then state.widths = {} end
            if type(state.hidden) ~= "table" then state.hidden = {} end
            if type(state.order) ~= "table" then state.order = {} end
            for name, w in pairs(state.widths) do
                if type(w) ~= "number" then state.widths[name] = nil
                else state.widths[name] = Clamp(w, AHF.LIMITS.column) end
            end
            for name, v in pairs(state.hidden) do
                if type(v) ~= "boolean" or type(name) ~= "string" then state.hidden[name] = nil end
            end
            local order = {}
            for _, name in ipairs(state.order) do
                if type(name) == "string" then order[#order + 1] = name end
            end
            state.order = order
        end
    end
    db.schema = AHF.SCHEMA
    return db
end
AHF.PrepareCharSettings = PrepareCharSettings

-- The saved state of one list's columns (made on first use)
function AHF:ColumnState(listKey)
    local all = self.charDB.columns
    local state = all[listKey]
    if not state then
        state = { widths = {}, hidden = {}, order = {} }
        all[listKey] = state
    end
    return state
end

function AHF:Version()
    local v = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    if type(v) ~= "string" or v:find("@") then return nil end
    return (v:gsub("^v", ""))
end

-- Repaints the open settings window when something changes elsewhere
function AHF:RefreshOptions()
    if self.optionsRefresh then self.optionsRefresh() end
end

-- Size, position and scale back to the defaults (the window goes back to
-- where Blizzard puts it)
function AHF:ResetWindow()
    local db = self.db
    db.width, db.height, db.scale = self.DEFAULTS.width, self.DEFAULTS.height, self.DEFAULTS.scale
    self:ResetPosition()
end

-- Every setting back to its default, columns included
function AHF:ResetAll()
    local db = self.db
    for k, v in pairs(self.DEFAULTS) do
        if k ~= "showSplash" and k ~= "lastSeenVersion" then db[k] = v end
    end
    self:ResetPosition()
    self:ResetColumns()
    self:ApplyRowFonts()
end

---------------------------------------------------------------------------
-- The Auction House is load-on-demand: set it up when it loads
---------------------------------------------------------------------------
local function AuctionHouseLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(AHF.AH_ADDON) end
    return IsAddOnLoaded and IsAddOnLoaded(AHF.AH_ADDON)
end

function AHF:OnAuctionHouseLoaded()
    if self.frame or not self.db then return end
    local f = _G.AuctionHouseFrame
    if not f then return end
    self.frame = f
    self:SetupLayout(f)
    self:SetupColumns(f)
    self:SetupColumnsButton(f)
    self:StretchBackgrounds()
    self:ApplyLayout()
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
AHF.COMMANDS = {
    { "/ahf", "open or close the settings" },
    { "/ahf lock · /ahf unlock", "lock or unlock the window's position" },
    { "/ahf reset", "size, position and scale back to the defaults" },
    { "/ahf columns", "every column shown, default order and widths" },
    { "/ahf news", "show the welcome / what's new window" },
}

local function Help()
    Print("commands:")
    for _, c in ipairs(AHF.COMMANDS) do Print(c[1] .. " — " .. c[2]) end
end

SLASH_AUCTIONHOUSEFOREVER1 = "/ahf"
SLASH_AUCTIONHOUSEFOREVER2 = "/auctionhouseforever"
SlashCmdList.AUCTIONHOUSEFOREVER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if not AHF.db then Print("not ready yet.") return end
    if msg == "" or msg == "config" or msg == "options" then
        AHF:ToggleConfig()
    elseif msg == "lock" or msg == "unlock" then
        AHF:SetLocked(msg == "lock")
        Print(msg == "lock" and "window locked." or "window unlocked: drag its title bar to move it.")
    elseif msg == "reset" then
        AHF:ResetWindow()
        Print("window size, position and scale reset.")
    elseif msg == "columns" then
        AHF:ResetColumns()
        Print("columns reset: all shown, default order and widths.")
    elseif msg == "news" then
        AHF:ToggleSplash()
    else
        Help()
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            if type(AuctionHouseForeverDB) ~= "table" then AuctionHouseForeverDB = {} end
            if type(AuctionHouseForeverCharDB) ~= "table" then AuctionHouseForeverCharDB = {} end
            AHF.db = PrepareSettings(AuctionHouseForeverDB)
            AHF.charDB = PrepareCharSettings(AuctionHouseForeverCharDB)
            -- Another addon (Auctionator) may have loaded the Auction House first
            if AuctionHouseLoaded() then AHF:OnAuctionHouseLoaded() end
        elseif arg1 == AHF.AH_ADDON then
            AHF:OnAuctionHouseLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        if AuctionHouseLoaded() then AHF:OnAuctionHouseLoaded() end
        AHF:RegisterSettingsCategory()
        AHF:MaybeShowSplash()
    end
end)
