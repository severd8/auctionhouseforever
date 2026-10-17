-- Short "What's new" lines for the window's What's new tab, newest first.
-- Add an entry here with every release, matching the top version in CHANGELOG.md
-- (a test fails if they don't match).

local _, ns = ...
local AHF = ns.AHF

AHF.NEWS = {
    { version = "2.4.2", date = "2026-10-17", items = {
        "/ahf share shows what price sharing is doing: channel, scan to pass on, messages sent and heard, and from whom.",
    } },
    { version = "2.4.1", date = "2026-10-17", items = {
        "Resale options: money boxes with coin icons, wide enough for two digits of silver and copper.",
    } },
    { version = "2.4.0", date = "2026-10-17", items = {
        "Price sharing: full scans go to other AHF players on your realm and faction, on a hidden channel, so you get fresh prices without scanning.",
        "Prices far from what you already have (over 10x) are left out. Turn sharing off in Settings.",
    } },
    { version = "2.3.2", date = "2026-10-17", items = {
        "The Scan button counts down the auction house's 15 minute wait between full scans.",
    } },
    { version = "2.3.1", date = "2026-10-17", items = {
        "Resale tab: no more rows with a blank item name.",
    } },
    { version = "2.3.0", date = "2026-10-17", items = {
        "Resale options: minimum profit, minimum percent, seen N times in X days, maximum price.",
    } },
    { version = "2.2.1", date = "2026-10-17", items = {
        "Resale tab: no more blank item names, no empty Seller column, top line clear of the portrait, Market each.",
        "Tooltips show the 7 and 14 day averages only once there's enough history.",
    } },
    { version = "2.2.0", date = "2026-10-17", items = {
        "Resale tab in the auction house: listings below their usual price, with profit and percent (after the 5% cut).",
        "Click a Resale row to search for it on the Buy tab; click a header to sort.",
        "Tooltips show how many scans over how many days, and the 14, 7 and 3 day averages.",
    } },
    { version = "2.1.0", date = "2026-10-17", items = {
        "AHF Disenchant in tooltips: what a weapon or armor piece is worth disenchanted, from AHF Market prices.",
        "A ~ in front means some materials have no price yet (counted at vendor price).",
    } },
    { version = "2.0.1", date = "2026-10-17", items = {
        "The full scan button is now a small red Scan button like Search, and no longer covers the search box.",
    } },
    { version = "2.0.0", date = "2026-10-17", items = {
        "A brand new addon: AuctionHouse Forever now keeps a history of auction house prices.",
        "Full scan button beside Search: reads every listing and saves the prices.",
        "Your normal searches save prices too, and so do Auctionator's full scans.",
        "AHF Vendor and AHF Market (seen N) lines in item tooltips.",
        "Prices are kept per realm and faction; old days are joined into weeks to keep the saved file small.",
        "/ahf opens the window, /ahf scan starts a full scan.",
    } },
}
