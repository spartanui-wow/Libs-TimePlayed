---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

function LibsTimePlayed:InitializeOptions()
	local options = {
		name = "Lib's TimePlayed",
		type = 'group',
		args = {
			display = {
				name = 'Display',
				type = 'group',
				order = 1,
				inline = true,
				args = {
					format = {
						name = 'Display Format',
						desc = 'What time to show on the broker text',
						type = 'select',
						order = 1,
						values = {
							total = 'Total Played',
							session = 'Session Time',
							level = 'Level Time',
						},
						get = function()
							return LibsTimePlayed.db.display.format
						end,
						set = function(_, val)
							LibsTimePlayed.db.display.format = val
							LibsTimePlayed:UpdateDisplay()
						end,
					},
					timeFormat = {
						name = 'Time Format',
						desc = 'How to format time values',
						type = 'select',
						order = 2,
						values = {
							smart = 'Smart (2d 5h)',
							full = 'Full (2d 5h 30m)',
							hours = 'Hours (53.5h)',
						},
						get = function()
							return LibsTimePlayed.db.display.timeFormat
						end,
						set = function(_, val)
							LibsTimePlayed.db.display.timeFormat = val
							LibsTimePlayed:UpdateDisplay()
						end,
					},
					groupBy = {
						name = 'Group By',
						desc = 'How to group characters in tooltip and popup window',
						type = 'select',
						order = 3,
						values = {
							class = 'Class',
							realm = 'Realm',
							faction = 'Faction',
							none = 'All Characters',
						},
						get = function()
							return LibsTimePlayed.db.display.groupBy
						end,
						set = function(_, val)
							LibsTimePlayed.db.display.groupBy = val
							LibsTimePlayed:UpdateDisplay()
						end,
					},
					showMilestones = {
						name = 'Show Milestones',
						desc = 'Display milestone achievements in tooltip and popup window',
						type = 'toggle',
						order = 5,
						width = 'full',
						get = function()
							return LibsTimePlayed.db.display.showMilestones
						end,
						set = function(_, val)
							LibsTimePlayed.db.display.showMilestones = val
						end,
					},
				},
			},
			import = {
				name = 'Import Data',
				type = 'group',
				order = 1.5,
				inline = true,
				args = {
					desc = {
						name = 'Import time-played data from AltVault or Altoholic to quickly populate your database without logging into each character.',
						type = 'description',
						order = 0,
					},
					detectButton = {
						name = 'Detect Sources',
						desc = 'Scan for available import sources',
						type = 'execute',
						order = 1,
						func = function()
							local sources = LibsTimePlayed.Import:GetAvailableSources()
							local found = {}
							for name, info in pairs(sources) do
								if info.available then
									table.insert(found, name .. ' (' .. info.characterCount .. ' characters)')
								end
							end
							if #found > 0 then
								LibsTimePlayed:Print('Found: ' .. table.concat(found, ', '))
							else
								LibsTimePlayed:Print('No import sources detected. Install AltVault or Altoholic to import data.')
							end
						end,
					},
					sourceSelect = {
						name = 'Import Source',
						desc = 'Select which addon to import from',
						type = 'select',
						order = 2,
						values = function()
							local sources = LibsTimePlayed.Import:GetAvailableSources()
							local values = {}
							for name, info in pairs(sources) do
								if info.available then
									values[name] = name .. ' (' .. info.characterCount .. ' characters)'
								end
							end
							return values
						end,
						get = function()
							return LibsTimePlayed.selectedImportSource
						end,
						set = function(_, val)
							LibsTimePlayed.selectedImportSource = val
						end,
					},
					mergeStrategy = {
						name = 'Merge Strategy',
						desc = 'How to handle conflicts when importing characters that already exist',
						type = 'select',
						order = 3,
						values = {
							newest_wins = 'Newest Wins (use most recent data)',
							prefer_imported = 'Prefer Imported (always use import data)',
							prefer_existing = 'Prefer Existing (keep current data)',
							max_values = 'Max Values (use highest time values)',
						},
						get = function()
							return LibsTimePlayed.Import:GetMergeStrategy()
						end,
						set = function(_, val)
							LibsTimePlayed.Import:SetMergeStrategy(val)
						end,
					},
					importButton = {
						name = 'Import',
						desc = 'Import character data from the selected source',
						type = 'execute',
						order = 4,
						confirm = function()
							if not LibsTimePlayed.selectedImportSource then
								return false
							end
							local sources = LibsTimePlayed.Import:GetAvailableSources()
							local source = sources[LibsTimePlayed.selectedImportSource]
							if not source or not source.available then
								return false
							end
							return 'Import ' .. source.characterCount .. ' character(s) from ' .. LibsTimePlayed.selectedImportSource .. '?'
						end,
						func = function()
							if not LibsTimePlayed.selectedImportSource then
								LibsTimePlayed:Print('Please select an import source first.')
								return
							end

							local success, imported, skipped = LibsTimePlayed.Import:ImportFrom(LibsTimePlayed.selectedImportSource)
							if success then
								LibsTimePlayed:Print('Import complete: ' .. imported .. ' imported, ' .. skipped .. ' skipped')
								LibsTimePlayed:UpdateDisplay()
							else
								LibsTimePlayed:Print('Import failed. Check /logs for details.')
							end
						end,
					},
					spacer = {
						name = '',
						type = 'description',
						order = 5,
					},
					historyDesc = {
						name = function()
							local history = LibsTimePlayed.Import:GetImportHistory()
							if #history == 0 then
								return 'No import history yet.'
							end

							local lines = { 'Import History:' }
							for i = #history, math.max(1, #history - 2), -1 do
								local record = history[i]
								local timestamp = date('%Y-%m-%d %H:%M', record.timestamp)
								table.insert(lines, string.format('  %s: %s (%d imported, %d skipped)', timestamp, record.source, record.charactersImported, record.charactersSkipped))
							end
							return table.concat(lines, '\n')
						end,
						type = 'description',
						order = 6,
						fontSize = 'small',
					},
				},
			},
			data = {
				name = 'Character Data',
				type = 'group',
				order = 2,
				inline = true,
				args = {
					refresh = {
						name = 'Refresh Played Time',
						desc = 'Request updated /played data from the server',
						type = 'execute',
						order = 1,
						func = function()
							RequestTimePlayed()
						end,
					},
					purge = {
						name = 'Purge Old Characters',
						desc = 'Remove characters not updated in over 90 days',
						type = 'execute',
						order = 2,
						confirm = true,
						confirmText = 'Remove characters not updated in 90+ days?',
						func = function()
							LibsTimePlayed:PurgeOldCharacters(90)
						end,
					},
				},
			},
			characters = {
				name = 'Manage Characters',
				type = 'group',
				order = 2.5,
				inline = true,
				args = {
					desc = {
						name = 'Select characters to remove from tracking. The current character cannot be removed.',
						type = 'description',
						order = 0,
					},
					charSelect = {
						name = 'Tracked Characters',
						type = 'multiselect',
						order = 1,
						width = 'full',
						values = function()
							return LibsTimePlayed:GetCharacterListForOptions()
						end,
						get = function(_, key)
							return LibsTimePlayed.selectedCharsForDeletion and LibsTimePlayed.selectedCharsForDeletion[key]
						end,
						set = function(_, key, val)
							if not LibsTimePlayed.selectedCharsForDeletion then
								LibsTimePlayed.selectedCharsForDeletion = {}
							end
							LibsTimePlayed.selectedCharsForDeletion[key] = val or nil
						end,
					},
					deleteSelected = {
						name = 'Delete Selected',
						desc = 'Remove the selected characters from tracking',
						type = 'execute',
						order = 2,
						confirm = function()
							local count = 0
							if LibsTimePlayed.selectedCharsForDeletion then
								for _ in pairs(LibsTimePlayed.selectedCharsForDeletion) do
									count = count + 1
								end
							end
							if count == 0 then
								return false
							end
							return 'Remove ' .. count .. ' selected character(s)? This cannot be undone.'
						end,
						func = function()
							LibsTimePlayed:DeleteSelectedCharacters()
						end,
					},
				},
			},
			popup = {
				name = 'Popup Window',
				type = 'group',
				order = 3,
				inline = true,
				args = {
					toggle = {
						name = 'Toggle Popup Window',
						desc = 'Show or hide the standalone popup window',
						type = 'execute',
						order = 1,
						func = function()
							LibsTimePlayed:TogglePopup()
						end,
					},
					resetPosition = {
						name = 'Reset Position',
						desc = 'Reset popup window size and position to defaults',
						type = 'execute',
						order = 2,
						func = function()
							LibsTimePlayed.db.popup.width = 520
							LibsTimePlayed.db.popup.height = 300
							LibsTimePlayed.db.popup.point = 'CENTER'
							LibsTimePlayed.db.popup.x = 0
							LibsTimePlayed.db.popup.y = 0
							local frame = _G['LibsTimePlayedPopup']
							if frame then
								frame:ClearAllPoints()
								frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
								frame:SetSize(520, 300)
							end
							LibsTimePlayed:Print('Popup position reset.')
						end,
					},
				},
			},
		},
	}

	LibStub('AceConfig-3.0'):RegisterOptionsTable('LibsTimePlayed', options)
	LibStub('AceConfigDialog-3.0'):AddToBlizOptions('LibsTimePlayed', "Lib's TimePlayed")
