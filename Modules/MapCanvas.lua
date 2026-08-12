local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon
local L = ns.L

-- The map frame itself: strata, placement, the blackout behind it,
-- and the scroll container's cursor maths. Everything else in
-- Wayfarer decorates the map this module has already tamed.
local MapCanvas = Wayfarer:NewModule("MapCanvas")

MapCanvas.mapPriority = 10
MapCanvas.settingsKey = "canvas"
MapCanvas.optionsKey = "canvas"
MapCanvas.optionsOrder = 10

-- GLOBALS: Clamp, Saturate, UIParent, WorldMapFrame, GetCursorPosition
-- GLOBALS: MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_NONE
-- GLOBALS: MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_SMOOTH
-- GLOBALS: MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_FULL

local pairs = pairs

-- ScrollContainer overrides
----------------------------------------------------
-- Classic's scroll container reports the cursor in screen space
-- without accounting for the canvas scale, which throws off every
-- mouseover on the map, and its mouse wheel zoom never fires at all.
-- These are the corrected versions, mixed into the live container.
local Container = {
	GetCanvasScale = function(self)
		return self.currentScale or self.targetScale or self:GetScale() or 1
	end,

	GetCursorPosition = function(self)
		local currentX, currentY = GetCursorPosition()
		local scale = UIParent:GetScale()
		if not(currentX and currentY and scale) then
			return 0, 0
		end
		return currentX/scale, currentY/scale
	end,

	GetNormalizedCursorPosition = function(self)
		local x, y = self:GetCursorPosition()
		return self:NormalizeUIPosition(x, y)
	end,

	NormalizeUIPosition = function(self, x, y)
		return Saturate(self:NormalizeHorizontalSize(x / self:GetCanvasScale() - self.Child:GetLeft())),
		       Saturate(self:NormalizeVerticalSize(self.Child:GetTop() - y / self:GetCanvasScale()))
	end,

	OnMouseWheel = function(self, delta)
		if (self.mouseWheelZoomMode == MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_NONE) then
			return
		end

		if (self:ShouldAdjustTargetPanOnMouseWheel(delta)) then
			local cursorX, cursorY = self:GetCursorPosition()
			local normalizedCursorX = self:NormalizeHorizontalSize(cursorX / self:GetCanvasScale() - self.Child:GetLeft())
			local normalizedCursorY = self:NormalizeVerticalSize(self.Child:GetTop() - cursorY / self:GetCanvasScale())

			if (not self:ShouldZoomInstantly()) then
				local nextZoomOutScale, nextZoomInScale = self:GetCurrentZoomRange()
				local minX, maxX, minY, maxY = self:CalculateScrollExtentsAtScale(nextZoomInScale)
				normalizedCursorX = Clamp(normalizedCursorX, minX, maxX)
				normalizedCursorY = Clamp(normalizedCursorY, minY, maxY)
			end

			self:SetPanTarget(normalizedCursorX, normalizedCursorY)
		end

		if (self.mouseWheelZoomMode == MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_SMOOTH) then
			self:SetZoomTarget(self:GetCanvasScale() + self.zoomAmountPerMouseWheelDelta * delta)

		elseif (self.mouseWheelZoomMode == MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_FULL) then
			if (delta > 0) then
				self:ZoomIn()
			else
				self:ZoomOut()
			end
		end
	end,

	ZoomIn = function(self)
		local nextZoomOutScale, nextZoomInScale = self:GetCurrentZoomRange()
		if (nextZoomInScale > self:GetCanvasScale()) then
			if (self:ShouldZoomInstantly()) then
				self:InstantPanAndZoom(nextZoomInScale, self.targetScrollX, self.targetScrollY)
			else
				self:SetZoomTarget(nextZoomInScale)
			end
		end
	end,

	ZoomOut = function(self)
		local nextZoomOutScale, nextZoomInScale = self:GetCurrentZoomRange()
		if (nextZoomOutScale < self:GetCanvasScale()) then
			if (self:ShouldZoomInstantly()) then
				self:InstantPanAndZoom(nextZoomOutScale, self.targetScrollX, self.targetScrollY)
			else
				self:SetZoomTarget(nextZoomOutScale)
				self:SetPanTarget(.5, .5)
			end
		end
	end
}

-- Module
----------------------------------------------------
-- Fired whenever the map is maximized, minimized or resized,
-- so anything anchored to the map can re-anchor itself.
local AnnounceDisplayState = function()
	Wayfarer:SendMessage("Wayfarer_MapDisplayStateChanged")
