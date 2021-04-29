--=====================================================================================--
--	FILE:	 GCO_PlotScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GCO_PlotScript.lua...")

-----------------------------------------------------------------------------------------
-- Includes
-----------------------------------------------------------------------------------------
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )
include( "YnAMP_Common" )


-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------
local _cached			= {}	-- cached table to reduce calculations

local mapName			= MapConfiguration.GetValue("MapName")

local RiverMap 			= {}	-- we could save and reference YnAMP.RiverMap, but it doesn't exist for non-TSL maps, and we want to keep saved data as low as possible, so we're caching the River Map on load instead
local PlotRivers		= {}	-- list of RiverIDs for each plot PlotRivers = { (plotID] = { [riverID] = true, ...}, ...}

local DirectionString 	= {
	[DirectionTypes.DIRECTION_NORTHEAST] 	= "NORTHEAST",
	[DirectionTypes.DIRECTION_EAST] 		= "EAST",
	[DirectionTypes.DIRECTION_SOUTHEAST] 	= "SOUTHEAST",
    [DirectionTypes.DIRECTION_SOUTHWEST] 	= "SOUTHWEST",
	[DirectionTypes.DIRECTION_WEST] 		= "WEST",
	[DirectionTypes.DIRECTION_NORTHWEST] 	= "NORTHWEST"
	}
	
local iDiffusionRatePer1000 		= 1

local iRoadMax		 				= tonumber(GameInfo.GlobalParameters["CULTURE_FOLLOW_ROAD_MAX"].Value)
local iRoadBonus	 				= tonumber(GameInfo.GlobalParameters["CULTURE_FOLLOW_ROAD_BONUS"].Value)
local iFollowingRiverMax 			= tonumber(GameInfo.GlobalParameters["CULTURE_FOLLOW_RIVER_MAX"].Value)
local iFollowingRiverBonus			= tonumber(GameInfo.GlobalParameters["CULTURE_FOLLOW_RIVER_BONUS"].Value)
local iCrossingRiverMax 			= tonumber(GameInfo.GlobalParameters["CULTURE_CROSS_RIVER_MAX"].Value)
local iCrossingRiverPenalty			= tonumber(GameInfo.GlobalParameters["CULTURE_CROSS_RIVER_PENALTY"].Value)
local iCrossingRiverThreshold		= tonumber(GameInfo.GlobalParameters["CULTURE_CROSS_RIVER_THRESHOLD"].Value)
local iBaseThreshold 				= tonumber(GameInfo.GlobalParameters["CULTURE_DIFFUSION_THRESHOLD"].Value)

