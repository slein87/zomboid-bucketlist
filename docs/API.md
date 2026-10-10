# Verified game APIs

Every game function, event and class that Shopping List uses or plans to use in a later phase is listed
here with its location in the installed version 42.21.0. `python3 -I tools/apicheck.py` checks every
row against the game and the jar dump (`.cache/jardump`, created with `python3 -I tools/pzjar.py`).
After each game patch, run this check first.

Each table has the columns Name, Location, Signature, Side, Use and Status. Locations are code
spans: `media/...` is in the game folder, `WS <id>/...` in the workshop folder,
`jar <class>` in the jar dump. The first location of a row is the main location.

Status: **verified** means the Lua line or the signature was read; **Bytecode** means the behavior
was derived from the bytecode and has not been observed in game yet; **game test pending** means a
game test still has to show the effect.

## 1 Mod structure and loading

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `mod.info` in `common/` | `WS 2553809727/mods/KillCount/common/mod.info:3` | `id=`, `poster=../common/...` | both | Mod with `common/mod.info` only, no version folder needed | verified |
| `versionMin` | `WS 3682106012/mods/SimpleSuppressorB42/42/mod.info:6` | `versionMin=42.21` | both | Lower bound, no `versionMax` | verified |
| `getModVersionDirName` | `jar zombie.ZomboidFileSystem` | `String getModVersionDirName(Path modDir)` | both | Exactly one version folder plus `common/` | Bytecode |
| `require` | `media/lua/client/Entity/ISUI/Components/Crafting/ISCraftBenchPanel.lua:1` | `require "path/file"` | Client | Load modules, return value is cached | verified |
| `Events.OnGameStart` | `media/lua/client/Chat/ISAlert.lua:61` | `OnGameStart()` | Client | Startup log, check wrappers | verified |
| `Events.OnCreatePlayer` | `media/lua/client/ISUI/PlayerData/ISPlayerData.lua:203` | `(playerNum, player)` | Client | Create or migrate the list per player | verified |
| `Events.OnPlayerDeath` | `media/lua/client/ISUI/PlayerData/ISPlayerData.lua:204` | `(player)` | Client | Drop the player's caches | verified |
| `Events.OnPostSave` | `media/lua/client/ISUI/PlayerData/ISPlayerData.lua:205` | `()` | Client | Clean up windows, fires twice | verified |
| `print` | `media/lua/client/ISUI/PlayerData/ISPlayerData.lua:162` | `print(text)` | Client | Log lines with `[ShoppingList]` | verified |
| `getCore():getVersion()` | `media/lua/client/ISUI/ISVersionWaterMark.lua:80` `jar zombie.core.Core` | `String getVersion()` | Client | Exact game version in the log | verified |
| `getCore():getDebug()` | `media/lua/client/Context/Inventory/InvContextMedia.lua:11` | `getDebug() -> boolean` | Client | Verbose logs in debug mode only | verified |
| `isClient` | `media/lua/client/Hotbar/ISHotbar.lua:675` | `isClient() -> boolean` | Client | Send ModData in MP only | verified |

## 2 Context menu

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `Events.OnFillInventoryObjectContextMenu` | `media/lua/client/ISUI/ISInventoryPaneContextMenu.lua:935` | `(playerNum, context, items)` | Client | Option "Add to Shopping List" / "Remove from Shopping List" | verified |
| `ISInventoryPaneContextMenu.createMenu` | `media/lua/client/ISUI/ISInventoryPaneContextMenu.lua:26` | `createMenu(player, isInPlayerInventory, items, x, y, origin) -> context` | Client | Dev test builds the menu without a mouse click | verified |
| `ISInventoryPane.getActualItems` | `media/lua/client/ISUI/ISInventoryPane.lua:912` | `getActualItems(items) -> {InventoryItem}` | Client | Unpack the stacks of the selection | verified |
| `ISContextMenu:addOption` | `media/lua/client/ISUI/ISContextMenu.lua:873` | `addOption(name, target, onSelect, param1, ...) -> option` | Client | Create an option; a click calls `onSelect(target, param1, ...)` | verified |
| `ISInventoryPaneContextMenu.addToolTip` | `media/lua/client/ISUI/ISInventoryPaneContextMenu.lua:411` | `addToolTip() -> ISToolTip` | Client | Tooltip on an option, pooled | verified |
| `getSpecificPlayer` | `media/lua/client/ISUI/ISInventoryPaneContextMenu.lua:113` | `getSpecificPlayer(playerNum) -> IsoPlayer` | Client | Player for an index, safe in split screen | verified |
| `instanceof` | `media/lua/client/ISUI/ISInventoryPane.lua:834` | `instanceof(obj, "InventoryItem")` | Client | Type check before item calls | verified |

