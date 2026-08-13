local _, ns = ...

-- Dungeon map data.
--
-- The maps themselves are the client's own dungeon art, addressed as
-- Interface\\Worldmap\\<Dungeon>\\<Dungeon><floor>_<tile> across a 4x3
-- grid of 256px tiles. Nothing is shipped with the addon.
--
-- Keyed by instanceMapID (the eighth return of GetInstanceInfo), not by
-- name, so it works in every locale.
--
--   dungeonByMapID          instanceMapID -> texture folder
--   subzoneToFloor          subzone name (no spaces) -> { folder, floor }
--   specialDungeons         folders whose textures break the naming rule
--   defaultFloor            folder -> floor to open on
--   dungeonFloors           folder -> list of valid floor numbers
--   floorLabels             folder -> short per-floor labels
--   floorNames              folder -> readable per-floor names
--   questieAreaByInstance   instanceMapID -> Questie areaID
--   dungeonPortals          uiMapID -> entrances { x, y, name, floor }
--   npcPositions            areaID -> [npcID] = { x, y }
--   dungeonBosses           instanceMapID -> { atlasModule, bosses }
--                           boss = { name, x, y, floor, atlasKey, atlasIndex }
--   dungeonStairs           instanceMapID -> [from][to] = { x, y }
--
-- Coordinates are percentages of the 1024x768 map, matching the client's
-- own dungeon map space.


-- Map ID -> texture folder name
ns.dungeonByMapID = {
	-- Vanilla
	[389] = "Ragefire",
	[43]  = "WailingCaverns",
	[36]  = "TheDeadmines",
	[33]  = "ShadowfangKeep",
	[48]  = "BlackfathomDeeps",
	[34]  = "TheStockade",
	[90]  = "Gnomeregan",
	[47]  = "RazorfenKraul",
	[189] = "ScarletMonastery",
	[129] = "RazorfenDowns",
	[70]  = "Uldaman",
	[209] = "ZulFarrak",
	[349] = "Maraudon",
	[109] = "TheTempleofAtalhakkar",
	[230] = "BlackrockDepths",
	[229] = "BlackrockSpire",
	[429] = "Diremaul",
	[329] = "Stratholme",
	[289] = "Scholomance",
	-- Vanilla Raids
	[409] = "MoltenCore",
	[249] = "OnyxiasLair",
	[469] = "BlackwingLair",
	[309] = "ZulGurub",
	[509] = "RuinsofAhnQiraj",
	[531] = "AhnQiraj",
	[533] = "Naxxramas",
	-- TBC Raids
	[532] = "Karazhan",
	[565] = "GruulsLair",
	[544] = "MagtheridonsLair",
	[548] = "CoilfangReservoir",
	[550] = "TempestKeep",
	[534] = "CoTMountHyjal",
	[564] = "BlackTemple",
	[580] = "SunwellPlateau",
	[568] = "ZulAman",
	-- TBC
	[543] = "HellfireRamparts",
	[542] = "TheBloodFurnace",
	[540] = "TheShatteredHalls",
	[547] = "TheSlavePens",
	[546] = "TheUnderbog",
	[545] = "TheSteamvault",
	[557] = "ManaTombs",
	[558] = "AuchenaiCrypts",
	[556] = "SethekkHalls",
	[555] = "ShadowLabyrinth",
	[554] = "TheMechanar",
	[553] = "TheBotanica",
	[552] = "TheArcatraz",
	[560] = "CoTHillsbradFoothills",
	[269] = "CoTTheBlackMorass",
	[585] = "MagistersTerrace",
}

-- The client's own LFG artwork gives most instances a dedicated icon.
-- Wings of one complex share their complex's icon; anything without an
-- entry falls back to the generic map icon at the call site.
local LFG_ICON = "Interface\\LFGFrame\\LFGIcon-"

ns.dungeonIcons = {
	Ragefire = LFG_ICON.."RagefireChasm",
	WailingCaverns = LFG_ICON.."WailingCaverns",
	TheDeadmines = LFG_ICON.."Deadmines",
	ShadowfangKeep = LFG_ICON.."ShadowfangKeep",
	BlackfathomDeeps = LFG_ICON.."BlackfathomDeeps",
	TheStockade = LFG_ICON.."StormwindStockades",
	Gnomeregan = LFG_ICON.."Gnomeregan",
	RazorfenKraul = LFG_ICON.."RazorfenKraul",
	ScarletMonastery = LFG_ICON.."ScarletMonastery",
	RazorfenDowns = LFG_ICON.."RazorfenDowns",
	Uldaman = LFG_ICON.."Uldaman",
	ZulFarrak = LFG_ICON.."ZulFarak",
	Maraudon = LFG_ICON.."Maraudon",
	TheTempleofAtalhakkar = LFG_ICON.."SunkenTemple",
	BlackrockDepths = LFG_ICON.."BlackrockDepths",
	BlackrockSpire = LFG_ICON.."BlackrockSpire",
	Diremaul = LFG_ICON.."DireMaul",
	Stratholme = LFG_ICON.."Stratholme",
	Scholomance = LFG_ICON.."Scholomance",
	MoltenCore = LFG_ICON.."MoltenCore",
	BlackwingLair = LFG_ICON.."BlackwingLair",
	ZulGurub = LFG_ICON.."ZulGurub",
	RuinsofAhnQiraj = LFG_ICON.."AQRuins",
	AhnQiraj = LFG_ICON.."AQTemple",
	Naxxramas = LFG_ICON.."Naxxramas",
	-- No LFG artwork exists for Onyxia; her head is the classic stand-in.
	OnyxiasLair = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
	Karazhan = LFG_ICON.."Karazhan",
	GruulsLair = LFG_ICON.."GruulsLair",
	MagtheridonsLair = LFG_ICON.."HellfireCitadelRaid",
	CoilfangReservoir = LFG_ICON.."SerpentshrineCavern",
	TempestKeep = LFG_ICON.."TempestKeep",
	CoTMountHyjal = LFG_ICON.."HyjalPast",
	BlackTemple = LFG_ICON.."BlackTemple",
	SunwellPlateau = LFG_ICON.."Sunwell",
	ZulAman = LFG_ICON.."ZulAman",
	HellfireRamparts = LFG_ICON.."HellfireCitadel5Man",
	TheBloodFurnace = LFG_ICON.."HellfireCitadel5Man",
	TheShatteredHalls = LFG_ICON.."HellfireCitadel5Man",
	TheSlavePens = LFG_ICON.."Coilfang",
	TheUnderbog = LFG_ICON.."Coilfang",
	TheSteamvault = LFG_ICON.."Coilfang",
	ManaTombs = LFG_ICON.."Auchindoun",
	AuchenaiCrypts = LFG_ICON.."Auchindoun",
	SethekkHalls = LFG_ICON.."Auchindoun",
	ShadowLabyrinth = LFG_ICON.."Auchindoun",
	TheMechanar = LFG_ICON.."TempestKeep",
	TheBotanica = LFG_ICON.."TempestKeep",
	TheArcatraz = LFG_ICON.."TempestKeep",
	CoTHillsbradFoothills = LFG_ICON.."CavernsOfTime",
	CoTTheBlackMorass = LFG_ICON.."CavernsOfTime",
	MagistersTerrace = LFG_ICON.."MagistersTerrace",
}

-- Returns a texture path only when the running client actually ships
-- the file, so a missing icon degrades to the caller's fallback.
local iconChecked = {}

ns.GetDungeonIcon = function(folder)
	local icon = folder and ns.dungeonIcons[folder]
	if (not icon) then
		return nil
	end
	if (type(GetFileIDFromPath) == "function") then
		if (iconChecked[icon] == nil) then
			iconChecked[icon] = GetFileIDFromPath(icon) ~= nil
		end
		if (not iconChecked[icon]) then
			return nil
		end
	end
	return icon
end

-- Folder names double as display names by splitting CamelCase, which
-- mangles the ones with lowercase words, apostrophes or acronyms.
ns.dungeonDisplayNames = {
	Ragefire = "Ragefire Chasm",
	Diremaul = "Dire Maul",
	TheTempleofAtalhakkar = "The Temple of Atal'Hakkar",
	ZulFarrak = "Zul'Farrak",
	ZulGurub = "Zul'Gurub",
	ZulAman = "Zul'Aman",
	AhnQiraj = "Ahn'Qiraj",
	RuinsofAhnQiraj = "Ruins of Ahn'Qiraj",
	OnyxiasLair = "Onyxia's Lair",
	GruulsLair = "Gruul's Lair",
	MagtheridonsLair = "Magtheridon's Lair",
	CoilfangReservoir = "Serpentshrine Cavern",
	CoTHillsbradFoothills = "Old Hillsbrad Foothills",
	CoTTheBlackMorass = "The Black Morass",
	CoTMountHyjal = "Hyjal Summit",
	ManaTombs = "Mana-Tombs",
	MagistersTerrace = "Magisters' Terrace",
}

ns.PrettyDungeonName = function(folder)
	if (not folder) then
		return ""
	end
	return ns.dungeonDisplayNames[folder] or (string.gsub(folder, "(%l)(%u)", "%1 %2"))
end

-- Recommended level ranges, shown on the entrance pin tooltips in the
-- same difficulty colours the zone names use.
ns.dungeonLevels = {
	-- Vanilla dungeons
	[389] = { 13, 18 },  -- Ragefire Chasm
	[43]  = { 15, 25 },  -- Wailing Caverns
	[36]  = { 18, 23 },  -- The Deadmines
	[33]  = { 22, 30 },  -- Shadowfang Keep
	[48]  = { 24, 32 },  -- Blackfathom Deeps
	[34]  = { 24, 32 },  -- The Stockade
	[90]  = { 29, 38 },  -- Gnomeregan
	[47]  = { 30, 40 },  -- Razorfen Kraul
	[189] = { 26, 45 },  -- Scarlet Monastery
	[129] = { 40, 50 },  -- Razorfen Downs
	[70]  = { 42, 52 },  -- Uldaman
	[209] = { 44, 54 },  -- Zul'Farrak
	[349] = { 46, 55 },  -- Maraudon
	[109] = { 50, 60 },  -- The Temple of Atal'Hakkar
	[230] = { 52, 60 },  -- Blackrock Depths
	[229] = { 55, 60 },  -- Blackrock Spire
	[429] = { 55, 60 },  -- Dire Maul
	[329] = { 58, 60 },  -- Stratholme
	[289] = { 58, 60 },  -- Scholomance
	-- Vanilla raids
	[409] = { 60, 60 }, [249] = { 60, 60 }, [469] = { 60, 60 },
	[309] = { 60, 60 }, [509] = { 60, 60 }, [531] = { 60, 60 },
	[533] = { 60, 60 },
	-- TBC dungeons
	[543] = { 60, 62 },  -- Hellfire Ramparts
	[542] = { 61, 63 },  -- The Blood Furnace
	[547] = { 62, 64 },  -- The Slave Pens
	[546] = { 63, 65 },  -- The Underbog
	[557] = { 64, 66 },  -- Mana-Tombs
	[558] = { 65, 67 },  -- Auchenai Crypts
	[560] = { 66, 68 },  -- Old Hillsbrad Foothills
	[556] = { 67, 69 },  -- Sethekk Halls
	[545] = { 68, 70 },  -- The Steamvault
	[555] = { 69, 70 },  -- Shadow Labyrinth
	[540] = { 69, 70 },  -- The Shattered Halls
	[554] = { 69, 70 },  -- The Mechanar
	[553] = { 70, 70 },  -- The Botanica
	[552] = { 70, 70 },  -- The Arcatraz
	[269] = { 70, 70 },  -- The Black Morass
	[585] = { 70, 70 },  -- Magisters' Terrace
	-- TBC raids
	[532] = { 70, 70 }, [565] = { 70, 70 }, [544] = { 70, 70 },
	[548] = { 70, 70 }, [550] = { 70, 70 }, [534] = { 70, 70 },
	[564] = { 70, 70 }, [568] = { 70, 70 }, [580] = { 70, 70 },
}

