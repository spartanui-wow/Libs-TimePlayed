---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

function LibsTimePlayed:InitializeMinimapButton()
	local LibDBIcon = LibStub('LibDBIcon-1.0', true)
	if not LibDBIcon or not self.dataObject then
		return
	end

	-- Smart default: hide minimap icon when Libs-DataBar is present (it shows LDB data already)
	if not self.db.minimapDefaultApplied then
		self.db.minimapDefaultApplied = true
		if C_AddOns.IsAddOnLoaded('Libs-DataBar') then
			self.db.minimap.hide = true
		end
	end

	LibDBIcon:Register("Lib's TimePlayed", self.dataObject, self.db.minimap)
end
