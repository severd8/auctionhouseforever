# AuctionHouse Forever — developer notes

A price-history addon for **World of Warcraft: Forever** (interface 16001, Lua 5.1, the retail-style `Blizzard_AuctionHouseUI`). It saves auction house prices from full scans (`C_AuctionHouse.ReplicateItems`) and normal searches, per realm and faction, and shows them in item tooltips.

- Author: `severd8`. License: MIT.
- CurseForge project ID: **1742416** (in the `.toc` as `X-Curse-Project-ID`).
- Since 2.0.0 this repo and CurseForge project hold a new addon. Versions 1.0.0–1.4.0 were a different addon of the same name (an auction house window resizer, now retired; its files were removed in 2.0.0 and its old CurseForge files archived). Its saved variables (`AuctionHouseForeverDB`, `AuctionHouseForeverCharDB`) are no longer listed in the `.toc`, so the game drops them. The new addon starts at 2.0.0 because the 1.x tags already exist and a tag can only be pushed once.
- Written from scratch. It does the job of Auctionator / Auctioneer / TradeSkillMaster's price history but uses none of their code.
- Planned order (one release each): 2.0.0 scan and price database; 2.1.0 sharing prices between players over a hidden channel; then tooltips with history (3/14/30-day averages, trend, scans, age), the window (search, price graph, deals), posting help. Maybe later: data from an outside source merged in at login.

## Files

- `AuctionHouseForever.toc` — `## Version: @project-version@` is filled in by the packager from the git tag. `SavedVariables: AuctionHouseForeverData, AuctionHouseForeverSettings` (both account-wide).
- `Theme.lua` — **the shared look, the same file in all the Forever addons.** Copied from GatherPath Forever (1.10.0 version, with `opts.height` / `T.BodyHeight`) plus an `AuctionHouseForever` row in `BRANDS` (logo `Media\logo`). Copy that row to the other repos next time Theme.lua changes there.
- `Prices.lua` — the price math and saved format, plain Lua with no game calls (the tests load it on its own): `P.Encode`/`P.Decode`, `P.MarketValue`, `P.Summarize`, `P.Add`, `P.Join`, `P.Condense`, `P.Average`.
- `Core.lua` — settings (`AHF.DEFAULTS`), saved data (`LoadSaved`, `Realm`, `Records`, `Observe`, `Pack`, `Stats`), item keys (`KeyFor`, `KeyFromLink`), background jobs (`RunJob`, `Pause`, `JobRunning`), condensing at login (`CondenseAll`), tooltips (`TooltipLines`, `AddToTooltip`, `HookTooltips`), `/ahf`, events (`AHF:On(event, fn)`).
- `Scan.lua` — full scan (`StartFullScan`, `ReadFullScan`, `CheckScanTimeout`), searches (`RecordBrowse`, `RecordCommodity`, `RecordItem`), the Full scan button (`MakeScanButton`, `RefreshScanButton`).
- `News.lua` — "What's new" lines for the window's What's new tab, newest first. **Add an entry with every release**; its top version must match the top of `CHANGELOG.md` (a test checks this).
- `Options.lua` — the window (`T.Window`, `/ahf`): Prices (realm key, items saved, records, approximate saved size, last full scan with its listing and item counts, next scan), Settings (tooltip, scan chat line, wait between scans slider 0–60 min, 0 = "None"), What's new. `AHF.ui` keeps the widgets the tests use.
- `Media/logo.tga` — 128×128 32-bit TGA, the gold-ringed medallion (kept from 1.x). Sources in `art/`.
- `tests/` — `wowstub.lua` (fake game API: frames, time, realm, `C_Item.GetItemInfo`, `TooltipDataProcessor`, a fake `C_AuctionHouse` with replicate, browse, commodity and item search lists, `OpenAuctionHouse()`, `RunJobs()`), `run_tests.lua` (scenarios), `run.lua` (runner).

## Saved data

```
AuctionHouseForeverData = { v = 1, condensed = <day last condensed>, realms = {
    ["<GetRealmName()>-<UnitFactionGroup>"] = {
        items = { [itemKey] = "<records>" },
        lastFull = <time of the last full scan asked for or seen>,
        scans = { { t, listings, items, keys, noBuyout, secs }, ... newest first, at most 10 } } } }
AuctionHouseForeverSettings = { tooltip = true, scanChat = true, cooldown = 0 }
```

