local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon
local L = ns.L

-- Sizes the world map as a share of your screen height, separately for
-- the windowed and maximized states. Blizzard's own sizing is built for
-- a monitor at arm's length; on a TV you want the whole screen.
--
-- This scales the frame rather than resizing it. Resizing desynchronises
-- the map from its own border: Blizzard lays the border art, the close
-- button and the rest out for the size it computed in
-- SynchronizeDisplayState, and a post-hook that changes the size
-- afterwards leaves all of that measured for the old one, which shows up
-- as a doubled frame and a canvas that no longer fills it. Scaling moves
-- every child in step, so nothing can drift out of place.
local MapSize = Wayfarer:NewModule("MapSize")

MapSize.mapPriority = 15
MapSize.settingsKey = "size"
MapSize.optionsKey = "size"
MapSize.optionsOrder = 15

-- GLOBALS: UIParent

local math_min = math.min

-- Room left around the outside for chrome Blizzard anchors past the
-- frame's own edges, the close button most visibly.
local CHROME_MARGIN = 16

-- Beyond these the map stops being usable rather than just large.
local MIN_SCALE, MAX_SCALE = 0.5, 4.0

local IsMaximized = function(Canvas)
	if (Canvas.IsMaximized) then
		return Canvas:IsMaximized()
	end
	return Canvas.isMaximized
end

function MapSize:ApplyScale()
	if (not self:IsMapReady()) or (self.applying) then
		return
	end

	local Canvas = self:GetCanvas()
	local db = self:GetSettings()

	local percent = IsMaximized(Canvas) and db.maximizedHeight or db.windowedHeight
	if (not percent) then
		return
	end

	local screenHeight, screenWidth = UIParent:GetHeight(), UIParent:GetWidth()
	if (not screenHeight) or (screenHeight <= 0) then
		return
	end

	-- We never touch the frame's size, so these stay at whatever
	-- Blizzard set for the current display state. Nothing to capture,
	-- and nothing of ours to accidentally measure a second time.
	local naturalWidth, naturalHeight = Canvas:GetSize()
	if (not naturalHeight) or (naturalHeight <= 0) or (not naturalWidth) or (naturalWidth <= 0) then
		return
	end

	local targetHeight = (screenHeight - CHROME_MARGIN * 2) * (percent / 100)
	local scale = targetHeight / naturalHeight

	-- Don't let a tall setting push the map off the sides.
	if (screenWidth) and (screenWidth > 0) then
		local maxScale = (screenWidth - CHROME_MARGIN * 2) / naturalWidth
		scale = math_min(scale, maxScale)
	end

	if (scale < MIN_SCALE) then
		scale = MIN_SCALE
	elseif (scale > MAX_SCALE) then
		scale = MAX_SCALE
	end

	-- Setting the scale re-fires the hooks we listen on.
	self.applying = true

	Canvas:SetScale(scale)
	Canvas:ClearAllPoints()
	Canvas:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

	self.applying = nil

	Wayfarer:SendMessage("Wayfarer_MapDisplayStateChanged")
end

function MapSize:OnMapReady()
	local Canvas = self:GetCanvas()

	local Apply = function() self:ApplyScale() end

	-- Blizzard re-lays the map out on each of these; we go after it.
	if (Canvas.Maximize and not self:IsHooked(Canvas, "Maximize")) then
		self:SecureHook(Canvas, "Maximize", Apply)
	end

	if (Canvas.Minimize and not self:IsHooked(Canvas, "Minimize")) then
		self:SecureHook(Canvas, "Minimize", Apply)
	end

	if (Canvas.SynchronizeDisplayState and not self:IsHooked(Canvas, "SynchronizeDisplayState")) then
		self:SecureHook(Canvas, "SynchronizeDisplayState", Apply)
	end

	self:SecureHookScript(Canvas, "OnShow", Apply)

	self:RegisterEvent("DISPLAY_SIZE_CHANGED", "ApplyScale")
	self:RegisterEvent("UI_SCALE_CHANGED", "ApplyScale")
end

function MapSize:OnConfigChanged()
	self:ApplyScale()
end

function MapSize:GetOptions()
	return {
		name = L["Size"],
		args = {
			description = {
				order = 1,
				type = "description",
				name = L["Sets how much of your screen the map covers. Both sizes are a percentage of your screen height; the map keeps its own shape and everything on it scales to match."]
			},
			maximizedHeight = {
				order = 10,
				type = "range", width = "full",
				min = 40, max = 100, step = 1,
				name = L["Large map size"],
				desc = L["How tall the maximized map is, as a percentage of your screen height."],
				get = ns.Getter("size", "maximizedHeight"),
				set = ns.Setter("size", "maximizedHeight")
			},
			windowedHeight = {
				order = 20,
				type = "range", width = "full",
				min = 20, max = 100, step = 1,
				name = L["Small map size"],
				desc = L["How tall the windowed map is, as a percentage of your screen height."],
				get = ns.Getter("size", "windowedHeight"),
				set = ns.Setter("size", "windowedHeight")
			}
		}
	}
end
