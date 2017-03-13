--=====================================================================================--
--	FILE:	 CityScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading CityScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local LinkedUnits 		= {}	-- temporary table to list all units linked to a city for supply
local UnitsSupplyDemand	= {}	-- temporary table to list all resources required by units
local CitiesForTransfer = {}	-- temporary table to list all cities connected via (internal) trade routes to a city
local CitiesForTrade	= {}	-- temporary table to list all cities connected via (external) trade routes to a city

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

local foodResourceID 	= GameInfo.Resources["RESOURCE_FOOD"].Index

local lightRationing 			=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_LIGHT_RATIO"].Value)
local mediumRationing 			=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_MEDIUM_RATIO"].Value)
local heavyRationing 			=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_HEAVY_RATIO"].Value)
local turnsToFamineLight 		=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_TO_FAMINE_LIGHT"].Value)
local turnsToFamineMedium 		=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_TO_FAMINE_MEDIUM"].Value)
local turnsToFamineHeavy 		=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_TO_FAMINE_HEAVY"].Value)
local RationingTurnsLocked		=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_TURNS_LOCKED"].Value)
local birthRateLightRationing 	=  tonumber(GameInfo.GlobalParameters["CITY_LIGHT_RATIONING_BIRTH_PERCENT"].Value)
local birthRateMediumRationing 	=  tonumber(GameInfo.GlobalParameters["CITY_MEDIUM_RATIONING_BIRTH_PERCENT"].Value)
local birthRateHeavyRationing	=  tonumber(GameInfo.GlobalParameters["CITY_HEAVY_RATIONING_BIRTH_PERCENT"].Value)
local deathRateLightRationing 	=  tonumber(GameInfo.GlobalParameters["CITY_LIGHT_RATIONING_DEATH_PERCENT"].Value)
local deathRateMediumRationing 	=  tonumber(GameInfo.GlobalParameters["CITY_MEDIUM_RATIONING_DEATH_PERCENT"].Value)
local deathRateHeavyRationing	=  tonumber(GameInfo.GlobalParameters["CITY_HEAVY_RATIONING_DEATH_PERCENT"].Value)


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
end

function SaveTables()
	--print("--------------------------- Saving CityData ---------------------------")
	GCO.StartTimer("CityData")
	GCO.SaveTableToSlot(ExposedMembers.CityData, "CityData")
	GCO.ShowTimer("CityData")
end
LuaEvents.SaveTables.Add(SaveTables)

-----------------------------------------------------------------------------------------
-- Initialize Cities
-----------------------------------------------------------------------------------------

function RegisterNewCity(playerID, city)

	local cityKey 			= city:GetKey()
	local personnel 		= city:GetMaxPersonnel()
	local totalPopulation 	= GetPopulationPerSize(city:GetSize()) + StartingPopulationBonus
	local upperClass		= GCO.Round(totalPopulation * GCO.GetPlayerUpperClassPercent(playerID) / 100)
	local middleClass		= GCO.Round(totalPopulation * GCO.GetPlayerMiddleClassPercent(playerID) / 100)
	local StartingFood		= GCO.Round(tonumber(GameInfo.GlobalParameters["CITY_BASE_FOOD_STOCK"].Value) / 2)
	
	ExposedMembers.CityData[cityKey] = {
		cityID 					= city:GetID(),
		playerID 				= playerID,
		Personnel 				= personnel,
		WoundedPersonnel 		= 0,
		PreviousPersonnel		= personnel,
		Prisonners				= GCO.CreateEverAliveTableWithDefaultValue(0),
		Stock					= { [foodResourceID] = StartingFood },
		PreviousStock			= { [foodResourceID] = StartingFood },
		UpperClass				= upperClass,
		MiddleClass				= middleClass,
		LowerClass				= totalPopulation - upperClass - middleClass,
		Slaves					= 0,
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
	local originalCityKey 	= GCO.GetCityKeyFromIDs(originalCityID, originalOwnerID)
	local newCityKey 		= GCO.GetCityKeyFromIDs(newCityID, newOwnerID)
	if ExposedMembers.CityData[originalCityKey] then
		originalData = ExposedMembers.CityData[originalCityKey]
		
		if ExposedMembers.CityData[newCityKey] then
			local city = CityManager.GetCity(newOwnerID, newCityID)
			print("Updating captured city (".. city:GetName() ..") for player #".. tostring(newOwnerID).. " id#" .. tostring(city:GetID()))
			print("-------------------------------------")
		
			ExposedMembers.CityData[newCityKey].Personnel 			= 0
			ExposedMembers.CityData[newCityKey].WoundedPersonnel 	= 0
			ExposedMembers.CityData[newCityKey].PreviousPersonnel 	= 0
			for civID, value in pairs(originalData.Prisonners) do
				ExposedMembers.CityData[newCityKey].Prisonners[civID] = value
			end
			ExposedMembers.CityData[newCityKey].Prisonners[tostring(originalOwnerID)] = originalData.Personnel + originalData.WoundedPersonnel	
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
LuaEvents.CapturedCityInitialized( UpdateCapturedCity ) -- called in Events.CityInitialized (after Events.CityAddedToMap and InitializeCity...)

-- for debugging
function ShowCityData()
	for cityKey, data in pairs(ExposedMembers.CityData) do
		print (cityKey, data)
		for k, v in pairs (data) do
			print ("-", k, v)
			if k == "Prisonners" then
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
	return math.pow(size, 2.8) * 1000
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

-----------------------------------------------------------------------------------------
-- City functions
-----------------------------------------------------------------------------------------

function ChangeSize(self)
print("check change size", self:GetSize()+1, GetPopulationPerSize(self:GetSize()+1), self:GetRealPopulation())
print("check change size", self:GetSize()-1, GetPopulationPerSize(self:GetSize()-1), self:GetRealPopulation())
	if GetPopulationPerSize(self:GetSize()-1) > self:GetRealPopulation() then
		self:ChangePopulation(-1) -- (-1, true) ?
	elseif GetPopulationPerSize(self:GetSize()+1) < self:GetRealPopulation() then
		self:ChangePopulation(1)
	end
end

function DoFood(self)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]	
	-- get city food yield
	local food = GCO.GetCityYield( self, YieldTypes.FOOD )
	-- food eaten
	local eaten = GCO.GetCityFoodConsumption(cityData)
	self:ChangeResourceStock(foodResourceID, food - eaten)	
