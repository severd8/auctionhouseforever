-- AuctionHouse Forever: start-up, saved data, background jobs, tooltips and /ahf.

local ADDON, ns = ...
local T, P = ns.Theme, ns.Prices
local AHF = {}
ns.AHF = AHF
_G.AuctionHouseForever = AHF

AHF.DEFAULTS = {
    tooltip = true,          -- show AHF prices in item tooltips
    scanChat = true,         -- say in chat when a full scan finishes
    cooldown = 0,            -- minutes to wait between full scans (0: none; Forever allowed one straight after another in testing)
}

AHF.BUDGET = 8               -- milliseconds of work per frame for background jobs

---------------------------------------------------------------------------
-- Chat and money
---------------------------------------------------------------------------
function AHF:Print(msg) print(T.CHAT_PREFIX .. ": " .. msg) end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- 26061 -> "2g 60s 61c" with the coin icons (plain letters with plain = true)
function AHF.Money(copper, plain)
    copper = math.floor((copper or 0) + 0.5)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local gi, si, ci = GOLD_ICON, SILVER_ICON, COPPER_ICON
    if plain then gi, si, ci = "g", "s", "c" end
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. gi end
    if s > 0 then parts[#parts + 1] = s .. si end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. ci end
    return table.concat(parts, " ")
end

-- 90 -> "1 min", 7200 -> "2 h", 200000 -> "2 days"
function AHF.Age(seconds)
    seconds = math.max(0, seconds or 0)
    if seconds < 60 then return "just now" end
    if seconds < 3600 then return math.floor(seconds / 60) .. " min" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. " h" end
    local d = math.floor(seconds / 86400)
    return d .. (d == 1 and " day" or " days")
end

-- 754 -> "12:34"
function AHF.Clock(seconds)
    seconds = math.max(0, math.ceil(seconds or 0))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function AHF.Now() return GetServerTime and GetServerTime() or time() end

function AHF:Version()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local v = get and get(ADDON, "Version")
    if not v or v:find("@") then return nil end
    return (v:gsub("^v", ""))
end

---------------------------------------------------------------------------
-- Saved data
--   AuctionHouseForeverData = { v = 1, realms = { ["Realm-Faction"] = {
--       items = { [itemKey] = encoded string (or the decoded list while in use) },
--       lastFull = time of the last full scan, scans = { recent full scans } } } }
--   AuctionHouseForeverSettings = settings, shared by every character
-- Item keys: "itemID", or "itemID:suffix" for items with a random suffix.
---------------------------------------------------------------------------
function AHF:LoadSaved()
    local data = AuctionHouseForeverData
    if type(data) ~= "table" or data.v ~= 1 then data = { v = 1, realms = {} } end
    if type(data.realms) ~= "table" then data.realms = {} end
    AuctionHouseForeverData = data
    self.data = data

    local s = AuctionHouseForeverSettings
    if type(s) ~= "table" then s = {} end
    for k, v in pairs(self.DEFAULTS) do
        if type(s[k]) ~= type(v) then s[k] = v end
    end
    s.cooldown = math.max(0, math.min(60, s.cooldown))
    AuctionHouseForeverSettings = s
    self.db = s
end

-- The auction house you use: realm and faction, since Forever's aren't shared
function AHF:RealmKey()
    local realm = GetRealmName and GetRealmName() or "?"
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "?"
    return realm .. "-" .. (faction or "?")
end

function AHF:Realm(key)
    key = key or self:RealmKey()
    local r = self.data.realms[key]
    if type(r) ~= "table" then
        r = { items = {}, scans = {}, lastFull = 0 }
        self.data.realms[key] = r
    end
    r.items = type(r.items) == "table" and r.items or {}
    r.scans = type(r.scans) == "table" and r.scans or {}
    r.lastFull = tonumber(r.lastFull) or 0
    return r
end

-- An item's records, decoded on first use; nil when there are none (unless create)
function AHF:Records(itemKey, create, realm)
    realm = realm or self:Realm()
    local v = realm.items[itemKey]
    if type(v) == "string" then
        v = P.Decode(v)
        realm.items[itemKey] = v
    elseif type(v) ~= "table" then
        if not create then return nil end
        v = {}
        realm.items[itemKey] = v
    end
    return v
end

function AHF:Observe(itemKey, obs, realm)
    local recs = self:Records(itemKey, true, realm)
    return P.Add(recs, obs)
end

-- Turns the decoded lists back into strings (at logout, before the game saves)
function AHF:Pack()
    for _, realm in pairs(self.data.realms) do
        for key, v in pairs(realm.items) do
            if type(v) == "table" then
                realm.items[key] = #v > 0 and P.Encode(v) or nil
            end
        end
    end
end

-- How much is stored: items, records and roughly how many bytes
function AHF:Stats(realm)
    realm = realm or self:Realm()
    local items, recs, bytes = 0, 0, 0
    for key, v in pairs(realm.items) do
        local str = type(v) == "table" and P.Encode(v) or v
        if type(str) == "string" and #str > 0 then
            items = items + 1
            bytes = bytes + #str + #key + 8
            local _, semis = str:gsub(";", "")
            recs = recs + semis + 1
        end
    end
    return items, recs, bytes
end

---------------------------------------------------------------------------
-- Item keys
---------------------------------------------------------------------------
function AHF.KeyFor(itemID, suffix)
    if not itemID then return nil end
    suffix = tonumber(suffix) or 0
    if suffix ~= 0 then return itemID .. ":" .. suffix end
    return tostring(itemID)
end

-- From an item link: the item's ID and its random suffix (the 8th field of item:...)
function AHF.KeyFromLink(link)
    if type(link) ~= "string" then return nil end
    local str = link:match("item:([%-%d:]+)")
    if not str then return nil end
    local f, i = {}, 0
    for part in (str .. ":"):gmatch("([^:]*):") do
        i = i + 1
        f[i] = part
    end
    local id = tonumber(f[1])
    if not id then return nil end
    return AHF.KeyFor(id, f[7]), id
end

---------------------------------------------------------------------------
-- Background jobs: big work runs a slice each frame so the game never stalls
---------------------------------------------------------------------------
local jobs = {}
local jobFrame = CreateFrame("Frame")
jobFrame:Hide()
local sliceStart

-- Call inside a job now and then: hands back to the game when the frame's time is used
function AHF:Pause()
    if sliceStart and debugprofilestop() - sliceStart > self.BUDGET then
        coroutine.yield()
    end
end

function AHF:RunJob(name, fn, done)
    jobs[#jobs + 1] = { name = name, co = coroutine.create(fn), done = done }
    jobFrame:Show()
end

function AHF:JobRunning(name)
    for _, j in ipairs(jobs) do if j.name == name then return true end end
    return false
end

jobFrame:SetScript("OnUpdate", function(self)
    local job = jobs[1]
    if not job then self:Hide() return end
    sliceStart = debugprofilestop()
    local ok, err = coroutine.resume(job.co)
    sliceStart = nil
    if not ok then
        table.remove(jobs, 1)
        AHF:Print("|cffff6060something went wrong (" .. job.name .. "): " .. tostring(err) .. "|r")
    elseif coroutine.status(job.co) == "dead" then
        table.remove(jobs, 1)
        if job.done then job.done() end
    end
    if not jobs[1] then self:Hide() end
end)

---------------------------------------------------------------------------
-- Tidying old data: days older than two weeks become weeks (once a day)
---------------------------------------------------------------------------
function AHF:CondenseAll(force)
    local today = P.Day(self.Now())
    if not force and self.data.condensed == today then return end
    self:RunJob("condense", function()
        for _, realm in pairs(self.data.realms) do
            local keys = {}
            for key in pairs(realm.items) do keys[#keys + 1] = key end
            for _, key in ipairs(keys) do
                local v = realm.items[key]
                local recs = type(v) == "string" and P.Decode(v) or v
                if type(recs) == "table" then
                    local out, changed = P.Condense(recs, today)
                    if #out == 0 then
                        realm.items[key] = nil
                    elseif changed then
                        realm.items[key] = type(v) == "string" and P.Encode(out) or out
                    end
                end
                self:Pause()
            end
        end
        self.data.condensed = today
    end)
end

---------------------------------------------------------------------------
-- Tooltips: AHF lines under an item
---------------------------------------------------------------------------
-- "AHF Vendor" (what a vendor pays) and "AHF Market (seen N)" (the market value,
-- or the lowest price when that's all there is; N = how many were listed in the
-- newest data), each for one item; and "AHF Disenchant" for items that can be
-- disenchanted (with "~" when a material has no AHF price yet)
function AHF.VendorPrice(link)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not get or not link then return nil end
    local sell = select(11, get(link))
    return type(sell) == "number" and sell > 0 and sell or nil
end

function AHF:MarketPrice(itemKey, itemID)
    local recs = self:Records(itemKey) or (itemID and self:Records(tostring(itemID)))
    if not recs or #recs == 0 then return nil end
    local last = recs[#recs]
    return last.v > 0 and last.v or last.m, last
end

-- "AHF seen in N scans over D days:" and the 14, 7 and 3 day averages (market
-- value, or the lowest price on days without one, weighted by scans)
AHF.AVERAGE_DAYS = { 14, 7, 3 }

function AHF:HistoryLines(key, id)
    local recs = self:Records(key) or (id and self:Records(tostring(id)))
    if not recs or #recs == 0 then return nil end
    local P = ns.Prices
    local today = P.Day(self.Now())
    local scans = 0
    for _, r in ipairs(recs) do scans = scans + math.max(r.n, 1) end
    local days = today - recs[1].d + 1
    local lines = {}
    for _, d in ipairs(self.AVERAGE_DAYS) do
        local avg = P.Average(recs, d, today)
        if avg then lines[#lines + 1] = { "  " .. d .. " day average", self.Money(avg) } end
    end
    if #lines == 0 then return nil end
    table.insert(lines, 1, { string.format("AHF seen in %d scan%s over %d day%s:", scans, scans == 1 and "" or "s",
        days, days == 1 and "" or "s"), "" })
    return lines
end

function AHF:TooltipLines(link)
    local key, id = self.KeyFromLink(link)
    if not key then return nil end
    local lines = {}
    local vendor = self.VendorPrice(link)
    if vendor then lines[#lines + 1] = { "AHF Vendor", self.Money(vendor) } end
    local market, last = self:MarketPrice(key, id)
    if market then lines[#lines + 1] = { "AHF Market (seen " .. (last.q or 0) .. ")", self.Money(market) } end
    local history = self:HistoryLines(key, id)
    for _, l in ipairs(history or {}) do lines[#lines + 1] = l end
    local de, guessed
    if self.DisenchantValue then de, guessed = self:DisenchantValue(link) end
    if de and de > 0 then lines[#lines + 1] = { "AHF Disenchant", (guessed and "~" or "") .. self.Money(de) } end
    return #lines > 0 and lines or nil
end

function AHF:AddToTooltip(tooltip)
    if not self.db or not self.db.tooltip or not tooltip or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    local lines = self:TooltipLines(link)
    if not lines then return end
    for _, l in ipairs(lines) do
        tooltip:AddDoubleLine(l[1], l[2], 0.91, 0.63, 0.25, 1, 1, 1)
    end
    tooltip:Show()
end

function AHF:HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            AHF:AddToTooltip(tooltip)
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip) AHF:AddToTooltip(tooltip) end)
    end
end

---------------------------------------------------------------------------
-- /ahf
---------------------------------------------------------------------------
function AHF:Slash(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "scan" then
        self:StartFullScan()
    elseif msg == "tooltip" then
        self.db.tooltip = not self.db.tooltip
        self:Print("prices in tooltips " .. (self.db.tooltip and "on" or "off") .. ".")
        if self.RefreshWindow then self:RefreshWindow() end
    elseif msg == "help" then
        self:Print("/ahf opens the window, /ahf scan starts a full scan (at the auction house), /ahf tooltip turns the tooltip prices on or off.")
    else
        if self.ToggleWindow then self:ToggleWindow() end
    end
end

SLASH_AUCTIONHOUSEFOREVER1 = "/ahf"
SlashCmdList.AUCTIONHOUSEFOREVER = function(msg) AHF:Slash(msg) end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
AHF.eventFrame = events
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
AHF.handlers = {}

function AHF:On(event, fn)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], fn)
    events:RegisterEvent(event)
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON then
        AHF:LoadSaved()
    elseif event == "PLAYER_LOGIN" then
        AHF:HookTooltips()
        AHF:CondenseAll()
    elseif event == "PLAYER_LOGOUT" then
        AHF:Pack()
    end
    for _, fn in ipairs(AHF.handlers[event] or {}) do fn(...) end
end)
