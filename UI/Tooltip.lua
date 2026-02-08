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
	local tooltip = LibQTip:AcquireTooltip('LibsTimePlayedTooltip', 3, 'LEFT', 'RIGHT', 'RIGHT')
	tooltip:Clear()

	-- Title
	local row = tooltip:AddHeadingRow()
	row:GetCell(1):SetText("Lib's TimePlayed"):SetColSpan(3):SetJustifyH('CENTER')

	if not self:HasPlayedData() then
		row = tooltip:AddRow()
		row:GetCell(1):SetText('Waiting for /played data...'):SetColSpan(3):SetJustifyH('CENTER'):SetTextColor(0.7, 0.7, 0.7)
		tooltip:SmartAnchorTo(anchorFrame)
		tooltip:SetAutoHideDelay(0.1, anchorFrame)
		tooltip:Show()
		return tooltip
	end

	-- Current character info
	local name = UnitName('player')
	local _, classFile = UnitClass('player')
	local color = RAID_CLASS_COLORS[classFile]

	tooltip:AddSeparator()

	row = tooltip:AddRow()
	local nameCell = row:GetCell(1):SetColSpan(3)
	if color then
		nameCell:SetText(name .. ' (Lv ' .. UnitLevel('player') .. ')'):SetTextColor(color.r, color.g, color.b)
	else
		nameCell:SetText(name .. ' (Lv ' .. UnitLevel('player') .. ')')
	end

	row = tooltip:AddRow()
	row:GetCell(1):SetText('  Total:'):SetTextColor(0.8, 0.8, 0.8)
	row:GetCell(2):SetText(self.FormatTime(self:GetTotalPlayed(), 'full')):SetColSpan(2):SetJustifyH('RIGHT')

	row = tooltip:AddRow()
	row:GetCell(1):SetText('  This Level:'):SetTextColor(0.8, 0.8, 0.8)
	row:GetCell(2):SetText(self.FormatTime(self:GetLevelPlayed(), 'full')):SetColSpan(2):SetJustifyH('RIGHT')

	row = tooltip:AddRow()
	row:GetCell(1):SetText('  Session:'):SetTextColor(0.8, 0.8, 0.8)
	row:GetCell(2):SetText(self.FormatTime(self:GetSessionTime(), 'full')):SetColSpan(2):SetJustifyH('RIGHT')

	-- Account summary using GetGroupedData
	local sortedGroups, accountTotal = self:GetGroupedData()
	local groupBy = self.db.display.groupBy or 'class'

	if accountTotal > 0 then
		tooltip:AddSeparator()

		row = tooltip:AddRow()
		row:GetCell(1):SetText('Account Total'):SetTextColor(1, 0.82, 0)
		row:GetCell(2):SetText(self.FormatTime(accountTotal, 'smart')):SetColSpan(2):SetJustifyH('RIGHT'):SetTextColor(1, 1, 1)

		row = tooltip:AddRow()
		row:GetCell(1):SetText('Grouped by: ' .. GROUPBY_LABELS[groupBy]):SetTextColor(0.5, 0.5, 0.5):SetColSpan(3)

		-- Count total characters to determine if we should hide individual character details
		local totalCharCount = 0
		for _, group in ipairs(sortedGroups) do
			totalCharCount = totalCharCount + #group.chars
		end
		local hideCharacters = totalCharCount >= 10

		for _, group in ipairs(sortedGroups) do
			local clr = group.color
			local r, g, b = clr.r, clr.g, clr.b

			local percent = accountTotal > 0 and (group.total / accountTotal * 100) or 0

			row = tooltip:AddRow()
			row:GetCell(1):SetText(group.label):SetTextColor(r, g, b)
			row:GetCell(2):SetText(string.format('%.0f%%', percent)):SetTextColor(0.8, 0.8, 0.8)
			row:GetCell(3):SetText(self.FormatTime(group.total, 'smart')):SetTextColor(0.8, 0.8, 0.8)

			-- Individual characters under each group
			-- Hide if: 10+ total characters OR only 1 character in this group
			local showCharacters = not hideCharacters and #group.chars > 1
			if showCharacters then
				for _, char in ipairs(group.chars) do
					local cr, cg, cb = 0.6, 0.6, 0.6
					if groupBy ~= 'class' then
						local charColor = RAID_CLASS_COLORS[char.classFile]
						if charColor then
							cr, cg, cb = charColor.r, charColor.g, charColor.b
						end
					end

					row = tooltip:AddRow()
					row:GetCell(1):SetText('  ' .. char.name .. ' (' .. char.level .. ')'):SetTextColor(cr, cg, cb):SetColSpan(2)
					row:GetCell(3):SetText(self.FormatTime(char.totalPlayed, 'smart')):SetTextColor(0.6, 0.6, 0.6)
				end
			end
		end

		-- Milestones
		if self.GetMilestones and self.db.display.showMilestones then
			local milestones = self:GetMilestones(sortedGroups, accountTotal)
			if #milestones > 0 then
				tooltip:AddSeparator()
				for _, milestone in ipairs(milestones) do
					row = tooltip:AddRow()
					row:GetCell(1):SetText(milestone):SetTextColor(0.7, 0.7, 0.7):SetColSpan(3)
				end
			end
		end

		-- Play Streaks
		if self.GetStreakInfo and self.db.display.showStreaks then
			local streakInfo = self:GetStreakInfo()
			if streakInfo.currentStreak > 0 or streakInfo.totalSessions > 0 then
				tooltip:AddSeparator()

				-- Section header
				row = tooltip:AddRow()
				row:GetCell(1):SetText('Play Streak'):SetTextColor(1, 0.82, 0):SetColSpan(3)

				-- Current / Longest streak
				row = tooltip:AddRow()
				row:GetCell(1):SetText('  Current: |cff00ff00' .. streakInfo.currentStreak .. ' day' .. (streakInfo.currentStreak ~= 1 and 's' or '') .. '|r'):SetColSpan(1)
				row:GetCell(2):SetText('Longest: |cff00ff00' .. streakInfo.longestStreak .. ' day' .. (streakInfo.longestStreak ~= 1 and 's' or '') .. '|r'):SetColSpan(2):SetJustifyH('RIGHT')

				-- Average session / Total sessions
				local avgText = string.format('%.1fh', streakInfo.averageSessionMinutes / 60)
				row = tooltip:AddRow()
				row:GetCell(1):SetText('  Avg Session: |cffffffff' .. avgText .. '|r'):SetColSpan(1)
				row:GetCell(2):SetText('Sessions: |cffffffff' .. streakInfo.totalSessions .. '|r'):SetColSpan(2):SetJustifyH('RIGHT')

				-- 14-day timeline
				if streakInfo.timeline ~= '' then
					row = tooltip:AddRow()
					row:GetCell(1):SetText('  ' .. streakInfo.timeline):SetColSpan(3)
				end
			end
		end
	end

	-- Click hints
	tooltip:AddSeparator()
	row = tooltip:AddRow()
	row:GetCell(1):SetText('Left Click: Cycle Format'):SetTextColor(1, 1, 0):SetColSpan(3)
	row = tooltip:AddRow()
	row:GetCell(1):SetText('Shift+Left: Toggle Window  |  Right: Options'):SetTextColor(1, 1, 0):SetColSpan(3)
	row = tooltip:AddRow()
	row:GetCell(1):SetText('Middle Click: Refresh /played'):SetTextColor(1, 1, 0):SetColSpan(3)

	tooltip:SmartAnchorTo(anchorFrame)
	tooltip:SetAutoHideDelay(0.1, anchorFrame)
	tooltip:Show()

	return tooltip
end
