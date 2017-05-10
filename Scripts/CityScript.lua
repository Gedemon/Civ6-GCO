--=====================================================================================--
--	FILE:	 CityScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading CityScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------
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
	
local ResourceValue 		= {			-- cached table with value of resources type
		["RESOURCECLASS_LUXURY"] 	= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_LUXURY"].Value),
		["RESOURCECLASS_STRATEGIC"]	= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_STRATEGIC"].Value),
		["RESOURCECLASS_BONUS"]		= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_BONUS"].Value)
}

-- Error checking
for row in GameInfo.BuildingResourcesConverted() do
	print(row.BuildingType, row.ResourceCreated, row.ResourceType, row.MultiResRequired, row.MultiResCreated)
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

local IsImprovementForResource		= {} -- cached table to check if an improvement is meant for a resouce
local IsImprovementForFeature		= {} -- cached table to check if an improvement is meant for a feature

for row in GameInfo.Improvement_ValidResources() do
	local improvementID = GameInfo.Improvements[row.ImprovementType].Index
	local resourceID 	= GameInfo.Resources[row.ResourceType].Index
	if not IsImprovementForResource[improvementID] then IsImprovementForResource[improvementID] = {} end
	IsImprovementForResource[improvementID][resourceID] = true
end
IsImprovementForFeature[GameInfo.Improvements["IMPROVEMENT_LUMBER_MILL"].Index] = {[GameInfo.Features["FEATURE_FOREST"].Index] = true}

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

local foodResourceKey			= tostring(foodResourceID)
local materielResourceKey		= tostring(materielResourceID)
local steelResourceKey			= tostring(steelResourceID)
local personnelResourceKey		= tostring(personnelResourceID)

local forestFeatureID			= GameInfo.Features["FEATURE_FOREST"].Index
local jungleFeatureID			= GameInfo.Features["FEATURE_JUNGLE"].Index

local baseWoodPerForest			= tonumber(GameInfo.GlobalParameters["RESOURCE_BASE_WOOD_PER_FOREST"].Value)
local baseWoodPerJungle			= tonumber(GameInfo.GlobalParameters["RESOURCE_BASE_WOOD_PER_JUNGLE"].Value)

local BaseImprovementMultiplier	= tonumber(GameInfo.GlobalParameters["RESOURCE_BASE_IMPROVEMENT_MULTIPLIER"].Value)

local directReinforcement = {} 				-- cached table with "resources" that are directly transfered to units
directReinforcement[foodResourceID] 		= true
directReinforcement[materielResourceID] 	= true
directReinforcement[horsesResourceID] 		= true
directReinforcement[personnelResourceID] 	= true

local notAvailableToExport = {} 			-- cached table with "resources" that can't be exported to other Civilizations
notAvailableToExport[personnelResourceID] 	= true

local baseFoodStock 			= tonumber(GameInfo.GlobalParameters["CITY_BASE_FOOD_STOCK"].Value)

