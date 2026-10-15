-- AuctionHouse Forever: /ahf debug opens a small window with details for a bug
-- report (version, game, tab, settings, other Auction House addons), selected
-- and ready to copy.

local _, ns = ...
local AHF = ns.AHF

local WIDTH, HEIGHT = 560, 380
-- Addons that change the Auction House: named in the report when loaded
local AUCTION_ADDONS = { "auction", "tradeskillmaster", "tsm", "journalator", "oribos", "undermine" }

local report

local function GetAddOn(i)
    local get = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if not get then return nil end
    local name, title = get(i)
    return name, title
end

local function Loaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return fn and fn(name) and true or false
end

-- Other loaded addons that work on the Auction House, with their versions
function AHF:AuctionAddOns()
    local count = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local found = {}
    for i = 1, (count and count() or 0) do
        local name, title = GetAddOn(i)
        if type(name) == "string" and name ~= "AuctionHouseForever" and not name:find("^Blizzard_")
                and Loaded(name) then
            local text = (name .. " " .. tostring(title or "")):lower()
            for _, word in ipairs(AUCTION_ADDONS) do
                if text:find(word, 1, true) then
                    local v = meta and meta(name, "Version")
                    found[#found + 1] = name .. ((type(v) == "string" and v ~= "") and (" " .. v) or "")
                    break
                end
            end
        end
    end
    return found
end

function AHF:ReportText()
    local db = self.db
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    add("AuctionHouse Forever " .. tostring(self:Version() or "(development copy)"))
    if GetBuildInfo then
        local version, build, _, interface = GetBuildInfo()
        add(("Game: %s (build %s), interface %s"):format(tostring(version), tostring(build), tostring(interface)))
    end
    add("Tab: " .. (self.TabDebug and self:TabDebug() or "no tab code"))
    if self.tabError then add("Tab error: " .. tostring(self.tabError)) end
    local f = self.frame
    add(("Window: %d x %d saved, %s shown, scale %d%%, %s, %s"):format(db.width, db.height,
        f and ("%d x %d"):format(f:GetWidth() or 0, f:GetHeight() or 0) or "not opened yet",
        math.floor(db.scale * 100 + 0.5), db.point and "moved" or "Blizzard's place",
        db.locked and "locked" or "unlocked"))
    add(("Text: rows %d%%, categories %d%%; category list %d wide"):format(db.rowTextScale,
        db.categoryTextScale, db.sidebarWidth))
    if UIParent then
        add(("Screen: %d x %d, UI scale %.2f"):format(UIParent:GetWidth() or 0, UIParent:GetHeight() or 0,
            UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1))
    end
    local sort = db.browseSort
    add("Sort: " .. (sort and (sort.kind .. (sort.reverse and ", reversed" or "")) or "the game's"))
    local others = self:AuctionAddOns()
    add("Other Auction House addons: " .. (#others > 0 and table.concat(others, ", ") or "none"))
    return table.concat(lines, "\n")
end

local function Build()
    local T = ns.Theme
    local C = T.C
    report = CreateFrame("Frame", "AuctionHouseForeverReport", UIParent)
    report:SetSize(WIDTH, HEIGHT)
    report:SetPoint("CENTER", 0, 40)
    report:SetFrameStrata("DIALOG")
    report:SetToplevel(true)
    report:SetClampedToScreen(true)
    report:SetMovable(true)
    report:EnableMouse(true)
    report:RegisterForDrag("LeftButton")
    report:SetScript("OnDragStart", report.StartMoving)
    report:SetScript("OnDragStop", report.StopMovingOrSizing)
    report:Hide()
    table.insert(UISpecialFrames, "AuctionHouseForeverReport")   -- Escape closes it
    T.Fill(report, C.win)
    T.Border(report, C.edge)

    local title = T.Text(report, T.NAME .. ": bug report details", "GameFontNormalLarge", C.gold)
    title:SetPoint("TOPLEFT", 16, -14)
    local x = T.FlatButton(report, "X", 24, 24)
    x:SetPoint("TOPRIGHT", -12, -10)
    x:SetScript("OnClick", function() report:Hide() end)
    local note = T.Note(report, "Press Ctrl+C to copy, then paste it into your bug report with what happened.",
        16, -42, WIDTH - 32)

    local box = CreateFrame("ScrollFrame", nil, report)
    box:SetPoint("TOPLEFT", 16, -66)
    box:SetPoint("BOTTOMRIGHT", -16, 50)
    T.Fill(box, C.field)
    T.Border(box, C.fieldEdge)
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetWidth(WIDTH - 44)
    edit:SetTextInsets(6, 6, 6, 6)
    box:SetScrollChild(edit)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 30)))
    end)
    edit:SetScript("OnEscapePressed", function() report:Hide() end)
    -- Read only: typing puts the report back, selected
    edit:SetScript("OnTextChanged", function(self, user)
        if user and report.text then
            self:SetText(report.text)
            self:HighlightText()
        end
    end)
    edit:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    report.edit = edit

    local done = T.FlatButton(report, "Close", 90)
    done:SetPoint("BOTTOMRIGHT", -14, 12)
    done:SetScript("OnClick", function() report:Hide() end)
    report.note = note
end

function AHF:ShowReport()
    if not report then Build() end
    report.text = self:ReportText()
    report.edit:SetText(report.text)
    report:Show()
    report:Raise()
    report.edit:SetFocus()
    report.edit:HighlightText()
end