-- The instances above that only exist on The Burning Crusade client.
-- Core.lua strips them from the tables on Classic Era.
ns.tbcInstances = {
	-- Raids
	[532] = true, [565] = true, [544] = true, [548] = true, [550] = true,
	[534] = true, [564] = true, [580] = true, [568] = true,
	-- Dungeons
	[543] = true, [542] = true, [540] = true, [547] = true, [546] = true,
	[545] = true, [557] = true, [558] = true, [556] = true, [555] = true,
	[554] = true, [553] = true, [552] = true, [560] = true, [269] = true,
	[585] = true,
}

-- Subzone name (no spaces) -> { dungeon folder, floor number }
ns.subzoneToFloor = {
	-- Scarlet Monastery: one instance ID, four wings. Subzone names pick
	-- the wing because Classic Era does not report player coordinates
	-- inside an instance.
	["Graveyard"]                = { "ScarletMonastery", 1 },
	["TheGraveyard"]             = { "ScarletMonastery", 1 },
	["ForlornCloister"]          = { "ScarletMonastery", 1 },
	["ChapelGardens"]            = { "ScarletMonastery", 1 },
	["Library"]                  = { "ScarletMonastery", 2 },
	["TheLibrary"]               = { "ScarletMonastery", 2 },
	["Armory"]                   = { "ScarletMonastery", 3 },
	["TheArmory"]                = { "ScarletMonastery", 3 },
	["Cathedral"]                = { "ScarletMonastery", 4 },
	["TheCathedral"]             = { "ScarletMonastery", 4 },
	["CathedralofBloodDominion"] = { "ScarletMonastery", 4 },

	-- Gnomeregan (4 floors)
	["TheClockwerkRun"]  = { "Gnomeregan", 1 },
	["TheCleanZone"]	 = { "Gnomeregan", 1 },
	["TheHallofGears"]   = { "Gnomeregan", 2 },
	["TheDormitory"]	 = { "Gnomeregan", 2 },
	["EngineeringLabs"]  = { "Gnomeregan", 3 },
	["LaunchBay"]		= { "Gnomeregan", 3 },
	["Tinkers'Court"]	= { "Gnomeregan", 4 },

	-- Blackfathom Deeps (3 floors)
	["BlackfathomDeeps"]  = { "BlackfathomDeeps", 1 },
	["MoonshrineRuins"]   = { "BlackfathomDeeps", 2 },
	["TheForgottenPool"]  = { "BlackfathomDeeps", 3 },

	-- Maraudon
	["EarthSongFalls"]  = { "Maraudon", 2 },
	["Zaetar'sGrave"]   = { "Maraudon", 2 },

	-- Blackrock Depths (2 floors)
	["DetentionBlock"]   = { "BlackrockDepths", 1 },
	["HallofCrafting"]   = { "BlackrockDepths", 1 },
	["DarkIronHighway"]  = { "BlackrockDepths", 1 },
	["TheDomicile"]	  = { "BlackrockDepths", 2 },
	["EastGarrison"]	 = { "BlackrockDepths", 2 },
	["RingoftheLaw"]	 = { "BlackrockDepths", 2 },
	["TheManufactory"]   = { "BlackrockDepths", 2 },
	["TheGrimGuzzler"]   = { "BlackrockDepths", 2 },
	["TheLyceum"]		= { "BlackrockDepths", 2 },

	-- Blackrock Spire (LBRS floors)
	["Tazz'Alaor"]		 = { "BlackrockSpire", 1 },
	["SkitterwebTunnels"]  = { "BlackrockSpire", 1 },
	["HordemarCity"]	   = { "BlackrockSpire", 3 },
	["ChamberofBattle"]	= { "BlackrockSpire", 6 },
	["HallofBlackhand"]	= { "BlackrockSpire", 7 },
	["BlackrockStadium"]   = { "BlackrockSpire", 7 },
	["SpireThrone"]		= { "BlackrockSpire", 7 },

	-- Upper Blackrock Spire
	["HallofBinding"]  = { "BlackrockSpire", 2 },
	["TheRookery"]	 = { "BlackrockSpire", 2 },

	-- Diremaul
	["WarpwoodQuarter"]	 = { "Diremaul", 5 },
	["TheConservatory"]	 = { "Diremaul", 6 },
	["CapitalGardens"]	  = { "Diremaul", 2 },
	["PrisonofImmol'thar"]  = { "Diremaul", 4 },

	-- Scholomance (4 floors)
	["TheReliquary"]		= { "Scholomance", 1 },
	["ChamberofSummoning"]  = { "Scholomance", 2 },
	["TheGreatOssuary"]	 = { "Scholomance", 2 },
	["TheViewingRoom"]	  = { "Scholomance", 2 },
	["Headmaster'sStudy"]   = { "Scholomance", 4 },

	-- Stratholme
	["Elders'Square"]	= { "Stratholme", 2 },
	["TheGauntlet"]	  = { "Stratholme", 2 },
	["SlaughterSquare"]  = { "Stratholme", 2 },
}

-- Dungeons with special texture path handling
ns.specialDungeons = {
	-- No floor prefix in texture name (e.g. ZulFarrak1.blp instead of ZulFarrak1_1.blp)
	["ZulFarrak"] = "no_floor_prefix",
	["ZulGurub"] = "no_floor_prefix",
	["RuinsofAhnQiraj"] = "no_floor_prefix",
	["CoTHillsbradFoothills"] = "no_floor_prefix",
	["CoTTheBlackMorass"] = "no_floor_prefix",
	["CoTMountHyjal"] = "no_floor_prefix",
	["ZulAman"] = "no_floor_prefix",
	-- ScarletMonastery: wing detected by player coordinates, not subzone
	["ScarletMonastery"] = "coordinate_detection",
}

-- Default floor when entering a dungeon (if not floor 1)
ns.defaultFloor = {
	["BlackrockSpire"] = 7,
}

-- Available floors for multi-floor dungeons (from /sdm probefloors)
ns.dungeonFloors = {
	-- Vanilla
	["TheDeadmines"]	 = {1, 2},
	["ShadowfangKeep"]   = {1, 2, 3, 4, 5, 6, 7},
	["BlackfathomDeeps"] = {1, 2, 3},
	["Gnomeregan"]	   = {1, 2, 3, 4},
	["Uldaman"]		  = {1, 2, 18}, -- page 18 = texture séparée (entrée ?), à identifier in-game
	["Maraudon"]		 = {1, 2},
	["BlackrockDepths"]  = {1, 2},
	["BlackrockSpire"]   = {1, 2, 3, 4, 5, 6, 7},
	["Diremaul"]		 = {1, 2, 3, 4, 5, 6},
	["Scholomance"]	  = {1, 2, 3, 4},
	["Stratholme"]	   = {1, 2},
	["ScarletMonastery"] = {1, 2, 3, 4},
	-- TBC
	["AuchenaiCrypts"]   = {1, 2},
	["SethekkHalls"]	 = {1, 2},
	["TheMechanar"]	  = {1, 2},
	["TheArcatraz"]	  = {1, 2, 3},
	["TheSteamvault"]	= {1, 2},
	["MagistersTerrace"] = {1, 2},
	-- Vanilla Raids
	["BlackwingLair"]	= {1, 2, 3, 4},
	["AhnQiraj"]		 = {1, 2, 3},
	["Naxxramas"]		= {1, 2, 3, 4, 5, 6},
	-- TBC Raids
	["Karazhan"]		 = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17},
	["BlackTemple"]	  = {1, 2, 3, 4, 5, 6, 7},
}

-- Short labels for floor buttons (nil = use floor number)
ns.floorLabels = {
	["ScarletMonastery"] = { "GY", "Lib", "Arm", "Cath" },
	["Stratholme"]	   = { "Liv", "UD" },
	-- Vanilla Raids
	["Naxxramas"]		= { "Arach", "Plag", "Mil", "Cons", "Frost", "KT" },
}

-- Tooltip names for floors
ns.floorNames = {
	-- Vanilla
	["ScarletMonastery"] = { "Graveyard", "Library", "Armory", "Cathedral" },
	["Diremaul"]		 = { "North", "East (Gardens)", "Floor 3", "East (Prison)", "West (Warpwood)", "West (Conservatory)" },
	["Stratholme"]	   = { "Living Side", "Undead Side" },
	["Gnomeregan"]	   = { "Clockwerk Run", "Hall of Gears", "Engineering Labs", "Tinkers' Court" },
	["BlackfathomDeeps"] = { "Deeps", "Moonshrine Ruins", "Forgotten Pool" },
	["Scholomance"]	  = { "Reliquary", "Chamber of Summoning", "Floor 3", "Headmaster's Study" },
	["BlackrockDepths"]  = { "Detention Block", "Domicile" },
	["BlackrockSpire"]   = { "Tazz'Alaor (Lower)", "The Rookery (Upper)", "Hordemar City (Lower)", "Halycon's Lair (Lower)", "Dragonspire Hall (Upper)", "Chamber of Battle (Lower)", "Hall of Blackhand (Upper)" },
	-- TBC
	["TheArcatraz"]	  = { "Stasis Block", "Restraining Grounds", "Top" },
	-- Vanilla Raids
	["BlackwingLair"]	= { "Razorgore", "Vaelastrasz", "Chromaggus", "Nefarian" },
	["AhnQiraj"]		 = { "Temple Entrance", "Twin Emperors", "C'Thun" },
	["Naxxramas"]		= { "Arachnid Quarter", "Plague Quarter", "Military Quarter", "Construct Quarter", "Frostwyrm Lair", "Kel'Thuzad" },
	-- TBC Raids
	["Karazhan"]		 = { "Servant Quarters", "Upper Livery", "The Guest Chambers", "The Opera House", "The Menagerie", "Gamesman's Hall", "Guardian's Library", "Netherspace", "Floor 9", "Floor 10", "Floor 11", "Floor 12", "Floor 13", "Floor 14", "Floor 15", "Floor 16", "Floor 17" },
	["BlackTemple"]	  = { "Karabor Sewers", "Sanctuary of Shadows", "Halls of Anguish", "Gorefiend's Vigil", "Den of Mortal Delights", "Chamber of Command", "Temple Summit" },
}

