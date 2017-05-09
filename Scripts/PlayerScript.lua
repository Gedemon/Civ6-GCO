--=====================================================================================--
--	FILE:	 PlayerScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading PlayerScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------
-- Initialize
-----------------------------------------------------------------------------------------

local GCO = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO = ExposedMembers.GCO
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function SaveTables()
	print("--------------------------- Saving PlayerData ---------------------------")
	GCO.SaveTableToSlot(ExposedMembers.PlayerData, "PlayerData")
end
LuaEvents.SaveTables.Add(SaveTables)

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.PlayerData = GCO.LoadTableFromSlot("PlayerData") or {}
	InitializePlayerFunctions()
end

-----------------------------------------------------------------------------------------
-- Player functions
-----------------------------------------------------------------------------------------

function IsResourceVisible(self, resourceID)
	return GCO.IsResourceVisibleFor(self, resourceID)
end
	
function SetCurrentTurn(self)
	if not ExposedMembers.PlayerData[self:GetID()] then ExposedMembers.PlayerData[self:GetID()] = {} end
	ExposedMembers.PlayerData[self:GetID()].CurrentTurn = Game.GetCurrentGameTurn()
end

function HasStartedTurn(self)
	if not ExposedMembers.PlayerData[self:GetID()] then return false end
	return (ExposedMembers.PlayerData[self:GetID()].CurrentTurn == Game.GetCurrentGameTurn())
end

function UpdateUnitsFlags(self)
	local playerUnits = self:GetUnits()
	if playerUnits then
		for i, unit in playerUnits:Members() do			
			LuaEvents.UnitsCompositionUpdated(self:GetID(), unit:GetID())
		end
	end
end

function UpdateCitiesBanners(self)
	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do			
			LuaEvents.CityCompositionUpdated(self:GetID(), city:GetID())
		end
	end
end

function DoPlayerTurn( playerID )
	if (playerID == -1) then playerID = 0 end -- this is necessary when starting in AutoPlay
	local player = Players[playerID]
	local playerConfig = PlayerConfigurations[playerID]
	print("---============================================================================================================================================================================---")
	print("--- STARTING TURN # ".. tostring(Game.GetCurrentGameTurn()) .." FOR PLAYER # ".. tostring(playerID) .. " ( ".. tostring(Locale.ToUpper(Locale.Lookup(playerConfig:GetCivilizationShortDescription()))) .." )")
	print("---============================================================================================================================================================================---")
	LuaEvents.DoUnitsTurn( playerID )
	LuaEvents.DoCitiesTurn( playerID )
	-- update flags after resources transfers
	player:UpdateUnitsFlags()
	player:UpdateCitiesBanners()
end
--LuaEvents.StartPlayerTurn.Add(DoPlayerTurn)

-- can't use those, they makes the game crash at self.m_Instance.UnitIcon:SetToolTipString( Locale.Lookup(nameString) ) in UnitFlagManager, and some other unidentified parts of the code...
--GameEvents.PlayerTurnStarted.Add(DoPlayerTurn)
--GameEvents.PlayerTurnStartComplete.Add(DoPlayerTurn)

function DoTurnForLocal()
	local playerID = Game.GetLocalPlayer()
	local player = Players[playerID]
	if player and not player:HasStartedTurn() then
		player:SetCurrentTurn()
		DoPlayerTurn(playerID)
		LuaEvents.SaveTables()
	end
end
Events.LocalPlayerTurnBegin.Add( DoTurnForLocal )

function DoTurnForRemote( playerID )
	DoPlayerTurn(playerID)
end
Events.RemotePlayerTurnBegin.Add( DoTurnForRemote )



-----------------------------------------------------------------------------------------
-- Shared Functions
-----------------------------------------------------------------------------------------
function GetPlayer(playerID)
	local player= Players[playerID]
	if not player then
		print("ERROR : player is nil in GetPlayer for playerID#", playerID)
		return
	end
	InitializePlayerFunctions(player)
	return player
end

-----------------------------------------------------------------------------------------
-- Initialize Player Functions
-----------------------------------------------------------------------------------------
function InitializePlayerFunctions(player) -- Note that those functions are limited to this file context
	if not player then player = Players[0] end
	local p = getmetatable(player).__index
	
	p.IsResourceVisible			= IsResourceVisible
	p.UpdateUnitsFlags			= UpdateUnitsFlags
	p.UpdateCitiesBanners		= UpdateCitiesBanners
	p.SetCurrentTurn			= SetCurrentTurn
	p.HasStartedTurn			= HasStartedTurn
	
end


----------------------------------------------
-- Share functions for other contexts
----------------------------------------------
function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.GetPlayer 					= GetPlayer
	ExposedMembers.GCO.InitializePlayerFunctions 	= InitializePlayerFunctions
	ExposedMembers.PlayerScript_Initialized 		= true
end
Initialize()