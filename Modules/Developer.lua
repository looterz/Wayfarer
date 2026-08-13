local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon

-- Developer mode: drag boss pins and dungeon entrance pins to their
-- correct spots, add, rename or delete them from a sidebar, and export
-- the touched data blocks as paste-ready Lua for the data files.
--
-- Edits mutate the live tables (ns.dungeonPortals, ns.dungeonBosses,
-- ns.derivedBosses) and persist per touched map in db.global, so
-- corrections survive reloads on this account until exported and folded
-- into the data files. Pristine copies taken at load back the revert.
--
-- This is developer tooling: deliberately unlocalized, off by default,
-- toggled with /wayf dev.
local Developer = Wayfarer:NewModule("Developer")

Developer.mapPriority = 90

-- GLOBALS: C_Map, CreateFrame, StaticPopupDialogs, StaticPopup_Show, UIParent

local ipairs = ipairs
local pairs = pairs
local string_format = string.format
local string_gsub = string.gsub
local tinsert = table.insert
local tremove = table.remove
local tostring = tostring

local SIDEBAR_WIDTH = 250
local ROW_HEIGHT = 18

-- MapSize reserves this much room on the map's right while developer
-- mode is on, so the sidebar never hangs off the screen.
ns.DEV_SIDEBAR_SPAN = SIDEBAR_WIDTH + 12

local Round = function(value)
	return math.floor(value * 10 + .5) / 10
end

local Prettify = function(folder)
	return ns.PrettyDungeonName(folder)
end

local CopyDeep
CopyDeep = function(source)
	local target = {}
	for key, value in pairs(source) do
		target[key] = (type(value) == "table") and CopyDeep(value) or value
	end
	return target
end

-- Persistence
----------------------------------------------------
local pristinePortals, pristineBosses, pristineDerived

local Store = function()
	local global = Wayfarer.db.global
	global.devData = global.devData or { bosses = {}, portals = {} }
	global.devData.bosses = global.devData.bosses or {}
	global.devData.portals = global.devData.portals or {}
	return global.devData
end

function Developer:IsOn()
	return Wayfarer.db.global.devMode and true or false
end

function Developer:OnInitialize()
	pristinePortals = CopyDeep(ns.dungeonPortals)
	pristineBosses = CopyDeep(ns.dungeonBosses)
	pristineDerived = CopyDeep(ns.derivedBosses or {})

	local data = Store()

	for zone, list in pairs(data.portals) do
		ns.dungeonPortals[zone] = CopyDeep(list)
	end

	for instance, record in pairs(data.bosses) do
		if (record.source == "derived") then
			ns.derivedBosses = ns.derivedBosses or {}
			ns.derivedBosses[instance] = CopyDeep(record.list)
		elseif (ns.dungeonBosses[instance]) then
			ns.dungeonBosses[instance].bosses = CopyDeep(record.list)
		end
	end
end

-- Which boss list an instance actually displays, and therefore the one
-- edits should land in: the derived list replaces a placeholder grid.
-- Reads must not create tables: an empty derived list would silently
-- replace the "Boss locations unknown" notice for untouched dungeons.
local empty = {}

local GetBossTarget = function(instanceMapID, create)
	if (ns.unpositionedBosses[instanceMapID]) then
		if (create) then
			ns.derivedBosses = ns.derivedBosses or {}
			ns.derivedBosses[instanceMapID] = ns.derivedBosses[instanceMapID] or {}
		end
		return (ns.derivedBosses and ns.derivedBosses[instanceMapID]) or empty, "derived"
	end
	local entry = ns.dungeonBosses[instanceMapID]
	if (not entry) then
		if (not create) then
			return empty, "authored"
		end
		ns.dungeonBosses[instanceMapID] = { bosses = {} }
		entry = ns.dungeonBosses[instanceMapID]
	end
	entry.bosses = entry.bosses or {}
	return entry.bosses, "authored"
end

local SaveBosses = function(instanceMapID)
	local list, source = GetBossTarget(instanceMapID, true)
	Store().bosses[instanceMapID] = { source = source, list = CopyDeep(list) }
