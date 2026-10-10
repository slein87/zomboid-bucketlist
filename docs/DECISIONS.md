# Decisions and assumptions

Every decision comes with its reason. Assumptions are marked as such and can be changed later.

**D1. Folder and repo.** Bucketlist has its own Git repo. The game loads the mod through the symlink
`~/Zomboid/mods/Bucketlist`, which points to `mod/Bucketlist`. This works because `getAllModFoldersAux` follows symlinks. Automated in-game tests
run with their own user folder `.cache/zomboid`, so the normal `~/Zomboid` stays untouched.

**D2. Mod layout.** `mod.info` and all files live in `common/`. There is no version folder,
`versionMin=42.21`, and no `versionMax`. A later folder `42.NN/` would only hold changed files and
would not need its own `mod.info`. Lua lives only under `client/Bucketlist/`; there is no `shared/`
or `server/` code. Images live under `media/ui/Bucketlist/` and are named `Bucketlist_*.png`, because
`getTexture` looks up the bare file name first.

**D3. Namespace.** One global table `Bucketlist`. Modules are loaded with `require "Bucketlist/<Name>"`
and return their table. ModData key `Bucketlist`, mod options ID `Bucketlist`, translation keys
`IGUI_Bucketlist_*`, `UI_Bucketlist_*`, `ContextMenu_Bucketlist_*`, `Tooltip_Bucketlist_*`. None of
these names is used by the game or by another known mod.

**D4. Data model, schema 1.** Entries are stored under `modData.Bucketlist.entries`, keyed by the
fullType including the module. Each entry has `sources` (type `context_menu`, `craft_menu`, `manual`),
`note` and `addedAt`. Rules:
1. Wanted amount = sum of the consuming sources plus the maximum of the tool sources, at least 1.
   Tools are not consumed, so they are not added up. This is an improvement over the original
   specification.
2. `manual` is a signed correction: setting the wanted amount to N means
   `manual = N - sum of the other sources`. If another source is removed later, the wanted amount
   drops by exactly that source's share.
3. Each entry has at most one `context_menu` source and one `craft_menu` source per recipe ID. Adding
   a second time replaces the amount instead of doubling it.
4. An entry lives as long as it has a source other than `manual`.
5. Carried amount = number of items in the player inventory including all carried bags
   (`getCountTypeRecurse`). Done means carried >= wanted.
6. Only IDs, amounts, timestamps (`getTimestamp`) and the note (at most 200 characters) are stored.
   Names are resolved in the current language when drawing.
7. Group entries (phase 4) get `kind = "group"` and the key `grp:` plus the normalized list of
   alternatives from the recipe line.

**D5. Persistence.** Every change is written to `player:getModData().Bucketlist` right away,
increments `rev`, and in multiplayer (`isClient()`) calls `player:transmitModData()`, the same way
vanilla saves the hotbar. In single player the game saves the players every 10 seconds. `OnSave` is
not used because it fires too late. Migration runs on first access per player. Data with a higher
schema is only read and never written, so that an older mod version cannot destroy newer data.
Whether the data survives rejoining a server and a server restart can only be shown by an in-game
test. The fallback is a file under `~/Zomboid/Lua/Bucketlist/`.

**D6. Context menu.** One option at the end of the menu, added through
`Events.OnFillInventoryObjectContextMenu`. The selection is unpacked with
`ISInventoryPane.getActualItems` and deduplicated by fullType. The option receives fullType strings,
not item objects. If all selected types are already listed, the option reads "Remove from Bucketlist"
and deletes the whole entries. Otherwise it reads "Add to Bucketlist" and adds the types that are
still missing with amount 1. With several types the count is shown in parentheses. *Assumption:*
moveables (`Moveables.*`) get no option.

**D7. Names and icons.** A script item only counts if `si:getFullName() == fullType`, because the
lookups fall back to the Base module when the module is unknown. Otherwise Bucketlist shows the
fullType itself. `getItemNameFromFullType` is only called with strings that contain a dot.

**D8. Highlighting.** All listed items are marked. Open entries (carried < wanted) get a strong mark
with a subtle fill and a frame, done entries get a thin, pale frame. The shape starts at `column2`
and the text colour is left alone. The first assumption, "open entries only", turned out to be
confusing in play (2026-10-09): an item taken from your own inventory is done immediately with a
wanted amount of 1, and then it was not marked anywhere.

**D9. Button "Missing ingredients".** *Assumption:* "missing" is whatever the crafting window shows
in red (`isInputSatisfied`). The amount is for one craft. Tools are included and flagged as tools.
Fluids and `[*]` inputs are not included. A container is only included if none of the alternatives
is available. Ingredients counted in uses get a wanted amount of 1 item.

**D10. Deleting in the window.** A second click confirms. `ISModalDialog` is not an option: when it
closes it sets the game speed to 1 and thereby ends a pause.