local cultureDecayRate				= tonumber(GameInfo.GlobalParameters["CULTURE_DECAY_RATE"].Value)
local minValueOwner 				= tonumber(GameInfo.GlobalParameters["CULTURE_MINIMAL_ON_OWNED_PLOT"].Value)
local bOnlyAdjacentCultureFlipping	= tonumber(GameInfo.GlobalParameters["CULTURE_FLIPPING_ONLY_ADJACENT"].Value) == 1
local bAllowCultureAcquisition		= tonumber(GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_ACQUISITION"].Value) == 1
local bAllowCultureFlipping			= tonumber(GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_FLIPPING"].Value) == 1

local FEATURE_ICE 					= GameInfo.Features["FEATURE_ICE"].Index
local TERRAIN_COAST 				= GameInfo.Terrains["TERRAIN_COAST"].Index

local GoodyHutID 					= GameInfo.Improvements["IMPROVEMENT_GOODY_HUT"].Index

local foodResourceID 			= GameInfo.Resources["RESOURCE_FOOD"].Index
local materielResourceID		= GameInfo.Resources["RESOURCE_MATERIEL"].Index
local steelResourceID 			= GameInfo.Resources["RESOURCE_STEEL"].Index
local horsesResourceID 			= GameInfo.Resources["RESOURCE_HORSES"].Index
local personnelResourceID		= GameInfo.Resources["RESOURCE_PERSONNEL"].Index
local woodResourceID			= GameInfo.Resources["RESOURCE_WOOD"].Index
local medicineResourceID		= GameInfo.Resources["RESOURCE_MEDICINE"].Index
local leatherResourceID			= GameInfo.Resources["RESOURCE_LEATHER"].Index
local plantResourceID			= GameInfo.Resources["RESOURCE_PLANTS"].Index

local foodResourceKey			= tostring(foodResourceID)
local personnelResourceKey		= tostring(personnelResourceID)
local materielResourceKey		= tostring(materielResourceID)

local baseFoodStock 			= tonumber(GameInfo.GlobalParameters["CITY_BASE_FOOD_STOCK"].Value)
local ResourceStockPerSize 		= tonumber(GameInfo.GlobalParameters["CITY_STOCK_PER_SIZE"].Value)
local FoodStockPerSize 			= tonumber(GameInfo.GlobalParameters["CITY_FOOD_STOCK_PER_SIZE"].Value)
local LuxuryStockRatio 			= tonumber(GameInfo.GlobalParameters["CITY_LUXURY_STOCK_RATIO"].Value)
local PersonnelPerSize	 		= tonumber(GameInfo.GlobalParameters["CITY_PERSONNEL_PER_SIZE"].Value)
local EquipmentBaseStock 		= tonumber(GameInfo.GlobalParameters["PLOT_MAX_STOCK_EQUIPMENT"].Value)

local MaxBaseEmployement 		= tonumber(GameInfo.GlobalParameters["PLOT_MAX_BASE_EMPLOYMENT"].Value)
local MaxImprovedEmployement	= tonumber(GameInfo.GlobalParameters["PLOT_MAX_IMPROVED_EMPLOYMENT"].Value)

-- Population
local populationPerSizepower 	= tonumber(GameInfo.GlobalParameters["CITY_POPULATION_PER_SIZE_POWER"].Value)
local maxMigrantPercent			= tonumber(GameInfo.GlobalParameters["PLOT_POPULATION_MAX_MIGRANT_PERCENT"].Value)
local minMigrantPercent			= tonumber(GameInfo.GlobalParameters["PLOT_POPULATION_MIN_MIGRANT_PERCENT"].Value)

local UpperClassID 				= GameInfo.Resources["POPULATION_UPPER"].Index
local MiddleClassID 			= GameInfo.Resources["POPULATION_MIDDLE"].Index
local LowerClassID 				= GameInfo.Resources["POPULATION_LOWER"].Index
local SlaveClassID 				= GameInfo.Resources["POPULATION_SLAVE"].Index
local PersonnelClassID			= GameInfo.Resources["RESOURCE_PERSONNEL"].Index
local PrisonersClassID			= GameInfo.Resources["POPULATION_PRISONERS"].Index

local BaseBirthRate 				= tonumber(GameInfo.GlobalParameters["CITY_BASE_BIRTH_RATE"].Value)
local UpperClassBirthRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_UPPER_CLASS_BIRTH_RATE_FACTOR"].Value)
local MiddleClassBirthRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_MIDDLE_CLASS_BIRTH_RATE_FACTOR"].Value)
local LowerClassBirthRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_LOWER_CLASS_BIRTH_RATE_FACTOR"].Value)
local SlaveClassBirthRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_SLAVE_CLASS_BIRTH_RATE_FACTOR"].Value)

local BirthRateFactor = {
	[UpperClassID] 	= UpperClassBirthRateFactor,
    [MiddleClassID] = MiddleClassBirthRateFactor,
    [LowerClassID] 	= LowerClassBirthRateFactor,
    [SlaveClassID] 	= SlaveClassBirthRateFactor,
	}

local BaseDeathRate 				= tonumber(GameInfo.GlobalParameters["CITY_BASE_DEATH_RATE"].Value)
local UpperClassDeathRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_UPPER_CLASS_DEATH_RATE_FACTOR"].Value)
local MiddleClassDeathRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_MIDDLE_CLASS_DEATH_RATE_FACTOR"].Value)
local LowerClassDeathRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_LOWER_CLASS_DEATH_RATE_FACTOR"].Value)
local SlaveClassDeathRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_SLAVE_CLASS_DEATH_RATE_FACTOR"].Value)

local DeathRateFactor = {
	[UpperClassID] 	= UpperClassDeathRateFactor,
    [MiddleClassID] = MiddleClassDeathRateFactor,
    [LowerClassID] 	= LowerClassDeathRateFactor,
    [SlaveClassID] 	= SlaveClassDeathRateFactor,
	}

	
local Regions	= {}
for RegionRow in GameInfo.RegionPosition() do
	if RegionRow.MapName == mapName  then
		table.insert(Regions, {Region = RegionRow.Region, X = RegionRow.X, Y = RegionRow.Y, Width = RegionRow.Width, Height = RegionRow.Height})
	end
end

local CultureRegions	= {}
local RegionCultures	= {}
--[[
for row in GameInfo.CultureGroupsStartingRegions() do
	CultureRegions[row.CultureType]		= CultureRegions[row.CultureType] or {}
	RegionCultures[row.StartingRegion]	= RegionCultures[row.StartingRegion] or {}
	
	CultureRegions[row.CultureType][row.StartingRegion] = true
	RegionCultures[row.StartingRegion][row.CultureType]	= true
end
--]]
	
	
-----------------------------------------------------------------------------------------
-- Debug
-----------------------------------------------------------------------------------------

DEBUG_PLOT_SCRIPT			= "PlotScript"
DEBUG_PLOT_TURN				= true			-- when true use pcall for plots turn
local debugTable 			= {}			-- table used to output debug data from some functions


-----------------------------------------------------------------------------------------
-- Initialize
-----------------------------------------------------------------------------------------
local GCO 	= {}
local YnAMP = {}
local pairs = pairs
local Dprint, Dline, Dlog, Div

function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 		= ExposedMembers.GCO
	YnAMP		= ExposedMembers.YnAMP
	LuaEvents	= ExposedMembers.GCO.LuaEvents
	Dprint 		= GCO.Dprint
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	Div			= GCO.Divide
	pairs 		= GCO.OrderedPairs
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function SaveTables()
	Dprint( DEBUG_PLOT_SCRIPT, "--------------------------- Saving Map ---------------------------")	
	GCO.StartTimer("Saving And Checking Map")
	GCO.SaveTableToSlot(ExposedMembers.CultureMap, "CultureMap")
	GCO.SaveTableToSlot(ExposedMembers.PreviousCultureMap, "PreviousCultureMap")
	GCO.SaveTableToSlot(ExposedMembers.MigrationMap, "MigrationMap")
	GCO.SaveTableToSlot(ExposedMembers.PlotData, "PlotData")
	
	-- debug
	--for plotKey, values in pairs(ExposedMembers.MigrationMap) do
	--	GCO.SaveTableToSlot(values, "debug_"..plotKey) -- if the MigrationMap fail to save, this will also return an error, but for specific plots
	--end
end
GameEvents.SaveTables.Add(SaveTables)

function CheckSave()
	Dprint( DEBUG_PLOT_SCRIPT, "Checking Saved Table...")
	if GCO.AreSameTables(ExposedMembers.CultureMap, GCO.LoadTableFromSlot("CultureMap")) then
		Dprint( DEBUG_PLOT_SCRIPT, "- Tables are identical")
	else
		GCO.Error("reloading saved CultureMap table show differences with actual table !")
		CompareData(ExposedMembers.CultureMap, GCO.LoadTableFromSlot("CultureMap"))
	end
	
	if GCO.AreSameTables(ExposedMembers.PreviousCultureMap, GCO.LoadTableFromSlot("PreviousCultureMap")) then
		Dprint( DEBUG_PLOT_SCRIPT, "- Tables are identical")
	else
		GCO.Error("reloading saved PreviousCultureMap table show differences with actual table !")
		LuaEvents.StopAuToPlay()
		CompareData(ExposedMembers.PreviousCultureMap, GCO.LoadTableFromSlot("PreviousCultureMap"))
	end
	
	if GCO.AreSameTables(ExposedMembers.PlotData, GCO.LoadTableFromSlot("PlotData")) then
		Dprint( DEBUG_PLOT_SCRIPT, "- Tables are identical")
	else
		GCO.Error("reloading saved PlotData table show differences with actual table !")
		CompareData(ExposedMembers.PlotData, GCO.LoadTableFromSlot("PlotData"))
	end
	GCO.ShowTimer("Saving And Checking Map")
end
GameEvents.SaveTables.Add(CheckSave)

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.CultureMap 			= GCO.LoadTableFromSlot("CultureMap") 			or {}	-- CultureMap[plotKey] = { [CultureID1] = value1,  [CultureID2] = value2, ...} 
	ExposedMembers.PreviousCultureMap 	= GCO.LoadTableFromSlot("PreviousCultureMap") 	or {}
	ExposedMembers.MigrationMap 		= GCO.LoadTableFromSlot("MigrationMap") 		or {}	-- MigrationMap[plotKey] = { [turnKey] = {[otherPlotKey] = { Migrants = value, }, ...} }
	ExposedMembers.PlotData 			= GCO.LoadTableFromSlot("PlotData") 			or CreatePlotData()
	
	SetGlobals() -- initialize YnAMP Common
	SetRiverIDs()
	InitializePlotFunctions()
	SetCultureDiffusionRatePer1000()
	SetInitialMapPopulation()
	CacheMapFeatures()
	
	GameEvents.CapturedCityInitialized.Add( UpdateCultureOnCityCapture )
end

function CacheMapFeatures()
	local iPlotCount 	= Map.GetPlotCount()
	for i = 0, iPlotCount - 1 do
		local plot 		= GetPlotByIndex(i)
		plot:SetCached("FeatureType", plot:GetFeatureType())
	end
end

function CreatePlotData()
	local plotData		= {}
	local iPlotCount 	= Map.GetPlotCount()
	for i = 0, iPlotCount - 1 do
		local plot 		= GetPlotByIndex(i)
		local plotKey 	= plot:GetKey()
		local turnKey 	= GCO.GetTurnKey()
		
		plotData[plotKey] = {
			Stock	= { [turnKey] = {} },
		}
	end
	return plotData
end

-- for debugging
function ShowPlotData()
	for key, data in pairs(ExposedMembers.CultureMap) do
		print(key, data)
		for k, v in pairs (data) do
			print("-", k, v)
		end
	end
end

function CompareData(data1, data2)
	for key, data in pairs(data1) do
		--print(key, data)
		for k, v in pairs (data) do
			if not data2[key] then
				print("- reloaded table is nil for key = ", key)
			elseif not data2[key][k] then			
				print("- no value for key = ", key, " CivID =", k)
			elseif v ~= data2[key][k] then
				print("- different value for key = ", key, " CivID =", k, " Data1 value = ", v, type(v), " Data2 value = ", data2[key][k], type(data2[key][k]), v - data2[key][k] )
			end
		end
	end
end

function ShowDebug()
	for key, textTable in pairs(debugTable) do
		print(GCO.Separator)
		print(key)
		for _, text in ipairs(textTable) do
			print(text)
		end
	end
end

-----------------------------------------------------------------------------------------
-- Plots Functions
-----------------------------------------------------------------------------------------
function GetKey ( self )
	return tostring(self:GetIndex())
end

function GetData(self)
	local plotKey 	= self:GetKey()
	local plotData 	= ExposedMembers.PlotData[plotKey]
	if not plotData then GCO.Warning("plotData is nil for ".. Locale.Lookup(self:GetName())); GCO.DlineFull(); end
	return plotData
end

function GetMigrationMap(self)
	local plotKey	 	= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	local MigrationMap 	= ExposedMembers.MigrationMap[plotKey]
	if not MigrationMap then
		ExposedMembers.MigrationMap[plotKey] 	= {}
		MigrationMap 							= ExposedMembers.MigrationMap[plotKey]
	end
	if not MigrationMap[turnKey] then MigrationMap[turnKey] = {} end
	return MigrationMap[turnKey]
end

function GetMigrationMapAtTurn(self, turn)
	local plotKey	 	= self:GetKey()
	local turnKey 		= tostring(turn)
	local MigrationMap 	= ExposedMembers.MigrationMap[plotKey]
	if not MigrationMap then
		ExposedMembers.MigrationMap[plotKey] 	= {}
		MigrationMap 							= ExposedMembers.MigrationMap[plotKey]
	end
	return MigrationMap[turnKey]
end

function GetMigrationDataWith(self, plot)
	local MigrationMap	= self:GetMigrationMap()
	local otherPlotKey	= plot:GetKey()
	if not MigrationMap[otherPlotKey] then
		local prevTurnData = self:GetMigrationDataAtTurn(plot, GCO.GetPreviousTurnKey())
		if prevTurnData then
			MigrationMap[otherPlotKey] = { Migrants = 0, Total = prevTurnData.Total or 0 } -- to do: check why prevTurnData.Total can be nil ?
		else
			MigrationMap[otherPlotKey] = { Migrants = 0, Total = 0 }
		end
	end
	return MigrationMap[otherPlotKey]
end

function GetMigrationDataAtTurn(self, plot, turn)
	local MigrationMap	= self:GetMigrationMapAtTurn(turn)
	if MigrationMap then
		local otherPlotKey	= plot:GetKey()
		if MigrationMap[otherPlotKey] then
			return MigrationMap[otherPlotKey]
		end	
	end
end

function GetCache(self)
	local selfKey 	= self:GetKey()
	if not _cached[selfKey] then _cached[selfKey] = {} end
	return _cached[selfKey]
end

function GetCached(self, key)
	local selfKey 	= self:GetKey()
	if not _cached[selfKey] then _cached[selfKey] = {} end
	return _cached[selfKey][key]
end

function SetCached(self, key, value)
	local selfKey 	= self:GetKey()
	if not _cached[selfKey] then _cached[selfKey] = {} end
	_cached[selfKey][key] = value
end

function GetValue(self, key)
	local Data = self:GetData()
	if not Data then
		GCO.Warning("plotData is nil for " .. tostring(self:GetX())..",".. tostring(self:GetY()).." #".. tostring(self:GetKey()))
		return 0
	end
	return Data[key]
end

function SetValue(self, key, value)
	local Data = self:GetData()
	if not Data then
		GCO.Error("plotData is nil for " .. tostring(self:GetX())..",".. tostring(self:GetY()).." #".. tostring(self:GetKey()) .. "[NEWLINE]Trying to set ".. tostring(key) .." value to " ..tostring(value))
	end
	Data[key] = value
end

function GetPlotFromKey( key )
	return Map.GetPlotByIndex(tonumber(key))
end

function GetCity(self)
	local city = Cities.GetPlotPurchaseCity(self)
	if city then
		GCO.AttachCityFunctions(city)
		return city
	end
end

function GetEraType(self)
	local player 	= Players[self:GetOwner()]
	if player then
		return GameInfo.Eras[player:GetEra()].EraType
	else
		return GameInfo.Eras[GCO.GetGameEra()].EraType
	end
end

function SetOwner(self, ownerID, cityID)
	local ownerID		= ownerID or -1
	local iX, iY		= self:GetX(), self:GetY()
	local CityManager	= WorldBuilder.CityManager or ExposedMembers.CityManager
	
	if not cityID and ownerID ~= -1 then
		local city	= GCO.FindNearestPlayerCity( ownerID, iX, iY )
		cityID		= city and city:GetID()
	end
	
	if CityManager then
		if ownerID ~= -1 then
			if cityID then
				CityManager():SetPlotOwner( iX, iY, false )
				CityManager():SetPlotOwner( iX, iY, ownerID, cityID)
			end
		else
			CityManager():SetPlotOwner( iX, iY, false )
		end
	else
		if ownerID ~= -1 then
			if cityID then
				self:OldSetOwner(-1)
				self:OldSetOwner(ownerID, cityID, true)
			end
		else
			self:OldSetOwner(-1)
		end
	end
end

function GetDirectionStringTo(self, otherPlot, iDistance)

	local gridWidth, gridHeight = Map.GetGridSize()
	
	local iX, iY	= self:GetX(), self:GetY()
	local oX, oY	= otherPlot:GetX(), otherPlot:GetY()
	
	local iDistance = iDistance or 5 -- when this value is higher, you'll need a biger difference between xDiff and yDiff to return a one-axis direction
	
	local yDiff = self:GetY() - otherPlot:GetY()
	local xDiff = self:GetX() - otherPlot:GetX()
	
	if Map:IsWrapX() and math.abs(xDiff) > Map.GetPlotDistance(iX, iY, oX, oY) then
		xDiff = xDiff > 0 and xDiff - gridWidth or xDiff + gridWidth
	end
	
	local ratioXY = yDiff ~= 0 and math.abs(xDiff) / math.abs(yDiff) or gridWidth
	
	if ratioXY > iDistance then -- East/West axis only
	
		return xDiff > 0 and "LOC_DIRECTION_WEST" or "LOC_DIRECTION_EAST"

	elseif ratioXY > 1/iDistance then

		if xDiff > 0 then 		-- West and...
		
			return yDiff > 0 and "LOC_DIRECTION_SOUTH_WEST" or "LOC_DIRECTION_NORTH_WEST"
		
		else					-- East and...
		
			return yDiff > 0 and "LOC_DIRECTION_SOUTH_EAST" or "LOC_DIRECTION_NORTH_EAST"
			
		end
	
	else 						-- North/South axis only
	
		return yDiff > 0 and "LOC_DIRECTION_SOUTH" or "LOC_DIRECTION_NORTH"

	end

end

function GetPlotDiffusionValuesTo(self, iDirection)
	local plotKey = self:GetKey()
	if not _cached[plotKey] then
		self:SetPlotDiffusionValuesTo(iDirection)
	elseif not _cached[plotKey].PlotDiffusionValues then
		self:SetPlotDiffusionValuesTo(iDirection)
	elseif not _cached[plotKey].PlotDiffusionValues[iDirection] then
		self:SetPlotDiffusionValuesTo(iDirection)
	end
	return _cached[plotKey].PlotDiffusionValues[iDirection]
end

function UpdatePlotDiffusionValues(self)
	local iX = self:GetX()
	local iY = self:GetY()
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot 	= Map.GetAdjacentPlot(iX, iY, direction)
		if adjacentPlot then
			local back	= GetOppositeDirection(direction)
			self:SetPlotDiffusionValuesTo(direction)
			adjacentPlot:SetPlotDiffusionValuesTo(back)
		end		
	end
end

function SetPlotDiffusionValuesTo(self, iDirection)

	if debugTable["SetPlotDiffusionValuesTo"] ~= nil then
		GCO.Error("previous call to SetPlotDiffusionValuesTo has failed for ".. self:GetX()..","..self:GetY())
		ShowDebug()
	end
	
	-- initialize and set local debug table
	debugTable["SetPlotDiffusionValuesTo"] 	= {} 
	local textTable 						= debugTable["SetPlotDiffusionValuesTo"]
	
	table.insert(textTable, "Set PlotDiffusionValues at turn ".. GCO.GetTurnKey() .." for ".. self:GetX()..","..self:GetY().." to ".. DirectionString[iDirection])
	
	local plotKey 	= self:GetKey()
	if not _cached[plotKey] then _cached[plotKey] = {} end
	if not _cached[plotKey].PlotDiffusionValues then _cached[plotKey].PlotDiffusionValues = {} end
	
	local pAdjacentPlot = Map.GetAdjacentPlot(self:GetX(), self:GetY(), iDirection)
	if (pAdjacentPlot and not pAdjacentPlot:IsWater()) then
		table.insert(textTable, "To (" .. pAdjacentPlot:GetX()..","..pAdjacentPlot:GetY()..")")
		local iBonus 			= 0
		local iPenalty 			= 0
		local iPlotMaxRatio		= 1		
		local bIsRoute 			= (self:IsRoute() and not self:IsRoutePillaged()) and (pAdjacentPlot:IsRoute() and not pAdjacentPlot:IsRoutePillaged())
		local bIsFollowingRiver	= self:GetRiverPath(pAdjacentPlot) and not self:IsRiverCrossing(iDirection) --self:IsRiverConnection(iDirection) and not self:IsRiverCrossing(direction)
		local bIsCrossingRiver 	= (not bIsRoute) and self:IsRiverCrossing(iDirection)
		local terrainType		= self:GetTerrainType()
		local terrainThreshold	= GameInfo.Terrains[terrainType].CultureThreshold
		local terrainPenalty	= GameInfo.Terrains[terrainType].CulturePenalty
		local terrainMaxPercent	= GameInfo.Terrains[terrainType].CultureMaxPercent
		local featureType		= self:GetFeatureType()
		table.insert(textTable, " - iPlotMaxRatio = "..iPlotMaxRatio..", bIsRoute = ".. tostring(bIsRoute) ..", bIsFollowingRiver =" .. tostring(bIsFollowingRiver) ..", bIsCrossingRiver = " .. tostring(bIsCrossingRiver) ..", terrainType = " .. Locale.Lookup(GameInfo.Terrains[terrainType].Name) ..", terrainThreshold = ".. terrainThreshold ..", terrainPenalty = ".. terrainPenalty ..", terrainMaxPercent = ".. terrainMaxPercent ..", featureType = ".. featureType)
		-- Bonus: following road
		if (bIsRoute) then
			iBonus 			= iBonus + iRoadBonus
			iPlotMaxRatio 	= iPlotMaxRatio * iRoadMax / 100
			table.insert(textTable, " - bIsRoute = true, iPlotMaxRatio = ".. iPlotMaxRatio .. ", iBonus : " .. iBonus)
		end
		
		-- Bonus: following a river
		if (bIsFollowingRiver) then
			iBonus 			= iBonus + iFollowingRiverBonus
			iPlotMaxRatio 	= iPlotMaxRatio * iFollowingRiverMax / 100
			table.insert(textTable, " - bIsFollowingRiver = true, iPlotMaxRatio = ".. iPlotMaxRatio .. ", iBonus : " .. iBonus)
		end
		
		-- Penalty: feature
		if featureType ~= NO_FEATURE then
			local featureThreshold	= GameInfo.Features[featureType].CultureThreshold
			local featurePenalty	= GameInfo.Features[featureType].CulturePenalty
			local featureMaxPercent	= GameInfo.Features[featureType].CultureMaxPercent
			if featurePenalty > 0 then
				iPenalty 		= iPenalty + featurePenalty
				iPlotMaxRatio 	= iPlotMaxRatio * featureMaxPercent / 100
				table.insert(textTable, " - featurePenalty[".. featurePenalty .."] > 0, iPlotMaxRatio = ".. iPlotMaxRatio .. ", iBonus : " .. iBonus .. " iPenalty = "..iPenalty)
			end
		end
		
		-- Penalty: terrain
		if terrainPenalty > 0 then
			iPenalty 		= iPenalty + terrainPenalty
			iPlotMaxRatio 	= iPlotMaxRatio * terrainMaxPercent / 100
			table.insert(textTable, " - terrainPenalty[".. terrainPenalty .."] > 0, iPlotMaxRatio = ".. iPlotMaxRatio .. ", iBonus : " .. iBonus.. " iPenalty = "..iPenalty)
		end
		
		-- Penalty: crossing river
		if bIsCrossingRiver then
			iPenalty 		= iPenalty + iCrossingRiverPenalty
			iPlotMaxRatio 	= iPlotMaxRatio * iCrossingRiverMax / 100
			table.insert(textTable, " - bIsCrossingRiver = true, iPlotMaxRatio = ".. iPlotMaxRatio .. ", iBonus : " .. iBonus .. " iPenalty = "..iPenalty)
		end
		table.insert(textTable, "Setting cached values " .. tostring(_cached[plotKey].PlotDiffusionValues) .. "MaxRatio = ".. iPlotMaxRatio .. ", Bonus : " .. iBonus .. " Penalty = "..iPenalty)
	
		_cached[plotKey].PlotDiffusionValues[iDirection] = { Bonus = iBonus, Penalty = iPenalty, MaxRatio = iPlotMaxRatio }
	end
	table.insert(textTable, "Deleting debug entry... ")
	debugTable["SetPlotDiffusionValuesTo"] = nil
end

local conquestCountdown = {}
function DoConquestCountDown( self )
	local count = conquestCountdown[self:GetKey()]
	if count and count > 0 then
		conquestCountdown[self:GetKey()] = count - 1
	end
end
function GetConquestCountDown( self )
	return conquestCountdown[self:GetKey()] or 0
end
function SetConquestCountDown( self, value )
	conquestCountdown[self:GetKey()] = value
end

function GetCultureTable( self )
	if ExposedMembers.CultureMap and ExposedMembers.CultureMap[self:GetKey()] then
		return ExposedMembers.CultureMap[self:GetKey()]
	end
end
function GetCulture( self, cultureID )
	local plotCulture = self:GetCultureTable()
	if plotCulture then 
		return plotCulture[tostring(cultureID)] or 0
	end
	return 0
end
function SetCulture( self, cultureID, value )
if not GameInfo.CultureGroups[tonumber(cultureID)] then GCO.Error("Called SetCulture for a Culture Group that does not exist #"..tostring(cultureID).." at ".. tostring(self:GetX())..","..tostring(self:GetY())) end
	local key = self:GetKey()
	--print("SetCulture",self:GetX(), self:GetY(), cultureID, GCO.ToDecimals(value))
	if ExposedMembers.CultureMap[key] then 
		ExposedMembers.CultureMap[key][tostring(cultureID)] = value
	else
		ExposedMembers.CultureMap[key] = {}
		ExposedMembers.CultureMap[key][tostring(cultureID)] = value
	end
end
function ChangeCulture( self, cultureID, value )
if not GameInfo.CultureGroups[tonumber(cultureID)] then GCO.Error("Called ChangeCulture for a Group that does not exist #"..tostring(cultureID).." at ".. tostring(self:GetX())..","..tostring(self:GetY())) end
	local key = self:GetKey()
	local value = GCO.Round(value)
	--print("ChangeCulture",self:GetX(), self:GetY(), cultureID, GCO.ToDecimals(value), GCO.ToDecimals(self:GetPreviousCulture(cultureID )))
	if ExposedMembers.CultureMap[key] then 
		if ExposedMembers.CultureMap[key][tostring(cultureID)] then
			ExposedMembers.CultureMap[key][tostring(cultureID)] = ExposedMembers.CultureMap[key][tostring(cultureID)] + value
		else
			ExposedMembers.CultureMap[key][tostring(cultureID)] = value
		end
	else
		ExposedMembers.CultureMap[key] = {}
		ExposedMembers.CultureMap[key][tostring(cultureID)] = value
	end
end

function GetPreviousCulture( self, cultureID )
	local plotCulture = ExposedMembers.PreviousCultureMap[self:GetKey()]
	if plotCulture then 
		return plotCulture[tostring(cultureID)] or 0
	end
	return 0
end
function SetPreviousCulture( self, cultureID, value )
	local key = self:GetKey()
	if ExposedMembers.PreviousCultureMap[key] then 
		ExposedMembers.PreviousCultureMap[key][tostring(cultureID)] = value
	else
		ExposedMembers.PreviousCultureMap[key] = {}
		ExposedMembers.PreviousCultureMap[key][tostring(cultureID)] = value
	end
end

function GetTotalCulture( self )
	local totalCulture = 0
	local plotCulture = self:GetCultureTable()
	if  plotCulture then
		for cultureID, value in pairs (plotCulture) do
			totalCulture = totalCulture + value			
		end
	end
	return totalCulture
end

function GetCulturePercentTable( self )
	-- return a table with civs culture % for a plot in cultureMap and the total culture
	local plotCulturePercent = {}
	local totalCulture = self:GetTotalCulture()
	local plotCulture = self:GetCultureTable()
	if  plotCulture and totalCulture > 0 then
		for cultureID, value in pairs (plotCulture) do
			plotCulturePercent[cultureID] = GCO.ToDecimals(value * Div(100, totalCulture))
		end
	end
	return plotCulturePercent, totalCulture
end

function GetCulturePercent( self, cultureID )
	local totalCulture = self:GetTotalCulture()
	if totalCulture > 0 then
		return GCO.Round(self:GetCulture(cultureID) * Div(100, totalCulture))
	end
	return 0
end

function GetHighestCultureID( self )
	local topPlayer
	local topValue = 0
	local plotCulture = self:GetCultureTable()
	if  plotCulture then
		for cultureKey, value in pairs (plotCulture) do
			if value > topValue then
				topValue = value
				topPlayer = cultureKey
			end
		end
	end
	return tonumber(topPlayer) -- can be nil
end

function GetTotalPreviousCulture( self )
	local totalCulture = 0
	local plotCulture = ExposedMembers.PreviousCultureMap[self:GetKey()]
	if  plotCulture then
		for cultureID, value in pairs (plotCulture) do
			totalCulture = totalCulture + value			
		end
	end
	return totalCulture
end

function GetCulturePer10000( self, cultureID )
	local totalCulture = GetTotalCulture( self )
	if totalCulture > 0 then
		return GCO.Round(GetCulture( self, cultureID ) * Div(10000, totalCulture))
	end
	return 0
end
function GetPreviousCulturePer10000( self, cultureID )
	local totalCulture = GetTotalPreviousCulture( self )
	if totalCulture > 0 then
		return GCO.Round(GetPreviousCulture( self, cultureID ) * Div(10000, totalCulture))
	end
	return 0
end

function IsLockedByWarForPlayer( self, playerID )
	local bLocked = false
	if (tonumber(GameInfo.GlobalParameters["CULTURE_LOCK_FLIPPING_ON_WAR"].Value) > 0)
	and (self:GetOwner() ~= NO_OWNER)
	and Players[playerID]
	and Players[playerID]:GetDiplomacy():IsAtWarWith(self:GetOwner()) then
		bLocked = true
	end
	return bLocked
end
function IsLockedByFortification( self )
	if (tonumber(GameInfo.GlobalParameters["CULTURE_NO_FORTIFICATION_FLIPPING"].Value) > 0) then
		local improvementType = self:GetImprovementType()
		if ( improvementType ~= NO_IMPROVEMENT) and (not GCO.IsImprovementPillaged(self)) then -- and (not self:IsImprovementPillaged()) then		
			if (GameInfo.Improvements[improvementType].GrantFortification > 0) then
				return true
			end
		end
	end
	return false
end
function IsLockedByCitadelForPlayer( self, playerID )
	if (tonumber(GameInfo.GlobalParameters["CULTURE_NO_FORTIFICATION_FLIPPING"].Value) > 0) then
		local iX = self:GetX()
		local iY = self:GetY()
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
			if (adjacentPlot ~= nil) and (not adjacentPlot:IsWater()) and (not adjacentPlot:GetOwner() == playerID) then
				local improvementType = self:GetImprovementType()
				if ( improvementType ~= NO_IMPROVEMENT) and (not GCO.IsImprovementPillaged(self)) then		
					if (GameInfo.Improvements[improvementType].GrantFortification > 0) then
						return true
					end
				end
			end
		end		
	end
	return false
end

function GetPotentialOwner( self )
	local bestPlayer = NO_OWNER
	local topValue = 0
	local plotCulture = self:GetCultureTable()
	if plotCulture then
		for cultureID, value in pairs (plotCulture) do
			local playerID	= GetPlayerIDFromCultureID(cultureID)
			if playerID then
				local player 	= Players[tonumber(playerID)]
				if player and player:IsAlive() and value > topValue then
					if not (bOnlyAdjacentCultureFlipping and not self:IsAdjacentPlayer(playerID)) then
						topValue = value
						bestPlayer = playerID
					end
				end
			end
		end
	end
	return tonumber(bestPlayer)
end

function IsTerritorialWaterOf( self, playerID )
	if not (self:IsAdjacentOwned() and self:IsAdjacentToLand()) then return false end
	local adjacentTerritoryLand	= 0
	local minimumCulture		= GetCultureMinimumForAcquisition( playerID )
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(self:GetX(), self:GetY(), direction);
		if (adjacentPlot ~= nil) and (not adjacentPlot:IsWater()) then
			if (adjacentPlot:GetOwner() ~= playerID) then -- all land plots must have the same owner
				return false
			elseif adjacentPlot:GetCulture( playerID ) >= minimumCulture then
				adjacentTerritoryLand = adjacentTerritoryLand + 1
			end
		end
	end	
	return (adjacentTerritoryLand >= 3)
end

function GetTerritorialWaterOwner( self )
	local potentialOwner 		= {}
	local bestAdjacentLandOwner	= 0
	local territorialWaterOwner = nil
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(self:GetX(), self:GetY(), direction);
		if (adjacentPlot ~= nil) and (not adjacentPlot:IsWater()) then
			local ownerID = adjacentPlot:GetOwner()
			if (ownerID == NO_OWNER) or (territorialWaterOwner ~= nil and territorialWaterOwner ~= ownerID) then -- all land plots must be owned by the same player player
				return nil
			elseif adjacentPlot:GetCulture( ownerID ) >= GetCultureMinimumForAcquisition( ownerID ) then
				potentialOwner[ownerID] = (potentialOwner[ownerID] or 0) + 1
				if potentialOwner[ownerID] >= 3 and potentialOwner[ownerID] > bestAdjacentLandOwner then
					bestAdjacentLandOwner = potentialOwner[ownerID]
					territorialWaterOwner = ownerID
				end
			end
		end
	end	
	return territorialWaterOwner
end

function MatchCultureToPopulation( self, population)

	if debugTable["MatchCultureToPopulation"] ~= nil then
		GCO.Error("previous call to MatchCultureToPopulation has failed for ".. self:GetX()..","..self:GetY())
		ShowDebug()
	end
	
	-- initialize and set local debug table
	debugTable["MatchCultureToPopulation"] 	= {} 
	local textTable 						= debugTable["MatchCultureToPopulation"]
	
	table.insert(textTable, "Match Culture Groups To Population at turn ".. GCO.GetTurnKey() .." for (".. tostring(self:GetX()) .. "," .. tostring(self:GetY()) ..") " )

	-- Adapt Culture to Population
	local totalCulture		= self:GetTotalCulture()
	local totalPopulation	= population or self:GetPopulation()
	if totalCulture ~= totalPopulation then
	
		if not self:IsCity() and population == nil then
			GCO.Error("totalCulture ~= totalPopulation on a non-city plot at ".. self:GetX()..","..self:GetY())
		end
	
		local removeRatio		= 0
		local addRatio			= 0

		if totalPopulation < totalCulture then
			local toRemove	= totalCulture - totalPopulation
			removeRatio		= Div(toRemove, totalCulture)
		elseif totalCulture < totalPopulation then
			local toAdd		= totalPopulation - totalCulture
			addRatio		= Div(toAdd, totalPopulation)	
		end
		
		local plotCulture = self:GetCultureTable()
		if plotCulture then
			table.insert(textTable, "----- Culture and Population matching -----")
			for cultureID, value in pairs (plotCulture) do
				
				-- Match Culture to Population
				if value > 0 then
					local change = 0
					if removeRatio > 0 then
						change	= - math.ceil(removeRatio * value) --
					
					elseif addRatio > 0 then
						change	= math.floor(addRatio * value) --
					end
					if change ~= 0 then
						if (value + change) <= 0 then
							self:SetCulture(cultureID, 0)
							table.insert(textTable, "Player #"..tostring(cultureID) .." (value ["..tostring(value).."] + change [".. tostring(change) .."]) <= 0 -> SetCulture("..tostring(cultureID) ..", ".. tostring(0)..")")
						else
							self:ChangeCulture(cultureID, change)
							table.insert(textTable, "Player #"..tostring(cultureID) .." (value ["..tostring(value).."] - change [".. tostring(change) .."]) = ".. tostring(value - change).."  -> ChangeCulture("..tostring(cultureID) ..", ".. tostring(- change)..")")	
						end
					end
				else -- remove dead culture
					ExposedMembers.CultureMap[self:GetKey()][tostring(cultureID)] = nil
					table.insert(textTable, "Player #"..tostring(cultureID) .." value ["..tostring(value).."] <= 0 before change, removing entry...")	
				end
			end
			
			-- Handle rounding values
			local totalCulture	= self:GetTotalCulture()
			if totalPopulation > totalCulture then
				self:ChangeCulture(INDEPENDENT_CULTURE, totalPopulation - totalCulture )
			end
			
			table.insert(textTable, "----- ----- -----")
		end
	end
	--if self:GetOwner() == Game.GetLocalPlayer() then ShowDebug() end
	debugTable["MatchCultureToPopulation"] = nil
end

function UpdateCulture( self )

	local DEBUG_PLOT_SCRIPT	= DEBUG_PLOT_SCRIPT
	--if self:GetOwner() == Game.GetLocalPlayer() and self:IsCity() then DEBUG_PLOT_SCRIPT = "debug" end	

	if debugTable["UpdateCulture"] ~= nil then
		GCO.Error("previous call to UpdateCulture has failed for ".. self:GetX()..","..self:GetY())
		ShowDebug()
	end
	
	-- initialize and set local debug table
	debugTable["UpdateCulture"] 	= {} 
	local textTable 				= debugTable["UpdateCulture"]
	
	table.insert(textTable, "Update Culture at turn ".. GCO.GetTurnKey() .." for (".. tostring(self:GetX()) .. "," .. tostring(self:GetY()) ..") " )

	-- Limited culture on water
	if self:IsWater() then
		local ownerID = self:GetOwner()
		if (ownerID ~= NO_OWNER) then --(ownerID ~= NO_OWNER) and (self:GetDistrictType() == -1) and (not self:IsTerritorialWaterOf(ownerID)) then
			--WorldBuilder.CityManager():SetPlotOwner( self:GetX(), self:GetY(), false )
			self:SetOwner(-1)
		end
		if false then --(ownerID == NO_OWNER) and self:IsAdjacentOwned() and self:IsAdjacentToLand() then
			local potentialOwnerID = self:GetTerritorialWaterOwner()
			if potentialOwnerID then			
				local city, distance = GCO.FindNearestPlayerCity(potentialOwnerID, self:GetX(), self:GetY())
				if not city then				
					debugTable["UpdateCulture"] = nil
					return
				end
				if distance > GetCultureFlippingMaxDistance(potentialOwnerID) then
					debugTable["UpdateCulture"] = nil
					return 
				end
				--WorldBuilder.CityManager():SetPlotOwner( self:GetX(), self:GetY(), potentialOwnerID, city:GetID() )
				self:SetOwner(-1)
				self:SetOwner(potentialOwnerID, city:GetID(), true)
				
			end
		end
		debugTable["UpdateCulture"] = nil
		return
	end
	
	local plotCulture 		= self:GetCultureTable()
	local totalCulture		= self:GetTotalCulture()
	local minCulture		= self:GetPopulation() -- (self:GetSize() + 1) * 50
	local maxCulture		= self:GetPopulation() * 2 -- (self:GetSize() + 1) * 50	
	
	-- update culture in cities
	table.insert(textTable, "Check for city")
	if self:IsCity() then
		local city 			= self:GetCity() --Cities.GetCityInPlot(self:GetX(), self:GetY())
		local cityCultureID = GetCultureIDFromPlayerID(city:GetOwner())
		--local cityCulture = city:GetCulture()
		table.insert(textTable, "----- ".. tostring(city:GetName()) .." -----")	
		
		Dprint( DEBUG_PLOT_SCRIPT, "Update culture in ".. city:GetName() .. ", Total Culture = " .. tostring(totalCulture))
		
		-- Culture creation in cities
		-- (commented out at end of file)
		
		-- Culture Conversion in cities
		local cultureConversionRatePer10000 = tonumber(GameInfo.GlobalParameters["CULTURE_CITY_CONVERSION_RATE"].Value)
		
		-- Todo : add conversion from buildings, policies...
		
		if (cultureConversionRatePer10000 > 0) then 
			if plotCulture then
				for cultureID, value in pairs (plotCulture) do
					if GetPlayerIDFromCultureID(cultureID) ~= city:GetOwner() and cultureID ~= SEPARATIST_CULTURE then
						local converted = GCO.Round(value * cultureConversionRatePer10000 / 10000)
						Dprint( DEBUG_PLOT_SCRIPT, "  - "..Indentation20("cultureID#"..tostring(cultureID)).. Indentation20(" converted = ".. tostring(converted)).. ", from Culture Value = " .. tostring(value))
						if converted > 0 then
							self:ChangeCulture(cultureID, -converted)
							self:ChangeCulture(cityCultureID, converted)
						end						
					end
				end
			end				
		end
		table.insert(textTable, "----- ----- -----")
	end
	
	-- Todo : improvements/units can affect culture
	
	-- Update Ownership
	if bAllowCultureAcquisition or bAllowCultureFlipping then
		self:UpdateOwnership()
	end
	
	-- Update locked plot
	if tonumber(GameInfo.GlobalParameters["CULTURE_CONQUEST_ENABLED"].Value) > 0 then
		self:DoConquestCountDown()
	end	
	--if self:IsAdjacentPlayer(0) then ShowDebug() end
	--if self:GetOwner() == Game.GetLocalPlayer() then ShowDebug() end
	debugTable["UpdateCulture"] = nil
end

function UpdateOwnership( self )

	if debugTable["UpdateOwnership"] ~= nil then
		GCO.Error("previous call to UpdateOwnership has failed for ".. self:GetX()..","..self:GetY())
		ShowDebug()
	end
	
	-- initialize and set local debug table
	debugTable["UpdateOwnership"] 	= {} 
	local textTable 				= debugTable["UpdateOwnership"]
	
	table.insert(textTable, "Update Ownership at turn ".. GCO.GetTurnKey() .." for (" .. self:GetX()..","..self:GetY()..")")
	if self:GetTotalCulture() > 0 then
		table.insert(textTable, "Total culture = " .. self:GetTotalCulture())
	end
	
	-- cities do not flip without Revolutions...
	if self:IsCity() then
		debugTable["UpdateOwnership"] = nil
		return
	end
	table.insert(textTable, "Not City")
	
	-- if plot is locked, don't try to change ownership...
	if (self:GetConquestCountDown() > 0) then
		debugTable["UpdateOwnership"] = nil
		return
	end
	table.insert(textTable, "Not Conquered")
	
	-- 	check if fortifications on this plot are preventing tile flipping...
	if (self:IsLockedByFortification()) then
		debugTable["UpdateOwnership"] = nil
		return
	end
	table.insert(textTable, "Not Locked by Fortification")
	
	-- Get potential owner
	local bestPlayerID = self:GetPotentialOwner()
	table.insert(textTable, "PotentialOwner = " .. bestPlayerID)
	if (bestPlayerID == NO_OWNER or bestPlayerID == nil) then
		debugTable["UpdateOwnership"] = nil
		return
	end
	local bestValue = self:GetCulture(GetCultureIDFromPlayerID(bestPlayerID))
	
	
	table.insert(textTable, "ActualOwner[".. self:GetOwner() .."] ~= PotentialOwner AND  bestValue[".. bestValue .."] > GetCultureMinimumForAcquisition( PotentialOwner )[".. GetCultureMinimumForAcquisition( PotentialOwner ) .."] ?" )
	if (bestPlayerID ~= self:GetOwner()) and (bestValue > GetCultureMinimumForAcquisition( bestPlayerID )) then
	
		-- Do we allow tile flipping when at war ?		
		if (self:IsLockedByWarForPlayer(bestPlayerID)) then
			debugTable["UpdateOwnership"] = nil
			return
		end
		table.insert(textTable, "Not Locked by war")
		
		-- check if an adjacent fortification can prevent tile flipping...
		if (self:IsLockedByCitadelForPlayer(bestPlayerID)) then
			debugTable["UpdateOwnership"] = nil
			return
		end
		table.insert(textTable, "Not Locked by Adjacent Fortification")
		
		-- case 1: the tile was not owned and tile acquisition is allowed
		local bAcquireNewPlot = (self:GetOwner() == NO_OWNER and bAllowCultureAcquisition)		
		table.insert(textTable, "bAcquireNewPlot = (self:GetOwner()[".. self:GetOwner() .."] == NO_OWNER[".. NO_OWNER .."] AND bAllowCultureAcquisition[".. tostring(bAllowCultureAcquisition) .."]) =" .. tostring(bAcquireNewPlot))
		
		-- case 2: tile flipping is allowed and the ratio between the old and the new owner is high enough
		local bConvertPlot = (bAllowCultureFlipping and (bestValue * tonumber(GameInfo.GlobalParameters["CULTURE_FLIPPING_RATIO"].Value)/100) > self:GetCulture(self:GetOwner()))
		table.insert(textTable, "bConvertPlot = bAllowCultureFlipping[".. tostring(bAllowCultureFlipping) .."] AND (bestValue[".. bestValue .."] * CULTURE_FLIPPING_RATIO[".. GameInfo.GlobalParameters["CULTURE_FLIPPING_RATIO"].Value .."]/100) > self:GetCulture(self:GetOwner())[".. self:GetCulture(self:GetOwner()) .."]) = " .. tostring(bConvertPlot))

		if bAcquireNewPlot or bConvertPlot then
			local city, distance = GCO.FindNearestPlayerCity(tonumber(bestPlayerID), self:GetX(), self:GetY())
			table.insert(textTable, "City: "..tostring(city)..", distance = " .. tostring(distance))
			if not city then
				debugTable["UpdateOwnership"] = nil
				return
			end
			
			-- Is the plot too far away ?			
			table.insert(textTable, "distance[".. tostring(distance) .."] <= GetCultureFlippingMaxDistance(bestPlayerID)[".. GetCultureFlippingMaxDistance(bestPlayerID) .."] ?")
			if distance > GetCultureFlippingMaxDistance(bestPlayerID) then
				debugTable["UpdateOwnership"] = nil
				return
			end
			
			-- Is there a path from the city to the plot ?
			local cityPlot	= GetPlot(city:GetX(), city:GetY())
			local path 		= self:GetPathToPlot(cityPlot, Players[bestPlayerID], "Land", GCO.TradePathBlocked, GetCultureFlippingMaxDistance(bestPlayerID))
			if not path then
				debugTable["UpdateOwnership"] = nil
				return
			end
			
			-- All test passed succesfully, notify the players and change owner...
			-- to do : notify the players...
			table.insert(textTable, "Changing owner !")
			self:SetOwner(-1)
			self:SetOwner(bestPlayerID, city:GetID(), true)
			--WorldBuilder.CityManager():SetPlotOwner( self:GetX(), self:GetY(), bestPlayerID, city:GetID() )
		end	
	end
	--if self:IsAdjacentPlayer(0) then ShowDebug() end
	--if self:GetOwner() == Game.GetLocalPlayer() then ShowDebug() end
	debugTable["UpdateOwnership"] = nil
end

function DiffuseCulture( self )

	if debugTable["DiffuseCulture"] ~= nil then
		GCO.Error("previous call to DiffuseCulture has failed for ".. self:GetX()..","..self:GetY())
		ShowDebug()
	end
	
	-- initialize and set local debug table
	debugTable["DiffuseCulture"] 	= {} 
	local textTable 				= debugTable["DiffuseCulture"]
	
	table.insert(textTable, "Diffuse Culture at turn ".. GCO.GetTurnKey() .." for ".. self:GetX()..","..self:GetY())
	local iX = self:GetX()
	local iY = self:GetY()
	local iCultureValue 	= self:GetTotalCulture()
	local iPlotBaseMax 		= iCultureValue * tonumber(GameInfo.GlobalParameters["CULTURE_NORMAL_MAX_PERCENT"].Value) / 100
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local pAdjacentPlot = Map.GetAdjacentPlot(iX, iY, direction)
		if (pAdjacentPlot and not pAdjacentPlot:IsWater()) then
			table.insert(textTable, "Direction = " .. DirectionString[direction] ..", to (" .. pAdjacentPlot:GetX()..","..pAdjacentPlot:GetY()..")")
			local iBonus 			= 0
			local iPenalty 			= 0
			local iPlotMax 			= iPlotBaseMax		
			local bIsRoute 			= (self:IsRoute() and not self:IsRoutePillaged()) and (pAdjacentPlot:IsRoute() and not pAdjacentPlot:IsRoutePillaged())
			local bIsFollowingRiver	= self:GetRiverPath(pAdjacentPlot) and not self:IsRiverCrossing(direction) --self:IsRiverConnection(direction) and not self:IsRiverCrossing(direction)
			local bIsCrossingRiver 	= (not bIsRoute) and self:IsRiverCrossing(direction)
			local terrainType		= self:GetTerrainType()
			local terrainThreshold	= GameInfo.Terrains[terrainType].CultureThreshold
			local terrainPenalty	= GameInfo.Terrains[terrainType].CulturePenalty
			local terrainMaxPercent	= GameInfo.Terrains[terrainType].CultureMaxPercent
			local featureType		= self:GetFeatureType()
			local bSkip				= false
			table.insert(textTable, " - iPlotMax = "..iPlotMax..", bIsRoute = ".. tostring(bIsRoute) ..", bIsFollowingRiver =" .. tostring(bIsFollowingRiver) ..", bIsCrossingRiver = " .. tostring(bIsCrossingRiver) ..", terrainType = " .. terrainType ..", terrainThreshold = ".. terrainThreshold ..", terrainPenalty = ".. terrainPenalty ..", terrainMaxPercent = ".. terrainMaxPercent ..", featureType = ".. featureType)
			-- Bonus: following road
			if (bIsRoute) then
				iBonus 		= iBonus + iRoadBonus
				iPlotMax 	= iPlotMax * iRoadMax / 100
				table.insert(textTable, " - bIsRoute = true, iPlotMax = ".. iPlotMax .. ", iBonus : " .. iBonus)
			end
			
			-- Bonus: following a river
			if (bIsFollowingRiver) then
				iBonus 		= iBonus + iFollowingRiverBonus
				iPlotMax 	= iPlotMax * iFollowingRiverMax / 100
				table.insert(textTable, " - bIsFollowingRiver = true, iPlotMax = ".. iPlotMax .. ", iBonus : " .. iBonus)
			end
			
			-- Penalty: feature
			if featureType ~= NO_FEATURE then
				local featureThreshold	= GameInfo.Features[featureType].CultureThreshold
				local featurePenalty	= GameInfo.Features[featureType].CulturePenalty
				local featureMaxPercent	= GameInfo.Features[featureType].CultureMaxPercent
				if featurePenalty > 0 then
					if iCultureValue > featureThreshold * iBaseThreshold / 100 then
						iPenalty 	= iPenalty + featurePenalty
						iPlotMax 	= iPlotMax * featureMaxPercent / 100
						table.insert(textTable, " - featurePenalty[".. featurePenalty .."] > 0, iPlotMax = ".. iPlotMax .. ", iBonus : " .. iBonus)
					else
						bSkip = true -- no diffusion on that plot
						table.insert(textTable, " - Skipping plot (iCultureValue[".. iCultureValue .."] < featureThreshold[".. featureThreshold .."] * iBaseThreshold[".. iBaseThreshold .."] / 100)")
					end
				end
			end
			
			-- Penalty: terrain
			if not bSkip then
				if terrainPenalty > 0 then
					if iCultureValue > terrainThreshold * iBaseThreshold / 100 then
						iPenalty 	= iPenalty + terrainPenalty
						iPlotMax 	= iPlotMax * terrainMaxPercent / 100
						table.insert(textTable, " - terrainPenalty[".. terrainPenalty .."] > 0, iPlotMax = ".. iPlotMax .. ", iBonus : " .. iBonus)
					else
						bSkip = true -- no diffusion on that plot
						table.insert(textTable, " - Skipping plot (iCultureValue[".. iCultureValue .."] < terrainThreshold[".. terrainThreshold .."] * iBaseThreshold[".. iBaseThreshold .."] / 100)")
					end
				end
			end
			
			-- Penalty: crossing river
			if not bSkip then
				if bIsCrossingRiver then
					if iCultureValue > iCrossingRiverThreshold * iBaseThreshold / 100 then
						iPenalty 	= iPenalty + iCrossingRiverPenalty
						iPlotMax 	= iPlotMax * iCrossingRiverMax / 100
						table.insert(textTable, " - bIsCrossingRiver = true, iPlotMax = ".. iPlotMax .. ", iBonus : " .. iBonus)
					else
						bSkip = true -- no diffusion on that plot
						table.insert(textTable, " - Skipping plot (iCultureValue[".. iCultureValue .."] < iCrossingRiverThreshold[".. iCrossingRiverThreshold .."] * iBaseThreshold[".. iBaseThreshold .."] / 100)")
					end
				end
			end
			
			if not bSkip then				
				table.insert(textTable, " - iPlotMax = math.min(iPlotMax[" .. iPlotMax.."], iCultureValue[" .. iCultureValue.."] * CULTURE_ABSOLUTE_MAX_PERCENT[" .. tonumber(GameInfo.GlobalParameters["CULTURE_ABSOLUTE_MAX_PERCENT"].Value).."] / 100) = " ..math.min(iPlotMax, iCultureValue * tonumber(GameInfo.GlobalParameters["CULTURE_ABSOLUTE_MAX_PERCENT"].Value) / 100))
				iPlotMax = math.min(iPlotMax, iCultureValue * tonumber(GameInfo.GlobalParameters["CULTURE_ABSOLUTE_MAX_PERCENT"].Value) / 100)
				-- Apply Culture diffusion to all culture groups
				local plotCulture = self:GetCultureTable() -- this should never be nil at this point
				for cultureID, value in pairs (plotCulture) do
				
					local iPlayerPlotMax = iPlotMax * self:GetCulturePercent(cultureID) / 100
					local iPlayerDiffusedCulture = Div((self:GetCulture(cultureID) * (iDiffusionRatePer1000 + (iDiffusionRatePer1000 * iBonus / 100))), (1000 + (1000 * iPenalty / 100)))
					local iPreviousCulture = pAdjacentPlot:GetCulture(cultureID);
					local iNextculture = math.min(iPlayerPlotMax, iPreviousCulture + iPlayerDiffusedCulture);
					table.insert(textTable, " - Diffuse for player#"..cultureID..", iPlotMax = "..iPlotMax..", iPlayerPlotMax = ".. GCO.ToDecimals(iPlayerPlotMax) ..", iPreviousCulture = ".. GCO.ToDecimals(iPreviousCulture) ..", iNextculture = " ..GCO.ToDecimals(iNextculture)) 
					table.insert(textTable, "		iPlayerDiffusedCulture["..GCO.ToDecimals(iPlayerDiffusedCulture).."] = (self:GetCulture(cultureID)["..GCO.ToDecimals(self:GetCulture(cultureID)).."] * (iDiffusionRatePer1000["..GCO.ToDecimals(iDiffusionRatePer1000).."] + (iDiffusionRatePer1000["..GCO.ToDecimals(iDiffusionRatePer1000).."] * iBonus["..GCO.ToDecimals(iBonus).."] / 100))) / (1000 + (1000 * iPenalty["..GCO.ToDecimals(iPenalty).."] / 100))")
					
					iPlayerDiffusedCulture = iNextculture - iPreviousCulture
					if (iPlayerDiffusedCulture > 0) then -- can be < 0 when a plot try to diffuse to another with a culture value already > at the calculated iPlayerPlotMax...
						pAdjacentPlot:ChangeCulture(cultureID, iPlayerDiffusedCulture)
						table.insert(textTable, " - Diffusing : " .. iPlayerDiffusedCulture)
					else
						table.insert(textTable, " - Not diffusing negative value... (" .. iPlayerDiffusedCulture ..")")
					end
				end				
			end
		else
			table.insert(textTable, " - Skipping plot (water)")
		end
	end
	table.insert(textTable, "----- ----- -----")
	--if self:IsAdjacentPlayer(0) then ShowDebug() end
	--if self:GetOwner() == Game.GetLocalPlayer() then ShowDebug() end
	debugTable["DiffuseCulture"] = nil
end

function GetCultureString(self)
	local cultureHeader 	= ""
	local tCultureString	= {}
	local totalCulture		= self:GetTotalCulture()
	if totalCulture > 0 then
		local sortedCulture = {}
		for cultureKey, value in pairs (self:GetCultureTable()) do -- GetCulturePercentTable
			table.insert(sortedCulture, {cultureID = tonumber(cultureKey), value = value})
		end	
		table.sort(sortedCulture, function(a,b) return a.value>b.value end)
		local totalPrevCulture	= self:GetTotalPreviousCulture()
		local numLines 			= 5
		local other 			= 0
		local iter 				= 1
		local iSlaves			= self:GetStock(SlaveClassID)
		local maxCultureLen		= math.max(string.len(totalCulture), string.len(iSlaves))
		local maxVarLen			= string.len(totalCulture - totalPrevCulture) + 1
		local bAlignRight		= true
		
		-- 
		--table.insert(popDetails, Locale.Lookup("LOC_PLOT_TOOLTIP_CULTURE_TOTAL", GCO.Round(totalCulture) ).. GCO.GetVariationStringNoColorHigh(totalCulture - totalPrevCulture))
		
		cultureHeader = Indentation("", 13) .. Indentation("", maxCultureLen, bAlignRight) .. "[ICON_Position]" .. Indentation("", 5 + maxVarLen, bAlignRight) .. "[ICON_UP_DOWN]" .. Indentation("", 2, bAlignRight)  .. "[ICON_UP_DOWN]%"
		--table.insert(tCultureString, Indentation("", 15) .. Indentation("", math.max(1,maxCultureLen-2), bAlignRight) .. "[ICON_Position]" .. Indentation("", 4, bAlignRight) .. Indentation("", maxVarLen, bAlignRight) .. "[ICON_UP_DOWN]" .. Indentation("", 2, bAlignRight)  .. "[ICON_UP_DOWN]%" )
		--table.insert(tCultureString, "[ICON_Culture]" .. Indentation(Locale.Lookup("LOC_PLOT_TOOLTIP_CULTURE_GROUPS"), 13) .. Indentation("", math.max(1,maxCultureLen-2), bAlignRight) .. "[ICON_Position]" .. Indentation("", 4, bAlignRight) .. Indentation("", maxVarLen, bAlignRight) .. "[ICON_UP_DOWN]" .. Indentation("", 2, bAlignRight)  .. "[ICON_UP_DOWN]%" )
		for i, t in ipairs(sortedCulture) do
			if (iter <= numLines) or (#sortedCulture == numLines + 1) then
				--local playerConfig 		= PlayerConfigurations[t.playerID]
				local percentVariation 	= (self:GetCulturePer10000(t.cultureID) - self:GetPreviousCulturePer10000(t.cultureID)) / 100
				local variation 		= (self:GetCulture(t.cultureID) - self:GetPreviousCulture(t.cultureID))
				local cultureAdjective 	= GameInfo.CultureGroups[t.cultureID].Adjective	--playerConfig and Locale.Lookup(GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Adjective) or "Independant"
				if t.value > 0 then
					--table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_CULTURE_LINE", t.value, cultureAdjective, t.value / totalCulture * 100) .. GCO.GetVariationString(variation))	-- GetVariationStringNoColorPercent
					local percentStr 	= Locale.Lookup("LOC_PERCENT_1", t.value / totalCulture * 100)
					local percentVarStr	= Locale.Lookup("LOC_VAR_NUMBER_2",percentVariation)
					table.insert(tCultureString, Indentation(Locale.Lookup(cultureAdjective), 15) .. "|" .. Indentation(t.value, maxCultureLen, bAlignRight) .. "|" ..  Indentation(percentStr, 6, bAlignRight) .. "|" .. Indentation(variation, maxVarLen, bAlignRight) .. "|" .. Indentation(percentVarStr, 6, bAlignRight) )	--
				end
			else
				other = other + t.value
			end
			iter = iter + 1
		end
		if other > 0 then
			--table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_CULTURE_LINE_OTHER", other))
			local percentStr 	= Locale.Lookup("LOC_PERCENT_1", other / totalCulture * 100)
			table.insert(tCultureString, Indentation(Locale.Lookup("LOC_PLOT_TOOLTIP_CULTURE_LINE_OTHER"), 15) .. "|" .. Indentation(other, maxCultureLen, bAlignRight) .. "|" ..  Indentation(percentStr, 6, bAlignRight) .. "|" .. Indentation("-", maxVarLen, bAlignRight) .. "|" .. Indentation("-", 6, bAlignRight) )	--
		end
		
		if iSlaves > 0 then
			table.insert(tCultureString, Indentation(Locale.Lookup("LOC_POPULATION_SLAVE_NAME"), 15) .. "|" .. Indentation(iSlaves, maxCultureLen, bAlignRight) .. "|")
		end
	end
	return tCultureString, cultureHeader
end



-----------------------------------------------------------------------------------------
-- Other Functions
-----------------------------------------------------------------------------------------
function GetPlayerIDFromCultureID(cultureID)
if not GameInfo.CultureGroups[tonumber(cultureID)] then Dline(cultureID) end
	local CivilizationType	= GameInfo.CultureGroups[tonumber(cultureID)].CultureType
	return GCO.GetPlayerIDFromCivilizationType(CivilizationType)
end

function GetCultureIDFromPlayerID(playerID)
	local playerConfig		= GCO.GetPlayerConfig(playerID)
	local CivilizationType	= playerConfig:GetCivilizationTypeName()
	return GameInfo.CultureGroups[CivilizationType].Index
end

function GetOppositeDirection(dir)
	local numTypes = DirectionTypes.NUM_DIRECTION_TYPES;
	return ((dir + 3) % numTypes);
end

function GetCultureMinimumForAcquisition( playerID )
	-- to do : change by era / policies
	return tonumber(GameInfo.GlobalParameters["CULTURE_MINIMUM_FOR_ACQUISITION"].Value)
end

function GetCultureFlippingMaxDistance( playerID )
	-- to do : change by era / policies
	return tonumber(GameInfo.GlobalParameters["CULTURE_FLIPPING_MAX_DISTANCE"].Value)
end

function UpdateCultureOnCityCapture( originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY )
	Dprint( DEBUG_PLOT_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLOT_SCRIPT, "Update Culture On City Capture")
	local city 		= GCO.GetCity(newOwnerID, newCityID)
	local cityPlots = GCO.GetCityPlots(city)
	for _, plotID in ipairs(cityPlots) do
		local plot	= Map.GetPlotByIndex(plotID)
		Dprint( DEBUG_PLOT_SCRIPT, " - Plot at :", plot:GetX(), plot:GetY())
		local totalCultureLoss = 0
		local plotCulture = plot:GetCultureTable()
		for cultureID, value in pairs (plotCulture) do
			local cultureLoss = GCO.Round(plot:GetCulture(cultureID) * tonumber(GameInfo.GlobalParameters["CULTURE_LOST_CITY_CONQUEST"].Value) / 100)
			Dprint( DEBUG_PLOT_SCRIPT, "   - player#"..tostring(cultureID).." lost culture = ", cultureLoss)
			if cultureLoss > 0 then
				totalCultureLoss = totalCultureLoss + cultureLoss
				plot:ChangeCulture(cultureID, -cultureLoss)
			end
		end
		local cultureGained = GCO.Round(totalCultureLoss * tonumber(GameInfo.GlobalParameters["CULTURE_GAIN_CITY_CONQUEST"].Value) / 100)
		Dprint( DEBUG_PLOT_SCRIPT, "   - player#"..tostring(newOwnerID).." gain culture = ", cultureGained)
		plot:ChangeCulture(GetCultureIDFromPlayerID(newOwnerID), cultureGained)
		local distance = Map.GetPlotDistance(iX, iY, plot:GetX(), plot:GetY())
		local bRemoveOwnership = (tonumber(GameInfo.GlobalParameters["CULTURE_REMOVE_PLOT_CITY_CONQUEST"].Value == 1 and distance > tonumber(GameInfo.GlobalParameters["CULTURE_MAX_DISTANCE_PLOT_CITY_CONQUEST"].Value)))
		Dprint( DEBUG_PLOT_SCRIPT, "   - check for changing owner: CULTURE_REMOVE_PLOT_CITY_CONQUEST ="..tostring(GameInfo.GlobalParameters["CULTURE_REMOVE_PLOT_CITY_CONQUEST"].Value)..", distance["..tostring(distance).."] >  CULTURE_MAX_DISTANCE_PLOT_CITY_CONQUEST["..tostring(GameInfo.GlobalParameters["CULTURE_MAX_DISTANCE_PLOT_CITY_CONQUEST"].Value).."]")
		if bRemoveOwnership then
			--WorldBuilder.CityManager():SetPlotOwner( plot:GetX(), plot:GetY(), false )
			self:SetOwner(-1)
		end
	end
end
--GameEvents.CapturedCityInitialized.Add( UpdateCultureOnCityCapture )

-----------------------------------------------------------------------------------------
-- Initialize Culture Functions
-----------------------------------------------------------------------------------------
function SetCultureDiffusionRatePer1000()
	local iSettingFactor 	= 1
	local iStandardTurns 	= 500
	local iTurnsFactor 		= 1
	-- to do : GameSpeed_Turns, GameSpeedType, add all TurnsPerIncrement
	-- iTurnsFactor = Div((iStandardTurns * 100), (getEstimateEndTurn() - getGameTurn()))
	
	local iStandardSize		= 84*54 -- to do : Maps, MapSizeType = Map.GetMapSize(), GridWidth*GridHeight
	local g_iW, g_iH 		= Map.GetGridSize()
	local iMapsize 			= g_iW * g_iH
	local iSizeFactor 		= Div((iMapsize * 100), iStandardSize)
	
	iSettingFactor = iSettingFactor * iSizeFactor
	
	iDiffusionRatePer1000 = (tonumber(GameInfo.GlobalParameters["CULTURE_DIFFUSION_RATE"].Value) * iSettingFactor / 100) / 10
	Dprint( DEBUG_PLOT_SCRIPT, "iSettingFactor = ".. tostring(iSettingFactor))
	Dprint( DEBUG_PLOT_SCRIPT, "iDiffusionRatePer1000 = ".. tostring(iDiffusionRatePer1000))
	iDiffusionRatePer1000 = tonumber(GameInfo.GlobalParameters["CULTURE_DIFFUSION_RATE"].Value) / 10
	Dprint( DEBUG_PLOT_SCRIPT, "iDiffusionRatePer1000 = ".. tostring(iDiffusionRatePer1000))
end

function InitializeCityPlots(playerID, cityID, iX, iY)
	Dprint( DEBUG_PLOT_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLOT_SCRIPT, "Initializing New City Plots...")
	local city 		= CityManager.GetCity(playerID, cityID)
	local cityPlot 	= Map.GetPlot(iX, iY)
	local cityPlots	= GCO.GetCityPlots(city)
	local counter 	= 0
	local ring		= 2 -- first ring to test for replacement plots
	for _, plotID in ipairs(cityPlots) do		
		local plot	= Map.GetPlotByIndex(plotID)
		local x		= plot:GetX()
		local y		= plot:GetY()
		if (plot:IsWater() or ( (plot:GetArea():GetID() ~= cityPlot:GetArea():GetID()) and not plot:IsMountain() )) and (plot:GetOwner() ~= NO_OWNER) then
			--adjacentPlot:SetOwner(NO_OWNER)
			--WorldBuilder.CityManager():SetPlotOwner( x, y, false )
			plot:SetOwner(-1, -1, true)
			counter = counter + 1
		end
	end
	Dprint( DEBUG_PLOT_SCRIPT, "- plots to replace = ", counter)
	function ReplacePlots()
		local plotList = {}
		if counter > 0 then
			for pEdgePlot in GCO.PlotRingIterator(cityPlot, ring) do
				if not ((pEdgePlot:IsWater() or ( pEdgePlot:GetArea():GetID() ~= cityPlot:GetArea():GetID() ))) and (pEdgePlot:GetOwner() == NO_OWNER) and pEdgePlot:IsAdjacentPlayer(playerID) then
					Dprint( DEBUG_PLOT_SCRIPT, "   adding to list :", pEdgePlot:GetX(), pEdgePlot:GetY(), "on ring :", ring)
					local totalYield = 0
					for row in GameInfo.Yields() do
						local yield = pEdgePlot:GetYield(row.Index);
						if (yield > 0) then
							totalYield = totalYield + 1
						end
					end
					local resourceID = pEdgePlot:GetResourceType()
					if resourceID ~= NO_RESOURCE then
						if Players[playerID]:IsResourceVisible(resourceID) then
							totalYield = totalYield + 2
						end
					end
					table.insert(plotList, {plot = pEdgePlot, yield = totalYield})				
				end
			end
		end
		table.sort(plotList, function(a, b) return a.yield > b.yield; end)
		for _, data in ipairs(plotList) do
			Dprint( DEBUG_PLOT_SCRIPT, "   replacing at : ", data.plot:GetX(), data.plot:GetY())
			--WorldBuilder.CityManager():SetPlotOwner( data.plot:GetX(), data.plot:GetY(), playerID, cityID )
			data.plot:SetOwner(-1)
			data.plot:SetOwner(playerID, cityID, true)
			counter = counter - 1
			if counter == 0 then
				return
			end
		end
	end
	local loop = 0
	while (counter > 0 and loop < 4) do
		Dprint( DEBUG_PLOT_SCRIPT, " - loop =", loop, "plots to replace left =", counter )
		ReplacePlots()
		ring = ring + 1
		ReplacePlots()
		ring = ring - 1  -- some plots that where not adjacent to another plot of that player maybe now
		ReplacePlots()
		ring = ring + 1
		loop = loop + 1
	end
	
	Dprint( DEBUG_PLOT_SCRIPT, "- check city ownership")	
	for ring = 1, 3 do
		for pEdgePlot in GCO.PlotRingIterator(cityPlot, ring) do
			local OwnerCity	= Cities.GetPlotPurchaseCity(pEdgePlot)
			if OwnerCity and pEdgePlot:GetOwner() == playerID and OwnerCity:GetID() ~= city:GetID() then
				local cityDistance 		= Map.GetPlotDistance(pEdgePlot:GetX(), pEdgePlot:GetY(), city:GetX(), city:GetY())
				local ownerCityDistance = Map.GetPlotDistance(pEdgePlot:GetX(), pEdgePlot:GetY(), OwnerCity:GetX(), OwnerCity:GetY())
				if (cityDistance < ownerCityDistance) and (pEdgePlot:GetWorkerCount() == 0 or cityDistance == 1) then
					Dprint( DEBUG_PLOT_SCRIPT, "   change city ownership at : ", pEdgePlot:GetX(), pEdgePlot:GetY(), " city distance = ", cityDistance, " previous city = ", Locale.Lookup(OwnerCity:GetName()), " previous city distance = ", ownerCityDistance)
					--WorldBuilder.CityManager():SetPlotOwner( pEdgePlot, false ) -- must remove previous city ownership first, else the UI context doesn't update
					--WorldBuilder.CityManager():SetPlotOwner( pEdgePlot, city, true )
					--LuaEvents.UpdatePlotTooltip(  pEdgePlot:GetIndex() )
					--print(Cities.GetPlotPurchaseCity(pEdgePlot):GetName())
					--Events.CityWorkerChanged(playerID, city:GetID())
					--pEdgePlot:SetOwner(city)
					
					pEdgePlot:SetOwner(-1)
					pEdgePlot:SetOwner(OwnerCity:GetOwner(), OwnerCity:GetID(), true)
				end
			end
		end
	end
end
Events.CityInitialized.Add(InitializeCityPlots)


-----------------------------------------------------------------------------------------
-- Region Functions
-----------------------------------------------------------------------------------------

function GetRegions(self)
	return self:GetCached("Regions") or self:SetRegions()
end

function SetRegions(self)
	PlotRegions = {}
	for i, row in pairs(Regions) do
		local x, y			= self:GetX(), self:GetY()
		local regX, regY 	= GetXYFromRefMapXY(row.X, row.Y)
		local regionWidth 	= g_ReferenceWidthRatio * row.Width
		local regionHeight 	= g_ReferenceHeightRatio * row.Height
--print(x, y, regX, regY, regionWidth, regionHeight, row.X, row.Y, row.Width, row.Height)
		if x >= regX and x <= regX + regionWidth and y >= regY and y <= regY + regionHeight then
			table.insert(PlotRegions, row.Region)
		end
	end
	self:SetCached("Regions", PlotRegions)
	return PlotRegions
end

-----------------------------------------------------------------------------------------
-- Rivers Functions
-----------------------------------------------------------------------------------------

function IsEOfRiver(self)
	if not self:IsRiver() then return false	end
	local pAdjacentPlot = Map.GetAdjacentPlot(self:GetX(), self:GetY(), DirectionTypes.DIRECTION_WEST)
	if pAdjacentPlot and pAdjacentPlot:IsWOfRiver() then return true end
	return false
end

function IsSEOfRiver(self)
	if not self:IsRiver() then return false	end
	local pAdjacentPlot = Map.GetAdjacentPlot(self:GetX(), self:GetY(), DirectionTypes.DIRECTION_NORTHWEST)
	if pAdjacentPlot and pAdjacentPlot:IsNWOfRiver() then return true end
	return false
end

function IsSWOfRiver(self)
	if not self:IsRiver() then return false	end
	local pAdjacentPlot = Map.GetAdjacentPlot(self:GetX(), self:GetY(), DirectionTypes.DIRECTION_NORTHEAST)
	if pAdjacentPlot and pAdjacentPlot:IsNEOfRiver() then return true end
	return false
end

function GetOppositeFlowDirection(dir)
	local numTypes = FlowDirectionTypes.NUM_FLOWDIRECTION_TYPES;
	return ((dir + 3) % numTypes);
end

function IsEdgeRiver(self, edge)
	return (edge == DirectionTypes.DIRECTION_NORTHEAST 	and self:IsSWOfRiver()) 
		or (edge == DirectionTypes.DIRECTION_EAST 		and self:IsWOfRiver())
		or (edge == DirectionTypes.DIRECTION_SOUTHEAST 	and self:IsNWOfRiver())
		or (edge == DirectionTypes.DIRECTION_SOUTHWEST 	and self:IsNEOfRiver())
		or (edge == DirectionTypes.DIRECTION_WEST	 	and self:IsEOfRiver())
		or (edge == DirectionTypes.DIRECTION_NORTHWEST 	and self:IsSEOfRiver())
end

function GetNextClockRiverPlot(self, edge)
	local DEBUG_PLOT_SCRIPT			= false
	local nextPlotEdge 	= (edge + 3 + 1) % 6
	local nextPlot		= Map.GetAdjacentPlot(self:GetX(), self:GetY(), edge)
	if nextPlot then
		Dprint( DEBUG_PLOT_SCRIPT, "- Testing : ", nextPlot:GetX(), nextPlot:GetY(), 				" river edge  = ", DirectionString[nextPlotEdge]); 		
		if nextPlot:IsEdgeRiver(nextPlotEdge) then return nextPlot, nextPlotEdge end
	end
end

function GetNextCounterClockRiverPlot(self, edge)
	local DEBUG_PLOT_SCRIPT			= false
	local nextPlotEdge 	= (edge + 3 - 1) % 6
	local nextPlot		= Map.GetAdjacentPlot(self:GetX(), self:GetY(), edge)
	if nextPlot then
		Dprint( DEBUG_PLOT_SCRIPT, "- Testing : ", nextPlot:GetX(), nextPlot:GetY(), 				" river edge  = ", DirectionString[nextPlotEdge]); 	
		if nextPlot:IsEdgeRiver(nextPlotEdge) then return nextPlot, nextPlotEdge end
	end
end

function plotToNode(plot, edge)
	return tostring(plot:GetIndex()) .."," .. tostring(edge)
end

function nodeToPlot(node)
	local pos = string.find(node, ",")
	local plotIndex = tonumber(string.sub(node, 1 , pos -1))
	return Map.GetPlotByIndex(plotIndex)
end

function nodeToPlotEdge(node)
	local pos  = string.find(node, ",")
	local plotIndex = tonumber(string.sub(node, 1 , pos -1))
	local edge = tonumber(string.sub(node, pos +1))
	return GCO.GetPlotByIndex(plotIndex), edge
end

function GetRiverIdForNode(plot, edge)
	local node = plotToNode(plot, edge)
	if not RiverMap[node] then GCO.Error("River Map entry is nil for node#"..tostring(node).." in direction ".. tostring(DirectionString[edge]) .." for plot"..string.format("(%i, %i)", plot:GetX(), plot:GetY())) end
	return RiverMap[node]
end

function IsPlotSameRiver(iPlot, iOtherPlot)
	if PlotRivers[iPlot] and PlotRivers[iOtherPlot] then
		local OtherRivers = PlotRivers[iOtherPlot]
		for riverID, _ in pairs(PlotRivers[iPlot]) do
			if OtherRivers[riverID] then
				return true
			end
		end
	end
	return false
end 

function GetRiverPath(self, destPlot, iPlayer)
	--local bFound 	= false
	local bestPath	= nil
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		--if not bFound and self:IsEdgeRiver(direction) then
		if self:IsEdgeRiver(direction) then
			local newPath = self:GetRiverPathFromEdge(direction, destPlot, iPlayer)
			if newPath then 
				--bFound = true
				if bestPath then
					if #newPath < #bestPath then
						bestPath = newPath
					end
				else
					bestPath = newPath
				end
			end
		end
	end
	return bestPath
end

function GetRiverPathFromEdge(self, edge, destPlot, iPlayer) -- Will check visibility if iPlayer is not nil
	local DEBUG_PLOT_SCRIPT	= false

	if not self:IsRiver() or not destPlot:IsRiver() then return end	
	
	local pPlayerVis	= iPlayer and PlayersVisibility[iPlayer] or nil
	
	local startPlot	= self
	local closedSet = {}
	local openSet	= {}
	local comeFrom 	= {}
	local gScore	= {}
	local fScore	= {}
	
	local startNode	= plotToNode(startPlot, edge)
	
	Dprint( DEBUG_PLOT_SCRIPT, "CHECK FOR RIVER PATH BETWEEN : ", startPlot:GetX(), startPlot:GetY(), " edge direction = ", DirectionString[edge] ," and ", destPlot:GetX(), destPlot:GetY(), " distance = ", Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), destPlot:GetX(), destPlot:GetY()) )
	
	local function GetPath(currentNode)
		local path 		= {}
		local seen 		= {}
		local current 	= currentNode
		local count 	= 0
		while true do
			local prev = comeFrom[current]
			if prev == nil then break end
			local plot = nodeToPlot(current)
			local plotIndex = plot:GetIndex()
			-- filter the plots that are referenced in consecutive nodes as we are following the edges
			-- but if a path goes through 5 of the 6 edges, we add it twice for displaying the u-turn 
			if plot ~= prevPlot or count > 2 then 
				Dprint( DEBUG_PLOT_SCRIPT, "Adding to path : ", plot:GetX(), plot:GetY())
				table.insert(path, 1, plotIndex)
				prevPlot = plot
				count = 0
			else
				count = count + 1 
			end
			current = prev
		 end
		Dprint( DEBUG_PLOT_SCRIPT, "Adding Starting plot to path : ", startPlot:GetX(), startPlot:GetY())
		table.insert(path, 1, startPlot:GetIndex())
		return path
	end
	
	gScore[startNode]	= 0
	fScore[startNode]	= Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), destPlot:GetX(), destPlot:GetY())
	
	local currentNode = startNode
	while currentNode do --and nodeToPlot(currentNode) ~= destPlot do
	
		local currentPlot 		= nodeToPlot(currentNode)
		closedSet[currentNode] 	= true
		
		if currentPlot == destPlot then
			Dprint( DEBUG_PLOT_SCRIPT, "Found a path, returning...")
			return GetPath(currentNode)
		end
		
		local neighbors = GetRiverNeighbors(currentNode, pPlayerVis)
		for i, data in ipairs(neighbors) do
			local node = plotToNode(data.Plot, data.Edge)
			if not closedSet[node] then
				if gScore[node] == nil then
					local nodeDistance 		= Map.GetPlotDistance(data.Plot:GetX(), data.Plot:GetY(), currentPlot:GetX(), currentPlot:GetY())
					
					if data.Plot:IsRiverCrossingToPlot(currentPlot) then nodeDistance = nodeDistance + 0.15 end
					local destDistance		= Map.GetPlotDistance(data.Plot:GetX(), data.Plot:GetY(), destPlot:GetX(), destPlot:GetY())
					local tentative_gscore 	= (gScore[currentNode] or math.huge) + nodeDistance
				
					table.insert (openSet, {Node = node, Score = tentative_gscore + destDistance})

					if tentative_gscore < (gScore[node] or math.huge) then
						local plot, edge = nodeToPlotEdge(node)
						Dprint( DEBUG_PLOT_SCRIPT, "New best : ", plot:GetX(), plot:GetY(), " edge direction = ", DirectionString[edge])
						comeFrom[node] = currentNode
						gScore[node] = tentative_gscore
						fScore[node] = tentative_gscore + destDistance
					end
				end				
			end		
		end
		table.sort(openSet, function(a, b) return a.Score > b.Score; end)
		local data = table.remove(openSet)
		if data then
			local plot, edge = nodeToPlotEdge(data.Node)
			Dprint( DEBUG_PLOT_SCRIPT, "Next to test : ", plot:GetX(), plot:GetY(), " edge direction = ", DirectionString[edge], data.Node, data.Score)
			currentNode = data.Node 
		else
			currentNode = nil
		end
	end
	Dprint( DEBUG_PLOT_SCRIPT, "failed to find a path")
