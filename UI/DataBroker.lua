---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

local LDB = LibStub('LibDataBroker-1.1')
local LibQTip = LibStub('LibQTip-2.0')

local dataObj

function LibsTimePlayed:InitializeDataBroker()
	dataObj = LDB:NewDataObject("Lib's TimePlayed", {
		type = 'data source',
		text = 'Loading...',
		icon = 'Interface\\Icons\\INV_Misc_PocketWatch_01',
		label = 'TimePlayed',
		OnClick = function(frame, button)
			if button == 'LeftButton' then
				LibsTimePlayed:TogglePopup()
			elseif button == 'RightButton' then
				LibsTimePlayed:OpenOptions()
			elseif button == 'MiddleButton' then
				RequestTimePlayed()
			end
		end,
		OnEnter = function(frame)
			LibsTimePlayed:ShowTooltip(frame)
		end,
		OnLeave = function(frame)
			-- Auto-hide handles cleanup via SetAutoHideDelay
		end,
		GetOptions = function()
			return {
				type = 'group',
				name = 'TimePlayed Settings',
				args = {
					format = {
						type = 'select',
						name = 'Display Format',
						desc = 'What time to show on the broker text',
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
						type = 'select',
						name = 'Time Format',
						desc = 'How to format time values',
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
						type = 'select',
						name = 'Group By',
						desc = 'How to group characters in tooltip',
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
				},
			}
		end,
	})

	self.dataObject = dataObj
	self:UpdateDisplay()
end

function LibsTimePlayed:ShowTooltip(anchorFrame)
	self:HideTooltip()
	self:BuildTooltip(anchorFrame)
end

function LibsTimePlayed:HideTooltip()
	if self.activeTooltip then
		LibQTip:ReleaseTooltip(self.activeTooltip)
		self.activeTooltip = nil
	end
end

function LibsTimePlayed:UpdateDisplay()
	if not dataObj then
		return
	end

	local format = self.db.display.format
	local timeFormat = self.db.display.timeFormat

	if not self:HasPlayedData() then
		dataObj.text = 'Waiting...'
		return
	end

	local text
	if format == 'session' then
		text = self.FormatTime(self:GetSessionTime(), timeFormat)
	elseif format == 'level' then
		text = self.FormatTime(self:GetLevelPlayed(), timeFormat)
	else -- 'total'
		text = self.FormatTime(self:GetTotalPlayed(), timeFormat)
	end

	dataObj.text = text
end
