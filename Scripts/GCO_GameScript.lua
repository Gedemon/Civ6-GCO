--=====================================================================================--
--	FILE:	 GameScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GameScript.lua...")

-----------------------------------------------------------------------------------------
-- Includes
-----------------------------------------------------------------------------------------
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )


-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------
DEBUG_GAME_SCRIPT = "GameScript"

-- Helpers to get Resources base number on map (also used to determine employment)
local ResClassCount = {
		["RESOURCECLASS_LUXURY"] 	= 2,
		["RESOURCECLASS_STRATEGIC"]	= 6,
		["RESOURCECLASS_BONUS"]		= 4
	}
	
local ResTypeBonus = {
		["RESOURCE_HORSES"] 	= 8,
	}

local ResBaseNum = {}
for row in GameInfo.Resources() do
	ResBaseNum[row.ResourceType] 	= (ResClassCount[row.ResourceClassType] or 1) + (ResTypeBonus[row.ResourceType] or 0)
	ResBaseNum[row.Index] 			= (ResClassCount[row.ResourceClassType] or 1) + (ResTypeBonus[row.ResourceType] or 0)
end

	
-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

local GCO 	= {}
local pairs = pairs
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 		= ExposedMembers.GCO		-- contains functions from other contexts 
	Dprint 		= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	pairs 		= GCO.OrderedPairs
	LuaEvents.InitializeGCO.Remove( InitializeUtilityFunctions )
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function PostInitialize() -- everything that may require other context to be loaded first	
	UpdateGameEra()
end


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
-- Update Cached Data on Load
-----------------------------------------------------------------------------------------
function UpdateCachedData()
	GCO.StartTimer("UpdateCachedData for All Players")
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		local player = GCO.GetPlayer(playerID)
		if player then
			player:UpdateDataOnLoad()
		end
	end
	GCO.ShowTimer("UpdateCachedData for All Players")
end
Events.LoadGameViewStateDone.Add( UpdateCachedData )

-----------------------------------------------------------------------------------------
-- Resources
-----------------------------------------------------------------------------------------
function GetBaseResourceNumOnMap(resourceID)
	return ResBaseNum[resourceID]
end


function SetResourcesCount()

	if Game.GetCurrentGameTurn() > GameConfiguration.GetStartTurn() then -- only called on first turn
		return
	end
	
	local iPlotCount = Map.GetPlotCount()
	for i = 0, iPlotCount - 1 do
		local plot = Map.GetPlotByIndex(i)
		local resCount = plot:GetResourceCount() 
		if resCount > 0 then
			local resourceID 	= GameInfo.Resources[plot:GetResourceType()].Index
			local baseNum 		= GetBaseResourceNumOnMap(resourceID)
			local num			= math.ceil(Game.GetRandNum(baseNum+1)+(baseNum/2))
			ResourceBuilder.SetResourceType(plot, resourceID, num)
		end
	end
end


-----------------------------------------------------------------------------------------
-- Game Era
-----------------------------------------------------------------------------------------
local gameEra = 0
function UpdateGameEra()
	Dprint( DEBUG_GAME_SCRIPT, GCO.Separator)
	Dprint( DEBUG_GAME_SCRIPT, "Setting Game Era...")
	local averageEra 	= 0
	local totalEra		= 0
	local count 		= 0
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		local player = Players[playerID]
		if player and player:IsAlive() and (not player:IsBarbarian()) and player:GetCities():GetCapitalCity() then
			totalEra 	= totalEra + player:GetEra()
			count		= count + 1
		end	
	end
	if count > 0 then 
		averageEra = math.floor(totalEra / count)
	else 
		averageEra = 0
	end
	Dprint( DEBUG_GAME_SCRIPT, "- averageEra = ", averageEra)
	if averageEra ~= gameEra then
		gameEra = averageEra
		LuaEvents.GCO_Message("[COLOR:Blue]Global Era is [ENDCOLOR] ".. Locale.Lookup(GameInfo.Eras[gameEra].Name), 6)
	end
end
GameEvents.OnGameTurnStarted.Add(UpdateGameEra)

function GetGameEra()
	return gameEra
end

-----------------------------------------------------------------------------------------
-- Initializing new turn
-----------------------------------------------------------------------------------------
function EndingTurn()
	Dprint( DEBUG_GAME_SCRIPT, "---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
	Dprint( DEBUG_GAME_SCRIPT, "---+                                                                     ENDING TURN # ".. tostring(Game.GetCurrentGameTurn()))
	Dprint( DEBUG_GAME_SCRIPT, "---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
end
Events.PreTurnBegin.Add(EndingTurn)

function InitializeNewTurn()
	Dprint( DEBUG_GAME_SCRIPT, "---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
	Dprint( DEBUG_GAME_SCRIPT, "---+                                                                    STARTING TURN # ".. tostring(Game.GetCurrentGameTurn()))
	Dprint( DEBUG_GAME_SCRIPT, "---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
	
	GCO.StartTimer("UpdateDataOnNewTurn")
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		local player = GCO.GetPlayer(playerID)
		if player then
			player:UpdateDataOnNewTurn()
		end
	end
	GCO.ShowTimer("UpdateDataOnNewTurn")
	
	GCO.StartTimer("UpdateUnitsData")
	GCO.UpdateUnitsData()
	GCO.ShowTimer("UpdateUnitsData")	
	
	GCO.StartTimer("CleanCitiesData")
	GCO.CleanCitiesData()
	GCO.ShowTimer("CleanCitiesData")
	
	GCO.StartTimer("CleanPlotsData")
	GCO.CleanPlotsData()
	GCO.ShowTimer("CleanPlotsData")
	
	--LuaEvents.StartPlayerTurn(0) -- calling that here makes the game crash (tested 25-Oct-17)
end
GameEvents.OnGameTurnStarted.Add(InitializeNewTurn)



-----------------------------------------------------------------------------------------
-- Initialize script
-----------------------------------------------------------------------------------------
function Initialize()
	KillAllCS()
	SetResourcesCount()
	
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	-- Era
	ExposedMembers.GCO.GetGameEra 				= GetGameEra
	-- Resources
	ExposedMembers.GCO.GetBaseResourceNumOnMap 	= GetBaseResourceNumOnMap

	-- initialization	
	ExposedMembers.GameScript_Initialized 	= true
	
end
Initialize()