end

function GetRiverNeighbors(node, pPlayerVis)

	local function IsVisible(plot)
		return pPlayerVis == nil or pPlayerVis:IsRevealed(plot:GetX(), plot:GetY())
	end
	
	Dprint( DEBUG_PLOT_SCRIPT, "Get neighbors :")
	local neighbors 				= {}
	local plot, edge 				= nodeToPlotEdge(node)
	local oppositeEdge				= (edge + 3) % 6
	local oppositePlot				= Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), edge)
	local nextEdge 					= (edge + 1) % 6
	local prevEdge 					= (edge - 1) % 6
	
	-- Check next edge, same plot
	Dprint( DEBUG_PLOT_SCRIPT, "- Testing : ", plot:GetX(), plot:GetY(), " river edge  = ", DirectionString[nextEdge])
	if plot:IsEdgeRiver(nextEdge) then
		Dprint( DEBUG_PLOT_SCRIPT, "- Adding : ", plot:GetX(), plot:GetY(), " river edge  = ", DirectionString[nextEdge])
		table.insert( neighbors, { Plot = plot, Edge = nextEdge } ) 
	end

	-- Check previous edge, same plot
	Dprint( DEBUG_PLOT_SCRIPT, "- Testing : ", plot:GetX(), plot:GetY(), " river edge  = ", DirectionString[prevEdge])
	if plot:IsEdgeRiver(prevEdge) then
		Dprint( DEBUG_PLOT_SCRIPT, "- Adding : ", plot:GetX(), plot:GetY(), " river edge  = ", DirectionString[prevEdge])
		table.insert( neighbors, { Plot = plot, Edge = prevEdge } ) 
	end

	-- Add Opposite plot, same edge
	--Dprint( DEBUG_PLOT_SCRIPT, "- Testing : ", oppositePlot:GetX(), oppositePlot:GetY(), " river edge  = ", DirectionString[oppositeEdge])
	--if oppositePlot:IsEdgeRiver(oppositeEdge) then
	if oppositePlot and (IsVisible(oppositePlot) or IsVisible(plot)) then
		Dprint( DEBUG_PLOT_SCRIPT, "- Adding : ", oppositePlot:GetX(), oppositePlot:GetY(), " river edge  = ", DirectionString[oppositeEdge])
		table.insert( neighbors, { Plot = oppositePlot, 	Edge = oppositeEdge } )
	end
	
	-- Test diverging edge on next plot (clock direction)
	local clockPlot, clockEdge		= plot:GetNextClockRiverPlot(nextEdge)
	if clockPlot and (IsVisible(clockPlot) or IsVisible(plot)) then
		Dprint( DEBUG_PLOT_SCRIPT, "- Adding : ", clockPlot:GetX(), clockPlot:GetY(), " river edge  = ", DirectionString[clockEdge])
		table.insert(neighbors, { Plot = clockPlot, Edge = clockEdge }	)
	end
	
	-- Test diverging edge on previous plot (counter-clock direction)
	local counterPlot, counterEdge	= plot:GetNextCounterClockRiverPlot(prevEdge)
	if counterPlot and (IsVisible(counterPlot) or IsVisible(plot)) then 
		Dprint( DEBUG_PLOT_SCRIPT, "- Adding : ", counterPlot:GetX(), counterPlot:GetY(), " river edge  = ", DirectionString[counterEdge])
		table.insert(neighbors, { Plot = counterPlot, 	Edge = counterEdge }) 
	end
	
	return neighbors