## 3 Items, names, counting

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `InventoryItem:getFullType` | `media/lua/client/ISUI/ISInventoryPaneContextMenu.lua:384` `jar zombie.inventory.InventoryItem` | `String getFullType()` | Client | Key of an entry, "Module.Type" | verified |
| `IsoGameCharacter:getInventory` | `media/lua/client/ISUI/ISInventoryPaneContextMenu.lua:114` | `getInventory() -> ItemContainer` | Client | Main inventory of the player | verified |
| `ItemContainer:getCountTypeRecurse` | `media/lua/client/ISUI/ISWorldObjectContextMenu.lua:1880` `jar zombie.inventory.ItemContainer` | `int getCountTypeRecurse(String type)` | Client | Carried amount including bags, always called with the fullType | verified |
| `ItemContainer:getCountEvalRecurse` | `media/lua/server/BuildingObjects/ISShovelGroundCursor.lua:70` `jar zombie.inventory.ItemContainer` | `int getCountEvalRecurse(LuaClosure functionObj)` | Client | Count groups and tags | verified |
| `getItemNameFromFullType` | `media/lua/client/Entity/ISUI/ISEntityBuildMenu.lua:176` | `getItemNameFromFullType(fullType) -> String` | Client | Display name; throws if the argument has no dot | verified |
| `ScriptManager:FindItem` | `media/lua/client/Farming/ISUI/ISFarmingMenu.lua:1123` | `getScriptManager():FindItem(name) -> Item` | Client | Script item for a fullType; falls back to Base, so use it only on an exact match | verified |
| `Item:getFullName` | `jar zombie.scripting.objects.Item` | `String getFullName()` | Client | Exact-match check `si:getFullName() == fullType` | Bytecode |
| `Item:getDisplayName` | `jar zombie.scripting.objects.Item` | `String getDisplayName()` | Client | Display name of the script item | Bytecode |
| `ISInventoryItem.renderScriptItemIcon` | `media/lua/client/ISUI/ISInventoryItem.lua:25` | `renderScriptItemIcon(self, scriptItem, x, y, alpha, w, h)` | Client | Icon in the window without an item instance | verified |

## 4 Persistence

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `IsoObject:getModData` | `media/lua/client/Hotbar/ISHotbar.lua:670` | `getModData() -> KahluaTable` | Client | List under `modData.ShoppingList`, SP saves it with the character | verified |
| `IsoObject:transmitModData` | `media/lua/client/Hotbar/ISHotbar.lua:676` `jar zombie.iso.IsoObject` | `void transmitModData()` | Client | Send a change to the server in MP | game test pending (MP) |
| `getTimestamp` | `media/lua/client/ISUI/ISPostDeathUI.lua:74` | `getTimestamp() -> seconds since 1970` | Client | `addedAt` | verified |
| `getFileWriter` | `media/lua/client/Entity/ISEntityUI.lua:687` | `getFileWriter(name, createIfNull, append)` | Client | Dev requests; plan B for an MP backup | verified |
| `getFileReader` | `media/lua/client/Entity/ISEntityUI.lua:643` | `getFileReader(name, createIfNull)` | Client | Read dev requests | verified |

## 5 Texts

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `getText` | `media/lua/client/ISUI/ISInventoryPaneContextMenu.lua:927` | `getText(key, arg1, ...)`, `%1` to `%9` | Client | All visible texts; `getText(nil)` throws | verified |
| `getTextOrNull` | `media/lua/client/Hotbar/ISHotbar.lua:43` | `getTextOrNull(key) -> String or nil` | Client | Optional texts | verified |
| `ContextMenu_*` in `ContextMenu.json` | `media/lua/shared/Translate/EN/ContextMenu.json:2` | flat object, one prefix per file | Shared | `ContextMenu_ShoppingList_*` in `ContextMenu.json` and so on | verified |
| `Mod.json` with `name` and `description` | `WS 3579640010/mods/STA_PryOpen/common/media/lua/shared/Translate/DE/Mod.json:2` | `{"name": ..., "description": ...}` | Shared | Mod entry per language | verified |

## 6 Highlighting and tooltip (phase 3)

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `ISInventoryPane:renderdetails` | `media/lua/client/ISUI/ISInventoryPane.lua:2205` | `renderdetails(doDragged)` | Client | Wrapper marks rows after the original has run | verified |
| `ISInventoryPane.items` | `media/lua/client/ISUI/ISInventoryPane.lua:2209` | field `self.items` | Client | Maps row i to a stack or an item | verified |
| `ISToolTipInv:render` | `media/lua/client/ISUI/ISToolTipInv.lua:43` | `render()` | Client | Own box below the item tooltip | verified |
| `Events.OnRefreshInventoryWindowContainers` | `media/lua/client/ISUI/ISInventoryPage.lua:1906` | `(page, state)` | Client | Invalidate the carried-amount cache | verified |
| `Events.OnContainerUpdate` | `media/lua/client/ISUI/ISInventoryPage.lua:2213` | `()` | Client | Invalidate the carried-amount cache | verified |
| `Events.OnClothingUpdated` | `media/lua/client/Hotbar/ISHotbar.lua:886` | `(character)` | Client | Carried-amount cache, local IsoPlayer only | verified |

