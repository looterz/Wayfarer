local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon
local L = ns.L

-- Optional hooks into the addons people already run alongside a map:
-- Questie for quest objectives, AtlasLoot for boss loot, Leatrix_Maps for
-- its dungeon entrance pins. Every one of these is optional and probed at
-- use, so a missing addon costs nothing and breaks nothing.
local Integrations = Wayfarer:NewModule("Integrations")

Integrations.mapPriority = 70
Integrations.settingsKey = "integrations"
Integrations.optionsKey = "integrations"
Integrations.optionsOrder = 70

-- GLOBALS: AtlasLoot, C_Timer, GameTooltip, GetInstanceInfo, QuestieLoader
-- GLOBALS: WorldMapFrame, hooksecurefunc, PIN_FRAME_LEVEL_DUNGEON_ENTRANCE

local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local pcall = pcall
local select = select
local string_format = string.format
local string_gsub = string.gsub
local unpack = unpack
local tinsert = table.insert

local Colors = ns.Colors

local QUEST_PIN_SIZE = 14

-- Questie's spawn table lists *every* spawn point of an objective mob. In
-- a dungeon populated by one or two mob types that is hundreds of points,
-- and a quest only needs one of them killed, so drawing them all buries
-- the map. These keep it to a usable number of markers.
local MAX_SPAWNS_PER_OBJECTIVE = 2
local MAX_QUEST_PINS = 15

-- Collapse spawns onto a coarse grid before deduping, so a pack of mobs
-- standing together becomes one marker instead of twelve.
local DEDUPE_GRID = 6

local PIN_ICONS = {
	kill = "Interface\\GossipFrame\\BattleMasterGossipIcon",
	object = "Interface\\GossipFrame\\WorkOrderGossipIcon",
	loot = "Interface\\GossipFrame\\VendorGossipIcon",
	turnin = "Interface\\GossipFrame\\ActiveQuestIcon"
}

-- Presence checks
----------------------------------------------------
ns.HasAtlasLoot = function()
	-- AtlasLoot.GUI is created by GUI/GUI.lua at load, but gating the
	-- whole integration on it means a single ordering hiccup reads as
	-- "not installed". Presence is the global; the GUI is checked when
	-- we actually try to open something.
	return AtlasLoot ~= nil
end

ns.HasQuestie = function()
	return QuestieLoader ~= nil
end

ns.HasLeatrixMaps = function()
	local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	local ok, loaded = pcall(IsAddOnLoaded, "Leatrix_Maps")
	return ok and loaded and true or false
end

-- AtlasLoot
----------------------------------------------------
-- Opening a specific boss means driving AtlasLoot's GUI from outside, and
-- its panels populate asynchronously. Selecting a boss alone does not
-- refresh the loot list; only the difficulty callback does, and the
-- difficulty list is not built until the boss select lands. So: retry
-- until the data shows up, then fire the difficulty select.
local ATLAS_RETRY = .2
local ATLAS_MAX_TRIES = 10

ns.OpenAtlasLootBoss = function(module, instanceKey, bossIndex)
	if (not ns.HasAtlasLoot()) then
		Wayfarer:Print(L["AtlasLoot is not installed."])
		return
	end

	if (not module) or (not instanceKey) or (not bossIndex) then
		return
	end

	local gui = AtlasLoot.GUI

	if (not gui.frame) and (gui.Create) then
		pcall(gui.Create, gui)
	end

	if (not gui.frame) then
		return
	end

	gui.frame:Show()

	-- The world map runs at FULLSCREEN strata, so AtlasLoot's window
	-- opens behind it and cannot be reached without closing the map.
	-- Dock it to the right instead.
	Integrations:DockAtlasLoot()

	if (not pcall(function() gui.frame.moduleSelect:SetSelected(module) end)) then
		return
	end

	-- Some entries are flagged ExtraList (heroic-only summons, event pages)
	-- and live in the extra dropdown rather than the boss one.
	local isExtra = false

	local Refresh
	Refresh = function(attempt)
		local done = pcall(function()
			if (isExtra) then
				gui.frame.extra:SetSelected(bossIndex)
			else
				gui.frame.boss:SetSelected(bossIndex)
			end

			local difficulty = gui.frame.difficulty
			if not (difficulty and difficulty.data and difficulty.data[1]) then
				error("difficulty list not built yet")
			end
			difficulty:SetSelected(nil, 1)
		end)

		if (done) then
			return
		end

		if (attempt < ATLAS_MAX_TRIES) then
			C_Timer.After(ATLAS_RETRY, function() Refresh(attempt + 1) end)
		end
	end

	local Select
	Select = function(attempt)
		local data = AtlasLoot.ItemDB and AtlasLoot.ItemDB:Get(module)

		if (data) and (data[instanceKey]) then
			pcall(function()
				local items = data[instanceKey].items
				isExtra = (items and items[bossIndex] and items[bossIndex].ExtraList) and true or false
			end)

			pcall(function() gui.frame.subCatSelect:SetSelected(instanceKey) end)
			C_Timer.After(ATLAS_RETRY, function() Refresh(1) end)
			return
		end

		if (attempt < ATLAS_MAX_TRIES) then
			C_Timer.After(ATLAS_RETRY, function() Select(attempt + 1) end)
		end
	end

	Select(1)
