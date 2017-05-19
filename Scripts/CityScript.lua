--=====================================================================================--
--	FILE:	 CityScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading CityScript.lua...")

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

local SupplyRouteType	= {		-- ENUM for resource trade/transfer route types
		Trader 	= 1,
		Road	= 2,
		River	= 3,
		Coastal	= 4,
		Ocean	= 5,
		Airport	= 6
}

local SupplyRouteLengthFactor = {		-- When calculating supply line efficiency relatively to length
		[SupplyRouteType.Trader]	= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_TRADER_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Road]		= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_ROAD_LENGTH_FACTOR"].Value),
		[SupplyRouteType.River]		= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_RIVER_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Coastal]	= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_SEA_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Ocean]		= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_SEA_LENGTH_FACTOR"].Value),
		[SupplyRouteType.Airport]	= tonumber(GameInfo.GlobalParameters["CITY_ROUTE_AIRPORT_LENGTH_FACTOR"].Value)
}

local ResourceUseType	= {		-- ENUM for resource trade/transfer route types (string as it it used as a key for saved table)
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
}

-- Reference types for Resource usage
local NoReference			= -1
local RefPopulationUpper	= GameInfo.Populations["POPULATION_UPPER"].Type
local RefPopulationMiddle	= GameInfo.Populations["POPULATION_MIDDLE"].Type
local RefPopulationLower	= GameInfo.Populations["POPULATION_LOWER"].Type
local RefPopulationSlave	= GameInfo.Populations["POPULATION_SLAVE"].Type
local RefPopulationAll		= GameInfo.Populations["POPULATION_ALL"].Type

-- Error checking
for row in GameInfo.BuildingResourcesConverted() do
	--print(row.BuildingType, row.ResourceCreated, row.ResourceType, row.MultiResRequired, row.MultiResCreated)
	if row.MultiResRequired and  row.MultiResCreated then
		print ("ERROR : BuildingResourcesConverted contains a row with both MultiResRequired and MultiResCreated set to true:", row.BuildingType, row.ResourceCreated, row.ResourceType, row.MultiResRequired, row.MultiResCreated)
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

local NO_IMPROVEMENT = -1

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

local IncomeExportPercent			= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_EXPORT_PERCENT"].Value)
local IncomeImportPercent			= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_IMPORT_PERCENT"].Value)	

local StartingPopulationBonus		= tonumber(GameInfo.GlobalParameters["CITY_STARTING_POPULATION_BONUS"].Value)

local BaseBirthRate 				= tonumber(GameInfo.GlobalParameters["CITY_BASE_BIRTH_RATE"].Value)
local UpperClassBirthRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_UPPER_CLASS_BIRTH_RATE_FACTOR"].Value)
local MiddleClassBirthRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_MIDDLE_CLASS_BIRTH_RATE_FACTOR"].Value)
local LowerClassBirthRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_LOWER_CLASS_BIRTH_RATE_FACTOR"].Value)
local SlaveClassBirthRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_SLAVE_CLASS_BIRTH_RATE_FACTOR"].Value)

local BaseDeathRate 				= tonumber(GameInfo.GlobalParameters["CITY_BASE_DEATH_RATE"].Value)
local UpperClassDeathRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_UPPER_CLASS_DEATH_RATE_FACTOR"].Value)
local MiddleClassDeathRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_MIDDLE_CLASS_DEATH_RATE_FACTOR"].Value)
local LowerClassDeathRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_LOWER_CLASS_DEATH_RATE_FACTOR"].Value)
local SlaveClassDeathRateFactor 	= tonumber(GameInfo.GlobalParameters["CITY_SLAVE_CLASS_DEATH_RATE_FACTOR"].Value)

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
local medecineResourceID		= GameInfo.Resources["RESOURCE_MEDECINE"].Index
local leatherResourceID			= GameInfo.Resources["RESOURCE_LEATHER"].Index
local plantResourceID			= GameInfo.Resources["RESOURCE_PLANTS"].Index

local foodResourceKey			= tostring(foodResourceID)
local personnelResourceKey		= tostring(personnelResourceID)

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
	}

local notAvailableToExport = {} 			-- cached table with "resources" that can't be exported to other Civilizations
notAvailableToExport[personnelResourceID] 	= true

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
	GCO = ExposedMembers.GCO		-- contains functions from other contexts
	Calendar = ExposedMembers.Calendar
	print ("Exposed Functions from other contexts initialized...")
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
	GCO.SaveTableToSlot(ExposedMembers.CityData, "CityData")
