-- AuctionHouse Forever: its own tab at the bottom of the Auction House. It
-- shows the settings window inside the Auction House, over the content.
--
-- The tab is made with LibAHTab (Libs/, the library Auctionator uses for its
-- tabs), so it looks and behaves like Auctionator's and sits in line after
-- them. The library shows our panel when the tab is selected and hides it when
-- any other tab is; the panel's OnShow / OnHide move the settings window in and
-- out. Without the library, a tab of our own does the same.

local _, ns = ...
local AHF = ns.AHF

local TAB_ID = "AuctionHouseForever"
local tab, panel, hookedTabs = nil, nil, setmetatable({}, { __mode = "k" })

local function Lib()
    local LS = _G.LibStub
    return LS and LS("LibAHTab-1-0", true) or nil
end

---------------------------------------------------------------------------
-- The settings window inside the panel, and back
---------------------------------------------------------------------------
local function Embed()
    local win = AHF:GetConfigWindow()
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
    AHF.embedded = true
    win:Show()
end

local function Release()
    local win = AHF.configWindow
    if not win or not AHF.embedded then return end
    AHF.embedded = false   -- before Hide: its OnHide comes back to HideTabPanel
    win:Hide()
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

---------------------------------------------------------------------------
-- Our own tab, when LibAHTab isn't there
---------------------------------------------------------------------------
local function Tabs(f)
    local t = {}
    for _, b in ipairs(type(f.Tabs) == "table" and f.Tabs or {}) do
        if type(b) == "table" and b ~= tab then t[#t + 1] = b end
    end
    return t
end

-- Does b's position depend on our tab? (anchoring to it would loop)
local function DependsOnTab(b, depth)
    if depth > 10 or not b or not b.GetNumPoints then return false end
    for i = 1, b:GetNumPoints() do
        local _, rel = b:GetPoint(i)
        if rel == tab or (type(rel) == "table" and rel ~= b and DependsOnTab(rel, depth + 1)) then return true end
    end
    return false
end

-- After the last tab in the tab row (same bottom edge as Blizzard's Buy tab)
local function PlaceTab(f)
    local first = Tabs(f)[1]
    local bottom, height = first and first:GetBottom(), first and first:GetHeight()
    local last, right = first, first and first:GetRight()
    local fr = f:GetRight()
    local function Consider(b)
        if b == tab or not b.GetObjectType or b:GetObjectType() ~= "Button" or not b:IsVisible() then return end
        local bb, r, h = b:GetBottom(), b:GetRight(), b:GetHeight()
        if bb and r and math.abs(bb - bottom) < 4 and r > (right or 0) and (not fr or r < fr + 400)
            and (not h or not height or math.abs(h - height) < 8) and not DependsOnTab(b, 0) then
            last, right = b, r
        end
    end
    if bottom then
        for _, child in ipairs({ f:GetChildren() }) do
            Consider(child)
            if child.GetChildren and child ~= panel then
                for _, grand in ipairs({ child:GetChildren() }) do Consider(grand) end
            end
        end
    end
    tab:ClearAllPoints()
    if last then pcall(tab.SetPoint, tab, "LEFT", last, "RIGHT", -15, 0)
    else tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 20, 2) end
end

local function PlaceSoon(f)
    PlaceTab(f)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() PlaceTab(f) end)
        C_Timer.After(2, function() PlaceTab(f) end)
    end
end

local function OwnTab(f)
    local b
    for _, template in ipairs({ "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate" }) do
        local ok, made = pcall(CreateFrame, "Button", "AuctionHouseForeverTab", f, template)
        if ok and made then b = made break end
        AHF.tabError = made
    end
    if not b then return end
    tab = b
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
    -- Any of Blizzard's tabs closes ours
    if f.SetDisplayMode then hooksecurefunc(f, "SetDisplayMode", function() AHF:HideTabPanel(true) end) end
    if type(PanelTemplates_SetTab) == "function" then
        hooksecurefunc("PanelTemplates_SetTab", function(frame) if frame == f then AHF:HideTabPanel(true) end end)
    end
    f:HookScript("OnShow", function() PlaceSoon(f) end)
    PlaceSoon(f)
end

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------
-- True when the settings are now showing in the tab
function AHF:ShowTabPanel(page)
    local f = self.frame
    if not f or not panel then return false end
    if self.libTab then
        pcall(self.libTab.SetSelected, self.libTab, TAB_ID)
    else
        for _, b in ipairs(Tabs(f)) do
            if not hookedTabs[b] then
                hookedTabs[b] = true
                b:HookScript("OnClick", function() AHF:HideTabPanel(true) end)
            end
            if PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, b) end
        end
        if tab and PanelTemplates_SelectTab then pcall(PanelTemplates_SelectTab, tab) end
        panel:Show()
    end
    if not panel:IsShown() then return false end
    local win = self.configWindow
    if page and win and win.pages[page] then win:ShowTab(page) end
    return true
end

-- Closes the tab. byOtherTab: another tab is being opened (don't switch tabs)
function AHF:HideTabPanel(byOtherTab)
    if not panel or not panel:IsShown() then return end
    local f = self.frame
    if self.libTab and not byOtherTab and f and f.SetDisplayMode and AuctionHouseFrameDisplayMode then
        -- Back to the Buy tab, like clicking it (the library then hides our panel)
        pcall(f.SetDisplayMode, f, AuctionHouseFrameDisplayMode.Buy)
    end
    panel:Hide()
    if tab and not self.libTab then
        if PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, tab) end
        if PanelTemplates_UpdateTabs and f then pcall(PanelTemplates_UpdateTabs, f) end
    end
end

function AHF:SetupTab(f)
    if panel then return end
    -- Covers the Auction House's content (below the title, above the tabs)
    panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -22)
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    panel:SetFrameLevel((f:GetFrameLevel() or 0) + 40)
    panel:EnableMouse(true)
    ns.Theme.Fill(panel, ns.Theme.C.win)
    panel:Hide()
    panel:SetScript("OnShow", Embed)
    panel:SetScript("OnHide", Release)
    self.tabPanel = panel
    f:HookScript("OnHide", function() AHF:HideTabPanel(true) end)

    local lib = Lib()
    if lib and lib.CreateTab then
        local ok, err = pcall(lib.CreateTab, lib, TAB_ID, panel, "AH Forever", ns.Theme.NAME)
        if ok then
            self.libTab = lib
            tab = lib:GetButton(TAB_ID)
            self.tab = tab
            return
        end
        self.tabError = err
    end
    OwnTab(f)
end

-- /ahf debug: where the tab is
function AHF:TabDebug()
    local f = self.frame
    if not f then return "the Auction House hasn't been opened yet" end
    if not tab then return "no tab (" .. tostring(self.tabError) .. ")" end
    local p, rel = tab:GetPoint(1)
    local relName = type(rel) == "table" and (rel.GetName and rel:GetName() or (rel.GetText and rel:GetText())) or tostring(rel)
    return ("tab (%s) shown=%s visible=%s at %s of %s, left=%s bottom=%s"):format(self.libTab and "LibAHTab" or "own",
        tostring(tab:IsShown()), tostring(tab:IsVisible()), tostring(p), tostring(relName), tostring(tab:GetLeft()),
        tostring(tab:GetBottom()))
end
