---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

---@class LibsTimePlayed.Import
local Import = {}
LibsTimePlayed.Import = Import

---Create a styled button, using LibAT.UI when available, falling back to UIPanelButtonTemplate
---@param parent Frame
---@param width number
---@param height number
---@param text string
---@return Button
local function CreateStyledButton(parent, width, height, text)
	if LibAT and LibAT.UI and LibAT.UI.CreateButton then
		return LibAT.UI.CreateButton(parent, width, height, text, true)
	end
	local btn = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
	btn:SetSize(width, height)
	btn:SetText(text)
	return btn
end

-- Available import sources
local IMPORT_SOURCES = {
	AltVault = 'AltVaultDB',
	Altoholic = 'DataStore_CharacterDB',
}

-- Merge strategies
local MERGE_STRATEGIES = {
	PREFER_IMPORTED = 'prefer_imported',
	PREFER_EXISTING = 'prefer_existing',
	NEWEST_WINS = 'newest_wins',
	MAX_VALUES = 'max_values',
}

-- Default merge strategy
local currentMergeStrategy = MERGE_STRATEGIES.NEWEST_WINS

---@class ImportSource
---@field available boolean Whether the source database is available
---@field characterCount number Number of characters found
---@field version string|number Source database version

---Get available import sources
---@return table<string, ImportSource>
function Import:GetAvailableSources()
	local sources = {}

	-- Check AltVault
	if _G.AltVaultDB and _G.AltVaultDB.characters then
		local count = 0
		for _ in pairs(_G.AltVaultDB.characters) do
			count = count + 1
		end
		sources.AltVault = {
			available = true,
			characterCount = count,
			version = (_G.AltVaultDB.data and _G.AltVaultDB.data.version) or 'Unknown',
		}
	else
		sources.AltVault = {
			available = false,
			characterCount = 0,
			version = nil,
		}
	end

	-- Check Altoholic
	if _G.DataStore_CharacterDB and _G.DataStore_CharacterDB.global and _G.DataStore_CharacterDB.global.Characters then
		local count = 0
		for _ in pairs(_G.DataStore_CharacterDB.global.Characters) do
			count = count + 1
		end
		sources.Altoholic = {
			available = true,
			characterCount = count,
			version = 'DataStore',
		}
	else
		sources.Altoholic = {
			available = false,
			characterCount = 0,
			version = nil,
		}
	end

	return sources
end

---Check if can import from a specific addon
---@param addonName string 'AltVault' or 'Altoholic'
---@return boolean
function Import:CanImportFrom(addonName)
	local sources = self:GetAvailableSources()
	return sources[addonName] and sources[addonName].available or false
end

---Convert AltVault lastPlayed table to Unix timestamp
---@param lastPlayed table {year, month, monthDay, hour, minute}
---@return number timestamp Unix timestamp
local function ConvertAltVaultTimestamp(lastPlayed)
	if not lastPlayed or type(lastPlayed) ~= 'table' then
		return 0
	end

	return time({
		year = lastPlayed.year or 2020,
		month = lastPlayed.month or 1,
		day = lastPlayed.monthDay or 1,
		hour = lastPlayed.hour or 0,
		min = lastPlayed.minute or 0,
		sec = 0,
	})
end

---Parse AltVault database
---@return table[] characters Array of normalized character data
function Import:ParseAltVault()
	if not self:CanImportFrom('AltVault') then
		return {}
	end

	local characters = {}
	local db = _G.AltVaultDB

	if not db or not db.characters then
		return {}
	end

	for _, entry in pairs(db.characters) do
		if type(entry) == 'table' and entry.character then
			local char = entry.character

			-- Extract required fields
			if char.played and char.name and char.realm then
				local normalizedChar = {
					source = 'AltVault',
					importedAt = time(),

					-- Identity
					name = char.name,
					realm = char.realm,
					guid = entry.GUID,

					-- Time-played data
					totalPlayed = char.played or 0,
					levelPlayed = char.playedAtLevel or 0,
					lastLogin = ConvertAltVaultTimestamp(char.lastPlayed),

					-- Character metadata
					level = char.level or 1,
					class = char.classKey or char.class or 'WARRIOR',
					race = char.raceKey or char.race or 'Unknown',
					faction = char.faction or 'Neutral',

					-- Optional context
					xp = char.xp,
					xpMax = char.xpMax,
					restedXP = char.restedXP,
				}

				table.insert(characters, normalizedChar)
			end
		end
	end

	return characters
