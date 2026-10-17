-- AuctionHouse Forever: the price math and the saved format. Plain Lua with no
-- game calls, so the tests load it on its own.
--
-- An item's history is a list of records, oldest first. Each record is one day
-- (span 1) or, once it's old, one week (span 7):
--   d  first day (days since 1 Jan 1970, UTC)     s  span in days (1 or 7)
--   m  lowest price seen (copper, per item)        v  market value (0 = none yet)
--   q  quantity listed                             n  scans the market value comes from
--   t  time of the newest data (seconds)
-- Saved as one string per item: records split by ";", fields by "," in base 36.

local _, ns = ...
ns = ns or {}
local P = {}
ns.Prices = P

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

P.DAY = 86400
P.KEEP_DAILY = 14      -- days kept one by one; older days are joined into weeks
P.KEEP_DAYS = 365      -- weeks older than this are dropped
P.SEARCH_GAP = 600     -- a search this soon after the last data doesn't count as another scan
P.OUTLIER = 3          -- market value ignores prices more than 3x away from the middle
P.CHEAP_SHARE = 0.3    -- ... then looks at the cheapest 30% of the items left

function P.Day(t) return floor(t / P.DAY) end

-- The Monday that starts the week of day d (day 0 was a Thursday)
function P.WeekStart(d) return d - (d + 3) % 7 end

---------------------------------------------------------------------------
-- Base 36 numbers
---------------------------------------------------------------------------
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

