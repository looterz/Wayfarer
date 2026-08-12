local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon

-- GLOBALS: C_Map, CreateFrame, Event, GetInstanceInfo, GetMouseFocus, GetPlayerFacing, GetTime, IsInInstance, UIParent, UnitPosition

-- MINIMAP_PING is a callback event on this client (CallbackEvent = true
-- in the API docs): Frame:RegisterEvent throws "attempt to register
-- unknown event" for it, and that abort took this whole file down once.
-- The correct path is the C-side callback system via Event.RegisterCallback
-- (Blizzard_SharedXMLBase/Event.lua). Both attempts are wrapped so a
-- registration failure can never break diagnostics again. The API
-- documentation lists the payload as (unitTarget, y, x), y first.
local pingRegistered = false

local RecordPing = function(unit, y, x)
	ns.lastPing = { unit = unit, x = x, y = y, at = GetTime() }
end

if (type(Event) == "table") and (type(Event.RegisterCallback) == "function") then
	pingRegistered = pcall(Event.RegisterCallback, "MINIMAP_PING", RecordPing)
end

if (not pingRegistered) then
	pingRegistered = pcall(function()
		local watcher = CreateFrame("Frame")
		watcher:RegisterEvent("MINIMAP_PING")
		watcher:SetScript("OnEvent", function(_, _, unit, y, x)
			RecordPing(unit, y, x)
		end)
	end)
end

local ipairs = ipairs
local select = select
local string_format = string.format
local tostring = tostring

