--=====================================================================================--
--	FILE:	 CityScript.lua
--  Gedemon (2017)
--=====================================================================================--

print("Loading CityScript.lua...")

-----------------------------------------------------------------------------------------
-- Debug
-----------------------------------------------------------------------------------------

DEBUG_CITY_SCRIPT			= false

function ToggleCityDebug()
	DEBUG_CITY_SCRIPT = not DEBUG_CITY_SCRIPT
end


-----------------------------------------------------------------------------------------
-- ENUMS
-----------------------------------------------------------------------------------------
local ResourceUseType	= {	-- ENUM for resource use types (string as it it used as a key for saved table)
		Collect 	= "1",	-- Resources from map (ref = PlotID)
		Consume		= "2",	-- Used by population or local industries (ref = PopulationType or buildingID)
		Product		= "3",	-- Produced by buildings (industrie) (ref = buildingID)
		Import		= "4",	-- Received from foreign cities (ref = cityKey)
		Export		= "5",	-- Send to foreign cities (ref = cityKey)
		TransferIn	= "6",	-- Reveived from own cities (ref = cityKey)
		TransferOut	= "7",	-- Send to own cities (ref = cityKey)
		Supply		= "8",	-- Send to units (ref = unitKey)
		Pillage		= "9",	-- Received from units (ref = unitKey)
		OtherIn		= "10",	-- Received from undetermined source
		OtherOut	= "11",	-- Send to undetermined source
		Waste		= "12",	-- Destroyed (excedent, ...)
		Recruit		= "13",	-- Recruit Personnel
		Demobilize	= "14",	-- Personnel send back to civil life
		Stolen		= "15", -- Stolen by units (ref = unitKey)
}

local ReferenceType = { 	-- ENUM for reference types used to determine resource uses
	Unit			= 1,
	City			= 2,
	Plot			= 3,
	Population		= 4,
	Building		= 5,
	PopOrBuilding	= 99,
}

local SupplyRouteType	= {	-- ENUM for resource trade/transfer route types
		Trader 	= 1,
		Road	= 2,
		River	= 3,
		Coastal	= 4,
		Ocean	= 5,
		Airport	= 6
}

local NO_IMPROVEMENT 	= -1
local NO_FEATURE 		= -1

YieldTypes.INTERNAL_MAX		= GameInfo.Yields["YIELD_FAITH"].Index -- last yield from base game
YieldTypes.HEALTH			= GameInfo.Yields["YIELD_HEALTH"].Index
YieldTypes.UPPER_HOUSING	= GameInfo.Yields["YIELD_UPPER_HOUSING"].Index
YieldTypes.MIDDLE_HOUSING	= GameInfo.Yields["YIELD_MIDDLE_HOUSING"].Index
YieldTypes.LOWER_HOUSING	= GameInfo.Yields["YIELD_LOWER_HOUSING"].Index

local NeedsEffectType	= {	-- ENUM for effect types from Citizen Needs
	DeathRate	= 1,
	BirthRate	= 2,
	}

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local _cached				= {}	-- cached table to reduce calculations

local LinkedUnits 			= {}	-- temporary table to list all units linked to a city for supply
local UnitsSupplyDemand		= {}	-- temporary table to list all resources required by units
local CitiesForTransfer 	= {}	-- temporary table to list all cities connected via (internal) trade routes to a city
local CitiesForTrade		= {}	-- temporary table to list all cities connected via (external) trade routes to a city
local CitiesTransferDemand	= {}	-- temporary table to list all resources required by own cities
local CitiesTradeDemand		= {}	-- temporary table to list all resources required by other civilizations cities

local SupplyRouteLengthFactor = {		-- When calculating supply line efficiency relatively to length
		[SupplyRouteType.Trader]	= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_TRADER_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Road]		= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_ROAD_LENGTH_FACTOR"].Value),
		[SupplyRouteType.River]		= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_RIVER_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Coastal]	= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_SEA_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Ocean]		= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_SEA_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Airport]	= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_AIRPORT_LENGTH_FACTOR"].Value)
}

local ResourceUseTypeReference	= {	-- Helper to get the reference type for a specific UseType
	[ResourceUseType.Collect] 		= ReferenceType.Plot,
	[ResourceUseType.Consume] 		= ReferenceType.PopOrBuilding, -- special case, PopulationType (string) or BuildingID (number)
	[ResourceUseType.Product] 		= ReferenceType.Building,
	[ResourceUseType.Import] 		= ReferenceType.City,
	[ResourceUseType.Export] 		= ReferenceType.City,
	[ResourceUseType.TransferIn] 	= ReferenceType.City,
	[ResourceUseType.TransferOut] 	= ReferenceType.City,
	[ResourceUseType.Supply] 		= ReferenceType.Unit,
	[ResourceUseType.Pillage] 		= ReferenceType.Unit,
	[ResourceUseType.Recruit] 		= ReferenceType.Population,
	[ResourceUseType.Demobilize] 	= ReferenceType.Population,
	[ResourceUseType.Stolen] 		= ReferenceType.Unit,
}

-- Reference types for Resource usage
local NO_REFERENCE			= -1
local NO_REFERENCE_KEY		= tostring(NO_REFERENCE)
local RefPopulationUpper	= GameInfo.Populations["POPULATION_UPPER"].Type
local RefPopulationMiddle	= GameInfo.Populations["POPULATION_MIDDLE"].Type
local RefPopulationLower	= GameInfo.Populations["POPULATION_LOWER"].Type
local RefPopulationSlave	= GameInfo.Populations["POPULATION_SLAVE"].Type
local RefPopulationAll		= GameInfo.Populations["POPULATION_ALL"].Type

-- Error checking
for row in GameInfo.BuildingResourcesConverted() do
	--print( DEBUG_CITY_SCRIPT, row.BuildingType, row.ResourceCreated, row.ResourceType, row.MultiResRequired, row.MultiResCreated)
	if row.MultiResRequired and  row.MultiResCreated then
		print("ERROR : BuildingResourcesConverted contains a row with both MultiResRequired and MultiResCreated set to true:", row.BuildingType, row.ResourceCreated, row.ResourceType, row.MultiResRequired, row.MultiResCreated)
	end
end

local BuildingStock			= {}		-- cached table with stock value of a building for a specific resource
local ResourceStockage		= {}		-- cached table with all the buildings that can stock a specific resource
for row in GameInfo.BuildingStock() do
	local buildingID = GameInfo.Buildings[row.BuildingType].Index
	local resourceID = GameInfo.Resources[row.ResourceType].Index
	if not BuildingStock[buildingID] then BuildingStock[buildingID] = {} end
	BuildingStock[buildingID][resourceID] = row.Stock
	if not ResourceStockage[resourceID] then ResourceStockage[resourceID] = {} end
	table.insert (ResourceStockage[resourceID], buildingID)
end

local ResourceUsage			= {}		-- cached table with minimum percentage of stock in a city before supply (units), transfer (cities), export (foreign cities) or convert (local industries) a specific resource
for row in GameInfo.ResourceStockUsage() do
	local resourceID = GameInfo.Resources[row.ResourceType].Index
	ResourceUsage[resourceID] = {
		MinPercentLeftToSupply 		= row.MinPercentLeftToSupply,
		MinPercentLeftToTransfer 	= row.MinPercentLeftToTransfer,
		MinPercentLeftToExport 		= row.MinPercentLeftToExport,
		MinPercentLeftToConvert 	= row.MinPercentLeftToConvert,
		MaxPercentLeftToRequest		= row.MaxPercentLeftToRequest,
		MaxPercentLeftToImport		= row.MaxPercentLeftToImport
	}
end

local BuildingYields		= {}		-- cached table with all the buildings that yield Upper/Middle/Lower Housing or Health
for row in GameInfo.Building_YieldChanges() do
	local YieldID = GameInfo.Yields[row.YieldType].Index
	if YieldID > YieldTypes.INTERNAL_MAX then
		local buildingID = GameInfo.Buildings[row.BuildingType].Index
		if not BuildingYields[buildingID] then BuildingYields[buildingID] = {} end
		BuildingYields[buildingID][YieldID] = row.YieldChange
	end
end


local IsImprovementForResource		= {} -- cached table to check if an improvement is meant for a resource
for row in GameInfo.Improvement_ValidResources() do
	local improvementID = GameInfo.Improvements[row.ImprovementType].Index
	local resourceID 	= GameInfo.Resources[row.ResourceType].Index
	if not IsImprovementForResource[improvementID] then IsImprovementForResource[improvementID] = {} end
	IsImprovementForResource[improvementID][resourceID] = true
end

local IsImprovementForFeature		= {} -- cached table to check if an improvement is meant for a feature
for row in GameInfo.Improvement_ValidFeatures() do
	local improvementID = GameInfo.Improvements[row.ImprovementType].Index
	local featureID 	= GameInfo.Features[row.FeatureType].Index
	if not IsImprovementForFeature[improvementID] then IsImprovementForFeature[improvementID] = {} end
	IsImprovementForFeature[improvementID][featureID] = true
end

local FeatureResources				= {} -- cached table to list resources produced by a feature
for row in GameInfo.FeatureResourcesProduced() do
	local featureID		= GameInfo.Features[row.FeatureType].Index
	local resourceID 	= GameInfo.Resources[row.ResourceType].Index
	if not FeatureResources[featureID] then FeatureResources[featureID] = {} end
	table.insert(FeatureResources[featureID], {[resourceID] = row.NumPerFeature})
end

--[[
local EquipmentResources	= {}
for row in GameInfo.UnitEquipmentResources() do
	local equipmentID 	= GameInfo.UnitEquipments[row.EquipmentType].Index
	local resourceID 	= GameInfo.Resources[row.ResourceType].Index
	if not EquipmentResources[equipmentID] then EquipmentResources[equipmentID] = {} end
	table.insert (EquipmentResources[equipmentID], resourceID)
end
--]]

local IncomeExportPercent			= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_EXPORT_PERCENT"].Value)
local IncomeImportPercent			= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_IMPORT_PERCENT"].Value)

local bUseRealYears					= (tonumber(GameInfo.GlobalParameters["CITY_USE_REAL_YEARS_FOR_GROWTH_RATE"].Value) == 1)
local GrowthRateBaseYears			= tonumber(GameInfo.GlobalParameters["CITY_GROWTH_RATE_BASE_YEARS"].Value)

local ClassMinimalGrowthRate		= tonumber(GameInfo.GlobalParameters["CITY_CLASS_MINIMAL_GROWTH_RATE"].Value)
local ClassMaximalGrowthRate		= tonumber(GameInfo.GlobalParameters["CITY_CLASS_MAXIMAL_GROWTH_RATE"].Value)

local StartingPopulationBonus		= tonumber(GameInfo.GlobalParameters["CITY_STARTING_POPULATION_BONUS"].Value)

local UpperClassID 					= GameInfo.Populations["POPULATION_UPPER"].Index
local MiddleClassID 				= GameInfo.Populations["POPULATION_MIDDLE"].Index
local LowerClassID 					= GameInfo.Populations["POPULATION_LOWER"].Index
local SlaveClassID 					= GameInfo.Populations["POPULATION_SLAVE"].Index
local AllClassID 					= GameInfo.Populations["POPULATION_ALL"].Index

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

local UpperClassMaxPercent		 	= tonumber(GameInfo.GlobalParameters["CITY_BASE_UPPER_CLASS_MAX_PERCENT"].Value)
local UpperClassMinPercent 			= tonumber(GameInfo.GlobalParameters["CITY_BASE_UPPER_CLASS_MIN_PERCENT"].Value)
local MiddleClassMaxPercent 		= tonumber(GameInfo.GlobalParameters["CITY_BASE_MIDDLE_CLASS_MAX_PERCENT"].Value)
local MiddleClassMinPercent 		= tonumber(GameInfo.GlobalParameters["CITY_BASE_MIDDLE_CLASS_MIN_PERCENT"].Value)
local LowerClassMaxPercent 			= tonumber(GameInfo.GlobalParameters["CITY_BASE_LOWER_CLASS_MAX_PERCENT"].Value)
local LowerClassMinPercent 			= tonumber(GameInfo.GlobalParameters["CITY_BASE_LOWER_CLASS_MIN_PERCENT"].Value)

local WealthUpperRatio				= tonumber(GameInfo.GlobalParameters["CITY_WEALTH_UPPER_CLASS_RATIO"].Value)
local WealthMiddleRatio				= tonumber(GameInfo.GlobalParameters["CITY_WEALTH_MIDDLE_CLASS_RATIO"].Value)
local WealthLowerRatio				= tonumber(GameInfo.GlobalParameters["CITY_WEALTH_LOWER_CLASS_RATIO"].Value)
local WealthSlaveRatio				= tonumber(GameInfo.GlobalParameters["CITY_WEALTH_SLAVE_CLASS_RATIO"].Value)

local MaterielProductionPerSize 	= tonumber(GameInfo.GlobalParameters["CITY_MATERIEL_PRODUCTION_PER_SIZE"].Value)
local ResourceStockPerSize 			= tonumber(GameInfo.GlobalParameters["CITY_STOCK_PER_SIZE"].Value)
local FoodStockPerSize 				= tonumber(GameInfo.GlobalParameters["CITY_FOOD_STOCK_PER_SIZE"].Value)
local EquipmentBaseStock 			= tonumber(GameInfo.GlobalParameters["CITY_STOCK_EQUIPMENT"].Value)

local MinPercentLeftToSupply 		= tonumber(GameInfo.GlobalParameters["CITY_MIN_PERCENT_LEFT_TO_SUPPLY"].Value)
local MinPercentLeftToTransfer		= tonumber(GameInfo.GlobalParameters["CITY_MIN_PERCENT_LEFT_TO_TRANSFER"].Value)
local MinPercentLeftToExport		= tonumber(GameInfo.GlobalParameters["CITY_MIN_PERCENT_LEFT_TO_EXPORT"].Value)
local MinPercentLeftToConvert		= tonumber(GameInfo.GlobalParameters["CITY_MIN_PERCENT_LEFT_TO_CONVERT"].Value)

local MaxPercentLeftToRequest		= tonumber(GameInfo.GlobalParameters["CITY_MAX_PERCENT_LEFT_TO_REQUEST"].Value)
local MaxPercentLeftToImport		= tonumber(GameInfo.GlobalParameters["CITY_MAX_PERCENT_LEFT_TO_IMPORT"].Value)

local UpperClassToPersonnelRatio	= tonumber(GameInfo.GlobalParameters["CITY_UPPER_CLASS_TO_PERSONNEL_RATIO"].Value)
local MiddleClassToPersonnelRatio	= tonumber(GameInfo.GlobalParameters["CITY_MIDDLE_CLASS_TO_PERSONNEL_RATIO"].Value)
local LowerClassToPersonnelRatio	= tonumber(GameInfo.GlobalParameters["CITY_LOWER_CLASS_TO_PERSONNEL_RATIO"].Value)
local PersonnelHighRankRatio		= tonumber(GameInfo.GlobalParameters["ARMY_PERSONNEL_HIGH_RANK_RATIO"].Value)
local PersonnelMiddleRankRatio		= tonumber(GameInfo.GlobalParameters["ARMY_PERSONNEL_MIDDLE_RANK_RATIO"].Value)
local PersonnelToUpperClassRatio	= tonumber(GameInfo.GlobalParameters["CITY_PERSONNEL_TO_UPPER_CLASS_RATIO"].Value)
local PersonnelToMiddleClassRatio	= tonumber(GameInfo.GlobalParameters["CITY_PERSONNEL_TO_MIDDLE_CLASS_RATIO"].Value)

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

local BaseImprovementMultiplier	= tonumber(GameInfo.GlobalParameters["RESOURCE_BASE_IMPROVEMENT_MULTIPLIER"].Value)
local BaseCollectCostMultiplier	= tonumber(GameInfo.GlobalParameters["RESOURCE_BASE_COLLECT_COST_MULTIPLIER"].Value)
local ImprovementCostRatio		= tonumber(GameInfo.GlobalParameters["RESOURCE_IMPROVEMENT_COST_RATIO"].Value)
local NotWorkedCostMultiplier	= tonumber(GameInfo.GlobalParameters["RESOURCE_NOT_WORKED_COST_MULTIPLIER"].Value)

local MaxCostVariationPercent 	= tonumber(GameInfo.GlobalParameters["RESOURCE_COST_MAX_VARIATION_PERCENT"].Value)

local ResourceTransportMaxCost	= tonumber(GameInfo.GlobalParameters["RESOURCE_TRANSPORT_MAX_COST"].Value)

local directReinforcement = { 				-- cached table with "resources" that are directly transfered to units
		[foodResourceID] 		= true,
		[materielResourceID] 	= true,
		[horsesResourceID] 		= true,
		[personnelResourceID] 	= true,
		[medicineResourceID] 	= true,
	}

--local notAvailableToExport = {} 			-- cached table with "resources" that can't be exported to other Civilizations
--notAvailableToExport[personnelResourceID] 	= true

local baseFoodStock 			= tonumber(GameInfo.GlobalParameters["CITY_BASE_FOOD_STOCK"].Value)

local lightRationing 			= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_LIGHT_RATIO"].Value)
local mediumRationing 			= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_MEDIUM_RATIO"].Value)
local heavyRationing 			= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_HEAVY_RATIO"].Value)
local Starvation	 			= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_STARVATION"].Value)
local turnsToFamineLight 		= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_TO_FAMINE_LIGHT"].Value)
local turnsToFamineMedium 		= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_TO_FAMINE_MEDIUM"].Value)
local turnsToFamineHeavy 		= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_TO_FAMINE_HEAVY"].Value)
local RationingTurnsLocked		= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_LOCKED"].Value)
local birthRateLightRationing 	= tonumber(GameInfo.GlobalParameters["CITY_LIGHT_RATIONING_BIRTH_PERCENT"].Value)
local birthRateMediumRationing 	= tonumber(GameInfo.GlobalParameters["CITY_MEDIUM_RATIONING_BIRTH_PERCENT"].Value)
local birthRateHeavyRationing	= tonumber(GameInfo.GlobalParameters["CITY_HEAVY_RATIONING_BIRTH_PERCENT"].Value)
local birthRateStarvation		= tonumber(GameInfo.GlobalParameters["CITY_STARVATION_BIRTH_PERCENT"].Value)
local deathRateLightRationing 	= tonumber(GameInfo.GlobalParameters["CITY_LIGHT_RATIONING_DEATH_PERCENT"].Value)
local deathRateMediumRationing 	= tonumber(GameInfo.GlobalParameters["CITY_MEDIUM_RATIONING_DEATH_PERCENT"].Value)
local deathRateHeavyRationing	= tonumber(GameInfo.GlobalParameters["CITY_HEAVY_RATIONING_DEATH_PERCENT"].Value)
local deathRateStarvation		= tonumber(GameInfo.GlobalParameters["CITY_STARVATION_DEATH_PERCENT"].Value)

-- Floating Texts LOD
local FLOATING_TEXT_NONE 	= 0
local FLOATING_TEXT_SHORT 	= 1
local FLOATING_TEXT_LONG 	= 2
local floatingTextLevel 	= FLOATING_TEXT_SHORT