- Realm key: realm name plus faction. Tyler confirmed Forever's auction houses are faction-only (not shared).
- Item key: `"itemID"`, or `"itemID:suffix"` when the random suffix isn't 0. From links it's the 7th number after `item:` (`item:id:enchant:gem1:gem2:gem3:gem4:suffix:...`); from search results `itemKey.itemSuffix`. **Unconfirmed in game that these two are the same number.** The tooltip falls back to the plain item ID when a suffixed key has no data. Item level is not part of the key.
- Records: one string per item, records split by `;`, fields by `,`, in base 36: `d` day (UTC days since 1970), `s` span (1 day or 7 = week starting Monday), `m` lowest price (copper per item), `v` market value (0 = none yet), `q` quantity listed in the newest data, `n` scans behind the market value, `t` time of the newest data. Sorted oldest first. Broken records are skipped on decode.
- While the game runs, an item's string is decoded into a table on first use and stays a table; `Pack()` turns tables back into strings on `PLAYER_LOGOUT`. Login only reads strings (fast), and the condense job decodes each once a day.
- Adding (`P.Add`): one record per item per day. Lowest price = lowest seen that day. Market = running average of the day's market values, weighted by `n`. A full scan or a full search result counts as a scan (`n + 1`); a search within 10 minutes (`P.SEARCH_GAP`) of the record's newest data blends into the market value without counting again; browse results and partial search results only lower the lowest price and set the quantity. `q` and `t` come from the newest data.
- Condensing (`P.Condense`, run by `CondenseAll` in a background job at login, once a day): days older than 14 (`KEEP_DAILY`) join the week they're in (`P.WeekStart`; lowest of the lows, market weighted by scans, quantity averaged, scans summed, newest time); anything that ends more than 365 days ago (`KEEP_DAYS`) is dropped. An item with no records left is removed.
- Size: about 30–40 bytes per record. With ~3,000 items, 14 days plus 52 weeks each would be at most about 6 MB; real items have far fewer days with data. The window's Prices tab shows the current size. **Load time in game not measured yet.**
- Outside data (sharing in 2.1.0, maybe a data file later) can merge whole records with `P.Join` / `P.Add`; that's why records carry their own scan counts and times.

## Market value (`P.MarketValue`)

Listings are `{ price per item, quantity }`. Each item in a stack counts once. Take the middle price of the cheaper half of all items (`ref`), drop prices more than 3x above or below `ref` (`P.OUTLIER`), take the cheapest 30% of the items left (`P.CHEAP_SHARE`, at least one), and return their middle price. Basing `ref` on the cheaper half means a pile of overpriced listings doesn't push out the real prices, and a few listings at 1 copper don't become the price.

## Full scan