end

function SetRiverIDs()

	local DEBUG_PLOT_SCRIPT = "debug"
	
	Dprint( DEBUG_PLOT_SCRIPT, "Set River IDS...")

	local riverID 	= 0

	function MarkRiver(node)
		local plot, edge 	= nodeToPlotEdge(node)
		local plotID		= plot:GetIndex()
		RiverMap[node] 		= riverID
		PlotRivers[plotID]	= PlotRivers[plotID] or {}
		
		PlotRivers[plotID][riverID] = true
		
		for _, row in ipairs(GetRiverNeighbors(node)) do
			local nextNode	= plotToNode(row.Plot, row.Edge)
			if not RiverMap[nextNode] then MarkRiver(nextNode) end
		end
	end
	
	-- mark all rivers
	local iW, iH = Map.GetGridSize()
	for x = 0, iW - 1, 1 do
		for y = 0, iH - 1, 1 do
			local pPlot = Map.GetPlot(x,y)
			if pPlot:IsWOfRiver() then
				local node = plotToNode(pPlot, DirectionTypes.DIRECTION_EAST)
				if not RiverMap[node] then
					MarkRiver(node)
					riverID = riverID  + 1
				end
			end
			if pPlot:IsNWOfRiver() then
				local node = plotToNode(pPlot, DirectionTypes.DIRECTION_SOUTHEAST)
				if not RiverMap[node] then
					MarkRiver(node)
					riverID = riverID  + 1
				end
			end
			if pPlot:IsNEOfRiver() then
				local node = plotToNode(pPlot, DirectionTypes.DIRECTION_SOUTHWEST)
				if not RiverMap[node] then
					MarkRiver(node)
					riverID = riverID  + 1
				end
			end
		end
	end
	
	Dprint( DEBUG_PLOT_SCRIPT, "- Added ID to "..tostring(riverID).." rivers")
end 

-----------------------------------------------------------------------------------------
-- Pathfinder Functions
-----------------------------------------------------------------------------------------

function GetRoadPath(plot, destPlot, sRoute, maxRange, iPlayer, bAllowHiddenRoute)

	local routes = {"Land", "Road", "Railroad", "Coastal", "Ocean", "Submarine", "AnyLand"}

	-- Is the plot passable for this route type ...
	local function isPassable(pPlot, sRoute)
	  bPassable = true

		-- ... due to terrain, eg those covered in ice
		if (pPlot:GetFeatureType() == g_FEATURE_ICE) then
			if sRoute ~= routes[6] then
				bPassable = false
			end
		elseif pPlot:IsImpassable() then
			bPassable = false
		end

	  return bPassable
	end
	
	local function GetNeighbors(node, iPlayer, sRoute, startPlot, destPlot, maxRange, bAllowHiddenRoute)

		local neighbors 				= {}
		local plot 						= node
		
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
			
			if (adjacentPlot ~= nil) then
				
				local distanceFromStart = Map.GetPlotDistance(adjacentPlot:GetX(), adjacentPlot:GetY(), startPlot:GetX(), startPlot:GetY())
				if maxRange == nil or distanceFromStart <= maxRange then
				
					local distanceFromDest	= Map.GetPlotDistance(adjacentPlot:GetX(), adjacentPlot:GetY(), destPlot:GetX(), destPlot:GetY())				
					if maxRange == nil or distanceFromDest <= maxRange then
				
						local IsPlotRevealed 	= bAllowHiddenRoute
						local pPlayer 			= Players[iPlayer]
						if pPlayer then
							local pPlayerVis = PlayersVisibility[pPlayer:GetID()]
							if (pPlayerVis ~= nil) then
								if (pPlayerVis:IsRevealed(adjacentPlot:GetX(), adjacentPlot:GetY())) then -- IsVisible
								  IsPlotRevealed = true
								end
							end
						end
					
						if (pPlayer == nil or IsPlotRevealed) then
							local bAdd = false

							-- Be careful of order, must check for road before rail, and coastal before ocean
							if (sRoute == routes[7] and not(adjacentPlot:IsWater())) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is any land")
							  bAdd = true
							elseif (sRoute == routes[1] and not( adjacentPlot:IsImpassable() or adjacentPlot:IsWater())) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is passable land")
							  bAdd = true
							elseif (sRoute == routes[2] and adjacentPlot:GetRouteType() ~= RouteTypes.NONE) then	
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is road")	
							  bAdd = true
							elseif (sRoute == routes[3] and adjacentPlot:GetRouteType() >= 1) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is railroad")
							  bAdd = true
							elseif (sRoute == routes[4] and adjacentPlot:GetTerrainType() == TERRAIN_COAST) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Coast")
							  bAdd = true
							elseif (sRoute == routes[5] and adjacentPlot:IsWater()) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Water")
							  bAdd = true
							elseif (sRoute == routes[6] and adjacentPlot:IsWater()) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Water")
							  bAdd = true
							end

							-- Special case for water, a city on the coast counts as water
							if (not bAdd and (sRoute == routes[4] or sRoute == routes[5] or sRoute == routes[6])) then
							  bAdd = adjacentPlot:IsCity()
							end

							-- Check for impassable and blockaded tiles
							bAdd = bAdd and isPassable(adjacentPlot, sRoute) --and not isBlockaded(adjacentPlot, pPlayer, fBlockaded, pPlot)

							if (bAdd) then
								table.insert( neighbors, { Plot = adjacentPlot } )
							end
						end
					end
				end
			end
		end
		
		return neighbors
	end

	local startPlot	= plot
	local closedSet = {}
	local openSet	= {}
	local comeFrom 	= {}
	local gScore	= {}
	local fScore	= {}
	
	local startNode	= startPlot
	local bestCost	= 0.10
	
	local adjancentRouteFactor	= 5
	
	local function GetPath(currentNode)
		local path 		= {}
		local seen 		= {}
		local current 	= currentNode
		local count 	= 0
		while true do
			local prev = comeFrom[current]
			if prev == nil then break end
			local plot 		= current
			local plotIndex = plot:GetIndex()
			table.insert(path, 1, plotIndex)
			current = prev
		 end
		table.insert(path, 1, startPlot:GetIndex())
		return path
	end
	
	gScore[startNode]	= 0
	fScore[startNode]	= Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), destPlot:GetX(), destPlot:GetY())
	
	local currentNode = startNode
	while currentNode do
	
		local currentPlot 		= currentNode
		closedSet[currentNode] 	= true
		
		if currentPlot == destPlot then
			return GetPath(currentNode)
		end
		
		local neighbors = GetNeighbors(currentNode, iPlayer, sRoute, startPlot, destPlot, maxRange, bAllowHiddenRoute)
		for i, data in ipairs(neighbors) do
			local node = data.Plot
			if not closedSet[node] then
				if gScore[node] == nil then
					local nodeDistance = node:GetMovementCost() --1 --Map.GetPlotDistance(data.Plot:GetX(), data.Plot:GetY(), currentPlot:GetX(), currentPlot:GetY())

					if node:IsRiverCrossingToPlot(currentPlot) then nodeDistance = nodeDistance + 1 end
					if node:GetRouteType() ~= -1 then
						nodeDistance = nodeDistance * bestCost  -- to do : real cost
					else
						-- try to prevent spaghetti routes by avoiding adjacency for new routes
						local numAdjacentRoutes		= 0
						for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
							local adjacentPlot = Map.GetAdjacentPlot(node:GetX(), node:GetY(), direction);
							if adjacentPlot and adjacentPlot ~= currentPlot and adjacentPlot:GetRouteType() ~= -1 then
								numAdjacentRoutes = numAdjacentRoutes + 1
							end
						end
						nodeDistance = nodeDistance + (numAdjacentRoutes * adjancentRouteFactor)
					end
					
					local destDistance		= Map.GetPlotDistance(node:GetX(), node:GetY(), destPlot:GetX(), destPlot:GetY()) * bestCost
					local tentative_gscore 	= (gScore[currentNode] or math.huge) + nodeDistance
				
					table.insert (openSet, {Node = node, Score = tentative_gscore + destDistance})

					if tentative_gscore < (gScore[node] or math.huge) then
						local plot = node
						comeFrom[node] = currentNode
						gScore[node] = tentative_gscore
						fScore[node] = tentative_gscore + destDistance
					end
				end				
			end		
		end
		table.sort(openSet, function(a, b) return a.Score > b.Score; end)
		local data = table.remove(openSet)
		if data then
			local plot = data.Node
			currentNode = data.Node 
		else
			currentNode = nil
		end
	end
	
end

