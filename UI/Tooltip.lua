---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

local LibQTip = LibStub('LibQTip-1.0')

local GROUPBY_LABELS = {
	class = 'Class',
	realm = 'Realm',
	faction = 'Faction',
}

local BAR_WIDTH = 12

---Build a text bar using block characters that don't conflict with WoW escape codes
---@param fillPercent number 0-1
---@param r number
---@param g number
---@param b number
---@return string
local function BuildTextBar(fillPercent, r, g, b)
	local filled = math.floor(fillPercent * BAR_WIDTH + 0.5)
	filled = math.max(0, math.min(BAR_WIDTH, filled))
	local empty = BAR_WIDTH - filled

	local colorHex = string.format('|cff%02x%02x%02x', r * 255, g * 255, b * 255)
	local bar = colorHex .. string.rep('\226\150\136', filled) .. '|r' -- UTF-8 full block character U+2588
	if empty > 0 then
		bar = bar .. '|cff333333' .. string.rep('\226\150\136', empty) .. '|r'
	end
	return bar
end

---Format a color into a WoW color escape string
---@param r number
---@param g number
---@param b number
---@param text string
---@return string
local function ColorText(r, g, b, text)
	return string.format('|cff%02x%02x%02x%s|r', r * 255, g * 255, b * 255, text)
end

---@param anchorFrame Frame
---@return table tooltip The LibQTip tooltip
function LibsTimePlayed:BuildTooltip(anchorFrame)
	local tooltip = LibQTip:Acquire('LibsTimePlayedTooltip', 4, 'LEFT', 'LEFT', 'RIGHT', 'RIGHT')
	tooltip:Clear()

	-- Title
	local line = tooltip:AddHeader()
	tooltip:SetCell(line, 1, "Lib's TimePlayed", 'CENTER', 4)

	if not self:HasPlayedData() then
		line = tooltip:AddLine()
		tooltip:SetCell(line, 1, ColorText(0.7, 0.7, 0.7, 'Waiting for /played data...'), 'CENTER', 4)
		tooltip:SmartAnchorTo(anchorFrame)
		tooltip:SetAutoHideDelay(0.1, anchorFrame)
		tooltip:Show()
		return tooltip
	end

	-- Current character info
	local name = UnitName('player')
	local _, classFile = UnitClass('player')
	local color = RAID_CLASS_COLORS[classFile]
	local coloredName = color and ColorText(color.r, color.g, color.b, name) or name

	tooltip:AddSeparator()
	line = tooltip:AddLine()
	tooltip:SetCell(line, 1, coloredName .. ' (Lv ' .. UnitLevel('player') .. ')', 'LEFT', 2)

	line = tooltip:AddLine()
	tooltip:SetCell(line, 1, ColorText(0.8, 0.8, 0.8, '  Total:'), 'LEFT', 2)
	tooltip:SetCell(line, 3, self.FormatTime(self:GetTotalPlayed(), 'full'), 'RIGHT', 2)

	line = tooltip:AddLine()
	tooltip:SetCell(line, 1, ColorText(0.8, 0.8, 0.8, '  This Level:'), 'LEFT', 2)
	tooltip:SetCell(line, 3, self.FormatTime(self:GetLevelPlayed(), 'full'), 'RIGHT', 2)

	line = tooltip:AddLine()
	tooltip:SetCell(line, 1, ColorText(0.8, 0.8, 0.8, '  Session:'), 'LEFT', 2)
	tooltip:SetCell(line, 3, self.FormatTime(self:GetSessionTime(), 'full'), 'RIGHT', 2)

	-- Account summary using GetGroupedData
	local sortedGroups, accountTotal = self:GetGroupedData()
	local groupBy = self.db.display.groupBy or 'class'
	local showBars = self.db.display.showBarsInTooltip

	if accountTotal > 0 then
		tooltip:AddSeparator()

		line = tooltip:AddLine()
		tooltip:SetCell(line, 1, ColorText(1, 0.82, 0, 'Account Total'), 'LEFT', 2)
		tooltip:SetCell(line, 3, ColorText(1, 1, 1, self.FormatTime(accountTotal, 'smart')), 'RIGHT', 2)

		line = tooltip:AddLine()
		tooltip:SetCell(line, 1, ColorText(0.5, 0.5, 0.5, 'Grouped by: ' .. GROUPBY_LABELS[groupBy]), 'LEFT', 4)

		-- Find top group total for bar scaling
		local topGroupTotal = sortedGroups[1] and sortedGroups[1].total or 0

		for _, group in ipairs(sortedGroups) do
			local clr = group.color
			local r, g, b = clr.r, clr.g, clr.b

			-- Percentage of account total
			local percent = accountTotal > 0 and (group.total / accountTotal * 100) or 0
			local barPercent = topGroupTotal > 0 and (group.total / topGroupTotal) or 0

			line = tooltip:AddLine()
			tooltip:SetCell(line, 1, ColorText(r, g, b, group.label), 'LEFT')
			if showBars then
				tooltip:SetCell(line, 2, BuildTextBar(barPercent, r, g, b), 'LEFT')
			else
				tooltip:SetCell(line, 2, '', 'LEFT')
			end
			tooltip:SetCell(line, 3, ColorText(0.8, 0.8, 0.8, string.format('%.0f%%', percent)), 'RIGHT')
			tooltip:SetCell(line, 4, ColorText(0.8, 0.8, 0.8, self.FormatTime(group.total, 'smart')), 'RIGHT')

			-- Individual characters under each group
			for _, char in ipairs(group.chars) do
				local cr, cg, cb = 0.6, 0.6, 0.6
				if groupBy ~= 'class' then
					local charColor = RAID_CLASS_COLORS[char.classFile]
					if charColor then
						cr, cg, cb = charColor.r, charColor.g, charColor.b
					end
				end

				line = tooltip:AddLine()
				tooltip:SetCell(line, 1, ColorText(cr, cg, cb, '  ' .. char.name .. ' (' .. char.level .. ')'), 'LEFT', 3)
				tooltip:SetCell(line, 4, ColorText(0.6, 0.6, 0.6, self.FormatTime(char.totalPlayed, 'smart')), 'RIGHT')
			end
		end

		-- Milestones
		if self.GetMilestones and self.db.display.showMilestones then
			local milestones = self:GetMilestones(sortedGroups, accountTotal)
			if #milestones > 0 then
				tooltip:AddSeparator()
				for _, milestone in ipairs(milestones) do
					line = tooltip:AddLine()
					tooltip:SetCell(line, 1, ColorText(0.7, 0.7, 0.7, milestone), 'LEFT', 4)
				end
			end
		end
	end

	-- Click hints
	tooltip:AddSeparator()
	line = tooltip:AddLine()
	tooltip:SetCell(line, 1, ColorText(1, 1, 0, 'Left Click:') .. ' Cycle Format', 'LEFT', 4)
	line = tooltip:AddLine()
	tooltip:SetCell(line, 1, ColorText(1, 1, 0, 'Shift+Left:') .. ' Toggle Window  ' .. ColorText(1, 1, 0, 'Right:') .. ' Options', 'LEFT', 4)
	line = tooltip:AddLine()
	tooltip:SetCell(line, 1, ColorText(1, 1, 0, 'Middle Click:') .. ' Refresh /played', 'LEFT', 4)

	tooltip:SmartAnchorTo(anchorFrame)
	tooltip:SetAutoHideDelay(0.1, anchorFrame)
	tooltip:Show()

	return tooltip
end