end

function MapCanvas:SetUpCanvas()
	local Canvas = self:GetCanvas()

	Canvas:SetIgnoreParentScale(false)
	Canvas:SetFrameStrata("MEDIUM")
	Canvas:ClearAllPoints()
	Canvas:SetPoint("CENTER")
	Canvas:RefreshDetailLayers()

	if (Canvas.BorderFrame) then
		Canvas.BorderFrame:SetFrameStrata("MEDIUM")
		Canvas.BorderFrame:SetFrameLevel(1)
	end

	-- The blackout dims the whole screen behind the map and swallows
	-- clicks. Questie and Season of Discovery both put it back, so we
	-- hook OnShow rather than hiding it once and hoping.
	if (Canvas.BlackoutFrame) and (not self:IsHooked(Canvas.BlackoutFrame, "OnShow")) then
		self:HookScript(Canvas.BlackoutFrame, "OnShow", function(blackout)
			if (self:GetSettings().hideBlackout) then
				blackout:Hide()
			end
		end)
	end

	if (Canvas.Maximize and not self:IsHooked(Canvas, "Maximize")) then
		self:SecureHook(Canvas, "Maximize", AnnounceDisplayState)
	end

	if (Canvas.Minimize and not self:IsHooked(Canvas, "Minimize")) then
		self:SecureHook(Canvas, "Minimize", AnnounceDisplayState)
	end

	if (Canvas.OnFrameSizeChanged and not self:IsHooked(Canvas, "OnFrameSizeChanged")) then
		self:SecureHook(Canvas, "OnFrameSizeChanged", AnnounceDisplayState)
	end
end

function MapCanvas:SetUpContainer()
	local Container_ = self:GetContainer()
	if (not Container_) then
		return
	end

	-- Keep the container's own handler so the fix can be undone.
	if (self.originalMouseWheel == nil) then
		self.originalMouseWheel = Container_:GetScript("OnMouseWheel") or false
		self.originalMethods = {}
		for name in pairs(Container) do
			self.originalMethods[name] = rawget(Container_, name) or false
		end
	end
end

function MapCanvas:ApplyContainerFix(enable)
	local Container_ = self:GetContainer()
	if (not Container_) or (self.originalMouseWheel == nil) then
		return
	end

	if (enable) then
		for name, method in pairs(Container) do
			Container_[name] = method
		end
		Container_:SetScript("OnMouseWheel", Container.OnMouseWheel)
	else
		for name in pairs(Container) do
			local original = self.originalMethods[name]
			Container_[name] = (original ~= false) and original or nil
		end
		Container_:SetScript("OnMouseWheel", (self.originalMouseWheel ~= false) and self.originalMouseWheel or nil)
	end
end

function MapCanvas:OnMapReady()
	self:SetUpCanvas()
	self:SetUpContainer()
end

function MapCanvas:OnConfigChanged()
	local db = self:GetSettings()
	local Canvas = self:GetCanvas()

	self:ApplyContainerFix(db.classicZoom)

	if (not Canvas) or (not Canvas.BlackoutFrame) then
		return
	end

	if (db.hideBlackout) then
		Canvas.BlackoutFrame:Hide()
		Canvas.BlackoutFrame:EnableMouse(false)
		Canvas.BlackoutFrame:SetAlpha(0)
	else
		Canvas.BlackoutFrame:EnableMouse(true)
		Canvas.BlackoutFrame:SetAlpha(1)
	end
end

function MapCanvas:GetOptions()
	return {
		name = L["Map"],
		args = {
			description = {
				order = 1,
				type = "description",
				name = L["Adjustments to the world map frame itself."]
			},
			classicZoom = {
				order = 10,
				type = "toggle", width = "full",
				name = L["Mouse wheel zoom"],
				desc = L["Enables zooming the map with the mouse wheel, and corrects the cursor position the map uses for mouseover."],
				get = ns.Getter("canvas", "classicZoom"),
				set = ns.Setter("canvas", "classicZoom")
			},
			hideBlackout = {
				order = 20,
				type = "toggle", width = "full",
				name = L["Hide the backdrop"],
				desc = L["Hides the dark overlay the map draws across the rest of the screen, so you can still see and click your interface."],
				get = ns.Getter("canvas", "hideBlackout"),
				set = ns.Setter("canvas", "hideBlackout")
			}
		}
	}
end
