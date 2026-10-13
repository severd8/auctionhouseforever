-- AuctionHouse Forever: the window itself. Size (corner grip), position (drag
-- the title bar), scale and the category list's width.
--
-- Blizzard sets the window's size and position again in several places (it's a
-- "doublewide" UI panel, so the panel manager moves it every time it opens, and
-- tabs switch its contents). Everything here only hooks those calls afterwards
-- and puts the saved layout back; nothing writes into Blizzard's own tables.

local _, ns = ...
local AHF = ns.AHF
local Clamp = AHF.Clamp

local applying = false      -- our own SetSize/SetScale calls don't trigger the hooks again
local touched = setmetatable({}, { __mode = "k" })   -- Blizzard frames we've adjusted, and their original sizes

local function Round(v) return math.floor(v + 0.5) end

local function SetResizeBounds(f, minW, minH, maxW, maxH)
    if f.SetResizeBounds then
        f:SetResizeBounds(minW, minH, maxW, maxH)
    else   -- older clients
        if f.SetMinResize then f:SetMinResize(minW, minH) end
        if f.SetMaxResize then f:SetMaxResize(maxW, maxH) end
    end
end

-- Stops the game from also remembering the window's place in its own layout
-- file, which would fight the saved position
local function NotUserPlaced(f)
    if f.SetUserPlaced then pcall(f.SetUserPlaced, f, false) end
end

---------------------------------------------------------------------------
-- Size limits: the settings' range, and never bigger than the screen
---------------------------------------------------------------------------
function AHF:SizeBounds()
    local L = self.LIMITS
    local scale = self.db.scale
    local maxW, maxH = L.width[2], L.height[2]
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if type(sw) == "number" and sw > 0 then maxW = math.min(maxW, Round(sw / scale)) end
    if type(sh) == "number" and sh > 0 then maxH = math.min(maxH, Round(sh / scale)) end
    return L.width[1], L.height[1], math.max(L.width[1], maxW), math.max(L.height[1], maxH)
end

function AHF:ClampedSize()
    local minW, minH, maxW, maxH = self:SizeBounds()
    return Clamp(self.db.width, { minW, maxW }), Clamp(self.db.height, { minH, maxH })
end

---------------------------------------------------------------------------
-- Apply the saved layout to the window
---------------------------------------------------------------------------
local function ApplyNow(self, f)
    local db = self.db
    if math.abs((f:GetScale() or 1) - db.scale) > 0.001 then f:SetScale(db.scale) end

    local minW, minH, maxW, maxH = self:SizeBounds()
    SetResizeBounds(f, minW, minH, maxW, maxH)
    local w, h = self:ClampedSize()
    if math.abs((f:GetWidth() or 0) - w) > 0.5 or math.abs((f:GetHeight() or 0) - h) > 0.5 then
        f:SetSize(w, h)
    end

    if db.point then
        local p = db.point
        f:ClearAllPoints()
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end

    self.mover:EnableMouse(not db.locked)
    self:ApplySidebar()
end

function AHF:ApplyLayout()
    local f = self.frame
    if not f or applying then return end
    applying = true
    local ok, err = pcall(ApplyNow, self, f)
    applying = false
    if not ok then geterrorhandler()(err) end
end

---------------------------------------------------------------------------
-- Settings changes (from the options window and slash commands)
---------------------------------------------------------------------------
function AHF:SetSize(w, h)
    local L = self.LIMITS
    self.db.width = Clamp(Round(w), L.width)
    self.db.height = Clamp(Round(h), L.height)
    self:ApplyLayout()
    self:RefreshOptions()
end

-- Keeps the window's top left corner where it is on screen
function AHF:SetScale(v)
    local db = self.db
    v = Clamp(v, self.LIMITS.scale)
    if db.point and v ~= db.scale then
        local p = db.point
        p[3], p[4] = p[3] * db.scale / v, p[4] * db.scale / v
    end
    db.scale = v
    self:ApplyLayout()
    self:RefreshOptions()
end

function AHF:SetLocked(on)
    self.db.locked = on and true or false
    self:ApplyLayout()
    self:RefreshOptions()
end

function AHF:SetSidebarWidth(w)
    self.db.sidebarWidth = Clamp(Round(w), self.LIMITS.sidebarWidth)
    self:ApplyLayout()
    self:RefreshOptions()
end

-- Back to where Blizzard puts the window
function AHF:ResetPosition()
    self.db.point = nil
    local f = self.frame
    if f and self.blizzardPoint then
        local p = self.blizzardPoint
        applying = true
        f:ClearAllPoints()
        f:SetPoint(p[1], p[2], p[3], p[4], p[5])
        applying = false
    end
    self:ApplyLayout()
    self:RefreshOptions()
