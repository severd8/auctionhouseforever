-- AuctionHouse Forever: sharing full scans with other players who have the
-- addon, over a hidden chat channel, so everyone gets fresh prices without
-- scanning.
--
-- How it goes (all on the channel, everyone with the addon hears it):
--   H  "I have the scan <by> made at <t>"   after a full scan, or to answer Q
--   Q  "my newest scan is from <t>"          after joining (at login)
--   R  "<holder>, please send that scan"     from one player who's behind
--   D  one piece of the scan                 the holder sends every piece once;
--                                            everyone who's behind keeps them
-- A random short wait before answering lets one player answer for everyone.

local _, ns = ...
local P, AHF = ns.Prices, ns.AHF
local S = {}
ns.Share = S
AHF.Share = S

S.PREFIX = "AHF1"          -- a new number if the format ever changes
S.CHANNEL = "AHFPrices"
S.MAX_MSG = 250            -- the game allows 255 characters per message
S.JOIN_DELAY = 20          -- seconds after login, so General and Trade keep their numbers
S.BURST = 5                -- messages that can go at once ...
S.GAP = 1.1                -- ... then one every this many seconds (the game allows about one a second)
S.RETRY = 3                -- seconds to wait after the game says too many messages
S.MAX_AGE = 2 * 86400      -- scans older than this aren't shared or taken
S.SAME_SCAN = 600          -- a scan this close to one we have adds nothing
S.TRUST = 10               -- a shared price over 10x away from ours is ignored
S.IDLE = 60                -- a scan with no new piece for this long is finished (some may be lost)

local b36 = P.ToBase36
local function n36(s) return type(s) == "string" and s ~= "" and P.FromBase36(s) or nil end