function GetPathToPlot(self, destPlot, pPlayer, sRoute, fBlockaded, maxRange)
	local DEBUG_PLOT_SCRIPT			= false	
	--if sRoute == "Coastal" then DEBUG_PLOT_SCRIPT	= "debug" end
	
	local routes = {"Land", "Road", "Railroad", "Coastal", "Ocean", "Submarine"}

	-- Is the plot passable for this route type ...
	local function isPassable(pPlot, sRoute)
	  bPassable = true

	  -- ... due to terrain, eg those covered in ice
	  if (pPlot:GetFeatureType() == FEATURE_ICE and sRoute ~= routes[6]) then
		bPassable = false
	  end

	  return bPassable
	end

	-- Is the plot blockaded for this player ...
	local function isBlockaded(pDestPlot, pPlayer, fBlockaded, pOriginPlot)
	  bBlockaded = false

	  if (fBlockaded ~= nil) then
		bBlockaded = fBlockaded(pDestPlot, pPlayer, pOriginPlot)
	  end

	  return bBlockaded
	end
	
	local function GetNeighbors(node, pPlayer, sRoute, fBlockaded, startPlot, destPlot, maxRange)
		local DEBUG_PLOT_SCRIPT			= false
		--if sRoute == "Coastal" then DEBUG_PLOT_SCRIPT	= "debug" end
		--Dprint( DEBUG_PLOT_SCRIPT, "Get neighbors :")
		local neighbors 				= {}
		local plot 						= node
		
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);		
			
			--GCO.Incremente("GetPathToPlot"..sRoute)
			
			if (adjacentPlot ~= nil) then
				--Dprint( DEBUG_PLOT_SCRIPT, "- test plot at ", adjacentPlot:GetX(), adjacentPlot:GetY() ,DirectionString[direction])
				
				local distanceFromStart = Map.GetPlotDistance(adjacentPlot:GetX(), adjacentPlot:GetY(), startPlot:GetX(), startPlot:GetY())
				if maxRange == nil or distanceFromStart <= maxRange then
				
					local distanceFromDest	= Map.GetPlotDistance(adjacentPlot:GetX(), adjacentPlot:GetY(), destPlot:GetX(), destPlot:GetY())				
					if maxRange == nil or distanceFromDest <= maxRange then
				
						local IsPlotRevealed = false
						if pPlayer then
							local pPlayerVis = PlayersVisibility[pPlayer:GetID()]
							if (pPlayerVis ~= nil) then
								if (pPlayerVis:IsRevealed(adjacentPlot:GetX(), adjacentPlot:GetY())) then -- IsVisible
								  IsPlotRevealed = true
								end
							end
						end
						--Dprint( DEBUG_PLOT_SCRIPT, "-  IsPlotRevealed = ", IsPlotRevealed)
					
						if (pPlayer == nil or IsPlotRevealed) then
							local bAdd = false

							-- Be careful of order, must check for road before rail, and coastal before ocean
							if (sRoute == routes[1] and not( adjacentPlot:IsImpassable() or adjacentPlot:IsWater())) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is passable land")
							  bAdd = true
							elseif (sRoute == routes[2] and adjacentPlot:GetRouteType() ~= RouteTypes.NONE) then	
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is road")	
							  bAdd = true
							elseif (sRoute == routes[3] and adjacentPlot:GetRouteType() >= 1) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is railroad")
							  bAdd = true
							elseif (sRoute == routes[4] and adjacentPlot:GetTerrainType() == TERRAIN_COAST) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Coast")
							  bAdd = true
							elseif (sRoute == routes[5] and adjacentPlot:IsWater()) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Water")
							  bAdd = true
							elseif (sRoute == routes[6] and adjacentPlot:IsWater()) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Water")
							  bAdd = true
							end

							-- Special case for water, a city on the coast counts as water
							if (not bAdd and (sRoute == routes[4] or sRoute == routes[5] or sRoute == routes[6])) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  check city for water route : adjacentPlot:IsCity() = ", adjacentPlot:IsCity())
							  bAdd = adjacentPlot:IsCity()
							end

							-- Check for impassable and blockaded tiles
							bAdd = bAdd and isPassable(adjacentPlot, sRoute) and not isBlockaded(adjacentPlot, pPlayer, fBlockaded, plot)

							--Dprint( DEBUG_PLOT_SCRIPT, "-  bAdd = ", bAdd)
							if (bAdd) then
								table.insert( neighbors, { Plot = adjacentPlot } )
							end
						end
					end
				end
			end
		end
		
		return neighbors
	end

	local startPlot	= self
	local closedSet = {}
	local openSet	= {}
	local comeFrom 	= {}
	local gScore	= {}
	local fScore	= {}
	
	local startNode	= startPlot
	
	--Dprint( DEBUG_PLOT_SCRIPT, "CHECK FOR PATH BETWEEN : ", startPlot:GetX(), startPlot:GetY(), " and ", destPlot:GetX(), destPlot:GetY(), " distance = ", Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), destPlot:GetX(), destPlot:GetY()) )
	
	local function GetPath(currentNode)
		local path 		= {}
		local seen 		= {}
		local current 	= currentNode
		local count 	= 0
		while true do
			local prev = comeFrom[current]
			if prev == nil then break end
			local plot = current
			local plotIndex = plot:GetIndex()
			--Dprint( DEBUG_PLOT_SCRIPT, "Adding to path : ", plot:GetX(), plot:GetY())
			table.insert(path, 1, plotIndex)
			current = prev
		 end
		--Dprint( DEBUG_PLOT_SCRIPT, "Adding Starting plot to path : ", startPlot:GetX(), startPlot:GetY())
		table.insert(path, 1, startPlot:GetIndex())
		return path
	end
	
	gScore[startNode]	= 0
	fScore[startNode]	= Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), destPlot:GetX(), destPlot:GetY())
	
	local currentNode = startNode
	while currentNode do
	
		local currentPlot 		= currentNode
		closedSet[currentNode] 	= true
		
		if currentPlot == destPlot then
			--Dprint( DEBUG_PLOT_SCRIPT, "Found a path, returning...")
			return GetPath(currentNode)
		end
		
		local neighbors = GetNeighbors(currentNode, pPlayer, sRoute, fBlockaded, startPlot, destPlot, maxRange)
		for i, data in ipairs(neighbors) do
			local node = data.Plot
			if not closedSet[node] then
				if gScore[node] == nil then
					local nodeDistance = 1 --Map.GetPlotDistance(data.Plot:GetX(), data.Plot:GetY(), currentPlot:GetX(), currentPlot:GetY())

					--if data.Plot:IsRiverCrossingToPlot(currentPlot) then nodeDistance = nodeDistance + 0.15 end
					local destDistance		= Map.GetPlotDistance(data.Plot:GetX(), data.Plot:GetY(), destPlot:GetX(), destPlot:GetY())
					local tentative_gscore 	= (gScore[currentNode] or math.huge) + nodeDistance
				
					table.insert (openSet, {Node = node, Score = tentative_gscore + destDistance})

					if tentative_gscore < (gScore[node] or math.huge) then
						local plot = node
						--Dprint( DEBUG_PLOT_SCRIPT, "New best : ", plot:GetX(), plot:GetY())
						comeFrom[node] = currentNode
						gScore[node] = tentative_gscore
						fScore[node] = tentative_gscore + destDistance
					end
				end				
			end		
		end
		table.sort(openSet, function(a, b) return a.Score > b.Score; end)
		local data = table.remove(openSet)
		if data then
			local plot = data.Node
			--Dprint( DEBUG_PLOT_SCRIPT, "Next to test : ", plot:GetX(), plot:GetY(), data.Node, data.Score)
			currentNode = data.Node 
		else
			currentNode = nil
		end
	end
	--Dprint( DEBUG_PLOT_SCRIPT, "failed to find a path")
end

function GetSupplyPath(plot, destPlot, iPlayer, maxRange, fBlockaded, bAllowCoast, bAllowOcean, bAllowHiddenRoute)

	local pPlayer		= iPlayer and Players[iPlayer] or nil
	local pPlayerVis	= iPlayer and PlayersVisibility[iPlayer] or nil

	local startPlot	= plot
	local closedSet = {}
	local openSet	= {}
	local comeFrom 	= {}
	local gScore	= {}
	local fScore	= {}
	local rivers	= {}
	
	local startNode	= startPlot
	local roadCost	= 0.30 -- try to keep it so (roadCost * riverCrossing < 1)
	local riverCost	= 0.15
	local waterCost	= 0.10
	local bestCost	= math.min(roadCost, riverCost, waterCost)

	local function isPassable(pPlot)
		return not pPlot:IsImpassable()
	end
	
	-- Is the plot blockaded for this player ...
	local function isBlockaded(pDestPlot, pOriginPlot)
		bBlockaded = false

		if (fBlockaded ~= nil and pPlayer ~= nil) then
			bBlockaded = fBlockaded(pDestPlot, pPlayer, pOriginPlot)
		end

		return bBlockaded
	end
	
	local function GetNeighbors(node)

		local neighbors = {}
		local plot 		= node
		
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
			
			if (adjacentPlot ~= nil) then
				
				local distanceFromStart = Map.GetPlotDistance(adjacentPlot:GetX(), adjacentPlot:GetY(), startPlot:GetX(), startPlot:GetY())
				if maxRange == nil or distanceFromStart <= maxRange then
				
					local distanceFromDest	= Map.GetPlotDistance(adjacentPlot:GetX(), adjacentPlot:GetY(), destPlot:GetX(), destPlot:GetY())				
					if maxRange == nil or distanceFromDest <= maxRange then
				
						local IsPlotRevealed 	= bAllowHiddenRoute
						if (pPlayerVis ~= nil) then
							if (pPlayerVis:IsRevealed(adjacentPlot:GetX(), adjacentPlot:GetY())) then -- IsVisible
								IsPlotRevealed = true
							end
						end
					
						if (pPlayer == nil or IsPlotRevealed) then
							local bAdd = false

							-- Be careful of order, must check for coastal before ocean
							if not( adjacentPlot:IsImpassable() or adjacentPlot:IsWater()) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is passable land")
							  bAdd = true
							elseif (bAllowCoast and adjacentPlot:GetTerrainType() == TERRAIN_COAST) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Coast")
							  bAdd = true
							elseif (bAllowOcean and adjacentPlot:IsWater()) then
							  --Dprint( DEBUG_PLOT_SCRIPT, "-  plot is Water")
							  bAdd = true
							end

							-- Check for impassable and blockaded tiles
							bAdd = bAdd and isPassable(adjacentPlot) and not isBlockaded(adjacentPlot, plot)

							if (bAdd) then
								table.insert( neighbors, { Plot = adjacentPlot } )
							end
						end
					end
				end
			end
		end
		
		return neighbors
	end
	
	local function GetPath(currentNode)
		local path 		= {}
		local seen 		= {}
		local current 	= currentNode
		local score 	= gScore[current] or 0 --that's the total score of the path
		while true do
			local prev = comeFrom[current]
			if prev == nil then break end
			local plot 		= current
			local plotIndex = plot:GetIndex()
			table.insert(path, 1, plotIndex)
			current = prev
		 end
		table.insert(path, 1, startPlot:GetIndex())
		return path, score
	end
	
	gScore[startNode]	= 0
	fScore[startNode]	= Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), destPlot:GetX(), destPlot:GetY())
	
	local currentNode = startNode
	while currentNode do
	
		local currentPlot 		= currentNode
		closedSet[currentNode] 	= true
		
		if currentPlot == destPlot then
			return GetPath(currentNode)
		end
		
		local neighbors = GetNeighbors(currentNode)
		for i, data in ipairs(neighbors) do
			local node = data.Plot
			if not closedSet[node] then
				if gScore[node] == nil then
				
					local nodeDistance 		= 0
					local bFollowingRiver	= false
					
					rivers[node] = rivers[node] or node:GetRiverPath(destPlot, iPlayer)
					if rivers[node] then
						rivers[currentPlot]	= rivers[currentPlot] or currentPlot:GetRiverPath(destPlot, iPlayer)
						if rivers[currentPlot] then
							local riverPath	= node:GetRiverPath(currentPlot, iPlayer)
							if riverPath and #riverPath <= 2 then -- U-turn count a same plot twice
								bFollowingRiver	= true
							end
						end
					end
					
					-- Order is important
					
					if node:IsRiverCrossingToPlot(currentPlot) then
						nodeDistance = nodeDistance + 3
					end
						
					if bFollowingRiver then
						nodeDistance = nodeDistance > 0 and nodeDistance * riverCost or riverCost
						
					else
						nodeDistance = nodeDistance + node:GetMovementCost()
						
						if node:GetRouteType() ~= -1 then
							nodeDistance = nodeDistance * roadCost  -- to do : separate route type cost
						end
					end
					
					local destDistance		= Map.GetPlotDistance(node:GetX(), node:GetY(), destPlot:GetX(), destPlot:GetY()) * bestCost
					local tentative_gscore 	= (gScore[currentNode] or math.huge) + nodeDistance
				
					table.insert (openSet, {Node = node, Score = tentative_gscore + destDistance})

					if tentative_gscore < (gScore[node] or math.huge) then
						local plot = node
						comeFrom[node] = currentNode
						gScore[node] = tentative_gscore
						fScore[node] = tentative_gscore + destDistance
					end
				end				
			end		
		end
		table.sort(openSet, function(a, b) return a.Score > b.Score; end)
		local data = table.remove(openSet)
		if data then
			local plot = data.Node
			currentNode = data.Node 
		else
			currentNode = nil
		end
	end
	
end


-----------------------------------------------------------------------------------------
-- Goody Huts (Deprecated)
-----------------------------------------------------------------------------------------

local minRange 		= 4
local lastGoodyPlot	= nil

function CanPlaceGoodyAt(plot)

	local improvementID = GoodyHutID
	local NO_TEAM = -1

	if (plot:IsWater()) then
		return false;
	end

	if (not ImprovementBuilder.CanHaveImprovement(plot, improvementID, NO_TEAM)) then
		return false;
	end
	

	if (plot:GetImprovementType() ~= NO_IMPROVEMENT) then
		return false;
	end

	if (plot:GetResourceType() ~= NO_RESOURCE) then
		return false;
	end

	if (plot:IsImpassable()) then
		return false;
	end

	if (plot:IsMountain()) then
		return false;
	end
	
	if lastGoodyPlot and Map.GetPlotDistance(lastGoodyPlot:GetX(), lastGoodyPlot:GetY(), plot:GetX(), plot:GetY()) < (minRange * 3) then
		return false
	end

	-- Check for being too close from somethings.
	local uniqueRange = minRange
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -uniqueRange, uniqueRange - 1, 1 do
		for dy = -uniqueRange, uniqueRange - 1, 1 do
			local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, uniqueRange);
			if(otherPlot) then
				if (otherPlot:GetImprovementType() == improvementID) then
					return false;
				end
				if otherPlot:IsOwned() then
					return false
				end
				local aUnits = Units.GetUnitsInPlot(otherPlot);
				for i, pUnit in ipairs(aUnits) do
					if not Players[pUnit:GetOwner()]:IsBarbarian() then
						return false
					end
				end
			end
		end
	end
	return true;
end

function AddGoody()
	local NO_PLAYER = -1;
	Dprint( DEBUG_PLOT_SCRIPT, "-------------------------------");
	Dprint( DEBUG_PLOT_SCRIPT, "-- Adding New Goody");
	local iW, iH 	= Map.GetGridSize()
	local plotList 	= {}
	for x = 0, iW - 1 do
		for y = 0, iH - 1 do
			local i = y * iW + x;
			local pPlot = GetPlotByIndex(i);
			local bGoody = CanPlaceGoodyAt(pPlot);
			if (bGoody) then			
				table.insert(plotList, pPlot)
			end
		end
	end
	local numPossiblePlots = #plotList
	local randomPlot = plotList[TerrainBuilder.GetRandomNumber(numPossiblePlots, "Add New Goody")+1]
	if randomPlot then
		ImprovementBuilder.SetImprovementType(randomPlot, GoodyHutID, NO_PLAYER);
		Dprint( DEBUG_PLOT_SCRIPT, "-- found new position at ", randomPlot:GetX(), randomPlot:GetY());
		--randomPlot:AddPopulationForTribalVillage()
	else
		Dprint( DEBUG_PLOT_SCRIPT, "-- can't found new position for goody");
	end
	Dprint( DEBUG_PLOT_SCRIPT, "-------------------------------");
end

function OnImprovementActivated(locationX, locationY, unitOwner, unitID, improvementType, improvementOwner,	activationType, activationValue)
	--print(locationX, locationY, unitOwner, unitID, improvementType, improvementOwner,	activationType, activationValue)
	if( GameInfo.Improvements[improvementType].Goody ) then -- create a new goody hut somewhere else
		lastGoodyPlot = Map.GetPlot(locationX, locationY)
		if GCO.GetGameEra() < 5 then
			AddGoody()
		end
	end
end
Events.ImprovementActivated.Add( OnImprovementActivated )

function OnImprovementAddedToMap(locX, locY, eImprovementType, eOwner)
	if GCO.IsTribeImprovement(eImprovementType) then --if( GameInfo.Improvements[eImprovementType].BarbarianCamp ) then
		local pPlot = GetPlot(locX, locY)
		--pPlot:AddPopulationForTribalVillage()
	end
end
Events.ImprovementAddedToMap.Add(			OnImprovementAddedToMap );

-----------------------------------------------------------------------------------------
-- Plot Activities
-----------------------------------------------------------------------------------------

---[[
-- << obsolete

-- vegetal resource = activity farmer (crop)
-- wood resource = activity woodcutter
-- games resource = activity hunter
-- mineral/metal resource = activity miner
-- "food" = activity farmer (crop)
-- animal resource = activity farmer (breeder)

-- employment available = pop for plot size at city size

-- GCO.Round(math.pow(size, populationPerSizepower) * 1000)

--local populationPerSizepower = tonumber(GameInfo.GlobalParameters["CITY_POPULATION_PER_SIZE_POWER"].Value) - 1 -- number of worked plots being equal to city size, using (popPerSizePower - 1) for tiles means that the sum of all population on worked tiles at size n will not be > to the total city population at that size 

function GetEmploymentValue(self, num)
	return GCO.Round(math.pow(num, self:GetRuralEmploymentPow()) * self:GetRuralEmploymentFactor())
end

function GetEmploymentSize(self, num)
	return GCO.Round(math.pow( Div(num, self:GetRuralEmploymentFactor()), Div(1, self:GetRuralEmploymentPow())))
end

local resourceActivities = {
	[GameInfo.Resources["RESOURCE_ALUMINUM"].Index]		= "Miners",
	[GameInfo.Resources["RESOURCE_BANANAS"].Index]		= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_CATTLE"].Index]		= "Cattle Farmers",
	[GameInfo.Resources["RESOURCE_CITRUS"].Index]		= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_COAL"].Index]			= "Miners",
	[GameInfo.Resources["RESOURCE_COCOA"].Index]		= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_COFFEE"].Index]		= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_COPPER"].Index]		= "Miners",
	[GameInfo.Resources["RESOURCE_COTTON"].Index]		= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_DEER"].Index]			= "Hunters",
	[GameInfo.Resources["RESOURCE_DIAMONDS"].Index]		= "Miners",
	[GameInfo.Resources["RESOURCE_DYES"].Index]			= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_FURS"].Index]			= "Hunters",
	[GameInfo.Resources["RESOURCE_GYPSUM"].Index]		= "Miners",
	[GameInfo.Resources["RESOURCE_HORSES"].Index]		= "Cattle Farmers",
	[GameInfo.Resources["RESOURCE_INCENSE"].Index]		= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_IRON"].Index]			= "Miners",
	[GameInfo.Resources["RESOURCE_IVORY"].Index]		= "Hunters",
	[GameInfo.Resources["RESOURCE_JADE"].Index]			= "Miners",
	[GameInfo.Resources["RESOURCE_MARBLE"].Index]		= "Miners",
	[GameInfo.Resources["RESOURCE_MERCURY"].Index]		= "Miners",
	--[GameInfo.Resources["RESOURCE_NITER"].Index]		= "Miners",
	[GameInfo.Resources["RESOURCE_OIL"].Index]			= "Miners",
	[GameInfo.Resources["RESOURCE_RICE"].Index]			= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_SALT"].Index]			= "Miners",
	[GameInfo.Resources["RESOURCE_SHEEP"].Index]		= "Cattle Farmers",
	[GameInfo.Resources["RESOURCE_SILK"].Index]			= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_SILVER"].Index]		= "Miners",
	[GameInfo.Resources["RESOURCE_SPICES"].Index]		= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_STONE"].Index]		= "Miners",
	[GameInfo.Resources["RESOURCE_SUGAR"].Index]		= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_TEA"].Index]			= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_TOBACCO"].Index]		= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_TRUFFLES"].Index]		= "Cattle Farmers",
	[GameInfo.Resources["RESOURCE_URANIUM"].Index]		= "Miners",
	[GameInfo.Resources["RESOURCE_WHEAT"].Index]		= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_WINE"].Index]			= "Crop Farmers",
	[GameInfo.Resources["RESOURCE_WOOD"].Index]			= "Wood Cutters",
	[GameInfo.Resources["RESOURCE_PLANTS"].Index]		= "Crop Farmers",

}
function GetAvailableEmployment(self)
	local EmploymentString 		= ""
	local Employment 			= {}
	local availableEmployment	= 0
	local bWorked 				= (self:GetWorkerCount() > 0)
	local bImproved				= (self:GetImprovementType() ~= NO_IMPROVEMENT)
	local bSeaResource 			= (self:IsWater() or self:IsLake())
	local village 				= GCO.GetTribalVillageAt(self:GetIndex())

	if village then
		availableEmployment = 5000 -- to do: remove magic number
	end
	
	local player = Players[self:GetOwner()] or Players[Game.GetLocalPlayer()] -- 
	if player then
	--if bWorked or bImproved or bSeaResource then

		local improvementID = self:GetImprovementType()
		if self:GetResourceCount() > 0 then
			local resourceID 	= self:GetResourceType()
			if player:IsResourceVisible(resourceID) then
				local collected 			= math.min(self:GetResourceCount(), MaxBaseEmployement)
				local bImprovedForResource	= GCO.IsImprovingResource(improvementID, resourceID)
				if bImprovedForResource then
					collected = math.min(collected * BaseImprovementMultiplier, MaxImprovedEmployement)
				end
				if resourceActivities[resourceID] then
					local resourceEmploymentValue				= self:GetEmploymentValue(collected)
					Employment[resourceActivities[resourceID]] 	= (Employment[resourceActivities[resourceID]] or 0) + resourceEmploymentValue
					availableEmployment 						= availableEmployment + resourceEmploymentValue
					--Employment[resourceActivities[resourceID]] 	= (Employment[resourceActivities[resourceID]] or 0) + collected
				end
			end
		elseif not self:IsWater() then  -- I don't like hardcoding, todo: find something else...
			local resourceEmploymentValue	= self:GetEmploymentValue(math.ceil(self:GetPlotActualYield(GameInfo.Yields["YIELD_FOOD"].Index)/2))
			Employment["Crop Farmers"] 		= (Employment["Crop Farmers"] or 0) + resourceEmploymentValue
			availableEmployment 			= availableEmployment + resourceEmploymentValue
		end

		local featureID = self:GetFeatureType()
		if FeatureResources[featureID] then
			for _, data in pairs(FeatureResources[featureID]) do
				for resourceID, value in pairs(data) do
					if player:IsResourceVisible(resourceID) then
						local collected 			= math.min(value, MaxBaseEmployement)
						local bImprovedForResource	= (IsImprovementForFeature[improvementID] and IsImprovementForFeature[improvementID][featureID])
						if bImprovedForResource then
							collected = math.min(collected * BaseImprovementMultiplier, MaxImprovedEmployement)
						end
						if resourceActivities[resourceID] then 
							local resourceEmploymentValue				= self:GetEmploymentValue(collected)
							Employment[resourceActivities[resourceID]] 	= (Employment[resourceActivities[resourceID]] or 0) + resourceEmploymentValue
							availableEmployment 						= availableEmployment + resourceEmploymentValue
							--Employment[resourceActivities[resourceID]] 	= (Employment[resourceActivities[resourceID]] or 0) + collected
						end
					end
				end
			end
		end

		--TerrainResources
		local terrainID = self:GetTerrainType()
		if TerrainResources[terrainID] then
			for _, data in pairs(TerrainResources[terrainID]) do
				for resourceID, value in pairs(data) do
					if player:IsResourceVisible(resourceID) then
						local collected 	= math.min(value, MaxBaseEmployement)
						local resourceCost 	= GCO.GetBaseResourceCost(resourceID)
						local bImprovedForResource	= GCO.IsImprovingResource(improvementID, resourceID)
						if bImprovedForResource then
							collected = math.min(collected * BaseImprovementMultiplier, MaxImprovedEmployement)
						end
						if resourceActivities[resourceID] then
							local resourceEmploymentValue				= self:GetEmploymentValue(collected)
							Employment[resourceActivities[resourceID]] 	= (Employment[resourceActivities[resourceID]] or 0) + resourceEmploymentValue
							availableEmployment 						= availableEmployment + resourceEmploymentValue
							--Employment[resourceActivities[resourceID]] 	= (Employment[resourceActivities[resourceID]] or 0) + collected
						end
					end
				end
			end
		end
	end
	
	--[[
	local EmploymentByActivities = {}
	for activity, num in pairs(Employment) do
		local employments 					= self:GetEmploymentValue(num)
		EmploymentByActivities[activity]	= employments
		availableEmployment 				= availableEmployment + employments
	end
	
	return EmploymentByActivities, availableEmployment
	--]]
	--	local maxEmploymentUrban = GCO.Round(self:GetUrbanPopulation()*Div(employmentSize, self:GetSize()))
	return Employment, availableEmployment
