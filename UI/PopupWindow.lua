---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

local ROW_HEIGHT = 22
local CHAR_ROW_HEIGHT = 18
local MAX_ROWS = 120

local GROUPBY_ITEMS = {
	{ key = 'class', label = 'Class' },
	{ key = 'realm', label = 'Realm' },
	{ key = 'faction', label = 'Faction' },
	{ key = 'none', label = 'All Characters' },
}

local GROUPBY_LABELS = {
	class = 'Class',
	realm = 'Realm',
	faction = 'Faction',
	none = 'All Characters',
}

-- Faction atlas mappings
local FACTION_ATLAS = {
	Alliance = 'questlog-questtypeicon-alliance',
	Horde = 'questlog-questtypeicon-horde',
}

-- Row pool
local rows = {}
local popupFrame
local expandedGroups = {} -- tracks which groups are expanded by key

---Create a single data row with label, bar, percent, and value
---@param parent Frame
---@param width number
---@return Frame
local function CreateRow(parent, width)
	local row = CreateFrame('Frame', nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:SetWidth(width)

	-- Expand indicator
	local expandIcon = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	expandIcon:SetPoint('LEFT', row, 'LEFT', 4, 0)
	expandIcon:SetWidth(12)
	expandIcon:SetJustifyH('LEFT')
	row.expandIcon = expandIcon

	-- Faction icon (atlas texture)
	local factionIcon = row:CreateTexture(nil, 'OVERLAY')
	factionIcon:SetPoint('LEFT', expandIcon, 'RIGHT', 2, 0)
	factionIcon:SetSize(14, 14)
	row.factionIcon = factionIcon

	-- Group/class label
	local label = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	label:SetPoint('LEFT', factionIcon, 'RIGHT', 2, 0)
	label:SetWidth(90)
	label:SetJustifyH('LEFT')
	row.label = label

	-- Value text (right side)
	local valueText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	valueText:SetPoint('RIGHT', row, 'RIGHT', -4, 0)
	valueText:SetWidth(80)
	valueText:SetJustifyH('RIGHT')
	row.valueText = valueText

	-- Percent text
	local percentText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	percentText:SetPoint('RIGHT', valueText, 'LEFT', -4, 0)
	percentText:SetWidth(45)
	percentText:SetJustifyH('RIGHT')
	row.percentText = percentText

	-- StatusBar between label and percent
	local bar = CreateFrame('StatusBar', nil, row)
	bar:SetPoint('LEFT', label, 'RIGHT', 4, 0)
	bar:SetPoint('RIGHT', percentText, 'LEFT', -4, 0)
	bar:SetHeight(14)
	bar:SetMinMaxValues(0, 1)
	bar:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar')

	local barBg = bar:CreateTexture(nil, 'BACKGROUND')
	barBg:SetAllPoints()
	barBg:SetColorTexture(0, 0, 0, 0.4)

	row.bar = bar

	-- Highlight texture for hover
	local highlight = row:CreateTexture(nil, 'HIGHLIGHT')
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.05)
	row.highlight = highlight

	-- Enable mouse for click and hover
	row:EnableMouse(true)

	return row
end

---Show GameTooltip with character breakdown for a group
---@param row Frame
---@param group table
local function ShowGroupTooltip(row, group)
	if #group.chars <= 1 then
		return
	end

	GameTooltip:SetOwner(row, 'ANCHOR_RIGHT')
	GameTooltip:AddLine(group.label, group.color.r, group.color.g, group.color.b)
	GameTooltip:AddLine(' ')

	for _, char in ipairs(group.chars) do
		local charColor = RAID_CLASS_COLORS[char.classFile]
		local r, g, b = 0.8, 0.8, 0.8
		if charColor then
			r, g, b = charColor.r, charColor.g, charColor.b
		end
		local charText = char.name .. ' (' .. char.level .. ')'
		local timeText = LibsTimePlayed.FormatTime(char.totalPlayed, 'smart')
		GameTooltip:AddDoubleLine(charText, timeText, r, g, b, 0.8, 0.8, 0.8)
	end

	GameTooltip:Show()
end

---Check if user plays both factions
---@return boolean playsBothFactions
local function PlaysBothFactions()
	local hasAlliance = false
	local hasHorde = false

	for _, data in pairs(LibsTimePlayed.globaldb.characters) do
		if data.faction == 'Alliance' then
			hasAlliance = true
		elseif data.faction == 'Horde' then
			hasHorde = true
		end
		if hasAlliance and hasHorde then
			return true
		end
	end

	return false
