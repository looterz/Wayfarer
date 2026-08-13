local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local Wayfarer = ns.Addon
local L = ns.L

-- GLOBALS: InterfaceOptionsFrame_OpenToCategory, Settings, SlashCmdList
-- GLOBALS: SLASH_WAYFARER1, SLASH_WAYFARER2

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local ipairs = ipairs
local sort = table.sort
local tinsert = table.insert

local OPTIONS_KEY = AddonName.."_options"
local PROFILES_KEY = AddonName.."_profiles"

-- Collect the option group each module exposes.
-- A module without GetOptions simply has no settings of its own.
local BuildModuleOptions = function(args)
	local groups = {}

	for _, module in ipairs(Wayfarer.orderedModules) do
		if (module.GetOptions) then
			local group = module:GetOptions()
			if (group) then
				group.type = group.type or "group"
				group.name = group.name or module:GetName()
				tinsert(groups, {
					key = module.optionsKey or module:GetName():lower(),
					order = module.optionsOrder or 50,
					group = group
				})
			end
		end
	end

	sort(groups, function(a, b) return a.order < b.order end)

	for i, entry in ipairs(groups) do
		entry.group.order = i * 10
		args[entry.key] = entry.group
	end
end

ns.SetUpOptions = function(self)
	local options = {
		type = "group",
		name = L["Wayfarer"],
		args = {}
	}

	BuildModuleOptions(options.args)

	AceConfig:RegisterOptionsTable(OPTIONS_KEY, options)
	AceConfigDialog:SetDefaultSize(OPTIONS_KEY, 620, 520)

	-- Under Addon Options, with Profiles as its own child panel.
	ns.optionsCategory = AceConfigDialog:AddToBlizOptions(OPTIONS_KEY, L["Wayfarer"])

	AceConfig:RegisterOptionsTable(PROFILES_KEY, ns.Profiles:BuildOptions(Wayfarer))
	ns.profilesCategory = AceConfigDialog:AddToBlizOptions(PROFILES_KEY, L["Profiles"], L["Wayfarer"])

	AceConfigRegistry:NotifyChange(OPTIONS_KEY)
end

-- Open our panel in whichever settings UI this client has.
ns.OpenOptions = function()
	local category = ns.optionsCategory

	if (Settings and Settings.OpenToCategory) then
		local id = category and (category.GetID and category:GetID() or category.ID)
		if (id) then
			Settings.OpenToCategory(id)
			return
		end
		Settings.OpenToCategory(L["Wayfarer"])
		return
	end

	if (InterfaceOptionsFrame_OpenToCategory) and (category) then
		-- Older clients need this twice; the first call only expands
		-- the addon list, the second actually selects the panel.
		InterfaceOptionsFrame_OpenToCategory(category)
		InterfaceOptionsFrame_OpenToCategory(category)
		return
	end

	AceConfigDialog:Open(OPTIONS_KEY)
end

SLASH_WAYFARER1 = "/wayfarer"
SLASH_WAYFARER2 = "/wayf"
SlashCmdList["WAYFARER"] = function(input)
	input = input and input:trim():lower() or ""

	if (input == "") then
		ns.OpenOptions()
		return
	end

	if (input == "config") then
		LibStub("AceConfigDialog-3.0"):Open(OPTIONS_KEY)
		return
	end

	if (input == "profiles") then
		LibStub("AceConfigDialog-3.0"):Open(PROFILES_KEY)
		return
	end

	if (input == "reset") then
		Wayfarer.db:ResetProfile()
		Wayfarer:Print(L["Settings have been reset to their defaults."])
		return
	end

	if (input == "probe") then
		ns.Probe()
		return
	end

	if (input == "dev") then
		local Developer = Wayfarer:GetModule("Developer", true)
		if (Developer) then
			Developer:Toggle()
		end
		return
	end

	if (input == "frames") then
		ns.FrameReport()
		return
	end

	if (input == "tree") then
		ns.FrameTree()
		return
	end

	if (input == "pick") then
		ns.PickerReport()
		return
	end

	if (input == "fog") then
		ns.FogReport()
		return
	end

	Wayfarer:Print(L["Usage:"])
	Wayfarer:Print("  /wayf             - "..L["Open the settings window."])
	Wayfarer:Print("  /wayf config      - "..L["Open the settings in a standalone window."])
	Wayfarer:Print("  /wayf profiles    - "..L["Manage settings profiles."])
	Wayfarer:Print("  /wayf reset       - "..L["Reset the current profile."])
	Wayfarer:Print("  /wayf probe       - "..L["Report what the client knows about your position."])
	Wayfarer:Print("  /wayf frames      - "..L["Report where the map frame and its pieces sit."])
	Wayfarer:Print("  /wayf tree        - "..L["List every named frame on the world map."])
	Wayfarer:Print("  /wayf pick        - "..L["Force the instance picker open and describe it."])
	Wayfarer:Print("  /wayf fog         - "..L["Report why the fog of war is or is not lifted."])
	Wayfarer:Print("  /wayf dev         - "..L["Toggle developer mode: drag, add, rename and delete map pins."])
end