end

function SetCityRationing(self)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]	
	local ratio 				= cityData.FoodRatio
	local foodStock 			= cityData.Stock[foodResourceID]
	local foodVariation 		= foodStock - cityData.PreviousStock[foodResourceID] 
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
	print("Social Stratification: totalPopultation = ", totalPopultation)
	print("Social Stratification: maxUpper = ", maxUpper)
	print("Social Stratification: minUpper = ", minUpper)
	print("Social Stratification: maxMiddle = ", maxMiddle)
	print("Social Stratification: minMiddle = ", minMiddle)
	print("Social Stratification: actualUpper = ", actualUpper)
	print("Social Stratification: actualMiddle = ", actualMiddle)
	-- Move Upper to Middle
	if actualUpper > maxUpper then
		toMove = actualUpper - maxUpper
		print("Social Stratification: Upper to Middle = ", toMove)
		ExposedMembers.CityData[cityKey].UpperClass		= cityData.UpperClass - toMove
		ExposedMembers.CityData[cityKey].MiddleClass	= cityData.MiddleClass + toMove
	end
	-- Move Middle to Upper
	if actualUpper < minUpper then
		toMove = minUpper - actualUpper
		print("Social Stratification: Middle to Upper = ", toMove)
		ExposedMembers.CityData[cityKey].UpperClass		= cityData.UpperClass + toMove
		ExposedMembers.CityData[cityKey].MiddleClass	= cityData.MiddleClass - toMove
	end	
	-- Move Middle to Lower
	if actualMiddle > maxMiddle then
		toMove = actualMiddle - maxMiddle
		print("Social Stratification: Middle to Lower = ", toMove)
		ExposedMembers.CityData[cityKey].MiddleClass	= cityData.MiddleClass - toMove
		ExposedMembers.CityData[cityKey].LowerClass		= cityData.LowerClass + toMove
	end	
	-- Move Lower to Middle
	if actualMiddle < minMiddle then
		toMove = minMiddle - actualMiddle
		print("Social Stratification: Lower to Middle = ", toMove)
		ExposedMembers.CityData[cityKey].MiddleClass	= cityData.MiddleClass + toMove
		ExposedMembers.CityData[cityKey].LowerClass		= cityData.LowerClass - toMove
	end	
end

-----------------------------------------------------------------------------------------
-- Resources functions
-----------------------------------------------------------------------------------------

function UpdateLinkedUnits(self)
	LinkedUnits[self] 		= {}
	UnitsSupplyDemand[self] = {}
	for unitKey, data in pairs(ExposedMembers.UnitData) do
		if data.SupplyLineCityKey == self:GetKey() then
			local unit = UnitManager.GetUnit(data.playerID, data.unitID)
			if unit then
				table.insert(LinkedUnits[self], unit)
			end
		end
	end	
end

function UpdateLinkedCities(self)
	CitiesForTransfer[self] = {}
	CitiesForTrade[self] 	= {}
end