-- instanceMapID -> Questie areaID (for reading quest pins from Questie)
ns.questieAreaByInstance = {
	-- Vanilla
	[389] = 2437,  -- Ragefire Chasm
	[43]  = 718,   -- Wailing Caverns
	[36]  = 1581,  -- The Deadmines
	[33]  = 209,   -- Shadowfang Keep
	[48]  = 719,   -- Blackfathom Deeps
	[34]  = 717,   -- The Stockade
	[90]  = 721,   -- Gnomeregan
	[47]  = 491,   -- Razorfen Kraul
	[189] = 796,   -- Scarlet Monastery
	[129] = 722,   -- Razorfen Downs
	[70]  = 1337,  -- Uldaman
	[209] = 1176,  -- Zul'Farrak
	[349] = 2100,  -- Maraudon
	[109] = 1477,  -- Temple of Atal'Hakkar
	[230] = 1584,  -- Blackrock Depths
	[229] = 1583,  -- Blackrock Spire
	[429] = 2557,  -- Dire Maul
	[329] = 2017,  -- Stratholme
	[289] = 2057,  -- Scholomance
	-- TBC
	[543] = 3562,  -- Hellfire Ramparts
	[542] = 3713,  -- The Blood Furnace
	[540] = 3714,  -- The Shattered Halls
	[547] = 3717,  -- The Slave Pens
	[546] = 3716,  -- The Underbog
	[545] = 3715,  -- The Steamvault
	[557] = 3792,  -- Mana-Tombs
	[558] = 3790,  -- Auchenai Crypts
	[556] = 3791,  -- Sethekk Halls
	[555] = 3789,  -- Shadow Labyrinth
	[554] = 3849,  -- The Mechanar
	[553] = 3847,  -- The Botanica
	[552] = 3848,  -- The Arcatraz
	[560] = 2367,  -- Old Hillsbrad Foothills
	[269] = 2366,  -- The Black Morass
	[585] = 4131,  -- Magisters' Terrace
	-- Vanilla Raids
	[409] = 2717,  -- Molten Core
	[249] = 2159,  -- Onyxia's Lair
	[469] = 2677,  -- Blackwing Lair
	[309] = 1977,  -- Zul'Gurub
	[509] = 3429,  -- Ruins of Ahn'Qiraj
	[531] = 3428,  -- Temple of Ahn'Qiraj
	[533] = 3456,  -- Naxxramas
	-- TBC Raids
	[532] = 3457,  -- Karazhan
	[565] = 3923,  -- Gruul's Lair
	[544] = 3836,  -- Magtheridon's Lair
	[548] = 3607,  -- Serpentshrine Cavern
	[550] = 3845,  -- Tempest Keep (The Eye)
	[534] = 3606,  -- Hyjal Summit
	[564] = 3959,  -- Black Temple
	[580] = 4075,  -- Sunwell Plateau
	[568] = 3805,  -- Zul'Aman
}

-- World map zone -> dungeon portal positions (coordinates in percent, from Leatrix_Maps)
-- Used to hook blue portal pins on the world map for click-to-preview
ns.dungeonPortals = {
	-- Eastern Kingdoms
	[1418] = {{ x=44.6, y=12.1, name="Uldaman", floor=1 }},
	[1420] = {
		{ x=85, y=32.7, name="ScarletMonastery", floor=1 },
	},
	[1421] = {
		{ x=43.1, y=67.5, name="ShadowfangKeep", floor=1 },
	},
	[1422] = {{ x=69.7, y=73.2, name="Scholomance", floor=1 }},
	[1423] = {
		{ x=31.1, y=15.6, name="Stratholme", floor=1 },
		{ x=48.1, y=23.7, name="Stratholme", floor=2 },
		{ x=38.8, y=25.9, name="Naxxramas", floor=1 },
	},
	[1426] = {{ x=24.3, y=39.8, name="Gnomeregan", floor=1 }},
	[1427] = {
		{ x=39.1, y=85.5, name="MoltenCore", floor=1 },
		{ x=30.3, y=85.4, name="BlackwingLair", floor=1 },
		{ x=34.8, y=79.8, name="BlackrockDepths", floor=1 },
		{ x=34.7, y=85.5, name="BlackrockSpire", floor=7 },
	},
	[1428] = {  -- Burning Steppes: Blackrock Mountain raids + dungeons
		{ x=29.8, y=38.5, name="MoltenCore", floor=1 },
		{ x=30, y=27.4, name="BlackwingLair", floor=1 },
		{ x=25.5, y=32.5, name="BlackrockDepths", floor=1 },
		{ x=34, y=32.8, name="BlackrockSpire", floor=7 },
	},
	[1435] = {
		{ x=70.7, y=59.3, name="TheTempleofAtalhakkar", floor=1 },
	},
	[1436] = {{ x=42.5, y=71.7, name="TheDeadmines", floor=1 }},
	[1453] = {{ x=42.3, y=59.0, name="TheStockade", floor=1 }},
	[1957] = {  -- Isle of Quel'Danas: Magisters' Terrace + Sunwell Plateau
		{ x=61.2, y=30.9, name="MagistersTerrace", floor=1 },
		{ x=44.3, y=45.6, name="SunwellPlateau", floor=1 },
	},
	[1434] = {
		{ x=53.6, y=17.8, name="ZulGurub", floor=1 },
	},		   -- Stranglethorn Vale
	[1445] = {{ x=52.6, y=76.8, name="OnyxiasLair", floor=1 }},		-- Dustwallow Marsh
	[1430] = {
		{ x=45.9, y=73.2, name="Karazhan", floor=1 },
	},		   -- Deadwind Pass
	[1942] = {{ x=35.8, y=37.1, name="ZulAman", floor=1 }},			-- Ghostlands

	-- Kalimdor
	[1413] = {
		{ x=46.8, y=36.8, name="WailingCaverns", floor=1 },
		{ x=41, y=89.7, name="RazorfenKraul", floor=1 },
		{ x=49.3, y=89, name="RazorfenDowns", floor=1 },
	},
	[1440] = {{ x=14.5, y=14.2, name="BlackfathomDeeps", floor=1 }},
	[1443] = {{ x=29.1, y=62.5, name="Maraudon", floor=1 }},
	[1444] = {  -- Feralas: 3 entrances Dire Maul
		{ x=59.1, y=41.7, name="Diremaul", floor=2 },
	},
	[1451] = {
		{ x=37.2, y=93.7, name="RuinsofAhnQiraj", floor=1 },
		{ x=29.9, y=92.1, name="AhnQiraj", floor=1 },
	},
	[1446] = {
		{ x=37.1, y=12.2, name="ZulFarrak", floor=1 },
		{ x=66.2, y=48.7, name="CoTHillsbradFoothills", floor=1 },
		{ x=67, y=48.7, name="CoTTheBlackMorass", floor=1 },
		{ x=67.8, y=48.7, name="CoTMountHyjal", floor=1 },
	},
	[1454] = {{ x=52.6, y=49.0, name="Ragefire", floor=1 }},

	-- Outland (TBC)
	[1944] = {  -- Hellfire Peninsula: 3 dungeons + Magtheridon's Lair
		{ x=47.7, y=53.6, name="HellfireRamparts", floor=1 },
		{ x=47.7, y=52.0, name="TheShatteredHalls", floor=1 },
		{ x=46.0, y=51.8, name="TheBloodFurnace", floor=1 },
		{ x=46.8, y=52.8, name="MagtheridonsLair", floor=1 },
	},
	[1952] = {  -- Terokkar Forest: 4 dungeons
		{ x=39.7, y=60.2, name="ManaTombs", floor=1 },
		{ x=36.1, y=65.6, name="AuchenaiCrypts", floor=1 },
		{ x=43.2, y=65.6, name="SethekkHalls", floor=1 },
		{ x=39.6, y=71.0, name="ShadowLabyrinth", floor=1 },
	},
	[1953] = {  -- Netherstorm: 3 dungeons + The Eye
		{ x=71.7, y=55.0, name="TheBotanica", floor=1 },
		{ x=74.4, y=57.7, name="TheArcatraz", floor=1 },
		{ x=70.6, y=69.7, name="TheMechanar", floor=1 },
		{ x=73.7, y=63.7, name="TempestKeep", floor=1 },
	},
	[1946] = {  -- Zangarmarsh: Coilfang dungeons + SSC
		{ x=49.5, y=40.2, name="TheSlavePens", floor=1 },
		{ x=50.3, y=40.9, name="TheUnderbog", floor=1 },
		{ x=51.1, y=40.2, name="TheSteamvault", floor=1 },
		{ x=50.3, y=41.7, name="CoilfangReservoir", floor=1 },
	},
	[1948] = {{ x=71.0, y=46.4, name="BlackTemple", floor=1 }},		-- Shadowmoon Valley
	[1949] = {{ x=68.7, y=24.0, name="GruulsLair", floor=1 }},		 -- Blade's Edge Mountains
}