-----------------------------------------------------------------------------------------
-- Initialize
-----------------------------------------------------------------------------------------
local GCO = {}
function InitializeUtilityFunctions()
	GCO 		= ExposedMembers.GCO		-- contains functions from other contexts
	Calendar 	= ExposedMembers.Calendar
	Dprint 		= GCO.Dprint
	print("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.CityData 		= GCO.LoadTableFromSlot("CityData") or {}
	--ExposedMembers.CityCachedData	= {}	-- cached table to reduce calculations
end

function Initialize() -- called immediatly after loading this file
	Events.CityAddedToMap.Add( InitializeCityFunctions ) -- first as InitializeCity() may require those functions
	Events.CityAddedToMap.Add( InitializeCity )
	ShareFunctions()
end

function SaveTables()
	print("--------------------------- Saving CityData ---------------------------")
	
	GCO.StartTimer("Saving And Checking CityData")
	GCO.SaveTableToSlot(ExposedMembers.CityData, "CityData")
end
LuaEvents.SaveTables.Add(SaveTables)

function CheckSave()
	print("Checking Saved Table...")
	if GCO.AreSameTables(ExposedMembers.CityData, GCO.LoadTableFromSlot("CityData")) then
		print("- Tables are identical")
	else
		print("ERROR: reloading saved table show differences with actual table !")
		LuaEvents.StopAuToPlay()
		CompareData(ExposedMembers.CityData, GCO.LoadTableFromSlot("CityData"))
	end
	GCO.ShowTimer("Saving And Checking CityData")
end
LuaEvents.SaveTables.Add(CheckSave)

function CompareData(data1, data2)
	print("comparing...")
	for key, data in pairs(data1) do
		for k, v in pairs (data) do
			if not data2[key] then
				print("- reloaded table is nil for key = ", key)
			elseif data2[key] and not data2[key][k] then			
				print("- no value for key = ", key, " entry =", k)
			elseif data2[key] and type(v) ~= "table" and v ~= data2[key][k] then
				print("- different value for key = ", key, " entry =", k, " Data1 value = ", v, type(v), " Data2 value = ", data2[key][k], type(data2[key][k]) )
			end
		end
	end
	print("no more data to compare...")
end

-----------------------------------------------------------------------------------------
-- Initialize Cities
-----------------------------------------------------------------------------------------
function RegisterNewCity(playerID, city)

	local cityKey 			= city:GetKey()
	local personnel 		= city:GetMaxPersonnel()
	local totalPopulation 	= GCO.Round(GetPopulationPerSize(city:GetSize()) + StartingPopulationBonus)
	local upperClass		= GCO.Round(totalPopulation * GCO.GetPlayerUpperClassPercent(playerID) / 100) -- can't use city:GetMaxUpperClass() before filling ExposedMembers.CityData[cityKey]
	local middleClass		= GCO.Round(totalPopulation * GCO.GetPlayerMiddleClassPercent(playerID) / 100)
	local lowerClass		= totalPopulation - (upperClass + middleClass)
	local startingFood		= GCO.Round(tonumber(GameInfo.GlobalParameters["CITY_BASE_FOOD_STOCK"].Value) / 2)
	local startingMateriel	= GCO.Round(tonumber(GameInfo.GlobalParameters["CITY_STOCK_PER_SIZE"].Value) * city:GetSize() / 2)
	local baseFoodCost 		= GCO.GetBaseResourceCost(foodResourceID)
	local turnKey 			= GCO.GetTurnKey()

	ExposedMembers.CityData[cityKey] = {
		cityID 					= city:GetID(),
		playerID 				= playerID,
		WoundedPersonnel 		= 0,
		Prisoners				= GCO.CreateEverAliveTableWithDefaultValue(0),
		Stock					= { [turnKey] = {[foodResourceKey] = startingFood, [personnelResourceKey] = personnel, [materielResourceKey] = startingMateriel} },
		ResourceCost			= { [turnKey] = {[foodResourceKey] = baseFoodCost, } },
		ResourceUse				= { [turnKey] = { } }, -- [ResourceID] = { ResourceUseType.Collected = { [plotID] = 0, }, ResourceUseType.Consummed = { [buildingID] = 0, [PopulationType] = 0, }, ...)
		Population				= { [turnKey] = { UpperClass = upperClass, MiddleClass	= middleClass, LowerClass = lowerClass,	Slaves = 0} },
		FoodRatio				= 1,
		FoodRatioTurn			= Game.GetCurrentGameTurn(),
	}

	LuaEvents.NewCityCreated()
end

function InitializeCity(playerID, cityID) -- add to Events.CityAddedToMap in initialize()
	local city = CityManager.GetCity(playerID, cityID)
	if city then
		local cityKey = city:GetKey()
		if ExposedMembers.CityData[cityKey] then
			-- city already registered, don't add it again...
			Dprint( DEBUG_CITY_SCRIPT, "  - ".. city:GetName() .." is already registered")
			return
		end

		Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
		Dprint( DEBUG_CITY_SCRIPT, "Initializing new city (".. city:GetName() ..") for player #".. tostring(playerID).. " id#" .. tostring(city:GetID()))
		RegisterNewCity(playerID, city)		
		
		local pCityBuildQueue = city:GetBuildQueue();
		pCityBuildQueue:CreateIncompleteBuilding(GameInfo.Buildings["BUILDING_CENTRAL_SQUARE"].Index, 100);
		
	else
		Dprint( DEBUG_CITY_SCRIPT, "- WARNING : tried to initialize nil city for player #".. tostring(playerID))
	end

end

function UpdateCapturedCity(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)
	local originalCityKey 	= GetCityKeyFromIDs(originalCityID, originalOwnerID)
	local newCityKey 		= GetCityKeyFromIDs(newCityID, newOwnerID)
	if ExposedMembers.CityData[originalCityKey] then
		originalData = ExposedMembers.CityData[originalCityKey]

		if ExposedMembers.CityData[newCityKey] then
			local city = CityManager.GetCity(newOwnerID, newCityID)
			Dprint( DEBUG_CITY_SCRIPT, "Updating captured city (".. city:GetName() ..") for player #".. tostring(newOwnerID).. " id#" .. tostring(city:GetID()))
			Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")

			ExposedMembers.CityData[newCityKey].WoundedPersonnel 	= 0
			for civID, value in pairs(originalData.Prisoners) do
				ExposedMembers.CityData[newCityKey].Prisoners[civID] = value
			end
			ExposedMembers.CityData[newCityKey].Prisoners[tostring(originalOwnerID)] = originalData.WoundedPersonnel
			for turnKey, data in pairs(originalData.Stock) do
				ExposedMembers.CityData[newCityKey].Stock[turnKey] = {}
				for resourceKey, value in pairs(data) do
					if turnKey == GCO.GetTurnKey() and resourceKey == personnelResourceKey then
						ExposedMembers.CityData[newCityKey].Prisoners[tostring(originalOwnerID)] = ExposedMembers.CityData[newCityKey].Prisoners[tostring(originalOwnerID)] + originalData.Stock[turnKey][personnelResourceKey]
					else
						ExposedMembers.CityData[newCityKey].Stock[turnKey][resourceKey] = value
					end
				end
			end
			for turnKey, data in pairs(originalData.ResourceCost) do
				ExposedMembers.CityData[newCityKey].ResourceCost[turnKey] = {}
				for resourceKey, value in pairs(data) do
					ExposedMembers.CityData[newCityKey].ResourceCost[turnKey][resourceKey] = value
				end
			end
			ExposedMembers.CityData[newCityKey].UpperClass 			= originalData.UpperClass
			ExposedMembers.CityData[newCityKey].MiddleClass 		= originalData.MiddleClass
			ExposedMembers.CityData[newCityKey].LowerClass 			= originalData.LowerClass
			ExposedMembers.CityData[newCityKey].Slaves 				= originalData.Slaves
		else
			print("ERROR: no data for new City on capture, cityID #", newCityID, "playerID #", newOwnerID)
		end
	else
		print("ERROR: no data for original City on capture, cityID #", originalCityID, "playerID #", originalOwnerID)
	end
end
LuaEvents.CapturedCityInitialized.Add( UpdateCapturedCity ) -- called in Events.CityInitialized (after Events.CityAddedToMap and InitializeCity...)

-- for debugging
function ShowCityData()
	local Stats = {
		["Stock"] 			= true,
		["ResourceCost"] 	= true,
		["ResourceUse"] 	= true,
		["Population"]	 	= true
		}
	local count = 0
	for cityKey, data in pairs(ExposedMembers.CityData) do
		print(cityKey, data)
		for k, v in pairs (data) do
			print("-", k, v)
			count = count + 1
			if k == "Prisoners" then
				for id, num in pairs (v) do
					print("-", "-", id, num)
					count = count + 1
				end
			end
			if Stats[k] then
				for turnkey, data2 in pairs(v) do
					print("-", "-", turnkey)
					for id, num in pairs(data2) do
						print("-", "-", "-", id, num)
						count = count + 1
					end
				end
			end
		end
	end
	print("#entry = ", count)
end


-----------------------------------------------------------------------------------------
-- Utils functions
-----------------------------------------------------------------------------------------
function GetPopulationPerSize(size)
	return GCO.Round(math.pow(size, 2.8) * 1000)
end


-----------------------------------------------------------------------------------------
-- City functions
-----------------------------------------------------------------------------------------
function GetCityKeyFromIDs(cityID, ownerID)
	return cityID..","..ownerID
end

function GetKey(self)
	return GetCityKeyFromIDs (self:GetID(), self:GetOwner())
end

function GetCityFromKey ( cityKey )
	if ExposedMembers.CityData[cityKey] then
		local city = GetCity(ExposedMembers.CityData[cityKey].playerID, ExposedMembers.CityData[cityKey].cityID)
		if city then
			return city
		else
			print("- WARNING: city is nil for GetCityFromKey(".. tostring(cityKey)..")")
			print("--- UnitId = " .. ExposedMembers.CityData[cityKey].cityID ..", playerID = " .. ExposedMembers.CityData[cityKey].playerID)
		end
	else
		print("- WARNING: ExposedMembers.CityData[cityKey] is nil for GetCityFromKey(".. tostring(cityKey)..")")
	end
end

function GetWealth(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetWealth()
	elseif not _cached[cityKey].Wealth then
		self:SetWealth()
	end
	return _cached[cityKey].Wealth
end

function SetWealth(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then _cached[cityKey] = {} end
	local wealth = (self:GetUpperClass()*WealthUpperRatio + self:GetMiddleClass()*WealthMiddleRatio + self:GetLowerClass()*WealthLowerRatio + self:GetSlaveClass()*WealthSlaveRatio) / self:GetRealPopulation()
	_cached[cityKey].Wealth = GCO.ToDecimals(wealth)
end


-----------------------------------------------------------------------------------------
-- Population functions
-----------------------------------------------------------------------------------------
function GetRealPopulation(self) -- the original city:GetPopulation() returns city size
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetRealPopulation()
	elseif not _cached[cityKey].TotalPopulation then
		self:SetRealPopulation()
	end
	return _cached[cityKey].TotalPopulation
end

function SetRealPopulation(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then _cached[cityKey] = {} end
	local totalPopulation = self:GetUpperClass() + self:GetMiddleClass() + self:GetLowerClass() + self:GetSlaveClass()
	_cached[cityKey].TotalPopulation = totalPopulation
end

function GetRealPopulationVariation(self)
	local previousPop = self:GetPreviousUpperClass() + self:GetPreviousMiddleClass() + self:GetPreviousLowerClass() + self:GetPreviousSlaveClass()
	return self:GetRealPopulation() - previousPop
end

function GetSize(self) -- for code consistency
	return self:GetPopulation()
end

function GetBirthRate(self)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	local birthRate = BaseBirthRate
	local cityRationning = cityData.FoodRatio
	if 		cityRationning <= Starvation 		then
		birthRate = birthRate - (birthRate * birthRateStarvation/100)

	elseif 	cityRationning <= heavyRationing 	then
		birthRate = birthRate - (birthRate * birthRateHeavyRationing/100)

	elseif cityRationning <= mediumRationing 	then
		birthRate = birthRate - (birthRate * birthRateMediumRationing/100)

	elseif cityRationning <= lightRationing 	then
		birthRate = birthRate - (birthRate * birthRateLightRationing/100)
	end
	return birthRate
end

function GetDeathRate(self)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	local deathRate = BaseDeathRate
	local cityRationning = cityData.FoodRatio

	if 		cityRationning <= Starvation 		then
		deathRate = deathRate + (deathRate * deathRateStarvation/100)

	elseif 	cityRationning <= heavyRationing 	then
		deathRate = deathRate + (deathRate * deathRateHeavyRationing/100)

	elseif 	cityRationning <= mediumRationing 	then
		deathRate = deathRate + (deathRate * deathRateMediumRationing/100)

	elseif 	cityRationning <= lightRationing 	then
		deathRate = deathRate + (deathRate * deathRateLightRationing/100)
	end
	return deathRate
end

function GetBasePopulationDeathRate(self, populationID)
	return self:GetDeathRate() * DeathRateFactor[populationID]
end

function GetPopulationDeathRate(self, populationID)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetPopulationDeathRate(populationID)
	elseif not _cached[cityKey].DeathRate then
		self:SetPopulationDeathRate(populationID)
	elseif not _cached[cityKey].DeathRate[populationID] then
		self:SetPopulationDeathRate(populationID)
	end
	return _cached[cityKey].DeathRate[populationID]
end

function SetPopulationDeathRate(self, populationID)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then _cached[cityKey] = {} end
	if not _cached[cityKey].DeathRate then _cached[cityKey].DeathRate = {} end
	local popDeathRate = self:GetBasePopulationDeathRate(populationID)
	
	if _cached[cityKey].NeedsEffects and _cached[cityKey].NeedsEffects[populationID] then
		local data = _cached[cityKey].NeedsEffects[populationID][NeedsEffectType.DeathRate]
		popDeathRate = popDeathRate + GCO.TableSummation(data)
	end
	
	_cached[cityKey].DeathRate[populationID] = popDeathRate
end

function GetBasePopulationBirthRate(self, populationID)
	return self:GetBirthRate() * BirthRateFactor[populationID]
end

function GetPopulationBirthRate(self, populationID)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetPopulationBirthRate(populationID)
	elseif not _cached[cityKey].BirthRate then
		self:SetPopulationBirthRate(populationID)
	elseif not _cached[cityKey].BirthRate[populationID] then
		self:SetPopulationBirthRate(populationID)
	end
	return _cached[cityKey].BirthRate[populationID]
end

function SetPopulationBirthRate(self, populationID)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then _cached[cityKey] = {} end
	if not _cached[cityKey].BirthRate then _cached[cityKey].BirthRate = {} end
	local popBirthRate = self:GetBasePopulationBirthRate(populationID)
	
	if _cached[cityKey].NeedsEffects and _cached[cityKey].NeedsEffects[populationID] then
		local data = _cached[cityKey].NeedsEffects[populationID][NeedsEffectType.BirthRate]
		popBirthRate = popBirthRate + GCO.TableSummation(data)
	end
	
	_cached[cityKey].BirthRate[populationID] = popBirthRate
end

function ChangeSize(self)
	Dprint( DEBUG_CITY_SCRIPT, "check change size to ", self:GetSize()+1, "required =", GetPopulationPerSize(self:GetSize()+1), "current =", self:GetRealPopulation())
	Dprint( DEBUG_CITY_SCRIPT, "check change size to ", self:GetSize()-1, "required =", GetPopulationPerSize(self:GetSize()-1), "current =", self:GetRealPopulation())
	if GetPopulationPerSize(self:GetSize()-1) > self:GetRealPopulation() then
		self:ChangePopulation(-1) -- (-1, true) ?
	elseif GetPopulationPerSize(self:GetSize()+1) < self:GetRealPopulation() then
		self:ChangePopulation(1)
	end
end

function GetMaxUpperClass(self)
	local maxPercent = UpperClassMaxPercent
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_UPPER" and row.EffectType == "CLASS_MAX_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				maxPercent = maxPercent + row.EffectValue
			end
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "Max Upper Class %", maxPercent)
	return GCO.Round(self:GetRealPopulation() * maxPercent / 100)
end

function GetMinUpperClass(self)
	local minPercent = UpperClassMinPercent
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_UPPER" and row.EffectType == "CLASS_MIN_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				minPercent = minPercent + row.EffectValue
			end
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "Min Upper Class %", minPercent)
	return GCO.Round(self:GetRealPopulation() * minPercent / 100)
end

function GetMaxMiddleClass(self)
	local maxPercent = MiddleClassMaxPercent
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_MIDDLE" and row.EffectType == "CLASS_MAX_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				maxPercent = maxPercent + row.EffectValue
			end
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "Max Middle Class %", maxPercent)
	return GCO.Round(self:GetRealPopulation() * maxPercent / 100)
end

function GetMinMiddleClass(self)
	local minPercent = MiddleClassMinPercent
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_MIDDLE" and row.EffectType == "CLASS_MIN_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				minPercent = minPercent + row.EffectValue
			end
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "Min Middle Class %", minPercent)
	return GCO.Round(self:GetRealPopulation() * minPercent / 100)
end

function GetMaxLowerClass(self)
	local maxPercent = LowerClassMaxPercent
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_LOWER" and row.EffectType == "CLASS_MAX_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				maxPercent = maxPercent + row.EffectValue
			end
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "Max Lower Class %", maxPercent)
	return GCO.Round(self:GetRealPopulation() * maxPercent / 100)
end

function GetMinLowerClass(self)
	local minPercent = LowerClassMinPercent
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_LOWER" and row.EffectType == "CLASS_MIN_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				minPercent = minPercent + row.EffectValue
			end
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "Min Lower Class %", minPercent)
	return GCO.Round(self:GetRealPopulation() * minPercent / 100)
end

function ChangeUpperClass(self, value)
	local cityKey 	= self:GetKey()
	local turnKey 	= GCO.GetTurnKey()
	local previous 	= ExposedMembers.CityData[cityKey].Population[turnKey].UpperClass
	ExposedMembers.CityData[cityKey].Population[turnKey].UpperClass = math.max(0 , previous + value)
end

function ChangeMiddleClass(self, value)
	local cityKey = self:GetKey()
	local turnKey 	= GCO.GetTurnKey()
	local previous 	= ExposedMembers.CityData[cityKey].Population[turnKey].MiddleClass
	ExposedMembers.CityData[cityKey].Population[turnKey].MiddleClass = math.max(0 , previous + value)
end

function ChangeLowerClass(self, value)
	local cityKey = self:GetKey()
	local turnKey 	= GCO.GetTurnKey()
	local previous 	= ExposedMembers.CityData[cityKey].Population[turnKey].LowerClass
	ExposedMembers.CityData[cityKey].Population[turnKey].LowerClass = math.max(0 , previous + value)
end

function ChangeSlaveClass(self, value)
	local cityKey = self:GetKey()
	local turnKey 	= GCO.GetTurnKey()
	local previous 	= ExposedMembers.CityData[cityKey].Population[turnKey].Slaves
	ExposedMembers.CityData[cityKey].Population[turnKey].Slaves = math.max(0 , previous + value)
end

function GetUpperClass(self)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	return ExposedMembers.CityData[cityKey].Population[turnKey].UpperClass or 0
end

function GetMiddleClass(self)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	return ExposedMembers.CityData[cityKey].Population[turnKey].MiddleClass or 0
end

function GetLowerClass(self)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	return ExposedMembers.CityData[cityKey].Population[turnKey].LowerClass or 0
end

function GetSlaveClass(self)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	return ExposedMembers.CityData[cityKey].Population[turnKey].Slaves or 0
end

function GetPopulationClass(self, populationID)
	if populationID == UpperClassID 	then return self:GetUpperClass() end
	if populationID == MiddleClassID 	then return self:GetMiddleClass() end
	if populationID == LowerClassID 	then return self:GetLowerClass() end
	if populationID == SlaveClassID 	then return self:GetSlaveClass() end
	if populationID == AllClassID 		then return self:GetRealPopulation() end
	print("ERROR : can't find population class for ID = ", populationID)
	return 0
end

function ChangePopulationClass(self, populationID, value)
	if populationID == UpperClassID 	then return self:ChangeUpperClass(value) end
	if populationID == MiddleClassID 	then return self:ChangeMiddleClass(value) end
	if populationID == LowerClassID 	then return self:ChangeLowerClass(value) end
	if populationID == SlaveClassID 	then return self:ChangeSlaveClass(value) end
	print("ERROR : can't find population class for ID = ", populationID)
end

function GetPreviousUpperClass(self)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetPreviousTurnKey()
	if ExposedMembers.CityData[cityKey].Population[turnKey] then -- for new city this will be nil
		return ExposedMembers.CityData[cityKey].Population[turnKey].UpperClass or 0
	else
		return self:GetUpperClass()
	end
end

function GetPreviousMiddleClass(self )
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetPreviousTurnKey()
	if ExposedMembers.CityData[cityKey].Population[turnKey] then -- for new city this will be nil
		return ExposedMembers.CityData[cityKey].Population[turnKey].MiddleClass or 0
	else
		return self:GetMiddleClass()
	end
end

function GetPreviousLowerClass(self)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetPreviousTurnKey()
	if ExposedMembers.CityData[cityKey].Population[turnKey] then -- for new city this will be nil
		return ExposedMembers.CityData[cityKey].Population[turnKey].LowerClass or 0
	else
		return self:GetLowerClass()
	end
end

function GetPreviousSlaveClass(self)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetPreviousTurnKey()
	if ExposedMembers.CityData[cityKey].Population[turnKey] then -- for new city this will be nil
		return ExposedMembers.CityData[cityKey].Population[turnKey].Slaves or 0
	else
		return self:GetSlaveClass()
	end
end

