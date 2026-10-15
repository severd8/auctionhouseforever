-- AuctionHouse Forever: its own tab at the bottom of the Auction House, after
-- Blizzard's and other addons' tabs (Auctionator's), like Auctionator's. It
-- shows the settings window inside the Auction House, over the content.
--
-- The tab isn't added to Blizzard's tab list (AuctionHouseFrame.Tabs): it only
-- looks like one. Clicking any other tab, or Escape, closes ours.

local _, ns = ...
local AHF = ns.AHF

local tab, panel, hookedTabs = nil, nil, setmetatable({}, { __mode = "k" })

local function Tabs(f)
    local t = {}
    for _, b in ipairs(type(f.Tabs) == "table" and f.Tabs or {}) do
        if type(b) == "table" and b ~= tab then t[#t + 1] = b end
    end
    return t
end

-- After the last tab on screen. Auctionator's tabs aren't all in
-- AuctionHouseFrame.Tabs, so every button in the tab row counts: same bottom
-- edge as Blizzard's Buy tab.
local function PlaceTab(f)
    local first = Tabs(f)[1]
    local bottom = first and first:GetBottom()
    local last, right = first, first and first:GetRight()
    if bottom then
        for _, b in ipairs({ f:GetChildren() }) do
            if b ~= tab and b.GetObjectType and b:GetObjectType() == "Button" and b:IsShown() then
                local bb, r, h = b:GetBottom(), b:GetRight(), b:GetHeight()
                local fr = f:GetRight()
                if bb and r and math.abs(bb - bottom) < 3 and r > (right or 0)
                    and (not fr or r < fr + 300) and (not h or math.abs(h - (first:GetHeight() or h)) < 6) then
                    last, right = b, r
                end
            end
        end
    end
    tab:ClearAllPoints()
    if last then tab:SetPoint("LEFT", last, "RIGHT", -15, 0)
    else tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 20, 2) end
end

-- Other addons add their tabs when the Auction House first opens: place ours
-- after them once they're there
local function PlaceSoon(f)
    PlaceTab(f)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() PlaceTab(f) end)
        C_Timer.After(0.5, function() PlaceTab(f) end)
    end
end

-- The window back to a window of its own
local function Release(win)
    AHF.embedded = false
    win:SetParent(UIParent)
    win:ClearAllPoints()
    win:SetSize(ns.Theme.WINDOW.W, ns.Theme.WINDOW.H)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win.header:EnableMouse(true)
    for _, b in ipairs(win.closeButtons or {}) do b:Show() end
    win.logo:ClearAllPoints()
    win.logo:SetPoint("LEFT", win.header, "LEFT", 14, 0)
end

function AHF:HideTabPanel()
    if not panel or not panel:IsShown() then return end
    panel:Hide()
    local win = self.configWindow
    if win and self.embedded then
        self.embedded = false   -- before Hide: its OnHide comes back here
        win:Hide()
        Release(win)
    end
    if tab and PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, tab) end
    if PanelTemplates_UpdateTabs and self.frame then pcall(PanelTemplates_UpdateTabs, self.frame) end
end

-- True when the settings are now showing in the tab
function AHF:ShowTabPanel(page)
    local f = self.frame
    if not f or not panel then return false end
    -- Any other tab closes ours
    for _, b in ipairs(Tabs(f)) do
        if not hookedTabs[b] then
            hookedTabs[b] = true
            b:HookScript("OnClick", function() AHF:HideTabPanel() end)
        end
        if PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, b) end
    end
    if tab and PanelTemplates_SelectTab then pcall(PanelTemplates_SelectTab, tab) end
    panel:Show()
    local win = self:GetConfigWindow()
    win:SetParent(panel)
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", panel, "TOPLEFT")
    win:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT")
    win:SetFrameStrata(panel:GetFrameStrata())
    win:SetFrameLevel(panel:GetFrameLevel() + 1)
    win.header:EnableMouse(false)   -- not dragged out of the Auction House
    for _, b in ipairs(win.closeButtons or {}) do b:Hide() end
    -- Logo and name clear of the Auction House's round NPC portrait
    win.logo:ClearAllPoints()
    win.logo:SetPoint("LEFT", win.header, "LEFT", 74, 0)
    self.embedded = true
    win:Show()
    if page and win.pages[page] then win:ShowTab(page) end
    return true
end

function AHF:SetupTab(f)
    if panel then return end
    -- Covers the Auction House's content (below the title, above the tabs).
    -- Made first, so the settings open here even if the tab can't be made.
    panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -22)
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    panel:SetFrameLevel((f:GetFrameLevel() or 0) + 40)
    panel:EnableMouse(true)
    ns.Theme.Fill(panel, ns.Theme.C.win)
    panel:Hide()
    self.tabPanel = panel

    f:HookScript("OnHide", function() AHF:HideTabPanel() end)
    if f.SetDisplayMode then hooksecurefunc(f, "SetDisplayMode", function() AHF:HideTabPanel() end) end
    if type(PanelTemplates_SetTab) == "function" then
        hooksecurefunc("PanelTemplates_SetTab", function(frame) if frame == f then AHF:HideTabPanel() end end)
    end

    -- The tab: the same template and size as Blizzard's Auction House tabs
    -- (PanelTabButtonTemplate, padding 20, at least 70 wide). Not added to
    -- AuctionHouseFrame.Tabs.
    local b
    for _, template in ipairs({ "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate" }) do
        local ok, made = pcall(CreateFrame, "Button", "AuctionHouseForeverTab", f, template)
        if ok and made then b = made break end
        self.tabError = made
    end
    if not b then return end
    tab = b
    self.tab = tab
    tab:SetText("AH Forever")
    local function Resize()
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 20, nil, 70) end
    end
    Resize()
    tab:HookScript("OnShow", Resize)
    if PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, tab) end
    tab:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
        AHF:ShowTabPanel()
    end)
    tab:Show()
    f:HookScript("OnShow", function() PlaceSoon(f) end)
    PlaceSoon(f)
end

-- /ahf debug: where the tab is
function AHF:TabDebug()
    local f = self.frame
    if not f then return "the Auction House hasn't been opened yet" end
    if not tab then return "no tab (" .. tostring(self.tabError) .. ")" end
    local p, rel = tab:GetPoint(1)
    local relName = type(rel) == "table" and (rel.GetName and rel:GetName() or (rel.GetText and rel:GetText())) or tostring(rel)
    return ("tab shown=%s visible=%s at %s of %s, left=%s bottom=%s, panel=%s"):format(tostring(tab:IsShown()),
        tostring(tab:IsVisible()), tostring(p), tostring(relName), tostring(tab:GetLeft()), tostring(tab:GetBottom()),
        tostring(panel ~= nil))
end
