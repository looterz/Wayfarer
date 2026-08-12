local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon
local L = ns.L

-- Draws the overlay tiles for zone areas you haven't explored yet,
-- lifting the fog of war off the world map.
local MapReveal = Wayfarer:NewModule("MapReveal")

MapReveal.mapPriority = 50
MapReveal.settingsKey = "reveal"
MapReveal.optionsKey = "reveal"
MapReveal.optionsOrder = 50

-- GLOBALS: C_Map, C_MapExplorationInfo, WorldMapFrame, hooksecurefunc

local zoneReveal = ns.zoneReveal

local ipairs = ipairs
local math_ceil = math.ceil
local math_mod = math.fmod
local next = next
local pairs = pairs
local string_split = string.split
local table_insert = table.insert
local table_wipe = table.wipe
local tonumber = tonumber

-- Every texture we've handed out, so we can show and hide them
-- without rebuilding the whole set.
local overlayTextureCache = {}

-- Last run's tally, for /wayf fog: how many of our tiles the client
-- already considers explored (so we leave them to Blizzard, at full
-- colour) versus how many we drew dimmed.
local lastRun = { skipped = 0, drawn = 0, explored = 0 }

-- Which overlay tiles the player has genuinely explored.
local tileExists = {}

-- Pins we've already hooked, and their fog state.
local pins = {}

local DIMMED = .6

-- Defined further down, next to the explanation of why it exists.
local ShowMouseOverOverlays

-- Textures come back to the pool with our vertex color still on them.
-- We used to acquire our reveal textures from pin.overlayTexturePool,
-- the pin's own pool, and tint them. That is unfixable on 1.15.9:
--
--   CreateTexturePool = CreateSecureTexturePool
--
-- so the pool is a secure proxy and its reset callback lives on a private
-- backing object -- SecureObjectPoolMixin:Init stores self.resetFunc, and
-- the proxy exposes neither that nor the old resetterFunc. An addon
-- cannot override the reset, which means a texture we tinted goes back to
-- the pool still dimmed, Blizzard re-acquires it for an *explored*
-- overlay, and explored ground renders as unexplored.
--
-- So we own our textures outright. Blizzard's pool is never touched, and
-- nothing of ours can end up under an explored overlay.
local ourTextures = setmetatable({}, { __mode = "k" })

local GetRevealTexture = function(pin, index)
	local list = ourTextures[pin]

	if (not list) then
		list = {}
		ourTextures[pin] = list
	end

	local texture = list[index]

	if (not texture) then
		-- Sublevel -1 keeps us under Blizzard's explored overlays, which
		-- it draws at ARTWORK 0.
		texture = pin:CreateTexture(nil, "ARTWORK", nil, -1)
		list[index] = texture
	end

	return texture
end

local HideRevealTexturesFrom = function(pin, index)
	local list = ourTextures[pin]
	if (not list) then
		return
	end

	for i = index, #list do
		list[i]:Hide()
	end
end

-- Runs after the map's own RefreshOverlays. Anything in our tile data
-- that the player hasn't explored gets drawn in here.
-- Which art layer the pin is drawing. Blizzard only assigns pin.layerIndex
-- inside "if exploredMapTextures then" -- so on a map with nothing explored
-- it is never set, and on the map after that it is whatever the last map
-- left behind. Reading it blindly is why the fog stayed put: we bailed on
-- layers[nil] before drawing anything. Ask the canvas instead.
local GetLayerIndex = function(pin, uiMapID)
	local map = pin.GetMap and pin:GetMap()
	local container = map and map.GetCanvasContainer and map:GetCanvasContainer()
	local index = container and container.GetCurrentLayerIndex and container:GetCurrentLayerIndex()

	return index or pin.layerIndex or 1
end

