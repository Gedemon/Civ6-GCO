--=====================================================================================--
--	FILE:	 GCO_TestAI.lua
--  Gedemon (2021)
--=====================================================================================--

print ("Loading GCO_TestAI.lua...")

--=====================================================================================--
-- Includes
--=====================================================================================--
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )


--=====================================================================================--
-- Defines
--=====================================================================================--
DEBUG_AI_SCRIPT 	= "debug"
local AI_TYPE_NAME	= "TestAI"

--=====================================================================================--
-- Initialize Functions
--=====================================================================================--

local GCO 	= {}
local pairs = pairs
local Dprint, Dline, Dlog, Div, LuaEvents
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 		= ExposedMembers.GCO		-- contains functions from other contexts 
	LuaEvents	= GCO.LuaEvents
	Dprint 		= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	Div			= GCO.Divide
	pairs 		= GCO.OrderedPairs
	GameEvents.InitializeGCO.Remove( InitializeUtilityFunctions )
	print ("Exposed Functions from other contexts initialized...")
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )



--=====================================================================================--
-- AI DoTurn
--=====================================================================================--

function DoTurn(self)
	Dprint( DEBUG_AI_SCRIPT, " - TEST AI: Starting turn for Player # ".. tostring(self.PlayerID))
	
end


function DoDiplomacy()
	Dprint( DEBUG_AI_SCRIPT, "   - TEST AI: Diplomacy...")

end

--=====================================================================================--
-- 
--=====================================================================================--

function InitializeTestAI(playerID, typeAI)
	if typeAI == AI_TYPE_NAME then
		Dprint( DEBUG_AI_SCRIPT, "   - Initialize AI for player#", playerID, typeAI)
		local pPlayer 	= GCO.GetPlayer(playerID)
		local pAI		= GCO.AI:Create(playerID)
		--
		pAI:SetValue("TypeName", AI_TYPE_NAME)
		--
		--pAI.DoTurn		= DoTurn
		pAI.DoDiplomacy	= DoDiplomacy
		--
		pPlayer:SetCached("AI", pAI)
	end
end
GameEvents.InitializePlayerAI.Add(InitializeTestAI)