-- Fallback NPC/object positions inside dungeons (from Wowhead)
-- Used when Questie has (-1,-1) coordinates
-- questieAreaID -> { npcOrObjId -> { x, y } }
ns.npcPositions = {
	[3562] = { -- Hellfire Ramparts
		[17306] = { 72.5, 35.5 },  -- Watchkeeper Gargolmar
		[17537] = { 27.2, 84.8 },  -- Vazruden
		[17536] = { 27.2, 84.8 },  -- Nazan
	},
	[3713] = { -- The Blood Furnace
		[17377] = { 59.8, 35.5 },  -- Keli'dan the Breaker
	},
	[3714] = { -- The Shattered Halls
		[16807] = { 33.6, 63.6 },  -- Grand Warlock Nethekurse
	},
	[3717] = { -- The Slave Pens
		[17890] = { 46, 80 },	  -- Weeder Greenthumb
		[17893] = { 94.4, 65.4 },  -- Naturalist Bite
		[17941] = { 48.7, 24.4 },  -- Mennu the Betrayer
	},
	[3716] = { -- The Underbog
		[17885] = { 67.5, 21.2 },  -- Earthbinder Rayge
		[17894] = { 41.5, 24.1 },  -- Windcaller Claw
		[17882] = { 24.7, 45.6 },  -- The Black Stalker
		[17770] = { 69.3, 89.9 },  -- Hungarfen
		[17826] = { 41.5, 24.1 },  -- Swamplord Musel'ek
	},
	[3715] = { -- The Steamvault
		[17798] = { 74, 37 },	  -- Warlord Kalithresh
		[17797] = { 53.8, 8.7 },   -- Hydromancer Thespia
		[17796] = { 29.6, 86.2 },  -- Mekgineer Steamrigger
	},
	[3792] = { -- Mana-Tombs
		[18344] = { 32, 49 },	  -- Nexus-Prince Shaffar
	},
	[3790] = { -- Auchenai Crypts
		[18373] = { 74, 51 },	  -- Exarch Maladaar
		[19412] = { 74, 51 },	  -- D'ore
	},
	[3791] = { -- Sethekk Halls
		[18472] = { 49, 68 },	  -- Darkweaver Syth
		[18473] = { 33, 28 },	  -- Talon King Ikiss
		[18956] = { 49, 68 },	  -- Lakka
		[183050] = { 33, 28 },	 -- The Saga of Terokk
	},
	[3789] = { -- Shadow Labyrinth (offset -2, -5 from Wowhead)
		[18731] = { 17, 20 },	  -- Ambassador Hellmaw (manually calibrated)
		[18667] = { 25, 65 },	  -- Blackheart the Inciter
		[18732] = { 51, 49 },	  -- Grandmaster Vorpil
		[18708] = { 79, 34 },	  -- Murmur
		[18891] = { 17, 20 },	  -- Spy To'gun (same as Hellmaw)
		[22890] = { 79, 34 },	  -- First Fragment Guardian
		[182947] = { 51, 49 },	 -- The Codex of Blood
		[182196] = { 79, 34 },	 -- Arcane Container
	},
	[3849] = { -- The Mechanar
		[19218] = { 47, 55 },	  -- Gatewatcher Gyro-Kill
		[19710] = { 59.5, 50.5 },  -- Gatewatcher Iron-Hand
		[19219] = { 55.5, 36 },	-- Mechano-Lord Capacitus
		[19220] = { 27, 61 },	  -- Pathaleon the Calculator
	},
	[3847] = { -- The Botanica
		[17976] = { 41.2, 31.6 },  -- Commander Sarannis
		[17975] = { 29.8, 34.6 },  -- High Botanist Freywinn
		[17978] = { 18.7, 46.4 },  -- Thorngrin the Tender
		[17980] = { 36.1, 69.3 },  -- Laj
		[17977] = { 36.3, 39.8 },  -- Warp Splinter
	},
	[3848] = { -- The Arcatraz
		[20870] = { 51.6, 49.3 },  -- Zereketh the Unbound
		[20886] = { 21.5, 64.1 },  -- Wrath-Scryer Soccothrates
		[20885] = { 29.9, 63.7 },  -- Dalliah the Doomsayer
		[20912] = { 57.8, 16.3 },  -- Harbinger Skyriss
	},
	[2367] = { -- Old Hillsbrad Foothills
		[17848] = { 69.4, 56.1 },  -- Lieutenant Drake
		[17862] = { 64.2, 58.8 },  -- Captain Skarloc
		[18096] = { 45.3, 24.6 },  -- Epoch Hunter
	},
	[4131] = { -- Magisters' Terrace
		[24723] = { 42, 30.5 },	-- Selin Fireheart
		[24744] = { 83, 26 },	  -- Vexallus
		[24560] = { 40, 56 },	  -- Priestess Delrissa
		[24664] = { 9, 50 },	   -- Kael'thas Sunstrider
	},
}

