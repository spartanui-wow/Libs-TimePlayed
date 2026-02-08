---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

local ROW_HEIGHT = 22
local CHAR_ROW_HEIGHT = 18
local MAX_ROWS = 120 -- group rows + character rows combined
local GROUPBY_ITEMS = {
	{ key = 'class', label = 'Class' },
	{ key = 'realm', label = 'Realm' },
	{ key = 'faction', label = 'Faction' },
}
local GROUPBY_LABELS = {
	class = 'Class',
	realm = 'Realm',
	faction = 'Faction',
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

	-- Group/class label
	local label = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	label:SetPoint('LEFT', expandIcon, 'RIGHT', 2, 0)
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

---Update scrollbar visibility based on content height
---@param frame Frame The scroll frame
local function UpdateScrollBarVisibility(frame)
	if not frame.scrollBar then
		return
	end
	if frame:GetVerticalScrollRange() > 0 then
		frame.scrollBar:Show()
	else
		frame.scrollBar:Hide()
	end
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

---Create the popup window frame
---@return Frame
function LibsTimePlayed:CreatePopup()
	if popupFrame then
		return popupFrame
	end

	local db = self.db.popup

	-- Main frame
	local frame = CreateFrame('Frame', 'LibsTimePlayedPopup', UIParent, 'BackdropTemplate')
	frame:SetFrameStrata('DIALOG')
	frame:SetSize(db.width, db.height)
	frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(420, 200, 800, 600)
	frame:EnableMouse(true)
	frame:SetBackdrop({
		bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
		edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.85)
	frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

	-- Dragging
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', frame.StartMoving)
	frame:SetScript('OnDragStop', function(f)
		f:StopMovingOrSizing()
		local point, _, _, x, y = f:GetPoint()
		self.db.popup.point = point
		self.db.popup.x = x
		self.db.popup.y = y
	end)

	-- Resize grip
	local resizer = CreateFrame('Button', nil, frame)
	resizer:SetSize(16, 16)
	resizer:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -4, 4)
	resizer:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
	resizer:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
	resizer:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')
	resizer:SetScript('OnMouseDown', function()
		frame:StartSizing('BOTTOMRIGHT')
	end)
	resizer:SetScript('OnMouseUp', function()
		frame:StopMovingOrSizing()
		self.db.popup.width = frame:GetWidth()
		self.db.popup.height = frame:GetHeight()
		self:UpdatePopupLayout()
	end)

	-- Title
	local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightLarge')
	title:SetPoint('TOP', frame, 'TOP', 0, -12)
	frame.title = title

	-- Close button
	local closeBtn = CreateFrame('Button', nil, frame, 'UIPanelCloseButton')
	closeBtn:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -2, -2)

	-- Settings button (gear icon, same atlas as LibAT logger)
	local settingsBtn = CreateFrame('Button', nil, frame)
	settingsBtn:SetSize(24, 24)
	settingsBtn:SetPoint('RIGHT', closeBtn, 'LEFT', -2, 0)

	local settingsIcon = settingsBtn:CreateTexture(nil, 'ARTWORK')
	settingsIcon:SetAtlas('Warfronts-BaseMapIcons-Empty-Workshop')
	settingsIcon:SetAllPoints()

	local settingsHighlight = settingsBtn:CreateTexture(nil, 'HIGHLIGHT')
	settingsHighlight:SetAtlas('Warfronts-BaseMapIcons-Alliance-Workshop')
	settingsHighlight:SetAllPoints()

	settingsBtn:SetScript('OnClick', function()
		self:OpenOptions()
	end)
	settingsBtn:SetScript('OnEnter', function(btn)
		GameTooltip:SetOwner(btn, 'ANCHOR_BOTTOM')
		GameTooltip:AddLine('Options')
		GameTooltip:Show()
	end)
	settingsBtn:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)

	-- Grouping dropdown (LibAT or fallback)
	if LibAT and LibAT.UI and LibAT.UI.CreateDropdown then
		local groupDropdown = LibAT.UI.CreateDropdown(frame, 'Group: Class', 140, 22)
		groupDropdown:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -10)
		groupDropdown:SetupMenu(function(_, rootDescription)
			for _, item in ipairs(GROUPBY_ITEMS) do
				local button = rootDescription:CreateButton(item.label, function()
					self.db.display.groupBy = item.key
					groupDropdown:SetText('Group: ' .. item.label)
					self:UpdatePopup()
				end)
				if self.db.display.groupBy == item.key then
					button:SetRadio(true)
				end
			end
		end)
		frame.groupDropdown = groupDropdown
	else
		-- Fallback: simple cycle button if LibAT not available
		local groupBtn = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
		groupBtn:SetSize(140, 22)
		groupBtn:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -10)
		groupBtn:SetText('Group: Class')
		groupBtn:SetScript('OnClick', function()
			local current = self.db.display.groupBy or 'class'
			for i, item in ipairs(GROUPBY_ITEMS) do
				if item.key == current then
					local nextItem = GROUPBY_ITEMS[i < #GROUPBY_ITEMS and i + 1 or 1]
					self.db.display.groupBy = nextItem.key
					groupBtn:SetText('Group: ' .. nextItem.label)
					self:UpdatePopup()
					return
				end
			end
		end)
		frame.groupDropdown = groupBtn
	end

	-- Scroll frame
	local scrollFrame = CreateFrame('ScrollFrame', 'LibsTimePlayedPopupScroll', frame, 'UIPanelScrollFrameTemplate')
	scrollFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -38)
	scrollFrame:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -28, 52)

	local scrollChild = CreateFrame('Frame', nil, scrollFrame)
	scrollChild:SetWidth(scrollFrame:GetWidth())
	scrollChild:SetHeight(1) -- will be set dynamically
	scrollFrame:SetScrollChild(scrollChild)

	-- Store the scrollbar reference
	scrollFrame.scrollBar = _G['LibsTimePlayedPopupScrollScrollBar']

	-- Mouse wheel scrolling
	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScript('OnMouseWheel', function(sf, delta)
		local current = sf:GetVerticalScroll()
		local maxScroll = sf:GetVerticalScrollRange()
		local newScroll = current - (delta * 20)
		newScroll = math.max(0, math.min(newScroll, maxScroll))
		sf:SetVerticalScroll(newScroll)
	end)

	frame.scrollFrame = scrollFrame
	frame.scrollChild = scrollChild

	-- Pre-allocate rows
	for i = 1, MAX_ROWS do
		local row = CreateRow(scrollChild, scrollChild:GetWidth())
		row:Hide()
		rows[i] = row
	end

	-- Total row at bottom
	local totalText = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	totalText:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 12, 10)
	totalText:SetTextColor(1, 0.82, 0)
	frame.totalText = totalText

	-- Milestone text above total
	local milestoneText = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	milestoneText:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 12, 28)
	milestoneText:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -12, 28)
	milestoneText:SetJustifyH('LEFT')
	milestoneText:SetTextColor(0.7, 0.7, 0.7)
	frame.milestoneText = milestoneText

	-- Handle resize
	frame:SetScript('OnSizeChanged', function()
		self:UpdatePopupLayout()
	end)

	frame:Hide()
	popupFrame = frame
	return frame