end

-- obsolete >>
--]]

function GetOutputPerYield(self)
	if self:IsWater() then
		return PlotOutputFactor[self:GetEraType()]
	else
		return self:GetSize() * self:GetActivityFactor() * PlotOutputFactor[self:GetEraType()]
	end
end

function GetRuralEmploymentPow(self)
	return PlotEmploymentPow[self:GetEraType()]
end

function GetRuralEmploymentFactor(self)
	return PlotEmploymentFactor[self:GetEraType()]
end

function GetMaxEmployment(self)
	local plotKey = self:GetKey()
	if not _cached[plotKey] then
		self:SetMaxEmployment()
	elseif not _cached[plotKey].MaxEmployment then
		self:SetMaxEmployment()
	end
	return _cached[plotKey].MaxEmployment
end

function SetMaxEmployment(self)
	local plotKey = self:GetKey()
	if not _cached[plotKey] then _cached[plotKey] = {} end
	local _, maxEmployment = self:GetAvailableEmployment()
	_cached[plotKey].MaxEmployment = maxEmployment
end

function GetEmployed(self)
	return math.min(self:GetPopulation(), self:GetMaxEmployment())
end

function GetActivityFactor(self)
	local employmentFromResources 	= self:GetMaxEmployment()
	local employed					= self:GetEmployed()
	if employmentFromResources > employed  then
		return Div(self:GetEmploymentSize(employed), self:GetEmploymentSize(employmentFromResources))
	else
		return 1
	end
end


-----------------------------------------------------------------------------------------
-- Plot Population
-----------------------------------------------------------------------------------------

--[[
	ExposedMembers.GCO.IsCultureGroupAvailableForPlot		= IsCultureGroupAvailableForPlot
	ExposedMembers.GCO.IsCultureGroupAvailableForContinent	= IsCultureGroupAvailableForContinent
	ExposedMembers.GCO.IsCultureGroupAvailableForEthnicity	= IsCultureGroupAvailableForEthnicity
--]]

function GetPlotFertility(self, kParameters)
	-- Calculate the fertility of the plot
	local kParameters				= kParameters or {}
	local iRange 					= kParameters.Range or 3
	local pPlot 					= self
	local plotX 					= pPlot:GetX()
	local plotY 					= pPlot:GetY()
	local iProductionYieldWeight	= kParameters.ProductionYieldWeight or 3
	local iFoodYieldWeight 			= kParameters.FoodYieldWeight or 5
	local iStrategicYieldWeight		= kParameters.StrategicYieldWeight or 2
	local iLuxuriesYieldWeight		= kParameters.LuxuriesYieldWeight or 2
	local iRiverFertility			= kParameters.RiverFertility or 50
	local iFreshWaterFertility		= kParameters.FreshWaterFertility or 50
	local iCoastalLandertility		= kParameters.CoastalLandFertility or 100

	local gridWidth, gridHeight = Map.GetGridSize()
	local gridHeightMinus1 = gridHeight - 1

	local iFertility 	= 0
	local terrainType 	= pPlot:GetTerrainType()
	
	local function GetFertilityFromResource(resourceID, count)
		local iValue = 0
		if GCO.IsResourceFood(resourceID) then
			iValue = iValue + (count*iFoodYieldWeight)
		end
		if (GCO.IsNoTechRequiredResource(resourceID) or GameInfo.Resources[resourceID].ResourceType == "RESOURCE_IRON") -- Assuming knowledge of Iron
			and (GCO.IsResourceEquipmentMaker(resourceID) or GameInfo.Resources[resourceID].ResourceClassType == "RESOURCECLASS_STRATEGIC") then
			iValue = iValue + (count*iStrategicYieldWeight)
		end
		if GCO.IsNoTechRequiredResource(resourceID) and GCO.IsResourceLuxury(resourceID) then
			iValue = iValue + (count*iLuxuriesYieldWeight)
		end
		return iValue
	end
	
	if(GCO.IsTerrainSnow(terrainType) ~= true and pPlot:IsImpassable() ~= true) then
		if pPlot:IsFreshWater() == true then
			iFertility = iFertility + iFreshWaterFertility
			if pPlot:IsRiver() == true then
				iFertility = iFertility + iRiverFertility
			end
		end
		if pPlot:IsCoastalLand() then
			iFertility = iFertility + iCoastalLandertility
		end
	end	
	
	for i, iPlotID in ipairs(GCO.GetPlotsInRange(pPlot, iRange)) do
		local otherPlot = GCO.GetPlotByIndex(iPlotID)

		-- Valid plot?  Also, skip plots along the top and bottom edge
		if(otherPlot) then
			local otherPlotY = otherPlot:GetY();
			if(otherPlotY > 0 and otherPlotY < gridHeightMinus1) then

				local terrainType = otherPlot:GetTerrainType();
				local featureType = otherPlot:GetFeatureType();

				-- Subtract one if there is snow and no resource. Do not count water plots unless there is a resource
				if(GCO.IsTerrainSnow(terrainType) and otherPlot:GetResourceCount() == 0) then
					iFertility = iFertility - 10
				elseif(featureType == GameInfo.Features["FEATURE_ICE"].Index) then
					iFertility = iFertility - 20
				elseif((otherPlot:IsWater() == false) or otherPlot:GetResourceCount() > 0) then
					iFertility = iFertility + (otherPlot:GetYield(GameInfo.Yields["YIELD_PRODUCTION"].Index)*iProductionYieldWeight)
					iFertility = iFertility + (otherPlot:GetYield(GameInfo.Yields["YIELD_FOOD"].Index)*iFoodYieldWeight)
				end
				
				-- Resource
				if otherPlot:GetResourceCount() > 0 then
					local resourceID = otherPlot:GetResourceType()
					iFertility = iFertility + GetFertilityFromResource(resourceID, otherPlot:GetResourceCount())
				end
				
				-- Terrain Resources
				if TerrainResources[terrainID] then
					for _, data in pairs(TerrainResources[terrainID]) do
						for resourceID, value in pairs(data) do
							iFertility = iFertility + GetFertilityFromResource(resourceID, value)
						end
					end
				end
				
				-- Feature Resources
				if FeatureResources[featureID] then
					for _, data in pairs(FeatureResources[featureID]) do
						for resourceID, value in pairs(data) do
							iFertility = iFertility + GetFertilityFromResource(resourceID, value)
						end
					end
				end
			
				-- Lower the Fertility if the plot is impassable
				if(iFertility > 5 and otherPlot:IsImpassable() == true) then
					iFertility = iFertility - 5
				end

				-- Lower the Fertility if the plot has Features
				if(featureType ~= NO_FEATURE) then
					iFertility = iFertility - 2
				end	

			else
				iFertility = iFertility - 5
			end
		else
			iFertility = iFertility - 10
		end
	end 

	return iFertility
end

function GetpossibleCultureGroups(self, bAnyEra, bNoDuplicate)

	local DEBUG_PLOT_SCRIPT = "debug"
		
	local tPossibleCulture 	= {}
	local eraType 			= GameInfo.Eras[GCO.GetGameEra()].EraType
	local sEthnicity 		= self:GetEthnicityByNearestMajor()

	Dprint( DEBUG_PLOT_SCRIPT, "Calling GetpossibleCultureGroups with X, Y, Era, Ethnicity, bAnyEra, bNoDuplicate = ", self:GetX(), self:GetY(), eraType, sEthnicity, bAnyEra, bNoDuplicate)
		
	for row in GameInfo.CultureGroups() do
	
		local sCultureType 	= row.CultureType
		local iCultureID	= row.Index
		local bHasSpawned	= GCO.HasCultureGroupSpawned(iCultureID)
		local bAllowed 		= not (bHasSpawned and bNoDuplicate) 
		if bAllowed and (bAnyEra or (row.EraTypes and string.find(row.EraTypes, eraType))) then
		
			local iPriority = bHasSpawned and 20 or 10
			
			if GCO.IsCultureGroupAvailableForPlot(sCultureType, self) then
				table.insert(tPossibleCulture, {CultureID = iCultureID, Priority = iPriority-10}) -- lower is better
				
			end
			if GCO.IsCultureGroupAvailableForContinent(sCultureType, self:GetContinentType()) then
				table.insert(tPossibleCulture, {CultureID = iCultureID, Priority = iPriority-1})
				
			end
			if GCO.IsCultureGroupAvailableForEthnicity(sCultureType, sEthnicity) then
				table.insert(tPossibleCulture, {CultureID = iCultureID, Priority = iPriority-2})
			end
		end
	end
	
	if #tPossibleCulture == 0 and not bAnyEra then
		Dprint( DEBUG_PLOT_SCRIPT, " - Can't find Culture group, trying again with any eras...")
		bAnyEra = true
		return self:GetpossibleCultureGroups(bAnyEra, bNoDuplicate), bAnyEra
	else
		return tPossibleCulture
	end
end