-----------------------------------------------------------------------------------------
-- Resources Transfers
-----------------------------------------------------------------------------------------
function UpdateLinkedUnits(self)
	Dprint( DEBUG_CITY_SCRIPT, "Updating Linked Units...")
	local selfKey 				= self:GetKey()
	LinkedUnits[selfKey] 		= {}
	UnitsSupplyDemand[selfKey] 	= { Resources = {}, NeedResources = {}, PotentialResources = {}} -- NeedResources : Number of units requesting a resource type

	for unitKey, data in pairs(ExposedMembers.UnitData) do
		local efficiency = data.SupplyLineEfficiency
		if data.SupplyLineCityKey == self:GetKey() and efficiency > 0 then
			local unit = GCO.GetUnit(data.playerID, data.unitID)
			if unit then
				LinkedUnits[selfKey][unit] = {NeedResources = {}}
				local requirements 	= unit:GetRequirements()
				--[[
				if requirements.Equipment > 0 then
					UnitsSupplyDemand[selfKey].Equipment 		= ( UnitsSupplyDemand[selfKey].Equipment 		or 0 ) + GCO.Round(requirements.Equipment*efficiency/100)
					UnitsSupplyDemand[selfKey].NeedEquipment 	= ( UnitsSupplyDemand[selfKey].NeedEquipment 	or 0 ) + 1
					LinkedUnits[selfKey][unit].NeedEquipment	= true
				end
				--]]

				for resourceID, value in pairs(requirements.Resources) do
					if value > 0 then
						UnitsSupplyDemand[selfKey].Resources[resourceID] 		= ( UnitsSupplyDemand[selfKey].Resources[resourceID] 		or 0 ) + GCO.Round(requirements.Resources[resourceID]*efficiency/100)
						UnitsSupplyDemand[selfKey].NeedResources[resourceID] 	= ( UnitsSupplyDemand[selfKey].NeedResources[resourceID] 	or 0 ) + 1
						LinkedUnits[selfKey][unit].NeedResources[resourceID] 	= true
					end
				end
			end
		end
	end
end

function GetLinkedUnits(self)
	local selfKey = self:GetKey()
	if not LinkedUnits[selfKey] then self:UpdateLinkedUnits() end
	return LinkedUnits[selfKey]
end

function UpdateCitiesConnection(self, transferCity, sRouteType, bInternalRoute)

	--GCO.StartTimer("UpdateCitiesConnection")
	local selfKey 		= self:GetKey()
	local transferKey 	= transferCity:GetKey()
	local selfPlot 		= Map.GetPlot(self:GetX(), self:GetY())
	local transferPlot	= Map.GetPlot(transferCity:GetX(), transferCity:GetY())
	
	-- Convert "Coastal" to "Ocean" with required tech for navigation on Ocean
	-- to do check for docks to allow transfert by sea/rivers
	-- add new building for connection by river (river docks)
	if sRouteType == "Coastal" then
		local pTech = Players[self:GetOwner()]:GetTechs()
		if pTech and pTech:HasTech(GameInfo.Technologies["TECH_CARTOGRAPHY"].Index) then
			sRouteType = "Ocean"
		end
	end

	Dprint( DEBUG_CITY_SCRIPT, "Testing "..tostring(sRouteType).." route from "..Locale.Lookup(self:GetName()).." to ".. Locale.Lookup(transferCity:GetName()))
	
	-- check if the route is possible before trying to determine it...
	if sRouteType == "Coastal" then
		if ( not(selfPlot:IsCoastalLand() and transferPlot:IsCoastalLand()) ) or self:GetMaxRouteLength(sRouteType) < Map.GetPlotDistance(selfPlot:GetX(), selfPlot:GetY(), transferPlot:GetX(), transferPlot:GetY()) then
			return
		end
		
	elseif sRouteType == "River" then
		if ( not(selfPlot:IsRiver() and transferPlot:IsRiver()) ) or self:GetMaxRouteLength(sRouteType) < Map.GetPlotDistance(selfPlot:GetX(), selfPlot:GetY(), transferPlot:GetX(), transferPlot:GetY())  then
			return
		end

	elseif sRouteType == "Road" then
		if self:GetMaxRouteLength(sRouteType) < Map.GetPlotDistance(selfPlot:GetX(), selfPlot:GetY(), transferPlot:GetX(), transferPlot:GetY()) then
			return
		end
	end

	local bIsPlotConnected = GCO.IsPlotConnected(Players[self:GetOwner()], selfPlot, transferPlot, sRouteType, true, nil, GCO.SupplyPathBlocked)
	if bIsPlotConnected then
		local routeLength 	= GCO.GetRouteLength()
		local efficiency 	= GCO.GetRouteEfficiency( routeLength * SupplyRouteLengthFactor[SupplyRouteType[sRouteType]] )
		if efficiency > 0 then
			Dprint( DEBUG_CITY_SCRIPT, " - Found route at " .. tostring(efficiency).." % efficiency, bInternalRoute = ", tostring(bInternalRoute))
			if bInternalRoute then
				if (not CitiesForTransfer[selfKey][transferKey]) or (CitiesForTransfer[selfKey][transferKey].Efficiency < efficiency) then
					CitiesForTransfer[selfKey][transferKey] = { RouteType = SupplyRouteType[sRouteType], Efficiency = efficiency }
				end
			else
				if (not CitiesForTrade[selfKey][transferKey]) or (CitiesForTrade[selfKey][transferKey].Efficiency < efficiency) then
					CitiesForTrade[selfKey][transferKey] = { RouteType = SupplyRouteType[sRouteType], Efficiency = efficiency }
				end
			end
		else
			Dprint( DEBUG_CITY_SCRIPT, " - Can't register route, too far away " .. tostring(efficiency).." % efficiency")
		end
	end
	--GCO.ShowTimer("UpdateCitiesConnection")
end

function GetMaxRouteLength(self, sRouteType)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetMaxRouteLength(sRouteType)
	elseif not _cached[cityKey].MaxRouteLength then
		self:SetMaxRouteLength(sRouteType)
	elseif not _cached[cityKey].MaxRouteLength[sRouteType] then
		self:SetMaxRouteLength(sRouteType)
	end
	return _cached[cityKey].MaxRouteLength[sRouteType]
end

function SetMaxRouteLength(self, sRouteType)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then _cached[cityKey] = {} end
	if not _cached[cityKey].MaxRouteLength then _cached[cityKey].MaxRouteLength = {} end
	local maxRouteLength = 0
	local efficiency = 100
	while efficiency > 0 do
		maxRouteLength 	= maxRouteLength + 1
		efficiency 		= GCO.GetRouteEfficiency( maxRouteLength * SupplyRouteLengthFactor[SupplyRouteType[sRouteType]] )
	end
	Dprint( DEBUG_CITY_SCRIPT, "Setting max route length for "..tostring(sRouteType).." = ".. tostring(maxRouteLength))
	_cached[cityKey].MaxRouteLength[sRouteType] = maxRouteLength
end

function GetTransferCities(self)
--GCO.StartTimer("GetTransferCities")
	local selfKey = self:GetKey()
	if not CitiesForTransfer[selfKey] then
		self:UpdateTransferCities()
	end
--GCO.ShowTimer("GetTransferCities")
	return CitiesForTransfer[selfKey]
end

function GetExportCities(self)
--GCO.StartTimer("GetExportCities")
	local selfKey = self:GetKey()
	if not CitiesForTrade[selfKey] then
		self:UpdateExportCities()
	end
--GCO.ShowTimer("GetExportCities")
	return CitiesForTrade[selfKey]
end

function UpdateTransferCities(self)
	local selfKey = self:GetKey()
	Dprint( DEBUG_CITY_SCRIPT, "Updating Routes to same Civilization Cities for ".. Locale.Lookup(self:GetName()))
	-- reset entries for that city
	CitiesForTransfer[selfKey] 		= {}	-- Internal transfert to own cities
	CitiesTransferDemand[selfKey] 	= { Resources = {}, NeedResources = {}, ReservedResources = {}, HasPrecedence = {} } -- NeedResources : Number of cities requesting a resource type

	local hasRouteTo 	= {}
	local ownerID 		= self:GetOwner()
	local player 		= Players[ownerID] --GCO.GetPlayer(ownerID) --<-- player:GetCities() sometime don't give the city objects from this script context
	local playerCities 	= player:GetCities()
	for i, transferCity in playerCities:Members() do
		AttachCityFunctions(transferCity) -- because UpdateExportCities() can be called from an UI context
		local transferKey = transferCity:GetKey()
		if transferKey ~= selfKey then
			-- search for trader routes first
			local trade = GCO.GetCityTrade(transferCity)
			local outgoingRoutes = trade:GetOutgoingRoutes()
			for j,route in ipairs(outgoingRoutes) do
				if route ~= nil and route.DestinationCityPlayer == ownerID and route.DestinationCityID == self:GetID() then
					Dprint( DEBUG_CITY_SCRIPT, " - Found trader for transfer from ".. Locale.Lookup(transferCity:GetName()))
					CitiesForTransfer[selfKey][transferKey] 	= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
					hasRouteTo[transferKey] = true
				end
			end

			if not hasRouteTo[transferKey] then
				for j,route in ipairs(trade:GetIncomingRoutes()) do
					if route ~= nil and route.OriginCityPlayer == ownerID and route.OriginCityID == self:GetID() then
						Dprint( DEBUG_CITY_SCRIPT, " - Found trader for transfer to ".. Locale.Lookup(transferCity:GetName()))
						CitiesForTransfer[selfKey][transferKey] 	= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
						hasRouteTo[transferKey] = true
					end
				end
			end

			-- search for other types or routes
			local bInternalRoute = true
			if not hasRouteTo[transferKey] then

				self:UpdateCitiesConnection(transferCity, "Road", bInternalRoute)
				self:UpdateCitiesConnection(transferCity, "River", bInternalRoute)
				self:UpdateCitiesConnection(transferCity, "Coastal", bInternalRoute)

			end

			if CitiesForTransfer[selfKey][transferKey] and CitiesForTransfer[selfKey][transferKey].Efficiency > 0 then

				local requirements 	= transferCity:GetRequirements(self) -- Get the resources required by transferCity and available in current city (self)...
				local efficiency	= CitiesForTransfer[selfKey][transferKey].Efficiency

				CitiesForTransfer[selfKey][transferKey].Resources 		= {}
				CitiesForTransfer[selfKey][transferKey].HasPrecedence 	= {}

				for resourceID, value in pairs(requirements.Resources) do
					if value > 0 then
						value = GCO.Round(value*efficiency/100)
						CitiesForTransfer[selfKey][transferKey].Resources[resourceID] 	= ( CitiesForTransfer[selfKey][transferKey].Resources[resourceID]	or 0 ) + value
						CitiesTransferDemand[selfKey].Resources[resourceID] 			= ( CitiesTransferDemand[selfKey].Resources[resourceID] 			or 0 ) + value
						CitiesTransferDemand[selfKey].NeedResources[resourceID] 		= ( CitiesTransferDemand[selfKey].NeedResources[resourceID] 		or 0 ) + 1
						if requirements.HasPrecedence[resourceID] then
							CitiesTransferDemand[selfKey].HasPrecedence[resourceID]				= true
							CitiesForTransfer[selfKey][transferKey].HasPrecedence[resourceID]	= true
							CitiesTransferDemand[selfKey].ReservedResources[resourceID] 		= ( CitiesTransferDemand[selfKey].ReservedResources[resourceID] or 0 ) + value
						end
					end
				end
			end
		end
	end
end

function TransferToCities(self)
	Dprint( DEBUG_CITY_SCRIPT, "Transfering to other cities for ".. Locale.Lookup(self:GetName()))
	local selfKey 			= self:GetKey()
	local supplyDemand 		= CitiesTransferDemand[selfKey]
	local transfers 		= {Resources = {}, ResPerCity = {}}
	local cityToSupply 		= CitiesForTransfer[selfKey]

	table.sort(cityToSupply, function(a, b) return a.Efficiency > b.Efficiency; end)

	for resourceID, value in pairs(supplyDemand.Resources) do
		local availableStock = self:GetAvailableStockForCities(resourceID)
		if supplyDemand.HasPrecedence[resourceID] then -- one city has made a prioritary request for that resource
			local bHasLocalPrecedence = (UnitsSupplyDemand[selfKey] and UnitsSupplyDemand[selfKey].Resources[resourceID]) -- to do : a function to test all precedence, and another to return the number of unit of resource required
			if bHasLocalPrecedence then
				availableStock = math.max(availableStock, GCO.Round(self:GetAvailableStockForUnits(resourceID)/2)) -- sharing unit stock when both city
			else
				availableStock = math.max(availableStock, GCO.Round(self:GetStock(resourceID)/2))
			end
		end
		transfers.Resources[resourceID] = math.min(value, availableStock)
		transfers.ResPerCity[resourceID] = math.floor(transfers.Resources[resourceID]/supplyDemand.NeedResources[resourceID])
		Dprint( DEBUG_CITY_SCRIPT, "- Required ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." = ".. tostring(value), " for " , tostring(supplyDemand.NeedResources[resourceID]) ," cities, available = " .. tostring(availableStock)..", transfer = ".. tostring(transfers.Resources[resourceID]) .. ", transfer priority = " ..tostring(supplyDemand.HasPrecedence[resourceID]) .. ", local priority = " ..tostring(bHasLocalPrecedence) )
	end

	for resourceID, value in pairs(transfers.Resources) do
		local resourceLeft			= value
		local maxLoop 				= 5
		local loop 					= 0
		local resourceCost 			= self:GetResourceCost(resourceID)
		local PrecedenceLeft		= supplyDemand.ReservedResources[resourceID] or 0
		local bResourcePrecedence	= supplyDemand.HasPrecedence[resourceID]

		while (resourceLeft > 0 and loop < maxLoop) do
			for cityKey, data in pairs(cityToSupply) do
				local city				= GCO.GetCityFromKey(cityKey)
				local requiredValue		= city:GetNumResourceNeeded(resourceID)
				local bCityPrecedence	= cityToSupply[cityKey].HasPrecedence[resourceID]
				if PrecedenceLeft > 0 and bResourcePrecedence and not bCityPrecedence then
					requiredValue = 0
				end
				if requiredValue > 0 then
					local efficiency	= data.Efficiency
					local send 			= math.min(transfers.ResPerCity[resourceID], requiredValue, resourceLeft)
					local costPerUnit	= self:GetTransportCostTo(city) + resourceCost -- to do : cache transport cost
					if (costPerUnit < city:GetResourceCost(resourceID)) or (bCityPrecedence and PrecedenceLeft > 0) or city:GetStock(resourceID) == 0 then -- this city may be in cityToSupply list for another resource, so check cost here again before sending the resource...
						resourceLeft = resourceLeft - send
						if bCityPrecedence then
							PrecedenceLeft = PrecedenceLeft - send
						end
						city:ChangeStock(resourceID, send, ResourceUseType.TransferIn, selfKey, costPerUnit)
						self:ChangeStock(resourceID, -send, ResourceUseType.TransferOut, cityKey)
						Dprint( DEBUG_CITY_SCRIPT, "  - send " .. tostring(send) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." (".. tostring(efficiency) .." % efficiency) to ".. Locale.Lookup(city:GetName()))
					end
				end
			end
			loop = loop + 1
		end
	end
end

function UpdateExportCities(self)
	Dprint( DEBUG_CITY_SCRIPT, "Updating Export Routes to other Civilizations Cities for ".. Locale.Lookup(self:GetName()))

	local selfKey 				= self:GetKey()
	CitiesForTrade[selfKey] 	= {}	-- Export to other civilizations cities
	CitiesTradeDemand[selfKey] 	= { Resources = {}, NeedResources = {}}

	local ownerID 		= self:GetOwner()
	local hasRouteTo 	= {}

	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player 	= Players[iPlayer] --GCO.GetPlayer(iPlayer) --<-- player:GetCities() sometime don't give the city object from this script context
		local pDiplo 	= player:GetDiplomacy()
		if iPlayer ~= ownerID and pDiplo and pDiplo:HasMet( ownerID ) and (not pDiplo:IsAtWarWith( ownerID )) then
			local playerConfig = PlayerConfigurations[iPlayer]
			Dprint( DEBUG_CITY_SCRIPT, "- searching for possible trade routes with "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()))
			local playerCities 	= player:GetCities()
			for i, transferCity in playerCities:Members() do
				AttachCityFunctions(transferCity) -- because UpdateExportCities() can be called from an UI context
				local transferKey = transferCity:GetKey()
				if transferKey ~= selfKey then
					-- search for trader routes first
					local trade = GCO.GetCityTrade(transferCity)
					local outgoingRoutes = trade:GetOutgoingRoutes()
					for j,route in ipairs(outgoingRoutes) do
						if route ~= nil and route.DestinationCityPlayer == ownerID and route.DestinationCityID == self:GetID() then
							Dprint( DEBUG_CITY_SCRIPT, " - Found trader for international trade from ".. Locale.Lookup(transferCity:GetName()))
							CitiesForTrade[selfKey][transferKey] 		= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
							hasRouteTo[transferKey] = true
						end
					end

					if not hasRouteTo[transferKey] then
						for j,route in ipairs(trade:GetIncomingRoutes()) do
							if route ~= nil and route.OriginCityPlayer == ownerID and route.OriginCityID == self:GetID() then
								Dprint( DEBUG_CITY_SCRIPT, " - Found trader for international trade to ".. Locale.Lookup(transferCity:GetName()))
								CitiesForTrade[selfKey][transferKey] 		= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
								hasRouteTo[transferKey] = true
							end
						end
					end

					-- search for other types or routes
					local bHasOpenMarket = GCO.HasPlayerOpenBordersFrom(player, ownerID) -- to do : real diplomatic deal for international trade over normal routes
					local bInternalRoute = false
					if bHasOpenMarket then
						if not hasRouteTo[transferKey] then

							self:UpdateCitiesConnection(transferCity, "Road", bInternalRoute)
							self:UpdateCitiesConnection(transferCity, "River", bInternalRoute)
							self:UpdateCitiesConnection(transferCity, "Coastal", bInternalRoute)

						end
					end

					if CitiesForTrade[selfKey][transferKey] and CitiesForTrade[selfKey][transferKey].Efficiency > 0 then

						local requirements 	= transferCity:GetRequirements(self) -- Get the resources required by transferCity and available in current city (self)...
						local efficiency	= CitiesForTrade[selfKey][transferKey].Efficiency

						for resourceID, value in pairs(requirements.Resources) do
							if value > 0 then --and not (notAvailableToExport[resourceID]) then
								CitiesTradeDemand[selfKey].Resources[resourceID] 		= ( CitiesTradeDemand[selfKey].Resources[resourceID] 		or 0 ) + GCO.Round(requirements.Resources[resourceID]*efficiency/100)
								CitiesTradeDemand[selfKey].NeedResources[resourceID] 	= ( CitiesTradeDemand[selfKey].NeedResources[resourceID] 	or 0 ) + 1
							end
						end
					end
				end
			end
		end
	end
end