local Overlay_RefreshTextures = function(pin, fullUpdate)
	pins[pin] = true

	-- A fullUpdate puts the pin at alpha 0 and leaves it there until
	--
	--   isWaitingForLoad and AreDetailLayersLoaded() and textureLoadGroup:IsFullyLoaded()
	--
	-- all come good in its OnUpdate. Every overlay the pin owns is
	-- invisible until then -- Blizzard's explored ground included, not
	-- just ours. AreDetailLayersLoaded() is false while any detail layer
	-- is still streaming, and we rescale the canvas underneath it, so
	-- that gate can stay shut. The result is a fully explored zone
	-- rendering as though none of it had been walked.
	--
	-- The fade is cosmetic. Drop the gate and show the overlays.
	if (pin.isWaitingForLoad) then
		pin.isWaitingForLoad = nil

		if (pin.textureLoadGroup) and (pin.textureLoadGroup.Reset) then
			pin.textureLoadGroup:Reset()
		end

		if (pin.RefreshAlpha) then
			pin:RefreshAlpha()
		else
			pin:SetAlpha(1)
		end
	end

	table_wipe(overlayTextureCache)
	table_wipe(tileExists)

	-- Hide everything up front rather than trimming at the end. The pin
	-- outlives the map, and every early return below is a map we have no
	-- data for -- a continent, the world map -- so trimming afterwards
	-- left the previous zone's reveal painted over the new one.
	HideRevealTexturesFrom(pin, 1)

	-- Index into our own texture list for this pass.
	local ourCount = 0

	-- The pin's own map, not the global one: they agree today, but the
	-- pin is the thing we are drawing into.
	local map = pin.GetMap and pin:GetMap()
	local uiMapID = (map and map.GetMapID and map:GetMapID()) or WorldMapFrame:GetMapID()
	if (not uiMapID) then
		return
	end

	local artID = C_Map.GetMapArtID(uiMapID)
	if (not artID) or (not zoneReveal[artID]) then
		return
	end

	local layers = C_Map.GetMapArtLayers(uiMapID)
	local layerInfo = layers and layers[GetLayerIndex(pin, uiMapID)]
	if (not layerInfo) then
		return
	end

	local zoneMaps = zoneReveal[artID]

	local exploredMapTextures = C_MapExplorationInfo.GetExploredMapTextures(uiMapID)
	if (exploredMapTextures) then
		for _, info in ipairs(exploredMapTextures) do
			tileExists[info.textureWidth..":"..info.textureHeight..":"..info.offsetX..":"..info.offsetY] = true
		end
	end

	lastRun.explored = exploredMapTextures and #exploredMapTextures or 0
	lastRun.skipped, lastRun.drawn = 0, 0

	lastRun.mouseOverOnly = 0
	if (exploredMapTextures) then
		for _, entry in ipairs(exploredMapTextures) do
			if (entry.isShownByMouseOver) then
				lastRun.mouseOverOnly = lastRun.mouseOverOnly + 1
			end
		end
	end

	ShowMouseOverOverlays(pin)

	local TILE_SIZE_WIDTH = layerInfo.tileWidth
	local TILE_SIZE_HEIGHT = layerInfo.tileHeight

	local db = MapReveal:GetSettings()
	local show = db.enable
	local vertex = db.dimLevel or DIMMED


	for key, files in pairs(zoneMaps) do
		if (tileExists[key]) then
			-- Already explored: Blizzard draws it at full colour, and
			-- leaving it alone is what makes explored ground look
			-- different from ground we filled in.
			lastRun.skipped = lastRun.skipped + 1
		else
			lastRun.drawn = lastRun.drawn + 1

			local width, height, offsetX, offsetY = string_split(":", key)
			local fileDataIDs = { string_split(",", files) }
			local numTexturesWide = math_ceil(width/TILE_SIZE_WIDTH)
			local numTexturesTall = math_ceil(height/TILE_SIZE_HEIGHT)
			local texturePixelWidth, textureFileWidth, texturePixelHeight, textureFileHeight

			for j = 1, numTexturesTall do
				if (j < numTexturesTall) then
					texturePixelHeight = TILE_SIZE_HEIGHT
					textureFileHeight = TILE_SIZE_HEIGHT
				else
					texturePixelHeight = math_mod(height, TILE_SIZE_HEIGHT)

					if (texturePixelHeight == 0) then
						texturePixelHeight = TILE_SIZE_HEIGHT
					end

					textureFileHeight = 16

					while (textureFileHeight < texturePixelHeight) do
						textureFileHeight = textureFileHeight * 2
					end
				end

				for k = 1, numTexturesWide do
					ourCount = ourCount + 1
					local texture = GetRevealTexture(pin, ourCount)

					if (k < numTexturesWide) then
						texturePixelWidth = TILE_SIZE_WIDTH
						textureFileWidth = TILE_SIZE_WIDTH
					else
						texturePixelWidth = math_mod(width, TILE_SIZE_WIDTH)

						if (texturePixelWidth == 0) then
							texturePixelWidth = TILE_SIZE_WIDTH
						end

						textureFileWidth = 16

						while (textureFileWidth < texturePixelWidth) do
							textureFileWidth = textureFileWidth * 2
						end
					end

					texture:SetSize(texturePixelWidth, texturePixelHeight)
					texture:SetTexCoord(0, texturePixelWidth/textureFileWidth, 0, texturePixelHeight/textureFileHeight)
					texture:SetPoint("TOPLEFT", offsetX + (TILE_SIZE_WIDTH * (k - 1)), -(offsetY + (TILE_SIZE_HEIGHT * (j - 1))))
					texture:SetTexture(tonumber(fileDataIDs[((j - 1) * numTexturesWide) + k]), nil, nil, "TRILINEAR")
					texture:SetDrawLayer("ARTWORK", -1)
					texture:SetVertexColor(vertex, vertex, vertex)

					-- Deliberately NOT added to pin.textureLoadGroup.
					-- That group gates the pin fading back in: while any
					-- texture in it reports not-loaded, IsFullyLoaded()
					-- stays false, isWaitingForLoad never clears, and the
					-- pin sits at alpha 0. Our file IDs came from a
					-- build 1.13.2 export, so one failing to resolve on
					-- this client would hide the whole pin for good.
					-- Blizzard's fade should only wait on Blizzard's own.
					texture:SetShown(show)

					table_insert(overlayTextureCache, texture)
				end
			end
		end
	end

