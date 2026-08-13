local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon
local L = ns.L

-- Classic Era's world map shows the zone outside when you're standing in a
-- dungeon. The client does ship dungeon art, it just never puts it on the
-- map, so this draws it over the canvas: a 4x3 grid of 256px tiles at
-- Interface\Worldmap\<Dungeon>\<Dungeon><floor>_<tile>. Nothing is shipped
-- with the addon; it is all already on disk.
--
-- The map table and boss coordinates live in Core/DungeonData.lua.
local InstanceMaps = Wayfarer:NewModule("InstanceMaps")

InstanceMaps.mapPriority = 60
InstanceMaps.settingsKey = "instanceMaps"
InstanceMaps.optionsKey = "instancemaps"
InstanceMaps.optionsOrder = 60

-- GLOBALS: C_Map, GameTooltip, GetFileIDFromPath, GetInstanceInfo, GetSubZoneText
-- GLOBALS: IsInInstance, UIParent

local ipairs = ipairs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local pairs = pairs
local select = select
local sort = table.sort
local string_format = string.format
local string_gsub = string.gsub
local tinsert = table.insert
local unpack = unpack

local Colors = ns.Colors

-- The client's dungeon maps are a 4x3 grid of 256px tiles -- 1024x768 of
-- texture -- but only 1002x668 of that is map. The last column carries
-- 234 usable pixels and the bottom row 156; the rest is padding. (1002x668
-- is also exactly what the map's own ScrollContainer.Child measures.)
-- Stretching whole tiles stretches the padding too, which is where the
-- black margin down the right and bottom came from, so each tile is
-- cropped to its usable part and laid out in content space.
local MAP_COLS, MAP_ROWS = 4, 3
local TILE_COUNT = MAP_COLS * MAP_ROWS
local TILE_PX = 256
local GRID_W, GRID_H = TILE_PX * MAP_COLS, TILE_PX * MAP_ROWS
local CONTENT_W, CONTENT_H = 1002, 668

-- Boss and objective coordinates are percentages of the full 1024x768
-- tile grid, padding included -- they were authored against all twelve
-- tiles drawn whole. We crop the padding
-- and stretch only the 1002x668 of real map, so a coordinate has to be
-- converted out of grid space before it means anything on our frame.
-- Skipping this drifts pins upward, by nothing at the top and ~12
-- percentage points by four fifths of the way down.
local GridToFrame = function(x, y, width, height)
	return (x / 100) * (GRID_W / CONTENT_W) * width,
	       (y / 100) * (GRID_H / CONTENT_H) * height
end

local FrameToGrid = function(px, py, width, height)
	return (px / width) * (CONTENT_W / GRID_W) * 100,
	       (py / height) * (CONTENT_H / GRID_H) * 100
end

ns.GridToFrame = GridToFrame
ns.FrameToGrid = FrameToGrid

local BOSS_PIN_SIZE = 16

-- Picker, sized to the map's own dropdowns.
local ROW_HEIGHT = 16
local LIST_WIDTH = 260
local MAX_LIST_HEIGHT = 420
local SELECTOR_WIDTH = 130
local SELECTOR_HEIGHT = 24
local DROPDOWN_GAP = 5

local ARROW_NORMAL = "common-dropdown-classic-a-buttonDown"
local ARROW_HOVER = "common-dropdown-classic-a-buttonDown-hover"
local ARROW_PRESSED = "common-dropdown-classic-a-buttonDown-pressed"
local ARROW_PRESSED_HOVER = "common-dropdown-classic-a-buttonDown-pressedhover"

local GetArrowAtlas = function(button)
	if (button.isOver) and (button.isDown) then
		return ARROW_PRESSED_HOVER
	elseif (button.isOver) then
		return ARROW_HOVER
	elseif (button.isDown) then
		return ARROW_PRESSED
	end
	return ARROW_NORMAL
end

local ANCHOR_ROOT = "WorldMapContinentDropdown"
local ANCHOR_AFTER = { "WorldMapZoomOutButton", "WorldMapZoneDropdown" }
local ZOOM_BUTTON_Y_FUDGE = -3

local GetShownFrame = function(name)
	local frame = _G[name]
	if (frame) and (frame.IsShown) and (frame:IsShown()) and (frame:GetLeft()) then
		return frame
	end
end

-- "BlackrockDepths" -> "Blackrock Depths", with the data table catching
-- the names CamelCase splitting mangles ("The Temple of Atal'Hakkar").
local Prettify = function(folder)
	return ns.PrettyDungeonName(folder)
end

-- Dungeon lookup
----------------------------------------------------
-- Most dungeons follow <Dungeon><floor>_<tile>; a handful drop the floor
-- prefix entirely, which is what specialDungeons records.
local GetTexturePath = function(dungeon, floor, tile)
	if (ns.specialDungeons[dungeon] == "no_floor_prefix") then
		return "Interface\\Worldmap\\"..dungeon.."\\"..dungeon..tile
	end
	return "Interface\\Worldmap\\"..dungeon.."\\"..dungeon..floor.."_"..tile
end

-- Whether this client actually ships the tile art for a dungeon. A
-- missing set would otherwise render as a silently black map. Checked
-- once per dungeon: if the first tile of the first floor resolves, the
-- rest of the set is assumed to.
local artChecked = {}

local HasMapArt = function(dungeon)
	if (type(GetFileIDFromPath) ~= "function") then
		return true
	end
	if (artChecked[dungeon] == nil) then
		local floors = (dungeon and ns.dungeonFloors[dungeon]) or { 1 }
		artChecked[dungeon] = GetFileIDFromPath(GetTexturePath(dungeon, floors[1], 1)) ~= nil
	end
	return artChecked[dungeon]
end

-- The map's pin system hands pins frame levels from 2000 up to 9000
-- (MapCanvas_PinFrameLevelsManager), so an overlay below that range has
-- every map pin bleeding through it -- Questie's zone icons did. Sit
-- above the whole pin space. The map's own dropdowns and border chrome
-- live outside the canvas rect, so pins are the only thing this covers.
local GetPinCeiling = function(Canvas)
	local manager = Canvas and Canvas.GetPinFrameLevelsManager and Canvas:GetPinFrameLevelsManager()
	return ((manager and manager.maxLevel) or 9000) + 50
end

local GetFloors = function(dungeon)
	return (dungeon and ns.dungeonFloors[dungeon]) or { 1 }
end

local GetFloorName = function(dungeon, floor, index)
	local names = ns.floorNames[dungeon]
	if (names) and (names[index]) then
		return names[index]
	end
	return string_format(L["Floor %d"], floor)
end

-- Scarlet Monastery is four wings behind one instance ID, so the only way
-- to tell them apart is where the player is standing.
local DetectScarletWing = function()
	local uiMapID = C_Map.GetBestMapForUnit("player")
	if (not uiMapID) then
		return 1
	end

	local position = C_Map.GetPlayerMapPosition(uiMapID, "player")
	local x, y = position and position:GetXY()
	if (not x) then
		return 1
	end

	if (x < 0.4778) and (y < 0.1950) then
		return 1 -- Graveyard
	elseif (x >= 0.4778) and (y >= 0.1959) then
		return 2 -- Library
	elseif (x >= 0.4782) and (y >= 0.1953) and (y < 0.1959) then
		return 3 -- Armory
	end
	return 4 -- Cathedral
end

-- Subzones give us the floor for free in the dungeons that name them.
local GetFloorFromSubzone = function(dungeon)
	local subzone = GetSubZoneText and GetSubZoneText()
	if (not subzone) or (subzone == "") then
		return
	end

	local entry = ns.subzoneToFloor[(string_gsub(subzone, "%s", ""))]
	if (entry) and (entry[1] == dungeon) then
		return entry[2]
	end
end

-- The zone a dungeon's entrance is in, inverted from ns.dungeonPortals.
-- Dungeons with several entrances (Blackrock Mountain) resolve to the
-- lowest zone id, deterministically.
local zoneByDungeon

local GetEntranceZone = function(dungeon)
	if (not zoneByDungeon) then
		zoneByDungeon = {}
		for zoneUiMapID, portals in pairs(ns.dungeonPortals) do
			for _, portal in ipairs(portals) do
				local known = zoneByDungeon[portal.name]
				if (not known) or (zoneUiMapID < known) then
					zoneByDungeon[portal.name] = zoneUiMapID
				end
			end
		end
	end
	return zoneByDungeon[dungeon]
end

-- Which dungeon the player is standing in, or nil.
function InstanceMaps:GetPlayerDungeon()
	local inInstance, instanceType = IsInInstance()
	if (not inInstance) or (instanceType ~= "party" and instanceType ~= "raid") then
		return nil
	end

	local instanceMapID = select(8, GetInstanceInfo())
	if (not instanceMapID) then
		return nil
	end

	return ns.dungeonByMapID[instanceMapID], instanceMapID
end

-- Order matters. The subzone is the only thing the game will actually
-- tell us in here, so it goes first. Then whatever floor you were last
-- looking at, which is the useful answer when the game says nothing.
-- Coordinate detection is last and near-useless on Classic Era, where
-- there is no position inside an instance -- kept only in case a client
-- does report one.
function InstanceMaps:GetAutoFloor(dungeon)
	local fromSubzone = GetFloorFromSubzone(dungeon)
	if (fromSubzone) then
		return fromSubzone
	end

	local remembered = self:GetRememberedFloor(dungeon)
	if (remembered) then
		return remembered
	end

	if (ns.specialDungeons[dungeon] == "coordinate_detection") then
		return DetectScarletWing()
	end

	return ns.defaultFloor[dungeon] or 1
end

-- One row per dungeon for the picker, sorted by name.
local dungeonList = {}

local BuildDungeonList = function()
	if (#dungeonList > 0) then
		return
	end

	local seen = {}

	for instanceMapID, dungeon in pairs(ns.dungeonByMapID) do
		if (not seen[dungeon]) and (HasMapArt(dungeon)) then
			seen[dungeon] = true
			tinsert(dungeonList, {
				dungeon = dungeon,
				instanceMapID = instanceMapID,
				label = Prettify(dungeon)
			})
		end
	end

	sort(dungeonList, function(a, b) return a.label < b.label end)
end

-- Display
----------------------------------------------------
function InstanceMaps:CreateFrame()
	if (self.frame) then
		return self.frame
	end

	local Canvas = self:GetCanvas()
	local Container = self:GetContainer()

	local frame = CreateFrame("Frame", nil, Canvas)
	frame:SetFrameStrata(Canvas:GetFrameStrata())
	frame:SetFrameLevel(GetPinCeiling(Canvas))
	frame:SetAllPoints(Container)
	frame:EnableMouse(true)
	frame:Hide()

	local backdrop = frame:CreateTexture(nil, "BACKGROUND")
	backdrop:SetAllPoints()
	backdrop:SetColorTexture(0, 0, 0, 1)

	-- Right-click drops back to the zone map. The overlay covers the whole
	-- canvas, so without this there is no way to see where you are in the
	-- world while you are underground.
	frame:SetScript("OnMouseUp", function(_, button)
		if (button == "RightButton") then
			self:DismissMap()
		end
	end)

	-- The wheel must be swallowed either way: unhandled, it reaches the
	-- zoom on the zone map underneath and scrolling back throws you off
	-- the instance map. Spend it on something useful instead: stepping
	-- floors, scroll down for deeper.
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function(_, delta)
		self:StepFloor(delta < 0 and 1 or -1)
	end)

	frame.Tiles = {}

	-- Sized and placed by LayoutMap, which stretches them to the canvas.
	for i = 1, TILE_COUNT do
		frame.Tiles[i] = frame:CreateTexture(nil, "ARTWORK")
	end

	frame.BossPins = {}

	-- Header drawn over the top of the map, not above it. Reserving a
	-- strip above cost height the map could be using, and the canvas is
	-- wider than the map's 4:3 anyway, so the corners are free.
	local header = frame:CreateTexture(nil, "BORDER")
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", 0, 0)
	header:SetHeight(30)
	header:SetColorTexture(0, 0, 0, .55)
	frame.Header = header

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", header, "LEFT", 8, 0)
	title:SetJustifyH("LEFT")
	frame.Title = title

	local floorLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	floorLabel:SetPoint("CENTER", header, "CENTER", 0, 0)
	floorLabel:SetWidth(280)
	floorLabel:SetJustifyH("CENTER")
	frame.FloorLabel = floorLabel

	-- The client will not say where you are, but it will say which named
	-- room you are in. That is the honest version of "you are here".
	local location = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	location:SetPoint("RIGHT", header, "RIGHT", -8, 0)
	location:SetJustifyH("RIGHT")
	frame.Location = location

	local MakeArrow = function(flip, onClick)
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(24, 24)

		local arrow = button:CreateTexture(nil, "ARTWORK")
		arrow:SetAllPoints()
		arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
		if (flip) then
			arrow:SetTexCoord(1, 0, 0, 1)
		end

		button:SetScript("OnEnter", function() arrow:SetVertexColor(unpack(Colors.highlight)) end)
		button:SetScript("OnLeave", function() arrow:SetVertexColor(1, 1, 1) end)
		button:SetScript("OnClick", onClick)

		return button
	end

	local prev = MakeArrow(true, function() self:StepFloor(-1) end)
	prev:SetPoint("RIGHT", floorLabel, "LEFT", -4, 0)
	frame.PrevFloor = prev

	local next_ = MakeArrow(false, function() self:StepFloor(1) end)
	next_:SetPoint("LEFT", floorLabel, "RIGHT", 4, 0)
	frame.NextFloor = next_

	self.frame = frame

	return frame
end

-- Boss pins
----------------------------------------------------
-- The derived table only carries { name, x, y, floor }. The AtlasLoot
-- linkage -- atlasKey and atlasIndex per boss, atlasModule on the entry --
-- lives on the original placeholder record, which we replaced wholesale.
-- Dropping it left the blue skulls clickable but with nothing to open.
-- Match the two by name and put the loot fields back.
--
-- The original names carry decorations the derived ones do not ("Lord Roccor
-- (Wanders)"), and a couple carry stray trailing spaces, so compare on the
-- bare, trimmed name.
local BareName = function(name)
	name = string_gsub(name, "%s*%(.-%)%s*$", "")
	return (string_gsub(name, "^%s*(.-)%s*$", "%1"))
end

local mergedBosses = {}

local GetDerivedEntry = function(instanceMapID)
	if (mergedBosses[instanceMapID]) then
		return mergedBosses[instanceMapID]
	end

	local derivedList = ns.derivedBosses and ns.derivedBosses[instanceMapID]
	if (not derivedList) then
		return nil
	end

	local original = ns.dungeonBosses[instanceMapID]
	local byName = {}

	if (original) and (original.bosses) then
		for _, boss in ipairs(original.bosses) do
			byName[BareName(boss[1])] = boss
		end
	end

	local bosses = {}

	for _, boss in ipairs(derivedList) do
		local source = byName[BareName(boss[1])]
		bosses[#bosses + 1] = {
			boss[1], boss[2], boss[3], boss[4],
			source and source[5], source and source[6]
		}
	end

	local entry = { bosses = bosses, atlasModule = original and original.atlasModule }
	mergedBosses[instanceMapID] = entry

	return entry
end

-- Developer mode edits the underlying tables; the merge cache above
-- would otherwise keep serving the stale result.
function InstanceMaps:InvalidateBossCache(instanceMapID)
	if (instanceMapID) then
		mergedBosses[instanceMapID] = nil
	else
		mergedBosses = {}
	end
end
-- Coordinates are percentages of the 1024x768 map, the same space the
-- client's own dungeon art uses, so they drop straight on with no fitting.
function InstanceMaps:GetBossPin(index)
	local frame = self.frame
	local pin = frame.BossPins[index]

	if (not pin) then
		pin = CreateFrame("Button", nil, frame)
		pin:SetSize(BOSS_PIN_SIZE, BOSS_PIN_SIZE)
		pin:SetFrameLevel(frame:GetFrameLevel() + 5)

		local icon = pin:CreateTexture(nil, "OVERLAY")
		icon:SetAllPoints()
		icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")

		-- The sheet is 256px with 64px icons in a 4-column grid, so the
		-- eight markers occupy only its top half. Hand-rolled coords had
		-- this sampling the blank lower half -- the pin was there and
		-- took the mouse, it just drew nothing. Blizzard's own helper
		-- does the arithmetic; skull is index 8.
		if (SetRaidTargetIconTexture) then
			SetRaidTargetIconTexture(icon, 8)
		else
			icon:SetTexCoord(.75, 1, .25, .5)
		end

		pin.Icon = icon

		pin:SetScript("OnEnter", function(pinSelf)
			GameTooltip:SetOwner(pinSelf, "ANCHOR_RIGHT")
			GameTooltip:AddLine(pinSelf.bossName or "")
			if (pinSelf.derived) then
				GameTooltip:AddLine(L["Position derived from game data; may be approximate"], .55, .75, 1, true)
			end
			if (pinSelf.atlasKey) and (ns.HasAtlasLoot) and (ns.HasAtlasLoot()) then
				GameTooltip:AddLine(L["Click for loot"], .6, .6, .6)
			end
			GameTooltip:Show()
		end)

		pin:SetScript("OnLeave", function(pinSelf)
			if (pinSelf.derived) then
				icon:SetVertexColor(.55, .75, 1)
			else
				icon:SetVertexColor(1, 1, 1)
			end
			GameTooltip:Hide()
		end)

		pin:SetScript("OnClick", function(pinSelf)
			if (ns.OpenAtlasLootBoss) and (pinSelf.atlasKey) then
				ns.OpenAtlasLootBoss(pinSelf.atlasModule, pinSelf.atlasKey, pinSelf.atlasIndex)
			end
		end)

		frame.BossPins[index] = pin
	end

	return pin
end

function InstanceMaps:UpdateBossPins()
	local frame = self.frame
	if (not frame) then
		return
	end

	local db = self:GetSettings()
	local shown = 0

	local entry = db.showBosses and self.instanceMapID and ns.dungeonBosses[self.instanceMapID]
	local derived = false

	-- A placeholder grid is worse than nothing: it looks like data. Where
	-- we have derived positions for one, use those instead and mark them.
	if (self.instanceMapID) and (ns.unpositionedBosses[self.instanceMapID]) then
		local fallback = db.showBosses and GetDerivedEntry(self.instanceMapID)

		if (fallback) then
			entry = fallback
			derived = true
		else
			entry = nil
		end
	end

	if (entry) and (entry.bosses) then
		for _, boss in ipairs(entry.bosses) do
			local name, x, y, floor = boss[1], boss[2], boss[3], boss[4]

			-- Only the bosses on the floor we're looking at.
			if (floor == self.floor) then
				shown = shown + 1

				local pin = self:GetBossPin(shown)
				pin.bossName = name
				pin.atlasModule = entry.atlasModule
				pin.atlasKey = boss[5]
				pin.atlasIndex = boss[6]
				pin.derived = derived

				-- Derived positions are drawn cooler and say so on hover,
				-- so they are never mistaken for authored ones.
				if (derived) then
					pin.Icon:SetVertexColor(.55, .75, 1)
				else
					pin.Icon:SetVertexColor(1, 1, 1)
				end

				local width, height = frame:GetSize()
				local px, py = GridToFrame(x, y, width, height)

				pin:ClearAllPoints()
				pin:SetPoint("CENTER", frame, "TOPLEFT", px, -py)
				pin:Show()
			end
		end
	end

	for i = shown + 1, #frame.BossPins do
		frame.BossPins[i]:Hide()
	end
end

-- No player arrow. Classic Era reports no position inside an instance:
-- both C_Map.GetBestMapForUnit and UnitPosition come back nil in here, so
-- there is nothing to draw one from. Kept as a stub so callers don't need
-- to care.
function InstanceMaps:UpdatePlayerPin()
	if (self.frame) and (self.frame.PlayerPin) then
		self.frame.PlayerPin:Hide()
	end
end

-- Stretch the map across the whole canvas, corner to corner, the way the
-- zone map does. The art is 4:3 and the canvas is wider, so this does
-- distort it a little -- but everything we place on the map is a
-- percentage of it, so bosses and pins stay exactly where they belong
-- under a non-uniform stretch. Preserving the 4:3 shape was only ever
-- buying us empty margins.
function InstanceMaps:LayoutMap()
	local frame = self.frame
	local Container = self:GetContainer()

	if (not frame) or (not Container) then
		return
	end

	local width, height = Container:GetSize()
	if (not width) or (width <= 0) or (not height) or (height <= 0) then
		return
	end

	frame:SetScale(1)
	frame:ClearAllPoints()
	frame:SetAllPoints(Container)

	-- Positions come from rounded *boundaries* in content space, so
	-- neighbours share an exact edge instead of leaving hairline seams
	-- where fractional widths accumulate across a row.
	for i = 1, TILE_COUNT do
		local col = (i - 1) % MAP_COLS
		local row = math_floor((i - 1) / MAP_COLS)

		local tile = frame.Tiles[i]

		-- Where this tile sits in the 1002x668 of actual map, and how
		-- much of its 256px texture is map rather than padding.
		local contentX, contentY = col * TILE_PX, row * TILE_PX
		local usableW = math_min(TILE_PX, CONTENT_W - contentX)
		local usableH = math_min(TILE_PX, CONTENT_H - contentY)

		if (usableW <= 0) or (usableH <= 0) then
			tile:Hide()
		else
			tile:SetTexCoord(0, usableW / TILE_PX, 0, usableH / TILE_PX)

			local left = math_floor(contentX / CONTENT_W * width + .5)
			local right = math_floor((contentX + usableW) / CONTENT_W * width + .5)
			local top = math_floor(contentY / CONTENT_H * height + .5)
			local bottom = math_floor((contentY + usableH) / CONTENT_H * height + .5)

			tile:ClearAllPoints()
			tile:SetSize(right - left, bottom - top)
			tile:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
			tile:Show()
		end
	end

	-- Pins are placed against the frame's size, which has just changed.
	self:UpdateBossPins()
	Wayfarer:SendMessage("Wayfarer_InstanceMapResized")
end

function InstanceMaps:StepFloor(delta)
	local floors = GetFloors(self.dungeon)
	if (#floors < 2) then
		return
	end

	local index = (self.floorIndex or 1) + delta

	if (index < 1) then
		index = #floors
	elseif (index > #floors) then
		index = 1
	end

	self:SetFloorIndex(index, true)
end

function InstanceMaps:GetRememberedFloor(dungeon)
	local db = Wayfarer.db
	return db and db.profile.lastFloor and db.profile.lastFloor[dungeon]
end

function InstanceMaps:RememberFloor(dungeon, floor)
	local db = Wayfarer.db
	if (not db) or (not dungeon) then
		return
	end

	db.profile.lastFloor = db.profile.lastFloor or {}
	db.profile.lastFloor[dungeon] = floor
end

-- remember: only a deliberate change is worth storing. Auto-detection
-- writing back would overwrite the choice it is meant to defer to.
function InstanceMaps:SetFloorIndex(index, remember)
	local floors = GetFloors(self.dungeon)

	self.floorIndex = index
	self.floor = floors[index] or 1

	if (remember) then
		self:RememberFloor(self.dungeon, self.floor)
	end

	self:Draw()
end

function InstanceMaps:Draw()
	local frame = self.frame
	if (not frame) or (not self.dungeon) then
		return
	end

	local hasArt = HasMapArt(self.dungeon)

	for i = 1, TILE_COUNT do
		if (hasArt) then
			frame.Tiles[i]:SetTexture(GetTexturePath(self.dungeon, self.floor, i))
			frame.Tiles[i]:Show()
		else
			frame.Tiles[i]:Hide()
		end
	end

	frame.Title:SetText(Prettify(self.dungeon))

	local floors = GetFloors(self.dungeon)
	local index = self.floorIndex or 1

	if (#floors > 1) then
		frame.FloorLabel:SetFormattedText("%s  |cff888888(%d/%d)|r",
			GetFloorName(self.dungeon, self.floor, index), index, #floors)
		frame.PrevFloor:Show()
		frame.NextFloor:Show()
	else
		frame.FloorLabel:SetText(GetFloorName(self.dungeon, self.floor, index))
		frame.PrevFloor:Hide()
		frame.NextFloor:Hide()
	end

	-- Only meaningful for the dungeon you are standing in.
	local subzone = self.isPlayerDungeon and GetSubZoneText and GetSubZoneText()

	if (not hasArt) then
		frame.Location:SetText("|cffcc8844"..L["This client has no map art for this dungeon"].."|r")
		frame.Location:Show()
	elseif (self.instanceMapID) and (ns.unpositionedBosses[self.instanceMapID])
	   and (not (ns.derivedBosses and ns.derivedBosses[self.instanceMapID]))
	   and (self:GetSettings().showBosses) then
		frame.Location:SetText("|cffcc8844"..L["Boss locations unknown for this dungeon"].."|r")
		frame.Location:Show()
	elseif (subzone) and (subzone ~= "") then
		frame.Location:SetFormattedText(L["You are in: %s"], subzone)
		frame.Location:Show()
	else
		frame.Location:Hide()
	end

	self:UpdateBossPins()
	self:LayoutMap()

	-- Integrations hang off this rather than reaching into us.
	Wayfarer:SendMessage("Wayfarer_InstanceMapShown",
		self.dungeon, self.floor, self.instanceMapID, frame)
end

function InstanceMaps:ShowDungeon(dungeon, instanceMapID, floor, isPlayerDungeon)
	self.dungeon = dungeon
	self.instanceMapID = instanceMapID
	self.isPlayerDungeon = isPlayerDungeon and true or false

	local floors = GetFloors(dungeon)
	local index = 1

	for i, value in ipairs(floors) do
		if (value == floor) then
			index = i
			break
		end
	end

	self:CreateFrame():Show()
	self:SetFloorIndex(index)
end

-- Back to the zone map, however the dungeon map got on screen. A hand
-- picked preview just needs the selection cleared; standing in a dungeon
-- also needs the suppressed flag, or auto-detection reclaims the canvas
-- on the very next refresh.
function InstanceMaps:DismissMap()
	local wasShowing = self.selection or (self.frame and self.frame:IsShown())
	if (not wasShowing) then
		return
	end

	self.selection = nil
	self.suppressed = self:GetPlayerDungeon() and true or nil

	-- Inside an instance the client cannot resolve a map for the player,
	-- so the canvas underneath is whatever was last viewed, often the
	-- continent. The zone map behind the Stockade is Stormwind: go there.
	if (self.suppressed) then
		local dungeon = self:GetPlayerDungeon()
		local zone = dungeon and GetEntranceZone(dungeon)
		local Canvas = self:GetCanvas()
		if (zone) and (Canvas) and (Canvas.SetMapID) and (Canvas:GetMapID() ~= zone) then
			Canvas:SetMapID(zone)
		end
	end

	self:Refresh()

	if (self.suppressed) then
		Wayfarer:Print(L["Showing the zone map. Pick the dungeon from the map dropdown to go back."])
	end
end

function InstanceMaps:HideMap()
	if (self.frame) and (self.frame:IsShown()) then
		self.frame:Hide()
		Wayfarer:SendMessage("Wayfarer_InstanceMapHidden")
	end

	self.dungeon = nil
	self.instanceMapID = nil
end

-- Anything an integration needs to place a pin of its own.
function InstanceMaps:GetMapContext()
	if (not self.dungeon) or (not self.frame) or (not self.frame:IsShown()) then
		return nil
	end
	local width, height = self.frame:GetSize()
	return self.frame, self.dungeon, self.floor, self.instanceMapID, width, height
end

-- Instance picker
----------------------------------------------------
function InstanceMaps:SetSelection(entry)
	self.selection = entry

	-- Picking a dungeon always shows it; picking "Zone Map" means show me
	-- the zone, including when standing in a dungeon that would otherwise
	-- take the canvas straight back.
	if (entry) then
		self.suppressed = nil
	else
		self.suppressed = self:GetPlayerDungeon() and true or nil
	end

	self:CloseList()
	self:Refresh()
end

function InstanceMaps:CloseList()
	if (self.list) then
		self.list:Hide()
	end
end

function InstanceMaps:ToggleList()
	local list = self:CreateList()
	if (list:IsShown()) then
		list:Hide()
	else
		self:RefreshList()
		list:SetFrameLevel(self.selector:GetFrameLevel() + 10)
		list:Show()
		list:Raise()
	end
end

function InstanceMaps:CreateSelector()
	if (self.selector) then
		return self.selector
	end

	local Container = self:GetContainer()

	local button = CreateFrame("Button", nil, self:GetCanvas())
	button:SetSize(SELECTOR_WIDTH, SELECTOR_HEIGHT)
	button:SetPoint("BOTTOMLEFT", Container, "TOPLEFT", 8, 4)

	-- WorldMapFrame runs at FULLSCREEN strata, and FULLSCREEN outranks
	-- both HIGH and DIALOG. Asking for anything lower just gets clamped
	-- up to the parent's, so say what we actually mean.
	button:SetFrameStrata("FULLSCREEN")
	button:SetFrameLevel(GetPinCeiling(self:GetCanvas()) + 20)
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonUp")

	-- Same atlas the map's own dropdowns use, with the same insets, so
	-- ours reads as part of the row instead of a bolted-on box.
	local backdrop = button:CreateTexture(nil, "BACKGROUND")
	backdrop:SetPoint("TOPLEFT", -9, 8)
	backdrop:SetPoint("BOTTOMRIGHT", 8, -9)
	if (backdrop.SetAtlas) then
		backdrop:SetAtlas("common-dropdown-classic-textholder", true)
	else
		backdrop:SetColorTexture(0, 0, 0, .7)
	end

	local arrow = button:CreateTexture(nil, "OVERLAY")
	arrow:SetPoint("RIGHT", -1, 0)
	if (arrow.SetAtlas) then
		arrow:SetAtlas(ARROW_NORMAL, true)
	else
		arrow:SetSize(16, 16)
		arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
		arrow:SetRotation(-1.5708)
	end

	local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOPRIGHT", arrow, "LEFT", 0, 0)
	label:SetPoint("TOPLEFT", 9, -7)
	label:SetJustifyH("RIGHT")
	label:SetWordWrap(false)
	button.Label = label
	button.Arrow = arrow

	-- Mirror the dropdown's own hover and press feedback.
	local UpdateState = function()
		if (arrow.SetAtlas) then
			arrow:SetAtlas(GetArrowAtlas(button), true)
		else
			local shade = button.isOver and 1 or .8
			arrow:SetVertexColor(shade, shade, shade)
		end
	end

	button:SetScript("OnEnter", function() button.isOver = true; UpdateState() end)
	button:SetScript("OnLeave", function() button.isOver = nil; UpdateState() end)
	button:SetScript("OnMouseDown", function() button.isDown = true; UpdateState() end)
	button:SetScript("OnMouseUp", function() button.isDown = nil; UpdateState() end)
	button:SetScript("OnClick", function() self:ToggleList() end)

	UpdateState()

	self.selector = button

	return button
end

function InstanceMaps:CreateList()
	if (self.list) then
		return self.list
	end

	local selector = self:CreateSelector()

	-- Parented to the selector, so re-anchoring the selector carries the
	-- list along. FULLSCREEN_DIALOG keeps it above the map; DIALOG is
	-- below FULLSCREEN and would open behind it.
	local list = CreateFrame("Frame", nil, selector)
	list:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", -9, -2)
	list:SetWidth(LIST_WIDTH)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:SetToplevel(true)
	list:EnableMouse(true)
	list:Hide()

	local backdrop = list:CreateTexture(nil, "BACKGROUND")
	backdrop:SetAllPoints()
	backdrop:SetColorTexture(0, 0, 0, .92)

	local scroll = CreateFrame("ScrollFrame", nil, list)
	scroll:SetPoint("TOPLEFT", 4, -4)
	scroll:SetPoint("BOTTOMRIGHT", -4, 4)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(LIST_WIDTH - 8, 1)
	scroll:SetScrollChild(content)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(scrollSelf, delta)
		local current = scrollSelf:GetVerticalScroll()
		local maximum = math_max(0, content:GetHeight() - scrollSelf:GetHeight())
		scrollSelf:SetVerticalScroll(math_max(0, math_min(maximum, current - delta * ROW_HEIGHT * 3)))
	end)

	list.Scroll = scroll
	list.Content = content
	list.Rows = {}

	self.list = list

	return list
end

function InstanceMaps:GetListRow(index)
	local list = self.list
	local row = list.Rows[index]

	if (not row) then
		row = CreateFrame("Button", nil, list.Content)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("LEFT", list.Content, "LEFT", 0, 0)
		row:SetPoint("RIGHT", list.Content, "RIGHT", 0, 0)

		if (index == 1) then
			row:SetPoint("TOP", list.Content, "TOP", 0, 0)
		else
			row:SetPoint("TOP", list.Rows[index - 1], "BOTTOM", 0, 0)
		end

		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, .12)

		local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", 6, 0)
		label:SetPoint("RIGHT", -6, 0)
		label:SetJustifyH("LEFT")
		row.Label = label

		list.Rows[index] = row
	end

	return row
end

function InstanceMaps:RefreshList()
	BuildDungeonList()

	local list = self:CreateList()
	local index = 1

	local zoneRow = self:GetListRow(index)
	zoneRow.Label:SetText(Colors.title.colorCode..L["Zone Map"].."|r")
	zoneRow:SetScript("OnClick", function() self:SetSelection(nil) end)
	zoneRow:Show()

	for _, entry in ipairs(dungeonList) do
		index = index + 1
		local row = self:GetListRow(index)
		row.Label:SetText(entry.label)
		row:SetScript("OnClick", function() self:SetSelection(entry) end)
		row:Show()
	end

	for i = index + 1, #list.Rows do
		list.Rows[i]:Hide()
	end

	local contentHeight = index * ROW_HEIGHT
	list.Content:SetHeight(contentHeight)
	list:SetHeight(math_min(contentHeight, MAX_LIST_HEIGHT) + 8)
	list.Scroll:SetVerticalScroll(0)
end

-- Slide the map's own navigation left to make room, and sit our picker
-- at the end of the row. Idempotent: the root's original anchor is
-- remembered, so repeated calls re-place rather than compound.
function InstanceMaps:PositionSelector()
	local selector = self.selector
	if (not selector) then
		return
	end

	local root = GetShownFrame(ANCHOR_ROOT)
	local shift = (SELECTOR_WIDTH + DROPDOWN_GAP) / 2

	if (root) then
		local anchor = self.rootAnchor

		if (not anchor) then
			local point, relativeTo, relativePoint, x, y = root:GetPoint(1)
			if (point) then
				anchor = { point = point, relativeTo = relativeTo,
				           relativePoint = relativePoint, x = x or 0, y = y or 0 }
				self.rootAnchor = anchor
			end
		end

		if (anchor) then
			root:ClearAllPoints()
			root:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint,
				anchor.x - shift, anchor.y)
		end
	end

	local after, fudge
	for _, name in ipairs(ANCHOR_AFTER) do
		after = GetShownFrame(name)
		if (after) then
			fudge = (name == "WorldMapZoomOutButton") and ZOOM_BUTTON_Y_FUDGE or 0
			break
		end
	end

	selector:ClearAllPoints()

	if (after) then
		-- Anchored to the row but deliberately NOT parented into it:
		-- MapCanvas drops BorderFrame to frame level 1 so the border sits
		-- behind the canvas, and anything parented in there goes under
		-- the map with it and stops taking clicks.
		selector:SetPoint("LEFT", after, "RIGHT", DROPDOWN_GAP, fudge)
		return true
	end

	local Container = self:GetContainer()
	selector:SetPoint("BOTTOMLEFT", Container, "TOPLEFT", 8, 4)

	return false
end

-- The first time the map is opened, Blizzard_WorldMap has only just loaded
-- on demand: OnShow fires before its dropdowns have been laid out, so there
-- is nothing to anchor to yet. Keep re-checking for a moment rather than
-- settling for the fallback.
local RETRY_DELAY = .1
local MAX_RETRIES = 20

function InstanceMaps:RetryPositioning()
	if ((self.retries or 0) >= MAX_RETRIES) then
		return
	end

	self.retries = (self.retries or 0) + 1
	self.retryTimer = self:ScheduleTimer("OnPositionRetry", RETRY_DELAY)
end

-- The timer fires through here rather than straight into UpdateSelector,
-- so the handle is cleared before the next attempt decides whether one is
-- already pending.
function InstanceMaps:OnPositionRetry()
	self.retryTimer = nil
	self:UpdateSelector()
end

function InstanceMaps:UpdateSelector()
	local db = self:GetSettings()

	if (not db.enable) or (not db.showSelector) then
		if (self.selector) then
			self.selector:Hide()
			self:CloseList()
		end
		return
	end

	local selector = self:CreateSelector()
	selector.Label:SetText(self.selection and self.selection.label or L["Zone Map"])
	selector:Show()

	if (self:PositionSelector()) then
		self.retries = nil
	elseif (not self.retryTimer) then
		self:RetryPositioning()
	end
end

-- Module
----------------------------------------------------
function InstanceMaps:Refresh()
	if (not self:IsMapReady()) then
		return
	end

	local db = self:GetSettings()

	-- Each refresh is a fresh chance to find the row.
	self.retries = nil

	if (not db.enable) then
		self:HideMap()
		self:UpdateSelector()
		return
	end

	self:UpdateSelector()

	if (self.selection) then
		-- Picked by hand: show it wherever we are.
		local entry = self.selection
		self:ShowDungeon(entry.dungeon, entry.instanceMapID,
			self:GetRememberedFloor(entry.dungeon) or ns.defaultFloor[entry.dungeon] or 1, false)
		return
	end

	local dungeon, instanceMapID = self:GetPlayerDungeon()

	if (not dungeon) or (self.suppressed) then
		self:HideMap()
		return
	end

	self:ShowDungeon(dungeon, instanceMapID, self:GetAutoFloor(dungeon), true)
end

function InstanceMaps:OnMapRelaidOut()
	self:LayoutMap()
	self:UpdateSelector()
end

-- A genuine world transition drops any hand-picked map, so you don't walk
-- into a dungeon still looking at the last one you browsed.
function InstanceMaps:OnWorldChanged()
	self.selection = nil
	self.suppressed = nil
	self:Refresh()
end

-- Opening the map always starts where the player is: the dungeon you are
-- standing in, or otherwise your current zone. Hand-picked browsing is
-- for while the map is open; it does not survive closing it.
function InstanceMaps:OnMapOpened()
	self.selection = nil
	self.suppressed = nil

	local Canvas = self:GetCanvas()
	local uiMapID = C_Map.GetBestMapForUnit("player")
	if (not uiMapID) then
		-- No position inside an instance; park the canvas on the zone the
		-- entrance is in so dismissing the overlay lands somewhere sane.
		local dungeon = self:GetPlayerDungeon()
		uiMapID = dungeon and GetEntranceZone(dungeon)
	end
	if (uiMapID) and (Canvas) and (Canvas.SetMapID) and (Canvas:GetMapID() ~= uiMapID) then
		Canvas:SetMapID(uiMapID)
	end

	self:Refresh()
end

function InstanceMaps:OnMapReady()
	BuildDungeonList()

	self:CreateSelector()

	self:SecureHookScript(self:GetCanvas(), "OnShow", "OnMapOpened")
	self:SecureHookScript(self:GetCanvas(), "OnHide", "CloseList")

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnWorldChanged")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Refresh")
	self:RegisterEvent("ZONE_CHANGED", "Refresh")
	-- Walking between the Scarlet Monastery wings is a subzone change
	-- and nothing else, so this is what notices it.
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "Refresh")

	self:RegisterMessage("Wayfarer_MapDisplayStateChanged", "OnMapRelaidOut")

	-- Our hooks go on during the load that the first map open triggered,
	-- so that first OnShow has already been and gone. Sweep once more.
	self:ScheduleTimer("UpdateSelector", 0)
end

function InstanceMaps:OnConfigChanged()
	self:Refresh()
end

function InstanceMaps:GetOptions()
	local Disabled = function() return not Wayfarer.db.profile.instanceMaps.enable end

	return {
		name = L["Instance Maps"],
		args = {
			description = {
				order = 1,
				type = "description",
				name = L["Classic Era never puts the client's own dungeon maps on the world map. Wayfarer draws them over the canvas instead, with boss locations."]
			},
			enable = {
				order = 10,
				type = "toggle", width = "full",
				name = L["Show instance maps"],
				desc = L["Draws the dungeon map on the world map whenever you are in one."],
				get = ns.Getter("instanceMaps", "enable"),
				set = ns.Setter("instanceMaps", "enable")
			},
			showSelector = {
				order = 15,
				type = "toggle", width = "full",
				name = L["Show the map picker"],
				desc = L["Puts a dropdown on the world map for reading any dungeon map from anywhere. Picking one overrides the zone map until you pick Zone Map again or close the map."],
				disabled = Disabled,
				get = ns.Getter("instanceMaps", "showSelector"),
				set = ns.Setter("instanceMaps", "showSelector")
			},
			showBosses = {
				order = 20,
				type = "toggle", width = "full",
				name = L["Show boss locations"],
				desc = L["Marks where each boss is found on the floor you are looking at."],
				disabled = Disabled,
				get = ns.Getter("instanceMaps", "showBosses"),
				set = ns.Setter("instanceMaps", "showBosses")
			},
			positionNote = {
				order = 30,
				type = "description",
				name = L["Classic Era reports no player position inside an instance, so a \"you are here\" marker is not possible here."]
			}
		}
	}
end