function ExportToForeignCities(self)
	Dprint( DEBUG_CITY_SCRIPT, "Export to other Civilizations Cities for ".. Locale.Lookup(self:GetName()))

	local selfKey 			= self:GetKey()
	local supplyDemand 		= CitiesTradeDemand[selfKey]
	local transfers 		= {Resources = {}, ResPerCity = {}}
	local cityToSupply 		= CitiesForTrade[selfKey]
	local bExternalRoute 	= true

	table.sort(cityToSupply, function(a, b) return a.Efficiency > b.Efficiency; end)

	for resourceID, value in pairs(supplyDemand.Resources) do
		transfers.Resources[resourceID] = math.min(value, self:GetAvailableStockForExport(resourceID))
		transfers.ResPerCity[resourceID] = math.floor(transfers.Resources[resourceID]/supplyDemand.NeedResources[resourceID])
		Dprint( DEBUG_CITY_SCRIPT, "- Required ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." = ".. tostring(value), " for " , tostring(supplyDemand.NeedResources[resourceID]) ," cities, available = " .. tostring(self:GetAvailableStockForExport(resourceID))..", transfer = ".. tostring(transfers.Resources[resourceID]))
	end

	local importIncome = {}
	local exportIncome = 0
	for resourceID, value in pairs(transfers.Resources) do
		local resLeft = value
		local maxLoop = 5
		local loop = 0
		while (resLeft > 0 and loop < maxLoop) do
			for cityKey, data in pairs(cityToSupply) do
			
				local city		= GCO.GetCityFromKey(cityKey)				
				local reqValue 	= city:GetNumResourceNeeded(resourceID, bExternalRoute)
				if reqValue > 0 then
					local resourceClassType = GameInfo.Resources[resourceID].ResourceClassType
					local efficiency		= data.Efficiency
					local send 				= math.min(transfers.ResPerCity[resourceID], reqValue, resLeft)
					local costPerUnit		= self:GetTransportCostTo(city) + self:GetResourceCost(resourceID)
					if costPerUnit < city:GetResourceCost(resourceID) or city:GetStock(resourceID) == 0 then -- this city may be in cityToSupply list for another resource, so check cost and stock here again before sending the resource... to do : track value per city
						local transactionIncome = send * self:GetResourceCost(resourceID) -- * costPerUnit
						resLeft = resLeft - send
						city:ChangeStock(resourceID, send, ResourceUseType.Import, selfKey, costPerUnit)
						self:ChangeStock(resourceID, -send, ResourceUseType.Export, cityKey)
						importIncome[city] = (importIncome[city] or 0) + transactionIncome
						exportIncome = exportIncome + transactionIncome
						Dprint( DEBUG_CITY_SCRIPT, "  - Generating "..tostring(transactionIncome).." golds for " .. tostring(send) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." (".. tostring(efficiency) .." % efficiency) send to ".. Locale.Lookup(city:GetName()))
					end
				end
			end
			loop = loop + 1
		end
	end

	-- Get gold from trade
	exportIncome = GCO.ToDecimals(exportIncome * IncomeExportPercent / 100)
	if exportIncome > 0 then
		Dprint( DEBUG_CITY_SCRIPT, "Total gold from Export income = " .. exportIncome .." gold for ".. Locale.Lookup(self:GetName()))
		local sText = Locale.Lookup("LOC_GOLD_FROM_EXPORT", exportIncome)
		if Game.GetLocalPlayer() == self:GetOwner() then Game.AddWorldViewText(EventSubTypes.PLOT, sText, self:GetX(), self:GetY(), 0) end
		Players[self:GetOwner()]:GetTreasury():ChangeGoldBalance(exportIncome)
	end

	for city, income in pairs(importIncome) do
		income = GCO.ToDecimals(income * IncomeImportPercent / 100)
		if income > 0 then
			Dprint( DEBUG_CITY_SCRIPT, "Total gold from Import income = " .. income .." gold for ".. Locale.Lookup(city:GetName()))
			local sText = Locale.Lookup("LOC_GOLD_FROM_IMPORT", income)
			if Game.GetLocalPlayer() == city:GetOwner() then Game.AddWorldViewText(EventSubTypes.PLOT, sText, city:GetX(), city:GetY(), 0) end
			Players[city:GetOwner()]:GetTreasury():ChangeGoldBalance(exportIncome)
		end
	end
end

function GetMaxPercentLeftToRequest(self, resourceID)
	local maxPercentLeft = MaxPercentLeftToRequest
	if ResourceUsage[resourceID] then
		maxPercentLeft = ResourceUsage[resourceID].MaxPercentLeftToRequest
	end
	return maxPercentLeft
end

function GetMaxPercentLeftToImport(self, resourceID)
	local maxPercentLeft = MaxPercentLeftToImport
	if ResourceUsage[resourceID] then
		maxPercentLeft = ResourceUsage[resourceID].MaxPercentLeftToImport
	end
	return maxPercentLeft
end

function GetMinPercentLeftToExport(self, resourceID)
	local minPercentLeft = MinPercentLeftToExport
	if ResourceUsage[resourceID] then
		minPercentLeft = ResourceUsage[resourceID].MinPercentLeftToExport
	end
	return minPercentLeft
end

function GetAvailableStockForExport(self, resourceID)
	local minPercentLeft = self:GetMinPercentLeftToExport(resourceID)
	local minStockLeft = GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
	return math.max(0, self:GetStock(resourceID)-minStockLeft)
end

function GetMinimalStockForExport(self, resourceID)
	local minPercentLeft = self:GetMinPercentLeftToExport(resourceID)
	return GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
end

function GetNumResourceNeeded(self, resourceID, bExternalRoute)
	local maxPercent = 0
	if bExternalRoute then
		maxPercent = math.min(self:GetMinPercentLeftToExport(resourceID), self:GetMaxPercentLeftToImport(resourceID))  -- make sure that we can't export a resource then import it, generating money both way
	else
		maxPercent = MaxPercentLeftToRequest
	end
	local maxStockLeft = GCO.Round(self:GetMaxStock(resourceID)*maxPercent/100)
	return math.max(0, maxStockLeft - self:GetStock(resourceID))
end

function GetRouteEfficiencyTo(self, city)
	local selfKey = self:GetKey()
	local cityKey = city:GetKey()
	---[[
	if (self:GetOwner() ~= city:GetOwner()) and not (CitiesForTrade[selfKey] and CitiesForTrade[selfKey][cityKey]) then
		self:UpdateExportCities()
	end
	if (self:GetOwner() == city:GetOwner()) and not (CitiesForTransfer[selfKey] and CitiesForTransfer[selfKey][cityKey]) then
		self:UpdateTransferCities()
	end
	--]]
	if CitiesForTrade[selfKey] and CitiesForTrade[selfKey][cityKey] then
		return CitiesForTrade[selfKey][cityKey].Efficiency or 0
	elseif CitiesForTransfer[selfKey] and CitiesForTransfer[selfKey][cityKey] then
		return CitiesForTransfer[selfKey][cityKey].Efficiency or 0
	end

	return 0
end

function GetRequirements(self, fromCity)
	local selfKey 				= self:GetKey()
	local resourceKey 			= tostring(resourceID)
	local player 				= GCO.GetPlayer(self:GetOwner())
	local cityName	 			= Locale.Lookup(self:GetName())
	local bExternalRoute 		= (self:GetOwner() ~= fromCity:GetOwner())
	local requirements 			= {}
	requirements.Resources 		= {}
	requirements.HasPrecedence 	= {}

	Dprint( DEBUG_CITY_SCRIPT, "GetRequirements for ".. cityName )

	for row in GameInfo.Resources() do
		local resourceID 			= row.Index
		local bCanRequest 			= false
		local bCanTradeResource 	= not((row.NoExport and bExternalRoute) or (row.NoTransfer and (not bExternalRoute)))
		--Dprint( DEBUG_CITY_SCRIPT, "can trade = ", bCanTradeResource,"no export",row.NoExport,"external route",bExternalRoute,"no transfer",row.NoTransfer,"internal route",(not bExternalRoute))
		if player:IsResourceVisible(resourceID) and bCanTradeResource then
			local numResourceNeeded = self:GetNumResourceNeeded(resourceID, bExternalRoute)
			if numResourceNeeded > 0 then
				local bPriorityRequest	= false
				if fromCity then -- function was called to only request resources available in "fromCity"
					local efficiency 	= fromCity:GetRouteEfficiencyTo(self)
					local transportCost = fromCity:GetTransportCostTo(self)
					local bHasStock		= fromCity:GetStock(resourceID) > 0 
					if bHasStock then
						local fromName	 		= Locale.Lookup(fromCity:GetName())
						Dprint( DEBUG_CITY_SCRIPT, "    - check for ".. Locale.Lookup(GameInfo.Resources[resourceID].Name), " efficiency", efficiency, " "..fromName.." stock", fromCity:GetStock(resourceID) ," "..cityName.." stock", self:GetStock(resourceID) ," "..fromName.." cost", fromCity:GetResourceCost(resourceID)," transport cost", transportCost, " "..cityName.." cost", self:GetResourceCost(resourceID))
					end
					local bHasMoreStock 	= true -- (fromCity:GetStock(resourceID) > self:GetStock(resourceID)) --< must find another check, this one doesn't allow small city at full stock to transfer to big city at low stock (but still higher than small city max stock) use percentage stock instead ?
					local bIsLowerCost 		= (fromCity:GetResourceCost(resourceID) + transportCost < self:GetResourceCost(resourceID))
					bPriorityRequest		= false

					if UnitsSupplyDemand[selfKey] and UnitsSupplyDemand[selfKey].Resources[resourceID] and resourceID ~= foodResourceID then -- Units have required this resource...
						numResourceNeeded	= math.min(self:GetMaxStock(resourceID), numResourceNeeded + UnitsSupplyDemand[selfKey].Resources[resourceID])
						bPriorityRequest	= true
					end

					if bHasStock and bHasMoreStock and (bIsLowerCost or bPriorityRequest or self:GetStock(resourceID) == 0) then
						bCanRequest = true
					end
				else
					bCanRequest = true
				end
				if bCanRequest then
					requirements.Resources[resourceID] 		= numResourceNeeded
					requirements.HasPrecedence[resourceID] 	= bPriorityRequest
					Dprint( DEBUG_CITY_SCRIPT, "- Required ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." = ".. tostring(requirements.Resources[resourceID])..", Priority = "..tostring(bPriorityRequest))
				end
			end
		end
	end

	return requirements
end


-----------------------------------------------------------------------------------------
-- Resources Stock
-----------------------------------------------------------------------------------------
function GetAvailableStockForUnits(self, resourceID)
	--[[
	if self:GetUseTypeAtTurn(resourceID, ResourceUseType.Consume, GCO.GetTurnKey()) == 0 then -- temporary, assume industries are first called
		return self:GetStock(resourceID)
	end
	--]]
	local minPercentLeft = MinPercentLeftToSupply
	if ResourceUsage[resourceID] then
		minPercentLeft = ResourceUsage[resourceID].MinPercentLeftToSupply
	end
	local minStockLeft = GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
	return math.max(0, self:GetStock(resourceID)-minStockLeft)
end

function GetAvailableStockForCities(self, resourceID)
	local minPercentLeft = MinPercentLeftToTransfer
	if ResourceUsage[resourceID] then
		minPercentLeft = ResourceUsage[resourceID].MinPercentLeftToTransfer
	end
	local minStockLeft = GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
	return math.max(0, self:GetStock(resourceID)-minStockLeft)
end

function GetAvailableStockForIndustries(self, resourceID)
	local minPercentLeft = MinPercentLeftToConvert
	if ResourceUsage[resourceID] then
		minPercentLeft = ResourceUsage[resourceID].MinPercentLeftToConvert
	end
	local minStockLeft = GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
	return math.max(0, self:GetStock(resourceID)-minStockLeft)
end

function GetMinimalStockForUnits(self, resourceID)
	local minPercentLeft = MinPercentLeftToSupply
	if ResourceUsage[resourceID] then
		minPercentLeft = ResourceUsage[resourceID].MinPercentLeftToSupply
	end
	return GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
end

function GetMinimalStockForCities(self, resourceID)
	local minPercentLeft = MinPercentLeftToTransfer
	if ResourceUsage[resourceID] then
		minPercentLeft = ResourceUsage[resourceID].MinPercentLeftToTransfer
	end
	return GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
end

function GetMinimalStockForIndustries(self, resourceID)
	local minPercentLeft = MinPercentLeftToConvert
	if ResourceUsage[resourceID] then
		minPercentLeft = ResourceUsage[resourceID].MinPercentLeftToConvert
	end
	return GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
end

function ChangeStock(self, resourceID, value, useType, reference, unitCost)

	if value == 0 then return end

	local resourceKey 	= tostring(resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	local cityData 		= ExposedMembers.CityData[cityKey]

	if not reference then reference = NO_REFERENCE_KEY end
	reference = tostring(reference) -- will be a key in table

	if value > 0 and resourceKey ~= personnelResourceKey then
		if not useType then useType = ResourceUseType.OtherIn end
		if not unitCost then unitCost = GCO.GetBaseResourceCost(resourceID) end
		local actualStock	= self:GetStock(resourceID)
		local actualCost	= self:GetResourceCost(resourceID)
		local maxStock		= self:GetMaxStock(resourceID)
		local surplus		= math.max(0, (actualStock + value) - maxStock)
		local virtualStock 	= math.max(actualStock, (math.ceil(maxStock/2)))
		local virtualValue 	= value - surplus
		local newCost 		= GCO.ToDecimals((virtualValue*unitCost + virtualStock*actualCost ) / (virtualValue + virtualStock))

		local surplusStr 	= ""
		local halfStockStr	= ""

		newCost = math.min(newCost, self:GetMaximumResourceCost(resourceID))
		newCost = math.max(newCost, self:GetMinimumResourceCost(resourceID))

		if surplus > 0 then surplusStr 	= "(surplus of "..tostring(surplus).." not effecting price)" end
		if virtualStock > actualStock then halfStockStr 	= " (using virtual half stock of "..tostring(virtualStock).." for calculation) " end

		Dprint( DEBUG_CITY_SCRIPT, "Update Unit Cost of ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." to "..tostring(newCost).." cost/unit, added "..tostring(value).." unit(s) at "..tostring(unitCost).." cost/unit "..surplusStr.." to stock of ".. tostring(actualStock).." unit(s) at ".. tostring(actualCost).." cost/unit " .. halfStockStr)
		self:SetResourceCost(resourceID, newCost)
	else
		if not useType then useType = ResourceUseType.OtherOut  end
	end

	-- Update stock
	if not ExposedMembers.CityData[cityKey].Stock[turnKey][resourceKey] then
		ExposedMembers.CityData[cityKey].Stock[turnKey][resourceKey] = math.max(0 , value)

	else
		ExposedMembers.CityData[cityKey].Stock[turnKey][resourceKey] = math.max(0 , cityData.Stock[turnKey][resourceKey] + value)
	end

	-- update stats
	if not ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey] then
		ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey] = { [useType] = {[reference] = math.abs(value)}}

	elseif not ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType] then
		ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType] = {[reference] = math.abs(value)}

	elseif not ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType][reference] then
		ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType][reference] = math.abs(value)

	else
		ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType][reference] = ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType][reference] + math.abs(value)
	end
end

function GetMaxStock(self, resourceID)
	if resourceID == personnelResourceID then return self:GetMaxPersonnel() end
	local maxStock = self:GetSize() * ResourceStockPerSize
	if resourceID == foodResourceID then maxStock = (self:GetSize() * FoodStockPerSize) + baseFoodStock end
	if GCO.IsResourceEquipment(resourceID) 		then maxStock = EquipmentBaseStock end	-- Equipment stock does not depend of city size, just buildings
	if ResourceStockage[resourceID] then
		for _, buildingID in ipairs(ResourceStockage[resourceID]) do
			if self:GetBuildings():HasBuilding(buildingID) then
				maxStock = maxStock + BuildingStock[buildingID][resourceID]
			end
		end
	end
	return maxStock
end