**D11. Hotkey.** The default key is Ö on a German keyboard (chosen by the author on 2026-10-08), which
is `Keyboard.KEY_SEMICOLON` with code 39 in the game. The game identifies keys by their US layout
position: the key binding menu shows ";", and on other keyboards it is whichever key sits in that
position. Vanilla uses the letter keys, F7 to F9 and 9/0 were taken by hotbar slots in the author's
setup, and B opens the crafting window. The semicolon position is free. The key can be rebound in the
mod options (page "Bucketlist", PZAPI.ModOptions); key 0 means unbound.

**D12. Controller.** No separate controller access in v1, it was not part of the original scope. The
context menu also works with a controller.

**D13. Translations.** One JSON file per category under `common/media/lua/shared/Translate/<LANG>/`,
UTF-8 without BOM, LF, 4 spaces, no `language.json`. EN and DE from phase 1, the other 12 languages
(FR, ES, PTBR, IT, PL, RU, UA, TR, CN, CH, JP, KO) machine-translated later (D31). ES_MX, ES_CL, AR
and PT get no copies and see EN. Sentences use placeholders only and are neutral with respect to
number. `tools/i18n_check.py` runs before every in-game test, because a malformed file aborts the
game start.

**D14. Multiplayer.** Bucketlist has no server code, but it must be installed on the server and
listed in `Mods=`, in the same version as on the client. This goes into the description and the
README.

**D15. In-game tests.** The game is started only through `tools/start-game.sh`, only on request, and
only when no Project Zomboid is running. A running game is never terminated, since the same machine
is also used for normal play. `--stop` ends only processes that have the test folder `.cache/zomboid`
in their command line.

**D16. Error protection.** Every event handler and every part of a wrapper that is our own runs in
`pcall`. An error is logged once with `[Bucketlist]`; vanilla behaviour always continues.

**D17. Context menu labels (phase 1).** One type: "Add to Bucketlist" or "Remove from Bucketlist".
Several types: the same texts with the count in parentheses ("(%1)"), which is neutral with respect
to number in all languages.

**D18. Dev tests (phase 1).** `mod/BucketlistDev` starts a fresh world through a debug scenario and
runs the tests `context`, `persist` and `all` (`tools/start-game.sh --test <name>`). After `context`,
`all` saves and quits the same way the pause menu entry does, loads the save again and checks
`persist`. The chain runs through the request `resume <test>` in `Lua/BucketlistDev.txt`. The request
name contains no hyphen, because `-` is a quantifier in Lua patterns.

**D19. mod.info without author and url.** Both come with the Workshop data in phase 5. Poster and
icon are provisional (256 and 64 pixels).

**D20. Window (phase 2).** One instance for player 0, created on `OnCreatePlayer` and set to its
saved position and size on load through `ISLayoutManager` ("bucketlist"). Rows are rebuilt when the
list's `rev` changes; otherwise the amounts are just recounted every 0.5 seconds. If the order stays
the same, the rows are updated in place so that selection and scroll position are kept. The wanted
amount is changed in a dialog with a number field, a deliberate choice over plus/minus buttons.
"Hide done" is stored as `hideDone` in the character's list. The schema stays at 1, because
additional fields do not interfere with the migration.

**D21. Sidebar (phase 2).** A button below the lowest vanilla or third-party button, the same size as
the inventory button, with images in the five vanilla sizes (`Bucketlist_Sidebar_On/Off_<width>.png`).
The tooltip shows the current key and is set again whenever the binding changes.

**D22. Workflow from phase 2 on.** On 2026-10-08 it was decided to finish phases 2 to 5 in one pass
without intermediate stops and to accept the whole result at the end. Each phase still gets its own
commit and tag. In-game tests only run while the machine is not being used for normal play.

**D23. Highlighting (phase 3).** A wrapper around `ISInventoryPane:renderdetails`, drawn after the
original and only in the normal pass. Open entries get a subtle fill (alpha 0.15) and a frame (0.7)
starting at `column2`, done entries only a frame (0.3) (D8). A stack row counts as listed as soon as
one of its items matches, because stacks are formed by display name. The default colour is amber
(1.0 / 0.75 / 0.15), so that it stands out from vanilla white, red and cyan and from the colours of
Item Rarity UI. It becomes configurable in phase 5.

**D24. Carried amounts (phase 3).** `Bucketlist/Tracker.lua` counts at most every 0.5 seconds per
player, and immediately after `OnRefreshInventoryWindowContainers` (player inventory),
`OnContainerUpdate` and `OnClothingUpdated` (local players only). An index from type to entries
answers the question for each inventory row without counting. Window, highlighting and tooltip read
the same numbers.

**D25. Tooltip (phase 3).** A wrapper around `ISToolTipInv:render` draws its own box below the panel
(above it for an anchored tooltip or at the screen edge) with carried/wanted, sources and up to three
lines of the note, for done entries as well. If another wrapper returns `false` (nothing drawn), the
box is skipped.

