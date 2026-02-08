---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

local defaults = {
	global = {
		characters = {
			-- ["RealmName-CharName"] = { name, realm, class, classFile, level, totalPlayed, levelPlayed, lastUpdated }
		},
		importHistory = {
			-- { source, timestamp, charactersImported, charactersSkipped, strategy }
		},
		firstTimeImportOffered = false, -- Track if we've offered first-time import
	},
	profile = {
		display = {
			format = 'total', -- 'total', 'session', 'level'
			timeFormat = 'smart', -- 'smart', 'full', 'hours'
			groupBy = 'class', -- 'class', 'realm', 'faction', 'none'
			showMilestones = true,
		},
		popup = {
			width = 520,
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

function LibsTimePlayed:InitializeDatabase()
	self.dbobj = LibStub('AceDB-3.0'):New('LibsTimePlayedDB', defaults, true)
	self.db = self.dbobj.profile
	self.globaldb = self.dbobj.global
end
