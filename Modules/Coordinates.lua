local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon
local L = ns.L

-- Player and cursor coordinates, printed below the map.
local Coordinates = Wayfarer:NewModule("Coordinates")

Coordinates.mapPriority = 30
Coordinates.settingsKey = "coordinates"
Coordinates.optionsKey = "coordinates"
Coordinates.optionsOrder = 30

-- GLOBALS: C_Map, Game12Font_o1, MOUSE_LABEL, PLAYER

local Colors = ns.Colors
local GetFormattedCoordinates = ns.GetFormattedCoordinates

local THROTTLE = .05

-- How far in from the map's edges the readouts sit. The scroll container
-- runs wider than the visible map, so anchoring flush to it puts the text
-- past the border on both sides.
local INSET_X = 26
local INSET_Y = -7

local OnUpdate_Coordinates = function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	if (self.elapsed < THROTTLE) then
		return
	end
	self.elapsed = 0

	local module = self.module
	local db = module:GetSettings()
	local accuracy = db.accuracy

	if (db.player) then
		local pX, pY
		local uiMapID = C_Map.GetBestMapForUnit("player")
		if (uiMapID) then
			local position = C_Map.GetPlayerMapPosition(uiMapID, "player")
			if (position) then
				pX, pY = position:GetXY()
			end
		end
		if (pX and pY) then
			self.PlayerCoordinates:SetFormattedText(Colors.title.colorCode.."%1$s|r %2$s %3$s",
				PLAYER, GetFormattedCoordinates(pX, pY, accuracy))
		else
			self.PlayerCoordinates:SetText("")
		end
	end

	if (db.cursor) then
		local cX, cY
		if (self.Canvas:IsMouseOver(0, 0, 0, 0)) then
			cX, cY = self.Container:GetNormalizedCursorPosition()
		end
		if (cX and cY) then
			self.CursorCoordinates:SetFormattedText("%2$s %3$s "..Colors.title.colorCode.."%1$s|r",
				MOUSE_LABEL, GetFormattedCoordinates(cX, cY, accuracy))
		else
			self.CursorCoordinates:SetText("")
		end
	end
end

-- Anchor the two readouts to the bottom corners of the map.
function Coordinates:UpdateAnchors()
	if (not self.PlayerCoordinates) then
		return
	end

	local Container = self:GetContainer()

	self.PlayerCoordinates:ClearAllPoints()
	self.PlayerCoordinates:SetPoint("TOPLEFT", Container, "BOTTOMLEFT", INSET_X, INSET_Y)

	self.CursorCoordinates:ClearAllPoints()
	self.CursorCoordinates:SetPoint("TOPRIGHT", Container, "BOTTOMRIGHT", -INSET_X, INSET_Y)
end

function Coordinates:OnMapReady()
	local Canvas = self:GetCanvas()
	local Container = self:GetContainer()

	local PlayerCoordinates = Container:CreateFontString()
	PlayerCoordinates:SetFontObject(Game12Font_o1)
	PlayerCoordinates:SetDrawLayer("OVERLAY")
	PlayerCoordinates:SetJustifyH("LEFT")

	local CursorCoordinates = Container:CreateFontString()
	CursorCoordinates:SetFontObject(Game12Font_o1)
	CursorCoordinates:SetDrawLayer("OVERLAY")
	CursorCoordinates:SetJustifyH("RIGHT")

	self.PlayerCoordinates = PlayerCoordinates
	self.CursorCoordinates = CursorCoordinates

	self:UpdateAnchors()

	local timer = CreateFrame("Frame", nil, Canvas)
	timer.elapsed = 0
	timer.module = self
	timer.Canvas = Canvas
	timer.Container = Container
	timer.PlayerCoordinates = PlayerCoordinates
	timer.CursorCoordinates = CursorCoordinates

	self.CoordinateTimer = timer

	-- Maximizing the map moves the container out from under us.
	self:RegisterMessage("Wayfarer_MapDisplayStateChanged", "UpdateAnchors")
end

function Coordinates:OnConfigChanged()
	if (not self.PlayerCoordinates) then
		return
	end

	local db = self:GetSettings()

	self.PlayerCoordinates:SetShown(db.player)
	self.CursorCoordinates:SetShown(db.cursor)

	self:UpdateAnchors()

	-- Nothing to show means nothing to poll for.
	if (db.player or db.cursor) then
		self.CoordinateTimer:SetScript("OnUpdate", OnUpdate_Coordinates)
	else
		self.CoordinateTimer:SetScript("OnUpdate", nil)
	end
end

function Coordinates:GetOptions()
	return {
		name = L["Coordinates"],
		args = {
			description = {
				order = 1,
				type = "description",
				name = L["Shows map coordinates below the world map."]
			},
			player = {
				order = 10,
				type = "toggle", width = "full",
				name = L["Show player coordinates"],
				desc = L["Show map coordinates of the player's current location."],
				get = ns.Getter("coordinates", "player"),
				set = ns.Setter("coordinates", "player")
			},
			cursor = {
				order = 20,
				type = "toggle", width = "full",
				name = L["Show cursor coordinates"],
				desc = L["Show map coordinates of the mouse cursor."],
				get = ns.Getter("coordinates", "cursor"),
				set = ns.Setter("coordinates", "cursor")
			},
			accuracy = {
				order = 30,
				type = "range", width = "full",
				min = 0, max = 2, step = 1,
				name = L["Decimals"],
				desc = L["How many decimal places to show in the coordinates."],
				get = ns.Getter("coordinates", "accuracy"),
				set = ns.Setter("coordinates", "accuracy")
			}
		}
	}
end
