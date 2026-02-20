---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

---@class LibsTimePlayed.Database : AceModule
local Database = LibsTimePlayed:NewModule('Database')
LibsTimePlayed.Database = Database

local defaults = {
	global = {
		characters = {
			-- ["RealmName-CharName"] = { name, realm, class, classFile, level, totalPlayed, levelPlayed, lastUpdated }
		},
		importHistory = {
			-- { source, timestamp, charactersImported, charactersSkipped, strategy }
		},
		firstTimeImportOffered = false, -- Track if we've offered first-time import
		streaks = {
			dailyLog = {}, -- ["2026-02-08"] = { totalSeconds = 7200, sessions = 2 }
			currentStreak = 0,
			longestStreak = 0,
			longestStreakStart = '',
			longestStreakEnd = '',
			longestWeekStreak = 0,
			totalSessions = 0,
		},
	},
	profile = {
		display = {
			format = 'total', -- 'total', 'session', 'level'
			timeFormat = 'smart', -- 'smart', 'full', 'hours'
			groupBy = 'class', -- 'class', 'realm', 'faction', 'none'
			fontSize = 10, -- popup window font size (8-16)
			showMilestones = true,
			showStreaks = true,
		},
		popup = {
			width = 700,
			height = 300,
			point = 'CENTER',
			x = 0,
			y = 0,
		},
		minimap = {
			hide = false,
		},
	},
}

function Database:OnInitialize()
	LibsTimePlayed.dbobj = LibStub('AceDB-3.0'):New('LibsTimePlayedDB', defaults, true)
	LibsTimePlayed.db = LibsTimePlayed.dbobj.profile
	LibsTimePlayed.globaldb = LibsTimePlayed.dbobj.global
end