end
LuaEvents.SaveTables.Add(SaveTables)


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
	local baseFoodCost 		= GCO.GetBaseResourceCost(foodResourceID)
	local turnKey 			= GCO.GetTurnKey()

	ExposedMembers.CityData[cityKey] = {
		cityID 					= city:GetID(),
		playerID 				= playerID,
		WoundedPersonnel 		= 0,
		Prisoners				= GCO.CreateEverAliveTableWithDefaultValue(0),
		Stock					= { [turnKey] = {[foodResourceKey] = startingFood, [personnelResourceKey] = personnel} },
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
			print("  - ".. city:GetName() .." is already registered")
			return
		end

		print ("Initializing new city (".. city:GetName() ..") for player #".. tostring(playerID).. " id#" .. tostring(city:GetID()))
		RegisterNewCity(playerID, city)
		print("---------------------------------------------------------------------------")
	else
		print ("- WARNING : tried to initialize nil city for player #".. tostring(playerID))
	end

end

function UpdateCapturedCity(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)
	local originalCityKey 	= GetCityKeyFromIDs(originalCityID, originalOwnerID)
	local newCityKey 		= GetCityKeyFromIDs(newCityID, newOwnerID)
	if ExposedMembers.CityData[originalCityKey] then
		originalData = ExposedMembers.CityData[originalCityKey]

		if ExposedMembers.CityData[newCityKey] then
			local city = CityManager.GetCity(newOwnerID, newCityID)
			print("Updating captured city (".. city:GetName() ..") for player #".. tostring(newOwnerID).. " id#" .. tostring(city:GetID()))
			print("---------------------------------------------------------------------------")

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
	for cityKey, data in pairs(ExposedMembers.CityData) do
		print (cityKey, data)
		for k, v in pairs (data) do
			print ("-", k, v)
			if k == "Prisoners" then
				for id, num in pairs (v) do
					print ("-", "-", id, num)
				end
			end
		end
	end
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
		local city = CityManager.GetCity(ExposedMembers.CityData[cityKey].playerID, ExposedMembers.CityData[cityKey].cityID)
		if city then
			return city
		else
			print("- WARNING: city is nil for GetCityFromKey(".. tostring(cityKey)..")")
			print("--- UnitId = " .. ExposedMembers.CityData[cityKey].cityID ..", playerID = " .. ExposedMembers.CityData[cityKey].playerID )
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

function ChangeSize(self)
	print("check change size to ", self:GetSize()+1, "required =", GetPopulationPerSize(self:GetSize()+1), "current =", self:GetRealPopulation())
	print("check change size to ", self:GetSize()-1, "required =", GetPopulationPerSize(self:GetSize()-1), "current =", self:GetRealPopulation())
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
	print("Max Upper Class %", maxPercent)
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
	print("Min Upper Class %", minPercent)
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
	print("Max Middle Class %", maxPercent)
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
	print("Min Middle Class %", minPercent)
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
	print("Max Lower Class %", maxPercent)
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
	print("Min Lower Class %", minPercent)
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

function GetPreviousUpperClass(self , resourceID)
	local cityKey 		= self:GetKey()	
	local turnKey 		= GCO.GetPreviousTurnKey()
	if ExposedMembers.CityData[cityKey].Population[turnKey] then -- for new city this will be nil
		return ExposedMembers.CityData[cityKey].Population[turnKey].UpperClass or 0
	else
		return self:GetUpperClass()
	end
end

function GetPreviousMiddleClass(self , resourceID)
	local cityKey 		= self:GetKey()	
	local turnKey 		= GCO.GetPreviousTurnKey()
	if ExposedMembers.CityData[cityKey].Population[turnKey] then -- for new city this will be nil
		return ExposedMembers.CityData[cityKey].Population[turnKey].MiddleClass or 0
	else
		return self:GetMiddleClass()
	end
end

function GetPreviousLowerClass(self , resourceID)
	local cityKey 		= self:GetKey()	
	local turnKey 		= GCO.GetPreviousTurnKey()
	if ExposedMembers.CityData[cityKey].Population[turnKey] then -- for new city this will be nil
		return ExposedMembers.CityData[cityKey].Population[turnKey].LowerClass or 0
	else
		return self:GetLowerClass()
	end
end

function GetPreviousSlaveClass(self , resourceID)
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
	print("Updating Linked Units...")
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
				if requirements.Equipment > 0 then
					UnitsSupplyDemand[selfKey].Equipment 		= ( UnitsSupplyDemand[selfKey].Equipment 		or 0 ) + GCO.Round(requirements.Equipment*efficiency/100)
					UnitsSupplyDemand[selfKey].NeedEquipment 	= ( UnitsSupplyDemand[selfKey].NeedEquipment 	or 0 ) + 1
					LinkedUnits[selfKey][unit].NeedEquipment	= true
				end

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

function UpdateCitiesConnection(self, transferCity, sRouteType, bInternalRoute)
	local selfKey = self:GetKey()
	
	-- Convert "Coastal" to "Ocean" with required tech for navigation on Ocean
	-- to do check for docks to allow transfert by sea/rivers
	-- add new building for connection by river (river docks)	
	if sRouteType == "Coastal" then
		local pTech = Players[self:GetOwner()]:GetTechs()
		if pTech and pTech:HasTech(GameInfo.Technologies["TECH_CARTOGRAPHY"].Index) then
			sRouteType = "Ocean"
		end
	end
	
	print("Testing "..tostring(sRouteType).." route from "..Locale.Lookup(self:GetName()).." to ".. Locale.Lookup(transferCity:GetName()))
	local bIsPlotConnected = GCO.IsPlotConnected(Players[self:GetOwner()], Map.GetPlot(self:GetX(), self:GetY()), Map.GetPlot(transferCity:GetX(), transferCity:GetY()), sRouteType, true, nil, GCO.SupplyPathBlocked)
	if bIsPlotConnected then
		local routeLength 	= GCO.GetRouteLength()
		local efficiency 	= GCO.GetRouteEfficiency( routeLength * SupplyRouteLengthFactor[SupplyRouteType[sRouteType]] )
		if efficiency > 0 then
			print(" - Found route at " .. tostring(efficiency).."% efficiency")
			if bInternalRoute then
				if (not CitiesForTransfer[selfKey][transferCity]) or (CitiesForTransfer[selfKey][transferCity].Efficiency < efficiency) then
					CitiesForTransfer[selfKey][transferCity] = { RouteType = SupplyRouteType[sRouteType], Efficiency = efficiency }
				end
			else	
				if (not CitiesForTrade[selfKey][transferCity]) or (CitiesForTrade[selfKey][transferCity].Efficiency < efficiency) then
					CitiesForTrade[selfKey][transferCity] = { RouteType = SupplyRouteType[sRouteType], Efficiency = efficiency }
				end
			end
		else
			print(" - Can't register route, too far away " .. tostring(efficiency).."% efficiency")
		end
	end	
end

function GetTransferCities(self)
	local selfKey = self:GetKey()
	if not CitiesForTransfer[selfKey] then
		self:UpdateTransferCities()
	end
	return CitiesForTransfer[selfKey]
end

function GetExportCities(self)
	local selfKey = self:GetKey()
	if not CitiesForTrade[selfKey] then
		self:UpdateExportCities()
	end
	return CitiesForTrade[selfKey]
end

function UpdateTransferCities(self)
	local selfKey = self:GetKey()
	print("Updating Routes to same Civilization Cities for ".. Locale.Lookup(self:GetName()))
	-- reset entries for that city
	CitiesForTransfer[selfKey] 		= {}	-- Internal transfert to own cities
	CitiesTransferDemand[selfKey] 	= { Resources = {}, NeedResources = {}, ReservedResources = {}, HasPrecedence = {} } -- NeedResources : Number of cities requesting a resource type
	
	local hasRouteTo 	= {}
	local ownerID 		= self:GetOwner()
	local player 		= GCO.GetPlayer(ownerID)
	local playerCities 	= player:GetCities()
	for i, transferCity in playerCities:Members() do
		if transferCity ~= self then
			-- search for trader routes first
			local trade = GCO.GetCityTrade(transferCity)
			local outgoingRoutes = trade:GetOutgoingRoutes()
			for j,route in ipairs(outgoingRoutes) do
				if route ~= nil and route.DestinationCityPlayer == ownerID and route.DestinationCityID == self:GetID() then
					print(" - Found trader from ".. Locale.Lookup(transferCity:GetName()))
					CitiesForTransfer[selfKey][transferCity] 	= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
					hasRouteTo[transferCity] = true
				end
			end

			if not hasRouteTo[transferCity] then
				for j,route in ipairs(trade:GetIncomingRoutes()) do	
					if route ~= nil and route.OriginCityPlayer == ownerID and route.OriginCityID == self:GetID() then
						print(" - Found trader to ".. Locale.Lookup(transferCity:GetName()))
						CitiesForTransfer[selfKey][transferCity] 	= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
						hasRouteTo[transferCity] = true
					end
				end
			end

			-- search for other types or routes
			local bInternalRoute = true
			if not hasRouteTo[transferCity] then
				
				self:UpdateCitiesConnection(transferCity, "Road", bInternalRoute)
				self:UpdateCitiesConnection(transferCity, "River", bInternalRoute)
				self:UpdateCitiesConnection(transferCity, "Coastal", bInternalRoute)

			end
			
			if CitiesForTransfer[selfKey][transferCity] and CitiesForTransfer[selfKey][transferCity].Efficiency > 0 then
			
				local requirements 	= transferCity:GetRequirements(self) -- Get the resources required by transferCity and available in current city (self)...
				local efficiency	= CitiesForTransfer[selfKey][transferCity].Efficiency
				
				CitiesForTransfer[selfKey][transferCity].Resources 		= {}
				CitiesForTransfer[selfKey][transferCity].HasPrecedence 	= {}
	
				for resourceID, value in pairs(requirements.Resources) do
					if value > 0 then
						value = GCO.Round(value*efficiency/100)
						CitiesForTransfer[selfKey][transferCity].Resources[resourceID] 	= ( CitiesForTransfer[selfKey][transferCity].Resources[resourceID]	or 0 ) + value
						CitiesTransferDemand[selfKey].Resources[resourceID] 			= ( CitiesTransferDemand[selfKey].Resources[resourceID] 			or 0 ) + value
						CitiesTransferDemand[selfKey].NeedResources[resourceID] 		= ( CitiesTransferDemand[selfKey].NeedResources[resourceID] 		or 0 ) + 1
						if requirements.HasPrecedence[resourceID] then
							CitiesTransferDemand[selfKey].HasPrecedence[resourceID]				= true
							CitiesForTransfer[selfKey][transferCity].HasPrecedence[resourceID]	= true
							CitiesTransferDemand[selfKey].ReservedResources[resourceID] 		= ( CitiesTransferDemand[selfKey].ReservedResources[resourceID] or 0 ) + value
						end
					end
				end
			end	
		end
	end			
end

function TransferToCities(self)
	print("Transfering to other cities for ".. Locale.Lookup(self:GetName()))
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
				availableStock = math.max(availableStock, GCO.Round(self:GetStock(resourceID)/3))
			else
				availableStock = math.max(availableStock, GCO.Round(self:GetStock(resourceID)/2))
			end
		end
		transfers.Resources[resourceID] = math.min(value, availableStock)
		transfers.ResPerCity[resourceID] = math.floor(transfers.Resources[resourceID]/supplyDemand.NeedResources[resourceID])
		print("- Required ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." = ".. tostring(value), " for " , tostring(supplyDemand.NeedResources[resourceID]) ," cities, available = " .. tostring(availableStock)..", transfer = ".. tostring(transfers.Resources[resourceID]) .. ", transfer priority = " ..tostring(supplyDemand.HasPrecedence[resourceID]) .. ", local priority = " ..tostring(bHasLocalPrecedence) )
	end
	
	for resourceID, value in pairs(transfers.Resources) do
		local resourceLeft			= value
		local maxLoop 				= 5
		local loop 					= 0
		local resourceCost 			= self:GetResourceCost(resourceID)
		local PrecedenceLeft		= supplyDemand.ReservedResources[resourceID] or 0
		local bResourcePrecedence	= supplyDemand.HasPrecedence[resourceID]
		
		while (resourceLeft > 0 and loop < maxLoop) do
			for city, data in pairs(cityToSupply) do
				local requiredValue		= city:GetNumResourceNeeded(resourceID)
				local bCityPrecedence	= cityToSupply[city].HasPrecedence[resourceID]
				if PrecedenceLeft > 0 and bResourcePrecedence and not bCityPrecedence then
					requiredValue = 0
				end
				if requiredValue > 0 then
					local efficiency	= data.Efficiency
					local send 			= math.min(transfers.ResPerCity[resourceID], requiredValue, resourceLeft)
					local costPerUnit	= self:GetTransportCostTo(city) + resourceCost -- to do : cache transport cost
					if (costPerUnit < city:GetResourceCost(resourceID)) or (bCityPrecedence and PrecedenceLeft > 0) then -- this city may be in cityToSupply list for another resource, so check cost here again before sending the resource...
						resourceLeft = resourceLeft - send
						if bCityPrecedence then
							PrecedenceLeft = PrecedenceLeft - send
						end
						city:ChangeStock(resourceID, send, ResourceUseType.TransferIn, selfKey, costPerUnit)
						self:ChangeStock(resourceID, -send, ResourceUseType.TransferOut, city:GetKey())
						print ("  - send " .. tostring(send) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." (".. tostring(efficiency) .."% efficiency) to ".. Locale.Lookup(city:GetName()))
					end
				end
			end
			loop = loop + 1
		end
	end
end

function UpdateExportCities(self)
	print("Updating Export Routes to other Civilizations Cities for ".. Locale.Lookup(self:GetName()))
	
	local selfKey 				= self:GetKey()
	CitiesForTrade[selfKey] 	= {}	-- Export to other civilizations cities
	CitiesTradeDemand[selfKey] 	= { Resources = {}, NeedResources = {}}
	
	local ownerID 		= self:GetOwner()	
	local hasRouteTo 	= {}
	
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player 	= GCO.GetPlayer(iPlayer)
		local pDiplo 	= player:GetDiplomacy()
		if iPlayer ~= ownerID and pDiplo and pDiplo:HasMet( ownerID ) and (not pDiplo:IsAtWarWith( ownerID )) then
			local playerConfig = PlayerConfigurations[iPlayer]
			print("- searching for possible trade routes with "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()))
			local playerCities 	= player:GetCities()
			for i, transferCity in playerCities:Members() do
				if transferCity ~= self then
					-- search for trader routes first
					local trade = GCO.GetCityTrade(transferCity)
					local outgoingRoutes = trade:GetOutgoingRoutes()
					for j,route in ipairs(outgoingRoutes) do
						if route ~= nil and route.DestinationCityPlayer == ownerID and route.DestinationCityID == self:GetID() then
							print(" - Found trader from ".. Locale.Lookup(transferCity:GetName()))
							CitiesForTrade[selfKey][transferCity] 		= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
							hasRouteTo[transferCity] = true
						end
					end

					if not hasRouteTo[transferCity] then
						for j,route in ipairs(trade:GetIncomingRoutes()) do	
							if route ~= nil and route.OriginCityPlayer == ownerID and route.OriginCityID == self:GetID() then
								print(" - Found trader to ".. Locale.Lookup(transferCity:GetName()))
								CitiesForTrade[selfKey][transferCity] 		= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
								hasRouteTo[transferCity] = true
							end
						end
					end

					-- search for other types or routes
					local bHasOpenMarket = GCO.HasPlayerOpenBordersFrom(player, ownerID) -- to do : real diplomatic deal for international trade over normal routes
					local bInternalRoute = false
					if bHasOpenMarket then 
						if not hasRouteTo[transferCity] then
							
							self:UpdateCitiesConnection(transferCity, "Road", bInternalRoute)
							self:UpdateCitiesConnection(transferCity, "River", bInternalRoute)
							self:UpdateCitiesConnection(transferCity, "Coastal", bInternalRoute)

						end
					end
					
					if CitiesForTrade[selfKey][transferCity] and CitiesForTrade[selfKey][transferCity].Efficiency > 0 then
					
						local requirements 	= transferCity:GetRequirements(self) -- Get the resources required by transferCity and available in current city (self)...
						local efficiency	= CitiesForTrade[selfKey][transferCity].Efficiency

						for resourceID, value in pairs(requirements.Resources) do
							if value > 0 and not (notAvailableToExport[resourceID]) then 
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
	print("Export to other Civilizations Cities for ".. Locale.Lookup(self:GetName()))
	
	local selfKey 			= self:GetKey()
	local supplyDemand 		= CitiesTradeDemand[selfKey]
	local transfers 		= {Resources = {}, ResPerCity = {}}	
	local cityToSupply 		= CitiesForTrade[selfKey]
	local bExternalRoute 	= true
	
	table.sort(cityToSupply, function(a, b) return a.Efficiency > b.Efficiency; end)

	for resourceID, value in pairs(supplyDemand.Resources) do
		transfers.Resources[resourceID] = math.min(value, self:GetAvailableStockForExport(resourceID))
		transfers.ResPerCity[resourceID] = math.floor(transfers.Resources[resourceID]/supplyDemand.NeedResources[resourceID])
		print("- Required ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." = ".. tostring(value), " for " , tostring(supplyDemand.NeedResources[resourceID]) ," cities, available = " .. tostring(self:GetAvailableStockForExport(resourceID))..", transfer = ".. tostring(transfers.Resources[resourceID]))
	end
	
	local importIncome = {}
	local exportIncome = 0
	for resourceID, value in pairs(transfers.Resources) do
		local resLeft = value
		local maxLoop = 5
		local loop = 0
		while (resLeft > 0 and loop < maxLoop) do
			for city, data in pairs(cityToSupply) do
				local reqValue = city:GetNumResourceNeeded(resourceID, bExternalRoute)
				if reqValue > 0 then
					local resourceClassType = GameInfo.Resources[resourceID].ResourceClassType
					local efficiency		= data.Efficiency
					local send 				= math.min(transfers.ResPerCity[resourceID], reqValue, resLeft)
					local costPerUnit		= self:GetTransportCostTo(city) + self:GetResourceCost(resourceID)
					if costPerUnit < city:GetResourceCost(resourceID) then -- this city may be in cityToSupply list for another resource, so check cost here again before sending the resource...
						local transactionIncome = send * self:GetResourceCost(resourceID) -- * costPerUnit
						resLeft = resLeft - send
						city:ChangeStock(resourceID, send, ResourceUseType.Import, selfKey, costPerUnit)					
						self:ChangeStock(resourceID, -send, ResourceUseType.Export, city:GetKey())
						importIncome[city] = (importIncome[city] or 0) + transactionIncome
						exportIncome = exportIncome + transactionIncome
						print ("  - Generating "..tostring(transactionIncome).." golds for " .. tostring(send) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." (".. tostring(efficiency) .."% efficiency) send to ".. Locale.Lookup(city:GetName()))
					end
				end
			end
			loop = loop + 1
		end
	end
	
	-- Get gold from trade
	exportIncome = GCO.ToDecimals(exportIncome * IncomeExportPercent / 100)
	if exportIncome > 0 then
		print("Total gold from Export income = " .. exportIncome .." gold for ".. Locale.Lookup(self:GetName()))
		local sText = Locale.Lookup("LOC_GOLD_FROM_EXPORT", exportIncome)
		if Game.GetLocalPlayer() == self:GetOwner() then Game.AddWorldViewText(EventSubTypes.PLOT, sText, self:GetX(), self:GetY(), 0) end
		Players[self:GetOwner()]:GetTreasury():ChangeGoldBalance(exportIncome)
	end
	
	for city, income in pairs(importIncome) do
		income = GCO.ToDecimals(income * IncomeImportPercent / 100)
		if income > 0 then
			print("Total gold from Import income = " .. income .." gold for ".. Locale.Lookup(city:GetName()))
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
	
	if CitiesForTrade[selfKey] and CitiesForTrade[selfKey][city] then
		return CitiesForTrade[selfKey][city].Efficiency or 0
	elseif CitiesForTransfer[selfKey] and CitiesForTransfer[selfKey][city] then
		return CitiesForTransfer[selfKey][city].Efficiency or 0
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
	
	print("GetRequirements for ".. cityName )

	for row in GameInfo.Resources() do
		local resourceID 			= row.Index
		local bCanRequest 			= false
		local bCanTradeResource 	= not((row.NoExport and bExternalRoute) or (row.NoTransfer and (not bExternalRoute)))
		--print("can trade = ", bCanTradeResource,"no export",row.NoExport,"external route",bExternalRoute,"no transfer",row.NoTransfer,"internal route",(not bExternalRoute))
		if player:IsResourceVisible(resourceID) and bCanTradeResource then
			local numResourceNeeded = self:GetNumResourceNeeded(resourceID, bExternalRoute)			
			if numResourceNeeded > 0 then
				local bPriorityRequest	= false
				if fromCity then -- function was called to only request resources available in "fromCity"
					local efficiency 	= fromCity:GetRouteEfficiencyTo(self)
					local transportCost = fromCity:GetTransportCostTo(self)
					if fromCity:GetStock(resourceID) > 0 then
						local fromName	 		= Locale.Lookup(fromCity:GetName())
						print ("    - check for ".. Locale.Lookup(GameInfo.Resources[resourceID].Name), " efficiency", efficiency, " "..fromName.." stock", fromCity:GetStock(resourceID) ," "..cityName.." stock", self:GetStock(resourceID) ," "..fromName.." cost", fromCity:GetResourceCost(resourceID)," transport cost", transportCost, " "..cityName.." cost", self:GetResourceCost(resourceID))
					end
					local bHasMoreStock 	= (fromCity:GetStock(resourceID) > self:GetStock(resourceID))
					local bIsLowerCost 		= (fromCity:GetResourceCost(resourceID) + transportCost < self:GetResourceCost(resourceID))
					bPriorityRequest		= false
					
					if UnitsSupplyDemand[selfKey] and UnitsSupplyDemand[selfKey].Resources[resourceID] and resourceID ~= foodResourceID then -- Units have required this resource...
						numResourceNeeded	= math.min(self:GetMaxStock(resourceID), numResourceNeeded + UnitsSupplyDemand[selfKey].Resources[resourceID])
						bPriorityRequest	= true
					end
			
					if bHasMoreStock and (bIsLowerCost or bPriorityRequest) then
						bCanRequest = true
					end
				else					
					bCanRequest = true
				end
				if bCanRequest then
					requirements.Resources[resourceID] 		= numResourceNeeded
					requirements.HasPrecedence[resourceID] 	= bPriorityRequest
					print("- Required ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." = ".. tostring(requirements.Resources[resourceID])..", Priority = "..tostring(bPriorityRequest))
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
	if self:GetUseTypeAtTurn(resourceID, ResourceUseType.Consume, GCO.GetTurnKey()) == 0 then -- temporary, assume industries are first called
		return self:GetStock(resourceID)
	end
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

function ChangeStock(self, resourceID, value, useType, reference, unitCost)
	
	if value == 0 then return end

	local resourceKey 	= tostring(resourceID)
	local cityKey 		= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	local cityData 		= ExposedMembers.CityData[cityKey]
	
	if not reference then reference = NoReference end
	
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
		
		print("Update Unit Cost of ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." to "..tostring(newCost).." cost/unit, added "..tostring(value).." unit(s) at "..tostring(unitCost).." cost/unit "..surplusStr.." to stock of ".. tostring(actualStock).." unit(s) at ".. tostring(actualCost).." cost/unit " .. halfStockStr)
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
	local maxStock = self:GetSize() * tonumber(GameInfo.GlobalParameters["CITY_STOCK_PER_SIZE"].Value)
	if resourceID == foodResourceID then maxStock = maxStock + baseFoodStock end
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
			
			supply = supply + ( GCO.TableSummation(useData[ResourceUseType.Collect]) 	or 0)
			supply = supply + ( GCO.TableSummation(useData[ResourceUseType.Product]) 	or 0)
			supply = supply + ( GCO.TableSummation(useData[ResourceUseType.Import]) 	or 0)
			supply = supply + ( GCO.TableSummation(useData[ResourceUseType.TransferIn]) or 0)
			supply = supply + ( GCO.TableSummation(useData[ResourceUseType.Pillage]) 	or 0)
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

	local useType = ResourceUseType.Supply
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

function DoFood(self)
	-- get city food yield
	local food = GCO.GetCityYield( self, YieldTypes.FOOD )
	local resourceCost = GCO.GetBaseResourceCost(foodResourceID) * self:GetWealth() * ImprovementCostRatio -- assume that city food yield is low cost (like collected with improvement)
	self:ChangeStock(foodResourceID, food, ResourceUseType.Collect, self:GetKey(), resourceCost)
	
	-- food eaten
	local eaten = self:GetFoodConsumption()
	self:ChangeStock(foodResourceID, - eaten, ResourceUseType.Consume, RefPopulationAll)
end

function SetCityRationing(self)
	print("Set Rationing...")
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
	
	print(" Food stock ", foodStock," Variation ",foodVariation, " Previous turn supply ", previousTurnSupply, " Consumption ", self:GetFoodConsumption(), " ratio ", ratio)
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
	local cityKey 	= self:GetKey()
	local turnKey 	= GCO.GetTurnKey()
	local data 		= ExposedMembers.CityData[cityKey]
	local str 		= ""
	if not data.Stock[turnKey] then return end
	for resourceKey, value in pairs(data.Stock[turnKey]) do
		if (value > 0 and resourceKey ~= foodResourceKey and resourceKey ~= personnelResourceKey) then
			local resourceID 		= tonumber(resourceKey)
			local stockVariation 	= self:GetStockVariation(resourceID)
			local resourceCost 		= self:GetResourceCost(resourceID)
			local costVariation 	= self:GetResourceCostVariation(resourceID)
			local resRow 			= GameInfo.Resources[resourceID]
			local tempIcons 		= { 
					[woodResourceID] 		= "[ICON_RESOURCE_CLOVES]", 
					[materielResourceID] 	= "[ICON_Charges]", 
					[steelResourceID] 		= "[ICON_New]", 
					[medecineResourceID] 	= "[ICON_New]", 
					[leatherResourceID] 	= "[ICON_New]", 
					[plantResourceID] 		= "[ICON_New]", 
				}
			
			if tempIcons[resourceID] then
				str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_RESOURCE_TEMP_ICON_STOCK", value, self:GetMaxStock(resourceID), resRow.Name, tempIcons[resourceID])
			else
				str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_RESOURCE_STOCK", value, self:GetMaxStock(resourceID), resRow.Name, resRow.ResourceType)
			end

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
			
			print("- Actualising cost of "..Locale.Lookup(GameInfo.Resources[resourceID].Name)," actual cost",actualCost,"stock",stock,"maxStock",maxStock,"demand",demand,"supply",supply)
			
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
				print("  New cost = ".. tostring(newCost), "  max cost",maxCost,"min cost",minCost,"turn until full",turnUntilFull,"variation",variation)
				
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
				print("  New cost = ".. tostring(newCost), "  max cost",maxCost,"min cost",minCost,"turn until empty",turnUntilEmpty,"variation",variation)
			
			end
		end			
	end

end

function UpdateDataOnNewTurn(self) -- called for every player at the beginning of a new turn

	print("---------------------------------------------------------------------------")	
	print("Updating Data for ".. Locale.Lookup(self:GetName()))
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
	print("Recruiting Personnel...")
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

	print(" - total needed =", nedded, "generals =", generals,"officers =", officers, "soldiers =",soldiers)
	print(" - max potential =", maxPotential ,"Upper = ", maxUpper, "Middle = ", maxMiddle, "Lower = ", maxLower )
	print(" - total recruits =", totalRecruits, "Generals = ", recruitedGenerals, "Officers = ", recruitedOfficers, "Soldiers = ", recruitedSoldiers )

	self:ChangeUpperClass(-recruitedGenerals)
	self:ChangeMiddleClass(-recruitedOfficers)
	self:ChangeLowerClass(-recruitedSoldiers)
	self:ChangePersonnel(recruitedGenerals, ResourceUseType.Recruit, RefPopulationUpper)
	self:ChangePersonnel(recruitedOfficers, ResourceUseType.Recruit, RefPopulationMiddle)
	self:ChangePersonnel(recruitedSoldiers, ResourceUseType.Recruit, RefPopulationLower)		
end

function DoReinforceUnits(self)
	print("Reinforcing units...")
	local cityKey 				= self:GetKey()
	local cityData 				= ExposedMembers.CityData[cityKey]
	local supplyDemand 			= UnitsSupplyDemand[cityKey]
	local reinforcements 		= {Resources = {}, ResPerUnit = {}}

	if supplyDemand.Equipment and supplyDemand.Equipment > 0 then
		print("- Required Equipment = ", tostring(supplyDemand.Equipment), " for " , tostring(supplyDemand.NeedEquipment) ," units")
	end

	for resourceID, value in pairs(supplyDemand.Resources) do
		reinforcements.Resources[resourceID] = math.min(value, self:GetAvailableStockForUnits(resourceID))
		reinforcements.ResPerUnit[resourceID] = math.floor(reinforcements.Resources[resourceID]/supplyDemand.NeedResources[resourceID])
		print("- Max transferable ".. Locale.Lookup(GameInfo.Resources[resourceID].Name).. " = ".. tostring(value) .. " for " .. tostring(supplyDemand.NeedResources[resourceID]) .." units, available = " .. tostring(self:GetAvailableStockForUnits(resourceID))..", send = ".. tostring(reinforcements.Resources[resourceID]))
	end
	reqValue = {}
	for resourceID, value in pairs(reinforcements.Resources) do
		if directReinforcement[resourceID]  then
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
						print ("  - send " .. tostring(send) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." (@ ".. tostring(efficiency) .."% efficiency) to unit ID#".. tostring(unit:GetID()), Locale.Lookup(UnitManager.GetTypeName(unit)))
					end
				end
				loop = loop + 1
			end
		else
			-- todo : make vehicles from resources
		end
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
		print("-- Collecting " .. tostring(collected) .. " " ..Locale.Lookup(GameInfo.Resources[resourceID].Name).." at ".. tostring(GCO.ToDecimals(resourceCost)) .. " cost/unit")
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

	print("Creating resources in Industries...")
	
	local size 		= self:GetSize()
	local wealth 	= self:GetWealth()

	-- materiel
	local materielprod	= MaterielProductionPerSize * size
	local materielCost 	= GCO.GetBaseResourceCost(materielResourceID) * wealth -- GCO.GetBaseResourceCost(materielResourceID)
	print(" - City production: ".. tostring(materielprod) .." ".. Locale.Lookup(GameInfo.Resources[materielResourceID].Name).." at ".. tostring(GCO.ToDecimals(materielCost)) .. " cost/unit")
	self:ChangeStock(materielResourceID, materielprod, ResourceUseType.Product, self:GetKey(), materielCost)
	
	local MultiResRequired 	= {}
	local MultiResCreated 	= {}
	for row in GameInfo.BuildingResourcesConverted() do
		local buildingID 	= GameInfo.Buildings[row.BuildingType].Index
		if self:GetBuildings():HasBuilding(buildingID) then		
			local resourceRequiredID = GameInfo.Resources[row.ResourceType].Index
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
				if available > 0 then
					local resourceCreatedID = GameInfo.Resources[row.ResourceCreated].Index
					local amountUsed		= math.min(available, row.MaxConverted) 
					local amountCreated		= math.floor(amountUsed * row.Ratio)
					
					-- don't allow excedent if there is no demand
					local bLimitedByExcedent	= false
					local stockVariation 	= self:GetStockVariation(resourceID)
					if amountCreated + self:GetStock(resourceID) > self:GetMaxStock(resourceID) and stockVariation >= 0 then
						local maxCreated 	= self:GetMaxStock(resourceID) - self:GetStock(resourceID)
						amountUsed 			= math.floor(maxCreated / row.Ratio)
						amountCreated		= math.floor(amountUsed * row.Ratio)
						bLimitedByExcedent	= true
					end
					
					if amountCreated > 0 then
						local resourceCost 	= (GCO.GetBaseResourceCost(resourceCreatedID) / row.Ratio * wealth) + (self:GetResourceCost(resourceRequiredID) / row.Ratio)
						print(" - " .. Locale.Lookup(GameInfo.Buildings[buildingID].Name) .." production: ".. tostring(amountCreated) .." ".. Locale.Lookup(GameInfo.Resources[resourceCreatedID].Name).." at ".. tostring(GCO.ToDecimals(resourceCost)) .. " cost/unit, using ".. tostring(amountUsed) .." ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name) ..", limited by excedent = ".. tostring(bLimitedByExcedent))
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
				print(" - " .. Locale.Lookup(GameInfo.Buildings[buildingID].Name) .." production of multiple resources using ".. tostring(available) .." available ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name))
				local amountUsed 			= 0
				local maxRequired			= 0
				local bLimitedByExcedent	= false
				for _, row in ipairs(data2) do
					amountUsed = math.min(available, row.MaxConverted)
					local amountCreated		= math.floor(amountUsed * row.Ratio)
					
					-- don't allow excedent if there is no demand
					local stockVariation 	= self:GetStockVariation(row.ResourceCreated)
					if amountCreated + self:GetStock(row.ResourceCreated) > self:GetMaxStock(row.ResourceCreated) and stockVariation >= 0 then
						amountCreated 		= self:GetMaxStock(row.ResourceCreated) - self:GetStock(row.ResourceCreated)
						amountUsed			= math.floor(amountCreated / row.Ratio)
						bLimitedByExcedent	= true
					end
					maxRequired	= math.max( maxRequired, amountUsed)
					
					if amountCreated > 0 then
						local resourceCost 	= (GCO.GetBaseResourceCost(row.ResourceCreated) / row.Ratio * wealth) + (self:GetResourceCost(resourceRequiredID) / row.Ratio)
						print("    - ".. tostring(amountCreated) .." ".. Locale.Lookup(GameInfo.Resources[row.ResourceCreated].Name).." created at ".. tostring(GCO.ToDecimals(resourceCost)) .. " cost/unit, ratio = " .. tostring(row.Ratio) .. ", used ".. tostring(amountUsed) .." ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name) ..", limited by excedent = ".. tostring(bLimitedByExcedent))
						self:ChangeStock(row.ResourceCreated, amountCreated, ResourceUseType.Product, buildingID, resourceCost)
						bUsed = true
					else					
						print("    - not enough resources available to create ".. Locale.Lookup(GameInfo.Resources[row.ResourceCreated].Name) ..", ratio = " .. tostring(row.Ratio))
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
				print(" - " .. Locale.Lookup(GameInfo.Buildings[buildingID].Name) .." production: ".. tostring(amountCreated) .." ".. Locale.Lookup(GameInfo.Resources[resourceCreatedID].Name).. " using multiple resource")
				local requiredResourceCost = 0
				local totalResourcesRequired = #requiredResourcesRatio
				local totalRatio = 0
				for resourceRequiredID, ratio in pairs(requiredResourcesRatio) do
					local amountUsed = GCO.Round(amountCreated / ratio) -- we shouldn't be here if ratio = 0, and the rounded value should be < maxAmountUsed
					local resourceCost = (self:GetResourceCost(resourceRequiredID) / ratio)
					requiredResourceCost = requiredResourceCost + resourceCost
					totalRatio = totalRatio + ratio
					print("    - ".. tostring(amountUsed) .." ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name) .." used at ".. tostring(GCO.ToDecimals(resourceCost)) .. " cost/unit, ratio = " .. tostring(ratio))
					self:ChangeStock(resourceRequiredID, - amountUsed, ResourceUseType.Consume, buildingID)
				end
				local baseRatio = totalRatio / totalResourcesRequired
				resourceCost = (GCO.GetBaseResourceCost(resourceCreatedID) / baseRatio * wealth) + requiredResourceCost
				print("    - " ..  Locale.Lookup(GameInfo.Resources[resourceCreatedID].Name).. " cost per unit  = "..resourceCost ..", limited by excedent = ".. tostring(bLimitedByExcedent))	
				self:ChangeStock(resourceCreatedID, amountCreated, ResourceUseType.Product, buildingID, resourceCost)
			end			
		end
	end	
end

function DoExcedents(self)

	print("Handling excedent...")

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
		
		print(" - Demobilized personnel =", excedentalPersonnel, "upper class =", toUpper,"middle class =", toMiddle, "lower class =",toLower)

	end

	-- excedental resources are lost
	for resourceKey, value in pairs(cityData.Stock[turnKey]) do
		local resourceID = tonumber(resourceKey)
		local excedent = self:GetStock(resourceID) - self:GetMaxStock(resourceID)
		if excedent > 0 then
			print(" - Excedental ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." destroyed = ".. tostring(excedent))
			self:ChangeStock(resourceID, -excedent, ResourceUseType.Waste)
		end
	end

end

function DoGrowth(self)
	if Game.GetCurrentGameTurn() < 2 then return end -- we need to know the previous year turn to calculate growth rate...
	print("Calculate city growth for ".. Locale.Lookup(self:GetName()))
	local cityKey = self:GetKey()
	--local cityData = ExposedMembers.CityData[cityKey]
	local cityBirthRate = self:GetBirthRate()
	local cityDeathRate = self:GetDeathRate()
	print("Global : cityBirthRate =", cityBirthRate, "cityDeathRate =", cityDeathRate)
	local years = Calendar.GetTurnYearForGame(Game.GetCurrentGameTurn()) - Calendar.GetTurnYearForGame(Game.GetCurrentGameTurn()-1)
	function LimitRate(birth, death)
		local minRate = -2.5
		local maxRate = 3.5
		local rate = math.min(maxRate, math.max(minRate, birth - death))
		return rate
	end
	
	local upperPop	= self:GetUpperClass()
	local middlePop = self:GetMiddleClass()
	local lowerPop	= self:GetLowerClass()
	local slavePop 	= self:GetSlaveClass()	

	function CalculateVar(initialPopulation, populationBirthRateFactor, populationDeathRateFactor )
		return GCO.Round( initialPopulation	* years * LimitRate(cityBirthRate * populationBirthRateFactor, cityDeathRate * populationDeathRateFactor) / 1000)
	end
	local upperVar	= CalculateVar( upperPop, UpperClassBirthRateFactor, UpperClassDeathRateFactor) 
	local middleVar = CalculateVar( middlePop, MiddleClassBirthRateFactor, MiddleClassDeathRateFactor)
	local lowerVar	= CalculateVar( lowerPop, LowerClassBirthRateFactor, LowerClassDeathRateFactor) 
	local slaveVar 	= CalculateVar( slavePop, SlaveClassBirthRateFactor, SlaveClassDeathRateFactor) 
	
	self:ChangeUpperClass(upperVar)
	self:ChangeMiddleClass(middleVar)	
	self:ChangeLowerClass(lowerVar)	
	self:ChangeSlaveClass(slaveVar)		
	
end

function DoSocialClassStratification(self)

	local totalPopultation = self:GetRealPopulation()	
	
	print("---------------------------------------------------------------------------")
	print("Social Stratification: totalPopultation = ", totalPopultation)
	
	local maxUpper = self:GetMaxUpperClass()
	local minUpper = self:GetMinUpperClass()
	
	local maxMiddle = self:GetMaxMiddleClass()
	local minMiddle = self:GetMinMiddleClass()
	
	local maxLower = self:GetMaxLowerClass()
	local minLower = self:GetMinLowerClass()
	
	local actualUpper = self:GetUpperClass()
	local actualMiddle = self:GetMiddleClass()
	local actualLower = self:GetLowerClass()
	
	print("---------------------------------------------------------------------------")
	print("Social Stratification: maxUpper = ", maxUpper)
	print("Social Stratification: actualUpper = ", actualUpper)
	print("Social Stratification: minUpper = ", minUpper)
	print("---------------------------------------------------------------------------")
	print("Social Stratification: maxMiddle = ", maxMiddle)
	print("Social Stratification: actualMiddle = ", actualMiddle)
	print("Social Stratification: minMiddle = ", minMiddle)
	print("---------------------------------------------------------------------------")
	print("Social Stratification: maxLower = ", maxLower)
	print("Social Stratification: actualLower = ", actualLower)
	print("Social Stratification: minLower = ", minLower)
	print("---------------------------------------------------------------------------")
	
	-- Move Upper to Middle
	if actualUpper > maxUpper then
		toMove = actualUpper - maxUpper
		print("Social Stratification: Upper to Middle (from actualUpper > maxUpper) = ", toMove)
		self:ChangeUpperClass(- toMove)
		self:ChangeMiddleClass( toMove)
	end
	-- Move Middle to Upper
	if actualUpper < minUpper then
		toMove = minUpper - actualUpper
		print("Social Stratification: Middle to Upper (from actualUpper < minUpper)= ", toMove)
		self:ChangeUpperClass(toMove)
		self:ChangeMiddleClass(-toMove)
	end
	-- Move Middle to Lower
	if actualMiddle > maxMiddle then
		toMove = actualMiddle - maxMiddle
		print("Social Stratification: Middle to Lower (from actualMiddle > maxMiddle)= ", toMove)
		self:ChangeMiddleClass(-toMove)
		self:ChangeLowerClass(toMove)
	end
	-- Move Lower to Middle
	if actualMiddle < minMiddle then
		toMove = minMiddle - actualMiddle
		print("Social Stratification: Lower to Middle (from actualMiddle < minMiddle)= ", toMove)
		self:ChangeMiddleClass(toMove)
		self:ChangeLowerClass(-toMove)
	end
	-- Move Lower to Middle
	if actualLower > maxLower then
		toMove = actualLower - maxLower
		print("Social Stratification: Lower to Middle (from actualLower > maxLower)= ", toMove)
		self:ChangeMiddleClass(toMove)
		self:ChangeLowerClass(-toMove)
	end
	-- Move Middle to Lower
	if actualLower < minLower then
		toMove = minLower - actualLower
		print("Social Stratification: Middle to Lower (from actualLower < minLower)= ", toMove)
		self:ChangeMiddleClass(-toMove)
		self:ChangeLowerClass(toMove)
	end
end

function DoTurnFirstPass(self)
	print("---------------------------------------------------------------------------")	
	print("First Pass on ".. Locale.Lookup(self:GetName()))
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
	self:DoFood()

	-- sell to foreign cities (do turn for traders ?), reinforce units, use in industry... (orders set in UI ?)
	self:DoIndustries()
	self:DoReinforceUnits()
end

function DoTurnSecondPass(self)
	print("---------------------------------------------------------------------------")
	print("Second Pass on ".. Locale.Lookup(self:GetName()))
	
	-- get linked cities and supply demand
	self:UpdateTransferCities()	
end

function DoTurnThirdPass(self)
	print("---------------------------------------------------------------------------")
	print("Third Pass on ".. Locale.Lookup(self:GetName()))
	
	-- diffuse to other cities, now that all of them have made their request after servicing industries and units
	self:TransferToCities()
	
	-- now export what's still available
	self:UpdateExportCities()
	self:ExportToForeignCities()
end

function DoTurnFourthPass(self)
	print("---------------------------------------------------------------------------")
	print("Fourth Pass on ".. Locale.Lookup(self:GetName()))
	
	-- Update City Size / social classes
	self:DoGrowth()
	self:SetRealPopulation()
	self:DoSocialClassStratification()
	self:SetWealth()
	self:ChangeSize()

	-- last...
	self:DoExcedents()
	
	print("Fourth Pass done for ".. Locale.Lookup(self:GetName()))
	LuaEvents.CityCompositionUpdated(self:GetOwner(), self:GetID())
end

function DoCitiesTurn( playerID )
	local player = Players[playerID]
	local playerCities = player:GetCities()
	if playerCities then
		for pass = 1, 4 do
			print("---------------------------------------------------------------------------")
			print("Cities Turn, pass #" .. tostring(pass))
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
	AttachCityFunctions(city)
	Events.CityAddedToMap.Remove(InitializeCityFunctions)
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
	--
	c.GetMaxPersonnel					= GetMaxPersonnel
	c.GetPersonnel						= GetPersonnel
	c.GetPreviousPersonnel				= GetPreviousPersonnel
	c.ChangePersonnel					= ChangePersonnel
	--
	c.UpdateLinkedUnits					= UpdateLinkedUnits
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
	c.GetTransportCostTo				= GetTransportCostTo
	c.GetRequirements					= GetRequirements
	c.GetDemand							= GetDemand
	c.GetSupplyAtTurn					= GetSupplyAtTurn
	c.GetDemandAtTurn					= GetDemandAtTurn
	c.GetUseTypeAtTurn					= GetUseTypeAtTurn
	--
	c.DoGrowth							= DoGrowth
	c.GetBirthRate						= GetBirthRate
	c.GetDeathRate						= GetDeathRate
	c.DoExcedents						= DoExcedents
	c.DoFood							= DoFood
	c.DoIndustries						= DoIndustries
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
	--
	c.DoRecruitPersonnel				= DoRecruitPersonnel
	-- text
	c.GetResourcesStockString			= GetResourcesStockString
	c.GetFoodStockString 				= GetFoodStockString
	c.GetFoodConsumptionString			= GetFoodConsumptionString

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

