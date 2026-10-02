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
	-- The only question: the time it shows and how the list is grouped have good defaults and change
	-- with a click on the bar. Hidden by the setup window when no source has characters, so most
	-- players never see a Time Played page at all.
	reg:AddStep({
		id = 'import',
		kind = 'import',
		name = 'Your characters',
		title = 'Bring in your other characters?',
		text = 'Another addon already knows how long you played them. This happens when you finish setup.',
		order = 10,
		-- Nothing to ask once Time Played has data of its own: an import already ran, the import was
		-- already offered, or it already knows more than one character
		hidden = function()
			local db = LibsTimePlayed.globaldb
			if not db then
				return false
			end
			if db.firstTimeImportOffered or (db.importHistory and #db.importHistory > 0) then
				return true
			end
			local count = 0
			for _ in pairs(db.characters or {}) do
				count = count + 1
				if count > 1 then
					return true
				end
			end
			return false
		end,
		sources = sources,
	})
end