function P.ToBase36(n)
    n = floor(n + 0.5)
    if n == 0 then return "0" end
    local neg = n < 0
    if neg then n = -n end
    local out = {}
    while n > 0 do
        local r = n % 36
        out[#out + 1] = DIGITS:sub(r + 1, r + 1)
        n = (n - r) / 36
    end
    local s = string.reverse(table.concat(out))
    return neg and ("-" .. s) or s
end

function P.FromBase36(s)
    if s:sub(1, 1) == "-" then return -(tonumber(s:sub(2), 36) or 0) end
    return tonumber(s, 36) or 0
end

local FIELDS = { "d", "s", "m", "v", "q", "n", "t" }

function P.Encode(recs)
    local parts = {}
    for i, r in ipairs(recs) do
        local f = {}
        for j, k in ipairs(FIELDS) do f[j] = P.ToBase36(r[k] or 0) end
        parts[i] = table.concat(f, ",")
    end
    return table.concat(parts, ";")
end

-- Broken records are skipped, so a damaged saved file can't stop the addon
function P.Decode(str)
    local recs = {}
    if type(str) ~= "string" then return recs end
    for chunk in str:gmatch("[^;]+") do
        local r, j = {}, 0
        for field in chunk:gmatch("[^,]+") do
            j = j + 1
            if FIELDS[j] then r[FIELDS[j]] = P.FromBase36(field) end
        end
        if j == #FIELDS and r.s > 0 and r.m >= 0 then recs[#recs + 1] = r end
    end
    table.sort(recs, function(a, b) return a.d < b.d end)
    return recs
end

---------------------------------------------------------------------------
-- Market value: a weighted median of the cheapest listings
---------------------------------------------------------------------------

-- listings: { { price per item, quantity }, ... } in any order.
-- Finds the middle price of the cheaper half of the items for sale, drops
-- prices more than 3x above or below it (a few silly listings at either end
-- can't drag it, and a pile of overpriced ones doesn't push out the real
-- prices), then takes the cheapest 30% of what's left (at least one item) and
-- returns their middle price, counting each item in a stack.
local function Median(items, count)
    local half, seen = count / 2, 0
    for _, l in ipairs(items) do
        seen = seen + l[2]
        if seen >= half then return l[1] end
    end
    return items[#items][1]
end

function P.MarketValue(listings)
    local list, total = {}, 0
    for _, l in ipairs(listings) do
        local price, qty = l[1], l[2]
        if price and price > 0 and qty and qty > 0 then
            list[#list + 1] = { price, qty }
            total = total + qty
        end
    end
    if total == 0 then return nil end
    table.sort(list, function(a, b) return a[1] < b[1] end)

    local mid = Median(list, total / 2)
    local kept, keptCount = {}, 0
    for _, l in ipairs(list) do
        if l[1] <= mid * P.OUTLIER and l[1] * P.OUTLIER >= mid then
            kept[#kept + 1] = l
            keptCount = keptCount + l[2]
        end
    end

    local want = max(1, ceil(keptCount * P.CHEAP_SHARE))
    local cheap, got = {}, 0
    for _, l in ipairs(kept) do
        local take = min(l[2], want - got)
        cheap[#cheap + 1] = { l[1], take }
        got = got + take
        if got >= want then break end
    end
    return floor(Median(cheap, got) + 0.5)
end

-- Sums up one item's listings: lowest price, market value, quantity
function P.Summarize(listings)
    local low, qty = nil, 0
    for _, l in ipairs(listings) do
        if l[1] > 0 and l[2] > 0 then
            if not low or l[1] < low then low = l[1] end
            qty = qty + l[2]
        end
    end
    if not low then return nil end
    return { min = low, market = P.MarketValue(listings), qty = qty }
end

---------------------------------------------------------------------------
-- Adding new data
---------------------------------------------------------------------------

-- obs = { min =, qty =, t =, market = (nil when only the lowest price is known),
--         full = true for a full scan }
-- Returns the record it went into.
function P.Add(recs, obs)
    local day = P.Day(obs.t)
    local r
    for i = #recs, 1, -1 do
        if recs[i].d == day and recs[i].s == 1 then r = recs[i] break end
        if recs[i].d < day then break end
    end
    if not r then
        r = { d = day, s = 1, m = obs.min, v = 0, q = obs.qty or 0, n = 0, t = 0 }
        local pos = #recs + 1
        while pos > 1 and recs[pos - 1].d > day do pos = pos - 1 end
        table.insert(recs, pos, r)
    end
    if obs.min < r.m then r.m = obs.min end
    if obs.market then
        -- a search moments after the last data refines it instead of counting twice
        local soon = not obs.full and r.n > 0 and obs.t - r.t < P.SEARCH_GAP
        r.v = floor((r.v * r.n + obs.market) / (r.n + 1) + 0.5)
        if not soon then r.n = r.n + 1 end
    end
    if obs.t >= r.t then
        r.q = obs.qty or r.q
        r.t = obs.t
    end
    return r
end

-- Joins b into a (both the same span of time)
local function Join(a, b, count)
    if b.m < a.m then a.m = b.m end
    if a.n + b.n > 0 then
        a.v = floor((a.v * a.n + b.v * b.n) / (a.n + b.n) + 0.5)
    elseif b.v > 0 and a.v == 0 then
        a.v = b.v
    end
    a.n = a.n + b.n
    -- quantity: the average over the records joined
    a.q = floor((a.q * count + b.q) / (count + 1) + 0.5)
    if b.t > a.t then a.t = b.t end
end
P.Join = Join

-- Days older than KEEP_DAILY become weeks; weeks older than KEEP_DAYS go.
-- Returns the new list and whether anything changed.
function P.Condense(recs, today)
    local out, changed = {}, false
    local weeks, joined = {}, {}
    for _, r in ipairs(recs) do
        if r.d + r.s - 1 < today - P.KEEP_DAYS then
            changed = true                                   -- too old: dropped
        elseif r.s == 1 and r.d <= today - P.KEEP_DAILY then
            changed = true
            local ws = P.WeekStart(r.d)
            local w = weeks[ws]
            if w then
                Join(w, r, joined[ws])
                joined[ws] = joined[ws] + 1
            else
                w = { d = ws, s = 7, m = r.m, v = r.v, q = r.q, n = r.n, t = r.t }
                weeks[ws], joined[ws] = w, 1
                out[#out + 1] = w
            end
        elseif r.s == 7 and weeks[r.d] then
            changed = true                                   -- an older week joins the new one
            Join(weeks[r.d], r, joined[r.d])
            joined[r.d] = joined[r.d] + 1
        else
            if r.s == 7 then weeks[r.d], joined[r.d] = r, 7 end
            out[#out + 1] = r
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out, changed
end

---------------------------------------------------------------------------
-- Reading it back
---------------------------------------------------------------------------

-- The newest record, and the average market value (or lowest price where
-- there's no market value) over the last `days` days, weighted by scans
function P.Latest(recs) return recs[#recs] end

function P.Average(recs, days, today)
    local sum, weight, scans = 0, 0, 0
    for i = #recs, 1, -1 do
        local r = recs[i]
        if r.d + r.s - 1 <= today - days then break end
        local value = r.v > 0 and r.v or r.m
        local w = max(r.n, 1)
        sum, weight, scans = sum + value * w, weight + w, scans + r.n
    end
    if weight == 0 then return nil end
    return floor(sum / weight + 0.5), scans
end

-- How many scans saw the item in the last `days` days (a day with only a
-- browse result counts once)
function P.Scans(recs, days, today)
    local scans = 0
    for i = #recs, 1, -1 do
        local r = recs[i]
        if r.d + r.s - 1 <= today - days then break end
        scans = scans + max(r.n, 1)
    end
    return scans
end

return P