end

local SavePortals = function(uiMapID)
	local list = ns.dungeonPortals[uiMapID]
	if (list) then
		Store().portals[uiMapID] = CopyDeep(list)
	else
		Store().portals[uiMapID] = nil
	end
end

-- Refresh plumbing
----------------------------------------------------
local GetInstanceMaps = function()
	return Wayfarer:GetModule("InstanceMaps", true)
end

local GetIntegrations = function()
	return Wayfarer:GetModule("Integrations", true)
end

function Developer:RedrawBosses(instanceMapID)
	local InstanceMaps = GetInstanceMaps()
	if (InstanceMaps) then
		if (InstanceMaps.InvalidateBossCache) then
			InstanceMaps:InvalidateBossCache(instanceMapID)
		end
		if (InstanceMaps.frame) and (InstanceMaps.frame:IsShown()) then
			InstanceMaps:Draw()
		end
	end
	self:RefreshSidebar()
end

function Developer:RedrawPortals()
	local Integrations = GetIntegrations()
	if (Integrations) and (Integrations.ShowEntrancePins) then
		Integrations:ShowEntrancePins()
	end
	self:RefreshSidebar()
end

-- What the world map is currently showing, from our point of view.
-- Returns "boss", instanceMapID, floor when an instance map is up, or
-- "portal", uiMapID when a zone map is up.
function Developer:GetContext()
	local InstanceMaps = GetInstanceMaps()
	if (InstanceMaps) and (InstanceMaps.frame) and (InstanceMaps.frame:IsShown()) and (InstanceMaps.instanceMapID) then
		return "boss", InstanceMaps.instanceMapID, InstanceMaps.floor or 1
	end

	local Canvas = self:GetCanvas()
	local uiMapID = Canvas and Canvas.GetMapID and Canvas:GetMapID()
	if (uiMapID) then
		return "portal", uiMapID
	end
end

-- Dragging: boss pins
----------------------------------------------------
local OnBossDragStop = function(pin)
	pin:StopMovingOrSizing()

	local InstanceMaps = GetInstanceMaps()
	local frame = InstanceMaps and InstanceMaps.frame
	if (not frame) or (not InstanceMaps.instanceMapID) then
		return
	end

	-- Everything scaled to screen pixels so the pin and the frame agree
	-- even mid canvas zoom.
	local ps, fs = pin:GetEffectiveScale(), frame:GetEffectiveScale()
	local cx, cy = pin:GetCenter()
	local left, top = frame:GetLeft(), frame:GetTop()
	if (not cx) or (not left) then
		return
	end

	local px = (cx * ps - left * fs) / fs
	local py = (top * fs - cy * ps) / fs
	local gx, gy = ns.FrameToGrid(px, py, frame:GetWidth(), frame:GetHeight())

	local instanceMapID = InstanceMaps.instanceMapID
	local floor = InstanceMaps.floor or 1
	local list = GetBossTarget(instanceMapID, true)

	for _, boss in ipairs(list) do
		if (boss[1] == pin.bossName) and (boss[4] == floor) then
			boss[2], boss[3] = Round(gx), Round(gy)
			break
		end
	end

	SaveBosses(instanceMapID)
	Developer:RedrawBosses(instanceMapID)
	Wayfarer:Print(string_format("%s moved to (%.1f, %.1f), floor %d.", pin.bossName or "?", Round(gx), Round(gy), floor))
end

local HookBossPins = function()
	local InstanceMaps = GetInstanceMaps()
	local frame = InstanceMaps and InstanceMaps.frame
	if (not frame) or (not frame.BossPins) then
		return
	end

	for _, pin in ipairs(frame.BossPins) do
		if (not pin.devHooked) then
			pin.devHooked = true
			pin:SetMovable(true)
			pin:RegisterForDrag("LeftButton")
			pin:SetScript("OnDragStart", function(self)
				if (Developer:IsOn()) then
					self:StartMoving()
				end
			end)
			pin:SetScript("OnDragStop", OnBossDragStop)
		end
	end
end