end

---Parse Altoholic database
---@return table[] characters Array of normalized character data
function Import:ParseAltoholic()
	if not self:CanImportFrom('Altoholic') then
		return {}
	end

	local characters = {}
	local db = _G.DataStore_CharacterDB

	if not db or not db.global or not db.global.Characters then
		return {}
	end

	-- Check for bit64 library (needed for BaseInfo decoding)
	local bit64
	if LibStub then
		bit64 = LibStub('DataStore_bit64', true)
	end

	if not bit64 then
		LibsTimePlayed:Log('Cannot import from Altoholic: DataStore_bit64 library not found', 'warning')
		return {}
	end

	-- GUID lookup table
	local guids = _G.DataStore_CharacterGUIDs or {}

	for charKey, data in pairs(db.global.Characters) do
		if type(data) == 'table' and data.played then
			-- Parse charKey: "Default.RealmName.CharName"
			local parts = { strsplit('.', charKey) }
			local realm = parts[2] or 'Unknown'
			local name = parts[3] or 'Unknown'

			-- Decode BaseInfo
			local level = 1
			local classID = 1
			local raceID = 1

			if data.BaseInfo then
				level = bit64:GetBits(data.BaseInfo, 0, 7) or 1
				classID = bit64:GetBits(data.BaseInfo, 7, 4) or 1
				raceID = bit64:GetBits(data.BaseInfo, 11, 7) or 1
			end

			-- Convert class/race IDs to names
			local classInfo = C_CreatureInfo.GetClassInfo(classID)
			local raceInfo = C_CreatureInfo.GetRaceInfo(raceID)

			local className = classInfo and classInfo.classFile or 'WARRIOR'
			local raceName = raceInfo and raceInfo.clientFileString or 'Unknown'

			-- Determine faction from race
			local faction = 'Neutral'
			if raceInfo then
				if raceInfo.raceID then
					-- Horde races: 2=Orc, 5=Undead, 6=Tauren, 8=Troll, 9=Goblin, 10=BloodElf, 27=Nightborne, 28=HighmountainTauren, 31=ZandalariTroll, 32=KulTiran, 34=DarkIronDwarf, 35=Vulpera, 36=MagharOrc, 70=Dracthyr(Horde)
					-- Alliance races: 1=Human, 3=Dwarf, 4=NightElf, 7=Gnome, 11=Draenei, 22=Worgen, 24=PandarenAlliance, 29=VoidElf, 30=LightforgedDraenei, 32=KulTiran, 34=DarkIronDwarf, 37=Mechagnome, 52=Dracthyr(Alliance)
					local hordeRaces = { [2] = true, [5] = true, [6] = true, [8] = true, [9] = true, [10] = true, [27] = true, [28] = true, [31] = true, [35] = true, [36] = true }
					local allianceRaces = { [1] = true, [3] = true, [4] = true, [7] = true, [11] = true, [22] = true, [29] = true, [30] = true, [37] = true, [52] = true }

					if hordeRaces[raceInfo.raceID] then
						faction = 'Horde'
					elseif allianceRaces[raceInfo.raceID] then
						faction = 'Alliance'
					end
				end
			end

			local normalizedChar = {
				source = 'Altoholic',
				importedAt = time(),

				-- Identity
				name = name,
				realm = realm,
				guid = guids[charKey],

				-- Time-played data
				totalPlayed = data.played or 0,
				levelPlayed = data.playedThisLevel or 0,
				lastLogin = data.lastLogoutTimestamp or data.lastUpdate or 0,

				-- Character metadata
				level = level,
				class = className,
				race = raceName,
				faction = faction,

				-- Optional context
				xp = data.XP,
				xpMax = data.maxXP,
				restedXP = data.restXP,
			}

			table.insert(characters, normalizedChar)
		end
	end

	return characters
end

