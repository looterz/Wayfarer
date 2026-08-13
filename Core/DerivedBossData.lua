local _, ns = ...

-- AUTO-GENERATED. Do not edit by hand; regenerate with
-- Scripts/derive_boss_positions.py (see Scripts/derive-boss-positions.md).
--
-- Boss positions for the dungeons whose DungeonData coordinates were a
-- placeholder grid. Derived from game data, not authored:
--
--   Blizzard encounter pins   the game's own JournalEncounter records
--                             (Blackrock Depths, BWL, AQ20, AQ40,
--                             Sunwell), uiMapID = floor
--   creature spawn coords     1.12 and TBC spawn data, projected
--                             through the UiMapAssignment world rects
--                             of build 2.5.6.69110, whose dungeon
--                             uiMaps still describe the vanilla layouts
--   floors                    per-boss, resolved by joining each uiMap's
--                             WMO groups to WMOAreaTable room names
--
-- Event-only bosses are anchored to where their event happens (Ring of
-- Law arena, the Dark Coffer, the Headmaster's Study). Positions are
-- flagged derived, drawn in a different colour, and say so on hover.
--
-- Blackrock Spire's map art draws the spire inside wide parchment
-- margins, so its transform was fitted from the full spawn cloud onto
-- the drawn outline and checked against the skull icons baked into the
-- art. Floors come from each boss's known room; event bosses without a
-- static spawn are anchored near where their event happens.
ns.derivedBosses = {
	-- BlackrockSpire: 27 of 27 bosses placed
	[229] = {
		{ "Burning Felguard", 48.1, 46.9, 1 },
		{ "Spirestone Butcher", 42.0, 54.2, 3 },
		{ "Highlord Omokk", 31.0, 51.9, 3 },
		{ "Spirestone Battle Lord", 31.8, 56.6, 3 },
		{ "Spirestone Lord Magus", 33.6, 57.6, 3 },
		{ "Shadow Hunter Vosh'gajin", 54.1, 67.5, 3 },
		{ "War Master Voone", 51.1, 49.9, 1 },
		{ "Bannok Grimaxe", 45.8, 56.3, 1 },
		{ "Mother Smolderweb", 64.7, 69.7, 1 },
		{ "Crystal Fang", 52.4, 70.2, 1 },
		{ "Urok Doomhowl", 33.5, 54.4, 3 },
		{ "Quartermaster Zigris", 53.2, 78.5, 3 },
		{ "Halycon", 35.8, 78.9, 4 },
		{ "Gizrul the Slavener", 38.3, 81.4, 4 },
		{ "Ghok Bashguud", 33.3, 59.8, 3 },
		{ "Overlord Wyrmthalak", 54.6, 51.9, 6 },
		{ "Mor Grayhoof", 53.6, 52.4, 1 },
		{ "Pyroguard Emberseer", 25.6, 25.5, 2 },
		{ "Solakar Flamewreath", 28.6, 28.5, 2 },
		{ "Jed Runewatcher", 25.6, 25.5, 2 },
		{ "Goraluk Anvilcrack", 24.5, 26.1, 5 },
		{ "Gyth", 59.2, 30.5, 7 },
		{ "Warchief Rend Blackhand", 59.2, 33.0, 7 },
		{ "The Beast", 63.2, 34.5, 7 },
		{ "General Drakkisath", 29.1, 42.6, 7 },
		{ "Darkstone Tablet", 31.6, 45.1, 7 },
		{ "Lord Valthalak", 66.2, 37.5, 7 },
	},
	-- BlackrockDepths: 29 of 30 bosses placed
	[230] = {
		{ "Lord Roccor", 54.8, 58.1, 1 },
		{ "High Interrogator Gerstahn", 46.4, 80.2, 1 },
		{ "Houndmaster Grebmar", 52.4, 49.9, 1 },
		{ "Grizzle", 46.2, 78.1, 2 },
		{ "Eviscerator", 48.7, 78.1, 2 },
		{ "Ok'thor the Breaker", 51.2, 78.1, 2 },
		{ "Anub'shiah", 46.2, 81.1, 2 },
		{ "Hedrum the Creeper", 48.7, 81.1, 2 },
		{ "Dark Coffer", 60.3, 60.2, 2 },
		{ "Warder Stilgiss", 58.3, 57.1, 2 },
		{ "Verek", 59.3, 58.7, 2 },
		{ "Watchman Doomgrip", 61.8, 60.2, 2 },
		{ "Fineous Darkvire", 62.2, 18.4, 1 },
		{ "Lord Incendius", 55.2, 27.1, 1 },
		{ "Bael'Gar", 25.1, 46, 1 },
		{ "General Angerforge", 35.6, 71.7, 2 },
		{ "Golem Lord Argelmach", 35.7, 56.7, 2 },
		{ "Guzzler", 48.7, 55.4, 2 },
		{ "Phalanx", 44.8, 49.1, 2 },
		{ "Ambassador Flamelash", 52.7, 42.2, 2 },
		{ "Panzor the Invincible", 49.4, 28.2, 2 },
		{ "Chest of The Seven", 55.7, 20.3, 2 },
		{ "Magmus", 78.4, 10.1, 2 },
		{ "Princess Moira Bronzebeard", 91.1, 10, 2 },
		{ "Emperor Dagran Thaurissan", 89, 10.3, 2 },
		{ "Theldren", 51.2, 81.1, 2 },
		{ "Coren Direbrew", 46.7, 51.4, 2 },
		{ "Gorosh the Dervish", 48.7, 83.1, 2 },
		{ "Pyromancer Loregrain", 53.7, 82.5, 2 },
	},
	-- Scholomance: 16 of 17 bosses placed
	[289] = {
		{ "Blood Steward of Kirtonos", 63.8, 52.3, 1 },
		{ "Kirtonos the Herald", 63.9, 55.5, 1 },
		{ "Jandice Barov", 47.4, 22.5, 2 },
		{ "Rattlegore", 31.1, 59.5, 2 },
		{ "Death Knight Darkreaver", 34.1, 62.5, 2 },
		{ "Marduk Blackpool", 43.4, 55.5, 2 },
		{ "Vectus", 47.2, 57.6, 2 },
		{ "Ras Frostwhisper", 39.7, 76.9, 4 },
		{ "Instructor Malicia", 71.2, 70.3, 3 },
		{ "Doctor Theolen Krastinov", 93.5, 39.9, 3 },
		{ "Lorekeeper Polkelt", 70.4, 10.4, 3 },
		{ "The Ravenian", 66.1, 45.3, 4 },
		{ "Lord Alexei Barov", 82.5, 26.8, 4 },
		{ "Lady Illucia Barov", 65.6, 5.3, 4 },
		{ "Darkmaster Gandling", 54, 21.3, 4 },
		{ "Lord Blackwood", 30.7, 47.9, 1 },
	},
	-- BlackwingLair: 8 of 8 bosses placed
	[469] = {
		{ "Razorgore the Untamed", 41.0, 52.4, 1 },
		{ "Vaelastrasz the Corrupt", 32.6, 24.0, 1 },
		{ "Broodlord Lashlayer", 49.5, 53.7, 3 },
		{ "Firemaw", 45.4, 37.4, 3 },
		{ "Ebonroc", 34.2, 18.2, 3 },
		{ "Flamegor", 34.8, 32.3, 4 },
		{ "Chromaggus", 38.6, 63.2, 4 },
		{ "Nefarian", 68.9, 63.0, 4 },
	},
	-- RuinsofAhnQiraj: 6 of 7 bosses placed
	[509] = {
		{ "Kurinnaxx", 55.1, 31.1, 1 },
		{ "General Rajaxx", 57.1, 42.7, 1 },
		{ "Moam", 32.2, 31.4, 1 },
		{ "Buru the Gorger", 68.3, 54.0, 1 },
		{ "Ayamiss the Hunter", 60.4, 78.7, 1 },
		{ "Ossirian the Unscarred", 42.0, 60.5, 1 },
	},
	-- AhnQiraj: 9 of 9 bosses placed
	[531] = {
		{ "The Prophet Skeram", 44.8, 45.4, 2 },
		{ "Bug Trio", 27.8, 43.3, 1 },
		{ "Battleguard Sartura", 43.6, 29.2, 1 },
		{ "Fankriss the Unyielding", 61.0, 19.0, 1 },
		{ "Viscidus", 70.6, 15.6, 1 },
		{ "Princess Huhuran", 42.6, 43.8, 1 },
		{ "Twin Emperors", 59.4, 60.7, 1 },
		{ "Ouro", 29.5, 71.2, 1 },
		{ "C'Thun", 55.8, 54.4, 3 },
	},
	-- ZulAman: 6 of 7 bosses placed
	[568] = {
		{ "Akil'zon", 34.3, 19.8, 1 },
		{ "Nalorakk", 33.7, 56.7, 1 },
		{ "Jan'alai", 54.1, 60.4, 1 },
		{ "Halazzi", 55.2, 20.4, 1 },
		{ "Hex Lord Malacrass", 65.0, 46.3, 1 },
		{ "Zul'jin", 90.8, 46.1, 1 },
	},
	-- SunwellPlateau: 6 of 7 bosses placed
	[580] = {
		{ "Kalecgos", 30.0, 44.4, 1 },
		{ "Brutallus", 64.5, 75.2, 1 },
		{ "Felmyst", 71.2, 71.9, 1 },
		{ "Eredar Twins", 62.8, 27.9, 1 },
		{ "M'uru", 62.7, 28.3, 1 },
		{ "Kil'jaeden", 62.4, 45.2, 1 },
	},
}

