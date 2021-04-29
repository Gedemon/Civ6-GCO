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

local forestID		= GameInfo.Features["FEATURE_FOREST"].Index
local denseID		= GameInfo.Features["FEATURE_FOREST_DENSE"].Index
local sparseID		= GameInfo.Features["FEATURE_FOREST_SPARSE"].Index
	
local GameEraByChronologyIndex = {}
for row in GameInfo.Eras() do
	GameEraByChronologyIndex[row.ChronologyIndex] = row.Index
end	

-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

local GCO 	= {}
local pairs = pairs
local Dprint, Dline, Dlog, Div
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 		= ExposedMembers.GCO		-- contains functions from other contexts
	Dprint 		= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	Div			= GCO.Divide
	pairs 		= GCO.OrderedPairs
	GameEvents.InitializeGCO.Remove( InitializeUtilityFunctions )
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

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

function SetExtraFeatures()

	if Game.GetCurrentGameTurn() > GameConfiguration.GetStartTurn() then -- only called on first turn
		return
	end
	local iPlotCount 	= Map.GetPlotCount()
	local numSparse		= 0
	local numDense		= 0
	
	for pass = 0, 2 do
		for i = 0, iPlotCount - 1 do
			local plot	= Map.GetPlotByIndex(i)
			if plot then
				local forestCount = CountAdjacentForest(plot:GetX(), plot:GetY())
				if forestCount > 0 then
					local bIsForest = (plot:GetFeatureType() == forestID)
					--print("Pass #".. pass ..", counted ".. tostring(forestCount) .. " forest plots around pos ", plot:GetX(), plot:GetY(), " bIsForest = ", bIsForest)
					if bIsForest then
						local randomNum = TerrainBuilder.GetRandomNumber( (6-forestCount)*100, "change to dense forest")
						--print("  - RandomNum = ", randomNum, " NumResources = ",  plot:GetResourceCount() )
						if (forestCount >= 2 and randomNum < 100) then
							if plot:GetResourceCount() == 0  then -- and TerrainBuilder.CanHaveFeature(plot, denseID)
								--print("  - Adding dense forest")
								TerrainBuilder.SetFeatureType(plot, denseID)
								numDense = numDense + 1
							end
						end
					else
						local randomNum = TerrainBuilder.GetRandomNumber( (6-forestCount)*100, "add sparse forest")
						--print("  - RandomNum = ", randomNum, " NumResources = ",  plot:GetResourceCount() )
						if randomNum < 100 and plot:GetResourceCount() == 0 and TerrainBuilder.CanHaveFeature(plot, sparseID) then --
							--print("  - Adding sparse forest")
							TerrainBuilder.SetFeatureType(plot, sparseID)
							numSparse = numSparse + 1
						end
					end
				end
			end
		end
	end
	print("Added ".. tostring(numDense)  .." dense forests")
	print("Added ".. tostring(numSparse)  .." sparse forests")
end

function CountAdjacentForest(iX, iY)
	local adjacentPlot;
	local count = 0
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil) then
			if (adjacentPlot:GetFeatureType() == forestID) or (adjacentPlot:GetFeatureType() == denseID)  then
				count = count + 1
			end
		end
	end
	return count
end


-----------------------------------------------------------------------------------------
-- Game Era
-----------------------------------------------------------------------------------------
local gameEra = 0
function UpdateGameEra()
	local DEBUG_GAME_SCRIPT = "debug"
	Dprint( DEBUG_GAME_SCRIPT, GCO.Separator)
	Dprint( DEBUG_GAME_SCRIPT, "Setting Game Era...")
	local averageEra 	= 1 -- ChronologyIndex
	local totalEra		= 0
	local count 		= 0
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		local player = Players[playerID]
		if player and player:IsAlive() and (not player:IsBarbarian()) and player:GetCities():GetCapitalCity() then
		Dprint( DEBUG_GAME_SCRIPT, " - Player#"..tostring(playerID).." Adding = ", GameInfo.Eras[player:GetEra()].ChronologyIndex)
			totalEra 	= totalEra + GameInfo.Eras[player:GetEra()].ChronologyIndex
			count		= count + 1
		end	
	end
	if count > 0 then 
		averageEra = math.max(1,math.floor(totalEra / count))
	else 
		averageEra = 1
	end
	Dprint( DEBUG_GAME_SCRIPT, "- averageEra = ", averageEra)
	
	local currentEra = GameEraByChronologyIndex[averageEra]
	if currentEra ~= gameEra then
		gameEra = currentEra
		GCO.StatusMessage("[COLOR:Blue]Global Era is [ENDCOLOR] ".. Locale.Lookup(GameInfo.Eras[gameEra].Name), 6, ReportingStatusTypes.GOSSIP)
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
	--local DEBUG_GAME_SCRIPT = "debug"
	Dprint( DEBUG_GAME_SCRIPT, "---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
	Dprint( DEBUG_GAME_SCRIPT, "---+                                                                     ENDING TURN # ".. Indentation(Game.GetCurrentGameTurn(),3,true) .. "                                                                                    +---")
	Dprint( DEBUG_GAME_SCRIPT, "---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
end
--Events.PreTurnBegin.Add(EndingTurn)

function InitializeNewTurn()
	local DEBUG_GAME_SCRIPT = "debug"
	Dprint( DEBUG_GAME_SCRIPT, "---+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+==+---")
	Dprint( DEBUG_GAME_SCRIPT, "---+                                                                    STARTING TURN # ".. Indentation(Game.GetCurrentGameTurn(),3,true) .. "                                                                                   +---")
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
	
	GCO.StartTimer("UpdateOperations")
	GCO.UpdateOperations()
	GCO.ShowTimer("UpdateOperations")
	
	--LuaEvents.StartPlayerTurn(0) -- calling that here makes the game crash (tested 25-Oct-17)
end
GameEvents.OnGameTurnStarted.Add(InitializeNewTurn)



-----------------------------------------------------------------------------------------
-- Initialize script
-----------------------------------------------------------------------------------------
function Initialize()
	KillAllCS()
	SetResourcesCount()
	SetExtraFeatures()
	
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	-- Era
	ExposedMembers.GCO.GetGameEra 				= GetGameEra
	-- Resources
	ExposedMembers.GCO.GetBaseResourceNumOnMap 	= GetBaseResourceNumOnMap

	-- initialization	
	ExposedMembers.GameScript_Initialized 	= true
	
end
Initialize()