-- Boss markers that open AtlasLoot at the boss loot page.
-- Indexed by instanceMapID (same key as ns.dungeonByMapID, from
-- select(8, GetInstanceInfo())).
--   atlasModule = AtlasLoot module name (= addon folder name)
--   bosses	  = { { name, x, y, floor, atlasKey, atlasBossIndex }, ... }
--   atlasKey is per-boss (one instanceMapID can span several AtlasLoot
--   keys, e.g. Scarlet Monastery / Dire Maul wings).
-- Coords are placeholder grid positions; fine-tune in-game via /sdm calib
-- (drag a skull; the override is saved to SDM_Settings.bossPinOverrides).
ns.dungeonBosses = {
	[33] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Rethilgore", 65.2, 62.9, 1, "ShadowfangKeep", 1 },
			{ "Fel Steed / Shadow Charger", 32.2, 49.1, 1, "ShadowfangKeep", 2 },
			{ "Razorclaw the Butcher", 47.8, 21, 2, "ShadowfangKeep", 3 },
			{ "Baron Silverlaine", 29.7, 66.9, 2, "ShadowfangKeep", 4 },
			{ "Commander Springvale", 27.3, 52.2, 1, "ShadowfangKeep", 5 },
			{ "Odo the Blindwatcher", 57.8, 70.8, 7, "ShadowfangKeep", 6 },
			{ "Deathsworn Captain", 54.2, 44.3, 7, "ShadowfangKeep", 7 },
			{ "Arugal's Voidwalker", 70, 26.4, 6, "ShadowfangKeep", 8 },
			{ "Fenrus the Devourer", 53.1, 46.8, 4, "ShadowfangKeep", 9 },
			{ "Wolf Master Nandos", 54.9, 55, 6, "ShadowfangKeep", 10 },
			{ "Archmage Arugal", 66.5, 29.1, 6, "ShadowfangKeep", 11 },
			{ "Jordan's Smithing Hammer", 32.1, 53.3, 1, "ShadowfangKeep", 15 },
			{ "The Book of Ur", 44.9, 54.1, 4, "ShadowfangKeep", 16 },
		},
	},
	[34] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			-- Only Kam and Bruegal have AtlasLoot pages; the rest drop
			-- nothing notable, so their pins carry no loot link. Positions
			-- projected from spawn data; Targorr and Dextren average
			-- several spawn cells.
			{ "Targorr the Dread", 49, 18.5, 1 },
			{ "Kam Deepfury", 68.1, 25.5, 1, "TheStockade", 1 },
			{ "Hamhock", 76.5, 39.7, 1 },
			{ "Bazil Thredd", 83.9, 44.4, 1 },
			{ "Dextren Ward", 18.6, 23.1, 1 },
			{ "Bruegal Ironknuckle", 29.5, 38.1, 1, "TheStockade", 2 },
		},
	},
	[36] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Rhahk'Zor", 35.5, 53.5, 1, "TheDeadmines", 1 },
			{ "Miner Johnson", 50.9, 43.7, 1, "TheDeadmines", 2 },
			{ "Sneed", 49.2, 75.3, 1, "TheDeadmines", 3 },
			{ "Sneed's Shredder", 46.3, 75.3, 1, "TheDeadmines", 4 },
			{ "Gilnid", 12.1, 65.9, 2, "TheDeadmines", 5 },
			{ "Mr. Smite", 54.9, 23, 2, "TheDeadmines", 6 },
			{ "Captain Greenskin", 59.2, 32.7, 2, "TheDeadmines", 7 },
			{ "Edwin VanCleef", 59.4, 39.2, 2, "TheDeadmines", 8 },
			{ "Cookie", 65.6, 35, 2, "TheDeadmines", 9 },
		},
	},
	[43] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Lord Cobrahn", 15.5, 49.3, 1, "WailingCaverns", 1 },
			{ "Lady Anacondra", 30.1, 37.3, 1, "WailingCaverns", 2 },
			{ "Kresh", 25.2, 38.8, 1, "WailingCaverns", 3 },
			{ "Lord Pythas", 83.8, 24.7, 1, "WailingCaverns", 4 },
			{ "Skum", 91.1, 69.3, 1, "WailingCaverns", 5 },
			{ "Lord Serpentis", 60.1, 46.7, 1, "WailingCaverns", 6 },
			{ "Verdan the Everliving", 55.2, 41.2, 1, "WailingCaverns", 7 },
			{ "Mutanus the Devourer", 54, 40.6, 1, "WailingCaverns", 8 },
			{ "Deviate Faerie Dragon", 63.7, 29.3, 1, "WailingCaverns", 9 },
		},
	},
	[47] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Aggem Thorncurse", 78.9, 44.9, 1, "RazorfenKraul", 1 },
			{ "Death Speaker Jargba", 85.5, 36.2, 1, "RazorfenKraul", 2 },
			{ "Overlord Ramtusk", 56.2, 26.8, 1, "RazorfenKraul", 3 },
			{ "Razorfen Spearhide", 57.6, 24, 1, "RazorfenKraul", 4 },
			{ "Agathelos the Raging", 7.5, 59.2, 1, "RazorfenKraul", 5 },
			{ "Blind Hunter", 10.6, 26.2, 1, "RazorfenKraul", 6 },
			{ "Charlga Razorflank", 21.2, 26.7, 1, "RazorfenKraul", 7 },
			{ "Earthcaller Halmgar", 47.5, 40.1, 1, "RazorfenKraul", 8 },
		},
	},
	[48] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Ghamoo-ra", 32.1, 52.6, 1, "BlackfathomDeeps", 1 },
			{ "Lady Sarevess", 11.1, 34.4, 1, "BlackfathomDeeps", 2 },
			{ "Gelihast", 53.2, 49.3, 1, "BlackfathomDeeps", 3 },
			{ "Baron Aquanis", 39.9, 62.7, 2, "BlackfathomDeeps", 4 },
			{ "Twilight Lord Kelris", 51.6, 71.1, 2, "BlackfathomDeeps", 5 },
			{ "Old Serra'kis", 57.5, 26.3, 3, "BlackfathomDeeps", 6 },
			{ "Aku'mai", 84, 75, 2, "BlackfathomDeeps", 7 },
		},
	},
	[70] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Eric \\\"The Swift\\\"", 57.3, 80, 1, "Uldaman", 1 },
			{ "Baelog", 59.9, 80.2, 1, "Uldaman", 2 },
			{ "Olaf", 54.3, 80.1, 1, "Uldaman", 3 },
			{ "Revelosh", 52.2, 63, 1, "Uldaman", 4 },
			{ "Ironaya", 36.1, 64.1, 1, "Uldaman", 5 },
			{ "Obsidian Sentinel", 28.3, 52.2, 1, "Uldaman", 6 },
			{ "Ancient Stone Keeper", 46.5, 38.3, 1, "Uldaman", 7 },
			{ "Galgann Firehammer", 25.8, 28.3, 1, "Uldaman", 8 },
			{ "Grimlok", 21.3, 22.6, 1, "Uldaman", 9 },
			{ "Archaedas", 40.8, 14.3, 1, "Uldaman", 10 },
			{ "Baelog's Chest", 62.6, 80.2, 1, "Uldaman", 12 },
			{ "Conspicuous Urn", 56.8, 83.4, 1, "Uldaman", 13 },
			{ "Shadowforge Cache", 22.6, 29.1, 1, "Uldaman", 14 },
			{ "Tablet of Will", 24.8, 31.3, 1, "Uldaman", 15 },
		},
	},
	[90] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Techbot", 48.3, 43.2, 1, "Gnomeregan", 1 },
			{ "Grubbis", 75.8, 57.8, 1, "Gnomeregan", 2 },
			{ "Viscous Fallout", 74.1, 40.5, 2, "Gnomeregan", 3 },
			{ "Electrocutioner 6000", 23.7, 59, 2, "Gnomeregan", 4 },
			{ "Crowd Pummeler 9-60", 42.1, 76.4, 3, "Gnomeregan", 5 },
			{ "Dark Iron Ambassador", 30.5, 25.7, 4, "Gnomeregan", 6 },
			{ "Mekgineer Thermaplugg", 2.8, 56, 2, "Gnomeregan", 7 },
		},
	},
	[109] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Balcony Minibosses", 56.4, 13.3, 1, "TheTempleOfAtal'Hakkar", 1 },
			{ "Atal'alarion", 59.6, 13.4, 1, "TheTempleOfAtal'Hakkar", 2 },
			{ "Spawn of Hakkar", 48.9, 35.4, 1, "TheTempleOfAtal'Hakkar", 3 },
			{ "Avatar of Hakkar", 23.5, 39.4, 1, "TheTempleOfAtal'Hakkar", 4 },
			{ "Jammal'an the Prophet", 74.4, 39.7, 1, "TheTempleOfAtal'Hakkar", 5 },
			{ "Ogom the Wretched", 76.8, 36.9, 1, "TheTempleOfAtal'Hakkar", 6 },
			{ "Dreamscythe", 51.9, 41.5, 1, "TheTempleOfAtal'Hakkar", 7 },
			{ "Weaver", 45.7, 41.7, 1, "TheTempleOfAtal'Hakkar", 8 },
			{ "Hazzas", 48.7, 75.5, 1, "TheTempleOfAtal'Hakkar", 9 },
			{ "Morphaz", 45.5, 75.5, 1, "TheTempleOfAtal'Hakkar", 10 },
			{ "Shade of Eranikus", 65, 76.3, 1, "TheTempleOfAtal'Hakkar", 11 },
		},
	},
	[129] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Tuten'kash", 57.8, 29.6, 1, "RazorfenDowns", 1 },
			{ "Mordresh Fire Eye", 83.9, 40.4, 1, "RazorfenDowns", 2 },
			{ "Glutton", 33.8, 58, 1, "RazorfenDowns", 3 },
			{ "Ragglesnout", 51.8, 58.5, 1, "RazorfenDowns", 4 },
			{ "Amnennar the Coldbringer", 43.4, 52.5, 1, "RazorfenDowns", 5 },
			{ "Plaguemaw the Rotting", 49.3, 60.5, 1, "RazorfenDowns", 6 },
			{ "Lady Falther'ess", 76, 20.3, 1, "RazorfenDowns", 8 },
			{ "Henry Stern", 78.7, 22.2, 1, "RazorfenDowns", 9 },
		},
	},
	[189] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Azshir the Sleepless", 34, 44.7, 1, "ScarletMonasteryGraveyard", 2 },
			{ "Fallen Champion", 35.1, 57.7, 1, "ScarletMonasteryGraveyard", 3 },
			{ "Ironspine", 50.1, 57.7, 1, "ScarletMonasteryGraveyard", 4 },
			{ "Bloodmage Thalnos", 23.5, 48.8, 1, "ScarletMonasteryGraveyard", 5 },
			{ "Scorn", 70.7, 54.6, 1, "ScarletMonasteryGraveyard", 7 },
			{ "Headless Horseman", 68.6, 51.9, 1, "ScarletMonasteryGraveyard", 8 },
			{ "Arcanist Doan", 81.6, 64.6, 2, "ScarletMonasteryLibrary", 2 },
			{ "Doan's Strongbox", 28.8, 73.5, 2, "ScarletMonasteryLibrary", 4 },
			{ "Scarlet Commander Mograine", 48.1, 14.4, 4, "ScarletMonasteryCathedral", 2 },
			{ "High Inquisitor Whitemane", 48, 24, 4, "ScarletMonasteryCathedral", 3 },
			{ "Interrogator Vishas", 70.5, 51.8, 1, "ScarletMonasteryGraveyard", 1 },
			{ "Houndmaster Loksey", 30.1, 76.4, 2, "ScarletMonasteryLibrary", 1 },
			{ "Herod", 77, 9.4, 3, "ScarletMonasteryArmory", 1 },
			{ "High Inquisitor Fairbanks", 54.2, 21.6, 4, "ScarletMonasteryCathedral", 1 },
		},
	},
	[209] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Antu'sul", 62.9, 23.9, 1, "Zul'Farrak", 1 },
			{ "Theka the Martyr", 51.6, 22.8, 1, "Zul'Farrak", 2 },
			{ "Sandarr Dunereaver", 43.6, 45.7, 1, "Zul'Farrak", 3 },
			{ "Witch Doctor Zum'rah", 43.3, 15.1, 1, "Zul'Farrak", 4 },
			{ "Nekrum Gutchewer", 29.8, 18.3, 1, "Zul'Farrak", 5 },
			{ "Shadowpriest Sezz'ziz", 24, 15.2, 1, "Zul'Farrak", 6 },
			{ "Dustwraith", 31.7, 13.1, 1, "Zul'Farrak", 7 },
			{ "Sandfury Executioner", 23.7, 15.6, 1, "Zul'Farrak", 8 },
			{ "Sergeant Bly", 23, 15.9, 1, "Zul'Farrak", 9 },
			{ "Hydromancer Velratha", 30.6, 35.8, 1, "Zul'Farrak", 10 },
			{ "Gahz'rilla", 57.6, 58.5, 1, "Zul'Farrak", 11 },
			{ "Chief Ukorz Sandscalp", 41.3, 29, 1, "Zul'Farrak", 12 },
			{ "Zerillis", 52.6, 32.4, 1, "Zul'Farrak", 13 },
		},
	},
	[229] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Burning Felguard", 12, 10, 1, "LowerBlackrockSpire", 1 },
			{ "Spirestone Butcher", 27.2, 10, 1, "LowerBlackrockSpire", 2 },
			{ "Highlord Omokk", 42.4, 10, 1, "LowerBlackrockSpire", 3 },
			{ "Spirestone Battle Lord", 57.6, 10, 1, "LowerBlackrockSpire", 4 },
			{ "Spirestone Lord Magus", 72.8, 10, 1, "LowerBlackrockSpire", 5 },
			{ "Shadow Hunter Vosh'gajin", 88, 10, 1, "LowerBlackrockSpire", 6 },
			{ "War Master Voone", 12, 30, 1, "LowerBlackrockSpire", 7 },
			{ "Bannok Grimaxe", 27.2, 30, 1, "LowerBlackrockSpire", 8 },
			{ "Mother Smolderweb", 42.4, 30, 1, "LowerBlackrockSpire", 9 },
			{ "Crystal Fang", 57.6, 30, 1, "LowerBlackrockSpire", 10 },
			{ "Urok Doomhowl", 72.8, 30, 1, "LowerBlackrockSpire", 11 },
			{ "Quartermaster Zigris", 88, 30, 1, "LowerBlackrockSpire", 12 },
			{ "Halycon", 12, 50, 1, "LowerBlackrockSpire", 13 },
			{ "Gizrul the Slavener", 27.2, 50, 1, "LowerBlackrockSpire", 14 },
			{ "Ghok Bashguud", 42.4, 50, 1, "LowerBlackrockSpire", 15 },
			{ "Overlord Wyrmthalak", 57.6, 50, 1, "LowerBlackrockSpire", 16 },
			{ "Mor Grayhoof", 72.8, 50, 1, "LowerBlackrockSpire", 18 },
			{ "Pyroguard Emberseer", 88, 50, 1, "UpperBlackrockSpire", 1 },
			{ "Solakar Flamewreath", 12, 70, 1, "UpperBlackrockSpire", 2 },
			{ "Jed Runewatcher", 27.2, 70, 1, "UpperBlackrockSpire", 3 },
			{ "Goraluk Anvilcrack ", 42.4, 70, 1, "UpperBlackrockSpire", 4 },
			{ "Gyth", 57.6, 70, 1, "UpperBlackrockSpire", 5 },
			{ "Warchief Rend Blackhand", 72.8, 70, 1, "UpperBlackrockSpire", 6 },
			{ "The Beast", 88, 70, 1, "UpperBlackrockSpire", 7 },
			{ "General Drakkisath", 12, 90, 1, "UpperBlackrockSpire", 8 },
			{ "Darkstone Tablet", 27.2, 90, 1, "UpperBlackrockSpire", 10 },
			{ "Lord Valthalak", 42.4, 90, 1, "UpperBlackrockSpire", 11 },
		},
	},
	[230] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Lord Roccor", 12, 10, 1, "BlackrockDepths", 1 },
			{ "High Interrogator Gerstahn ", 27.2, 10, 1, "BlackrockDepths", 2 },
			{ "Houndmaster Grebmar", 42.4, 10, 1, "BlackrockDepths", 3 },
			{ "Grizzle", 57.6, 10, 1, "BlackrockDepths", 5 },
			{ "Eviscerator", 72.8, 10, 1, "BlackrockDepths", 6 },
			{ "Ok'thor the Breaker", 88, 10, 1, "BlackrockDepths", 7 },
			{ "Anub'shiah", 12, 30, 1, "BlackrockDepths", 8 },
			{ "Hedrum the Creeper", 27.2, 30, 1, "BlackrockDepths", 9 },
			{ "Dark Coffer", 42.4, 30, 1, "BlackrockDepths", 11 },
			{ "Warder Stilgiss", 57.6, 30, 1, "BlackrockDepths", 12 },
			{ "Verek", 72.8, 30, 1, "BlackrockDepths", 13 },
			{ "Watchman Doomgrip", 88, 30, 1, "BlackrockDepths", 14 },
			{ "Fineous Darkvire", 12, 50, 1, "BlackrockDepths", 15 },
			{ "Lord Incendius", 27.2, 50, 1, "BlackrockDepths", 16 },
			{ "Bael'Gar", 42.4, 50, 1, "BlackrockDepths", 17 },
			{ "General Angerforge", 57.6, 50, 1, "BlackrockDepths", 18 },
			{ "Golem Lord Argelmach", 72.8, 50, 1, "BlackrockDepths", 19 },
			{ "Guzzler", 88, 50, 1, "BlackrockDepths", 20 },
			{ "Phalanx", 12, 70, 1, "BlackrockDepths", 21 },
			{ "Ambassador Flamelash", 27.2, 70, 1, "BlackrockDepths", 22 },
			{ "Panzor the Invincible", 42.4, 70, 1, "BlackrockDepths", 23 },
			{ "Chest of The Seven", 57.6, 70, 1, "BlackrockDepths", 24 },
			{ "Magmus", 72.8, 70, 1, "BlackrockDepths", 25 },
			{ "Princess Moira Bronzebeard ", 88, 70, 1, "BlackrockDepths", 26 },
			{ "Emperor Dagran Thaurissan", 12, 90, 1, "BlackrockDepths", 27 },
			{ "Plans", 27.2, 90, 1, "BlackrockDepths", 29 },
			{ "Theldren", 42.4, 90, 1, "BlackrockDepths", 30 },
			{ "Coren Direbrew", 57.6, 90, 1, "BlackrockDepths", 31 },
			{ "Gorosh the Dervish", 72.8, 90.0, 1, "BlackrockDepths", 4 },
			{ "Pyromancer Loregrain", 88.0, 90.0, 1, "BlackrockDepths", 10 },
		},
	},
	[249] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Onyxia", 65.8, 26.7, 1, "Onyxia", 1 },
		},
	},
	[269] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Chrono Lord Deja", 12, 10, 1, "TheBlackMorass", 1 },
			{ "Temporus", 88, 10, 1, "TheBlackMorass", 2 },
			{ "Aeonus", 12, 90, 1, "TheBlackMorass", 3 },
		},
	},
	[289] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Blood Steward of Kirtonos", 12, 10, 1, "Scholomance", 1 },
			{ "Kirtonos the Herald", 31, 10, 1, "Scholomance", 2 },
			{ "Jandice Barov", 50, 10, 1, "Scholomance", 3 },
			{ "Rattlegore", 69, 10, 1, "Scholomance", 4 },
			{ "Death Knight Darkreaver", 88, 10, 1, "Scholomance", 5 },
			{ "Marduk Blackpool", 12, 36.7, 1, "Scholomance", 6 },
			{ "Vectus", 31, 36.7, 1, "Scholomance", 7 },
			{ "Ras Frostwhisper", 50, 36.7, 1, "Scholomance", 8 },
			{ "Instructor Malicia", 69, 36.7, 1, "Scholomance", 9 },
			{ "Doctor Theolen Krastinov", 88, 36.7, 1, "Scholomance", 10 },
			{ "Lorekeeper Polkelt", 12, 63.3, 1, "Scholomance", 11 },
			{ "The Ravenian", 31, 63.3, 1, "Scholomance", 12 },
			{ "Lord Alexei Barov", 50, 63.3, 1, "Scholomance", 13 },
			{ "Lady Illucia Barov", 69, 63.3, 1, "Scholomance", 14 },
			{ "Darkmaster Gandling", 88, 63.3, 1, "Scholomance", 15 },
			{ "Lord Blackwood", 12, 90, 1, "Scholomance", 17 },
			{ "Kormok", 31, 90, 1, "Scholomance", 18 },
		},
	},
	[309] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "High Priestess Jeklik", 37.9, 63.6, 1, "Zul'Gurub", 1 },
			{ "High Priest Venoxis", 49.8, 47.2, 1, "Zul'Gurub", 2 },
			{ "High Priestess Mar'li", 47.2, 68.2, 1, "Zul'Gurub", 3 },
			{ "Bloodlord Mandokir", 64.3, 59.7, 1, "Zul'Gurub", 4 },
			{ "Gri'lek", 58.6, 40.2, 1, "Zul'Gurub", 5 },
			{ "Hazza'rah", 60, 37.4, 1, "Zul'Gurub", 6 },
			{ "Renataki", 61.6, 40, 1, "Zul'Gurub", 7 },
			{ "Wushoolay", 60.5, 43.2, 1, "Zul'Gurub", 8 },
			{ "Gahz'ranka", 56.3, 29.6, 1, "Zul'Gurub", 9 },
			{ "High Priest Thekal", 68, 27.3, 1, "Zul'Gurub", 10 },
			{ "High Priestess Arlokk", 46.8, 18, 1, "Zul'Gurub", 11 },
			{ "Jin'do the Hexxer", 30.8, 21.5, 1, "Zul'Gurub", 12 },
			{ "Hakkar", 48.9, 34.6, 1, "Zul'Gurub", 13 },
			{ "Muddy Churning Waters", 12, 90, 1, "Zul'Gurub", 17 },
			{ "Jinxed Hoodoo Pile", 31, 90, 1, "Zul'Gurub", 18 },
		},
	},
	[329] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Skul", 81.9, 34.7, 1, "Stratholme", 1 },
			{ "Stratholme Courier", 55.4, 59.6, 1, "Stratholme", 2 },
			{ "Hearthsinger Forresten", 59, 28.2, 1, "Stratholme", 3 },
			{ "The Unforgiven", 72, 17.4, 1, "Stratholme", 4 },
			{ "Timmy the Cruel", 48.3, 15.6, 1, "Stratholme", 6 },
			{ "Malor the Zealous", 29, 35.3, 1, "Stratholme", 7 },
			{ "Crimson Hammersmith", 11.4, 41.6, 1, "Stratholme", 8 },
			{ "Cannon Master Willey", 4, 44, 1, "Stratholme", 9 },
			{ "Archivist Galford", 26.6, 65.1, 1, "Stratholme", 10 },
			{ "Balnazzar", 19.8, 71, 1, "Stratholme", 11 },
			{ "Magistrate Barthilas", 55.5, 14.1, 2, "Stratholme", 12 },
			{ "Stonespine", 63.5, 42.5, 2, "Stratholme", 13 },
			{ "Baroness Anastari", 73, 40.8, 2, "Stratholme", 14 },
			{ "Black Guard Swordsmith", 72.5, 40.1, 2, "Stratholme", 15 },
			{ "Nerub'enkan", 55.8, 40.4, 2, "Stratholme", 16 },
			{ "Maleki the Pallid", 66.1, 18.9, 2, "Stratholme", 17 },
			{ "Ramstein the Gorger", 44.3, 17.1, 2, "Stratholme", 18 },
			{ "Baron Rivendare", 38.2, 17.7, 2, "Stratholme", 19 },
			{ "Atiesh", 12, 90, 1, "Stratholme", 22 },
			{ "Balzaphon", 78, 16.5, 1, "Stratholme", 23 },
			{ "Sothos and Jarien's Heirlooms", 50, 90, 1, "Stratholme", 24 },
		},
	},
	[349] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Veng", 40.4, 16.9, 1, "Maraudon", 1 },
			{ "Noxxion", 35, 8.6, 1, "Maraudon", 2 },
			{ "Razorlash", 16, 29.6, 1, "Maraudon", 3 },
			{ "Maraudos", 49.4, 45.4, 1, "Maraudon", 4 },
			{ "Lord Vyletongue", 36.8, 61.4, 1, "Maraudon", 5 },
			{ "Meshlok the Harvester", 22.6, 60.6, 1, "Maraudon", 6 },
			{ "Celebras the Cursed", 23.9, 12.1, 2, "Maraudon", 7 },
			{ "Landslide", 40.3, 42.6, 2, "Maraudon", 8 },
			{ "Tinkerer Gizlock", 49.2, 55.1, 2, "Maraudon", 9 },
			{ "Rotgrip", 40.4, 71, 2, "Maraudon", 10 },
			{ "Princess Theradras", 25.4, 68.6, 2, "Maraudon", 11 },
		},
	},
	[389] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			-- Oggleflint and Bazzalan drop nothing notable, so they have no
			-- AtlasLoot page; their pins carry no loot link.
			{ "Oggleflint", 52.9, 25.9, 1 },
			{ "Taragaman the Hungerer", 40.1, 50.2, 1, "Ragefire", 1 },
			{ "Jergosh the Invoker", 33.5, 71, 1, "Ragefire", 2 },
			{ "Bazzalan", 40.6, 75, 1 },
		},
	},
	[409] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Lucifron", 64.3, 32.8, 1, "MoltenCore", 1 },
			{ "Magmadar", 67.4, 20.6, 1, "MoltenCore", 2 },
			{ "Gehennas", 32.5, 42.4, 1, "MoltenCore", 3 },
			{ "Garr", 30.3, 60.6, 1, "MoltenCore", 4 },
			{ "Shazzrah", 51.3, 67.5, 1, "MoltenCore", 5 },
			{ "Baron Geddon", 53.9, 73.7, 1, "MoltenCore", 6 },
			{ "Golemagg the Incinerator", 67.1, 50.9, 1, "MoltenCore", 7 },
			{ "Sulfuron Harbinger", 80.9, 72.2, 1, "MoltenCore", 8 },
			{ "Majordomo Executus", 82.1, 57.3, 1, "MoltenCore", 9 },
			{ "Ragnaros", 54.5, 47.2, 1, "MoltenCore", 10 },
		},
	},
	[429] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Pusillin", 42.9, 41.4, 5, "DireMaulEast", 1 },
			{ "Zevrim Thornhoof", 56.5, 64.2, 6, "DireMaulEast", 2 },
			{ "Hydrospawn", 56.4, 60.3, 6, "DireMaulEast", 3 },
			{ "Lethtendris", 52.4, 62, 6, "DireMaulEast", 4 },
			{ "Alzzin the Wildshaper", 55.2, 25, 6, "DireMaulEast", 5 },
			{ "Tendris Warpwood", 32.5, 46.4, 2, "DireMaulWest", 1 },
			{ "Illyanna Ravenoak", 18.8, 48.7, 2, "DireMaulWest", 2 },
			{ "Magister Kalendris", 20.3, 68, 2, "DireMaulWest", 3 },
			{ "Tsu'zee", 31.3, 12.7, 3, "DireMaulWest", 4 },
			{ "Immol'thar", 34.1, 49.9, 4, "DireMaulWest", 5 },
			{ "Prince Tortheldrin", 60.8, 20.3, 4, "DireMaulWest", 6 },
			{ "Revanchion", 32.9, 38.9, 3, "DireMaulWest", 8 },
			{ "Shen'dralar Provisioner", 70.1, 11.7, 4, "DireMaulWest", 9 },
			{ "Lord Hel'nurath", 37.6, 50, 4, "DireMaulWest", 10 },
			{ "Guard Mol'dar", 67.9, 66, 1, "DireMaulNorth", 1 },
			{ "Stomper Kreeg", 59.5, 59.3, 1, "DireMaulNorth", 2 },
			{ "Guard Fengus", 48.4, 67.9, 1, "DireMaulNorth", 3 },
			{ "Guard Slip'kik", 25.6, 49.5, 1, "DireMaulNorth", 4 },
			{ "Knot Thimblejack's Cache", 27.9, 47.7, 1, "DireMaulNorth", 5 },
			{ "Captain Kromcrush", 31.2, 43.4, 1, "DireMaulNorth", 6 },
			{ "Cho'Rush the Observer", 31.1, 22.9, 1, "DireMaulNorth", 7 },
			{ "King Gordok", 31.1, 19.1, 1, "DireMaulNorth", 8 },
			{ "Tribute", 31.1, 24.7, 1, "DireMaulNorth", 9 },
		},
	},
	[469] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Razorgore the Untamed", 12, 10, 1, "BlackwingLair", 1 },
			{ "Vaelastrasz the Corrupt", 50, 10, 1, "BlackwingLair", 2 },
			{ "Broodlord Lashlayer", 88, 10, 1, "BlackwingLair", 3 },
			{ "Firemaw", 12, 50, 1, "BlackwingLair", 4 },
			{ "Ebonroc", 50, 50, 1, "BlackwingLair", 5 },
			{ "Flamegor", 88, 50, 1, "BlackwingLair", 6 },
			{ "Chromaggus", 12, 90, 1, "BlackwingLair", 7 },
			{ "Nefarian", 50, 90, 1, "BlackwingLair", 8 },
		},
	},
	[509] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Kurinnaxx", 12, 10, 1, "TheRuinsofAhnQiraj", 1 },
			{ "General Rajaxx", 50, 10, 1, "TheRuinsofAhnQiraj", 2 },
			{ "Moam", 88, 10, 1, "TheRuinsofAhnQiraj", 3 },
			{ "Buru the Gorger", 12, 50, 1, "TheRuinsofAhnQiraj", 4 },
			{ "Ayamiss the Hunter", 50, 50, 1, "TheRuinsofAhnQiraj", 5 },
			{ "Ossirian the Unscarred", 88, 50, 1, "TheRuinsofAhnQiraj", 6 },
			{ "Class books", 12, 90, 1, "TheRuinsofAhnQiraj", 8 },
		},
	},
	[531] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "The Prophet Skeram", 12, 10, 1, "TheTempleofAhnQiraj", 1 },
			{ "Bug Trio", 50, 10, 1, "TheTempleofAhnQiraj", 2 },
			{ "Battleguard Sartura", 88, 10, 1, "TheTempleofAhnQiraj", 3 },
			{ "Fankriss the Unyielding", 12, 50, 1, "TheTempleofAhnQiraj", 4 },
			{ "Viscidus", 50, 50, 1, "TheTempleofAhnQiraj", 5 },
			{ "Princess Huhuran", 88, 50, 1, "TheTempleofAhnQiraj", 6 },
			{ "Twin Emperors", 12, 90, 1, "TheTempleofAhnQiraj", 7 },
			{ "Ouro", 50, 90, 1, "TheTempleofAhnQiraj", 8 },
			{ "C'Thun", 88, 90, 1, "TheTempleofAhnQiraj", 9 },
		},
	},
	[532] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Attumen the Huntsman", 44.4, 71.6, 1, "Karazhan", 1 },
			-- The Servants' Quarters rares are script-summoned with no
			-- static spawn; anchored to the trash packs they spawn among.
			{ "Rokad the Ravager", 66.4, 17.0, 1, "Karazhan", 2 },
			{ "Shadikith the Glider", 56.8, 23.6, 1, "Karazhan", 3 },
			{ "Hyakiss the Lurker", 53.7, 41.5, 1, "Karazhan", 4 },
			{ "Moroes", 26.3, 55.3, 3, "Karazhan", 5 },
			{ "Maiden of Virtue", 81.7, 43.1, 4, "Karazhan", 6 },
			{ "The Wizard of Oz", 15.5, 27.7, 4, "Karazhan", 7 },
			{ "The Big Bad Wolf", 19.3, 27.9, 4, "Karazhan", 8 },
			{ "Romulo and Julianne", 17.6, 33, 4, "Karazhan", 9 },
			{ "The Curator", 48.4, 31.6, 9, "Karazhan", 10 },
			{ "Terestian Illhoof", 51.8, 60.6, 11, "Karazhan", 11 },
			{ "Shade of Aran", 70, 22.7, 10, "Karazhan", 12 },
			{ "Netherspite", 35.3, 36.5, 13, "Karazhan", 13 },
			{ "Chess Event", 35.2, 54, 14, "Karazhan", 14 },
			{ "Prince Malchezaar", 50.4, 27.1, 17, "Karazhan", 15 },
			{ "Nightbane", 46.1, 79.6, 6, "Karazhan", 16 },
		},
	},
	[533] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			-- Wing positions from Blizzard's journal pins; Sapphiron and
			-- Kel'Thuzad share one journal map while our art gives each
			-- its own floor, so those two are centred approximations.
			{ "Anub'Rekhan", 30, 40.9, 1, "Naxxramas", 1 },
			{ "Grand Widow Faerlina", 43.2, 31.4, 1, "Naxxramas", 2 },
			{ "Maexxna", 67.2, 13.3, 1, "Naxxramas", 3 },
			{ "Noth the Plaguebringer", 30, 40.7, 2, "Naxxramas", 4 },
			{ "Heigan the Unclean", 43.1, 31.3, 2, "Naxxramas", 5 },
			{ "Loatheb", 67.1, 13.2, 2, "Naxxramas", 6 },
			{ "Instructor Razuvious", 41.8, 40, 3, "Naxxramas", 7 },
			{ "Gothik the Harvester", 66.1, 51.9, 3, "Naxxramas", 8 },
			{ "The Four Horsemen", 29.5, 66.8, 3, "Naxxramas", 9 },
			{ "Patchwerk", 74.1, 24.6, 4, "Naxxramas", 10 },
			{ "Grobbulus", 64.9, 47.5, 4, "Naxxramas", 11 },
			{ "Gluth", 48.7, 39.5, 4, "Naxxramas", 12 },
			{ "Thaddius", 33.9, 49.2, 4, "Naxxramas", 13 },
			{ "Sapphiron", 52.1, 43.1, 5, "Naxxramas", 14 },
			{ "Kel'Thuzad", 35.7, 19.5, 6, "Naxxramas", 15 },
		},
	},
	[534] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Rage Winterchill", 12, 10, 1, "HyjalSummit", 1 },
			{ "Anetheron", 50, 10, 1, "HyjalSummit", 2 },
			{ "Kaz'rogal", 88, 10, 1, "HyjalSummit", 3 },
			{ "Azgalor", 12, 90, 1, "HyjalSummit", 4 },
			{ "Archimonde", 50, 90, 1, "HyjalSummit", 5 },
		},
	},
	[540] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Grand Warlock Nethekurse", 32.5, 53.9, 1, "TheShatteredHalls", 1 },
			{ "Blood Guard Porung", 29, 13.1, 1, "TheShatteredHalls", 2 },
			{ "Warbringer O'mrogg", 52.6, 29.7, 1, "TheShatteredHalls", 3 },
			{ "Warchief Kargath Bladefist", 66.1, 47.4, 1, "TheShatteredHalls", 4 },
		},
	},
	[542] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "The Maker", 37.6, 36.2, 1, "TheBloodFurnace", 1 },
			{ "Broggok", 42.1, 18.6, 1, "TheBloodFurnace", 2 },
			{ "Keli'dan the Breaker", 57.2, 35.8, 1, "TheBloodFurnace", 3 },
		},
	},
	[543] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			-- coords calibrated in-game via /sdm calib
			{ "Watchkeeper Gargolmar", 71.4, 27.3, 1, "HellfireRamparts", 1 },
			{ "Omor the Unscarred", 38.2, 17.6, 1, "HellfireRamparts", 2 },
			{ "Nazan & Vazruden", 34.6, 71.6, 1, "HellfireRamparts", 3 },
		},
	},
	[544] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Magtheridon", 67.4, 64.6, 1, "MagtheridonsLair", 1 },
		},
	},
	[545] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Hydromancer Thespia", 53.1, 11.7, 1, "TheSteamvault", 1 },
			{ "Mekgineer Steamrigger", 33.2, 71.5, 1, "TheSteamvault", 2 },
			{ "Warlord Kalithresh", 74.6, 38.1, 1, "TheSteamvault", 3 },
		},
	},
	[546] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Hungarfen", 67.7, 78.4, 1, "TheUnderbog", 1 },
			{ "Ghaz'an", 76.8, 24.7, 1, "TheUnderbog", 2 },
			{ "Swamplord Musel'ek", 40.6, 21.5, 1, "TheUnderbog", 3 },
			{ "The Black Stalker", 24.2, 39.7, 1, "TheUnderbog", 4 },
		},
	},
	[547] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Mennu the Betrayer", 47.8, 23.2, 1, "TheSlavePens", 1 },
			{ "Rokmar the Crackler", 56.4, 35.2, 1, "TheSlavePens", 2 },
			{ "Quagmirran", 80.1, 66.8, 1, "TheSlavePens", 3 },
			{ "Ahune <The Frost Lord>", 66.7, 50.2, 1, "TheSlavePens", 4 },
		},
	},
	[548] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Hydross the Unstable", 35.6, 73.5, 1, "SerpentshrineCavern", 1 },
			{ "The Lurker Below", 39, 50.8, 1, "SerpentshrineCavern", 2 },
			{ "Leotheras the Blind", 40.9, 22.4, 1, "SerpentshrineCavern", 3 },
			{ "Fathom-Lord Karathress", 49.2, 15.1, 1, "SerpentshrineCavern", 4 },
			{ "Morogrim Tidewalker", 58.4, 22.8, 1, "SerpentshrineCavern", 5 },
			{ "Lady Vashj", 70.7, 51.4, 1, "SerpentshrineCavern", 6 },
		},
	},
	[550] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Al'ar", 49, 51.1, 1, "TempestKeep", 1 },
			{ "Void Reaver", 25.6, 42.7, 1, "TempestKeep", 2 },
			{ "High Astromancer Solarian", 72.3, 42.6, 1, "TempestKeep", 3 },
			-- Blizzard's retail journal pin, which agrees with the spawn
			-- data projection within a grid unit. The old entry was a
			-- leftover placeholder cell mislinked to the Magisters' Terrace
			-- loot page.
			{ "Kael'thas Sunstrider", 49.0, 12.0, 1, "TempestKeep", 4 },
		},
	},
	[552] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Zereketh the Unbound", 57.8, 20.7, 1, "TheArcatraz", 1 },
			{ "Dalliah the Doomsayer", 35.4, 67.8, 2, "TheArcatraz", 2 },
			{ "Wrath-Scryer Soccothrates", 19.6, 68.1, 2, "TheArcatraz", 3 },
			{ "Harbinger Skyriss", 60.3, 26.4, 3, "TheArcatraz", 4 },
		},
	},
	[553] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Commander Sarannis", 43.6, 19.7, 1, "TheBotanica", 1 },
			{ "High Botanist Freywinn", 23.6, 19.7, 1, "TheBotanica", 2 },
			{ "Thorngrin the Tender", 6.7, 41.6, 1, "TheBotanica", 3 },
			{ "Laj", 33.5, 75.4, 1, "TheBotanica", 4 },
			{ "Warp Splinter", 33.4, 31.8, 1, "TheBotanica", 5 },
		},
	},
	[554] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Mechano-Lord Capacitus", 50, 27.2, 1, "TheMechanar", 1 },
			{ "Nethermancer Sepethrea", 46.6, 17.1, 2, "TheMechanar", 2 },
			{ "Pathaleon the Calculator", 26.6, 53.2, 2, "TheMechanar", 3 },
			{ "Cache of the Legion", 37.7, 24.6, 1, "TheMechanar", 4 },
			{ "Gatewatcher Gyro-Kill", 44.8, 49.8, 1, "TheMechanar", 5 },
			{ "Gatewatcher Iron-Hand", 59.2, 33.5, 1, "TheMechanar", 6 },
		},
	},
	[555] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Ambassador Hellmaw", 21.4, 34.2, 1, "ShadowLabyrinth", 1 },
			{ "Blackheart the Inciter", 26.3, 61.3, 1, "ShadowLabyrinth", 2 },
			{ "Grandmaster Vorpil", 52.4, 46.6, 1, "ShadowLabyrinth", 3 },
			{ "Murmur", 79.4, 33.9, 1, "ShadowLabyrinth", 4 },
		},
	},
	[556] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Darkweaver Syth", 47.7, 58.8, 1, "SethekkHalls", 1 },
			{ "Talon King Ikiss", 31.9, 24, 2, "SethekkHalls", 2 },
			{ "Anzu", 31.7, 47.4, 2, "SethekkHalls", 3 },
		},
	},
	[557] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Pandemonius", 47.1, 25.4, 1, "Mana-Tombs", 1 },
			{ "Tavarok", 59.2, 64.1, 1, "Mana-Tombs", 2 },
			{ "Nexus-Prince Shaffar", 31.9, 42.6, 1, "Mana-Tombs", 3 },
		},
	},
	[558] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Shirrak the Dead Watcher", 45.3, 58.3, 2, "AuchenaiCrypts", 1 },
			{ "Exarch Maladaar", 72.3, 43.2, 2, "AuchenaiCrypts", 2 },
		},
	},
	[560] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Lieutenant Drake", 73.7, 57.3, 1, "OldHillsbradFoothills", 1 },
			{ "Captain Skarloc", 67.8, 60, 1, "OldHillsbradFoothills", 2 },
			{ "Epoch Hunter", 49.5, 27.7, 1, "OldHillsbradFoothills", 3 },
			{ "Don Carlos", 43.6, 47.4, 1, "OldHillsbradFoothills", 4 },
		},
	},
	[564] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "High Warlord Naj'entus", 43, 16.3, 1, "BlackTemple", 1 },
			{ "Supremus", 40.1, 77.2, 2, "BlackTemple", 2 },
			{ "Shade of Akama", 52.7, 40.9, 3, "BlackTemple", 3 },
			{ "Gurtogg Bloodboil", 88, 10, 1, "BlackTemple", 4 },
			{ "Reliquary of the Lost", 12, 50, 1, "BlackTemple", 5 },
			{ "Teron Gorefiend", 37.3, 50, 1, "BlackTemple", 6 },
			{ "Mother Shahraz", 62.7, 50, 1, "BlackTemple", 7 },
			{ "The Illidari Council", 88, 50, 1, "BlackTemple", 8 },
			{ "Illidan Stormrage", 12, 90, 1, "BlackTemple", 9 },
			{ "Patterns", 12, 90, 1, "SunwellPlateau", 7 },
		},
	},
	[565] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "High King Maulgar", 53.9, 50.3, 1, "GruulsLair", 1 },
			{ "Gruul the Dragonkiller", 19.8, 25, 1, "GruulsLair", 2 },
		},
	},
	[568] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Akil'zon", 12, 10, 1, "ZulAman", 1 },
			{ "Nalorakk", 50, 10, 1, "ZulAman", 2 },
			{ "Jan'alai", 88, 10, 1, "ZulAman", 3 },
			{ "Halazzi", 12, 50, 1, "ZulAman", 4 },
			{ "Hex Lord Malacrass", 50, 50, 1, "ZulAman", 5 },
			{ "Zul'jin", 88, 50, 1, "ZulAman", 6 },
			{ "Timed Chest", 12, 90, 1, "ZulAman", 7 },
		},
	},
	[580] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			{ "Kalecgos", 12, 10, 1, "SunwellPlateau", 1 },
			{ "Brutallus", 50, 10, 1, "SunwellPlateau", 2 },
			{ "Felmyst", 88, 10, 1, "SunwellPlateau", 3 },
			{ "Eredar Twins", 12, 50, 1, "SunwellPlateau", 4 },
			{ "M'uru", 50, 50, 1, "SunwellPlateau", 5 },
			{ "Kil'jaeden", 88, 50, 1, "SunwellPlateau", 6 },
			{ "Patterns", 12.0, 90.0, 1, "SunwellPlateau", 7 },
		},
	},
	[585] = {
		atlasModule = "AtlasLootClassic_DungeonsAndRaids",
		bosses = {
			-- From retail's JournalEncounter pins (Magisters' Terrace is a
			-- timewalking dungeon there): floor 1 is the entrance level
			-- (Assembly Chamber rooms), floor 2 the Asylum level, per the
			-- WMOAreaTable rooms of retail uiMaps 349 and 348.
			{ "Selin Fireheart", 41.6, 19.4, 1, "MagistersTerrace", 1 },
			{ "Vexallus", 81.7, 23, 1, "MagistersTerrace", 2 },
			{ "Priestess Delrissa", 38.9, 48.4, 2, "MagistersTerrace", 3 },
			{ "Kael'thas Sunstrider", 8.4, 43.7, 2, "MagistersTerrace", 4 },
		},
	},
}