function GetStock(self, resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	local resourceKey 	= tostring(resourceID)
	if cityKey == nil or turnKey == nil or resourceKey == nil then
		print("ERROR: nil value in GetStock", " cityKey = ", cityKey, "turnKey = ", turnKey, "resourceKey = ", resourceKey)
	end
	return ExposedMembers.CityData[cityKey].Stock[turnKey][resourceKey] or 0
end

function GetPreviousStock(self , resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetPreviousTurnKey()
	local resourceKey 	= tostring(resourceID)
	if ExposedMembers.CityData[cityKey].Stock[turnKey] then -- for new city this will be nil
		return ExposedMembers.CityData[cityKey].Stock[turnKey][resourceKey] or 0
	else
		return self:GetStock(resourceID) -- return actual stock for a new city
	end
end

function GetStockVariation(self, resourceID)
	return self:GetStock(resourceID) - self:GetPreviousStock(resourceID)
end


-----------------------------------------------------------------------------------------
-- Resources Cost
-----------------------------------------------------------------------------------------
function GetMinimumResourceCost(self, resourceID)
	return GCO.GetBaseResourceCost(resourceID) / 4
end

function GetMaximumResourceCost(self, resourceID)
	return GCO.GetBaseResourceCost(resourceID) * 4
end

function GetResourceCost(self, resourceID)
	if resourceID == personnelResourceID then return 0 end
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	local resourceKey 	= tostring(resourceID)
	local resourceCost	= (ExposedMembers.CityData[cityKey].ResourceCost[turnKey][resourceKey] or GCO.GetBaseResourceCost(resourceID))
	resourceCost		= GCO.ToDecimals(resourceCost)
	return resourceCost
end

function SetResourceCost(self, resourceID, value)
	local resourceKey = tostring(resourceID)
	if resourceKey == personnelResourceKey then	return end

	local cityKey = self:GetKey()
	local turnKey = GCO.GetTurnKey()

	ExposedMembers.CityData[cityKey].ResourceCost[turnKey][resourceKey] = math.max(0 , GCO.ToDecimals(value))
end

function ChangeResourceCost(self, resourceID, value)
	local resourceKey = tostring(resourceID)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	if resourceKey == personnelResourceKey then
		return

	elseif not ExposedMembers.CityData[cityKey].ResourceCost[resourceKey] then
		ExposedMembers.CityData[cityKey].ResourceCost[resourceKey] = math.max(0 , value)

	else
		ExposedMembers.CityData[cityKey].ResourceCost[resourceKey] = math.max(0 , cityData.ResourceCost[resourceKey] + value)
	end
end

function GetResourceCostVariation(self, resourceID)
	return (self:GetResourceCost(resourceID) - self:GetPreviousResourceCost(resourceID))
end

function GetPreviousResourceCost(self , resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetPreviousTurnKey()
	local resourceKey 	= tostring(resourceID)
	if ExposedMembers.CityData[cityKey].ResourceCost[turnKey] then -- for new city this will be nil
		return ExposedMembers.CityData[cityKey].ResourceCost[turnKey][resourceKey] or GCO.GetBaseResourceCost(resourceID)
	else
		return GCO.GetBaseResourceCost(resourceID)
	end
end

function GetTransportCostTo(self, city)
	return GCO.ToDecimals(ResourceTransportMaxCost * (100 - self:GetRouteEfficiencyTo(city)) / 100)
end


-----------------------------------------------------------------------------------------
-- Resources Supply/Demand
-----------------------------------------------------------------------------------------
function GetDemand(self, resourceID)
	local demand = 0

	-- get food needed outside rationing (the rationed consumption is added in the call to GetDemandAtTurn) -- to do : clean that code
	if resourceID == foodResourceID then
		local normalRatio = 1
		demand = demand + (self:GetFoodConsumption(normalRatio)-self:GetFoodConsumption())
	end

	-- Industries
	--[[
	local MultiResRequired 	= {}
	local MultiResCreated 	= {}
	for row in GameInfo.BuildingResourcesConverted() do
		local buildingID 	= GameInfo.Buildings[row.BuildingType].Index
		if self:GetBuildings():HasBuilding(buildingID) then
			local resourceRequiredID = GameInfo.Resources[row.ResourceType].Index
			if resourceRequiredID == resourceID then
				if row.MultiResRequired then
					local resourceCreatedID = GameInfo.Resources[row.ResourceCreated].Index
					if not MultiResRequired[resourceCreatedID] then	MultiResRequired[resourceCreatedID] = {[buildingID] = {}} end
					table.insert(MultiResRequired[resourceCreatedID][buildingID], {ResourceRequired = resourceRequiredID, MaxConverted = row.MaxConverted, Ratio = row.Ratio})

				elseif row.MultiResCreated then
					local resourceCreatedID = GameInfo.Resources[row.ResourceCreated].Index
					if not MultiResCreated[resourceRequiredID] then	MultiResCreated[resourceRequiredID] = {[buildingID] = {}} end
					table.insert(MultiResCreated[resourceRequiredID][buildingID], {ResourceCreated = resourceCreatedID, MaxConverted = row.MaxConverted, Ratio = row.Ratio})
				else
					demand = demand + row.MaxConverted
				end
			end
		end
	end

	for resourceRequiredID, data1 in pairs(MultiResCreated) do
		for buildingID, data2 in pairs (data1) do
			demand = demand + data2[1].MaxConverted -- MaxConverted should be the same in all rows, no need to go through them, pick the first entry
		end
	end

	for resourceCreatedID, data1 in pairs(MultiResRequired) do
		for buildingID, data2 in pairs (data1) do
			for _, row in ipairs(data2) do
				if row.ResourceRequired == resourceID then
					demand = demand + row.MaxConverted
				end
			end
		end
	end
	--]]
	local previousTurn	= tonumber(GCO.GetPreviousTurnKey())
	demand = demand + self:GetDemandAtTurn(resourceID, previousTurn)

	return demand

end

function GetSupplyAtTurn(self, resourceID, turn)
	local resourceKey 	= tostring(resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= tostring(turn)
	local cityData 		= ExposedMembers.CityData[cityKey]

	if cityData.ResourceUse[turnKey] then
		local useData = cityData.ResourceUse[turnKey][resourceKey]
		if useData then

			local supply = 0

			supply = supply + GCO.TableSummation(useData[ResourceUseType.Collect])
			supply = supply + GCO.TableSummation(useData[ResourceUseType.Product])
			supply = supply + GCO.TableSummation(useData[ResourceUseType.Import])
			supply = supply + GCO.TableSummation(useData[ResourceUseType.TransferIn])
			supply = supply + GCO.TableSummation(useData[ResourceUseType.Pillage])
			--supply = supply + ( useData[ResourceUseType.OtherIn] 	or 0)

			return supply
		end
	end

	return 0
end

function GetDemandAtTurn(self, resourceID, turn)
	local resourceKey 	= tostring(resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= tostring(turn)
	local cityData 		= ExposedMembers.CityData[cityKey]

	if cityData.ResourceUse[turnKey] then
		local useData = cityData.ResourceUse[turnKey][resourceKey]
		if useData then

			local demand = 0

			demand = demand + GCO.TableSummation(useData[ResourceUseType.Consume])
			demand = demand + GCO.TableSummation(useData[ResourceUseType.Export])
			demand = demand + GCO.TableSummation(useData[ResourceUseType.TransferOut])
			demand = demand + GCO.TableSummation(useData[ResourceUseType.Supply])

			return demand
		end
	end

	return 0
end

function GetUseTypeAtTurn(self, resourceID, useType, turn)
	local resourceKey 	= tostring(resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= tostring(turn)
	local cityData 		= ExposedMembers.CityData[cityKey]

	if cityData.ResourceUse[turnKey] then
		local useData = cityData.ResourceUse[turnKey][resourceKey]
		if useData then
			return GCO.TableSummation(useData[useType])
		end
	end

	return 0
end

function GetAverageUseTypeOnTurns(self, resourceID, useType, numTurn)
	local total 		= 0
	local loop 			= 0
	local currentTurn 	= Game.GetCurrentGameTurn()
	for turn = currentTurn, currentTurn - (numTurn-1), -1 do
		if turn < 0 then break end
		total = total + self:GetUseTypeAtTurn(resourceID, useType, turn)
		loop = loop + 1
	end
	if loop > 0 then
		return GCO.Round(total/loop)
	end
	return 0
end

function GetResourceUseToolTipStringForTurn(self, resourceID, useTypeKey, turn)
--Dprint( DEBUG_CITY_SCRIPT, self)
--Dprint( DEBUG_CITY_SCRIPT, resourceID)
--Dprint( DEBUG_CITY_SCRIPT, useTypeKey)
--Dprint( DEBUG_CITY_SCRIPT, turn)
--Dprint( DEBUG_CITY_SCRIPT, ResourceUseTypeReference[useTypeKey])
	local resourceKey 	= tostring(resourceID)
	local selfKey 		= self:GetKey()
	local turnKey 		= tostring(turn)
	local cityData 		= ExposedMembers.CityData[selfKey]
	local selfName		= Locale.Lookup(self:GetName())
	local bNotUnitUse	= (ResourceUseTypeReference[useTypeKey] ~= ReferenceType.Unit)
	
	local MakeString	= function(key, value) return tostring(key) .. " = " .. tostring(value) end	
	
	function SelfString(value)
		return tostring(selfName) .. " = " .. tostring(value)
	end
	
	if ResourceUseTypeReference[useTypeKey] == ReferenceType.Plot then
		MakeString	= function(key, value)
			local plot 	= Map.GetPlotByIndex(key)
			local name	= Locale.Lookup(GameInfo.Terrains[plot:GetTerrainType()].Name)
			local featureID = plot:GetFeatureType()
			if featureID ~= NO_FEATURE then
				name = name .. ", ".. Locale.Lookup(GameInfo.Features[featureID].Name)
			end
			local improvementID = plot:GetImprovementType()
			if improvementID ~= NO_FEATURE then
				name = name .. ", ".. Locale.Lookup(GameInfo.Improvements[improvementID].Name)
			end
			name = name.. " @(".. tostring(plot:GetX())..",".. tostring(plot:GetY())..")"
			return tostring(name) .. " = " ..  tostring(value)
		end
	elseif ResourceUseTypeReference[useTypeKey] == ReferenceType.City then
		MakeString	= function(key, value)
			local city 	= GetCityFromKey ( key )
			local name	= Locale.Lookup(city:GetName())
			return tostring(name) .. " = " .. tostring(value)
		end
	elseif ResourceUseTypeReference[useTypeKey] == ReferenceType.Unit then
		MakeString	= function(key, value)
			local unit 	= GCO.GetUnitFromKey ( key )
			if unit then
				local name	= Locale.Lookup(unit:GetName())
				return tostring(name) .. " = " .. tostring(value)
			else
				return "Dead unit = " .. tostring(value)
			end
		end
	elseif ResourceUseTypeReference[useTypeKey] == ReferenceType.Population then
		MakeString	= function(key, value)
			local name	= Locale.Lookup(GameInfo.Populations[key].Name)
			return tostring(name) .. " = " .. tostring(value)
		end
	elseif ResourceUseTypeReference[useTypeKey] == ReferenceType.Building then
		MakeString	= function(key, value)
			local buildingID 	= tonumber ( key )
			local name			= Locale.Lookup(GameInfo.Buildings[buildingID].Name)
			return tostring(name) .. " = " .. tostring(value)
		end
	elseif ResourceUseTypeReference[useTypeKey] == ReferenceType.PopOrBuilding then
		MakeString	= function(key, value)
			local name = ""
			if string.len(key) > 5 then -- this lenght means Population type string
				name	= Locale.Lookup(GameInfo.Populations[key].Name)
			else -- buildingKey
				local buildingID 	= tonumber ( key )
				name				= Locale.Lookup(GameInfo.Buildings[buildingID].Name)			
			end
			return tostring(name) .. " = " .. tostring(value)
		end
	end
	
	local str = ""
	if cityData.ResourceUse[turnKey] then
		local useData = cityData.ResourceUse[turnKey][resourceKey]
		if useData and useData[useTypeKey] then		
			for key, value in pairs(useData[useTypeKey]) do
			--Dprint( DEBUG_CITY_SCRIPT, key, value)
				if (key == selfKey and bNotUnitUse) or key == NO_REFERENCE_KEY then
					str = str..SelfString(value).."[NEWLINE]"
				else
					str = str..MakeString(key, value).."[NEWLINE]"
				end
			end
		end
	end
	
--Dprint( DEBUG_CITY_SCRIPT, str)
--Dprint( DEBUG_CITY_SCRIPT, "----------")
	return str
end


-----------------------------------------------------------------------------------------
-- City Panel Stats
-----------------------------------------------------------------------------------------
function GetResourcesStockTable(self)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	local data 			= ExposedMembers.CityData[cityKey]
	local stockTable	= {}
	if not data.Stock[turnKey] then return {} end
	for resourceKey, value in pairs(data.Stock[turnKey]) do
		local resourceID 		= tonumber(resourceKey)
		if (value + self:GetSupplyAtTurn(resourceID, turnKey) + self:GetDemandAtTurn(resourceID, turnKey) > 0) then
			local rowTable 			= {}
			local stockVariation 	= self:GetStockVariation(resourceID)
			local resourceCost 		= self:GetResourceCost(resourceID)
			local costVariation 	= self:GetResourceCostVariation(resourceID)
			local resRow 			= GameInfo.Resources[resourceID]
			
			rowTable.Icon 			= GCO.GetResourceIcon(resourceID)			
			rowTable.Name 			= Locale.Lookup(resRow.Name)
			local toolTipHeader		= rowTable.Icon .. " " .. rowTable.Name .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR")			
			rowTable.Stock 			= value
			
			local availableForCities		= self:GetAvailableStockForCities(resourceID)
			local minimalStockForCities		= self:GetMinimalStockForCities(resourceID)
			local availableForIndustries	= self:GetAvailableStockForIndustries(resourceID)
			local minimalStockForIndustries	= self:GetMinimalStockForIndustries(resourceID)
			local availableForUnits			= self:GetAvailableStockForUnits(resourceID)
			local minimalStockForUnits		= self:GetMinimalStockForUnits(resourceID)
			local availableForExport		= self:GetAvailableStockForExport(resourceID)
			local minimalStockForExport		= self:GetMinimalStockForExport(resourceID)
			local stockToolTipString		= Locale.Lookup("LOC_HUD_CITY_STOCK_TOOLTIP", availableForCities, minimalStockForCities, availableForIndustries, minimalStockForIndustries, availableForUnits, minimalStockForUnits, availableForExport, minimalStockForExport )
			
			rowTable.StockToolTip			= toolTipHeader .. stockToolTipString
			
			rowTable.MaxStock 		= self:GetMaxStock(resourceID)

			if stockVariation == 0 then
				rowTable.StockVar 	= "-"
			else
				rowTable.StockVar 	= GCO.GetVariationStringGreenPositive(stockVariation)
			end

			if resourceCost == 0 then
				rowTable.UnitCost 	= "-"
			else
				rowTable.UnitCost 	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_COST", resourceCost)
			end

			if costVariation == 0 or resourceCost == 0 then
				rowTable.CostVar 	= "-"
			else
				rowTable.CostVar 	= GCO.GetVariationStringRedPositive(costVariation)
			end

			rowTable.ResourceType 	= resRow.ResourceType

			table.insert(stockTable, rowTable)
		end
	end

	table.sort(stockTable, function(a, b) return a.ResourceType < b.ResourceType; end)
	return stockTable
end

function GetResourcesSupplyTable(self)
	local cityKey 			= self:GetKey()
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey	= GCO.GetPreviousTurnKey()
	local data 				= ExposedMembers.CityData[cityKey]
	local supplyTable		= {}
	if not data.ResourceUse[turnKey] then return {} end
	for resRow in GameInfo.Resources() do
		local resourceID 	= resRow.Index
	--for resourceKey, useData in pairs(data.ResourceUse[turnKey]) do

		local Collect 		= self:GetUseTypeAtTurn(resourceID, ResourceUseType.Collect, turnKey)
		local Product 		= self:GetUseTypeAtTurn(resourceID, ResourceUseType.Product, turnKey)
		local Import 		= self:GetUseTypeAtTurn(resourceID, ResourceUseType.Import, previousTurnKey) -- all other players cities have not exported their resource at the beginning of the player turn, so get previous turn value
		local TransferIn 	= self:GetUseTypeAtTurn(resourceID, ResourceUseType.TransferIn, turnKey)
		local Pillage 		= self:GetUseTypeAtTurn(resourceID, ResourceUseType.Pillage, turnKey)
		local OtherIn 		= self:GetUseTypeAtTurn(resourceID, ResourceUseType.OtherIn, turnKey)
		local TotalIn		= Collect + Product + Import + TransferIn + Pillage + OtherIn

		if (TotalIn > 0) then
			local rowTable 			= {}

			rowTable.Icon 		= GCO.GetResourceIcon(resourceID)			
			rowTable.Name 		= Locale.Lookup(resRow.Name)
			local toolTipHeader	= rowTable.Icon .. " " .. rowTable.Name
			local separator		= Locale.Lookup("LOC_TOOLTIP_SEPARATOR")
		
			if Collect 		== 0 then
				rowTable.Collect		= "-"
			else
				rowTable.Collect 		= Collect
				rowTable.CollectToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_COLLECT_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.Collect, turnKey)
			end
			if Product 		== 0 then
				rowTable.Product		= "-"
			else
				rowTable.Product 		= Product
				rowTable.ProductToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_PRODUCT_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.Product, turnKey)
			end
			if Import 		== 0 then
				rowTable.Import			= "-"
			else
				rowTable.Import 		= Import
				rowTable.ImportToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_IMPORT_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.Import, previousTurnKey)
			end
			if TransferIn 	== 0 then
				rowTable.TransferIn		= "-"
			else
				rowTable.TransferIn 		= TransferIn
				rowTable.TransferInToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_TRANSFER_IN_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.TransferIn, turnKey)
			end
			if Pillage 		== 0 then
				rowTable.Pillage		= "-"
			else
				rowTable.Pillage 		= Pillage
				rowTable.PillageToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_PILLAGE_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.Pillage, turnKey)
			end
			if OtherIn 		== 0 then
				rowTable.OtherIn		= "-"
			else
				rowTable.OtherIn 		= OtherIn
				rowTable.OtherInToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_OTHER_IN_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.OtherIn, turnKey)
			end

			rowTable.TotalIn		= TotalIn
			rowTable.TotalInToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_TOTAL_IN_DETAILS_TOOLTIP", toolTipHeader)
			rowTable.ResourceType 	= resRow.ResourceType

			table.insert(supplyTable, rowTable)
		end
	end

	table.sort(supplyTable, function(a, b) return a.ResourceType < b.ResourceType; end)
	return supplyTable
end

function GetResourcesDemandTable(self)
	local cityKey 			= self:GetKey()
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey	= GCO.GetPreviousTurnKey()
	local data 				= ExposedMembers.CityData[cityKey]
	local demandTable		= {}
	if not data.ResourceUse[turnKey] then return {} end
	--for resourceKey, useData in pairs(data.ResourceUse[turnKey]) do
	
	for resRow in GameInfo.Resources() do
		local resourceID 	= resRow.Index

		local Consume 		= self:GetUseTypeAtTurn(resourceID, ResourceUseType.Consume, turnKey)
		local Export 		= self:GetUseTypeAtTurn(resourceID, ResourceUseType.Export, turnKey)
		local TransferOut 	= self:GetUseTypeAtTurn(resourceID, ResourceUseType.TransferOut, turnKey)
		local Supply 		= self:GetUseTypeAtTurn(resourceID, ResourceUseType.Supply, turnKey)
		local Stolen 		= self:GetUseTypeAtTurn(resourceID, ResourceUseType.Stolen, previousTurnKey) -- all other players units have not attacked yet at the beginning of the player turn, so get previous turn value
		local OtherOut 		= self:GetUseTypeAtTurn(resourceID, ResourceUseType.OtherOut, turnKey)
		local TotalOut		= Consume + Export + TransferOut + Supply + Stolen + OtherOut

		if (TotalOut > 0) then
			local rowTable 			= {}
			--local resourceID 		= tonumber(resourceKey)
			--local resRow 			= GameInfo.Resources[resourceID]

			rowTable.Icon 		= GCO.GetResourceIcon(resourceID)			
			rowTable.Name 		= Locale.Lookup(resRow.Name)			
			
			local toolTipHeader	= rowTable.Icon .. " " .. rowTable.Name
			local separator		= Locale.Lookup("LOC_TOOLTIP_SEPARATOR")
		
			if Consume 		== 0 then
				rowTable.Consume		= "-"
			else
				rowTable.Consume 		= Consume
				rowTable.ConsumeToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_CONSUME_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.Consume, turnKey)
			end
			if Export 		== 0 then
				rowTable.Export		= "-"
			else
				rowTable.Export 		= Export
				rowTable.ExportToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_EXPORT_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.Export, turnKey)
			end
			if TransferOut 		== 0 then
				rowTable.TransferOut			= "-"
			else
				rowTable.TransferOut 		= TransferOut
				rowTable.TransferOutToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_TRANSFER_OUT_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.TransferOut, turnKey)
			end
			if Supply 	== 0 then
				rowTable.Supply		= "-"
			else
				rowTable.Supply 		= Supply
				rowTable.SupplyToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_UNIT_SUPPLY_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.Supply, turnKey)
			end
			if Stolen 		== 0 then
				rowTable.Stolen		= "-"
			else
				rowTable.Stolen 		= Stolen
				rowTable.StolenToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_STOLEN_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.Stolen, previousTurnKey)
			end
			if OtherOut 		== 0 then
				rowTable.OtherOut		= "-"
			else
				rowTable.OtherOut 		= OtherOut
				rowTable.OtherOutToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_OTHER_OUT_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.OtherOut, turnKey)
			end

			rowTable.TotalOut			= TotalOut
			rowTable.TotalOutToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_TOTAL_OUT_DETAILS_TOOLTIP", toolTipHeader)

			rowTable.ResourceType 	= resRow.ResourceType

			table.insert(demandTable, rowTable)
		end
	end

	table.sort(demandTable, function(a, b) return a.ResourceType < b.ResourceType; end)
	return demandTable
end

function GetExportCitiesTable(self)
	local cityKey 		= self:GetKey()
	local data 			= self:GetExportCities() or {}
	local citiesTable	= {}
	if not data then return {} end
	for routeCityKey, routeData in pairs(data) do

		local rowTable 			= {}
		local city				= GCO.GetCityFromKey(routeCityKey)
		
		rowTable.Name 			= Locale.Lookup(city:GetName())
		rowTable.NameToolTip	= Locale.Lookup(PlayerConfigurations[city:GetOwner()]:GetCivilizationShortDescription())
		rowTable.RouteType 		= GetSupplyRouteString(routeData.RouteType)
		rowTable.Efficiency 	= routeData.Efficiency
		
		local transportCost		= self:GetTransportCostTo(city)
		if transportCost == 0 then
			rowTable.TransportCost 	= Locale.Lookup("LOC_HUD_CITY_NO_COST")
		else
			rowTable.TransportCost 	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_COST", transportCost)
		end

		table.insert(citiesTable, rowTable)
	end

	table.sort(citiesTable, function(a, b) return a.Efficiency > b.Efficiency; end)
	return citiesTable
end

function GetTransferCitiesTable(self)
	local cityKey 		= self:GetKey()
	local data 			= self:GetTransferCities() or {}
	local citiesTable	= {}
	if not data then return {} end
	for routeCityKey, routeData in pairs(data) do

		local rowTable 			= {}
		local city				= GCO.GetCityFromKey(routeCityKey)
		
		if city:GetOwner() ~= self:GetOwner() then
			Dprint( DEBUG_CITY_SCRIPT, "WARNING : foreign city found in internal transfer list : " ..city:GetName())
			Dprint( DEBUG_CITY_SCRIPT, "WARNING : key = " ..routeCityKey)
		end
		
		rowTable.Name 			= Locale.Lookup(city:GetName())
		--rowTable.NameToolTip	= Locale.Lookup(PlayerConfigurations[city:GetOwner()]:GetCivilizationShortDescription())
		rowTable.RouteType 		= GetSupplyRouteString(routeData.RouteType)
		rowTable.Efficiency 	= routeData.Efficiency
		
		local transportCost		= self:GetTransportCostTo(city)
		if transportCost == 0 then
			rowTable.TransportCost 	= Locale.Lookup("LOC_HUD_CITY_NO_COST")
		else
			rowTable.TransportCost 	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_COST", transportCost)
		end

		table.insert(citiesTable, rowTable)
	end

	table.sort(citiesTable, function(a, b) return a.Efficiency > b.Efficiency; end)
	return citiesTable
end

function GetSupplyLinesTable(self)
	local cityKey 		= self:GetKey()
	local linkedUnits	= self:GetLinkedUnits() or {}
	local unitsTable	= {}
	if not LinkedUnits[cityKey] then return {} end	
	
	for unit, data in pairs(linkedUnits) do
	
		local rowTable 			= {}
		
		rowTable.Name 			= Locale.Lookup(unit:GetName())
		rowTable.Efficiency 	= unit:GetSupplyLineEfficiency()
		
		local Personnel 		= unit:GetNumResourceNeeded(personnelResourceID)
		local Materiel 			= unit:GetNumResourceNeeded(materielResourceID)
		local Horses 			= unit:GetNumResourceNeeded(horsesResourceID)	
		local Food 				= unit:GetNumResourceNeeded(foodResourceID)
		local Medicine 			= unit:GetNumResourceNeeded(medicineResourceID)		
		
		if Personnel	== 0 then  Personnel	= "-" end
		if Materiel 	== 0 then  Materiel 	= "-" end
		if Horses 		== 0 then  Horses 		= "-" end
		if Food 		== 0 then  Food 		= "-" end
		if Medicine 	== 0 then  Medicine 	= "-" end
		
		rowTable.Personnel 		= Personnel
		rowTable.Materiel 		= Materiel
		rowTable.Horses 		= Horses
		rowTable.Food 			= Food
		rowTable.Medicine 		= Medicine

		table.insert(unitsTable, rowTable)
	end

	table.sort(unitsTable, function(a, b) return a.Efficiency > b.Efficiency; end)
	return unitsTable
end


-----------------------------------------------------------------------------------------
-- Personnel functions
-----------------------------------------------------------------------------------------
function GetMaxPersonnel(self) -- called by GetMaxStock(self, personnelResourceID)
	local maxPersonnel = self:GetSize() * tonumber(GameInfo.GlobalParameters["CITY_PERSONNEL_PER_SIZE"].Value)

	return maxPersonnel
end

function GetPersonnel(self) -- equivalent to GetStock(self, personnelResourceID)
	return self:GetStock(personnelResourceID)
end

function GetPreviousPersonnel(self) -- equivalent to GetPreviousStock(self, personnelResourceID)
	return self:GetPreviousStock(personnelResourceID)
end

function ChangePersonnel(self, value, useType, reference) -- equivalent to ChangeStock(self, personnelResourceID, value)

	if not useType then
		if value > 0 then useType = ResourceUseType.Recruit end
		if value < 0 then useType = ResourceUseType.Supply end
	end
	self:ChangeStock(personnelResourceID, value, useType, reference)
end