function GetBestCultureGroup(self, bNoDuplicate)

	local DEBUG_PLOT_SCRIPT = "debug"
	
	local tPossibleCulture = self:GetpossibleCultureGroups(bAnyEra, bNoDuplicate) -- can call with bAnyEra = nil
	
	if #tPossibleCulture > 0 then
		--local randomIndex = TerrainBuilder.GetRandomNumber(#tPossibleCulture, "GetRandomCultureForPlot")
		table.sort(tPossibleCulture, function(a, b) return a.Priority < b.Priority; end)
		local iBestCultureID = tPossibleCulture[1].CultureID
		
		Dprint( DEBUG_PLOT_SCRIPT, " - GetBestCultureGroup returns with priority ", tPossibleCulture[1].Priority, GameInfo.CultureGroups[iBestCultureID].CultureType, self:GetX(), self:GetY(), #tPossibleCulture )
		return iBestCultureID
	end
end

function GetEthnicityByNearestMajor(self)

	--local DEBUG_PLOT_SCRIPT = "debug"
	
	local bestDistance 	= math.huge
	local ethnicity		= nil
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		Dprint( DEBUG_PLOT_SCRIPT, "   - GetEthnicityByNearestMajor, check player#", playerID)
		local pPlayer 		= Players[playerID]
		local startingPlot 	= pPlayer:GetStartingPlot()
		if startingPlot then
			local distance = Map.GetPlotDistance(self:GetX(), self:GetY(), startingPlot:GetX(), startingPlot:GetY())
			Dprint( DEBUG_PLOT_SCRIPT, "     - Distances", distance, bestDistance)
			if distance < bestDistance then
				local CivType	= PlayerConfigurations[playerID]:GetCivilizationTypeName()
				bestDistance 	= distance
				ethnicity		= GameInfo.Civilizations[CivType].Ethnicity
				Dprint( DEBUG_PLOT_SCRIPT, "     - New Ethnicity = ", ethnicity, GameInfo.Civilizations[CivType].CivilizationType)
			end
		end
	end
	return ethnicity
end

function GetRandomCultureForEthnicity(ethnicity)

	local DEBUG_PLOT_SCRIPT = "debug"

	local tPossibleCulture 	= {}
	local eraType 			= GameInfo.Eras[GCO.GetGameEra()].EraType
	local currentYear		= GCO.GetTurnYear(currentTurn)
	for row in GameInfo.CultureGroups() do
		if row.Ethnicity == ethnicity and not GCO.HasCultureGroupSpawned(row.Index) then --CultureRegions[row.CultureType] then
			if (row.EraTypes and string.find(row.EraTypes, eraType)) or (row.StartDate and row.StartDate <= currentYear and (row.EndDate == nil or row.EndDate >= currentYear)) then
				Dprint( DEBUG_PLOT_SCRIPT, "Add Random Culture For Ethnicity ", ethnicity, row.CultureType, row.StartDate, currentYear, row.EndDate, eraType, row.EraTypes)
				table.insert(tPossibleCulture, row.Index)
			else
				Dprint( DEBUG_PLOT_SCRIPT, "Discard Random Culture For Ethnicity ", ethnicity, row.CultureType, row.StartDate, currentYear, row.EndDate, eraType, row.EraTypes )
			end
		end
	end
	if #tPossibleCulture > 0 then
		local randomIndex = TerrainBuilder.GetRandomNumber(#tPossibleCulture, "GetRandomCultureForEthnicity")
		return tPossibleCulture[randomIndex]
	end
end

function AddPopulationForTribalVillage(self, cultureID, bNoDuplicate)

	local DEBUG_PLOT_SCRIPT = "debug"
	
	local population 	= self:GetPopulation()
	local popAdded		= 1000 + (population * 4) -- to do: no magic number
	
	Dprint( DEBUG_PLOT_SCRIPT, " - Add population for Tribal Village at ", self:GetX(), self:GetY(), ", initial pop. = ", population, "cultureID = ", cultureID)
	local bestCultureID		= self:GetHighestCultureID()
	local bestCultureKey 	= tostring(bestCultureID)
	local bUpdated			= false
	if bestCultureKey == INDEPENDENT_CULTURE then

		local cultureID = cultureID or self:GetBestCultureGroup(bNoDuplicate)
		if cultureID then
			local cultIndep	= self:GetCulture(INDEPENDENT_CULTURE)
			self:ChangeCulture(INDEPENDENT_CULTURE, -cultIndep)
			self:ChangeCulture(cultureID, cultIndep+popAdded)
			--self:ChangeLowerClass(popAdded)
			GCO.SetCultureGroupSpawned(cultureID)
			Dprint( DEBUG_PLOT_SCRIPT, "   - Added ", popAdded, ", Culture Type = ", GameInfo.CultureGroups[cultureID].CultureType)
			bUpdated = true
		end
		--[[
		local ethnicity = self:GetEthnicityByNearestMajor()
		if ethnicity then
			local cultureID = GetRandomCultureForEthnicity(ethnicity)
			if cultureID then
				local cultIndep	= self:GetCulture(INDEPENDENT_CULTURE)
				self:ChangeCulture(INDEPENDENT_CULTURE, -cultIndep)
				self:ChangeCulture(cultureID, cultIndep+popAdded)
				self:ChangeLowerClass(popAdded)
				GCO.SetCultureGroupSpawned(cultureID)
				Dprint( DEBUG_PLOT_SCRIPT, "   - Added ", popAdded, ", Culture Type = ", GameInfo.CultureGroups[cultureID].CultureType)
				bUpdated = true
			end
		end
		--]]
	end
	if (not bUpdated) and GameInfo.CultureGroups[bestCultureID] then
		self:ChangeCulture(bestCultureID, popAdded)
		--self:ChangeLowerClass(popAdded)
		Dprint( DEBUG_PLOT_SCRIPT, "   - Added ", popAdded, ", Culture Type = ", GameInfo.CultureGroups[bestCultureID].CultureType)
		bUpdated = true
	end
	if not bUpdated then
		GCO.Warning("Can't find Culture Type for Goody Hut at ", self:GetX(), self:GetY(), bestCultureID)
	end
end


function SetInitialMapPopulation()

	if Game:GetProperty("InitialMapPopulationAdded") == 1 then -- only called once per game
		return
	end
	
	--local DEBUG_PLOT_SCRIPT = "debug"

	Dprint( DEBUG_PLOT_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLOT_SCRIPT, "Initializing Map Population at turn "..tostring(GCO.GetTurnKey()))
	
	local eraFactor 	= math.max(1, GCO.GetGameEra() / 2)
	local currentTurn	= Game.GetCurrentGameTurn()
	local currentYear	= GCO.GetTurnYear(currentTurn)
	
	local iPlotCount = Map.GetPlotCount()
	for i = 0, iPlotCount - 1 do
		local plot = GetPlotByIndex(i)
		if plot:GetPopulation() > 0 then -- double check in case we're reloading a game on the first turn
			return
		end
		if (not plot:IsWater()) then 
			local maxSize		= plot:GetMaxSize()
			local maxPopulation	= GCO.GetPopulationAtSize((maxSize / 4) * eraFactor) 
			local minPopulation	= math.max(1,math.floor(maxPopulation / 8))
			local population	= minPopulation + TerrainBuilder.GetRandomNumber(maxPopulation - minPopulation, "Add population on plot")
			
			Dprint( DEBUG_PLOT_SCRIPT, " - Set " .. Indentation20("population = ".. tostring(population)) .. " at ", plot:GetX(), plot:GetY(), " maxSize = ", maxSize)
			
			--plot:ChangeLowerClass(population)
			
			local plotRegions 	= plot:GetRegions()
			local plotCultures	= {}
			local totalStrength	= 0

			for r, region in pairs(plotRegions) do
				local cultures	= RegionCultures[region]
				if cultures then
					for cultureType, c in pairs(cultures) do
						local cultureRow	= GameInfo.CultureGroups[cultureType]
						if cultureRow and cultureRow.StartDate <= currentYear and (cultureRow.EndDate == nil or cultureRow.EndDate >= currentYear) then -- add Era row here ?
							local strength 	= 10 -- to do : actual calculation based on PeakDate / PeakStrength or StartDate / EndDate
							totalStrength	= totalStrength + strength
							table.insert(plotCultures, { CultureType = cultureType, CultureID = cultureRow.Index, Strength = strength})
							Dprint( DEBUG_PLOT_SCRIPT, "    - Found culture " .. Indentation(cultureType, 25) .. " in region " .. Indentation(region,25), cultureRow.StartDate, cultureRow.EndDate)
						end
					end
				end
				--RegionCultures[row.StartingRegion][row.CultureType]
			end
			
			local numCulture = #plotCultures
			if numCulture > 0 then
				local cultureLeft 	= population
				local perCulture	= Div(population, totalStrength)
				for _, row in ipairs(plotCultures) do
					local value = math.floor(perCulture * row.Strength)
					Dprint( DEBUG_PLOT_SCRIPT, "       - Set culture = " .. tostring(value).."/"..tostring(population))
					plot:SetCulture(row.CultureID, value )
					cultureLeft = GCO.Round(cultureLeft - value)
					GCO.SetCultureGroupSpawned(row.CultureID)
				end
				if cultureLeft > 0 then
					Dprint( DEBUG_PLOT_SCRIPT, "       - Set culture = " .. tostring(cultureLeft).."/"..tostring(population))
					plot:SetCulture(INDEPENDENT_CULTURE, cultureLeft)
				end
			else
				plot:SetCulture(INDEPENDENT_CULTURE, population )
			end
		end
	end
		
	for i = 0, iPlotCount - 1 do
		local plot = GetPlotByIndex(i)
		if plot:GetImprovementType() == GoodyHutID then
			--plot:AddPopulationForTribalVillage(plot)
		end	
	end
	
	-- Simulate a few turns of migration
	-- (moved to InitializeTribesOnMap() in GCO_AltHistScript.lua)
	--[[
	for i = 0, iPlotCount - 1 do
		local plot = GetPlotByIndex(i)
		plot:SetMigrationValues()
	end	
	for loop = 0, 3 do
		for i = 0, iPlotCount - 1 do
			local plot = GetPlotByIndex(i)
			plot:DoMigration()
		end
	end
	--]]
	
	Game:SetProperty("InitialMapPopulationAdded", 1);
end

function GetSize(self)
	return math.pow(self:GetPopulation()/1000, Div(1,populationPerSizepower)) --GCO.Round(math.pow(self:GetPopulation()/1000, 1/populationPerSizepower))
end

function GetMaxSize(self)
	local maxSize = 0
	if (not self:IsWater()) then
		local food 			= math.ceil(self:GetPlotActualYield(GameInfo.Yields["YIELD_FOOD"].Index)*0.5)
		local bonus			= 0
		local appeal		= self:GetPlotAppeal()
		local numResource	= self:GetResourceCount()
		
		if numResource > 0 then
			local resourceID 	= self:GetResourceType()
			if GCO.IsResourceFood(resourceID) then
				food = food + math.ceil(numResource*0.5)
			end
		end
		if food > 1 then
			bonus = bonus + appeal
			if self:IsFreshWater() then
				bonus = bonus + 2
			end
		end
		maxSize = maxSize + food + bonus
		
	end
	return math.max(1,maxSize)
end

-- Legacy methods <<<<<
function GetPopulation(self)
	
	if self:IsCity() then
		local city = Cities.GetCityInPlot(self:GetX(), self:GetY())
		GCO.AttachCityFunctions(city)
		return city:GetUrbanPopulation()
	end
	return self:GetTotalCulture() --return self:GetLowerClass() --self:GetUpperClass() + self:GetMiddleClass() + self:GetLowerClass() + self:GetSlaveClass()
end

function ChangePopulation(self, value)
	self:MatchCultureToPopulation(self:GetPopulation() + value)
end

function GetPreviousPopulation(self)

	return self:GetTotalPreviousCulture() --self:GetPreviousLowerClass() -- self:GetPreviousUpperClass() + self:GetPreviousMiddleClass() + self:GetPreviousLowerClass() + self:GetPreviousSlaveClass()
end
--[[
function ChangeUpperClass(self, value)
	self:ChangePopulationClass(UpperClassID, value)
end

function ChangeMiddleClass(self, value)
	self:ChangePopulationClass(MiddleClassID, value)
end

function ChangeLowerClass(self, value)
	self:ChangePopulationClass(LowerClassID, value)
end

function ChangeSlaveClass(self, value)
	self:ChangePopulationClass(SlaveClassID, value)
end

function GetUpperClass(self)
	return self:GetStock(UpperClassID)
end

function GetMiddleClass(self)
	return self:GetStock(MiddleClassID)
end

function GetLowerClass(self)
	return self:GetStock(LowerClassID)
end

function GetSlaveClass(self)
	return self:GetStock(SlaveClassID)
end

function GetPopulationClass(self, populationID)
	return self:GetStock(populationID)
end

function GetPreviousPopulationClass(self, populationID)
	return self:GetPreviousStock(populationID)
end

function ChangePopulationClass(self, populationID, value)
	self:ChangeStock(populationID, value)
end

function GetPreviousUpperClass(self)
	return self:GetPreviousStock(UpperClassID)
end

function GetPreviousMiddleClass(self )
	return self:GetPreviousStock(MiddleClassID)
end

function GetPreviousLowerClass(self)
	return self:GetPreviousStock(LowerClassID)
end

function GetPreviousSlaveClass(self)
	return self:GetPreviousStock(SlaveClassID)
end
--]]
-- Legacy methods >>>>>

function GetBirthRate(self)
	local city = self:GetCity()
	if city then
		return city:GetBirthRate()
	else
		return 0 -- temporary
	end
end

function GetDeathRate(self)
	local city = self:GetCity()
	if city then
		return city:GetDeathRate()
	else
		return 0 -- temporary
	end
end

function GetBasePopulationDeathRate(self, populationID)
	return self:GetDeathRate() * DeathRateFactor[populationID]
end

function GetPopulationDeathRate(self, populationID)
	local city = self:GetCity()
	if city then
		return city:GetPopulationDeathRate()
	else
		return self:GetBasePopulationDeathRate(populationID)
	end
end

function GetBasePopulationBirthRate(self, populationID)
	return self:GetBirthRate() * BirthRateFactor[populationID]
end

function GetPopulationBirthRate(self, populationID)
	local city = self:GetCity()
	if city then
		return city:GetPopulationBirthRate()
	else
		return self:GetBasePopulationBirthRate(populationID)
	end
end

function GetMigration(self)
	local plotKey = self:GetKey()	
	
	local bInitialize = false
	if not _cached[plotKey] then
		_cached[plotKey] = {}
		bInitialize = true
	end
	if not _cached[plotKey].Migration then
		_cached[plotKey].Migration = { Push = {}, Pull = {}, Migrants = {}}
		bInitialize = true
	end
	
	if bInitialize then self:SetMigrationValues() end
	
	return _cached[plotKey].Migration
end

function MigrationTo(self, plot, migrants)

	local DEBUG_PLOT_SCRIPT	= DEBUG_PLOT_SCRIPT
	--if self:GetOwner() == Game.GetLocalPlayer() then DEBUG_PLOT_SCRIPT = "debug" end	-- and self:IsCity()
	
	local cultureTable	 	= self:GetCultureTable() or {}
	local leaveRatio		= math.min(1, Div(migrants, math.max(1, self:GetPopulation())))
	--local destinationRatio 	= math.min(1, Div(migrants, math.max(1, plot:GetPopulation())))
	--local changeRatio		= migrantRatio * populationRatio
	Dprint( DEBUG_PLOT_SCRIPT, "Do Migration from plot (".. self:GetX()..","..self:GetY() ..") to plot (".. plot:GetX()..","..plot:GetY() .."), Migrants =  "..tostring(migrants))

	
	for cultureKey, value in pairs(cultureTable) do
		-- once we have default culture groups on all the map, only use one value ? (cultureRemove)
		local cultureRemove	= math.floor(value * leaveRatio)
		local cultureAdd	= cultureRemove --math.ceil(cultureRemove * destinationRatio)
		Dprint( DEBUG_PLOT_SCRIPT, "  - "..Indentation20("cultureID#"..tostring(cultureKey)).. Indentation20(" remove = ".. tostring(cultureRemove)).. Indentation20(" leaveRatio = ".. tostring(GCO.ToDecimals(leaveRatio))).. Indentation20(" add = ".. tostring(cultureAdd)).. " origine Culture Value = " .. tostring(value))
		plot:ChangeCulture(cultureKey, cultureRemove) -- cultureAdd
		self:ChangeCulture(cultureKey, -cultureRemove)
		if plot:IsCity() then
			-- todo
		end
	end
	

	local migrationData		= self:GetMigrationDataWith(plot)
	local destMigrationData	= plot:GetMigrationDataWith(self)	
	
	migrationData.Migrants 		= migrationData.Migrants - migrants
if not migrationData.Total then GCO.Error("migrationData.Total is nil", self:GetX(), self:GetY()) end
	migrationData.Total 		= migrationData.Total - migrants
	destMigrationData.Migrants 	= destMigrationData.Migrants + migrants
if not destMigrationData.Total then GCO.Error("destMigrationData.Total is nil", self:GetX(), self:GetY()) end
	destMigrationData.Total 	= destMigrationData.Total + migrants
end

-----------------------------------------------------------------------------------------
-- Plot Stock
-----------------------------------------------------------------------------------------
function GetMaxStock(self, resourceID)
	local maxStock 			= 0
	local improvementType	= self:GetImprovementType()
	if improvementType == GameInfo.Improvements["IMPROVEMENT_BARBARIAN_CAMP_GCO"].Index then
		if resourceID == SlaveClassID 		then return 5000 end
		if resourceID == materielResourceID then return 1000 end
	end
	--if not GameInfo.Resources[resourceID].SpecialStock then -- Some resources are stocked in specific buildings only
		maxStock = GameInfo.Improvements[improvementType] and GameInfo.Improvements[improvementType].MaxStock or ResourceStockPerSize
		if resourceID == personnelResourceID 	then maxStock = PersonnelPerSize end
		if resourceID == foodResourceID 		then maxStock = FoodStockPerSize + baseFoodStock end
		if GCO.IsResourceEquipment(resourceID) 	then		
			local equipmentType = GameInfo.Resources[resourceID].ResourceType
			local equipmentSize = GameInfo.Equipment[equipmentType].Size
			maxStock = math.floor(Div(EquipmentBaseStock, equipmentSize))
		end
		if GCO.IsResourceLuxury(resourceID) 	then maxStock = GCO.Round(maxStock * LuxuryStockRatio) end
	--else
		-- handle improvement stocking specific resources here ?
	--end
	return maxStock
end

function GetStock(self, resourceID)
	local plotData 		= self:GetData()
	local turnKey 		= GCO.GetTurnKey()
	local resourceKey 	= tostring(resourceID)
	if not plotData.Stock[turnKey] then return 0 end
	return plotData.Stock[turnKey][resourceKey] or 0
end

function ChangeStock(self, resourceID, value, useType, reference)

	if not resourceID then
		GCO.Warning("resourceID is nil or false in ChangeStock at ", self:GetX(), self:GetY(), " resourceID = ", resourceID," value= ", value)
		return
	end

	if value == 0 then return end
	
	if resourceID == LowerClassID then -- should not call ChangeStock with population directly, but this will correctly change the population value on plot, with an error correction on culture.
		self:ChangePopulation(value)
		GCO.Warning("Called pPlot:ChangeStock for LowerClassID at ", self:GetX(), self:GetY())
		GCO.DlineFull()
		return
	end

	value = GCO.ToDecimals(value)

	local resourceKey 	= tostring(resourceID)
	local plotData 		= self:GetData()
	local turnKey 		= GCO.GetTurnKey()

	--[[
	if not reference then reference = NO_REFERENCE_KEY end
	reference = tostring(reference) -- will be a key in table
	
	if value > 0 then
		if not useType then useType = ResourceUseType.OtherIn end
	else
		if not useType then useType = ResourceUseType.OtherOut  end
	end
	--]]
	
	if not plotData.Stock[turnKey] then 
		GCO.Warning("plotData not initialized at turn"..tostring(turnKey), self:GetX(), self:GetY())
		GCO.DlineFull()
		plotData.Stock[turnKey] = {}
	end

	-- Update stock
	if not plotData.Stock[turnKey][resourceKey] then
		if value < 0 then
			GCO.Error("Trying to set a negative value to ".. Locale.Lookup(GameInfo.Resources[tonumber(resourceID)].Name) .." stock, value = "..tostring(value))
		end
		plotData.Stock[turnKey][resourceKey] = math.max(0 , value)
	else
		local newStock = GCO.ToDecimals(plotData.Stock[turnKey][resourceKey] + value)
		if newStock < -1 then -- allow a rounding error up to 1
			GCO.Error("Trying to set a negative value to ".. Locale.Lookup(GameInfo.Resources[tonumber(resourceID)].Name) .." stock, previous stock = ".. tostring(plotData.Stock[turnKey][resourceKey])..", variation value = "..tostring(value))
		end
		plotData.Stock[turnKey][resourceKey] = math.max(0 , newStock)
	end

	-- update stats
	--[[
	if not plotData.ResourceUse[turnKey][resourceKey] then
		plotData.ResourceUse[turnKey][resourceKey] = { [useType] = {[reference] = math.abs(value)}}

	elseif not plotData.ResourceUse[turnKey][resourceKey][useType] then
		plotData.ResourceUse[turnKey][resourceKey][useType] = {[reference] = math.abs(value)}

	elseif not plotData.ResourceUse[turnKey][resourceKey][useType][reference] then
		plotData.ResourceUse[turnKey][resourceKey][useType][reference] = math.abs(value)

	else
		plotData.ResourceUse[turnKey][resourceKey][useType][reference] = GCO.ToDecimals(ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType][reference] + math.abs(value))
	end
	--]]
end

function GetResources(self)
	local plotData 		= self:GetData()
	local turnKey 		= GCO.GetTurnKey()
	return plotData.Stock[turnKey] or {}
end

function GetPreviousStock(self , resourceID)
	local plotData 		= self:GetData()
	local turnKey 		= GCO.GetPreviousTurnKey()
	local resourceKey 	= tostring(resourceID)
	if not plotData.Stock[turnKey] then return 0 end
	return plotData.Stock[turnKey][resourceKey] or 0
end

function GetStockVariation(self, resourceID)
	return GCO.ToDecimals(self:GetStock(resourceID) - self:GetPreviousStock(resourceID))
end

function GetBaseVisibleResources(self, playerID)
	local resourceValues	= {}
	local player 			= GCO.GetPlayer(playerID)
	
	if player then
	
		local function AddResource(resourceID, value)
			if player:IsResourceVisible(resourceID) then
				resourceValues[resourceID] = (resourceValues[resourceID] or 0) + value
			end
		end

		if self:GetResourceCount() > 0 then
			local resourceID 	= self:GetResourceType()
			AddResource(resourceID, self:GetResourceCount())
		end

		local featureID = self:GetFeatureType()
		if FeatureResources[featureID] then
			for _, data in pairs(FeatureResources[featureID]) do
				for resourceID, value in pairs(data) do
					AddResource(resourceID, value)
				end
			end
		end

		local terrainID = self:GetTerrainType()
		if TerrainResources[terrainID] then
			for _, data in pairs(TerrainResources[terrainID]) do
				for resourceID, value in pairs(data) do
					AddResource(resourceID, value)
				end
			end
		end
	end
	return resourceValues
end

-----------------------------------------------------------------------------------------
-- Plot Doturn
-----------------------------------------------------------------------------------------

function UpdateDataOnNewTurn(self) -- called for every player at the beginning of a new turn

	--Dlog("UpdateDataOnNewTurn (".. tostring(self:GetX()) .. "," tostring(self:GetY())..") /START")
	--local DEBUG_PLOT_SCRIPT = "debug"

	Dprint( DEBUG_PLOT_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLOT_SCRIPT, "Updating Data for ".. self:GetX(), self:GetY())

	if Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then -- don't update on first turn (NewTurn is called on the first turn of a later era start)
		GCO.Warning("Aborting UpdateDataOnNewTurn for plots, this is the first turn !")
		return
	end
	
	local plotData 			= self:GetData()
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey 	= GCO.GetPreviousTurnKey()
	if turnKey ~= previousTurnKey then

		Dprint( DEBUG_PLOT_SCRIPT, "turnKey = ", turnKey, " previousTurnKey = ", previousTurnKey)
		
		-- get previous turn data
		local stockData = plotData.Stock[previousTurnKey] 		or {}
		--local popData 	= plotData.Population[previousTurnKey]	or {}
		
		-- initialize empty tables for the new turn data
		plotData.Stock[turnKey] 		= {}
		--plotData.Population[turnKey]	= {}
		--plotData.ResourceUse[turnKey]	= {}
		
		-- fill the new table with previous turn data
		for resourceKey, value in pairs(stockData) do
			plotData.Stock[turnKey][resourceKey] = value
		end

		--for key, value in pairs(popData) do
		--	plotData.Population[turnKey][key] = value
		--end

	end
	--Dlog("UpdateDataOnNewTurn /END")
end

function SetMigrationValues(self)

	if self:IsCity() then return end -- cities handle migration differently
		
	local DEBUG_PLOT_SCRIPT	= DEBUG_PLOT_SCRIPT
	--if self:GetOwner() == Game.GetLocalPlayer() then DEBUG_PLOT_SCRIPT = "debug" end
	
	local village = GCO.GetTribalVillageAt(self:GetIndex())
	--if village and village.Owner == Game.GetLocalPlayer() then DEBUG_PLOT_SCRIPT = "debug" end
	--if self:GetIndex() == 1006 then DEBUG_PLOT_SCRIPT = "debug" end
	
	local plotMigration = self:GetMigration()
	
	Dprint( DEBUG_PLOT_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLOT_SCRIPT, "- Set Migration values to plot ".. self:GetX() ..",".. self:GetY())
	local possibleDestination 		= {}
	local city						= self:GetCity()
	local migrantClasses			= {UpperClassID, MiddleClassID, LowerClassID}
	--local migrantMotivations		= {"Under threat", "Starvation", "Employment", "Overpopulation"}
	local migrants					= {}
	local population				= self:GetPopulation()
	local employment				= self:GetMaxEmployment()
	local maxPlotPopulation			= GCO.GetPopulationAtSize(self:GetMaxSize())
	
	if village then -- a village exploit its plot and all adjacent plot, use adjacent max for population/employment
		--local numPlots = 1
		for i, adjacentPlotID in ipairs(GCO.GetAdjacentPlots(self)) do
			local adjacentPlot	= GCO.GetPlotByIndex(adjacentPlotID)
			if adjacentPlot then
				employment 			= math.max(employment, adjacentPlot:GetMaxEmployment()) -- employment + adjacentPlot:GetMaxEmployment()
				maxPlotPopulation	= math.max(maxPlotPopulation, GCO.GetPopulationAtSize(adjacentPlot:GetMaxSize())) -- maxPlotPopulation, GCO.GetPopulationAtSize(adjacentPlot:GetMaxSize())
				--numPlots			= numPlots + 1
			end
		end
		--local divisor		= numPlots * 0.5
		employment 			= math.floor(employment*1.05)--Div(employment, divisor)
		maxPlotPopulation	= math.floor(maxPlotPopulation*1.05)--Div(maxPlotPopulation, divisor)
	end
	
	local maxHousedPopulation		= math.floor((employment*0.25) + maxPlotPopulation) -- employment provides housing
	local employed					= self:GetEmployed()
	local unEmployed				= math.max(0, population - employment)
	
	if population > 0 then
		-- check Migration motivations, from lowest to most important :	
	
		-- Employment
		if employment > 0 then
			plotMigration.Pull.Employment	= Div(employment, population)
			plotMigration.Push.Employment	= Div(population, employment)
			if plotMigration.Push.Employment > 1 then 
				plotMigration.Motivation 			= "Employment"
				plotMigration.Migrants.Employment	= unEmployed
			end
		else
			plotMigration.Pull.Employment	= 0
			plotMigration.Push.Employment	= 0		
		end
		Dprint( DEBUG_PLOT_SCRIPT, "  - UnEmployed = ", unEmployed," employment : ", employment, " population = ", population, " maxPlotPopulation = ", maxPlotPopulation)
		
		-- Population
		plotMigration.Pull.Housing	= Div(maxHousedPopulation, population)
		plotMigration.Push.Housing	= Div(population, maxHousedPopulation)
		if plotMigration.Push.Housing > 1 then 
			plotMigration.Motivation 		= "Population"
			local overPopulation			= population - maxHousedPopulation
			plotMigration.Migrants.Housing	= overPopulation
		end
		Dprint( DEBUG_PLOT_SCRIPT, "  - Overpopulation = ", plotMigration.Migrants.Housing," maxHousedPopulation : ", maxHousedPopulation, " population = ", population)
		
		-- Starvation
		if city then
			-- starvation can happen on plots controlled by a city (the city is requisitionning all food then share it over its urban+rural population)
			-- on free plots, the risk of starvation is part of the "Overpopulation" motivation
			-- if food rationning in city, try to move to external plot (other civ or unowned), reason : "food is requisitioned"
			local consumptionRatio	= 1
			local foodNeeded		= math.max(1, city:GetFoodConsumption(consumptionRatio))
			local foodstock			= math.max(1, city:GetFoodStock())
			-- pondered by plots own sustainability
			plotMigration.Pull.Food	= (Div(foodstock, foodNeeded) + Div(maxPlotPopulation, population)) / 2 
			plotMigration.Push.Food	= (Div(foodNeeded, foodstock) + Div(population, maxPlotPopulation)) / 2
			if plotMigration.Push.Food > 1 then 
				plotMigration.Motivation 	= "Food"
				local starving				= population - Div(population, plotMigration.Push.Food)
				plotMigration.Migrants.Food	= starving
			end
			Dprint( DEBUG_PLOT_SCRIPT, "  - Starving = ", plotMigration.Migrants.Food," foodNeeded : ", foodNeeded, " foodstock = ", foodstock)
			
		elseif village and village.Pull and village.Push then
			plotMigration.Pull.Food	= village.Pull.Food and (village.Pull.Food*0.25) + (Div(maxPlotPopulation, population)*0.75) or Div(maxPlotPopulation, population)
			plotMigration.Push.Food	= village.Push.Food or Div(population, maxPlotPopulation)
			
			if plotMigration.Push.Food > 1 then 
				plotMigration.Motivation 	= "Food"
				local starving				= population - Div(population, plotMigration.Push.Food)
				plotMigration.Migrants.Food	= starving
			end
			Dprint( DEBUG_PLOT_SCRIPT, "  - Starving = ", plotMigration.Migrants.Food," foodNeeded : ", village.FoodRequired, " foodstock, produced = ", self:GetStock(foodResourceID), village.FoodProduced)
		
		else
			plotMigration.Pull.Food	= Div(maxPlotPopulation, population) -- free plots use the population support value for Food when "pulling" migrants that are pushed out of a city influence by starvation 
			plotMigration.Push.Food	= Div(population, maxPlotPopulation)
		end
		
		-- Threat
		--
		--
		
		if city then
		Dprint( DEBUG_PLOT_SCRIPT, "  - Pull.Food : ", GCO.ToDecimals(plotMigration.Pull.Food), " Push.Food = ", GCO.ToDecimals(plotMigration.Push.Food))
		end	
		Dprint( DEBUG_PLOT_SCRIPT, "  - Pull.Housing : ", GCO.ToDecimals(plotMigration.Pull.Housing), " Push.Housing = ", GCO.ToDecimals(plotMigration.Push.Housing))
		Dprint( DEBUG_PLOT_SCRIPT, "  - Pull.Employment : ", GCO.ToDecimals(plotMigration.Pull.Employment), " Push.Employment = ", GCO.ToDecimals(plotMigration.Push.Employment))
	end
end

function DoMigration(self)

	if self:IsCity() then return end -- cities handle migration differently (but we want to allow migration to adjacent plots not owned by the city if not done in the city turn)
	
	local DEBUG_PLOT_SCRIPT	= DEBUG_PLOT_SCRIPT
	--if self:GetOwner() == Game.GetLocalPlayer() then DEBUG_PLOT_SCRIPT = "debug" end	
	
	local village = GCO.GetTribalVillageAt(self:GetIndex())
	--if village and village.Owner == Game.GetLocalPlayer() then DEBUG_PLOT_SCRIPT = "debug" end
	--if self:GetIndex() == 1006 then DEBUG_PLOT_SCRIPT = "debug" end
	
	Dprint( DEBUG_PLOT_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLOT_SCRIPT, "- Population Migration from plot ".. self:GetX() ..",".. self:GetY())
	local plotKey 				= self:GetKey()
	local plotMigration 		= self:GetMigration()
	--local migrationMap	 		= self:GetMigrationMap()
	local population			= self:GetPopulation()
	
	if population == 0 then return end
	
	local possibleDestination 	= {}
	local city					= self:GetCity()
	local migrantClasses		= {LowerClassID}--{UpperClassID, MiddleClassID, LowerClassID}
	--local migrantMotivations	= {"Under threat", "Starvation", "Employment", "Overpopulation"}	
	local maxMigrants			= math.floor(population * maxMigrantPercent / 100)
	local minMigrants			= math.floor(population * minMigrantPercent / 100)
	local migrants 				= 0
	local totalWeight			= 0
	
	local classesRatio			= {}
	--for i, classID in ipairs(migrantClasses) do
	--	classesRatio[classID] = Div(self:GetPopulationClass(classID), population)
	--end
	-- Get the number of migrants from this plot
	for motivation, value in pairs(plotMigration.Migrants) do
		migrants = math.max(value, migrants) -- motivations can overlap, so just use the biggest value from all motivations 
	end
	migrants = math.min(maxMigrants, math.max(minMigrants, migrants))
	
	Dprint( DEBUG_PLOT_SCRIPT, "- Eager migrants = ", migrants)
	for _, populationID in ipairs(migrantClasses) do
			
	end
	--]]
	
	if migrants > 0 then
		
		-- migration to adjacent plots
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local adjacentPlot 	= Map.GetAdjacentPlot(self:GetX(), self:GetY(), direction)
			if adjacentPlot then
				local bNotSameOwner	= adjacentPlot:GetOwner() ~= self:GetOwner()
				local bCanDiffuse 	= (not adjacentPlot:IsWater()) and ((not (adjacentPlot:IsCity() or self:IsCity())) or bNotSameOwner) -- we update adjacent city plots only when not owned by the city, else the city itself handles that

				if bCanDiffuse then
					local diffusionValues	= self:GetPlotDiffusionValuesTo(direction)
					-- debug
					if (not diffusionValues) then
						local toStr 			= self:GetX() ..",".. self:GetY() .. " to " .. adjacentPlot:GetX() ..",".. adjacentPlot:GetY()
						local plotTerrainStr	= Locale.Lookup(GameInfo.Terrains[self:GetTerrainType()].Name)
						local toTerrainStr		= Locale.Lookup(GameInfo.Terrains[adjacentPlot:GetTerrainType()].Name)
						GCO.Warning("No diffusion value from ".. plotTerrainStr .. " " .. toStr .. " " .. toTerrainStr)
					end
					
					if diffusionValues then			
						local adjacentPlotKey 		= adjacentPlot:GetKey()
						local adjacentPlotMigration = adjacentPlot:GetMigration()
						local bWorked 				= (adjacentPlot:GetWorkerCount() > 0)
						local plotWeight			= 0
						
						Dprint( DEBUG_PLOT_SCRIPT, "  - Looking for better conditions in ".. DirectionString[direction] .." on plot ".. adjacentPlot:GetX() ..",".. adjacentPlot:GetY().." Diffusion Values : Bonus = "..tostring(diffusionValues.Bonus)..", Penalty = "..tostring(diffusionValues.Penalty)..", Ratio = "..tostring(diffusionValues.MaxRatio))
						for motivation, pushValue in pairs(plotMigration.Push) do
							local adjacentPull	= adjacentPlotMigration.Pull[motivation] or 0
							local adjacentPush	= adjacentPlotMigration.Push[motivation] or 0
							-- to do : effect of owned / foreign / free plots
							local weightRatio	= 1	
							Dprint( DEBUG_PLOT_SCRIPT, "    -  Motivation : "..Indentation15(motivation) .. " pushValue = ", GCO.ToDecimals(pushValue), " adjacentPush = ", GCO.ToDecimals(adjacentPush), " adjacentPull = ", GCO.ToDecimals(adjacentPull))

							if adjacentPush < pushValue then 			-- situation is better on adjacentPlot than on currentPlot for [motivation]
								if adjacentPull > 1 then
									weightRatio = weightRatio * 2		-- situation is good on adjacentPlot
								end
								if pushValue > 1 then
									weightRatio = weightRatio * 5		-- situation is bad on currentPlot
								end
								if motivation == plotMigration.Motivation then
									weightRatio = weightRatio * 10		-- this is the most important motivation for migration
								end
								if bWorked then
									weightRatio = weightRatio * 10		-- we want migration on worked plots
								end
								local motivationWeight = (adjacentPull + pushValue) * weightRatio
								plotWeight = plotWeight + motivationWeight
								Dprint( DEBUG_PLOT_SCRIPT, "       -  weightRatio = ", GCO.ToDecimals(weightRatio), " motivationWeight = ", GCO.ToDecimals(motivationWeight), " updated plotWeight = ", GCO.ToDecimals(plotWeight))
							end
						end
						
						if plotWeight > 0 then
							plotWeight = (plotWeight + diffusionValues.Bonus + diffusionValues.Penalty) * diffusionValues.MaxRatio
							Dprint( DEBUG_PLOT_SCRIPT, "  - After diffusionValues: plotWeight = ", GCO.ToDecimals(plotWeight))
							totalWeight = totalWeight + plotWeight
							table.insert (possibleDestination, {PlotID = adjacentPlot:GetIndex(), Weight = plotWeight, MigrationEfficiency = math.min(1,diffusionValues.MaxRatio)})
						end
					end
				end
			end
		end
		
		-- migration to owning city
		if city then
			
			local cityMigration = city:GetMigration()
			if cityMigration then
				local distance		= Map.GetPlotDistance(self:GetX(), self:GetY(), city:GetX(), city:GetY())
				if distance < 3 then
					local cityPlot 	= GetPlot(city:GetX(), city:GetY())
					local path 		= self:GetPathToPlot(cityPlot, nil, "Land", nil, 5)
					if path then
						local efficiency 	= (1 - math.min(0.9, distance / 10))
						local cityWeight = 0
						Dprint( DEBUG_PLOT_SCRIPT, "  - Looking for better conditions in City of ".. Locale.Lookup(city:GetName()) ..", Transport efficiency = ", GCO.ToDecimals(efficiency))
						for motivation, pushValue in pairs(plotMigration.Push) do
							local cityPull	= cityMigration.Pull[motivation][LowerClassID] or 0
							local cityPush	= cityMigration.Push[motivation][LowerClassID] or 0
							-- to do : effect of owned / foreign / free plots
							local weightRatio	= efficiency	
							Dprint( DEBUG_PLOT_SCRIPT, "    -  Motivation : "..Indentation15(motivation) .. " pushValue = ", GCO.ToDecimals(pushValue), " cityPush = ", GCO.ToDecimals(cityPush), " cityPull = ", GCO.ToDecimals(cityPull))
							if cityPush < pushValue then 			-- situation is better on adjacentPlot than on currentPlot for [motivation]
								if cityPull > 1 then
									weightRatio = weightRatio * 2		-- situation is good on adjacentPlot
								end
								if pushValue > 1 then
									weightRatio = weightRatio * 5		-- situation is bad on currentPlot
								end
								if motivation == plotMigration.Motivation then
									weightRatio = weightRatio * 10		-- this is the most important motivation for migration
								end
								local motivationWeight = (cityPull + pushValue) * weightRatio
								cityWeight = cityWeight + motivationWeight
								Dprint( DEBUG_PLOT_SCRIPT, "       -  weightRatio = ", GCO.ToDecimals(weightRatio), " motivationWeight = ", GCO.ToDecimals(motivationWeight), " updated cityWeight = ", GCO.ToDecimals(cityWeight))
							end
						end
						
						if cityWeight > 0 then
							totalWeight = totalWeight + cityWeight
							table.insert (possibleDestination, {City = city, Weight = cityWeight, MigrationEfficiency = efficiency, Path = path})
						end
					end
				end
			else
				GCO.Warning("cityMigration is nil for ".. Locale.Lookup(city:GetName()))
			end
		end
		
		table.sort(possibleDestination, function(a, b) return a.Weight > b.Weight; end)
		local numPlotDest = #possibleDestination
		Dprint( DEBUG_PLOT_SCRIPT, "- Num Destinations = ", numPlotDest)
		for i, destination in ipairs(possibleDestination) do
			if migrants > 0 and destination.Weight > 0 then
				-- MigrationEfficiency already affect destination.Weight, but when there is not many possible destination 
				-- we want to limit the number of migrants over difficult routes, so it's included here too
				if destination.MigrationEfficiency > 1 then
					GCO.Warning("MigrationEfficiency = ".. tostring(destination.MigrationEfficiency))
					for k, v in pairs(destination) do print(k,v) end
					destination.MigrationEfficiency = 1
				end
				totalWeight				= math.max(1, totalWeight) -- do not divide by 0 !!!
				local totalPopMoving 	= math.floor(migrants * Div(destination.Weight, totalWeight) * destination.MigrationEfficiency)
				if totalPopMoving > 0 then
					for ii, classID in ipairs(migrantClasses) do
						local classMoving = totalPopMoving --math.floor(totalPopMoving * classesRatio[classID])
						if classMoving > 0 then
							if destination.PlotID then -- plot to plot migration
								local plot 				= GCO.GetPlotByIndex(destination.PlotID)
								Dprint( DEBUG_PLOT_SCRIPT, "- Moving " .. Indentation20(tostring(classMoving) .. " " ..Locale.Lookup(GameInfo.Resources[classID].Name)).. " to plot ("..tostring(plot:GetX())..","..tostring(plot:GetY())..") with Weight = "..tostring(destination.Weight))
								self:MigrationTo(plot, classMoving) -- before changing population values to get the correct numbers on each plot
								--self:ChangePopulationClass(classID, -classMoving)
								--plot:ChangePopulationClass(classID, classMoving)
							else -- going to owning city
								local city 			= destination.City
								local plot 			= GetPlot(city:GetX(), city:GetY())
								local currentPlot	= self
								local path			= destination.Path
								Dprint( DEBUG_PLOT_SCRIPT, "- Moving " .. Indentation20(tostring(classMoving) .. " " ..Locale.Lookup(GameInfo.Resources[classID].Name)).. " to city ("..Locale.Lookup(city:GetName())..") with Weight = "..tostring(destination.Weight))
								for num, plotID in ipairs(path) do
									if num > 1 then -- 1 is the origin plot
										local pathPlot = Map.GetPlotByIndex(plotID)
										Dprint( DEBUG_PLOT_SCRIPT, "- path plot #".. tostring(num) .." = ".. pathPlot:GetX() ..",".. pathPlot:GetY())
										currentPlot:MigrationTo(pathPlot, classMoving)
										currentPlot = pathPlot
									end
								end
								--self:MigrationTo(plot, classMoving)
								--self:ChangePopulationClass(classID, -classMoving)
								city:ChangePopulationClass(classID, classMoving)
							end
						end
					end
				end
			end	
		end
		
		-- to do: temporary table with total migration for each destination
		-- and call MigrationTo only once per destination
		-- to prevent culture overflow
	end