end

-- Explored subareas that Blizzard only reveals on hover
----------------------------------------------------
-- 1.15.9 marks explored overlays with isShownByMouseOver. Those are built
-- hidden, behind a hit rect, and RefreshMouseOverOverlays then does:
--
--   highlightRect.texture:SetShown(highlightRect.index == highlightIndex)
--
-- every frame the cursor is over the map -- so an explored subarea shows
-- only while you happen to be pointing at it, and hovering one hides all
-- the others. That is the "highlighted correctly, but only a handful, and
-- only sometimes" behaviour, and it is new: this flag is why the map
-- changed with the UI update rather than anything in our data.
--
-- Blizzard's own hover behaviour is left intact when this is off.
ShowMouseOverOverlays = function(pin)
	if (not MapReveal:GetSettings().alwaysShowExplored) then
		return
	end

	if (not pin.highlightRectPool) or (not pin.highlightRectPool.EnumerateActive) then
		return
	end

	for highlightRect in pin.highlightRectPool:EnumerateActive() do
		if (highlightRect.texture) then
			highlightRect.texture:Show()
		end
	end
end

-- Module
----------------------------------------------------
-- The exploration pins are created by the map's data provider the
-- first time the map is shown, so we can't hook them all up front.
-- Our overlays are built by a hook on the pin's RefreshOverlays, so they
-- only appear the next time something asks the pin to refresh. On the
-- first map open the pin is created and refreshed during Blizzard's own
-- OnShow, which runs before ours -- so the hook lands too late and the
-- fog stays until something happens to refresh again. That is the
-- "open it a few times and it fixes itself" bug.
--
-- So: whenever a pin is newly hooked, ask it to refresh right away.
-- RefreshOverlays starts with RemoveAllData/ReleaseAll, so forcing one is
-- idempotent rather than additive.
function MapReveal:HookPins()
	local Canvas = self:GetCanvas()
	if (not Canvas) or (not Canvas.EnumeratePinsByTemplate) then
		return
	end

	for pin in Canvas:EnumeratePinsByTemplate("MapExplorationPinTemplate") do
		if (not pins[pin]) then
			pins[pin] = true
			hooksecurefunc(pin, "RefreshOverlays", Overlay_RefreshTextures)

			-- Earlier builds tinted textures borrowed from this pool, and
			-- a secure pool's reset cannot be overridden to undo it. Any
			-- still active are wearing our colour on explored ground, so
			-- put them back to white. We never borrow from it again, so
			-- this only ever has anything to do once.
			local pool = pin.overlayTexturePool
			if (pool) and (pool.EnumerateActive) then
				for texture in pool:EnumerateActive() do
					texture:SetVertexColor(1, 1, 1)
				end
			end

			-- Runs every frame the cursor is over the map, hiding every
			-- explored subarea except the one under the pointer.
			if (pin.RefreshMouseOverOverlays) then
				hooksecurefunc(pin, "RefreshMouseOverOverlays", ShowMouseOverOverlays)
			end

			-- Not a full update: that path zeroes the pin's alpha and
			-- waits on a load group which, on a map with nothing
			-- explored, never gets anything to wait for.
			--
			-- Contained: this runs Blizzard's refresh and then our hook,
			-- and a throw anywhere in that chain would otherwise abandon
			-- the rest of HookPins and, above it, every module that sets
			-- up after this one.
			if (pin.RefreshOverlays) then
				local ok, err = pcall(pin.RefreshOverlays, pin, false)
				if (not ok) then
					Wayfarer:Print("|cffff4444MapReveal|r could not refresh overlays: "..tostring(err))
				end
			end
		end
	end
