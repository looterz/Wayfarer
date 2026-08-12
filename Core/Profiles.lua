local AddonName, ns = ...

if (not ns.isSupportedClient) then
	return
end

local L = ns.L

-- The profile system: a shared Default profile
-- every character starts on, per-character profiles named "Name - Realm"
-- that only their owner sees in the picker, and management that cannot
-- leave the database in a state the stock AceDBOptions page could --
-- no dangling profile keys, no accidental empty profiles, and renames
-- that carry every character assignment along.
local Profiles = {}
ns.Profiles = Profiles

local EXPORT_HEADER = "Wayfarer:1"

local format = string.format
local ipairs = ipairs
local next = next
local pairs = pairs
local sort = table.sort
local tinsert = table.insert
local tonumber = tonumber
local tostring = tostring
local type = type

-- GLOBALS: GetRealmName, UnitName

local Copy
Copy = function(source)
	local target = {}
	for key, value in pairs(source) do
		target[key] = (type(value) == "table") and Copy(value) or value
	end
	return target
end

function Profiles:Defaults()
	return Copy(ns.defaults.profile)
end

local characterProfileName = function()
	return UnitName("player") .. " - " .. GetRealmName()
end

local trim = function(text)
	return text:match("^%s*(.-)%s*$")
end

-- True when nothing in the stored table differs from the defaults, which
-- is what a profile looks like when it was created by a stray click on
-- the old stock profiles page and never edited.
local matchesDefaults
matchesDefaults = function(data, defaults)
	if (type(data) ~= "table") then
		return data == defaults
	end
	if (type(defaults) ~= "table") then
		-- Runtime state like remembered floors has no default; an empty
		-- leftover table is still indistinguishable from untouched.
		return next(data) == nil
	end

	for key, value in pairs(data) do
		if (type(value) == "table") then
			if (not matchesDefaults(value, defaults[key])) then
				return false
			end
		elseif (value ~= defaults[key]) then
			return false
		end
	end

	return true
end

-- AceDB's DeleteProfile leaves other characters' assignments behind, and
-- a key pointing at a missing profile resurrects it empty on their next
-- login instead of falling back to Default.
local forgetProfileKeys = function(db, name)
	if (not db.sv.profileKeys) then
		return
	end

	for character, assigned in pairs(db.sv.profileKeys) do
		if (assigned == name) then
			db.sv.profileKeys[character] = nil
		end
	end
end

