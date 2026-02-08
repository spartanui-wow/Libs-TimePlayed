---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

---Format seconds into a readable time string
---@param seconds number Time in seconds
---@param format? string Format style: 'smart' (default), 'full', 'hours'
---@return string
function LibsTimePlayed.FormatTime(seconds, format)
	seconds = tonumber(seconds) or 0
	format = format or 'smart'

	if seconds < 60 then
		return '< 1m'
	end

	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)

	if format == 'hours' then
		local totalHours = seconds / 3600
		return string.format('%.1fh', totalHours)
	elseif format == 'full' then
		if days >= 365 then
			local years = math.floor(days / 365)
			local remDays = days % 365
			return string.format('%dy %dd %dh %dm', years, remDays, hours, minutes)
		elseif days > 0 then
			return string.format('%dd %dh %dm', days, hours, minutes)
		elseif hours > 0 then
			return string.format('%dh %dm', hours, minutes)
		else
			return string.format('%dm', minutes)
		end
	else -- 'smart'
		if days >= 365 then
			local years = math.floor(days / 365)
			local remDays = days % 365
			return string.format('%dy %dd %dh', years, remDays, hours)
		elseif days > 0 then
			return string.format('%dd %dh', days, hours)
		elseif hours > 0 then
			return string.format('%dh %dm', hours, minutes)
		else
			return string.format('%dm', minutes)
		end
	end
end
