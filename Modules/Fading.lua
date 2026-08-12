local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon
local L = ns.L

-- Fades the map down while you're running, so you can see where
-- you're actually going, and back up when you stop.
local Fading = Wayfarer:NewModule("Fading")

Fading.mapPriority = 20
Fading.settingsKey = "fading"
Fading.optionsKey = "fading"
Fading.optionsOrder = 20

-- GLOBALS: IsPlayerMoving

local SetRawAlpha = ns.SetRawAlpha

local STEP_IN = .05
local STEP_OUT = .05
local THROTTLE = .02

-- Walk the map's alpha towards its target, then stop costing us frames.
local OnUpdate_Fader = function(self, elapsed)
	self.elapsed = self.elapsed + elapsed
	if (self.elapsed < THROTTLE) then
		return
	end
	self.elapsed = 0

	if (not self.isFading) then
		return
	end

	if (self.fadeDirection == "IN") then
		if (self.alpha + STEP_IN < self.stopAlpha) then
			self.alpha = self.alpha + STEP_IN
		else
			self.alpha = self.stopAlpha
			self.fadeDirection = nil
			self.isFading = nil
			self:SetScript("OnUpdate", nil)
		end

	elseif (self.fadeDirection == "OUT") then
		if (self.alpha - STEP_OUT > self.moveAlpha) then
			self.alpha = self.alpha - STEP_OUT
		else
			self.alpha = self.moveAlpha
			self.fadeDirection = nil
			self.isFading = nil
			self:SetScript("OnUpdate", nil)
		end
	end

	SetRawAlpha(self.Canvas, self.alpha)
end

function Fading:StartFading()
	local timer = self.FadeTimer
	if (not timer) then
		return
	end
	timer.alpha = self:GetCanvas():GetAlpha()
	timer.fadeDirection = "OUT"
	timer.isFading = true
	timer:SetScript("OnUpdate", OnUpdate_Fader)
end

function Fading:StopFading()
	local timer = self.FadeTimer
	if (not timer) then
		return
	end
	timer.alpha = self:GetCanvas():GetAlpha()
	timer.fadeDirection = "IN"
	timer.isFading = true
	timer:SetScript("OnUpdate", OnUpdate_Fader)
end

-- Decide which way we should be fading right now.
function Fading:UpdateFading()
	if (not self:IsMapReady()) then
		return
	end

	if (self:GetSettings().enable and IsPlayerMoving()) then
		self:StartFading()
	else
		self:StopFading()
	end
end

-- The map resets its own alpha when Blizzard feels like it,
-- so while we own the opacity we replace SetAlpha with a no-op
-- and drive the real one off the frame metatable instead.
function Fading:TakeOverAlpha(takeOver)
	local Canvas = self:GetCanvas()
	if (not Canvas) then
		return
	end

	if (takeOver) then
		if (not self.ownsAlpha) then
			Canvas.SetAlpha = function() end
			self.ownsAlpha = true
		end
	elseif (self.ownsAlpha) then
		Canvas.SetAlpha = nil
		self.ownsAlpha = nil
		SetRawAlpha(Canvas, 1)
	end
end

function Fading:OnMapReady()
	local Canvas = self:GetCanvas()

	local timer = CreateFrame("Frame", nil, Canvas)
	timer.elapsed = 0
	timer.Canvas = Canvas
	timer.stopAlpha = self:GetSettings().alphaStationary
	timer.moveAlpha = self:GetSettings().alphaMoving

	self.FadeTimer = timer

	-- Opening the map is as good a reason to re-evaluate as moving is.
	self:SecureHookScript(Canvas, "OnShow", function() self:UpdateFading() end)

	self:RegisterEvent("PLAYER_STARTED_MOVING", "UpdateFading")
	self:RegisterEvent("PLAYER_STOPPED_MOVING", "UpdateFading")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateFading")
end

function Fading:OnConfigChanged()
	if (not self.FadeTimer) then
		return
	end

	local db = self:GetSettings()

	self.FadeTimer.stopAlpha = db.alphaStationary
	self.FadeTimer.moveAlpha = db.alphaMoving

	-- We keep ownership even with movement fading off, because the
	-- stationary opacity slider still applies to a map sitting still.
	self:TakeOverAlpha(true)
	self:UpdateFading()
end

function Fading:GetOptions()
	return {
		name = L["Fading"],
		args = {
			description = {
				order = 1,
				type = "description",
				name = L["Controls how opaque the map is, and whether it gets out of your way while you move."]
			},
			alphaStationary = {
				order = 10,
				type = "range", width = "full",
				min = .1, max = 1, step = .05, isPercent = true,
				name = L["Map opacity"],
				desc = L["Sets the map opacity when not moving."],
				get = ns.Getter("fading", "alphaStationary"),
				set = ns.Setter("fading", "alphaStationary")
			},
			enable = {
				order = 20,
				type = "toggle", width = "full",
				name = L["Fade when moving"],
				desc = L["Fades the map out when moving to allow you to see your character and its closest surroundings."],
				get = ns.Getter("fading", "enable"),
				set = ns.Setter("fading", "enable")
			},
			alphaMoving = {
				order = 30,
				type = "range", width = "full",
				min = .1, max = 1, step = .05, isPercent = true,
				name = L["Map opacity when moving"],
				desc = L["Sets the map opacity when moving."],
				disabled = function() return not Wayfarer.db.profile.fading.enable end,
				get = ns.Getter("fading", "alphaMoving"),
				set = ns.Setter("fading", "alphaMoving")
			}
		}
	}
end