-- The stock profiles page offered class and realm names as one click
-- profile creators, so databases in the wild carry profiles like "Mage"
-- or "Whitemane" holding nothing. Anything indistinguishable from a
-- fresh profile is dropped, and characters parked on one go back to
-- Default. A profile holding any real setting is never touched.
function Profiles:Cleanup(db)
	local stored = db.sv and db.sv.profiles
	if (not stored) then
		return
	end

	local defaults = self:Defaults()

	if (db:GetCurrentProfile() ~= "Default") and (matchesDefaults(db.profile, defaults)) then
		db:SetProfile("Default")
	end

	local current = db:GetCurrentProfile()

	local names = {}
	for name in pairs(stored) do
		names[#names + 1] = name
	end

	for _, name in ipairs(names) do
		if (name ~= "Default") and (name ~= current) and (matchesDefaults(stored[name], defaults)) then
			db:DeleteProfile(name, true)
			forgetProfileKeys(db, name)
		end
	end
end

-- Export and import
----------------------------------------------------
-- The settings tree is scalars nested under section tables, so a profile
-- serializes as one "section.key=value" line per setting the defaults
-- know about. Runtime state without a default, like remembered floors,
-- stays out of exports on purpose.
local ListLeaves
ListLeaves = function(defaults, prefix, out)
	for key, value in pairs(defaults) do
		local path = prefix and (prefix .. "." .. key) or key
		if (type(value) == "table") then
			ListLeaves(value, path, out)
		else
			out[#out + 1] = path
		end
	end
	return out
end

local ResolvePath = function(root, path)
	local node, leaf = root, nil
	for step in path:gmatch("[^.]+") do
		if (leaf) then
			if (type(node[leaf]) ~= "table") then
				return nil
			end
			node = node[leaf]
		end
		leaf = step
	end
	return node, leaf
end

function Profiles:Export(profile)
	local lines = { EXPORT_HEADER }

	local paths = ListLeaves(ns.defaults.profile, nil, {})
	sort(paths)

	for _, path in ipairs(paths) do
		local node, leaf = ResolvePath(profile, path)
		local value = node and node[leaf]
		if (value == nil) then
			local defaultNode, defaultLeaf = ResolvePath(ns.defaults.profile, path)
			value = defaultNode[defaultLeaf]
		end
		lines[#lines + 1] = path .. "=" .. tostring(value)
	end

	return table.concat(lines, "\n")
end

-- Returns a full profile table built from defaults plus the export, or
-- nil and a reason. Unknown keys are skipped rather than rejected, so an
-- export from a newer version still loads what this one understands.
function Profiles:Import(text)
	if (type(text) ~= "string") then
		return nil, L["Nothing to import."]
	end

	local data = self:Defaults()
	local seenHeader = false

	for raw in text:gmatch("[^\r\n]+") do
		local line = trim(raw)
		if (line ~= "") then
			if (not seenHeader) then
				if (line ~= EXPORT_HEADER) then
					return nil, format(L["This is not a Wayfarer export. The first line should be %s."], EXPORT_HEADER)
				end
				seenHeader = true
			else
				local path, value = line:match("^([%w_.]+)%s*=%s*(.-)%s*$")
				if (not path) then
					return nil, format(L["Could not read this line: \"%s\""], line)
				end

				local defaultNode, defaultLeaf = ResolvePath(ns.defaults.profile, path)
				local default = defaultNode and defaultNode[defaultLeaf]

				if (default ~= nil) then
					local node, leaf = ResolvePath(data, path)
					if (type(default) == "boolean") then
						if (value ~= "true") and (value ~= "false") then
							return nil, format(L["%s must be true or false."], path)
						end
						node[leaf] = (value == "true")
					elseif (type(default) == "number") then
						local number = tonumber(value)
						if (not number) then
							return nil, format(L["%s must be a number."], path)
						end
						node[leaf] = number
					else
						node[leaf] = value
					end
				end
			end
		end
	end

	if (not seenHeader) then
		return nil, L["Nothing to import."]
	end

	return data
end

local ApplyImport = function(addon, data)
	local profile = addon.db.profile

	for _, path in ipairs(ListLeaves(ns.defaults.profile, nil, {})) do
		local from, fromLeaf = ResolvePath(data, path)
		local to, toLeaf = ResolvePath(profile, path)
		if (to) then
			to[toLeaf] = from[fromLeaf]
		end
	end

	addon:RefreshConfig()
	addon:Print(format(L["Settings imported into the %s profile."], addon.db:GetCurrentProfile()))
end

-- Management
----------------------------------------------------
-- Returns the trimmed name, or nil and a reason. Names in the character
-- key format are refused because the picker treats them as belonging to
-- a character, so a shared profile named that way would vanish from the
-- list.
function Profiles:ValidateName(db, value)
	local name = trim(value or "")

	if (name == "") then
		return nil, L["Give the profile a name."]
	end
	if (name:find(" - ", 1, true)) then
		return nil, L["Names containing \" - \" are reserved for character profiles."]
	end
	if (name == "Default") or ((db.sv.profiles or {})[name]) then
		return nil, format(L["A profile named %s already exists."], name)
	end

	return name
end

function Profiles:Create(db, name)
	db:SetProfile(name)
end

function Profiles:Duplicate(db, name)
	local source = db:GetCurrentProfile()
	db:SetProfile(name)
	db:CopyProfile(source, true)
end

-- AceDB has no rename, so this is switch, copy, delete. Other characters
-- assigned to the old name are pointed at the new one, because a
-- dangling key would otherwise resurrect the old profile empty on their
-- next login.
function Profiles:Rename(db, name)
	local old = db:GetCurrentProfile()

	db:SetProfile(name)
	db:CopyProfile(old, true)
	db:DeleteProfile(old, true)

	if (db.sv.profileKeys) then
		for character, assigned in pairs(db.sv.profileKeys) do
			if (assigned == old) then
				db.sv.profileKeys[character] = name
			end
		end
	end
end

local listSwitchable = function(db)
	local values = { Default = "Default" }
	local character = characterProfileName()
	local current = db:GetCurrentProfile()

	for _, name in ipairs(db:GetProfiles()) do
		local characterStyle = name:find(" - ", 1, true) ~= nil
		if (name == current) or (name == character) or (not characterStyle) then
			values[name] = name
		end
	end

	return values
end

local listDeletable = function(db)
	local values = {}
	local current = db:GetCurrentProfile()

	for _, name in ipairs(db:GetProfiles()) do
		if (name ~= current) and (name ~= "Default") then
			values[name] = name
		end
	end

	return values
end

-- Unlike the picker, this list includes other characters' profiles.
-- Reading from one is the whole point: it is how a character borrows the
-- setup of another that shares its needs.
local listCopyable = function(db)
	local values = {}
	local current = db:GetCurrentProfile()

	for _, name in ipairs(db:GetProfiles()) do
		if (name ~= current) then
			values[name] = name
		end
	end

	return values
end

function Profiles:BuildOptions(addon)
	return {
		type = "group",
		name = L["Profiles"],
		order = 100,
		args = {
			intro = {
				type = "description",
				order = 1,
				fontSize = "medium",
				name = L["Every character starts on the shared Default profile, so a change made there follows you everywhere. To give one character its own settings, branch: the new profile starts as a copy of what you have now and only shows up for that character."] .. "\n",
			},
			current = {
				type = "select",
				order = 2,
				name = L["Active profile"],
				desc = L["The profile this character reads its settings from."],
				values = function() return listSwitchable(addon.db) end,
				get = function() return addon.db:GetCurrentProfile() end,
				set = function(_, value) addon.db:SetProfile(value) end,
			},
			branch = {
				type = "execute",
				order = 3,
				name = function() return format(L["Branch for %s"], UnitName("player")) end,
				desc = function()
					local name = characterProfileName()
					if ((addon.db.sv.profiles or {})[name]) then
						return format(L["%s already exists. Pick it from the Active profile list."], name)
					end
					return format(L["Copies the active profile into %s and switches this character to it."], name)
				end,
				disabled = function()
					return (addon.db.sv.profiles or {})[characterProfileName()] ~= nil
				end,
				func = function()
					Profiles:Duplicate(addon.db, characterProfileName())
				end,
			},
			manage = {
				type = "group",
				inline = true,
				order = 5,
				name = L["Manage profiles"],
				args = {
					create = {
						type = "input",
						order = 1,
						name = L["New profile"],
						desc = L["Type a name and press Enter. The new profile starts from the defaults and this character switches to it."],
						get = function() return "" end,
						validate = function(_, value)
							local _, err = Profiles:ValidateName(addon.db, value)
							return err or true
						end,
						confirm = function(_, value)
							return format(L["Create the %s profile and switch to it?"], trim(value))
						end,
						set = function(_, value)
							local name = Profiles:ValidateName(addon.db, value)
							if (name) then
								Profiles:Create(addon.db, name)
							end
						end,
					},
					duplicate = {
						type = "input",
						order = 2,
						name = L["Duplicate profile"],
						desc = function()
							return format(L["Type a name and press Enter. Copies the %s profile into it and switches to the copy."], addon.db:GetCurrentProfile())
						end,
						get = function() return "" end,
						validate = function(_, value)
							local _, err = Profiles:ValidateName(addon.db, value)
							return err or true
						end,
						confirm = function(_, value)
							return format(L["Duplicate the %s profile into %s and switch to it?"], addon.db:GetCurrentProfile(), trim(value))
						end,
						set = function(_, value)
							local name = Profiles:ValidateName(addon.db, value)
							if (name) then
								Profiles:Duplicate(addon.db, name)
							end
						end,
					},
					rename = {
						type = "input",
						order = 3,
						name = L["Rename profile"],
						desc = function()
							if (addon.db:GetCurrentProfile() == "Default") then
								return L["The shared Default profile cannot be renamed."]
							end
							return format(L["Type a name and press Enter. Renames the %s profile, and characters using it follow the new name."], addon.db:GetCurrentProfile())
						end,
						disabled = function()
							return addon.db:GetCurrentProfile() == "Default"
						end,
						get = function() return "" end,
						validate = function(_, value)
							local _, err = Profiles:ValidateName(addon.db, value)
							return err or true
						end,
						confirm = function(_, value)
							return format(L["Rename the %s profile to %s?"], addon.db:GetCurrentProfile(), trim(value))
						end,
						set = function(_, value)
							local name = Profiles:ValidateName(addon.db, value)
							if (name) then
								Profiles:Rename(addon.db, name)
							end
						end,
					},
					copyFrom = {
						type = "select",
						order = 4,
						name = L["Copy settings from"],
						desc = L["Replaces everything in the active profile with the settings of the profile you pick, including other characters' profiles. The profile you copy from is not changed."],
						values = function() return listCopyable(addon.db) end,
						disabled = function() return next(listCopyable(addon.db)) == nil end,
						get = function() return nil end,
						confirm = function(_, value)
							return format(L["Replace everything in the %s profile with the settings from %s?"], addon.db:GetCurrentProfile(), value)
						end,
						set = function(_, value)
							addon.db:CopyProfile(value, true)
						end,
					},
					reset = {
						type = "execute",
						order = 5,
						name = L["Reset profile"],
						desc = L["Returns every setting in the active profile to the defaults."],
						confirm = function()
							return format(L["Reset the %s profile? Every setting in it goes back to the defaults."], addon.db:GetCurrentProfile())
						end,
						func = function() addon.db:ResetProfile() end,
					},
					delete = {
						type = "select",
						order = 6,
						name = L["Delete a profile"],
						desc = L["Removes a profile permanently. The active profile and Default are protected."],
						values = function() return listDeletable(addon.db) end,
						disabled = function() return next(listDeletable(addon.db)) == nil end,
						get = function() return nil end,
						confirm = function(_, value)
							return format(L["Delete the %s profile? There is no undo."], value)
						end,
						set = function(_, value)
							addon.db:DeleteProfile(value, true)
							forgetProfileKeys(addon.db, value)
						end,
					},
				},
			},
			transfer = {
				type = "group",
				inline = true,
				order = 10,
				name = L["Backup and sharing"],
				args = {
					about = {
						type = "description",
						order = 1,
						fontSize = "medium",
						name = L["Copy the export text somewhere safe to back up this profile, or paste an export below to load one. Importing replaces everything in the active profile."],
					},
					export = {
						type = "input",
						multiline = 8,
						width = "full",
						order = 2,
						name = L["Export"],
						desc = L["Select the text, then press Ctrl+C to copy it."],
						get = function() return Profiles:Export(addon.db.profile) end,
						set = function() end,
					},
					import = {
						type = "input",
						multiline = 8,
						width = "full",
						order = 3,
						name = L["Import"],
						desc = L["Paste a Wayfarer export, then press Accept."],
						get = function() return "" end,
						validate = function(_, value)
							local data, err = Profiles:Import(value)
							if (not data) then
								return err
							end
							return true
						end,
						confirm = function()
							return format(L["Replace everything in the %s profile with this import?"], addon.db:GetCurrentProfile())
						end,
						set = function(_, value)
							local data = Profiles:Import(value)
							if (data) then
								ApplyImport(addon, data)
							end
						end,
					},
				},
			},
		},
	}
end