end

-- Everything the reveal looked at on its last run, for /wayf fog.
function MapReveal:GetDebugInfo()
	local Canvas = self:GetCanvas()
	local uiMapID = Canvas and Canvas.GetMapID and Canvas:GetMapID()
	local info = {
		uiMapID = uiMapID,
		artID = uiMapID and C_Map.GetMapArtID(uiMapID),
		drawn = #overlayTextureCache,
		tilesDrawn = lastRun.drawn,
		tilesSkipped = lastRun.skipped,
		mouseOverOnly = lastRun.mouseOverOnly,
		enabled = self:GetSettings().enable,
		hooked = 0,
		pinAlpha = nil,
		pinWaiting = nil
	}

	for _ in next, pins do
		info.hooked = info.hooked + 1
	end

	if (info.artID) then
		local data = zoneReveal[info.artID]
		info.haveData = data and true or false

		if (data) then
			info.tiles = 0
			for _ in pairs(data) do
				info.tiles = info.tiles + 1
			end
		end
	end

	if (uiMapID) then
		local layers = C_Map.GetMapArtLayers(uiMapID)
		info.layerCount = layers and #layers or 0

		local explored = C_MapExplorationInfo.GetExploredMapTextures(uiMapID)
		info.exploredCount = explored and #explored or 0
	end

	for pin in next, pins do
		info.layerIndex = GetLayerIndex(pin, uiMapID)
		info.pinLayerIndex = pin.layerIndex
		info.pinAlpha = pin.GetAlpha and pin:GetAlpha()
		info.pinWaiting = pin.isWaitingForLoad and true or false

		-- Overlay offsets are absolute pixels inside this pin, so if the
		-- pin is not the size the map art expects, they land off it.
		info.pinW, info.pinH = pin:GetSize()

		local map = pin.GetMap and pin:GetMap()
		local child = map and map.ScrollContainer and map.ScrollContainer.Child
		if (child) then
			info.childW, info.childH = child:GetSize()
		end
		break
	end

	-- The client's explored overlays and our table entries, as the keys
	-- they are matched on. If these are the same ground described with
	-- different numbers, that is the whole bug and it shows up here.
	if (uiMapID) then
		info.clientKeys = {}
		local explored = C_MapExplorationInfo.GetExploredMapTextures(uiMapID)
		if (explored) then
			for _, entry in ipairs(explored) do
				info.clientKeys[#info.clientKeys + 1] = entry.textureWidth..":"..entry.textureHeight
					..":"..entry.offsetX..":"..entry.offsetY
					..(entry.isShownByMouseOver and " (mouseover)" or "")
			end
		end
	end

	info.ourKeys = {}
	if (info.artID) and (zoneReveal[info.artID]) then
		for key in pairs(zoneReveal[info.artID]) do
			info.ourKeys[#info.ourKeys + 1] = key
		end
		table.sort(info.ourKeys)
	end

	-- What is actually in the pin's overlay pool right now: how many
	-- textures exist, how many are shown, and whether any carry our tint.
	-- Blizzard's explored overlays and ours share this pool, so this is
	-- the only place that shows what is really on screen.
	info.active, info.activeShown, info.tinted, info.zeroSized = 0, 0, 0, 0
	info.ours, info.oursShown = 0, 0
	info.samples = {}

	for pin in next, pins do
		-- Blizzard's pool. Nothing of ours should be in here, and nothing
		-- in here should be tinted; a tint means contamination.
		local pool = pin.overlayTexturePool
		if (pool) and (pool.EnumerateActive) then
			for texture in pool:EnumerateActive() do
				info.active = info.active + 1

				local shown = texture:IsShown()
				if (shown) then
					info.activeShown = info.activeShown + 1
				end

				local w, h = texture:GetWidth(), texture:GetHeight()
				if ((w or 0) < 1) or ((h or 0) < 1) then
					info.zeroSized = info.zeroSized + 1
				end

				local r = texture:GetVertexColor()
				if (r) and (r < .99) then
					info.tinted = info.tinted + 1
				end

				if (#info.samples < 6) then
					info.samples[#info.samples + 1] = string.format(
						"%dx%d shown=%s alpha=%.2f tint=%.2f",
						w or 0, h or 0, tostring(shown), texture:GetAlpha() or 0, r or 0)
				end
			end
		end

		-- Ours, which Blizzard never sees.
		local list = ourTextures[pin]
		if (list) then
			for i = 1, #list do
				info.ours = info.ours + 1
				if (list[i]:IsShown()) then
					info.oursShown = info.oursShown + 1
				end
			end
		end

		break
	end

	return info
end

-- Cheap path: the textures already exist, just show or hide them.
function MapReveal:UpdateTextures()
	local db = self:GetSettings()
	local vertex = db.dimLevel or DIMMED

	-- Anything released back to the pool since we cached it is no longer
	-- ours to touch. Blizzard may have re-issued it for explored ground,
	-- and tinting that is what made the whole map read as unexplored.
	for i = 1, #overlayTextureCache do
		local texture = overlayTextureCache[i]

		texture:SetVertexColor(vertex, vertex, vertex)
		texture:SetShown(db.enable)
	end
end

-- Expensive path: rebuild every pin's overlays from scratch.
--
-- Goes through the pin's own RefreshOverlays rather than calling our hook
-- body directly. Ours only ever *acquires* textures from the pool; it is
-- the pin's RemoveAllData that releases them. Calling ours straight would
-- hand out a fresh set on top of the last one every time.
function MapReveal:RefreshPins()
	for pin in next, pins do
		if (pin.RefreshOverlays) then
			pin:RefreshOverlays(false)
		end
	end
end

function MapReveal:OnMapReady()
	local Canvas = self:GetCanvas()

	self:HookPins()

	-- New pins can appear the first few times the map is opened.
	self:SecureHookScript(Canvas, "OnShow", function()
		self:HookPins()
	end)

	-- Changing zone rebuilds the overlays for the new map. Catch it at
	-- the source rather than waiting for the map to be reopened.
	if (Canvas.OnMapChanged) and (not self:IsHooked(Canvas, "OnMapChanged")) then
		self:SecureHook(Canvas, "OnMapChanged", "OnMapChanged")
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshPins")

	-- Fires when the server tells us new ground has been explored, which
	-- also invalidates whatever we last drew.
	self:RegisterEvent("MAP_EXPLORATION_UPDATED", "OnMapChanged")
end

function MapReveal:OnMapChanged()
	self:HookPins()
	self:UpdateTextures()
end

function MapReveal:OnConfigChanged()
	self:HookPins()
	self:UpdateTextures()
end

function MapReveal:GetOptions()
	return {
		name = L["Fog of War"],
		args = {
			description = {
				order = 1,
				type = "description",
				name = L["Reveals the parts of each zone map you have not discovered yet."]
			},
			enable = {
				order = 10,
				type = "toggle", width = "full",
				name = L["Reveal unexplored areas"],
				desc = L["Draws the areas of the map you haven't explored yet, instead of leaving them blank."],
				get = ns.Getter("reveal", "enable"),
				set = ns.Setter("reveal", "enable")
			},
			alwaysShowExplored = {
				order = 15,
				type = "toggle", width = "full",
				name = L["Always show explored areas"],
				desc = L["Since 1.15.9 the game hides some explored subareas until you point at them, and pointing at one hides the rest. This keeps them all on screen so you can see everywhere you have been at a glance."],
				disabled = function() return not Wayfarer.db.profile.reveal.enable end,
				get = ns.Getter("reveal", "alwaysShowExplored"),
				set = ns.Setter("reveal", "alwaysShowExplored")
			},
			dimLevel = {
				order = 20,
				type = "range", width = "full",
				min = .3, max = 1, step = .05, isPercent = true,
				name = L["Unexplored brightness"],
				desc = L["How brightly the areas you have not explored are drawn. Anything below full makes them read as different from ground you have actually walked, which is the point of drawing them at all."],
				disabled = function() return not Wayfarer.db.profile.reveal.enable end,
				get = ns.Getter("reveal", "dimLevel"),
				set = ns.Setter("reveal", "dimLevel")
			}
		}
	}
end