end

-- Remembers where Blizzard put the window, so Reset can put it back there
-- straight away without asking the panel manager again. force: Blizzard has
-- just placed it (even if a saved position goes on top next)
function AHF:RememberBlizzardPoint(force)
    local f = self.frame
    if not f or (self.db.point and not force) then return end
    local p, rel, rp, x, y = f:GetPoint(1)
    if type(p) == "string" then self.blizzardPoint = { p, rel or UIParent, rp or p, x or 0, y or 0 } end
end

---------------------------------------------------------------------------
-- The category list's width
---------------------------------------------------------------------------
-- Stretches a category button's artwork with the button (the textures have
-- fixed sizes in Blizzard's template; the text is already anchored both sides)
-- Category text size and button height (taller for bigger text)
function AHF:CategoryHeight()
    local size = self.db.categoryFontSize
    if size == 0 then return self.CATEGORY_HEIGHT end
    return math.max(self.CATEGORY_HEIGHT, size + 9)
end

local catFont = setmetatable({}, { __mode = "k" })   -- category font strings changed, and their own font

-- Stretches a category button's artwork with the button (the textures have
-- fixed sizes in Blizzard's template; the text is already anchored both sides)
-- and gives it the category text size
local function StretchCategoryButton(btn)
    local normal, highlight = btn.NormalTexture, btn.HighlightTexture
    if not touched[btn] then
        touched[btn] = { highlightW = highlight and highlight:GetWidth() or 0, btnW = btn:GetWidth() or 0,
            highlightH = highlight and highlight:GetHeight() or 0, normalH = normal and normal:GetHeight() or 0,
            btnH = AHF.CATEGORY_HEIGHT }
        if normal then
            normal:ClearAllPoints()
            normal:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 0)
            normal:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 2, 0)
        end
    end
    local base = touched[btn]
    local h = AHF:CategoryHeight()
    if (btn:GetHeight() or 0) ~= h then btn:SetHeight(h) end
    local extra = h - base.btnH
    if normal and base.normalH > 0 then normal:SetHeight(base.normalH + extra) end
    if highlight and base.highlightW > 0 then
        local w = base.highlightW + (btn:GetWidth() or base.btnW) - base.btnW
        if w > 0 then highlight:SetWidth(w) end
        if base.highlightH > 0 then highlight:SetHeight(base.highlightH + extra) end
    end
    local text = type(btn.Text) == "table" and btn.Text or nil
    if text and text.SetFont then
        local size = AHF.db.categoryFontSize
        if not catFont[text] then
            local font, fsize, flags = text:GetFont()
            if font then catFont[text] = { font, fsize, flags } end
        end
        local b = catFont[text]
        if b then text:SetFont(b[1], size == 0 and b[2] or size, b[3]) end
    end
end

function AHF:StretchCategoryButtons()
    local list = self.frame and self.frame.CategoriesList
    local box = list and list.ScrollBox
    if not AHF.HasRows(box) then return end
    -- Nothing to change at Blizzard's own width and text, unless changed before
    local changed = self.db.sidebarWidth ~= self.BLIZZARD_SIDEBAR or self.db.categoryFontSize ~= 0
    if not changed and not self.sidebarStretched then return end
    self.sidebarStretched = true
    AHF.SetBoxRowHeight(box, self:CategoryHeight(), self.CATEGORY_HEIGHT)
    box:ForEachFrame(StretchCategoryButton)
end

function AHF:SetCategoryFontSize(size)
    local ok = false
    for _, v in ipairs(self.CATEGORY_FONT_SIZES) do if v == size then ok = true end end
    self.db.categoryFontSize = ok and size or 0
    self:StretchCategoryButtons()
    self:RefreshOptions()
end

local function Child(t, key)
    local v = type(t) == "table" and t[key]
    return type(v) == "table" and v or nil
end

-- A panel's background art has a fixed size in Blizzard's template (anchored
-- only at its top left); anchor its bottom right too, mirroring the top left
-- inset, so it fills the panel at any size
local function StretchBackground(panel)
    local bg = Child(panel, "Background")
    if not bg or not bg.GetPoint or touched[bg] then return end
    local _, _, _, x, y = bg:GetPoint(1)
    x, y = x or 0, y or 0
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -x, -y)
    touched[bg] = true
end

function AHF:StretchBackgrounds()
    local f = self.frame
    if not f then return end
    StretchBackground(Child(f, "CategoriesList"))
    StretchBackground(Child(f, "ItemSellFrame"))
    StretchBackground(Child(f, "CommoditiesSellFrame"))
    StretchBackground(Child(Child(f, "CommoditiesBuyFrame"), "BuyDisplay"))
    StretchBackground(Child(Child(f, "AuctionsFrame"), "SummaryList"))
    for _, e in ipairs(self.columnEntries or {}) do StretchBackground(e.list) end