-- Dragging: entrance pins
----------------------------------------------------
local OnPortalDragStop = function(pin)
	pin:StopMovingOrSizing()

	local Canvas = Developer:GetCanvas()
	local child = Canvas and Canvas.ScrollContainer and Canvas.ScrollContainer.Child
	local uiMapID = Canvas and Canvas.GetMapID and Canvas:GetMapID()
	local portals = uiMapID and ns.dungeonPortals[uiMapID]
	if (not child) or (not portals) or (not pin.devIndex) then
		return
	end

	-- The scroll child rescales with zoom, so compare in screen pixels.
	local ps, cs = pin:GetEffectiveScale(), child:GetEffectiveScale()
	local cx, cy = pin:GetCenter()
	local left, top = child:GetLeft(), child:GetTop()
	if (not cx) or (not left) then
		return
	end

	local x = (cx * ps - left * cs) / (child:GetWidth() * cs) * 100
	local y = (top * cs - cy * ps) / (child:GetHeight() * cs) * 100

	local portal = portals[pin.devIndex]
	if (portal) then
		portal.x, portal.y = Round(x), Round(y)
		SavePortals(uiMapID)
		Wayfarer:Print(string_format("%s entrance moved to (%.1f, %.1f).", Prettify(portal.name), portal.x, portal.y))
	end

	Developer:RedrawPortals()
end

local HookEntrancePins = function()
	local Integrations = GetIntegrations()
	local pins = Integrations and Integrations.entrancePins
	if (not pins) then
		return
	end

	local on = Developer:IsOn()

	for index, pin in ipairs(pins) do
		pin.devIndex = index

		if (not pin.devHooked) then
			pin.devHooked = true
			pin:SetMovable(true)
			pin:RegisterForDrag("LeftButton")
			pin:SetScript("OnDragStart", function(self)
				if (Developer:IsOn()) then
					self:StartMoving()
				end
			end)
			pin:SetScript("OnDragStop", OnPortalDragStop)
		end

		-- The marker art is normally hidden; an invisible pin cannot be
		-- dragged with any confidence, so force it visible in dev mode.
		if (on) and (pin:IsShown()) then
			pin.Icon:Show()
			pin.Fill:Show()
			pin.Backing:Show()
		end
	end
end

-- Popups
----------------------------------------------------
StaticPopupDialogs["WAYFARER_DEV_TEXT"] = {
	text = "%s",
	button1 = "Accept",
	button2 = "Cancel",
	hasEditBox = true,
	editBoxWidth = 260,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnShow = function(self)
		local box = self.editBox or self.EditBox
		if (box) and (self.data) and (self.data.default) then
			box:SetText(self.data.default)
			box:HighlightText()
		end
	end,
	OnAccept = function(self)
		local box = self.editBox or self.EditBox
		local value = box and box:GetText()
		if (self.data) and (self.data.callback) and (value) and (value ~= "") then
			self.data.callback(value)
		end
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		StaticPopupDialogs["WAYFARER_DEV_TEXT"].OnAccept(parent)
		parent:Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
}

local AskText = function(prompt, default, callback)
	StaticPopup_Show("WAYFARER_DEV_TEXT", prompt, nil, { default = default, callback = callback })
end

-- Editing operations
----------------------------------------------------
function Developer:AddPin()
	local kind, id, floor = self:GetContext()

	if (kind == "boss") then
		AskText("Name for the new boss pin:", "", function(name)
			local list = GetBossTarget(id, true)
			tinsert(list, { name, 48.9, 43.5, floor })
			SaveBosses(id)
			self:RedrawBosses(id)
			Wayfarer:Print(string_format("%s added at the map centre of floor %d. Drag it into place.", name, floor))
		end)
	elseif (kind == "portal") then
		AskText("Dungeon folder for the new entrance (e.g. TheDeadmines):", "", function(name)
			ns.dungeonPortals[id] = ns.dungeonPortals[id] or {}
			tinsert(ns.dungeonPortals[id], { x = 50, y = 50, name = name, floor = 1 })
			SavePortals(id)
			self:RedrawPortals()
			Wayfarer:Print(string_format("%s entrance added at the map centre. Drag it into place.", Prettify(name)))
		end)
	end