---Validate character data before import
---@param char table Character data to validate
---@return boolean valid
---@return string? error Error message if invalid
local function ValidateCharacterData(char)
	-- Required fields
	if not char.name or char.name == '' then
		return false, 'Missing character name'
	end
	if not char.realm or char.realm == '' then
		return false, 'Missing realm name'
	end
	if not char.totalPlayed or type(char.totalPlayed) ~= 'number' then
		return false, 'Missing or invalid totalPlayed'
	end

	-- Validate time values
	if char.totalPlayed < 0 then
		return false, 'Negative totalPlayed value'
	end
	if char.levelPlayed and char.levelPlayed < 0 then
		return false, 'Negative levelPlayed value'
	end

	-- Validate timestamp (not in future, not before WoW launch ~2004)
	local wowLaunchDate = 1101283200 -- Nov 23, 2004
	local now = time()
	if char.lastLogin and (char.lastLogin > now or char.lastLogin < wowLaunchDate) then
		return false, 'Invalid timestamp'
	end

	-- Validate level (1-80 for retail)
	if char.level and (char.level < 1 or char.level > 80) then
		return false, 'Invalid level: ' .. char.level
	end

	return true
end

---Set merge strategy for conflict resolution
---@param strategy string One of MERGE_STRATEGIES
function Import:SetMergeStrategy(strategy)
	if MERGE_STRATEGIES[strategy:upper()] then
		currentMergeStrategy = MERGE_STRATEGIES[strategy:upper()]
	end
end

---Get current merge strategy
---@return string
function Import:GetMergeStrategy()
	return currentMergeStrategy
end

---Merge imported character data into database
---@param importedChars table[] Array of normalized character data
---@return number imported Count of characters imported
---@return number skipped Count of characters skipped
function Import:MergeCharacterData(importedChars)
	local imported = 0
	local skipped = 0
	local db = LibsTimePlayed.globaldb.characters

	for _, char in ipairs(importedChars) do
		-- Validate data
		local valid, error = ValidateCharacterData(char)
		if not valid then
			LibsTimePlayed:Log('Skipped invalid character ' .. (char.name or '?') .. ': ' .. (error or 'unknown error'), 'warning')
			skipped = skipped + 1
		else
			-- Build character key
			local charKey = char.realm .. '-' .. char.name

			-- Check if character already exists
			local existing = db[charKey]

			local shouldImport = false

			if not existing then
				-- New character, always import
				shouldImport = true
			else
				-- Handle conflict based on merge strategy
				if currentMergeStrategy == MERGE_STRATEGIES.PREFER_IMPORTED then
					shouldImport = true
				elseif currentMergeStrategy == MERGE_STRATEGIES.PREFER_EXISTING then
					shouldImport = false
				elseif currentMergeStrategy == MERGE_STRATEGIES.NEWEST_WINS then
					-- Compare timestamps
					local existingTime = existing.lastUpdated or 0
					local importedTime = char.lastLogin or 0
					shouldImport = importedTime > existingTime
				elseif currentMergeStrategy == MERGE_STRATEGIES.MAX_VALUES then
					-- Use maximum of both values
					shouldImport = true
					char.totalPlayed = math.max(char.totalPlayed, existing.totalPlayed or 0)
					char.levelPlayed = math.max(char.levelPlayed, existing.levelPlayed or 0)
				end
			end

			if shouldImport then
				-- Convert to internal format
				db[charKey] = {
					name = char.name,
					realm = char.realm,
					class = char.class, -- Might be localized from AltVault
					classFile = char.class, -- Altoholic already provides classFile
					faction = char.faction,
					level = char.level,
					totalPlayed = char.totalPlayed,
					levelPlayed = char.levelPlayed,
					lastUpdated = char.lastLogin,
					importedFrom = char.source,
				}

				imported = imported + 1
				LibsTimePlayed:Log('Imported: ' .. char.name .. '-' .. char.realm .. ' (' .. LibsTimePlayed.FormatTime(char.totalPlayed, 'smart') .. ' played)', 'debug')
			else
				skipped = skipped + 1
				LibsTimePlayed:Log('Skipped: ' .. char.name .. '-' .. char.realm .. ' (merge strategy: ' .. currentMergeStrategy .. ')', 'debug')
			end
		end
	end

	return imported, skipped
end