## 6a Highlighting and tooltip in detail (phase 3)

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `playerInventory.player` (ISInventoryPage) | `media/lua/client/ISUI/PlayerData/ISPlayerDataObject.lua:37` | Player index of the inventory window, loot window on line 46; `onCharacter` in `ISUI/ISInventoryPage.lua:1963` | Client | Assign a change signal to the right player | verified |
| `ISInventoryPane.player` | `media/lua/client/ISUI/ISInventoryPage.lua:84` | `panel2.player = self.player` | Client | Mark the list of the right player | verified |
| `ISInventoryPane.itemHgt` | `media/lua/client/ISUI/ISInventoryPane.lua:2806` | Row height, recalculated at runtime | Client | Row geometry, never cache it | verified |
| `ISInventoryPane.headerHgt` | `media/lua/client/ISUI/ISInventoryPane.lua:32` | Height of the column header | Client | Do not draw over the header | verified |
| `ISInventoryPane.column2` | `media/lua/client/ISUI/ISInventoryPane.lua:34` | Start of the name column | Client | Frame starts at `column2`, icons and arrow are to the left | verified |
| `ISInventoryPane.dragging` | `media/lua/client/ISUI/ISInventoryPane.lua:2273` | `dragging ~= nil and selected[y+1] ~= nil and dragStarted` | Client | Skip dragged rows like vanilla does | verified |
| `ISInventoryPane:addScrollBars` | `media/lua/client/ISUI/ISInventoryPane.lua:102` | creates `vscroll` | Client | Subtract the width of the scroll bar | verified |
| `ISUIElement:getYScroll` | `media/lua/client/ISUI/ISUIElement.lua:332` | `getYScroll() -> int` (0 or negative) | Client | Visible range of the list | verified |
| `ISUIElement:getScrollHeight` | `media/lua/client/ISUI/ISUIElement.lua:1639` | `getScrollHeight() -> int` | Client | Tells whether a scroll bar is shown | verified |
| `ISUIElement:getAbsoluteY` | `media/lua/client/ISUI/ISUIElement.lua:549` | `getAbsoluteY() -> int` | Client | Tooltip box above or below the panel | verified |
| `ISToolTipInv.item` | `media/lua/client/ISUI/ISToolTipInv.lua:64` | `self.item:DoTooltip(self.tooltip)` | Client | Item of the tooltip, can be a FluidContainer | verified |
| `ISToolTipInv.followMouse` | `media/lua/client/ISUI/ISToolTipInv.lua:49` | `followMouse`, `anchorBottomLeft` (line 52) | Client | Box goes above when the tooltip is anchored | verified |
| `ISToolTipInv.backgroundColor` | `media/lua/client/ISUI/ISToolTipInv.lua:197` | `backgroundColor`, `borderColor` (line 198) | Client | Box colors match the panel | verified |
| `getCore():getScreenHeight` | `media/lua/client/ISUI/ISToolTipInv.lua:71` | `getScreenHeight() -> int` | Client | Check the space below the tooltip | verified |
| `ObjectTooltip:getCharacter` | `WS 2503622437/mods/Skill Recovery Journal/42.20.1/media/lua/client/Skill Recovery Journal Tooltip.lua:221` `jar zombie.ui.ObjectTooltip` | `getCharacter() -> IsoGameCharacter` | Client | List of the right player in split screen | verified |
| `ObjectTooltip:getFont` | `jar zombie.ui.ObjectTooltip` | `UIFont getFont()` | Client | Font of the tooltip box | Bytecode |
| `IsoPlayer:isLocalPlayer` | `media/lua/client/XpSystem/ISUI/ISCharacterInfoWindow.lua:346` | `instanceof(chr, 'IsoPlayer') and chr:isLocalPlayer()` | Client | Guard for `OnClothingUpdated` | verified |
| `ISInventoryPage.renderDirty` | `media/lua/client/ISUI/ISInventoryPage.lua:694` | `ISInventoryPage.renderDirty = true` | Client | Dev test makes the windows rebuild | verified |
| `getPlayerInventory` | `media/lua/client/ISUI/PlayerData/ISPlayerData.lua:87` | `getPlayerInventory(id).inventoryPane` | Client | Dev test reads the rows of the inventory list | verified |
| `ItemContainer:getFirstTypeRecurse` | `media/lua/client/BuildingObjects/ISUI/ISInventoryBuildMenu.lua:110` `jar zombie.inventory.ItemContainer` | `getFirstTypeRecurse(String type) -> InventoryItem` | Client | Dev test fetches an item for the tooltip | verified |

## 7 Window, HUD button, keys (phase 2)

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `ISCollapsableWindowJoypad` | `media/lua/client/ISUI/ISCollapsableWindowJoypad.lua:4` | `ISCollapsableWindowJoypad:derive(name)` | Client | Base class of the list window | verified |
| `ISScrollingListBox:addItem` | `media/lua/client/ISUI/ISScrollingListBox.lua:141` | `addItem(name, item, tooltip)` | Client | Rows of the list | verified |
| `ISScrollingListBox:doDrawItem` | `media/lua/client/ISUI/ISScrollingListBox.lua:304` | `doDrawItem(y, item, alt) -> y` | Client | Custom drawing per instance | verified |
| `ISTextBox:new` | `media/lua/client/ISUI/ISTextBox.lua:280` | `new(x, y, w, h, text, default, target, onclick, player, p1..p4)` | Client | Dialog for amount and note | verified |
| `ISEquippedItem:initialise` | `media/lua/client/ISUI/ISEquippedItem.lua:711` | `initialise()` | Client | Wrapper adds the HUD button to the sidebar | verified |
| `ISLayoutManager.RegisterWindow` | `media/lua/client/ISUI/ISLayoutManager.lua:6` | `RegisterWindow(name, funcs, target)` | Client | Remember the window position | verified |
| `Events.OnKeyPressed` | `media/lua/client/ISUI/ISInventoryPage.lua:2212` | `(key)`, on release | Client | Hotkey | verified |
| `Keyboard.getKeyName` | `media/lua/client/Entity/ISUI/ISEntityBuildMenu.lua:208` | `getKeyName(key) -> String` | Client | Key name in the tooltip of the HUD button | verified |

