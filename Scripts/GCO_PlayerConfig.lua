--=====================================================================================--
--	FILE:	 GCO_PlayerConfig.lua
--  Gedemon (2018)
--
--
--	Override PlayerConfig methods to set/get dynamic naming for Civilizations
--	Use : [ include( "GCO_PlayerConfig" ) ] in the related UI files, this file is not loaded in UI or Script context
--
--=====================================================================================--

print("Loading GCO_PlayerConfig.lua...")

-----------------------------------------------------------------------------------------
-- Debug
-----------------------------------------------------------------------------------------

DEBUG_PLAYER_CONFIG	= "debug"

function ToggleDebug()
	DEBUG_PLAYER_CONFIG = not DEBUG_PLAYER_CONFIG
end


-----------------------------------------------------------------------------------------
-- Initialize
-----------------------------------------------------------------------------------------

GCO 					= {} -- not local to be passed to UI files including this file.
local GameEvents		= ExposedMembers.GameEvents
--local LuaEvents			= ExposedMembers.LuaEvents
local PlayerConfigData	= {}
local pairs 			= pairs
local Dprint, Dline, Dlog
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 		= ExposedMembers.GCO
	Dprint 		= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	pairs 		= GCO.OrderedPairs
	print("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

--[[
-- Loading/saving done in GCO_PlayerScript to prevent multiple call as this file is included in multiple files
function SaveTables()
	Dprint( DEBUG_PLAYER_CONFIG, "--------------------------- Saving PlayerConfigData ---------------------------")
	GCO.SaveTableToSlot(ExposedMembers.GCO.PlayerConfigData, "PlayerConfigData")
end
GameEvents.SaveTables.Add(SaveTables)
--]]

function PostInitialize() -- everything that may require other context to be loaded first
	--ExposedMembers.GCO.PlayerConfigData = GCO.LoadTableFromSlot("PlayerConfigData") or {}
	InitializePlayerConfigFunctions()
end


-----------------------------------------------------------------------------------------
-- New functions
-----------------------------------------------------------------------------------------
function GetPlayerConfig(playerID)
	local playerConfig = PlayerConfigurations[playerID]
	InitializePlayerConfigFunctions(playerConfig)
	return playerConfig
end

function GetData(self)
	return ExposedMembers.GCO.PlayerConfigData[self:OldGetCivilizationTypeName()]
end

function SetKeyValue(self, key, value)
	local configData = self:GetData()
	if not configData then
		ExposedMembers.GCO.PlayerConfigData[self:OldGetCivilizationTypeName()] = {}
		configData = ExposedMembers.GCO.PlayerConfigData[self:OldGetCivilizationTypeName()]
	end	
	configData[key] = value
end
function GetKeyValue(self, key)
	local configData = self:GetData()
	if configData then
		return configData[key]
	end	
end


-----------------------------------------------------------------------------------------
-- Override functions
-----------------------------------------------------------------------------------------
function GetCivilizationTypeName(self)
	local configData = self:GetData()
	if configData then
		return configData.CivilizationTypeName or self:OldGetCivilizationTypeName()
	else
		return self:OldGetCivilizationTypeName()
	end
end
function GetCivilizationShortDescription(self)
	local configData = self:GetData()
	if configData then
		return configData.CivilizationShortDescription or self:OldGetCivilizationShortDescription()
	else
		return self:OldGetCivilizationShortDescription()
	end
end
function GetPlayerName(self)
	local configData = self:GetData()
	if configData then
		return configData.PlayerName or self:OldGetPlayerName()
	else
		return self:OldGetPlayerName()
	end
end
function GetLeaderName(self)
	local configData = self:GetData()
	if configData then
		return configData.LeaderName or self:OldGetLeaderName()
	else
		return self:OldGetLeaderName()
	end
end
function GetCivilizationDescription(self)
	local configData = self:GetData()
	if configData then
		return configData.CivilizationDescription or self:OldGetCivilizationDescription()
	else
		return self:OldGetCivilizationDescription()
	end
end
function GetLeaderTypeName(self)
	local configData = self:GetData()
	if configData then
		return configData.LeaderTypeName or self:OldGetLeaderTypeName()
	else
		return self:OldGetLeaderTypeName()
	end
end

-----------------------------------------------------------------------------------------
-- Initialize PlayerConfig Functions
-----------------------------------------------------------------------------------------
function InitializePlayerConfigFunctions(pPlayerConfig) -- Note that those functions are limited to this file context (and those which include it)

	local pPlayerConfig = pPlayerConfig or PlayerConfigurations[0]
	local p = getmetatable(pPlayerConfig).__index
	
	if not p.GetData then -- initialize only once !
		p.GetData								= GetData
		p.SetKeyValue							= SetKeyValue
		p.GetKeyValue							= GetKeyValue
		-- Old functions
		p.OldGetCivilizationTypeName			= p.GetCivilizationTypeName
		p.OldGetCivilizationShortDescription	= p.GetCivilizationShortDescription
		p.OldGetPlayerName						= p.GetPlayerName
		p.OldGetLeaderName						= p.GetLeaderName
		p.OldGetLeaderTypeName					= p.GetLeaderTypeName
		p.OldGetCivilizationDescription			= p.GetCivilizationDescription
		-- Override functions
		p.GetCivilizationTypeName				= GetCivilizationTypeName
		p.GetCivilizationShortDescription		= GetCivilizationShortDescription
		p.GetPlayerName							= GetPlayerName
		p.GetLeaderName							= GetLeaderName
		p.GetLeaderTypeName						= GetLeaderTypeName
		p.GetCivilizationDescription			= GetCivilizationDescription
	end
end


----------------------------------------------
-- Initialize
----------------------------------------------
function Initialize()
	-- Sharing Functions for other contexts
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end	
	ExposedMembers.GCO.InitializePlayerConfigFunctions 	= InitializePlayerConfigFunctions
	ExposedMembers.GCO.GetPlayerConfig					= GetPlayerConfig
end
Initialize()