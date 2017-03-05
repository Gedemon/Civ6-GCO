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
	--print("--------------------------- Saving PlayerData ---------------------------")
	GCO.StartTimer("PlayerData")
	GCO.SaveTableToSlot(ExposedMembers.PlayerData, "PlayerData")
	GCO.ShowTimer("PlayerData")
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
	LuaEvents.DoUnitsTurn( playerID )
	LuaEvents.DoCitiesTurn( playerID )
end

function DoTurnForHuman( playerID, bFirstTime )
	if ( not bFirstTime) then
		return
	end
	local player = Players[playerID]
	if player:IsHuman() then
		DoPlayerTurn(playerID)
		LuaEvents.SaveTables()
	end
end
Events.PlayerTurnActivated.Add( DoTurnForHuman )

function DoTurnForAI( playerID )
	local player = Players[playerID]
	if player:IsHuman() then
		return
	end
	DoPlayerTurn(playerID)
end
Events.RemotePlayerTurnBegin.Add( DoTurnForAI )


-----------------------------------------------------------------------------------------
-- Initialize Player Functions
-----------------------------------------------------------------------------------------

function InitializePlayerFunctions() -- Note that those functions are limited to this file context
	local p = getmetatable(Players[0]).__index
	
	--p.function			= function
	
end