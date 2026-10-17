-- Short "What's new" lines for the window's What's new tab, newest first.
-- Add an entry here with every release, matching the top version in CHANGELOG.md
-- (a test fails if they don't match).

local _, ns = ...
local AHF = ns.AHF

AHF.NEWS = {
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