## 7a List window in detail (phase 2)

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `ISCollapsableWindowJoypad.new` | `media/lua/client/ISUI/ISDesignationZonePanel.lua:300` | `ISCollapsableWindowJoypad.new(self, x, y, w, h)` | Client | Constructor of the derived window | verified |
| `ISCollapsableWindowJoypad.initialise` | `media/lua/client/ISUI/ISDesignationZonePanel.lua:11` | Base call in `initialise` | Client | Build the window like the zone window | verified |
| `ISCollapsableWindowJoypad.prerender` | `media/lua/client/ISUI/ISDesignationZonePanel.lua:130` | Base call in `prerender` | Client | Own prerender calls the base | verified |
| `ISCollapsableWindowJoypad.render` | `media/lua/client/ISUI/ISDesignationZonePanel.lua:139` | Base call in `render` | Client | Own render calls the base | verified |
| `ISCollapsableWindow:setTitle` | `media/lua/client/ISUI/ISCollapsableWindow.lua:18` | `setTitle(title)` | Client | Window title | verified |
| `ISCollapsableWindow:titleBarHeight` | `media/lua/client/ISUI/ISCollapsableWindow.lua:298` | `titleBarHeight() -> int` | Client | Inner layout | verified |
| `ISCollapsableWindow:resizeWidgetHeight` | `media/lua/client/ISUI/ISCollapsableWindow.lua:302` | `resizeWidgetHeight() -> int` | Client | Space for the resize handle | verified |
| `ISCollapsableWindow:setResizable` | `media/lua/client/ISUI/ISCollapsableWindow.lua:326` | `setResizable(bool)` | Client | Resizable, size is remembered in the layout | verified |
| `ISCollapsableWindow:RestoreLayout` | `media/lua/client/ISUI/ISCollapsableWindow.lua:336` | `RestoreLayout(name, layout)`, `SaveLayout` line 351 | Client | Functions for `ISLayoutManager.RegisterWindow` | verified |
| `isKeyConsumed` | `media/lua/client/ISUI/Crafting/ISHandcraftWindow.lua:289` | `isKeyConsumed(key) -> boolean` | Client | ESC and the hotkey close the window | verified |
| `onKeyRelease` | `media/lua/client/ISUI/Crafting/ISHandcraftWindow.lua:293` | `onKeyRelease(key)` | Client | Close on ESC and hotkey | verified |
| `setWantKeyEvents` | `media/lua/client/ISUI/Crafting/ISHandcraftWindow.lua:386` | `setWantKeyEvents(true)` | Client | Window receives key events | verified |
| `Keyboard.KEY_ESCAPE` | `media/lua/client/ISUI/Crafting/ISHandcraftWindow.lua:290` | Key code | Client | Detect ESC | verified |
| `Keyboard.KEY_K` | `media/lua/client/erosion/debug/DebugDemoTime.lua:90` | Key code 37 (constant in `org/lwjglx/input/Keyboard.class` of the game jar); not bound in `media/lua/shared/keyBinding.lua` | Client | Default hotkey | verified |
| `getPlayerScreenLeft` | `media/lua/client/ISUI/PlayerData/ISPlayerDataObject.lua:103` | `getPlayerScreenLeft/Top/Width/Height(playerNum)` (lines 103 to 106) | Client | Center the window in the player's screen area | verified |
| `ISUIElement:addToUIManager` | `media/lua/client/ISUI/ISUIElement.lua:1365` | `addToUIManager()`, `removeFromUIManager()` line 1373 | Client | Show and hide the window | verified |
| `ISUIElement:setVisible` | `media/lua/client/ISUI/ISUIElement.lua:657` | `setVisible(bool)`, `getIsVisible()` line 676 | Client | Visibility | verified |
| `ISUIElement:bringToTop` | `media/lua/client/ISUI/ISUIElement.lua:1548` | `bringToTop()` | Client | Bring the window to the front | verified |
| `ISUIElement:setAnchorBottom` | `media/lua/client/ISUI/ISUIElement.lua:129` | `setAnchorBottom/Top/Right(bool)` (lines 129 to 150) | Client | List grows with the window, buttons stay at the bottom | verified |
| `ISUIElement:drawRect` | `media/lua/client/ISUI/ISUIElement.lua:1191` | `drawRect(x, y, w, h, a, r, g, b)` | Client | Selection and hover of a row | verified |
| `ISUIElement:drawRectBorder` | `media/lua/client/ISUI/ISUIElement.lua:1219` | `drawRectBorder(x, y, w, h, a, r, g, b)` | Client | Row frame | verified |
| `ISUIElement:drawText` | `media/lua/client/ISUI/ISUIElement.lua:1293` | `drawText(str, x, y, r, g, b, a, font)`, `drawTextRight` line 1306, `drawTextCentre` line 1280 | Client | Row texts, carried/wanted right-aligned, hint for an empty list | verified |
| `getTextManager():MeasureStringX` | `media/lua/client/ISUI/ISDesignationZonePanel.lua:15` | `MeasureStringX(font, text) -> int` | Client | Button widths from the translated texts | verified |
| `getTextManager():getFontHeight` | `media/lua/client/ISUI/ISDesignationZonePanel.lua:5` | `getFontHeight(font) -> int` | Client | Row and button height | verified |
| `getTextManager():WrapText` | `media/lua/client/Entity/ISUI/CraftRecipe/ISRecipeScrollingListBox.lua:141` | `WrapText(font, text, maxWidth, maxLines, suffix)` | Client | Shorten long names and notes with "..." | verified |
| `getCore():getGoodHighlitedColor` | `media/lua/client/ISUI/ISButton.lua:387` | `-> ColorInfo` with `getR/getG/getB` | Client | Done entries in the "good" color | verified |
| `getCore():getBadHighlitedColor` | `media/lua/client/ISUI/ISDesignationZonePanel.lua:172` | `-> ColorInfo` | Client | Counterpart, provided in the adapter | verified |
| `getTimestampMs` | `media/lua/client/Chat/ISChat.lua:469` | `getTimestampMs() -> milliseconds` | Client | Counting interval 0.5 s, delete confirmation 3 s | verified |
| `ISScrollingListBox:clear` | `media/lua/client/ISUI/ISScrollingListBox.lua:340` | `clear()`, sets `selected = 1` | Client | Rebuild the rows, restore the selection by key | verified |
| `ISScrollingListBox:isMouseOverScrollBar` | `media/lua/client/ISUI/ISScrollingListBox.lua:112` | `isMouseOverScrollBar() -> boolean` | Client | No hover over the scroll bar | verified |
| `ISScrollingListBox.vscroll` | `media/lua/client/ISUI/ISScrollingListBox.lua:396` | `self.vscroll:getHeight() < self:getScrollHeight()` | Client | Subtract the space of the scroll bar, like `updateTooltip` | verified |
| `ISButton:new` | `media/lua/client/ISUI/ISButton.lua:479` | `new(x, y, w, h, title, target, onclick)`; fields `target`, `onclick` | Client | Buttons in the window and in the sidebar | verified |
| `ISButton:setTitle` | `media/lua/client/ISUI/ISButton.lua:282` | `setTitle(title)` | Client | "Delete" turns into "Really delete?" | verified |
| `ISButton:setEnable` | `media/lua/client/ISUI/ISButton.lua:416` | `setEnable(bool)` | Client | Buttons are enabled only with a selection | verified |
| `ISButton:setImage` | `media/lua/client/ISUI/ISButton.lua:179` | `setImage(texture)`, `setDisplayBackground` line 294, `prerender` line 111 | Client | Sidebar button gray or orange | verified |
| `ISTickBox:new` | `media/lua/client/ISUI/ISTickBox.lua:282` | `new(x, y, w, h, name, target, method)`; `addOption` line 227, `setSelected` line 51, `setWidthToFit` line 266 | Client | "Hide done" | verified |
| `ISTextBox:setOnlyNumbers` | `media/lua/client/ISUI/ISTextBox.lua:84` | `setOnlyNumbers(bool)` after `initialise` | Client | Numeric field for the wanted amount | verified |
| `ISTextBox:setMultipleLine` | `media/lua/client/ISUI/ISTextBox.lua:88` | `setMultipleLine`, `setNumberOfLines` (96), `setMaxLines` (100) before `initialise` | Client | Multi-line note | verified |
| `ISTextBox:setValidateFunction` | `media/lua/client/ISUI/ISTextBox.lua:111` | `setValidateFunction(target, func)`; `maxChars` line 178 | Client | OK only for a valid amount, note limited to 200 characters | verified |
| `ISTextBox:onClick` | `media/lua/client/ISUI/ISTextBox.lua:127` | calls `onclick(target, button, p1..p4)` and closes | Client | Callback of the dialogs; dev test presses OK | verified |
| `ISTextEntryBox:getText` | `media/lua/client/ISUI/ISTextEntryBox.lua:60` | `getText()`, `setText(str)` line 109 | Client | Read the input; dev test fills the field | verified |
| `getTexture` | `media/lua/client/ISUI/ISCollapsableWindow.lua:382` | `getTexture(path) -> Texture` | Client | Own icons `media/ui/ShoppingList/ShoppingList_*.png` | verified |
| `ISEquippedItem:addMouseOverToolTipItem` | `media/lua/client/ISUI/ISEquippedItem.lua:702` | `addMouseOverToolTipItem(object, text)`, entry in `mouseOverList` | Client | Tooltip on the sidebar button | verified |
| `ISEquippedItem:shrinkWrap` | `media/lua/client/ISUI/ISEquippedItem.lua:972` | counts children with `Type == "ISButton"`; `getChildren` line 975 | Client | Resize the sidebar after adding the new button | verified |
| `getPlayerData` | `media/lua/client/ISUI/ISEquippedItem.lua:1060` | `getPlayerData(playerNum).equipped` | Client | Dev test finds the button | verified |
| `triggerEvent` | `media/lua/client/DebugUIs/ISRemoveItemTool.lua:318` | `triggerEvent(name, args...)` | Client | Dev test fires `OnKeyPressed` | verified |