end

function Developer:RenameRow(kind, id, index)
	if (kind == "boss") then
		local list = GetBossTarget(id, true)
		local boss = list[index]
		if (not boss) then return end
		AskText("Rename boss:", boss[1], function(name)
			boss[1] = name
			SaveBosses(id)
			self:RedrawBosses(id)
		end)
	else
		local portals = ns.dungeonPortals[id]
		local portal = portals and portals[index]
		if (not portal) then return end
		AskText("Dungeon folder for this entrance:", portal.name, function(name)
			portal.name = name
			SavePortals(id)
			self:RedrawPortals()
		end)
	end
end

function Developer:DeleteRow(kind, id, index)
	if (kind == "boss") then
		local list = GetBossTarget(id, true)
		if (list[index]) then
			Wayfarer:Print(string_format("Removed boss pin: %s.", tostring(list[index][1])))
			tremove(list, index)
			SaveBosses(id)
			self:RedrawBosses(id)
		end
	else
		local portals = ns.dungeonPortals[id]
		if (portals) and (portals[index]) then
			Wayfarer:Print(string_format("Removed entrance pin: %s.", Prettify(portals[index].name)))
			tremove(portals, index)
			SavePortals(id)
			self:RedrawPortals()
		end
	end
end

function Developer:RevertMap()
	local kind, id = self:GetContext()
	if (kind == "boss") then
		local _, source = GetBossTarget(id)
		if (source == "derived") then
			ns.derivedBosses[id] = pristineDerived[id] and CopyDeep(pristineDerived[id]) or nil
		else
			ns.dungeonBosses[id].bosses = pristineBosses[id] and CopyDeep(pristineBosses[id].bosses) or {}
		end
		Store().bosses[id] = nil
		self:RedrawBosses(id)
		Wayfarer:Print("Boss pins for this map reverted to the shipped data.")
	elseif (kind == "portal") then
		ns.dungeonPortals[id] = pristinePortals[id] and CopyDeep(pristinePortals[id]) or nil
		Store().portals[id] = nil
		self:RedrawPortals()
		Wayfarer:Print("Entrance pins for this map reverted to the shipped data.")
	end
end

-- Export
----------------------------------------------------
local FormatBossLine = function(boss)
	if (boss[5]) then
		return string_format('\t{ "%s", %s, %s, %d, "%s", %d },', boss[1], boss[2], boss[3], boss[4], boss[5], boss[6])
	end
	return string_format('\t{ "%s", %s, %s, %d },', boss[1], boss[2], boss[3], boss[4])
end