end

function CheckNewTurnFinished()
	if debugTable["OnNewTurn"] ~= nil then
		GCO.Error("Plots turn unfinished !")
		ShowDebug()
	end
end


function OnNewTurn()
	if DEBUG_PLOT_TURN then
		GCO.Monitor(DoPlotsTurn, {}, "Plots Turn")
	else
		DoPlotsTurn()
	end
end

function DoPlotsTurn()

	if Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then -- don't update on first turn (NewTurn is called on the first turn of a later era start)
		GCO.Warning("Aborting OnNewTurn() for plots, this is the first turn !")
		return
	end
	
	-- delayed updates
	local turnRate 	= 1 -- update per turn
	local step		= GCO.LoadValue("PlotsDoTurnCurrentStep") or 0
	
	
	-- initialize and set local debug table
	debugTable["OnNewTurn"] 		= {} 	
	debugTable["OnNewTurnPlotNum"] 	= {}
	local textTable 				= debugTable["OnNewTurn"]
	local posTable 					= debugTable["OnNewTurnPlotNum"]

	GCO.StartTimer("Plots DoTurn")
	local iPlotCount = Map.GetPlotCount()
	
	-- First Pass
	GCO.StartTimer("Plots DoTurn First Pass")
	table.insert(textTable, "First Pass")
	for i = 0, iPlotCount - 1 do
		local plot 	= Map.GetPlotByIndex(i)
		--posTable[1] = Indentation8("Managing plot #"..tostring(i)).." at ".. tostring(plot:GetX())..",".. tostring(plot:GetY())
		-- set previous culture first
		local plotCulture = plot:GetCultureTable()
		if  plotCulture then
			for playerID, value in pairs (plotCulture) do
				plot:SetPreviousCulture( playerID, value )			
			end
		end
	end
	GCO.ShowTimer("Plots DoTurn First Pass")
	
	-- Second Pass
	GCO.StartTimer("Plots DoTurn Second Pass")
	table.insert(textTable, "Second Pass")
	for i = 0, iPlotCount - 1 do
		local plot = Map.GetPlotByIndex(i)
		--posTable[1] = Indentation20("Managing plot #"..tostring(i)).." at ".. tostring(plot:GetX())..",".. tostring(plot:GetY())
		plot:UpdateDataOnNewTurn()	
		plot:UpdateCulture()
		plot:SetMaxEmployment()
	end
	GCO.ShowTimer("Plots DoTurn Second Pass")
	
	-- Third Pass
	GCO.StartTimer("Plots DoTurn Third Pass")
	table.insert(textTable, "Third Pass")
	for i = 0, iPlotCount - 1 do
		local plot = Map.GetPlotByIndex(i)
		--posTable[1] = Indentation20("Managing plot #"..tostring(i)).." at ".. tostring(plot:GetX())..",".. tostring(plot:GetY())
		plot:SetMigrationValues()
	end	
	GCO.ShowTimer("Plots DoTurn Third Pass")
	
	-- Fourth Pass
	GCO.StartTimer("Plots DoTurn Fourth Pass")
	table.insert(textTable, "Fourth Pass")
	for i = step, iPlotCount - 1, turnRate do
		local plot = Map.GetPlotByIndex(i)
		--posTable[1] = Indentation20("Managing plot #"..tostring(i)).." at ".. tostring(plot:GetX())..",".. tostring(plot:GetY())
		plot:DoMigration()
	end
	GCO.ShowTimer("Plots DoTurn Fourth Pass")
	
	-- Fifth Pass
	GCO.StartTimer("Plots DoTurn Fifth Pass")
	table.insert(textTable, "Fifth Pass")
	for i = step, iPlotCount - 1, turnRate do
		local plot = Map.GetPlotByIndex(i)
		--posTable[1] = Indentation20("Managing plot #"..tostring(i)).." at ".. tostring(plot:GetX())..",".. tostring(plot:GetY())
		plot:MatchCultureToPopulation()
	end	
	GCO.ShowTimer("Plots DoTurn Fifth Pass")
	
	--print("-----------------------------------------------------------------------------------------")
	GCO.ShowTimer("Plots DoTurn")
	--print("-----------------------------------------------------------------------------------------")
	
	step = (step == turnRate-1) and 0 or step + 1
	GCO.SaveValue("PlotsDoTurnCurrentStep", step)
	
	debugTable["OnNewTurn"] = nil
	debugTable["OnNewTurnPlotNum"] = nil
end
Events.TurnBegin.Add(OnNewTurn)
Events.TurnBegin.Add(CheckNewTurnFinished)

-----------------------------------------------------------------------------------------
-- UI Functions
-----------------------------------------------------------------------------------------
--ContextPtr:RequestRefresh()


-----------------------------------------------------------------------------------------
-- Events Functions
-----------------------------------------------------------------------------------------
function OnCityTileOwnershipChanged(playerID, cityID)

end
Events.CityTileOwnershipChanged.Add(OnCityTileOwnershipChanged)

function DiffusionValueUpdate(x,y)
	if not ExposedMembers.GCO_Initialized then return end
	local plot = GetPlot(x,y)
	if plot then
		plot:UpdatePlotDiffusionValues()
	end
end
function EmploymentValueUpdate(x,y)
	if not ExposedMembers.GCO_Initialized then return end
	local plot = GetPlot(x,y)
	if plot then
		plot:SetMaxEmployment()
	end
end

function OnFeatureChanged(x,y)
	if not ExposedMembers.GCO_Initialized then return end
	--local DEBUG_PLOT_SCRIPT = "debug"
	Dprint( DEBUG_PLOT_SCRIPT, "Feature changed at ", x,y)
	
	local plot 			= GetPlot(x,y)	
	local prevFeatureID = plot:GetCached("FeatureType")
	local newFeatureID	= plot:GetFeatureType()

	Dprint( DEBUG_PLOT_SCRIPT, "  - from FeatureID#", prevFeatureID)
	Dprint( DEBUG_PLOT_SCRIPT, "  - to   FeatureID#", newFeatureID)
	
	if prevFeatureID ~= NO_FEATURE and newFeatureID == NO_FEATURE then
		GameEvents.FeatureRemoved.Call(prevFeatureID, x,y)
	end
	
	plot:SetCached("FeatureType", plot:GetFeatureType())
end

Events.ImprovementAddedToMap.Add(DiffusionValueUpdate)
Events.ImprovementRemovedFromMap.Add(DiffusionValueUpdate)
Events.FeatureRemovedFromMap.Add(DiffusionValueUpdate)
Events.FeatureAddedToMap.Add(DiffusionValueUpdate)
Events.RouteAddedToMap.Add(DiffusionValueUpdate)
Events.RouteRemovedFromMap.Add(DiffusionValueUpdate)

Events.ImprovementAddedToMap.Add(EmploymentValueUpdate)
Events.ImprovementRemovedFromMap.Add(EmploymentValueUpdate)
Events.FeatureRemovedFromMap.Add(EmploymentValueUpdate)
Events.FeatureAddedToMap.Add(EmploymentValueUpdate)
Events.ResourceVisibilityChanged.Add(EmploymentValueUpdate)

Events.FeatureRemovedFromMap.Add(OnFeatureChanged)
Events.FeatureAddedToMap.Add(OnFeatureChanged)

-----------------------------------------------------------------------------------------
-- Functions passed from UI Context
-----------------------------------------------------------------------------------------
function GetPlotAppeal(self)
	return GCO.GetPlotAppeal( self )
end

function IsPlotImprovementPillaged(self)
	return GCO.IsImprovementPillaged( self )
end

function GetPlotActualYield(self, yieldID)
	return GCO.GetPlotActualYield(self, yieldID )
end


-----------------------------------------------------------------------------------------
-- Shared Functions
-----------------------------------------------------------------------------------------
function GetPlotByIndex(index) -- return a plot with PlotScript functions for another context
	local plot = Map.GetPlotByIndex(index)
	if plot then
		InitializePlotFunctions(plot)
		return plot
	end
end

function GetPlot(x, y) -- return a plot with PlotScript functions for another context
	local plot = Map.GetPlot(x, y)
	InitializePlotFunctions(plot)
	return plot
end

function CleanPlotsData() -- called in GCO_GameScript.lua

	-- remove old data from the table
	--local DEBUG_PLOT_SCRIPT = "debug"
	Dprint( DEBUG_PLOT_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLOT_SCRIPT, "Cleaning PlotData...")	
	
	local toClean 	= {"Stock"}
	local maxTurn	= 3
		
	for plotKey, data1 in pairs(ExposedMembers.PlotData) do
		for i, dataToClean in ipairs(toClean) do
			turnTable = {}
			for turnkey, data2 in pairs(data1[dataToClean]) do
				local turn = tonumber(turnkey)
				if turn <= (Game.GetCurrentGameTurn() - maxTurn) then

					Dprint( DEBUG_PLOT_SCRIPT, "Removing entry : ", plotKey, dataToClean, " turn = ", turn)
					table.insert(turnTable, turn)
				end
			end
			for j, turn in ipairs(turnTable) do
				local turnkey = tostring(turn)
				ExposedMembers.PlotData[plotKey][dataToClean][turnkey] = nil
			end
		end
	end
	
	for plotKey, data1 in pairs(ExposedMembers.MigrationMap) do
		turnTable = {}
		for turnkey, data2 in pairs(data1) do
			local turn = tonumber(turnkey)
			if turn <= (Game.GetCurrentGameTurn() - maxTurn) then

				Dprint( DEBUG_PLOT_SCRIPT, "Removing entry : ", plotKey, " turn = ", turn)
				table.insert(turnTable, turnkey)
			end
		end
		for j, turnkey in ipairs(turnTable) do
			ExposedMembers.MigrationMap[plotKey][turnkey] = nil
		end
	end
end


-----------------------------------------------------------------------------------------
-- Initialize Plot Functions
-----------------------------------------------------------------------------------------
function InitializePlotFunctions(plot) -- Note that those functions are limited to this file context

	if not plot then plot = Map.GetPlot(1,1) end
	local p = getmetatable(plot).__index
	
	if p.IsInitializedForGCO == nil then
		p.OldSetOwner					= p.SetOwner
		p.SetOwner						= SetOwner
	
		p.IsPlotImprovementPillaged		= IsPlotImprovementPillaged
		p.GetPlotAppeal					= GetPlotAppeal
		p.GetPlotActualYield			= GetPlotActualYield
		
		p.GetKey						= GetKey
		p.GetData						= GetData
		p.GetMigrationMap				= GetMigrationMap
		p.GetMigrationMapAtTurn			= GetMigrationMapAtTurn
		p.GetMigrationDataWith			= GetMigrationDataWith
		p.GetMigrationDataAtTurn		= GetMigrationDataAtTurn
		p.GetCache						= GetCache
		p.GetCached						= GetCached
		p.SetCached						= SetCached
		p.GetValue						= GetValue
		p.SetValue						= SetValue
		p.GetCity						= GetCity
		p.GetEraType					= GetEraType
		p.GetPlotDiffusionValuesTo		= GetPlotDiffusionValuesTo
		p.SetPlotDiffusionValuesTo		= SetPlotDiffusionValuesTo
		p.UpdatePlotDiffusionValues		= UpdatePlotDiffusionValues
		p.GetTotalCulture 				= GetTotalCulture
		p.GetCulturePercent				= GetCulturePercent
		p.GetCulturePercentTable		= GetCulturePercentTable
		p.GetCultureString				= GetCultureString
		p.DoConquestCountDown 			= DoConquestCountDown
		p.GetConquestCountDown 			= GetConquestCountDown
		p.SetConquestCountDown 			= SetConquestCountDown
		p.GetCultureTable				= GetCultureTable
		p.GetCulture 					= GetCulture
		p.SetCulture 					= SetCulture
		p.ChangeCulture 				= ChangeCulture
		p.GetPreviousCulture 			= GetPreviousCulture
		p.SetPreviousCulture 			= SetPreviousCulture
		p.GetHighestCultureID 			= GetHighestCultureID
		p.GetTotalPreviousCulture		= GetTotalPreviousCulture	
		p.GetCulturePer10000			= GetCulturePer10000
		p.GetPreviousCulturePer10000	= GetPreviousCulturePer10000
		p.IsLockedByWarForPlayer		= IsLockedByWarForPlayer
		p.IsLockedByFortification		= IsLockedByFortification
		p.IsLockedByCitadelForPlayer 	= IsLockedByCitadelForPlayer
		p.GetPotentialOwner				= GetPotentialOwner
		p.IsTerritorialWaterOf			= IsTerritorialWaterOf
		p.GetTerritorialWaterOwner		= GetTerritorialWaterOwner
		p.MatchCultureToPopulation		= MatchCultureToPopulation
		p.UpdateCulture					= UpdateCulture
		p.UpdateOwnership				= UpdateOwnership
		p.DiffuseCulture				= DiffuseCulture
		p.MigrationTo					= MigrationTo
		p.GetDirectionStringTo			= GetDirectionStringTo
		--
		p.GetAvailableEmployment		= GetAvailableEmployment
		p.GetEmploymentValue			= GetEmploymentValue
		p.GetEmploymentSize				= GetEmploymentSize
		p.GetOutputPerYield				= GetOutputPerYield
		p.GetRuralEmploymentPow			= GetRuralEmploymentPow
		p.GetRuralEmploymentFactor		= GetRuralEmploymentFactor
		p.GetMaxEmployment				= GetMaxEmployment
		p.SetMaxEmployment				= SetMaxEmployment
		p.GetEmployed					= GetEmployed
		p.GetActivityFactor				= GetActivityFactor
		--
		p.GetPlotFertility				= GetPlotFertility
		p.GetEthnicityByNearestMajor	= GetEthnicityByNearestMajor
		p.GetBestCultureGroup			= GetBestCultureGroup
		p.GetpossibleCultureGroups		= GetpossibleCultureGroups
		p.AddPopulationForTribalVillage	= AddPopulationForTribalVillage
		p.GetSize						= GetSize
		p.GetPopulation					= GetPopulation
		p.ChangePopulation				= ChangePopulation
		p.GetMaxSize					= GetMaxSize
		p.GetPreviousPopulation			= GetPreviousPopulation
		p.ChangeUpperClass				= ChangeUpperClass
		p.ChangeMiddleClass				= ChangeMiddleClass
		p.ChangeLowerClass				= ChangeLowerClass
		p.ChangeSlaveClass				= ChangeSlaveClass
		p.GetUpperClass					= GetUpperClass
		p.GetMiddleClass				= GetMiddleClass
		p.GetLowerClass					= GetLowerClass
		p.GetSlaveClass					= GetSlaveClass
		p.GetPreviousUpperClass			= GetPreviousUpperClass
		p.GetPreviousMiddleClass		= GetPreviousMiddleClass
		p.GetPreviousLowerClass			= GetPreviousLowerClass
		p.GetPreviousSlaveClass			= GetPreviousSlaveClass
		p.GetPopulationClass			= GetPopulationClass
		p.GetPreviousPopulationClass	= GetPreviousPopulationClass
		p.ChangePopulationClass			= ChangePopulationClass
		p.GetPopulationDeathRate		= GetPopulationDeathRate
		p.GetBasePopulationDeathRate	= GetBasePopulationDeathRate
		p.GetPopulationBirthRate		= GetPopulationBirthRate
		p.GetBasePopulationBirthRate	= GetBasePopulationBirthRate
		p.GetBirthRate					= GetBirthRate
		p.GetDeathRate					= GetDeathRate
		p.GetMigration					= GetMigration
		--
		p.GetMaxStock					= GetMaxStock
		p.GetStock 						= GetStock
		p.GetResources					= GetResources
		p.GetPreviousStock				= GetPreviousStock
		p.ChangeStock 					= ChangeStock
		p.GetBaseVisibleResources		= GetBaseVisibleResources
		--
		p.GetRegions					= GetRegions
		p.SetRegions					= SetRegions
		--
		p.IsEOfRiver					= IsEOfRiver
		p.IsSEOfRiver					= IsSEOfRiver
		p.IsSWOfRiver					= IsSWOfRiver
		p.IsEdgeRiver					= IsEdgeRiver
		p.GetNextClockRiverPlot			= GetNextClockRiverPlot
		p.GetNextCounterClockRiverPlot	= GetNextCounterClockRiverPlot
		p.GetRiverPath					= GetRiverPath
		p.GetRiverPathFromEdge			= GetRiverPathFromEdge
		--
		p.GetPathToPlot					= GetPathToPlot
		p.GetRoadPath					= GetRoadPath
		p.GetSupplyPath					= GetSupplyPath
		--
		p.UpdateDataOnNewTurn			= UpdateDataOnNewTurn
		p.SetMigrationValues			= SetMigrationValues
		p.DoMigration					= DoMigration
		--
		p.IsInitializedForGCO			= true
	end

end


----------------------------------------------
-- Share functions for other contexts
----------------------------------------------
function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.GetPlotByIndex 			= GetPlotByIndex
	ExposedMembers.GCO.GetPlot 					= GetPlot
	ExposedMembers.GCO.InitializePlotFunctions 	= InitializePlotFunctions
	--
	ExposedMembers.GCO.GetPlotFromKey 			= GetPlotFromKey
	ExposedMembers.GCO.GetRiverPath				= GetRiverPath
	ExposedMembers.GCO.GetOppositeDirection		= GetOppositeDirection
	--
	ExposedMembers.GCO.GetCultureIDFromPlayerID	= GetCultureIDFromPlayerID
	--
	ExposedMembers.GCO.CleanPlotsData			= CleanPlotsData
	--
	ExposedMembers.PlotScript_Initialized 		= true
end
Initialize()

-- Culture Creation in Cities
		--[[
		local baseCulture = tonumber(GameInfo.GlobalParameters["CULTURE_CITY_BASE_PRODUCTION"].Value)
		local maxCulture = city:GetRealPopulation() --(city:GetPopulation() + GCO.GetCityCultureYield(self)) * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_CAPED_FACTOR"].Value)
		table.insert(textTable, "baseCulture = " .. tostring(baseCulture) ..", maxCulture ["..tostring(maxCulture).."] = (city:GetPopulation() ["..tostring(city:GetPopulation()) .." + GCO.GetCityCultureYield(self)[".. tostring(GCO.GetCityCultureYield(self)).."]) * CULTURE_CITY_CAPED_FACTOR["..tonumber(GameInfo.GlobalParameters["CULTURE_CITY_CAPED_FACTOR"].Value).."]")
		if self:GetTotalCulture() < maxCulture then -- don't add culture if above max, the excedent will decay each turn
			if plotCulture then
				-- First add culture for city owner				
				local cultureAdded = 0
				local value = self:GetCulture( city:GetOwner() )
				if tonumber(GameInfo.GlobalParameters["CULTURE_OUTPUT_USE_LOG"].Value) > 0 then
					cultureAdded = GCO.Round((city:GetSize() + GCO.GetCityCultureYield(self)) * math.log( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value) ,10))
				else
					cultureAdded = GCO.Round((city:GetSize() + GCO.GetCityCultureYield(self)) * math.sqrt( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value)))
				end	
				cultureAdded = cultureAdded + baseCulture
				table.insert(textTable, "- Player#".. tostring(cultureID)..", population= ".. tostring(city:GetPopulation())..", GCO.GetCityCultureYield(self) =".. tostring(GCO.GetCityCultureYield(self)) ..", math.log( value[".. tostring(value).."] * CULTURE_CITY_FACTOR["..tostring(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value).."], 10) = " .. tostring(math.log( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value) ,10)) ..", math.sqrt( value[".. tostring(value).."] * CULTURE_CITY_RATIO[".. tostring (GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value).."]" .. tostring(math.sqrt( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value))) .. ", baseCulture =" .. tostring(baseCulture) ..", cultureAdded = " ..tostring(cultureAdded))
				self:ChangeCulture(cityCultureID, cultureAdded)	
				
				-- Then update all other Culture
				for cultureID, value in pairs (plotCulture) do
					if value > 0 then
						local cultureAdded = 0
						if GetPlayerIDFromCultureID(cultureID) ~= city:GetOwner() then
							if tonumber(GameInfo.GlobalParameters["CULTURE_OUTPUT_USE_LOG"].Value) > 0 then
								cultureAdded = GCO.Round(city:GetSize() * math.log( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value) ,10))
							else
								cultureAdded = GCO.Round(city:GetSize() * math.sqrt( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value)))
							end
							self:ChangeCulture(cultureID, cultureAdded)
						end					
					end				
				end
			elseif self:GetOwner() == city:GetOwner() then -- initialize culture in city
				self:ChangeCulture(cityCultureID, baseCulture)
			end
		end
		--]]