end

---Setup a group row
---@param row Frame
---@param group table
---@param barPercent number
---@param percent number
---@param isExpanded boolean
---@param hasChars boolean
local function SetupGroupRow(row, group, barPercent, percent, isExpanded, hasChars)
	row:SetHeight(ROW_HEIGHT)

	-- Expand/collapse indicator
	if hasChars then
		row.expandIcon:SetText(isExpanded and '▼' or '▶')
		row.expandIcon:SetTextColor(0.8, 0.8, 0.8)
	else
		row.expandIcon:SetText('')
	end

	-- Faction icon (only show if player plays both factions and this is faction grouping)
	local groupBy = LibsTimePlayed.db.display.groupBy or 'class'
	local showFactionIcon = groupBy ~= 'faction' and PlaysBothFactions()

	if showFactionIcon then
		-- Determine faction for this group
		local factionForGroup = nil
		if #group.chars > 0 then
			-- Use the first character's faction as representative
			factionForGroup = group.chars[1].faction
		end

		if factionForGroup and FACTION_ATLAS[factionForGroup] then
			row.factionIcon:SetAtlas(FACTION_ATLAS[factionForGroup])
			row.factionIcon:Show()
		else
			row.factionIcon:Hide()
		end
	else
		row.factionIcon:Hide()
	end

	-- Group label
	row.label:SetText(group.label)
	row.label:SetTextColor(group.color.r, group.color.g, group.color.b)

	-- Bar
	row.bar:SetValue(barPercent)
	row.bar:SetStatusBarColor(group.color.r, group.color.g, group.color.b, 0.8)
	row.bar:Show()

	-- Percent
	row.percentText:SetText(string.format('%.0f%%', percent))
	row.percentText:SetTextColor(0.8, 0.8, 0.8)

	-- Value
	row.valueText:SetText(LibsTimePlayed.FormatTime(group.total, 'smart'))
	row.valueText:SetTextColor(0.9, 0.9, 0.9)

	-- Mark as group row
	row.groupData = group
	row.isGroupRow = true
	row.isCharRow = false

	row:Show()
end

---Setup a character row
---@param row Frame
---@param char table
---@param groupBy string
---@param groupTotal number
---@param groupColor table
local function SetupCharRow(row, char, groupBy, groupTotal, groupColor)
	row:SetHeight(CHAR_ROW_HEIGHT)

	-- No expand indicator for char rows
	row.expandIcon:SetText('')

	-- Faction icon for character rows (if player plays both factions)
	if PlaysBothFactions() and char.faction and FACTION_ATLAS[char.faction] then
		row.factionIcon:SetAtlas(FACTION_ATLAS[char.faction])
		row.factionIcon:Show()
	else
		row.factionIcon:Hide()
	end

	-- Character name with indent
	local cr, cg, cb = 0.7, 0.7, 0.7
	if groupBy ~= 'class' then
		local charColor = RAID_CLASS_COLORS[char.classFile]
		if charColor then
			cr, cg, cb = charColor.r, charColor.g, charColor.b
		end
	else
		cr, cg, cb = groupColor.r, groupColor.g, groupColor.b
	end

	row.label:SetText('    ' .. char.name .. ' (' .. char.level .. ')')
	row.label:SetTextColor(cr, cg, cb)
	row.label:SetWidth(90)

	-- Bar showing character's proportion of the group total
	local charPercent = groupTotal > 0 and (char.totalPlayed / groupTotal) or 0
	row.bar:SetValue(charPercent)
	row.bar:SetStatusBarColor(cr, cg, cb, 0.5)
	row.bar:Show()

	-- Percent of group
	row.percentText:SetText(string.format('%.0f%%', charPercent * 100))
	row.percentText:SetTextColor(0.6, 0.6, 0.6)

	-- Time value
	row.valueText:SetText(LibsTimePlayed.FormatTime(char.totalPlayed, 'smart'))
	row.valueText:SetTextColor(0.7, 0.7, 0.7)

	-- Mark as char row
	row.groupData = nil
	row.isGroupRow = false
	row.isCharRow = true

	row:Show()
end

