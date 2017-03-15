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
local foodResourceKey	= tostring(foodResourceID)
local baseFoodStock 	= tonumber(GameInfo.GlobalParameters["CITY_BASE_FOOD_STOCK"].Value)

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
		Stock					= { [tostring(foodResourceID)] = StartingFood },
		PreviousStock			= { [tostring(foodResourceID)] = StartingFood },
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

function GetMaxStock(self, resourceID)
	local maxStock = self:GetSize() * tonumber(GameInfo.GlobalParameters["CITY_STOCK_PER_SIZE"].Value)
	if resourceID == foodResourceID then maxStock = maxStock + baseFoodStock end
	return maxStock
end

function GetMaxPersonnel(self)
	local maxPersonnel = self:GetSize() * tonumber(GameInfo.GlobalParameters["CITY_PERSONNEL_PER_SIZE"].Value)

	return maxPersonnel
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
print("check change size", self:GetSize()+1, GetPopulationPerSize(self:GetSize()+1), self:GetRealPopulation())
print("check change size", self:GetSize()-1, GetPopulationPerSize(self:GetSize()-1), self:GetRealPopulation())
	if GetPopulationPerSize(self:GetSize()-1) > self:GetRealPopulation() then
		self:ChangePopulation(-1) -- (-1, true) ?
	elseif GetPopulationPerSize(self:GetSize()+1) < self:GetRealPopulation() then
		self:ChangePopulation(1)
	end
end

function DoFood(self)	
	-- get city food yield
	local food = GCO.GetCityYield( self, YieldTypes.FOOD )
	-- food eaten
	local eaten = self:GetFoodConsumption()
	self:ChangeResourceStock(foodResourceID, food - eaten)	
end

function SetCityRationing(self)
	local cityKey = self:GetKey()
	local cityData = ExposedMembers.CityData[cityKey]	
	local ratio 				= cityData.FoodRatio
	local foodStock 			= cityData.Stock[foodResourceKey]
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
	if data.Prisonners then	
		foodConsumption1000 = foodConsumption1000 + (GCO.GetTotalPrisonners(data) * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PRISONNERS_FACTOR"].Value) )
	end	
	return math.max(1, GCO.Round( foodConsumption1000 * ratio / 1000 ))
end

function GetCityBaseFoodStock(data)
	local city = CityManager.GetCity(data.playerID, data.cityID)
	return GCO.Round(city:GetMaxStock(foodResourceID) / 2)
end

----------------------------------------------
-- Texts function
----------------------------------------------

function GetResourcesStockString(data)
	local str = ""
	for resourceID, value in pairs(data.Stock) do
		if value > 0 then
			local stockVariation = 0
			if  data.PreviousStock[resourceID] then stockVariation = value - data.PreviousStock[resourceID] end
			local resourceID = tonumber(resourceID)
			local resRow = GameInfo.Resources[resourceID]
			if resourceID == foodResourceID then
				str = str .. "[NEWLINE]" .. GetFoodStockString(data) --Locale.Lookup("LOC_CITYBANNER_FOOD_STOCK", value) 
			elseif resourceID == materielResourceID then
				str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_MATERIEL_STOCK", value) 
			else 
				str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_CITYBANNER_RESOURCE_STOCK", value, resRow.Name, resRow.ResourceType) 
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

function GetFoodStockString(data) 
	local city 					= CityManager.GetCity(data.playerID, data.cityID)
	local baseFoodStock 		= GetCityBaseFoodStock(data)
	local maxFoodStock 			= city:GetMaxStock(foodResourceID)
	local foodStock 			= data.Stock[foodResourceKey]
	local foodStockVariation 	= foodStock - data.PreviousStock[foodResourceKey]
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
	for resourceID, value in pairs(cityData.Stock) do
		ExposedMembers.CityData[cityKey].PreviousStock[resourceID]	= cityData.Stock[resourceID]
	end
	
	-- get linked units and supply demand
	city:UpdateLinkedUnits()
	
	-- get linked cities
	city:UpdateLinkedCities()
	
	-- get Resources (allow excedents)
	city:CollectResources()
	
	-- feed population
	city:DoFood()
	
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
-- Shared Functions
-----------------------------------------------------------------------------------------

function GetCity(playerID, cityID) -- return a city with CityScript functions for another context
	local city = CityManager.GetCity(playerID, cityID)
	AttachCityFunctions(city)
	return city
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
	c.ChangeSize					= ChangeSize
	c.GetSize						= GetSize
	c.GetRealPopulation				= GetRealPopulation
	c.GetKey						= GetKey
	c.GetMaxStock					= GetMaxStock
	c.GetMaxPersonnel				= GetMaxPersonnel
	c.UpdateLinkedUnits				= UpdateLinkedUnits
	c.UpdateLinkedCities			= UpdateLinkedCities
	c.DoGrowth						= DoGrowth
	c.GetBirthRate					= GetBirthRate
	c.GetDeathRate					= GetDeathRate
	c.DoFood						= DoFood
	c.GetFoodConsumption 			= GetFoodConsumption
	c.CollectResources				= CollectResources
	c.ChangeResourceStock 			= ChangeResourceStock
	c.SetCityRationing				= SetCityRationing
	c.DoSocialClassStratification	= DoSocialClassStratification
end


----------------------------------------------
-- Share functions for other contexts
----------------------------------------------
ExposedMembers.CityScript_Initialized 	= false

function ShareFunctions()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.GetCity 				= GetCity
	ExposedMembers.GCO.AttachCityFunctions 	= AttachCityFunctions
	--
	ExposedMembers.GCO.GetCityFromKey 			= GetCityFromKey
	--
	ExposedMembers.GCO.GetResourcesStockString	= GetResourcesStockString
	ExposedMembers.GCO.GetCityFoodStockString 	= GetFoodStockString
	--
	ExposedMembers.CityScript_Initialized 	= true
end


----------------------------------------------
-- Initialize after loading
----------------------------------------------
Initialize()