-- Stair/passage markers (calibrated in-game; see /sdm stairpins + calib).
-- ns.dungeonStairs[instanceMapID][srcFloor][targetFloor] = { x, y }
-- Baked from SavedVariables stairOverrides via tools/bake_stairs.py.
ns.dungeonStairs = {
	[33] = {
		[1] = { [2] = { 14.6, 74.9 }, [7] = { 35.1, 58.1 } },
		[2] = { [1] = { 26.1, 79.2 } },
		[3] = { [4] = { 51.7, 76.7 }, [7] = { 52.3, 52.3 } },
		[4] = { [3] = { 51.5, 78.2 }, [5] = { 43.4, 65.5 } },
		[5] = { [4] = { 47.8, 69.1 }, [6] = { 43.1, 65.5 } },
		[6] = { [5] = { 41, 74.4 } },
		[7] = { [1] = { 23.8, 65.5 }, [3] = { 40.8, 27.1 } },
	},
	[36] = {
		[1] = { [2] = { 64, 58.3 } },
		[2] = { [1] = { 12.1, 76.6 } },
	},
	[48] = {
		[1] = { [2] = { 60.4, 62.2 } },
		[2] = { [1] = { 33.7, 25.9 }, [3] = { 46.1, 62.8 } },
		[3] = { [2] = { 39.8, 55.7 } },
	},
	[70] = {
		[1] = { [2] = { 47, 18.4 }, [18] = { 66, 62.7 } },
		[2] = { [1] = { 63.5, 37.6 } },
		[18] = { [1] = { 35.9, 25 } },
	},
	[90] = {
		[1] = { [2] = { 34.3, 55.4 } },
		[2] = { [1] = { 60, 54.6 }, [3] = { 41.8, 72 } },
		[3] = { [4] = { 49.1, 60.3 } },
		[4] = { [3] = { 69.9, 67.7 } },
	},
	[329] = {
		[1] = { [2] = { 88.2, 28.1 } },
	},
	[349] = {
		[1] = { [2] = { 15.2, 50.3 } },
		[2] = { [1] = { 27.8, 5.1 } },
	},
	[429] = {
		[5] = { [6] = { 48.9, 54.5 } },
		[6] = { [5] = { 61.7, 73.2 } },
	},
	[532] = {
		[1] = { [3] = { 52, 55 } },
		[3] = { [1] = { 51.6, 80.7 }, [4] = { 69.7, 32.1 } },
		[4] = { [3] = { 70.3, 38.5 }, [5] = { 23.1, 42.6 } },
		[5] = { [4] = { 41.8, 73 }, [6] = { 61.6, 17.7 } },
		[6] = { [5] = { 40, 11.8 }, [7] = { 65.5, 57.9 } },
		[7] = { [6] = { 67.1, 57.3 }, [8] = { 53.2, 52.5 } },
		[8] = { [7] = { 57.6, 48.7 }, [9] = { 52.8, 43.9 } },
		[9] = { [8] = { 61.1, 19.5 }, [10] = { 30.1, 56 } },
		[10] = { [9] = { 31.4, 53.8 }, [11] = { 35.3, 17.3 }, [12] = { 59.8, 51.2 } },
		[11] = { [10] = { 63.9, 22.9 } },
		[12] = { [10] = { 45.1, 46.7 }, [13] = { 40.3, 13.7 }, [14] = { 38.1, 21.7 } },
		[13] = { [12] = { 53.3, 69.7 } },
		[14] = { [12] = { 19.6, 71.8 }, [16] = { 81.1, 47.8 } },
		[16] = { [14] = { 67.7, 68.6 }, [17] = { 59.9, 63.6 } },
		[17] = { [16] = { 50.5, 76.1 } },
	},
	[552] = {
		[1] = { [2] = { 67.2, 23.9 } },
		[2] = { [1] = { 87.4, 37.8 }, [3] = { 43.9, 49.3 } },
	},
	[554] = {
		[1] = { [2] = { 41.1, 17.1 } },
		[2] = { [1] = { 41.1, 30.7 } },
	},
	[556] = {
		[1] = { [2] = { 52.4, 81.8 } },
		[2] = { [1] = { 52.2, 83 } },
	},
	[558] = {
		[1] = { [2] = { 49.5, 19.7 } },
		[2] = { [1] = { 23.9, 11.2 } },
	},
}

