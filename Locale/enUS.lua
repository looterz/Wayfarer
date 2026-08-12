local L = LibStub("AceLocale-3.0"):NewLocale((...), "enUS", true, true)

if (not L) then
	return
end

-- Addon
L["Wayfarer"] = true

-- Slash commands
L["Usage:"] = true
L["Open the settings window."] = true
L["Reset the current profile."] = true
L["Settings have been reset to their defaults."] = true

-- Map
L["Map"] = true
L["Adjustments to the world map frame itself."] = true
L["Mouse wheel zoom"] = true
L["Enables zooming the map with the mouse wheel, and corrects the cursor position the map uses for mouseover."] = true
L["Hide the backdrop"] = true
L["Hides the dark overlay the map draws across the rest of the screen, so you can still see and click your interface."] = true

-- Fading
L["Fading"] = true
L["Controls how opaque the map is, and whether it gets out of your way while you move."] = true
L["Map opacity"] = true
L["Sets the map opacity when not moving."] = true
L["Fade when moving"] = true
L["Fades the map out when moving to allow you to see your character and its closest surroundings."] = true
L["Map opacity when moving"] = true
L["Sets the map opacity when moving."] = true

-- Coordinates
L["Coordinates"] = true
L["Shows map coordinates below the world map."] = true
L["Show player coordinates"] = true
L["Show map coordinates of the player's current location."] = true
L["Show cursor coordinates"] = true
L["Show map coordinates of the mouse cursor."] = true
L["Decimals"] = true
L["How many decimal places to show in the coordinates."] = true

-- Zone levels
L["Zone Levels"] = true
L["Adds level ranges and faction control to the zone names shown on the map."] = true
L["Show zone level ranges"] = true
L["Appends the recommended level range to the name of the zone under your cursor."] = true
L["Show controlling faction"] = true
L["Shows which faction controls the zone under your cursor, colored by whether it is yours."] = true

-- Fog of war
L["Fog of War"] = true
L["Reveals the parts of each zone map you have not discovered yet."] = true
L["Reveal unexplored areas"] = true
L["Draws the areas of the map you haven't explored yet, instead of leaving them blank."] = true

-- Options window
L["Profiles"] = true
L["Open the settings in a standalone window."] = true
L["Manage settings profiles."] = true
L["Report what the client knows about your position."] = true

-- Size
L["Size"] = true
L["Sets how much of your screen the map covers. Both sizes are a percentage of your screen height; the map keeps its own shape and everything on it scales to match."] = true
L["Large map size"] = true
L["How tall the maximized map is, as a percentage of your screen height."] = true
L["Small map size"] = true
L["How tall the windowed map is, as a percentage of your screen height."] = true

-- Instance maps
L["Instance Maps"] = true
L["Show instance maps"] = true

-- Calibration
L["Report where the map frame and its pieces sit."] = true

-- Instance map picker
L["Zone Map"] = true
L["Show the map picker"] = true
L["List every named frame on the world map."] = true

-- Instance maps
L["Classic Era never puts the client's own dungeon maps on the world map. Wayfarer draws them over the canvas instead, with boss locations."] = true
L["Draws the dungeon map on the world map whenever you are in one."] = true
L["Puts a dropdown on the world map for reading any dungeon map from anywhere. Picking one overrides the zone map until you pick Zone Map again or close the map."] = true
L["Show boss locations"] = true
L["Marks where each boss is found on the floor you are looking at."] = true
L["Floor %d"] = true
L["Click for loot"] = true
L["Force the instance picker open and describe it."] = true