function CollectResources(self)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	-- get resources on worked tiles
	local cityPlots	= GCO.GetCityPlots(self)
	for _, plotID in ipairs(cityPlots) do		
		local plot	= Map.GetPlotByIndex(plotID)
		if plot:GetWorkerCount() > 0 and plot:GetResourceCount() > 0 then
			print("-- adding resource type #", plot:GetResourceType() )
			self:ChangeResourceStock(plot:GetResourceType(), plot:GetResourceCount())			
		end
	end
end

function ChangeResourceStock(self, resourceID, value)
	local resourceID = tostring(resourceID)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	print("ChangeResourceStock : ", resourceID, value)
	print("previous value =", ExposedMembers.CityData[cityKey].Stock[resourceID])
	if not ExposedMembers.CityData[cityKey].Stock[resourceID] then
		ExposedMembers.CityData[cityKey].Stock[resourceID] = value
	else
		ExposedMembers.CityData[cityKey].Stock[resourceID] = cityData.Stock[resourceID] + value
	end	
	print("new value =", ExposedMembers.CityData[cityKey].Stock[resourceID])
end


-----------------------------------------------------------------------------------------
-- Do Turn for Cities
-----------------------------------------------------------------------------------------

function DoGrowth(self)
	if Game.GetCurrentGameTurn() < 2 then return end 
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	local cityBirthRate = self:GetBirthRate()
	local cityDeathRate = self:GetDeathRate()
	print("cityBirthRate =", cityBirthRate, "cityDeathRate =", cityDeathRate)
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

function CityDoTurn(city)

	local cityKey = city:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]
	
	-- set food rationing
	city:SetCityRationing()
	
	-- set previous stock
	print("set previous stock")
	print ("previous food =", ExposedMembers.CityData[cityKey].PreviousStock[foodResourceID], "current food = ", ExposedMembers.CityData[cityKey].Stock[foodResourceID])
	for resourceID, value in pairs(cityData.Stock) do
		ExposedMembers.CityData[cityKey].PreviousStock[resourceID]	= cityData.Stock[resourceID]
	end
	print ("previous food =", ExposedMembers.CityData[cityKey].PreviousStock[foodResourceID], "current food = ", ExposedMembers.CityData[cityKey].Stock[foodResourceID])
	
	-- get linked units and supply demand
	print("- get linked units and supply demand")
	city:UpdateLinkedUnits()
	
	-- get linked cities
	print("- get linked cities")
	city:UpdateLinkedCities()
	
	-- get Resources (allow excedents)
	print("- get Resources (allow excedents)")
	city:CollectResources()
	print ("previous food =", ExposedMembers.CityData[cityKey].PreviousStock[foodResourceID], "current food = ", ExposedMembers.CityData[cityKey].Stock[foodResourceID])
	
	-- feed population
	print("- feed population")
	city:DoFood()
	print ("previous food =", ExposedMembers.CityData[cityKey].PreviousStock[foodResourceID], "current food = ", ExposedMembers.CityData[cityKey].Stock[foodResourceID])
	
	-- diffuse to other cities, sell to foreign cities (do turn for traders ?), reinforce units, use in industry... (orders set in UI ?)
	
	-- remove excedents left
	
	-- Update City Size
	city:DoGrowth()
	city:DoSocialClassStratification()
	city:ChangeSize()
	LuaEvents.CityCompositionUpdated(city:GetOwner(), city:GetID())
end

function DoCitiesTurn( playerID )
	local player = Players[playerID]
	local playerCities = player:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			CityDoTurn(city)
		end
	end
end
LuaEvents.DoCitiesTurn.Add( DoCitiesTurn )

-----------------------------------------------------------------------------------------
-- Initialize City Functions
-----------------------------------------------------------------------------------------

function InitializeCityFunctions(playerID, cityID) -- add to Events.CityAddedToMap in initialize()
	-- Note that those functions are limited to this file context
	local city = CityManager.GetCity(playerID, cityID)
	local c = getmetatable(city).__index
	c.ChangeSize					= ChangeSize
	c.GetSize						= GCO.GetCitySize
	c.GetRealPopulation				= GCO.GetRealPopulation
	c.GetKey						= GCO.GetCityKey
	c.GetMaxStock					= GCO.GetMaxStock
	c.GetMaxPersonnel				= GCO.GetMaxPersonnel
	c.UpdateLinkedUnits				= UpdateLinkedUnits
	c.UpdateLinkedCities			= UpdateLinkedCities
	c.DoGrowth						= DoGrowth
	c.GetBirthRate					= GetBirthRate
	c.GetDeathRate					= GetDeathRate
	c.DoFood						= DoFood
	c.CollectResources				= CollectResources
	c.ChangeResourceStock 			= ChangeResourceStock
	c.SetCityRationing				= SetCityRationing
	c.DoSocialClassStratification	= DoSocialClassStratification
	
	Events.CityAddedToMap.Remove(InitializeCityFunctions)
end

Initialize()