---Import from a specific source
---@param sourceName string 'AltVault' or 'Altoholic'
---@return boolean success
---@return number imported Count of characters imported
---@return number skipped Count of characters skipped
function Import:ImportFrom(sourceName)
	LibsTimePlayed:Log('Starting import from ' .. sourceName .. '...', 'info')

	local characters = {}

	if sourceName == 'AltVault' then
		characters = self:ParseAltVault()
	elseif sourceName == 'Altoholic' then
		characters = self:ParseAltoholic()
	else
		LibsTimePlayed:Log('Unknown import source: ' .. sourceName, 'error')
		return false, 0, 0
	end

	if #characters == 0 then
		LibsTimePlayed:Log('No characters found in ' .. sourceName .. ' database', 'warning')
		return false, 0, 0
	end

	LibsTimePlayed:Log('Found ' .. #characters .. ' character(s) in ' .. sourceName .. ' database', 'info')

	-- Merge into database
	local imported, skipped = self:MergeCharacterData(characters)

	-- Track import in history
	if not LibsTimePlayed.globaldb.importHistory then
		LibsTimePlayed.globaldb.importHistory = {}
	end

	table.insert(LibsTimePlayed.globaldb.importHistory, {
		source = sourceName,
		timestamp = time(),
		charactersImported = imported,
		charactersSkipped = skipped,
		strategy = currentMergeStrategy,
	})

	LibsTimePlayed:Log('Import complete: ' .. imported .. ' imported, ' .. skipped .. ' skipped', 'success')

	return true, imported, skipped
end

---Get import history
---@return table[] history Array of import records
function Import:GetImportHistory()
	return LibsTimePlayed.globaldb.importHistory or {}
end

---Check if this is a first-time user (no characters tracked and hasn't been offered import)
---@return boolean isFirstTime
function Import:IsFirstTimeUser()
	-- Count existing characters (excluding current character)
	local currentCharKey = GetNormalizedRealmName() .. '-' .. UnitName('player')
	local charCount = 0
	for key in pairs(LibsTimePlayed.globaldb.characters) do
		if key ~= currentCharKey then
			charCount = charCount + 1
		end
	end

	-- First time if: no OTHER characters AND hasn't been offered import yet
	-- This allows the current character to be added without interfering with import detection
	return charCount == 0 and not LibsTimePlayed.globaldb.firstTimeImportOffered
end

---Perform import from a source and report result
---@param sourceName string Source to import from
local function DoImport(sourceName)
	LibsTimePlayed:Log('First-time import accepted, importing from ' .. sourceName, 'info')
	Import:SetMergeStrategy('newest_wins')
	local success, imported, skipped = Import:ImportFrom(sourceName)
	if success then
		LibsTimePlayed:Print(string.format('Welcome import complete: %d character(s) imported from %s!', imported, sourceName))
		LibsTimePlayed:UpdateDisplay()
	else
		LibsTimePlayed:Print('Import failed. You can try again from /libstp options.')
	end
end

---Create the import dialog frame using LibAT.UI
---@param message string Dialog message text
---@param buttons table[] Array of {text, onClick} button definitions
local function ShowImportDialog(message, buttons)
	-- Destroy previous dialog if it exists
	if _G['LibsTPImportDialog'] then
		_G['LibsTPImportDialog']:Hide()
		_G['LibsTPImportDialog']:SetParent(nil)
		_G['LibsTPImportDialog'] = nil
	end

	local dialogWidth = 360
	local dialogHeight = 180

	-- Create dialog frame
	local dialog = CreateFrame('Frame', 'LibsTPImportDialog', UIParent, 'BackdropTemplate')
	dialog:SetSize(dialogWidth, dialogHeight)
	dialog:SetPoint('CENTER', UIParent, 'CENTER', 0, 100)
	dialog:SetFrameStrata('DIALOG')
	dialog:SetBackdrop({
		bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	dialog:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
	dialog:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:RegisterForDrag('LeftButton')
	dialog:SetScript('OnDragStart', dialog.StartMoving)
	dialog:SetScript('OnDragStop', dialog.StopMovingOrSizing)

	-- Title bar
	local title = dialog:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	title:SetPoint('TOP', dialog, 'TOP', 0, -12)
	title:SetText("|cffffffffLib's|r |cffe21f1fTimePlayed|r")

	-- Message text
	local text = dialog:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	text:SetPoint('TOP', title, 'BOTTOM', 0, -10)
	text:SetPoint('LEFT', dialog, 'LEFT', 20, 0)
	text:SetPoint('RIGHT', dialog, 'RIGHT', -20, 0)
	text:SetJustifyH('CENTER')
	text:SetText(message)
	text:SetWordWrap(true)

	-- Measure text height and resize dialog if needed
	local textHeight = text:GetStringHeight()
	local minContentHeight = 12 + title:GetStringHeight() + 10 + textHeight + 15 + 26 + 14
	if minContentHeight > dialogHeight then
		dialog:SetHeight(minContentHeight)
	end

	-- Create buttons from right to left
	local buttonWidth = math.min(130, (dialogWidth - 20 - (#buttons - 1) * 6) / #buttons)
	local totalButtonsWidth = (#buttons * buttonWidth) + ((#buttons - 1) * 6)
	local startX = -totalButtonsWidth / 2

	for i, btnDef in ipairs(buttons) do
		local btn = CreateStyledButton(dialog, buttonWidth, 26, btnDef.text)
		btn:SetPoint('BOTTOM', dialog, 'BOTTOM', startX + (i - 1) * (buttonWidth + 6) + buttonWidth / 2, 14)
		btn:SetScript('OnClick', function()
			dialog:Hide()
			btnDef.onClick()
		end)
	end

	-- Allow Escape to close
	tinsert(UISpecialFrames, 'LibsTPImportDialog')

	dialog:Show()
end

---Offer first-time import to the user
---Automatically detects available sources and prompts user to import
function Import:OfferFirstTimeImport()
	-- Mark that we've offered (do this first to prevent repeated prompts)
	LibsTimePlayed.globaldb.firstTimeImportOffered = true

	-- Check for available sources
	local sources = self:GetAvailableSources()
	local availableSources = {}

	for name, info in pairs(sources) do
		if info.available and info.characterCount > 0 then
			table.insert(availableSources, { name = name, count = info.characterCount })
		end
	end

	-- No sources available
	if #availableSources == 0 then
		LibsTimePlayed:Log('First-time user detected, but no import sources available', 'debug')
		return
	end

	-- Sort sources: prefer AltVault (cleaner data format), then by character count
	table.sort(availableSources, function(a, b)
		-- If one is AltVault and counts are close (within 10%), prefer AltVault
		if a.name == 'AltVault' and b.name ~= 'AltVault' then
			local ratio = a.count / b.count
			if ratio >= 0.9 then
				return true
			end
		elseif b.name == 'AltVault' and a.name ~= 'AltVault' then
			local ratio = b.count / a.count
			if ratio >= 0.9 then
				return false
			end
		end
		return a.count > b.count
	end)

	local topSource = availableSources[1]
	local hasMultipleSources = #availableSources > 1

	if hasMultipleSources then
		-- Build multi-source message
		local message = 'Detected multiple data sources:\n\n'
		for i, src in ipairs(availableSources) do
			local recommended = (i == 1) and ' (Recommended)' or ''
			message = message .. string.format('  %s: %d character(s)%s\n', src.name, src.count, recommended)
		end

		-- Show dialog with a button per source + No Thanks
		ShowImportDialog(message, {
			{
				text = topSource.name,
				onClick = function()
					DoImport(topSource.name)
				end,
			},
			{
				text = availableSources[2].name,
				onClick = function()
					DoImport(availableSources[2].name)
				end,
			},
			{
				text = 'No Thanks',
				onClick = function()
					LibsTimePlayed:Log('First-time import declined', 'debug')
					LibsTimePlayed:Print('You can import data anytime from /libstp options.')
				end,
			},
		})
	else
		-- Single source
		local message = string.format('Detected %s with %d character(s).\n\nImport this data to populate your time-played history?', topSource.name, topSource.count)

		ShowImportDialog(message, {
			{
				text = 'Import Now',
				onClick = function()
					DoImport(topSource.name)
				end,
			},
			{
				text = 'Remind Later',
				onClick = function()
					LibsTimePlayed.globaldb.firstTimeImportOffered = false
					LibsTimePlayed:Log('First-time import deferred', 'debug')
					LibsTimePlayed:Print('You can import data anytime from /libstp options.')
				end,
			},
			{
				text = 'No Thanks',
				onClick = function()
					LibsTimePlayed:Log('First-time import declined', 'debug')
					LibsTimePlayed:Print('You can import data anytime from /libstp options.')
				end,
			},
		})
	end
end