-- Integrations
L["Integrations"] = true
L["Optional hooks into other addons. Each is used only when that addon is present."] = true
L["Questie quest objectives"] = true
L["Marks quest objectives on the dungeon map, using Questie's database. Off by default: Questie lists every spawn of an objective mob, so a dungeon full of one mob type gets crowded even with the limits Wayfarer applies."] = true
L["AtlasLoot boss loot"] = true
L["Clicking a boss marker opens its loot table in AtlasLoot."] = true
L["Dungeon entrance pins"] = true
L["Marks dungeon entrances on the zone map; clicking one opens that dungeon's map. Classic Era draws no entrance pins of its own, so these are Wayfarer's."] = true
L["AtlasLoot is not installed."] = true
L["%s is not installed."] = true
L["Classic Era reports no player position inside an instance, so a \"you are here\" marker is not possible here."] = true
L["Showing the zone map. Pick the dungeon from the map dropdown to go back."] = true
L["Report why the fog of war is or is not lifted."] = true
L["Unexplored brightness"] = true
L["How brightly the areas you have not explored are drawn. Anything below full makes them read as different from ground you have actually walked, which is the point of drawing them at all."] = true
L["Always show explored areas"] = true
L["Since 1.15.9 the game hides some explored subareas until you point at them, and pointing at one hides the rest. This keeps them all on screen so you can see everywhere you have been at a glance."] = true
L["Click to open this dungeon's map"] = true
L["Dock AtlasLoot beside the map"] = true
L["The world map sits above AtlasLoot's window, so opening loot from a boss marker would otherwise put it behind the map. This moves it to the right of the map while the map is open, and puts it back afterwards."] = true
L["You are in: %s"] = true
L["Boss locations unknown for this dungeon"] = true
L["This client has no map art for this dungeon"] = true
L["Position derived from game data; may be approximate"] = true
L["Show entrance markers"] = true

-- Profile management
L["Every character starts on the shared Default profile, so a change made there follows you everywhere. To give one character its own settings, branch: the new profile starts as a copy of what you have now and only shows up for that character."] = true
L["Active profile"] = true
L["The profile this character reads its settings from."] = true
L["Branch for %s"] = true
L["%s already exists. Pick it from the Active profile list."] = true
L["Copies the active profile into %s and switches this character to it."] = true
L["Manage profiles"] = true
L["New profile"] = true
L["Type a name and press Enter. The new profile starts from the defaults and this character switches to it."] = true
L["Create the %s profile and switch to it?"] = true
L["Duplicate profile"] = true
L["Type a name and press Enter. Copies the %s profile into it and switches to the copy."] = true
L["Duplicate the %s profile into %s and switch to it?"] = true
L["Rename profile"] = true
L["The shared Default profile cannot be renamed."] = true
L["Type a name and press Enter. Renames the %s profile, and characters using it follow the new name."] = true
L["Rename the %s profile to %s?"] = true
L["Copy settings from"] = true
L["Replaces everything in the active profile with the settings of the profile you pick, including other characters' profiles. The profile you copy from is not changed."] = true
L["Replace everything in the %s profile with the settings from %s?"] = true
L["Reset profile"] = true
L["Returns every setting in the active profile to the defaults."] = true
L["Reset the %s profile? Every setting in it goes back to the defaults."] = true
L["Delete a profile"] = true
L["Removes a profile permanently. The active profile and Default are protected."] = true
L["Delete the %s profile? There is no undo."] = true
L["Backup and sharing"] = true
L["Copy the export text somewhere safe to back up this profile, or paste an export below to load one. Importing replaces everything in the active profile."] = true
L["Export"] = true
L["Select the text, then press Ctrl+C to copy it."] = true
L["Import"] = true
L["Paste a Wayfarer export, then press Accept."] = true
L["Replace everything in the %s profile with this import?"] = true
L["Settings imported into the %s profile."] = true
L["Nothing to import."] = true
L["This is not a Wayfarer export. The first line should be %s."] = true
L["Could not read this line: \"%s\""] = true
L["%s must be true or false."] = true
L["%s must be a number."] = true
L["Give the profile a name."] = true
L["Names containing \" - \" are reserved for character profiles."] = true
L["A profile named %s already exists."] = true
L["Draws an icon at each dungeon entrance. Off by default: the markers sit awkwardly on the zone art. The entrances still tooltip and still open their map either way."] = true
