# AuctionHouse Forever — developer notes

An addon for **World of Warcraft: Forever** (interface 16001, client 1.60.x) that makes the retail-style Auction House (`Blizzard_AuctionHouseUI`, `AuctionHouseFrame`) resizable, movable and scalable, with draggable column widths and an adjustable category list. It changes only layout, size and styling.

- Author: `severd8`.
- CurseForge project ID: **1742416** (in the `.toc` as `X-Curse-Project-ID`).
- License: MIT.

## Files

- `AuctionHouseForever.toc` — `## Version: @project-version@` is filled in by the packager from the git tag. Don't hard-code a version.
- `Theme.lua` — **the shared look, the same file in all the Forever addons** (TauntMaster, ToppedOff, Outfitter, BattleText, AuctionHouse). Change it in one repo, then copy it to the others. It finds its own addon's name and logo from the folder name, in `BRANDS`; this repo added the `AuctionHouseForever` entry, so copy it to the other four. Loaded first. Don't use Blizzard templates in a window with this look.
- `Core.lua` — settings (`DEFAULTS`, `LIMITS`, `PrepareSettings`, `PrepareCharSettings`, `ColumnState`), resets, setup when `Blizzard_AuctionHouseUI` loads (`OnAuctionHouseLoaded`), slash commands (`/ahf`, `/auctionhouseforever`, list in `COMMANDS`) and events.
- `Layout.lua` — the window: size and corner grip, moving by the title bar, scale, lock, the category list's width (`ApplySidebar`, `StretchCategoryButtons`). `ApplyLayout()` puts every saved setting on the frame; call it freely.
- `Columns.lua` — column widths: divider grips on each list's header row, saved widths put back after every layout (`ArrangeColumns`), `ResetColumns`. The lists are in `COLUMN_LISTS` (key and path under `AuctionHouseFrame`).
- `Options.lua` — the settings window (`Theme.Window`: Window, Columns, General tabs) and the Interface Options entry (`RegisterSettingsCategory`: a page with an "Open settings" button). Every control gets hover help through `TipAll`; a new control must too (a test checks). "Reset to default" needs a second click within 4 seconds (`ConfirmButton`). `AHF.optionsRefresh` repaints the open window when a setting changes elsewhere.
- `News.lua` — short "What's new" lines for the splash screen, newest first. **Add an entry with every release**; its top version must match the top of `CHANGELOG.md` (a test checks this).
- `Splash.lua` — welcome / what's new window. Shows once per new `News.lua` version (and on first install) unless turned off; `/ahf news` opens it.
- `Media/logo.tga` — 128×128, 32-bit TGA with alpha: a gold coin and a gavel in the gold ring, the same medallion style as the other Forever addons. Used through `Theme.LOGO` everywhere. Sources in `art/` (not shipped): `icon.svg` (the medallion), `logo.svg` (the framed logo with the name on a banner) and `logo.png` (1024×1024, for the CurseForge project icon and the README). Re-export `Media/logo.tga` from `icon.svg` if the logo changes.
- `tests/` — offline test suite (not shipped). `wowstub.lua` fakes the WoW API and the parts of the Auction House the addon touches (`FakeAuctionHouse()`, a table builder with Blizzard's width math); `run_tests.lua` holds the scenarios; `run.lua` runs them.
- `CHANGELOG.md` — release notes shown on CurseForge. Newest version at the top.
- `CURSEFORGE.md` — the CurseForge project description, pasted by hand (not shipped).
- `.pkgmeta` — packager config (folder name, changelog, files to leave out of the download).
- `.github/workflows/test.yml` — runs the tests on every push. `release.yml` — on a `v*` tag, runs the tests, checks the project ID, then packages and uploads to CurseForge (needs the `CF_API_KEY` secret). `add-to-project.yml` — adds new issues to the project board (needs the `ADD_TO_PROJECT_PAT` secret).

## How Blizzard's Auction House is built (checked against 12.x Blizzard_AuctionHouseUI)

- `AuctionHouseFrame` (`AuctionHouseFrameMixin`, `PortraitFrameTemplate`), 800×538. It's in `UIPanelWindows` as `"doublewide"`, so the panel manager (`UpdateUIPanelPositions`) moves it every time it opens.
- Children are anchored to the frame's edges, so they stretch with it: `SearchBar`, `CategoriesList` (168 wide), `BrowseResultsFrame` (its `ItemList` fills to the right), `ItemBuyFrame`, `CommoditiesBuyFrame`, `ItemSellFrame` / `ItemSellList`, `CommoditiesSellFrame` / `CommoditiesSellList`, `AuctionsFrame` (`AllAuctionsList`, `BidsList`, `ItemList`, `CommoditiesList`), the bottom tabs.
- Every list is an `AuctionHouseItemListTemplate`: `HeaderContainer`, `ScrollBox`, and `tableBuilder` (made on first show). `SetTableBuilderLayout(fn)` marks it dirty; `UpdateTableBuilderLayout()` runs `fn(tableBuilder)` (columns added with `AddFixedWidthColumn` / `AddFillColumn`), `SetTableWidth(ScrollBox:GetWidth())`, `Arrange()`. Blizzard **doesn't** arrange again when the list changes size; `Columns.lua` does (ScrollBox `OnSizeChanged`).
- Browse columns: Price 146 (168 with copper), Name = fill, Lvl 55 (some categories), Available 83 (60 with copper), favourite star 29 (no header).
- Category buttons: 132 wide, `NormalTexture` 136×32 (fixed size), `HighlightTexture` centred. The linear ScrollBox view stretches the buttons to the list's width; their art is stretched by `StretchCategoryButton`.

## Rules the code follows

- **Lua 5.1.** No `goto`, `//`, bitwise operators or `_ENV`.
- **Never buy, bid, post or cancel.** Bid and buyout stay the player's own clicks. The addon doesn't call `C_AuctionHouse` at all (a test checks the source).
- **Coexist.** Only sizes, anchors and widths change. Columns are never removed, replaced or reordered; tabs (Auctionator's Shopping / Selling / Cancelling / Auctionator) and buttons from other addons are left alone. Columns are known by their header text, so columns added by other addons (e.g. Median) are resized like Blizzard's.
- **Don't taint Blizzard's tables.** Only `hooksecurefunc` (post-hooks) and `HookScript`; never assign fields on Blizzard frames or replace their functions. Original sizes of Blizzard textures are kept in a weak table in `Layout.lua` (`touched`), not on the frames. Calling widget methods and the table builder's column methods (`SetFixedConstraints`, `Arrange`) is fine.
- **Load-on-demand.** Setup runs on `ADDON_LOADED` for `Blizzard_AuctionHouseUI`, or at our own `ADDON_LOADED` / `PLAYER_LOGIN` if another addon (Auctionator) already loaded it. `OnAuctionHouseLoaded` runs once.
- **Blizzard sets the size again** (tab switches, `OnShow`, the panel manager): `SetupLayout` post-hooks `SetSize`, `SetWidth`, `SetHeight`, `SetScale`, `SetDisplayMode`, `OnShow` and `UpdateUIPanelPositions`, and each puts the saved layout back. The `applying` flag stops our own calls from re-triggering the hooks; nothing is re-applied while the grip or title bar is being dragged.
- **Position.** `db.point` is nil until the window is dragged (Blizzard's place is used). Once dragged it's `{ "TOPLEFT", "BOTTOMLEFT", left, top }` on UIParent, in the frame's own scale; `SetScale` converts it so the top left corner stays put. `RememberBlizzardPoint` keeps Blizzard's last place so Reset can move the window back at once (calling `UpdateUIPanelPositions` ourselves would taint the panel manager). `SetUserPlaced(false)` after every drag, so the game's layout cache doesn't fight the saved position.
- **Size limits**: `LIMITS.width` / `LIMITS.height`, and never bigger than the screen at the current scale (`SizeBounds`).
- **Column widths.** Each fixed column's Blizzard width is recorded the first time that column object is seen (`seen`, weak keys; a new layout makes new column objects), before anything changes it, so a reset goes back to it. A divider left of the fill column resizes the column on its left; right of it, the column on its right, so the divider follows the mouse. Dragging stops when Name would drop under `NAME_MIN`; a window made narrower afterwards takes room back from widened columns first (towards Blizzard's width) without changing the saved widths. Columns an addon adds right after Blizzard's layout get their saved width a frame later (`C_Timer.After(0)`).
- **Saved settings** are checked on load: a value whose type doesn't match its default goes back to the default, numbers are brought inside `LIMITS`, a broken position or column entry is dropped.
- **Chat lines** all start with `Theme.CHAT_PREFIX`: use `AHF.Print`, not `print`.

### Saved variables

- `AuctionHouseForeverDB` (account): `width`, `height`, `scale`, `locked`, `point`, `sidebarWidth`, `showSplash`, `lastSeenVersion`, `rowFontSize` (reserved for v1.1), `schema`.
- `AuctionHouseForeverCharDB` (per character): `columns[listKey] = { widths = { [name] = px }, hidden = {}, order = {} }`, `schema`. `hidden` and `order` are reserved for v1.1.

### Planned for v1.1

- **Hide / show and reorder columns**: per list, `ColumnState(key).hidden` and `.order`, applied in `ArrangeColumns` next to the widths (a hidden column can be given width 0 and its cells hidden; reordering means moving entries in the table builder's column list before `Arrange`, after Blizzard's layout function). A Columns tab section listing each list's columns by name.
- **Row font size**: `db.rowFontSize` (0 = the game's own), applied to the list cells' font strings as rows are laid out.

## Testing

Run from the repo root before every commit:

    lua5.1 tests/run.lua

It loads the addon against the fake WoW API and Auction House and covers: loading before and after the Auction House, the size coming back after Blizzard resets it, the panel manager, moving, lock, the corner grip, size and scale limits, dragging dividers (limits, Name minimum, double-click), widths kept across layouts, a column from another addon (Median) and one added late, separate lists, the category list, every settings control, the two-click reset, the Interface Options button, slash commands, damaged saved settings, and that nothing buys, bids or posts. Add a scenario to `tests/run_tests.lua` for any new feature.

Things only testable in game: the real frame names on Forever's client (`/fstack` over the Auction House), how the Blizzard art looks when stretched, Auctionator's tabs at bigger sizes, and anything the panel manager does when other windows open beside the Auction House.

## Releasing

1. Make the change, run the tests, add a new section at the top of `CHANGELOG.md` (e.g. `## 1.0.1`), and add the matching entry at the top of `News.lua`.
   If the change shows on the CurseForge project page (features, options, commands), update `CURSEFORGE.md` too (the README, adjusted: no logo, a short install note, full links), and **give the whole updated file in the reply as one Markdown code block**, ready to paste into the project's description (Edit project → Description, Markdown editor). Do this every time the file changes, without being asked. The packager only uploads `CHANGELOG.md` with each file; the description never changes on its own.
2. Commit and push to `main`. The **Tests** workflow must be green.
3. Tag and push the tag: `git tag v1.0.1 && git push origin v1.0.1`. Push a tag only once: pushing it again uploads a second file. Tags containing `beta` or `alpha` upload as Beta/Alpha files.
4. The **Package and release** workflow runs the tests again, then uploads to CurseForge. Check the Actions tab for a green check and the CurseForge Files page (new files go through CurseForge review).

A tag publishes to players, so only tag a tested commit.