-- Whether the player can be placed on an instance map at all comes down
-- to what this client will tell us from inside a dungeon, and that is
-- not something we can find out from the outside. This prints the answer.
--
--   /wayf probe
--
-- Run it standing inside an instance and hand the output back.
ns.Probe = function()
	local say = function(...)
		Wayfarer:Print(string_format(...))
	end

	local yellow = ns.Colors.title.colorCode

	Wayfarer:Print(yellow.."--- Wayfarer position probe ---|r")

	local inInstance, instanceType = IsInInstance()
	say("IsInInstance: %s (%s)", tostring(inInstance), tostring(instanceType))

	local name, itype, difficultyID, difficultyName, maxPlayers, _, _, instanceID = GetInstanceInfo()
	say("GetInstanceInfo: name=%s type=%s instanceID=%s maxPlayers=%s",
		tostring(name), tostring(itype), tostring(instanceID), tostring(maxPlayers))

	local uiMapID = C_Map.GetBestMapForUnit("player")
	say("GetBestMapForUnit: %s", tostring(uiMapID))

	if (uiMapID) then
		local info = C_Map.GetMapInfo(uiMapID)
		say("  map name: %s, type: %s, parent: %s",
			tostring(info and info.name), tostring(info and info.mapType), tostring(info and info.parentMapID))

		local layers = C_Map.GetMapArtLayers(uiMapID)
		say("  art layers: %s", layers and #layers or "none")

		local artID = C_Map.GetMapArtID(uiMapID)
		say("  art ID: %s", tostring(artID))

		local position = C_Map.GetPlayerMapPosition(uiMapID, "player")
		if (position) then
			local x, y = position:GetXY()
			say("  GetPlayerMapPosition: %.4f, %.4f  <- positioning is possible", x or -1, y or -1)
		else
			say("  GetPlayerMapPosition: nil  <- no map-space position here")
		end
	end

	if (type(UnitPosition) ~= "function") then
		say("UnitPosition: not present on this client")
	elseif (true) then
		local py, px, pz, worldMapID = UnitPosition("player")
		if (px) then
			say("UnitPosition: x=%.2f y=%.2f z=%.2f instance=%s  <- world coords available",
				px, py, pz or 0, tostring(worldMapID))
		else
			say("UnitPosition: exists but returned nil here")
		end
	end

	-- "GetPlayerFacing and GetPlayerFacing()" prints nil both when the
	-- function is absent and when it exists but returns nil, so the
	-- earlier output could not distinguish "no such API on this client"
	-- from "no heading available in here". Separate them.
	if (type(GetPlayerFacing) ~= "function") then
		say("GetPlayerFacing: |cffff6666not present on this client|r")
	else
		local facing = GetPlayerFacing()
		if (facing) then
			say("GetPlayerFacing: |cff88ff88%.4f rad (%.1f deg)|r", facing, facing * 180 / math.pi)
		else
			say("GetPlayerFacing: present, returned nil here")
		end
	end

	if (type(GetUnitSpeed) ~= "function") then
		say("GetUnitSpeed: not present on this client")
	else
		local speed = GetUnitSpeed("player")
		say("GetUnitSpeed(player): %s", tostring(speed))
	end

	-- A minimap ping reports where it landed relative to the player, in
	-- minimap-radius fractions. If the payload survives inside an
	-- instance it is a yardstick: ping a known feature and the offset is
	-- measurable. The event only fires on an actual ping, so the last one
	-- seen is cached here and read back by the next probe.
	if (not pingRegistered) then
		say("MINIMAP_PING: could not listen for pings on this client")
	elseif (ns.lastPing) then
		say("MINIMAP_PING: last ping x=%.3f y=%.3f (%ds ago)",
			ns.lastPing.x or -99, ns.lastPing.y or -99, GetTime() - ns.lastPing.at)
	else
		say("MINIMAP_PING: none seen yet. Alt-click the minimap, then probe again.")
	end

	local InstanceMaps = Wayfarer:GetModule("InstanceMaps", true)
	if (InstanceMaps) then
		local dungeon, instanceMapID = InstanceMaps:GetPlayerDungeon()
		if (dungeon) then
			say("Wayfarer map: %s (instanceMapID %s), floor %s",
				dungeon, tostring(instanceMapID), tostring(InstanceMaps.floor))
		else
			say("Wayfarer has no dungeon map matching this instance")
		end
		say("integrations: Questie=%s AtlasLoot=%s Leatrix_Maps=%s",
			tostring(ns.HasQuestie and ns.HasQuestie()),
			tostring(ns.HasAtlasLoot and ns.HasAtlasLoot()),
			tostring(ns.HasLeatrixMaps and ns.HasLeatrixMaps()))

		local Integrations = Wayfarer:GetModule("Integrations", true)
		if (Integrations) then
			local db = Integrations:GetSettings()
			say("  AtlasLoot.GUI present: %s   boss pins on: %s",
				tostring(AtlasLoot ~= nil and AtlasLoot.GUI ~= nil),
				tostring(InstanceMaps and InstanceMaps:GetSettings().showBosses))
			local pins = Integrations.entrancePins
			say("  entrance pins on: %s   created: %s",
				tostring(db.entrancePins), tostring(pins and #pins or 0))

			-- Where the first one actually is, and whether it is drawing.
			if (pins) and (pins[1]) then
				local pin = pins[1]
				local left = pin:GetLeft()
				say("    pin 1: %s  shown=%s  %s",
					tostring(pin.label),
					tostring(pin:IsShown()),
					left and string_format("L=%.0f T=%.0f size %.0fx%.0f strata=%s level=%d",
						left, pin:GetTop() or 0, pin:GetWidth() or 0, pin:GetHeight() or 0,
						pin:GetFrameStrata(), pin:GetFrameLevel()) or "not laid out")

				if (pin.Icon) then
					say("    icon: shown=%s alpha=%.2f texture=%s",
						tostring(pin.Icon:IsShown()), pin.Icon:GetAlpha() or 0,
						tostring(pin.Icon:GetTexture()))
				end

				local parent = pin:GetParent()
				if (parent) then
					say("    parent: %s  %0.fx%.0f  level=%d",
						tostring(parent:GetName() or "<unnamed>"),
						parent:GetWidth() or 0, parent:GetHeight() or 0,
						parent:GetFrameLevel())
				end
			end

			-- How many entrances this zone should have at all.
			local Canvas = Wayfarer.Canvas
			local uiMapID = Canvas and Canvas.GetMapID and Canvas:GetMapID()
			local portals = uiMapID and ns.dungeonPortals[uiMapID]
			say("    this zone (uiMapID %s) has %s entrance(s) in our data",
				tostring(uiMapID), portals and #portals or 0)
		end
	end

	-- Walk the same decision the player pin makes, and say which step
	-- turned it off. Guessing at this from outside the game is exactly
	-- what the probe exists to avoid.
	local InstanceMapsModule = Wayfarer:GetModule("InstanceMaps", true)
	if (InstanceMapsModule) then
		local reason

		if (InstanceMapsModule.selection) then
			reason = "you are browsing another dungeon by hand"
		elseif (not InstanceMapsModule.isPlayerDungeon) then
			reason = "no dungeon map is showing for where you are"
		elseif (not uiMapID) then
			reason = "GetBestMapForUnit returned nothing in here"
		else
			local pos = C_Map.GetPlayerMapPosition(uiMapID, "player")
			local px = pos and pos:GetXY()
			if (not px) then
				reason = "the client will not report a position in this instance"
			end
		end

		-- Settled: Classic Era reports no position inside an instance,
		-- so there is no player marker to draw. Kept in the probe so the
		-- finding is reproducible rather than folklore.
		say("player position: %s", reason or "reported (unexpected on Classic Era)")
	end

	Wayfarer:Print(yellow.."--- end of probe ---|r")
end

-- Where every piece of the map frame actually sits on screen. Run this
-- with the map open when something is hanging outside its border, so we
-- can see which element is misplaced instead of guessing at it.
--
--   /wayf frames
--
ns.FrameReport = function()
	local say = function(...)
		Wayfarer:Print(string_format(...))
	end

	local yellow = ns.Colors.title.colorCode
	local Canvas = Wayfarer.Canvas

	Wayfarer:Print(yellow.."--- Wayfarer frame geometry ---|r")

	if (not Canvas) then
		Wayfarer:Print("The world map has not been set up yet.")
		return
	end

	say("UIParent: %.0f x %.0f (scale %.3f)",
		UIParent:GetWidth(), UIParent:GetHeight(), UIParent:GetEffectiveScale())

	local Report = function(label, frame)
		if (not frame) then
			say("%s: absent", label)
			return
		end

		local left, right = frame:GetLeft(), frame:GetRight()
		local top, bottom = frame:GetTop(), frame:GetBottom()

		if (not left) then
			say("%s: not laid out", label)
			return
		end

		say("%s: L=%.0f R=%.0f T=%.0f B=%.0f  (%.0f x %.0f)%s",
			label, left, right, top, bottom, right - left, top - bottom,
			frame.IsShown and (frame:IsShown() and "" or "  [hidden]") or "")
	end

	say("maximized: %s", tostring(Canvas.IsMaximized and Canvas:IsMaximized() or Canvas.isMaximized))
	say("map scale: %.3f (effective %.3f)", Canvas:GetScale(), Canvas:GetEffectiveScale())

	Report("WorldMapFrame", Canvas)
	Report("  ScrollContainer", Canvas.ScrollContainer)
	Report("  ScrollContainer.Child", Canvas.ScrollContainer and Canvas.ScrollContainer.Child)
	Report("  BorderFrame", Canvas.BorderFrame)
	Report("  MiniBorderFrame", Canvas.MiniBorderFrame)
	Report("  CloseButton", Canvas.CloseButton or (Canvas.BorderFrame and Canvas.BorderFrame.CloseButton))
	Report("  MaximizeMinimizeFrame", Canvas.MaximizeMinimizeFrame
		or (Canvas.BorderFrame and Canvas.BorderFrame.MaximizeMinimizeFrame))

	local InstanceMaps = Wayfarer:GetModule("InstanceMaps", true)
	if (InstanceMaps) and (InstanceMaps.FindMapDropdowns) then
		local dropdowns = InstanceMaps:FindMapDropdowns()
		say("map dropdowns found: %d", #dropdowns)
		for _, frame in ipairs(dropdowns) do
			Report("  "..(frame:GetName() or "<unnamed>"), frame)
		end
		Report("  Wayfarer picker", InstanceMaps.selector)
		local picker = InstanceMaps.selector
		if (picker) then
			say("    strata=%s level=%d parent=%s mouse=%s",
				picker:GetFrameStrata(), picker:GetFrameLevel(),
				tostring(picker:GetParent() and picker:GetParent():GetName() or "?"),
				tostring(picker:IsMouseEnabled()))
		end
	end

	-- The dungeon overlay, if one is up: its scale is what decides
	-- whether the map fills the canvas.
	local InstanceMapsModule = Wayfarer:GetModule("InstanceMaps", true)
	local overlay = InstanceMapsModule and InstanceMapsModule.frame

	if (overlay) then
		Report("  dungeon map", overlay)
		local container = Wayfarer.Container
		local os_ = overlay:GetScale() or 1
		say("    scale=%.3f  rendered %.0f x %.0f  in container %.0f x %.0f",
			os_, overlay:GetWidth() * os_, overlay:GetHeight() * os_,
			container and container:GetWidth() or 0,
			container and container:GetHeight() or 0)
		say("    dungeon=%s floor=%s", tostring(InstanceMapsModule.dungeon),
			tostring(InstanceMapsModule.floor))
	else
		say("dungeon map: not created")
	end

	-- What the map occupies on screen once its scale is applied.
	local scale = Canvas:GetScale() or 1
	say("on screen: %.0f x %.0f of %.0f x %.0f",
		Canvas:GetWidth() * scale, Canvas:GetHeight() * scale,
		UIParent:GetWidth(), UIParent:GetHeight())

	Wayfarer:Print(yellow.."--- end of report ---|r")
end

-- Every named frame hanging off the world map, with its type and rect.
-- When something can't find the widget it needs to anchor to, this says
-- what is actually there instead of us guessing at Blizzard's names.
--
--   /wayf tree
--
local MAX_TREE_DEPTH = 4

ns.FrameTree = function()
	local yellow = ns.Colors.title.colorCode
	local Canvas = Wayfarer.Canvas

	Wayfarer:Print(yellow.."--- Wayfarer map frame tree ---|r")

	if (not Canvas) then
		Wayfarer:Print("The world map has not been set up yet.")
		return
	end

	local count = 0

	local Walk
	Walk = function(frame, depth, indent)
		if (not frame) or (not frame.GetChildren) or (depth > MAX_TREE_DEPTH) then
			return
		end

		for i = 1, select("#", frame:GetChildren()) do
			local child = select(i, frame:GetChildren())

			if (child) then
				local name = child.GetName and child:GetName()
				local kind = child.GetObjectType and child:GetObjectType() or "?"

				-- Unnamed frames can't be anchored to by name, but they
				-- may still contain something that can, so keep walking.
				if (name) then
					count = count + 1

					local left = child.GetLeft and child:GetLeft()
					local where = ""
					if (left) then
						where = string_format("  L=%.0f R=%.0f T=%.0f B=%.0f",
							left, child:GetRight(), child:GetTop(), child:GetBottom())
					else
						where = "  (not laid out)"
					end

					Wayfarer:Print(string_format("%s%s |cff888888[%s]%s%s|r",
						indent, name, kind, where,
						child:IsShown() and "" or " hidden"))
				end

				Walk(child, depth + 1, indent.."  ")
			end
		end
	end

	Walk(Canvas, 1, "")

	Wayfarer:Print(string_format("%d named frames, depth %d|r", count, MAX_TREE_DEPTH))
	Wayfarer:Print(yellow.."--- end of tree ---|r")
end

-- Forces the instance picker open and describes what came up, which
-- separates "the click never arrived" from "the list opened somewhere
-- you can't see it". Also names whatever is under the cursor, so a
-- frame stealing our clicks has nowhere to hide.
--
--   /wayf pick
--
ns.PickerReport = function()
	local say = function(...)
		Wayfarer:Print(string_format(...))
	end

	local yellow = ns.Colors.title.colorCode
	Wayfarer:Print(yellow.."--- Wayfarer picker test ---|r")

	local InstanceMaps = Wayfarer:GetModule("InstanceMaps", true)
	if (not InstanceMaps) then
		Wayfarer:Print("InstanceMaps module is not loaded.")
		return
	end

	local Describe = function(label, frame)
		if (not frame) then
			say("%s: absent", label)
			return
		end
		local left = frame:GetLeft()
		if (not left) then
			say("%s: not laid out  shown=%s", label, tostring(frame:IsShown()))
			return
		end
		say("%s: L=%.0f R=%.0f T=%.0f B=%.0f strata=%s level=%d shown=%s",
			label, left, frame:GetRight(), frame:GetTop(), frame:GetBottom(),
			frame:GetFrameStrata(), frame:GetFrameLevel(), tostring(frame:IsShown()))
	end

	-- What is the mouse actually over right now?
	local focus = GetMouseFocus and GetMouseFocus()
	if (focus) then
		say("mouse is over: %s [%s]",
			tostring(focus.GetName and focus:GetName() or "<unnamed>"),
			tostring(focus.GetObjectType and focus:GetObjectType() or "?"))
	else
		say("mouse is over: nothing")
	end

	Describe("picker", InstanceMaps.selector)

	-- Open it without going through a click.
	InstanceMaps:CreateList()
	InstanceMaps:RefreshList()
	InstanceMaps.list:SetFrameLevel(InstanceMaps.selector:GetFrameLevel() + 10)
	InstanceMaps.list:Show()
	InstanceMaps.list:Raise()

	Describe("list", InstanceMaps.list)
	Describe("  scroll", InstanceMaps.list.Scroll)
	Describe("  content", InstanceMaps.list.Content)
	Describe("  row 1", InstanceMaps.list.Rows and InstanceMaps.list.Rows[1])
	say("rows built: %d", InstanceMaps.list.Rows and #InstanceMaps.list.Rows or 0)

	Wayfarer:Print("If the list is listed above but you cannot see it, it is")
	Wayfarer:Print("rendering behind the map. If you CAN see it now, the")
	Wayfarer:Print("button's click is being intercepted instead.")
	Wayfarer:Print(yellow.."--- end of picker test ---|r")
end

-- Why the fog of war is or is not lifted on the map you're looking at.
-- Walks the same chain the reveal does and names the step that stopped it.
--
--   /wayf fog
--
ns.FogReport = function()
	local say = function(...)
		Wayfarer:Print(string_format(...))
	end

	local yellow = ns.Colors.title.colorCode
	Wayfarer:Print(yellow.."--- Wayfarer fog of war ---|r")

	local MapReveal = Wayfarer:GetModule("MapReveal", true)
	if (not MapReveal) or (not MapReveal.GetDebugInfo) then
		Wayfarer:Print("MapReveal module is not loaded.")
		return
	end

	local info = MapReveal:GetDebugInfo()

	say("map: uiMapID=%s artID=%s", tostring(info.uiMapID), tostring(info.artID))
	say("our tile data for this art: %s%s",
		tostring(info.haveData),
		info.tiles and (" ("..info.tiles.." entries)") or "")
	say("art layers: %s   layerIndex used: %s (pin had %s)",
		tostring(info.layerCount), tostring(info.layerIndex), tostring(info.pinLayerIndex))
	say("explored tiles reported by the client: %s", tostring(info.exploredCount))
	say("exploration pins hooked: %s", tostring(info.hooked))
	-- If this is 0, every overlay the pin owns is invisible, Blizzard's
	-- explored ground included, and the map reads as unexplored.
	say("pin alpha: %s   waiting for load: %s",
		info.pinAlpha and string_format("%.2f", info.pinAlpha) or "?",
		tostring(info.pinWaiting))
	say("overlay textures we drew: %s", tostring(info.drawn))
	say("our tiles: %s drawn dimmed (unexplored), %s left to Blizzard (explored)",
		tostring(info.tilesDrawn), tostring(info.tilesSkipped))
	-- These are the ones 1.15.9 hides until you hover them.
	say("explored areas the game reveals only on hover: %s", tostring(info.mouseOverOnly))
	-- The pool is shared with Blizzard, so this is what is really drawn.
	-- These two should match. Overlay positions are absolute pixels in
	-- the pin, so a mismatch puts most of them off the visible map.
	say("pin size: %.0f x %.0f   canvas child: %.0f x %.0f",
		info.pinW or 0, info.pinH or 0, info.childW or 0, info.childH or 0)
	-- Blizzard's pool should contain only Blizzard's overlays, all
	-- untinted. Any tint in here is our colour leaking onto explored art.
	say("Blizzard's pool: %s active, %s shown, %s tinted, %s zero-sized",
		tostring(info.active), tostring(info.activeShown),
		tostring(info.tinted), tostring(info.zeroSized))
	say("our own textures: %s created, %s shown",
		tostring(info.ours), tostring(info.oursShown))
	if (info.samples) then
		for i = 1, #info.samples do
			say("  |cff88ccff%s|r", info.samples[i])
		end
	end
	say("reveal enabled: %s", tostring(info.enabled))

	local reason
	if (not info.enabled) then
		reason = "the reveal option is switched off"
	elseif (info.hooked == 0) then
		reason = "we never found an exploration pin to hook"
	elseif (not info.artID) then
		reason = "the client reports no art ID for this map"
	elseif (not info.haveData) then
		reason = "our tile data has no entry for art ID "..tostring(info.artID)
			.." -- the data was exported from build 1.13.2 and this art may have changed"
	elseif ((info.layerCount or 0) == 0) then
		reason = "the client reports no art layers for this map"
	elseif (info.drawn == 0) and ((info.tilesSkipped or 0) > 0) then
		-- Not a failure: the client already considers all of it explored.
		reason = nil
	elseif (info.drawn == 0) then
		reason = "we drew nothing despite having data; the refresh has not run for this map"
	end

	-- Side by side, so a key mismatch is visible rather than inferred.
	local MAX_KEYS = 6

	if (info.clientKeys) then
		if (#info.clientKeys == 0) then
			say("client explored keys: |cffff6666none|r -- the client says you have")
			say("  explored nothing on this map, so everything we draw is dimmed")
		else
			say("client explored keys (w:h:x:y), first %d of %d:",
				math.min(MAX_KEYS, #info.clientKeys), #info.clientKeys)
			for i = 1, math.min(MAX_KEYS, #info.clientKeys) do
				say("  |cff88ff88%s|r", info.clientKeys[i])
			end
		end
	end

	if (info.ourKeys) and (#info.ourKeys > 0) then
		say("our table keys, first %d of %d:", math.min(MAX_KEYS, #info.ourKeys), #info.ourKeys)
		for i = 1, math.min(MAX_KEYS, #info.ourKeys) do
			say("  |cffffcc66%s|r", info.ourKeys[i])
		end
	end

	if (reason) then
		say("fog stays because %s", reason)
	elseif ((info.drawn or 0) == 0) then
		say("nothing to reveal here -- the client says this whole map is explored")
	else
		say("reveal should be drawing")
	end
	Wayfarer:Print(yellow.."--- end of fog report ---|r")
end