- `C_AuctionHouse.ReplicateItems()`, then `REPLICATE_ITEM_LIST_UPDATE`. `GetNumReplicateItems()`, and for `i = 0 .. n-1` (0-based) `GetReplicateItemInfo(i)` (3rd return `count`, 10th `buyoutPrice`, 17th `itemID`) and `GetReplicateItemLink(i)`. Price per item = `ceil(buyoutPrice / count)`; listings with no buyout are counted but not priced. Checked in Forever's `AuctionHouseDocumentation.lua`: none of these have `SecretReturns`. **Unconfirmed in game: that `buyoutPrice` is for the whole stack** (as in Classic), not per item.
- Reading runs as a job: 50 listings between `Pause()` checks, 20 items between them while summing up. `AHF.BUDGET` = 8 ms per frame (`debugprofilestop`).
- Chat after a scan: "N listings of M different items (K with only a bid). Prices saved for X items." Confirmed in game with 2.0.0: 57,610 listings of 2,808 different items in about 8 s, so Auctionator's "2784 items" counts different items and the replicate list is the whole auction house.
- Wait between scans: Tyler found Forever allows a second full scan straight away, so `cooldown` defaults to 0 (no countdown). There is no API that reports a wait. If one appears, the Settings slider sets it and the button counts down (`ScanWait`, `lastFull`).
- No answer within 60 s (`SCAN_TIMEOUT`) puts the scan back to idle with a chat line. Closing the auction house while waiting stops it.
- `REPLICATE_ITEM_LIST_UPDATE` without our own request (Auctionator's full scan, Tyler said yes to using them) is read too, unless one was read in the last 60 s (`SCAN_REPEAT`), in case the event fires more than once for one scan.
- The button (since 2.0.1): a `UIPanelButtonTemplate` button (the template Blizzard's Search button inherits), `AHF.SCAN_BUTTON_W` = 80 x 22, text "Scan" / "..." (waiting) / "45%" (reading) / "m:ss" (wait left), `Disable()`d while busy, own OnEnter tooltip with `SetMotionScriptsWhileDisabled(true)`. Parented to `AuctionHouseFrame.SearchBar` (so it shows only with the Buy tab's search bar), `RIGHT` to `SearchBar.FilterButton`'s `LEFT` at -10 (the same gap Blizzard leaves between Filter and Search). The gap there is about 100 units: the search bar is 618 wide, the search box 241 from just after the 32-wide favorites button, Search 132. Nothing of Blizzard's is moved or scripted. In 2.0.0 it was a 110-wide `T.FlatButton` at -8, which covered the right end of the search box in game (Tyler's screenshot) and didn't match the auction house's buttons; Tyler picked the small Search-style button.

## Searches

- `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED` (`GetBrowseResults()`) and `AUCTION_HOUSE_BROWSE_RESULTS_ADDED` (payload): `minPrice` and `totalQuantity` per `itemKey`.
- `COMMODITY_SEARCH_RESULTS_UPDATED(itemID)`: `GetNumCommoditySearchResults` / `GetCommoditySearchResultInfo(itemID, i)` (`unitPrice`, `quantity`). `ITEM_SEARCH_RESULTS_UPDATED(itemKey)`: `GetNumItemSearchResults` / `GetItemSearchResultInfo(itemKey, i)` (`buyoutAmount`, `quantity`; price per item = `ceil(buyoutAmount / quantity)`). **Unconfirmed: `buyoutAmount` for the whole auction rather than per item.** With `HasFullCommoditySearchResults` / `HasFullItemSearchResults` true it counts as a scan of that item (market value); otherwise just the lowest price.

## Tooltips

`TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)` (in Forever's `TooltipDataHandler.lua`; falls back to `GameTooltip:HookScript("OnTooltipSetItem")`), `tooltip:GetItem()` for the link. Lines, per one item (Tyler's choice), labelled "AHF" (Tyler's wording):
- `AHF Vendor`: 11th return of `C_Item.GetItemInfo` (`sellPrice`, no `SecretReturns`), when above 0.
- `AHF Market (seen N)`: the newest record's market value, or its lowest price when there's no market value; N = its quantity listed.

## Tests

`lua5.1 tests/run.lua` (also run by GitHub Actions on every push and before every release). Covers: base 36 and the saved format (with broken data), market value (one listing, cheapest share, low and high outliers, a pile of overpriced, quantities), adding (same day, browse, the 10-minute search rule, order), condensing (days kept, weeks, lowest kept, scans not lost, a year), averages, item keys and money text, the full scan (closed auction house, 3,000 listings over several frames, counts, suffixes, bid-only, the optional wait, timeout, Auctionator's scans, repeats ignored), searches (commodity full and partial, item, browse), tooltips (lines, fallbacks, off), realms and factions, the window, saving and loading, broken saved data, condensing at login in the background, and News matching the changelog.

Mutation checks done for 2.0.0 (each made a test fail, then restored): outlier factor off, outlier middle taken from all listings instead of the cheaper half, `Pause` not yielding, condensing never joining days, searches always counting as scans.

Mutation check for 2.0.1: the button never disabled (the waiting test failed).

**Seen in game (2.0.0)**: the full scan (57,610 listings, ~8 s), AHF Vendor and AHF Market (seen N) in bag tooltips with sensible values (Linen Cloth 13c / 19c, seen 13,465). AHF Vendor reads `sellPrice` from `C_Item.GetItemInfo`; for Minor Mana Oil it shows 5s while the game's own Sell Price line says 2s (Auctionator's Vendor line also shows 5s), left as is.

**Not yet seen in game**: the 2.0.1 Scan button fitting the gap before Filter (and next to Auctionator's additions); that `buyoutPrice` (replicate) and `buyoutAmount` (item search) are whole-stack prices; the AHF lines in tooltips (bags, auction results, links in chat); the suffix keys matching between links and search results; the saved file size and login time after a few weeks.