## 8 Mod options (phase 5)

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `PZAPI.ModOptions:create` | `media/lua/client/PZAPI/ModOptions.lua:247` | `create(modOptionsID, name) -> options` | Client | Options page `ShoppingList`, create it only once | verified |
| `Options:addKeyBind` | `media/lua/client/PZAPI/ModOptions.lua:182` | `addKeyBind(id, name, key, tooltip)` | Client | Hotkey; pass the name already translated | verified |
| `Options:addColorPicker` | `media/lua/client/PZAPI/ModOptions.lua:158` | `addColorPicker(id, name, r, g, b, a, tooltip)` | Client | Highlight color | verified |
| `colorOption:getValue` | `media/lua/client/PZAPI/ModOptions.lua:167` | `getValue() -> { r, g, b, a }` (0 to 1) | Client | Highlight color, read fresh every time, never modified | verified |
| `Options:addTickBox` | `media/lua/client/PZAPI/ModOptions.lua:64` | `addTickBox(id, name, value, tooltip)` | Client | Toggle | verified |

## 9 Crafting window (phase 4)

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `ISCraftRecipePanel:createDynamicChildren` | `media/lua/client/Entity/ISUI/CraftRecipe/ISCraftRecipePanel.lua:31` | `createDynamicChildren()` | Client | Wrapper appends the button as a table row | verified |
| `ISTableLayout:addRow` | `media/lua/client/Entity/ISUI/Controls/ISTableLayout.lua:268` | `addRow(styleRow, autoFill) -> row` | Client | New row in the recipe panel | verified |
| `HandcraftLogic:getRecipe` | `media/lua/client/Entity/ISUI/CraftRecipe/ISHandCraftPanel.lua:233` | `getRecipe() -> CraftRecipe` | Client | Selected recipe | verified |
| `CraftRecipe:getInputs` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetIngredientsInputs.lua:54` | `getInputs() -> ArrayList<InputScript>` | Client | Iterate over the ingredients | verified |
| `BaseCraftingLogic:isInputSatisfied` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:504` | `isInputSatisfied(input) -> boolean` | Client | "Missing" means the same as the red marking | verified |
| `BaseCraftingLogic:areAllInputItemsSatisfied` | `media/lua/client/Entity/ISUI/Controls/ISWidgetTitleHeader.lua:181` | `areAllInputItemsSatisfied() -> boolean` | Client | Button is enabled only when something is missing | verified |
| `InputScript:getPossibleInputItems` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:199` | `getPossibleInputItems() -> List<Item>` | Client | Alternatives of an input | verified |
| `InputScript:getAmount` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:541` | `getAmount(fullType) -> float` | Client | Amount per alternative | verified |
| `InputScript:isKeep` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:182` | `isKeep() -> boolean` | Client | Tool, wanted amount is taken as a maximum | verified |
| `CraftRecipe:getTranslationName` | `media/lua/client/Entity/ISUI/Controls/ISWidgetTitleHeader.lua:535` | `getTranslationName() -> String` | Client | Recipe name in the current language | verified |
| `CraftRecipe:getScriptObjectFullType` | `media/lua/client/DebugUIs/DebugMenu/Recipes/ISCraftRecipeTagsPanel.lua:199` | `getScriptObjectFullType() -> "Module.Name"` | Client | Recipe ID of the source | verified |
| `ScriptManager:getCraftRecipe` | `media/lua/client/ISUI/ISInventoryPaneContextMenu.lua:1199` | `getCraftRecipe(name) -> CraftRecipe` | Client | Recipe for the stored ID | verified |
| `ISEntityUI.OpenHandcraftWindow` | `media/lua/client/Entity/ISEntityUI.lua:562` | `OpenHandcraftWindow(player, isoObject, query, ignoreSurface, recipe, itemString)` | Client | Open a recipe from the list | verified |

## 9a Crafting window in detail (phase 4)

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `ISXuiSkin.build` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetHandCraftControl.lua:77` | `ISXuiSkin.build(xuiSkin, "S_NeedsAStyle", ISButton, 0, 0, 0, h, title)` | Client | Button in the style of the craft button | verified |
| `self.player:getModData` in the recipe panel | `media/lua/client/Entity/ISUI/CraftRecipe/ISCraftRecipePanel.lua:46` | `self.player` (IsoPlayer) | Client | Entries go to the panel's player, not to `getPlayer()` | verified |
| `ISCraftRecipePanel.rootTable` | `media/lua/client/Entity/ISUI/CraftRecipe/ISCraftRecipePanel.lua:52` | `row = self.rootTable:addRow()`, `setElement(0, row:index(), el)` | Client | Own table row | verified |
| `xuiRecalculateLayout` | `media/lua/client/Entity/ISUI/CraftRecipe/ISCraftRecipePanel.lua:97` | `self:xuiRecalculateLayout()` | Client | Layout after adding the new row | verified |
| `BaseCraftingLogic:isCraftActionInProgress` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetHandCraftControl.lua:242` | `isCraftActionInProgress() -> boolean` | Client | Button is disabled while crafting | verified |
| `InputScript:isAutomationOnly` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetIngredientsInputs.lua:56` | `isAutomationOnly() -> boolean` | Client | Skip such inputs | verified |
| `InputScript:getResourceType` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:189` | `getResourceType() == ResourceType.Item` | Client | Item inputs only | verified |
| `InputScript:isTool` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:183` | `isTool() -> boolean`, `isKeep()` line 182 | Client | Tool, wanted amount is taken as a maximum | verified |
| `InputScript:getAmount` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:209` | `getAmount() -> float`, `getAmount(fullType)` line 541 | Client | Unit of the input and amount per alternative | verified |
| `InputScript:isAcceptsAnyItem` | `media/lua/client/Entity/ISUI/CraftRecipe/ISCraftInventoryPanel.lua:300` | `isAcceptsAnyItem() -> boolean` | Client | Never resolve "[*]" | verified |
| `InputScript:hasConsumeFromItem` | `media/lua/client/Entity/ISUI/CraftRecipe/ISCraftInventoryPanel.lua:359` | `hasConsumeFromItem() -> boolean` | Client | Containers holding a fluid | verified |
| `InputScript:isUsesPartialItem` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:554` | `isUsesPartialItem(Item) -> boolean` | Client | Ingredients consumed by uses, wanted amount 1 piece | verified |
| `Item:getFullName` (alternatives) | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:205` | `inputObjects:get(0):getFullName()` | Client | fullType of an alternative | verified |
| `InputScript:getOriginalLine` | `jar zombie.scripting.entity.components.crafting.InputScript` | `String getOriginalLine()` | Client | Group key from the script line | Bytecode |
| `InputScript:isExclusive` | `jar zombie.scripting.entity.components.crafting.InputScript` | `boolean isExclusive()` | Client | Exclusive groups | Bytecode |
| `CraftRecipe:getIndexForIO` | `media/lua/shared/Entity/TimedActions/ISHandcraftAction.lua:310` | `getIndexForIO(inputScript) -> int` | Client | Fallback key: recipe plus index | verified |
| `ISEntityUI.GetWindowInstance` | `media/lua/client/Entity/ISEntityUI.lua:627` | `GetWindowInstance(playerNum, "HandcraftWindow")`; fields `handCraftPanel` (`ISUI/Crafting/ISHandcraftWindow.lua:49`), `recipePanel` (`Entity/ISUI/CraftRecipe/ISHandCraftPanel.lua:90`) | Client | Dev test finds the recipe panel | verified |
| `ISContextMenu.get` | `media/lua/client/Context/ISMenuContextWorld.lua:52` | `ISContextMenu.get(playerNum, x, y) -> context` | Client | Right-click menu of a window row | verified |
| `ISUIElement:onRightMouseUp` | `media/lua/client/ISUI/ISUIElement.lua:1555` | `onRightMouseUp(x, y)`, empty, inherited by `ISWidgetInput` | Client | Wrapper for a right-click on an ingredient | verified |
| `ISUIElement:onRightMouseUpOutside` | `media/lua/client/ISUI/ISUIElement.lua:1524` | `onRightMouseUpOutside(x, y)`, empty | Client | Right-click over a child element of the ingredient field | to verify in game |
| `ISUIElement:isMouseOver` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:304` | `isMouseOver() -> boolean` | Client | Detect a click inside a child element, like vanilla does for left-clicks | verified |
| `ISWidgetInput.inputScript` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetInput.lua:612` | field, along with `player` (line 609) and `logic` (line 610) | Client | Ingredient, player and logic of the field | verified |
| `ISWidgetInput.displayAsOutput` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetIngredientsOutputs.lua:50` | field, `true` for output fields | Client | No menu on outputs | verified |
| `ISWidgetIngredientsInputs.inputs` | `media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetIngredientsInputs.lua:91` | list of `ISWidgetInput`; panel field `inputs` in `ISCraftRecipePanel.lua:59` | Client | Dev test finds the ingredient field | verified |
| `ISScrollingListBox:rowAt` | `media/lua/client/ISUI/ISScrollingListBox.lua:66` | `rowAt(x, y) -> index` | Client | Row under the right-click, like `onMouseDown` (line 579) | verified |
| `onRightMouseUp` on the instance | `media/lua/client/ISUI/ISEquippedItem.lua:720` | `element.onRightMouseUp = function(self, x, y)` | Client | Right-click on the list, set on the instance | verified |
| `getMouseX` | `media/lua/client/ISUI/ISToolTipInv.lua:47` | `getMouseX()`, `getMouseY()` | Client | Menu at the mouse position | verified |

