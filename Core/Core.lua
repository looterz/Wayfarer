local AddonName, ns = ...

-- Wayfarer runs on WoW Classic Era and The Burning Crusade Anniversary.
-- Bail out early and silently on any other client flavour,
-- rather than erroring our way through a map API that doesn't match.
local clientVersion = GetBuildInfo()
local clientMajor = tonumber((string.split(".", clientVersion))) or 0

ns.isClassicEra = (WOW_PROJECT_ID and WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
             or (not WOW_PROJECT_ID and clientMajor == 1)
ns.isTBC = (WOW_PROJECT_ID and WOW_PROJECT_BURNING_CRUSADE_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
             or (not WOW_PROJECT_ID and clientMajor == 2)
ns.isSupportedClient = ns.isClassicEra or ns.isTBC

-- The data files load before this one, so they cannot test the flags we
-- have only just set. They define their tables unconditionally; dropping
-- or merging them is this file's job.
if (not ns.isSupportedClient) then
	ns.zoneData, ns.zoneReveal = nil, nil
	ns.zoneDataTBC, ns.zoneRevealTBC, ns.tbcInstances = nil, nil, nil
	ns.dungeonByMapID, ns.subzoneToFloor, ns.specialDungeons = nil, nil, nil
	ns.defaultFloor, ns.dungeonFloors, ns.floorLabels, ns.floorNames = nil, nil, nil, nil
	ns.questieAreaByInstance, ns.dungeonPortals, ns.dungeonLevels = nil, nil, nil
	ns.npcPositions, ns.dungeonBosses, ns.dungeonStairs = nil, nil, nil
	return
end

if (ns.isClassicEra) then
	-- This client has neither the TBC instances nor their map art; keep
	-- them out of the picker, the auto-detection, and the entrance pins.
	local tbcFolders = {}
	for instanceMapID in pairs(ns.tbcInstances or {}) do
		tbcFolders[ns.dungeonByMapID[instanceMapID] or 0] = true
		ns.dungeonByMapID[instanceMapID] = nil
		ns.dungeonBosses[instanceMapID] = nil
	end
	for _, portals in pairs(ns.dungeonPortals) do
		for i = #portals, 1, -1 do
			if (tbcFolders[portals[i].name]) then
				table.remove(portals, i)
			end
		end
	end
else
	-- The TBC client re-numbers zone map art, so its reveal table
	-- overrides the Era one wholesale, and its zones join the level table.
	for artID, tiles in pairs(ns.zoneRevealTBC or {}) do
		ns.zoneReveal[artID] = tiles
	end
	for uiMapID, zone in pairs(ns.zoneDataTBC or {}) do
		ns.zoneData[uiMapID] = zone
	end
end
ns.zoneDataTBC, ns.zoneRevealTBC = nil, nil

local Wayfarer = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(AddonName)

ns.Addon = Wayfarer
ns.L = L
_G[AddonName] = Wayfarer

-- GLOBALS: C_AddOns, C_Map, C_MapExplorationInfo, MapUtil, UIParent, WorldMapFrame
-- GLOBALS: WOW_PROJECT_ID, WOW_PROJECT_CLASSIC, FONT_COLOR_CODE_CLOSE

-- Lua API
local math_floor = math.floor
local select = select
local sort = table.sort
local string_format = string.format
local string_gsub = string.gsub
local tinsert = table.insert
local unpack = unpack

-- WoW API
-- The AddOn functions live in the C_AddOns namespace on current clients.
-- The bare globals were removed, so don't reach for them without a guard.
local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

-- Saved Settings
----------------------------------------------------
-- Anything a module needs persisted goes here.
-- Modules read their own sub-table and nothing else.
ns.defaults = {
	profile = {
		coordinates = {
			player = true,
			cursor = true,
			accuracy = 1
		},
		fading = {
			enable = true,
			alphaStationary = 1,
			alphaMoving = .7
		},
		zoneLevels = {
			enable = true,
			showFaction = true
		},
		reveal = {
			enable = true,
			-- Unexplored ground is drawn at 60% brightness so it reads as
			-- different from ground you have actually explored, which
			-- Blizzard draws at full.
			dimLevel = .6,
			-- 1.15.9 hides some explored subareas until you hover them.
			alwaysShowExplored = true
		},
		canvas = {
			classicZoom = true,
			hideBlackout = true
		},
		size = {
			-- Fill the screen vertically by default. Blizzard's own
			-- maximized size is built for a desk, not a couch.
			maximizedHeight = 100,
			windowedHeight = 55
		},
		instanceMaps = {
			enable = true,
			showSelector = true,
			showBosses = true
		},
		integrations = {
			-- Off by default: Questie's spawn data lists every spawn of
			-- an objective mob, which in a dungeon full of one mob type
			-- buries the map in pins.
			questie = false,
			atlasLoot = true,
			dockAtlasLoot = true,
			entrancePins = true,
			-- On by default now that each instance draws its own icon
			-- rather than a generic map marker.
			entrancePinIcons = true
		}
	}
}

-- Utility
----------------------------------------------------
-- Convert a Blizzard color or a set of RGB values
-- into our own table format, with a ready-made escape code.
local createColor = function(...)
	local tbl
	if (select("#", ...) == 1) then
		local old = ...
		if (old.r) then
			tbl = { old.r or 1, old.g or 1, old.b or 1 }
		else
			tbl = { unpack(old) }
		end
	else
		tbl = { ... }
	end
	if (#tbl == 3) then
		tbl.colorCode = string_format("|cff%02x%02x%02x", math_floor(tbl[1]*255), math_floor(tbl[2]*255), math_floor(tbl[3]*255))
	end
	return tbl
end

ns.CreateColor = createColor

ns.Colors = {
	normal = createColor(229/255, 178/255, 38/255),
	highlight = createColor(250/255, 250/255, 250/255),
	title = createColor(255/255, 234/255, 137/255),
	offwhite = createColor(196/255, 196/255, 196/255),
	faction = {
		friendly = createColor(64/255, 211/255, 38/255),
		contested = createColor(249/255, 188/255, 65/255),
		hostile = createColor(245/255, 46/255, 36/255)
	},
	quest = {
		red = createColor(204/255, 26/255, 26/255),
		orange = createColor(255/255, 128/255, 64/255),
		yellow = createColor(229/255, 178/255, 38/255),
		green = createColor(89/255, 201/255, 89/255),
		gray = createColor(120/255, 120/255, 120/255)
	}
}

-- Returns a coordinate pair as strings,
-- with the decimals dimmed down a notch.
ns.GetFormattedCoordinates = function(x, y, accuracy)
	local mask = "%."..(accuracy or 1).."f"
	return string_gsub(string_format(mask, x*100), "%.(.+)", "|cff888888.%1|r"),
	       string_gsub(string_format(mask, y*100), "%.(.+)", "|cff888888.%1|r")
end

-- Returns the difficulty color of a level relative to the player.
ns.GetQuestDifficultyColor = function(level, playerLevel)
	local Colors = ns.Colors
	level = level - (playerLevel or UnitLevel("player"))
	if (level > 4) then
		return Colors.quest.red
	elseif (level > 2) then
		return Colors.quest.orange
	elseif (level >= -2) then
		return Colors.quest.yellow
	elseif (level >= -GetQuestGreenRange("player")) then
		return Colors.quest.green
	else
		return Colors.quest.gray
	end
end

-- Scale the map relative to the user's UI scale,
-- while keeping it within limits that stay readable.
ns.CalculateScale = function()
	local min, max = 0.65, 0.95 -- our own scale limits
	local uiMin, uiMax = 0.65, 1.15 -- blizzard uiScale slider limits
	local uiScale = UIParent:GetEffectiveScale()

	if (uiScale < uiMin) then
		return min
	elseif (uiScale > uiMax) then
		return max
	else
		return ((uiScale - uiMin) / (uiMax - uiMin)) * (max - min) + min
	end
end

-- Option get/set closures for a given settings section.
-- Explicit beats deriving the key from the AceConfig info path,
-- which breaks the moment an option is moved to another group.
ns.Getter = function(section, key)
	return function()
		return ns.Addon.db.profile[section][key]
	end
end

ns.Setter = function(section, key)
	return function(info, value)
		ns.Addon.db.profile[section][key] = value
		ns.Addon:RefreshConfig()
	end
end

-- As above, but for a toggle that reads inverted in the UI.
ns.InvertedGetter = function(section, key)
	return function()
		return not ns.Addon.db.profile[section][key]
	end
end

ns.InvertedSetter = function(section, key)
	return function(info, value)
		ns.Addon.db.profile[section][key] = not value
		ns.Addon:RefreshConfig()
	end
end

-- Raw SetAlpha, pulled off the frame metatable.
-- Modules that take over map opacity replace the map's own
-- SetAlpha with a no-op, and need this to still get through.
ns.SetRawAlpha = getmetatable(CreateFrame("Frame")).__index.SetAlpha

-- Module Framework
----------------------------------------------------
-- Every feature is a module. A module may implement:
--
--   module.mapPriority        number, lower runs first (default 50)
--   module:OnMapReady()       the world map exists and is ours to decorate
--   module:OnConfigChanged()  a setting or profile changed, re-read yours
--   module:GetOptions()       returns an AceConfig group for this module
--
-- Modules are never handed the map before OnMapReady, and OnMapReady is
-- guaranteed to fire exactly once per module, in mapPriority order.
local modulePrototype = {
	mapPriority = 50,

	-- Shortcut to this module's own settings table.
	-- The key defaults to the lowercased module name.
	GetSettings = function(self)
		local db = ns.Addon.db
		return db and db.profile[self.settingsKey or self:GetName():lower()]
	end,

	IsMapReady = function(self)
		return ns.Addon.mapReady
	end,

	GetCanvas = function(self)
		return ns.Addon.Canvas
	end,

	GetContainer = function(self)
		return ns.Addon.Container
	end
}

Wayfarer:SetDefaultModulePrototype(modulePrototype)
Wayfarer:SetDefaultModuleLibraries("AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
Wayfarer:SetDefaultModuleState(true)

-- One module erroring must not take the rest down with it. Without this a
-- throw in an early module simply stops the loop, and every later module
-- never gets set up at all -- which looks like those features vanishing
-- rather than like the error it is.
local SafeCall = function(module, method)
	local ok, err = pcall(module[method], module)

	if (not ok) then
		Wayfarer:Print(string_format("|cffff4444%s|r error in %s: %s",
			module:GetName(), method, tostring(err)))
	end

	return ok
end

-- Returns our modules sorted by mapPriority, registration order breaking ties.
local sortedModules = {}
local GetSortedModules = function(self)
	wipe(sortedModules)
	for i, module in ipairs(self.orderedModules) do
		module.registrationOrder = i
		tinsert(sortedModules, module)
	end
	sort(sortedModules, function(a, b)
		local pa, pb = a.mapPriority or 50, b.mapPriority or 50
		if (pa ~= pb) then
			return pa < pb
		end
		return a.registrationOrder < b.registrationOrder
	end)
	return sortedModules
end

-- Push the current settings out to every module that cares.
-- Called on any option change, and on profile switches.
function Wayfarer:RefreshConfig()
	if (not self.mapReady) then
		return
	end
	for _, module in ipairs(GetSortedModules(self)) do
		if (module:IsEnabled() and module.OnConfigChanged) then
			SafeCall(module, "OnConfigChanged")
		end
	end
end

-- Map Setup
----------------------------------------------------
-- Blizzard_WorldMap is load-on-demand, so we can't assume the map
-- exists when we're enabled. This is idempotent and safe to spam.
function Wayfarer:TrySetUpMap()
	if (self.mapReady) then
		return true
	end

	if (not IsAddOnLoaded("Blizzard_WorldMap")) or (not WorldMapFrame) then
		return false
	end

	self.Canvas = WorldMapFrame
	self.Container = WorldMapFrame.ScrollContainer
	self.mapReady = true

	for _, module in ipairs(GetSortedModules(self)) do
		if (module:IsEnabled() and module.OnMapReady) then
			SafeCall(module, "OnMapReady")
		end
	end

	self:RefreshConfig()

	return true
end

-- Addon Init & Events
----------------------------------------------------
function Wayfarer:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New(AddonName.."DB", ns.defaults, true)
	ns.Profiles:Cleanup(self.db)

	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

	if (ns.SetUpOptions) then
		ns:SetUpOptions()
	end
end

function Wayfarer:OnEnable()
	-- Our own OnEnable runs before AceAddon enables our modules,
	-- so hand the map off on the next frame instead of right now.
	self:ScheduleTimer("TrySetUpMap", 0)

	if (not IsAddOnLoaded("Blizzard_WorldMap")) then
		self:RegisterEvent("ADDON_LOADED")
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Wayfarer:ADDON_LOADED(event, addon)
	if (addon ~= "Blizzard_WorldMap") then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")
	-- Same story as OnEnable: let the loading addon finish first.
	self:ScheduleTimer("TrySetUpMap", 0)
end

function Wayfarer:PLAYER_ENTERING_WORLD()
	self:TrySetUpMap()
	self:RefreshConfig()
end