**D26. Hook helper (phase 3).** `Bucketlist/Hooks.lua` wraps vanilla functions in a uniform way:
original first and exactly once, return values passed through, our own part in `pcall`. On
`OnGameStart` the function is wrapped again if a mod loaded later has replaced it. A timestamp on the
object prevents our own part from running twice if our wrapper ends up in the chain twice, and it
does not get stuck after an error in the original.

**D27. Button in the crafting window (phase 4).** A wrapper around
`ISCraftRecipePanel:createDynamicChildren` appends a table row with the button after the original.
The button is only enabled while ingredients are missing and no craft is running. It works in the
crafting window and at workstations, but not in the build menu, which uses its own classes. Feedback
is shown for 2.5 seconds in the button itself ("Added to Bucketlist: 3" or "Nothing missing").

**D28. Group entries (phase 4).** A missing input with several alternatives becomes a group entry
with the key `grp:` plus the source text of the script line (`tags[...]` or `[...]`), with a trailing
`!` for exclusive inputs. The fallback is `grp:<recipe>#<index>`. The alternatives are stored with
their items per unit (at most 100), and the wanted amount is the number of units. A group is
satisfied when the sum of the alternatives (for exclusive inputs, the best single one) reaches the
number of units. "[*]" inputs and fluids are not put on the list, and a container with fluid only if
no matching alternative is carried.

**D29. Right-click menu in the window (phase 4).** Per row: "Change amount", "Edit note", "Open
recipe" for each recipe source (`ISEntityUI.OpenHandcraftWindow`), and "Remove source" for each
source. Removing the last source other than the adjustment deletes the entry (D4).

**D30. Mod options (phase 5).** A page "Bucketlist" with the hotkey (D11) and a colour picker for the
highlighting (default amber, D23). There are no other options; the required features are operated in
the window. The colour is read fresh on every draw.

**D31. Languages.** EN and DE are written by hand. The other 12 languages of the original
specification (FR, ES, PTBR, IT, PL, RU, UA, TR, CN, CH, JP, KO) were added on 2026-10-10 as machine
translations: the terms come from the game's own translation files of each language, a second pass
translated every text back and compared it with EN, and every language was looked at in game with
`tools/lang-tour.sh` for missing glyphs and cut-off texts. A script also compared every character with the glyph tables
of the game's fonts: all languages are covered except CN, because the Chinese font of 42.21.0
contains Traditional characters only and drops Simplified ones in vanilla texts too. No native
speaker has read them. The
README and the Workshop text say so and name the ways to send corrections. "Bucketlist" stays the
same as a name in every language.

**D32. Workshop files (phase 5).** `workshop/Bucketlist/` contains `workshop.txt` (tags Build 42,
Interface, QoL from `media/WorkshopTags.txt`) and `preview.png` (512 pixels, below 1,024,000 bytes).
`tools/build-workshop.sh` builds `Contents/mods/Bucketlist` from the repo and checks the uploader's
rules. Nothing is uploaded automatically; the upload is done by hand. A copy in `~/Zomboid/Workshop`
hides the symlink in `~/Zomboid/mods` and should be removed again after uploading. Poster and icon in
the mod are scaled down from the same source image.

**D33. Code review (after phase 5).** A code review read the code against the game sources, and each
finding was checked a second time. Confirmed and fixed:
- The hotkey also opened the window on top of the game menu and with a dead character.
- The note dialog would never have opened at the mouse position (`ISTextBox:setMaxLines` hits a plain
  UIElement there; now the field `maxLines` is set before `initialise`).
- The three buttons shared one border colour table and always showed the red "locked" border (now
  one table per button).
- The tooltip box ran off the right screen edge (now shifted to the left).
- For the bound journal of Skill Recovery Journal the box now sits above the tooltip, because that
  mod draws below it.
- `Store.get` validated the list on every frame (now once per stored table).
- The dev test `highlight` expands the inventory so that the list is drawn at all.

Refuted: a window supposedly too narrow with a large font. The game sets the minimum width in the
first frame; the minimum width is set immediately anyway.

**D34. Single ingredient by right-click (2026-10-10).** Right-clicking an ingredient or tool slot in
the crafting window offers "Add to Bucketlist", or "Remove from Bucketlist" if the recipe is already
a source for that ingredient. Unlike the button, the right-click also lists ingredients that the
window shows as available, and the container exception from D9 does not apply: whoever clicks a
specific slot wants that item. Amount, tool flag and groups work as with the button, and both share
the one recipe source per entry, so nothing is counted twice. Removing takes away only the source of
this recipe. Technically these are two wrappers around the empty `onRightMouseUp` and
`onRightMouseUpOutside` that `ISWidgetInput` inherits from `ISUIElement`; no vanilla code is
replaced. The build menu uses the same widget and gets the menu as well. The texts are those of the
inventory right-click.

**D35. Copy instead of symlink in the normal profile (2026-10-10).** For normal play the mod is
installed as a copy in `~/Zomboid/mods/Bucketlist`, no longer as a symlink (changes D1). The test
profile `.cache/zomboid` keeps the symlink.
