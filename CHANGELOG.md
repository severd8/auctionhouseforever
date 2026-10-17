# Changelog

## 2.1.0

- **Disenchant value.** Weapons and armor that can be disenchanted (green, blue and purple) show one more tooltip line: **AHF Disenchant**. It's what the item is worth to disenchant: the chance of each dust, essence and shard, times how many you usually get, times its AHF Market price. One line, no clutter.
- If a material has no AHF price yet, it's counted at its vendor price and the value starts with **~**, so you know it's a rough guess. Scan once and the ~ goes away.

## 2.0.1

- **Scan button fixed.** The full scan button no longer covers the end of the search box. It's now a small red **Scan** button like the game's own Search button, in the gap before Filter. While it works it shows its progress (for example 45%).
- Your first scan with 2.0.0 read 57,610 listings of 2,808 different items in about 8 seconds, so it really does read the whole auction house.

## 2.0.0

A brand new addon under the same name. AuctionHouse Forever now keeps a history of auction house prices, so you know what things are really worth. (Versions 1.x were a window resizer; that addon is retired and its settings are not used.)

- **Full scan.** A **Full scan** button sits beside the auction house's Filter and Search buttons. It reads every listing in a few seconds and saves the prices, then says in chat how many listings and different items it read. If the auction house ever makes you wait between scans, set the wait under Settings and the button counts down.
- **Your searches count too.** Every search you make saves the prices it shows, and so does a full scan started from Auctionator.
- **Tooltips.** Items show **AHF Vendor** (what a vendor pays for one) and **AHF Market (seen N)**: the usual auction price for one, and how many were listed last time. The market price is the middle of the cheapest listings, ignoring silly prices at either end.
- **Per realm and faction.** Alliance and Horde keep separate prices, since their auction houses are separate.
- **Small saved file.** Each day is kept for two weeks, then joined into weeks, and anything older than a year is dropped. The work is spread out so the game never freezes.
- `/ahf` opens the window (prices saved, last scan, settings). `/ahf scan` starts a full scan at the auction house.