function Developer:BuildExport()
	local data = Store()
	local lines = { "-- Wayfarer developer export, paste-ready data blocks" }

	for zone, list in pairs(data.portals) do
		lines[#lines + 1] = ""
		lines[#lines + 1] = string_format("-- ns.dungeonPortals[%d]", zone)
		lines[#lines + 1] = string_format("[%d] = {", zone)
		for _, portal in ipairs(list) do
			lines[#lines + 1] = string_format('\t{ x=%s, y=%s, name="%s", floor=%d },',
				portal.x, portal.y, portal.name, portal.floor or 1)
		end
		lines[#lines + 1] = "},"
	end

	for instance, record in pairs(data.bosses) do
		lines[#lines + 1] = ""
		lines[#lines + 1] = string_format("-- ns.%s[%d]",
			record.source == "derived" and "derivedBosses" or "dungeonBosses (bosses list)", instance)
		lines[#lines + 1] = string_format("[%d] = {", instance)
		for _, boss in ipairs(record.list) do
			lines[#lines + 1] = FormatBossLine(boss)
		end
		lines[#lines + 1] = "},"
	end

	if (#lines == 1) then
		lines[#lines + 1] = "-- No overrides recorded yet."
	end

	return table.concat(lines, "\n")
end

function Developer:ShowExport()
	if (not self.exportFrame) then
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetSize(600, 440)
		frame:SetPoint("CENTER")
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

		local bg = frame:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, .92)

		local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", 12, -10)
		title:SetText("Wayfarer developer export")

		local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
		hint:SetText("Ctrl+A then Ctrl+C to copy. Escape closes.")

		local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 0, 0)

		local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 12, -52)
		scroll:SetPoint("BOTTOMRIGHT", -30, 12)

		local edit = CreateFrame("EditBox", nil, scroll)
		edit:SetMultiLine(true)
		edit:SetFontObject(_G.GameFontHighlightSmall)
		edit:SetWidth(550)
		edit:SetAutoFocus(false)
		edit:SetScript("OnEscapePressed", function() frame:Hide() end)
		scroll:SetScrollChild(edit)
		frame.EditBox = edit

		self.exportFrame = frame
	end

	self.exportFrame.EditBox:SetText(self:BuildExport())
	self.exportFrame:Show()
	self.exportFrame.EditBox:SetFocus()
	self.exportFrame.EditBox:HighlightText()
end

-- Sidebar
----------------------------------------------------
function Developer:CreateSidebar()
	if (self.sidebar) then
		return self.sidebar
	end

	local Canvas = self:GetCanvas()

	local bar = CreateFrame("Frame", nil, Canvas)
	bar:SetWidth(SIDEBAR_WIDTH)
	bar:SetPoint("TOPLEFT", Canvas, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", Canvas, "BOTTOMRIGHT", 6, 0)
	bar:SetFrameStrata(Canvas:GetFrameStrata())
	bar:SetFrameLevel(9200)
	bar:EnableMouse(true)
	bar:Hide()

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, .85)

	local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText("|cff88ccffWayfarer|r developer")
	bar.Title = title

	local context = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	context:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	context:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
	context:SetJustifyH("LEFT")
	bar.Context = context

	local hint = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", context, "BOTTOMLEFT", 0, -4)
	hint:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText("Drag pins on the map to reposition them.")

	-- Bottom buttons.
	local add = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
	add:SetSize(SIDEBAR_WIDTH - 20, 20)
	add:SetPoint("BOTTOMLEFT", 10, 62)
	add:SetText("Add pin here")
	add:SetScript("OnClick", function() self:AddPin() end)

	local export = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
	export:SetSize(SIDEBAR_WIDTH - 20, 20)
	export:SetPoint("BOTTOMLEFT", 10, 38)
	export:SetText("Export overrides")
	export:SetScript("OnClick", function() self:ShowExport() end)

	local revert = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
	revert:SetSize(SIDEBAR_WIDTH - 20, 20)
	revert:SetPoint("BOTTOMLEFT", 10, 14)
	revert:SetText("Revert this map")
	revert:SetScript("OnClick", function() self:RevertMap() end)

	local scroll = CreateFrame("ScrollFrame", nil, bar, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -74)
	scroll:SetPoint("BOTTOMRIGHT", -28, 90)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(SIDEBAR_WIDTH - 38, 10)
	scroll:SetScrollChild(content)
	bar.Content = content
	bar.Rows = {}

	self.sidebar = bar
	return bar
end

function Developer:GetRow(index)
	local bar = self.sidebar
	local row = bar.Rows[index]

	if (not row) then
		row = CreateFrame("Frame", nil, bar.Content)
		row:SetSize(SIDEBAR_WIDTH - 38, ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

		local delete = CreateFrame("Button", nil, row)
		delete:SetSize(20, ROW_HEIGHT)
		delete:SetPoint("RIGHT", 0, 0)
		delete:SetNormalFontObject(_G.GameFontNormalSmall)
		delete:SetHighlightFontObject(_G.GameFontHighlightSmall)
		delete:SetText("|cffff5555x|r")
		delete:SetScript("OnClick", function()
			if (row.kind) then
				Developer:DeleteRow(row.kind, row.id, row.index)
			end
		end)

		local rename = CreateFrame("Button", nil, row)
		rename:SetSize(20, ROW_HEIGHT)
		rename:SetPoint("RIGHT", delete, "LEFT", -2, 0)
		rename:SetNormalFontObject(_G.GameFontNormalSmall)
		rename:SetHighlightFontObject(_G.GameFontHighlightSmall)
		rename:SetText("|cffffcc00r|r")
		rename:SetScript("OnClick", function()
			if (row.kind) then
				Developer:RenameRow(row.kind, row.id, row.index)
			end
		end)

		local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("LEFT", 0, 0)
		text:SetPoint("RIGHT", rename, "LEFT", -4, 0)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
		row.Text = text

		bar.Rows[index] = row
	end

	return row
end

function Developer:RefreshSidebar()
	local bar = self.sidebar
	if (not bar) then
		return
	end

	local Canvas = self:GetCanvas()
	if (not self:IsOn()) or (not Canvas) or (not Canvas:IsShown()) then
		bar:Hide()
		return
	end

	local kind, id, floor = self:GetContext()
	if (not kind) then
		bar:Hide()
		return
	end

	local shown = 0

	if (kind == "boss") then
		local dungeon = ns.dungeonByMapID[id] or "?"
		bar.Context:SetFormattedText("Instance: %s (%d), floor %d", Prettify(dungeon), id, floor or 1)

		local list, source = GetBossTarget(id)
		for index, boss in ipairs(list) do
			shown = shown + 1
			local row = self:GetRow(shown)
			row.kind, row.id, row.index = "boss", id, index
			local current = (boss[4] == floor) and "|cffffffff" or "|cff888888"
			row.Text:SetFormattedText("%s%s|r  |cff667788f%d (%.1f, %.1f)|r", current, boss[1], boss[4], boss[2], boss[3])
			row:Show()
		end
	else
		local info = Canvas.GetMapID and _G.C_Map.GetMapInfo(id)
		bar.Context:SetFormattedText("Zone: %s (%d)", info and info.name or "?", id)

		local portals = ns.dungeonPortals[id] or {}
		for index, portal in ipairs(portals) do
			shown = shown + 1
			local row = self:GetRow(shown)
			row.kind, row.id, row.index = "portal", id, index
			row.Text:SetFormattedText("|cffffffff%s|r  |cff667788(%.1f, %.1f)|r", Prettify(portal.name), portal.x, portal.y)
			row:Show()
		end
	end

	for i = shown + 1, #bar.Rows do
		bar.Rows[i]:Hide()
	end

	bar.Content:SetHeight(math.max(shown * ROW_HEIGHT, 10))
	bar:Show()
end

-- Toggle and wiring
----------------------------------------------------
function Developer:Toggle()
	Wayfarer.db.global.devMode = not Wayfarer.db.global.devMode

	if (self:IsOn()) then
		Wayfarer:Print("Developer mode |cff88ff88on|r. Drag pins to move them; the sidebar on the world map adds, renames, deletes and exports.")
	else
		Wayfarer:Print("Developer mode |cffff8888off|r. Recorded overrides still apply; /wayf dev to edit again.")
	end

	local MapSize = Wayfarer:GetModule("MapSize", true)
	if (MapSize) and (MapSize.ApplyScale) then
		MapSize:ApplyScale()
	end

	HookEntrancePins()
	self:RedrawPortals()
	self:RefreshSidebar()
end

function Developer:OnInstanceMapShown()
	HookBossPins()
	self:RefreshSidebar()
end

function Developer:OnMapReady()
	self:CreateSidebar()

	local Canvas = self:GetCanvas()
	self:SecureHookScript(Canvas, "OnShow", "RefreshSidebar")
	self:SecureHookScript(Canvas, "OnHide", "RefreshSidebar")
	if (Canvas.OnMapChanged) then
		self:SecureHook(Canvas, "OnMapChanged", "RefreshSidebar")
	end

	local Integrations = GetIntegrations()
	if (Integrations) and (Integrations.ShowEntrancePins) then
		self:SecureHook(Integrations, "ShowEntrancePins", HookEntrancePins)
	end

	self:RegisterMessage("Wayfarer_InstanceMapShown", "OnInstanceMapShown")
	self:RegisterMessage("Wayfarer_InstanceMapHidden", "RefreshSidebar")
	self:RegisterMessage("Wayfarer_MapDisplayStateChanged", "RefreshSidebar")
end
