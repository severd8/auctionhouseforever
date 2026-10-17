-- AuctionHouse Forever: what an item is worth disenchanted. The game doesn't
-- tell addons what an item disenchants into, so the Classic disenchanting
-- table is written out here: by quality and item level, each material's
-- chance and the average number you get.

local _, ns = ...
local AHF = ns.AHF

local M = {
    strange = 10940, soul = 11083, vision = 11137, dream = 11176, illusion = 16204,
    lesserMagic = 10938, greaterMagic = 10939, lesserAstral = 10998, greaterAstral = 11082,
    lesserMystic = 11134, greaterMystic = 11135, lesserNether = 11174, greaterNether = 11175,
    lesserEternal = 16202, greaterEternal = 16203,
    smallGlimmering = 10978, largeGlimmering = 11084, smallGlowing = 11138, largeGlowing = 11139,
    smallRadiant = 11177, largeRadiant = 11178, smallBrilliant = 14343, largeBrilliant = 14344,
    nexus = 20725,
}
AHF.DE_MATERIALS = M

-- Uncommon (green): up to item level, dust (amount), essence (amount), shard.
-- Armor gives mostly dust; weapons swap the dust and essence chances.
local UNCOMMON = {
    { 15, M.strange, 1.5, M.lesserMagic, 1.5, nil },
    { 20, M.strange, 2.5, M.greaterMagic, 1.5, M.smallGlimmering },
    { 25, M.strange, 5, M.lesserAstral, 1.5, M.smallGlimmering },
    { 30, M.soul, 1.5, M.greaterAstral, 1.5, M.largeGlimmering },
    { 35, M.soul, 3.5, M.lesserMystic, 1.5, M.smallGlowing },
    { 40, M.vision, 1.5, M.greaterMystic, 1.5, M.largeGlowing },
    { 45, M.vision, 3.5, M.lesserNether, 1.5, M.smallRadiant },
    { 50, M.dream, 1.5, M.greaterNether, 1.5, M.largeRadiant },
    { 55, M.dream, 3.5, M.lesserEternal, 1.5, M.smallBrilliant },
    { 60, M.illusion, 1.5, M.greaterEternal, 1.5, M.largeBrilliant },
    { 999, M.illusion, 3.5, M.greaterEternal, 2.5, M.largeBrilliant },
}

-- Rare (blue): one shard; the best ones sometimes give a Nexus Crystal
local RARE = {
    { 25, M.smallGlimmering }, { 30, M.largeGlimmering }, { 35, M.smallGlowing }, { 40, M.largeGlowing },
    { 45, M.smallRadiant }, { 50, M.largeRadiant }, { 55, M.smallBrilliant }, { 999, M.largeBrilliant },
}

-- Epic (purple)
local EPIC = {
    { 45, M.smallRadiant, 3 }, { 50, M.largeRadiant, 3 }, { 55, M.smallBrilliant, 3 },
    { 60, M.nexus, 1 }, { 999, M.nexus, 1.5 },
}

local function Row(list, level)
    for _, row in ipairs(list) do
        if level <= row[1] then return row end
    end
end

local WEAPON, ARMOR = 2, 4

-- The materials an item disenchants into: { { itemID, chance, average amount }, ... },
-- or nil if it can't be disenchanted
function AHF.DisenchantResults(quality, level, classID)
    if classID ~= WEAPON and classID ~= ARMOR then return nil end
    if not level or level < 5 then return nil end
    if quality == 2 then
        local r = Row(UNCOMMON, level)
        local dust, essence = 0.75, 0.20
        if not r[6] then dust, essence = 0.80, 0.20 end
        if classID == WEAPON then dust, essence = essence, dust end
        local out = { { r[2], dust, r[3] }, { r[4], essence, r[5] } }
        if r[6] then out[3] = { r[6], 0.05, 1 } end
        return out
    elseif quality == 3 then
        if level < 11 then return nil end
        local r = Row(RARE, level)
        if level > 55 then return { { r[2], 0.995, 1 }, { M.nexus, 0.005, 1 } } end
        return { { r[2], 1, 1 } }
    elseif quality == 4 then
        if level < 40 then return nil end
        local r = Row(EPIC, level)
        return { { r[2], 1, r[3] } }
    end
    return nil
end

-- An item's disenchant value in copper, and whether part of it is a guess
-- (a material with no AHF price yet, counted at its vendor price)
function AHF:DisenchantValue(link)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not get or not link then return nil end
    local _, _, quality, level, _, _, _, _, _, _, _, classID = get(link)
    local results = self.DisenchantResults(quality, level, classID)
    if not results then return nil end
    local total, guessed = 0, false
    for _, r in ipairs(results) do
        local price = self:MarketPrice(tostring(r[1]), r[1])
        if not price then
            guessed = true
            local vendor = select(11, get(r[1]))
            price = type(vendor) == "number" and vendor or 0
        end
        total = total + r[2] * r[3] * price
    end
    return math.floor(total + 0.5), guessed
end
