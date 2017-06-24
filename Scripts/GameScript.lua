--=====================================================================================--
--	FILE:	 GameScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GameScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local ResClassCount = {
		["RESOURCECLASS_LUXURY"] 	= 2,
		["RESOURCECLASS_STRATEGIC"]	= 10,
		["RESOURCECLASS_BONUS"]		= 5
	}
	
local ResTypeBonus = {
		["RESOURCE_HORSES"] 	= 10,
	}

	
-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

local GCO = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO = ExposedMembers.GCO			-- contains functions from other contexts 
	LuaEvents.InitializeGCO.Remove( InitializeUtilityFunctions )
	print ("Exposed Functions from other contexts initialized...")
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

-----------------------------------------------------------------------------------------
-- Remove CS on game start
-----------------------------------------------------------------------------------------
function KillAllCS()

	if Game.GetCurrentGameTurn() > GameConfiguration.GetStartTurn() then -- only called on first turn
		return
	end
	
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		if not(player:IsMajor()) then
			local playerUnits = player:GetUnits()
			if playerUnits then
				for i, unit in playerUnits:Members() do
					playerUnits:Destroy(unit)
				end
			end
		end
	end
end


-----------------------------------------------------------------------------------------
-- Resources
-----------------------------------------------------------------------------------------
function SetResourcesCount()

	if Game.GetCurrentGameTurn() > GameConfiguration.GetStartTurn() then -- only called on first turn
		return
	end
	
	local iPlotCount = Map.GetPlotCount()
	for i = 0, iPlotCount - 1 do
		local plot = Map.GetPlotByIndex(i)
		local resCount = plot:GetResourceCount() 
		if resCount > 0 then
			local row 		= GameInfo.Resources[plot:GetResourceType()]
			local baseNum 	= ResClassCount[row.ResourceClassType]
			if ResTypeBonus[row.ResourceType] then 
				baseNum = baseNum + ResTypeBonus[row.ResourceType]
			end
			local num		= Game.GetRandNum(baseNum+1)+baseNum
			ResourceBuilder.SetResourceType(plot, row.Index, num)
		end
	end
end


-----------------------------------------------------------------------------------------
-- Initializing new turn
-----------------------------------------------------------------------------------------
function EndingTurn()
	print("---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
	print("---+                                                                     ENDING TURN # ".. tostring(Game.GetCurrentGameTurn()))
	print("---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
end
Events.PreTurnBegin.Add(EndingTurn)

function InitializeNewTurn()
	print("---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
	print("---+                                                                    STARTING TURN # ".. tostring(Game.GetCurrentGameTurn()))
	print("---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		local player = GCO.GetPlayer(playerID)
		if player then
			player:UpdateDataOnNewTurn()
		end
	end
end
GameEvents.OnGameTurnStarted.Add(InitializeNewTurn)


-----------------------------------------------------------------------------------------
-- Initialize script
-----------------------------------------------------------------------------------------
function Initialize()
	KillAllCS()
	SetResourcesCount()
end
Initialize()