---------------------------------------------------------------------------
-- The data: "id:min:market:qty" per item (base 36; "id_suffix" for suffixed
-- items; market left empty when there's none), joined by ";" into pieces
---------------------------------------------------------------------------
function S.EncodeItem(key, min, market, qty)
    local id, suffix = key:match("^(%-?%d+):(%-?%d+)$")
    local k = id and (b36(tonumber(id)) .. "_" .. b36(tonumber(suffix))) or b36(tonumber(key) or 0)
    return k .. ":" .. b36(min) .. ":" .. (market and market > 0 and b36(market) or "") .. ":" .. b36(qty or 0)
end

function S.DecodeItem(str)
    local k, min, market, qty = str:match("^([%w_%-]+):([%w%-]+):([%w%-]*):([%w%-]+)$")
    if not k then return nil end
    local id, suffix = k:match("^([%w%-]+)_([%w%-]+)$")
    local key
    if id then
        key = AHF.KeyFor(n36(id), n36(suffix))
    else
        key = tostring(n36(k) or "")
    end
    min, market, qty = n36(min), market ~= "" and n36(market) or nil, n36(qty)
    if not key or key == "" or not min or min <= 0 or not qty or qty < 0 then return nil end
    if market and market <= 0 then market = nil end
    return key, min, market, qty
end

-- Splits the items into pieces of at most room characters
function S.Pieces(items, room)
    local pieces, cur, len = {}, {}, 0
    for _, it in ipairs(items) do
        local s = S.EncodeItem(it[1], it[2], it[3], it[4])
        if len > 0 and len + 1 + #s > room then
            pieces[#pieces + 1] = table.concat(cur, ";")
            cur, len = {}, 0
        end
        cur[#cur + 1] = s
        len = len + (len > 0 and 1 or 0) + #s
    end
    if len > 0 then pieces[#pieces + 1] = table.concat(cur, ";") end
    return pieces
end

function S.ReadPiece(piece)
    local out = {}
    for part in (piece or ""):gmatch("[^;]+") do
        local key, min, market, qty = S.DecodeItem(part)
        if key then out[#out + 1] = { key, min, market, qty } end
    end
    return out
end

-- Room for a piece's data once the D header is in front
local function Room(t, by, n)
    return S.MAX_MSG - #("D,A," .. b36(t) .. "," .. by .. "," .. b36(n) .. "," .. b36(n) .. ",")
end

---------------------------------------------------------------------------
-- Who we are, and who sent what
---------------------------------------------------------------------------
local function Me()
    return UnitName and UnitName("player") or "?"
end

local function Short(name)
    if Ambiguate then return Ambiguate(name or "", "none") end
    return ((name or ""):gsub("%-.*$", ""))
end

local function Faction()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f and f:sub(1, 1) or "?"
end

function S:On() return AHF.db and AHF.db.share and true or false end

-- The newest scan we hold for sharing (ours, or one we got whole from someone)
function S:Held()
    local h = AHF:Realm().share
    if type(h) == "table" and type(h.pieces) == "table" and #h.pieces > 0 and h.t and h.by then return h end
    return nil
end

function S:NewestTime()
    local h = self:Held()
    local t = h and h.t or 0
    return math.max(t, AHF:Realm().lastGood or 0)
end

---------------------------------------------------------------------------
-- Timers and the send queue (paced to stay under the game's limits)
---------------------------------------------------------------------------
S.timers, S.queue = {}, {}
S.tokens, S.wait = S.BURST, 0
local ticker = CreateFrame("Frame")
S.ticker = ticker

function S:After(seconds, fn, tag)
    local t = { at = GetTime() + seconds, fn = fn, tag = tag }
    self.timers[#self.timers + 1] = t
    return t
end

function S:Cancel(tag)
    for i = #self.timers, 1, -1 do
        if self.timers[i].tag == tag then table.remove(self.timers, i) end
    end
end

function S:Pending(tag)
    for _, t in ipairs(self.timers) do if t.tag == tag then return true end end
    return false
end

-- Control messages go before the pieces of a scan
function S:Send(msg, first)
    if first then
        local pos = 1
        while self.queue[pos] and self.queue[pos].first do pos = pos + 1 end
        table.insert(self.queue, pos, { msg = msg, first = true })
    else
        self.queue[#self.queue + 1] = { msg = msg }
    end
end

local THROTTLED = { [3] = true, [8] = true }   -- AddonMessageThrottle, ChannelThrottle
local LOCKDOWN = 11                            -- AddOnMessageLockdown

function S:SendNext(now)
    local item = self.queue[1]
    if not item or now < self.wait or self.tokens < 1 then return end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        self.wait = now + 5
        return
    end
    local id = GetChannelName(self.CHANNEL)
    if not id or id == 0 then
        self.wait = now + 5
        return
    end
    local result = C_ChatInfo.SendAddonMessage(self.PREFIX, item.msg, "CHANNEL", id)
    if type(result) == "number" and THROTTLED[result] then
        self.wait = now + self.RETRY
    elseif result == LOCKDOWN then
        self.wait = now + 5
    else
        table.remove(self.queue, 1)
        self.tokens = self.tokens - 1
        self.sent = (self.sent or 0) + 1
    end
end

ticker:SetScript("OnUpdate", function(_, dt)
    local now = GetTime()
    S.tokens = math.min(S.BURST, S.tokens + (dt or 0) / S.GAP)
    for i = #S.timers, 1, -1 do
        local t = S.timers[i]
        if t and now >= t.at then
            table.remove(S.timers, i)
            t.fn()
        end
    end
    S:SendNext(now)
    S:CheckIdle(now)
end)

---------------------------------------------------------------------------
-- The channel
---------------------------------------------------------------------------
local function OurChannel(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" and v:lower():find(S.CHANNEL:lower(), 1, true) then return true end
    end
    return false
end

-- Keeps it out of every chat window, and its join and leave notices out of chat
function S:Hide()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f then
            if f.RemoveChannel then
                f:RemoveChannel(self.CHANNEL)
            elseif ChatFrame_RemoveChannel then
                ChatFrame_RemoveChannel(f, self.CHANNEL)
            end
        end
    end
    if not self.filtered then
        local add = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
        if add then
            local function filter(_, _, ...) return OurChannel(...) end
            add("CHAT_MSG_CHANNEL_NOTICE", filter)
            add("CHAT_MSG_CHANNEL_NOTICE_USER", filter)
            add("CHAT_MSG_CHANNEL", filter)
            self.filtered = true
        end
    end
end

function S:Join()
    if not self:On() then return end
    self:Hide()
    local id = GetChannelName(self.CHANNEL)
    if not id or id == 0 then
        local join = JoinTemporaryChannel or JoinChannelByName
        if not join then return end
        join(self.CHANNEL)
    end
    self:Hide()
    self:After(1, function() S:Hide() end)
    self.joined = true
    -- ask whether anyone has newer prices than ours
    self:After(3, function() S:Ask() end)
end

function S:Leave()
    self.queue = {}
    self.sending = nil
    if self.joined and LeaveChannelByName then LeaveChannelByName(self.CHANNEL) end
    self.joined = false
end

function S:SetOn(on)
    AHF.db.share = on and true or false
    if on then self:Join() else self:Leave() end
end

---------------------------------------------------------------------------
-- Our own scans
---------------------------------------------------------------------------
-- items: { { key, min, market, qty }, ... } from a full scan at time t
function S:OwnScan(t, items)
    if #items == 0 then return end
    local by = Me()
    local pieces = self.Pieces(items, Room(t, by, 9999))
    AHF:Realm().share = { t = t, by = by, pieces = pieces, items = #items }
    self:Announce()
end

function S:Announce()
    local h = self:Held()
    if not h or not self:On() or not self.joined then return end
    if AHF.Now() - h.t > self.MAX_AGE then return end
    self:Send(table.concat({ "H", Faction(), b36(h.t), h.by, b36(#h.pieces) }, ","), true)
end

function S:Ask()
    if not self:On() then return end
    self:Send(table.concat({ "Q", Faction(), b36(self:NewestTime()) }, ","), true)
end

-- Every piece of the scan we hold, once (unless it's going out already)
function S:SendHeld()
    local h = self:Held()
    if not h or self.sending == h.t .. h.by then return end
    self.sending = h.t .. h.by
    local n = #h.pieces
    for i, piece in ipairs(h.pieces) do
        self:Send(table.concat({ "D", Faction(), b36(h.t), h.by, b36(i), b36(n), piece }, ","))
    end
    self:Send("E," .. Faction() .. "," .. b36(h.t) .. "," .. h.by)
end

---------------------------------------------------------------------------
-- Scans from others
---------------------------------------------------------------------------
S.incoming = {}
S.requested = {}

-- Whether a scan made at t is worth taking
function S:Wanted(t, by)
    local now = AHF.Now()
    if not t or t > now + 300 or now - t > self.MAX_AGE then return false end
    for _, s in ipairs(AHF:Realm().shared) do
        if s.t == t and s.by == by then return false end
    end
    local newest = self:NewestTime()
    return t > newest + self.SAME_SCAN
end

-- A shared price far from what we already know is left out
function S:Trusted(key, market, min)
    local ours = AHF:MarketPrice(key)
    if not ours or ours <= 0 then return true end
    local theirs = market or min
    return theirs <= ours * self.TRUST and theirs * self.TRUST >= ours
end

function S:TakePiece(t, by, i, n, piece)
    local id = t .. by
    local inc = self.incoming[id]
    if not inc then
        if not self:Wanted(t, by) then return end
        inc = { t = t, by = by, n = n, got = {}, count = 0, items = 0, skipped = 0, pieces = {} }
        self.incoming[id] = inc
        self:Cancel("R" .. id)
    end
    if inc.done or inc.got[i] or i < 1 or i > inc.n then return end
    inc.got[i], inc.count, inc.last = true, inc.count + 1, GetTime()
    inc.pieces[i] = piece
    local realm = AHF:Realm()
    for _, it in ipairs(self.ReadPiece(piece)) do
        local key, min, market, qty = it[1], it[2], it[3], it[4]
        if self:Trusted(key, market, min) then
            AHF:Observe(key, { min = min, market = market, qty = qty, t = t, full = true }, realm)
            inc.items = inc.items + 1
        else
            inc.skipped = inc.skipped + 1
        end
    end
    if inc.count == inc.n then self:Finish(inc) end
end

function S:Finish(inc)
    if inc.done then return end
    inc.done = true
    local realm = AHF:Realm()
    if inc.count == inc.n then
        -- whole: we can pass it on to the next player who asks
        realm.share = { t = inc.t, by = inc.by, pieces = inc.pieces, items = inc.items + inc.skipped }
    end
    inc.pieces = nil
    table.insert(realm.shared, 1, { t = inc.t, by = inc.by, items = inc.items, skipped = inc.skipped,
        whole = inc.count == inc.n, got = AHF.Now() })
    while #realm.shared > 10 do table.remove(realm.shared) end
    if AHF.db.scanChat then
        AHF:Print(string.format("prices for %d items from %s's scan (%s old)%s.", inc.items, inc.by,
            AHF.Age(AHF.Now() - inc.t), inc.skipped > 0 and (", " .. inc.skipped .. " far from yours left out") or ""))
    end
    if AHF.RefreshWindow then AHF:RefreshWindow() end
end

function S:CheckIdle(now)
    for id, inc in pairs(self.incoming) do
        if not inc.done and inc.last and now - inc.last > self.IDLE then self:Finish(inc) end
        if inc.done and inc.last and now - inc.last > self.IDLE * 10 then self.incoming[id] = nil end
    end
end

S.heard, S.heardFrom = 0, {}

function S:Receive(text, sender)
    if not self:On() then return end
    local who = Short(sender)
    if who == Me() then return end
    local kind, fac, rest = text:match("^(%u),(%a),(.*)$")
    if not kind then return end
    self.heard = self.heard + 1
    self.heardFrom[who] = fac
    if fac ~= Faction() then return end
    if kind == "Q" then
        local theirs = n36(rest) or 0
        local h = self:Held()
        if h and h.t > theirs + self.SAME_SCAN and AHF.Now() - h.t <= self.MAX_AGE then
            self:After(1 + math.random() * 3, function() S:Announce() end, "H" .. h.t .. h.by)
        end
    elseif kind == "H" then
        local t, by = rest:match("^([%w]+),([^,]+),")
        t = n36(t)
        if not t then return end
        local h = self:Held()   -- someone answered with this scan or a newer one: no need to
        if h and h.t <= t then self:Cancel("H" .. h.t .. h.by) end
        local id = t .. by
        if self:Wanted(t, by) and not self.incoming[id] and not self.requested[id] and not self:Pending("R" .. id) then
            self:After(0.5 + math.random() * 2, function()
                S.requested[id] = true
                S:Send(table.concat({ "R", Faction(), b36(t), by, who }, ","), true)
            end, "R" .. id)
        end
    elseif kind == "R" then
        local t, by, holder = rest:match("^([%w]+),([^,]+),([^,]+)$")
        t = n36(t)
        if not t then return end
        self:Cancel("R" .. t .. by)   -- someone asked already: their copy is ours too
        self.requested[t .. by] = true
        local h = self:Held()
        if holder == Me() and h and h.t == t and h.by == by then self:SendHeld() end
    elseif kind == "D" then
        local t, by, i, n, piece = rest:match("^([%w]+),([^,]+),([%w]+),([%w]+),(.*)$")
        t, i, n = n36(t), n36(i), n36(n)
        if t and i and n then self:TakePiece(t, by, i, n, piece) end
    elseif kind == "E" then
        local t, by = rest:match("^([%w]+),([^,]+)$")
        local inc = t and self.incoming[n36(t) .. by]
        if inc then self:Finish(inc) end
    end
end

-- /ahf share: what sharing is doing, to check it in game
function S:Status()
    local lines = {}
    if not self:On() then
        lines[1] = "sharing is off (Settings)."
    else
        local id = GetChannelName(self.CHANNEL)
        lines[1] = (id and id > 0) and ("sharing on, in channel " .. id .. " (" .. self.CHANNEL .. ").")
            or ("sharing on, but not in the " .. self.CHANNEL .. " channel" .. (self.joined and "" or " yet (it joins 20 s after login)") .. ".")
        local h = self:Held()
        lines[2] = h and string.format("Ready to pass on: %s's scan from %s ago (%d messages to send).", h.by,
            AHF.Age(AHF.Now() - h.t), #h.pieces) or "Nothing to pass on until you do a full scan."
        local players = {}
        for name, fac in pairs(self.heardFrom) do players[#players + 1] = name .. (fac ~= Faction() and " (other faction)" or "") end
        table.sort(players)
        lines[3] = string.format("Sent %d messages (%d waiting). Heard %d from %s.", self.sent or 0, #self.queue, self.heard,
            #players > 0 and table.concat(players, ", ") or "nobody yet")
        local g = AHF:Realm().shared[1]
        if g then lines[4] = string.format("Last got: %d items from %s's scan, %s ago.", g.items, g.by, AHF.Age(AHF.Now() - g.got)) end
    end
    for _, l in ipairs(lines) do AHF:Print(l) end
end

AHF:On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
    if prefix == S.PREFIX and channel == "CHANNEL" then S:Receive(text, sender) end
end)

AHF:On("PLAYER_LOGIN", function()
    if C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(S.PREFIX) end
    S:After(S.JOIN_DELAY, function() S:Join() end, "join")
end)
