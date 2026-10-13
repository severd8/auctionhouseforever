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