local lightRationing 			= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_LIGHT_RATIO"].Value)
local mediumRationing 			= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_MEDIUM_RATIO"].Value)
local heavyRationing 			= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_HEAVY_RATIO"].Value)
local turnsToFamineLight 		= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_TO_FAMINE_LIGHT"].Value)
local turnsToFamineMedium 		= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_TO_FAMINE_MEDIUM"].Value)
local turnsToFamineHeavy 		= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_TO_FAMINE_HEAVY"].Value)
local RationingTurnsLocked		= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_LOCKED"].Value)
local birthRateLightRationing 	= tonumber(GameInfo.GlobalParameters["CITY_LIGHT_RATIONING_BIRTH_PERCENT"].Value)
local birthRateMediumRationing 	= tonumber(GameInfo.GlobalParameters["CITY_MEDIUM_RATIONING_BIRTH_PERCENT"].Value)
local birthRateHeavyRationing	= tonumber(GameInfo.GlobalParameters["CITY_HEAVY_RATIONING_BIRTH_PERCENT"].Value)
local deathRateLightRationing 	= tonumber(GameInfo.GlobalParameters["CITY_LIGHT_RATIONING_DEATH_PERCENT"].Value)
local deathRateMediumRationing 	= tonumber(GameInfo.GlobalParameters["CITY_MEDIUM_RATIONING_DEATH_PERCENT"].Value)
local deathRateHeavyRationing	= tonumber(GameInfo.GlobalParameters["CITY_HEAVY_RATIONING_DEATH_PERCENT"].Value)

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
	ExposedMembers.CityData = GCO.LoadTableFromSlot("CityData") or {}
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
	local upperClass		= GCO.Round(totalPopulation * GCO.GetPlayerUpperClassPercent(playerID) / 100)
	local middleClass		= GCO.Round(totalPopulation * GCO.GetPlayerMiddleClassPercent(playerID) / 100)
	local lowerClass		= totalPopulation - (upperClass + middleClass)
	local startingFood		= GCO.Round(tonumber(GameInfo.GlobalParameters["CITY_BASE_FOOD_STOCK"].Value) / 2)

	ExposedMembers.CityData[cityKey] = {
		cityID 					= city:GetID(),
		playerID 				= playerID,
		Personnel 				= personnel,
		WoundedPersonnel 		= 0,
		PreviousPersonnel		= personnel,
		Prisoners				= GCO.CreateEverAliveTableWithDefaultValue(0),
		Stock					= { [foodResourceKey] = startingFood, [personnelResourceKey] = personnel },
		PreviousStock			= { [foodResourceKey] = startingFood, [personnelResourceKey] = personnel },
		UpperClass				= upperClass,
		MiddleClass				= middleClass,
		LowerClass				= lowerClass,
		PreviousUpperClass		= upperClass,
		PreviousMiddleClass		= middleClass,
		PreviousLowerClass		= lowerClass,
		Slaves					= 0,
		PreviousSlaves			= 0,
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
		print("-------------------------------------")
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
			print("-------------------------------------")

			ExposedMembers.CityData[newCityKey].Personnel 			= 0
			ExposedMembers.CityData[newCityKey].WoundedPersonnel 	= 0
			ExposedMembers.CityData[newCityKey].PreviousPersonnel 	= 0
			for civID, value in pairs(originalData.Prisoners) do
				ExposedMembers.CityData[newCityKey].Prisoners[civID] = value
			end
			ExposedMembers.CityData[newCityKey].Prisoners[tostring(originalOwnerID)] = originalData.Personnel + originalData.WoundedPersonnel
			for resourceID, value in pairs(originalData.Stock) do
				ExposedMembers.CityData[newCityKey].Stock[resourceID] = value
			end
			for resourceID, value in pairs(originalData.PreviousStock) do
				ExposedMembers.CityData[newCityKey].PreviousStock[resourceID] = value
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


-----------------------------------------------------------------------------------------
-- Population functions
-----------------------------------------------------------------------------------------
function GetRealPopulation(self) -- the original city:GetPopulation() returns city size
	local key = self:GetKey()
	if ExposedMembers.CityData[key] then
		return ExposedMembers.CityData[key].UpperClass + ExposedMembers.CityData[key].MiddleClass + ExposedMembers.CityData[key].LowerClass + ExposedMembers.CityData[key].Slaves
	end
	return 0
end

function GetSize(self) -- for code consistency
	return self:GetPopulation()
end

function GetBirthRate(self)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	local birthRate = BaseBirthRate
	local cityRationning = cityData.FoodRatio
	if cityRationning == heavyRationing 	then birthRate = birthRate - (birthRate * birthRateHeavyRationing/100) end
	if cityRationning == mediumRationing 	then birthRate = birthRate - (birthRate * birthRateMediumRationing/100) end
	if cityRationning == lightRationing 	then birthRate = birthRate - (birthRate * birthRateLightRationing/100) end
	return birthRate
end

function GetDeathRate(self)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	local deathRate = BaseDeathRate
	local cityRationning = cityData.FoodRatio
	if cityRationning == heavyRationing 	then deathRate = deathRate + (deathRate * deathRateHeavyRationing/100) end
	if cityRationning == mediumRationing 	then deathRate = deathRate + (deathRate * deathRateMediumRationing/100) end
	if cityRationning == lightRationing 	then deathRate = deathRate + (deathRate * deathRateLightRationing/100) end
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

function DoSocialClassStratification(self)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	local totalPopultation = self:GetRealPopulation()
	local maxUpper = GCO.Round(totalPopultation * 10 / 100)
	local minUpper = GCO.Round(totalPopultation * 1 / 100)
	local maxMiddle = GCO.Round(totalPopultation * 50 / 100)
	local minMiddle = GCO.Round(totalPopultation * 25 / 100)
	local actualUpper = cityData.UpperClass
	local actualMiddle = cityData.MiddleClass
	--[[
	print("Social Stratification: totalPopultation = ", totalPopultation)
	print("Social Stratification: maxUpper = ", maxUpper)
	print("Social Stratification: minUpper = ", minUpper)
	print("Social Stratification: maxMiddle = ", maxMiddle)
	print("Social Stratification: minMiddle = ", minMiddle)
	print("Social Stratification: actualUpper = ", actualUpper)
	print("Social Stratification: actualMiddle = ", actualMiddle)
	--]]
	-- Move Upper to Middle
	if actualUpper > maxUpper then
		toMove = actualUpper - maxUpper
		print("Social Stratification: Upper to Middle = ", toMove)
		self:ChangeUpperClass(- toMove)
		self:ChangeMiddleClass( toMove)
	end
	-- Move Middle to Upper
	if actualUpper < minUpper then
		toMove = minUpper - actualUpper
		print("Social Stratification: Middle to Upper = ", toMove)
		self:ChangeUpperClass(toMove)
		self:ChangeMiddleClass(-toMove)
	end
	-- Move Middle to Lower
	if actualMiddle > maxMiddle then
		toMove = actualMiddle - maxMiddle
		print("Social Stratification: Middle to Lower = ", toMove)
		self:ChangeMiddleClass(-toMove)
		self:ChangeLowerClass(toMove)
	end
	-- Move Lower to Middle
	if actualMiddle < minMiddle then
		toMove = minMiddle - actualMiddle
		print("Social Stratification: Lower to Middle = ", toMove)
		self:ChangeMiddleClass(toMove)
		self:ChangeLowerClass(-toMove)
	end
end

function ChangeUpperClass(self, value)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	ExposedMembers.CityData[cityKey].UpperClass = math.max(0 , cityData.UpperClass + value)
end

function ChangeMiddleClass(self, value)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	ExposedMembers.CityData[cityKey].MiddleClass = math.max(0 , cityData.MiddleClass + value)
end

function ChangeLowerClass(self, value)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	ExposedMembers.CityData[cityKey].LowerClass = math.max(0 , cityData.LowerClass + value)
end

function ChangeSlaveClass(self, value)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	ExposedMembers.CityData[cityKey].Slaves = math.max(0 , cityData.Slaves + value)
end

function GetUpperClass(self)
	local cityKey = self:GetKey()
	return ExposedMembers.CityData[cityKey].UpperClass
end

function GetMiddleClass(self)
	local cityKey = self:GetKey()
	return ExposedMembers.CityData[cityKey].MiddleClass
end

function GetLowerClass(self)
	local cityKey = self:GetKey()
	return ExposedMembers.CityData[cityKey].LowerClass
end

function GetSlaveClass(self)
	local cityKey = self:GetKey()
	return ExposedMembers.CityData[cityKey].Slaves
end

function RecruitPersonnel(self)
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
	self:ChangePersonnel(totalRecruits)
end


-----------------------------------------------------------------------------------------
-- Resources functions
-----------------------------------------------------------------------------------------
function UpdateLinkedUnits(self)
	print("Update Linked Units for ".. Locale.Lookup(self:GetName()))
	LinkedUnits[self] 						= {}
	UnitsSupplyDemand[self] 				= { Resources = {}, NeedResources = {}} -- NeedResources : Number of units requesting a resource type

	for unitKey, data in pairs(ExposedMembers.UnitData) do
		local efficiency = data.SupplyLineEfficiency
		if data.SupplyLineCityKey == self:GetKey() and efficiency > 0 then
			local unit = GCO.GetUnit(data.playerID, data.unitID)
			if unit then
				LinkedUnits[self][unit] = {NeedResources = {}}
				local requirements 	= unit:GetRequirements()
				if requirements.Equipment > 0 then
					UnitsSupplyDemand[self].Equipment 		= ( UnitsSupplyDemand[self].Equipment 		or 0 ) + GCO.Round(requirements.Equipment*efficiency/100)
					UnitsSupplyDemand[self].NeedEquipment 	= ( UnitsSupplyDemand[self].NeedEquipment 	or 0 ) + 1
					LinkedUnits[self][unit].NeedEquipment	= true
				end

				for resourceID, value in pairs(requirements.Resources) do
					if value > 0 then
						UnitsSupplyDemand[self].Resources[resourceID] 		= ( UnitsSupplyDemand[self].Resources[resourceID] 		or 0 ) + GCO.Round(requirements.Resources[resourceID]*efficiency/100)
						UnitsSupplyDemand[self].NeedResources[resourceID] 	= ( UnitsSupplyDemand[self].NeedResources[resourceID] 	or 0 ) + 1
						LinkedUnits[self][unit].NeedResources[resourceID] 	= true
					end
				end
			end
		end
	end
end

function UpdateCitiesConnection(self, transferCity, sRouteType, bInternalRoute)
	-- Convert "Coastal" to "Ocean" with required tech for navigation on Ocean
	-- to do check for docks to allow transfert by sea/rivers
	-- add new building for connection by river (river docks)
	if sRouteType == "Coastal" then
		local pTech = Players[self:GetOwner()]:GetTechs()
		if pTech and pTech:HasTech(GameInfo.Technologies["TECH_CARTOGRAPHY"].Index) then
			sRouteType = "Ocean"
		end
	end
	
	local bIsPlotConnected = GCO.IsPlotConnected(Players[self:GetOwner()], Map.GetPlot(self:GetX(), self:GetY()), Map.GetPlot(transferCity:GetX(), transferCity:GetY()), sRouteType, true, nil, GCO.SupplyPathBlocked)
	if bIsPlotConnected then
		local routeLength 	= GCO.GetRouteLength()
		local efficiency 	= GCO.GetRouteEfficiency( routeLength * SupplyRouteLengthFactor[SupplyRouteType[sRouteType]] )
		print("Found "..tostring(sRouteType).." route to ".. Locale.Lookup(transferCity:GetName()) .." at " .. tostring(efficiency).."% efficiency")
		if bInternalRoute then
			if (not CitiesForTransfer[self][transferCity]) or (CitiesForTransfer[self][transferCity].Efficiency < efficiency) then
				CitiesForTransfer[self][transferCity] = { RouteType = SupplyRouteType[sRouteType], Efficiency = efficiency }
			end
		else	
			if (not CitiesForTrade[self][transferCity]) or (CitiesForTrade[self][transferCity].Efficiency < efficiency) then
				CitiesForTrade[self][transferCity] = { RouteType = SupplyRouteType[sRouteType], Efficiency = efficiency }
			end
		end
	end	
end

function GetTransferCities(self)
	if not CitiesForTransfer[self] then
		self:UpdateTransferCities()
	end
	return CitiesForTransfer[self]
end

function GetExportCities(self)
	if not CitiesForTrade[self] then
		self:UpdateExportCities()
	end
	return CitiesForTrade[self]
end

function UpdateTransferCities(self)
	print("Update Linked Cities for ".. Locale.Lookup(self:GetName()))
	-- reset entries for that city
	CitiesForTransfer[self] 	= {}	-- Internal transfert to own cities
	CitiesTransferDemand[self] 	= { Resources = {}, NeedResources = {}} -- NeedResources : Number of cities requesting a resource type
	
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
					CitiesForTransfer[self][transferCity] 	= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
					hasRouteTo[transferCity] = true
				end
			end

			if not hasRouteTo[transferCity] then
				for j,route in ipairs(trade:GetIncomingRoutes()) do	
					if route ~= nil and route.OriginCityPlayer == ownerID and route.OriginCityID == self:GetID() then
						print(" - Found trader to ".. Locale.Lookup(transferCity:GetName()))
						CitiesForTransfer[self][transferCity] 	= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
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
			
			if CitiesForTransfer[self][transferCity] and CitiesForTransfer[self][transferCity].Efficiency > 0 then
			
				local requirements 	= transferCity:GetRequirements(self) -- Get the resources required by transferCity and available in current city (self)...
				local efficiency	= CitiesForTransfer[self][transferCity].Efficiency

				for resourceID, value in pairs(requirements.Resources) do
					if value > 0 then 
						CitiesTransferDemand[self].Resources[resourceID] 		= ( CitiesTransferDemand[self].Resources[resourceID] 		or 0 ) + GCO.Round(requirements.Resources[resourceID]*efficiency/100)
						CitiesTransferDemand[self].NeedResources[resourceID] 	= ( CitiesTransferDemand[self].NeedResources[resourceID] 	or 0 ) + 1
					end
				end
			end	
		end
	end
end

function ReinforceUnits(self)
	print("Reinforcing units for ".. tostring(self:GetName()))
	local cityKey 				= self:GetKey()
	local cityData 				= ExposedMembers.CityData[cityKey]
	local supplyDemand 			= UnitsSupplyDemand[self]
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
				for unit, data in pairs(LinkedUnits[self]) do
					local efficiency = unit:GetSupplyLineEfficiency()
					if not reqValue[unit] then reqValue[unit] = {} end
					if not reqValue[unit][resourceID] then reqValue[unit][resourceID] = GCO.Round(unit:GetNumResourceNeeded(resourceID)*efficiency/100) end
					if reqValue[unit][resourceID] > 0 then
						local efficiency	= unit:GetSupplyLineEfficiency()
						local send 			= math.min(reinforcements.ResPerUnit[resourceID], reqValue[unit][resourceID], resLeft)
						
						resLeft = resLeft - send
						reqValue[unit][resourceID] = reqValue[unit][resourceID] - send
						
						unit:ChangeStock(resourceID, send)
						self:ChangeStock(resourceID, -send)
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

function TransferToCities(self)
	print("Transfering to other cities for ".. Locale.Lookup(self:GetName()))
	local cityKey 			= self:GetKey()
	local supplyDemand 		= CitiesTransferDemand[self]
	local transfers 		= {Resources = {}, ResPerCity = {}}	
	local cityToSupply 		= CitiesForTransfer[self]
	
	table.sort(cityToSupply, function(a, b) return a.Efficiency > b.Efficiency; end)

	for resourceID, value in pairs(supplyDemand.Resources) do
		transfers.Resources[resourceID] = math.min(value, self:GetAvailableStockForCities(resourceID))
		transfers.ResPerCity[resourceID] = math.floor(transfers.Resources[resourceID]/supplyDemand.NeedResources[resourceID])
		print("- Required ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." = ".. tostring(value), " for " , tostring(supplyDemand.NeedResources[resourceID]) ," cities, available = " .. tostring(self:GetAvailableStockForCities(resourceID))..", transfer = ".. tostring(transfers.Resources[resourceID]))
	end
	
	for resourceID, value in pairs(transfers.Resources) do
		local resLeft = value
		local maxLoop = 5
		local loop = 0
		while (resLeft > 0 and loop < maxLoop) do
			for city, data in pairs(cityToSupply) do
				local reqValue = city:GetNumResourceNeeded(resourceID)
				if reqValue > 0 then
					local efficiency	= data.Efficiency
					local send 			= math.min(transfers.ResPerCity[resourceID], reqValue, resLeft)
					resLeft = resLeft - send
					city:ChangeStock(resourceID, send)
					self:ChangeStock(resourceID, -send)
					print ("  - send " .. tostring(send) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." (".. tostring(efficiency) .."% efficiency) to ".. Locale.Lookup(city:GetName()))
				end
			end
			loop = loop + 1
		end
	end
end

function UpdateExportCities(self)
	print("Update Export list to other Civilizations Cities for ".. Locale.Lookup(self:GetName()))
	
	CitiesForTrade[self] 		= {}	-- Export to other civilizations cities
	CitiesTradeDemand[self] 	= { Resources = {}, NeedResources = {}}
	
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
							CitiesForTrade[self][transferCity] 		= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
							hasRouteTo[transferCity] = true
						end
					end

					if not hasRouteTo[transferCity] then
						for j,route in ipairs(trade:GetIncomingRoutes()) do	
							if route ~= nil and route.OriginCityPlayer == ownerID and route.OriginCityID == self:GetID() then
								print(" - Found trader to ".. Locale.Lookup(transferCity:GetName()))
								CitiesForTrade[self][transferCity] 		= { RouteType = SupplyRouteType.Trader, Efficiency = 100 }
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
					
					if CitiesForTrade[self][transferCity] and CitiesForTrade[self][transferCity].Efficiency > 0 then
					
						local requirements 	= transferCity:GetRequirements(self) -- Get the resources required by transferCity and available in current city (self)...
						local efficiency	= CitiesForTrade[self][transferCity].Efficiency

						for resourceID, value in pairs(requirements.Resources) do
							if value > 0 and not (notAvailableToExport[resourceID]) then 
								CitiesTradeDemand[self].Resources[resourceID] 		= ( CitiesTradeDemand[self].Resources[resourceID] 		or 0 ) + GCO.Round(requirements.Resources[resourceID]*efficiency/100)
								CitiesTradeDemand[self].NeedResources[resourceID] 	= ( CitiesTradeDemand[self].NeedResources[resourceID] 	or 0 ) + 1
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
	
	local cityKey 			= self:GetKey()
	local supplyDemand 		= CitiesTradeDemand[self]
	local transfers 		= {Resources = {}, ResPerCity = {}}	
	local cityToSupply 		= CitiesForTrade[self]
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
					local transactionIncome = send * ResourceValue[resourceClassType]
					resLeft = resLeft - send
					city:ChangeStock(resourceID, send)					
					self:ChangeStock(resourceID, -send)
					importIncome[city] = (importIncome[city] or 0) + transactionIncome
					exportIncome = exportIncome + transactionIncome
					print ("  - Generating "..tostring(transactionIncome).." golds for " .. tostring(send) .." ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." (".. tostring(efficiency) .."% efficiency) send to ".. Locale.Lookup(city:GetName()))
				end
			end
			loop = loop + 1
		end
	end
	
	-- Get gold from trade
	exportIncome = GCO.Round(exportIncome * IncomeExportPercent / 100)
	if exportIncome > 0 then
		print("Total gold from Export income = " .. exportIncome .." gold for ".. Locale.Lookup(self:GetName()))
		local sText = Locale.Lookup("LOC_GOLD_FROM_EXPORT", exportIncome)
		if Game.GetLocalPlayer() == self:GetOwner() then Game.AddWorldViewText(EventSubTypes.PLOT, sText, self:GetX(), self:GetY(), 0) end
		Players[self:GetOwner()]:GetTreasury():ChangeGoldBalance(exportIncome)
	end
	
	for city, income in pairs(importIncome) do
		income = GCO.Round(income * IncomeImportPercent / 100)
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

function GetRequirements(self, fromCity)
	local resourceKey 		= tostring(resourceID)
	local cityKey 			= self:GetKey()
	local cityData 			= ExposedMembers.CityData[cityKey]	
	local player 			= GCO.GetPlayer(self:GetOwner())
	local bExternalRoute 	= (self:GetOwner() ~= fromCity:GetOwner())
	local requirements 		= {}
	requirements.Resources 	= {}
	
	print("GetRequirements for ".. Locale.Lookup(self:GetName()) )

	for row in GameInfo.Resources() do
		local resourceID = row.Index
		local bCanRequest = false
		if player:IsResourceVisible(resourceID) then
			local numResourceNeeded = self:GetNumResourceNeeded(resourceID, bExternalRoute)
			if numResourceNeeded > 0 then
				if fromCity then -- function was called to only request resources available in "fromCity"
					if fromCity:GetStock(resourceID) > self:GetStock(resourceID) then
						bCanRequest = true
					end			
				else
					bCanRequest = true
				end
				if bCanRequest then
					requirements.Resources[resourceID] = numResourceNeeded
					print("- Required ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." = ".. tostring(requirements.Resources[resourceID]))
				end
			end
		end
	end	

	return requirements
end

function CollectResources(self)
	local cityKey 	= self:GetKey()
	local cityData 	= ExposedMembers.CityData[cityKey]
	local player 	= GCO.GetPlayer(self:GetOwner())
	-- get resources on worked tiles
	local cityPlots	= GCO.GetCityPlots(self)
	for _, plotID in ipairs(cityPlots) do
		local plot	= Map.GetPlotByIndex(plotID)
		if plot:GetWorkerCount() > 0 then
			local improvementID = plot:GetImprovementType()
			if plot:GetResourceCount() > 0 then		
				local resourceID = plot:GetResourceType()
				if player:IsResourceVisible(resourceID) then
					local collected = plot:GetResourceCount()
					if IsImprovementForResource[improvementID] and IsImprovementForResource[improvementID][resourceID] then
						collected = collected * BaseImprovementMultiplier
					end
					print("-- Collecting " .. tostring(collected) .. " " ..Locale.Lookup(GameInfo.Resources[resourceID].Name ))
					self:ChangeStock(resourceID, collected)
				end
			end
			local featureID = plot:GetFeatureType()
			local woodCollected = 0
			if featureID == forestFeatureID then
				woodCollected = baseWoodPerForest
			end
			if featureID == jungleFeatureID then
				woodCollected = baseWoodPerJungle
			end
			if woodCollected > 0 then
				if IsImprovementForFeature[improvementID] and IsImprovementForFeature[improvementID][featureID] then
					woodCollected = woodCollected * BaseImprovementMultiplier
				end
				print("-- Collecting " .. tostring(woodCollected) .. " " ..Locale.Lookup(GameInfo.Resources[woodResourceID].Name ))
				self:ChangeStock(woodResourceID, woodCollected)
			end
		end
	end
end

function ChangeStock(self, resourceID, value)
	local resourceKey = tostring(resourceID)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	if resourceKey == personnelResourceKey then
		ExposedMembers.CityData[cityKey].Personnel = math.max(0, cityData.Personnel + value)

	elseif not ExposedMembers.CityData[cityKey].Stock[resourceKey] then
		ExposedMembers.CityData[cityKey].Stock[resourceKey] = math.max(0 , value)

	else
		ExposedMembers.CityData[cityKey].Stock[resourceKey] = math.max(0 , cityData.Stock[resourceKey] + value)
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
	if resourceID == personnelResourceID then return self:GetPersonnel() end
	local cityKey = self:GetKey()
	local resourceKey = tostring(resourceID)
	return ExposedMembers.CityData[cityKey].Stock[resourceKey] or 0
end

function GetAvailableStockForUnits(self, resourceID)
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

function GetAvailableStockForIndustries(self, resourceID)
	local minPercentLeft = MinPercentLeftToConvert
	if ResourceUsage[resourceID] then
		minPercentLeft = ResourceUsage[resourceID].MinPercentLeftToConvert
	end
	local minStockLeft = GCO.Round(self:GetMaxStock(resourceID)*minPercentLeft/100)
	return math.max(0, self:GetStock(resourceID)-minStockLeft)
end

function GetMaxPersonnel(self) -- called by GetMaxStock(self, personnelResourceID)
	local maxPersonnel = self:GetSize() * tonumber(GameInfo.GlobalParameters["CITY_PERSONNEL_PER_SIZE"].Value)

	return maxPersonnel
end

function GetPersonnel(self) -- called by GetStock(self, personnelResourceID)
	local key = self:GetKey()
	if ExposedMembers.CityData[key] then
		return ExposedMembers.CityData[key].Personnel or 0
	end
	return 0
end

function ChangePersonnel(self, value) -- equivalent to ChangeStock(self, personnelResourceID, value)
	local cityKey = self:GetKey()
	ExposedMembers.CityData[cityKey].Personnel = math.max(0 , ExposedMembers.CityData[cityKey].Personnel + value)
end

function GetFoodConsumption(self)
	local cityKey = self:GetKey()
	local data = ExposedMembers.CityData[cityKey]
	local foodConsumption1000 = 0
	local ratio = data.FoodRatio
	foodConsumption1000 = foodConsumption1000 + (data.UpperClass 		* tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_UPPER_CLASS_FACTOR"].Value) )
	foodConsumption1000 = foodConsumption1000 + (data.MiddleClass 		* tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_MIDDLE_CLASS_FACTOR"].Value) )
	foodConsumption1000 = foodConsumption1000 + (data.LowerClass 		* tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_LOWER_CLASS_FACTOR"].Value) )
	foodConsumption1000 = foodConsumption1000 + (data.Slaves 			* tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_SLAVE_CLASS_FACTOR"].Value) )
	foodConsumption1000 = foodConsumption1000 + (data.Personnel 		* tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PERSONNEL_FACTOR"].Value) )
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

function DoFood(self)
	-- get city food yield
	local food = GCO.GetCityYield( self, YieldTypes.FOOD )
	-- food eaten
	local eaten = self:GetFoodConsumption()
	self:ChangeStock(foodResourceID, food - eaten)
end

function SetCityRationing(self)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	local ratio 				= cityData.FoodRatio
	local foodStock 			= cityData.Stock[foodResourceKey]
	if foodStock == 0 then
		ratio = heavyRationing
		ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		ExposedMembers.CityData[cityKey].FoodRatio = ratio
		return
	end
	local foodVariation 		= foodStock - cityData.PreviousStock[foodResourceKey]
	if foodVariation < 0 then
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
		if cityData.FoodRatio == heavyRationing then
			ratio = mediumRationing
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif cityData.FoodRatio == mediumRationing then
			ratio = lightRationing
			ExposedMembers.CityData[cityKey].FoodRatioTurn = Game.GetCurrentGameTurn()
		elseif cityData.FoodRatio == lightRationing then
			ratio = 1
		end
	end
	ExposedMembers.CityData[cityKey].FoodRatio = ratio
end

function DoIndustries(self)

	print("Creating resources in Industries...")
	
	local size = self:GetSize()

	-- materiel
	local materielprod	= MaterielProductionPerSize * size
	print(" - City production: ".. tostring(materielprod) .." ".. Locale.Lookup(GameInfo.Resources[materielResourceID].Name))
	self:ChangeStock(materielResourceID, materielprod)
	
	local MultiRes = {}
	for row in GameInfo.BuildingResourcesConverted() do
		local buildingID 	= GameInfo.Buildings[row.BuildingType].Index
		if self:GetBuildings():HasBuilding(buildingID) then		
			local resourceRequiredID = GameInfo.Resources[row.ResourceType].Index
			if row.MultiResRequired then
				local resourceCreatedID = GameInfo.Resources[row.ResourceCreated].Index
				if not MultiRes[resourceCreatedID] then	MultiRes[resourceCreatedID] = {} end
				table.insert(MultiRes[resourceCreatedID][buildingID], {ResourceRequired = resourceRequiredID, MaxConverted = row.MaxConverted, Ratio = row.Ratio})
			else		
				local available = self:GetAvailableStockForIndustries(resourceRequiredID)
				if available > 0 then
					if row.MultiResCreated then
					
					else
						local resourceCreatedID = GameInfo.Resources[row.ResourceCreated].Index
						local amountUsed		= math.min(available, row.MaxConverted) 
						local amountCreated		= math.floor(amountUsed * row.Ratio)
						if amountCreated > 0 then
							print(" - " .. Locale.Lookup(GameInfo.Buildings[buildingID].Name) .." production: ".. tostring(amountCreated) .." ".. Locale.Lookup(GameInfo.Resources[ResourceCreatedID].Name).. " using ".. tostring(amountUsed) .." ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name))
							self:ChangeStock(resourceRequiredID, - amountUsed)
							self:ChangeStock(resourceCreatedID, amountCreated)
						end
					
					end
				end
			end
		end
	end
	
	for resourceCreatedID, data1 in pairs(MultiRes) do
		for buildingID, data2 in pairs (data1) do
			local bCanCreate				= true
			local requiredResourcesRatio 	= {}
			local amountCreated				= nil
			for _, row in ipairs(data2) do
				if bCanCreate then
					local available = self:GetAvailableStockForIndustries(row.ResourceRequired)
					if available > 0 then						
						local maxAmountUsed			= math.min(available, row.MaxConverted) 
						local maxResourceCreated	= maxAmountUsed * row.Ratio -- no rounding here, we'll use this number to recalculate the amount used
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
				print(" - " .. Locale.Lookup(GameInfo.Buildings[buildingID].Name) .." production: ".. tostring(amountCreated) .." ".. Locale.Lookup(GameInfo.Resources[ResourceCreatedID].Name).. " using multiple resource")
				self:ChangeStock(ResourceCreatedID, amountCreated)
				for resourceRequiredID, ratio in pairs(requiredResourcesRatio) do
					local amountUsed = GCO.Round(amountCreated / ratio) -- we shouldn't be here if ratio = 0, and the rounded value should be < maxAmountUsed
					print("    - ".. tostring(amountUsed) .." ".. Locale.Lookup(GameInfo.Resources[resourceRequiredID].Name) .." used")
					self:ChangeStock(resourceRequiredID, - amountUsed)
				end
			end			
		end
	end	
end

function DoExcedents(self)

	print("Handling excedent...")

	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]

	-- excedental resources are lost
	for resourceKey, value in pairs(cityData.Stock) do
		local resourceID = tonumber(resourceKey)
		local excedent = self:GetStock(resourceID) - self:GetMaxStock(resourceID)
		if excedent > 0 then
			print(" - Excedental ".. Locale.Lookup(GameInfo.Resources[resourceID].Name) .." destroyed = ".. tostring(excedent))
			self:ChangeStock(resourceID, -excedent)
		end
	end

	-- excedental personnel is sent back to civil life... (to do : send them to another location if available)
	local excedentalPersonnel = self:GetPersonnel() - self:GetMaxPersonnel()

	if excedentalPersonnel > 0 then

		local toUpper 	= GCO.Round(excedentalPersonnel * PersonnelToUpperClassRatio)
		local toMiddle 	= GCO.Round(excedentalPersonnel * PersonnelToMiddleClassRatio)
		local toLower	= math.max(0, excedentalPersonnel - (toMiddle + toUpper))

		self:ChangeUpperClass(toUpper)
		self:ChangeMiddleClass(toMiddle)
		self:ChangeLowerClass(toLower)

		print(" - Demobilized personnel =", excedentalPersonnel, "upper class =", toUpper,"middle class =", toMiddle, "lower class =",toLower)

	end
end

----------------------------------------------
-- Texts function
----------------------------------------------
function GetResourcesStockString(self)
	local cityKey = self:GetKey()
	local data = ExposedMembers.CityData[cityKey]
	local str = ""
	for resourceKey, value in pairs(data.Stock) do
		if (value > 0 or resourceKey == foodResourceKey) and (resourceKey ~= personnelResourceKey) then
			local stockVariation = value - (data.PreviousStock[resourceKey] or 0)
			local resourceID = tonumber(resourceKey)
			local resRow = GameInfo.Resources[resourceID]
			if resourceID == foodResourceID then
				str = str .. "[NEWLINE]" .. self:GetFoodStockString()
			elseif resourceID == woodResourceID then
				str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_WOOD_STOCK", value, self:GetMaxStock(resourceID))
			elseif resourceID == materielResourceID then
				str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_MATERIEL_STOCK", value, self:GetMaxStock(resourceID))
			else
				str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_RESOURCE_STOCK", value, self:GetMaxStock(resourceID), resRow.Name, resRow.ResourceType)
			end

			if stockVariation > 0 then
				str = str .. "[ICON_PressureUp][COLOR_Civ6Green] +".. tostring(stockVariation).."[ENDCOLOR]"
			elseif stockVariation < 0 then
				str = str .." [ICON_PressureDown][COLOR_Civ6Red] ".. tostring(stockVariation).."[ENDCOLOR]"
			end
		end
	end
	return str
end

function GetFoodStockString(self)
	local cityKey = self:GetKey()
	local data = ExposedMembers.CityData[cityKey]
	--local baseFoodStock 		= GetCityBaseFoodStock(data)
	local maxFoodStock 			= self:GetMaxStock(foodResourceID)
	local foodStock 			= data.Stock[foodResourceKey]
	--local foodStockVariation 	= foodStock - data.PreviousStock[foodResourceKey]
	local cityRationning 		= data.FoodRatio
	local str 					= ""
	if cityRationning == heavyRationing then
		str = Locale.Lookup("LOC_UNITFLAG_FOOD_RATION_HEAVY_RATIONING", foodStock, maxFoodStock)
	elseif cityRationning == mediumRationing then
		str = Locale.Lookup("LOC_UNITFLAG_FOOD_RATION_MEDIUM_RATIONING", foodStock, maxFoodStock)
	elseif cityRationning == lightRationing then
		str = Locale.Lookup("LOC_UNITFLAG_FOOD_RATION_LIGHT_RATIONING", foodStock, maxFoodStock)
	else
		str = Locale.Lookup("LOC_UNITFLAG_FOOD_RATION", foodStock, maxFoodStock)
	end
	--[[
	if foodStockVariation > 0 then
		str = str .. "[ICON_PressureUp] +".. tostring(foodStockVariation).."[ENDCOLOR]"
	elseif foodStockVariation < 0 then
		str = str .." [ICON_PressureDown][COLOR_Civ6Red] ".. tostring(foodStockVariation).."[ENDCOLOR]"
	end
	--]]

	return str
end


-----------------------------------------------------------------------------------------
-- Do Turn for Cities
-----------------------------------------------------------------------------------------
function DoGrowth(self)
	if Game.GetCurrentGameTurn() < 2 then return end -- we need to know the previous year turn to calculate growth rate...
	print("Calculate city growth for ".. Locale.Lookup(self:GetName()))
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
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
	ExposedMembers.CityData[cityKey].UpperClass		= cityData.UpperClass	+ GCO.Round( cityData.UpperClass	* years * LimitRate(cityBirthRate * UpperClassBirthRateFactor 	, cityDeathRate * UpperClassDeathRateFactor) / 1000)
	ExposedMembers.CityData[cityKey].MiddleClass	= cityData.MiddleClass	+ GCO.Round( cityData.MiddleClass	* years * LimitRate(cityBirthRate * MiddleClassBirthRateFactor 	, cityDeathRate * MiddleClassDeathRateFactor) / 1000)
	ExposedMembers.CityData[cityKey].LowerClass		= cityData.LowerClass	+ GCO.Round( cityData.LowerClass	* years * LimitRate(cityBirthRate * LowerClassBirthRateFactor 	, cityDeathRate * LowerClassDeathRateFactor) / 1000)
	ExposedMembers.CityData[cityKey].Slaves			= cityData.Slaves		+ GCO.Round( cityData.Slaves		* years * LimitRate(cityBirthRate * SlaveClassBirthRateFactor 	, cityDeathRate * SlaveClassDeathRateFactor) / 1000)
end

function DoTurnFirstPass(self)
	print("-------------------------------------")
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]

	-- set food rationing
	self:SetCityRationing()

	-- set previous values
	for resourceID, value in pairs(cityData.Stock) do
		ExposedMembers.CityData[cityKey].PreviousStock[resourceID]	= cityData.Stock[resourceID]
	end	
	ExposedMembers.CityData[cityKey].PreviousUpperClass		= ExposedMembers.CityData[cityKey].UpperClass
	ExposedMembers.CityData[cityKey].PreviousMiddleClass	= ExposedMembers.CityData[cityKey].MiddleClass
	ExposedMembers.CityData[cityKey].PreviousLowerClass		= ExposedMembers.CityData[cityKey].LowerClass
	ExposedMembers.CityData[cityKey].PreviousSlaves			= ExposedMembers.CityData[cityKey].Slaves
	ExposedMembers.CityData[cityKey].PreviousPersonnel		= ExposedMembers.CityData[cityKey].Personnel

	-- get linked units and supply demand
	self:UpdateLinkedUnits()

	-- get Resources (allow excedents)
	self:CollectResources()
	self:RecruitPersonnel()

	-- feed population
	self:DoFood()

	-- sell to foreign cities (do turn for traders ?), reinforce units, use in industry... (orders set in UI ?)
	self:DoIndustries()
	self:ReinforceUnits()
	self:UpdateExportCities()
	self:ExportToForeignCities()
end

function DoTurnSecondPass(self)
	print("-------------------------------------")
	-- get linked cities and supply demand
	self:UpdateTransferCities()	
end

function DoTurnThirdPass(self)
	print("-------------------------------------")
	-- diffuse to other cities, now that all of them have made their request after servicing industries, units and export
	self:TransferToCities()
end

function DoTurnFourthPass(self)
	print("-------------------------------------")
	-- Update City Size
	self:DoGrowth()
	self:DoSocialClassStratification()
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
			print("-------------------------------------")
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
	c.GetKey							= GetKey
	c.GetMaxStock						= GetMaxStock
	c.GetStock 							= GetStock
	c.GetMaxPercentLeftToRequest		= GetMaxPercentLeftToRequest
	c.GetMaxPercentLeftToImport			= GetMaxPercentLeftToImport
	c.GetMinPercentLeftToExport			= GetMinPercentLeftToExport
	c.GetAvailableStockForUnits			= GetAvailableStockForUnits
	c.GetAvailableStockForCities		= GetAvailableStockForCities
	c.GetAvailableStockForExport		= GetAvailableStockForExport
	c.GetAvailableStockForIndustries 	= GetAvailableStockForIndustries
	c.GetMaxPersonnel					= GetMaxPersonnel
	c.GetPersonnel						= GetPersonnel
	c.ChangePersonnel					= ChangePersonnel
	c.UpdateLinkedUnits					= UpdateLinkedUnits
	c.UpdateTransferCities				= UpdateTransferCities
	c.UpdateExportCities				= UpdateExportCities
	c.UpdateCitiesConnection			= UpdateCitiesConnection
	c.ReinforceUnits					= ReinforceUnits
	c.GetTransferCities					= GetTransferCities
	c.GetExportCities					= GetExportCities
	c.TransferToCities					= TransferToCities
	c.ExportToForeignCities				= ExportToForeignCities
	c.GetNumResourceNeeded				= GetNumResourceNeeded
	c.GetRequirements					= GetRequirements
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
	c.CollectResources					= CollectResources
	c.ChangeStock 						= ChangeStock
	c.SetCityRationing					= SetCityRationing
	c.DoSocialClassStratification		= DoSocialClassStratification
	c.ChangeUpperClass					= ChangeUpperClass
	c.ChangeMiddleClass					= ChangeMiddleClass
	c.ChangeLowerClass					= ChangeLowerClass
	c.ChangeSlaveClass					= ChangeSlaveClass
	c.GetUpperClass						= GetUpperClass
	c.GetMiddleClass					= GetMiddleClass
	c.GetLowerClass						= GetLowerClass
	c.GetSlaveClass						= GetSlaveClass
	c.RecruitPersonnel					= RecruitPersonnel
	-- text
	c.GetResourcesStockString			= GetResourcesStockString
	c.GetFoodStockString 				= GetFoodStockString

end


----------------------------------------------
-- Share functions for other contexts
----------------------------------------------
function ShareFunctions()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.GetCity 				= GetCity
	ExposedMembers.GCO.AttachCityFunctions 	= AttachCityFunctions
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