## 9b Additions from the code review

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `IsoPlayer:isDead` | `media/lua/server/XpSystem/XpUpdate.lua:128` | `isDead() -> boolean` | Client | No hotkey while the character is dead | verified |
| `MainScreen.instance:isVisible` | `media/lua/client/ISUI/ISPostDeathUI.lua:234` | `MainScreen.instance:isVisible() -> boolean` | Client | No hotkey while the game menu is open | verified |
| `ISInventoryPage:setPinned` | `media/lua/client/ISUI/ISInventoryPage.lua:410` | `setPinned()` | Client | Dev test expands the inventory so that the list draws | verified |
| `ISUIElement:getAbsoluteX` | `media/lua/client/ISUI/ISUIElement.lua:406` | `getAbsoluteX() -> int` | Client | Shift the tooltip box to the left at the right screen edge | verified |
| `getCore():getScreenWidth` | `media/lua/client/ISUI/ISToolTipInv.lua:70` | `getScreenWidth() -> int` | Client | Right screen edge | verified |
| `InventoryItem:getType` (SRJ journal) | `WS 2503622437/mods/Skill Recovery Journal/42.20.1/media/lua/client/Skill Recovery Journal Tooltip.lua:228` | `itemObj:getType() == "SkillRecoveryBoundJournal"` | Client | Box above the tooltip for the Skill Recovery Journal, because that mod draws below it | verified |
| `ISTextBox.maxLines` | `media/lua/client/ISUI/ISTextBox.lua:24` | `self.entry:setMaxLines(self.maxLines)` in `initialise` | Client | Set the line limit of the note as a field, not through `setMaxLines` | verified |

