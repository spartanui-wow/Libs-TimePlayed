---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

---@class LibsTimePlayed.DataBroker : AceModule, AceEvent-3.0, AceTimer-3.0
local DataBroker = LibsTimePlayed:NewModule('DataBroker')
LibsTimePlayed.DataBroker = DataBroker

local LDB = LibStub('LibDataBroker-1.1')
local LibQTip = LibStub('LibQTip-2.0')

function DataBroker:OnEnable()
	self.dataObj = LDB:NewDataObject("Lib's TimePlayed", {
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
			DataBroker:ShowTooltip(frame)
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

	-- Store reference on main addon for MinimapButton
	LibsTimePlayed.dataObject = self.dataObj

	self:UpdateDisplay()
end

function DataBroker:ShowTooltip(anchorFrame)
	self:HideTooltip()
	LibsTimePlayed:BuildTooltip(anchorFrame)
end

function DataBroker:HideTooltip()
	if self.activeTooltip then
		LibQTip:ReleaseTooltip(self.activeTooltip)
		self.activeTooltip = nil
	end
end

function DataBroker:UpdateDisplay()
	if not self.dataObj then
		return
	end

	local format = LibsTimePlayed.db.display.format
	local timeFormat = LibsTimePlayed.db.display.timeFormat

	if not LibsTimePlayed:HasPlayedData() then
		self.dataObj.text = 'Waiting...'
		return
	end

	local text
	if format == 'session' then
		text = LibsTimePlayed.FormatTime(LibsTimePlayed:GetSessionTime(), timeFormat)
	elseif format == 'level' then
		text = LibsTimePlayed.FormatTime(LibsTimePlayed:GetLevelPlayed(), timeFormat)
	else -- 'total'
		text = LibsTimePlayed.FormatTime(LibsTimePlayed:GetTotalPlayed(), timeFormat)
	end

	self.dataObj.text = text
end