---Create the popup window frame using LibAT.UI
---@return Frame
function LibsTimePlayed:CreatePopup()
	if popupFrame then
		return popupFrame
	end

	-- Check if LibAT.UI is available
	if not LibAT or not LibAT.UI or not LibAT.UI.CreateWindow then
		self:Log('LibAT.UI not available, cannot create popup window', 'error')
		return nil
	end

	-- Create window using LibAT.UI
	local window = LibAT.UI.CreateWindow({
		name = 'LibsTimePlayedPopup',
		title = 'Time Played',
		width = self.db.popup.width or 520,
		height = self.db.popup.height or 300,
		hidePortrait = true,
	})

	-- Create control frame for dropdown
	local controlFrame = LibAT.UI.CreateControlFrame(window)

	-- Group By dropdown
	local groupDropdown = CreateFrame('Frame', 'LibsTimePlayedGroupDropdown', controlFrame, 'UIDropDownMenuTemplate')
	groupDropdown:SetPoint('LEFT', controlFrame, 'LEFT', -10, 0)
	UIDropDownMenu_SetWidth(groupDropdown, 130)

	UIDropDownMenu_Initialize(groupDropdown, function(self, level)
		local info = UIDropDownMenu_CreateInfo()
		for _, item in ipairs(GROUPBY_ITEMS) do
			info.text = item.label
			info.value = item.key
			info.func = function()
				LibsTimePlayed.db.display.groupBy = item.key
				UIDropDownMenu_SetSelectedValue(groupDropdown, item.key)
				LibsTimePlayed:UpdatePopup()
			end
			info.checked = (LibsTimePlayed.db.display.groupBy == item.key)
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	local currentGroupBy = self.db.display.groupBy or 'class'
	UIDropDownMenu_SetSelectedValue(groupDropdown, currentGroupBy)
	UIDropDownMenu_SetText(groupDropdown, 'Group: ' .. GROUPBY_LABELS[currentGroupBy])

	window.groupDropdown = groupDropdown

	-- Create content area below control frame
	local contentFrame = LibAT.UI.CreateContentFrame(window, controlFrame)

	-- Create scroll frame using LibAT.UI (modern scrollbar)
	local scrollFrame = LibAT.UI.CreateScrollFrame(contentFrame)
	scrollFrame:SetPoint('TOPLEFT', contentFrame, 'TOPLEFT', 4, 0)
	scrollFrame:SetPoint('BOTTOMRIGHT', contentFrame, 'BOTTOMRIGHT', -4, 40)

	-- Create scroll child
	local scrollChild = CreateFrame('Frame', nil, scrollFrame)
	scrollChild:SetWidth(1) -- Will be set dynamically
	scrollChild:SetHeight(1) -- Will be set dynamically based on content
	scrollFrame:SetScrollChild(scrollChild)

	window.scrollFrame = scrollFrame
	window.scrollChild = scrollChild

	-- Create row pool
	for i = 1, MAX_ROWS do
		local row = CreateRow(scrollChild, scrollFrame:GetWidth() - 20)
		row:Hide()
		rows[i] = row
	end

	-- Total text (bottom)
	local totalText = window:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	totalText:SetPoint('BOTTOMLEFT', window, 'BOTTOMLEFT', 20, 16)
	totalText:SetJustifyH('LEFT')
	window.totalText = totalText

	-- Milestone text (bottom right)
	local milestoneText = window:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	milestoneText:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -20, 16)
	milestoneText:SetPoint('LEFT', totalText, 'RIGHT', 10, 0)
	milestoneText:SetJustifyH('RIGHT')
	milestoneText:SetTextColor(0.7, 0.7, 0.7)
	milestoneText:SetWordWrap(false)
	window.milestoneText = milestoneText

	-- Store config on hide
	window:SetScript('OnHide', function()
		local point, _, _, x, y = window:GetPoint()
		self.db.popup.point = point or 'CENTER'
		self.db.popup.x = x or 0
		self.db.popup.y = y or 0
		self.db.popup.width = window:GetWidth()
		self.db.popup.height = window:GetHeight()
	end)

	popupFrame = window
	return window
end

