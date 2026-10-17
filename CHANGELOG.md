# Changelog

## 2.4.1

- **Resale options look tidier.** The money boxes now look like the game's own: a box, then its gold, silver or copper coin. The silver and copper boxes are wide enough for two digits (typing 30 silver showed only "3"), and numbers sit on the right like money does.

## 2.4.0

- **Price sharing.** Players with AuctionHouse Forever now share their full scans with each other, so you get fresh prices without scanning yourself. It all happens on a hidden channel that never shows in your chat.
  - After a full scan, the addon tells everyone listening. Anyone whose prices are older asks for it, and one copy goes out to all of them. It takes a few minutes, because the game only allows about one addon message a second.
  - When you log in, it asks whether anyone has newer prices than yours.
  - Only your own realm and faction.
  - A shared price more than 10 times higher or lower than what you already have is left out, so one bad sender can't spoil prices you know.
  - Chat says when prices arrive: "prices for 2,800 items from Bob's scan (3 min old)".
- **Window.** The Prices tab shows the last prices you got from others; Settings has a switch to turn sharing off.

## 2.3.2

- **Full scan wait.** The auction house only sends a full scan once every 15 minutes. The Scan button now counts down to the next one (after a scan from Auctionator too), instead of letting you click and then saying the scan didn't come.

## 2.3.1

- **Resale tab:** fixed rows with a blank item name. The game sometimes sends an item's link with no name in it; those rows now show "Loading item..." and then the item's name.

## 2.3.0

- **Resale options.** A strip at the top of the Resale tab sets what gets listed, and remembers it:
  - **Min profit** (gold, silver, copper): 1 silver to start with.
  - **Min %**: 10% to start with.
  - **Seen N times in X days**: only items AHF has seen in at least that many scans lately, so one odd price can't fool it. 3 times in 7 days to start with; the top line says how many more deals this hides.
  - **Max price**: nothing dearer than this. Blank means no limit.
- The list updates as soon as you press Enter or click away from a box.

## 2.2.1

- **Resale tab fixes.** The line at the top no longer hides behind the portrait. Items the game hadn't loaded yet showed a blank name; they now show "Loading item..." and fill in a moment later, and clicking them still finds them. The Seller column is gone (the game doesn't tell addons who's selling), so item names get more room. Market is now **Market each**, since Buyout is for the whole stack. When there are more than 500 deals, the top line says it's showing the best 500.
- **Tooltip averages.** The 7 and 14 day averages only show once there's more than 3 and 7 days of prices, so a new item doesn't show the same number three times.

## 2.2.0

- **Resale tab.** A new **Resale** tab at the bottom of the auction house lists the listings from your last full scan that sell below their usual price, with the profit and percent profit if you buy and post them again. The profit already takes off the auction house's 5% cut. Only deals worth at least 1 silver and 10% are listed, best first. Click a column header to sort by it. Click a row to search for that item on the Buy tab, then buy it with the game's own button.
- **Price history in tooltips.** Under AHF Market, a short history: **AHF seen in N scans over D days**, then the **14, 7 and 3 day averages**. **AHF Disenchant** is now the last line.

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
