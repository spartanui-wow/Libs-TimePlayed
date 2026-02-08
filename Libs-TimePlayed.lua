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
	self:InitializeOptions()

	-- Check for first-time import after a short delay (let other addons load)
	self:ScheduleTimer('CheckFirstTimeImport', 3)

	self:Log("Lib's TimePlayed loaded", 'info')
end

function LibsTimePlayed:OnDisable()
	self:UnregisterAllEvents()
	self:CancelAllTimers()
end

function LibsTimePlayed:SlashCommand(input)
	input = input and input:trim():lower() or ''

	if input == '' or input == 'config' or input == 'options' then
		self:OpenOptions()
	elseif input == 'played' then
		RequestTimePlayed()
	elseif input == 'popup' or input == 'window' or input == 'show' then
		self:TogglePopup()
	else
		self:Print('Commands: /libstp [config|played|popup]')
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
		return
	end

	-- Check if this is a first-time user
	if self.Import:IsFirstTimeUser() then
		self:Log('First-time user detected, checking for import sources...', 'debug')
		self.Import:OfferFirstTimeImport()
	end
end