-- Placeholder boss layouts
----------------------------------------------------
-- Some dungeons in the table above have no real boss coordinates. The
-- bosses were laid out on an even grid instead -- Scholomance is five
-- columns by four rows, every entry on floor 1 -- which renders as a neat
-- lattice of skulls across the map with no relation to where anything is.
--
-- Detected rather than hand-listed, so edits to the table can't
-- silently reintroduce a grid we have not noticed. A layout counts as
-- placeholder when every boss sits on one floor, the distinct x and y
-- values are few and evenly spaced, and the grid they form is big enough
-- to hold them all.
local LooksLikeGrid = function(bosses)
	if (#bosses < 6) then
		return false
	end

	local xs, ys, floors = {}, {}, {}

	for _, boss in ipairs(bosses) do
		xs[boss[2]] = true
		ys[boss[3]] = true
		floors[boss[4]] = true
	end

	local floorCount = 0
	for _ in pairs(floors) do floorCount = floorCount + 1 end
	if (floorCount ~= 1) then
		return false
	end

	local xList, yList = {}, {}
	for value in pairs(xs) do xList[#xList + 1] = value end
	for value in pairs(ys) do yList[#yList + 1] = value end

	if (#xList > 6) or (#yList > 6) or (#xList * #yList < #bosses) then
		return false
	end

	table.sort(xList)
	table.sort(yList)

	local EvenlySpaced = function(list)
		if (#list < 3) then
			return true
		end
		local step = list[2] - list[1]
		for i = 3, #list do
			if (math.abs((list[i] - list[i - 1]) - step) > .6) then
				return false
			end
		end
		return true
	end

	return EvenlySpaced(xList) and EvenlySpaced(yList)
end

ns.unpositionedBosses = {}

for instanceMapID, entry in pairs(ns.dungeonBosses) do
	if (entry.bosses) and (LooksLikeGrid(entry.bosses)) then
		ns.unpositionedBosses[instanceMapID] = true
	end
end