end

---Update layout after resize
function LibsTimePlayed:UpdatePopupLayout()
	if not popupFrame then
		return
	end

	local contentWidth = popupFrame.scrollFrame:GetWidth()
	popupFrame.scrollChild:SetWidth(contentWidth)

	for i = 1, MAX_ROWS do
		if rows[i] then
			rows[i]:SetWidth(contentWidth)
		end
	end

	UpdateScrollBarVisibility(popupFrame.scrollFrame)
end

---Configure a row as a group row
---@param row Frame
---@param group table
---@param barPercent number
---@param percent number
---@param isExpanded boolean
---@param hasChars boolean Whether the group has multiple characters
local function SetupGroupRow(row, group, barPercent, percent, isExpanded, hasChars)
	local color = group.color
	row:SetHeight(ROW_HEIGHT)

	-- Expand indicator
	if hasChars then
		row.expandIcon:SetText(isExpanded and '-' or '+')
		row.expandIcon:SetTextColor(0.8, 0.8, 0.8)
	else
		row.expandIcon:SetText('')
	end

	-- Label
	row.label:SetText(group.label)
	row.label:SetTextColor(color.r, color.g, color.b)
	row.label:SetWidth(90)

	-- Bar
	row.bar:SetValue(barPercent)
	row.bar:SetStatusBarColor(color.r, color.g, color.b, 0.8)
	row.bar:Show()

	-- Percent
	row.percentText:SetText(string.format('%.1f%%', percent))
	row.percentText:SetTextColor(0.8, 0.8, 0.8)

	-- Value
	row.valueText:SetText(LibsTimePlayed.FormatTime(group.total, 'smart'))
	row.valueText:SetTextColor(1, 1, 1)

	-- Store group data for click/hover
	row.groupData = group
	row.isGroupRow = true
	row.isCharRow = false

	row:Show()
end

---Configure a row as a character detail row (indented under group)
---@param row Frame
---@param char table
---@param groupBy string
---@param groupTotal number Total played time for the parent group
---@param groupColor table Color of the parent group {r, g, b}
local function SetupCharRow(row, char, groupBy, groupTotal, groupColor)
	row:SetHeight(CHAR_ROW_HEIGHT)

	-- No expand indicator for char rows
	row.expandIcon:SetText('')

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
	row.label:SetWidth(200)

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

---Populate the popup with current data
function LibsTimePlayed:UpdatePopup()
	if not popupFrame then
		return
	end

	local sortedGroups, accountTotal = self:GetGroupedData()
	local groupBy = self.db.display.groupBy or 'class'

	-- Update title and dropdown text
	popupFrame.title:SetText("Lib's TimePlayed - By " .. GROUPBY_LABELS[groupBy])
	if popupFrame.groupDropdown then
		popupFrame.groupDropdown:SetText('Group: ' .. GROUPBY_LABELS[groupBy])
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

	UpdateScrollBarVisibility(popupFrame.scrollFrame)
end

---Toggle popup visibility
function LibsTimePlayed:TogglePopup()
	local frame = self:CreatePopup()
	if frame:IsShown() then
		frame:Hide()
	else
		self:UpdatePopup()
		frame:Show()
	end
end