## 10 Kahlua

Kahlua is a Lua 5.1 dialect. `next`, `xpcall`, `goto` and `continue` are missing. `table.sort` is an
unstable quicksort. Non-ASCII characters in Lua string literals turn into U+FFFD, so visible texts
come from the JSON files only. `string.sub` and `#` count UTF-16 units, while lua5.1 counts bytes
offline. `string.gmatch` is reimplemented in `stdlib.lua:99` and hangs on patterns that can match
the empty string, so all of our patterns consume at least one character. `tests/run.lua` removes
the missing globals so that the offline tests cannot use them by accident.

## 11 Dev mod ShoppingListDev only

Only the test helper `mod/ShoppingListDev` uses these calls, never the mod itself.

| Name | Location | Signature | Side | Use | Status |
|---|---|---|---|---|---|
| `debugScenarios` with `forceLaunch` | `media/lua/client/DebugUIs/DebugScenarios.lua:117` | `debugScenarios.X = { forceLaunch = true, ... }` plus the debug option `DebugScenario.ForceLaunch` | Client | Fresh test world without a click | verified |
| `debugScenarios.PatrickScenario` | `media/lua/client/DebugUIs/Scenarios/PatrickScenario.lua:5` | Vanilla scenario used as a model | Client | Structure of a scenario | verified |
| `ActiveMods.getById("currentGame"):copyFrom` | `media/lua/client/OptionScreens/ModSelector/ModSelectorModel.lua:35` | `copyFrom(activeMods)` | Client | Test save remembers the mod list | verified |
| `getDebugOptions():setBoolean` | `media/lua/client/DebugUIs/DebugMenu/Recipes/ISRecipeMonitor.lua:112` | `setBoolean(name, value)` | Client | Turn ForceLaunch off after the start | verified |
| `ItemContainer:AddItem` | `media/lua/client/DebugUIs/Scenarios/PatrickScenario.lua:82` | `AddItem("Module.Type") -> InventoryItem` | Client | Test items into the inventory (SP only) | verified |
| `ISContextMenu:getOptionFromName` | `media/lua/client/ISUI/ISContextMenu.lua:889` | `getOptionFromName(name) -> option` | Client | Find our option in the built menu | verified |
| `ISContextMenu:closeAll` | `media/lua/client/ISUI/ISContextMenu.lua:268` | `closeAll()` | Client | Close the menu after the test | verified |
| `getCore():quit()` | `media/lua/client/OptionScreens/MainScreen.lua:1364` | `setGameSpeed(1); getCore():quit()` like "EXIT" in the game | Client | Save and quit for the persistence test | game test pending |
| `MainScreen.continueLatestSave` | `media/lua/client/OptionScreens/MainScreen.lua:1283` | `continueLatestSave(gameMode, saveName)` | Client | Load the latest test save | verified |
| `Events.OnMainMenuEnter` | `media/lua/client/OptionScreens/MainScreen.lua:2178` | `()` | Client | Pick up a "continue" or "resume" request | verified |
| `Events.OnFETick` | `jar zombie.gameStates.MainScreenState` `jar zombie.Lua.LuaEventManager` (the game's own Lua never uses this event) | `()` every frame in the main menu | Client | Wait until the main menu is ready; event name is listed in `.cache/jardump/events.txt` and triggered from `MainScreenState.update` | verified |
| `Events.OnTick` | `media/lua/client/DebugUIs/ISFastTeleportMove.lua:20` | `()` every frame | Client | Test steps frame by frame | verified |
| `isServer` | `media/lua/client/DebugUIs/ISSpawnPointsEditor.lua:1` | `isServer() -> boolean` | Client | Test script in single player only | verified |
| `takeScreenshot` | `jar zombie.Lua.LuaManager$GlobalObject` | `takeScreenshot(fileName)`, stores the file under `Screenshots/` in the user folder | Client | Screenshots of the `tour` walkthrough | verified in game |
| `IsoGridSquare:AddWorldInventoryItem` | `media/lua/client/DebugUIs/Scenarios/Trailer3Scenario.lua:240` | `AddWorldInventoryItem(fullType, x, y, z)` | Client | Put items on the ground so that the loot window has rows | verified |
| `getPlayerLoot` | `media/lua/client/ISUI/PlayerData/ISPlayerData.lua:93` | `getPlayerLoot(id) -> ISInventoryPage` | Client | Pin the loot window | verified |
| `ISToolTipInv:new` | `media/lua/client/ISUI/ISToolTipInv.lua:181` | `ISToolTipInv:new(item)`, set up like `ISInventoryPane.lua:858` to `864` | Client | Show the item tooltip without a mouse | verified |
| `ToggleEscapeMenu` | `media/lua/client/OptionScreens/MainScreen.lua:1728` | `ToggleEscapeMenu(key)`, called like on line 1377 | Client | Open and close the pause menu | verified |
| `MainOptions:toUI` | `media/lua/client/OptionScreens/MainOptions.lua:3306` | `toUI()`, then `setVisible(true)` like `MainScreen.lua:1396` | Client | Show the options | verified |
| `ISTabPanel:activateView` | `media/lua/client/ISUI/ISTabPanel.lua:438` | `activateView(viewName)` | Client | Select the MODS tab | verified |
| `Events.OnPostUIDraw` | `media/lua/client/LastStand/LastStandSetup.lua:22` | `()` every drawn frame, also runs while paused | Client | Count frames while `OnTick` is stopped | verified in game |
