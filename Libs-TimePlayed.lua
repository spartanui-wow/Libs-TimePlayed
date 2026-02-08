---@class LibsTimePlayed : AceAddon
local ADDON_NAME, LibsTimePlayed = ...

LibsTimePlayed = LibStub('AceAddon-3.0'):NewAddon(ADDON_NAME, 'AceEvent-3.0', 'AceTimer-3.0', 'AceConsole-3.0')
_G.LibsTimePlayed = LibsTimePlayed

LibsTimePlayed.version = '1.0.0'
LibsTimePlayed.addonName = "Lib's TimePlayed"

function LibsTimePlayed:OnInitialize()
	-- Initialize logger
	if LibAT and LibAT.Logger then
		self.logger = LibAT.Logger.RegisterAddon('LibsTimePlayed')
	end

	-- Database is initialized in Core/Database.lua
	self:InitializeDatabase()

	-- Register slash commands
	self:RegisterChatCommand('libstp', 'SlashCommand')
	self:RegisterChatCommand('timeplayed', 'SlashCommand')
end

function LibsTimePlayed:OnEnable()
	-- Initialize subsystems
	self:InitializeTracker()
	self:InitializeDataBroker()
	self:InitializeMinimapButton()
	self:InitializeStreakTracker()
	self:InitializeOptions()

	-- Register with Addon Compartment (10.x+ dropdown)
	if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
		AddonCompartmentFrame:RegisterAddon({
			text = "Lib's TimePlayed",
			icon = 'Interface/Icons/INV_Misc_PocketWatch_01',
			registerForAnyClick = true,
			notCheckable = true,
			func = function(_, _, _, _, mouseButton)
				if mouseButton == 'LeftButton' then
					self:TogglePopup()
				else
					self:OpenOptions()
				end
			end,
			funcOnEnter = function()
				GameTooltip:SetOwner(AddonCompartmentFrame, 'ANCHOR_CURSOR_RIGHT')
				GameTooltip:AddLine("|cffffffffLib's|r |cffe21f1fTimePlayed|r", 1, 1, 1)
				GameTooltip:AddLine(' ')
				GameTooltip:AddLine('|cffeda55fLeft-Click|r to toggle popup window.', 1, 1, 1)
				GameTooltip:AddLine('|cffeda55fRight-Click|r to open options.', 1, 1, 1)
				GameTooltip:Show()
			end,
		})
	end

	-- Check for first-time import BEFORE requesting played time
	-- This prevents the current character from being added to DB before import check
	self:ScheduleTimer('CheckFirstTimeImport', 1)

	self:Log("Lib's TimePlayed loaded", 'info')
end

function LibsTimePlayed:OnDisable()
	self:UnregisterAllEvents()
	self:CancelAllTimers()
end

function LibsTimePlayed:SlashCommand(input)
	input = input and input:trim():lower() or ''

	if input == '' then
		self:TogglePopup()
	elseif input == 'options' or input == 'config' then
		self:OpenOptions()
	elseif input == 'refresh' or input == 'played' then
		RequestTimePlayed()
		self:Print('Refreshing /played data...')
	else
		self:Print('Commands: /libstp [options|refresh]')
	end
end

-- Logging helper
function LibsTimePlayed:Log(message, level)
	level = level or 'info'
	if self.logger and self.logger[level] then
		self.logger[level](message)
	end
end

-- Check for first-time import opportunity
function LibsTimePlayed:CheckFirstTimeImport()
	if not self.Import then
		self:Log('Import module not available', 'warning')
		return
	end

	-- Check if this is a first-time user
	if self.Import:IsFirstTimeUser() then
		self:Log('First-time user detected, checking for import sources...', 'info')
		self.Import:OfferFirstTimeImport()
	else
		self:Log('Not a first-time user - skipping import check', 'debug')
	end
end