end

-- The category list: the saved width, and as tall as the window allows (its
-- height is fixed in Blizzard's template, and the results list takes its
-- height from it)
function AHF:ApplySidebar()
    local f = self.frame
    local list = f and f.CategoriesList
    if not list then return end
    local w = self.db.sidebarWidth
    if math.abs((list:GetWidth() or 0) - w) > 0.5 then list:SetWidth(w) end
    if not touched[list] then touched[list] = { h = list:GetHeight() or 0 } end
    local base = touched[list].h
    if base > 0 then
        local h = base + (f:GetHeight() or self.BLIZZARD_HEIGHT) - self.BLIZZARD_HEIGHT
        if math.abs((list:GetHeight() or 0) - h) > 0.5 then list:SetHeight(h) end
    end
    self:StretchCategoryButtons()
end

---------------------------------------------------------------------------
-- One-time setup when the Auction House loads
---------------------------------------------------------------------------
local GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"

function AHF:SetupLayout(f)
    local T = ns.Theme
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetClampedToScreen(true)

    -- Corner grip: drag to resize
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel((f:GetFrameLevel() or 0) + 20)
    grip:SetNormalTexture(GRIP .. "Up")
    grip:SetHighlightTexture(GRIP .. "Highlight")
    grip:SetPushedTexture(GRIP .. "Down")
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        AHF.sizing = true
        f:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        if not AHF.sizing then return end
        AHF.sizing = false
        f:StopMovingOrSizing()
        NotUserPlaced(f)
        -- Sizing from the corner keeps the top left in place; keep it there
        if AHF.db.point then
            AHF.db.point = { "TOPLEFT", "BOTTOMLEFT", Round(f:GetLeft() or 0), Round(f:GetTop() or 0) }
        end
        AHF:SetSize(f:GetWidth() or AHF.db.width, f:GetHeight() or AHF.db.height)
    end)
    T.Tooltip(grip, "Resize", "Drag to make the Auction House bigger or smaller. Taller shows more rows.")
    self.grip = grip

    -- Title bar: drag to move (only takes the mouse while unlocked)
    local mover = CreateFrame("Frame", nil, f)
    mover:SetPoint("TOPLEFT", 60, -1)
    mover:SetPoint("TOPRIGHT", -28, -1)
    mover:SetHeight(22)
    mover:SetFrameLevel((f:GetFrameLevel() or 0) + 20)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function()
        AHF.moving = true
        f:StartMoving()
    end)
    mover:SetScript("OnDragStop", function()
        if not AHF.moving then return end
        AHF.moving = false
        f:StopMovingOrSizing()
        NotUserPlaced(f)
        AHF.db.point = { "TOPLEFT", "BOTTOMLEFT", Round(f:GetLeft() or 0), Round(f:GetTop() or 0) }
        AHF:ApplyLayout()
    end)
    T.Tooltip(mover, T.NAME, "Drag to move the Auction House. Lock it in place with /ahf lock or in the settings (/ahf).")
    self.mover = mover

    -- Put the saved layout back whenever Blizzard changes it
    local function Reapply()
        if not applying and not AHF.sizing and not AHF.moving then AHF:ApplyLayout() end
    end
    for _, method in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetScale" }) do
        hooksecurefunc(f, method, Reapply)
    end
    -- The category list follows the window's height, also while dragging the grip
    f:HookScript("OnSizeChanged", function() AHF:ApplySidebar() end)
    f:HookScript("OnShow", function()
        AHF:RememberBlizzardPoint()
        Reapply()
    end)
    if f.SetDisplayMode then hooksecurefunc(f, "SetDisplayMode", Reapply) end
    if type(UpdateUIPanelPositions) == "function" then
        hooksecurefunc("UpdateUIPanelPositions", function()
            if applying or not f:IsShown() then return end
            AHF:RememberBlizzardPoint(true)
            if AHF.db.point then Reapply() end
        end)
    end

    -- Category buttons are reused as the list scrolls; stretch each new layout
    local box = f.CategoriesList and f.CategoriesList.ScrollBox
    if box and box.RegisterCallback then
        pcall(box.RegisterCallback, box, "OnLayout", function() AHF:StretchCategoryButtons() end, AHF)
        pcall(box.RegisterCallback, box, "OnAcquiredFrame", function(_, btn)
            if AHF.sidebarStretched and btn and btn.SetHeight then btn:SetHeight(AHF:CategoryHeight()) end
        end, AHF)
    end
end
