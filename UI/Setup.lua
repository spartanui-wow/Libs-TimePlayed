---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

-- First-run steps for the shared Libs-AddonTools setup window (LibAT.Setup).
-- Without LibAT.Setup, the first-time import popup in Core/Import.lua is used instead.

local SETUP_ID = 'libs-timeplayed'

-- Sources the import step offers, in the order they are shown
local IMPORT_SOURCES = { 'AltVault', 'Altoholic' }

---Build one import source. Its caption is refreshed each time the step checks for it.
---@param sourceName string
---@return table source
local function ImportSource(sourceName)
	local source = { id = sourceName, title = sourceName }
	source.detect = function()
		local count = LibsTimePlayed.Import and LibsTimePlayed.Import:CountImportable(sourceName) or 0
		source.caption = count == 1 and '1 character with its played time.' or (count .. ' characters with their played time.')
		return count > 0
	end
	source.apply = function()
		LibsTimePlayed.Import:ImportForSetup(sourceName)
	end
	return source
end

---Register with the setup window. Called from OnInitialize, before the Database module creates the
---saved data, so a new install can still be told apart from an existing one.
function LibsTimePlayed:RegisterSetup()
	if self.setupRegistration or not LibAT or not LibAT.Setup or type(LibAT.Setup.Register) ~= 'function' then
		return
	end
	local reg = LibAT.Setup:Register(SETUP_ID, {
		name = self.addonName,
		icon = 'Interface\\Icons\\INV_Misc_PocketWatch_01',
		summary = 'Shows how long you have played each of your characters.',
		priority = 70,
		isExistingUser = function()
			return type(LibsTimePlayedDB) == 'table' and next(LibsTimePlayedDB) ~= nil
		end,
		optionsCommand = '/libstp options',
	})
	if not reg then
		return
	end
	self.setupRegistration = reg

	local sources = {}
	for _, sourceName in ipairs(IMPORT_SOURCES) do
		sources[#sources + 1] = ImportSource(sourceName)
	end
	-- Hidden by the setup window when none of the sources has characters
	reg:AddStep({
		id = 'import',
		kind = 'import',
		name = 'Your characters',
		title = 'Bring in your other characters?',
		text = 'Another addon already knows how long you played them. This happens when you finish setup.',
		order = 10,
		sources = sources,
	})

	reg:AddStep({
		id = 'format',
		kind = 'choice',
		name = 'What it shows',
		title = 'Which time should it show?',
		text = 'This is the text on your info bar. Left-click it to switch.',
		order = 20,
		choices = {
			{ value = 'total', title = 'All my time', caption = 'Everything you played on this character.', recommended = true },
			{ value = 'session', title = 'This session', caption = 'Time since you logged in.' },
			{ value = 'level', title = 'This level', caption = 'Time spent on your current level.' },
			{ value = 'account', title = 'All my characters', caption = 'Everything you played on every character.' },
		},
		get = function()
			return LibsTimePlayed.db.display.format
		end,
		set = function(value)
			LibsTimePlayed.db.display.format = value
			LibsTimePlayed:UpdateDisplay()
		end,
	})

	reg:AddStep({
		id = 'groupBy',
		kind = 'choice',
		name = 'Your list',
		title = 'How should your characters be grouped?',
		text = 'This is for the list in the tooltip and the window.',
		order = 30,
		choices = {
			{ value = 'class', title = 'By class', caption = 'Characters of the same class together.', recommended = true },
			{ value = 'realm', title = 'By realm', caption = 'Characters on the same realm together.' },
			{ value = 'faction', title = 'By faction', caption = 'Alliance and Horde apart.' },
			{ value = 'none', title = 'One list', caption = 'All your characters in one list.' },
		},
		get = function()
			return LibsTimePlayed.db.display.groupBy
		end,
		set = function(value)
			LibsTimePlayed.db.display.groupBy = value
			LibsTimePlayed:UpdateDisplay()
		end,
	})
end
