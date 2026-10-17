<p align="center"><img src="https://raw.githubusercontent.com/severd8/auctionhouseforever/main/art/logo.png" width="160" alt="AuctionHouse Forever logo"></p>

# AuctionHouse Forever

**Know what things are really worth: a history of auction house prices for World of Warcraft: Forever.**

AuctionHouse Forever saves the prices you see at the auction house, from full scans and from your normal searches, and shows them in item tooltips. It keeps a day-by-day history per realm and faction, so later versions can show trends, a price graph, deals and posting prices.

It works alongside Auctionator: a full scan started from Auctionator fills AuctionHouse Forever's prices too. It never buys, bids or posts anything for you.

---

## Features

- **Full scan.** Click the red **Scan** button beside the auction house's Filter and Search buttons. It reads every listing in a few seconds and saves the prices. Chat tells you how many listings and different items it read.
- **Your searches count too.** Every search you make saves the prices it shows, and so does a full scan started from Auctionator.
- **Tooltips.** Items show **AHF Vendor** (what a vendor pays for one) and **AHF Market (seen N)**: the usual auction price for one, and how many were listed last time.
- **Price history.** Under AHF Market: **AHF seen in N scans over D days**, then the 14, 7 and 3 day averages.
- **Resale tab.** A **Resale** tab at the bottom of the auction house lists the listings from your last full scan that sell below their usual price (the 14 day average), with profit and percent profit after the auction house's 5% cut. Sort by any column; click a row to search for it on the Buy tab, then buy with the game's own button. Options at the top: minimum profit, minimum percent, seen at least N times in X days, maximum price.
- **Disenchant value.** Weapons and armor that can be disenchanted show **AHF Disenchant**: each material's chance, times how many you usually get, times its AHF Market price, in one line. A **~** in front means some materials have no price yet.
- **A fair market price.** The middle price of the cheapest listings, ignoring silly prices at either end, so one listing at 1 copper or 999 gold can't drag it.
- **Per realm and faction.** Alliance and Horde keep separate prices, since their auction houses are separate.
- **Small saved file.** Each day is kept for two weeks, then joined into weeks; anything older than a year is dropped. Big jobs are spread out so the game never freezes.

## Installation

1. Download the latest release.
2. Unzip it into your WoW: Forever `Interface\AddOns` folder so you end up with an `AddOns\AuctionHouseForever\` folder.
3. Restart the game, or type `/reload` if it's already running.

Then visit an auctioneer and click **Scan**.

## Slash commands

| Command | Does |
|---|---|
| `/ahf` | Open or close the window (prices saved, last scan, settings, what's new) |
| `/ahf scan` | Start a full scan (at the auction house) |
| `/ahf tooltip` | Turn the tooltip prices on or off |

## Settings

| Tab | What's there |
|---|---|
| **Prices** | Your realm and faction, how many items have prices, the saved file's size, the last full scan |
| **Settings** | Tooltip prices on or off, the chat line after a scan, a wait between full scans (none to start with) |
| **What's new** | The changes in each version |

## Feedback and bug reports

Found a bug or have an idea? Please [submit it on GitHub](https://github.com/severd8/auctionhouseforever/issues/new/choose). You'll need a free GitHub account. Otherwise, feel free to leave a comment on the CurseForge page.

## Support the addon

AuctionHouse Forever is free. If it helps you sell smarter, you can [leave a small tip on Ko-fi](https://ko-fi.com/tauntmasterforever). Thank you!

## Also by me

- **TauntMaster Forever**: click a party member's bar to taunt their target off them.
- **ToppedOff Forever**: reminds you when buffs, food, reagents, ammo or gear need topping off.
- **Outfitter Forever**: the classic Outfitter gear manager, ported to WoW Forever.
- **BattleText Forever**: scrolling combat text for your hits, heals and the damage you take.
- **GatherPath Forever**: the shortest gathering route through your herb and ore nodes.

All free on CurseForge.

## Credits

The Resale tab uses **LibAHTab** by plusmouse (MIT licence, included in `Libs/LibAHTab`), the library Auctionator makes its tabs with, so the tabs line up. **LibStub** is public domain.

## License

MIT — see [LICENSE](LICENSE).
