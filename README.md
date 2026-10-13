<p align="center"><img src="https://raw.githubusercontent.com/severd8/auctionhouseforever/main/art/logo.png" width="160" alt="AuctionHouse Forever logo"></p>

# AuctionHouse Forever

**A bigger, roomier Auction House: resize it, move it, scale it, and set up its columns your way.**

AuctionHouse Forever is an addon for **World of Warcraft: Forever**. It changes only the size and layout of the Auction House window (the category list on the left, the results on the right, the tabs at the bottom), so long item names stop getting cut off and you can see more results at once.

It works alongside Auctionator and other Auction House addons: their tabs, columns and buttons stay where they are.

---

## Features

- **Resizable.** Drag the grip in the bottom right corner. The category list, the results and the tabs stretch with the window, and a taller window shows more rows.
- **Wider by default.** The window opens 200 pixels wider than Blizzard's, and all of the extra room goes to the Name column.
- **Movable.** Drag the title bar to put the window anywhere. Lock it in place when you're happy with it.
- **Scale** the whole window from 60% to 150%.
- **Column widths.** Drag the line between two column headers to resize a column. Double-click the line for the column's default width. Works on every list (Buy, Sell, Auctions) and on columns added by other addons, like a Median price column. Saved for each character.
- **Hide, show and reorder columns** with the **Columns** button beside the search box (or the Show & Order tab). Columns from other addons too.
- **Extra columns**: **iLvl**, **Req Lvl**, **Type** and **Vendor** (click their headers to sort) (green when you could sell it to a vendor for more than the lowest buyout) on the search results; **Per unit** and **Seller** on an item's auctions.
- **Row text size** for every list; rows grow with bigger text.
- **Category list width and text size.** Make the list of categories on the left wider, and its text bigger.
- **Settings in their own tab** (**AH Forever**) at the bottom of the Auction House, with hover help on every option and a Reset to default button.

## Installation

1. Download the latest release.
2. Unzip it into your WoW: Forever `Interface\AddOns` folder so you end up with an `AddOns\AuctionHouseForever\` folder.
3. Restart the game, or type `/reload` if it's already running.

Then visit an auctioneer. The Auction House opens at its new size straight away.

## Using it

- **Resize** — drag the grip in the bottom right corner of the Auction House.
- **Move** — drag the title bar at the top. Lock it with `/ahf lock` or in the settings.
- **Resize a column** — point at the line between two column headers (it turns gold) and drag. Double-click the line to put that column back to its default width.
- **Hide, show or reorder columns** — click **Columns** beside the search box: tick a column on or off, or hover it for Move left / Move right. Or use the settings → **Show & Order** tab. The Name column always shows.
- **Open the settings** — click the **AH Forever** tab at the bottom of the Auction House, type `/ahf`, or go to **Options → AddOns → AuctionHouse Forever**.

### Settings (AH Forever tab)

| Tab | What's there |
|---|---|
| **Window** | Width, height and scale, keep the window in place, reset position |
| **Columns** | Category list width and text size, row text size, how many columns have their own width, reset all columns |
| **Show & Order** | For each list: show or hide each column, move it left or right, show all in the default order |
| **General** | Welcome screen, Reset to default, command list |

### Slash commands

| Command | Does |
|---|---|
| `/ahf` | Open or close the settings |
| `/ahf lock` · `/ahf unlock` | Lock or unlock the window's position |
| `/ahf reset` | Size, position and scale back to the defaults |
| `/ahf columns` | Every column shown, in the default order and width |
| `/ahf news` | Show the welcome / what's new window |

`/auctionhouseforever` works too.

## Good to know

- **It never buys, bids or posts anything.** Every purchase is still your own click on Blizzard's (or Auctionator's) buttons.
- **Size, position, scale and row text size** are shared by all your characters. **Columns** (widths, hidden, order) are saved for each character.
- Hiding a column only takes it off the screen: nothing is deleted, and other addons' columns come back when you show them again.
- Until you drag the window, it opens where Blizzard puts it.
- The window is never bigger than your screen, and the Name column never gets narrower than 150 pixels: if the window is too narrow, widened columns give the room back first.

## Troubleshooting

- **The window is off-screen or too big** — type `/ahf reset`.
- **Columns look wrong** — type `/ahf columns`.
- **Everything looks wrong** — **General** tab → **Reset to default** (click twice).

## Feedback and bug reports

Found a bug or have an idea? Please [submit it on GitHub](https://github.com/severd8/auctionhouseforever/issues/new/choose). A short form asks which tab you were on and for any error message, so issues can be fixed quickly. You'll need a free GitHub account. Otherwise, feel free to leave a comment on the CurseForge page.

## Support the addon

AuctionHouse Forever is free. If it saves you some squinting at the Auction House, you can [leave a small tip on Ko-fi](https://ko-fi.com/tauntmasterforever). Thank you!

## Also by me

- **TauntMaster Forever**: click a party member's bar to taunt their target off them. Free on CurseForge.
- **ToppedOff Forever**: reminds you when buffs, food, reagents, ammo or gear need topping off. Free on CurseForge.
- **Outfitter Forever**: the classic Outfitter gear manager, ported to WoW Forever. Free on CurseForge.
- **BattleText Forever**: scrolling combat text for your hits, heals and the damage you take. Free on CurseForge.

## License

MIT — see [LICENSE](LICENSE).
