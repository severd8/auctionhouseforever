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

-- After the last tab on screen (Auctionator adds its tabs after Blizzard's)
local function PlaceTab(f)
    local last, right
    for _, b in ipairs(Tabs(f)) do
        local r = b:IsShown() and b:GetRight()
        if r and (not right or r > right) then last, right = b, r end
    end
    tab:ClearAllPoints()
    if last then tab:SetPoint("LEFT", last, "RIGHT", -15, 0)
    else tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 20, 2) end
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
    if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    if PanelTemplates_UpdateTabs and self.frame then PanelTemplates_UpdateTabs(self.frame) end
end

function AHF:ShowTabPanel(page)
    local f = self.frame
    if not f or not panel then return end
    -- Any other tab closes ours
    for _, b in ipairs(Tabs(f)) do
        if not hookedTabs[b] then
            hookedTabs[b] = true
            b:HookScript("OnClick", function() AHF:HideTabPanel() end)
        end
        if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(b) end
    end
    if PanelTemplates_SelectTab then PanelTemplates_SelectTab(tab) end
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
    self.embedded = true
    win:Show()
    if page and win.pages[page] then win:ShowTab(page) end
end

function AHF:SetupTab(f)
    if tab then return end
    local ok, b = pcall(CreateFrame, "Button", "AuctionHouseForeverTab", f, "PanelTabButtonTemplate")
    if not ok or not b then
        ok, b = pcall(CreateFrame, "Button", "AuctionHouseForeverTab", f, "CharacterFrameTabButtonTemplate")
    end
    if not ok or not b then return end
    tab = b
    tab:SetText("AH Forever")
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
    if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    tab:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
        AHF:ShowTabPanel()
    end)
    self.tab = tab

    -- Covers the Auction House's content (below the title, above the tabs)
    panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -22)
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    panel:SetFrameLevel((f:GetFrameLevel() or 0) + 40)
    panel:EnableMouse(true)
    ns.Theme.Fill(panel, ns.Theme.C.win)
    panel:Hide()
    self.tabPanel = panel

    f:HookScript("OnShow", function() PlaceTab(f) end)
    f:HookScript("OnHide", function() AHF:HideTabPanel() end)
    if f.SetDisplayMode then hooksecurefunc(f, "SetDisplayMode", function() AHF:HideTabPanel() end) end
    if type(PanelTemplates_SetTab) == "function" then
        hooksecurefunc("PanelTemplates_SetTab", function(frame) if frame == f then AHF:HideTabPanel() end end)
    end
    PlaceTab(f)
end
