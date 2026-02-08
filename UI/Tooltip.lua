---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

local LibQTip = LibStub('LibQTip-2.0')

local GROUPBY_LABELS = {
	class = 'Class',
	realm = 'Realm',
	faction = 'Faction',
}

---@param anchorFrame Frame
---@return LibQTip-2.0.Tooltip tooltip
function LibsTimePlayed:BuildTooltip(anchorFrame)
	local tooltip = LibQTip:AcquireTooltip('LibsTimePlayedTooltip', 5, 'LEFT', 'LEFT', 'LEFT', 'RIGHT', 'RIGHT')
	tooltip:Clear()

	-- Column layout: Label | BarFill | BarEmpty | Percent | Time
	-- Columns 2+3 form the visual bar via cell background colors

	-- Title
	local row = tooltip:AddHeadingRow()
	row:GetCell(1):SetText("Lib's TimePlayed"):SetColSpan(5):SetJustifyH('CENTER')

	if not self:HasPlayedData() then
		row = tooltip:AddRow()
		row:GetCell(1):SetText('Waiting for /played data...'):SetColSpan(5):SetJustifyH('CENTER'):SetTextColor(0.7, 0.7, 0.7)
		tooltip:SmartAnchorTo(anchorFrame)
		tooltip:SetAutoHideDelay(0.1, anchorFrame)
		tooltip:UpdateLayout()
		tooltip:Show()
		return tooltip
	end

	-- Current character info
	local name = UnitName('player')
	local _, classFile = UnitClass('player')
	local color = RAID_CLASS_COLORS[classFile]

	tooltip:AddSeparator()

	row = tooltip:AddRow()
	local nameCell = row:GetCell(1):SetColSpan(5)
	if color then
		nameCell:SetText(name .. ' (Lv ' .. UnitLevel('player') .. ')'):SetTextColor(color.r, color.g, color.b)
	else
		nameCell:SetText(name .. ' (Lv ' .. UnitLevel('player') .. ')')
	end

	row = tooltip:AddRow()
	row:GetCell(1):SetText('  Total:'):SetTextColor(0.8, 0.8, 0.8):SetColSpan(3)
	row:GetCell(4):SetText(self.FormatTime(self:GetTotalPlayed(), 'full')):SetColSpan(2):SetJustifyH('RIGHT')

	row = tooltip:AddRow()
	row:GetCell(1):SetText('  This Level:'):SetTextColor(0.8, 0.8, 0.8):SetColSpan(3)
	row:GetCell(4):SetText(self.FormatTime(self:GetLevelPlayed(), 'full')):SetColSpan(2):SetJustifyH('RIGHT')

	row = tooltip:AddRow()
	row:GetCell(1):SetText('  Session:'):SetTextColor(0.8, 0.8, 0.8):SetColSpan(3)
	row:GetCell(4):SetText(self.FormatTime(self:GetSessionTime(), 'full')):SetColSpan(2):SetJustifyH('RIGHT')

	-- Account summary using GetGroupedData
	local sortedGroups, accountTotal = self:GetGroupedData()
	local groupBy = self.db.display.groupBy or 'class'
	local showBars = self.db.display.showBarsInTooltip

	if accountTotal > 0 then
		tooltip:AddSeparator()

		row = tooltip:AddRow()
		row:GetCell(1):SetText('Account Total'):SetTextColor(1, 0.82, 0):SetColSpan(3)
		row:GetCell(4):SetText(self.FormatTime(accountTotal, 'smart')):SetColSpan(2):SetJustifyH('RIGHT'):SetTextColor(1, 1, 1)

		row = tooltip:AddRow()
		row:GetCell(1):SetText('Grouped by: ' .. GROUPBY_LABELS[groupBy]):SetTextColor(0.5, 0.5, 0.5):SetColSpan(5)

		-- Find top group total for bar scaling
		local topGroupTotal = sortedGroups[1] and sortedGroups[1].total or 0

		for _, group in ipairs(sortedGroups) do
			local clr = group.color
			local r, g, b = clr.r, clr.g, clr.b

			-- Percentage of account total
			local percent = accountTotal > 0 and (group.total / accountTotal * 100) or 0
			local barPercent = topGroupTotal > 0 and (group.total / topGroupTotal) or 0

			row = tooltip:AddRow()
			row:GetCell(1):SetText(group.label):SetTextColor(r, g, b)

			if showBars then
				-- Use cell background colors as visual bar
				-- SetMinWidth must be set before SetText so OnContentChanged uses the correct minimum
				local fillWidth = math.max(1, math.floor(barPercent * 80 + 0.5))
				local emptyWidth = math.max(1, 80 - fillWidth)
				row:GetCell(2):SetMinWidth(fillWidth):SetText(' '):SetColor(r, g, b, 0.7)
				row:GetCell(3):SetMinWidth(emptyWidth):SetText(' '):SetColor(0.15, 0.15, 0.15, 0.5)
			else
				row:GetCell(2):SetText('')
				row:GetCell(3):SetText('')
			end

			row:GetCell(4):SetText(string.format('%.0f%%', percent)):SetTextColor(0.8, 0.8, 0.8)
			row:GetCell(5):SetText(self.FormatTime(group.total, 'smart')):SetTextColor(0.8, 0.8, 0.8)

			-- Individual characters under each group
			for _, char in ipairs(group.chars) do
				local cr, cg, cb = 0.6, 0.6, 0.6
				if groupBy ~= 'class' then
					local charColor = RAID_CLASS_COLORS[char.classFile]
					if charColor then
						cr, cg, cb = charColor.r, charColor.g, charColor.b
					end
				end

				row = tooltip:AddRow()
				row:GetCell(1):SetText('  ' .. char.name .. ' (' .. char.level .. ')'):SetTextColor(cr, cg, cb):SetColSpan(4)
				row:GetCell(5):SetText(self.FormatTime(char.totalPlayed, 'smart')):SetTextColor(0.6, 0.6, 0.6)
			end
		end

		-- Milestones
		if self.GetMilestones and self.db.display.showMilestones then
			local milestones = self:GetMilestones(sortedGroups, accountTotal)
			if #milestones > 0 then
				tooltip:AddSeparator()
				for _, milestone in ipairs(milestones) do
					row = tooltip:AddRow()
					row:GetCell(1):SetText(milestone):SetTextColor(0.7, 0.7, 0.7):SetColSpan(5)
				end
			end
		end
	end

	-- Click hints
	tooltip:AddSeparator()
	row = tooltip:AddRow()
	row:GetCell(1):SetText('Left Click: Cycle Format'):SetTextColor(1, 1, 0):SetColSpan(5)
	row = tooltip:AddRow()
	row:GetCell(1):SetText('Shift+Left: Toggle Window  |  Right: Options'):SetTextColor(1, 1, 0):SetColSpan(5)
	row = tooltip:AddRow()
	row:GetCell(1):SetText('Middle Click: Refresh /played'):SetTextColor(1, 1, 0):SetColSpan(5)

	tooltip:SmartAnchorTo(anchorFrame)
	tooltip:SetAutoHideDelay(0.1, anchorFrame)
	tooltip:UpdateLayout()
	tooltip:Show()

	return tooltip
end
