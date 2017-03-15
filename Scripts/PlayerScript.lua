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

function DoPlayerTurn( playerID )
	if (playerID == -1) then playerID = 0 end -- this is necessary when starting in AutoPlay
	local player = Players[playerID]
	local playerConfig = PlayerConfigurations[playerID]
	print("---============================================================================================================================================================================---")
	print("--- STARTING TURN # ".. tostring(Game.GetCurrentGameTurn()) .." FOR PLAYER # ".. tostring(playerID) .. " ( ".. tostring(Locale.ToUpper(Locale.Lookup(playerConfig:GetCivilizationShortDescription()))) .." )")
	print("---============================================================================================================================================================================---")
	LuaEvents.DoUnitsTurn( playerID )
	LuaEvents.DoCitiesTurn( playerID )
end
--LuaEvents.StartPlayerTurn.Add(DoPlayerTurn)

function DoTurnForLocal()
	local playerID = Game.GetLocalPlayer()
	DoPlayerTurn(playerID)
	LuaEvents.SaveTables()
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
	
	--p.function			= function
	
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