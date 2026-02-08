---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

local LibQTip = LibStub('LibQTip-2.0')

local DEFAULT_FONT_SIZE = 10
local MAX_ROWS = 120
local STREAK_PANE_WIDTH = 188 -- 7 cols * 22px + 4px padding + 30px scrollbar/margin

-- Dynamically computed row heights based on font size
local function GetRowHeight()
	local fontSize = LibsTimePlayed.db and LibsTimePlayed.db.display.fontSize or DEFAULT_FONT_SIZE
	return fontSize + 12
end

local function GetCharRowHeight()
	local fontSize = LibsTimePlayed.db and LibsTimePlayed.db.display.fontSize or DEFAULT_FONT_SIZE
	return fontSize + 8
end

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

---Check which external addons (AltVault, Altoholic) have a character
---@param charName string Character name
---@param charRealm string Realm name
---@return string[] sources List of addon names that have this character
local function GetExternalSourcesForChar(charName, charRealm)
	local sources = {}
	-- Check AltVault
	if _G.AltVaultDB and _G.AltVaultDB.characters then
		for _, entry in pairs(_G.AltVaultDB.characters) do
			if type(entry) == 'table' and entry.character and entry.character.name == charName and entry.character.realm == charRealm then
				table.insert(sources, 'AltVault')
				break
			end
		end
	end
	-- Check Altoholic
	if _G.DataStore_CharacterDB and _G.DataStore_CharacterDB.global and _G.DataStore_CharacterDB.global.Characters then
		local altKey = 'Default.' .. charRealm .. '.' .. charName
		if _G.DataStore_CharacterDB.global.Characters[altKey] then
			table.insert(sources, 'Altoholic')
		end
	end
	return sources
end

---Delete a character from AltVault's database
---@param charName string Character name
---@param charRealm string Realm name
local function DeleteFromAltVault(charName, charRealm)
	if not _G.AltVaultDB or not _G.AltVaultDB.characters then
		return
	end
	for key, entry in pairs(_G.AltVaultDB.characters) do
		if type(entry) == 'table' and entry.character and entry.character.name == charName and entry.character.realm == charRealm then
			_G.AltVaultDB.characters[key] = nil
			return
		end
	end
end

---Delete a character from Altoholic's database
---@param charName string Character name
---@param charRealm string Realm name
local function DeleteFromAltoholic(charName, charRealm)
	if not _G.DataStore_CharacterDB or not _G.DataStore_CharacterDB.global or not _G.DataStore_CharacterDB.global.Characters then
		return
	end
	local altKey = 'Default.' .. charRealm .. '.' .. charName
	_G.DataStore_CharacterDB.global.Characters[altKey] = nil
end

---Apply the configured font size to a FontString
---@param fontString FontString
local function ApplyFont(fontString)
	local fontSize = LibsTimePlayed.db and LibsTimePlayed.db.display.fontSize or DEFAULT_FONT_SIZE
	local fontFile = GameFontNormalSmall:GetFont()
	fontString:SetFont(fontFile, fontSize, '')
end

-- WoW max character name = 12 chars. Longest display: "    Characternam (80)" = ~21 chars + 4 buffer
-- We measure the max label width using the current font, then cap at that
local MAX_LABEL_CHARS = 20 -- "    " indent (4) + 12 char name + " (80)" (5) + 2 buffer

---Compute label width: scales with row width but caps at the max name length
---@param rowWidth number Total row width
---@return number labelWidth
local function GetLabelWidth(rowWidth)
	local fontSize = LibsTimePlayed.db and LibsTimePlayed.db.display.fontSize or DEFAULT_FONT_SIZE
	-- Approximate max label width from font size and max chars
	local maxLabelWidth = MAX_LABEL_CHARS * fontSize * 0.6
	-- Give label ~30% of row width, but never more than the max
	local dynamicWidth = rowWidth * 0.25
	return math.min(math.max(dynamicWidth, 90), maxLabelWidth)
end

