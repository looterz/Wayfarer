local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon
local L = ns.L

-- Appends the level range and controlling faction to the zone name
-- the map prints when you hover a zone.
local ZoneLevels = Wayfarer:NewModule("ZoneLevels")

ZoneLevels.mapPriority = 40
ZoneLevels.settingsKey = "zoneLevels"
ZoneLevels.optionsKey = "zonelevels"
ZoneLevels.optionsOrder = 40

-- GLOBALS: C_Map, MapUtil, MAP_AREA_LABEL_TYPE, WorldMapFrame
-- GLOBALS: FACTION_ALLIANCE, FACTION_CONTROLLED_TERRITORY, FACTION_HORDE, FONT_COLOR_CODE_CLOSE

local Colors = ns.Colors
local GetQuestDifficultyColor = ns.GetQuestDifficultyColor
local zoneData = ns.zoneData

local next = next
local string_format = string.format

-- Build the "(20-30)" suffix in the difficulty color of the range.
local GetLevelSuffix = function(minLevel, maxLevel)
	if not(minLevel and maxLevel and minLevel > 0 and maxLevel > 0) then
		return
	end

	local playerLevel = UnitLevel("player")
	local color

	if (playerLevel < minLevel) then
		color = GetQuestDifficultyColor(minLevel, playerLevel)
	elseif (playerLevel > maxLevel) then
		-- Subtract 2 from the max so zones entirely below
		-- the player's level don't come out yellow.
		color = GetQuestDifficultyColor(maxLevel - 2, playerLevel)
	else
		color = Colors.quest.yellow
	end

	if (minLevel ~= maxLevel) then
		return color.colorCode.." ("..minLevel.."-"..maxLevel..")"..FONT_COLOR_CODE_CLOSE
	end

	return color.colorCode.." ("..maxLevel..")"..FONT_COLOR_CODE_CLOSE
end

-- The entrance pin tooltips colour their dungeon ranges the same way,
-- so the map never shows the same range in two different colours.
ns.GetLevelSuffix = GetLevelSuffix

-- Green if it's ours, red if it isn't.
local GetFactionDescription = function(zoneFaction)
	if (not zoneFaction) then
		return
	end

	local description
	if (zoneFaction == "Alliance") then
		description = string_format(FACTION_CONTROLLED_TERRITORY, FACTION_ALLIANCE)
	elseif (zoneFaction == "Horde") then
		description = string_format(FACTION_CONTROLLED_TERRITORY, FACTION_HORDE)
	else
		return
	end

	local playerFaction = UnitFactionGroup("player")
	if (playerFaction == zoneFaction) then
		return Colors.faction.friendly.colorCode..description..FONT_COLOR_CODE_CLOSE
	end

	return Colors.faction.hostile.colorCode..description..FONT_COLOR_CODE_CLOSE
end

-- Replaces the area label provider's own OnUpdate.
local OnUpdate_AreaLabel = function(self)
	self:ClearLabel(MAP_AREA_LABEL_TYPE.AREA_NAME)

	local map = self.dataProvider:GetMap()

	if (map:IsCanvasMouseFocus()) then
		local db = ZoneLevels:GetSettings()
		local name, description
		local uiMapID = map:GetMapID()
		local cursorX, cursorY = map:GetNormalizedCursorPosition()
		local positionMapInfo = C_Map.GetMapInfoAtPosition(uiMapID, cursorX, cursorY)

		if (positionMapInfo and (positionMapInfo.mapID ~= uiMapID)) then
			name = positionMapInfo.name

			local zone = zoneData[positionMapInfo.mapID]
			if (zone and db.enable) then
				if (db.showFaction) then
					description = GetFactionDescription(zone.faction)
				end

				local suffix = GetLevelSuffix(zone.min, zone.max)
				if (name and suffix) then
					name = name..suffix
				end
			end
		else
			name = MapUtil.FindBestAreaNameAtMouse(uiMapID, cursorX, cursorY)
		end

		if (name) then
			self:SetLabel(MAP_AREA_LABEL_TYPE.AREA_NAME, name, description)
		end
	end

	self:EvaluateLabels()
end

function ZoneLevels:OnMapReady()
	local Canvas = self:GetCanvas()

	self.labels = {}

	for provider in next, Canvas.dataProviders do
		if (provider.setAreaLabelCallback and provider.Label) then
			self.labels[provider.Label] = provider.Label:GetScript("OnUpdate") or false
		end
	end
end

function ZoneLevels:OnConfigChanged()
	if (not self.labels) then
		return
	end

	-- The hook stays in place whether the feature is on or off; the
	-- label handler checks the setting itself, so toggling it can't
	-- leave the map's own area name broken behind us.
	for label in next, self.labels do
		if (label:GetScript("OnUpdate") ~= OnUpdate_AreaLabel) then
			label:SetScript("OnUpdate", OnUpdate_AreaLabel)
		end
	end
end

function ZoneLevels:GetOptions()
	return {
		name = L["Zone Levels"],
		args = {
			description = {
				order = 1,
				type = "description",
				name = L["Adds level ranges and faction control to the zone names shown on the map."]
			},
			enable = {
				order = 10,
				type = "toggle", width = "full",
				name = L["Show zone level ranges"],
				desc = L["Appends the recommended level range to the name of the zone under your cursor."],
				get = ns.Getter("zoneLevels", "enable"),
				set = ns.Setter("zoneLevels", "enable")
			},
			showFaction = {
				order = 20,
				type = "toggle", width = "full",
				name = L["Show controlling faction"],
				desc = L["Shows which faction controls the zone under your cursor, colored by whether it is yours."],
				disabled = function() return not Wayfarer.db.profile.zoneLevels.enable end,
				get = ns.Getter("zoneLevels", "showFaction"),
				set = ns.Setter("zoneLevels", "showFaction")
			}
		}
	}
end