end

-- Docking AtlasLoot beside the map
----------------------------------------------------
-- Rather than reimplement AtlasLoot's item list, we move its own window
-- to the right of the world map and lift it above the map's strata. Its
-- original parent, anchor and strata are remembered and put back when the
-- map closes, so its normal behaviour is unchanged outside our use.
local DOCK_GAP = 8

function Integrations:DockAtlasLoot()
	if (not self:GetSettings().dockAtlasLoot) then
		return
	end

	local frame = AtlasLoot and AtlasLoot.GUI and AtlasLoot.GUI.frame
	local Canvas = self:GetCanvas()

	if (not frame) or (not Canvas) or (not Canvas:IsShown()) then
		return
	end

	if (not self.atlasLootRestore) then
		local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
		self.atlasLootRestore = {
			parent = frame:GetParent(),
			strata = frame:GetFrameStrata(),
			point = point, relativeTo = relativeTo, relativePoint = relativePoint,
			x = x or 0, y = y or 0
		}
	end

	frame:SetParent(UIParent)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:ClearAllPoints()

	-- To the right of the map if it fits, otherwise overlapping its right
	-- edge rather than off the screen entirely.
	local room = (UIParent:GetWidth() or 0) - (Canvas:GetRight() or 0)

	if (room >= (frame:GetWidth() or 0) + DOCK_GAP) then
		frame:SetPoint("TOPLEFT", Canvas, "TOPRIGHT", DOCK_GAP, 0)
	else
		frame:SetPoint("TOPRIGHT", Canvas, "TOPRIGHT", -DOCK_GAP, -DOCK_GAP)
	end

	frame:Raise()
end

function Integrations:UndockAtlasLoot()
	local restore = self.atlasLootRestore
	local frame = AtlasLoot and AtlasLoot.GUI and AtlasLoot.GUI.frame

	if (not restore) or (not frame) then
		return
	end

	frame:SetParent(restore.parent or UIParent)
	frame:SetFrameStrata(restore.strata or "MEDIUM")
	frame:ClearAllPoints()

	if (restore.point) then
		frame:SetPoint(restore.point, restore.relativeTo, restore.relativePoint, restore.x, restore.y)
	else
		frame:SetPoint("CENTER")
	end

	self.atlasLootRestore = nil
end

-- Questie
----------------------------------------------------
function Integrations:GetQuestPin(index)
	self.questPins = self.questPins or {}

	local pin = self.questPins[index]

	if (not pin) then
		local frame, _, _, _, _, _ = Wayfarer:GetModule("InstanceMaps"):GetMapContext()
		if (not frame) then
			return nil
		end

		pin = CreateFrame("Frame", nil, frame)
		pin:SetSize(QUEST_PIN_SIZE, QUEST_PIN_SIZE)
		pin:SetFrameLevel(frame:GetFrameLevel() + 6)
		pin:EnableMouse(true)

		local icon = pin:CreateTexture(nil, "OVERLAY")
		icon:SetAllPoints()
		pin.Icon = icon

		pin:SetScript("OnEnter", function(pinSelf)
			GameTooltip:SetOwner(pinSelf, "ANCHOR_RIGHT")
			GameTooltip:AddLine(pinSelf.questName or "")
			if (pinSelf.objectiveText) and (pinSelf.objectiveText ~= "") then
				GameTooltip:AddLine(pinSelf.objectiveText, .8, .8, .8, true)
			end
			GameTooltip:Show()
		end)

		pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

		self.questPins[index] = pin
	end

	return pin
