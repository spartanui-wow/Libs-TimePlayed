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

