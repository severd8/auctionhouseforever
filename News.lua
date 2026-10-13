-- Short "What's new" lines for the splash screen (Splash.lua), newest first.
-- Add an entry here with every release, matching the top version in CHANGELOG.md
-- (a test fails if they don't match).

local _, ns = ...
local AHF = ns.AHF

AHF.NEWS = {
    { version = "1.0.0", date = "2026-10-13", items = {
        "First release: drag the corner of the Auction House to resize it. Taller shows more rows.",
        "Move it by its title bar (lock it in the settings), and set its scale.",
        "Drag the lines between column headers to resize columns, and widen the category list.",
    } },
}
