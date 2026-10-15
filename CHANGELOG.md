## 1.3.5

- Fixed: the window flickered while dragging the **Scale** slider in the AH Forever tab. Scale now changes when you let go of the slider.
- Scale now goes up to 200%, for small game UI scales.

## 1.3.4

- Fixed: an error with Auctionator's tabs, and the **AH Forever** tab's place. The tab is now made the same way as Auctionator's (with the LibAHTab library), so it looks like them, sits in line after them, and switches like them.

## 1.3.3

- Fixed: the **AH Forever** tab now sits after Auctionator's tabs instead of between Auctions and Shopping.

## 1.3.2

- Fixed: the **AH Forever** tab was missing in 1.3.1, and `/ahf` did nothing while the Auction House was open. The tab uses the same template and size as the other tabs, and `/ahf` always opens the settings (as a window if the tab can't show).
- New: `/ahf debug` shows the version and where the tab is, to help with bug reports.

## 1.3.1

- Fixed: category text grew bigger every time the list redrew, and wouldn't size back down. Category text now goes up to 150%; a saved 200% goes back to Default.
- The **AH Forever** tab now looks like the other tabs and sits after the last one (after Auctionator's tabs).
- In the AH Forever tab, the logo and name are no longer hidden behind the NPC portrait.

## 1.3.0

- **Settings in the Auction House**: a new **AH Forever** tab after the other tabs (Auctionator's too) shows the settings right inside the Auction House. `/ahf` opens it while the Auction House is open; otherwise the settings open in their own window, as before.
- **Sort by our columns**: click the **iLvl**, **Req Lvl**, **Vendor** or **Type** header to sort the search results; click again to reverse. Clicking one of Blizzard's headers goes back to the game's sort.
- "Req" is now **Req Lvl**.
- Fixed: the category buttons' artwork now stretches to the full width of a wider category list.
- Row and category text sizes are now percentages of the game's own size (Default, 110% to 200%), so Default really is the game's size. Your 1.2 text sizes go back to Default.

## 1.2.2

- Fixed: an error when moving the mouse over the search results in 1.2.0 and 1.2.1.
- Fixed: the Columns button said "Filter".
- New: **Category text size** (Columns tab); the category buttons get taller with bigger text.
- Row text size now goes up to 20.

## 1.2.1

- Fixed: an error when opening the Auction House in 1.2.0.

## 1.2.0

- **Columns button** beside the search box, in the same style as Filter: tick columns on or off and move them left or right, for the list on screen.
- **New columns** on the search results: **iLvl**, **Req** (level needed to use it), **Type** (e.g. Cloth Head; starts hidden) and **Vendor** (what a vendor pays; green when the lowest buyout is below it). On an item's auctions: **Per unit** and **Seller**. Hide, move and resize them like any column.
- **Bigger rows**: Row text size now goes up to 16, and rows get taller with bigger text instead of squeezing it.
- "Lock the window" is now **Keep window in place**; your position is saved either way.

## 1.1.2

- Fixed: an error when changing **Row text size** before every list had been opened once.
- "Show & Order" tab name capitalized.

## 1.1.1

- Fixed: a taller window now makes the category list and the results list taller too, instead of leaving an empty area at the bottom.
- Fixed: the dark background behind the results and the category list now fills them at any size.
- Fixed: an error when opening the settings (`/ahf`).
- Cleaner **Show & Order** tab: one striped row per column with its switch and Left / Right buttons.

## 1.1.0

Columns your way.

- **Hide and show columns.** New **Show & Order** tab in the settings (`/ahf`): pick a list, then switch any column off or on. A hidden column comes back in its place when you turn it on again. The Name column always shows.
- **Reorder columns** with the arrows beside each column, for example Name first. Columns without a header (the favourite star) keep their place.
- Works on every list (Buy, Sell, Auctions), each with its own columns, saved for each character. Columns added by other addons (like Median) can be hidden and moved too; a new one appears after the column it belongs beside.
- **Row text size** (Columns tab): Default, or 9 to 14, for the text in every list's rows.
- **Show all, default order** puts one list back to Blizzard's columns. **Reset all columns** (and `/ahf columns`) now also shows hidden columns and puts the order back, as well as the widths. **Reset to default** includes all of it.

## 1.0.0

First release.

- **Resize the Auction House** by dragging the grip in its bottom right corner. The category list, the results and the tabs stretch with it, and a taller window shows more rows. It's never smaller than Blizzard's size or bigger than your screen.
- **Wider by default**: the window opens 200 pixels wider than Blizzard's, all of it for the Name column, so long item names stop getting cut off.
- **Move it** by dragging the title bar, and **lock** it in place (`/ahf lock`, or in the settings). Until you move it, it opens where Blizzard puts it.
- **Scale** the whole window from 60% to 150%.
- **Column widths**: drag the line between two column headers to resize a column; double-click it for the default width. Works on every list (Buy, Sell, Auctions) and on columns added by other addons. Saved for each character. The Name column never gets narrower than 150 pixels.
- **Category list width**: make the list of categories on the left wider.
- **Settings window** (`/ahf`, or Options → AddOns → AuctionHouse Forever) with hover help on every option, and a **Reset to default** button.
- Works alongside Auctionator and other Auction House addons: it only changes sizes and layout, never their tabs, columns or buttons, and it never buys, bids or posts anything.