---Create a single data row with label, bar, percent, and value
---@param parent Frame
---@param width number
---@return Frame
local function CreateRow(parent, width)
	local row = CreateFrame('Frame', nil, parent)
	row:SetHeight(GetRowHeight())
	row:SetWidth(width)

	-- Expand indicator
	local expandIcon = row:CreateTexture(nil, 'OVERLAY')
	expandIcon:SetPoint('LEFT', row, 'LEFT', 4, 0)
	expandIcon:SetSize(12, 12)
	expandIcon:SetAtlas('common-dropdown-icon-next')
	row.expandIcon = expandIcon

	-- Faction icon (atlas texture)
	local factionIcon = row:CreateTexture(nil, 'OVERLAY')
	factionIcon:SetPoint('LEFT', expandIcon, 'RIGHT', 2, 0)
	factionIcon:SetSize(14, 14)
	row.factionIcon = factionIcon

	-- Group/class label
	local label = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	label:SetPoint('LEFT', factionIcon, 'RIGHT', 2, 0)
	label:SetWidth(GetLabelWidth(width))
	label:SetJustifyH('LEFT')
	ApplyFont(label)
	row.label = label

	-- Value text (right side)
	local valueText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	valueText:SetPoint('RIGHT', row, 'RIGHT', -4, 0)
	valueText:SetWidth(80)
	valueText:SetJustifyH('RIGHT')
	ApplyFont(valueText)
	row.valueText = valueText

	-- Percent text
	local percentText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	percentText:SetPoint('RIGHT', valueText, 'LEFT', -4, 0)
	percentText:SetWidth(45)
	percentText:SetJustifyH('RIGHT')
	ApplyFont(percentText)
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
	row:SetHeight(GetRowHeight())

	-- Expand/collapse indicator (common-dropdown-icon-next: default points right)
	if hasChars then
		row.expandIcon:Show()
		if isExpanded then
			-- Point down: rotate 90 degrees clockwise
			row.expandIcon:SetRotation(math.rad(-90))
		else
			-- Point right: no rotation needed
			row.expandIcon:SetRotation(0)
		end
	else
		row.expandIcon:Hide()
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
	row:SetHeight(GetCharRowHeight())

	-- No expand indicator for char rows
	row.expandIcon:Hide()

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
	row.label:SetWidth(GetLabelWidth(row:GetWidth()))

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
		width = self.db.popup.width or 700,
		height = self.db.popup.height or 300,
		hidePortrait = true,
		resizable = true,
		minWidth = 550,
		minHeight = 200,
	})

	-- Create control frame for dropdown
	local controlFrame = LibAT.UI.CreateControlFrame(window)

	-- Settings button (gear icon, positioned at right)
	local settingsButton = LibAT.UI.CreateIconButton(controlFrame, 'Warfronts-BaseMapIcons-Empty-Workshop', 'Warfronts-BaseMapIcons-Alliance-Workshop', 'Warfronts-BaseMapIcons-Horde-Workshop')
	settingsButton:SetPoint('RIGHT', controlFrame, 'RIGHT', -5, 5)
	settingsButton:SetScript('OnClick', function()
		LibsTimePlayed:OpenOptions()
	end)
	window.settingsButton = settingsButton

	-- Streak toggle button (calendar icon, to the left of settings)
	local streakButton = LibAT.UI.CreateIconButton(controlFrame, 'ui-hud-calendar-1-up', 'ui-hud-calendar-1-mouseover', 'ui-hud-calendar-1-down')
	streakButton:SetPoint('RIGHT', settingsButton, 'LEFT', -5, -2)
	streakButton:SetScript('OnClick', function()
		LibsTimePlayed.db.display.showStreaks = not LibsTimePlayed.db.display.showStreaks
		LibsTimePlayed:UpdatePopup()
	end)
	window.streakButton = streakButton

	-- Refresh button (to the left of streak toggle)
	local refreshButton = LibAT.UI.CreateIconButton(controlFrame, 'uitools-icon-refresh', 'uitools-icon-refresh', 'uitools-icon-refresh')
	refreshButton:SetPoint('RIGHT', streakButton, 'LEFT', -5, 2)
	refreshButton:SetScript('OnClick', function()
		RequestTimePlayed()
	end)
	refreshButton:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:AddLine('Refresh /played data')
		GameTooltip:Show()
	end)
	refreshButton:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)
	window.refreshButton = refreshButton

	-- Group By dropdown (modern style, positioned before settings button)
	local groupDropdown = LibAT.UI.CreateDropdown(controlFrame, 'Group By', 130, 22)
	groupDropdown:SetPoint('LEFT', controlFrame, 'LEFT', 10, 2)

	-- Setup dropdown generator function
	groupDropdown:SetupMenu(function(dropdown, rootDescription)
		rootDescription:SetTag('MENU_TIME_PLAYED_GROUP_BY')

		for _, item in ipairs(GROUPBY_ITEMS) do
			local button = rootDescription:CreateRadio(item.label, function()
				return LibsTimePlayed.db.display.groupBy == item.key
			end, function()
				LibsTimePlayed.db.display.groupBy = item.key
				LibsTimePlayed:UpdatePopup()
			end)
		end
	end)

	-- Set initial dropdown text based on current groupBy
	local currentGroupBy = self.db.display.groupBy or 'class'
	groupDropdown:SetText('Group: ' .. GROUPBY_LABELS[currentGroupBy])

	window.groupDropdown = groupDropdown

	-- Create content area below control frame
	local contentFrame = LibAT.UI.CreateContentFrame(window, controlFrame)

	-- Right pane: streak display (fixed width, anchored to right edge)
	local rightPane = CreateFrame('Frame', nil, contentFrame)
	rightPane:SetWidth(STREAK_PANE_WIDTH)
	rightPane:SetPoint('TOPRIGHT', contentFrame, 'TOPRIGHT', 0, 0)
	rightPane:SetPoint('BOTTOMRIGHT', contentFrame, 'BOTTOMRIGHT', 0, 0)
	window.rightPane = rightPane

	-- Vertical divider between panes
	local paneDivider = contentFrame:CreateTexture(nil, 'OVERLAY')
	paneDivider:SetColorTexture(0.3, 0.3, 0.3, 0.8)
	paneDivider:SetWidth(1)
	paneDivider:SetPoint('TOPRIGHT', rightPane, 'TOPLEFT', -2, 0)
	paneDivider:SetPoint('BOTTOMRIGHT', rightPane, 'BOTTOMLEFT', -2, 20)
	window.paneDivider = paneDivider

	-- Left pane: character data (fills remaining space)
	local leftPane = CreateFrame('Frame', nil, contentFrame)
	leftPane:SetPoint('TOPLEFT', contentFrame, 'TOPLEFT', 0, 0)
	leftPane:SetPoint('BOTTOMRIGHT', paneDivider, 'BOTTOMLEFT', -2, 0)
	window.leftPane = leftPane

	-- Create scroll frame in the left pane
	local scrollFrame = LibAT.UI.CreateScrollFrame(leftPane)
	scrollFrame:SetPoint('TOPLEFT', leftPane, 'TOPLEFT', 4, 0)
	scrollFrame:SetPoint('BOTTOMRIGHT', leftPane, 'BOTTOMRIGHT', -4, 0)
	window.scrollFrame = scrollFrame

	-- Create scroll child
	local scrollChild = CreateFrame('Frame', nil, scrollFrame)
	scrollChild:SetWidth(1) -- Will be set dynamically
	scrollChild:SetHeight(1) -- Will be set dynamically based on content
	scrollFrame:SetScrollChild(scrollChild)
	window.scrollChild = scrollChild

	-- Create row pool
	for i = 1, MAX_ROWS do
		local row = CreateRow(scrollChild, scrollFrame:GetWidth() - 20)
		row:Hide()
		rows[i] = row
	end

	-- Create scroll frame for the right (streak) pane
	local streakScrollFrame = LibAT.UI.CreateScrollFrame(rightPane)
	streakScrollFrame:SetPoint('TOPLEFT', rightPane, 'TOPLEFT', 0, 0)
	streakScrollFrame:SetPoint('BOTTOMRIGHT', rightPane, 'BOTTOMRIGHT', -4, 20)
	window.streakScrollFrame = streakScrollFrame

	-- Create scroll child for streak pane
	local streakScrollChild = CreateFrame('Frame', nil, streakScrollFrame)
	streakScrollChild:SetWidth(STREAK_PANE_WIDTH - 20)
	streakScrollChild:SetHeight(1) -- Will be set based on content
	streakScrollFrame:SetScrollChild(streakScrollChild)
	window.streakScrollChild = streakScrollChild

	-- Create streak pane content inside the scroll child
	self:CreateStreakPane(streakScrollChild)

	-- Total text (bottom)
	local totalText = window:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	totalText:SetPoint('BOTTOMLEFT', window, 'BOTTOMLEFT', 15, 7)
	totalText:SetJustifyH('LEFT')
	window.totalText = totalText

	-- Milestone text (bottom right)
	local milestoneText = window:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	milestoneText:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -20, 7)
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

	-- Recalculate pane widths and row widths on resize
	window:HookScript('OnSizeChanged', function()
		if not window:IsShown() then
			return
		end

		-- Re-layout the content (UpdatePopup handles pane widths and row widths)
		self:UpdatePopup()
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
		popupFrame.groupDropdown:SetText('Group: ' .. GROUPBY_LABELS[groupBy])
	end

	-- Manage pane layout based on showStreaks setting
	local showStreaks = self.db.display.showStreaks

	if showStreaks then
		popupFrame.rightPane:Show()
		popupFrame.paneDivider:Show()
		-- Left pane shrinks: anchored to divider
		popupFrame.leftPane:ClearAllPoints()
		popupFrame.leftPane:SetPoint('TOPLEFT', popupFrame.leftPane:GetParent(), 'TOPLEFT', 0, 0)
		popupFrame.leftPane:SetPoint('BOTTOMRIGHT', popupFrame.paneDivider, 'BOTTOMLEFT', -2, 0)
		-- Shift left scrollbar inward so it doesn't crowd the divider
		popupFrame.scrollFrame:ClearAllPoints()
		popupFrame.scrollFrame:SetPoint('TOPLEFT', popupFrame.leftPane, 'TOPLEFT', 4, 0)
		popupFrame.scrollFrame:SetPoint('BOTTOMRIGHT', popupFrame.leftPane, 'BOTTOMRIGHT', -14, 0)
		if popupFrame.streakButton then
			popupFrame.streakButton.NormalTexture:SetDesaturated(false)
		end
	else
		popupFrame.rightPane:Hide()
		popupFrame.paneDivider:Hide()
		-- Left pane fills full content area
		popupFrame.leftPane:ClearAllPoints()
		popupFrame.leftPane:SetPoint('TOPLEFT', popupFrame.leftPane:GetParent(), 'TOPLEFT', 0, 0)
		popupFrame.leftPane:SetPoint('BOTTOMRIGHT', popupFrame.leftPane:GetParent(), 'BOTTOMRIGHT', 0, 0)
		-- Reset left scrollbar to normal position
		popupFrame.scrollFrame:ClearAllPoints()
		popupFrame.scrollFrame:SetPoint('TOPLEFT', popupFrame.leftPane, 'TOPLEFT', 4, 0)
		popupFrame.scrollFrame:SetPoint('BOTTOMRIGHT', popupFrame.leftPane, 'BOTTOMRIGHT', -4, 20)
		if popupFrame.streakButton then
			popupFrame.streakButton.NormalTexture:SetDesaturated(true)
		end
	end

	-- Update row widths for the left pane
	local rowWidth = popupFrame.scrollFrame:GetWidth() - 20
	for i = 1, MAX_ROWS do
		local row = rows[i]
		if row then
			row:SetWidth(rowWidth)
			row.label:SetWidth(GetLabelWidth(rowWidth))
		end
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

		-- Click handler for expand/collapse + right-click delete for single-char groups
		row:SetScript('OnMouseDown', function(_, button)
			if button == 'RightButton' and #group.chars == 1 then
				self:ShowCharacterContextMenu(row, group.chars[1])
			elseif button == 'LeftButton' and hasChars then
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

		yOffset = yOffset + GetRowHeight()

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

				-- Right-click to delete character
				charRow:SetScript('OnMouseDown', function(_, button)
					if button == 'RightButton' then
						self:ShowCharacterContextMenu(charRow, char)
					end
				end)
				charRow:SetScript('OnEnter', nil)
				charRow:SetScript('OnLeave', nil)

				yOffset = yOffset + GetCharRowHeight()
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

	-- Update streak pane
	if showStreaks and self.UpdateStreakPane then
		self:UpdateStreakPane()
	end
end

---Apply font size to all existing popup rows and refresh
function LibsTimePlayed:ApplyFontSize()
	if not popupFrame then
		return
	end

	local rowWidth = popupFrame.scrollFrame:GetWidth() - 20
	for i = 1, MAX_ROWS do
		local row = rows[i]
		if row then
			ApplyFont(row.label)
			ApplyFont(row.valueText)
			ApplyFont(row.percentText)
			row.label:SetWidth(GetLabelWidth(rowWidth))
		end
	end

	-- Refresh layout with new row heights
	self:UpdatePopup()
end

---Show a right-click context menu for a character using LibQTip-2.0
---@param anchor Frame The frame to anchor the menu to
---@param char table Character data with key, name, realm fields
function LibsTimePlayed:ShowCharacterContextMenu(anchor, char)
	-- Don't allow deleting current character
	local currentKey = GetNormalizedRealmName() .. '-' .. UnitName('player')
	if char.key == currentKey then
		return
	end

	-- Release any previous context menu tooltip
	if self.contextMenuTooltip then
		LibQTip:ReleaseTooltip(self.contextMenuTooltip)
		self.contextMenuTooltip = nil
	end

	local tooltip = LibQTip:AcquireTooltip('LibsTPContextMenu', 1, 'LEFT')
	self.contextMenuTooltip = tooltip
	tooltip:Clear()

	-- Title row (character name)
	local titleRow = tooltip:AddHeadingRow()
	titleRow:GetCell(1):SetText(char.name .. ' - ' .. char.realm)

	-- Delete button row
	local deleteRow = tooltip:AddRow()
	local deleteCell = deleteRow:GetCell(1)
	deleteCell:SetText('|cffff4444Delete Character|r')
	deleteCell:SetScript('OnMouseDown', function()
		LibQTip:ReleaseTooltip(tooltip)
		self.contextMenuTooltip = nil
		self:HandleDeleteCharacter(char)
	end)

	tooltip:SmartAnchorTo(anchor)
	tooltip:SetAutoHideDelay(0.25, anchor)
	tooltip:Show()
end

---Handle character deletion, checking for external addon data
---@param char table Character data with key, name, realm fields
function LibsTimePlayed:HandleDeleteCharacter(char)
	local externalSources = GetExternalSourcesForChar(char.name, char.realm)

	if #externalSources == 0 then
		-- No external addons — delete immediately, no confirmation
		self.globaldb.characters[char.key] = nil
		self:Print('Removed ' .. char.name .. ' - ' .. char.realm)
		self:UpdatePopup()
	else
		-- External addons found — show confirmation dialog
		self:ShowDeleteConfirmDialog(char, externalSources)
	end
end

---Show a confirmation dialog when external addons have the character
---Uses the same visual style as the import dialog in Import.lua
---@param char table Character data with key, name, realm fields
---@param externalSources string[] List of external addon names
function LibsTimePlayed:ShowDeleteConfirmDialog(char, externalSources)
	-- Destroy previous dialog if it exists
	if _G['LibsTPDeleteDialog'] then
		_G['LibsTPDeleteDialog']:Hide()
		_G['LibsTPDeleteDialog']:SetParent(nil)
		_G['LibsTPDeleteDialog'] = nil
	end

	local dialogWidth = 360
	local dialogHeight = 180

	-- Create dialog frame
	local dialog = CreateFrame('Frame', 'LibsTPDeleteDialog', UIParent, 'BackdropTemplate')
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
	local sourceList = table.concat(externalSources, ', ')
	local message = char.name .. ' - ' .. char.realm .. '\n\nAlso found in: ' .. sourceList .. '\n\nDelete from these as well?'

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

	-- Button definitions
	local buttons = {
		{
			text = 'Delete All',
			onClick = function()
				-- Delete from our DB
				self.globaldb.characters[char.key] = nil
				-- Delete from external addons
				for _, source in ipairs(externalSources) do
					if source == 'AltVault' then
						DeleteFromAltVault(char.name, char.realm)
					elseif source == 'Altoholic' then
						DeleteFromAltoholic(char.name, char.realm)
					end
				end
				self:Print('Removed ' .. char.name .. ' - ' .. char.realm .. ' from TimePlayed and ' .. sourceList)
				self:UpdatePopup()
			end,
		},
		{
			text = 'Only TimePlayed',
			onClick = function()
				self.globaldb.characters[char.key] = nil
				self:Print('Removed ' .. char.name .. ' - ' .. char.realm)
				self:UpdatePopup()
			end,
		},
		{
			text = 'Cancel',
			onClick = function() end,
		},
	}

	-- Create buttons
	local buttonWidth = math.min(130, (dialogWidth - 20 - (#buttons - 1) * 6) / #buttons)
	local totalButtonsWidth = (#buttons * buttonWidth) + ((#buttons - 1) * 6)
	local startX = -totalButtonsWidth / 2

	for i, btnDef in ipairs(buttons) do
		local btn = LibAT.UI.CreateButton(dialog, buttonWidth, 26, btnDef.text, true)
		btn:SetPoint('BOTTOM', dialog, 'BOTTOM', startX + (i - 1) * (buttonWidth + 6) + buttonWidth / 2, 14)
		btn:SetScript('OnClick', function()
			dialog:Hide()
			btnDef.onClick()
		end)
	end

	-- Allow Escape to close
	tinsert(UISpecialFrames, 'LibsTPDeleteDialog')

	dialog:Show()
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