end

function LibsTimePlayed:OpenOptions()
	LibStub('AceConfigDialog-3.0'):Open('LibsTimePlayed')
end

---Remove characters not updated within the given number of days
---@param days number
function LibsTimePlayed:PurgeOldCharacters(days)
	local cutoff = time() - (days * 86400)
	local removed = 0

	for charKey, data in pairs(self.globaldb.characters) do
		if type(data) == 'table' and (data.lastUpdated or 0) < cutoff then
			self.globaldb.characters[charKey] = nil
			removed = removed + 1
		end
	end

	self:Print('Removed ' .. removed .. ' character(s) not updated in ' .. days .. '+ days')
end

---Build a sorted list of character keys for the options multiselect
---Excludes the currently logged-in character
---@return table<string, string> values keyed by charKey, value is display label
function LibsTimePlayed:GetCharacterListForOptions()
	local values = {}
	local playerName = UnitName('player')
	local playerRealm = GetNormalizedRealmName()
	local currentKey = playerRealm and playerName and (playerRealm .. '-' .. playerName) or ''

	for charKey, data in pairs(self.globaldb.characters) do
		if type(data) == 'table' and charKey ~= currentKey then
			local label = (data.name or '?') .. ' - ' .. (data.realm or '?')
			if data.class then
				label = label .. ' (' .. data.class .. ' ' .. (data.level or '?') .. ')'
			end
			label = label .. '  ' .. self.FormatTime(data.totalPlayed or 0, 'smart')
			values[charKey] = label
		end
	end

	return values
end

---Delete all characters marked in selectedCharsForDeletion
function LibsTimePlayed:DeleteSelectedCharacters()
	if not self.selectedCharsForDeletion then
		return
	end

	local removed = 0
	for charKey in pairs(self.selectedCharsForDeletion) do
		if self.globaldb.characters[charKey] then
			self.globaldb.characters[charKey] = nil
			removed = removed + 1
		end
	end

	self.selectedCharsForDeletion = nil
	self:Print('Removed ' .. removed .. ' character(s)')
end