---Populate the popup with current data
function LibsTimePlayed:UpdatePopup()
	if not popupFrame then
		return
	end

	local groupBy = self.db.display.groupBy or 'class'

	-- Update dropdown text
	if popupFrame.groupDropdown then
		UIDropDownMenu_SetText(popupFrame.groupDropdown, 'Group: ' .. GROUPBY_LABELS[groupBy])
	end

	-- Get data
	local sortedGroups, accountTotal

	if groupBy == 'none' then
		-- Raw character list - create a single "All Characters" group
		sortedGroups = {}
		accountTotal = 0

		local allChars = {}
		for charKey, data in pairs(self.globaldb.characters) do
			if type(data) == 'table' and data.totalPlayed and data.classFile then
				local char = {
					key = charKey,
					name = data.name or charKey,
					realm = data.realm or '',
					class = data.class or data.classFile,
					classFile = data.classFile,
					faction = data.faction or 'Neutral',
					level = data.level or 0,
					totalPlayed = data.totalPlayed,
					levelPlayed = data.levelPlayed or 0,
					lastUpdated = data.lastUpdated or 0,
				}
				table.insert(allChars, char)
				accountTotal = accountTotal + data.totalPlayed
			end
		end

		-- Sort by totalPlayed descending
		table.sort(allChars, function(a, b)
			return a.totalPlayed > b.totalPlayed
		end)

		-- Create single group
		table.insert(sortedGroups, {
			key = 'all',
			label = 'All Characters',
			color = { r = 0.8, g = 0.8, b = 0.8 },
			chars = allChars,
			total = accountTotal,
		})
	else
		sortedGroups, accountTotal = self:GetGroupedData(groupBy)
	end

	-- Find top group total for bar scaling
	local topGroupTotal = 0
	if sortedGroups[1] then
		topGroupTotal = sortedGroups[1].total
	end

	-- Populate rows (groups + expanded character rows)
	local rowIndex = 0
	local yOffset = 0

	for _, group in ipairs(sortedGroups) do
		rowIndex = rowIndex + 1
		if rowIndex > MAX_ROWS then
			break
		end

		local barPercent = topGroupTotal > 0 and (group.total / topGroupTotal) or 0
		local percent = accountTotal > 0 and (group.total / accountTotal * 100) or 0
		local isExpanded = expandedGroups[group.key] or false
		local hasChars = #group.chars > 1

		local row = rows[rowIndex]
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', popupFrame.scrollChild, 'TOPLEFT', 0, -yOffset)
		SetupGroupRow(row, group, barPercent, percent, isExpanded, hasChars)

		-- Click handler for expand/collapse
		row:SetScript('OnMouseDown', function()
			if hasChars then
				expandedGroups[group.key] = not expandedGroups[group.key]
				self:UpdatePopup()
			end
		end)

		-- Hover handler for character tooltip
		row:SetScript('OnEnter', function(r)
			if hasChars then
				ShowGroupTooltip(r, group)
			end
		end)
		row:SetScript('OnLeave', function()
			GameTooltip:Hide()
		end)

		yOffset = yOffset + ROW_HEIGHT

		-- Show character detail rows if expanded
		if isExpanded and hasChars then
			for _, char in ipairs(group.chars) do
				rowIndex = rowIndex + 1
				if rowIndex > MAX_ROWS then
					break
				end

				local charRow = rows[rowIndex]
				charRow:ClearAllPoints()
				charRow:SetPoint('TOPLEFT', popupFrame.scrollChild, 'TOPLEFT', 0, -yOffset)
				SetupCharRow(charRow, char, groupBy, group.total, group.color)

				-- No special click/hover for char rows
				charRow:SetScript('OnMouseDown', nil)
				charRow:SetScript('OnEnter', nil)
				charRow:SetScript('OnLeave', nil)

				yOffset = yOffset + CHAR_ROW_HEIGHT
			end
		end
	end

	-- Hide unused rows
	for i = rowIndex + 1, MAX_ROWS do
		rows[i]:Hide()
	end

	-- Set content height
	popupFrame.scrollChild:SetHeight(yOffset)

	-- Total
	popupFrame.totalText:SetText('Account Total: ' .. self.FormatTime(accountTotal, 'full'))

	-- Milestones
	if self.GetMilestones and self.db.display.showMilestones then
		local milestones = self:GetMilestones(sortedGroups, accountTotal)
		popupFrame.milestoneText:SetText(table.concat(milestones, '  |  '))
		popupFrame.milestoneText:Show()
	else
		popupFrame.milestoneText:Hide()
	end
end

---Toggle popup visibility
function LibsTimePlayed:TogglePopup()
	local frame = self:CreatePopup()
	if not frame then
		return
	end

	if frame:IsShown() then
		frame:Hide()
	else
		self:UpdatePopup()
		frame:Show()
	end
end