-----------------------------------------------------------------------------------------
-- Food functions
-----------------------------------------------------------------------------------------
function GetFoodConsumption(self, optionalRatio)
	local cityKey = self:GetKey()
	local data = ExposedMembers.CityData[cityKey]
	local foodConsumption1000 = 0
	local ratio = optionalRatio or data.FoodRatio
	foodConsumption1000 = foodConsumption1000 + (self:GetUpperClass()	* tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_UPPER_CLASS_FACTOR"].Value) )
	foodConsumption1000 = foodConsumption1000 + (self:GetMiddleClass()	* tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_MIDDLE_CLASS_FACTOR"].Value) )
	foodConsumption1000 = foodConsumption1000 + (self:GetLowerClass()	* tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_LOWER_CLASS_FACTOR"].Value) )
	foodConsumption1000 = foodConsumption1000 + (self:GetSlaveClass()	* tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_SLAVE_CLASS_FACTOR"].Value) )
	foodConsumption1000 = foodConsumption1000 + (self:GetPersonnel()	* tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PERSONNEL_FACTOR"].Value) )
	-- value belows may be nil
	if data.WoundedPersonnel then
		foodConsumption1000 = foodConsumption1000 + (data.WoundedPersonnel * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_WOUNDED_FACTOR"].Value) )
	end
	if data.Prisoners then
		foodConsumption1000 = foodConsumption1000 + (GCO.GetTotalPrisoners(data) * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PRISONERS_FACTOR"].Value) )
	end
	return math.max(1, GCO.Round( foodConsumption1000 * ratio / 1000 ))
end

function GetCityBaseFoodStock(data)
	local city = CityManager.GetCity(data.playerID, data.cityID)
	return GCO.Round(city:GetMaxStock(foodResourceID) / 2)
end

function GetFoodRationing(self)
	local cityKey = self:GetKey()
	return ExposedMembers.CityData[cityKey].FoodRatio
end

function SetCityRationing(self)
	Dprint( DEBUG_CITY_SCRIPT, "Set Rationing...")
	local cityKey 	= self:GetKey()
	local cityData 	= ExposedMembers.CityData[cityKey]
	local ratio 	= cityData.FoodRatio
	local foodStock = self:GetStock(foodResourceID)
	if foodStock == 0 then
		ratio = Starvation
		ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		ExposedMembers.CityData[cityKey].FoodRatio = ratio
		return
	end
	local previousTurn	= tonumber(GCO.GetPreviousTurnKey())
	local previousTurnSupply = self:GetSupplyAtTurn(foodResourceID, previousTurn)
	local normalRatio = 1
	local foodVariation =  previousTurnSupply - self:GetFoodConsumption(normalRatio) -- self:GetStockVariation(foodResourceID) can't use stock variation here, as it will be equal to 0 when consumption > supply and there is not enough stock left (consumption capped at stock left...)

	Dprint( DEBUG_CITY_SCRIPT, " Food stock ", foodStock," Variation ",foodVariation, " Previous turn supply ", previousTurnSupply, " Consumption ", self:GetFoodConsumption(), " ratio ", ratio)
	if foodVariation < 0 and foodStock < (self:GetMaxStock(foodResourceID) / 2) then
		local turnBeforeFamine		= -(foodStock / foodVariation)
		if turnBeforeFamine < turnsToFamineHeavy then
			ratio = heavyRationing
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif turnBeforeFamine < turnsToFamineMedium then
			ratio = mediumRationing
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif turnBeforeFamine < turnsToFamineLight then
			ratio = lightRationing
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		end
	elseif Game.GetCurrentGameTurn() - cityData.FoodRatioTurn >= RationingTurnsLocked then
		if cityData.FoodRatio <= heavyRationing then
			ratio = mediumRationing
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif cityData.FoodRatio <= mediumRationing then
			ratio = lightRationing
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif cityData.FoodRatio <= lightRationing then
			ratio = 1
		end
	end
	ExposedMembers.CityData[cityKey].FoodRatio = ratio
end


----------------------------------------------
-- Texts function
----------------------------------------------
function GetResourcesStockString(self)
	local cityKey 			= self:GetKey()
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey	= GCO.GetPreviousTurnKey()
	local data 				= ExposedMembers.CityData[cityKey]
	local str 				= ""
	if not data.Stock[turnKey] then return end
	for resourceKey, value in pairs(data.Stock[turnKey]) do
		local resourceID 		= tonumber(resourceKey)
		if (value + self:GetSupplyAtTurn(resourceID, previousTurnKey) + self:GetDemandAtTurn(resourceID, previousTurnKey) + self:GetSupplyAtTurn(resourceID, turnKey) + self:GetDemandAtTurn(resourceID, turnKey) > 0 and resourceKey ~= foodResourceKey and resourceKey ~= personnelResourceKey) then
			local stockVariation 	= self:GetStockVariation(resourceID)
			local resourceCost 		= self:GetResourceCost(resourceID)
			local costVariation 	= self:GetResourceCostVariation(resourceID)
			local resRow 			= GameInfo.Resources[resourceID]

			--[[
			if ResourceTempIcons[resourceID] then
				str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_RESOURCE_TEMP_ICON_STOCK", value, self:GetMaxStock(resourceID), resRow.Name, ResourceTempIcons[resourceID])
			else
				str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_RESOURCE_STOCK", value, self:GetMaxStock(resourceID), resRow.Name, resRow.ResourceType)
			end
			--]]
			str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_RESOURCE_TEMP_ICON_STOCK", value, self:GetMaxStock(resourceID), resRow.Name, GCO.GetResourceIcon(resourceID))			

			str = str .. GCO.GetVariationString(stockVariation)

			local costVarStr = GCO.GetVariationStringRedPositive(costVariation)
			if resourceCost > 0 then
				str = str .." (".. Locale.Lookup("LOC_CITYBANNER_RESOURCE_COST", resourceCost)..costVarStr..")"
			end

		end
	end
	return str
end

function GetFoodStockString(self)
	local maxFoodStock 			= self:GetMaxStock(foodResourceID)
	local foodStock 			= self:GetStock(foodResourceID)
	local foodStockVariation 	= self:GetStockVariation(foodResourceID)
	local cityRationning 		= self:GetFoodRationing()

	local resourceCost 			= self:GetResourceCost(foodResourceID)
	local costVariation 		= self:GetResourceCostVariation(foodResourceID)

	local str 					= ""
	if cityRationning <= Starvation then
		str = Locale.Lookup("LOC_CITYBANNER_FOOD_RATION_HEAVY_RATIONING", foodStock, maxFoodStock)
	elseif cityRationning <= heavyRationing then
		str = Locale.Lookup("LOC_CITYBANNER_FOOD_RATION_HEAVY_RATIONING", foodStock, maxFoodStock)
	elseif cityRationning <= mediumRationing then
		str = Locale.Lookup("LOC_CITYBANNER_FOOD_RATION_MEDIUM_RATIONING", foodStock, maxFoodStock)
	elseif cityRationning <= lightRationing then
		str = Locale.Lookup("LOC_CITYBANNER_FOOD_RATION_LIGHT_RATIONING", foodStock, maxFoodStock)
	else
		str = Locale.Lookup("LOC_CITYBANNER_FOOD_RATION", foodStock, maxFoodStock)
	end
	str = str ..GCO.GetVariationString(foodStockVariation)

	local costVarStr = GCO.GetVariationStringRedPositive(costVariation)
	if resourceCost > 0 then
		str = str .." (".. Locale.Lookup("LOC_CITYBANNER_RESOURCE_COST", resourceCost)..costVarStr..")"
	end

	return str
end

function GetFoodConsumptionString(self)
	local foodConsumption		= self:GetFoodConsumption()
	local normalRatio 			= 1
	local foodMaxConsumption 	= self:GetFoodConsumption(normalRatio)
	local cityRationing 		= self:GetFoodRationing()

	local str 					= ""
	if cityRationing <= Starvation then
		str = Locale.Lookup("LOC_CITYBANNER_FOOD_STOCK_STARVATION", foodConsumption, foodMaxConsumption)
	elseif cityRationing <= heavyRationing then
		str = Locale.Lookup("LOC_CITYBANNER_FOOD_STOCK_HEAVY_RATIONING", foodConsumption, foodMaxConsumption)
	elseif cityRationing <= mediumRationing then
		str = Locale.Lookup("LOC_CITYBANNER_FOOD_STOCK_MEDIUM_RATIONING", foodConsumption, foodMaxConsumption)
	elseif cityRationing <= lightRationing then
		str = Locale.Lookup("LOC_CITYBANNER_FOOD_STOCK_LIGHT_RATIONING", foodConsumption, foodMaxConsumption)
	else
		str = Locale.Lookup("LOC_CITYBANNER_FOOD_STOCK", foodConsumption)
	end

	return str
end


-----------------------------------------------------------------------------------------
-- Do Turn for Cities
-----------------------------------------------------------------------------------------
function UpdateCosts(self)
	local cityKey 			= self:GetKey()
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey 	= GCO.GetPreviousTurnKey()

	-- update local prices
	local stockData = ExposedMembers.CityData[cityKey].Stock[turnKey]
	for resourceKey, value in pairs(stockData) do
		if resourceKey ~= personnelResourceKey then

			local resourceID 	= tonumber(resourceKey)
			local previousTurn	= tonumber(previousTurnKey)
			local demand 		= self:GetDemand(resourceID) -- include real demand for food (GetDemandAtTurn return the real use with rationing)
			local supply		= self:GetSupplyAtTurn(resourceID, previousTurn)

			local varPercent	= 0
			local stock 		= self:GetStock(resourceID)
			local maxStock		= self:GetMaxStock(resourceID)
			local actualCost	= self:GetResourceCost(resourceID)
			local minCost		= self:GetMinimumResourceCost(resourceID)
			local maxCost		= self:GetMaximumResourceCost(resourceID)
			local newCost 		= actualCost

			Dprint( DEBUG_CITY_SCRIPT, "- Actualising cost of "..Locale.Lookup(GameInfo.Resources[resourceID].Name)," actual cost",actualCost,"stock",stock,"maxStock",maxStock,"demand",demand,"supply",supply)

			if supply > demand or stock == maxStock then

				local turnUntilFull = (maxStock - stock) / (supply - demand)
				if turnUntilFull == 0 then
					varPercent = MaxCostVariationPercent
				else
					varPercent = math.min(MaxCostVariationPercent, 1 / (turnUntilFull / (maxStock / 2)))
				end
				local variation = math.min(actualCost * varPercent / 100, (actualCost - minCost) / 2)
				newCost = actualCost - variation
				self:SetResourceCost(resourceID, newCost)
				Dprint( DEBUG_CITY_SCRIPT, "  New cost = ".. tostring(newCost), "  max cost",maxCost,"min cost",minCost,"turn until full",turnUntilFull,"variation",variation)

			elseif demand > supply then

				local turnUntilEmpty = stock / (demand - supply)
				if turnUntilEmpty == 0 then
					varPercent = MaxCostVariationPercent
				else
					varPercent = math.min(MaxCostVariationPercent, 1 / (turnUntilEmpty / (maxStock / 2)))
				end
				local variation = math.min(actualCost * varPercent / 100, (maxCost - actualCost) / 2)
				newCost = actualCost + variation
				self:SetResourceCost(resourceID, newCost)
				Dprint( DEBUG_CITY_SCRIPT, "  New cost = ".. tostring(newCost), "  max cost",maxCost,"min cost",minCost,"turn until empty",turnUntilEmpty,"variation",variation)

			end
		end
	end

end

function UpdateDataOnNewTurn(self) -- called for every player at the beginning of a new turn

	Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
	Dprint( DEBUG_CITY_SCRIPT, "Updating Data for ".. Locale.Lookup(self:GetName()))
	local cityKey 			= self:GetKey()
	local data 				= ExposedMembers.CityData[cityKey]
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey 	= GCO.GetPreviousTurnKey()
	if turnKey ~= previousTurnKey then

		-- initialize empty tables for the new turn data
		ExposedMembers.CityData[cityKey].Stock[turnKey] 		= {}
		ExposedMembers.CityData[cityKey].ResourceCost[turnKey]	= {}
		ExposedMembers.CityData[cityKey].Population[turnKey]	= {}
		ExposedMembers.CityData[cityKey].ResourceUse[turnKey]	= {}

		-- get previous turn data
		local stockData = ExposedMembers.CityData[cityKey].Stock[previousTurnKey]
		local costData 	= ExposedMembers.CityData[cityKey].ResourceCost[previousTurnKey]
		local popData 	= ExposedMembers.CityData[cityKey].Population[previousTurnKey]

		-- fill the new table with previous turn data
		for resourceKey, value in pairs(stockData) do
			ExposedMembers.CityData[cityKey].Stock[turnKey][resourceKey] = value
		end

		for resourceKey, value in pairs(costData) do
			ExposedMembers.CityData[cityKey].ResourceCost[turnKey][resourceKey] = value
		end

		for key, value in pairs(popData) do
			ExposedMembers.CityData[cityKey].Population[turnKey][key] = value
		end

		self:UpdateCosts()
	end
end

function DoRecruitPersonnel(self)
	Dprint( DEBUG_CITY_SCRIPT, "Recruiting Personnel...")
	local nedded 			= math.max(0, self:GetMaxPersonnel() - self:GetPersonnel())

	local generals			= GCO.Round(nedded*PersonnelHighRankRatio)
	local officers			= GCO.Round(nedded*PersonnelMiddleRankRatio)
	local soldiers			= math.max(0, nedded - (generals + officers))

	local maxUpper 			= GCO.Round(self:GetUpperClass()	* UpperClassToPersonnelRatio)
	local maxMiddle			= GCO.Round(self:GetMiddleClass()	* MiddleClassToPersonnelRatio)
	local maxLower 			= GCO.Round(self:GetLowerClass()	* LowerClassToPersonnelRatio)
	local maxPotential		= maxUpper + maxMiddle + maxLower

	local recruitedGenerals = math.min(generals, maxUpper)
	local recruitedOfficers = math.min(officers, maxMiddle)
	local recruitedSoldiers = math.min(soldiers, maxLower)
	local totalRecruits		= recruitedGenerals + recruitedOfficers + recruitedSoldiers

	Dprint( DEBUG_CITY_SCRIPT, " - total needed =", nedded, "generals =", generals,"officers =", officers, "soldiers =",soldiers)
	Dprint( DEBUG_CITY_SCRIPT, " - max potential =", maxPotential ,"Upper = ", maxUpper, "Middle = ", maxMiddle, "Lower = ", maxLower )
	Dprint( DEBUG_CITY_SCRIPT, " - total recruits =", totalRecruits, "Generals = ", recruitedGenerals, "Officers = ", recruitedOfficers, "Soldiers = ", recruitedSoldiers )

	self:ChangeUpperClass(-recruitedGenerals)
	self:ChangeMiddleClass(-recruitedOfficers)
	self:ChangeLowerClass(-recruitedSoldiers)
	self:ChangePersonnel(recruitedGenerals, ResourceUseType.Recruit, RefPopulationUpper)
	self:ChangePersonnel(recruitedOfficers, ResourceUseType.Recruit, RefPopulationMiddle)
	self:ChangePersonnel(recruitedSoldiers, ResourceUseType.Recruit, RefPopulationLower)
end

function DoReinforceUnits(self)
	Dprint( DEBUG_CITY_SCRIPT, "Reinforcing units...")
	local cityKey 				= self:GetKey()
	local cityData 				= ExposedMembers.CityData[cityKey]
	local supplyDemand 			= UnitsSupplyDemand[cityKey]
	local reinforcements 		= {Resources = {}, ResPerUnit = {}}

	if supplyDemand.Equipment and supplyDemand.Equipment > 0 then
		Dprint( DEBUG_CITY_SCRIPT, "- Required Equipment = ", tostring(supplyDemand.Equipment), " for " , tostring(supplyDemand.NeedEquipment) ," units")
	end

	for resourceID, value in pairs(supplyDemand.Resources) do
		reinforcements.Resources[resourceID] = math.min(value, self:GetAvailableStockForUnits(resourceID))
		reinforcements.ResPerUnit[resourceID] = math.floor(reinforcements.Resources[resourceID]/supplyDemand.NeedResources[resourceID])
		Dprint( DEBUG_CITY_SCRIPT, "- Max transferable ".. Locale.Lookup(GameInfo.Resources[resourceID].Name).. " = ".. tostring(value) .. " for " .. tostring(supplyDemand.NeedResources[resourceID]) .." units, available = " .. tostring(self:GetAvailableStockForUnits(resourceID))..", send = ".. tostring(reinforcements.Resources[resourceID]))
	end
	reqValue = {}
	for resourceID, value in pairs(reinforcements.Resources) do
		--if directReinforcement[resourceID]  then
			local resLeft = value
			local maxLoop = 5
			local loop = 0
			while (resLeft > 0 and loop < maxLoop) do
				for unit, data in pairs(LinkedUnits[cityKey]) do
					local efficiency = unit:GetSupplyLineEfficiency()
					if not reqValue[unit] then reqValue[unit] = {} end
					if not reqValue[unit][resourceID] then reqValue[unit][resourceID] = GCO.Round(unit:GetNumResourceNeeded(resourceID)*efficiency/100) end
					if reqValue[unit][resourceID] > 0 then
						local efficiency	= unit:GetSupplyLineEfficiency()
						local send 			= math.min(reinforcements.ResPerUnit[resourceID], reqValue[unit][resourceID], resLeft)

						resLeft = resLeft - send
						reqValue[unit][resourceID] = reqValue[unit][resourceID] - send

						unit:ChangeStock(resourceID, send)
						self:ChangeStock(resourceID, -send, ResourceUseType.Supply, unit:GetKey())
						Dprint( DEBUG_CITY_SCRIPT, "  - send " .. tostring(send) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." (@ ".. tostring(efficiency) .." % efficiency) to unit ID#".. tostring(unit:GetID()), Locale.Lookup(UnitManager.GetTypeName(unit)))
					end
				end
				loop = loop + 1
			end
		--else
			-- todo : make vehicles from resources
		--end
	end

end

function DoCollectResources(self)
	local cityKey 		= self:GetKey()
	local cityData 		= ExposedMembers.CityData[cityKey]
	local cityWealth	= self:GetWealth()
	local player 		= GCO.GetPlayer(self:GetOwner())

	-- private function
	function Collect(resourceID, collected, resourceCost, plotID, bWorked, bImprovedForResource)
		if bImprovedForResource then
			collected 		= collected * BaseImprovementMultiplier
			resourceCost 	= resourceCost * ImprovementCostRatio
		end
		resourceCost = resourceCost * cityWealth
		if not bWorked then resourceCost = resourceCost * NotWorkedCostMultiplier end
		Dprint( DEBUG_CITY_SCRIPT, "-- Collecting " .. tostring(collected) .. " " ..Locale.Lookup(GameInfo.Resources[resourceID].Name).." at ".. tostring(GCO.ToDecimals(resourceCost)) .. " cost/unit")
		self:ChangeStock(resourceID, collected, ResourceUseType.Collect, plotID, resourceCost)
	end

	-- get resources on worked tiles
	local cityPlots	= GCO.GetCityPlots(self)
	for _, plotID in ipairs(cityPlots) do
		local plot		= Map.GetPlotByIndex(plotID)
		local bWorked 	= (plot:GetWorkerCount() > 0)
		local bImproved	= (plot:GetImprovementType() ~= NO_IMPROVEMENT)
		if bWorked or bImproved then

			local improvementID = plot:GetImprovementType()
			if plot:GetResourceCount() > 0 then
				local resourceID 	= plot:GetResourceType()
				local resourceCost 	= GCO.GetBaseResourceCost(resourceID)
				if player:IsResourceVisible(resourceID) then
					local collected 			= plot:GetResourceCount()
					local bImprovedForResource	= (IsImprovementForResource[improvementID] and IsImprovementForResource[improvementID][resourceID])
					Collect(resourceID, collected, resourceCost, plotID, bWorked, bImprovedForResource)
				end
			end

			local featureID = plot:GetFeatureType()
			if FeatureResources[featureID] then
				for _, data in pairs(FeatureResources[featureID]) do
					for resourceID, value in pairs(data) do
						if player:IsResourceVisible(resourceID) then
							local collected 	= value
							local resourceCost 	= GCO.GetBaseResourceCost(resourceID)
							local bImprovedForResource	= (IsImprovementForFeature[improvementID] and IsImprovementForFeature[improvementID][featureID])
							Collect(resourceID, collected, resourceCost, plotID, bWorked, bImprovedForResource)
						end
					end
				end
			end
		end
	end
end

function DoIndustries(self)

	Dprint( DEBUG_CITY_SCRIPT, "Creating resources in Industries...")

	local size 		= self:GetSize()
	local wealth 	= self:GetWealth()

	-- materiel
	local materielprod	= MaterielProductionPerSize * size
	local materielCost 	= GCO.GetBaseResourceCost(materielResourceID) * wealth -- GCO.GetBaseResourceCost(materielResourceID)
	Dprint( DEBUG_CITY_SCRIPT, " - City production: ".. tostring(materielprod) .." ".. Locale.Lookup(GameInfo.Resources[materielResourceID].Name).." at ".. tostring(GCO.ToDecimals(materielCost)) .. " cost/unit")
	self:ChangeStock(materielResourceID, materielprod, ResourceUseType.Product, self:GetKey(), materielCost)

	local MultiResRequired 	= {}
	local MultiResCreated 	= {}
	for row in GameInfo.BuildingResourcesConverted() do
		local buildingID 	= GameInfo.Buildings[row.BuildingType].Index
		if self:GetBuildings():HasBuilding(buildingID) then
			local resourceRequiredID = GameInfo.Resources[row.ResourceType].Index
			--Dprint( DEBUG_CITY_SCRIPT, " - check " .. Locale.Lookup(GameInfo.Buildings[buildingID].Name) .." production using ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name))
			if row.MultiResRequired then
				local resourceCreatedID = GameInfo.Resources[row.ResourceCreated].Index
				if not MultiResRequired[resourceCreatedID] then	MultiResRequired[resourceCreatedID] = {[buildingID] = {}} end
				table.insert(MultiResRequired[resourceCreatedID][buildingID], {ResourceRequired = resourceRequiredID, MaxConverted = row.MaxConverted, Ratio = row.Ratio})

			elseif row.MultiResCreated then
				local resourceCreatedID = GameInfo.Resources[row.ResourceCreated].Index
				if not MultiResCreated[resourceRequiredID] then	MultiResCreated[resourceRequiredID] = {[buildingID] = {}} end
				table.insert(MultiResCreated[resourceRequiredID][buildingID], {ResourceCreated = resourceCreatedID, MaxConverted = row.MaxConverted, Ratio = row.Ratio})
			else
				local available = self:GetAvailableStockForIndustries(resourceRequiredID)
				--Dprint( DEBUG_CITY_SCRIPT, "			available = ", available)
				if available > 0 then
					local resourceCreatedID = GameInfo.Resources[row.ResourceCreated].Index
					local amountUsed		= math.min(available, row.MaxConverted)
					local amountCreated		= math.floor(amountUsed * row.Ratio)
				--Dprint( DEBUG_CITY_SCRIPT, "			amountUsed = ", amountUsed)
				--Dprint( DEBUG_CITY_SCRIPT, "			amountCreated = ", amountCreated)

					-- don't allow excedent if there is no demand
					local bLimitedByExcedent	= false
					local stockVariation 	= self:GetStockVariation(resourceID)
				--Dprint( DEBUG_CITY_SCRIPT, "			bLimitedByExcedent = ", bLimitedByExcedent)
				--Dprint( DEBUG_CITY_SCRIPT, "			stockVariation = ", stockVariation)
					if amountCreated + self:GetStock(resourceID) > self:GetMaxStock(resourceID) and stockVariation >= 0 then
						local maxCreated 	= self:GetMaxStock(resourceID) - self:GetStock(resourceID)
						amountUsed 			= math.floor(maxCreated / row.Ratio)
						amountCreated		= math.floor(amountUsed * row.Ratio)
						bLimitedByExcedent	= true
					end

					if amountCreated > 0 then
						local resourceCost 	= (GCO.GetBaseResourceCost(resourceCreatedID) / row.Ratio * wealth) + (self:GetResourceCost(resourceRequiredID) / row.Ratio)
						Dprint( DEBUG_CITY_SCRIPT, " - " .. Locale.Lookup(GameInfo.Buildings[buildingID].Name) .." production: ".. tostring(amountCreated) .." ".. Locale.Lookup(GameInfo.Resources[resourceCreatedID].Name).." at ".. tostring(GCO.ToDecimals(resourceCost)) .. " cost/unit, using ".. tostring(amountUsed) .." ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name) ..", limited by excedent = ".. tostring(bLimitedByExcedent))
						self:ChangeStock(resourceRequiredID, - amountUsed, ResourceUseType.Consume, buildingID)
						self:ChangeStock(resourceCreatedID, amountCreated, ResourceUseType.Product, buildingID, resourceCost)
					end
				end
			end
		end
	end

	for resourceRequiredID, data1 in pairs(MultiResCreated) do
		for buildingID, data2 in pairs (data1) do
			local bUsed			= false
			local available 	= self:GetAvailableStockForIndustries(resourceRequiredID)
			if available > 0 then
				Dprint( DEBUG_CITY_SCRIPT, " - " .. Locale.Lookup(GameInfo.Buildings[buildingID].Name) .." production of multiple resources using ".. tostring(available) .." available ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name))
				local amountUsed 			= 0
				local maxRequired			= 0
				local bLimitedByExcedent	= true
				for _, row in ipairs(data2) do
					amountUsed = math.min(available, row.MaxConverted)
					local amountCreated		= math.floor(amountUsed * row.Ratio)

					-- don't allow excedent if there is no demand
					local stockVariation 	= self:GetStockVariation(row.ResourceCreated)
					if amountCreated + self:GetStock(row.ResourceCreated) > self:GetMaxStock(row.ResourceCreated) and stockVariation >= 0 then
						amountCreated 		= self:GetMaxStock(row.ResourceCreated) - self:GetStock(row.ResourceCreated)
						amountUsed			= math.floor(amountCreated / row.Ratio)
					else -- limit only if all resource created will generate excedents
						bLimitedByExcedent	= false
					end
					maxRequired	= math.max( maxRequired, amountUsed)

					if amountCreated > 0 then
						local resourceCost 	= (GCO.GetBaseResourceCost(row.ResourceCreated) / row.Ratio * wealth) + (self:GetResourceCost(resourceRequiredID) / row.Ratio)
						Dprint( DEBUG_CITY_SCRIPT, "    - ".. tostring(amountCreated) .." ".. Locale.Lookup(GameInfo.Resources[row.ResourceCreated].Name).." created at ".. tostring(GCO.ToDecimals(resourceCost)) .. " cost/unit, ratio = " .. tostring(row.Ratio) .. ", used ".. tostring(amountUsed) .." ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name) ..", limited by excedent = ".. tostring(bLimitedByExcedent))
						self:ChangeStock(row.ResourceCreated, amountCreated, ResourceUseType.Product, buildingID, resourceCost)
						bUsed = true
					elseif bLimitedByExcedent then
						Dprint( DEBUG_CITY_SCRIPT, "    - not producing ".. Locale.Lookup(GameInfo.Resources[row.ResourceCreated].Name) .." to prevent excedent without use.")
					else
						Dprint( DEBUG_CITY_SCRIPT, "    - not enough resources available to create ".. Locale.Lookup(GameInfo.Resources[row.ResourceCreated].Name) ..", ratio = " .. tostring(row.Ratio))
					end
				end
				if bUsed then
					self:ChangeStock(resourceRequiredID, - maxRequired, ResourceUseType.Consume, buildingID)
				end
			end
		end
	end

	for resourceCreatedID, data1 in pairs(MultiResRequired) do
		for buildingID, data2 in pairs (data1) do
			local bCanCreate				= true
			local requiredResourcesRatio 	= {}
			local amountCreated				= nil
			local bLimitedByExcedent		= false
			for _, row in ipairs(data2) do
				if bCanCreate then
					local available = self:GetAvailableStockForIndustries(row.ResourceRequired)
					if available > 0 then
						local maxAmountUsed			= math.min(available, row.MaxConverted)
						local maxResourceCreated	= maxAmountUsed * row.Ratio -- no rounding here, we'll use this number to recalculate the amount used

						-- don't allow excedent if there is no demand
						local stockVariation 	= self:GetStockVariation(resourceCreatedID)
						if maxResourceCreated + self:GetStock(resourceCreatedID) > self:GetMaxStock(resourceCreatedID) and stockVariation >= 0 then
							maxResourceCreated 	= self:GetMaxStock(resourceCreatedID) - self:GetStock(resourceCreatedID)
							bLimitedByExcedent	= true
						end

						if not amountCreated then amountCreated = maxResourceCreated end
						if math.floor(maxResourceCreated) > 0 then
							requiredResourcesRatio[row.ResourceRequired] = row.Ratio
							amountCreated = math.min(amountCreated, maxResourceCreated)
						else
							bCanCreate = false
						end
					else
						bCanCreate = false
					end
				end
			end

			if bCanCreate then
				Dprint( DEBUG_CITY_SCRIPT, " - " .. Locale.Lookup(GameInfo.Buildings[buildingID].Name) .." production: ".. tostring(amountCreated) .." ".. Locale.Lookup(GameInfo.Resources[resourceCreatedID].Name).. " using multiple resource")
				local requiredResourceCost = 0
				local totalResourcesRequired = #requiredResourcesRatio
				local totalRatio = 0
				for resourceRequiredID, ratio in pairs(requiredResourcesRatio) do
					local amountUsed = GCO.Round(amountCreated / ratio) -- we shouldn't be here if ratio = 0, and the rounded value should be < maxAmountUsed
					local resourceCost = (self:GetResourceCost(resourceRequiredID) / ratio)
					requiredResourceCost = requiredResourceCost + resourceCost
					totalRatio = totalRatio + ratio
					Dprint( DEBUG_CITY_SCRIPT, "    - ".. tostring(amountUsed) .." ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name) .." used at ".. tostring(GCO.ToDecimals(resourceCost)) .. " cost/unit, ratio = " .. tostring(ratio))
					self:ChangeStock(resourceRequiredID, - amountUsed, ResourceUseType.Consume, buildingID)
				end
				local baseRatio = totalRatio / totalResourcesRequired
				resourceCost = (GCO.GetBaseResourceCost(resourceCreatedID) / baseRatio * wealth) + requiredResourceCost
				Dprint( DEBUG_CITY_SCRIPT, "    - " ..  Locale.Lookup(GameInfo.Resources[resourceCreatedID].Name).. " cost per unit  = "..resourceCost ..", limited by excedent = ".. tostring(bLimitedByExcedent))
				self:ChangeStock(resourceCreatedID, amountCreated, ResourceUseType.Product, buildingID, resourceCost)
			end
		end
	end
end

function DoExcedents(self)

	Dprint( DEBUG_CITY_SCRIPT, "Handling excedent...")

	local cityKey 	= self:GetKey()
	local cityData 	= ExposedMembers.CityData[cityKey]
	local turnKey 	= GCO.GetTurnKey()

	-- excedental personnel is sent back to civil life... (to do : send them to another location if available)
	local excedentalPersonnel = self:GetPersonnel() - self:GetMaxPersonnel()

	if excedentalPersonnel > 0 then

		local toUpper 	= GCO.Round(excedentalPersonnel * PersonnelToUpperClassRatio)
		local toMiddle 	= GCO.Round(excedentalPersonnel * PersonnelToMiddleClassRatio)
		local toLower	= math.max(0, excedentalPersonnel - (toMiddle + toUpper))

		self:ChangeUpperClass(toUpper)
		self:ChangeMiddleClass(toMiddle)
		self:ChangeLowerClass(toLower)

		self:ChangePersonnel(-toUpper, ResourceUseType.Demobilize, RefPopulationUpper)
		self:ChangePersonnel(-toMiddle, ResourceUseType.Demobilize, RefPopulationMiddle)
		self:ChangePersonnel(-toLower, ResourceUseType.Demobilize, RefPopulationLower)

		Dprint( DEBUG_CITY_SCRIPT, " - Demobilized personnel =", excedentalPersonnel, "upper class =", toUpper,"middle class =", toMiddle, "lower class =",toLower)

	end

	-- excedental resources are lost
	for resourceKey, value in pairs(cityData.Stock[turnKey]) do
		local resourceID = tonumber(resourceKey)
		local excedent = self:GetStock(resourceID) - self:GetMaxStock(resourceID)
		if excedent > 0 then
			Dprint( DEBUG_CITY_SCRIPT, " - Excedental ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." destroyed = ".. tostring(excedent))
			self:ChangeStock(resourceID, -excedent, ResourceUseType.Waste)
		end
	end

end

function DoGrowth(self)

	local DEBUG_CITY_SCRIPT = true
	
	if Game.GetCurrentGameTurn() < 2 and bUseRealYears then return end -- we need to know the previous year turn to calculate growth rate...
	Dprint( DEBUG_CITY_SCRIPT, "Calculate city growth for ".. Locale.Lookup(self:GetName()))
	local cityKey = self:GetKey()
	--local cityData = ExposedMembers.CityData[cityKey]
	local cityBirthRate = self:GetBirthRate()
	local cityDeathRate = self:GetDeathRate()
	Dprint( DEBUG_CITY_SCRIPT, "Global :	BirthRate = ", cityBirthRate, " DeathRate = ", cityDeathRate)
	local years = GrowthRateBaseYears
	if bUseRealYears then
		years = Calendar.GetTurnYearForGame(Game.GetCurrentGameTurn()) - Calendar.GetTurnYearForGame(Game.GetCurrentGameTurn()-1)
	end
	function LimitRate(birth, death)
		local rate = math.min(ClassMaximalGrowthRate, math.max(ClassMinimalGrowthRate, birth - death))
		return rate
	end

	local upperPop	= self:GetUpperClass()
	local middlePop = self:GetMiddleClass()
	local lowerPop	= self:GetLowerClass()
	local slavePop 	= self:GetSlaveClass()

	function CalculateVar(initialPopulation, populationBirthRate, populationDeathRate )
		return GCO.Round( initialPopulation	* years * LimitRate(populationBirthRate, populationDeathRate) / 1000)
	end
	local upperVar	= CalculateVar( upperPop, self:GetPopulationBirthRate(UpperClassID), self:GetPopulationDeathRate(UpperClassID))
	local middleVar = CalculateVar( middlePop, self:GetPopulationBirthRate(MiddleClassID), self:GetPopulationDeathRate(MiddleClassID))
	local lowerVar	= CalculateVar( lowerPop, self:GetPopulationBirthRate(LowerClassID), self:GetPopulationDeathRate(LowerClassID))
	local slaveVar 	= CalculateVar( slavePop, self:GetPopulationBirthRate(SlaveClassID), self:GetPopulationDeathRate(SlaveClassID))
	
	
	Dprint( DEBUG_CITY_SCRIPT, "Upper :		BirthRate = ", self:GetPopulationBirthRate(UpperClassID), " DeathRate = ", self:GetPopulationDeathRate(UpperClassID), " Initial Population = ", upperPop, " Variation = ", upperVar )
	Dprint( DEBUG_CITY_SCRIPT, "Middle :	BirthRate = ", self:GetPopulationBirthRate(MiddleClassID), " DeathRate = ", self:GetPopulationDeathRate(MiddleClassID), " Initial Population = ", middlePop, " Variation = ", middleVar )
	Dprint( DEBUG_CITY_SCRIPT, "Lower :		BirthRate = ", self:GetPopulationBirthRate(LowerClassID), " DeathRate = ", self:GetPopulationDeathRate(LowerClassID), " Initial Population = ", lowerPop, " Variation = ", lowerVar )
	Dprint( DEBUG_CITY_SCRIPT, "Slave :		BirthRate = ", self:GetPopulationBirthRate(SlaveClassID), " DeathRate = ", self:GetPopulationDeathRate(SlaveClassID), " Initial Population = ", slavePop, " Variation = ", slaveVar )

	self:ChangeUpperClass(upperVar)
	self:ChangeMiddleClass(middleVar)
	self:ChangeLowerClass(lowerVar)
	self:ChangeSlaveClass(slaveVar)

end

function DoFood(self)
	-- get city food yield
	local food = self:GetCityYield(YieldTypes.FOOD )
	local resourceCost = GCO.GetBaseResourceCost(foodResourceID) * self:GetWealth() * ImprovementCostRatio -- assume that city food yield is low cost (like collected with improvement)
	self:ChangeStock(foodResourceID, food, ResourceUseType.Collect, self:GetKey(), resourceCost)

	-- food eaten
	local eaten = self:GetFoodConsumption()
	self:ChangeStock(foodResourceID, - eaten, ResourceUseType.Consume, RefPopulationAll)
end

function DoNeeds(self)

	local DEBUG_CITY_SCRIPT = true
	
	Dprint( DEBUG_CITY_SCRIPT, "handling Population needs...")
	
	local cityKey = self:GetKey()
	
	-- (re)initialize cached table
	if not _cached[cityKey] then _cached[cityKey] = {} end
	_cached[cityKey].NeedsEffects = {
		[UpperClassID] 	= { [NeedsEffectType.BirthRate] = {},  [NeedsEffectType.DeathRate] = {},},
		[MiddleClassID] = { [NeedsEffectType.BirthRate] = {},  [NeedsEffectType.DeathRate] = {},},
		[LowerClassID] 	= { [NeedsEffectType.BirthRate] = {},  [NeedsEffectType.DeathRate] = {},},
	}
	
	-- Upper Class
	local upperHousingSize		= self:GetCityYield( YieldTypes.UPPER_HOUSING )
	local upperHousing			= GetPopulationPerSize(upperHousingSize)
	local upperPopulation		= self:GetPopulationClass(UpperClassID)
	local upperHousingAvailable	= math.max( 0, upperHousing - upperPopulation)
	local upperLookingForMiddle	= math.max( 0, upperPopulation - upperHousing)
	Dprint( DEBUG_CITY_SCRIPT, "Upper Class Needs : Housing Size = ", upperHousingSize, " Housing Capacity = ", upperHousing, " Population = ", upperPopulation, " Available housing = ", upperHousingAvailable)
	
	-- Middle Class
	local middleHousingSize			= self:GetCityYield( YieldTypes.MIDDLE_HOUSING )
	local middleHousing				= GetPopulationPerSize(middleHousingSize)
	local middlePopulation			= self:GetPopulationClass(MiddleClassID)
	local middleHousingAvailable	= math.max( 0, middleHousing - middlePopulation - upperLookingForMiddle)
	local middleLookingForLower		= math.max( 0, (middlePopulation + upperLookingForMiddle) - middleHousing)
	Dprint( DEBUG_CITY_SCRIPT, "Middle Class Needs : Housing Size = ", middleHousingSize, " Housing Capacity = ", middleHousing, " Population = ", middlePopulation, " Available housing = ", middleHousingAvailable)
	
	-- Lower Class
	local lowerHousingSize		= self:GetCityYield( YieldTypes.LOWER_HOUSING )
	local lowerHousing			= GetPopulationPerSize(lowerHousingSize)
	local lowerPopulation		= self:GetPopulationClass(LowerClassID)
	local lowerHousingAvailable	= math.max( 0, lowerHousing - lowerPopulation - middleLookingForLower)
	Dprint( DEBUG_CITY_SCRIPT, "Lower Class Needs : Housing Size = ", lowerHousingSize, " Housing Capacity = ", lowerHousing, " Population = ", lowerPopulation, " Available housing = ", lowerHousingAvailable)
	
	-- Private functions
	function GetMaxPercentFromLowDiff(maxEffectValue, higherValue, lowerValue) 	-- Return a higher value lowerValue is high
		return maxEffectValue*(lowerValue/higherValue)
	end	
	function GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue)	-- Return a higher value if lowerValue is low
		return maxEffectValue*(100-(lowerValue/higherValue*100))/100
	end
	function LimitEffect(maxEffectValue, effectValue)							-- Keep effectValue never equals to maxEffectValue
		return GCO.ToDecimals(maxEffectValue*effectValue/(maxEffectValue+1))
	end
	
	-- Housing Upper Class	
	Dprint( DEBUG_CITY_SCRIPT, "Upper class Housing effect...")
	local upperGrowthRateLeft = math.max ( 0, self:GetBasePopulationBirthRate(UpperClassID) - self:GetBasePopulationDeathRate(UpperClassID))
	if upperHousingAvailable > upperHousing / 2 then -- BirthRate bonus from housing available
		local maxEffectValue 	= 5
		local higherValue 		= (upperHousing / 2)
		local lowerValue 		= upperHousingAvailable - (upperHousing / 2)
		local effectValue		= GCO.ToDecimals(GetMaxPercentFromLowDiff(maxEffectValue, higherValue, lowerValue))
		_cached[cityKey].NeedsEffects[UpperClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_BONUS_FROM_HOUSING"] = effectValue
		Dprint( DEBUG_CITY_SCRIPT, Locale.Lookup("LOC_BIRTHRATE_BONUS_FROM_HOUSING", effectValue))
	elseif upperGrowthRateLeft > 0 and (upperHousingAvailable < upperHousing * 25 / 100) and (middleHousingAvailable < middleHousing * 25 / 100) then -- BirthRate malus from low housing left (upper class can use middle class housing if available)
		local maxEffectValue 	= upperGrowthRateLeft
		local higherValue 		= (upperHousing + middleHousing) * 25 / 100
		local lowerValue 		= upperHousingAvailable + middleHousingAvailable
		local effectValue		= GCO.ToDecimals(GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue))
		effectValue				= LimitEffect(maxEffectValue, effectValue)
		_cached[cityKey].NeedsEffects[UpperClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING"] = - effectValue
		Dprint( DEBUG_CITY_SCRIPT, maxEffectValue, higherValue, lowerValue, Locale.Lookup("LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING", - effectValue))
		upperGrowthRateLeft = upperGrowthRateLeft - effectValue
	end	
	
	-- Housing Middle Class	
	Dprint( DEBUG_CITY_SCRIPT, "Middle class Housing effect...")
	local middleGrowthRateLeft = math.max ( 0, self:GetBasePopulationBirthRate(MiddleClassID) - self:GetBasePopulationDeathRate(MiddleClassID))
	if middleHousingAvailable > middleHousing / 2 then -- BirthRate bonus from housing available
		local maxEffectValue 	= 5
		local higherValue 		= (middleHousing / 2)
		local lowerValue 		= middleHousingAvailable - (middleHousing / 2)
		local effectValue		= GCO.ToDecimals(GetMaxPercentFromLowDiff(maxEffectValue, higherValue, lowerValue))
		_cached[cityKey].NeedsEffects[MiddleClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_BONUS_FROM_HOUSING"] = effectValue
		Dprint( DEBUG_CITY_SCRIPT, Locale.Lookup("LOC_BIRTHRATE_BONUS_FROM_HOUSING", effectValue))
	elseif middleGrowthRateLeft > 0 and (middleHousingAvailable < middleHousing * 25 / 100) and (lowerHousingAvailable < lowerHousing * 25 / 100)  then -- BirthRate malus from low housing left (middle class can use lower class housing if available)
		local maxEffectValue 	= middleGrowthRateLeft
		local higherValue 		= (middleHousing + lowerHousing) * 25 / 100
		local lowerValue 		= middleHousingAvailable + lowerHousingAvailable
		local effectValue		= GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue)
		effectValue				= LimitEffect(maxEffectValue, effectValue)
		_cached[cityKey].NeedsEffects[MiddleClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING"] = - effectValue
		Dprint( DEBUG_CITY_SCRIPT, maxEffectValue, higherValue, lowerValue, Locale.Lookup("LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING", - effectValue))
		middleGrowthRateLeft = middleGrowthRateLeft - effectValue
	end	
	
	-- Housing Lower Class	
	Dprint( DEBUG_CITY_SCRIPT, "Lower class Housing effect...")
	local lowerGrowthRateLeft = math.max ( 0, self:GetBasePopulationBirthRate(LowerClassID) - self:GetBasePopulationDeathRate(LowerClassID))
	if lowerHousingAvailable > lowerHousing / 2 then -- BirthRate bonus from housing available
		local maxEffectValue 	= 5
		local higherValue 		= (lowerHousing / 2)
		local lowerValue 		= lowerHousingAvailable - (lowerHousing / 2)
		local effectValue		= GCO.ToDecimals(GetMaxPercentFromLowDiff(maxEffectValue, higherValue, lowerValue))
		_cached[cityKey].NeedsEffects[LowerClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_BONUS_FROM_HOUSING"] = effectValue
		Dprint( DEBUG_CITY_SCRIPT, Locale.Lookup("LOC_BIRTHRATE_BONUS_FROM_HOUSING", effectValue))
	elseif lowerGrowthRateLeft > 0 and lowerHousingAvailable < lowerHousing * 25 / 100  then -- BirthRate malus from low housing left
		local maxEffectValue 	= lowerGrowthRateLeft
		local higherValue 		= lowerHousing * 25 / 100
		local lowerValue 		= lowerHousingAvailable
		local effectValue		= GCO.ToDecimals(GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue))
		effectValue				= LimitEffect(maxEffectValue, effectValue)
		_cached[cityKey].NeedsEffects[LowerClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING"] = - effectValue
		Dprint( DEBUG_CITY_SCRIPT, maxEffectValue, higherValue, lowerValue, Locale.Lookup("LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING", - effectValue))
		lowerGrowthRateLeft = lowerGrowthRateLeft - effectValue
	end	
	
	self:SetPopulationBirthRate(UpperClassID)
	self:SetPopulationBirthRate(MiddleClassID)
	self:SetPopulationBirthRate(LowerClassID)
	self:SetPopulationBirthRate(SlaveClassID)
	
	self:SetPopulationDeathRate(UpperClassID)
	self:SetPopulationDeathRate(MiddleClassID)
	self:SetPopulationDeathRate(LowerClassID)
	self:SetPopulationDeathRate(SlaveClassID)
	
	--[[
	local player = GCO.GetPlayer(self:GetOwner())
	for row in GameInfo.Populations() do
		local populationID 		= row.Index
		local population 		= self:GetPopulationClass(populationID)
		local populationNeeds 	= player:GetPopulationNeeds(populationID)
		local maxNeed = 0
		Dprint( DEBUG_CITY_SCRIPT, "- Needs for ".. Locale.Lookup(row.Name), " population of ", population)
		for resourceID, affectData in pairs(populationNeeds) do
			local stock = self:GetStock(resourceID)
			local ratio	= player:GetResourcesConsumptionRatioForPopulation(resourceID, populationID)
			Dprint( DEBUG_CITY_SCRIPT, " - Resource : ".. Locale.Lookup(GameInfo.Resources[resourceID].Name), " Consumption ratio = ", ratio, " Stock = ", stock)			
			for affectType, data in pairs(affectData) do			
				local need 			= data.NeededCalculFunction(population, ratio)
				local effectValue 	= data.EffectCalculFunction(need, stock, data.MaxEffectValue)
				Dprint( DEBUG_CITY_SCRIPT, "  - Affect : ".. tostring(affectType), " Needed = ", need, " Effect Value = ", effectValue)		
			end	
		end
	end		
	--]]
end

function DoSocialClassStratification(self)

	local totalPopultation = self:GetRealPopulation()

	Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: totalPopultation = ", totalPopultation)

	local maxUpper = self:GetMaxUpperClass()
	local minUpper = self:GetMinUpperClass()

	local maxMiddle = self:GetMaxMiddleClass()
	local minMiddle = self:GetMinMiddleClass()

	local maxLower = self:GetMaxLowerClass()
	local minLower = self:GetMinLowerClass()

	local actualUpper = self:GetUpperClass()
	local actualMiddle = self:GetMiddleClass()
	local actualLower = self:GetLowerClass()

	Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: maxUpper = ", maxUpper)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: actualUpper = ", actualUpper)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: minUpper = ", minUpper)
	Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: maxMiddle = ", maxMiddle)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: actualMiddle = ", actualMiddle)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: minMiddle = ", minMiddle)
	Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: maxLower = ", maxLower)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: actualLower = ", actualLower)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: minLower = ", minLower)
	Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")

	-- Move Upper to Middle
	if actualUpper > maxUpper then
		toMove = actualUpper - maxUpper
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Upper to Middle (from actualUpper > maxUpper) = ", toMove)
		self:ChangeUpperClass(- toMove)
		self:ChangeMiddleClass( toMove)
	end
	-- Move Middle to Upper
	if actualUpper < minUpper then
		toMove = minUpper - actualUpper
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Middle to Upper (from actualUpper < minUpper)= ", toMove)
		self:ChangeUpperClass(toMove)
		self:ChangeMiddleClass(-toMove)
	end
	-- Move Middle to Lower
	if actualMiddle > maxMiddle then
		toMove = actualMiddle - maxMiddle
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Middle to Lower (from actualMiddle > maxMiddle)= ", toMove)
		self:ChangeMiddleClass(-toMove)
		self:ChangeLowerClass(toMove)
	end
	-- Move Lower to Middle
	if actualMiddle < minMiddle then
		toMove = minMiddle - actualMiddle
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Lower to Middle (from actualMiddle < minMiddle)= ", toMove)
		self:ChangeMiddleClass(toMove)
		self:ChangeLowerClass(-toMove)
	end
	-- Move Lower to Middle
	if actualLower > maxLower then
		toMove = actualLower - maxLower
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Lower to Middle (from actualLower > maxLower)= ", toMove)
		self:ChangeMiddleClass(toMove)
		self:ChangeLowerClass(-toMove)
	end
	-- Move Middle to Lower
	if actualLower < minLower then
		toMove = minLower - actualLower
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Middle to Lower (from actualLower < minLower)= ", toMove)
		self:ChangeMiddleClass(-toMove)
		self:ChangeLowerClass(toMove)
	end
end

function DoTurnFirstPass(self)
	Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
	Dprint( DEBUG_CITY_SCRIPT, "First Pass on ".. Locale.Lookup(self:GetName()))
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]

	-- set food rationing
	self:SetCityRationing()

	-- get linked units and supply demand
	self:UpdateLinkedUnits()

	-- get Resources (allow excedents)
	self:DoCollectResources()
	self:DoRecruitPersonnel()

	-- feed population
	self:DoNeeds()
	self:DoFood()

	-- sell to foreign cities (do turn for traders ?), reinforce units, use in industry... (orders set in UI ?)
	self:DoIndustries()
	self:DoReinforceUnits()
end

function DoTurnSecondPass(self)
	Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
	Dprint( DEBUG_CITY_SCRIPT, "Second Pass on ".. Locale.Lookup(self:GetName()))

	-- get linked cities and supply demand
	self:UpdateTransferCities()
end

function DoTurnThirdPass(self)
	Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
	Dprint( DEBUG_CITY_SCRIPT, "Third Pass on ".. Locale.Lookup(self:GetName()))

	-- diffuse to other cities, now that all of them have made their request after servicing industries and units
	self:TransferToCities()

	-- now export what's still available
	self:UpdateExportCities()
	self:ExportToForeignCities()
end

function DoTurnFourthPass(self)
	Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
	Dprint( DEBUG_CITY_SCRIPT, "Fourth Pass on ".. Locale.Lookup(self:GetName()))

	-- Update City Size / social classes
	self:DoGrowth()
	self:SetRealPopulation()
	self:DoSocialClassStratification()
	self:SetWealth()
	self:ChangeSize()

	-- last...
	self:DoExcedents()

	Dprint( DEBUG_CITY_SCRIPT, "Fourth Pass done for ".. Locale.Lookup(self:GetName()))
	LuaEvents.CityCompositionUpdated(self:GetOwner(), self:GetID())
end

function DoCitiesTurn( playerID )
	local player = Players[playerID]
	local playerCities = player:GetCities()
	if playerCities then
		for pass = 1, 4 do
			Dprint( DEBUG_CITY_SCRIPT, "---------------------------------------------------------------------------")
			Dprint( DEBUG_CITY_SCRIPT, "Cities Turn, pass #" .. tostring(pass))
			for i, city in playerCities:Members() do
				if 		pass == 1 then city:DoTurnFirstPass()
				elseif	pass == 2 then city:DoTurnSecondPass()
				elseif	pass == 3 then city:DoTurnThirdPass()
				elseif	pass == 4 then city:DoTurnFourthPass()
				end
			end
		end
	end
end
LuaEvents.DoCitiesTurn.Add( DoCitiesTurn )


-----------------------------------------------------------------------------------------
-- Functions from UI Context
-----------------------------------------------------------------------------------------
function GetCityYield(self, yieldType)
	if yieldType > YieldTypes.INTERNAL_MAX then
		local yield = 0
		for buildingID, Yields in pairs(BuildingYields) do
			if self:GetBuildings():HasBuilding(buildingID) and Yields[yieldType] then
				yield = yield + Yields[yieldType]
			end
		end
		return yield
	else
		return GCO.GetCityYield( self, yieldType )
	end
end

-----------------------------------------------------------------------------------------
-- General Functions
-----------------------------------------------------------------------------------------
function CleanCityData()

	local DEBUG_CITY_SCRIPT = true

	-- remove old data from the table
	Dprint( DEBUG_CITY_SCRIPT, "-----------------------------------------------------------------------------------------")
	Dprint( DEBUG_CITY_SCRIPT, "Cleaning CityData...")
	for cityKey, data1 in pairs(ExposedMembers.CityData) do
		local toClean = {"Stock","ResourceCost","ResourceUse","Population"}
		for i, dataToClean in ipairs(toClean) do
			turnTable = {}
			for turnkey, data2 in pairs(data1[dataToClean]) do
				local turn = tonumber(turnkey)
				if turn <= (Game.GetCurrentGameTurn() - 10) then
				
					Dprint( DEBUG_CITY_SCRIPT, "Removing entry : ", cityKey, dataToClean, " turn = ", turn)
					table.insert(turnTable, turn)
				end
			end
			for j, turn in ipairs(turnTable) do
				local turnkey = tostring(turn)
				ExposedMembers.CityData[cityKey][dataToClean][turnkey] = nil
			end
		end
	end
end
Events.TurnBegin.Add(CleanCityData)

-----------------------------------------------------------------------------------------
-- Shared Functions
-----------------------------------------------------------------------------------------
function GetCity(playerID, cityID) -- return a city with CityScript functions for another context
	local city = CityManager.GetCity(playerID, cityID)
	AttachCityFunctions(city)
	return city
end

function GetSupplyRouteString(iType)
	for key, routeType in pairs(SupplyRouteType) do
		if routeType == iType then
			return key
		end
	end
end


-----------------------------------------------------------------------------------------
-- Initialize City Functions
-----------------------------------------------------------------------------------------
function InitializeCityFunctions(playerID, cityID) -- add to Events.CityAddedToMap in initialize()
	-- Note that those functions are limited to this file context
	local city = CityManager.GetCity(playerID, cityID)
	if city then
		AttachCityFunctions(city)
		Events.CityAddedToMap.Remove(InitializeCityFunctions)
	end
end

function AttachCityFunctions(city)
	local c = getmetatable(city).__index
	c.ChangeSize						= ChangeSize
	c.GetSize							= GetSize
	c.GetRealPopulation					= GetRealPopulation
	c.SetRealPopulation					= SetRealPopulation
	c.GetRealPopulationVariation		= GetRealPopulationVariation
	c.GetKey							= GetKey
	c.UpdateDataOnNewTurn				= UpdateDataOnNewTurn
	c.GetWealth							= GetWealth
	c.SetWealth							= SetWealth
	c.UpdateCosts						= UpdateCosts
	-- resources
	c.GetMaxStock						= GetMaxStock
	c.GetStock 							= GetStock
	c.GetPreviousStock					= GetPreviousStock
	c.ChangeStock 						= ChangeStock
	c.GetStockVariation					= GetStockVariation
	c.GetMinimumResourceCost			= GetMinimumResourceCost
	c.GetMaximumResourceCost			= GetMaximumResourceCost
	c.GetResourceCost					= GetResourceCost
	c.SetResourceCost					= SetResourceCost
	c.ChangeResourceCost				= ChangeResourceCost
	c.GetPreviousResourceCost			= GetPreviousResourceCost
	c.GetResourceCostVariation			= GetResourceCostVariation
	c.GetMaxPercentLeftToRequest		= GetMaxPercentLeftToRequest
	c.GetMaxPercentLeftToImport			= GetMaxPercentLeftToImport
	c.GetMinPercentLeftToExport			= GetMinPercentLeftToExport
	c.GetAvailableStockForUnits			= GetAvailableStockForUnits
	c.GetAvailableStockForCities		= GetAvailableStockForCities
	c.GetAvailableStockForExport		= GetAvailableStockForExport
	c.GetAvailableStockForIndustries 	= GetAvailableStockForIndustries
	c.GetMinimalStockForExport			= GetMinimalStockForExport
	c.GetMinimalStockForUnits			= GetMinimalStockForUnits
	c.GetMinimalStockForCities			= GetMinimalStockForCities
	c.GetMinimalStockForIndustries		= GetMinimalStockForIndustries
	c.GetResourcesStockTable			= GetResourcesStockTable
	c.GetResourcesSupplyTable			= GetResourcesSupplyTable
	c.GetResourcesDemandTable			= GetResourcesDemandTable
	c.GetExportCitiesTable				= GetExportCitiesTable
	c.GetTransferCitiesTable			= GetTransferCitiesTable
	c.GetSupplyLinesTable				= GetSupplyLinesTable
	--
	c.GetMaxPersonnel					= GetMaxPersonnel
	c.GetPersonnel						= GetPersonnel
	c.GetPreviousPersonnel				= GetPreviousPersonnel
	c.ChangePersonnel					= ChangePersonnel
	--
	c.UpdateLinkedUnits					= UpdateLinkedUnits
	c.GetLinkedUnits					= GetLinkedUnits
	c.UpdateTransferCities				= UpdateTransferCities
	c.UpdateExportCities				= UpdateExportCities
	c.UpdateCitiesConnection			= UpdateCitiesConnection
	c.DoReinforceUnits					= DoReinforceUnits
	c.GetTransferCities					= GetTransferCities
	c.GetExportCities					= GetExportCities
	c.TransferToCities					= TransferToCities
	c.ExportToForeignCities				= ExportToForeignCities
	c.GetNumResourceNeeded				= GetNumResourceNeeded
	c.GetRouteEfficiencyTo				= GetRouteEfficiencyTo
	c.GetMaxRouteLength					= GetMaxRouteLength
	c.SetMaxRouteLength					= SetMaxRouteLength
	c.GetTransportCostTo				= GetTransportCostTo
	c.GetRequirements					= GetRequirements
	c.GetDemand							= GetDemand
	c.GetSupplyAtTurn					= GetSupplyAtTurn
	c.GetDemandAtTurn					= GetDemandAtTurn
	c.GetUseTypeAtTurn					= GetUseTypeAtTurn
	c.GetAverageUseTypeOnTurns			= GetAverageUseTypeOnTurns
	--
	c.DoGrowth							= DoGrowth
	c.GetBirthRate						= GetBirthRate
	c.GetDeathRate						= GetDeathRate
	c.DoExcedents						= DoExcedents
	c.DoFood							= DoFood
	c.DoIndustries						= DoIndustries
	c.DoNeeds							= DoNeeds
	c.DoTurnFirstPass					= DoTurnFirstPass
	c.DoTurnSecondPass					= DoTurnSecondPass
	c.DoTurnThirdPass					= DoTurnThirdPass
	c.DoTurnFourthPass					= DoTurnFourthPass
	c.GetFoodConsumption 				= GetFoodConsumption
	c.GetFoodRationing					= GetFoodRationing
	c.DoCollectResources				= DoCollectResources
	c.SetCityRationing					= SetCityRationing
	--
	c.DoSocialClassStratification		= DoSocialClassStratification
	c.ChangeUpperClass					= ChangeUpperClass
	c.ChangeMiddleClass					= ChangeMiddleClass
	c.ChangeLowerClass					= ChangeLowerClass
	c.ChangeSlaveClass					= ChangeSlaveClass
	c.GetUpperClass						= GetUpperClass
	c.GetMiddleClass					= GetMiddleClass
	c.GetLowerClass						= GetLowerClass
	c.GetSlaveClass						= GetSlaveClass
	c.GetPreviousUpperClass				= GetPreviousUpperClass
	c.GetPreviousMiddleClass			= GetPreviousMiddleClass
	c.GetPreviousLowerClass				= GetPreviousLowerClass
	c.GetPreviousSlaveClass				= GetPreviousSlaveClass
	c.GetMaxUpperClass					= GetMaxUpperClass
	c.GetMinUpperClass					= GetMinUpperClass
	c.GetMaxMiddleClass					= GetMaxMiddleClass
	c.GetMinMiddleClass					= GetMinMiddleClass
	c.GetMaxLowerClass					= GetMaxLowerClass
	c.GetMinLowerClass					= GetMinLowerClass
	c.GetPopulationClass				= GetPopulationClass
	c.ChangePopulationClass				= ChangePopulationClass
	c.GetPopulationDeathRate			= GetPopulationDeathRate
	c.SetPopulationDeathRate			= SetPopulationDeathRate
	c.GetBasePopulationDeathRate		= GetBasePopulationDeathRate
	c.GetPopulationBirthRate			= GetPopulationBirthRate
	c.SetPopulationBirthRate			= SetPopulationBirthRate
	c.GetBasePopulationBirthRate		= GetBasePopulationBirthRate
	--
	c.DoRecruitPersonnel				= DoRecruitPersonnel
	-- text
	c.GetResourcesStockString			= GetResourcesStockString
	c.GetFoodStockString 				= GetFoodStockString
	c.GetFoodConsumptionString			= GetFoodConsumptionString
	c.GetResourceUseToolTipStringForTurn= GetResourceUseToolTipStringForTurn
	
	c.GetCityYield						= GetCityYield

end


----------------------------------------------
-- Share functions for other contexts
----------------------------------------------
function ShareFunctions()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.GetCity 				= GetCity
	ExposedMembers.GCO.AttachCityFunctions 	= AttachCityFunctions
	ExposedMembers.GCO.GetPopulationPerSize = GetPopulationPerSize
	--
	ExposedMembers.GCO.GetCityFromKey 		= GetCityFromKey
	--
	ExposedMembers.GCO.GetSupplyRouteString = GetSupplyRouteString
	--
	ExposedMembers.CityScript_Initialized 	= true
end


----------------------------------------------
-- Initialize after loading
----------------------------------------------
Initialize()

function debugList()
	for cityKey, data in pairs(CitiesForTransfer) do
		for routeCityKey, routeData in pairs(data) do

			local city				= GCO.GetCityFromKey(routeCityKey)
			local ownCity			= GCO.GetCityFromKey(cityKey)
			
			if city:GetOwner() ~= ownCity:GetOwner() then
				Dprint( DEBUG_CITY_SCRIPT, "WARNING : foreign city found in internal transfer list : " ..city:GetName())
				Dprint( DEBUG_CITY_SCRIPT, "WARNING : key = " ..routeCityKey)
				CitiesForTransfer[cityKey][routeCityKey] = nil
			end
		end
	end
end
--Events.GameCoreEventPublishComplete.Add( debugList )

