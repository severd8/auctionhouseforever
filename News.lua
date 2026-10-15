-- Short "What's new" lines for the splash screen (Splash.lua), newest first.
-- Add an entry here with every release, matching the top version in CHANGELOG.md
-- (a test fails if they don't match).

local _, ns = ...
local AHF = ns.AHF

AHF.NEWS = {
    { version = "1.3.3", date = "2026-10-15", items = {
        "Fixed: the AH Forever tab sits after Auctionator's tabs.",
    } },
    { version = "1.3.2", date = "2026-10-15", items = {
        "Fixed: the AH Forever tab was missing and /ahf didn't open the settings.",
    } },
    { version = "1.3.1", date = "2026-10-13", items = {
        "Fixed: category text growing on its own. The AH Forever tab matches the others and sits last.",
    } },
    { version = "1.3.0", date = "2026-10-13", items = {
        "Settings in their own AH Forever tab inside the Auction House.",
        "Click the iLvl, Req Lvl, Vendor or Type header to sort the results.",
        "Category buttons fill the list's width. Text sizes are now 110% to 200% of the game's.",
    } },
    { version = "1.2.2", date = "2026-10-13", items = {
        "Fixed: an error when moving the mouse over the search results, and the Columns button's name.",
        "Category text size, and row text up to 20 (Columns tab).",
    } },
    { version = "1.2.1", date = "2026-10-13", items = {
        "Fixed: an error when opening the Auction House.",
    } },
    { version = "1.2.0", date = "2026-10-13", items = {
        "Columns button beside the search box: tick columns on or off and move them.",
        "New columns: iLvl, Req, Type and Vendor (green = sells to a vendor for more); Per unit and Seller.",
        "Bigger rows: text size up to 16, and rows grow with it.",
    } },
    { version = "1.1.2", date = "2026-10-13", items = {
        "Fixed: an error when changing Row text size.",
    } },
    { version = "1.1.1", date = "2026-10-13", items = {
        "Fixed: taller windows show more rows, backgrounds fill the lists, and /ahf opens without an error.",
        "Cleaner Show & Order tab.",
    } },
    { version = "1.1.0", date = "2026-10-13", items = {
        "Hide, show and reorder columns: new Show & Order tab in the settings (/ahf).",
        "Row text size for every list (Columns tab).",
    } },
    { version = "1.0.0", date = "2026-10-13", items = {
        "First release: drag the corner of the Auction House to resize it. Taller shows more rows.",
        "Move it by its title bar (lock it in the settings), and set its scale.",
        "Drag the lines between column headers to resize columns, and widen the category list.",
    } },
}
