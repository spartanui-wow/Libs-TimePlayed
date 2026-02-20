---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

---@class LibsTimePlayed.MinimapButton : AceModule, AceEvent-3.0, AceTimer-3.0
local MinimapButton = LibsTimePlayed:NewModule('MinimapButton')
LibsTimePlayed.MinimapButton = MinimapButton

function MinimapButton:OnEnable()
	local LibDBIcon = LibStub('LibDBIcon-1.0', true)
	if not LibDBIcon or not LibsTimePlayed.dataObject then
		return
	end

	-- Smart default: hide minimap icon when Libs-DataBar is present (it shows LDB data already)
	if not LibsTimePlayed.db.minimapDefaultApplied then
		LibsTimePlayed.db.minimapDefaultApplied = true
		if C_AddOns.IsAddOnLoaded('Libs-DataBar') then
			LibsTimePlayed.db.minimap.hide = true
		end
	end

	LibDBIcon:Register("Lib's TimePlayed", LibsTimePlayed.dataObject, LibsTimePlayed.db.minimap)
end
