-- AuctionHouse Forever: welcome / "What's new" splash screen.
-- Shows once after each update (and on first install), unless turned off.
-- /ahf news opens it anytime.

local _, ns = ...
local AHF = ns.AHF

local WIDTH, HEIGHT = 720, 620
local BANNER_H = 130
local MAX_NEWS = 6

local splash

function AHF:CurrentNewsVersion()
    return self.NEWS and self.NEWS[1] and self.NEWS[1].version
end

local ORANGE, GOLD, BLUE, GREY = "|cffff9a2a", "|cffffd100", "|cff8fd3ff", "|cffbbbbbb"

local function BuildText()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    local top = AHF.NEWS and AHF.NEWS[1]
    if top then
        add(GOLD .. "v" .. top.version .. "|r " .. GREY .. "(" .. top.date .. ")|r")
        add(" ")
    end

    add(ORANGE .. "# Quick start|r")
    add("- |cffffffffDrag the bottom right corner|r of the Auction House to resize it")
    add("- |cffffffffDrag the title bar|r to move it (lock it in the settings)")
    add("- |cffffffffDrag the line between two column headers|r to resize a column")
    add("- |cffffffffHide, show and reorder columns|r on the Show & Order tab of " .. BLUE .. "/ahf|r")
    add("- " .. BLUE .. "/ahf|r  open settings      " .. BLUE .. "/ahf reset|r  default size and position")
    add("- " .. BLUE .. "/ahf news|r  show this window again")
    add(" ")

    add(ORANGE .. "# What's new|r")
    local count = 0
    for _, entry in ipairs(AHF.NEWS or {}) do
        for _, item in ipairs(entry.items) do
            if count >= MAX_NEWS then break end
            add("- " .. GOLD .. "v" .. entry.version .. "|r  " .. item)
            count = count + 1
        end
        if count >= MAX_NEWS then break end
    end
    add(" ")

    add(ORANGE .. "# Support|r")
    add("Found a bug? Report it on GitHub (link on the CurseForge page).")
    add("Enjoying the addon? Tips on Ko-fi keep it updated: ko-fi.com/tauntmasterforever")
    return table.concat(lines, "\n")
end

local function Build()
    local T = ns.Theme
    local C = T.C
    splash = CreateFrame("Frame", "AuctionHouseForeverSplash", UIParent)
    splash:SetSize(WIDTH, HEIGHT)
    splash:SetPoint("CENTER", 0, 40)
    splash:SetFrameStrata("DIALOG")
    splash:SetToplevel(true)
    splash:SetClampedToScreen(true)
    splash:SetMovable(true)
    splash:EnableMouse(true)
    splash:RegisterForDrag("LeftButton")
    splash:SetScript("OnDragStart", splash.StartMoving)
    splash:SetScript("OnDragStop", splash.StopMovingOrSizing)
    splash:Hide()
    table.insert(UISpecialFrames, "AuctionHouseForeverSplash") -- Escape closes it
    T.Fill(splash, C.win)
    T.Border(splash, C.edge)

    -- Banner
    local banner = splash:CreateTexture(nil, "BORDER")
    banner:SetPoint("TOPLEFT", 1, -1)
    banner:SetPoint("TOPRIGHT", -1, -1)
    banner:SetHeight(BANNER_H)
    T.HeaderGradient(banner)
    local line = splash:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", banner, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", banner, "BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(unpack(C.edge))

    local logo = splash:CreateTexture(nil, "ARTWORK")
    logo:SetSize(108, 108)
    logo:SetPoint("TOPLEFT", 18, -12)
    logo:SetTexture(T.LOGO)

    local title = T.Text(splash, T.NAME, "GameFontNormalHuge", { 0.95, 0.9, 0.78 }, 34)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 18, -16)
    local sub = T.Text(splash, "A bigger, roomier Auction House for WoW: Forever", "GameFontNormalLarge", C.orange)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -8)

    local x = T.FlatButton(splash, "X", 24, 24)
    x:SetPoint("TOPRIGHT", -12, -12)
    x:SetScript("OnClick", function() splash:Hide() end)

    -- Text area: mouse wheel scrolls it, with a thin themed scroll bar
    local scroll = CreateFrame("ScrollFrame", nil, splash)
    scroll:SetPoint("TOPLEFT", 22, -(BANNER_H + 16))
    scroll:SetPoint("BOTTOMRIGHT", -26, 50)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 60, 10)
    scroll:SetScrollChild(content)
    local text = T.Text(content, "", "GameFontHighlight")
    text:SetPoint("TOPLEFT")
    text:SetWidth(WIDTH - 60)
    text:SetSpacing(3)
    splash.text, splash.content, splash.scroll = text, content, scroll

    local bar = CreateFrame("Frame", nil, splash)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 0)
    bar:SetWidth(4)
    T.Fill(bar, C.offTrack)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(4)
    thumb:SetColorTexture(unpack(C.btnEdge))
    splash.scrollBar = bar

    local function updateBar()
        local range = scroll:GetVerticalScrollRange() or 0
        local h = scroll:GetHeight() or 1
        if range <= 0 then bar:Hide() return end
        bar:Show()
        local total = h + range
        local thumbH = math.max(20, h * h / total)
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        local off = (scroll:GetVerticalScroll() or 0) / range * (h - thumbH)
        thumb:SetPoint("TOP", bar, "TOP", 0, -off)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local v = (self:GetVerticalScroll() or 0) - delta * 40
        self:SetVerticalScroll(math.max(0, math.min(range, v)))
        updateBar()
    end)
    splash.updateBar = updateBar

    -- Footer
    local sep = splash:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("BOTTOMLEFT", 1, 40)
    sep:SetPoint("BOTTOMRIGHT", -1, 40)
    sep:SetHeight(1)
    sep:SetColorTexture(unpack(C.line))

    local sw = T.SwitchWidget(splash)
    sw:SetPoint("BOTTOMLEFT", 16, 13)
    local swText = T.Text(splash, "Show welcome screen after updates", "GameFontHighlightSmall", C.muted)
    swText:SetPoint("LEFT", sw, "RIGHT", 8, 0)
    sw:SetScript("OnClick", function(self)
        AHF.db.showSplash = not AHF.db.showSplash
        self:SetOn(AHF.db.showSplash)
    end)
    splash.check = sw

    local done = T.FlatButton(splash, "Close", 90)
    done:SetPoint("BOTTOMRIGHT", -14, 10)
    done:SetScript("OnClick", function() splash:Hide() end)

    local notes = T.Text(splash, "Full release notes on CurseForge", "GameFontNormalSmall", C.orange)
    notes:SetPoint("RIGHT", done, "LEFT", -12, 0)

    AHF._splash = splash
end

function AHF:ShowSplash()
    if not splash then Build() end
    splash.text:SetText(BuildText())
    splash.content:SetHeight((splash.text:GetStringHeight() or 0) + 10)
    splash.scroll:SetVerticalScroll(0)
    splash.updateBar()
    splash.check:SetOn(self.db.showSplash)
    self.db.lastSeenVersion = self:CurrentNewsVersion()
    splash:Show()
    splash:Raise()
end

function AHF:ToggleSplash()
    if splash and splash:IsShown() then splash:Hide() else self:ShowSplash() end
end

-- On login: show once per new version (and on first install), a few seconds in
function AHF:MaybeShowSplash()
    local current = self:CurrentNewsVersion()
    if not current or not self.db.showSplash or self.db.lastSeenVersion == current then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(4, function() AHF:ShowSplash() end)
    else
        self:ShowSplash()
    end
end
