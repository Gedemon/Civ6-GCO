--=====================================================================================--
--	FILE:	 CityScript.lua
--  Gedemon (2017)
--=====================================================================================--

print("Loading CityScript.lua...")

-----------------------------------------------------------------------------------------
-- Includes
-----------------------------------------------------------------------------------------
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )


-----------------------------------------------------------------------------------------
-- Debug
-----------------------------------------------------------------------------------------

DEBUG_CITY_SCRIPT = "CityScript"

function ToggleDebug()
	DEBUG_CITY_SCRIPT = not DEBUG_CITY_SCRIPT
end

local previousDebugLevel = DEBUG_CITY_SCRIPT
function SetDebugLevel(sLevel)
	previousDebugLevel	= DEBUG_CITY_SCRIPT
	DEBUG_CITY_SCRIPT 	= sLevel
end
function RestorePreviousDebugLevel()
	DEBUG_CITY_SCRIPT = previousDebugLevel
end
--LuaEvents.SetCitiesDebugLevel.Add(SetDebugLevel)
--LuaEvents.RestoreCitiesDebugLevel.Add(RestorePreviousDebugLevel)

-----------------------------------------------------------------------------------------
-- ENUMS
-----------------------------------------------------------------------------------------

local NO_IMPROVEMENT 	= -1
local NO_FEATURE 		= -1
local NO_PLAYER			= -1

local YieldHealthID			= GameInfo.CustomYields["YIELD_HEALTH"].Index
local YieldUpperHousingID	= GameInfo.CustomYields["YIELD_UPPER_HOUSING"].Index
local YieldMiddleHousingID	= GameInfo.CustomYields["YIELD_MIDDLE_HOUSING"].Index
local YieldLowerHousingID	= GameInfo.CustomYields["YIELD_LOWER_HOUSING"].Index
local YieldAdministrationID	= GameInfo.CustomYields["YIELD_ADMINISTRATION"].Index

local NeedsEffectType	= {	-- ENUM for effect types from Citizen Needs
	DeathRate				= 1,
	BirthRate				= 2,
	SocialStratification	= 3,
	SocialStratificationReq	= 4,
	DeathRateReq			= 5,
	BirthRateReq			= 6,
	Consumption				= 7, -- NeedsEffects[PopulationID][NeedsEffectType.Consumption][Locale.Lookup("LOC_RESOURCE_CONSUMED_BY_NEED", resName, resIcon)] 		= consumedValue
	}

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local _cached					= {}	-- cached table to reduce calculations
	
local LinkedUnits 				= {}	-- temporary table to list all units linked to a city for supply
local UnitsSupplyDemand			= {}	-- temporary table to list all resources required by units
local CitiesForTransfer 		= {}	-- temporary table to list all cities connected via (internal) trade routes to a city
local CitiesForTrade			= {}	-- temporary table to list all cities connected via (external) trade routes to a city
local CitiesTransferDemand		= {}	-- temporary table to list all resources required by own cities
local CitiesTradeDemand			= {}	-- temporary table to list all resources required by other civilizations cities
local CitiesOutOfReach			= {}	-- temporary table to list all cities out of reach of another city (and turns left before next attempt)
local CitiesToIgnoreThisTurn	= {}	-- temporary table to list all cities to ignore during the current "DoTurn"

local BaseCityYields			= {
		[YieldHealthID]			= 1,
		[YieldUpperHousingID]	= 0, --2, --1
		[YieldMiddleHousingID]	= 0, --2, --1
		[YieldLowerHousingID]	= 0, --4, --2
	}

local SupplyRouteLengthFactor 	= {		-- When calculating supply line efficiency relatively to length
		[SupplyRouteType.Trader]	= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_TRADER_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Road]		= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_ROAD_LENGTH_FACTOR"].Value),
		[SupplyRouteType.River]		= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_RIVER_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Coastal]	= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_SEA_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Ocean]		= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_SEA_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Airport]	= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_AIRPORT_LENGTH_FACTOR"].Value)
}

-- Reference types for Resource usage
local NO_REFERENCE			= -1
local NO_REFERENCE_KEY		= tostring(NO_REFERENCE)
local RefPopulationUpper	= "POPULATION_UPPER"
local RefPopulationMiddle	= "POPULATION_MIDDLE"
local RefPopulationLower	= "POPULATION_LOWER"
local RefPopulationSlave	= "POPULATION_SLAVE"
local RefPersonnel			= "POPULATION_PERSONNEL"
local RefPrisoners			= "POPULATION_PRISONERS"

-- Error checking
for row in GameInfo.BuildingResourcesConverted() do
	if row.MultiResRequired and  row.MultiResCreated then
		print("ERROR: BuildingResourcesConverted contains a row with both MultiResRequired and MultiResCreated set to true:", row.BuildingType, row.ResourceCreated, row.ResourceType, row.MultiResRequired, row.MultiResCreated)
	end
end

local BuildingStock			= {}		-- cached table with stock value of a building for a specific resource (or resource class)
local ResourceStockage		= {}		-- cached table with all the buildings that can stock a specific resource (or resource class)
local FixedBuildingStock	= {}		-- cached table with all the buildings that stock a specific resource (or resource class) at a fixed value (not related to city size)
for row in GameInfo.BuildingStock() do
	-- we can mix resourceID or classType as key in those table because one is ID the other is TypeName and they can't overlap.
	local buildingID	= GameInfo.Buildings[row.BuildingType].Index
	local resourceID	= row.ResourceType and GameInfo.Resources[row.ResourceType].Index
	local classType		= row.ResourceClassType
	if classType == nil and row.ResourceType == nil then print("ERROR: BuildingStock contains a row with both ResourceClassType and ResourceType not defined:", row.BuildingType) end
	if classType and row.ResourceTyp then print("ERROR: BuildingStock contains a row with both ResourceClassType and ResourceType defined:", row.BuildingType, row.ResourceType, row.ResourceClassType ) end
	--
	if not BuildingStock[buildingID] then BuildingStock[buildingID] = {} end
	BuildingStock[buildingID][(resourceID or classType)] = row.Stock
	--
	if not FixedBuildingStock[buildingID] then FixedBuildingStock[buildingID] = {} end
	FixedBuildingStock[buildingID][(resourceID or classType)] = row.FixedValue
	--
	if not ResourceStockage[(resourceID or classType)] then ResourceStockage[(resourceID or classType)] = {} end
	table.insert (ResourceStockage[(resourceID or classType)], buildingID)
end

local EquipmentStockage		= {}		-- cached table with all the buildings that can stock equipment
local BuildingEmployment	= {}		-- cached table with all the buildings that provide employment
for row in GameInfo.Buildings() do
	if row.EquipmentStock and  row.EquipmentStock > 0 then
		EquipmentStockage[row.Index] = row.EquipmentStock
	end
	if row.EmploymentSize and  row.EmploymentSize > 0 then
		BuildingEmployment[row.Index] = row.EmploymentSize
	end
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
for row in GameInfo.Building_CustomYieldChanges() do
	local YieldID = GameInfo.CustomYields[row.YieldType].Index
	local buildingID = GameInfo.Buildings[row.BuildingType].Index
	if not BuildingYields[buildingID] then BuildingYields[buildingID] = {} end
	BuildingYields[buildingID][YieldID] = row.YieldChange
end

local UnitPrereqBuildingOR			= {} -- cached table for buiding prerequired (Any) for an unit
for row in GameInfo.Unit_RealBuildingPrereqsOR() do
	local unitID 		= GameInfo.Units[row.Unit].Index
	local buildingID 	= GameInfo.Buildings[row.PrereqBuilding].Index
	if not UnitPrereqBuildingOR[unitID] then UnitPrereqBuildingOR[unitID] = {} end
	UnitPrereqBuildingOR[unitID][buildingID] = true
end

local UnitPrereqBuildingAND			= {} -- cached table for buiding prerequired (All) for an unit
for row in GameInfo.Unit_RealBuildingPrereqsAND() do
	local unitID 		= GameInfo.Units[row.Unit].Index
	local buildingID 	= GameInfo.Buildings[row.PrereqBuilding].Index
	if not UnitPrereqBuildingAND[unitID] then UnitPrereqBuildingAND[unitID] = {} end
	UnitPrereqBuildingAND[unitID][buildingID] = true
end

local BuildingPrereqBuildingOR		= {} -- cached table for buiding prerequired (Any) for a building
for row in GameInfo.BuildingRealPrereqsOR() do
	local buildingID	= GameInfo.Buildings[row.Building].Index
	local prereqID	 	= GameInfo.Buildings[row.PrereqBuilding].Index
	if not BuildingPrereqBuildingOR[buildingID] then BuildingPrereqBuildingOR[buildingID] = {} end
	BuildingPrereqBuildingOR[buildingID][prereqID] = true
end

local BuildingPrereqBuildingAND		= {} -- cached table for buiding prerequired (All) for a building
for row in GameInfo.BuildingRealPrereqsAND() do
	local buildingID	= GameInfo.Buildings[row.Building].Index
	local prereqID	 	= GameInfo.Buildings[row.PrereqBuilding].Index
	if not BuildingPrereqBuildingAND[buildingID] then BuildingPrereqBuildingAND[buildingID] = {} end
	BuildingPrereqBuildingAND[buildingID][prereqID] = true
end

-- Helper to get the resource list required by a building for its construction (but not for repairs, if/when implemented)
local buildingConstructionResources = {}
for row in GameInfo.BuildingConstructionResources() do
	local buildingType 	= row.BuildingType
	local resourceType 	= row.ResourceType
	local buildingID 	= GameInfo.Buildings[buildingType].Index
	local resourceID	= GameInfo.Resources[resourceType].Index
	if not buildingConstructionResources[buildingID] then buildingConstructionResources[buildingID] = {} end
	table.insert(buildingConstructionResources[buildingID], {ResourceID = resourceID, Quantity = row.Quantity})
end

-- Helper to get 
local BuildingReplacements	= {} -- cached table to get the upgrades for Buildings (which buildings a Building is directly replacing)
local BuildingUpgrade		= {} -- cached table to get which building is directly replacing a Building 
for row in GameInfo.BuildingUpgrades() do
	local buildingType 	= row.BuildingType
	local upgradeType 	= row.UpgradeType
	local buildingID 	= GameInfo.Buildings[buildingType].Index
	local upgradeID		= GameInfo.Buildings[upgradeType].Index
	BuildingUpgrade[buildingID]	= upgradeID
	if not BuildingReplacements[upgradeID] then BuildingReplacements[upgradeID] = {} end
	table.insert(BuildingReplacements[upgradeID], buildingID)
end

local BuildingFullUpgrades	= {} -- All buildings that are replacing a Building, directly or indirectly
for buildingID, upgradeID in pairs(BuildingUpgrade) do
	BuildingFullUpgrades[buildingID] = {}
	while (upgradeID ~= nil) do
		table.insert(BuildingFullUpgrades[buildingID], upgradeID)
		upgradeID = BuildingUpgrade[upgradeID]
	end
end

-- List of Buildings which provide Health
local BuildingHealth = {}
for row in GameInfo.Building_CustomYieldChanges() do
	if row.YieldType == "YIELD_HEALTH" then
		local buildingType 			= row.BuildingType
		local buildingID 			= GameInfo.Buildings[buildingType].Index
		BuildingHealth[buildingID]	= row.YieldChange
	end
end

-- Helper to get the resources that can be traded at a specific trade level (filled after initialization) 
local resourceTradeLevel = { 
	[TradeLevelType.Limited] = {},	-- embargo (denounced)
	[TradeLevelType.Neutral] = {},
	[TradeLevelType.Friend] = {},
	[TradeLevelType.Allied] = {}	-- internal trade route are at this level
}

local centralSquareIDs	= {
	["ERA_ANCIENT"] 		= GameInfo.Buildings["BUILDING_CENTRAL_SQUARE_ANCIENT"].Index ,
	["ERA_CLASSICAL"] 		= GameInfo.Buildings["BUILDING_CENTRAL_SQUARE_CLASSICAL"].Index ,
	["ERA_MEDIEVAL"] 		= GameInfo.Buildings["BUILDING_CENTRAL_SQUARE_MEDIEVAL"].Index ,
	["ERA_RENAISSANCE"] 	= GameInfo.Buildings["BUILDING_CENTRAL_SQUARE_RENAISSANCE"].Index ,
	["ERA_INDUSTRIAL"] 		= GameInfo.Buildings["BUILDING_CENTRAL_SQUARE_INDUSTRIAL"].Index ,
	["ERA_MODERN"] 			= GameInfo.Buildings["BUILDING_CENTRAL_SQUARE_MODERN"].Index ,
	["ERA_ARMS_RACE"] 		= GameInfo.Buildings["BUILDING_CENTRAL_SQUARE_ARMS_RACE"].Index ,
	["ERA_ATOMIC"] 			= GameInfo.Buildings["BUILDING_CENTRAL_SQUARE_ATOMIC"].Index ,
	["ERA_INFORMATION"] 	= GameInfo.Buildings["BUILDING_CENTRAL_SQUARE_INFORMATION"].Index ,
	["ERA_FUTURE"] 			= GameInfo.Buildings["BUILDING_CENTRAL_SQUARE_FUTURE"].Index ,
}

local IncomeExportPercent			= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_EXPORT_PERCENT"].Value)
local IncomeImportPercent			= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_IMPORT_PERCENT"].Value)

local bUseRealYears					= (tonumber(GameInfo.GlobalParameters["CITY_USE_REAL_YEARS_FOR_GROWTH_RATE"].Value) == 1)
local GrowthRateBaseYears			= tonumber(GameInfo.GlobalParameters["CITY_GROWTH_RATE_BASE_YEARS"].Value)

local ClassMinimalGrowthRate		= tonumber(GameInfo.GlobalParameters["CITY_CLASS_MINIMAL_GROWTH_RATE"].Value)
local ClassMaximalGrowthRate		= tonumber(GameInfo.GlobalParameters["CITY_CLASS_MAXIMAL_GROWTH_RATE"].Value)

local StartingPopulationBonus		= tonumber(GameInfo.GlobalParameters["CITY_STARTING_POPULATION_BONUS"].Value)

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

local MinNeededLuxuriesPerMil 		= tonumber(GameInfo.GlobalParameters["CITY_MIN_NEEDED_LUXURIES_PER_MIL"].Value)
local MaxLuxuriesConsumedPerMil 	= tonumber(GameInfo.GlobalParameters["CITY_MAX_LUXURIES_CONSUMED_PER_MIL"].Value)

local UpperClassFoodConsumption 	= tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_UPPER_CLASS_FACTOR"].Value)
local MiddleClassFoodConsumption 	= tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_MIDDLE_CLASS_FACTOR"].Value)
local LowerClassFoodConsumption 	= tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_LOWER_CLASS_FACTOR"].Value)
local SlaveClassFoodConsumption 	= tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_SLAVE_CLASS_FACTOR"].Value)
local PersonnelFoodConsumption 		= tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PERSONNEL_FACTOR"].Value)

local MaterielProductionPerSize 	= tonumber(GameInfo.GlobalParameters["CITY_MATERIEL_PRODUCTION_PER_SIZE"].Value)
local ResourceStockPerSize 			= tonumber(GameInfo.GlobalParameters["CITY_STOCK_PER_SIZE"].Value)
local FoodStockPerSize 				= tonumber(GameInfo.GlobalParameters["CITY_FOOD_STOCK_PER_SIZE"].Value)
local FoodStockPerConsumption		= tonumber(GameInfo.GlobalParameters["CITY_FOOD_CONSUMPTION_TO_STOCK_FACTOR"].Value)
local FoodPreparationFactor			= tonumber(GameInfo.GlobalParameters["CITY_FOOD_PREPARATION_OBJECTIVE_FACTOR"].Value)
local LuxuryStockRatio 				= tonumber(GameInfo.GlobalParameters["CITY_LUXURY_STOCK_RATIO"].Value)
local PerSizeStockRatio 			= tonumber(GameInfo.GlobalParameters["CITY_PER_SIZE_STOCK_RATIO"].Value)
local PersonnelPerSize	 			= tonumber(GameInfo.GlobalParameters["CITY_PERSONNEL_PER_SIZE"].Value)
local KnowledgePerSize	 			= tonumber(GameInfo.GlobalParameters["CITY_KNOWLEDGE_PER_SIZE"].Value)
local EquipmentBaseStock 			= tonumber(GameInfo.GlobalParameters["CITY_STOCK_EQUIPMENT"].Value)
local ConstructionMinStockRatio		= tonumber(GameInfo.GlobalParameters["CITY_CONSTRUCTION_MINIMUM_STOCK_RATIO"].Value)

local SurplusWasteFastPercent		= tonumber(GameInfo.GlobalParameters["CITY_SURPLUS_WASTE_FAST_PERCENT"].Value)
local SurplusWasteSlowPercent		= tonumber(GameInfo.GlobalParameters["CITY_SURPLUS_WASTE_SLOW_PERCENT"].Value)
local SurplusWastePercent			= tonumber(GameInfo.GlobalParameters["CITY_SURPLUS_WASTE_PERCENT"].Value)

--local MaterielPerBuildingCost		= tonumber(GameInfo.GlobalParameters["CITY_MATERIEL_PER_BUIDING_COST"].Value)

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

local BaseCollectCostMultiplier	= tonumber(GameInfo.GlobalParameters["RESOURCE_BASE_COLLECT_COST_MULTIPLIER"].Value)
local ImprovementCostRatio		= tonumber(GameInfo.GlobalParameters["RESOURCE_IMPROVEMENT_COST_RATIO"].Value)
local NotWorkedCostMultiplier	= tonumber(GameInfo.GlobalParameters["RESOURCE_NOT_WORKED_COST_MULTIPLIER"].Value)

local RequiredResourceFactor	= tonumber(GameInfo.GlobalParameters["CITY_REQUIRED_RESOURCE_BASE_FACTOR"].Value)
local ProducedResourceFactor	= tonumber(GameInfo.GlobalParameters["CITY_PRODUCED_RESOURCE_BASE_FACTOR"].Value)

local MaxCostIncreasePercent 	= tonumber(GameInfo.GlobalParameters["RESOURCE_COST_MAX_INCREASE_PERCENT"].Value)
local MaxCostReductionPercent 	= tonumber(GameInfo.GlobalParameters["RESOURCE_COST_MAX_REDUCTION_PERCENT"].Value)
local MaxCostFromBaseFactor 	= tonumber(GameInfo.GlobalParameters["RESOURCE_COST_MAX_FROM_BASE_FACTOR"].Value)
local MinCostFromBaseFactor 	= tonumber(GameInfo.GlobalParameters["RESOURCE_COST_MIN_FROM_BASE_FACTOR"].Value)
local ResourceTransportMaxCost	= tonumber(GameInfo.GlobalParameters["RESOURCE_TRANSPORT_MAX_COST_RATIO"].Value)

local baseFoodStock 			= tonumber(GameInfo.GlobalParameters["CITY_BASE_FOOD_STOCK"].Value)
local populationPerSizepower	= tonumber(GameInfo.GlobalParameters["CITY_POPULATION_PER_SIZE_POWER"].Value)
local maxMigrantPercent			= tonumber(GameInfo.GlobalParameters["CITY_POPULATION_MAX_MIGRANT_PERCENT"].Value)
local minMigrantPercent			= tonumber(GameInfo.GlobalParameters["CITY_POPULATION_MIN_MIGRANT_PERCENT"].Value)

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

local healGarrisonMaxPerTurn		= tonumber(GameInfo.GlobalParameters["CITY_HEAL_GARRISON_MAX_PER_TURN"].Value)
local healGarrisonBaseMateriel		= tonumber(GameInfo.GlobalParameters["CITY_HEAL_GARRISON_BASE_MATERIEL"].Value)
local healOuterDefensesMaxPerTurn	= tonumber(GameInfo.GlobalParameters["CITY_HEAL_OUTER_DEFENSES_MAX_PER_TURN"].Value)
local healOuterDefensesBaseMateriel	= tonumber(GameInfo.GlobalParameters["CITY_HEAL_OUTER_DEFENSES_BASE_MATERIEL"].Value)

local ConscriptsBaseActiveTurns		= tonumber(GameInfo.GlobalParameters["ARMY_CONSCRIPTS_BASE_ACTIVE_TURNS"].Value)

local minAdmSupportPercent			= tonumber(GameInfo.GlobalParameters["MIN_ADMIN_SUPPORT_PERCENT"].Value)

-- Population
local UpperClassID 				= GameInfo.Resources["POPULATION_UPPER"].Index
local MiddleClassID 			= GameInfo.Resources["POPULATION_MIDDLE"].Index
local LowerClassID 				= GameInfo.Resources["POPULATION_LOWER"].Index
local SlaveClassID 				= GameInfo.Resources["POPULATION_SLAVE"].Index
local PersonnelClassID			= GameInfo.Resources["POPULATION_PERSONNEL"].Index
local PrisonersClassID			= GameInfo.Resources["POPULATION_PRISONERS"].Index

local PopulationRefFromID = {
	[UpperClassID] 				= RefPopulationUpper,
	[MiddleClassID] 			= RefPopulationMiddle,
	[LowerClassID] 				= RefPopulationLower,
	[SlaveClassID] 				= RefPopulationSlave,
	[PersonnelClassID]			= RefPersonnel,
	[PrisonersClassID]			= RefPrisoners,
}

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

-- Floating Texts LOD
local FLOATING_TEXT_NONE 	= 0
local FLOATING_TEXT_SHORT 	= 1
local FLOATING_TEXT_LONG 	= 2
local floatingTextLevel 	= FLOATING_TEXT_SHORT

-----------------------------------------------------------------------------------------
-- Initialize
-----------------------------------------------------------------------------------------
local GCO 		= {}
local pairs 	= pairs
local oldpairs 	= pairs
local Dprint, Dline, Dlog, Div
function InitializeUtilityFunctions()
	GCO 		= ExposedMembers.GCO		-- contains functions from other contexts
	LuaEvents	= GCO.LuaEvents
	Calendar 	= ExposedMembers.Calendar	-- required for city growth (when based on real calendar)
	Dprint 		= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	Div			= GCO.Divide
	pairs 		= GCO.OrderedPairs
	print("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
function InitializeCheck()
	if not ExposedMembers.CityData then GCO.Error("ExposedMembers.CityData is nil after Initialization") end
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )
GameEvents.InitializeGCO.Add( InitializeCheck )

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.CityData 		= GCO.LoadTableFromSlot("CityData") or {}
	CitiesOutOfReach				= GCO.LoadTableFromSlot("CitiesOutOfReach") or {}
	CitiesTransferDemand			= GCO.LoadTableFromSlot("CitiesTransferDemand") or {}
	CitiesTradeDemand				= GCO.LoadTableFromSlot("CitiesTradeDemand") or {}
	CitiesForTransfer				= GCO.LoadTableFromSlot("CitiesForTransfer") or {}
	CitiesForTrade					= GCO.LoadTableFromSlot("CitiesForTrade") or {}
	
	-- Filling the helper to get the resources that can be traded at a specific trade level
	-- (require initializing resources functions in ModUtils first)
	for row in GameInfo.Resources() do
		local resourceID = row.Index
		if (GCO.IsResourceFood(resourceID) and row.ResourceClassType ~= "RESOURCECLASS_LUXURY" ) then
			resourceTradeLevel[TradeLevelType.Limited][resourceID] 	= true
			resourceTradeLevel[TradeLevelType.Neutral][resourceID] 	= true
			resourceTradeLevel[TradeLevelType.Friend][resourceID] 	= true
			resourceTradeLevel[TradeLevelType.Allied][resourceID] 	= true
		end
		if (row.ResourceClassType ~= "RESOURCECLASS_STRATEGIC" and row.ResourceClassType ~= "RESOURCECLASS_EQUIPMENT" and (not GCO.IsResourceEquipmentMaker(resourceID))) then
			resourceTradeLevel[TradeLevelType.Neutral][resourceID] 	= true
			resourceTradeLevel[TradeLevelType.Friend][resourceID] 	= true
			resourceTradeLevel[TradeLevelType.Allied][resourceID] 	= true	
		end
		if (row.ResourceClassType == "RESOURCECLASS_STRATEGIC" or GCO.IsResourceEquipmentMaker(resourceID)) then
			resourceTradeLevel[TradeLevelType.Friend][resourceID] 	= true
			resourceTradeLevel[TradeLevelType.Allied][resourceID] 	= true	
		end
		if (row.ResourceClassType == "RESOURCECLASS_EQUIPMENT") then
			resourceTradeLevel[TradeLevelType.Allied][resourceID] 	= true	
		end
	end
	
	LuaEvents.SetCitiesDebugLevel.Add(SetDebugLevel)
	LuaEvents.RestoreCitiesDebugLevel.Add(RestorePreviousDebugLevel)
	GameEvents.CapturedCityInitialized.Add( UpdateCapturedCity ) -- called in Events.CityInitialized (after Events.CityAddedToMap and InitializeCity...)
	LuaEvents.DoCitiesTurn.Add( DoCitiesTurn )
end

function Initialize() -- called immediatly after loading this file
	Events.CityAddedToMap.Add( InitializeCityFunctions ) -- first as InitializeCity() may require those functions
	Events.CityAddedToMap.Add( InitializeCity )
	ShareFunctions()
end

function SaveTables()
	Dprint("--------------------------- Saving CityData ---------------------------")

	GCO.CityDataSavingCheck = nil

	GCO.StartTimer("Saving And Checking CityData")
	GCO.SaveTableToSlot(ExposedMembers.CityData, "CityData")
	GCO.SaveTableToSlot(CitiesOutOfReach, "CitiesOutOfReach")
	GCO.SaveTableToSlot(CitiesTransferDemand, "CitiesTransferDemand")
	GCO.SaveTableToSlot(CitiesTradeDemand, "CitiesTradeDemand")
	GCO.SaveTableToSlot(CitiesForTransfer, "CitiesForTransfer")
	GCO.SaveTableToSlot(CitiesForTrade, "CitiesForTrade")
end
GameEvents.SaveTables.Add(SaveTables)

function CheckSave()
	Dprint( DEBUG_CITY_SCRIPT, "Checking Saved Table...")
	if GCO.AreSameTables(ExposedMembers.CityData, GCO.LoadTableFromSlot("CityData")) then
		Dprint("- Tables are identical")
	else
		GCO.ErrorWithLog("reloading saved table show differences with actual table !")
		CompareData(ExposedMembers.CityData, GCO.LoadTableFromSlot("CityData"))
	end
	GCO.ShowTimer("Saving And Checking CityData")
	GCO.CityDataSavingCheck = true
end
GameEvents.SaveTables.Add(CheckSave)

function ControlSave()
	if not GCO.CityDataSavingCheck then
		GCO.ErrorWithLog("CityData saving check failed !")
		ShowCityData()
	end
end
GameEvents.SaveTables.Add(ControlSave)

function CompareData(data1, data2, tab)
	if not tab then tab = "" end
	print(tab,"comparing...", data1, data2)
	for key, data in pairs(data1) do
		for k, v in pairs (data) do
		print(k, v)
		print( "A")
			if not data2[key] then
				print(tab,"- reloaded table is nil for key = ", key)
			end
		print( "B")
			if data2[key] and not data2[key][k] then
				print(tab,"- no value for key = ", key, " entry =", k)
			end
		print( "C")
			if data2[key] and type(v) ~= "table" and v ~= data2[key][k] then
				print(tab,"- different value for key = ", key, " entry =", k, " Data1 value = ", v, type(v), " Data2 value = ", data2[key][k], type(data2[key][k]) )
			end
		print( "D")
			if type(v) == "table" then
				CompareData(v, data2[key][k], tab.."\t")
			end
		end
	end
	print( "no more data to compare...")
end

-----------------------------------------------------------------------------------------
-- Initialize Cities
-----------------------------------------------------------------------------------------
function RegisterNewCity(playerID, city)

	local cityKey 			= city:GetKey()
	local personnel 		= city:GetMaxPersonnel()
	local initialSize		= city:GetSize()
	local totalPopulation 	= GCO.Round(GetPopulationPerSize(initialSize) + StartingPopulationBonus)
	local upperClass		= GCO.Round(totalPopulation * GCO.GetPlayerUpperClassPercent(playerID) / 100) -- can't use city:GetMaxUpperClass() before filling ExposedMembers.CityData[cityKey]
	local middleClass		= GCO.Round(totalPopulation * GCO.GetPlayerMiddleClassPercent(playerID) / 100)
	local lowerClass		= totalPopulation - (upperClass + middleClass)
	local slaveClass		= 0
	local startingFood		= 0 -- (re)initialized at the end of this function --GCO.Round(baseFoodStock / 2)
	local startingMateriel	= GCO.Round(ResourceStockPerSize * city:GetSize() / 2)
	local baseFoodCost 		= GCO.GetBaseResourceCost(foodResourceID)
	local turnKey 			= GCO.GetTurnKey()
	local plot				= GCO.GetPlot(city:GetX(), city:GetY())
	local ownerCultureID	= GCO.GetCultureIDFromPlayerID(playerID)
	
	-- add City owner culture on plot
	plot:ChangeCulture(ownerCultureID, totalPopulation)
	
	-- add/remove plot's population (plot:GetPopulation() returns its city population, not the plot data)
	upperClass		= upperClass	+ plot:GetUpperClass()
	middleClass		= middleClass	+ plot:GetMiddleClass()
	lowerClass		= lowerClass	+ plot:GetLowerClass()
	slaveClass		= slaveClass	+ plot:GetSlaveClass()
	
	local toRemove		= {UpperClassID, MiddleClassID, LowerClassID, SlaveClassID}
	for i, populationID in ipairs(toRemove) do
		plot:ChangePopulationClass(populationID, - plot:GetPopulationClass(populationID))
	end

	ExposedMembers.CityData[cityKey] = {
		TurnCreated				= Game.GetCurrentGameTurn(),
		cityID 					= city:GetID(),
		playerID 				= playerID,
		WoundedPersonnel 		= 0,
		Prisoners				= GCO.CreateEverAliveTableWithDefaultValue(0),
		Stock					= { [turnKey] = {[foodResourceKey] = startingFood, [personnelResourceKey] = personnel, [materielResourceKey] = startingMateriel} },
		ResourceCost			= { [turnKey] = {[foodResourceKey] = baseFoodCost, } },
		ResourceUse				= { [turnKey] = { } }, -- [ResourceKey] = { ResourceUseType.Collected = { [plotKey] = 0, }, ResourceUseType.Consummed = { [buildingKey] = 0, [PopulationType] = 0, }, ...)
		Population				= { [turnKey] = { UpperClass = upperClass, MiddleClass	= middleClass, LowerClass = lowerClass,	Slaves = slaveClass} },
		Account					= { [turnKey] = {} }, -- [TransactionType] = { [refKey] = value }
		FoodRatio				= 1,
		FoodRatioTurn			= Game.GetCurrentGameTurn(),
		ConstructionEfficiency	= 1,
		BuildQueue				= {},
	}
	
	local currentSize 	= math.floor(GCO.GetSizeAtPopulation(city:GetRealPopulation()))
	local sizeDiff		= currentSize - initialSize
	if sizeDiff ~= 0 then
		city:ChangePopulation(sizeDiff)
		city:UpdateSize()
		--ExposedMembers.CityData[cityKey].Stock[turnKey][foodResourceKey] = 
	end
	city:ChangeStock(foodResourceID, city:GetMaxStock(foodResourceID), ResourceUseType.Product, cityKey)--GCO.Round(city:GetMaxStock(foodResourceID)/2))
	
	--plot:MatchCultureToPopulation()
	
	LuaEvents.NewCityCreated(playerID, city)
	GameEvents.NewCityCreated.Call(playerID, city, true)
end

function InitializeCity(playerID, cityID) -- added to Events.CityAddedToMap in initialize()

	--local DEBUG_CITY_SCRIPT = "CityScript"

	local city = CityManager.GetCity(playerID, cityID)
	if city then
		local cityKey = city:GetKey()
		if ExposedMembers.CityData[cityKey] then
			-- city already registered, don't add it again...
			Dprint( DEBUG_CITY_SCRIPT, "  - ".. city:GetName() .." is already registered")
			return
		end

		Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
		Dprint( DEBUG_CITY_SCRIPT, "Initializing new city (".. city:GetName() ..") for player #".. tostring(playerID).. " id#" .. tostring(city:GetID()))
		RegisterNewCity(playerID, city)

		local pCityBuildQueue = city:GetBuildQueue();
		
		-- Set Central Square building if not exists
		local bHasCentralSquare = false
		for eraType, centralSquareID in pairs(centralSquareIDs) do
			if city:GetBuildings():HasBuilding(centralSquareID) then
				bHasCentralSquare = true
			end
		end
		if not bHasCentralSquare then
			local centralSquareID = centralSquareIDs[city:GetEraType()] or GCO.Error("No central Square Building for Era : ", city:GetEraType())
			pCityBuildQueue:CreateIncompleteBuilding(centralSquareID, 100)
		end

		city:SetUnlockers()

	else
		Dprint( DEBUG_CITY_SCRIPT, "- WARNING : tried to initialize nil city for player #".. tostring(playerID))
	end

end

function UpdateCapturedCity(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)

	--local DEBUG_CITY_SCRIPT = "CityScript"

	--LuaEvents.StopAuToPlay()

	local originalCityKey 	= GetCityKeyFromIDs(originalCityID, originalOwnerID)
	local newCityKey 		= GetCityKeyFromIDs(newCityID, newOwnerID)
	if ExposedMembers.CityData[originalCityKey] then
		local originalData 	= ExposedMembers.CityData[originalCityKey]
		local newData 		= ExposedMembers.CityData[newCityKey]

		if newData then
			local city = CityManager.GetCity(newOwnerID, newCityID)
			Dprint( DEBUG_CITY_SCRIPT, "Updating captured city (".. city:GetName() ..") for player #".. tostring(newOwnerID).. " id#" .. tostring(city:GetID()))
			Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)

			newData.TurnCreated 		= originalData.TurnCreated
			newData.WoundedPersonnel 	= 0

			local liberatedPrisoners	= 0

			for civKey, value in pairs(originalData.Prisoners) do
				if tonumber(civKey) == newOwnerID then
					liberatedPrisoners = value
				else
					newData.Prisoners[civKey] = value
				end
			end
			newData.Prisoners[tostring(originalOwnerID)] = originalData.WoundedPersonnel

			for turnKey, data in pairs(originalData.Stock) do
				newData.Stock[turnKey] = {}
				for resourceKey, value in pairs(data) do
					Dprint( DEBUG_CITY_SCRIPT, Indentation15("Stock"), turnKey, resourceKey, value)
					if turnKey == GCO.GetTurnKey() and resourceKey == personnelResourceKey then -- Old personnel is now prisoners, liberated prisoners are now personnel
						newData.Prisoners[tostring(originalOwnerID)] = newData.Prisoners[tostring(originalOwnerID)] + originalData.Stock[turnKey][personnelResourceKey]
						newData.Stock[turnKey][personnelResourceKey] = liberatedPrisoners
					else
						newData.Stock[turnKey][resourceKey] = value
					end
				end
			end
			for turnKey, data in pairs(originalData.ResourceCost) do
				newData.ResourceCost[turnKey] = {}
				for resourceKey, value in pairs(data) do
					Dprint( DEBUG_CITY_SCRIPT, Indentation15("ResourceCost"), turnKey, resourceKey, value)
					newData.ResourceCost[turnKey][resourceKey] = value
				end
			end

			for turnKey, data in pairs(originalData.ResourceUse) do
				newData.ResourceUse[turnKey] = {}
				for resourceKey, resourceUses in pairs(data) do
					newData.ResourceUse[turnKey][resourceKey] = {}
					for useKey, references in pairs(resourceUses) do
						newData.ResourceUse[turnKey][resourceKey][useKey] = {}
						for referenceKey, value in pairs(references) do
							Dprint( DEBUG_CITY_SCRIPT, Indentation15("ResourceUse"), turnKey, resourceKey, useKey, referenceKey, value)
							newData.ResourceUse[turnKey][resourceKey][useKey][referenceKey] = value
						end
					end
				end
			end
			
			for turnKey, data in pairs(originalData.Account) do
				newData.Account[turnKey] = {}
				for transactionType, transactionData in pairs(data) do
					newData.Account[turnKey][transactionType] = {}
					for refKey, value in pairs(transactionData) do
						Dprint( DEBUG_CITY_SCRIPT, Indentation15("Account"), turnKey, transactionType, refKey, value)
						newData.Account[turnKey][transactionType][refKey] = value
					end
				end
			end
			
			for turnKey, data in pairs(originalData.Population) do
				newData.Population[turnKey] = {}
				for PopulationKey, value in pairs(data) do
					Dprint( DEBUG_CITY_SCRIPT, Indentation15("Population"), turnKey, PopulationKey, value)
					newData.Population[turnKey][PopulationKey] = value
				end
			end

			-- remove unlocker buildings that may now be pillaged and unrepairable...
			--[[
			for row in GameInfo.Buildings() do
				if row.Unlockers then
					local unlockerID = row.Index
					if city:GetBuildings():HasBuilding(unlockerID) then
						Dprint( DEBUG_CITY_SCRIPT, "Removing unlocker : ", unlocker)
						city:GetBuildings():RemoveBuilding(unlockerID);
						pCityBuildQueue:RemoveBuilding(unlockerID);
					end
				end
			end

			-- reset unlockers
			city:SetUnlockers()
			--]]
		else
			GCO.Error("no data for new City on capture, cityID #", newCityID, "playerID #", newOwnerID)
		end

		ExposedMembers.CityData[originalCityKey] = nil

	else
		GCO.Error("no data for original City on capture, cityID #", originalCityID, "playerID #", originalOwnerID)
	end
end
--GameEvents.CapturedCityInitialized.Add( UpdateCapturedCity ) -- called in Events.CityInitialized (after Events.CityAddedToMap and InitializeCity...)

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
		local city = GetCityFromKey ( cityKey )
		if city then print(city:GetName()) end
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
_cached.CityPopulationAtSize = {}
function GetPopulationPerSize(size)
	if not _cached.CityPopulationAtSize[size] then
		_cached.CityPopulationAtSize[size] = GCO.Round(math.pow(size, populationPerSizepower) * 1000)
	end
	return _cached.CityPopulationAtSize[size]
end


-----------------------------------------------------------------------------------------
-- City functions
-----------------------------------------------------------------------------------------
function IsInitialized(self)
	local cityKey = self:GetKey()
	if ExposedMembers.CityData[cityKey] then return true end
end

function GetCityKeyFromIDs(cityID, ownerID)
	return cityID..","..ownerID
end

function GetKey(self)
	return GetCityKeyFromIDs (self:GetID(), self:GetOwner())
end

function GetData(self)
	local cityKey 	= self:GetKey()
	local cityData 	= ExposedMembers.CityData[cityKey]
	if not cityData then GCO.Warning("cityData is nil for ".. Locale.Lookup(self:GetName())); GCO.DlineFull(); end
	return cityData
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
		GCO.Warning("cityData is nil for " .. self:GetName(), self:GetKey())
		return 0
	end
	return Data[key]
end

function SetValue(self, key, value)
	local Data = self:GetData()
	if not Data then
		GCO.Error("cityData is nil for " .. self:GetName(), self:GetKey() .. "[NEWLINE]Trying to set ".. tostring(key) .." value to " ..tostring(value))
	end
	Data[key] = value
end

function GetCityFromKey ( cityKey )
	if ExposedMembers.CityData[cityKey] then
		local city = GetCity(ExposedMembers.CityData[cityKey].playerID, ExposedMembers.CityData[cityKey].cityID)
		if city then
			return city
		else
			GCO.Warning("city is nil for GetCityFromKey(".. tostring(cityKey)..")")
			GCO.DlineFull()
			Dprint( DEBUG_CITY_SCRIPT, "--- CityId = " .. ExposedMembers.CityData[cityKey].cityID ..", playerID = " .. ExposedMembers.CityData[cityKey].playerID)
		end
	else
		GCO.Warning("ExposedMembers.CityData[cityKey] is nil for GetCityFromKey(".. tostring(cityKey)..")")
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
	local wealth = Div((self:GetUpperClass()*WealthUpperRatio + self:GetMiddleClass()*WealthMiddleRatio + self:GetLowerClass()*WealthLowerRatio + self:GetSlaveClass()*WealthSlaveRatio), self:GetRealPopulation())
	_cached[cityKey].Wealth = GCO.ToDecimals(wealth)
end

function TurnCreated(self)
	local cityKey = self:GetKey()
	if ExposedMembers.CityData[cityKey] then
		return ExposedMembers.CityData[cityKey].TurnCreated
	end
	return Game.GetCurrentGameTurn()
end

function IsCoastal(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then _cached[cityKey] = {} end
	if not _cached[cityKey].Coastal then
		local plot = Map.GetPlot(self:GetX(), self:GetY())
		if plot:IsCoastalLand() then
			_cached[cityKey].Coastal = 1 -- we're not using false/true as the point is to avoid to check the plot everytime, which would happens at the 3rd line in this function if _cached[cityKey].Coastal = false
		else
			_cached[cityKey].Coastal = 0
		end
	end
	return (_cached[cityKey].Coastal == 1)
end

function RecordTransaction(self, accountType, value, refKey, turnKey) --turnKey optionnal
	local cityData 	= self:GetData()
	local turnKey 	= turnKey or GCO.GetTurnKey()
	if not cityData.Account[turnKey] then cityData.Account[turnKey] = {} end
	if not cityData.Account[turnKey][accountType] then cityData.Account[turnKey][accountType] = {} end
	cityData.Account[turnKey][accountType][refKey] = (cityData.Account[turnKey][accountType][refKey] or 0) + value
end

function GetTransactionValue(self, accountType, refKey, turnKey)
	local cityData 	= self:GetData()	
	if not cityData.Account[turnKey] then return 0 end
	if not cityData.Account[turnKey][accountType] then return 0 end
	return cityData.Account[turnKey][accountType][refKey] or 0
end

function GetModifiersForEffect(self, eEffectType) -- Cities, Units
	local list		= {}
	local pPlayer 	= GCO.GetPlayer(self:GetOwner())
	local pTechs	= pPlayer:GetTechs()
	local bValid	= false
	local modifiers	= GCO.GetEffectModifiers(eEffectType)
	local value		= 0 -- to do: column for type of result: stacked (added) or best in <EffectsGCO>
	for i, row in ipairs(modifiers) do
		local data = GameInfo[row.Table] and GameInfo[row.Table][row.ObjectType]
		if row.Table == "Technologies" then
			bValid = pTechs:HasTech(data.Index)
		elseif row.Table == "Policies" then
			bValid = pPlayer:HasPolicyActive(data.Index)
		elseif row.Table == "Governments" then
			bValid = pPlayer:GetCurrentGovernment() == data.Index
		elseif row.Table == "Buildings" then
			bValid = self:GetBuildings():HasBuilding(data.Index)
		end
		
		if bValid then
			value = value + row.Value
			table.insert(list, {Type = row.ObjectType, Value = row.Value, Name = GameInfo[row.Table][row.ObjectType].Name})
		end
	end
	return value, list
end


-----------------------------------------------------------------------------------------
-- Population functions
-----------------------------------------------------------------------------------------
function GetRealPopulation(self) -- the original city:GetPopulation() returns city size
	--[[
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetRealPopulation()
	elseif not _cached[cityKey].TotalPopulation then
		self:SetRealPopulation()
	end
	return _cached[cityKey].TotalPopulation
	--]]
	return self:GetUpperClass() + self:GetMiddleClass() + self:GetLowerClass() + self:GetSlaveClass()
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

function GetRealSize(self) -- size with decimals
	return math.pow(self:GetRealPopulation()/1000, 1/populationPerSizepower) --GCO.Round(math.pow(self:GetPopulation()/1000, 1/populationPerSizepower))
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

function UpdateSize(self)
	local currentSize 			= math.floor(GCO.GetSizeAtPopulation(self:GetRealPopulation()))
	local size 					= self:GetSize()
	local sizeDiff				= currentSize - size
	local DEBUG_CITY_SCRIPT		= DEBUG_CITY_SCRIPT
	--if Game.GetLocalPlayer() 	== self:GetOwner() then DEBUG_CITY_SCRIPT = "debug" end
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "UpdateSize for "..Locale.Lookup(self:GetName()))
	Dprint( DEBUG_CITY_SCRIPT, "sizeDiff = ", sizeDiff)
	Dprint( DEBUG_CITY_SCRIPT, "check change size to ", size+1, "required =", GetPopulationPerSize(size+1), "current =", self:GetRealPopulation())
	Dprint( DEBUG_CITY_SCRIPT, "check change size to ", size-1, "required =", GetPopulationPerSize(size), "current =", self:GetRealPopulation())
	if GetPopulationPerSize(size) > self:GetRealPopulation() and size > 1 then -- GetPopulationPerSize(self:GetSize()-1) > self:GetRealPopulation()
		self:ChangePopulation(-1) -- (-1, true) ?
		--self:ChangePopulation(sizeDiff)
	elseif GetPopulationPerSize(size+1) < self:GetRealPopulation() then
		self:ChangePopulation(1)
		--self:ChangePopulation(sizeDiff)
	end
end

function GetMaxUpperClass(self)
	local cityKey 			= self:GetKey()
	local maxPercent 		= UpperClassMaxPercent
	local returnStrTable 	= {}
	
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_UPPER" and row.EffectType == "CLASS_MAX_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				maxPercent 	= maxPercent + row.EffectValue
				table.insert(returnStrTable, Locale.Lookup("LOC_PERCENTAGE_FROM_BUILDING", GCO.GetVariationStringGreenPositive(row.EffectValue), GameInfo.Buildings[row.BuildingType].Name))
			end
		end
	end
	
	local NeedsEffects	= self:GetCached("NeedsEffects") or {}
	if NeedsEffects[UpperClassID] then
		local data = NeedsEffects[UpperClassID][NeedsEffectType.SocialStratification] or {}
		for key, value in pairs(data) do		
			table.insert(returnStrTable, Locale.Lookup(key, value))
			maxPercent = maxPercent + value
		end
	end
	
	Dprint( DEBUG_CITY_SCRIPT, "Max Upper Class %", maxPercent)
	return GCO.Round(self:GetRealPopulation() * maxPercent / 100), table.concat(returnStrTable, "[NEWLINE]")
end

function GetMinUpperClass(self)
	local cityKey 			= self:GetKey()
	local minPercent 		= UpperClassMinPercent
	local returnStrTable 	= {}
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_UPPER" and row.EffectType == "CLASS_MIN_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				minPercent = minPercent + row.EffectValue
				table.insert(returnStrTable, Locale.Lookup("LOC_PERCENTAGE_FROM_BUILDING", GCO.GetVariationStringGreenPositive(row.EffectValue), GameInfo.Buildings[row.BuildingType].Name))
			end
		end
	end
	
	local NeedsEffects	= self:GetCached("NeedsEffects") or {}
	if NeedsEffects[UpperClassID] then
		local data = NeedsEffects[UpperClassID][NeedsEffectType.SocialStratification] or {}
		for key, value in pairs(data) do		
			table.insert(returnStrTable, Locale.Lookup(key, value))
			minPercent = minPercent + value
		end
	end
	
	Dprint( DEBUG_CITY_SCRIPT, "Min Upper Class %", minPercent)
	return GCO.Round(self:GetRealPopulation() * minPercent / 100), table.concat(returnStrTable, "[NEWLINE]")
end

function GetMaxMiddleClass(self)
	local maxPercent 		= MiddleClassMaxPercent
	local returnStrTable 	= {}
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_MIDDLE" and row.EffectType == "CLASS_MAX_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				maxPercent = maxPercent + row.EffectValue
				table.insert(returnStrTable, Locale.Lookup("LOC_PERCENTAGE_FROM_BUILDING", GCO.GetVariationStringGreenPositive(row.EffectValue), GameInfo.Buildings[row.BuildingType].Name))
			end
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "Max Middle Class %", maxPercent)
	return GCO.Round(self:GetRealPopulation() * maxPercent / 100)
end

function GetMinMiddleClass(self)
	local minPercent 		= MiddleClassMinPercent
	local returnStrTable 	= {}
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_MIDDLE" and row.EffectType == "CLASS_MIN_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				minPercent = minPercent + row.EffectValue
				table.insert(returnStrTable, Locale.Lookup("LOC_PERCENTAGE_FROM_BUILDING", GCO.GetVariationStringGreenPositive(row.EffectValue), GameInfo.Buildings[row.BuildingType].Name))
			end
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "Min Middle Class %", minPercent)
	return GCO.Round(self:GetRealPopulation() * minPercent / 100), table.concat(returnStrTable, "[NEWLINE]")
end

function GetMaxLowerClass(self)
	local maxPercent 		= LowerClassMaxPercent
	local returnStrTable 	= {}
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_LOWER" and row.EffectType == "CLASS_MAX_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				maxPercent = maxPercent + row.EffectValue
				table.insert(returnStrTable, Locale.Lookup("LOC_PERCENTAGE_FROM_BUILDING", GCO.GetVariationStringGreenPositive(row.EffectValue), GameInfo.Buildings[row.BuildingType].Name))
			end
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "Max Lower Class %", maxPercent)
	return GCO.Round(self:GetRealPopulation() * maxPercent / 100), table.concat(returnStrTable, "[NEWLINE]")
end

function GetMinLowerClass(self)
	local minPercent 		= LowerClassMinPercent
	local returnStrTable 	= {}
	for row in GameInfo.BuildingPopulationEffect() do
		if row.PopulationType == "POPULATION_LOWER" and row.EffectType == "CLASS_MIN_PERCENT" then
			local buildingID = GameInfo.Buildings[row.BuildingType].Index
			if self:GetBuildings():HasBuilding(buildingID) then
				minPercent = minPercent + row.EffectValue
				table.insert(returnStrTable, Locale.Lookup("LOC_PERCENTAGE_FROM_BUILDING", GCO.GetVariationStringGreenPositive(row.EffectValue)), GameInfo.Buildings[row.BuildingType].Name)
			end
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "Min Lower Class %", minPercent)
	return GCO.Round(self:GetRealPopulation() * minPercent / 100), table.concat(returnStrTable, "[NEWLINE]")
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
	GCO.Error("can't find population class for ID = ", populationID)
	return 0
end

function ChangePopulationClass(self, populationID, value)
	if populationID == UpperClassID 	then return self:ChangeUpperClass(value) end
	if populationID == MiddleClassID 	then return self:ChangeMiddleClass(value) end
	if populationID == LowerClassID 	then return self:ChangeLowerClass(value) end
	if populationID == SlaveClassID 	then return self:ChangeSlaveClass(value) end
	GCO.Error("can't find population class for ID = ", populationID)
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

function GetMigration(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetMigrationValues()
	elseif not _cached[cityKey].Migration then
		self:SetMigrationValues()
	end
	return _cached[cityKey].Migration
end

function GetPopulationHousing(self)
	local upperClass				= self:GetUpperClass()
	local middleClass				= self:GetMiddleClass()
	local lowerClass				= self:GetLowerClass()
	local slaveClass				= self:GetSlaveClass()
	local upperHousingSize			= self:GetCustomYield( GameInfo.CustomYields["YIELD_UPPER_HOUSING"].Index )
	local upperHousing				= GCO.GetPopulationPerSize(upperHousingSize)
	local upperHousingAvailable		= math.max( 0, upperHousing - upperClass)
	local upperLookingForMiddle		= math.max( 0, upperClass - upperHousing)
	local middleHousingSize			= self:GetCustomYield( GameInfo.CustomYields["YIELD_MIDDLE_HOUSING"].Index )
	local middleHousing				= GCO.GetPopulationPerSize(middleHousingSize)
	local middleHousingAvailable	= math.max( 0, middleHousing - middleClass - upperLookingForMiddle)
	local middleLookingForLower		= math.max( 0, (middleClass + upperLookingForMiddle) - middleHousing)
	local lowerHousingSize			= self:GetCustomYield( GameInfo.CustomYields["YIELD_LOWER_HOUSING"].Index )
	local lowerHousing				= GCO.GetPopulationPerSize(lowerHousingSize)
	local lowerHousingAvailable		= math.max( 0, lowerHousing - lowerClass - middleLookingForLower)

	
	
	local PopulationHousing							= { [UpperClassID] = {}, [MiddleClassID] = {}, [LowerClassID] = {}}
	PopulationHousing.TotalMaxHousing				= upperHousing + middleHousing + lowerHousing + slaveClass -- slave class doesn't use housing space
	PopulationHousing[UpperClassID].MaxHousing		= upperHousing + math.max(0, middleHousing - middleClass)
	PopulationHousing[MiddleClassID].MaxHousing		= middleHousing + math.max(0, lowerHousing - lowerClass)
	PopulationHousing[LowerClassID].MaxHousing		= lowerHousing
	PopulationHousing[UpperClassID].HigherReserved 	= 0
	PopulationHousing[MiddleClassID].HigherReserved = upperLookingForMiddle
	PopulationHousing[LowerClassID].HigherReserved 	= middleLookingForLower
	PopulationHousing[UpperClassID].Available 		= math.max(0, upperHousing + middleHousing - upperClass)
	PopulationHousing[MiddleClassID].Available		= math.max(0, middleHousing + lowerHousing - middleClass - upperLookingForMiddle)
	PopulationHousing[LowerClassID].Available	 	= math.max(0, lowerHousing - lowerClass - middleLookingForLower)
	--[[
	local HousingOccupiedByHigher				= {}
	HousingOccupiedByHigher[UpperClassID] 		= 0
	HousingOccupiedByHigher[MiddleClassID] 		= math.min( middleHousing, upperLookingForMiddle)
	HousingOccupiedByHigher[LowerClassID] 		= math.min( lowerHousing, middleLookingForLower)
	return HousingOccupiedByHigher
	--]]
	return PopulationHousing
end
-----------------------------------------------------------------------------------------
-- Science Functions
-----------------------------------------------------------------------------------------
function GetLiteracy(self)
	return self:GetCached("Literacy") or self:SetLiteracy()
end

function SetLiteracy(self) -- must be updated before Research:DoTurn()
	local population	= self:GetRealPopulation()
	local literacy		= GCO.ToDecimals(math.min(100, (100 * Div(self:GetUpperClass(), population)) + (50 * Div(self:GetMiddleClass(), population))))
	self:SetCached("Literacy", literacy)
	return literacy
end

function CanDoResearch(self)
	local cityBuildings	= self:GetBuildings()
	if 	cityBuildings:HasBuilding(GameInfo.Buildings["BUILDING_SCRIBE_HOUSE"].Index)
		or cityBuildings:HasBuilding(GameInfo.Buildings["BUILDING_LIBRARY"].Index)
		or cityBuildings:HasBuilding(GameInfo.Buildings["BUILDING_UNIVERSITY"].Index)
	then
		return true
	else
		return false
	end
end

-----------------------------------------------------------------------------------------
-- Resources Transfers
-----------------------------------------------------------------------------------------
function UpdateLinkedUnits(self)

	Dlog("UpdateLinkedUnits ".. Locale.Lookup(self:GetName()).." /START")
	--local DEBUG_CITY_SCRIPT = "CityScript"

	Dprint( DEBUG_CITY_SCRIPT, "Updating Linked Units...")
	local selfKey 				= self:GetKey()
	LinkedUnits[selfKey] 		= {}
	UnitsSupplyDemand[selfKey] 	= { Resources = {}, NeedResources = {}, PotentialResources = {}} -- NeedResources : Number of units requesting a resource type

	for unitKey, data in pairs(ExposedMembers.UnitData) do
		local efficiency = data.SupplyLineEfficiency
		if data.SupplyLineCityKey == self:GetKey() and efficiency > 0 then
			local unit = GCO.GetUnit(data.playerID, data.unitID)
			if unit then
				LinkedUnits[selfKey][unitKey] = {NeedResources = {}}
				if not unit:IsDisbanding() then
					local bTotal		= unit:CanGetFullReinforcement()
					local requirements 	= unit:GetRequirements(bTotal)
					for resourceID, value in pairs(requirements.Resources) do
						if value > 0 then
							UnitsSupplyDemand[selfKey].Resources[resourceID] 		= ( UnitsSupplyDemand[selfKey].Resources[resourceID] 		or 0 ) + GCO.Round(requirements.Resources[resourceID]*efficiency/100)
							UnitsSupplyDemand[selfKey].NeedResources[resourceID] 	= ( UnitsSupplyDemand[selfKey].NeedResources[resourceID] 	or 0 ) + 1
							LinkedUnits[selfKey][unitKey].NeedResources[resourceID] = true
						end
					end
				end
			end
		end
	end

	Dlog("UpdateLinkedUnits /START")
end

function GetLinkedUnits(self)
	local selfKey = self:GetKey()
	if not LinkedUnits[selfKey] then self:UpdateLinkedUnits() end
	return LinkedUnits[selfKey]
end

function UpdateCitiesConnection(self, transferCity, sRouteType, bInternalRoute, tradeRouteLevel)

	--local DEBUG_CITY_SCRIPT = "debug"
	local DEBUG_CITY_SCRIPT 	= DEBUG_CITY_SCRIPT
	--if Locale.Lookup(self:GetName()) =="Urumqi" or Locale.Lookup(transferCity:GetName()) =="Urumqi" then DEBUG_CITY_SCRIPT = "debug" end

	local selfKey 		= self:GetKey()
	local transferKey 	= transferCity:GetKey()
	local selfPlot 		= GCO.GetPlot(self:GetX(), self:GetY())
	local transferPlot	= GCO.GetPlot(transferCity:GetX(), transferCity:GetY())
	local currentTurn 	= Game.GetCurrentGameTurn()
	local maxlength		= self:GetMaxRouteLength(sRouteType)

	-- Convert "Coastal" to "Ocean" with required tech for navigation on Ocean
	-- to do check for docks to allow transfert by sea/rivers
	-- add new building for connection by river (river docks)
	if sRouteType == "Coastal" then
		local pTech = Players[self:GetOwner()]:GetTechs()
		if pTech and not pTech:HasTech(GameInfo.Technologies["TECH_SAILING"].Index) then
			return
		end
		if pTech and pTech:HasTech(GameInfo.Technologies["TECH_CARTOGRAPHY"].Index) then
			sRouteType = "Ocean"
		end
	end

	Dprint( DEBUG_CITY_SCRIPT, "Testing "..tostring(sRouteType).." route from "..Locale.Lookup(self:GetName()).." to ".. Locale.Lookup(transferCity:GetName()))

	-- check if the route is possible before trying to determine it...
	local distance = Map.GetPlotDistance(selfPlot:GetX(), selfPlot:GetY(), transferPlot:GetX(), transferPlot:GetY())
	
	if sRouteType == "Coastal" then
		if ( not(selfPlot:IsCoastalLand() and transferPlot:IsCoastalLand()) ) or maxlength < distance then
			Dprint( DEBUG_CITY_SCRIPT, " - abort from starting conditions: selfPlot:IsCoastalLand() = ", selfPlot:IsCoastalLand(), " transferPlot:IsCoastalLand() = ", transferPlot:IsCoastalLand(), " maxlength = ", maxlength, " distance = ", distance)
			return
		end

	elseif sRouteType == "River" then
		if ( not(selfPlot:IsRiver() and transferPlot:IsRiver()) ) or maxlength < Map.GetPlotDistance(selfPlot:GetX(), selfPlot:GetY(), transferPlot:GetX(), transferPlot:GetY())  then
			Dprint( DEBUG_CITY_SCRIPT, " - abort from starting conditions: selfPlot:IsRiver() = ", selfPlot:IsRiver(), " transferPlot:IsRiver() = ", transferPlot:IsRiver(), " maxlength = ", maxlength, " distance = ", distance)
			return
		end

	elseif sRouteType == "Road" then
		if maxlength < Map.GetPlotDistance(selfPlot:GetX(), selfPlot:GetY(), transferPlot:GetX(), transferPlot:GetY()) then
			Dprint( DEBUG_CITY_SCRIPT, " - abort from starting conditions: maxlength = ", maxlength, " distance = ", distance)
			return
		end
	end

	local bIsPlotConnected 	= false
	local routeLength		= 0
	local pathPlots			= {}
	if sRouteType == "River" then
	
		GCO.StartTimer("GetRiverPath")
		local path = selfPlot:GetRiverPath(transferPlot)
		GCO.ShowTimer("GetRiverPath")
		if path then
			bIsPlotConnected 	= true
			routeLength 		= #path
			pathPlots			= path
		end
	else
		--[[
		GCO.StartTimer("IsPlotConnected"..sRouteType)
		bIsPlotConnected 	= GCO.IsPlotConnected(Players[self:GetOwner()], selfPlot, transferPlot, sRouteType, true, nil, GCO.TradePathBlocked)
		GCO.ShowTimer("IsPlotConnected"..sRouteType)
		routeLength 		= GCO.GetRouteLength()
		pathPlots 			= GCO.GetRoutePlots()
		--]]
		
		GCO.StartTimer("GetPathToPlot"..sRouteType)
		local path = selfPlot:GetPathToPlot(transferPlot, Players[self:GetOwner()], sRouteType, GCO.TradePathBlocked, maxlength)
		GCO.ShowTimer("GetPathToPlot"..sRouteType)
		if path then
			bIsPlotConnected 	= true
			routeLength 		= #path
			pathPlots			= path
		end
	end
	if bIsPlotConnected then
		local efficiency 	= GCO.GetRouteEfficiency( routeLength * SupplyRouteLengthFactor[SupplyRouteType[sRouteType]] )
		if efficiency > 0 then
			Dprint( DEBUG_CITY_SCRIPT, " - Found route at " .. tostring(efficiency).." % efficiency, bInternalRoute = ", tostring(bInternalRoute))
			if bInternalRoute then
				if (not CitiesForTransfer[selfKey][transferKey]) or (CitiesForTransfer[selfKey][transferKey].Efficiency < efficiency) then
					CitiesForTransfer[selfKey][transferKey] = { RouteType = SupplyRouteType[sRouteType], Efficiency = efficiency, PathPlots = pathPlots, LastUpdate = currentTurn }
				end
			else
				if (not CitiesForTrade[selfKey][transferKey]) or (CitiesForTrade[selfKey][transferKey].Efficiency < efficiency) then
					CitiesForTrade[selfKey][transferKey] = { RouteType = SupplyRouteType[sRouteType], Efficiency = efficiency, TradeRouteLevel = tradeRouteLevel, PathPlots = pathPlots, LastUpdate = currentTurn }
				end
			end
		else
			Dprint( DEBUG_CITY_SCRIPT, " - Can't register route, too far away " .. tostring(efficiency).." % efficiency")
		end
	else
		Dprint( DEBUG_CITY_SCRIPT, " - Can't find a route")
	end
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
	local maxRouteLength = GCO.CalculateMaxRouteLength(SupplyRouteLengthFactor[SupplyRouteType[sRouteType]])
	Dprint( DEBUG_CITY_SCRIPT, "Setting max route length for "..tostring(sRouteType).." = ".. tostring(maxRouteLength))
	_cached[cityKey].MaxRouteLength[sRouteType] = maxRouteLength
end

function GetMaxInternalLandRoutes( self )
	return 1
end

function GetMaxInternalRiverRoutes( self )
	return 1
end

function GetMaxInternalSeaRoutes( self )
	return 1
end

function GetMaxExternalLandRoutes( self )
	return 1
end

function GetMaxExternalRiverRoutes( self )
	return 1
end

function GetMaxExternalSeaRoutes( self )
	return 1
end

function GetTransferCities(self)
	local selfKey = self:GetKey()
	if not CitiesForTransfer[selfKey] then
		return {} --self:UpdateTransferCities() -- UpdateTransferCities() must not be called from the UI, it affect gameplay and would lead to desync.
	end
	return CitiesForTransfer[selfKey]
end

function GetExportCities(self)
	local selfKey = self:GetKey()
	if not CitiesForTrade[selfKey] then
		return {} --self:UpdateExportCities() -- UpdateExportCities() must not be called from the UI, it affect gameplay and would lead to desync.
	end
	return CitiesForTrade[selfKey]
end

function UpdateTransferCities(self)
	local name 		= Locale.Lookup(self:GetName())
	GCO.StartTimer("UpdateTransferCities for ".. name)
	Dlog("UpdateTransferCities ".. name.." /START")
	--local DEBUG_CITY_SCRIPT = "CityScript"
	Dprint( DEBUG_CITY_SCRIPT, "Updating Routes to same Civilization Cities for ".. name)
	
	-- reset entries for that city
	local selfKey 					= self:GetKey()
	CitiesTransferDemand[selfKey] 	= { Resources = {}, NeedResources = {}, ReservedResources = {}, HasPrecedence = {} } -- NeedResources : Number of cities requesting a resource type

	local currentTurn 	= Game.GetCurrentGameTurn()
	local hasRouteTo 	= {}
	local ownerID 		= self:GetOwner()
	local player 		= Players[ownerID] --GCO.GetPlayer(ownerID) --<-- player:GetCities() sometime don't give the city objects from this script context
	local playerCities 	= player:GetCities()

	if not CitiesForTransfer[selfKey] 	then CitiesForTransfer[selfKey] = {} end	-- Internal transfer cities
	if not CitiesOutOfReach[selfKey] 	then CitiesOutOfReach[selfKey] = {} end		-- Cities we can't reach at this moment
	
	local citiesList = {}
	for i, transferCity in playerCities:Members() do
		local distance = Map.GetPlotDistance(self:GetX(), self:GetY(), transferCity:GetX(), transferCity:GetY())
		table.insert(citiesList, { TransferCity = transferCity, Distance = distance })
	end
	table.sort(citiesList, function(a, b) return a.Distance < b.Distance; end)
	
	-- try to create routes until the max possible number of routes is reached (or there is no cities left to iterate), starting by closest cities first
	local availableLandRoutes 	= self:GetMaxInternalLandRoutes()
	local availableRiverRoutes	= self:GetMaxInternalRiverRoutes()
	local availableSeaRoutes	= self:GetMaxInternalSeaRoutes()
	for _, cityData in ipairs(citiesList) do
		local transferCity	= cityData.TransferCity
		local transferKey 	= transferCity:GetKey()
		if transferKey ~= selfKey and not CitiesToIgnoreThisTurn[transferKey] then
		
			if CitiesOutOfReach[selfKey][transferKey] then
				-- Update rate is relative to route length
				local distance			= cityData.Distance
				local turnSinceUpdate	= currentTurn - CitiesOutOfReach[selfKey][transferKey]
				if turnSinceUpdate > distance / 2 then
					Dprint( DEBUG_CITY_SCRIPT, " - ".. Locale.Lookup(transferCity:GetName()) .." at distance = "..tostring(distance).." was marked out of reach ".. tostring(turnSinceUpdate) .." turns ago, unmarking for next turn...")
					CitiesOutOfReach[selfKey][transferKey] = nil
				else
					Dprint( DEBUG_CITY_SCRIPT, " - ".. Locale.Lookup(transferCity:GetName()) .." at distance = "..tostring(distance).." is marked out of reach since ".. tostring(turnSinceUpdate) .." turns")
				end
			else
				-- link table
				local tradeRoute	= CitiesForTransfer[selfKey][transferKey]				
				local tradeRouteFrom
				
				if CitiesForTransfer[transferKey] then tradeRouteFrom = CitiesForTransfer[transferKey][selfKey] end
				
				-- check if the city at the other side of the route is already maintening it
				local bFreeRoute 	= (tradeRouteFrom and tradeRouteFrom.MaintainedRoute)
					
				-- do we need to update the route ?
				local bNeedUpdate 	= false
				if tradeRoute then
					if tradeRoute.RouteType ~= SupplyRouteType.Trader then
						-- Update rate is relative to route length
						local routeLength 		= #tradeRoute.PathPlots
						local turnSinceUpdate	= currentTurn - tradeRoute.LastUpdate
						if turnSinceUpdate > routeLength / 2 then
							bNeedUpdate = true								
						end
						
						-- check for blockade
						if not bNeedUpdate and tradeRoute.RouteType ~= SupplyRouteType.Trader then 
							for i=1, #tradeRoute.PathPlots do
								local plot = Map.GetPlotByIndex(tradeRoute.PathPlots[i])
								if GCO.TradePathBlocked(plot, Players[self:GetOwner()]) then
									bNeedUpdate = true
									break
								end
							end
						end
					else	-- trader routes are updated on change
						bNeedUpdate = false
					end
				else
					bNeedUpdate = true
				end
		
				if bNeedUpdate then
					--[[ -- now updated on route change
					-- search for trader routes first
					local trade 				= GCO.GetCityTrade(transferCity)
					local tradeManager:table 	= GCO.GetTradeManager()
					local outgoingRoutes 		= trade:GetOutgoingRoutes()
					for j,route in ipairs(outgoingRoutes) do
						if route ~= nil and route.DestinationCityPlayer == ownerID and route.DestinationCityID == self:GetID() then
							Dprint( DEBUG_CITY_SCRIPT, " - Found trader for transfer from ".. Locale.Lookup(transferCity:GetName()))
							local pathPlots 						= tradeManager:GetTradeRoutePath(transferCity:GetOwner(), transferCity:GetID(), self:GetOwner(), self:GetID() )
							CitiesForTransfer[selfKey][transferKey] = { RouteType = SupplyRouteType.Trader, Efficiency = 100, PathPlots = pathPlots, LastUpdate = currentTurn }
							hasRouteTo[transferKey] 				= true
						end
					end

					if not hasRouteTo[transferKey] then
						for j,route in ipairs(trade:GetIncomingRoutes()) do
							if route ~= nil and route.OriginCityPlayer == ownerID and route.OriginCityID == self:GetID() then
								Dprint( DEBUG_CITY_SCRIPT, " - Found trader for transfer to ".. Locale.Lookup(transferCity:GetName()))
								local pathPlots 						= tradeManager:GetTradeRoutePath(self:GetOwner(), self:GetID(), transferCity:GetOwner(), transferCity:GetID() )
								CitiesForTransfer[selfKey][transferKey] = { RouteType = SupplyRouteType.Trader, Efficiency = 100, PathPlots = pathPlots, LastUpdate = currentTurn }
								hasRouteTo[transferKey] 				= true
							end
						end
					end
					--]]
				
					-- search for other types or routes
					local bInternalRoute = true
					--if not hasRouteTo[transferKey] then

						-- to do : in case of a route maintained by the other city, match the route type, or mark it as not "free"
					
						if (availableLandRoutes > 0) or (bFreeRoute and tradeRouteFrom.RouteType == SupplyRouteType.Road) then
							self:UpdateCitiesConnection(transferCity, "Road", bInternalRoute)
						end
						if (availableRiverRoutes > 0) or (bFreeRoute and tradeRouteFrom.RouteType == SupplyRouteType.River) then
							self:UpdateCitiesConnection(transferCity, "River", bInternalRoute)
						end
						if (availableSeaRoutes > 0) or (bFreeRoute and (tradeRouteFrom.RouteType == SupplyRouteType.Coastal or tradeRouteFrom.RouteType == SupplyRouteType.Ocean)) then
							self:UpdateCitiesConnection(transferCity, "Coastal", bInternalRoute)
						end

					--end
				end

				-- if the route was nil, it may now have been set in UpdateCitiesConnection()
				local tradeRoute	= CitiesForTransfer[selfKey][transferKey]
				
				if tradeRoute and tradeRoute.Efficiency > 0 then
					local routeType = tradeRoute.RouteType
					local bAbort 	= false
					if (routeType ~= SupplyRouteType.Trader) then

						-- check if the city can (still) maintain that route or update the number of route slots left
						-- a closer city may have replaced it, or an event may have removed some available route slots
						if not bFreeRoute then
							if routeType == SupplyRouteType.Road 	then
								if availableLandRoutes > 0 then
									availableLandRoutes = availableLandRoutes - 1
								else
									bAbort = true
								end
							end
							if routeType == SupplyRouteType.River 	then
								if availableRiverRoutes > 0 then
									availableRiverRoutes = availableRiverRoutes - 1
								else
									bAbort = true
								end
							end
							if routeType == SupplyRouteType.Coastal or routeType == SupplyRouteType.Ocean then
								if availableSeaRoutes > 0 then
									availableSeaRoutes = availableSeaRoutes - 1
								else
									bAbort = true
								end
							end
							
							if bAbort then
								-- that route is not valid anymore 
								CitiesForTransfer[selfKey][transferKey] = nil
							else
								-- mark that this city is maintaining the route 
								CitiesForTransfer[selfKey][transferKey].MaintainedRoute = true
							end
						end						
					end

					if not bAbort then
						local requirements 	= transferCity:GetRequirements(self) -- Get the resources required by transferCity and available in current city (self)...
						local efficiency	= tradeRoute.Efficiency

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
				else
					CitiesOutOfReach[selfKey][transferKey] = currentTurn
				end
			end
		end
		if availableLandRoutes + availableRiverRoutes + availableSeaRoutes <= 0 then
			--break() -- we need to continue to iterate for the "free" routes 
		end
	end
	
	Dlog("UpdateTransferCities "..name.." /END")
	GCO.ShowTimer("UpdateTransferCities for ".. name)
end

function TransferToCities(self)
	Dlog("TransferToCities ".. Locale.Lookup(self:GetName()).." /START")
	--local DEBUG_CITY_SCRIPT = "CityScript"
	Dprint( DEBUG_CITY_SCRIPT, "Transfering to other cities for ".. Locale.Lookup(self:GetName()))
	local selfKey 			= self:GetKey()
	local supplyDemand 		= CitiesTransferDemand[selfKey]
	local transfers 		= {Resources = {}, ResPerCity = {}}
	local cityToSupply 		= {}
	local unsortedTable		= CitiesForTransfer[selfKey]
	for cityKey, data in pairs(unsortedTable) do
		local precedenceTable = {}
		for resourceID, _ in pairs(data.HasPrecedence) do
			precedenceTable[resourceID]	= true
		end
		table.insert(cityToSupply, { CityKey = cityKey, Efficiency = data.Efficiency, HasPrecedence = precedenceTable })
	end

	table.sort(cityToSupply, function(a, b) return a.Efficiency > b.Efficiency; end)

	for resourceID, value in pairs(supplyDemand.Resources) do
		local availableStock = self:GetAvailableStockForCities(resourceID)
		if supplyDemand.HasPrecedence[resourceID] then -- one city has made a prioritary request for that resource
			local bHasLocalPrecedence = (UnitsSupplyDemand[selfKey] and UnitsSupplyDemand[selfKey].Resources[resourceID]) or self:GetNumRequiredInQueue(resourceID) > 0  -- to do : a function to test all precedence, and another to return the number of unit of resource required, separate build queue / units
			if bHasLocalPrecedence then
				availableStock = math.max(availableStock, GCO.Round(self:GetAvailableStockForUnits(resourceID)*0.5)) -- sharing 50% of unit stock when both city requires it 
			else
				--availableStock = math.max(availableStock, GCO.Round(self:GetStock(resourceID)/2))
				availableStock = math.max(availableStock, GCO.Round(self:GetAvailableStockForUnits(resourceID)*0.75)) -- sharing 75% of unit stock when only the city to supply requires it
			end
		end
		transfers.Resources[resourceID] = math.min(value, availableStock)
		transfers.ResPerCity[resourceID] = math.floor(Div(transfers.Resources[resourceID],supplyDemand.NeedResources[resourceID]))
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
			for _, data in ipairs(cityToSupply) do
				local cityKey			= data.CityKey
				local city				= GetCityFromKey(cityKey)
				
				-- check for city = nil (could have been captured and key has changed)
				if city then
					local requiredValue		= city:GetNumResourceNeeded(resourceID)
					local bCityPrecedence	= data.HasPrecedence[resourceID]

					if PrecedenceLeft > 0 and bResourcePrecedence and not bCityPrecedence then
						requiredValue = 0
					end
					if requiredValue > 0 then
						local efficiency	= data.Efficiency
						local send 			= math.min(transfers.ResPerCity[resourceID], requiredValue, resourceLeft)
						local costPerUnit	= (resourceCost * self:GetTransportCostTo(city)) + resourceCost -- to do : cache transport cost ?
						if (costPerUnit < city:GetResourceCost(resourceID)) or (bCityPrecedence and PrecedenceLeft > 0) or city:GetStock(resourceID) == 0 then -- this city may be in cityToSupply list for another resource, so check cost here again before sending the resource...
							resourceLeft = resourceLeft - send
							if bCityPrecedence then
								PrecedenceLeft = PrecedenceLeft - send
							end
							city:ChangeStock(resourceID, send, ResourceUseType.TransferIn, selfKey, costPerUnit)
							self:ChangeStock(resourceID, -send, ResourceUseType.TransferOut, cityKey)
							Dprint( DEBUG_CITY_SCRIPT, "  - send " .. tostring(send) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." (".. tostring(efficiency) .." percent efficiency) to ".. Locale.Lookup(city:GetName()))
						end
					end
				end
			end
			loop = loop + 1
		end
	end
	Dlog("TransferToCities ".. Locale.Lookup(self:GetName()).." /END")
end

function UpdateExportCities(self)
	local name 		= Locale.Lookup(self:GetName())
	GCO.StartTimer("UpdateExportCities for ".. name)
	Dlog("UpdateExportCities ".. name.." /START")
	
	local DEBUG_CITY_SCRIPT 	= DEBUG_CITY_SCRIPT
	--if Locale.Lookup(self:GetName()) =="Urumqi" then DEBUG_CITY_SCRIPT = "debug" end
	
	Dprint( DEBUG_CITY_SCRIPT, "Updating Export Routes to other Civilizations Cities for ".. Locale.Lookup(self:GetName()))

	local selfKey 				= self:GetKey()	
	CitiesTradeDemand[selfKey] 	= { Resources = {}, NeedResources = {}}
	local hasRouteTo 			= {}
	local ownerID 				= self:GetOwner()
	local currentTurn 			= Game.GetCurrentGameTurn()
	
	if not CitiesForTrade[selfKey] 		then CitiesForTrade[selfKey] = {} end	-- Export to other civilizations cities
	if not CitiesOutOfReach[selfKey] 	then CitiesOutOfReach[selfKey] = {} end	-- Cities we can't reach at this moment

	local citiesList = {}
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player 			= Players[iPlayer]
		local pDiplo 			= player:GetDiplomacy()
		local pDiploAI			= player:GetAi_Diplomacy()
		if pDiplo and pDiploAI then
			local tradeRouteLevel 	= TradeLevelType.Neutral
			local bIsFriend			= (pDiploAI:GetDiplomaticState(ownerID) == "DIPLO_STATE_DECLARED_FRIEND") or (pDiploAI:GetDiplomaticState(ownerID) == "DIPLO_STATE_ALLIED")
			local bIsAllied			= (pDiploAI:GetDiplomaticState(ownerID) == "DIPLO_STATE_ALLIED")
			local bIsEmbargo		= (pDiploAI:GetDiplomaticState(ownerID) == "DIPLO_STATE_DENOUNCED")
			local playerConfig 		= PlayerConfigurations[iPlayer]
			
			if bIsFriend 	then tradeRouteLevel = TradeLevelType.Friend end
			if bIsAllied 	then tradeRouteLevel = TradeLevelType.Allied end
			if bIsEmbargo 	then tradeRouteLevel = TradeLevelType.Limited end
			
			if iPlayer ~= ownerID and pDiplo:HasMet( ownerID ) then
				if (not pDiplo:IsAtWarWith( ownerID )) then
					Dprint( DEBUG_CITY_SCRIPT, "- searching for possible trade routes with "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()).. ", tradeRouteLevel = ", tradeRouteLevel)
					local playerCities 	= player:GetCities()
					for _, transferCity in playerCities:Members() do
						local distance = Map.GetPlotDistance(self:GetX(), self:GetY(), transferCity:GetX(), transferCity:GetY())
						Dprint( DEBUG_CITY_SCRIPT, Indentation20(Locale.Lookup(transferCity:GetName())).. " Distance = ".. tostring(distance) )
						table.insert(citiesList, { TransferCity = transferCity, Distance = distance, TradeRouteLevel = tradeRouteLevel })
					end
				else -- remove routes if exist
					Dprint( DEBUG_CITY_SCRIPT, "- removing possible trade routes with "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()))
					local playerCities 	= player:GetCities()
					for _, transferCity in playerCities:Members() do
						local transferKey = transferCity:GetKey()
						CitiesForTrade[selfKey][transferKey] = nil
					end
				end
			end
		end
	end
	table.sort(citiesList, function(a, b) return a.Distance < b.Distance; end)

	-- try to create routes until the max possible number of routes is reached (or there is no cities left to iterate), starting by closest cities first
	local availableLandRoutes 	= self:GetMaxExternalLandRoutes()
	local availableRiverRoutes	= self:GetMaxExternalRiverRoutes()
	local availableSeaRoutes	= self:GetMaxExternalSeaRoutes()
	for _, cityData in ipairs(citiesList) do
		local transferCity	= cityData.TransferCity
		local transferKey 	= transferCity:GetKey()	
		Dprint( DEBUG_CITY_SCRIPT, Indentation20("   ".. Locale.Lookup(transferCity:GetName())))
		if transferKey ~= selfKey and transferCity:IsInitialized() then
			if CitiesOutOfReach[selfKey][transferKey] then
				-- Update rate is relative to route length
				local distance			= cityData.Distance
				local turnSinceUpdate	= currentTurn - CitiesOutOfReach[selfKey][transferKey]
				if turnSinceUpdate > distance / 2 then
					Dprint( DEBUG_CITY_SCRIPT, "   - distance = "..tostring(distance).." was marked out of reach ".. tostring(turnSinceUpdate) .." turns ago, unmarking for next turn...")
					CitiesOutOfReach[selfKey][transferKey] = nil
				else
					Dprint( DEBUG_CITY_SCRIPT, "   - at distance = "..tostring(distance).." is marked out of reach since ".. tostring(turnSinceUpdate) .." turns")
				end
			else
				local tradeRouteLevel = cityData.TradeRouteLevel
				-- check if the other city of the route is already maintening it
				local bFreeRoute 	= (CitiesForTrade[transferKey] and CitiesForTrade[transferKey][selfKey] and CitiesForTrade[transferKey][selfKey].MaintainedRoute)
				
				-- do we need to update the route ?
				local bNeedUpdate 	= false
				local tradeRoute	= CitiesForTrade[selfKey][transferKey]
				if tradeRoute then
					if tradeRoute.RouteType ~= SupplyRouteType.Trader then
				
						-- Update rate is relative to route length
						local routeLength 		= #tradeRoute.PathPlots
						local turnSinceUpdate	= currentTurn - tradeRoute.LastUpdate
						if turnSinceUpdate > routeLength / 2 then
							Dprint( DEBUG_CITY_SCRIPT, "   - (turnSinceUpdate > routeLength / 2)")
							bNeedUpdate = true								
						end
						
						-- check for blockade on path
						if not bNeedUpdate and tradeRoute.RouteType ~= SupplyRouteType.Trader then 
							for i=1, #tradeRoute.PathPlots do
								local plot = Map.GetPlotByIndex(tradeRoute.PathPlots[i])
								if GCO.TradePathBlocked(plot, Players[self:GetOwner()]) then
									Dprint( DEBUG_CITY_SCRIPT, "   - Found blockade on path")
									bNeedUpdate = true
									break
								end
							end
						end									
					else	-- trader routes are updated on change
						Dprint( DEBUG_CITY_SCRIPT, "   - Previous trader route found")
						bNeedUpdate = false
					end
						
					-- Update Diplomatic relations (That shouldn't require to update the Route itself)
					if tradeRouteLevel ~= tradeRoute.TradeRouteLevel then
						tradeRoute.TradeRouteLevel = tradeRouteLevel
						Dprint( DEBUG_CITY_SCRIPT, "   - Changing tradeRouteLevel to level #".. tostring(tradeRouteLevel))
					end
				else
					Dprint( DEBUG_CITY_SCRIPT, "   - No previous trade route")
					bNeedUpdate = true
				end
				
				Dprint( DEBUG_CITY_SCRIPT, "   - Need update : ", bNeedUpdate)
				Dprint( DEBUG_CITY_SCRIPT, "   - availableLandRoutes. = ", availableLandRoutes)
				Dprint( DEBUG_CITY_SCRIPT, "   - availableRiverRoutes = ", availableRiverRoutes)
				Dprint( DEBUG_CITY_SCRIPT, "   - availableSeaRoutes.. = ", availableSeaRoutes)
				
				if bNeedUpdate then
					--[[ -- now updated on route change
					-- search for trader routes first
					local trade 				= GCO.GetCityTrade(transferCity)
					local tradeManager:table 	= GCO.GetTradeManager()
					local outgoingRoutes 		= trade:GetOutgoingRoutes()
					for j,route in ipairs(outgoingRoutes) do
						if route ~= nil and route.DestinationCityPlayer == ownerID and route.DestinationCityID == self:GetID() then
							Dprint( DEBUG_CITY_SCRIPT, " - Found trader for international trade from ".. Locale.Lookup(transferCity:GetName()))
							local pathPlots 						= tradeManager:GetTradeRoutePath(transferCity:GetOwner(), transferCity:GetID(), self:GetOwner(), self:GetID() )
							CitiesForTrade[selfKey][transferKey] 	= { RouteType = SupplyRouteType.Trader, Efficiency = 100, TradeRouteLevel = tradeRouteLevel, PathPlots = pathPlots, LastUpdate = currentTurn}
							hasRouteTo[transferKey] 				= true
						end
					end

					if not hasRouteTo[transferKey] then
						for j,route in ipairs(trade:GetIncomingRoutes()) do
							if route ~= nil and route.OriginCityPlayer == ownerID and route.OriginCityID == self:GetID() then
								Dprint( DEBUG_CITY_SCRIPT, " - Found trader for international trade to ".. Locale.Lookup(transferCity:GetName()))
								local pathPlots 						= tradeManager:GetTradeRoutePath(self:GetOwner(), self:GetID(), transferCity:GetOwner(), transferCity:GetID() )
								CitiesForTrade[selfKey][transferKey] 	= { RouteType = SupplyRouteType.Trader, Efficiency = 100, TradeRouteLevel = tradeRouteLevel, PathPlots = pathPlots, LastUpdate = currentTurn }
								hasRouteTo[transferKey] 				= true
							end
						end
					end
					--]]
					
					-- search for other types or routes
					local bInternalRoute = false
					--if not hasRouteTo[transferKey] then
					
						-- to do : in case of a route maintained by the other city, match the route type, or mark it as not "free"
					
						if (availableLandRoutes > 0) or (bFreeRoute and CitiesForTrade[transferKey][selfKey].RouteType == SupplyRouteType.Road) then
							self:UpdateCitiesConnection(transferCity, "Road", bInternalRoute, tradeRouteLevel)
						end
						if (availableRiverRoutes > 0) or (bFreeRoute and CitiesForTrade[transferKey][selfKey].RouteType == SupplyRouteType.River) then
							self:UpdateCitiesConnection(transferCity, "River", bInternalRoute, tradeRouteLevel)
						end
						
						if (availableSeaRoutes > 0) or (bFreeRoute and ( CitiesForTrade[transferKey][selfKey].RouteType == SupplyRouteType.Coastal or CitiesForTrade[transferKey][selfKey].RouteType == SupplyRouteType.Ocean )) then
							self:UpdateCitiesConnection(transferCity, "Coastal", bInternalRoute, tradeRouteLevel)
						end
						
					--end
				end
					
				if CitiesForTrade[selfKey][transferKey] and CitiesForTrade[selfKey][transferKey].Efficiency > 0 then
					local routeType = CitiesForTrade[selfKey][transferKey].RouteType
					local bAbort 	= false
					if (routeType ~= SupplyRouteType.Trader) then

						-- check if the city can (still) maintain that route or update the number of route slots left
						-- a closer city may have replaced it, or an event may have removed some available route slots
						if not bFreeRoute then
							if routeType == SupplyRouteType.Road 	then
								if availableLandRoutes > 0 then
									availableLandRoutes = availableLandRoutes - 1
								else
									bAbort = true
								end
							end
							if routeType == SupplyRouteType.River 	then
								if availableRiverRoutes > 0 then
									availableRiverRoutes = availableRiverRoutes - 1
								else
									bAbort = true
								end
							end
							if routeType == SupplyRouteType.Coastal or routeType == SupplyRouteType.Ocean then
								if availableSeaRoutes > 0 then
									availableSeaRoutes = availableSeaRoutes - 1
								else
									bAbort = true
								end
							end
							
							if bAbort then
								-- that route is not valid anymore 
								CitiesForTrade[selfKey][transferKey] = nil
							else
								-- mark that this city is maintaining the route 
								CitiesForTrade[selfKey][transferKey].MaintainedRoute = true
							end
						end						
					end

					if not bAbort then
						local requirements 	= transferCity:GetRequirements(self) -- Get the resources required by transferCity and available in current city (self)...
						local efficiency	= CitiesForTrade[selfKey][transferKey].Efficiency

						for resourceID, value in pairs(requirements.Resources) do
							if value > 0 then
								CitiesTradeDemand[selfKey].Resources[resourceID] 		= ( CitiesTradeDemand[selfKey].Resources[resourceID] 		or 0 ) + GCO.Round(requirements.Resources[resourceID]*efficiency/100)
								CitiesTradeDemand[selfKey].NeedResources[resourceID] 	= ( CitiesTradeDemand[selfKey].NeedResources[resourceID] 	or 0 ) + 1
							end
						end
					end
				else
					CitiesOutOfReach[selfKey][transferKey] = currentTurn
				end
			end
		end
		if availableLandRoutes + availableRiverRoutes + availableSeaRoutes <= 0 then
			--break() -- we need to continue to iterate for the "free" routes 
		end
	end
	
	Dlog("UpdateExportCities "..name.." /END")
	GCO.ShowTimer("UpdateExportCities for ".. name)
end

function OnTradeRouteActivityChanged(routeOwnerID, originalOwnerID, originalCityID, destinationOwnerID, destinationCityID)

	local originalCity 			= GetCity(originalOwnerID, originalCityID)
	local destinationCity 		= GetCity(destinationOwnerID, destinationCityID)
	if originalCity and destinationCity then
		local originalKey 			= originalCity:GetKey()
		local destinationKey		= destinationCity:GetKey()	
		local tradeManager:table 	= GCO.GetTradeManager()
		local currentTurn 			= Game.GetCurrentGameTurn()
		
		if originalOwnerID ~= destinationOwnerID then -- Export route
		
			if not CitiesForTrade[originalKey] 		then CitiesForTrade[originalKey] = {} end
			if not CitiesForTrade[destinationKey] 	then CitiesForTrade[destinationKey] = {} end
		
			local tradeRouteLevel 	= TradeLevelType.Neutral
			local player 			= Players[originalOwnerID]
			local pDiploAI			= player:GetAi_Diplomacy()
			if pDiploAI then
				local bIsFriend			= (pDiploAI:GetDiplomaticState(ownerID) == "DIPLO_STATE_DECLARED_FRIEND") or (pDiploAI:GetDiplomaticState(ownerID) == "DIPLO_STATE_ALLIED")
				local bIsAllied			= (pDiploAI:GetDiplomaticState(ownerID) == "DIPLO_STATE_ALLIED")
				local bIsEmbargo		= (pDiploAI:GetDiplomaticState(ownerID) == "DIPLO_STATE_DENOUNCED")
				local playerConfig 		= PlayerConfigurations[iPlayer]
				
				if bIsFriend 	then tradeRouteLevel = TradeLevelType.Friend end
				if bIsAllied 	then tradeRouteLevel = TradeLevelType.Allied end
				if bIsEmbargo 	then tradeRouteLevel = TradeLevelType.Limited end
			end

			local tradeRoute = CitiesForTrade[originalKey][destinationKey]		
			if tradeRoute and tradeRoute.RouteType == SupplyRouteType.Trader then	-- remove old route
				CitiesForTrade[originalKey][destinationKey] = nil
			else 																	-- new trade route
				local pathPlots 							= tradeManager:GetTradeRoutePath(originalCity:GetOwner(), originalCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID() )
				CitiesForTrade[originalKey][destinationKey] = { RouteType = SupplyRouteType.Trader, Efficiency = 100, TradeRouteLevel = tradeRouteLevel, PathPlots = pathPlots, LastUpdate = currentTurn}
			end
			
			local tradeRoute = CitiesForTrade[destinationKey][originalKey]
			if tradeRoute and tradeRoute.RouteType == SupplyRouteType.Trader then	-- remove old route
				CitiesForTrade[destinationKey][originalKey] = nil
			else 																	-- new trade route		
				local pathPlots 							= tradeManager:GetTradeRoutePath(destinationCity:GetOwner(), destinationCity:GetID(), originalCity:GetOwner(), originalCity:GetID() )
				CitiesForTrade[destinationKey][originalKey] = { RouteType = SupplyRouteType.Trader, Efficiency = 100, TradeRouteLevel = tradeRouteLevel, PathPlots = pathPlots, LastUpdate = currentTurn}
			end
		else		-- Internal Route
		
			if not CitiesForTransfer[originalKey] 		then CitiesForTransfer[originalKey] = {} end
			if not CitiesForTransfer[destinationKey] 	then CitiesForTransfer[destinationKey] = {} end
			
			local tradeRoute = CitiesForTransfer[originalKey][destinationKey]		
			if tradeRoute and tradeRoute.RouteType == SupplyRouteType.Trader then	-- remove old route
				CitiesForTransfer[originalKey][destinationKey] = nil
			else 																	-- new trade route
				local pathPlots 								= tradeManager:GetTradeRoutePath(originalCity:GetOwner(), originalCity:GetID(), destinationCity:GetOwner(), destinationCity:GetID() )
				CitiesForTransfer[originalKey][destinationKey] 	= { RouteType = SupplyRouteType.Trader, Efficiency = 100, TradeRouteLevel = tradeRouteLevel, PathPlots = pathPlots, LastUpdate = currentTurn}
				if CitiesOutOfReach[originalKey] and CitiesOutOfReach[originalKey][destinationKey] then
					CitiesOutOfReach[originalKey][destinationKey] = nil
				end
			end
			
			local tradeRoute = CitiesForTransfer[destinationKey][originalKey]
			if tradeRoute and tradeRoute.RouteType == SupplyRouteType.Trader then	-- remove old route
				CitiesForTransfer[destinationKey][originalKey] = nil
			else 																	-- new trade route		
				local pathPlots 								= tradeManager:GetTradeRoutePath(destinationCity:GetOwner(), destinationCity:GetID(), originalCity:GetOwner(), originalCity:GetID() )
				CitiesForTransfer[destinationKey][originalKey] 	= { RouteType = SupplyRouteType.Trader, Efficiency = 100, TradeRouteLevel = tradeRouteLevel, PathPlots = pathPlots, LastUpdate = currentTurn}
				if CitiesOutOfReach[destinationKey] and CitiesOutOfReach[destinationKey][originalKey] then
					CitiesOutOfReach[destinationKey][originalKey] = nil
				end
			end
		end
	end
end
Events.TradeRouteActivityChanged.Add(OnTradeRouteActivityChanged)

function ExportToForeignCities(self)
	Dlog("ExportToForeignCities ".. Locale.Lookup(self:GetName()).." /START")
	
	local DEBUG_CITY_SCRIPT 	= DEBUG_CITY_SCRIPT
	--if Locale.Lookup(self:GetName()) =="Urumqi" then DEBUG_CITY_SCRIPT = "debug" end

	Dprint( DEBUG_CITY_SCRIPT, "Export to other Civilizations Cities for ".. Locale.Lookup(self:GetName()))

	local selfKey 			= self:GetKey()
	local supplyDemand 		= CitiesTradeDemand[selfKey]
	local transfers 		= {Resources = {}, ResPerCity = {}}
	local cityToSupply 		= CitiesForTrade[selfKey]
	local bExternalRoute 	= true

	table.sort(cityToSupply, function(a, b) return a.Efficiency > b.Efficiency; end)

	for resourceID, value in pairs(supplyDemand.Resources) do
		transfers.Resources[resourceID] = math.min(value, self:GetAvailableStockForExport(resourceID))
		transfers.ResPerCity[resourceID] = math.floor(Div(transfers.Resources[resourceID],supplyDemand.NeedResources[resourceID]))
		Dprint( DEBUG_CITY_SCRIPT, "- Required ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)) .." = ".. tostring(value), " for " , tostring(supplyDemand.NeedResources[resourceID]) ," cities, available = " .. tostring(self:GetAvailableStockForExport(resourceID))..", transfer = ".. tostring(transfers.Resources[resourceID]))
	end

	local importIncome = {}
	local exportIncome = 0
	for resourceID, value in pairs(transfers.Resources) do
		local resLeft = value
		local maxLoop = 5
		local loop = 0
		while (resLeft > 0 and loop < maxLoop) do
			for cityKey, data in pairs(cityToSupply) do
			
				-- we need to check trade route level here has this is not cached in the transfers.Resources table...
				local tradeRouteLevel = CitiesForTrade[selfKey][cityKey].TradeRouteLevel
				if resourceTradeLevel[tradeRouteLevel][resourceID] then
				
					local city		= GetCityFromKey(cityKey)
					if city then
					
						local reqValue 	= city:GetNumResourceNeeded(resourceID, bExternalRoute)
						Dprint( DEBUG_CITY_SCRIPT, " - Check route to ".. Indentation20(Locale.Lookup(city:GetName())) .." require = ".. tostring(value), " unit of " .. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)))

						if reqValue > 0 then
							local resourceClassType = GameInfo.Resources[resourceID].ResourceClassType
							local efficiency		= data.Efficiency
							local send 				= math.min(transfers.ResPerCity[resourceID], reqValue, resLeft)
							local localCost			= self:GetResourceCost(resourceID)
							local costPerUnit		= (localCost * self:GetTransportCostTo(city)) + localCost

							if costPerUnit < city:GetResourceCost(resourceID) or city:GetStock(resourceID) == 0 then -- this city may be in cityToSupply list for another resource, so check cost and stock here again before sending the resource... to do : track value per city
								local transactionIncome = send * self:GetResourceCost(resourceID) -- * costPerUnit
								resLeft = resLeft - send
								city:ChangeStock(resourceID, send, ResourceUseType.Import, selfKey, costPerUnit)
								self:ChangeStock(resourceID, -send, ResourceUseType.Export, cityKey)
								importIncome[cityKey] 	= (importIncome[cityKey] or 0) + transactionIncome
								exportIncome 			= exportIncome + transactionIncome
								Dprint( DEBUG_CITY_SCRIPT, "   - Generating ", transactionIncome, " golds for ", send, " ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)) .." (".. tostring(efficiency) .." percent efficiency) send to ".. Locale.Lookup(city:GetName()))
							end
						end
					end
				else
					Dprint( DEBUG_CITY_SCRIPT, "   - Not allowed to trade ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)) .." at tradeRouteLevel".. tostring(tradeRouteLevel))
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
		local player = GCO.GetPlayer(self:GetOwner())
		player:ProceedTransaction(AccountType.ExportTaxes, exportIncome)
		--Players[self:GetOwner()]:GetTreasury():ChangeGoldBalance(exportIncome)
	end

	for cityKey, income in pairs(importIncome) do
		income = GCO.ToDecimals(income * IncomeImportPercent / 100)
		if income > 0 then
			local city = GetCityFromKey(cityKey)
			if city then
				Dprint( DEBUG_CITY_SCRIPT, "Total gold from Import income = " .. income .." gold for ".. Locale.Lookup(city:GetName()))
				local sText = Locale.Lookup("LOC_GOLD_FROM_IMPORT", income)
				if Game.GetLocalPlayer() == city:GetOwner() then Game.AddWorldViewText(EventSubTypes.PLOT, sText, city:GetX(), city:GetY(), 0) end
				
				local player = GCO.GetPlayer(city:GetOwner())
				player:ProceedTransaction(AccountType.ImportTaxes, income)
				--Players[city:GetOwner()]:GetTreasury():ChangeGoldBalance(income)
			end
		end
	end
	Dlog("ExportToForeignCities "..Locale.Lookup(self:GetName()).." /END")
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
	--local DEBUG_CITY_SCRIPT 	= "debug" --"CityScript"
	
	local DEBUG_CITY_SCRIPT 	= DEBUG_CITY_SCRIPT
	--if Locale.Lookup(self:GetName()) =="Luzhou" and Locale.Lookup(fromCity:GetName()) =="Urumqi" then DEBUG_CITY_SCRIPT = "debug" end
	
	local selfKey 				= self:GetKey()
	local player 				= GCO.GetPlayer(self:GetOwner())
	local fromplayerID			= fromCity:GetOwner()
	local fromName				= Locale.Lookup(fromCity:GetName())
	local fromKey				= fromCity:GetKey()
	local cityName	 			= Locale.Lookup(self:GetName())
	local bExternalRoute 		= (self:GetOwner() ~= fromplayerID)
	local requirements 			= {}
	requirements.Resources 		= {}
	requirements.HasPrecedence 	= {}	
		
	local tradeRouteLevel 
	if bExternalRoute then
		tradeRouteLevel = CitiesForTrade[fromKey][selfKey].TradeRouteLevel -- we're checking the route from the city
	else
		tradeRouteLevel = TradeLevelType.Allied
	end

	Dprint( DEBUG_CITY_SCRIPT, "GetRequirements for ".. cityName .. " from " .. fromName .. GCO.Separator)

	for row in GameInfo.Resources() do
		local resourceID 			= row.Index
		
		Dprint( DEBUG_CITY_SCRIPT, Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)) .. Indentation20("... strategic").. tostring(row.ResourceClassType == "RESOURCECLASS_STRATEGIC"))
		Dprint( DEBUG_CITY_SCRIPT, Indentation20("...") .. Indentation20("... equipment") .. tostring( GCO.IsResourceEquipment(resourceID)))
		
		if resourceTradeLevel[tradeRouteLevel][resourceID] then
		
			local bCanRequest 			= false
			local bCanTradeResource 	= (not((row.NoExport and bExternalRoute) or (row.NoTransfer and (not bExternalRoute))))
			Dprint( DEBUG_CITY_SCRIPT, Indentation20("...") .. Indentation20("... can trade") .. tostring(bCanTradeResource),", no export = ",row.NoExport," external route = ",bExternalRoute,", no transfer = ",row.NoTransfer,", internal route = ",(not bExternalRoute))
			if bCanTradeResource and not player:IsObsoleteResource(resourceID) then -- player:IsResourceVisible(resourceID) and -- Allow trading (but not collection or production) of unresearched resources, do not ask for obsolete resource
				local numResourceNeeded = self:GetNumResourceNeeded(resourceID, bExternalRoute)
				if numResourceNeeded > 0 then
					local bPriorityRequest	= false
					if fromCity then -- function was called to only request resources available in "fromCity" --<-- note : we have to rewrite the function if we want that behavior, cause it will crash if fromCity is nil !
						local efficiency 	= fromCity:GetRouteEfficiencyTo(self)
						local transportCost = fromCity:GetTransportCostTo(self)
						local bHasStock		= fromCity:GetStock(resourceID) > 0
						if bHasStock then
							Dprint( DEBUG_CITY_SCRIPT, Indentation20("...") .. Indentation20("... has stock").. Locale.Lookup(GameInfo.Resources[resourceID].Name), " efficiency", efficiency, " "..fromName.." stock", fromCity:GetStock(resourceID) ," "..cityName.." stock", self:GetStock(resourceID) ," "..fromName.." cost", fromCity:GetResourceCost(resourceID)," transport cost", fromCity:GetResourceCost(resourceID) * transportCost, " "..cityName.." cost", self:GetResourceCost(resourceID))
						else
							Dprint( DEBUG_CITY_SCRIPT, Indentation20("...") .. "... no stock")
						end
						local bHasMoreStock 	= true -- (fromCity:GetStock(resourceID) > self:GetStock(resourceID)) --< must find another check, this one doesn't allow small city at full stock to transfer to big city at low stock (but still higher than small city max stock) use percentage stock instead ?
						local fromCost			= fromCity:GetResourceCost(resourceID)
						local bIsLowerCost 		= ((fromCost * transportCost) + fromCost < self:GetResourceCost(resourceID))
						bPriorityRequest		= false

						if UnitsSupplyDemand[selfKey] and UnitsSupplyDemand[selfKey].Resources[resourceID] and resourceID ~= foodResourceID then -- Units have required this resource...
							numResourceNeeded	= math.min(self:GetMaxStock(resourceID), numResourceNeeded + UnitsSupplyDemand[selfKey].Resources[resourceID])
							bPriorityRequest	= true
						end
						
						local numRequiredInQueue = self:GetNumRequiredInQueue(resourceID)
						if numRequiredInQueue > 0 then -- an Item in build queue is requiring this resource...
							numResourceNeeded	= math.min(self:GetMaxStock(resourceID), numResourceNeeded + numRequiredInQueue)
							bPriorityRequest	= true
						end

						if bHasStock and bHasMoreStock and (bIsLowerCost or bPriorityRequest or self:GetStock(resourceID) == 0) then
							bCanRequest = true
						else
							Dprint( DEBUG_CITY_SCRIPT, Indentation20("...") .. Indentation20("... bCanRequest").. tostring(bCanRequest), ", (bOtherHasStock ["..tostring(bHasStock).."] and bHasMoreStock["..tostring(bHasMoreStock).."] and (bIsLowerCost["..tostring(bIsLowerCost).."] or bPriorityRequest["..tostring(bPriorityRequest).."] or bSelfHasNoStock["..tostring(self:GetStock(resourceID) == 0).."])")
						end
					else
						bCanRequest = true
					end
					if bCanRequest then
						requirements.Resources[resourceID] 		= numResourceNeeded
						requirements.HasPrecedence[resourceID] 	= bPriorityRequest
						Dprint( DEBUG_CITY_SCRIPT, Indentation20("...") .. Indentation20("... Required ").. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." = ".. tostring(requirements.Resources[resourceID])..", Priority = "..tostring(bPriorityRequest))
					end
				else
					Dprint( DEBUG_CITY_SCRIPT, Indentation20("...") .. "... No demand")
				end
			else
				Dprint( DEBUG_CITY_SCRIPT, Indentation20("...") .. "... Can't trade or obsolete")
			end
		else
			Dprint( DEBUG_CITY_SCRIPT, Indentation20("...") .. "... Insufficient tradeRouteLevel at " .. tostring( tradeRouteLevel))
		end
	end

	return requirements
end


-----------------------------------------------------------------------------------------
-- Resources Stock
-----------------------------------------------------------------------------------------

function GetSizeStockRatio(self)
	return self:GetSize() * PerSizeStockRatio
end

function GetAvailableStockForUnits(self, resourceID)

	local turnKey 		= GCO.GetPreviousTurnKey()
	local supply		= self:GetSupplyAtTurn(resourceID, turnKey)
	local sharedSupply	= GCO.Round(supply / 4)
	local minStockLeft 	= self:GetMinimalStockForUnits(resourceID)--GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
	local stock			= self:GetStock(resourceID)
	return math.min(stock, math.max(0, stock-minStockLeft, sharedSupply))
end

function GetAvailableStockForCities(self, resourceID)
	local turnKey 			= GCO.GetPreviousTurnKey()
	local minPercentLeft 	= MinPercentLeftToTransfer
	if ResourceUsage[resourceID] then
		minPercentLeft = ResourceUsage[resourceID].MinPercentLeftToTransfer
	end
	local supply		= self:GetSupplyAtTurn(resourceID, turnKey)
	local sharedSupply	= GCO.Round(supply / 4)
	local minStockLeft 	= GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
	local stock			= self:GetStock(resourceID)
	return math.min(stock, math.max(0, stock-minStockLeft, sharedSupply))
end

function GetAvailableStockForIndustries(self, resourceID)
	local turnKey 			= GCO.GetPreviousTurnKey()
	local minPercentLeft = MinPercentLeftToConvert
	if ResourceUsage[resourceID] then
		minPercentLeft = ResourceUsage[resourceID].MinPercentLeftToConvert
	end
	local supply		= self:GetSupplyAtTurn(resourceID, turnKey)
	local sharedSupply	= GCO.Round(supply / 2)
	local minStockLeft = GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
	local stock			= self:GetStock(resourceID)
	return math.min(stock, math.max(0, stock-minStockLeft, sharedSupply))
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

	local DEBUG_CITY_SCRIPT = DEBUG_CITY_SCRIPT
	--if Locale.Lookup(self:GetName()) =="Kyoto" and Locale.Lookup(GameInfo.Resources[resourceID].Name) =="Materiel" then DEBUG_CITY_SCRIPT = "debug" end
	
	if not resourceID then
		GCO.Warning("resourceID is nil or false in ChangeStock for "..Locale.Lookup(self:GetName()), " resourceID = ", resourceID," value= ", value)
		return
	end

	if value == 0 then return end

	value = GCO.ToDecimals(value)

	local resourceKey 	= tostring(resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	local cityData 		= ExposedMembers.CityData[cityKey]


	if not reference then reference = NO_REFERENCE_KEY end
	reference = tostring(reference) -- will be a key in table

	if value > 0 and resourceKey ~= personnelResourceKey then
		if not useType then useType = ResourceUseType.OtherIn end
		if not unitCost then unitCost = GCO.GetBaseResourceCost(resourceID) end
		local maxStock		= self:GetMaxStock(resourceID)
		local actualStock	= math.min(self:GetStock(resourceID), maxStock) -- To prevent virtualValue to be negative when the actualStock is > maxStock
		local actualCost	= self:GetResourceCost(resourceID)
		local surplus		= math.max(0, (actualStock + value) - maxStock)
		local virtualStock 	= math.max(actualStock, (math.ceil(maxStock/2)))
		local virtualValue 	= value - surplus
		local divisor		= virtualValue + virtualStock
		local newCost 		= divisor > 0 and GCO.ToDecimals(Div((virtualValue*unitCost + virtualStock*actualCost ), divisor)) or unitCost

		Dprint( DEBUG_CITY_SCRIPT, "newCost = (virtualValue[".. tostring(virtualValue) .."] * unitCost["..tostring(unitCost).."] + virtualStock["..tostring(virtualStock).."]*actualCost["..tostring(actualCost).."] ) / (virtualValue["..tostring(virtualValue).."] + virtualStock["..tostring(virtualStock).."])")

		local surplusStr 	= ""
		local halfStockStr	= ""

		newCost = math.min(newCost, self:GetMaximumResourceCost(resourceID))
		newCost = math.max(newCost, self:GetMinimumResourceCost(resourceID))
		
		--[[
		local variation = math.min(actualCost * varPercent / 100, (actualCost - minCost) / 2)
		newCost = math.max(minCost, math.min(maxCost, actualCost - variation))
		--]]

		if surplus > 0 then surplusStr 	= "(surplus of "..tostring(surplus).." not affecting price)" end
		if virtualStock > actualStock then halfStockStr 	= " (using virtual half stock of "..tostring(virtualStock).." for calculation) " end

		Dprint( DEBUG_CITY_SCRIPT, "Update Unit Cost of ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)) .." to "..tostring(newCost), " cost/unit, added "..tostring(value), " unit(s) at "..tostring(unitCost), " cost/unit "..surplusStr.." to stock of ".. tostring(actualStock), " unit(s) at ".. tostring(actualCost), " cost/unit " .. halfStockStr)
		self:SetResourceCost(resourceID, newCost)
	else
		if not useType then useType = ResourceUseType.OtherOut  end
	end

	-- Update stock
	if not ExposedMembers.CityData[cityKey].Stock[turnKey][resourceKey] then
		if value < 0 then
			GCO.Error("Trying to set a negative value to ".. Locale.Lookup(GameInfo.Resources[tonumber(resourceID)].Name) .." stock, value = "..tostring(value))
		end
		ExposedMembers.CityData[cityKey].Stock[turnKey][resourceKey] = math.max(0 , value)
	else
		local newStock = GCO.ToDecimals(cityData.Stock[turnKey][resourceKey] + value)
		if newStock < -1 then -- allow a rounding error of 1
			GCO.Error("Trying to set a negative value to ".. Locale.Lookup(GameInfo.Resources[tonumber(resourceID)].Name) .." stock, previous stock = ".. tostring(cityData.Stock[turnKey][resourceKey])..", variation value = "..tostring(value))
		end
		ExposedMembers.CityData[cityKey].Stock[turnKey][resourceKey] = math.max(0 , newStock)
	end

	-- update stats
	if not ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey] then
		ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey] = { [useType] = {[reference] = math.abs(value)}}

	elseif not ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType] then
		ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType] = {[reference] = math.abs(value)}

	elseif not ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType][reference] then
		ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType][reference] = math.abs(value)

	else
		ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType][reference] = GCO.ToDecimals(ExposedMembers.CityData[cityKey].ResourceUse[turnKey][resourceKey][useType][reference] + math.abs(value))
	end
end

function ChangeBuildingQueueStock(self, resourceID, currentlyBuilding, value)

	if not resourceID then
		GCO.Warning("resourceID is nil or false in ChangeBuildingQueueStock for "..Locale.Lookup(self:GetName()), " resourceID = ", resourceID," value= ", value)
		return
	end

	if value == 0 then return end

	local resourceKey 	= tostring(resourceID)
	local cityKey 		= self:GetKey()
	local cityData 		= ExposedMembers.CityData[cityKey]

	-- Update stock
	if not ExposedMembers.CityData[cityKey].BuildQueue[currentlyBuilding] then
		ExposedMembers.CityData[cityKey].BuildQueue[currentlyBuilding] = { [resourceKey] = math.max(0 , GCO.ToDecimals(value)) }
	else
		ExposedMembers.CityData[cityKey].BuildQueue[currentlyBuilding][resourceKey] = math.max(0 , GCO.ToDecimals((cityData.BuildQueue[currentlyBuilding][resourceKey] or 0) + value)) -- try to prevent rounding error on addition, which in turn seems to lead to corrupted tables when saving data.
	end
end

function GetBuildingQueueStock(self, resourceID, currentlyBuilding)
	local cityKey 		= self:GetKey()
	local cityData 		= ExposedMembers.CityData[cityKey]
	local resourceKey	= tostring(resourceID)
	if not cityData then return 0 end -- could happen on city initialization or after capture ? 
	if cityData.BuildQueue[currentlyBuilding] then
		return cityData.BuildQueue[currentlyBuilding][resourceKey] or 0
	end
	return 0
end

function GetBuildingQueueAllStock(self, currentlyBuilding)
	local cityKey 	= self:GetKey()
	local cityData 	= ExposedMembers.CityData[cityKey]
	if not cityData then return {} end -- could happen on city initialization or after capture ? 
	return cityData.BuildQueue[currentlyBuilding] or {}
end

function ClearBuildingQueueStock(self, finishedBuilding)
	local cityKey 		= self:GetKey()
	ExposedMembers.CityData[cityKey].BuildQueue[finishedBuilding] = nil
end

function GetNumRequiredInQueue(self, resourceID)

	--local DEBUG_CITY_SCRIPT = "CityScript"
	
	local cityKey 		= self:GetKey()
	local cityData 		= ExposedMembers.CityData[cityKey]
	local resourceKey	= tostring(resourceID)
	local player		= GCO.GetPlayer(self:GetOwner())
	
	local organizationLevel = player:GetMilitaryOrganizationLevel()
	
	for itemBuild, data in pairs(cityData.BuildQueue) do
		if data[resourceKey] then
			if GameInfo.Units[itemBuild] then
				local unitID		= GameInfo.Units[itemBuild].Index
				local resTable 		= GCO.GetUnitConstructionResources(unitID, organizationLevel)
				local resOrTable 	= GCO.GetUnitConstructionOrResources(unitID, organizationLevel)
				local resNeeded		= 0
				if resTable[resourceKey] then
					resNeeded = resNeeded + math.max(0, resTable[resourceID] - data[resourceKey])
				end
				for equipmentClass, resourceTable in pairs(resOrTable) do
					local totalNeeded 		= resourceTable.Value
					local alreadyStocked 	= 0
					local bInResOrTable		= false
					-- get the number of resource already stocked for that class...
					for _, neededResourceID in ipairs(resourceTable.Resources) do -- loop through the possible resources (ordered by desirability) for that class
						if neededResourceID == resourceID then bInResOrTable = true end
						alreadyStocked = alreadyStocked + self:GetBuildingQueueStock(neededResourceID, itemBuild)
					end
					if bInResOrTable then
						resNeeded = resNeeded + math.max(0, totalNeeded - alreadyStocked)
					end				
				end
				Dprint( DEBUG_CITY_SCRIPT, " - Required by item in build queue for ".. tostring(itemBuild) .." in ".. self:GetName() .." : ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." = ".. tostring(resNeeded) .. " already stocked = " .. tostring(data[resourceKey]))
				
				cityData.BuildQueue.__orderedIndex = nil  -- manual cleanup for orderedpair
				return resNeeded
			else -- to do: other item types ?
			
				cityData.BuildQueue.__orderedIndex = nil  -- manual cleanup for orderedpair
				return 0
			end
		end
	end
	return 0
end

function GetMaxStock(self, resourceID)

	local maxStock 	= 0
	local sizeRatio	= self:GetSizeStockRatio()
	local classType	= GameInfo.Resources[resourceID].ResourceClassType

	-- special case for Knowledge (scholars)
	if classType == "RESOURCECLASS_KNOWLEDGE" then
		return GCO.Round(sizeRatio * KnowledgePerSize * self:GetLiteracy() / 100)
	end
	
	-- special case for Food
	if resourceID == foodResourceID then
		local normalRatio = 1
		return self:GetFoodConsumption(normalRatio) * FoodStockPerConsumption
	end
	
	if not GameInfo.Resources[resourceID].SpecialStock then -- Some resources are stocked in specific buildings only
		maxStock = sizeRatio * ResourceStockPerSize
		if resourceID == personnelResourceID 	then maxStock = GCO.Round(sizeRatio * PersonnelPerSize) end
		--if resourceID == foodResourceID 		then maxStock = GCO.Round(sizeRatio * FoodStockPerSize) + baseFoodStock end
		if GCO.IsResourceEquipment(resourceID) 	then maxStock = self:GetMaxEquipmentStock(resourceID) end	-- Equipment stock does not depend of city size, just buildings
		if GCO.IsResourceLuxury(resourceID) 	then maxStock = GCO.Round(maxStock * LuxuryStockRatio) end
	end
	if ResourceStockage[resourceID] then
		for _, buildingID in ipairs(ResourceStockage[resourceID]) do
			if self:GetBuildings():HasBuilding(buildingID) then
				if FixedBuildingStock[buildingID][resourceID] then
					maxStock = maxStock + BuildingStock[buildingID][resourceID]
				else
					maxStock = maxStock + GCO.Round(BuildingStock[buildingID][resourceID] * sizeRatio )
				end
			end
		end
	end
	
	if ResourceStockage[classType] then
		for _, buildingID in ipairs(ResourceStockage[classType]) do
			if self:GetBuildings():HasBuilding(buildingID) then
				if FixedBuildingStock[buildingID][classType] then
					maxStock = maxStock + BuildingStock[buildingID][classType]
				else
					maxStock = maxStock + GCO.Round(BuildingStock[buildingID][classType] * sizeRatio )
				end
			end
		end
	end
	return maxStock
end

function GetStock(self, resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	local resourceKey 	= tostring(resourceID)
	if not ExposedMembers.CityData[cityKey] or not ExposedMembers.CityData[cityKey].Stock[turnKey] then return 0 end -- this can happen during city capture ?
	return ExposedMembers.CityData[cityKey].Stock[turnKey][resourceKey] or 0
end

function GetResources(self)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	if not ExposedMembers.CityData[cityKey] or not ExposedMembers.CityData[cityKey].Stock[turnKey] then return {} end -- this can happen during city capture ?
	return ExposedMembers.CityData[cityKey].Stock[turnKey] or {}
end

function GetEquipmentList(self)
	local DEBUG_CITY_SCRIPT		= DEBUG_CITY_SCRIPT
	--if Game.GetLocalPlayer() 	== self:GetOwner() then DEBUG_CITY_SCRIPT = "debug" end
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Get Equipment list for "..Locale.Lookup(self:GetName()))
	local equipmentList	= {}
	for resourceKey, value in pairs(self:GetResources()) do
		local resourceID = tonumber(resourceKey)
		if GCO.IsResourceEquipment(resourceID) then
			equipmentList[resourceID] = value
			Dprint( DEBUG_CITY_SCRIPT, "  - adding " .. tostring(value) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." to list")
		end
	end
	return equipmentList
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
	return GCO.ToDecimals(self:GetStock(resourceID) - self:GetPreviousStock(resourceID))
end


-----------------------------------------------------------------------------------------
-- Equipment functions
-----------------------------------------------------------------------------------------
function GetMaxEquipmentStorage(self)
	local storage = EquipmentBaseStock
	for buildingID, value in pairs(EquipmentStockage) do
		if self:GetBuildings():HasBuilding(buildingID) then
			storage = storage + value
		end
	end
	return storage
end

function GetMaxEquipmentStock(self, equipmentID)
	local equipmentType = GameInfo.Resources[equipmentID].ResourceType
	local equipmentSize = GameInfo.Equipment[equipmentType].Size
	return math.floor(Div(self:GetMaxEquipmentStorage(), equipmentSize))
end

function GetEquipmentStorageLeft(self, equipmentID)
	local equipmentType = GameInfo.Resources[equipmentID].ResourceType
	local equipmentSize = GameInfo.Equipment[equipmentType].Size
	return math.max(0, self:GetMaxEquipmentStorage() - (self:GetStock(equipmentID)*equipmentSize))
end


-----------------------------------------------------------------------------------------
-- Resources Cost
-----------------------------------------------------------------------------------------
function GetMinimumResourceCost(self, resourceID)
	return GCO.GetBaseResourceCost(resourceID) * MinCostFromBaseFactor -- MinCostFromBaseFactor < 1
end

function GetMaximumResourceCost(self, resourceID)
	return GCO.GetBaseResourceCost(resourceID) * MaxCostFromBaseFactor -- MaxCostFromBaseFactor > 1
end

function GetResourceCost(self, resourceID)
	if resourceID == personnelResourceID then return 0 end
	local cityData 		= self:GetData()
	local baseCost		= GCO.GetBaseResourceCost(resourceID)
	local turnKey 		= GCO.GetTurnKey()
	if not cityData or not cityData.Stock[turnKey] then return baseCost end -- this can happen during city capture ?
	local resourceKey 	= tostring(resourceID)
	local resourceCost	= (cityData.ResourceCost[turnKey][resourceKey] or baseCost)
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
	return GCO.ToDecimals(self:GetResourceCost(resourceID) - self:GetPreviousResourceCost(resourceID))
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

function GetSupply(self, resourceID)
	return self:GetSupplyAtTurn(resourceID, GCO.GetPreviousTurnKey())
end

function GetSupplyAtTurn(self, resourceID, turn, iteration)
	local resourceKey 	= tostring(resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= tostring(turn)
	local turn			= tonumber(turn)
	local cityData 		= ExposedMembers.CityData[cityKey]
	if not cityData then return 0 end -- why do we need this ?
	if cityData.ResourceUse[turnKey] then
		local useData = cityData.ResourceUse[turnKey][resourceKey]
		if useData then

			local supply = 0

			supply = supply + GCO.TableSummation(useData[ResourceUseType.Collect])
			supply = supply + GCO.TableSummation(useData[ResourceUseType.Product])
			supply = supply + GCO.TableSummation(useData[ResourceUseType.Import])
			supply = supply + GCO.TableSummation(useData[ResourceUseType.TransferIn])
			supply = supply + GCO.TableSummation(useData[ResourceUseType.Pillage])
			supply = supply + GCO.TableSummation(useData[ResourceUseType.Recruit])
			--supply = supply + ( useData[ResourceUseType.OtherIn] 	or 0)

			return supply
		end
	elseif self:TurnCreated() < turn then
		GCO.Error(Locale.Lookup(self:GetName()).." created at turn ".. self:TurnCreated() .." has no cityData.ResourceUse[turnKey] for GetSupplyAtTurn#", turnKey, "resourceID #", resourceID)
		if not iteration or (iteration and iteration < 3) then
			local iteration = (iteration or 0) + 1
			local prevTurn	= math.max(0, turn - 1)
			return self:GetSupplyAtTurn(resourceID, prevTurn, iteration)
		else
			return 0
		end
	end
	return 0
end

function GetAverageSupplyAtTurn(self, resourceID, numTurn)

	local supply 	= 0
	local numTurn	= numTurn or 5
	supply = supply + self:GetAverageUseTypeOnTurns(resourceID, ResourceUseType.Collect, numTurn)
	supply = supply + self:GetAverageUseTypeOnTurns(resourceID, ResourceUseType.Product, numTurn)
	supply = supply + self:GetAverageUseTypeOnTurns(resourceID, ResourceUseType.Import, numTurn)
	supply = supply + self:GetAverageUseTypeOnTurns(resourceID, ResourceUseType.TransferIn, numTurn)
	supply = supply + self:GetAverageUseTypeOnTurns(resourceID, ResourceUseType.Pillage, numTurn)
	supply = supply + self:GetAverageUseTypeOnTurns(resourceID, ResourceUseType.Recruit, numTurn)
	--supply = supply + ( useData[ResourceUseType.OtherIn] 	or 0)

	return supply
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
	local turn			= turn or GCO.GetPreviousTurnKey()
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
		return GCO.Round(Div(total,loop))
	end
	return 0
end

function GetResourceUseToolTipStringForTurn(self, resourceID, useTypeKey, turn)

	--local DEBUG_CITY_SCRIPT = false

	local resourceKey 	= tostring(resourceID)
	local selfKey 		= self:GetKey()
	local turnKey 		= tostring(turn)
	local cityData 		= ExposedMembers.CityData[selfKey]
	local selfName		= Locale.Lookup(self:GetName())
	local bNotUnitUse	= (ResourceUseTypeReference[useTypeKey] ~= ReferenceType.Unit)

	local MakeString	= function(key, value) return Indentation20(key) .. tostring(value) end

	function SelfString(value)
		return Indentation20(selfName) .. tostring(value)
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
			return tostring(name) .. " = " .. tostring(value)
		end
	elseif ResourceUseTypeReference[useTypeKey] == ReferenceType.City then
		MakeString	= function(key, value)
			local city 	= GetCityFromKey ( key )
			local name	= "a city"
			if city then name = Locale.Lookup(city:GetName()) end
			return Indentation20(name) .. tostring(value)
		end
	elseif ResourceUseTypeReference[useTypeKey] == ReferenceType.Unit then
		MakeString	= function(key, value)
			local unit 	= GCO.GetUnitFromKey ( key )
			if unit then
				local name	= Locale.Lookup(unit:GetName())
				return Indentation20(name) .. tostring(value)
			else
				return Indentation20("an unit") .. tostring(value)
			end
		end
	elseif ResourceUseTypeReference[useTypeKey] == ReferenceType.Population then
		MakeString	= function(key, value)
			local name	= Locale.Lookup(GameInfo.Populations[key].Name)
			return Indentation20(name) .. tostring(value)
		end
	elseif ResourceUseTypeReference[useTypeKey] == ReferenceType.Building then
		MakeString	= function(key, value)
			local buildingID 	= tonumber ( key )
			local name			= Locale.Lookup(GameInfo.Buildings[buildingID].Name)
			return Indentation20(name) .. tostring(value)
		end
	elseif ResourceUseTypeReference[useTypeKey] == ReferenceType.PopOrBuilding then
		MakeString	= function(key, value)
			local name = "unknown"
			if string.find(key, ",") then -- this is a city or unit key
				local city 	= GetCityFromKey ( key )
				if city then name = Locale.Lookup(city:GetName()) end
			elseif string.len(key) > 5 then -- this lenght means Population type string
				name	= Locale.Lookup(GameInfo.Populations[key].Name)
			else -- buildingKey
				local buildingID 	= tonumber ( key )
				name				= Locale.Lookup(GameInfo.Buildings[buildingID].Name)
			end
			return Indentation20(name) .. tostring(value)
		end
	end

	local str = ""
	if cityData.ResourceUse[turnKey] then
		local useData = cityData.ResourceUse[turnKey][resourceKey]
		if useData and useData[useTypeKey] then
			for key, value in pairs(useData[useTypeKey]) do
			Dprint( DEBUG_CITY_SCRIPT, key, value)
				if (key == selfKey and bNotUnitUse) or key == NO_REFERENCE_KEY then
					str = str..SelfString(value).."[NEWLINE]"
				else
					str = str..MakeString(key, value).."[NEWLINE]"
				end
			end
		end
	end

	Dprint( DEBUG_CITY_SCRIPT, str)
	Dprint( DEBUG_CITY_SCRIPT, "----------")
	return str
end


-----------------------------------------------------------------------------------------
-- Administrative Functions
-----------------------------------------------------------------------------------------
function GetAdministrativeEfficiency(self)
	local minAdminEfficiency = 25 -- to do : tech, gov, policies
	return math.max(self:GetValue("AdministrativeEfficiency") or 100, minAdminEfficiency)
end

function SetAdministrativeEfficiency(self, value) -- set when processing administrative resource use
	self:SetValue("AdministrativeEfficiency", GCO.ToDecimals(value))
end

function GetAdministrativeSupport(self)
	return self:GetValue("AdministrativeSupport") or self:SetAdministrativeSupport()
end

function SetAdministrativeSupport(self) -- set when processing administrative resource use

	local minPercent			= minAdmSupportPercent -- to do : change with policies
	local AdministrativeSupport = {}
	local adminResources		= 0
		
	for resourceKey, value in pairs(self:GetResources()) do
		local resourceID	= tonumber(resourceKey)
		local adminValue	= GCO.GetAdministrativeResourceValue(resourceID)
		if adminValue then
			local reserved	= math.floor(self:GetMaxStock(resourceID)*minPercent/100)
			local available = (value > reserved and value - reserved) or 0
			if available > 0 then
				adminResources	= adminResources + (available*adminValue)
			end
		end
	end
	
	AdministrativeSupport.Resources	= adminResources
	AdministrativeSupport.Yield		= self:GetCustomYield(YieldAdministrationID)
	
	self:SetValue("AdministrativeSupport", AdministrativeSupport)
	return AdministrativeSupport
end

function GetAdministrativeCost(self)
	return self:GetValue("AdministrativeCost") or self:SetAdministrativeCost()
end

function SetAdministrativeCost(self) -- update each turn
	local adminCost			= 0
	local techFactor 		= self:GetTechAdministrativeFactor()
	local buildingsFactor	= self:GetBuildingsAdministrativeFactor()
	local popCost			= self:GetpopulationAdministrativeCost()
	local landCost			= self:GetTerritoryAdministrativeCost()
	
	local adminCost	= math.floor((popCost + landCost)*techFactor*buildingsFactor)
	
	self:SetValue("AdministrativeCost", adminCost)
	return adminCost
end

function GetTechAdministrativeFactor(self)
	local player	 = GCO.GetPlayer(self:GetOwner())
	local techFactor = player:GetTechAdministrativeFactor()
	return math.max(1, techFactor / 4)
end

function GetBuildingsAdministrativeFactor(self)
	local numBuildings	= 0
	local pBuildings	= self:GetBuildings()
	local kCityPlots	= GCO.GetCityPlots(self)
	if (kCityPlots ~= nil) then
		for _,plotID in pairs(kCityPlots) do
			local kTypes	= GCO.GetBuildingsAtLocation(self, plotID)
			for _, buildingType in ipairs(kTypes) do
				local row	= GameInfo.Buildings[buildingType]
				if not row.NoCityScreen then
					numBuildings	= numBuildings + 1
				end
			end
		end
	end
	return 1+(numBuildings/4), numBuildings
end

function GetTerritoryAdministrativeCost(self)
	local kPlots	= GCO.GetCityPlots(self)
	local territory	= #kPlots
	local surface	= territory*10000
	return math.floor(territory / 2), surface
end

function GetpopulationAdministrativeCost(self)
	local population	= self:GetTotalPopulation()
	local popSize		= math.floor(GCO.GetSizeAtPopulation(population))
	return popSize, population
end


-----------------------------------------------------------------------------------------
-- Sea Exploitation function
-----------------------------------------------------------------------------------------
function GetSeaRange(self)
	if not self:IsCoastal() then return 0 end -- to do: harbor
	
	return self:GetModifiersForEffect("RAISE_CITY_SEA_RANGE")
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
			rowTable.Stock 			= GCO.Round(value)

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

		local Collect 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Collect, turnKey))
		local Product 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Product, turnKey))
		local Import 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Import, previousTurnKey)) -- all other players cities have not exported their resource at the beginning of the player turn, so get previous turn value
		local TransferIn 	= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.TransferIn, turnKey))
		local Pillage 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Pillage, turnKey))
		local OtherIn 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.OtherIn, turnKey))

		if resourceID == personnelResourceID then Product = GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Recruit, turnKey)) end

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
				if resourceID == personnelResourceID then rowTable.ProductToolTip	= Locale.Lookup("LOC_HUD_CITY_RESOURCES_PRODUCT_DETAILS_TOOLTIP", toolTipHeader) .. separator .. self:GetResourceUseToolTipStringForTurn(resourceID, ResourceUseType.Recruit, turnKey) end
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

		local Consume 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Consume, turnKey))
		local Export 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Export, turnKey))
		local TransferOut 	= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.TransferOut, turnKey))
		local Supply 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Supply, turnKey))
		local Stolen 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Stolen, previousTurnKey)) -- all other players units have not attacked yet at the beginning of the player turn, so get previous turn value
		local OtherOut 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.OtherOut, turnKey))
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
		local city				= GetCityFromKey(routeCityKey)
		if city then
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
	end

	table.sort(citiesTable, function(a, b) return a.Efficiency > b.Efficiency; end)
	return citiesTable
end

function GetTransferCitiesTable(self)
	local data 			= self:GetTransferCities()
	local citiesTable	= {}
	if not data then return {} end
	for routeCityKey, routeData in pairs(data) do

		local rowTable 			= {}
		local city				= GetCityFromKey(routeCityKey)
		if city then
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
	end

	table.sort(citiesTable, function(a, b) return a.Efficiency > b.Efficiency; end)
	return citiesTable
end

function GetSupplyLinesTable(self)
	local cityKey 		= self:GetKey()
	local linkedUnits	= self:GetLinkedUnits() or {}
	local unitsTable	= {}
	if not LinkedUnits[cityKey] then return {} end

	for unitKey, data in pairs(linkedUnits) do

		local unit = GCO.GetUnitFromKey ( unitKey )
		if unit then
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
	end

	table.sort(unitsTable, function(a, b) return a.Efficiency > b.Efficiency; end)
	return unitsTable
end


-----------------------------------------------------------------------------------------
-- Personnel functions
-----------------------------------------------------------------------------------------
function GetMaxPersonnel(self) -- equivalent to GetMaxStock(self, personnelResourceID)
	return self:GetMaxStock(personnelResourceID)
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
	foodConsumption1000 = foodConsumption1000 + (self:GetUpperClass()	* UpperClassFoodConsumption 	)
	foodConsumption1000 = foodConsumption1000 + (self:GetMiddleClass()	* MiddleClassFoodConsumption 	)
	foodConsumption1000 = foodConsumption1000 + (self:GetLowerClass()	* LowerClassFoodConsumption 	)
	foodConsumption1000 = foodConsumption1000 + (self:GetSlaveClass()	* SlaveClassFoodConsumption 	)
	foodConsumption1000 = foodConsumption1000 + (self:GetPersonnel()	* PersonnelFoodConsumption 		)
	-- value belows may be nil
	if data.WoundedPersonnel then
		foodConsumption1000 = foodConsumption1000 + (data.WoundedPersonnel * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_WOUNDED_FACTOR"].Value) )
	end
	if data.Prisoners then
		foodConsumption1000 = foodConsumption1000 + (GCO.GetTotalPrisoners(data) * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PRISONERS_FACTOR"].Value) )
	end
	return math.max(1, GCO.Round(Div(( foodConsumption1000 * ratio / 1000  ), self:GetFoodNeededByPopulationFactor()))) -- self:GetFoodNeededByPopulation(population, consumptionRatio )))--
end

function GetFoodNeededByPopulationFactor(self)	-- reduce food consumption relatively to city size as population per size is exponential, set FOOD_CONSUMPTION_SIZE_EFFECT_REDUCTION > 1 to limit the effect of city size on food consumption
	return math.max(1, Div(self:GetRealSize(), tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_SIZE_EFFECT_REDUCTION"].Value)))
end

function GetFoodStock(self) -- return all edible food stock
	local foodStock	= 0
	for _, resourceID in ipairs(GCO.GetEdibleFoodList()) do
		foodStock = foodStock + self:GetStock(resourceID)
	end
	return foodStock
	--return self:GetStock(foodResourceID)
end

function GetCityBaseFoodStock(data)
	local city = CityManager.GetCity(data.playerID, data.cityID)
	return GCO.Round(city:GetMaxStock(foodResourceID) / 2)
end

function GetFoodRationing(self)
	local cityKey = self:GetKey()
	return ExposedMembers.CityData[cityKey].FoodRatio
end


----------------------------------------------
-- Custom Yields function
----------------------------------------------
function GetCustomYield(self, yieldID)
	local yield = BaseCityYields[yieldID] or 0

	for buildingID, Yields in pairs(BuildingYields) do
		if self:GetBuildings():HasBuilding(buildingID) and Yields[yieldID] then
			yield = yield + Yields[yieldID]
		end
	end
	return yield
end


----------------------------------------------
-- Construction function
----------------------------------------------
function GetBuildingConstructionResources(buildingType)
	local resTable 		= {}
	local row			= GameInfo.Buildings[buildingType]
	local buildingID	= row.Index
	local materiel 		= row.Cost * row.MaterielPerProduction
	if materiel 	> 0 then resTable[materielResourceID]	= materiel end
		
	if buildingConstructionResources[buildingID] then
		for _, row in ipairs(buildingConstructionResources[buildingID]) do
			resTable[row.ResourceID]	= row.Quantity
		end
	end
	
	return resTable
end

function GetConstructionEfficiency(self)
	local cityKey = self:GetKey()
	if ExposedMembers.CityData[cityKey] then
		return ExposedMembers.CityData[cityKey].ConstructionEfficiency or 1
	end
	return 1
end

function SetConstructionEfficiency(self, efficiency)
	local cityKey = self:GetKey()
	if ExposedMembers.CityData[cityKey] then
		ExposedMembers.CityData[cityKey].ConstructionEfficiency = efficiency
	end
end

function CanTrain(self, unitType)

	local DEBUG_CITY_SCRIPT = DEBUG_CITY_SCRIPT	
	--if GameInfo.Units["UNIT_HORSEMAN"].Index == unitID and Game.GetLocalPlayer() == self:GetOwner() then DEBUG_CITY_SCRIPT = "debug" end
	--if self:GetBuildings():HasBuilding(GameInfo.Buildings["BUILDING_PALACE"].Index) and Game.GetLocalPlayer() == self:GetOwner() then DEBUG_CITY_SCRIPT = "debug" end
	
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "CanTrain for "..Locale.Lookup(GameInfo.Units[unitType].Name).." in "..Locale.Lookup(self:GetName()))

	local row				= GameInfo.Units[unitType]
	local prereqTech 		= row.PrereqTech
	local prereqCivic		= row.PrereqCivic
	local unitID 			= row.Index
	local player			= GCO.GetPlayer(self:GetOwner())	
	local organizationLevel = player:GetMilitaryOrganizationLevel()
	local NumResource		= player:GetCached("NumResource") or {}
	local bHasComponents 	= true
	local bCanShow			= true -- can this unit been shown in the production Panel
	local production 		= self:GetProductionYield()
	local turnsToBuild 		= production == 0 and 1 or math.max(1, math.ceil(Div(row.Cost, production)))
	local turnsLeft 		= self:GetProductionTurnsLeft(unitType) or turnsToBuild
	local resTable 			= GCO.GetUnitConstructionResources(unitID, organizationLevel)
	local resOrTable 		= GCO.GetUnitConstructionOrResources(unitID, organizationLevel)
	local requirementStr 	= Locale.Lookup("LOC_PRODUCTION_PER_TURN_REQUIREMENT")
	local reservedStr		= Locale.Lookup("LOC_ALREADY_RESERVED_RESOURCE")
	local totalStr			= Locale.Lookup("LOC_PRODUCTION_TOTAL_REQUIREMENT")
	local turn				= Game.GetCurrentGameTurn()
	local previousTurn		= math.max(0, turn - 1 )
	local costPerTurn		= 0

	-- check for required buildings (any required)
	local bCheckBuildingOR
	if UnitPrereqBuildingOR[unitID] then
		for buildingID, _ in ipairs(UnitPrereqBuildingOR[unitID]) do
			if self:GetBuildings():HasBuilding(buildingID) then bCheckBuildingOR = true end
		end
	else
		bCheckBuildingOR = true
	end
	-- check for required buildings (all required)
	local bCheckBuildingAND
	if UnitPrereqBuildingAND[unitID] then
		for buildingID, _ in ipairs(UnitPrereqBuildingAND[unitID]) do
			if not self:GetBuildings():HasBuilding(buildingID) then bCheckBuildingAND = false end
		end
	else
		bCheckBuildingAND = true
	end
	
	if not (row.CanTrain) then
		bCanShow = false
	elseif (row.TraitType == "TRAIT_BARBARIAN") then
		bCanShow = false
	elseif prereqTech then -- the UI side will show units with prereq techs/civics only when they can be started
		bCanShow = false
	elseif prereqCivic then
		bCanShow = false
	elseif row.UnitType == "UNIT_SPY" then -- special case, shown only if the UI says it can be produced
		bCanShow = false
	end
	
	-- Check if this unit is already in production queue
	local reservedResource 	= self:GetBuildingQueueAllStock(unitType)
	local bAddStr 			= false
	for resourceKey, value in pairs(reservedResource) do
		bAddStr = true
		--break
	end

	-- check components needed
	for resourceID, value in pairs(resTable) do
		if not NumResource[resourceID] then
			bCanShow = false  -- don't show Units for which we don't have one of the required resource in any city
		end
	
		local reserved 					= self:GetBuildingQueueStock(resourceID, unitType)
		local needPerTurn 				= math.ceil( Div((value - reserved), turnsLeft))
		local stock						= self:GetStock(resourceID)
		local supplied					= math.max(self:GetSupplyAtTurn(resourceID, turn), self:GetSupplyAtTurn(resourceID, previousTurn))
		local resourceCost				= self:GetResourceCost(resourceID)
		local costPerTurn				= needPerTurn * resourceCost
		local costStr					= ""
		local totalCost 				= resourceCost * value
		local totalCostStr 				= ""
		if costPerTurn > 0 	then costStr = "("..tostring(costPerTurn).." [ICON_Gold])" end
		if totalCost > 0 	then totalCostStr = "("..tostring(totalCost).." [ICON_Gold])" end
		if reserved > 0 then
			reservedStr = reservedStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESERVED_RESOURCE", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, reserved )

			Dprint( DEBUG_CITY_SCRIPT, Locale.Lookup("LOC_PRODUCTION_RESERVED_RESOURCE", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, reserved))
		end

		totalStr = totalStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_TOTAL", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, value, totalCostStr )

		if (needPerTurn * ConstructionMinStockRatio) > stock and (needPerTurn * ConstructionMinStockRatio) > supplied then
			bHasComponents = false
			Dprint( DEBUG_CITY_SCRIPT, "Can't train ".. Locale.Lookup(GameInfo.Units[unitType].Name) ..", failed check on components ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." -> needPerTurn * ConstructionMinStockRatio = ", needPerTurn * ConstructionMinStockRatio, " > stock ", stock, " and > supplied ", supplied)
			requirementStr = requirementStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_NO_STOCK", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, needPerTurn, stock, supplied, costStr )
		elseif value > (stock + (supplied * turnsToBuild)) and needPerTurn > supplied then
			requirementStr = requirementStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_LIMITED_STOCK", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, needPerTurn, stock, supplied, costStr )
		else
			requirementStr = requirementStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_ENOUGH_STOCK", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, needPerTurn, stock, supplied, costStr )
		end
	end

	-- check equipment needed
	local totalMaxLogisticCost 	= 0
	local totalMinLogisticCost 	= 0
		
	for equipmentClass, resourceTable in pairs(resOrTable) do

		local totalNeeded 		= resourceTable.Value
		local bIsKnown			= false -- to check if there is at least one equipment of that class available in all this player's cities
		local alreadyStocked 	= 0
		-- get the number of resource already stocked for that class...
		for _, resourceID in ipairs(resourceTable.Resources) do -- loop through the possible resources (ordered by desirability) for that class
			alreadyStocked = alreadyStocked + self:GetBuildingQueueStock(resourceID, unitType)
			if NumResource[resourceID] then bIsKnown = true end
		end
		if not bIsKnown then
			bCanShow = false
		end

		local value 				= totalNeeded - alreadyStocked
		local needPerTurn 			= math.ceil( value / turnsLeft )
		local numResourceToProvide	= needPerTurn
		local supplied 				= 0
		local stock					= 0
		local costMin				= 99999
		local costMax				= 0
		local logisticCostMin		= 99999
		local logisticCostMax		= 0
		for _, resourceID in ipairs(resourceTable.Resources) do -- loop through the possible resources (ordered by desirability) for that class
			--if numResourceToProvide > 0 then
				stock 				= stock + self:GetStock(resourceID)
				supplied 			= supplied + math.max(self:GetSupplyAtTurn(resourceID, turn), self:GetSupplyAtTurn(resourceID, previousTurn))
				local cost			= self:GetResourceCost(resourceID)
				local logisticCost	= EquipmentInfo[resourceID].LogisticCost or 0
				if cost > costMax then
					costMax = cost
				end
				if cost < costMin then
					costMin = cost
				end
				if logisticCost > logisticCostMax then
					logisticCostMax = logisticCost
				end
				if logisticCost < logisticCostMin then
					logisticCostMin = logisticCost
				end
			--end
			local reserved 	= self:GetBuildingQueueStock(resourceID, unitType)
			if reserved > 0 then
				reservedStr = reservedStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESERVED_RESOURCE", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, reserved )
			end
		end

		local totalMaxCost 			= costMax * totalNeeded
		local totalMinCost 			= costMin * totalNeeded
		totalMaxLogisticCost 	= totalMaxLogisticCost + (logisticCostMax * totalNeeded)
		totalMinLogisticCost 	= totalMinLogisticCost + (logisticCostMin * totalNeeded)
		local totalCostStr = ""
		if totalMaxCost + totalMinCost > 0 then
			if totalMaxCost ~= totalMinCost then
				totalCostStr = "("..tostring(totalMinCost).."-"..tostring(totalMaxCost).." [ICON_Gold])"
			else
				totalCostStr = "("..tostring(totalMinCost).." [ICON_Gold])"
			end
		end
		
		totalStr = totalStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_TOTAL", GCO.GetResourceIcon(), GameInfo.EquipmentClasses[equipmentClass].Name, totalNeeded, totalCostStr )
				
		local maxCostPerTurn = costMax * needPerTurn
		local minCostPerTurn = costMin * needPerTurn
		local costPerTurnStr = ""
		if maxCostPerTurn + minCostPerTurn > 0 then
			if maxCostPerTurn ~= minCostPerTurn then 
				costPerTurnStr = "("..tostring(minCostPerTurn).."-"..tostring(maxCostPerTurn).." [ICON_Gold])"
			else
				costPerTurnStr = "("..tostring(minCostPerTurn).." [ICON_Gold])"
			end
		end

		if (needPerTurn * ConstructionMinStockRatio) > stock and (needPerTurn * ConstructionMinStockRatio) > supplied then
			Dprint( DEBUG_CITY_SCRIPT, "Can't train ".. Locale.Lookup(GameInfo.Units[unitType].Name) ..", failed check on equipment ".. Locale.Lookup(GameInfo.EquipmentClasses[equipmentClass].Name).." -> needPerTurn * ConstructionMinStockRatio) = ", needPerTurn * ConstructionMinStockRatio, " > stock ", stock, " and > supplied ", supplied)
			bHasComponents = false
			requirementStr = requirementStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_NO_STOCK", GCO.GetResourceIcon(), GameInfo.EquipmentClasses[equipmentClass].Name, needPerTurn, stock, supplied, costPerTurnStr ) -- GetResourceIcon() with no argument returns a default icon (to do : GetEquipmentClassIcon(equipmentClass))
		elseif value > (stock + (supplied * turnsToBuild)) and needPerTurn > supplied then
			requirementStr = requirementStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_LIMITED_STOCK", GCO.GetResourceIcon(), GameInfo.EquipmentClasses[equipmentClass].Name, needPerTurn, stock, supplied, costPerTurnStr )
		else
			requirementStr = requirementStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_ENOUGH_STOCK", GCO.GetResourceIcon(), GameInfo.EquipmentClasses[equipmentClass].Name, needPerTurn, stock, supplied, costPerTurnStr )
		end

	end
	
	local logisticCostStr
	if totalMaxLogisticCost + totalMinLogisticCost > 0 then
		if totalMaxLogisticCost ~= totalMinLogisticCost then
			logisticCostStr = tostring(totalMinLogisticCost).."-"..tostring(totalMaxLogisticCost)
		else
			logisticCostStr = tostring(totalMinLogisticCost)
		end
	end
	
	local bCheckLogistic 	= true
	local PromotionClassID 	= GCO.GetUnitPromotionClassID(unitID)
	if PromotionClassID then
		local logisticCost		= player:GetLogisticCost(PromotionClassID)
		local availableLogistic	= player:GetLogisticSupport(PromotionClassID)
		if logisticCost >= availableLogistic then
			Dprint( DEBUG_CITY_SCRIPT, "Can't train ".. Locale.Lookup(GameInfo.Units[unitType].Name) .." of ".. Locale.Lookup(GameInfo.UnitPromotionClasses[PromotionClassID].Name) .." class, failed check on logistic : available = ".. tostring(availableLogistic)..",  current cost = " .. tostring(logisticCost))
			bCheckLogistic = false
			requirementStr = requirementStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_NO_LOGISTIC_SUPPORT", logisticCost, GameInfo.UnitPromotionClasses[PromotionClassID].Name, availableLogistic, logisticCost - availableLogistic )
		end
	end

	-- construct the complete requirement string
	if logisticCostStr 	then totalStr		= totalStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_LOGISTIC_COST", logisticCostStr) end
	if bAddStr 			then requirementStr = reservedStr .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") .. requirementStr end
	requirementStr = "[NEWLINE]" .. totalStr .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") .. requirementStr
	Dprint( DEBUG_CITY_SCRIPT, requirementStr)

	return (bHasComponents and bCheckBuildingAND and bCheckBuildingOR and bCheckLogistic), requirementStr, bCanShow
end

function CanConstruct(self, buildingType)

	local row 				= GameInfo.Buildings[buildingType]
	local buildingID 		= row.Index
	local cityBuildings		= self:GetBuildings()
	local preReqStr 		= {}
	local bCheckSpecial 	= true
	local bCanShow			= true -- can this building been shown in the production Panel
	local player 			= GCO.GetPlayer(self:GetOwner())
	local pScience 			= player:GetTechs()
	local prereqTech 		= GameInfo.Buildings[buildingType].PrereqTech
	local prereqCivic		= GameInfo.Buildings[buildingType].PrereqCivic
	local bHasComponents 	= true
	local production 		= self:GetProductionYield()
	local turnsToBuild 		= production == 0 and 1 or math.max(1, math.ceil(Div(row.Cost, production)))
	local resTable 			= GCO.GetBuildingConstructionResources(buildingType)
	local requirementStr 	= {} -- table to build the string
	local reservedStr		= Locale.Lookup("LOC_ALREADY_RESERVED_RESOURCE")
	local totalStr			= Locale.Lookup("LOC_PRODUCTION_TOTAL_REQUIREMENT")
	
	-- Can we show this in the production panel ?
	if cityBuildings:HasBuilding(buildingID) and row.BuildingType ~= "BUILDING_RECRUITS" then -- at this point the game has not registered that BUILDING_RECRUITS was removed ?
		bCanShow = false
	elseif prereqTech and not (pScience:HasTech(GameInfo.Technologies[prereqTech].Index)) then
		bCanShow = false
	elseif prereqCivic then -- the UI side will show those buildings when they can be started
		bCanShow = false
	end
	
	-- check for upgrade already build
	local bCheckNoUpgradeBuild = true
	if BuildingFullUpgrades[buildingID] then
		for _, upgradeID in ipairs(BuildingFullUpgrades[buildingID]) do
			if self:GetBuildings():HasBuilding(upgradeID) then
				bCheckNoUpgradeBuild 	= false
				bCanShow				= false
			elseif BuildingUpgrade[buildingID] == upgradeID then -- this is the direct upgrade to this building
				table.insert(preReqStr, "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_UPGRADE_TO", GameInfo.Buildings[upgradeID].Name))
			end
		end
	end
	
	-- add string for replacement
	local replacements		= BuildingReplacements[buildingID]
	local replacementsStr	= ""
	if replacements then
		for _, replacedID in ipairs(replacements) do
			replacementsStr = replacementsStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_BULLET_BUILDING", GameInfo.Buildings[replacedID].Name )
		end
		table.insert(preReqStr, "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_REPLACE") .. replacementsStr)
	end
	
	-- check for required buildings (any required)
	local bCheckBuildingOR
	local buildORstr = ""
	if BuildingPrereqBuildingOR[buildingID] then
		for prereq, _ in pairs(BuildingPrereqBuildingOR[buildingID]) do
			if self:GetBuildings():HasBuilding(prereq) then
				bCheckBuildingOR = true
				buildORstr = buildORstr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_REQUIRES_BUILDING_FOUND_ANY", GameInfo.Buildings[prereq].Name )
			else
				buildORstr = buildORstr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_REQUIRES_BUILDING", GameInfo.Buildings[prereq].Name )
			end
		end
		table.insert(preReqStr, "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_REQUIRES_ANY_BUILDING") .. buildORstr)
	else
		bCheckBuildingOR = true
	end

	-- check for required buildings (all required)
	local bCheckBuildingAND
	local buildANDstr = ""
	if BuildingPrereqBuildingAND[buildingID] then
		for prereq, _ in pairs(BuildingPrereqBuildingAND[buildingID]) do
			if not self:GetBuildings():HasBuilding(prereq) then
				bCheckBuildingAND = false
				buildANDstr = buildANDstr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_REQUIRES_BUILDING_MISSING_ALL", GameInfo.Buildings[prereq].Name )
			else
				buildANDstr = buildANDstr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_REQUIRES_BUILDING", GameInfo.Buildings[prereq].Name )
			end
		end
		table.insert(preReqStr, "[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_REQUIRES_ALL_BUILDING") .. buildANDstr)
	else
		bCheckBuildingAND = true
	end

	-- check for coastal buildings
	local bCoastalCheck = true
	if (row.Coast and row.PrereqDistrict == "DISTRICT_CITY_CENTER") then
		if not self:IsCoastal() then
			bCoastalCheck 	= false
			bCanShow		= false
			--preReqStr = preReqStr.."[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_REQUIRES_COASTAL_FAIL")
		else
			--preReqStr = preReqStr.."[NEWLINE][NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_REQUIRES_COASTAL_CHECKED")
		end
	end

	-- check components
	table.insert(requirementStr, Locale.Lookup("LOC_PRODUCTION_PER_TURN_REQUIREMENT"))
	
	-- Check if this building is already in production queue
	local reservedResource 	= self:GetBuildingQueueAllStock(buildingType)
	local bAddStr 			= false
	--for resourceKey, value in pairs(reservedResource) do
	if not GCO.IsEmpty(reservedResource) then
		bAddStr = true
	end

	for resourceID, value in pairs(resTable) do

		local previousTurnKey 	= GCO.GetPreviousTurnKey()
		local turn				= Game.GetCurrentGameTurn()
		local previousTurn		= math.max(0, turn - 1 )
		local needPerTurn 		= math.ceil( Div(value, turnsToBuild))
		local stock				= self:GetStock(resourceID)
		local supplied			= math.max(self:GetSupplyAtTurn(resourceID, turn), self:GetSupplyAtTurn(resourceID, previousTurn))		
		local reserved 			= self:GetBuildingQueueStock(resourceID, buildingType)
		local resourceCost		= self:GetResourceCost(resourceID)
		local costPerTurn		= needPerTurn * resourceCost
		local costStr			= ""
		local totalCost 		= resourceCost * value
		local totalCostStr 		= ""
		if costPerTurn > 0 	then costStr = "("..tostring(costPerTurn).." [ICON_Gold])" end
		if totalCost > 0 	then totalCostStr = "("..tostring(totalCost).." [ICON_Gold])" end

		if reserved > 0 then
			reservedStr = reservedStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESERVED_RESOURCE", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, reserved )
		end
		
		totalStr = totalStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_TOTAL", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, value, totalCostStr )

		if (needPerTurn * ConstructionMinStockRatio) > stock and (needPerTurn * ConstructionMinStockRatio) > supplied then
			bHasComponents = false
			table.insert(requirementStr, "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_NO_STOCK", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, needPerTurn, stock, supplied, costStr ))
		elseif value > (stock + (supplied * turnsToBuild)) and needPerTurn > supplied then
			table.insert(requirementStr, "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_LIMITED_STOCK", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, needPerTurn, stock, supplied, costStr ))
		else
			table.insert(requirementStr, "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RESOURCE_ENOUGH_STOCK", GCO.GetResourceIcon(resourceID), GameInfo.Resources[resourceID].Name, needPerTurn, stock, supplied, costStr ))
		end
	end	
	
	-- check for special recruitment building
	if row.BuildingType == "BUILDING_RECRUITS" then
		local promotionClassID 	= GameInfo.UnitPromotionClasses["PROMOTION_CLASS_CONSCRIPT"].Index
		local unitType 			= GameInfo.Units["UNIT_CONSCRIPT_WARRIOR"].Index -- first unit in conscript class

		-- must be at war or under threat from barbarians
		if not player:IsAtWar() then
			local bNoThreat	= true
			local pLocalPlayerVis = PlayersVisibility[self:GetOwner()]
			if (pLocalPlayerVis ~= nil) then
				local cityPlot 	= GCO.GetPlot(self:GetX(), self:GetY())
				for ring = 1, 6 do
					for pEdgePlot in GCO.PlotRingIterator(cityPlot, ring) do
						if (pLocalPlayerVis:IsVisible(pEdgePlot:GetX(), pEdgePlot:GetY())) then
							if pEdgePlot:GetUnitCount() > 0 then
								local aUnits = Units.GetUnitsInPlot(pEdgePlot)
								for i, unit in ipairs(aUnits) do
									local unitOwner = GCO.GetPlayer(unit:GetOwner())
									-- check Domain
									if unitOwner:IsBarbarian() and not ("DOMAIN_SEA" == GameInfo.Units[unit:GetType()].Domain) then
										bNoThreat = false
									end
								end
							end
						end				
					end
				end
			end
			if bNoThreat then
				bCheckSpecial = false
				table.insert(requirementStr, "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_NO_THREAT_RECRUITS" ))
			end
		end
		
		if promotionClassID then
			---[[
			-- Don't allows drafting without logistic support
			local logisticCost		= player:GetLogisticCost(promotionClassID)
			local availableLogistic	= player:GetLogisticSupport(promotionClassID)
			if logisticCost >= availableLogistic then
				bCheckSpecial = false
				table.insert(requirementStr, "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_NO_LOGISTIC_SUPPORT", logisticCost, GameInfo.UnitPromotionClasses[promotionClassID].Name, availableLogistic, logisticCost - availableLogistic ))
			end
			--]]
			
			local personnelSupply	= math.max(0, self:GetStockVariation(personnelResourceID))
			local maxPersonnel		= 300
			local minPersonnel		= 250
			local organizationLevel	= player:GetConscriptOrganizationLevel()
			
			--local organizationLevel	= math.max(0 , player:GetMilitaryOrganizationLevel() - 2)
			if militaryOrganization[organizationLevel] and militaryOrganization[organizationLevel][promotionClassID] then
				local factor = 1
				if self:GetBuildings():HasBuilding(GameInfo.Buildings["BUILDING_SMALL_BARRACKS"].Index) then
					factor = 1
				end
				if self:GetBuildings():HasBuilding(GameInfo.Buildings["BUILDING_BARRACKS"].Index) then
					factor = 2.4 -- (*0.75 = 1.8 = 1 full unit + 1 at 80 HP)
				end
				maxPersonnel = militaryOrganization[organizationLevel][promotionClassID].FrontLinePersonnel*factor
				minPersonnel = maxPersonnel*0.75
			end
			
			if self:GetPersonnel() < (minPersonnel  - personnelSupply) then
				bCheckSpecial = false
				table.insert(requirementStr, "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_NO_PERSONNEL_RECRUITS", self:GetPersonnel(), minPersonnel, minPersonnel - self:GetPersonnel() ))
			end
			
			-- Get type
			local equipmentList	=  GCO.GetAvailableEquipmentForUnitPromotionClassFromList(unitType, promotionClassID, maxPersonnel, self:GetEquipmentList(), organizationLevel)
			local recruitType	= nil
			if promotionClassID then 
				recruitType = GCO.GetUnitTypeFromEquipmentList(promotionClassID, equipmentList, unitType, 75, organizationLevel)
			end
			if recruitType then
				table.insert(requirementStr, "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_RECRUIT_TYPE", GameInfo.Units[recruitType].Name))
			else
				bCheckSpecial = false
				table.insert(requirementStr, "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_NO_EQUIPMENT_RECRUITS"))
			end
		end
	end
	
	-- construct the complete requirement string
	local requirementStr = table.concat(requirementStr)
	if bAddStr then requirementStr = reservedStr .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") .. requirementStr end
	requirementStr = "[NEWLINE]" .. totalStr .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") .. requirementStr

	return (bHasComponents and bCheckBuildingAND and bCheckBuildingOR and bCoastalCheck and bCheckSpecial and bCheckNoUpgradeBuild), requirementStr, table.concat(preReqStr), bCanShow
end

function RecruitUnits(self, UnitType, number)
	
	--local DEBUG_CITY_SCRIPT = "debug"
	
	if not GameInfo.Units[UnitType] then
		GCO.Error("can't find "..tostring(UnitType).." in GameInfo.Units")
		return
	end
	
	local number 	= number or 1
	local playerID	= self:GetOwner()
	local player	= GCO.GetPlayer(playerID)
	
	for i = 1, number do
	
		local unit 				= UnitManager.InitUnit(playerID, UnitType, self:GetX(), self:GetY())
		
		-- initialize at 0 HP...
		Dprint( DEBUG_self_SCRIPT, "Initializing unit...")
		unit:SetDamage(100)
		local initialHP 				= 0
		local organizationLevel			= player:GetConscriptOrganizationLevel()
		local turnsActive				= ConscriptsBaseActiveTurns
		
		local policies	= player:GetActivePolicies()
		for _, policyID in ipairs(policies) do
			turnsActive = turnsActive + GameInfo.Policies[policyID].ActiveTurnsLeftBoost
		end

		GCO.RegisterNewUnit(playerID, unit, initialHP, nil, organizationLevel)
		GCO.AttachUnitFunctions(unit)
		unit:InitializeEquipment()
		unit:SetValue("CanChangeOrganization", nil)
		unit:SetValue("ActiveTurnsLeft", turnsActive)
		unit:SetValue("HomeCityKey", self:GetKey())	-- send back personnel/equipment/resources here on disbanding (with no income from selling)
		unit:SetValue("UnitPersonnelType", UnitPersonnelType.Conscripts)
		
		-- get full reinforcement...
		Dprint( DEBUG_self_SCRIPT, "Getting full reinforcement...")
		local bTotal		= true
		local recruitmentCostFactor	= tonumber(GameInfo.GlobalParameters["CITY_RECRUITMENT_COST_FACTOR"].Value)
		--local requirements 	= unit:GetRequirements(bTotal)
		
		local resTable 		= GCO.GetUnitConstructionResources(unit:GetType(), organizationLevel)
		local resOrTable 	= GCO.GetUnitConscriptionEquipment(unit:GetType(), organizationLevel)
					
		Dprint( DEBUG_self_SCRIPT, "Get available resources in city...")
		for resourceID, value in pairs(resTable) do
			if value > 0 then
				local maxValue	= math.min(self:GetStock(resourceID), value)
				local cost 		= self:GetResourceCost(resourceID) * maxValue * recruitmentCostFactor
				Dprint( DEBUG_self_SCRIPT, " - ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)).." = ",maxValue, ", cost = ", cost)
				unit:ChangeStock(resourceID, maxValue)
				self:ChangeStock(resourceID, -maxValue, ResourceUseType.Supply, unit:GetKey())
				if cost > 0 then
					player:ProceedTransaction(AccountType.Reinforce, -cost)
				end
			end
		end			
		
		for equipmentClass, resourceTable in pairs(resOrTable) do
			local totalNeeded 		= resourceTable.Value
			local stillNeeded		= totalNeeded
			-- get the number of resource already stocked for that class...
			for _, resourceID in ipairs(resourceTable.Resources) do -- loop through the possible resources (ordered by desirability) for that class
				local maxValue 	= math.min(self:GetStock(resourceID), stillNeeded)
				local cost 		= self:GetResourceCost(resourceID) * maxValue * recruitmentCostFactor
				Dprint( DEBUG_self_SCRIPT, " - ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)).." = ",maxValue, ", cost = ", cost)
				unit:ChangeStock(resourceID, maxValue)
				self:ChangeStock(resourceID, -maxValue, ResourceUseType.Supply, unit:GetKey())
				if cost > 0 then
					player:ProceedTransaction(AccountType.Reinforce, -cost)
				end
				stillNeeded = math.max(0, stillNeeded - maxValue)
			end
		end
			
		-- heal completly...			
		Dprint( DEBUG_self_SCRIPT, "Healing...")
		local bNoLimit 	= true
		local maxHP		= 100
		unit:Heal(maxHP, maxHP, bNoLimit)
		
		-- try to upgrade...
		Dprint( DEBUG_self_SCRIPT, "Upgrading...")
		local newUnitType 	= unit:GetTypesFromEquipmentList()			
		if newUnitType and newUnitType ~= unit:GetType() then
			local newUnit = GCO.ChangeUnitTo(unit, newUnitType)
			if newUnit then
				newUnit:Heal(maxHP, maxHP, bNoLimit)
			end
		end		
	
	end

end


-----------------------------------------------------------------------------------------
-- Activities & Employment
-----------------------------------------------------------------------------------------
function GetEraType(self)
	local player 	= Players[self:GetOwner()]
	return GameInfo.Eras[player:GetEra()].EraType
end

function GetTotalPopulation(self)
	return self:GetUrbanPopulation() + self:GetRuralPopulation() 
end

function GetTotalPopulationVariation(self)
	return self:GetUrbanPopulationVariation() + self:GetRuralPopulationVariation() 
end

function GetUrbanPopulation(self)
	--[[
	-- simple test function before implementing per plot population for migration
	local eraType = self:GetEraType()
	local percent = BaseUrbanPercent[eraType]
	return GCO.Round(self:GetRealPopulation() * percent / 100)
	--]]
	return self:GetRealPopulation()
end

function GetUrbanPopulationVariation(self)
	--[[
	-- simple test function before implementing per plot population for migration
	local eraType = self:GetEraType()
	local percent = BaseUrbanPercent[eraType]
	return GCO.Round(self:GetRealPopulation() * percent / 100)
	--]]
	return self:GetRealPopulationVariation()
end

function GetRuralPopulation(self)
	--return self:GetRealPopulation() - self:GetUrbanPopulation()
	local ruralPopulation 	= 0
	local cityPlots			= GCO.GetCityPlots(self)
	for _, plotID in ipairs(cityPlots) do
		local plot = GCO.GetPlotByIndex(plotID)
		if plot and (not plot:IsCity()) then
			ruralPopulation = ruralPopulation + plot:GetPopulation()
		end
	end
	return ruralPopulation
end

function GetRuralPopulationClass(self, populationID)
	--return self:GetRealPopulation() - self:GetUrbanPopulation()
	local ruralPopulation 	= 0
	local cityPlots			= GCO.GetCityPlots(self)
	for _, plotID in ipairs(cityPlots) do
		local plot = GCO.GetPlotByIndex(plotID)
		if plot and (not plot:IsCity()) then
			ruralPopulation = ruralPopulation + plot:GetPopulationClass(populationID)
		end
	end
	return ruralPopulation
end

function GetPreviousRuralPopulationClass(self, populationID)
	--return self:GetRealPopulation() - self:GetUrbanPopulation()
	local ruralPopulation 	= 0
	local cityPlots			= GCO.GetCityPlots(self)
	for _, plotID in ipairs(cityPlots) do
		local plot = GCO.GetPlotByIndex(plotID)
		if plot and (not plot:IsCity()) then
			ruralPopulation = ruralPopulation + plot:GetPreviousPopulationClass(populationID)
		end
	end
	return ruralPopulation
end

function GetRuralPopulationVariation(self)
	--return self:GetRealPopulation() - self:GetUrbanPopulation()
	local ruralPopulation 	= 0
	local cityPlots			= GCO.GetCityPlots(self)
	for _, plotID in ipairs(cityPlots) do
		local plot = GCO.GetPlotByIndex(plotID)
		if plot and (not plot:IsCity()) then
			local previousPop = plot:GetPreviousUpperClass() + plot:GetPreviousMiddleClass() + plot:GetPreviousLowerClass() + plot:GetPreviousSlaveClass()			
			ruralPopulation = ruralPopulation + (plot:GetPopulation() - previousPop)
		end
	end
	return ruralPopulation
end

function GetUrbanEmploymentSize(self)
	local employment 		= 0
	--local maxEmploymentSize	= 5  -- to do : limit max size scale per building, use it in production too
	for buildingID, employmentValue in pairs(BuildingEmployment) do
		if self:GetBuildings():HasBuilding(buildingID) then
			employment = employment + employmentValue --(employmentValue + (math.min(self:GetSize(),maxEmploymentSize)))
		end
	end
	return employment
end

function GetCityEmploymentPow(self)
	return CityEmploymentPow[self:GetEraType()]
end

function GetCityEmploymentFactor(self)
	return CityEmploymentFactor[self:GetEraType()]
end

function GetEmploymentSize(self, num)
	return GCO.Round(math.pow( Div(num, self:GetCityEmploymentFactor()), Div(1, self:GetCityEmploymentPow())))
end

-- unused [[
function GetPlotEmploymentPow(self)
	return PlotEmploymentPow[self:GetEraType()]
end

function GetPlotEmploymentFactor(self)
	return PlotEmploymentFactor[self:GetEraType()]
end

function GetMaxEmploymentRural(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetMaxEmploymentRural()
	elseif not _cached[cityKey].MaxEmploymentRural then
		self:SetMaxEmploymentRural()
	end
	return _cached[cityKey].MaxEmploymentRural
end

function SetMaxEmploymentRural(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then _cached[cityKey] = {} end
	-- We want the max value before reaching the next city size...
	local nextCitySize = self:GetSize() + 1
	_cached[cityKey].MaxEmploymentRural = GCO.Round(math.pow(nextCitySize, self:GetPlotEmploymentPow()) * self:GetPlotEmploymentFactor())
end
-- unused ]]

function GetMaxEmploymentUrban(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetMaxEmploymentUrban()
	elseif not _cached[cityKey].MaxEmploymentUrban then
		self:SetMaxEmploymentUrban()
	end
	return _cached[cityKey].MaxEmploymentUrban
end

function SetMaxEmploymentUrban(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then _cached[cityKey] = {} end
	-- We want the max value before reaching the next city size...
	local employmentSize = self:GetUrbanEmploymentSize() --self:GetSize() + 1
	_cached[cityKey].MaxEmploymentUrban = GCO.Round(self:GetUrbanPopulation()*Div(employmentSize, self:GetSize()))--GCO.Round(math.pow(employmentSize, self:GetCityEmploymentPow()) * self:GetCityEmploymentFactor())
end

-- duplicate usage with GetUrbanActivityFactor...
--[[
function GetProductionFactorFromBuildings(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetProductionFactorFromBuildings()
	elseif not _cached[cityKey].ProductionFactorFromBuildings then
		self:SetProductionFactorFromBuildings()
	end
	return _cached[cityKey].ProductionFactorFromBuildings
end

function SetProductionFactorFromBuildings(self)

	local cityKey = self:GetKey()
	if not _cached[cityKey] then _cached[cityKey] = {} end
	
	local size 			= self:GetSize()
	local employment 	= self:GetUrbanEmploymentSize()
	
	local ratio = 1
	if employment > 0 then 
		ratio = math.min(1,Div(size, employment))
	end
	_cached[cityKey].ProductionFactorFromBuildings = ratio
end
--]]

function GetEmploymentFactorFromBuildings(self)
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		self:SetEmploymentFactorFromBuildings()
	elseif not _cached[cityKey].EmploymentFactorFromBuildings then
		self:SetEmploymentFactorFromBuildings()
	end
	return _cached[cityKey].EmploymentFactorFromBuildings
end

function SetEmploymentFactorFromBuildings(self)

	local cityKey = self:GetKey()
	if not _cached[cityKey] then _cached[cityKey] = {} end
	
	local size 			= self:GetSize()
	local employment 	= self:GetUrbanEmploymentSize()
	
	_cached[cityKey].EmploymentFactorFromBuildings = math.min(1,Div(employment, size))
end

-- duplicate usage with GetUrbanActivityFactor...
--[[
function GetMaxEmploymentFromBuildings(self)
	local maxEmployment = self:GetMaxEmploymentUrban()
	local ratio 		= self:GetEmploymentFactorFromBuildings()
	return GCO.Round(maxEmployment * ratio)
end
--]]

function GetUrbanEmployed(self)
	return math.min(self:GetUrbanPopulation(), self:GetMaxEmploymentUrban())
end

function GetUrbanActivityFactor(self)
	local employmentFromBuilding 	= self:GetMaxEmploymentUrban()
	local employed					= self:GetUrbanEmployed()
	if employmentFromBuilding > employed then
		--return Div(self:GetUrbanEmployed(), employmentFromBuilding)
		return Div(self:GetEmploymentSize(employed), self:GetEmploymentSize(employmentFromBuilding))
	else
		return 1
	end
end

function GetUrbanProductionFactor(self)
	return self:GetUrbanActivityFactor() --math.min(1, self:GetProductionFactorFromBuildings() * self:GetUrbanActivityFactor())
end

function GetOutputPerYield(self)
	local adminEfficiency = self:GetAdministrativeEfficiency()/100
	return math.max(1, self:GetUrbanProductionFactor() * self:GetSize() * adminEfficiency)
end


----------------------------------------------
-- Health function
----------------------------------------------


----------------------------------------------
-- Texts function
----------------------------------------------
function GetHealthString(self)

	if not self:GetCached("Health") then self:SetHealthValues() end	
	
	local health		= self:GetValue("Health") or 0
	local healthPct		= (100 + (health)) / 2 -- to do: no hardcoding of the max (+100) and min (-100) health values
	local healthStr		= GCO.GetEvaluationStringFromValue(health, 100, -100) -- GCO.GetEvaluationStringFromValue(health, 100, -100, "LOC_CITYBANNER_HEALTH_NAME")
	local returnStr		= Locale.Lookup("LOC_CITYBANNER_HEALTH_PERCENTAGE", GCO.GetPercentBarString(healthPct), healthStr) .. " " ..Locale.Lookup("LOC_TOOLTIP_SEPARATOR")--""
	local change		= 0
	local healthValues	= self:GetCached("Health") or {}
	local changeTable	= {}
	local strTable 		= {}
	
	if healthValues.Condensed then
		for cause, value in pairs(healthValues.Condensed) do
			change = change + value
			table.insert(changeTable, {Text = cause, Value = value})
		end
	end
	
	table.sort(changeTable, function(a, b) return a.Value > b.Value; end)
	for _, data in ipairs(changeTable) do
		table.insert(strTable, Locale.Lookup(data.Text, data.Value))
	end
	return returnStr .. table.concat(strTable, "[NEWLINE]") ..Locale.Lookup("LOC_TOOLTIP_SEPARATOR") .. Locale.Lookup("LOC_CITYBANNER_HEALTH_CHANGE", GCO.GetEvaluationStringFromValue(change, 15, -15))
end

function GetHealthIcon(self)

	if not self:GetCached("Health") then self:SetHealthValues() end	
	
	local health	= self:GetValue("Health") or 0
	local healthPct	= (100 + (health)) / 2 -- to do: no hardcoding of the max (+100) and min (-100) health values
	local str		= "[ICON_HealthGood]" --"[ICON_HEALTH2]"
	
	if healthPct < 25 then
		str		= "[ICON_HealthBad]"
	elseif healthPct < 50 then
		str		= "[ICON_HealthLow]"
	end
	
	return str
end

function GetResourcesStockString(self)
	local cityKey 			= self:GetKey()
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey	= GCO.GetPreviousTurnKey()
	local data 				= ExposedMembers.CityData[cityKey]
	local strFull			= ""
	local equipmentList		= {}
	local foodList			= {}
	local strategicList		= {}
	local otherList			= {}
	if not data.Stock[turnKey] then return end
local count = 0
	for resourceKey, value in pairs(data.Stock[turnKey]) do
		local resourceID 		= tonumber(resourceKey)
		---[[
--Dline(count)
count = count + 1
--Dline(resourceKey, type(resourceKey))
--Dline(value, type(value))
if type(value) == "table" then for k, v in pairs(value) do print(k,v) end
else 
--]]
		if (value + self:GetAverageSupplyAtTurn(resourceID) + self:GetDemandAtTurn(resourceID, previousTurnKey) + self:GetDemandAtTurn(resourceID, turnKey) > 0 and resourceKey ~= personnelResourceKey) then -- and resourceKey ~= foodResourceKey

			local stockVariation 	= self:GetStockVariation(resourceID)
			local resourceCost 		= self:GetResourceCost(resourceID)
			local costVariation 	= self:GetResourceCostVariation(resourceID)
			local resRow 			= GameInfo.Resources[resourceID]
			local str 				= ""
			local bIsEquipmentMaker = GCO.IsResourceEquipmentMaker(resourceID)
			
			str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_RESOURCE_TEMP_ICON_STOCK", value, self:GetMaxStock(resourceID), resRow.Name, GCO.GetResourceIcon(resourceID), GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Product, turnKey)))
			str = str .. GCO.GetVariationString(stockVariation)
			local costVarStr = GCO.GetVariationStringRedPositive(costVariation)
			if resourceCost > 0 then
				str = str .." (".. Locale.Lookup("LOC_CITYBANNER_RESOURCE_COST", resourceCost)..costVarStr..")"
			end
			
			if GCO.IsResourceEquipment(resourceID) then
				table.insert(equipmentList, { String = str, Order = EquipmentInfo[resourceID].Desirability })
			elseif resRow.ResourceClassType == "RESOURCECLASS_STRATEGIC" or bIsEquipmentMaker then
				local equipmentMaker = 0
				if bIsEquipmentMaker then equipmentMaker = 1 end
				table.insert(strategicList, { String = str, Order = equipmentMaker })
			elseif GCO.IsResourceFood(resourceID) or resourceKey == foodResourceKey then
				table.insert(foodList, { String = str, Order = value })
			else
				table.insert(otherList, { String = str, Order = value })
			end			
		end
end
	end
	table.sort(equipmentList, function(a, b) return a.Order > b.Order; end)
	table.sort(strategicList, function(a, b) return a.Order > b.Order; end)
	table.sort(foodList, function(a, b) return a.Order > b.Order; end)
	table.sort(otherList, function(a, b) return a.Order > b.Order; end)
	strFull = strFull .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_EQUIPMENT_STOCK_TITLE")
	for i, data in ipairs(equipmentList) do
		strFull = strFull .. data.String
	end
	strFull = strFull .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_STRATEGIC_STOCK_TITLE")
	for i, data in ipairs(strategicList) do
		strFull = strFull .. data.String
	end
	strFull = strFull .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_FOOD_STOCK_TITLE")
	for i, data in ipairs(foodList) do
		strFull = strFull .. data.String
	end
	strFull = strFull .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_OTHER_STOCK_TITLE")
	for i, data in ipairs(otherList) do
		strFull = strFull .. data.String
	end
	return strFull
end

function GetScienceStockStringTable(self, scienceToolTipTab, scienceToolTipMode)
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey	= GCO.GetPreviousTurnKey()
	local strFull			= ""
	local pResearch 		= GCO.Research:Create(self:GetOwner())
	local pTechs			= pResearch:GetTechs()
	local scienceList		= {}
	local stringTable		= {}
	local bAllTab			= (scienceTabs[scienceToolTipTab] == "LOC_CITYBANNER_TOOLTIP_SCIENCE_ALL_TAB")
	local bKnownTab			= (scienceTabs[scienceToolTipTab] == "LOC_CITYBANNER_TOOLTIP_SCIENCE_KNOWN_TAB")
	local bUnlockedTab		= (scienceTabs[scienceToolTipTab] == "LOC_CITYBANNER_TOOLTIP_SCIENCE_UNLOCKED_TAB")
	local bLockedTab		= (scienceTabs[scienceToolTipTab] == "LOC_CITYBANNER_TOOLTIP_SCIENCE_LOCKED_TAB")
	
	for resourceKey, value in pairs(self:GetResources()) do
		local resourceID 		= tonumber(resourceKey)
		
		if GCO.IsKnowledgeResource(resourceID) then

			local techType			= pResearch:GetResourceTechnologyType(resourceID)
			local techRow			= techType and GameInfo.Technologies[techType]
			local techID			= techRow and techRow.Index
			local bHasTech			= techID and pTechs:HasTech(techID)
			local bCanResearch		= techID and pTechs:CanResearch(techID)
			local bIsResearchField	= pResearch:GetResourceResearchType(resourceID) ~= nil
			local bCanShow 			= (bAllTab or pResearch:IsBlankKnowledgeResource(resourceID)) or (bKnownTab and bHasTech and not bIsResearchField) or (bUnlockedTab and (bIsResearchField or bCanResearch)) or (bLockedTab and not (bCanResearch or bHasTech or bIsResearchField))
		
			if bCanShow and (value + self:GetAverageSupplyAtTurn(resourceID) + self:GetDemandAtTurn(resourceID, previousTurnKey) + self:GetDemandAtTurn(resourceID, turnKey) > 0 and resourceKey ~= personnelResourceKey) then -- and resourceKey ~= foodResourceKey

				local stockVariation 	= self:GetStockVariation(resourceID)
				local resourceCost 		= self:GetResourceCost(resourceID)
				local costVariation 	= self:GetResourceCostVariation(resourceID)
				local resRow 			= GameInfo.Resources[resourceID]
				local str 				= ""
				local bIsEquipmentMaker = GCO.IsResourceEquipmentMaker(resourceID)
				local product 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Product, turnKey))
				local collect 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Collect, turnKey))
				local localProd			= product + collect
				local sDisabled			= "X"
				local sNoTransfer		= resRow.NoTransfer and sDisabled
				local sNoExport			= resRow.NoExport and sDisabled
				local sNoTrade			= resRow.NoTransfer and resRow.NoExport and sDisabled

				local import 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Import, previousTurnKey))--GCO.Round(self:GetAverageUseTypeOnTurns(resourceID, ResourceUseType.Import, 3))-- -- all other players cities have not exported their resource at the beginning of the player turn, so get previous turn value
				local transferIn 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.TransferIn, turnKey))--GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.TransferIn, turnKey))
				local pillage 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Pillage, turnKey))
				local otherIn 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.OtherIn, turnKey))
				
				local consume 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Consume, turnKey))
				local export 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Export, turnKey))
				local transferOut 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.TransferOut, turnKey))
				local supply 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Supply, turnKey))
				local stolen 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Stolen, previousTurnKey)) --GCO.Round(self:GetAverageUseTypeOnTurns(resourceID, ResourceUseType.Stolen, 3))-- all other players units have not attacked yet at the beginning of the player turn, so get previous turn value
				local otherOut 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.OtherOut, turnKey))
				
				local name				= techRow and Locale.Lookup(techRow.Name) or " " .. Locale.Lookup(resRow.Name)
				
				-- mode 1 test
				---[[
					local tradeIn	= import + transferIn + pillage + otherIn
					local tradeOut	= export + transferOut + supply + stolen + otherOut
					
					str = GCO.GetResourceIcon(resourceID)
					str = str .. " " .. Indentation(name, 20)

					if tradeIn > 0 then
						str = str .. " |+" .. Indentation(tradeIn, 3, true).."/-"..Indentation(tradeOut, 3, true)
					else
						str = str .. " | " .. Indentation(sNoTrade or "0", 3, true).."/-"..Indentation(sNoTrade or tradeOut, 3, true)
					end
					
					str = str .. " |" .. Indentation(value, 4, true) .."/"..Indentation(self:GetMaxStock(resourceID), 4, true)
					str = str .. " |" .. (stockVariation < 0 and "[COLOR_Civ6Red]-"..Indentation(-stockVariation, 3, true) or "[COLOR_Civ6Green]+"..Indentation(stockVariation, 3, true)) .."[ENDCOLOR]"
					str = str .. " |[COLOR_Gold]" .. Indentation(resourceCost, 4, true).."[ENDCOLOR]"
					str = str .. " " .. (costVariation < 0 and "[COLOR_Civ6Green]-"..Indentation(-costVariation, 4, true) or "[COLOR_Civ6Red]+"..Indentation(costVariation, 4, true)) .."[ENDCOLOR]"
					str = str .. "[NEWLINE]"
				--]]
				
				table.insert(scienceList, { String = str, Order = name }) -- Order = resourceID + 1000*(techID or 0) })
			end
		end
	end
	
	table.sort(scienceList, function(a, b) return a.Order < b.Order; end)
	local linesLimit	= 50 -- to do : this should be relative to screen height
	for i, data in ipairs(scienceList) do
		if i < linesLimit then
			table.insert(stringTable, data.String)
		elseif i == linesLimit then
			table.insert(stringTable, "[...]")
		end
	end
	
	return stringTable
end

function GetResourcesStockStringTable(self, resourceToolTipTab, resourceToolTipMode)
	local cityKey 			= self:GetKey()
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey	= GCO.GetPreviousTurnKey()
	local data 				= ExposedMembers.CityData[cityKey]
	local strFull			= ""
	local equipmentList		= {}
	local foodList			= {}
	local strategicList		= {}
	local otherList			= {}
	local scienceList		= {}
	local stringTable		= {["Equipment"] = {}, ["Food"] = {}, ["Strategic"] = {}, ["Other"] = {}, ["Science"] = {}, }
	if not data.Stock[turnKey] then return end
local count = 0
	for resourceKey, value in pairs(data.Stock[turnKey]) do
		local resourceID 		= tonumber(resourceKey)
		---[[
--Dline(count)
count = count + 1
--Dline(resourceKey, type(resourceKey))
--Dline(value, type(value))
if type(value) == "table" then for k, v in pairs(value) do print(k,v) end
else 
--]]
		if (value + self:GetAverageSupplyAtTurn(resourceID) + self:GetDemandAtTurn(resourceID, previousTurnKey) + self:GetDemandAtTurn(resourceID, turnKey) > 0 and resourceKey ~= personnelResourceKey) then -- and resourceKey ~= foodResourceKey

			local stockVariation 	= self:GetStockVariation(resourceID)
			local resourceCost 		= self:GetResourceCost(resourceID)
			local costVariation 	= self:GetResourceCostVariation(resourceID)
			local resRow 			= GameInfo.Resources[resourceID]
			local str 				= ""
			local bIsEquipmentMaker = GCO.IsResourceEquipmentMaker(resourceID)
			local product 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Product, turnKey))
			local collect 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Collect, turnKey))
			local localProd			= product + collect
			local sDisabled			= "X"
			local sNoTransfer		= resRow.NoTransfer and sDisabled
			local sNoExport			= resRow.NoExport and sDisabled
			local sNoTrade			= resRow.NoTransfer and resRow.NoExport and sDisabled

			local import 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Import, previousTurnKey))--GCO.Round(self:GetAverageUseTypeOnTurns(resourceID, ResourceUseType.Import, 3))-- -- all other players cities have not exported their resource at the beginning of the player turn, so get previous turn value
			local transferIn 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.TransferIn, turnKey))--GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.TransferIn, turnKey))
	 		local pillage 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Pillage, turnKey))
	 		local otherIn 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.OtherIn, turnKey))
			
			local consume 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Consume, turnKey))
	 		local export 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Export, turnKey))
	 		local transferOut 		= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.TransferOut, turnKey))
	 		local supply 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Supply, turnKey))
	 		local stolen 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.Stolen, previousTurnKey)) --GCO.Round(self:GetAverageUseTypeOnTurns(resourceID, ResourceUseType.Stolen, 3))-- all other players units have not attacked yet at the beginning of the player turn, so get previous turn value
	 		local otherOut 			= GCO.Round(self:GetUseTypeAtTurn(resourceID, ResourceUseType.OtherOut, turnKey))
	
			local bSimpleMode		= (resourceModes[resourceToolTipMode] == "LOC_CITYBANNER_TOOLTIP_RESOURCE_SIMPLE_MOD")
			local bCondensedMode	= (resourceModes[resourceToolTipMode] == "LOC_CITYBANNER_TOOLTIP_RESOURCE_CONDENSED_MOD")
			
			if bCondensedMode then -- unique mode
			
				local tradeIn	= import + transferIn + pillage + otherIn
				local tradeOut	= export + transferOut + supply + stolen + otherOut
				
				str = GCO.GetResourceIcon(resourceID)
				str = str .. " " .. Indentation(Locale.Lookup(resRow.Name), 9)
				
				if localProd > 0 then
					str = str .. " |+" .. Indentation(localProd, 3, true).."/-"..Indentation(consume, 3, true)
				else
					str = str .. " | " .. Indentation("0", 3, true).."/-"..Indentation(consume, 3, true)
				end
				
				if tradeIn > 0 then
					str = str .. " |+" .. Indentation(tradeIn, 3, true).."/-"..Indentation(tradeOut, 3, true)
				else
					str = str .. " | " .. Indentation(sNoTrade or "0", 3, true).."/-"..Indentation(sNoTrade or tradeOut, 3, true)
				end
				
				str = str .. " |" .. Indentation(value, 4, true) .."/"..Indentation(self:GetMaxStock(resourceID), 4, true)
				str = str .. " |" .. (stockVariation < 0 and "[COLOR_Civ6Red]-"..Indentation(-stockVariation, 3, true) or "[COLOR_Civ6Green]+"..Indentation(stockVariation, 3, true)) .."[ENDCOLOR]"
				str = str .. " |[COLOR_Gold]" .. Indentation(resourceCost, 4, true).."[ENDCOLOR]"
				str = str .. " " .. (costVariation < 0 and "[COLOR_Civ6Green]-"..Indentation(-costVariation, 4, true) or "[COLOR_Civ6Red]+"..Indentation(costVariation, 4, true)) .."[ENDCOLOR]"
				str = str .. "[NEWLINE]"
			
			elseif resourceTabs[resourceToolTipTab] == "LOC_CITYBANNER_TOOLTIP_STOCK_TAB" then
			
				--test Indentation(str, maxLength, bAlignRight, bShowSpace)
				str = GCO.GetResourceIcon(resourceID)
				
				if bSimpleMode then
					local bShowSpace 	= true
					local bAlignRight	= false
					str = str .. " " .. Indentation(Locale.Lookup(resRow.Name).." ", 14, bAlignRight, bShowSpace)
					str = str .. " | " .. Indentation(value, 4, true) .."/"..Indentation(self:GetMaxStock(resourceID), 4, true)
					str = str .. " | " .. (stockVariation < 0 and "[COLOR_Civ6Red]-"..Indentation(-stockVariation, 3, true) or "[COLOR_Civ6Green]+"..Indentation(stockVariation, 3, true)) .."[ENDCOLOR]"
				else
					str = str .. " " .. Indentation(Locale.Lookup(resRow.Name), 8)
					if product > 0 and product > collect then
						str = str .. "|[ICON_Charges]+" .. Indentation(localProd, 3, true)
					elseif collect > 0 then
						str = str .. "|[ICON_Terrain]+" ..Indentation(localProd, 3, true)
					else
						str = str .. "|[ICON_INDENT] " .. Indentation("0", 3, true)
					end
					str = str .. "|" .. Indentation(value, 4, true) .."/"..Indentation(self:GetMaxStock(resourceID), 4, true)
					str = str .. "| " .. (stockVariation < 0 and "[COLOR_Civ6Red]-"..Indentation(-stockVariation, 3, true) or "[COLOR_Civ6Green]+"..Indentation(stockVariation, 3, true)) .."[ENDCOLOR]"
				end
				str = str .. "| [COLOR_Gold]" .. Indentation(resourceCost, 4, true).."[ENDCOLOR]"
				str = str .. " " .. (costVariation < 0 and "[COLOR_Civ6Green]-"..Indentation(-costVariation, 4, true) or "[COLOR_Civ6Red]+"..Indentation(costVariation, 4, true)) .."[ENDCOLOR]"
				str = str .. "[NEWLINE]"
				
			elseif resourceTabs[resourceToolTipTab] == "LOC_CITYBANNER_TOOLTIP_PRODUCTION_TAB" then
			
				str = GCO.GetResourceIcon(resourceID)
				
				if bSimpleMode then
					str = str .. " " .. Indentation(Locale.Lookup(resRow.Name), 9)
					if product > 0 and product > collect then
						str = str .. "|[ICON_Charges]+" .. Indentation(localProd, 3, true)
					elseif collect > 0 then
						str = str .. "|[ICON_Terrain]+" ..Indentation(localProd, 3, true)
					else
						str = str .. "|[ICON_INDENT] " .. Indentation("0", 3, true)
					end
					str = str .. "|-" .. Indentation(consume, 3, true)
					str = str .. "|" .. Indentation(value, 4, true) .."/"..Indentation(self:GetMaxStock(resourceID), 4, true)
					str = str .. "|" .. (stockVariation < 0 and "[COLOR_Civ6Red]-"..Indentation(-stockVariation, 3, true) or "[COLOR_Civ6Green]+"..Indentation(stockVariation, 3, true)) .."[ENDCOLOR]"
					str = str .. "| [COLOR_Gold]" .. Indentation(resourceCost, 4, true).."[ENDCOLOR]"
					str = str .. " " .. (costVariation < 0 and "[COLOR_Civ6Green]-"..Indentation(-costVariation, 4, true) or "[COLOR_Civ6Red]+"..Indentation(costVariation, 4, true)) .."[ENDCOLOR]"
					str = str .. "[NEWLINE]"
				else
					-- special case for detailed consumption to get City (construction), building or population usage
					local buildingUsage	= 0
					local popUsage		= 0
					local cityUsage		= 0
					if data.ResourceUse and data.ResourceUse[turnKey] then
						local useData = data.ResourceUse[turnKey][resourceKey]
						if useData and useData[ResourceUseType.Consume] then
							for key, value in pairs(useData[ResourceUseType.Consume]) do
								if key ~= NO_REFERENCE_KEY then
									if string.find(key, ",") then -- this is a city or unit key
										cityUsage		= cityUsage + value
									elseif string.len(key) > 5 then -- this lenght means Population type string
										popUsage		= popUsage + value
									else -- buildingKey
										buildingUsage	= buildingUsage + value
									end
								end
							end
						end
					end
					str = str .. " " .. Indentation(Locale.Lookup(resRow.Name), 9)
					if product > 0 and product > collect then
						str = str .. "|[ICON_Charges]+" .. Indentation(localProd, 3, true)
					elseif collect > 0 then
						str = str .. "|[ICON_Terrain]+" ..Indentation(localProd, 3, true)
					else
						str = str .. "|[ICON_INDENT] " .. Indentation("-", 3, true)
					end
					str = str .. "|-" .. Indentation(buildingUsage, 3, true)
					str = str .. "|-" .. Indentation(cityUsage, 3, true)
					str = str .. "|-" .. Indentation(popUsage, 3, true)
					str = str .. "|" .. Indentation(value, 4, true) .."/"..Indentation(self:GetMaxStock(resourceID), 4, true)
					str = str .. "|" .. (stockVariation < 0 and "[COLOR_Civ6Red]-"..Indentation(-stockVariation, 3, true) or "[COLOR_Civ6Green]+"..Indentation(stockVariation, 3, true)) .."[ENDCOLOR]"
					str = str .. "[NEWLINE]"
				
				end
				
			elseif resourceTabs[resourceToolTipTab] == "LOC_CITYBANNER_TOOLTIP_TRADE_TAB" then
			
				str = GCO.GetResourceIcon(resourceID)
				
				if bSimpleMode then
					local trade			= import + transferIn - export - transferOut
					local supply		= pillage - supply
					local bShowSpace 	= true
					local bAlignRight	= false
					str = str .. " " .. Indentation(Locale.Lookup(resRow.Name).." ", 14, bAlignRight, bShowSpace)
					if trade > 0 then
						str = str .. " |+" .. Indentation(trade, 4, true)
					elseif trade < 0 then
						str = str .. " |-" .. Indentation(-trade, 4, true)
					else
						str = str .. " | " .. Indentation(sNoTrade or trade, 4, true)					
					end
					if supply > 0 then
						str = str .. " |+" .. Indentation(supply, 4, true)
					elseif supply < 0 then
						str = str .. " |-" .. Indentation(-supply, 4, true)
					else
						str = str .. " | " .. Indentation(supply, 4, true)					
					end
					str = str .. " | " .. (stockVariation < 0 and "[COLOR_Civ6Red]-"..Indentation(-stockVariation, 3, true) or "[COLOR_Civ6Green]+"..Indentation(stockVariation, 3, true)) .."[ENDCOLOR]"
					str = str .. "| [COLOR_Gold]" .. Indentation(resourceCost, 4, true).."[ENDCOLOR]"
					str = str .. " " .. (costVariation < 0 and "[COLOR_Civ6Green]-"..Indentation(-costVariation, 4, true) or "[COLOR_Civ6Red]+"..Indentation(costVariation, 4, true)) .."[ENDCOLOR]"
				else
					str = str .. " " .. Indentation(Locale.Lookup(resRow.Name), 6)
					str = str .. "|+" .. Indentation(sNoExport or import, 3, true).. "/-" .. Indentation(sNoExport or export, 3, true)
					str = str .. "|+" .. Indentation(sNoTransfer or transferIn, 3, true).. "/-" .. Indentation(sNoTransfer or transferOut, 3, true)
					str = str .. "|+" .. Indentation(pillage, 3, true).. "/-" .. Indentation(supply, 3, true)
					
					--str = str .. "|" .. Indentation(value, 4, true) .."/"..Indentation(self:GetMaxStock(resourceID), 4, true)
					str = str .. "|" .. (stockVariation < 0 and "[COLOR_Civ6Red]-"..Indentation(-stockVariation, 3, true) or "[COLOR_Civ6Green]+"..Indentation(stockVariation, 3, true)) .."[ENDCOLOR]"
					str = str .. "|[COLOR_Gold]" .. Indentation(resourceCost, 4, true).."[ENDCOLOR]"
				end
				str = str .. "[NEWLINE]"
				
			else
				GCO.Warning("resourceToolTipTab not registered :", resourceToolTipTab)
			end
			
			if GCO.IsKnowledgeResource(resourceID) then
				-- separate function
			elseif GCO.IsResourceEquipment(resourceID) then
				table.insert(equipmentList, { String = str, Order = EquipmentInfo[resourceID].Desirability })
			elseif resRow.ResourceClassType == "RESOURCECLASS_STRATEGIC" or bIsEquipmentMaker then			
			
				local equipmentMaker = 0
				if bIsEquipmentMaker then equipmentMaker = 1 end
				table.insert(strategicList, { String = str, Order = equipmentMaker })
			elseif GCO.IsResourceFood(resourceID) or resourceKey == foodResourceKey then
				table.insert(foodList, { String = str, Order = value })
			elseif resourceKey ~= foodResourceKey then -- everything else
				table.insert(otherList, { String = str, Order = value })
			end			
		end
end
	end
	table.sort(equipmentList, function(a, b) return a.Order > b.Order; end)
	table.sort(strategicList, function(a, b) return a.Order > b.Order; end)
	table.sort(foodList, function(a, b) return a.Order > b.Order; end)
	table.sort(otherList, function(a, b) return a.Order > b.Order; end)
	for i, data in ipairs(equipmentList) do
		table.insert(stringTable["Equipment"], data.String)
	end
	for i, data in ipairs(strategicList) do
		table.insert(stringTable["Strategic"], data.String)
	end
	for i, data in ipairs(foodList) do
		table.insert(stringTable["Food"], data.String)
	end
	for i, data in ipairs(otherList) do
		table.insert(stringTable["Other"], data.String)
	end
	return stringTable
end

function GetFoodStockString(self)
	local maxFoodStock 			= self:GetMaxStock(foodResourceID)
	local foodStock 			= self:GetStock(foodResourceID)
	local foodStockVariation 	= self:GetStockVariation(foodResourceID)
	local cityRationning 		= self:GetFoodRationing()

	local resourceCost 			= self:GetResourceCost(foodResourceID)
	local costVariation 		= self:GetResourceCostVariation(foodResourceID)

	local pctFood				= Div(foodStock, maxFoodStock) * 100
	local str 					= Locale.Lookup("LOC_CITYBANNER_FOOD_PERCENTAGE", GCO.GetPercentBarString(pctFood), pctFood) .. "[NEWLINE]"-- ..Locale.Lookup("LOC_TOOLTIP_SEPARATOR")--""
	if cityRationning <= Starvation then
		str = str ..Locale.Lookup("LOC_CITYBANNER_FOOD_RATION_STARVATION", foodStock, maxFoodStock)
	elseif cityRationning <= heavyRationing then
		str = str ..Locale.Lookup("LOC_CITYBANNER_FOOD_RATION_HEAVY_RATIONING", foodStock, maxFoodStock)
	elseif cityRationning <= mediumRationing then
		str = str ..Locale.Lookup("LOC_CITYBANNER_FOOD_RATION_MEDIUM_RATIONING", foodStock, maxFoodStock)
	elseif cityRationning <= lightRationing then
		str = str ..Locale.Lookup("LOC_CITYBANNER_FOOD_RATION_LIGHT_RATIONING", foodStock, maxFoodStock)
	else
		str = str ..Locale.Lookup("LOC_CITYBANNER_FOOD_RATION", foodStock, maxFoodStock)
	end
	str = str ..GCO.GetVariationString(foodStockVariation)

	local costVarStr = GCO.GetVariationStringRedPositive(costVariation)
	if resourceCost > 0 then
		str = str .." (".. Locale.Lookup("LOC_CITYBANNER_RESOURCE_COST", resourceCost)..costVarStr..")"
	end

	return str
end

function GetFoodStockIcon(self)
	local cityRationning 		= self:GetFoodRationing()
	local str 					= "[ICON_FoodSurplus]"
	if cityRationning <= Starvation then
		str = "[ICON_FoodDeficit]"
	elseif cityRationning <= heavyRationing then
		str = "[ICON_FoodDeficit]"
	elseif cityRationning <= mediumRationing then
		str = "[ICON_FoodRationing]"
	elseif cityRationning <= lightRationing then
		str = "[ICON_FoodPerTurn]"
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

function GetPopulationNeedsEffectsString(self) -- draft for a global string

	if not self:GetCached("NeedsEffects") then self:SetNeedsValues() end

	local returnStrTable 	= {}
	local NeedsEffects		= self:GetCached("NeedsEffects") or {}
	local needClasses		= {UpperClassID, MiddleClassID, LowerClassID}
	table.insert(returnStrTable, Locale.Lookup("LOC_BIRTHRATE_PER_1000", self:GetBirthRate()))
	table.insert(returnStrTable, Locale.Lookup("LOC_DEATHRATE_PER_1000", self:GetDeathRate()))
	table.insert(returnStrTable, Locale.Lookup("LOC_TOOLTIP_SEPARATOR_NO_LB"))

	if NeedsEffects then --and _cached[cityKey].NeedsEffects[populationID] then
		for populationID, data1 in pairs(NeedsEffects) do
		-- for _, populationID in pairs(needClasses) do 
			--local data1 = NeedsEffects[populationID]
			if BirthRateFactor[populationID] then
				table.insert(returnStrTable, "[ICON_BULLET]"..Locale.Lookup(GameInfo.Resources[populationID].Name) .. ": " .. Locale.Lookup("LOC_BIRTHRATE_PER_1000_SHORT", self:GetPopulationBirthRate(populationID)).." "..Locale.Lookup("LOC_DEATHRATE_PER_1000_SHORT", self:GetPopulationDeathRate(populationID)) )
			else
				table.insert(returnStrTable, "[ICON_BULLET]"..Locale.Lookup(GameInfo.Resources[populationID].Name))
			end
			for needsEffectType, data2 in pairs(data1) do
				if needsEffectType == NeedsEffectType.Consumption then
					for resourceID, value in pairs(data2) do
						table.insert(returnStrTable, "[ICON_INDENT][ICON_BULLET]"..Locale.Lookup("LOC_RESOURCE_CONSUMED_BY_NEED", GameInfo.Resources[resourceID].Name, GCO.GetResourceIcon(resourceID), value))
					end				
				else
					for locString, value in pairs(data2) do
						table.insert(returnStrTable, "[ICON_INDENT][ICON_BULLET]"..Locale.Lookup(locString, value))
					end
				end
			end
		end
	end		

	return table.concat(returnStrTable, "[NEWLINE]")
end

function GetHousingToolTip(self)
	local upperClass		= self:GetUpperClass()
	local middleClass		= self:GetMiddleClass()
	local lowerClass		= self:GetLowerClass()
	local slaveClass		= self:GetSlaveClass()
	local upperHousingSize	= self:GetCustomYield( GameInfo.CustomYields["YIELD_UPPER_HOUSING"].Index )
	local upperHousing		= GCO.GetPopulationPerSize(upperHousingSize)
	local upperHousingAvailable	= math.max( 0, upperHousing - upperClass)
	local upperLookingForMiddle	= math.max( 0, upperClass - upperHousing)
	local middleHousingSize	= self:GetCustomYield( GameInfo.CustomYields["YIELD_MIDDLE_HOUSING"].Index )
	local middleHousing		= GCO.GetPopulationPerSize(middleHousingSize)
	local middleHousingAvailable	= math.max( 0, middleHousing - middleClass - upperLookingForMiddle)
	local middleLookingForLower		= math.max( 0, (middleClass + upperLookingForMiddle) - middleHousing)
	local lowerHousingSize	= self:GetCustomYield( GameInfo.CustomYields["YIELD_LOWER_HOUSING"].Index )
	local lowerHousing		= GCO.GetPopulationPerSize(lowerHousingSize)
	local lowerHousingAvailable	= math.max( 0, lowerHousing - lowerClass - middleLookingForLower)
	
	local realPopulation	= self:GetRealPopulation()
	local maxPopulation		= upperHousing + middleHousing + lowerHousing + slaveClass -- slave class doesn't use housing space	

	local housingToolTip	= Locale.Lookup("LOC_HUD_CITY_TOTAL_HOUSING", realPopulation, maxPopulation)
	housingToolTip	= housingToolTip .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") ..Locale.Lookup("LOC_HUD_CITY_UPPER_HOUSING", upperHousing - upperHousingAvailable, upperHousing)
	if upperClass - upperLookingForMiddle > 0 then
		housingToolTip		= housingToolTip .. "[NEWLINE][ICON_Bullet]" .. Locale.Lookup("LOC_CITYBANNER_UPPER_CLASS", upperClass - upperLookingForMiddle)
	end
	
	housingToolTip	= housingToolTip .. "[NEWLINE]" .. Locale.Lookup("LOC_HUD_CITY_MIDDLE_HOUSING", middleHousing - middleHousingAvailable, middleHousing)
	if upperLookingForMiddle > 0 then
		housingToolTip		= housingToolTip .. "[NEWLINE][ICON_Bullet]" .. Locale.Lookup("LOC_CITYBANNER_UPPER_CLASS", upperLookingForMiddle)
	end
	if middleClass - middleLookingForLower > 0 then
		housingToolTip		= housingToolTip .. "[NEWLINE][ICON_Bullet]" .. Locale.Lookup("LOC_CITYBANNER_MIDDLE_CLASS", middleClass - middleLookingForLower)
	end
	
	housingToolTip	= housingToolTip .. "[NEWLINE]" .. Locale.Lookup("LOC_HUD_CITY_LOWER_HOUSING", lowerHousing - lowerHousingAvailable, lowerHousing)
	if middleLookingForLower > 0 then
		housingToolTip		= housingToolTip .. "[NEWLINE][ICON_Bullet]" .. Locale.Lookup("LOC_CITYBANNER_MIDDLE_CLASS", middleLookingForLower)
	end
	if lowerClass > 0 then
		housingToolTip		= housingToolTip .. "[NEWLINE][ICON_Bullet]" .. Locale.Lookup("LOC_CITYBANNER_LOWER_CLASS", lowerClass)
	end
	return housingToolTip
end

function GetAdministrativeCostText(self)
	local adminEfficiency 	= self:GetAdministrativeEfficiency()
	local adminCost			= self:GetAdministrativeCost()
	local popCost, popValue	= self:GetpopulationAdministrativeCost()
	local landCost, surface	= self:GetTerritoryAdministrativeCost()
	local bldFactor, numBld	= self:GetBuildingsAdministrativeFactor()
	local techFactor 		= self:GetTechAdministrativeFactor()
	local SupportTable		= self:GetAdministrativeSupport()
	local adminSupport		= GCO.TableSummation(SupportTable)

	return Locale.Lookup("LOC_CITYBANNER_ADMINISTRATIVE_COST_DETAILS", adminEfficiency, adminCost, popCost, popValue, landCost, surface, bldFactor, numBld, techFactor, adminSupport, SupportTable.Yield, SupportTable.Resources)
end

function GetSeaRangeToolTip(self)
	local eEffectType		= "RAISE_CITY_SEA_RANGE"
	local value, list 		= self:GetModifiersForEffect(eEffectType)
	local applicationText	= GCO.GetEffectApplicationText(eEffectType)
	local strTable			= {Locale.Lookup(GCO.GetEffectName(eEffectType)) .. " = ".. tostring(value)}
	if not self:GetBuildings():HasBuilding(GameInfo.Buildings["BUILDING_CITY_SHIPYARD"].Index) then
		table.insert(strTable, Locale.Lookup("LOC_CITYBANNER_HARBOR_REQUIRED"))
	end
	-- for a small text separation
	--table.insert(strTable, "[NEWLINE]")
	for i, row in ipairs(list) do
		table.insert(strTable, "[ICON_BULLET]"..Locale.Lookup(applicationText,row.Value,row.Name))
	end
	return table.concat(strTable, "[NEWLINE]")
end


-----------------------------------------------------------------------------------------
-- Do Turn for Cities
-----------------------------------------------------------------------------------------
function SetCityRationing(self)
	Dlog("SetCityRationing ".. Locale.Lookup(self:GetName()).." /START")
	local DEBUG_CITY_SCRIPT = DEBUG_CITY_SCRIPT
	--if Locale.Lookup(self:GetName()) =="Nidaros" then DEBUG_CITY_SCRIPT = "debug" end

	Dprint( DEBUG_CITY_SCRIPT, "Set Rationing...")
	local cityKey 				= self:GetKey()
	local cityData 				= ExposedMembers.CityData[cityKey]
	local ratio 				= cityData.FoodRatio
	local foodStock 			= self:GetFoodStock()
	local previousTurn			= tonumber(GCO.GetPreviousTurnKey())
	local previousTurnSupply 	= self:GetSupplyAtTurn(foodResourceID, previousTurn)
	local foodSent 				= GCO.Round(self:GetUseTypeAtTurn(foodResourceID, ResourceUseType.Export, previousTurn)) +  GCO.Round(self:GetUseTypeAtTurn(foodResourceID, ResourceUseType.TransferOut, previousTurn))
	local normalRatio 			= 1
	local foodVariation 		= previousTurnSupply - self:GetFoodConsumption(normalRatio) -- self:GetStockVariation(foodResourceID) can't use stock variation here, as it will be equal to 0 when consumption > supply and there is not enough stock left (consumption capped at stock left...)
	local consumptionRatio		= math.min(normalRatio, Div(previousTurnSupply, self:GetFoodConsumption(normalRatio))) -- GetFoodConsumption returns a value >= 1

--Dline(" Food stock = ", foodStock," Variation = ",foodVariation, " Previous turn supply = ", previousTurnSupply, " Wanted = ", self:GetFoodConsumption(normalRatio), " Actual Consumption = ", self:GetFoodConsumption(), " Export+Transfer = ", foodSent, " Actual ratio = ", ratio, " Turn(s) locked left = ", (RationingTurnsLocked - (Game.GetCurrentGameTurn() - cityData.FoodRatioTurn)), " Consumption ratio = ",  consumptionRatio)

	Dprint( DEBUG_CITY_SCRIPT, " Food stock = ", foodStock," Variation = ",foodVariation, " Previous turn supply = ", previousTurnSupply, " Wanted = ", self:GetFoodConsumption(normalRatio), " Actual Consumption = ", self:GetFoodConsumption(), " Export+Transfer = ", foodSent, " Actual ratio = ", ratio, " Turn(s) locked left = ", (RationingTurnsLocked - (Game.GetCurrentGameTurn() - cityData.FoodRatioTurn)), " Consumption ratio = ",  consumptionRatio)

	--[[
	if foodVariation < 0 and foodSent == 0 and foodStock < self:GetMaxStock(foodResourceID) * 0.75 then
		local turnBeforeFamine		= -Div(foodStock, foodVariation)
		Dprint( DEBUG_CITY_SCRIPT, " Turns Before Starvation = ", turnBeforeFamine)
		if foodStock == 0 then
			ratio = math.max(consumptionRatio, Starvation)
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif turnBeforeFamine <= turnsToFamineHeavy then
			ratio = math.max(consumptionRatio, heavyRationing) -- Always use the maximum available supply, do not generate surplus food when rationing...
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif turnBeforeFamine <= turnsToFamineMedium then
			ratio = math.max(consumptionRatio, mediumRationing)
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif turnBeforeFamine <= turnsToFamineLight then
			ratio = math.max(consumptionRatio, lightRationing)
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		end
	elseif Game.GetCurrentGameTurn() - cityData.FoodRatioTurn >= RationingTurnsLocked then
		if cityData.FoodRatio <= heavyRationing then
			ratio = math.max(consumptionRatio, mediumRationing)
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif cityData.FoodRatio <= mediumRationing then
			ratio = math.max(consumptionRatio, lightRationing)
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif cityData.FoodRatio <= lightRationing then
			ratio = consumptionRatio
		end
	end
	--]]
	
	-- simple
	ratio = math.max(Starvation, math.min(1, consumptionRatio))
	
	Dprint( DEBUG_CITY_SCRIPT, " Final Ratio = ", ratio)
	ExposedMembers.CityData[cityKey].FoodRatio = GCO.ToDecimals(ratio)
	Dlog("SetCityRationing /END")
end

function UpdateCosts(self)

	Dlog("UpdateCosts ".. Locale.Lookup(self:GetName()).." /START")
	local DEBUG_CITY_SCRIPT = DEBUG_CITY_SCRIPT
	--if Locale.Lookup(self:GetName()) =="Kyoto" then DEBUG_CITY_SCRIPT = "debug" end
	local cityKey 			= self:GetKey()
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey 	= GCO.GetPreviousTurnKey()

	-- update local prices
	local stockData = ExposedMembers.CityData[cityKey].Stock[turnKey]
	for resourceKey, value in pairs(stockData) do
		if resourceKey ~= personnelResourceKey then

			local resourceID 		= tonumber(resourceKey)
			local bCanUpdateCost 	= not GameInfo.Resources[resourceID].FixedPrice -- true
			
			--[[
			if GCO.IsResourceEquipment(resourceID) 	then
				bCanUpdateCost = not EquipmentInfo[resourceID].FixedPrice
			end
			--]]
			
			if bCanUpdateCost then
				local previousTurn	= tonumber(previousTurnKey)
				local demand 		= self:GetDemand(resourceID) -- include real demand for food (GetDemandAtTurn return the real use with rationing)
				local supply		= self:GetSupplyAtTurn(resourceID, previousTurn)

				local varPercent	= 0
				local maxVarPercent	= GameInfo.Resources[resourceID].MaxPriceVariationPercent
				local stock 		= self:GetStock(resourceID)
				local maxStock		= self:GetMaxStock(resourceID)
				local actualCost	= self:GetResourceCost(resourceID)
				local minCost		= self:GetMinimumResourceCost(resourceID)
				local maxCost		= self:GetMaximumResourceCost(resourceID)
				local newCost 		= actualCost

				Dprint( DEBUG_CITY_SCRIPT, "- Actualising cost of "..Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name))," actual cost.. ".. tostring(actualCost)," stock ",stock," maxStock ",maxStock," demand ",demand," supply ",supply)

				if supply > demand or stock >= maxStock then
					local turnUntilFull = 0
					if stock < maxStock then
						turnUntilFull = Div((maxStock - stock), (supply - demand)) -- (don't worry, supply - demand > 0 if we're here)
					end
					if turnUntilFull == 0 then
						varPercent = math.min(maxVarPercent, MaxCostReductionPercent)
					else
						varPercent = math.min(maxVarPercent, MaxCostReductionPercent, Div(1, (Div(turnUntilFull, (maxStock / 2)))))
					end
					local variation = math.min(actualCost * varPercent / 100, (actualCost - minCost) / 2)
					newCost = math.max(minCost, math.min(maxCost, actualCost - variation))
					self:SetResourceCost(resourceID, newCost)
					Dprint( DEBUG_CITY_SCRIPT, "          ........... "..Indentation20("...").." new cost..... ".. Indentation8(newCost).. "  max cost ".. Indentation8(maxCost).." min cost ".. Indentation8(minCost).." turn until full ".. Indentation8(turnUntilFull).." variation ".. Indentation8(variation))
				elseif demand > supply then

					local turnUntilEmpty = Div(stock, (demand - supply))
					if turnUntilEmpty == 0 then
						varPercent = math.min(maxVarPercent, MaxCostIncreasePercent)
					else
						varPercent = math.min(maxVarPercent, MaxCostIncreasePercent, Div(1, (Div(turnUntilEmpty, (maxStock / 2)))))
					end
					local variation = math.min(actualCost * varPercent / 100, (maxCost - actualCost) / 2)
					newCost = math.max(minCost, math.min(maxCost, actualCost + variation))
					self:SetResourceCost(resourceID, newCost)
					Dprint( DEBUG_CITY_SCRIPT, "          ........... "..Indentation20("...").." new cost..... ".. Indentation8(newCost).. "  max cost ".. Indentation8(maxCost).." min cost ".. Indentation8(minCost).." turn until empty ".. Indentation8(turnUntilEmpty).." variation ".. Indentation8(variation))
				end
			end
		end
	end
	
	Dlog("UpdateCosts ".. Locale.Lookup(self:GetName()).." /STOP")
end

function UpdateDataOnNewTurn(self) -- called for every player at the beginning of a new turn

	Dlog("UpdateDataOnNewTurn ".. Locale.Lookup(self:GetName()).." /START")
	--local DEBUG_CITY_SCRIPT = false

	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Updating Data for ".. Locale.Lookup(self:GetName()))

	if Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then -- don't update on first turn (NewTurn is called on the first turn of a later era start)
		GCO.Warning("Aborting UpdateDataOnNewTurn for cities, this is the first turn !")
		return
	end
	
	local cityKey 			= self:GetKey()
	local data 				= ExposedMembers.CityData[cityKey]
	local turnKey 			= GCO.GetTurnKey()
	local previousTurnKey 	= GCO.GetPreviousTurnKey()
	if turnKey ~= previousTurnKey then

		Dprint( DEBUG_CITY_SCRIPT, "cityKey = ", cityKey, " turnKey = ", turnKey, " previousTurnKey = ", previousTurnKey)
		
		-- get previous turn data
		local stockData = data.Stock[previousTurnKey]
		local costData 	= data.ResourceCost[previousTurnKey]
		local popData 	= data.Population[previousTurnKey]
		
		-- when using the "enforce TSL option" from YnAMP, the entry may have already been set (and theere is no previous entries) no need to update in that case
		-- if there is neither previous turn and current turn data, output an Error message before aborting
		if stockData 	== nil then if not data.Stock[turnKey] 			then GCO.Error("stockData[previousTurnKey] = nil"); return	else return end end
		if costData 	== nil then if not data.ResourceCost[turnKey]	then GCO.Error("costData[previousTurnKey] = nil"); return	else return end end
		if popData 		== nil then if not data.Population[turnKey]		then GCO.Error("popData[previousTurnKey] = nil"); return	else return end end

		-- initialize empty tables for the new turn data
		data.Stock[turnKey] 		= {}
		data.ResourceCost[turnKey]	= {}
		data.Population[turnKey]	= {}
		data.ResourceUse[turnKey]	= {}
		
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
	Dlog("UpdateDataOnNewTurn /END")
end

function SetUnlockers(self)
	Dlog("SetUnlockers ".. Locale.Lookup(self:GetName()).." /START")
	
	local DEBUG_CITY_SCRIPT = DEBUG_CITY_SCRIPT	
	--if GameInfo.Units["UNIT_HORSEMAN"].Index == unitID and Game.GetLocalPlayer() == self:GetOwner() then DEBUG_CITY_SCRIPT = "debug" end
	--if self:GetBuildings():HasBuilding(GameInfo.Buildings["BUILDING_PALACE"].Index) and Game.GetLocalPlayer() == self:GetOwner() then SetDebugLevel("debug") end

	Dprint( DEBUG_CITY_SCRIPT, "Setting unlocker buildings for ".. Locale.Lookup(self:GetName()), " production = ", self:GetProductionYield())

	local pCityBuildQueue = self:GetBuildQueue()

	for row in GameInfo.Buildings() do
		local unlocker = "UNLOCKER_".. tostring(row.BuildingType)
		if GameInfo.Buildings[unlocker] then
			local unlockerID = GameInfo.Buildings[unlocker].Index
			if not row.Unlockers and GCO.CityCanProduce(self, row.Hash) and self:CanConstruct(row.BuildingType) then
				if not self:GetBuildings():HasBuilding(unlockerID) then
					Dprint( DEBUG_CITY_SCRIPT, "Adding unlocker : ", unlocker)
					pCityBuildQueue:CreateIncompleteBuilding(unlockerID, 100)
				end
			else
				if self:GetBuildings():HasBuilding(unlockerID) and self:GetBuildQueue():CurrentlyBuilding() ~= row.BuildingType then
					Dprint( DEBUG_CITY_SCRIPT, "Removing unlocker : ", unlocker)
					self:GetBuildings():RemoveBuilding(unlockerID);
					pCityBuildQueue:RemoveBuilding(unlockerID);
				end
			end
		end
	end

	for row in GameInfo.Units() do
		local unlocker = "UNLOCKER_".. tostring(row.UnitType)
		if GameInfo.Buildings[unlocker] then
			local unlockerID = GameInfo.Buildings[unlocker].Index
			if self:CanTrain(row.UnitType) then --GCO.CityCanProduce(self, row.Hash) return false everytime for units...
				if not self:GetBuildings():HasBuilding(unlockerID) then
					Dprint( DEBUG_CITY_SCRIPT, "Adding unlocker : ", unlocker)
					pCityBuildQueue:CreateIncompleteBuilding(unlockerID, 100)
				end
			else
				local player = Players[self:GetOwner()]
				if self:GetBuildings():HasBuilding(unlockerID) and (self:GetBuildQueue():CurrentlyBuilding() ~= row.UnitType or not player:IsHuman()) then
					Dprint( DEBUG_CITY_SCRIPT, "Removing unlocker : ", unlocker)
					self:GetBuildings():RemoveBuilding(unlockerID);
					pCityBuildQueue:RemoveBuilding(unlockerID);
				end
			end
		end
	end
	
	--if self:GetBuildings():HasBuilding(GameInfo.Buildings["BUILDING_PALACE"].Index) and Game.GetLocalPlayer() == self:GetOwner() then RestorePreviousDebugLevel() end

	Dlog("SetUnlockers ".. Locale.Lookup(self:GetName()).." /STOP")
end

function DoRecruitPersonnel(self)
	
	Dlog("DoRecruitPersonnel ".. Locale.Lookup(self:GetName()).." /START")
	--local DEBUG_CITY_SCRIPT = "debug"
	Dprint( DEBUG_CITY_SCRIPT, "Recruiting Personnel...")
	local player			= GCO.GetPlayer(self:GetOwner())
	local populationRatio	= player:GetArmyPersonnelPopulationRatio()
	local nedded 			= math.max(0, self:GetMaxPersonnel() - self:GetPersonnel()) * populationRatio
	
	local maxDraftedPercentage	= player:GetMaxDraftedPercentage()
	local draftedPercentage		= player:GetDraftedPercentage()
	local draftRatio			= player:GetDraftEfficiencyPercent() / 100

	local generals			= GCO.Round(nedded*PersonnelHighRankRatio)
	local officers			= GCO.Round(nedded*PersonnelMiddleRankRatio)
	local soldiers			= math.max(0, nedded - (generals + officers))

	local maxUpper 			= GCO.Round(self:GetUpperClass()	* UpperClassToPersonnelRatio	* draftRatio)
	local maxMiddle			= GCO.Round(self:GetMiddleClass()	* MiddleClassToPersonnelRatio	* draftRatio)
	local maxLower 			= GCO.Round(self:GetLowerClass()	* LowerClassToPersonnelRatio	* draftRatio)
	local maxPotential		= maxUpper + maxMiddle + maxLower

	local recruitedGenerals = math.min(generals, maxUpper)
	local recruitedOfficers = math.min(officers, maxMiddle)
	local recruitedSoldiers = math.min(soldiers, maxLower)
	local totalRecruits		= recruitedGenerals + recruitedOfficers + recruitedSoldiers

	Dprint( DEBUG_CITY_SCRIPT, " - total needed =", nedded, "generals =", generals,"officers =", officers, "soldiers =",soldiers)
	Dprint( DEBUG_CITY_SCRIPT, " - maxDraftedPercentage in army =", maxDraftedPercentage, "current draftedPercentage =", draftedPercentage, " draftRatio =", draftRatio)
	Dprint( DEBUG_CITY_SCRIPT, " - max potential =", maxPotential ,"Upper = ", maxUpper, "Middle = ", maxMiddle, "Lower = ", maxLower )
	Dprint( DEBUG_CITY_SCRIPT, " - total recruits =", totalRecruits, "Generals = ", recruitedGenerals, "Officers = ", recruitedOfficers, "Soldiers = ", recruitedSoldiers )

	self:ChangeUpperClass(-recruitedGenerals)
	self:ChangeMiddleClass(-recruitedOfficers)
	self:ChangeLowerClass(-recruitedSoldiers)
	self:ChangePersonnel(math.floor(Div(recruitedGenerals,populationRatio)), ResourceUseType.Recruit, RefPopulationUpper)
	self:ChangePersonnel(math.floor(Div(recruitedOfficers,populationRatio)), ResourceUseType.Recruit, RefPopulationMiddle)
	self:ChangePersonnel(math.floor(Div(recruitedSoldiers,populationRatio)), ResourceUseType.Recruit, RefPopulationLower)
	
	Dlog("DoRecruitPersonnel /END")
end

function DoReinforceUnits(self)
	Dlog("DoReinforceUnits ".. Locale.Lookup(self:GetName()).." /START")
	--local DEBUG_CITY_SCRIPT = "CityScript"

	Dprint( DEBUG_CITY_SCRIPT, "Reinforcing units...")
	local cityKey 				= self:GetKey()
	local cityData 				= ExposedMembers.CityData[cityKey]
	local supplyDemand 			= UnitsSupplyDemand[cityKey]
	local player 				= GCO.GetPlayer(self:GetOwner())
	local reinforcements 		= {Resources = {}, ResPerUnit = {}}	
	local pendingTransaction	= {}
	
	if not LinkedUnits[cityKey] then self:UpdateLinkedUnits() end

	for resourceID, value in pairs(supplyDemand.Resources) do
		reinforcements.Resources[resourceID] = math.min(value, self:GetAvailableStockForUnits(resourceID))
		reinforcements.ResPerUnit[resourceID] = math.floor(Div(reinforcements.Resources[resourceID],supplyDemand.NeedResources[resourceID]))
		Dprint( DEBUG_CITY_SCRIPT, "- Max transferable ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)).. " = ".. tostring(value), " for " .. tostring(supplyDemand.NeedResources[resourceID]), " units, available = " .. tostring(self:GetAvailableStockForUnits(resourceID)), ", send = ".. tostring(reinforcements.Resources[resourceID]))
	end
	
	local reqValue = {}
	for resourceID, value in pairs(reinforcements.Resources) do
		local resLeft = value
		local maxLoop = 5
		local loop = 0
		while (resLeft > 0 and loop < maxLoop) do
			for unitKey, data in pairs(LinkedUnits[cityKey]) do
				local unit = GCO.GetUnitFromKey ( unitKey )
				if unit and not unit:IsDisbanding() then
					if not reqValue[unit] then reqValue[unit] = {} end
					
					if reqValue[unit].FullReinforcement == nil then reqValue[unit].FullReinforcement = unit:CanGetFullReinforcement() end
					local bTotal = reqValue[unit].FullReinforcement
					
					local efficiency
					if bTotal then 
						efficiency = 100
					else
						efficiency = unit:GetSupplyLineEfficiency()
					end
					
					if not reqValue[unit][resourceID] then reqValue[unit][resourceID] = GCO.Round(unit:GetNumResourceNeeded(resourceID, bTotal)*efficiency/100) end
					if reqValue[unit][resourceID] > 0 then
					
						local send = math.min(reinforcements.ResPerUnit[resourceID], reqValue[unit][resourceID], resLeft)

						resLeft = resLeft - send
						reqValue[unit][resourceID] = reqValue[unit][resourceID] - send

						unit:ChangeStock(resourceID, send)
						self:ChangeStock(resourceID, -send, ResourceUseType.Supply, unit:GetKey())						
						
						local cost 					= self:GetResourceCost(resourceID) * send						
						pendingTransaction[unitKey] = (pendingTransaction[unitKey] or 0) + cost

						Dprint( DEBUG_CITY_SCRIPT, "  - send ".. tostring(send)," ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)) .." (@ ".. tostring(efficiency), " percent efficiency), cost = "..tostring(cost), " to unit key#".. tostring(unit:GetKey()), Locale.Lookup(UnitManager.GetTypeName(unit)))
					end
				end
			end
			loop = loop + 1
		end
	end

	local totalCost = 0
	for unitKey, cost in pairs(pendingTransaction) do
		if cost > 0 then -- personnel is free, some other resources maybe.
			totalCost = totalCost + cost
			local unit = GCO.GetUnitFromKey(unitKey)
			if unit then			
				--self:RecordTransaction(AccountType.Reinforce, cost, unitKey)
				--unit:RecordTransaction(AccountType.Reinforce, -cost, cityKey)
				local sText = Locale.Lookup("LOC_GOLD_FOR_REINFORCEMENT", GCO.ToDecimals(cost))
				if Game.GetLocalPlayer() == unit:GetOwner() then Game.AddWorldViewText(EventSubTypes.PLOT, sText, unit:GetX(), unit:GetY(), 0) end
			end
		end
	end
	
	if totalCost > 0 then
		player:ProceedTransaction(AccountType.Reinforce, -totalCost)
	end
	
	-- Now remove excedent from units
	local totalIncome = 0
	for unitKey, _ in pairs(LinkedUnits[cityKey]) do
		local unit = GCO.GetUnitFromKey ( unitKey )
		if unit then
			if reqValue[unit] and reqValue[unit].FullReinforcement then -- force a full internal transfer now if the unit was on a city or a (military related) district
				local bLimitTransfer = false
				unit:DoInternalEquipmentTransfer( bLimitTransfer )
			end
			local unitExcedent 	= unit:GetAllSurplus()
			local unitData 		= ExposedMembers.UnitData[unitKey]
			if unitData then
				-- Send excedent back to city
				local income = 0
				for resourceID, value in pairs(unitExcedent) do
					local toTransfert = math.min(self:GetMaxStock(resourceID) - self:GetStock(resourceID), value)
					if resourceID == personnelResourceID 	then toTransfert = value end -- city can convert surplus in personnel to population
					if GCO.IsResourceEquipment(resourceID)  then toTransfert = value end -- don't allow units to keep equipment surplus
					if toTransfert > 0 then
						local sellPrice = math.max(self:GetMinimumResourceCost(resourceID), self:GetResourceCost(resourceID) / 2)
						income		= income + (sellPrice * toTransfert)
						unit:ChangeStock(resourceID, -toTransfert)
						self:ChangeStock(resourceID, toTransfert, ResourceUseType.Pillage, unitKey, sellPrice)
						
						Dprint( DEBUG_CITY_SCRIPT, "  - received " .. tostring(toTransfert) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." from ".. Locale.Lookup(unit:GetName()) .." that had an excedent of ".. tostring(value))
					end
				end
				
				if income > 0 then
					totalIncome = totalIncome + income
					--self:RecordTransaction(AccountType.Plundering, -income, unitKey)
					--unit:RecordTransaction(AccountType.Plundering, income, cityKey)					
					local sText = Locale.Lookup("LOC_GOLD_FROM_PLUNDERING", GCO.ToDecimals(income))
					if Game.GetLocalPlayer() == unit:GetOwner() then Game.AddWorldViewText(EventSubTypes.PLOT, sText, unit:GetX(), unit:GetY(), 0) end
				end
				
				-- Send prisoners to city
				local cityData = ExposedMembers.CityData[cityKey]
				for playerKey, number in pairs(unitData.Prisoners) do
					if number > 0 then
						Dprint( DEBUG_CITY_SCRIPT, "  - received " .. tostring(number) .." " .. Locale.Lookup( PlayerConfigurations[tonumber(playerKey)]:GetPlayerName() ) .. " prisoners from ".. Locale.Lookup(unit:GetName()))
						cityData.Prisoners[playerKey] = cityData.Prisoners[playerKey] + number
						unitData.Prisoners[playerKey] = 0
					end
				end
			end
		end
	end
		
	if totalIncome > 0 then
		player:ProceedTransaction(AccountType.Plundering, totalIncome)	
	end

	Dlog("DoReinforceUnits ".. Locale.Lookup(self:GetName()).." /END")
end

function DoCollectResources(self)

	Dlog("DoCollectResources ".. Locale.Lookup(self:GetName()).." /START")
	Dprint( DEBUG_CITY_SCRIPT, "-- Collecting Resources...")
	--local DEBUG_CITY_SCRIPT = false
	
	local cityKey 		= self:GetKey()
	local cityData 		= ExposedMembers.CityData[cityKey]
	local cityWealth	= self:GetWealth()
	local playerID		= self:GetOwner()
	local player 		= GCO.GetPlayer(playerID)
	local pResearch 	= GCO.Research:Create(playerID)

	-- private function
	function Collect(resourceID, collected, resourceCost, plotID, bWorked, bImprovedForResource)
		if not (bWorked or bImprovedForResource) then
			return
		end
		if bImprovedForResource then
			--collected 		= collected * BaseImprovementMultiplier
			resourceCost 	= resourceCost * ImprovementCostRatio
		end
		resourceCost 	= resourceCost * cityWealth
		collected 		= math.max(1,GCO.Round(collected))
		if not bWorked then resourceCost = resourceCost * NotWorkedCostMultiplier end
		Dprint( DEBUG_CITY_SCRIPT, "-- Collecting " .. tostring(collected) .. " " ..Locale.Lookup(GameInfo.Resources[resourceID].Name).." at ".. tostring(GCO.ToDecimals(resourceCost)) .. " cost/unit")
		self:ChangeStock(resourceID, collected, ResourceUseType.Collect, plotID, resourceCost)
	end

	-- get resources on worked tiles
	local cityPlots	= GCO.GetCityPlots(self)

	-- add sea resources
	local seaRange = self:GetSeaRange()
	if seaRange > 0 then
		local sRouteType 	= "Coastal"
		local pPlayer 		= Players[self:GetOwner()]
		local pTech 		= pPlayer:GetTechs()
		if pTech and pTech:HasTech(GameInfo.Technologies["TECH_SAILING"].Index) then
			if  pTech:HasTech(GameInfo.Technologies["TECH_CARTOGRAPHY"].Index) then
				sRouteType = "Ocean"
			end
			local cityPlot 		= GCO.GetPlot(self:GetX(), self:GetY())
			local pBuildings	= self:GetBuildings()
			local bHasBoat		= pBuildings:HasBuilding(GameInfo.Buildings["BUILDING_CITY_SHIPYARD"].Index)
			--local pDistricts	= self:GetDistricts()
			--local harbor		= pDistricts:GetDistrict(GameInfo.Districts["DISTRICT_HARBOR"].Index)
			--local bHasBoat		= harbor or pBuildings:HasBuilding(GameInfo.Buildings["BUILDING_LIGHTHOUSE"].Index) or pBuildings:HasBuilding(GameInfo.Buildings["BUILDING_CITY_SHIPYARD"].Index)
			
			--if harbor then
			--	cityPlot 		= GCO.GetPlot(harbor:GetX(), harbor:GetY())
			--end
			
			for ring = 1, seaRange do
				for pEdgePlot in GCO.PlotRingIterator(cityPlot, ring) do
					local plotOwner = pEdgePlot:GetOwner()
					if (plotOwner == self:GetOwner()) or (plotOwner == NO_PLAYER) then
						if (pEdgePlot:IsWater() or pEdgePlot:IsLake()) and pEdgePlot:GetResourceCount() > 0 then
							local bIsPlotConnected 	= false --GCO.IsPlotConnected(pPlayer, cityPlot, pEdgePlot, sRouteType, true, nil, GCO.TradePathBlocked)
							local routeLength		= 0
							GCO.StartTimer("GetPathToPlot"..sRouteType)
							local path = cityPlot:GetPathToPlot(pEdgePlot, pPlayer, sRouteType, GCO.TradePathBlocked, seaRange+1) -- origin count as 1 for distance
							GCO.ShowTimer("GetPathToPlot"..sRouteType)
							if path then
								bIsPlotConnected 	= true
								routeLength 		= #path
							end
							
							if bIsPlotConnected then
								--local routeLength = GCO.GetRouteLength()
								if routeLength <= seaRange + 1  then -- not needed with GetPathToPlot called with seaRange ?
									local resourceID = pEdgePlot:GetResourceType()
									if player:IsResourceVisible(resourceID) then
										if plotOwner == NO_PLAYER then
											table.insert(cityPlots, pEdgePlot:GetIndex())-- owned plots are already in a cityPlots list and are not shared
										end
										Dprint( DEBUG_CITY_SCRIPT, "-- Adding Sea plots for resource collection, route length = ", routeLength, " sea range = ", seaRange, " resource = ", Locale.Lookup(GameInfo.Resources[resourceID].Name), " at ", pEdgePlot:GetX(), pEdgePlot:GetY() )
										if (pEdgePlot:GetImprovementType() == NO_IMPROVEMENT) and bHasBoat then
											local improvementID = GCO.GetResourceImprovementID(resourceID)
											if improvementID then
												ImprovementBuilder.SetImprovementType(pEdgePlot, improvementID, NO_PLAYER)
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	for _, plotID in ipairs(cityPlots) do
		local plot			= GCO.GetPlotByIndex(plotID)
		local bWorked 		= (plot:GetWorkerCount() > 0)
		local bImproved		= (plot:GetImprovementType() ~= NO_IMPROVEMENT)
		local bSeaResource 	= (plot:IsWater() or plot:IsLake())
		local outputFactor	= plot:GetOutputPerYield()
		
		if (bWorked or bImproved or bSeaResource) and not plot:IsCity() then

			if bSeaResource then 
				outputFactor = self:GetOutputPerYield()
			end
			local improvementID = plot:GetImprovementType()
			if bWorked and bImproved then
				LuaEvents.ResearchGCO("EVENT_WORKED_IMPROVEMENT", playerID, plot:GetX(), plot:GetY(), GameInfo.Improvements[improvementID].ImprovementType, self)
			end
			if plot:GetResourceCount() > 0 then
				local resourceID 	= plot:GetResourceType()
				local resourceCost 	= GCO.GetBaseResourceCost(resourceID)
				if player:IsResourceVisible(resourceID) then
					local baseResource			= plot:GetResourceCount()
					local collected 			= baseResource * outputFactor
					local bImprovedForResource	= GCO.IsImprovingResource(improvementID, resourceID)
					if bImprovedForResource then
						collected	= math.max(collected * BaseImprovementMultiplier, baseResource)
						LuaEvents.ResearchGCO("EVENT_WORKED_IMPROVED_RESOURCE", playerID, plot:GetX(), plot:GetY(), GameInfo.Resources[resourceID].ResourceType, self)
					else
						LuaEvents.ResearchGCO("EVENT_WORKED_RESOURCE", playerID, plot:GetX(), plot:GetY(), GameInfo.Resources[resourceID].ResourceType, self)
					end
					Collect(resourceID, collected, resourceCost, plotID, (bWorked or bSeaResource), bImprovedForResource)
				end
			end

			local featureID = plot:GetFeatureType()
			if FeatureResources[featureID] then
				for _, data in pairs(FeatureResources[featureID]) do
					for resourceID, value in pairs(data) do
						if player:IsResourceVisible(resourceID) then
							local collected 			= value * outputFactor
							local resourceCost 			= GCO.GetBaseResourceCost(resourceID)
							local bImprovedForResource	= GCO.IsImprovingResource(improvementID, resourceID)
							if bImprovedForResource then 
								collected	= math.max(collected * BaseImprovementMultiplier, value)
								--LuaEvents.ResearchGCO("EVENT_WORKED_IMPROVED_RESOURCE", playerID, plot:GetX(), plot:GetY(), GameInfo.Resources[resourceID].ResourceType )
							else
								--LuaEvents.ResearchGCO("EVENT_WORKED_RESOURCE", playerID, plot:GetX(), plot:GetY(), GameInfo.Resources[resourceID].ResourceType)
							end
							Collect(resourceID, collected, resourceCost, plotID, bWorked, bImprovedForResource)
						end
					end
				end
			end

			--TerrainResources
			local terrainID = plot:GetTerrainType()
			if TerrainResources[terrainID] then
				for _, data in pairs(TerrainResources[terrainID]) do
					for resourceID, value in pairs(data) do
						if player:IsResourceVisible(resourceID) then
							local collected 			= value * outputFactor
							local resourceCost 			= GCO.GetBaseResourceCost(resourceID)
							local bImprovedForResource	= GCO.IsImprovingResource(improvementID, resourceID)
							if bImprovedForResource then 
								collected	= math.max(collected * BaseImprovementMultiplier, value) 
								--LuaEvents.ResearchGCO("EVENT_WORKED_IMPROVED_RESOURCE", playerID, plot:GetX(), plot:GetY(), GameInfo.Resources[resourceID].ResourceType)
							else
								--LuaEvents.ResearchGCO("EVENT_WORKED_RESOURCE", playerID, plot:GetX(), plot:GetY(), GameInfo.Resources[resourceID].ResourceType)
							end
							Collect(resourceID, collected, resourceCost, plotID, bWorked, bImprovedForResource)
						end
					end
				end
			end
		end
	end
	Dlog("DoCollectResources ".. Locale.Lookup(self:GetName()).." /END")
end

function DoIndustries(self)

	Dlog("DoIndustries ".. Locale.Lookup(self:GetName()).." /START")
	--local DEBUG_CITY_SCRIPT = "CityScript"

	Dprint( DEBUG_CITY_SCRIPT, "Creating resources in Industries...")

	local size 		= self:GetSize()
	local wealth 	= self:GetWealth()
	local player 	= GCO.GetPlayer(self:GetOwner())

	-- materiel production
	local materielprod	= MaterielProductionPerSize * size
	local materielCost 	= GCO.GetBaseResourceCost(materielResourceID) * wealth -- GCO.GetBaseResourceCost(materielResourceID)
	Dprint( DEBUG_CITY_SCRIPT, " - City production: ".. tostring(materielprod) .." ".. Locale.Lookup(GameInfo.Resources[materielResourceID].Name).." at ".. tostring(GCO.ToDecimals(materielCost)) .. " cost/unit")
	self:ChangeStock(materielResourceID, materielprod, ResourceUseType.Product, self:GetKey(), materielCost)

	-- Resources production: creating tables
	local MultiResRequired 	= {}	-- Resources that require multiple resources to be created
	local MultiResCreated 	= {}	-- Resources that create multiple resources
	local ResCreated		= {}	-- Resources that are created from a single resource type
	local ResNeeded			= {}	-- Total resources required 
	for row in GameInfo.BuildingResourcesConverted() do
		local buildingID 	= GameInfo.Buildings[row.BuildingType].Index
		local maxConverted 	= GCO.Round(row.MaxConverted * self:GetOutputPerYield() * RequiredResourceFactor)
		local ratio			= row.Ratio * ProducedResourceFactor
		
		if self:GetBuildings():HasBuilding(buildingID) then
			local resourceRequiredID 	= GameInfo.Resources[row.ResourceType].Index
			local resourceCreatedID 	= GameInfo.Resources[row.ResourceCreated].Index
			if player:IsResourceVisible(resourceCreatedID) and not player:IsObsoleteResource(resourceCreatedID) then -- don't create resources we don't have the tech for or that are obsolete...
				if not ResNeeded[resourceRequiredID] then ResNeeded[resourceRequiredID] = { Value = 0, Buildings = {} } end
				ResNeeded[resourceRequiredID].Value = ResNeeded[resourceRequiredID].Value + maxConverted
				ResNeeded[resourceRequiredID].Buildings[buildingID] = (ResNeeded[resourceRequiredID].Buildings[buildingID] or 0) + maxConverted

				if row.MultiResRequired then
					if not MultiResRequired[resourceCreatedID] then	MultiResRequired[resourceCreatedID] = {} end
					if not MultiResRequired[resourceCreatedID][buildingID] then	MultiResRequired[resourceCreatedID][buildingID] = {} end
					table.insert(MultiResRequired[resourceCreatedID][buildingID], {ResourceRequired = resourceRequiredID, MaxConverted = maxConverted, Ratio = ratio, CostFactor = row.CostFactor })

				elseif row.MultiResCreated then
					if not MultiResCreated[resourceRequiredID] then	MultiResCreated[resourceRequiredID] = {} end
					if not MultiResCreated[resourceRequiredID][buildingID] then	MultiResCreated[resourceRequiredID][buildingID] = {} end
					table.insert(MultiResCreated[resourceRequiredID][buildingID], {ResourceCreated = resourceCreatedID, MaxConverted = maxConverted, Ratio = ratio, CostFactor = row.CostFactor })
				else
					if not ResCreated[resourceRequiredID] then	ResCreated[resourceRequiredID] = {} end
					if not ResCreated[resourceRequiredID][buildingID] then	ResCreated[resourceRequiredID][buildingID] = {} end
					table.insert(ResCreated[resourceRequiredID][buildingID], {ResourceCreated = resourceCreatedID, MaxConverted = maxConverted, Ratio = ratio, CostFactor = row.CostFactor })
				end
			end
		end
	end

	-- Resources production: assign available resources for each building
	local resPerBuilding = {}
	Dprint( DEBUG_CITY_SCRIPT, "- Assign available resources for each building")
	for resourceID, data in pairs(ResNeeded) do
		local totalResNeeded	= data.Value
		local totalResAvailable	= self:GetAvailableStockForIndustries(resourceID)
		if totalResAvailable > 0 then
			Dprint( DEBUG_CITY_SCRIPT, "- Check for .......................... : ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name))..", available = "..tostring(totalResAvailable)," required = "..tostring(totalResNeeded))
			if totalResAvailable >= totalResNeeded then
				for buildingID, value in pairs(data.Buildings) do
					if not resPerBuilding[buildingID] then resPerBuilding[buildingID] = {} end
					resPerBuilding[buildingID][resourceID] = value
					Dprint( DEBUG_CITY_SCRIPT, " - Allocating full requested resources : ".. tostring(value) .." to "..Locale.Lookup(GameInfo.Buildings[buildingID].Name))
				end
			else
				local numBuildings 		= 0
				local buildingConsumptionRatio = {}
				for buildingID, value in pairs(data.Buildings) do
					numBuildings = numBuildings + 1
					buildingConsumptionRatio[buildingID] = Div(value, totalResNeeded)
					Dprint( DEBUG_CITY_SCRIPT, " - Set ratio for ..................... : ".. Indentation20(Locale.Lookup(GameInfo.Buildings[buildingID].Name)) ..", requires = "..tostring(value), ", calculated ratio = "..tostring(Div(value, totalResNeeded)))
				end
				
				for buildingID, _ in pairs(data.Buildings) do
					if not resPerBuilding[buildingID] then resPerBuilding[buildingID] = {} end
					local allocatedRes = math.floor(totalResAvailable * buildingConsumptionRatio[buildingID])
					resPerBuilding[buildingID][resourceID] = allocatedRes
					Dprint( DEBUG_CITY_SCRIPT, " - Allocating .........................: ".. tostring(allocatedRes) .." to "..Locale.Lookup(GameInfo.Buildings[buildingID].Name))
				end
			end
		else
			Dprint( DEBUG_CITY_SCRIPT, "- No ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)).." available, required = "..tostring(totalResNeeded))
			for buildingID, value in pairs(data.Buildings) do
				if not resPerBuilding[buildingID] then resPerBuilding[buildingID] = {} end
				resPerBuilding[buildingID][resourceID] = 0
			end
		end
	end

	-- Resources production: create single resources
	for resourceRequiredID, data1 in pairs(ResCreated) do
		for buildingID, data2 in pairs (data1) do
			for _, row in ipairs(data2) do

				local available = resPerBuilding[buildingID][resourceRequiredID]

				if available > 0 then
					local resourceCreatedID = GameInfo.Resources[row.ResourceCreated].Index
					local amountUsed		= math.min(available, row.MaxConverted)
					local amountCreated		= math.floor(amountUsed * row.Ratio)

					-- don't allow excedent if there is no demand
					local bLimitedByExcedent	= false
					local stockVariation 		= self:GetStockVariation(resourceCreatedID)
					if amountCreated + self:GetStock(resourceCreatedID) > self:GetMaxStock(resourceCreatedID) and stockVariation >= 0 then
						local maxCreated 	= self:GetMaxStock(resourceCreatedID) - self:GetStock(resourceCreatedID)
						amountUsed 			= math.floor(Div(maxCreated, row.Ratio))
						amountCreated		= math.floor(amountUsed * row.Ratio)
						bLimitedByExcedent	= true
					end

					if amountCreated > 0 then
						local costFactor	= row.CostFactor
						local resourceCost 	= (Div(GCO.GetBaseResourceCost(resourceCreatedID), row.Ratio) * wealth * costFactor) + (Div(self:GetResourceCost(resourceRequiredID), row.Ratio))
						Dprint( DEBUG_CITY_SCRIPT, " - " .. Indentation20(Locale.Lookup(GameInfo.Buildings[buildingID].Name)) .." production: ".. tostring(amountCreated), " ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceCreatedID].Name)).." at ".. tostring(GCO.ToDecimals(resourceCost)), " cost/unit, using ".. tostring(amountUsed), " ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name)) ..", limited by excedent = ".. tostring(bLimitedByExcedent))
						self:ChangeStock(resourceRequiredID, - amountUsed, ResourceUseType.Consume, buildingID)
						resPerBuilding[buildingID][resourceRequiredID] = resPerBuilding[buildingID][resourceRequiredID] - amountUsed
						self:ChangeStock(resourceCreatedID, amountCreated, ResourceUseType.Product, buildingID, resourceCost)
					end
				end

			end
		end
	end

	-- Resources production: create multiple Resources from one Resource
	for resourceRequiredID, data1 in pairs(MultiResCreated) do
		for buildingID, data2 in pairs (data1) do
			local bUsed			= false
			local available 	= resPerBuilding[buildingID][resourceRequiredID] --self:GetAvailableStockForIndustries(resourceRequiredID)
			if available > 0 then
				Dprint( DEBUG_CITY_SCRIPT, " - " .. Indentation20(Locale.Lookup(GameInfo.Buildings[buildingID].Name)) .." production of multiple resources using ".. tostring(available), " available ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name))
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
					else -- limit only if all resources created will generate excedents
						bLimitedByExcedent	= false
					end
					maxRequired	= math.max( maxRequired, amountUsed)

					if amountCreated > 0 then
						local costFactor	= row.CostFactor
						local resourceCost 	= (Div(GCO.GetBaseResourceCost(row.ResourceCreated), row.Ratio) * wealth) + Div(self:GetResourceCost(resourceRequiredID), row.Ratio)
						Dprint( DEBUG_CITY_SCRIPT, "    - ".. tostring(amountCreated) .." ".. Indentation20(Locale.Lookup(GameInfo.Resources[row.ResourceCreated].Name)).." created at ".. tostring(GCO.ToDecimals(resourceCost)), " cost/unit, ratio = " .. tostring(row.Ratio), ", used ".. tostring(amountUsed), " ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name)) ..", limited by excedent = ".. tostring(bLimitedByExcedent))
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
					resPerBuilding[buildingID][resourceRequiredID] = resPerBuilding[buildingID][resourceRequiredID] - maxRequired
				end
			end
		end
	end

	-- Resources production: create single Resources from multiple Resources
	for resourceCreatedID, data1 in pairs(MultiResRequired) do
		for buildingID, data2 in pairs (data1) do
			local bCanCreate				= true
			local requiredResourcesRatio 	= {}
			local amountCreated				= nil
			local bLimitedByExcedent		= false
			for _, row in ipairs(data2) do
				if bCanCreate then
					local available = resPerBuilding[buildingID][row.ResourceRequired] --self:GetAvailableStockForIndustries(row.ResourceRequired)
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
							table.insert(requiredResourcesRatio, { ResourceRequiredID = row.ResourceRequired, Ratio = row.Ratio, CostFactor = row.CostFactor })
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
				Dprint( DEBUG_CITY_SCRIPT, " - " .. Indentation20(Locale.Lookup(GameInfo.Buildings[buildingID].Name)) .." production: ".. tostring(amountCreated), " ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceCreatedID].Name)).. " using multiple resource")
				local requiredResourceCost 		= 0
				local totalResourcesRequired 	= #requiredResourcesRatio
				local totalRatio 				= 0
				for i, row in pairs(requiredResourcesRatio) do
					local resourceRequiredID 	= row.ResourceRequiredID
					local ratio 				= row.Ratio
					local amountUsed 			= GCO.Round(Div(amountCreated, ratio)) -- we shouldn't be here if ratio = 0, and the rounded value should be < maxAmountUsed
					local resourceCost 			= Div(self:GetResourceCost(resourceRequiredID), ratio) * row.CostFactor
					requiredResourceCost = requiredResourceCost + resourceCost
					totalRatio = totalRatio + ratio
					Dprint( DEBUG_CITY_SCRIPT, "    - ".. tostring(amountUsed) .." ".. Indentation20(Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name)) .." used at ".. tostring(GCO.ToDecimals(resourceCost)), " cost/unit, ratio = " .. tostring(ratio))
					self:ChangeStock(resourceRequiredID, - amountUsed, ResourceUseType.Consume, buildingID)
					resPerBuilding[buildingID][resourceRequiredID] = resPerBuilding[buildingID][resourceRequiredID] - amountUsed
				end
				local baseRatio = Div(totalRatio, totalResourcesRequired)
				resourceCost = (Div(GCO.GetBaseResourceCost(resourceCreatedID), baseRatio) * wealth ) + requiredResourceCost
				Dprint( DEBUG_CITY_SCRIPT, "    - " ..  Indentation20(Locale.Lookup(GameInfo.Resources[resourceCreatedID].Name)).. " cost per unit  = ".. tostring(resourceCost), ", limited by excedent = ".. tostring(bLimitedByExcedent))
				self:ChangeStock(resourceCreatedID, amountCreated, ResourceUseType.Product, buildingID, resourceCost)
			end
		end
	end
	Dlog("DoIndustries ".. Locale.Lookup(self:GetName()).." /END")
end

function DoConstruction(self)

	Dlog("DoConstruction ".. Locale.Lookup(self:GetName()).." /START")
	--local DEBUG_CITY_SCRIPT = "CityScript"
	Dprint( DEBUG_CITY_SCRIPT, "Getting resources for Constructions...")

	local cityKey			= self:GetKey()
	local currentlyBuilding	= self:GetBuildQueue():CurrentlyBuilding() -- return hash
	local turnsLeft 		= self:GetProductionTurnsLeft(currentlyBuilding)
	local production 		= self:GetProductionYield()
	local row				= GameInfo.Units[currentlyBuilding] or GameInfo.Buildings[currentlyBuilding]
	local bIsUnit			= (GameInfo.Units[currentlyBuilding] ~= nil)
	local bIsBuilding		= (GameInfo.Buildings[currentlyBuilding] ~= nil)
	local progress			= 0
	local efficiency		= 1
	local totalCost			= 0
	
	if row and production > 0 then

		if bIsUnit 		then progress = self:GetProductionProgress(ProductionTypes.UNIT, row.Index) end
		if bIsBuilding 	then progress = self:GetProductionProgress(ProductionTypes.BUILDING, row.Index) end

		local turnsToBuild 	= math.max(1, math.ceil(row.Cost / production))
		local buildCost		= row.Cost
		local prodLeft		= buildCost - progress
		Dprint( DEBUG_CITY_SCRIPT, "Total turns To Build = " .. tostring(turnsToBuild), " Turns left = " .. tostring(turnsLeft), " progress = " .. tostring(progress), " prodCost = "..tostring(buildCost), " left = "..tostring(prodLeft), " To build : ".. tostring(currentlyBuilding) )

		local resTable 			= {} -- mandatory resources
		local resOrTable 		= {} -- mandatory resources from OR list
		local resOptionalTable	= {} -- optional resources from OR list
		
		local player			= GCO.GetPlayer(self:GetOwner())	
		local organizationLevel = player:GetMilitaryOrganizationLevel()

		if bIsUnit 		then resTable 			= GCO.GetUnitConstructionResources(row.Index, organizationLevel) end
		if bIsUnit 		then resOrTable 		= GCO.GetUnitConstructionOrResources(row.Index, organizationLevel) end
		if bIsUnit 		then resOptionalTable 	= GCO.GetUnitConstructionOptionalResources(row.Index, organizationLevel) end
		if bIsBuilding 	then resTable 			= GCO.GetBuildingConstructionResources(row.Index) end

		-- Get construction efficiency from global resources...
		local usedTable = {}
		for resourceID, value in pairs(resTable) do
			local neededPerTurn 	= math.ceil( Div((value - self:GetBuildingQueueStock(resourceID, currentlyBuilding)), turnsLeft))
			Dprint( DEBUG_CITY_SCRIPT, "Need : ".. tostring(neededPerTurn), " " ..Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)).. ", Actual Stock = " .. Indentation15(tostring(self:GetStock(resourceID))).. " (Resource)" )
			usedTable[resourceID] = neededPerTurn
			if neededPerTurn > self:GetStock(resourceID) then efficiency = math.min(efficiency, Div(self:GetStock(resourceID), neededPerTurn)) end
		end

		-- Get construction efficiency from mandatory equipment (OR list)
		for equipmentClass, resourceTable in pairs(resOrTable) do
			local totalNeeded 		= resourceTable.Value
			local alreadyStocked 	= 0
			-- get the number of resource already stocked for that class...
			for _, resourceID in ipairs(resourceTable.Resources) do -- loop through the possible resources (ordered by desirability) for that class
				alreadyStocked = alreadyStocked + self:GetBuildingQueueStock(resourceID, currentlyBuilding)
			end
			if totalNeeded > alreadyStocked then -- we may already have enough of that resource/equipment in the reserved stock
				local neededPerTurn 		= math.ceil( Div((totalNeeded-alreadyStocked), turnsLeft )) -- total needed for that class at 100% production efficiency
				local numResourceToProvide	= neededPerTurn
				local totalClass			= 0
				for _, resourceID in ipairs(resourceTable.Resources) do -- loop through the possible resources (ordered by desirability) for that class
					if numResourceToProvide > 0 then
						local stock = self:GetStock(resourceID)
						totalClass = totalClass + stock
						if stock >= numResourceToProvide then
							numResourceToProvide	= 0
						else
							numResourceToProvide	= numResourceToProvide - stock
						end
					end
				end
				local providedResources = (neededPerTurn - numResourceToProvide)
				Dprint( DEBUG_CITY_SCRIPT, "Need : ".. tostring(neededPerTurn), " " ..Indentation20(Locale.Lookup(GameInfo.EquipmentClasses[equipmentClass].Name)).. ", Actual Stock = " .. Indentation15(tostring(totalClass)).. " (Equipment)" )

				if numResourceToProvide > 0 	then
					efficiency = math.min(efficiency, Div(providedResources, neededPerTurn))
				end
			else -- if we already have enough of that resource/equipment, mark it...
				resOrTable[equipmentClass].Value = 0
			end
		end

		-- Efficiency value is set, we can use the global resources...
		Dprint( DEBUG_CITY_SCRIPT, "Calculated Efficiency = ", efficiency )
		for resourceID, value in pairs(usedTable) do
			local used = math.ceil(value * efficiency)
			
			-- add cost
			local cost 	= self:GetResourceCost(resourceID) * used
			totalCost 	= totalCost + cost

			Dprint( DEBUG_CITY_SCRIPT, "Using : ".. tostring(used), " " .. Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)) .. Indentation15(" Cost = "..tostring(cost)) .. " Actual Stock = ".. tostring(self:GetStock(resourceID)) )
			
			-- add to building queue stock
			self:ChangeBuildingQueueStock(resourceID, currentlyBuilding, used)

			-- remove from city stock
			self:ChangeStock(resourceID, -used, ResourceUseType.Consume, cityKey)
		end
		-- reset usedTable for OR resources...
		usedTable = {}

		-- Now get the equipment needed for that turn at the calculated production efficiency...
		-- from mandatory equipment (OR list)
		for equipmentClass, resourceTable in pairs(resOrTable) do
			local neededPerTurn 		= math.ceil( Div(resourceTable.Value, turnsToBuild) * efficiency) -- needed at calculated efficiency for that class
			local numResourceToProvide	= neededPerTurn
			for _, resourceID in ipairs(resourceTable.Resources) do -- loop through the possible resources (ordered by desirability) for that class
				if numResourceToProvide > 0 then
					local stock = self:GetStock(resourceID)
					if stock >= numResourceToProvide then
						usedTable[resourceID] 	= numResourceToProvide
						numResourceToProvide	= 0
					else
						usedTable[resourceID] 	= stock
						numResourceToProvide	= numResourceToProvide - stock
					end
				end
			end
		end

		-- from optional equipment (OR list)
		for equipmentClass, resourceTable in pairs(resOptionalTable) do
			local neededPerTurn 		= math.ceil( Div(resourceTable.Value, turnsToBuild) * efficiency ) -- needed at calculated efficiency for that class
			local numResourceToProvide	= neededPerTurn
			for _, resourceID in ipairs(resourceTable.Resources) do -- loop through the possible resources (ordered by desirability) for that class
				if numResourceToProvide > 0 then
					local stock = self:GetStock(resourceID)
					if stock >= numResourceToProvide then
						usedTable[resourceID] 	= numResourceToProvide
						numResourceToProvide	= 0
					else
						usedTable[resourceID] 	= stock
						numResourceToProvide	= numResourceToProvide - stock
					end
				end
			end
		end

		-- Get the resources (value is already set based on efficiency here)
		for resourceID, value in pairs(usedTable) do

			local cost 	= self:GetResourceCost(resourceID) * value
			totalCost 	= totalCost + cost
			Dprint( DEBUG_CITY_SCRIPT, "Using : ".. tostring(value), " "..Indentation20(Locale.Lookup(GameInfo.Resources[resourceID].Name)).. Indentation15(" Cost = "..tostring(cost)) .. " Actual Stock = " .. tostring(self:GetStock(resourceID)) )

			-- add to building queue stock
			self:ChangeBuildingQueueStock(resourceID, currentlyBuilding, value)

			-- remove from city stock
			self:ChangeStock(resourceID, -value, ResourceUseType.Consume, cityKey)
			
		end

		if efficiency < 1 then
			local actualProd 	= math.floor(math.min(production, prodLeft) * efficiency)
			local lostProd		= production - actualProd
			Dprint( DEBUG_CITY_SCRIPT, "Under 100 percent efficiency: Max Production = ", production, " Production Left = ", prodLeft, " Actualized Production = ", actualProd, " Wasted Production = ", lostProd)

			-- At this point in the code, the production value is not added yet to the current item in build queue
			-- we nullify this turn production by removing it before it's applied (to prevent item spawning when it's the last turn of production)
			-- we'll add the real value based on efficiency when Events.CityProductionUpdated is called
			
			-- to do, maybe, to prevent unexpected behavior on first turn: 
			-- 1/ calculate progressBasedOnEfficiency = (current production + actualProd)
			-- 2/ set current progress to 0 here
			-- 3/ update current progress to progressBasedOnEfficiency when Events.CityProductionUpdated is called
			
			-- to do : check if we can set a negative progression value, in that case no need of the 1-2-3 above, the AddProgress(- production)
			-- below is enough for all cases (including items requiring a total of production < 1 turn of city yield)
			
			self:GetBuildQueue():AddProgress(- production) 
			if not _cached.RealProduction then _cached.RealProduction = {} end
			_cached.RealProduction[cityKey] = actualProd

		end
		
		player:ProceedTransaction(AccountType.Production, -totalCost)
	end

	-- save efficiency value for UI call
	self:SetConstructionEfficiency(GCO.ToDecimals(efficiency))

	Dlog("DoConstruction ".. Locale.Lookup(self:GetName()).." /END")
end

function DoStockDecay(self)

	Dlog("DoStockDecay ".. Locale.Lookup(self:GetName()).." /START")
	Dprint( DEBUG_CITY_SCRIPT, "Resource decay...")

	-- 
	for resourceKey, value in pairs(self:GetResources()) do
		local resourceID	= tonumber(resourceKey)
		local stock			= self:GetStock(resourceID)
		local row			= GameInfo.Resources[resourceID]
		
		--
		if stock > 0 and row.DecayRate then
			local decay = GCO.ToDecimals(math.max(0, stock - self:GetDemand(resourceID)) * row.DecayRate / 100)
			self:ChangeStock(resourceID, -decay, ResourceUseType.Waste)
		end
	end

	Dlog("DoStockDecay ".. Locale.Lookup(self:GetName()).." /END")
end

function DoStockUpdate(self)

	Dlog("DoStockUpdate ".. Locale.Lookup(self:GetName()).." /START")
	Dprint( DEBUG_CITY_SCRIPT, "Handling excedent...")

	local cityKey 			= self:GetKey()
	local cityData 			= ExposedMembers.CityData[cityKey]
	local turnKey 			= GCO.GetTurnKey()
	local player 			= GCO.GetPlayer(self:GetOwner())
	local populationRatio	= player:GetArmyPersonnelPopulationRatio()

	-- surplus personnel is sent back to civil life... (to do : send them to another location if available)
	local excedentalPersonnel = self:GetPersonnel() - self:GetMaxPersonnel()

	if excedentalPersonnel > 0 then

		local toUpper 	= GCO.Round(excedentalPersonnel * PersonnelToUpperClassRatio)
		local toMiddle 	= GCO.Round(excedentalPersonnel * PersonnelToMiddleClassRatio)
		local toLower	= math.max(0, excedentalPersonnel - (toMiddle + toUpper))

		self:ChangeUpperClass(toUpper * populationRatio)
		self:ChangeMiddleClass(toMiddle * populationRatio)
		self:ChangeLowerClass(toLower * populationRatio)

		self:ChangePersonnel(-toUpper, ResourceUseType.Demobilize, RefPopulationUpper)
		self:ChangePersonnel(-toMiddle, ResourceUseType.Demobilize, RefPopulationMiddle)
		self:ChangePersonnel(-toLower, ResourceUseType.Demobilize, RefPopulationLower)

		Dprint( DEBUG_CITY_SCRIPT, " - Demobilized personnel = ", excedentalPersonnel, " upper class = ", toUpper," middle class = ", toMiddle, " lower class = ",toLower)

	end

	-- Check resources stock, remove surplus
	for resourceKey, value in pairs(cityData.Stock[turnKey]) do
		local resourceID	= tonumber(resourceKey)
		local excedent		= 0
		local stock			= self:GetStock(resourceID)
		local row			= GameInfo.Resources[resourceID]
		
		-- Studying resource
		if stock > 0 then
			local plot	= self:GetPlot()
			LuaEvents.ResearchGCO("EVENT_RESOURCE_IN_STOCK", self:GetOwner(), plot:GetX(), plot:GetY(), row.ResourceType, self)
		end
		
		-- Some resource decay
		--[[
		if row.DecayRate then
			local decay = GCO.ToDecimals(math.max(0, stock - self:GetDemand(resourceID)) * row.DecayRate / 100)
			stock 		= stock - decay
			self:ChangeStock(resourceID, -decay, ResourceUseType.Waste)
		end
		--]]
		
		-- Obsolete equipment is removed at a faster rate
		if player:IsObsoleteResource(resourceID) then
			if self:GetNumRequiredInQueue(resourceID) == 0 then
				excedent = math.ceil(stock * SurplusWasteFastPercent / 100)
			end		
		-- Used resources are removed at a slower rate	
		elseif self:GetDemand(resourceID) > 0 or self:GetNumRequiredInQueue(resourceID) > 0 then
			excedent = math.ceil((stock - self:GetMaxStock(resourceID)) * SurplusWasteSlowPercent / 100)
		-- Non used resources are removed at normal rate
		else
			excedent = math.ceil((stock - self:GetMaxStock(resourceID)) * SurplusWastePercent / 100)
		end
		
		if excedent > 0 then
			Dprint( DEBUG_CITY_SCRIPT, " - Surplus destroyed = ".. tostring(excedent).." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name))
			self:ChangeStock(resourceID, -excedent, ResourceUseType.Waste)
		end
	end

	Dlog("DoStockUpdate ".. Locale.Lookup(self:GetName()).." /END")
end

function DoGrowth(self)

	Dlog("DoGrowth ".. Locale.Lookup(self:GetName()).." /START")
	
	local DEBUG_CITY_SCRIPT 	= DEBUG_CITY_SCRIPT
	--if Game.GetLocalPlayer() 	== self:GetOwner() then DEBUG_CITY_SCRIPT = "debug" end

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
	
	function CalculateVar(initialPopulation, populationBirthRate, populationDeathRate )
		return GCO.Round( initialPopulation	* years * LimitRate(populationBirthRate, populationDeathRate) / 1000)
	end
	
	local popTable	= {UpperClassID, MiddleClassID, LowerClassID, SlaveClassID}
	for i, populationID in ipairs(popTable) do
		local birthRate	= self:GetPopulationBirthRate(populationID)
		local deathRate	= self:GetPopulationDeathRate(populationID)
		if birthRate >= deathRate then -- population growth occurs on city center
			local number = self:GetPopulationClass(populationID) + math.floor(self:GetRuralPopulationClass(populationID) / 2)  -- half influence outside city
			if number > 0 then
				local variation	= CalculateVar( number, birthRate, deathRate)
				Dprint( DEBUG_CITY_SCRIPT, "URBAN POPULATION " ..Indentation8("City") .. " <<< " .. Indentation20(Locale.Lookup(GameInfo.Resources[populationID].Name)).." : BirthRate = ", birthRate, " DeathRate = ", deathRate, " Initial Population = ", number, " Variation = ", variation )
				self:ChangePopulationClass(populationID, variation)
			end
		else	-- population loss is occuring on all tiles
			local number = self:GetPopulationClass(populationID)
			if number > 0 then
				local variation	= CalculateVar( number, birthRate, deathRate)
				Dprint( DEBUG_CITY_SCRIPT, "URBAN POPULATION " ..Indentation8("City") .. " <<< " .. Indentation20(Locale.Lookup(GameInfo.Resources[populationID].Name)).." : BirthRate = ", birthRate, " DeathRate = ", deathRate, " Initial Population = ", number, " Variation = ", variation )
				self:ChangePopulationClass(populationID, variation)
				local cityPlots	= GCO.GetCityPlots(self)
				for _, plotID in ipairs(cityPlots) do			
					local plot = GCO.GetPlotByIndex(plotID)
					if plot and (not plot:IsCity() or plot:IsWater()) then
						local number 	= math.floor(plot:GetPopulationClass(populationID) / 2) -- half influence outside city
						local variation	= CalculateVar( number, birthRate, deathRate)
						Dprint( DEBUG_CITY_SCRIPT, "Rural Population " ..Indentation8(plot:GetX() ..",".. plot:GetY()) .. " >>> " .. Indentation20(Locale.Lookup(GameInfo.Resources[populationID].Name)).." : BirthRate = ", birthRate, " DeathRate = ", deathRate, " Initial Population = ", number, " Variation = ", variation )
						plot:ChangePopulationClass(populationID, variation)
					end
				end
			end
		end
	end
end

function DoFood(self)

	Dlog("DoFood ".. Locale.Lookup(self:GetName()).." /START")
	-- get city food yield. Todo : switch to collect on plots with employment activity on plots
	local foodYield		= GCO.ToDecimals(self:GetCityYield(YieldTypes.FOOD )) --* self:GetOutputPerYield())
	local resourceCost	= GCO.GetBaseResourceCost(foodResourceID) * self:GetWealth() * ImprovementCostRatio -- assume that city food yield is low cost (like collected with improvement)
	self:ChangeStock(foodResourceID, foodYield, ResourceUseType.Collect, self:GetKey(), resourceCost)

	-- Food eaten is calculated in DoNeeds()
	
	-- prepared Food
	local normalRatio	= 1
	local consumption	= self:GetFoodConsumption(normalRatio)
	local foodNeeded	= (consumption * FoodPreparationFactor) - foodYield
	if foodNeeded > 0 then
		local sortedFood	= {}
		for _, resourceID in ipairs(GCO.GetEdibleFoodList()) do
			if resourceID ~= foodResourceID then
				table.insert(sortedFood, {ResourceID = resourceID, DecayRate = GameInfo.Resources[resourceID].DecayRate or 0 })
			end
		end
		table.sort(sortedFood, function(a, b) return a.DecayRate > b.DecayRate; end)
		
		for _, row in ipairs(sortedFood) do
			local resourceID 	= row.ResourceID
			local used			= math.min(foodNeeded, self:GetStock(resourceID))
			if used > 0 then
				self:ChangeStock(foodResourceID, used, ResourceUseType.Product, self:GetKey(), self:GetResourceCost(resourceID))
				self:ChangeStock(resourceID, -used, ResourceUseType.Consume, self:GetKey())
				foodNeeded = foodNeeded - used
			end
		end
	end
	
	Dlog("DoFood ".. Locale.Lookup(self:GetName()).." /END")
end

function DoNeeds(self)
	Dlog("DoNeeds ".. Locale.Lookup(self:GetName()).." /START")
	--local DEBUG_CITY_SCRIPT = "CityScript"

	Dprint( DEBUG_CITY_SCRIPT, "handling Population needs...")
	
	local cache 		= self:GetCache() or {}
	local NeedsEffects	= cache.NeedsEffects
	if NeedsEffects then --and _cached[cityKey].NeedsEffects[populationID] then
		for populationID, data in pairs(NeedsEffects) do
			local consumption = data[NeedsEffectType.Consumption] 
			if consumption then
				for resourceID, value in pairs(consumption) do
					self:ChangeStock(resourceID, - value, ResourceUseType.Consume, PopulationRefFromID[populationID])
				end
			end
		end
	end
	Dlog("DoNeeds ".. Locale.Lookup(self:GetName()).." /END")
end

function SetNeedsValues(self)

	Dlog("SetNeedsValues ".. Locale.Lookup(self:GetName()).." /START")
	--local DEBUG_CITY_SCRIPT = "CityScript"

	Dprint( DEBUG_CITY_SCRIPT, "Setting Population needs...")

	--
	-- (re)initialize cached table
	--
	local cache 		= self:GetCache()
	cache.NeedsEffects 	= {
		--[UpperClassID] 	= { [NeedsEffectType.BirthRate] = {},  [NeedsEffectType.DeathRate] = {},	[NeedsEffectType.SocialStratification] = {},	[NeedsEffectType.SocialStratificationReq] = {},},
		--[MiddleClassID] = { [NeedsEffectType.BirthRate] = {},  [NeedsEffectType.DeathRate] = {},	[NeedsEffectType.SocialStratification] = {},	[NeedsEffectType.SocialStratificationReq] = {},},
		--[LowerClassID] 	= { [NeedsEffectType.BirthRate] = {},  [NeedsEffectType.DeathRate] = {},	[NeedsEffectType.SocialStratification] = {},	[NeedsEffectType.SocialStratificationReq] = {},},
	}
	local NeedsEffects	= cache.NeedsEffects

	--
	-- Private functions
	--	
	local GetMaxPercentFromLowDiff 	= GCO.GetMaxPercentFromLowDiff	-- Return a higher value if lowerValue is high 	(maxEffectValue, higherValue, lowerValue)
	local GetMaxPercentFromHighDiff = GCO.GetMaxPercentFromHighDiff	-- Return a higher value if lowerValue is low	(maxEffectValue, higherValue, lowerValue)
	local LimitEffect				= GCO.LimitEffect				-- Keep effectValue never equals to maxEffectValue (maxEffectValue, effectValue)
	
	function AddNeeds(populationID, EffectType, locKey, value)
		if not NeedsEffects[populationID] then NeedsEffects[populationID] = {} end
		if not NeedsEffects[populationID][EffectType] then NeedsEffects[populationID][EffectType] = {} end
		NeedsEffects[populationID][EffectType][locKey] = value
	end

	local upperPopulation		= self:GetPopulationClass(UpperClassID)
	local middlePopulation		= self:GetPopulationClass(MiddleClassID)
	local lowerPopulation		= self:GetPopulationClass(LowerClassID)
	local slavePopulation		= self:GetPopulationClass(SlaveClassID)

	--
	-- Handle Death Rate first, Population can compensate with higher birth Rate...
	--
	
	Dprint( DEBUG_CITY_SCRIPT, "Eating ----------")

	local rationing 	= self:GetFoodRationing()
	local availableFood = self:GetStock(foodResourceID)

	Dprint( DEBUG_CITY_SCRIPT, "Available food = ", availableFood, " rationing = ", rationing)

	-- Food for personnel
	local personnelNeed		= self:GetPersonnel() * PersonnelFoodConsumption / 1000
	local personnelRation	= personnelNeed * rationing
	local personnelFood		= GCO.ToDecimals(math.min(availableFood, personnelRation))
	availableFood 			= availableFood - personnelFood
	Dprint( DEBUG_CITY_SCRIPT, "Personnel Needs : ")
	Dprint( DEBUG_CITY_SCRIPT, "food wanted = ", personnelNeed, " ration allowed = ", personnelRation, " food eaten = ", personnelFood, "Available food left = ", availableFood)

	-- Food for population
	function GetFoodEaten(classID, population, consumption, maxEffectValue)
		local need		= GCO.ToDecimals(Div((population * consumption / 1000), self:GetFoodNeededByPopulationFactor())) -- 
		local ration	= GCO.ToDecimals(need * rationing)
		local eaten		= GCO.ToDecimals(math.min(availableFood, ration))
		availableFood 		= availableFood - eaten
		Dprint( DEBUG_CITY_SCRIPT, " food wanted = ", need, " ration allowed = ", ration, " food eaten = ", eaten, "Available food left = ", availableFood)
		if eaten < need then
			local higherValue 		= need
			local lowerValue 		= eaten
			local effectValue		= GCO.ToDecimals(GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue))
			effectValue				= LimitEffect(maxEffectValue, effectValue)
			--NeedsEffects[classID][NeedsEffectType.DeathRate]["LOC_DEATHRATE_FROM_FOOD_RATIONING"] = effectValue
			AddNeeds(classID, NeedsEffectType.DeathRate, "LOC_DEATHRATE_FROM_FOOD_RATIONING", effectValue)
			Dprint( DEBUG_CITY_SCRIPT, maxEffectValue, higherValue, lowerValue, Locale.Lookup("LOC_DEATHRATE_FROM_FOOD_RATIONING", effectValue))
		end
		return eaten
	end

	Dprint( DEBUG_CITY_SCRIPT, "Upper Class Needs : ")
	local upperFood = GetFoodEaten(UpperClassID, upperPopulation, UpperClassFoodConsumption, 5)

	Dprint( DEBUG_CITY_SCRIPT, "Middle Class Needs : ")
	local middleFood = GetFoodEaten(MiddleClassID, middlePopulation, MiddleClassFoodConsumption, 10)

	Dprint( DEBUG_CITY_SCRIPT, "Lower Class Needs : ")
	local lowerFood = GetFoodEaten(LowerClassID, lowerPopulation, LowerClassFoodConsumption, 15)

	Dprint( DEBUG_CITY_SCRIPT, "Slave Class Needs : ")
	local slaveFood = GetFoodEaten(SlaveClassID, slavePopulation, SlaveClassFoodConsumption, 5)

	self:SetPopulationDeathRate(UpperClassID)
	self:SetPopulationDeathRate(MiddleClassID)
	self:SetPopulationDeathRate(LowerClassID)
	self:SetPopulationDeathRate(SlaveClassID)

	-- Eat Food
	--self:ChangeStock(foodResourceID, - upperFood, ResourceUseType.Consume, RefPopulationUpper	)
	--self:ChangeStock(foodResourceID, - middleFood, ResourceUseType.Consume, RefPopulationMiddle	)
	--self:ChangeStock(foodResourceID, - lowerFood, ResourceUseType.Consume, RefPopulationLower	)
	--self:ChangeStock(foodResourceID, - slaveFood, ResourceUseType.Consume, RefPopulationSlave	)
	--self:ChangeStock(foodResourceID, - personnelFood, ResourceUseType.Consume, RefPersonnel	)
	
	AddNeeds(UpperClassID, NeedsEffectType.Consumption, foodResourceID, upperFood)
	AddNeeds(MiddleClassID, NeedsEffectType.Consumption, foodResourceID, middleFood)
	AddNeeds(LowerClassID, NeedsEffectType.Consumption, foodResourceID, lowerFood)
	AddNeeds(SlaveClassID, NeedsEffectType.Consumption, foodResourceID, slaveFood)
	AddNeeds(PersonnelClassID, NeedsEffectType.Consumption, foodResourceID, personnelFood)
--[[	
	NeedsEffects[UpperClassID][NeedsEffectType.Consumption][foodResourceID] 		= upperFood
	NeedsEffects[MiddleClassID][NeedsEffectType.Consumption][foodResourceID] 		= middleFood
	NeedsEffects[LowerClassID][NeedsEffectType.Consumption][foodResourceID] 		= lowerFood
	NeedsEffects[SlaveClassID][NeedsEffectType.Consumption][foodResourceID] 		= slaveFood
	NeedsEffects[PersonnelClassID][NeedsEffectType.Consumption][Locale.Lookup("LOC_RESOURCE_CONSUMED_BY_NEED", GameInfo.Resources[foodResourceID].Name, GCO.GetResourceIcon(foodResourceID))] 	= personnelFood
--]]

	--
	-- Birth Rate Effects
	--
	
	Dprint( DEBUG_CITY_SCRIPT, "Housing ----------")
	-- Upper Class
	local upperHousingSize		= self:GetCustomYield( YieldUpperHousingID )
	local upperHousing			= GetPopulationPerSize(upperHousingSize)
	local upperHousingAvailable	= math.max( 0, upperHousing - upperPopulation)
	local upperLookingForMiddle	= math.max( 0, upperPopulation - upperHousing)
	Dprint( DEBUG_CITY_SCRIPT, "Upper Class Needs : Housing Size = ", upperHousingSize, " Housing Capacity = ", upperHousing, " Population = ", upperPopulation, " Available housing = ", upperHousingAvailable)

	-- Middle Class
	local middleHousingSize			= self:GetCustomYield( YieldMiddleHousingID )
	local middleHousing				= GetPopulationPerSize(middleHousingSize)
	local middleHousingAvailable	= math.max( 0, middleHousing - middlePopulation - upperLookingForMiddle)
	local middleLookingForLower		= math.max( 0, (middlePopulation + upperLookingForMiddle) - middleHousing)
	Dprint( DEBUG_CITY_SCRIPT, "Middle Class Needs : Housing Size = ", middleHousingSize, " Housing Capacity = ", middleHousing, " Population = ", middlePopulation, " Available housing = ", middleHousingAvailable)

	-- Lower Class
	local lowerHousingSize		= self:GetCustomYield( YieldLowerHousingID )
	local lowerHousing			= GetPopulationPerSize(lowerHousingSize)
	local lowerHousingAvailable	= math.max( 0, lowerHousing - lowerPopulation - middleLookingForLower)
	Dprint( DEBUG_CITY_SCRIPT, "Lower Class Needs : Housing Size = ", lowerHousingSize, " Housing Capacity = ", lowerHousing, " Population = ", lowerPopulation, " Available housing = ", lowerHousingAvailable)

	-- Housing Upper Class
	Dprint( DEBUG_CITY_SCRIPT, "Upper class Housing effect...")
	local upperGrowthRateLeft = math.max ( 0, self:GetBasePopulationBirthRate(UpperClassID) - self:GetBasePopulationDeathRate(UpperClassID)) --* 1.25
	if upperHousingAvailable > upperHousing * 0.5 then -- BirthRate bonus from housing available
		local maxEffectValue 	= 5
		local higherValue 		= (upperHousing * 0.5)
		local lowerValue 		= upperHousingAvailable - (upperHousing * 0.5)
		local effectValue		= GCO.ToDecimals(GetMaxPercentFromLowDiff(maxEffectValue, higherValue, lowerValue))
		--NeedsEffects[UpperClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_BONUS_FROM_HOUSING"] = effectValue
		AddNeeds(UpperClassID, NeedsEffectType.BirthRate, "LOC_BIRTHRATE_BONUS_FROM_HOUSING", effectValue)
		Dprint( DEBUG_CITY_SCRIPT, Locale.Lookup("LOC_BIRTHRATE_BONUS_FROM_HOUSING", effectValue))
	-- upperGrowthRateLeft > 0 and 
	elseif (upperHousingAvailable < upperHousing * 0.25) and (middleHousingAvailable < middleHousing * 0.25) then -- BirthRate malus from low housing left (upper class can use middle class housing if available)
		local maxEffectValue 	= self:GetBasePopulationBirthRate(UpperClassID)--upperGrowthRateLeft
		local higherValue 		= (upperHousing + middleHousing) * 0.25
		local lowerValue 		= upperHousingAvailable + middleHousingAvailable
		local effectValue		= GCO.ToDecimals(GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue))
		effectValue				= LimitEffect(maxEffectValue, effectValue)
		--NeedsEffects[UpperClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING"] = - effectValue
		AddNeeds(UpperClassID, NeedsEffectType.BirthRate, "LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING", - effectValue)
		Dprint( DEBUG_CITY_SCRIPT, maxEffectValue, higherValue, lowerValue, Locale.Lookup("LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING", - effectValue))
		upperGrowthRateLeft = upperGrowthRateLeft - effectValue
	end

	-- Housing Middle Class
	Dprint( DEBUG_CITY_SCRIPT, "Middle class Housing effect...")
	local middleGrowthRateLeft = math.max ( 0, self:GetBasePopulationBirthRate(MiddleClassID) - self:GetBasePopulationDeathRate(MiddleClassID)) --* 1.25
	if middleHousingAvailable > middleHousing * 0.5 then -- BirthRate bonus from housing available
		local maxEffectValue 	= 5
		local higherValue 		= (middleHousing * 0.5)
		local lowerValue 		= middleHousingAvailable - (middleHousing * 0.5)
		local effectValue		= GCO.ToDecimals(GetMaxPercentFromLowDiff(maxEffectValue, higherValue, lowerValue))
		--NeedsEffects[MiddleClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_BONUS_FROM_HOUSING"] = effectValue
		AddNeeds(MiddleClassID, NeedsEffectType.BirthRate, "LOC_BIRTHRATE_BONUS_FROM_HOUSING", effectValue)
		Dprint( DEBUG_CITY_SCRIPT, Locale.Lookup("LOC_BIRTHRATE_BONUS_FROM_HOUSING", effectValue))
	-- middleGrowthRateLeft > 0 and 
	elseif (middleHousingAvailable < middleHousing * 0.25) and (lowerHousingAvailable < lowerHousing * 0.25)  then -- BirthRate malus from low housing left (middle class can use lower class housing if available)
		local maxEffectValue 	= math.max(middleGrowthRateLeft, self:GetBasePopulationBirthRate(MiddleClassID) * 0.35)
		local higherValue 		= (middleHousing + lowerHousing) * 0.25
		local lowerValue 		= middleHousingAvailable + lowerHousingAvailable
		local effectValue		= GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue)
		effectValue				= LimitEffect(maxEffectValue, effectValue)--math.min(middleGrowthRateLeft,LimitEffect(maxEffectValue, effectValue))
		--NeedsEffects[MiddleClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING"] = - effectValue
		AddNeeds(MiddleClassID, NeedsEffectType.BirthRate, "LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING", - effectValue)
		Dprint( DEBUG_CITY_SCRIPT, maxEffectValue, higherValue, lowerValue, Locale.Lookup("LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING", - effectValue))
		middleGrowthRateLeft = middleGrowthRateLeft - effectValue
	end

	-- Housing Lower Class
	Dprint( DEBUG_CITY_SCRIPT, "Lower class Housing effect...")
	local lowerGrowthRateLeft = math.max ( 0, self:GetBasePopulationBirthRate(LowerClassID) - self:GetBasePopulationDeathRate(LowerClassID)) --* 1.25
	if lowerHousingAvailable > lowerHousing * 0.5 then -- BirthRate bonus from housing available
		local maxEffectValue 	= 5
		local higherValue 		= (lowerHousing * 0.5)
		local lowerValue 		= lowerHousingAvailable - (lowerHousing * 0.5)
		local effectValue		= GCO.ToDecimals(GetMaxPercentFromLowDiff(maxEffectValue, higherValue, lowerValue))
		--NeedsEffects[LowerClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_BONUS_FROM_HOUSING"] = effectValue
		AddNeeds(LowerClassID, NeedsEffectType.BirthRate, "LOC_BIRTHRATE_BONUS_FROM_HOUSING", effectValue)
		Dprint( DEBUG_CITY_SCRIPT, maxEffectValue, higherValue, lowerValue, Locale.Lookup("LOC_BIRTHRATE_BONUS_FROM_HOUSING", effectValue))
	elseif lowerGrowthRateLeft > 0 and lowerHousingAvailable < lowerHousing * 0.25  then -- BirthRate malus from low housing left
		local maxEffectValue 	= lowerGrowthRateLeft--self:GetBasePopulationBirthRate(LowerClassID) --
		local higherValue 		= lowerHousing * 0.25
		local lowerValue 		= lowerHousingAvailable
		local effectValue		= GCO.ToDecimals(GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue))
		effectValue				= LimitEffect(maxEffectValue, effectValue)--math.min(lowerGrowthRateLeft,LimitEffect(maxEffectValue, effectValue))
		--NeedsEffects[LowerClassID][NeedsEffectType.BirthRate]["LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING"] = - effectValue
		AddNeeds(LowerClassID, NeedsEffectType.BirthRate, "LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING", - effectValue)
		Dprint( DEBUG_CITY_SCRIPT, maxEffectValue, higherValue, lowerValue, Locale.Lookup("LOC_BIRTHRATE_MALUS_FROM_LOW_HOUSING", - effectValue))
		lowerGrowthRateLeft = lowerGrowthRateLeft - effectValue
	end
	
	self:SetPopulationBirthRate(UpperClassID)
	self:SetPopulationBirthRate(MiddleClassID)
	self:SetPopulationBirthRate(LowerClassID)
	self:SetPopulationBirthRate(SlaveClassID)
	
	--
	-- Social Stratification Effects
	--
	
		
	-- Luxury Resources	
		
	Dprint( DEBUG_CITY_SCRIPT, "Upper class Luxuries effect...")
	
	local luxuryTable 				= {}
	local totalLuxuries				= 0
	local stock						= self:GetResources()
	local maxPositiveEffectValue 	= 25
	local maxNegativeEffectValue 	= 10
	
	for resourceKey, value in pairs(stock) do
		local resourceID = tonumber(resourceKey)
		if GCO.IsResourceLuxury(resourceID) and value > 0 then
			totalLuxuries = totalLuxuries + value
			luxuryTable[resourceID] = value
		end
	end
	
	local minLuxuriesNeeded 	= math.floor(self:GetSize() * (Div(upperPopulation, self:GetUrbanPopulation())) * 25) --math.max(1, GCO.Round(upperPopulation * MinNeededLuxuriesPerMil / 1000))
	local maxLuxuriesConsumed 	= math.min(totalLuxuries, math.floor(self:GetSize() * Div(upperPopulation, self:GetUrbanPopulation()) * 50))--math.min(totalLuxuries, GCO.Round(upperPopulation * MaxLuxuriesConsumedPerMil / 1000 ))
	
	if totalLuxuries > 0 then
	
		if totalLuxuries > minLuxuriesNeeded then -- Social Stratification bonus from available luxuries
			local maxEffectValue 	= maxPositiveEffectValue
			local higherValue 		= totalLuxuries
			local lowerValue 		= maxLuxuriesConsumed--minLuxuriesNeeded
			local effectValue		= GCO.ToDecimals(GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue))
			--effectValue				= LimitEffect(maxEffectValue, effectValue)
			--NeedsEffects[UpperClassID][NeedsEffectType.SocialStratification]["LOC_SOCIAL_STRATIFICATION_BONUS_FROM_LUXURIES"] 		= effectValue
			--NeedsEffects[UpperClassID][NeedsEffectType.SocialStratificationReq]["LOC_SOCIAL_STRATIFICATION_AVAILABLE_LUXURIES"] 	= totalLuxuries
			--NeedsEffects[UpperClassID][NeedsEffectType.SocialStratificationReq]["LOC_SOCIAL_STRATIFICATION_CONSUMED_LUXURIES"] 	= maxLuxuriesConsumed
			
			AddNeeds(UpperClassID, NeedsEffectType.SocialStratification, "LOC_SOCIAL_STRATIFICATION_BONUS_FROM_LUXURIES", effectValue)
			AddNeeds(UpperClassID, NeedsEffectType.SocialStratificationReq, "LOC_SOCIAL_STRATIFICATION_AVAILABLE_LUXURIES", totalLuxuries)
			AddNeeds(UpperClassID, NeedsEffectType.SocialStratificationReq, "LOC_SOCIAL_STRATIFICATION_CONSUMED_LUXURIES", maxLuxuriesConsumed)
			
			Dprint( DEBUG_CITY_SCRIPT, maxEffectValue, higherValue, lowerValue, Locale.Lookup("LOC_SOCIAL_STRATIFICATION_BONUS_FROM_LUXURIES", effectValue))
		elseif totalLuxuries < minLuxuriesNeeded then -- Social Stratification penalty from not enough luxuries
			local maxEffectValue 	= maxNegativeEffectValue
			local higherValue 		= minLuxuriesNeeded
			local lowerValue 		= totalLuxuries
			local effectValue		= GCO.ToDecimals(GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue))
			--effectValue				= LimitEffect(maxEffectValue, effectValue)
			--NeedsEffects[UpperClassID][NeedsEffectType.SocialStratification]["LOC_SOCIAL_STRATIFICATION_PENALTY_FROM_LUXURIES"] 	= - effectValue
			--NeedsEffects[UpperClassID][NeedsEffectType.SocialStratificationReq]["LOC_SOCIAL_STRATIFICATION_AVAILABLE_LUXURIES"] 	= totalLuxuries
			--NeedsEffects[UpperClassID][NeedsEffectType.SocialStratificationReq]["LOC_SOCIAL_STRATIFICATION_REQUIRED_LUXURIES"] 		= minLuxuriesNeeded
			
			AddNeeds(UpperClassID, NeedsEffectType.SocialStratification, "LOC_SOCIAL_STRATIFICATION_PENALTY_FROM_LUXURIES", -effectValue)
			AddNeeds(UpperClassID, NeedsEffectType.SocialStratificationReq, "LOC_SOCIAL_STRATIFICATION_AVAILABLE_LUXURIES", totalLuxuries)
			AddNeeds(UpperClassID, NeedsEffectType.SocialStratificationReq, "LOC_SOCIAL_STRATIFICATION_REQUIRED_LUXURIES", minLuxuriesNeeded)
			
			Dprint( DEBUG_CITY_SCRIPT, maxEffectValue, higherValue, lowerValue, Locale.Lookup("LOC_SOCIAL_STRATIFICATION_PENALTY_FROM_LUXURIES", - effectValue))
		end
		
		local ratio = Div(maxLuxuriesConsumed, totalLuxuries)
		for resourceID, value in pairs(luxuryTable) do
			local consumed = GCO.Round(value * ratio)
			--self:ChangeStock(resourceID, - consumed, ResourceUseType.Consume, RefPopulationUpper)
			--NeedsEffects[UpperClassID][NeedsEffectType.Consumption][Locale.Lookup("LOC_RESOURCE_CONSUMED_BY_NEED", GameInfo.Resources[resourceID].Name, GCO.GetResourceIcon(resourceID))] 		= consumed
			AddNeeds(UpperClassID, NeedsEffectType.Consumption, resourceID, consumed)
		end
		
	else
		--NeedsEffects[UpperClassID][NeedsEffectType.SocialStratification]["LOC_SOCIAL_STRATIFICATION_PENALTY_FROM_LUXURIES"] = -maxNegativeEffectValue
		AddNeeds(UpperClassID, NeedsEffectType.SocialStratification, "LOC_SOCIAL_STRATIFICATION_PENALTY_FROM_LUXURIES", -maxNegativeEffectValue)
		Dprint( DEBUG_CITY_SCRIPT, maxNegativeEffectValue, minLuxuriesNeeded, totalLuxuries, Locale.Lookup("LOC_SOCIAL_STRATIFICATION_PENALTY_FROM_LUXURIES", - maxNegativeEffectValue))
	end

	--[[
	local player = GCO.GetPlayer(self:GetOwner())
	for row in GameInfo.Populations() do
		local populationID 		= GameInfo.Resources[row.PopulationType].Index
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
	
	Dlog("SetNeedsValues ".. Locale.Lookup(self:GetName()).." /END")
end

function DoSocialClassStratification(self)

	local DEBUG_CITY_SCRIPT = DEBUG_CITY_SCRIPT
	--if Locale.Lookup(self:GetName()) =="London" then DEBUG_CITY_SCRIPT = "debug" end
	
	Dlog("DoSocialClassStratification ".. Locale.Lookup(self:GetName()).." /START")
	local totalPopulation = self:GetRealPopulation()

	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: totalPopulation = ", totalPopulation)

	local maxUpper = self:GetMaxUpperClass()
	local minUpper = self:GetMinUpperClass()
	
	local maxMiddle = self:GetMaxMiddleClass()
	local minMiddle = self:GetMinMiddleClass()

	local maxLower = self:GetMaxLowerClass()
	local minLower = self:GetMinLowerClass()

	local actualUpper = self:GetUpperClass()
	local actualMiddle = self:GetMiddleClass()
	local actualLower = self:GetLowerClass()

	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: maxUpper .. = ", maxUpper)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: actualUpper = ", actualUpper)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: minUpper .. = ", minUpper)
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: maxMiddle .. = ", maxMiddle)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: actualMiddle = ", actualMiddle)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: minMiddle .. = ", minMiddle)
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: maxLower .. = ", maxLower)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: actualLower = ", actualLower)
	Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: minLower .. = ", minLower)
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)

	-- to do : change magic ratio number, influence by era/tech/policies
	-- Move Upper to Middle
	if actualUpper > maxUpper then
		toMove = GCO.Round(math.min(actualUpper * 0.20, actualUpper - maxUpper))
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Upper to Middle (from actualUpper > maxUpper) ..... = ", toMove)
		self:ChangeUpperClass(- toMove)
		self:ChangeMiddleClass( toMove)
	end
	-- Move Middle to Upper
	if actualUpper < minUpper then
		toMove = GCO.Round(math.min(actualMiddle * 0.075, minUpper - actualUpper))
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Middle to Upper (from actualUpper < minUpper) ..... = ", toMove)
		self:ChangeUpperClass(toMove)
		self:ChangeMiddleClass(-toMove)
	end
	-- Move Middle to Lower
	if actualMiddle > maxMiddle then
		toMove = GCO.Round(math.min(actualMiddle * 0.25, actualMiddle - maxMiddle))
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Middle to Lower (from actualMiddle > maxMiddle) ... = ", toMove)
		self:ChangeMiddleClass(-toMove)
		self:ChangeLowerClass(toMove)
	end
	-- Move Lower to Middle
	if actualMiddle < minMiddle then
		toMove = GCO.Round(math.min(actualLower * 0.10, minMiddle - actualMiddle))
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Lower to Middle (from actualMiddle < minMiddle) ... = ", toMove)
		self:ChangeMiddleClass(toMove)
		self:ChangeLowerClass(-toMove)
	end
	-- Move Lower to Middle
	if actualLower > maxLower then
		toMove = GCO.Round(math.min(actualLower * 0.10, actualLower - maxLower))
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Lower to Middle (from actualLower > maxLower) ..... = ", toMove)
		self:ChangeMiddleClass(toMove)
		self:ChangeLowerClass(-toMove)
	end
	-- Move Middle to Lower
	if actualLower < minLower then
		toMove = GCO.Round(math.min(actualMiddle * 0.25, minLower - actualLower))
		Dprint( DEBUG_CITY_SCRIPT, "Social Stratification: Middle to Lower (from actualLower < minLower) ..... = ", toMove)
		self:ChangeMiddleClass(-toMove)
		self:ChangeLowerClass(toMove)
	end
	Dlog("DoSocialClassStratification ".. Locale.Lookup(self:GetName()).." /END")
end

function DoTaxes(self)

	local player 		= GCO.GetPlayer(self:GetOwner())
	local goldPerTurn 	= self:GetCityYield(YieldTypes.GOLD )
	
	if player:HasPolicyActive(GameInfo.Policies["POLICY_UPPER_TAX"].Index) then 
		local ratio 		= Div(self:GetUpperClass(), self:GetRealPopulation())
		local extraGold 	= goldPerTurn * ratio * 2
		player:ProceedTransaction(AccountType.UpperTaxes, extraGold)		
	end
	
	if player:HasPolicyActive(GameInfo.Policies["POLICY_MIDDLE_TAX"].Index) then 
		local ratio 		= Div(self:GetMiddleClass(), self:GetRealPopulation())
		local extraGold 	= goldPerTurn * ratio
		player:ProceedTransaction(AccountType.MiddleTaxes, extraGold)		
	end
end

function DoAdministration(self) -- after processing resources

	-- Update administrative cost first
	-- "Set" returns the updated values, "Get" are used for UI
	local totalNeeded 	= self:SetAdministrativeCost()
	local Support		= self:SetAdministrativeSupport()
	local minPercent	= minAdmSupportPercent -- to do : change with policies
	local needed		= totalNeeded
	local provided		= 0
	local adminYield	= Support.Yield
	
	if adminYield > 0 then
		local used	= math.min(needed, adminYield)
		needed 		= needed - used
		provided	= provided + used	
	end
	
	if needed > 0 then
		for resourceKey, value in pairs(self:GetResources()) do
			local resourceID	= tonumber(resourceKey)
			local adminValue	= GCO.GetAdministrativeResourceValue(resourceID)
			if adminValue then
				local reserved	= math.floor(self:GetMaxStock(resourceID)*minPercent/100)
				local available = (value > reserved and value - reserved) or 0
				if available > 0 then
					local used = math.min(needed, available)
					self:ChangeStock(resourceID, -used, ResourceUseType.OtherOut) -- to do: new ResourceUseType ?
					needed 		= needed - used
					provided	= provided + (used * adminValue)
				end
			end
		end
	end
	local efficiency = ((provided >= totalNeeded or totalNeeded == 0) and 100) or GCO.GetMaxPercentFromLowDiff(100, totalNeeded, provided)--(100 - Div( totalNeeded, (provided + 1))))
	self:SetAdministrativeEfficiency(efficiency)
end

-- todo : move to defines
-- todo : no magic numbers !
-- new entries in GlobalParameters ? or fields in Population table ? or new linked table(s) ?
local migrationClassMotivation	= {
	-- Main motivations
	["Employment"] 	= { [UpperClassID] 	= 0.10, [MiddleClassID] = 2.00, [LowerClassID] 	= 3.00, },
	["Housing"] 	= { [UpperClassID] 	= 3.00, [MiddleClassID] = 1.75, [LowerClassID] 	= 1.50, },
	["Food"] 		= { [UpperClassID] 	= 0.25, [MiddleClassID] = 2.00, [LowerClassID] 	= 3.00, },
	["Threat"] 		= { [UpperClassID] 	= 3.00, [MiddleClassID] = 2.00, [LowerClassID] 	= 1.00, },
	-- Values below are used for further calculation
	["Rural"] 		= { [UpperClassID] 	= 0.25, [MiddleClassID] = 1.00, [LowerClassID] 	= 1.00, },	-- Moving away from cities
	["Urban"] 		= { [UpperClassID] 	= 2.00, [MiddleClassID] = 1.00, [LowerClassID] 	= 1.00, },	-- Moving to other cities
	["Emigration"] 	= { [UpperClassID] 	= 1.00, [MiddleClassID] = 0.75, [LowerClassID] 	= 0.50, },	-- Moving to foreign cities
	["Transport"] 	= { [UpperClassID] 	= 1.00, [MiddleClassID] = 0.25, [LowerClassID] 	= 0.05, },	-- Ability to move over distance (max = 1.00) (todo : era dependant)
}

function SetMigrationValues(self)

	Dlog("SetMigrationValues ".. Locale.Lookup(self:GetName()).." /START")
	local DEBUG_CITY_SCRIPT = DEBUG_CITY_SCRIPT
	--if Locale.Lookup(self:GetName()) =="London" then DEBUG_CITY_SCRIPT = "debug" end
	
	local cityKey = self:GetKey()
	if not _cached[cityKey] then
		_cached[cityKey] = {}
	end
	if not _cached[cityKey].Migration then
		_cached[cityKey].Migration = { 
			Push 		= {Employment = {}, Housing = {}, Food = {}},
			Pull 		= {Employment = {}, Housing = {}, Food = {}},
			Migrants 	= {Employment = {}, Housing = {}, Food = {}},
			Motivation	= {}
		}
	end
	local cityMigration = _cached[cityKey].Migration
	
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "- Set Migration values for ".. Locale.Lookup(self:GetName()))
	local possibleDestination 		= {}
	local migrantClasses			= {UpperClassID, MiddleClassID, LowerClassID}
	local housingID					= { [UpperClassID] 	= YieldUpperHousingID, [MiddleClassID] = YieldMiddleHousingID, [LowerClassID] 	= YieldLowerHousingID, } -- to do : something else...
	local tPopulationHousing		= self:GetPopulationHousing()
	--local migrantMotivations		= {"Under threat", "Starvation", "Employment", "Overpopulation"}
	local migrants					= {}
	local totalPopulation 			= self:GetUrbanPopulation()
	
	-- for now global, but todo : per class employment in cities
	local employment				= self:GetMaxEmploymentUrban()
	local employed					= self:GetUrbanEmployed()
	local unEmployed				= math.max(0, totalPopulation - employment)
	
	local classesRatio				= {}
	for i, classID in ipairs(migrantClasses) do
		classesRatio[classID] = Div(self:GetPopulationClass(classID), totalPopulation)
	end
	
	Dprint( DEBUG_CITY_SCRIPT, "  - UnEmployed = ", unEmployed," employment : ", employment, " totalPopulation = ", totalPopulation)
	
	for _, populationID in pairs(migrantClasses) do
	
		local population			= self:GetPopulationClass(populationID)		
		local housingSize			= self:GetCustomYield( housingID[populationID] )
		local maxPopulation			= tPopulationHousing[populationID].MaxHousing--math.max(GetPopulationPerSize(1), GetPopulationPerSize(housingSize) - tPopulationHousing[populationID])
		local bestMotivationWeight	= 0
		
		Dprint( DEBUG_CITY_SCRIPT, "  - "..Indentation20(Locale.ToUpper(GameInfo.Resources[populationID].Name)).." current population = "..Indentation15(population).. " motivations : employment = ".. tostring(migrationClassMotivation.Employment[populationID]) ..", housing = ".. migrationClassMotivation.Housing[populationID] ..", food = ".. tostring(migrationClassMotivation.Food[populationID]))
		
		if population > 0 then
			-- check Migration motivations, from lowest to most important :	
		
			-- Employment
			-- for now global, but todo : per class employment in cities
			if employment > 0 then
				cityMigration.Pull.Employment[populationID]		= Div(employment, totalPopulation)
				cityMigration.Push.Employment[populationID]		= Div(totalPopulation, employment)
				cityMigration.Migrants.Employment[populationID]	= 0
				if cityMigration.Push.Employment[populationID] > 1 then
					local motivationWeight = cityMigration.Push.Employment[populationID] * migrationClassMotivation.Employment[populationID]
					if motivationWeight > bestMotivationWeight then
						cityMigration.Motivation[populationID]		= "Employment"
						bestMotivationWeight						= motivationWeight
					end
					cityMigration.Migrants.Employment[populationID]	= math.floor(unEmployed * classesRatio[populationID] * math.min(1, migrationClassMotivation.Employment[populationID])) -- Weight affect numbers of migrant when < 1.00
				end
			else
				cityMigration.Pull.Employment[populationID]		= 0
				cityMigration.Push.Employment[populationID]		= 0
				cityMigration.Migrants.Employment[populationID]	= 0	
			end
			Dprint( DEBUG_CITY_SCRIPT, "  - Employment migrants for ...."..Indentation20(Locale.Lookup(GameInfo.Resources[populationID].Name)).." = ".. tostring(cityMigration.Migrants.Employment[populationID]) .."/".. population )
			
			-- Housing
			cityMigration.Pull.Housing[populationID]		= Div(maxPopulation, population)
			cityMigration.Push.Housing[populationID]		= Div(population, maxPopulation)
			cityMigration.Migrants.Housing[populationID]	= 0
			if cityMigration.Push.Housing[populationID] > 1 then 
				local motivationWeight = cityMigration.Push.Housing[populationID] * migrationClassMotivation.Housing[populationID]
				if motivationWeight > bestMotivationWeight then
					cityMigration.Motivation[populationID]		= "Housing"
					bestMotivationWeight						= motivationWeight
				end
				local overPopulation							= population - maxPopulation
				cityMigration.Migrants.Housing[populationID]	= math.floor(overPopulation * math.min(1, migrationClassMotivation.Housing[populationID]))
			end
			--Dprint( DEBUG_CITY_SCRIPT, "  - Overpopulation = ", overPopulation," maxPopulation : ", maxPopulation, " population = ", population)
			Dprint( DEBUG_CITY_SCRIPT, "  - Overpopulation migrants for "..Indentation20(Locale.Lookup(GameInfo.Resources[populationID].Name)).." = ".. tostring(cityMigration.Migrants.Housing[populationID]) .."/".. population )
			
			-- Starvation
			-- Todo : get values per population class from NeedsEffects instead of global values here
			local consumptionRatio						= 1
			local foodNeeded							= self:GetFoodConsumption(consumptionRatio)
			local foodstock								= self:GetFoodStock()
			cityMigration.Pull.Food[populationID]		= Div(foodstock, foodNeeded)
			cityMigration.Push.Food[populationID]		= Div(foodNeeded, foodstock)
			cityMigration.Migrants.Food[populationID]	= 0
			
			if cityMigration.Push.Food[populationID] > 1 then 
				local motivationWeight = cityMigration.Push.Food[populationID] * migrationClassMotivation.Food[populationID]
				if motivationWeight >= bestMotivationWeight then
					cityMigration.Motivation[populationID]		= "Food"
					bestMotivationWeight						= motivationWeight
				end
				local starving								= population - Div(population, cityMigration.Push.Food[populationID])
				cityMigration.Migrants.Food[populationID]	= math.floor(starving * classesRatio[populationID] * math.min(1, migrationClassMotivation.Food[populationID]))
			end
			--Dprint( DEBUG_CITY_SCRIPT, "  - Starving = ", starving," foodNeeded : ", foodNeeded, " foodstock = ", foodstock)
			Dprint( DEBUG_CITY_SCRIPT, "  - Starving migrants for ......"..Indentation20(Locale.Lookup(GameInfo.Resources[populationID].Name)).." = ".. tostring(cityMigration.Migrants.Food[populationID]) .."/".. population )

			-- Threat
			--
			--
			
			Dprint( DEBUG_CITY_SCRIPT, "  - Best motivation : ", cityMigration.Motivation[populationID])
			Dprint( DEBUG_CITY_SCRIPT, "  - Pull.Food ......: ", GCO.ToDecimals(cityMigration.Pull.Food[populationID]), 		" Push.Food ......= ", GCO.ToDecimals(cityMigration.Push.Food[populationID]))
			Dprint( DEBUG_CITY_SCRIPT, "  - Pull.Housing ...: ", GCO.ToDecimals(cityMigration.Pull.Housing[populationID]), 		" Push.Housing ...= ", GCO.ToDecimals(cityMigration.Push.Housing[populationID]))
			Dprint( DEBUG_CITY_SCRIPT, "  - Pull.Employment : ", GCO.ToDecimals(cityMigration.Pull.Employment[populationID]), 	" Push.Employment = ", GCO.ToDecimals(cityMigration.Push.Employment[populationID]))
		end
	end
	Dlog("SetMigrationValues ".. Locale.Lookup(self:GetName()).." /END")
end

function DoMigration(self)

	Dlog("DoMigration ".. Locale.Lookup(self:GetName()).." /START")
	
	local DEBUG_CITY_SCRIPT = DEBUG_CITY_SCRIPT
	--if Locale.Lookup(self:GetName()) =="London" then DEBUG_CITY_SCRIPT = "debug" end
	
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "- Population Migration for ".. Locale.Lookup(self:GetName()))
	
	local migrantClasses		= {UpperClassID, MiddleClassID, LowerClassID}
	
	-- Get potential migrants
	local totalPopulation 		= self:GetRealPopulation()
	local minPopulationLeft		= GetPopulationPerSize(math.max(1, self:GetSize()-1))
	local availableMigrants		= totalPopulation - minPopulationLeft
	local plotsToUpdate			= {} -- list of plots that will need updating for Culture to Population matching
	
	if availableMigrants  > 0 then
		local maxMigrants		= math.floor(availableMigrants * maxMigrantPercent / 100)
		local minMigrants		= math.floor(availableMigrants * minMigrantPercent / 100)
		
		--local migrants			= math.min(maxMigrants, minMigrants)
		
		Dprint( DEBUG_CITY_SCRIPT, "  - Max Migrants = ", maxMigrants, " Min Migrants = ", minMigrants)
		
		if maxMigrants > 0 then
			local cityMigration 			= self:GetMigration()
			
			local classesRatio				= {}
			for i, classID in ipairs(migrantClasses) do
				classesRatio[classID] = Div(self:GetPopulationClass(classID), totalPopulation)
			end
			
			-- Do Migration for each population class
			for _, populationID in ipairs(migrantClasses) do
			
				local possibleDestination 		= {}
				local majorMotivation			= cityMigration.Motivation[populationID] or "Greener Pastures" -- to do: check if this happens
				local bestMotivationValue		= 0
				local bestMotivationWeight		= 0
				local totalWeight				= 0
				local migrants					= 0
			
				-- Get the number of migrants for each class from this city
				for motivation, value in pairs(cityMigration.Migrants) do
					-- motivations can overlap, so just use the biggest value for this populationID from all motivations 
					migrants = math.max(value[populationID] or 0, migrants ) -- value[populationID] can be nil when the number of population in that class = 0 
				end
				-- Max/Min migrant for a populationID are relative to the populationID ratio, to prevent all migrants
				-- to be of the same populationID when that class has more eager migrants than the max possible value for the whole city population
				migrants = math.floor(math.min(maxMigrants * classesRatio[populationID], math.max(minMigrants * classesRatio[populationID], migrants)))
				Dprint( DEBUG_CITY_SCRIPT, "  - Eager migrants for "..Indentation20(Locale.ToUpper(GameInfo.Resources[populationID].Name)).." = ".. tostring(migrants) .."/".. tostring(self:GetPopulationClass(populationID)) .. ", Major motivation = " .. tostring(majorMotivation) )
			
				if migrants > 0 then
					-- Get possible destinations from this city own plots
					local cityPlots	= GCO.GetCityPlots(self)
					
					-- Add adjacent plots owned by another player as there won't be migration to it if it's surrounded by water
					for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
						local adjacentPlot 	= Map.GetAdjacentPlot(iX, iY, direction)
						if adjacentPlot and not adjacentPlot:IsWater() and adjacentPlot:GetOwner() ~= self:GetOwner() then
							table.insert(cityPlots, adjacentPlot:GetIndex())
						end		
					end
					for _, plotID in ipairs(cityPlots) do
						local plot = GCO.GetPlotByIndex(plotID)
						if plot and (not plot:IsCity()) then
							local plotMigration = plot:GetMigration()
							if plotMigration then
								local distance		= Map.GetPlotDistance(self:GetX(), self:GetY(), plot:GetX(), plot:GetY())
								local efficiency 	= (1 - math.min(0.95, distance / 4)) * migrationClassMotivation["Transport"][populationID]
								local factor		= migrationClassMotivation["Rural"][populationID] * efficiency
								local plotWeight 	= 0
								local bWorked 		= (plot:GetWorkerCount() > 0)
								if majorMotivation == "Greener Pastures" then								
									plotWeight = 1  -- Any plots will have mimimun attraction for adventurers
								end
								Dprint( DEBUG_CITY_SCRIPT, "   - Looking for better conditions on plot (".. plot:GetX() ..",".. plot:GetY().."), Class Factor = ", GCO.ToDecimals(factor))
								for motivation, pushValues in pairs(cityMigration.Push) do
									local pushValue		= pushValues[populationID]
									local weightRatio	= migrationClassMotivation[motivation][populationID] * factor
									local plotPull		= plotMigration.Pull[motivation] or 0
									local plotPush		= plotMigration.Push[motivation] or 0
									-- special case here : use housing plotPull for food motivation (which is the same in a city and its plots) as sending people
									-- in plots which could maintain more population if they were not attached to a city may help produce more food for the region
									-- note : deprecated, plotMigration.Pull["Food"] is now directly pondered with plotMigration.Pull["Housing"]
									--[[
									if motivation == "Food" then
										plotPull		= plotMigration.Pull["Housing"] or 0
									end	
									--]]									
									Dprint( DEBUG_CITY_SCRIPT, "     -  Motivation : "..Indentation15(motivation) .. " pushValue = ", GCO.ToDecimals(pushValue), " plotPush = ", GCO.ToDecimals(plotPush), " plotPull = ", GCO.ToDecimals(plotPull))
									if plotPush < pushValue then 			-- situation is better on adjacentPlot than on currentPlot for [motivation]
										if plotPull > 1 then
											weightRatio = weightRatio * 2		-- situation is good on adjacentPlot
										end
										if pushValue > 1 then
											weightRatio = weightRatio * 5		-- situation is bad on currentPlot
										end
										if motivation == majorMotivation then
											weightRatio = weightRatio * 10		-- this is the most important motivation for migration
										end
										
										if bWorked then
											weightRatio = weightRatio * 10		-- we want migration on worked plots
										end
										local motivationWeight = (plotPull + pushValue) * weightRatio
										plotWeight = plotWeight + motivationWeight
										Dprint( DEBUG_CITY_SCRIPT, "       -  weightRatio = ", GCO.ToDecimals(weightRatio), " motivationWeight = ", GCO.ToDecimals(motivationWeight), " updated plotWeight = ", GCO.ToDecimals(plotWeight))
									end				
								end

								if plotWeight > 0 then
									totalWeight = totalWeight + plotWeight
									table.insert (possibleDestination, {PlotID = plot:GetIndex(), Weight = plotWeight, MigrationEfficiency = efficiency})
								end
							else
								GCO.Warning("plotMigration is nil for plot @(".. tostring(plot:GetX())..",".. tostring(plot:GetY())..")")
							end
						end
					end
					
					-- Get possible destinations from transfer cities
					local data 	= self:GetTransferCities() or {}
					for routeCityKey, routeData in pairs(data) do
						local city	= GetCityFromKey(routeCityKey)
						if city then

							local otherCityMigration = city:GetMigration()
							if otherCityMigration then
								local cityWeight 	= 0
								local efficiency	= (routeData.Efficiency / 100) * migrationClassMotivation["Transport"][populationID]
								local factor		= migrationClassMotivation["Urban"][populationID] * efficiency
								if majorMotivation == "Greener Pastures" then								
									cityWeight = 1  -- Any city will have mimimun attraction for adventurers
								end
								Dprint( DEBUG_CITY_SCRIPT, "   - Looking for better conditions in City of ".. Locale.Lookup(city:GetName()), " Class Factor = ", GCO.ToDecimals(factor))
								for motivation, pushValues in pairs(cityMigration.Push) do
									local pushValue		= pushValues[populationID]
									local weightRatio	= migrationClassMotivation[motivation][populationID] * factor
									local cityPull		= otherCityMigration.Pull[motivation][populationID] or 0
									local cityPush		= otherCityMigration.Push[motivation][populationID] or 0
								
									Dprint( DEBUG_CITY_SCRIPT, "     -  Motivation : "..Indentation15(motivation) .. " pushValue = ", GCO.ToDecimals(pushValue), " cityPush = ", GCO.ToDecimals(cityPush), " cityPull = ", GCO.ToDecimals(cityPull))
									if cityPush < pushValue then 				-- situation is better in other city than in current city for [motivation]
										if cityPull > 1 then
											weightRatio = weightRatio * 2		-- situation is good in other city
										end
										if pushValue > 1 then
											weightRatio = weightRatio * 5		-- situation is bad in current city
										end
										if motivation == majorMotivation then
											weightRatio = weightRatio * 10		-- this is the most important motivation for migration
										end
										local motivationWeight = (cityPull + pushValue) * weightRatio
										cityWeight = cityWeight + motivationWeight
										Dprint( DEBUG_CITY_SCRIPT, "       -  weightRatio = ", GCO.ToDecimals(weightRatio), " motivationWeight = ", GCO.ToDecimals(motivationWeight), " updated cityWeight = ", GCO.ToDecimals(cityWeight))
									end
								end

								if cityWeight > 0 then
									totalWeight = totalWeight + cityWeight
									table.insert (possibleDestination, {City = city, Weight = cityWeight, MigrationEfficiency = efficiency})
								end
							else
								GCO.Warning("cityMigration is nil for ".. Locale.Lookup(city:GetName()))
							end
						end
					end
					
					-- Get possible destinations from foreign cities
					local data 	= self:GetExportCities() or {}
					for routeCityKey, routeData in pairs(data) do
						local city	= GetCityFromKey(routeCityKey)
						if city then

							local otherCityMigration = city:GetMigration()
							if otherCityMigration then
								local cityWeight 	= 0
								local efficiency	= (routeData.Efficiency / 100) * migrationClassMotivation["Transport"][populationID]
								local factor		= migrationClassMotivation["Emigration"][populationID] * efficiency
								if majorMotivation == "Greener Pastures" then								
									cityWeight = 1  -- Any city will have mimimun attraction for adventurers
								end
								Dprint( DEBUG_CITY_SCRIPT, "   - Looking for better conditions in foreign City of ".. Locale.Lookup(city:GetName()), " Class Factor = ", GCO.ToDecimals(factor))
								for motivation, pushValues in pairs(cityMigration.Push) do
									local pushValue		= pushValues[populationID]
									local weightRatio	= migrationClassMotivation[motivation][populationID] * factor
									local cityPull		= otherCityMigration.Pull[motivation][populationID] or 0
									local cityPush		= otherCityMigration.Push[motivation][populationID] or 0
								
									Dprint( DEBUG_CITY_SCRIPT, "     -  Motivation : "..Indentation15(motivation) .. " pushValue = ", GCO.ToDecimals(pushValue), " cityPush = ", GCO.ToDecimals(cityPush), " cityPull = ", GCO.ToDecimals(cityPull))
									if cityPush < pushValue then 				-- situation is better in other city than in current city for [motivation]
										if cityPull > 1 then
											weightRatio = weightRatio * 2		-- situation is good in other city
										end
										if pushValue > 1 then
											weightRatio = weightRatio * 5		-- situation is bad in current city
										end
										if motivation == majorMotivation then
											weightRatio = weightRatio * 10		-- this is the most important motivation for migration
										end
										local motivationWeight = (cityPull + pushValue) * weightRatio
										cityWeight = cityWeight + motivationWeight
										Dprint( DEBUG_CITY_SCRIPT, "       -  weightRatio = ", GCO.ToDecimals(weightRatio), " motivationWeight = ", GCO.ToDecimals(motivationWeight), " updated cityWeight = ", GCO.ToDecimals(cityWeight))
									end
								end

								if cityWeight > 0 then
									totalWeight = totalWeight + cityWeight
									table.insert (possibleDestination, {City = city, Weight = cityWeight, MigrationEfficiency = efficiency})
								end
							else
								GCO.Warning("cityMigration is nil for ".. Locale.Lookup(city:GetName()))
							end
						end
					end
				
					-- Migrate to best destinations
					table.sort(possibleDestination, function(a, b) return a.Weight > b.Weight; end)
					local numPlotDest 			= #possibleDestination
					local originePlot			= GCO.GetPlot(self:GetX(), self:GetY())
					plotsToUpdate[originePlot]	= true
					for i, destination in ipairs(possibleDestination) do
						if migrants > 0 and destination.Weight > 0 then
							-- MigrationEfficiency already affect destination.Weight, but when there is not many possible destination 
							-- we want to limit the number of migrants over long routes, so it's included here too 
							totalWeight		= math.max(1, totalWeight) -- do not divide by 0 !!!
							local popMoving = math.floor(migrants * Div(destination.Weight, totalWeight) * destination.MigrationEfficiency)
							if popMoving > 0 then
								if destination.PlotID then
									local plot 				= GCO.GetPlotByIndex(destination.PlotID)
									plotsToUpdate[plot]		= true
									Dprint( DEBUG_CITY_SCRIPT, "- Moving " .. Indentation20(tostring(popMoving) .. " " ..Locale.Lookup(GameInfo.Resources[populationID].Name)).. " to plot ("..tostring(plot:GetX())..","..tostring(plot:GetY())..") with Weight = "..tostring(destination.Weight))
									originePlot:MigrationTo(plot, popMoving)  -- before changing population values to get the correct numbers on each plot
									self:ChangePopulationClass(populationID, -popMoving)
									plot:ChangePopulationClass(populationID, popMoving)
								else
									local city 				= destination.City
									local plot				= GCO.GetPlot(city:GetX(), city:GetY())
									plotsToUpdate[plot]		= true
									Dprint( DEBUG_CITY_SCRIPT, "- Moving " .. Indentation20(tostring(popMoving) .. " " ..Locale.Lookup(GameInfo.Resources[populationID].Name)).. " to city ("..Locale.Lookup(city:GetName())..") with Weight = "..tostring(destination.Weight))
									originePlot:MigrationTo(plot, popMoving)
									self:ChangePopulationClass(populationID, -popMoving)
									city:ChangePopulationClass(populationID, popMoving)
								end
							end
						end	
					end
				end
			end
		end
	end
	
	for plot, _ in oldpairs(plotsToUpdate) do -- orderedpairs crash here
		plot:MatchCultureToPopulation()
	end
	
	Dlog("DoMigration ".. Locale.Lookup(self:GetName()).." /END")
end

function Heal(self)
	--local DEBUG_CITY_SCRIPT = "CityScript"

	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Healing " .. Locale.Lookup(self:GetName()).." id#".. tostring(self:GetKey()).." player#"..tostring(self:GetOwner()))

	local playerID		= self:GetOwner()
	local cityCenter 	= self:GetDistricts():GetDistrict(GameInfo.Districts["DISTRICT_CITY_CENTER"].Index)
	local cityDamage	= cityCenter:GetDamage(DefenseTypes.DISTRICT_GARRISON)
	local wallDamage	= cityCenter:GetDamage(DefenseTypes.DISTRICT_OUTER)
	
	if cityDamage > 0 then
		local requiredMaterielPerHP = healGarrisonBaseMateriel * self:GetSize()
		local availableMateriel 	= self:GetStock(materielResourceID)
		local maxHealed				= math.min(cityDamage, healGarrisonMaxPerTurn, math.floor(Div(availableMateriel, requiredMaterielPerHP)))
		local materielUsed			= maxHealed * requiredMaterielPerHP
		
		self:ChangeStock(materielResourceID, -materielUsed, ResourceUseType.Consume, self:GetKey())	--to do : repair usage	
		local cost 		= self:GetResourceCost(materielResourceID) * materielUsed
		local player 	= GCO.GetPlayer(playerID)
		player:ProceedTransaction(AccountType.Repair, -cost)
		cityCenter:ChangeDamage(DefenseTypes.DISTRICT_GARRISON, - maxHealed)
		
		Dprint( DEBUG_CITY_SCRIPT, "  - Used ".. Indentation8(materielUsed) .." ".. Indentation20(Locale.Lookup(GameInfo.Resources[materielResourceID].Name)) .." to heal ".. tostring(maxHealed), " HP for City Center, cost = "..tostring(cost))
	end
	
	if wallDamage > 0 then
		local bEnemyNear 	= false
		local pDiplomacy	= Players[playerID]:GetDiplomacy()
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			adjacentPlot = Map.GetAdjacentPlot(self:GetX(), self:GetY(), direction);
			if (adjacentPlot ~= nil) and (adjacentPlot:GetUnitCount() > 0) then
				local aUnits = Units.GetUnitsInPlot(adjacentPlot)
				for i, unit in ipairs(aUnits) do
					GCO.AttachUnitFunctions(unit)
					if unit:IsCombat() and pDiplomacy:IsAtWarWith(unit:GetOwner()) then
						bEnemyNear = true
					end
				end
			end
		end
		if not bEnemyNear then
		
			local requiredMaterielPerHP = healOuterDefensesBaseMateriel * self:GetSize()
			local availableMateriel 	= self:GetStock(materielResourceID)
			local maxHealed				= math.min(wallDamage, healOuterDefensesMaxPerTurn, math.floor(Div(availableMateriel, requiredMaterielPerHP)))
			local materielUsed			= maxHealed * requiredMaterielPerHP
			
			self:ChangeStock(materielResourceID, -materielUsed, ResourceUseType.Consume, self:GetKey())	--to do : repair usage	
			local cost 		= self:GetResourceCost(materielResourceID) * materielUsed
			local player 	= GCO.GetPlayer(playerID)
			player:ProceedTransaction(AccountType.Repair, -cost)
			cityCenter:ChangeDamage(DefenseTypes.DISTRICT_OUTER, - maxHealed)
			
			Dprint( DEBUG_CITY_SCRIPT, "  - Used ".. Indentation8(materielUsed) .." ".. Indentation20(Locale.Lookup(GameInfo.Resources[materielResourceID].Name)) .." to heal ".. tostring(maxHealed), " HP for City Wall, cost = "..tostring(cost))
		
		end
	end
end

function UpdateHealth(self)
	local change		= 0
	local currentHealth = self:GetValue("Health") or 0
	local healthValues	= self:GetCached("Health") or {}
	if healthValues.Condensed then
		for cause, value in pairs(healthValues.Condensed) do
			change = change + value
		end
	end
	local newHealth = math.max(-100, math.min(100, currentHealth + change))
	self:SetValue("Health", GCO.ToDecimals(newHealth))
end

function SetHealthValues(self)

	Dlog("SetHealthValues ".. Locale.Lookup(self:GetName()).." /START")
	
	local cache 		= self:GetCache()
	cache.Health 		= { Detailed = {}, Condensed = {}} -- reset values
	local health 		= cache.Health
	local currentHealth = self:GetValue("Health") or 0
	local selfPlot 		= GCO.GetPlot(self:GetX(), self:GetY())
	local player		= GCO.GetPlayer(self:GetOwner())

	-- Normalization
	if currentHealth ~= 0 then
		local normalisation = - GCO.Round(currentHealth / 10)
		if normalisation > 0 then
			health.Condensed["LOC_HEALTH_NORMALIZATION_UP"]		= normalisation
		elseif normalisation < 0 then
			health.Condensed["LOC_HEALTH_NORMALIZATION_DOWN"]	= normalisation		
		end
	end
	
	-- Penalty from Population size
	local populationSize	= self:GetSize()
	health.Detailed["LOC_HEALTH_PENALTY_FROM_POPULATION"]	= - populationSize
	health.Condensed["LOC_HEALTH_PENALTY_FROM_POPULATION"]	= - populationSize
	
	-- Change from Features and local resources (to do : move to XML ?)
	local ChangeHealthFeatures = {
		[GameInfo.Features["FEATURE_FLOODPLAINS"].Index] 	= -0.5,
		[GameInfo.Features["FEATURE_JUNGLE"].Index] 		= -2,
		[GameInfo.Features["FEATURE_MARSH"].Index] 			= -3,
		[GameInfo.Features["FEATURE_FOREST"].Index] 		= 1,
		[GameInfo.Features["FEATURE_FOREST_DENSE"].Index]	= 2,
		[GameInfo.Features["FEATURE_FOREST_SPARSE"].Index]	= 0.5,
	}
	local StringsFromFeatures = {
		[GameInfo.Features["FEATURE_FLOODPLAINS"].Index] 	= "LOC_HEALTH_PENALTY_FROM_FLOODPLAINS",
		[GameInfo.Features["FEATURE_JUNGLE"].Index] 		= "LOC_HEALTH_PENALTY_FROM_JUNGLE",
		[GameInfo.Features["FEATURE_MARSH"].Index] 			= "LOC_HEALTH_PENALTY_FROM_MARSH",
		[GameInfo.Features["FEATURE_FOREST"].Index] 		= "LOC_HEALTH_BONUS_FROM_FOREST",
		[GameInfo.Features["FEATURE_FOREST_DENSE"].Index]	= "LOC_HEALTH_BONUS_FROM_FOREST",
		[GameInfo.Features["FEATURE_FOREST_SPARSE"].Index]	= "LOC_HEALTH_BONUS_FROM_FOREST",	
	}
	local cityPlots	= GCO.GetCityPlots(self)
	for _, plotID in ipairs(cityPlots) do
		local plot = GCO.GetPlotByIndex(plotID)
		if plot and (not plot:IsCity()) then
			local featureID 	= plot:GetFeatureType()
			local resourceID 	= plot:GetResourceType()
			if ChangeHealthFeatures[featureID] then
				health.Condensed[StringsFromFeatures[featureID]] = (health.Condensed[StringsFromFeatures[featureID]] or 0) + Div(ChangeHealthFeatures[featureID], Map.GetPlotDistance(selfPlot:GetX(), selfPlot:GetY(), plot:GetX(), plot:GetY()))
			end
			if GCO.IsResourceFood(resourceID) then
				health.Condensed["LOC_HEALTH_BONUS_FROM_FRESH_FOOD"] = (health.Condensed["LOC_HEALTH_BONUS_FROM_FRESH_FOOD"] or 0) + Div(1, Map.GetPlotDistance(selfPlot:GetX(), selfPlot:GetY(), plot:GetX(), plot:GetY()))
			end
		end
	end
	
	-- Resources in stock
	local stock					= self:GetResources()
	local countFoodVariation	= 0
	
	for resourceKey, value in pairs(stock) do
		local resourceID = tonumber(resourceKey)
		if GCO.IsResourceFood(resourceID) and (value > 0 or self:GetSupply(resourceID) > 0) then
			countFoodVariation = countFoodVariation + 1
		end
		if resourceID == GameInfo.Resources["RESOURCE_SALT"].Index and (value > 0 or self:GetSupply(resourceID) > 0) then
			health.Condensed["LOC_HEALTH_BONUS_FROM_SALT"] = 2
		end
	end
	if countFoodVariation > 1 then
		health.Condensed["LOC_HEALTH_BONUS_FROM_FOOD_DIVERSITY"] = countFoodVariation * 0.5
	end
	
	-- Fresh Water
	local bHasFreshWater 	= false
	local freshWaterBonus	= 3
	if selfPlot:IsFreshWater() then
		bHasFreshWater = true
	end
	
	local district 	= self:GetDistricts():GetDistrict(GameInfo.Districts["DISTRICT_AQUEDUCT"].Index)
	if district and district:IsComplete() then
		if bHasFreshWater then -- Get additional health from Aqueduct
			freshWaterBonus = 5
		else
			bHasFreshWater = true
		end
	end
	
	if bHasFreshWater then
		health.Condensed["LOC_HEALTH_BONUS_FROM_FRESH_WATER"] = freshWaterBonus
	else
		health.Condensed["LOC_HEALTH_PENALTY_FROM_FRESH_WATER"] = -3
	end
	
	-- Food Rationing
	local cityRationning = self:GetValue("FoodRatio") or 1
	if 		cityRationning <= Starvation 		then
		health.Condensed["LOC_HEALTH_PENALTY_FROM_FOOD_RATIONING"] = -8

	elseif 	cityRationning <= heavyRationing 	then
		health.Condensed["LOC_HEALTH_PENALTY_FROM_FOOD_RATIONING"] = -4

	elseif cityRationning <= mediumRationing 	then
		health.Condensed["LOC_HEALTH_PENALTY_FROM_FOOD_RATIONING"] = -2

	elseif cityRationning <= lightRationing 	then
		health.Condensed["LOC_HEALTH_PENALTY_FROM_FOOD_RATIONING"] = -1
	end
	
	-- Buildings
	local buildings = self:GetBuildings()		
	for buildingID, value in pairs(BuildingHealth) do
		if buildings and buildings:HasBuilding(buildingID) then
			health.Condensed["LOC_HEALTH_BONUS_FROM_BUILDINGS"] = (health.Condensed["LOC_HEALTH_BONUS_FROM_BUILDINGS"] or 0) + value
		end
	end
	
	-- Change from Techs (to do : move to XML ?)
	local ChangeHealthTechs = {
		[GameInfo.Technologies["TECH_HERBALISM"].Index] 	= 1,
		[GameInfo.Technologies["TECH_SURGERY"].Index] 		= 1,
	}
	for techID, value in pairs(ChangeHealthTechs) do
		local pScience = player:GetTechs()
		if pScience:HasTech(techID) then
			health.Condensed["LOC_HEALTH_BONUS_FROM_TECHS"] = (health.Condensed["LOC_HEALTH_BONUS_FROM_TECHS"] or 0) + value
		end
	end
	
	Dlog("SetHealthValues ".. Locale.Lookup(self:GetName()).." /END")
end

function DoTurnFirstPass(self)
	--local DEBUG_CITY_SCRIPT = "debug"
	Dlog("DoTurnFirstPass ".. Locale.Lookup(self:GetName()).." /START")
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "First Pass on ".. Locale.Lookup(self:GetName()))
	local cityKey 	= self:GetKey()
	local name 		= Locale.Lookup(self:GetName())
	local cityData 	= ExposedMembers.CityData[cityKey]
	if not cityData then -- this can happen when using Autoplay, so just output a warning
		GCO.Warning("cityData is nil in DoTurnFirstPass, force initialization...")
		InitializeCity(playerID, cityID)
		CitiesToIgnoreThisTurn[cityKey] = true
		return
	end
	
	-- set food rationing
	self:SetCityRationing()
	
	-- resource decay (after setting rationing, before collecting resources)
	self:DoStockDecay()

	-- get linked units and supply demand
	GCO.StartTimer("UpdateLinkedUnits for ".. name)
	self:UpdateLinkedUnits()
	GCO.ShowTimer("UpdateLinkedUnits for ".. name)

	-- get Resources (allow excedents)
	GCO.StartTimer("DoCollectResources for ".. name)
	self:DoCollectResources()
	GCO.ShowTimer("DoCollectResources for ".. name)
	
	--
	self:DoRecruitPersonnel()

	-- prepare food for consumption
	GCO.StartTimer("DoFood for ".. name)
	self:DoFood()
	GCO.ShowTimer("DoFood for ".. name)
	
	--
	GCO.StartTimer("DoNeeds for ".. name)
	self:SetNeedsValues()
	self:DoNeeds()
	GCO.ShowTimer("DoNeeds for ".. name)	

	-- sell to foreign cities (do turn for traders ?), reinforce units, use in industry... (orders set in UI ?)
	GCO.StartTimer("DoIndustries for ".. name)
	self:DoIndustries()
	GCO.ShowTimer("DoIndustries for ".. name)
	
	GCO.StartTimer("DoConstruction for ".. name)
	self:DoConstruction()	
	GCO.ShowTimer("DoConstruction for ".. name)
	
	-- set migration values (note: must Set Needs first)
	GCO.StartTimer("SetMigrationValues for ".. name)
	self:SetMigrationValues()
	GCO.ShowTimer("SetMigrationValues for ".. name)
	
	GCO.StartTimer("DoReinforceUnits for ".. name)
	self:DoReinforceUnits()
	GCO.ShowTimer("DoReinforceUnits for ".. name)
	
	Dlog("DoTurnFirstPass ".. Locale.Lookup(self:GetName()).." /END")
end

function DoTurnSecondPass(self)

	--local DEBUG_CITY_SCRIPT = "debug"
	
	local cityKey 	= self:GetKey()
	local name 		= Locale.Lookup(self:GetName())
	if CitiesToIgnoreThisTurn[cityKey] then return end
	
	Dlog("DoTurnSecondPass ".. name.." /START")
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Second Pass on ".. name)

	local cityData = ExposedMembers.CityData[cityKey]
	if not cityData then -- this should not happen
		GCO.Error("cityData is nil in DoTurnSecondPass")
		return
	end

	-- migration from city center
	GCO.StartTimer("DoMigration for ".. name)
	self:DoMigration()
	GCO.ShowTimer("DoMigration for ".. name)
	
	-- get linked cities and supply demand
	self:UpdateTransferCities()
	
	Dlog("DoTurnSecondPass ".. name.." /END")
end

function DoTurnThirdPass(self)
	--local DEBUG_CITY_SCRIPT = "debug"

	local cityKey 	= self:GetKey()
	local name 		= Locale.Lookup(self:GetName())
	if CitiesToIgnoreThisTurn[cityKey] then return end
	
	Dlog("DoTurnThirdPass ".. name.." /START")
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Third Pass on ".. name)
	
	local cityData = ExposedMembers.CityData[cityKey]
	if not cityData then -- this should not happen
		GCO.Error("cityData is nil in DoTurnThirdPass")
		return
	end

	-- diffuse to other cities, now that all of them have made their request after servicing industries and units
	GCO.StartTimer("TransferToCities for ".. name)
	self:TransferToCities()
	GCO.ShowTimer("TransferToCities for ".. name)

	-- now export what's still available
	self:UpdateExportCities()
	
	GCO.StartTimer("ExportToForeignCities for ".. name)
	self:ExportToForeignCities()
	GCO.ShowTimer("ExportToForeignCities for ".. name)
	
	Dlog("DoTurnThirdPass ".. name.." /END")
end

function DoTurnFourthPass(self)
	--local DEBUG_CITY_SCRIPT = "debug"

	local cityKey 	= self:GetKey()
	local name 		= Locale.Lookup(self:GetName())
	if CitiesToIgnoreThisTurn[cityKey] then return end
	
	Dlog("DoTurnFourthPass ".. name.." /START")
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Fourth Pass on ".. name)
	
	local cityData = ExposedMembers.CityData[cityKey]
	if not cityData then -- this should not happen
		GCO.Error("cityData is nil in DoTurnFourthPass")
		return
	end

	-- Update City Size / social classes / Employment
	GCO.StartTimer("CitySize/SocialClasses for ".. name)
	self:DoGrowth()
	self:SetRealPopulation()
	self:DoSocialClassStratification()
	self:SetWealth()
	self:DoTaxes()
	self:UpdateSize()
	self:Heal()
	self:SetMaxEmploymentRural()
	self:SetMaxEmploymentUrban()
	--self:SetProductionFactorFromBuildings()
	self:SetEmploymentFactorFromBuildings()
	self:SetLiteracy()
	self:DoAdministration()
	GCO.ShowTimer("CitySize/SocialClasses for ".. name)
	
	GCO.StartTimer("Set Health for ".. name)
	self:SetHealthValues()
	self:UpdateHealth()
	GCO.ShowTimer("Set Health  for ".. name)

	-- last...
	GCO.StartTimer("DoStockUpdate for ".. name)
	self:DoStockUpdate()
	GCO.ShowTimer("DoStockUpdate for ".. name)
	
	GCO.StartTimer("SetUnlockers for ".. name)
	self:SetUnlockers()
	GCO.ShowTimer("SetUnlockers for ".. name)
	
	local plot	= GCO.GetPlot(self:GetX(), self:GetY())
	plot:MatchCultureToPopulation()

	Dprint( DEBUG_CITY_SCRIPT, "Fourth Pass done for ".. name)
	
	Dlog("DoTurnFourthPass ".. name.." /END")
end

function DoCitiesTurn( playerID )
	--local DEBUG_CITY_SCRIPT = "debug"
	CitiesToIgnoreThisTurn = {}
	Dlog("DoCitiesTurn /START")
	local player = Players[playerID]
	local playerCities = player:GetCities()
	if playerCities then
		for pass = 1, 4 do
			Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
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
	Dlog("DoCitiesTurn /END")
	GCO.PlayerTurnsDebugChecks[playerID].CitiesTurn	= true
end
--LuaEvents.DoCitiesTurn.Add( DoCitiesTurn )


-----------------------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------------------

function OnCityProductionCompleted(playerID, cityID, productionID, objectID, bCanceled, typeModifier)

	local city = CityManager.GetCity(playerID, cityID)
	
	local DEBUG_CITY_SCRIPT = DEBUG_CITY_SCRIPT
	if (city:GetOwner() == Game.GetLocalPlayer()) then DEBUG_CITY_SCRIPT = "debug" end
	
	if productionID == ProductionTypes.BUILDING then
		if GameInfo.Buildings[objectID] and GameInfo.Buildings[objectID].Unlockers then return end
		
		-- Replace buildings on upgrade
		--BuildingReplacements
		--local buildingID	= GameInfo.Buildings[objectID].Index
		local replacements	= BuildingReplacements[objectID]
		if replacements then
			Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
			Dprint( DEBUG_CITY_SCRIPT, "Checking for obsolete buildings on completion of ".. Locale.Lookup(GameInfo.Buildings[objectID].Name))
			for _, buildingID in ipairs(replacements) do
				if city:GetBuildings():HasBuilding(buildingID) then
					Dprint( DEBUG_CITY_SCRIPT, "  - removing : ".. Locale.Lookup(GameInfo.Buildings[buildingID].Name))
					city:GetBuildings():RemoveBuilding(buildingID)
				end
			end
		end
		
		-- On recruitment...
		if GameInfo.Buildings[objectID].BuildingType =="BUILDING_RECRUITS" then

			--local DEBUG_CITY_SCRIPT = "debug"
			--LuaEvents.SetUnitsDebugLevel("debug")	-- temporary set custom debug level for UnitScript
			
			Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
			Dprint( DEBUG_CITY_SCRIPT, "Completed BUILDING_RECRUITS !")
			
			local number = 1
			if city:GetBuildings():HasBuilding(GameInfo.Buildings["BUILDING_SMALL_BARRACKS"].Index) then
				number = 1
			end
			if city:GetBuildings():HasBuilding(GameInfo.Buildings["BUILDING_BARRACKS"].Index) then
				number = 2
			end
			city:RecruitUnits("UNIT_LIGHT_SPEARMAN", number) -- called with the first unit of the conscript line, it will be upgraded automatically to the best available with the current equipment in city
			
			--LuaEvents.RestoreUnitsDebugLevel()	-- restore previous debug level for UnitScript
	
			-- remove this "project" building
			Dprint( DEBUG_CITY_SCRIPT, "Removing BUILDING_RECRUITS...")
			city:GetBuildings():RemoveBuilding(objectID)
			Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
		end
	end
	Dprint( DEBUG_CITY_SCRIPT, "OnCityProductionCompleted", Locale.Lookup(city:GetName()), playerID, cityID, productionID, objectID, bCanceled, typeModifier)
	city:SetUnlockers()
end
Events.CityProductionCompleted.Add(	OnCityProductionCompleted)

function OnCityProductionUpdated( playerID, cityID, objectID, productionID)

	--local DEBUG_CITY_SCRIPT = "CityScript"

	local city = CityManager.GetCity(playerID, cityID)
	if productionID == ProductionTypes.BUILDING then
		if GameInfo.Buildings[objectID] and GameInfo.Buildings[objectID].Unlockers then return end
	end

	local cityKey			= city:GetKey()
	if _cached.RealProduction and _cached.RealProduction[cityKey] then
		Dprint( DEBUG_CITY_SCRIPT, "Updating production progress for ", Locale.Lookup(city:GetName()), " real production = ", _cached.RealProduction[cityKey])
		city:GetBuildQueue():AddProgress(_cached.RealProduction[cityKey])
		_cached.RealProduction[cityKey] = nil
	end

end
Events.CityProductionUpdated.Add( OnCityProductionUpdated )

function OnCityProductionChanged(playerID, cityID, productionID, objectID, bCanceled, typeModifier)

	local city = CityManager.GetCity(playerID, cityID)
	if productionID == ProductionTypes.BUILDING then
		if GameInfo.Buildings[objectID] and GameInfo.Buildings[objectID].Unlockers then return end
	end

	Dprint( DEBUG_CITY_SCRIPT, "OnCityProductionChanged", Locale.Lookup(city:GetName()), playerID, cityID, productionID, objectID, bCanceled, typeModifier)

	city:SetConstructionEfficiency(1)
	LuaEvents.CityCompositionUpdated(city:GetOwner(), city:GetID())
end
Events.CityProductionChanged.Add( OnCityProductionChanged )

function OnCityFocusChange( playerID, cityID )
	local city = CityManager.GetCity(playerID, cityID)
	Dprint( DEBUG_CITY_SCRIPT, "OnCityFocusChange", Locale.Lookup(city:GetName()), playerID, cityID)
	city:SetUnlockers()
end
Events.CityFocusChanged.Add(OnCityFocusChange );

function OnCityInitialized( playerID: number, cityID : number, cityX : number, cityY : number )
	
	--print("CityAddedToMap - " .. tostring(playerID) .. ":" .. tostring(cityID) .. " " .. tostring(cityX) .. "x" .. tostring(cityY));

	local city = GetCity(playerID, cityID)
	
	-- calling SetHealthValues() here because the initial call from the City Banner Manager is done before the City plots are initialized 
	city:SetHealthValues()
	LuaEvents.CityCompositionUpdated(playerID, cityID)
end
Events.CityInitialized.Add(OnCityInitialized)


-----------------------------------------------------------------------------------------
-- Functions passed from UI Context
-----------------------------------------------------------------------------------------
function GetCityYield(self, yieldType)
	return GCO.GetCityYield( self, yieldType )
end

function GetProductionTurnsLeft(self, productionType)
	return GCO.GetCityProductionTurnsLeft(self, productionType)
end

function GetProductionYield(self)
	return GCO.GetCityProductionYield(self)
end

function GetProductionProgress(self, productionType, objetID)
	return GCO.GetCityProductionProgress(self, productionType, objetID)
end


-----------------------------------------------------------------------------------------
-- General Functions
-----------------------------------------------------------------------------------------
function CleanCitiesData() -- called in GCO_GameScript.lua

	--local DEBUG_CITY_SCRIPT = "CityScript"
	
	-- remove old data from the table
	Dprint( DEBUG_CITY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_CITY_SCRIPT, "Cleaning CityData...")
	
	for cityKey, data1 in pairs(ExposedMembers.CityData) do
		local toClean 	= {"Stock","ResourceCost","ResourceUse","Population"}
		local maxTurn	= 3
		local player 	= Players[data1.playerID]
		if player and player:IsHuman() then
			maxTurn = 10
		end
		
		for i, dataToClean in ipairs(toClean) do
			turnTable = {}
			for turnkey, data2 in pairs(data1[dataToClean]) do
				local turn = tonumber(turnkey)
				if turn <= (Game.GetCurrentGameTurn() - maxTurn) then

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
			SupplyRouteType.__orderedIndex = nil -- manual cleanup for orderedpair
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
	if not city then return end
	local c = getmetatable(city).__index
	
	if c.IsInitializedForGCO == nil then
	
		if not c.IsInitialized						then c.IsInitialized						= IsInitialized							end
		if not c.UpdateSize							then c.UpdateSize							= UpdateSize                        	end
		if not c.GetSize							then c.GetSize								= GetSize                           	end
		if not c.GetRealSize						then c.GetRealSize							= GetRealSize                       	end
		if not c.GetRealPopulation					then c.GetRealPopulation					= GetRealPopulation                 	end
		if not c.SetRealPopulation					then c.SetRealPopulation					= SetRealPopulation                 	end
		if not c.GetRealPopulationVariation			then c.GetRealPopulationVariation			= GetRealPopulationVariation        	end
		if not c.GetKey								then c.GetKey								= GetKey                            	end
		if not c.GetData							then c.GetData								= GetData                           	end
		if not c.GetCache							then c.GetCache								= GetCache                          	end
		if not c.GetCached							then c.GetCached							= GetCached                         	end
		if not c.SetCached							then c.SetCached							= SetCached                         	end
		if not c.GetValue							then c.GetValue								= GetValue                          	end
		if not c.SetValue							then c.SetValue								= SetValue                          	end
		if not c.UpdateDataOnNewTurn				then c.UpdateDataOnNewTurn					= UpdateDataOnNewTurn               	end
		if not c.GetWealth							then c.GetWealth							= GetWealth                         	end
		if not c.SetWealth							then c.SetWealth							= SetWealth                         	end
		if not c.UpdateCosts						then c.UpdateCosts							= UpdateCosts                       	end
		if not c.RecordTransaction					then c.RecordTransaction					= RecordTransaction                 	end
		if not c.GetTransactionValue				then c.GetTransactionValue					= GetTransactionValue               	end
		-- resources
		if not c.GetMaxStock						then c.GetMaxStock							= GetMaxStock                       	end
		if not c.GetStock 							then c.GetStock 							= GetStock                          	end
		if not c.GetResources						then c.GetResources							= GetResources                      	end
		if not c.GetEquipmentList					then c.GetEquipmentList						= GetEquipmentList						end
		if not c.GetPreviousStock					then c.GetPreviousStock						= GetPreviousStock                  	end
		if not c.ChangeStock 						then c.ChangeStock 							= ChangeStock                       	end
		if not c.ChangeBuildingQueueStock			then c.ChangeBuildingQueueStock				= ChangeBuildingQueueStock          	end
		if not c.ClearBuildingQueueStock			then c.ClearBuildingQueueStock				= ClearBuildingQueueStock           	end
		if not c.GetBuildingQueueStock				then c.GetBuildingQueueStock				= GetBuildingQueueStock             	end
		if not c.GetBuildingQueueAllStock			then c.GetBuildingQueueAllStock				= GetBuildingQueueAllStock          	end
		if not c.GetNumRequiredInQueue				then c.GetNumRequiredInQueue				= GetNumRequiredInQueue             	end
		if not c.GetStockVariation					then c.GetStockVariation					= GetStockVariation                 	end
		if not c.GetMinimumResourceCost				then c.GetMinimumResourceCost				= GetMinimumResourceCost            	end
		if not c.GetMaximumResourceCost				then c.GetMaximumResourceCost				= GetMaximumResourceCost            	end
		if not c.GetResourceCost					then c.GetResourceCost						= GetResourceCost                   	end
		if not c.SetResourceCost					then c.SetResourceCost						= SetResourceCost                   	end
		if not c.ChangeResourceCost					then c.ChangeResourceCost					= ChangeResourceCost                	end
		if not c.GetPreviousResourceCost			then c.GetPreviousResourceCost				= GetPreviousResourceCost           	end
		if not c.GetResourceCostVariation			then c.GetResourceCostVariation				= GetResourceCostVariation          	end
		if not c.GetMaxPercentLeftToRequest			then c.GetMaxPercentLeftToRequest			= GetMaxPercentLeftToRequest        	end
		if not c.GetMaxPercentLeftToImport			then c.GetMaxPercentLeftToImport			= GetMaxPercentLeftToImport         	end
		if not c.GetMinPercentLeftToExport			then c.GetMinPercentLeftToExport			= GetMinPercentLeftToExport         	end
		if not c.GetSizeStockRatio					then c.GetSizeStockRatio					= GetSizeStockRatio                 	end
		if not c.GetAvailableStockForUnits			then c.GetAvailableStockForUnits			= GetAvailableStockForUnits         	end
		if not c.GetAvailableStockForCities			then c.GetAvailableStockForCities			= GetAvailableStockForCities        	end
		if not c.GetAvailableStockForExport			then c.GetAvailableStockForExport			= GetAvailableStockForExport        	end
		if not c.GetAvailableStockForIndustries 	then c.GetAvailableStockForIndustries 		= GetAvailableStockForIndustries    	end
		if not c.GetMinimalStockForExport			then c.GetMinimalStockForExport				= GetMinimalStockForExport          	end
		if not c.GetMinimalStockForUnits			then c.GetMinimalStockForUnits				= GetMinimalStockForUnits           	end
		if not c.GetMinimalStockForCities			then c.GetMinimalStockForCities				= GetMinimalStockForCities          	end
		if not c.GetMinimalStockForIndustries		then c.GetMinimalStockForIndustries			= GetMinimalStockForIndustries      	end
		if not c.GetResourcesStockTable				then c.GetResourcesStockTable				= GetResourcesStockTable            	end
		if not c.GetResourcesSupplyTable			then c.GetResourcesSupplyTable				= GetResourcesSupplyTable           	end
		if not c.GetResourcesDemandTable			then c.GetResourcesDemandTable				= GetResourcesDemandTable           	end
		if not c.GetExportCitiesTable				then c.GetExportCitiesTable					= GetExportCitiesTable              	end
		if not c.GetTransferCitiesTable				then c.GetTransferCitiesTable				= GetTransferCitiesTable            	end
		if not c.GetSupplyLinesTable				then c.GetSupplyLinesTable					= GetSupplyLinesTable               	end
		--
		if not c.GetMaxEquipmentStock				then c.GetMaxEquipmentStock					= GetMaxEquipmentStock              	end
		if not c.GetMaxEquipmentStorage				then c.GetMaxEquipmentStorage				= GetMaxEquipmentStorage            	end
		if not c.GetEquipmentStorageLeft			then c.GetEquipmentStorageLeft				= GetEquipmentStorageLeft           	end
		--
		if not c.GetMaxPersonnel					then c.GetMaxPersonnel						= GetMaxPersonnel                   	end
		if not c.GetPersonnel						then c.GetPersonnel							= GetPersonnel                      	end
		if not c.GetPreviousPersonnel				then c.GetPreviousPersonnel					= GetPreviousPersonnel              	end
		if not c.ChangePersonnel					then c.ChangePersonnel						= ChangePersonnel                   	end
		--
		if not c.GetMaxInternalLandRoutes   		then c.GetMaxInternalLandRoutes   			= GetMaxInternalLandRoutes          	end
		if not c.GetMaxInternalRiverRoutes  		then c.GetMaxInternalRiverRoutes  			= GetMaxInternalRiverRoutes         	end
		if not c.GetMaxInternalSeaRoutes    		then c.GetMaxInternalSeaRoutes    			= GetMaxInternalSeaRoutes           	end
		if not c.GetMaxExternalLandRoutes   		then c.GetMaxExternalLandRoutes   			= GetMaxExternalLandRoutes          	end
		if not c.GetMaxExternalRiverRoutes  		then c.GetMaxExternalRiverRoutes  			= GetMaxExternalRiverRoutes         	end
		if not c.GetMaxExternalSeaRoutes    		then c.GetMaxExternalSeaRoutes    			= GetMaxExternalSeaRoutes           	end
		--
		if not c.UpdateLinkedUnits					then c.UpdateLinkedUnits					= UpdateLinkedUnits                 	end
		if not c.GetLinkedUnits						then c.GetLinkedUnits						= GetLinkedUnits                    	end
		if not c.UpdateTransferCities				then c.UpdateTransferCities					= UpdateTransferCities              	end
		if not c.UpdateExportCities					then c.UpdateExportCities					= UpdateExportCities                	end
		if not c.UpdateCitiesConnection				then c.UpdateCitiesConnection				= UpdateCitiesConnection            	end
		if not c.DoReinforceUnits					then c.DoReinforceUnits						= DoReinforceUnits                  	end
		if not c.GetTransferCities					then c.GetTransferCities					= GetTransferCities                 	end
		if not c.GetExportCities					then c.GetExportCities						= GetExportCities                   	end
		if not c.TransferToCities					then c.TransferToCities						= TransferToCities                  	end
		if not c.ExportToForeignCities				then c.ExportToForeignCities				= ExportToForeignCities             	end
		if not c.GetNumResourceNeeded				then c.GetNumResourceNeeded					= GetNumResourceNeeded              	end
		if not c.GetRouteEfficiencyTo				then c.GetRouteEfficiencyTo					= GetRouteEfficiencyTo              	end
		if not c.GetMaxRouteLength					then c.GetMaxRouteLength					= GetMaxRouteLength                 	end
		if not c.SetMaxRouteLength					then c.SetMaxRouteLength					= SetMaxRouteLength                 	end
		if not c.GetTransportCostTo					then c.GetTransportCostTo					= GetTransportCostTo                	end
		if not c.GetRequirements					then c.GetRequirements						= GetRequirements                   	end
		if not c.GetDemand							then c.GetDemand							= GetDemand                         	end
		if not c.GetSupply							then c.GetSupply							= GetSupply								end
		if not c.GetSupplyAtTurn					then c.GetSupplyAtTurn						= GetSupplyAtTurn                   	end
		if not c.GetAverageSupplyAtTurn				then c.GetAverageSupplyAtTurn				= GetAverageSupplyAtTurn               	end
		if not c.GetDemandAtTurn					then c.GetDemandAtTurn						= GetDemandAtTurn                   	end
		if not c.GetUseTypeAtTurn					then c.GetUseTypeAtTurn						= GetUseTypeAtTurn                  	end
		if not c.GetAverageUseTypeOnTurns			then c.GetAverageUseTypeOnTurns				= GetAverageUseTypeOnTurns          	end
		--
		if not c.DoGrowth							then c.DoGrowth								= DoGrowth                          	end
		if not c.GetBirthRate						then c.GetBirthRate							= GetBirthRate                      	end
		if not c.GetDeathRate						then c.GetDeathRate							= GetDeathRate                      	end
		if not c.DoStockUpdate						then c.DoStockUpdate						= DoStockUpdate                       	end
		if not c.DoStockDecay						then c.DoStockDecay							= DoStockDecay                       	end
		if not c.DoFood								then c.DoFood								= DoFood                            	end
		if not c.DoIndustries						then c.DoIndustries							= DoIndustries                      	end
		if not c.DoConstruction						then c.DoConstruction						= DoConstruction                    	end
		if not c.DoNeeds							then c.DoNeeds								= DoNeeds                           	end
		if not c.SetNeedsValues						then c.SetNeedsValues						= SetNeedsValues						end
		if not c.DoTaxes							then c.DoTaxes								= DoTaxes                           	end
		if not c.SetMigrationValues					then c.SetMigrationValues					= SetMigrationValues                	end
		if not c.DoMigration						then c.DoMigration							= DoMigration                       	end
		if not c.Heal								then c.Heal									= Heal                              	end
		if not c.DoTurnFirstPass					then c.DoTurnFirstPass						= DoTurnFirstPass                   	end
		if not c.DoTurnSecondPass					then c.DoTurnSecondPass						= DoTurnSecondPass                  	end
		if not c.DoTurnThirdPass					then c.DoTurnThirdPass						= DoTurnThirdPass                   	end
		if not c.DoTurnFourthPass					then c.DoTurnFourthPass						= DoTurnFourthPass                  	end
		if not c.GetFoodStock						then c.GetFoodStock							= GetFoodStock                      	end
		if not c.GetFoodConsumption 				then c.GetFoodConsumption 					= GetFoodConsumption                	end
		if not c.GetFoodRationing					then c.GetFoodRationing						= GetFoodRationing                  	end
		if not c.GetFoodNeededByPopulationFactor	then c.GetFoodNeededByPopulationFactor		= GetFoodNeededByPopulationFactor   	end
		if not c.DoCollectResources					then c.DoCollectResources					= DoCollectResources                	end
		if not c.SetCityRationing					then c.SetCityRationing						= SetCityRationing                  	end
		if not c.SetUnlockers						then c.SetUnlockers							= SetUnlockers                      	end
		--
		if not c.DoSocialClassStratification		then c.DoSocialClassStratification			= DoSocialClassStratification       	end
		if not c.ChangeUpperClass					then c.ChangeUpperClass						= ChangeUpperClass                  	end
		if not c.ChangeMiddleClass					then c.ChangeMiddleClass					= ChangeMiddleClass                 	end
		if not c.ChangeLowerClass					then c.ChangeLowerClass						= ChangeLowerClass                  	end
		if not c.ChangeSlaveClass					then c.ChangeSlaveClass						= ChangeSlaveClass                  	end
		if not c.GetUpperClass						then c.GetUpperClass						= GetUpperClass                     	end
		if not c.GetMiddleClass						then c.GetMiddleClass						= GetMiddleClass                    	end
		if not c.GetLowerClass						then c.GetLowerClass						= GetLowerClass                     	end
		if not c.GetSlaveClass						then c.GetSlaveClass						= GetSlaveClass                     	end
		if not c.GetPreviousUpperClass				then c.GetPreviousUpperClass				= GetPreviousUpperClass             	end
		if not c.GetPreviousMiddleClass				then c.GetPreviousMiddleClass				= GetPreviousMiddleClass            	end
		if not c.GetPreviousLowerClass				then c.GetPreviousLowerClass				= GetPreviousLowerClass             	end
		if not c.GetPreviousSlaveClass				then c.GetPreviousSlaveClass				= GetPreviousSlaveClass             	end
		if not c.GetMaxUpperClass					then c.GetMaxUpperClass						= GetMaxUpperClass                  	end
		if not c.GetMinUpperClass					then c.GetMinUpperClass						= GetMinUpperClass                  	end
		if not c.GetMaxMiddleClass					then c.GetMaxMiddleClass					= GetMaxMiddleClass                 	end
		if not c.GetMinMiddleClass					then c.GetMinMiddleClass					= GetMinMiddleClass                 	end
		if not c.GetMaxLowerClass					then c.GetMaxLowerClass						= GetMaxLowerClass                  	end
		if not c.GetMinLowerClass					then c.GetMinLowerClass						= GetMinLowerClass                  	end
		if not c.GetPopulationClass					then c.GetPopulationClass					= GetPopulationClass                	end
		if not c.ChangePopulationClass				then c.ChangePopulationClass				= ChangePopulationClass             	end
		if not c.GetPopulationDeathRate				then c.GetPopulationDeathRate				= GetPopulationDeathRate            	end
		if not c.SetPopulationDeathRate				then c.SetPopulationDeathRate				= SetPopulationDeathRate            	end
		if not c.GetBasePopulationDeathRate			then c.GetBasePopulationDeathRate			= GetBasePopulationDeathRate        	end
		if not c.GetPopulationBirthRate				then c.GetPopulationBirthRate				= GetPopulationBirthRate            	end
		if not c.SetPopulationBirthRate				then c.SetPopulationBirthRate				= SetPopulationBirthRate            	end
		if not c.GetBasePopulationBirthRate			then c.GetBasePopulationBirthRate			= GetBasePopulationBirthRate        	end
		if not c.GetMigration						then c.GetMigration							= GetMigration                      	end
		if not c.GetPopulationHousing				then c.GetPopulationHousing					= GetPopulationHousing     			 	end
		
		if not c.GetLiteracy						then c.GetLiteracy							= GetLiteracy                     	 	end
		if not c.SetLiteracy						then c.SetLiteracy							= SetLiteracy                     	 	end
		if not c.CanDoResearch						then c.CanDoResearch						= CanDoResearch                      	end
		--
		if not c.DoRecruitPersonnel					then c.DoRecruitPersonnel					= DoRecruitPersonnel					end
		-- text
		if not c.GetHealthString					then c.GetHealthString						= GetHealthString						end
		if not c.GetHealthIcon						then c.GetHealthIcon						= GetHealthIcon							end
		if not c.GetResourcesStockString			then c.GetResourcesStockString				= GetResourcesStockString           	end
		if not c.GetScienceStockStringTable			then c.GetScienceStockStringTable			= GetScienceStockStringTable      		end
		if not c.GetResourcesStockStringTable		then c.GetResourcesStockStringTable			= GetResourcesStockStringTable      	end
		if not c.GetFoodStockString 				then c.GetFoodStockString 					= GetFoodStockString                	end
		if not c.GetFoodStockIcon 					then c.GetFoodStockIcon 					= GetFoodStockIcon          	      	end
		if not c.GetFoodConsumptionString			then c.GetFoodConsumptionString				= GetFoodConsumptionString          	end
		if not c.GetResourceUseToolTipStringForTurn	then c.GetResourceUseToolTipStringForTurn	= GetResourceUseToolTipStringForTurn	end
		if not c.GetPopulationNeedsEffectsString	then c.GetPopulationNeedsEffectsString		= GetPopulationNeedsEffectsString   	end
		if not c.GetHousingToolTip					then c.GetHousingToolTip					= GetHousingToolTip   					end
		--
		if not c.GetAdministrativeEfficiency		then c.GetAdministrativeEfficiency			= GetAdministrativeEfficiency   		end
		if not c.SetAdministrativeEfficiency		then c.SetAdministrativeEfficiency			= SetAdministrativeEfficiency   		end
		if not c.GetAdministrativeCost				then c.GetAdministrativeCost				= GetAdministrativeCost   				end
		if not c.SetAdministrativeCost				then c.SetAdministrativeCost				= SetAdministrativeCost   				end
		if not c.GetBuildingsAdministrativeFactor	then c.GetBuildingsAdministrativeFactor		= GetBuildingsAdministrativeFactor		end
		if not c.GetAdministrativeCostText			then c.GetAdministrativeCostText			= GetAdministrativeCostText   			end
		if not c.GetAdministrativeSupport			then c.GetAdministrativeSupport				= GetAdministrativeSupport   			end
		if not c.SetAdministrativeSupport			then c.SetAdministrativeSupport				= SetAdministrativeSupport   			end
		if not c.GetpopulationAdministrativeCost	then c.GetpopulationAdministrativeCost		= GetpopulationAdministrativeCost   	end
		if not c.GetTerritoryAdministrativeCost		then c.GetTerritoryAdministrativeCost		= GetTerritoryAdministrativeCost   		end
		if not c.GetTechAdministrativeFactor		then c.GetTechAdministrativeFactor			= GetTechAdministrativeFactor   		end
		if not c.DoAdministration					then c.DoAdministration						= DoAdministration   					end
		--              
		if not c.CanConstruct						then c.CanConstruct							= CanConstruct                      	end
		if not c.CanTrain							then c.CanTrain								= CanTrain                          	end
		if not c.GetProductionTurnsLeft				then c.GetProductionTurnsLeft				= GetProductionTurnsLeft            	end
		if not c.GetProductionYield					then c.GetProductionYield					= GetProductionYield                	end
		if not c.GetConstructionEfficiency			then c.GetConstructionEfficiency			= GetConstructionEfficiency         	end
		if not c.SetConstructionEfficiency			then c.SetConstructionEfficiency			= SetConstructionEfficiency         	end
		if not c.GetProductionProgress				then c.GetProductionProgress				= GetProductionProgress             	end
		if not c.RecruitUnits						then c.RecruitUnits							= RecruitUnits                      	end
		--
		if not c.GetModifiersForEffect				then c.GetModifiersForEffect				= GetModifiersForEffect                	end
		--
		if not c.IsCoastal							then c.IsCoastal							= IsCoastal                        		end
		if not c.GetSeaRange						then c.GetSeaRange							= GetSeaRange                       	end
		if not c.GetSeaRangeToolTip					then c.GetSeaRangeToolTip					= GetSeaRangeToolTip					end
		--
		if not c.GetCityYield						then c.GetCityYield							= GetCityYield                      	end
		if not c.GetCustomYield						then c.GetCustomYield						= GetCustomYield                    	end
		if not c.TurnCreated						then c.TurnCreated							= TurnCreated                       	end
		--
		if not c.GetEraType							then c.GetEraType							= GetEraType                        	end
		if not c.GetUrbanEmploymentSize				then c.GetUrbanEmploymentSize				= GetUrbanEmploymentSize            	end
		if not c.GetCityEmploymentPow				then c.GetCityEmploymentPow					= GetCityEmploymentPow              	end
		if not c.GetCityEmploymentFactor			then c.GetCityEmploymentFactor				= GetCityEmploymentFactor           	end
		if not c.GetEmploymentSize					then c.GetEmploymentSize					= GetEmploymentSize                 	end
		if not c.GetPlotEmploymentPow				then c.GetPlotEmploymentPow					= GetPlotEmploymentPow              	end
		if not c.GetPlotEmploymentFactor			then c.GetPlotEmploymentFactor				= GetPlotEmploymentFactor           	end
		if not c.GetMaxEmploymentRural				then c.GetMaxEmploymentRural				= GetMaxEmploymentRural             	end
		if not c.GetMaxEmploymentUrban				then c.GetMaxEmploymentUrban				= GetMaxEmploymentUrban             	end
		if not c.SetMaxEmploymentRural				then c.SetMaxEmploymentRural				= SetMaxEmploymentRural             	end
		if not c.SetMaxEmploymentUrban				then c.SetMaxEmploymentUrban				= SetMaxEmploymentUrban             	end
		if not c.GetProductionFactorFromBuildings	then c.GetProductionFactorFromBuildings		= GetProductionFactorFromBuildings  	end
		if not c.SetProductionFactorFromBuildings	then c.SetProductionFactorFromBuildings		= SetProductionFactorFromBuildings  	end
		if not c.GetEmploymentFactorFromBuildings	then c.GetEmploymentFactorFromBuildings		= GetEmploymentFactorFromBuildings  	end
		if not c.SetEmploymentFactorFromBuildings	then c.SetEmploymentFactorFromBuildings		= SetEmploymentFactorFromBuildings  	end
		if not c.GetMaxEmploymentFromBuildings		then c.GetMaxEmploymentFromBuildings		= GetMaxEmploymentFromBuildings     	end
		if not c.GetTotalPopulation					then c.GetTotalPopulation					= GetTotalPopulation                	end
		if not c.GetTotalPopulationVariation		then c.GetTotalPopulationVariation			= GetTotalPopulationVariation       	end
		if not c.GetUrbanPopulation					then c.GetUrbanPopulation					= GetUrbanPopulation                	end
		if not c.GetUrbanPopulationVariation		then c.GetUrbanPopulationVariation			= GetUrbanPopulationVariation       	end
		if not c.GetRuralPopulation					then c.GetRuralPopulation					= GetRuralPopulation                	end
		if not c.GetRuralPopulationClass			then c.GetRuralPopulationClass				= GetRuralPopulationClass           	end
		if not c.GetPreviousRuralPopulationClass	then c.GetPreviousRuralPopulationClass		= GetPreviousRuralPopulationClass   	end
		if not c.GetRuralPopulationVariation		then c.GetRuralPopulationVariation			= GetRuralPopulationVariation       	end
		if not c.GetUrbanEmployed					then c.GetUrbanEmployed						= GetUrbanEmployed                  	end
		if not c.GetUrbanActivityFactor				then c.GetUrbanActivityFactor				= GetUrbanActivityFactor            	end
		if not c.GetUrbanProductionFactor			then c.GetUrbanProductionFactor				= GetUrbanProductionFactor          	end
		if not c.GetOutputPerYield					then c.GetOutputPerYield					= GetOutputPerYield						end
		--
		if not c.UpdateHealth						then c.UpdateHealth							= UpdateHealth							end
		if not c.SetHealthValues					then c.SetHealthValues						= SetHealthValues						end

		--
		c.IsInitializedForGCO			= true
	end
end


----------------------------------------------
-- Share functions for other contexts
----------------------------------------------
function ShareFunctions()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.GetCity 							= GetCity
	ExposedMembers.GCO.GetCityKey						= GetKey
	ExposedMembers.GCO.AttachCityFunctions 				= AttachCityFunctions
	ExposedMembers.GCO.GetPopulationPerSize 			= GetPopulationPerSize
	ExposedMembers.GCO.CleanCitiesData 					= CleanCitiesData
	--
	ExposedMembers.GCO.GetCityFromKey 					= GetCityFromKey
	--
	ExposedMembers.GCO.GetSupplyRouteString 			= GetSupplyRouteString
	--
	ExposedMembers.GCO.GetBuildingConstructionResources	= GetBuildingConstructionResources
	--
	ExposedMembers.CityScript_Initialized 				= true
end


----------------------------------------------
-- Initialize after loading
----------------------------------------------
Initialize()