end

function Integrations:HideQuestPins()
	if (not self.questPins) then
		return
	end
	for _, pin in ipairs(self.questPins) do
		pin:Hide()
	end
end

-- Walks the player's quest log and drops a pin on every objective that
-- resolves to a spawn inside the dungeon currently on screen.
function Integrations:ShowQuestPins()
	self:HideQuestPins()

	local db = self:GetSettings()
	if (not db.questie) or (not ns.HasQuestie()) then
		return
	end

	local InstanceMaps = Wayfarer:GetModule("InstanceMaps", true)
	if (not InstanceMaps) then
		return
	end

	local frame, dungeon, floor, instanceMapID, mapWidth, mapHeight = InstanceMaps:GetMapContext()
	if (not frame) then
		return
	end

	-- Only for the dungeon we're standing in; a browsed map has no
	-- relationship to our quest log.
	if (not InstanceMaps.isPlayerDungeon) then
		return
	end

	local areaID = instanceMapID and ns.questieAreaByInstance[instanceMapID]
	if (not areaID) then
		return
	end

	local ok, QuestieDB = pcall(function() return QuestieLoader:ImportModule("QuestieDB") end)
	if (not ok) or (not QuestieDB) then
		return
	end

	local okPlayer, QuestiePlayer = pcall(function() return QuestieLoader:ImportModule("QuestiePlayer") end)
	if (not okPlayer) or (not QuestiePlayer) or (not QuestiePlayer.currentQuestlog) then
		return
	end

	local fallbacks = ns.npcPositions[areaID]
	local index, seen = 0, {}

	local Place = function(x, y, questName, objectiveText, pinType)
		if (not x) or (not y) or (x < 0) or (y < 0) or (x > 100) or (y > 100) then
			return false
		end

		if (index >= MAX_QUEST_PINS) then
			return false
		end

		-- Snap to a coarse grid so a clustered pack collapses to one pin.
		local key = string_format("%d,%d",
			math_floor(x / DEDUPE_GRID), math_floor(y / DEDUPE_GRID))

		if (seen[key]) then
			return true
		end
		seen[key] = true

		index = index + 1

		local pin = self:GetQuestPin(index)
		if (not pin) then
			return false
		end

		pin.questName = questName or ""
		pin.objectiveText = objectiveText or ""
		pin.Icon:SetTexture(PIN_ICONS[pinType or "kill"] or PIN_ICONS.kill)
		-- Same grid-space convention as the boss coordinates.
		local px, py = ns.GridToFrame(x, y, mapWidth, mapHeight)

		pin:ClearAllPoints()
		pin:SetPoint("CENTER", frame, "TOPLEFT", px, -py)
		pin:Show()

		return true
	end

	-- Questie's spawn tables are keyed by area; fall back to our own
	-- coordinates for the NPCs it has no spawn data for.
	local PlaceSpawns = function(spawns, id, questName, objectiveText, pinType)
		local placed = false

		if (spawns) and (spawns[areaID]) then
			local drawn = 0

			for _, coords in ipairs(spawns[areaID]) do
				if (drawn >= MAX_SPAWNS_PER_OBJECTIVE) then
					break
				end

				if (Place(coords[1], coords[2], questName, objectiveText, pinType)) then
					placed = true
					drawn = drawn + 1
				end
			end
		end

		if (not placed) and (id) and (fallbacks) and (fallbacks[id]) then
			Place(fallbacks[id][1], fallbacks[id][2], questName, objectiveText, pinType)
		end
	end

	local ProcessNPC = function(npcID, questName, text, pinType)
		local npc = QuestieDB.GetNPC and QuestieDB:GetNPC(npcID)
		PlaceSpawns(npc and npc.spawns, npcID, questName, text or (npc and npc.name) or "", pinType or "kill")
	end

	local ProcessObject = function(objectID, questName, text)
		local object = QuestieDB.GetObject and QuestieDB:GetObject(objectID)
		PlaceSpawns(object and object.spawns, objectID, questName, text or (object and object.name) or "", "object")
	end

	local ProcessItem = function(itemID, questName, text)
		if (QuestieDB.QueryItemSingle) then
			local okDrops, drops = pcall(QuestieDB.QueryItemSingle, itemID, "npcDrops")

			if (okDrops) and (drops) then
				for _, npcID in ipairs(drops) do
					local npc = QuestieDB.GetNPC and QuestieDB:GetNPC(npcID)
					local label = text or ""

					if (npc) and (npc.name) then
						label = (label ~= "") and (label.." - "..npc.name) or npc.name
					end

					ProcessNPC(npcID, questName, label, "loot")
				end
				return
			end
		end

		if (fallbacks) and (fallbacks[itemID]) then
			Place(fallbacks[itemID][1], fallbacks[itemID][2], questName, text, "loot")
		end
	end

	for questID in pairs(QuestiePlayer.currentQuestlog) do
		local quest = QuestieDB.GetQuest and QuestieDB.GetQuest(questID)

		if (quest) then
			local questName = quest.name or quest.Name or ("Quest "..questID)

			-- Processed objectives, when Questie has them.
			if (quest.ObjectiveData) then
				for _, objective in ipairs(quest.ObjectiveData) do
					local text = objective.Text or objective.Name or ""

					if (objective.Type == "monster") or (objective.Type == "killcredit") then
						ProcessNPC(objective.Id, questName, text, "kill")
					elseif (objective.Type == "object") then
						ProcessObject(objective.Id, questName, text)
					elseif (objective.Type == "item") then
						ProcessItem(objective.Id, questName, text)
					end
				end
			end

			-- Raw objectives, for quests whose ObjectiveData came back empty.
			if (quest.objectives) and ((not quest.ObjectiveData) or (#quest.ObjectiveData == 0)) then
				if (quest.objectives[1]) then
					for _, objective in ipairs(quest.objectives[1]) do
						if (objective[1]) then
							ProcessNPC(objective[1], questName, objective[2] or "", "kill")
						end
					end
				end

				if (quest.objectives[2]) then
					for _, objective in ipairs(quest.objectives[2]) do
						if (objective[1]) then
							ProcessObject(objective[1], questName, objective[2] or "")
						end
					end
				end

				if (quest.objectives[3]) then
					for _, objective in ipairs(quest.objectives[3]) do
						if (objective[1]) then
							ProcessItem(objective[1], questName, objective[2] or "")
						end
					end
				end
			end

			-- Event-style quests carry their own trigger coordinates.
			if (quest.triggerEnd) and (quest.triggerEnd[2]) then
				local text = quest.triggerEnd[1] or questName

				for triggerArea, coordinates in pairs(quest.triggerEnd[2]) do
					if (triggerArea == areaID) then
						for _, coords in ipairs(coordinates) do
							Place(coords[1], coords[2], questName, text, "object")
						end
					end
				end
			end
		end
	end
end

-- Dungeon entrances
----------------------------------------------------
-- Classic Era ships no entrance pins to hook. Blizzard's own provider is
-- commented out in Vanilla/Blizzard_WorldMap.lua:
--
--   --self:AddDataProvider(CreateFromMixins(DungeonEntranceDataProviderMixin));
--
-- so waiting for one to appear -- which is what we were doing, and what
-- only works alongside Leatrix_Maps -- means the feature never fires. We
-- have the coordinates ourselves, so draw them.
-- One size drives the icon, the hover area and the click target, so
-- the artwork is exactly as big as the pin feels. Developer mode can
-- override it live to try sizes; the export carries the choice back
-- here to become the shipped default.
local ENTRANCE_PIN_SIZE = 48

local GetEntrancePinSize = function()
	local dev = Wayfarer.db and Wayfarer.db.global and Wayfarer.db.global.devData
	return (dev and dev.pinSize) or ENTRANCE_PIN_SIZE
end

ns.GetEntrancePinSize = GetEntrancePinSize

function Integrations:GetEntrancePin(index)
	self.entrancePins = self.entrancePins or {}

	local pin = self.entrancePins[index]

	if (not pin) then
		local Canvas = self:GetCanvas()
		local child = Canvas and Canvas.ScrollContainer and Canvas.ScrollContainer.Child
		if (not child) then
			return nil
		end

		-- Parented to the CANVAS, not the scroll child. Raising the frame
		-- level inside the child did not lift these above the detail
		-- layers, so stop competing with them: the canvas is where our
		-- instance-map overlay and the picker both render reliably.
		-- The anchor still targets the child, and anchors work across
		-- parents, so the pin tracks panning as before -- it just no
		-- longer scales with zoom, which for a marker is an improvement.
		pin = CreateFrame("Button", nil, Canvas)
		pin:SetSize(GetEntrancePinSize(), GetEntrancePinSize())
		pin:SetFrameStrata(Canvas:GetFrameStrata())
		pin:SetFrameLevel(Canvas.ScrollContainer:GetFrameLevel() + 30)

		-- A plain colour fill can't fail to resolve, so the marker is
		-- visible even if the icon file ever goes missing again.
		local border = pin:CreateTexture(nil, "BACKGROUND")
		border:SetPoint("TOPLEFT", -2, 2)
		border:SetPoint("BOTTOMRIGHT", 2, -2)
		border:SetColorTexture(0, 0, 0, .85)

		local fill = pin:CreateTexture(nil, "BORDER")
		fill:SetAllPoints()
		fill:SetColorTexture(unpack(Colors.normal))
		pin.Fill = fill

		-- Interface\\Minimap\\Dungeon, which this used before, appears
		-- nowhere in the 1.15.9 UI source. It does not exist.
		local icon = pin:CreateTexture(nil, "OVERLAY")
		icon:SetPoint("TOPLEFT", 2, -2)
		icon:SetPoint("BOTTOMRIGHT", -2, 2)
		icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
		icon:SetTexCoord(.1, .9, .1, .9)
		pin.Icon = icon
		pin.Fill = fill
		pin.Backing = border

		pin:SetScript("OnEnter", function(pinSelf)
			fill:SetColorTexture(unpack(Colors.highlight))
			GameTooltip:SetOwner(pinSelf, "ANCHOR_RIGHT")

			-- The recommended level range rides along in the same
			-- difficulty colours the zone names use, behind the same
			-- zone levels toggle.
			local title = pinSelf.label or ""
			local levels = pinSelf.instanceMapID and ns.dungeonLevels
				and ns.dungeonLevels[pinSelf.instanceMapID]
			if (levels) and (Wayfarer.db.profile.zoneLevels.enable) and (ns.GetLevelSuffix) then
				title = title..(ns.GetLevelSuffix(levels[1], levels[2]) or "")
			end

			GameTooltip:AddLine(title)
			GameTooltip:AddLine(L["Click to open this dungeon's map"], .6, .6, .6)
			GameTooltip:Show()
		end)

		pin:SetScript("OnLeave", function()
			fill:SetColorTexture(unpack(Colors.normal))
			GameTooltip:Hide()
		end)

		pin:SetScript("OnClick", function(pinSelf)
			local InstanceMaps = Wayfarer:GetModule("InstanceMaps", true)
			if (InstanceMaps) and (pinSelf.dungeon) then
				InstanceMaps:SetSelection({
					dungeon = pinSelf.dungeon,
					instanceMapID = pinSelf.instanceMapID,
					label = pinSelf.label
				})
			end
		end)

		self.entrancePins[index] = pin
	end

	return pin
end

function Integrations:HideEntrancePins()
	if (not self.entrancePins) then
		return
	end
	for _, pin in ipairs(self.entrancePins) do
		pin:Hide()
	end
end

-- Which instance ID a texture folder belongs to, so a clicked entrance
-- can carry the boss data with it.
local instanceIDByDungeon

function Integrations:ShowEntrancePins()
	self:HideEntrancePins()

	local db = self:GetSettings()
	if (not db.entrancePins) then
		return
	end

	local Canvas = self:GetCanvas()
	local child = Canvas and Canvas.ScrollContainer and Canvas.ScrollContainer.Child
	if (not child) or (not Canvas.GetMapID) then
		return
	end

	-- The instance map covers the canvas, but these pins are parented to
	-- the canvas rather than inside it, so they float over the dungeon
	-- map unless we take them down ourselves.
	local InstanceMaps = Wayfarer:GetModule("InstanceMaps", true)
	if (InstanceMaps) and (InstanceMaps.frame) and (InstanceMaps.frame:IsShown()) then
		return
	end

	local portals = ns.dungeonPortals[Canvas:GetMapID()]
	if (not portals) then
		return
	end

	if (not instanceIDByDungeon) then
		instanceIDByDungeon = {}
		for instanceMapID, dungeon in pairs(ns.dungeonByMapID) do
			instanceIDByDungeon[dungeon] = instanceMapID
		end
	end

	local width, height = child:GetSize()
	if (not width) or (width <= 0) then
		return
	end

	local pinSize = GetEntrancePinSize()

	for index, portal in ipairs(portals) do
		local pin = self:GetEntrancePin(index)

		if (pin) then
			pin:SetSize(pinSize, pinSize)
			pin.dungeon = portal.name
			pin.instanceMapID = instanceIDByDungeon[portal.name]
			pin.label = ns.PrettyDungeonName(portal.name)

			-- Each instance gets its own LFG artwork where the client
			-- ships it; those are self-contained, so the box behind the
			-- generic fallback icon stays hidden for them. With the art
			-- off the frame stays live: the entrance still tooltips and
			-- still clicks through.
			local custom = ns.GetDungeonIcon and ns.GetDungeonIcon(portal.name)
			if (custom) then
				pin.Icon:SetTexture(custom)
				-- LFG artwork is framed already; square inventory icons
				-- keep the usual edge trim.
				if (custom:find("LFGFrame")) then
					pin.Icon:SetTexCoord(0, 1, 0, 1)
				else
					pin.Icon:SetTexCoord(.1, .9, .1, .9)
				end
			else
				pin.Icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
				pin.Icon:SetTexCoord(.1, .9, .1, .9)
			end

			local showArt = db.entrancePinIcons
			pin.Icon:SetShown(showArt)
			pin.Fill:SetShown(showArt and not custom)
			pin.Backing:SetShown(showArt and not custom)

			pin:ClearAllPoints()
			-- The offsets are interpreted in the pin's own coordinate
			-- space, but the scroll child rescales as the map zooms, so
			-- the child-relative fractions must be converted through the
			-- scale difference or the pins drift off their entrances the
			-- moment the zoom changes.
			local relScale = child:GetEffectiveScale() / (pin:GetEffectiveScale() or 1)
			pin:SetPoint("CENTER", child, "TOPLEFT",
				(portal.x / 100) * width * relScale, -(portal.y / 100) * height * relScale)
			pin:Show()

			-- No longer clipped by the scroll frame, so hide it by hand
			-- once it pans outside the visible map.
			local container = Canvas.ScrollContainer
			local px, cl = pin:GetLeft(), container:GetLeft()

			if (px) and (cl) then
				local pr, ct, cb = pin:GetRight(), container:GetTop(), container:GetBottom()
				local pt, pb = pin:GetTop(), pin:GetBottom()

				if (pr < cl) or (px > container:GetRight())
				   or (pb > ct) or (pt < cb) then
					pin:Hide()
				end
			end
		end
	end
end

-- Module
----------------------------------------------------
function Integrations:OnInstanceMapShown()
	self:HideEntrancePins()
	self:ShowQuestPins()
end

function Integrations:OnInstanceMapHidden()
	self:HideQuestPins()
	self:ShowEntrancePins()
end

function Integrations:OnMapReady()
	self:RegisterMessage("Wayfarer_InstanceMapShown", "OnInstanceMapShown")
	self:RegisterMessage("Wayfarer_InstanceMapResized", "OnInstanceMapShown")
	self:RegisterMessage("Wayfarer_InstanceMapHidden", "OnInstanceMapHidden")

	local Canvas = self:GetCanvas()

	-- Entrances are ours to draw, and they move with the map, so redraw
	-- whenever the map changes or is re-laid out.
	if (Canvas) and (Canvas.OnMapChanged) then
		self:SecureHook(Canvas, "OnMapChanged", "ShowEntrancePins")
	end

	self:SecureHookScript(Canvas, "OnShow", "ShowEntrancePins")

	-- Zooming rescales the scroll child and panning slides it; both move
	-- where our anchors land and stale-cull pins, so re-place on each.
	if (Canvas) and (Canvas.OnCanvasScaleChanged) then
		self:SecureHook(Canvas, "OnCanvasScaleChanged", "ShowEntrancePins")
	end
	if (Canvas) and (Canvas.OnCanvasPanChanged) then
		self:SecureHook(Canvas, "OnCanvasPanChanged", "ShowEntrancePins")
	end

	-- Hand AtlasLoot back its own window when the map goes away.
	self:SecureHookScript(Canvas, "OnHide", "UndockAtlasLoot")
	self:RegisterMessage("Wayfarer_MapDisplayStateChanged", "ShowEntrancePins")

	self:ShowEntrancePins()

	-- Questie loads its database well after login, so a quest log we read
	-- too early comes back empty.
	self:RegisterEvent("QUEST_LOG_UPDATE", "ShowQuestPins")
end

function Integrations:OnConfigChanged()
	self:ShowEntrancePins()
	self:ShowQuestPins()
end

function Integrations:GetOptions()
	local Missing = function(has, name)
		if (has()) then
			return nil
		end
		return string_format(L["%s is not installed."], name)
	end

	return {
		name = L["Integrations"],
		args = {
			description = {
				order = 1,
				type = "description",
				name = L["Optional hooks into other addons. Each is used only when that addon is present."]
			},
			questie = {
				order = 10,
				type = "toggle", width = "full",
				name = L["Questie quest objectives"],
				desc = L["Marks quest objectives on the dungeon map, using Questie's database. Off by default: Questie lists every spawn of an objective mob, so a dungeon full of one mob type gets crowded even with the limits Wayfarer applies."],
				disabled = function() return not ns.HasQuestie() end,
				get = ns.Getter("integrations", "questie"),
				set = ns.Setter("integrations", "questie")
			},
			questieStatus = {
				order = 11,
				type = "description",
				name = function() return Missing(ns.HasQuestie, "Questie") or "" end,
				hidden = function() return ns.HasQuestie() end
			},
			atlasLoot = {
				order = 20,
				type = "toggle", width = "full",
				name = L["AtlasLoot boss loot"],
				desc = L["Clicking a boss marker opens its loot table in AtlasLoot."],
				disabled = function() return not ns.HasAtlasLoot() end,
				get = ns.Getter("integrations", "atlasLoot"),
				set = ns.Setter("integrations", "atlasLoot")
			},
			atlasLootStatus = {
				order = 21,
				type = "description",
				name = function() return Missing(ns.HasAtlasLoot, "AtlasLoot") or "" end,
				hidden = function() return ns.HasAtlasLoot() end
			},
			dockAtlasLoot = {
				order = 25,
				type = "toggle", width = "full",
				name = L["Dock AtlasLoot beside the map"],
				desc = L["The world map sits above AtlasLoot's window, so opening loot from a boss marker would otherwise put it behind the map. This moves it to the right of the map while the map is open, and puts it back afterwards."],
				disabled = function() return not ns.HasAtlasLoot() end,
				get = ns.Getter("integrations", "dockAtlasLoot"),
				set = ns.Setter("integrations", "dockAtlasLoot")
			},
			entrancePinIcons = {
				order = 35,
				type = "toggle", width = "full",
				name = L["Show entrance markers"],
				desc = L["Draws each dungeon's own icon at its entrance. The entrances still tooltip and still open their map with the icons hidden."],
				disabled = function() return not Wayfarer.db.profile.integrations.entrancePins end,
				get = ns.Getter("integrations", "entrancePinIcons"),
				set = ns.Setter("integrations", "entrancePinIcons")
			},
			entrancePins = {
				order = 30,
				type = "toggle", width = "full",
				name = L["Dungeon entrance pins"],
				desc = L["Marks dungeon entrances on the zone map; clicking one opens that dungeon's map. Classic Era draws no entrance pins of its own, so these are Wayfarer's."],
				get = ns.Getter("integrations", "entrancePins"),
				set = ns.Setter("integrations", "entrancePins")
			}
		}
	}
end
