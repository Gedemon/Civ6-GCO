--=====================================================================================--
--	FILE:	 ModUtils.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading ModUtils.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

-- This file should be the first to load, do some cleaning just in case Events.LeaveGameComplete hasn't fired on returning to main menu or loading a game...
ExposedMembers.SaveLoad_Initialized 		= nil
ExposedMembers.ContextFunctions_Initialized	= nil
ExposedMembers.Utils_Initialized 			= nil
ExposedMembers.Serialize_Initialized 		= nil
ExposedMembers.RouteConnections_Initialized	= nil
ExposedMembers.PlotIterator_Initialized		= nil
ExposedMembers.PlotScript_Initialized 		= nil
ExposedMembers.CityScript_Initialized 		= nil

-- Floating Texts LOD
local FLOATING_TEXT_NONE 	= 0
local FLOATING_TEXT_SHORT 	= 1
local FLOATING_TEXT_LONG 	= 2
local floatingTextLevel 	= FLOATING_TEXT_SHORT

local maxHP = GlobalParameters.COMBAT_MAX_HIT_POINTS

local foodResourceID 	= GameInfo.Resources["RESOURCE_FOOD"].Index
local foodResourceKey	= tostring(foodResourceID)
--local baseFoodStock 	= tonumber(GameInfo.GlobalParameters["CITY_BASE_FOOD_STOCK"].Value)

local materielResourceID	= GameInfo.Resources["RESOURCE_MATERIEL"].Index
local steelResourceID 		= GameInfo.Resources["RESOURCE_STEEL"].Index

local lightRationing 	=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_LIGHT_RATIO"].Value)
local mediumRationing 	=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_MEDIUM_RATIO"].Value)
local heavyRationing 	=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_HEAVY_RATIO"].Value)

-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

function IsInitializedGCO() -- we can't use something like GameEvents.ExposedFunctionsInitialized.TestAll() because it will be called before all required test are added to the event...
	local bIsInitialized = 	(	ExposedMembers.SaveLoad_Initialized 
							and ExposedMembers.Utils_Initialized
							and	ExposedMembers.Serialize_Initialized
							and ExposedMembers.ContextFunctions_Initialized
							and ExposedMembers.RouteConnections_Initialized
							and ExposedMembers.PlotIterator_Initialized
							and ExposedMembers.PlotScript_Initialized
							and ExposedMembers.CityScript_Initialized
							)
	return bIsInitialized
end

local GCO = {}
local CombatTypes = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	if IsInitializedGCO() then 	
		print ("All GCO script files loaded...")
		GCO = ExposedMembers.GCO					-- contains functions from other contexts
		CombatTypes = ExposedMembers.CombatTypes 	-- Need those in combat results
		print ("Exposed Functions from other contexts initialized...")
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		-- tell all other scripts they can initialize now
		LuaEvents.InitializeGCO() 
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )


-----------------------------------------------------------------------------------------
-- Maths
-----------------------------------------------------------------------------------------
function Round(num)
    under = math.floor(num)
    upper = math.floor(num) + 1
    underV = -(under - num)
    upperV = upper - num
    if (upperV > underV) then
        return under
    else
        return upper
    end
end

function Shuffle(t)
  local n = #t
 
  while n >= 2 do
    -- n is now the last pertinent index
    local k = math.random(n) -- 1 <= k <= n
    -- Quick swap
    t[n], t[k] = t[k], t[n]
    n = n - 1
  end
 
  return t
end

function GetSize(t)

	if type(t) ~= "table" then
		return 1 
	end

	local n = #t 
	if n == 0 then
		for k, v in pairs(t) do
			n = n + 1
		end
	end 
	return n
end

function ToDecimals(num)
	num = Round(num*100)/100
	string.format("%5.2f", num)
	return num
end


----------------------------------------------
-- Debug
----------------------------------------------

local bNoOutput = false
function ToggleOutput()
	bNoOutput = not bNoOutput
	print("Spam control = " .. tostring(bNoOutput))
end

function Dprint(str)
	if bNoOutput then -- spam control
		return
	end
	print(str)
end

----------------------------------------------
-- Timer
----------------------------------------------

local Timer = {}
function StartTimer(name)
	Timer[name] = Automation.GetTime()
end
function ShowTimer(name)
	if bNoOutput then -- spam control
		return
	end
	if Timer[name] then
		print("- "..tostring(name) .." timer = " .. tostring(Automation.GetTime()-Timer[name]) .. " seconds")
	end
end

----------------------------------------------
-- Civilizations
----------------------------------------------

function CreateEverAliveTableWithDefaultValue(value)
	local t = {}
	for i, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		t[tostring(playerID)] = value -- key must be string for correct serialization
	end
	return t
end

function CreateEverAliveTableWithEmptyTable()
	local t = {}
	for i, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		t[tostring(playerID)] = {} -- key must be string for correct serialization
	end
	return t
end

----------------------------------------------
-- Map
----------------------------------------------

function GetPlotKey( plot )
	return tostring(plot:GetIndex()) -- use string for correct serialisation/deserialization of tables when using this as a key
end
function GetPlotFromKey( key )
	return Map.GetPlotByIndex(tonumber(key))
end

function FindNearestPlayerCity( eTargetPlayer, iX, iY )

	local pCity = nil
    local iShortestDistance = 10000
	local pPlayer = Players[eTargetPlayer]
	if pPlayer then
		local pPlayerCities:table = pPlayer:GetCities()
		for i, pLoopCity in pPlayerCities:Members() do
			local iDistance = Map.GetPlotDistance(iX, iY, pLoopCity:GetX(), pLoopCity:GetY())
			if (iDistance < iShortestDistance) then
				pCity = pLoopCity
				iShortestDistance = iDistance
			end
		end
	else
		print ("WARNING : Player is nil in FindNearestPlayerCity for ID = ".. tostring(eTargetPlayer) .. "at" .. tostring(iX) ..","..tostring(iY))
	end

	if (not pCity) then
		--print ("No city found of player " .. tostring(eTargetPlayer) .. " in range of " .. tostring(iX) .. ", " .. tostring(iY));
	end
   
    return pCity, iShortestDistance;
end


----------------------------------------------
-- Cities
----------------------------------------------

-- City Capture Events
local cityCaptureTest = {}
function CityCaptureDistrictRemoved(playerID, districtID, cityID, iX, iY)
	local key = iX..","..iY
	cityCaptureTest[key]			= {}
	cityCaptureTest[key].Turn 		= Game.GetCurrentGameTurn()
	cityCaptureTest[key].PlayerID 	= playerID
	cityCaptureTest[key].CityID 	= cityID
end
Events.DistrictRemovedFromMap.Add(CityCaptureDistrictRemoved)
function CityCaptureCityAddedToMap(playerID, cityID, iX, iY)
	local key = iX..","..iY
	if (	cityCaptureTest[key]
		and cityCaptureTest[key].Turn 	== Game.GetCurrentGameTurn()
		and not	cityCaptureTest[key].CityAddedXY	)
	then
		cityCaptureTest[key].CityAddedXY = true
		local city = CityManager.GetCity(playerID, cityID)
		local originalOwnerID 	= city:GetOriginalOwner()
		local originalCityID	= cityCaptureTest[key].CityID
		local newOwnerID 		= playerID
		local newCityID			= cityID
		if cityCaptureTest[key].PlayerID == originalOwnerID then
			print("Calling LuaEvents.CapturedCityAddedToMap (", originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY,")")
			LuaEvents.CapturedCityAddedToMap(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)
		end
	end
end
Events.CityAddedToMap.Add(CityCaptureCityAddedToMap)
function CityCaptureCityInitialized(playerID, cityID, iX, iY)
	local key = iX..","..iY
	if (	cityCaptureTest[key]
		and cityCaptureTest[key].Turn 	== Game.GetCurrentGameTurn() )
	then
		cityCaptureTest[key].CityInitializedXY = true
		local city = CityManager.GetCity(playerID, cityID)
		local originalOwnerID 	= city:GetOriginalOwner()
		local originalCityID	= cityCaptureTest[key].CityID
		local newOwnerID 		= playerID
		local newCityID			= cityID
		if cityCaptureTest[key].PlayerID == originalOwnerID then
			LuaEvents.CapturedCityInitialized(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)
			cityCaptureTest[key] = {}
		end
	end
end
Events.CityInitialized.Add(CityCaptureCityInitialized)

function GetCityBaseFoodStock(data)
	local city = GCO.GetCity(data.playerID, data.cityID)
	return GCO.Round(city:GetMaxStock(foodResourceID) / 2)
end

function GetCityFoodConsumption(data)
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
		foodConsumption1000 = foodConsumption1000 + (GetTotalPrisonners(data) * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PRISONNERS_FACTOR"].Value) )
	end	
	return math.max(1, Round( foodConsumption1000 * ratio / 1000 ))
end


----------------------------------------------
-- Common
----------------------------------------------

function GetTotalPrisonners(data) -- works for cityData and unitData
	local prisonners = 0
	for playerID, number in pairs(data.Prisonners) do
		prisonners = prisonners + number
	end	
	return prisonners
end

----------------------------------------------
-- Players
----------------------------------------------

function GetPlayerUpperClassPercent( playerID )
	return tonumber(GameInfo.GlobalParameters["CITY_BASE_UPPER_CLASS_PERCENT"].Value)
end

function GetPlayerMiddleClassPercent( playerID )
	return tonumber(GameInfo.GlobalParameters["CITY_BASE_MIDDLE_CLASS_PERCENT"].Value)
end

----------------------------------------------
-- Units
----------------------------------------------

function GetUnitKeyFromIDs(ownerID, unitID) -- local
	return unitID..","..ownerID
end

-- return unique key for units table [unitID,playerID]
function GetUnitKey(unit)
	if unit then
		local ownerID = unit:GetOwner()
		local unitID = unit:GetID()
		local unitKey = GetUnitKeyFromIDs(ownerID, unitID)
		return unitKey
	else
		print("- WARNING: unit is nil for GetUnitKey()")
	end
end

function GetUnitFromKey ( unitKey )
	if ExposedMembers.UnitData[unitKey] then
		local unit = UnitManager.GetUnit(ExposedMembers.UnitData[unitKey].playerID, ExposedMembers.UnitData[unitKey].unitID)
		if unit then
			return unit
		else
			print("- WARNING: unit is nil for GetUnitFromKey(".. tostring(unitKey).."), marking as dead")
			print("--- UnitId = " .. ExposedMembers.UnitData[unitKey].UnitID ..", playerID = " .. ExposedMembers.UnitData[unitKey].playerID )
			ExposedMembers.UnitData[unitKey].Alive = false
		end
	else
		print("- WARNING: ExposedMembers.UnitData[unitKey] is nil for GetUnitFromKey(".. tostring(unitKey)..")")
	end
end

function CheckComponentsHP(unit, str, bNoWarning)
	if not unit then
		print("WARNING : unit is nil in CheckComponentsHP() for " .. tostring(str))
		return
	end
	local HP = unit:GetMaxDamage() - unit:GetDamage()
	local unitType = unit:GetType()
	local key = GetUnitKey(unit)
	--if HP < 0 then
	function debug()
		print("---------------------------------------------------------------------------")
		print("in CheckComponentsHP() for " .. tostring(str))
		if bNoWarning then
			print("SHOWING : For "..tostring(GameInfo.Units[unit:GetType()].UnitType).." id#".. tostring(unit:GetID()).." player#"..tostring(unit:GetOwner()))
		else
			print("WARNING : For "..tostring(GameInfo.Units[unit:GetType()].UnitType).." id#".. tostring(unit:GetID()).." player#"..tostring(unit:GetOwner()))
		end
		--print("WARNING : HP < 0 in CheckComponentsHP() for " .. tostring(str))
		print("key =", key, "unitType =", unitType, "HP =", HP)	
		--print(ExposedMembers.UnitData, ExposedMembers.UnitHitPointsTable)
		--print(ExposedMembers.UnitData[key], ExposedMembers.UnitHitPointsTable[unitType])
		print("UnitData[key].Personnel =", ExposedMembers.UnitData[key].Personnel, "UnitHitPointsTable[unitType][HP].Personnel =", ExposedMembers.UnitHitPointsTable[unitType][HP].Personnel)
		print("UnitData[key].Vehicles =", ExposedMembers.UnitData[key].Vehicles, "UnitHitPointsTable[unitType][HP].Vehicles =", ExposedMembers.UnitHitPointsTable[unitType][HP].Vehicles)
		print("UnitData[key].Horses =", ExposedMembers.UnitData[key].Horses, "UnitHitPointsTable[unitType][HP].Horses =", ExposedMembers.UnitHitPointsTable[unitType][HP].Horses)
		print("UnitData[key].Materiel =", ExposedMembers.UnitData[key].Materiel, "UnitHitPointsTable[unitType][HP].Materiel =", ExposedMembers.UnitHitPointsTable[unitType][HP].Materiel)
		print("---------------------------------------------------------------------------")
	end
	if 		ExposedMembers.UnitData[key].Personnel 	~= ExposedMembers.UnitHitPointsTable[unitType][HP].Personnel 
		or 	ExposedMembers.UnitData[key].Vehicles  	~= ExposedMembers.UnitHitPointsTable[unitType][HP].Vehicles  
		or 	ExposedMembers.UnitData[key].Horses		~= ExposedMembers.UnitHitPointsTable[unitType][HP].Horses	 
		or 	ExposedMembers.UnitData[key].Materiel 	~= ExposedMembers.UnitHitPointsTable[unitType][HP].Materiel 
	then 
		debug()
		return false
	end
	return true
end

local debugTable = {}
function DebugComponentsHP(unit, str)
	if not unit then
		print("WARNING : unit is nil in DebugComponentsHP, REF = " .. tostring(str))
		return
	end
	if not debugTable[unit] then debugTable[unit] = {} end
	local HP = unit:GetMaxDamage() - unit:GetDamage()
	local unitType = unit:GetType()
	local key = GetUnitKey(unit)
	--if HP < 0 then
	table.insert(debugTable, "---------------------------------------------------------------------------")
	table.insert(debugTable, "In DebugComponentsHP at turn#"..tostring(Game.GetCurrentGameTurn())..", REF = " .. tostring(str))
	table.insert(debugTable, "For "..tostring(GameInfo.Units[unitType].UnitType).." id#".. tostring(unit:GetID()).." player#"..tostring(unit:GetOwner()))
	--table.insert(debugTable, "WARNING : HP < 0 in CheckComponentsHP() for " .. tostring(str))
	table.insert(debugTable, "key =".. tostring(key).. ", unitType =".. tostring(unitType).. ", HP =".. tostring(HP))	
	--table.insert(debugTable, ExposedMembers.UnitData, ExposedMembers.UnitHitPointsTable)
	--table.insert(debugTable, ExposedMembers.UnitData[key], ExposedMembers.UnitHitPointsTable[unitType])
	table.insert(debugTable, "UnitData[key].Personnel =".. tostring(ExposedMembers.UnitData[key].Personnel) ..", UnitHitPointsTable[unitType][HP].Personnel =".. tostring(ExposedMembers.UnitHitPointsTable[unitType][HP].Personnel))
	table.insert(debugTable, "UnitData[key].Vehicles =".. tostring(ExposedMembers.UnitData[key].Vehicles) ..", UnitHitPointsTable[unitType][HP].Vehicles =".. tostring(ExposedMembers.UnitHitPointsTable[unitType][HP].Vehicles))
	table.insert(debugTable, "UnitData[key].Horses =".. tostring(ExposedMembers.UnitData[key].Horses) ..", UnitHitPointsTable[unitType][HP].Horses =".. tostring(ExposedMembers.UnitHitPointsTable[unitType][HP].Horses))
	table.insert(debugTable, "UnitData[key].Materiel =".. tostring(ExposedMembers.UnitData[key].Materiel) ..", UnitHitPointsTable[unitType][HP].Materiel =".. tostring(ExposedMembers.UnitHitPointsTable[unitType][HP].Materiel))
	table.insert(debugTable, "---------------------------------------------------------------------------")
end

function ShowDebugComponentsHP(unit)
	if not unit then return end
	local key = GetUnitKey(unit)
	local unitType = unit:GetType()
	local HP = unit:GetMaxDamage() - unit:GetDamage()
	if 		ExposedMembers.UnitData[key].Personnel 	~= ExposedMembers.UnitHitPointsTable[unitType][HP].Personnel 
		or 	ExposedMembers.UnitData[key].Vehicles  	~= ExposedMembers.UnitHitPointsTable[unitType][HP].Vehicles  
		or 	ExposedMembers.UnitData[key].Horses		~= ExposedMembers.UnitHitPointsTable[unitType][HP].Horses	 
		or 	ExposedMembers.UnitData[key].Materiel 	~= ExposedMembers.UnitHitPointsTable[unitType][HP].Materiel 
	then 
		for _, text in ipairs(debugTable[unit]) do
			print(text)
		end
		debugTable[unit] = {}
	end
end

function GetPersonnelReserve(unitType)
	return Round((GameInfo.Units[unitType].Personnel * GameInfo.GlobalParameters["UNIT_RESERVE_RATIO"].Value / 10) * 10)
end

function GetVehiclesReserve(unitType)
	return Round((GameInfo.Units[unitType].Vehicles * GameInfo.GlobalParameters["UNIT_RESERVE_RATIO"].Value / 10) * 10)
end

function GetHorsesReserve(unitType)
	return Round((GameInfo.Units[unitType].Horses * GameInfo.GlobalParameters["UNIT_RESERVE_RATIO"].Value / 10) * 10)
end

function GetMaterielReserve(unitType)
	return GameInfo.Units[unitType].Materiel -- 100% stock for materiel reserve
end

function GetUnitFoodConsumptionRatio(unitData) -- local
	local ratio = 1
	local baseFoodStock = GetUnitBaseFoodStock(unitData.unitType)
	if unitData.FoodStock < (baseFoodStock * heavyRationing) then
		ratio = heavyRationing
	elseif unitData.FoodStock < (baseFoodStock * mediumRationing) then
		ratio = mediumRationing
	elseif unitData.FoodStock < (baseFoodStock * lightRationing) then
		ratio = lightRationing
	end
	return ratio
end

function GetUnitFoodConsumption(unitData, fixedRatio)
	local foodConsumption1000 = 0
	local ratio = fixedRatio or GetUnitFoodConsumptionRatio(unitData) -- to prevent an infinite loop between GetUnitBaseFoodStock & GetUnitFoodConsumptionRatio
	foodConsumption1000 = foodConsumption1000 + ((unitData.Personnel + unitData.PersonnelReserve) * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PERSONNEL_FACTOR"].Value) * ratio)
	foodConsumption1000 = foodConsumption1000 + ((unitData.Horses + unitData.HorsesReserve) * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_HORSES_FACTOR"].Value) * ratio)
	-- value belows may be nil
	if unitData.WoundedPersonnel then
		foodConsumption1000 = foodConsumption1000 + (unitData.WoundedPersonnel * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_WOUNDED_FACTOR"].Value) * ratio )
	end
	if unitData.Prisonners then	
		foodConsumption1000 = foodConsumption1000 + (GetTotalPrisonners(unitData) * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PRISONNERS_FACTOR"].Value) * ratio )
	end	
	return math.max(1, Round( foodConsumption1000 / 1000 ))
end

function GetUnitBaseFoodStock(unitType)
	local unitData = {}
	unitData.unitType 			= unitType
	unitData.Personnel 			= GameInfo.Units[unitType].Personnel
	unitData.Horses 			= GameInfo.Units[unitType].Horses
	unitData.PersonnelReserve	= GetPersonnelReserve(unitType)
	unitData.HorsesReserve 		= GetHorsesReserve(unitType)
	local fixedRatio = 1
	return GetUnitFoodConsumption(unitData, fixedRatio)*5 -- set enough stock for 5 turns
end

function GetFuelConsumptionRatio(unitData) -- local
	local ratio = 1
	local lightRationing 	= tonumber(GameInfo.GlobalParameters["FUEL_RATIONING_LIGHT_RATIO"].Value)
	local mediumRationing 	= tonumber(GameInfo.GlobalParameters["FUEL_RATIONING_MEDIUM_RATIO"].Value)
	local heavyRationing 	= tonumber(GameInfo.GlobalParameters["FUEL_RATIONING_HEAVY_RATIO"].Value)
	local baseFuelStock = GetBaseFuelStock(unitData.unitType)
	if unitData.FuelStock < (baseFuelStock * heavyRationing) then
		ratio = tonumber(GameInfo.GlobalParameters["FUEL_CONSUMPTION_HEAVY_RATIO"].Value)
	elseif unitData.FuelStock < (baseFuelStock * mediumRationing) then
		ratio = tonumber(GameInfo.GlobalParameters["FUEL_CONSUMPTION_MEDIUM_RATIO"].Value)
	elseif unitData.FuelStock < (baseFuelStock * lightRationing) then
		ratio = tonumber(GameInfo.GlobalParameters["FUEL_CONSUMPTION_LIGHT_RATIO"].Value)
	end
	return ratio
end

function GetFuelConsumption(unitData, fixedRatio)
	if (not unitData.Vehicles) or (unitData.Vehicles == 0) then
		return 0
	end
	local fuelConsumption1000 = 0
	local ratio = fixedRatio or GetFuelConsumptionRatio(unitData) -- to prevent an infinite loop between GetBaseFuelStock & GetFuelConsumptionRatio
	fuelConsumption1000 = fuelConsumption1000 + unitData.Vehicles * unitData.FuelConsumptionPerVehicle * tonumber(GameInfo.GlobalParameters["FUEL_CONSUMPTION_ACTIVE_FACTOR"].Value) * ratio
	
	if unitData.DamagedVehicles then	
		foodConsumption1000 = foodConsumption1000 + (unitData.DamagedVehicles * unitData.FuelConsumptionPerVehicle * tonumber(GameInfo.GlobalParameters["FUEL_CONSUMPTION_DAMAGED_FACTOR"].Value) * ratio )
	end	
	return math.max(1, Round( fuelConsumption1000 / 1000))
end

function GetBaseFuelStock(unitType)
	local unitData = {}
	unitData.unitType 					= unitType
	unitData.Vehicles 					= GameInfo.Units[unitType].Vehicles
	unitData.FuelConsumptionPerVehicle 	= GameInfo.Units[unitType].FuelConsumptionPerVehicle	
	local fixedRatio = 1
	if unitData.Vehicles > 0 and unitData.FuelConsumptionPerVehicle > 0 then
		return GetFuelConsumption(unitData, fixedRatio) * 5 -- set enough stock for 5 turns
	end
	return 0
end

function GetMaxTransfertTable(unit)
	local maxTranfert = {}
	local unitType = unit:GetType()
	local unitInfo = GameInfo.Units[unit:GetType()]
	maxTranfert.Personnel = GameInfo.GlobalParameters["UNIT_MAX_PERSONNEL_FROM_RESERVE"].Value
	maxTranfert.Materiel = GameInfo.GlobalParameters["UNIT_MAX_MATERIEL_FROM_RESERVE"].Value
	return maxTranfert
end

function GetMoraleFromFood(unitData)	
	local moralefromFood 	= tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_WELL_FED"].Value)
	local lightRationing 	= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_LIGHT_RATIO"].Value)
	local mediumRationing 	= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_MEDIUM_RATIO"].Value)
	local heavyRationing 	= tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_HEAVY_RATIO"].Value)
	local baseFoodStock 	= GetUnitBaseFoodStock(unitData.unitType)
	
	if unitData.FoodStock < (baseFoodStock * heavyRationing) then
		moralefromFood = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_FOOD_RATIONING_HEAVY"].Value)
	elseif unitData.FoodStock < (baseFoodStock * mediumRationing) then
		moralefromFood = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_FOOD_RATIONING_MEDIUM"].Value)
	elseif unitData.FoodStock < (baseFoodStock * lightRationing) then
		moralefromFood = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_FOOD_RATIONING_LIGHT"].Value)
	end
	return moralefromFood	
end

function GetMoraleFromLastCombat(unitData)
	if (Game.GetCurrentGameTurn() - unitData.LastCombatTurn) > tonumber(GameInfo.GlobalParameters["MORALE_COMBAT_EFFECT_NUM_TURNS"].Value) then
		return 0
	end
	local moraleFromCombat = 0
	if unitData.LastCombatResult > tonumber(GameInfo.GlobalParameters["COMBAT_HEAVY_DIFFERENCE_VALUE"].Value) then
		moraleFromCombat = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_COMBAT_LARGE_VICTORY"].Value)
	elseif unitData.LastCombatResult > 0 then
		moraleFromCombat = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_COMBAT_VICTORY"].Value)	
	elseif unitData.LastCombatResult < 0 then
		moraleFromCombat = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_COMBAT_DEFEAT"].Value)	
	elseif unitData.LastCombatResult < - tonumber(GameInfo.GlobalParameters["COMBAT_HEAVY_DIFFERENCE_VALUE"].Value) then
		moraleFromCombat = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_COMBAT_LARGE_DEFEAT"].Value)	
	end
	
	if unitData.LastCombatType ~= CombatTypes.MELEE then
		moraleFromCombat = Round(moraleFromCombat * tonumber(GameInfo.GlobalParameters["MORALE_COMBAT_NON_MELEE_RATIO"].Value))
	end

	return moraleFromCombat	
end

function GetMoraleFromWounded(unitData)
	local moraleFromWounded = 0
	if unitData.WoundedPersonnel > ( (unitData.Personnel + unitData.PersonnelReserve) * tonumber(GameInfo.GlobalParameters["MORALE_WOUNDED_HIGH_PERCENT"].Value) / 100) then
		moraleFromWounded = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_WOUNDED_HIGH"].Value)
	elseif unitData.WoundedPersonnel > ( (unitData.Personnel + unitData.PersonnelReserve) * tonumber(GameInfo.GlobalParameters["MORALE_WOUNDED_LOW_PERCENT"].Value) / 100) then 
		moraleFromWounded = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_WOUNDED_LOW"].Value)	
	end
	return moraleFromWounded	
end

function GetMoraleFromHP(unitData)
	local moraleFromHP = 0
	local unit = UnitManager.GetUnit(unitData.playerID, unitData.unitID)
	if unit then
		local HP = unit:GetMaxDamage() - unit:GetDamage()		
		if HP == maxHP then
			moraleFromHP = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_HP_FULL"].Value)
		else
			local percentHP = (HP / maxHP * 100)
			if  percentHP < tonumber(GameInfo.GlobalParameters["MORALE_HP_VERY_LOW_PERCENT"].Value) then
				moraleFromHP = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_HP_VERY_LOW"].Value)
			elseif  percentHP < tonumber(GameInfo.GlobalParameters["MORALE_HP_LOW_PERCENT"].Value) then
				moraleFromHP = tonumber(GameInfo.GlobalParameters["MORALE_CHANGE_HP_LOW"].Value)
			end
		end
	end
	return moraleFromHP
end


----------------------------------------------
-- Texts function
----------------------------------------------

function GetPrisonnersStringByCiv(data) -- works for unitData and cityData
	local sortedPrisonners = {}
	for playerID, number in pairs(data.Prisonners) do
		table.insert(sortedPrisonners, {playerID = tonumber(playerID), Number = number})
	end	
	table.sort(sortedPrisonners, function(a,b) return a.Number>b.Number end)
	local numLines = tonumber(GameInfo.GlobalParameters["UI_MAX_PRISONNERS_LINE_IN_TOOLTIP"].Value)
	local str = ""
	local other = 0
	local iter = 1
	for i, t in ipairs(sortedPrisonners) do
		if (iter <= numLines) or (#sortedPrisonners == numLines + 1) then
			local playerConfig = PlayerConfigurations[t.playerID]
			local civAdjective = Locale.Lookup(GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Adjective)
			if t.Number > 0 then str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_PRISONNERS_NATIONALITY", t.Number, civAdjective) end
		else
			other = other + t.Number
		end
		iter = iter + 1
	end
	if other > 0 then str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_PRISONNERS_OTHER_NATIONALITY", other) end
	return str
end

function GetResourcesStockString(data)
	local str = ""
	for resourceID, value in pairs(data.Stock) do
		if value > 0 then
			local stockVariation = 0
			if  data.PreviousStock[resourceID] then stockVariation = value - data.PreviousStock[resourceID] end
			local resourceID = tonumber(resourceID)
			local resRow = GameInfo.Resources[resourceID]
			if resourceID == foodResourceID then
				str = str .. "[NEWLINE]" .. GetCityFoodStockString(data) --Locale.Lookup("LOC_CITYBANNER_FOOD_STOCK", value) 
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

function GetFuelStockString(unitData) 
	local lightRationing = 	tonumber(GameInfo.GlobalParameters["FUEL_RATIONING_LIGHT_RATIO"].Value)
	local mediumRationing = tonumber(GameInfo.GlobalParameters["FUEL_RATIONING_MEDIUM_RATIO"].Value)
	local heavyRationing = 	tonumber(GameInfo.GlobalParameters["FUEL_RATIONING_HEAVY_RATIO"].Value)
	local baseFuelStock = GetBaseFuelStock(unitData.unitType)
	local fuelStockVariation = unitData.FuelStock - unitData.PreviousFuelStock
	local str = ""
	if unitData.FuelStock < (baseFuelStock * heavyRationing) then
		str = Locale.Lookup("LOC_UNITFLAG_FUEL_STOCK_HEAVY_RATIONING", unitData.FuelStock, baseFuelStock)
	elseif unitData.FuelStock < (baseFuelStock * mediumRationing) then
		str = Locale.Lookup("LOC_UNITFLAG_FUEL_STOCK_MEDIUM_RATIONING", unitData.FuelStock, baseFuelStock)
	elseif unitData.FuelStock < (baseFuelStock * lightRationing) then
		str = Locale.Lookup("LOC_UNITFLAG_FUEL_STOCK_LIGHT_RATIONING", unitData.FuelStock, baseFuelStock)
	else
		str = Locale.Lookup("LOC_UNITFLAG_FUEL_STOCK", unitData.FuelStock, baseFuelStock)
	end	
	
	if fuelStockVariation > 0 then
		str = str .. "[ICON_PressureUp]"
	elseif fuelStockVariation < 0 then
		str = str .." [ICON_PressureDown]"
	end
	
	return str
end

function GetFuelConsumptionString(unitData)
	local str = ""
	local ratio = GetFuelConsumptionRatio(unitData)
	if unitData.Vehicles > 0 then 
		local fuel = ( unitData.Vehicles * tonumber(GameInfo.GlobalParameters["FUEL_CONSUMPTION_ACTIVE_FACTOR"].Value) )/1000
		str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FUEL_CONSUMPTION_ACTIVE", ToDecimals(fuel * ratio), unitData.Vehicles) 
	end	
	if unitData.DamagedVehicles > 0 then 
		local fuel = ( unitData.DamagedVehicles * tonumber(GameInfo.GlobalParameters["FUEL_CONSUMPTION_ACTIVE_FACTOR"].Value) )/1000
		str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FUEL_CONSUMPTION_DAMAGED", ToDecimals(fuel * ratio), unitData.DamagedVehicles) 
	end	
	return str
end

function GetUnitFoodStockString(data) 
	local baseFoodStock = GetUnitBaseFoodStock(data.unitType)
	local foodStockVariation = data.FoodStock - data.PreviousFoodStock
	local str = ""
	if data.FoodStock < (baseFoodStock * heavyRationing) then
		str = Locale.Lookup("LOC_UNITFLAG_FOOD_RATION_HEAVY_RATIONING", data.FoodStock, baseFoodStock)
	elseif data.FoodStock < (baseFoodStock * mediumRationing) then
		str = Locale.Lookup("LOC_UNITFLAG_FOOD_RATION_MEDIUM_RATIONING", data.FoodStock, baseFoodStock)
	elseif data.FoodStock < (baseFoodStock * lightRationing) then
		str = Locale.Lookup("LOC_UNITFLAG_FOOD_RATION_LIGHT_RATIONING", data.FoodStock, baseFoodStock)
	else
		str = Locale.Lookup("LOC_UNITFLAG_FOOD_RATION", data.FoodStock, baseFoodStock)
	end	
	
	if foodStockVariation > 0 then
		str = str .. "[ICON_PressureUp]"
	elseif foodStockVariation < 0 then
		str = str .." [ICON_PressureDown]"
	end
	
	return str
end

function GetCityFoodStockString(data) 
	local city 					= GCO.GetCity(data.playerID, data.cityID)
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

function GetUnitFoodConsumptionString(unitData)
	local str = ""
	local ratio = GetUnitFoodConsumptionRatio(unitData)
	local totalPersonnel = unitData.Personnel + unitData.PersonnelReserve
	if totalPersonnel > 0 then 
		local personnelFood = ( totalPersonnel * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PERSONNEL_FACTOR"].Value) )/1000
		str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FOOD_CONSUMPTION_PERSONNEL", ToDecimals(personnelFood * ratio), totalPersonnel) 
	end	
	local totalHorses = unitData.Horses + unitData.HorsesReserve
	if totalHorses > 0 then 
		local horsesFood = ( totalHorses * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_HORSES_FACTOR"].Value) )/1000
		str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FOOD_CONSUMPTION_HORSES", ToDecimals(horsesFood * ratio), totalHorses ) 
	end
	
	-- value belows may be nil
	if unitData.WoundedPersonnel and unitData.WoundedPersonnel > 0 then 
		local woundedFood = ( unitData.WoundedPersonnel * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_WOUNDED_FACTOR"].Value) )/1000
		str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FOOD_CONSUMPTION_WOUNDED", ToDecimals(woundedFood * ratio), unitData.WoundedPersonnel ) 
	end
	if unitData.Prisonners then	
		local totalPrisonners = GetTotalPrisonners(unitData)		
		if totalPrisonners > 0 then 
			local prisonnersFood = ( totalPrisonners * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PRISONNERS_FACTOR"].Value) )/1000
			str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FOOD_CONSUMPTION_PRISONNERS", ToDecimals(prisonnersFood * ratio), totalPrisonners )
		end
	end	
	return str
end

function GetMoraleString(unitData) 
	local baseMorale 		= tonumber(GameInfo.GlobalParameters["MORALE_BASE_VALUE"].Value)
	local lowMorale 		= Round(baseMorale * tonumber(GameInfo.GlobalParameters["MORALE_LOW_PERCENT"].Value) / 100)
	local badMorale 		= Round(baseMorale * tonumber(GameInfo.GlobalParameters["MORALE_BAD_PERCENT"].Value) / 100)
	local unitMorale 		= unitData.Morale
	local moraleVariation	= unitData.MoraleVariation
	
	local str = ""
	-- summary, one line
	if unitMorale < badMorale then
		str = Locale.Lookup("LOC_UNITFLAG_BAD_MORALE", unitMorale, baseMorale)
	elseif unitMorale < lowMorale then
		str = Locale.Lookup("LOC_UNITFLAG_LOW_MORALE", unitMorale, baseMorale)
	elseif unitMorale == baseMorale then
		str = Locale.Lookup("LOC_UNITFLAG_HIGH_MORALE", unitMorale, baseMorale)
	else
		str = Locale.Lookup("LOC_UNITFLAG_MORALE", unitMorale, baseMorale)
	end	
	if moraleVariation > 0 then
		str = str .. " [ICON_PressureUp]"
	elseif moraleVariation < 0 then
		str = str .. " [ICON_PressureDown]"
	end
	
	-- details, multiple lines
	local moraleFromFood = GetMoraleFromFood(unitData)
	if moraleFromFood > 0 then
		str = str .. Locale.Lookup("LOC_UNITFLAG_MORALE_WELL_FED", moraleFromFood)
	elseif moraleFromFood < 0 then
		str = str .. Locale.Lookup("LOC_UNITFLAG_MORALE_FOOD_RATIONING", moraleFromFood)
	end	
	
	local moraleFromCombat = GetMoraleFromLastCombat(unitData)
	local turnLeft = tonumber(GameInfo.GlobalParameters["MORALE_COMBAT_EFFECT_NUM_TURNS"].Value) - (Game.GetCurrentGameTurn() - unitData.LastCombatTurn)
	if moraleFromCombat > 0 then
		str = str .. Locale.Lookup("LOC_UNITFLAG_MORALE_VICTORY", moraleFromCombat, turnLeft)
	elseif moraleFromCombat < 0 then
		str = str .. Locale.Lookup("LOC_UNITFLAG_MORALE_DEFEAT", moraleFromCombat, turnLeft)
	end			
	
	local moraleFromWounded = GetMoraleFromWounded(unitData)
	if moraleFromWounded > 0 then
		str = str .. Locale.Lookup("LOC_UNITFLAG_MORALE_NO_WOUNDED", moraleFromWounded)
	elseif moraleFromWounded < 0 then
		str = str .. Locale.Lookup("LOC_UNITFLAG_MORALE_WOUNDED", moraleFromWounded)
	end	
	
	local moraleFromHP = GetMoraleFromHP(unitData)
	if moraleFromHP > 0 then
		str = str .. Locale.Lookup("LOC_UNITFLAG_MORALE_FULL_HP", moraleFromHP)
	elseif moraleFromHP < 0 then
		str = str .. Locale.Lookup("LOC_UNITFLAG_MORALE_LOW_HP", moraleFromHP)
	end
	
	return str
end

function ShowCasualtiesFloatingText(CombatData)
	if floatingTextLevel == FLOATING_TEXT_NONE then
		return
	end
	local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
	if (pLocalPlayerVis ~= nil) then
		if (pLocalPlayerVis:IsVisible(CombatData.unit:GetX(), CombatData.unit:GetY())) then
			local sText = ""
			if floatingTextLevel == FLOATING_TEXT_SHORT then
				-- Show everything in 2 calls to AddWorldViewText
				-- Format text with newlines or separator as required, with 3 lines max
				local bNeedNewLine, bNeedSeparator = false, false
				if CombatData.PersonnelCasualties > 0 then
					sText = sText .. Locale.Lookup("LOC_FRONTLINE_PERSONNEL_CASUALTIES_DETAILS_SHORT", CombatData.Dead, CombatData.Captured, CombatData.Wounded)
					-- The string above is near the lenght limit of what AddWorldViewText can accept, so call it now.
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end
				-- 
				sText = ""
				if CombatData.VehiclesCasualties > 0 then
					if bNeedNewLine then sText = sText .. "[NEWLINE]" end
					sText = sText .. Locale.Lookup("LOC_FRONTLINE_VEHICLES_CASUALTIES_DETAILS_SHORT", CombatData.VehiclesLost, CombatData.DamagedVehicles)
					bNeedNewLine = true
				end
				if CombatData.HorsesLost > 0 then
					if bNeedNewLine then sText = sText .. "[NEWLINE]" end
					sText = sText .. Locale.Lookup("LOC_FRONTLINE_HORSES_CASUALTIES_SHORT", CombatData.HorsesLost)
					bNeedNewLine, bNeedSeparator = false, true
				end
				if CombatData.MaterielLost > 0 then
					if bNeedNewLine then sText = sText .. "[NEWLINE]" end
					if bNeedSeparator then sText = sText .. "," end
					sText = sText .. Locale.Lookup("LOC_FRONTLINE_MATERIEL_CASUALTIES_SHORT", CombatData.MaterielLost)
				end				
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
			
			else
				-- Show details with multiple calls to AddWorldViewText
				if CombatData.PersonnelCasualties > 0 then
					sText = Locale.Lookup("LOC_FRONTLINE_PERSONNEL_CASUALTIES", CombatData.PersonnelCasualties)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end
				if CombatData.Dead + CombatData.Captured + CombatData.Wounded > 0 then
					sText = Locale.Lookup("LOC_FRONTLINE_PERSONNEL_CASUALTIES_DETAILS", CombatData.Dead, CombatData.Captured, CombatData.Wounded)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end

				if CombatData.VehiclesCasualties > 0 then
					sText = Locale.Lookup("LOC_FRONTLINE_VEHICLES_CASUALTIES", CombatData.VehiclesCasualties)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end
				if CombatData.VehiclesLost +CombatData.DamagedVehicles > 0 then
					sText = Locale.Lookup("LOC_FRONTLINE_VEHICLES_CASUALTIES_DETAILS", CombatData.VehiclesLost, CombatData.DamagedVehicles)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end

				if CombatData.HorsesLost > 0 then
					sText = Locale.Lookup("LOC_FRONTLINE_HORSES_CASUALTIES", CombatData.HorsesLost)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end

				if CombatData.MaterielLost > 0 then
					sText = Locale.Lookup("LOC_FRONTLINE_MATERIEL_CASUALTIES", CombatData.MaterielLost)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end
			end
		end
	end
end

function ShowCombatPlunderingFloatingText(CombatData)
	if floatingTextLevel == FLOATING_TEXT_NONE then
		return
	end
	local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
	if (pLocalPlayerVis ~= nil) then
		if (pLocalPlayerVis:IsVisible(CombatData.unit:GetX(), CombatData.unit:GetY())) then
			local sText = ""
			if floatingTextLevel == FLOATING_TEXT_SHORT then
				-- Show everything in one call to AddWorldViewText
				-- Format text with newlines or separator as required
				local bNeedNewLine, bNeedSeparator = false, false
				-- first line				
				if CombatData.Prisonners > 0 then
					sText = Locale.Lookup("LOC_FRONTLINE_PRISONNERS_CAPTURED_SHORT", CombatData.Prisonners)
					bNeedNewLine, bNeedSeparator = true, true
				end
				if CombatData.MaterielGained > 0 then
					if bNeedSeparator then sText = sText .. "," end
					sText = Locale.Lookup("LOC_FRONTLINE_MATERIEL_CAPTURED_SHORT", CombatData.MaterielGained)
					bNeedNewLine, bNeedSeparator = true, false
				end
				-- second line
				if bNeedNewLine then Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0) end
				sText = ""
				bNeedSeparator = false -- we don't want a separator at the beginning of a new line
				if CombatData.LiberatedPrisonners and CombatData.LiberatedPrisonners > 0 then -- LiberatedPrisonners is not nil only when the defender is dead...
					--if bNeedNewLine then sText = sText .. "[NEWLINE]" end
					sText = Locale.Lookup("LOC_FRONTLINE_LIBERATED_PRISONNERS_SHORT", CombatData.LiberatedPrisonners)
					bNeedNewLine, bNeedSeparator = false, true
				end				
				if CombatData.FoodGained and CombatData.FoodGained > 0 then  -- FoodGained is not nil only when the defender is dead...
					--if bNeedNewLine then sText = sText .. "[NEWLINE]" end
					if bNeedSeparator then sText = sText .. "," end
					sText = Locale.Lookup("LOC_FRONTLINE_FOOD_CAPTURED_SHORT", CombatData.FoodGained)
				end
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
			else
				-- Show details with multiple calls to AddWorldViewText			
				if CombatData.Prisonners > 0 then
					sText = Locale.Lookup("LOC_FRONTLINE_PRISONNERS_CAPTURED", CombatData.Prisonners)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end
				if CombatData.MaterielGained > 0 then
					sText = Locale.Lookup("LOC_FRONTLINE_MATERIEL_CAPTURED", CombatData.MaterielGained)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end
				if CombatData.LiberatedPrisonners and CombatData.LiberatedPrisonners > 0 then -- LiberatedPrisonners is not nil only when the defender is dead...
					sText = Locale.Lookup("LOC_FRONTLINE_LIBERATED_PRISONNERS", CombatData.LiberatedPrisonners)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end				
				if CombatData.FoodGained and CombatData.FoodGained > 0 then  -- FoodGained is not nil only when the defender is dead...
					sText = Locale.Lookup("LOC_FRONTLINE_FOOD_CAPTURED", CombatData.FoodGained)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, CombatData.unit:GetX(), CombatData.unit:GetY(), 0)
				end
			end
		end
	end
end

function ShowFoodFloatingText(foodData)
	if floatingTextLevel == FLOATING_TEXT_NONE then
		return
	end
	if foodData.foodEat + foodData.foodGet > 0 then
		local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
		if (pLocalPlayerVis ~= nil) then
			if (pLocalPlayerVis:IsVisible(foodData.X, foodData.Y)) then
				local sText = ""
				if foodData.foodEat > 0 then sText = Locale.Lookup("LOC_UNIT_EATING", foodData.foodEat) end
				if foodData.foodGet > 0 then sText = sText .. "[NEWLINE]" ..Locale.Lookup("LOC_UNIT_GET_FOOD", foodData.foodGet) end
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, foodData.X, foodData.Y, 0)
			end
		end
	end
end

function ShowFrontLineHealingFloatingText(healingData)
	if floatingTextLevel == FLOATING_TEXT_NONE then
		return
	end
	local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
	if (pLocalPlayerVis ~= nil) then
		if (pLocalPlayerVis:IsVisible(healingData.X, healingData.Y)) then
			local sText = ""
			if floatingTextLevel == FLOATING_TEXT_SHORT then
				-- Show everything in 2 calls to AddWorldViewText
				-- Format text with newlines or separator as required
				local bNeedNewLine, bNeedSeparator = false, false
				if healingData.reqPersonnel + healingData.reqMateriel > 0 then
					sText = sText .. Locale.Lookup("LOC_PERSONNEL_RESERVE_TRANSFERT", healingData.reqPersonnel)
					bNeedNewLine, bNeedSeparator = true, true
				end
				if healingData.reqMateriel > 0 then
					if bNeedSeparator then sText = sText .. "," end
					sText = sText .. Locale.Lookup("LOC_MATERIEL_RESERVE_TRANSFERT", healingData.reqMateriel)
					bNeedNewLine, bNeedSeparator = true, true
				end
				-- second line
				if bNeedNewLine then Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, healingData.X, healingData.Y, 0) end
				bNeedNewLine, bNeedSeparator = false, false
				sText = ""
				if healingData.reqVehicles > 0 then
					--if bNeedNewLine then sText = sText .. "[NEWLINE]" end
					sText = sText .. Locale.Lookup("LOC_VEHICLES_RESERVE_TRANSFERT", healingData.reqVehicles)					
					bNeedNewLine, bNeedSeparator = false, true
				end
				if healingData.reqHorses > 0 then
					--if bNeedNewLine then sText = sText .. "[NEWLINE]" end
					if bNeedSeparator then sText = sText .. "," end
					sText = sText .. Locale.Lookup("LOC_HORSES_RESERVE_TRANSFERT", healingData.reqHorses)
				end
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, healingData.X, healingData.Y, 0)
			else
				-- Show details with multiple calls to AddWorldViewText	
				if healingData.reqPersonnel + healingData.reqMateriel > 0 then
					sText = Locale.Lookup("LOC_HEALING_PERSONNEL_MATERIEL", healingData.reqPersonnel, healingData.reqMateriel)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, healingData.X, healingData.Y, 0)
				end
				if healingData.reqVehicles > 0 then
					sText = Locale.Lookup("LOC_HEALING_VEHICLES", healingData.reqVehicles)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, healingData.X, healingData.Y, 0)
				end
				if healingData.reqHorses > 0 then
					sText = Locale.Lookup("LOC_HEALING_HORSES", healingData.reqHorses)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, healingData.X, healingData.Y, 0)
				end
			end
		end
	end
end

function ShowReserveHealingFloatingText(healingData)
	if floatingTextLevel == FLOATING_TEXT_NONE then
		return
	end
	local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
	if (pLocalPlayerVis ~= nil) then
		if (pLocalPlayerVis:IsVisible(healingData.X, healingData.Y)) then
			local sText = ""
			if floatingTextLevel == FLOATING_TEXT_SHORT then
				-- Show everything in 2 calls to AddWorldViewText
				-- Format text with NEWLINE as required				
				local bNeedNewLine, bNeedSeparator = false, false
				-- first line
				if healingData.deads + healingData.healed > 0 then
					sText = sText .. Locale.Lookup("LOC_HEALING_WOUNDED", healingData.deads, healingData.healed)
					bNeedNewLine, bNeedSeparator = true, false
				end
				-- second line
				if bNeedNewLine then Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, healingData.X, healingData.Y, 0) end
				sText = ""
				bNeedSeparator = false
				if healingData.repairedVehicules > 0 then
					--if bNeedNewLine then sText = sText .. "[NEWLINE]" end
					sText = sText .. Locale.Lookup("LOC_REPAIRING_VEHICLES", healingData.repairedVehicules)
				end
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, healingData.X, healingData.Y, 0)
			else			
				-- Show details with multiple calls to AddWorldViewText	
				if healingData.deads + healingData.healed > 0 then
					sText = Locale.Lookup("LOC_HEALING_WOUNDED", healingData.deads, healingData.healed)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, healingData.X, healingData.Y, 0)
				end
				if healingData.repairedVehicules > 0 then
					sText = Locale.Lookup("LOC_REPAIRING_VEHICLES", healingData.repairedVehicules)
					Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, healingData.X, healingData.Y, 0)
				end
			end
		end
	end
end

function ShowDesertionFloatingText(desertionData)
	if floatingTextLevel == FLOATING_TEXT_NONE then
		return
	end
	local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
	if (pLocalPlayerVis ~= nil) then
		if (pLocalPlayerVis:IsVisible(desertionData.X, desertionData.Y)) then
			local sText = Locale.Lookup("LOC_UNIT_PERSONNEL_DESERTION", desertionData.Personnel)
			local bNeedNewLine, bNeedSeparator = true, false
			if desertionData.Vehicles > 0 then
				if bNeedNewLine then sText = sText .. "[NEWLINE]" end
				if bNeedSeparator then sText = sText .. "," end
				sText = sText .. Locale.Lookup("LOC_VEHICLES_RESERVE_TRANSFERT", desertionData.Vehicles)
				bNeedNewLine, bNeedSeparator = false, true
			end
			if desertionData.Horses > 0 then
				if bNeedNewLine then sText = sText .. "[NEWLINE]" end
				if bNeedSeparator then sText = sText .. "," end
				sText = sText .. Locale.Lookup("LOC_HORSES_RESERVE_TRANSFERT", desertionData.Horses)
				bNeedNewLine, bNeedSeparator = false, true
			end
			if desertionData.Materiel > 0 then
				if bNeedNewLine then sText = sText .. "[NEWLINE]" end
				if bNeedSeparator then sText = sText .. "," end
				sText = sText .. Locale.Lookup("LOC_MATERIEL_RESERVE_TRANSFERT", desertionData.Materiel)
				bNeedNewLine, bNeedSeparator = false, true
			end
			Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, desertionData.X, desertionData.Y, 0)
		end
	end
end

function ShowFuelConsumptionFloatingText(fuelData)
	if floatingTextLevel == FLOATING_TEXT_NONE then
		return
	end
	if fuelData.fuelConsumption > 0 then
		local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()]
		if (pLocalPlayerVis ~= nil) then
			if (pLocalPlayerVis:IsVisible(fuelData.X, fuelData.Y)) then
				local sText = Locale.Lookup("LOC_UNIT_FUEL_CONSUMPTION", fuelData.fuelConsumption)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, fuelData.X, fuelData.Y, 0)
			end
		end
	end
end

----------------------------------------------
-- Share functions for other contexts
----------------------------------------------

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	-- maths
	ExposedMembers.GCO.Round 		= Round
	ExposedMembers.GCO.Shuffle 		= Shuffle
	ExposedMembers.GCO.GetSize 		= GetSize
	ExposedMembers.GCO.ToDecimals 	= ToDecimals
	-- timers
	ExposedMembers.GCO.StartTimer 	= StartTimer
	ExposedMembers.GCO.ShowTimer 	= ShowTimer
	-- debug
	ExposedMembers.GCO.ToggleOutput = ToggleOutput
	ExposedMembers.GCO.Dprint		= Dprint
	-- cities
	ExposedMembers.GCO.GetCityFoodConsumption 	= GetCityFoodConsumption
	-- cities flag strings
	ExposedMembers.GCO.GetCityFoodStockString 	= GetCityFoodStockString
	ExposedMembers.GCO.GetResourcesStockString	= GetResourcesStockString
	-- civilizations
	ExposedMembers.GCO.CreateEverAliveTableWithDefaultValue = CreateEverAliveTableWithDefaultValue
	ExposedMembers.GCO.CreateEverAliveTableWithEmptyTable 	= CreateEverAliveTableWithEmptyTable
	-- map
	ExposedMembers.GCO.GetPlotKey 					= GetPlotKey
	ExposedMembers.GCO.FindNearestPlayerCity 		= FindNearestPlayerCity
	-- player
	ExposedMembers.GCO.GetPlayerUpperClassPercent 	= GetPlayerUpperClassPercent
	ExposedMembers.GCO.GetPlayerMiddleClassPercent 	= GetPlayerMiddleClassPercent
	-- units
	ExposedMembers.GCO.GetUnitKey 						= GetUnitKey
	ExposedMembers.GCO.GetUnitFromKey 					= GetUnitFromKey
	ExposedMembers.GCO.GetUnitKeyFromIDs 				= GetUnitKeyFromIDs
	ExposedMembers.GCO.GetMaxTransfertTable 			= GetMaxTransfertTable	
	ExposedMembers.GCO.GetPersonnelReserve 				= GetPersonnelReserve
	ExposedMembers.GCO.GetVehiclesReserve 				= GetVehiclesReserve
	ExposedMembers.GCO.GetHorsesReserve 				= GetHorsesReserve
	ExposedMembers.GCO.GetMaterielReserve 				= GetMaterielReserve
	ExposedMembers.GCO.GetTotalPrisonners 				= GetTotalPrisonners
	ExposedMembers.GCO.GetUnitFoodConsumption 			= GetUnitFoodConsumption
	ExposedMembers.GCO.GetUnitBaseFoodStock 			= GetUnitBaseFoodStock
	ExposedMembers.GCO.GetFuelConsumption 				= GetFuelConsumption
	ExposedMembers.GCO.GetBaseFuelStock 				= GetBaseFuelStock
	ExposedMembers.GCO.GetMoraleFromFood 				= GetMoraleFromFood
	ExposedMembers.GCO.GetMoraleFromLastCombat 			= GetMoraleFromLastCombat
	ExposedMembers.GCO.GetMoraleFromWounded				= GetMoraleFromWounded
	ExposedMembers.GCO.GetMoraleFromHP 					= GetMoraleFromHP	
	ExposedMembers.GCO.CheckComponentsHP 				= CheckComponentsHP
	ExposedMembers.GCO.ShowDebugComponentsHP 			= ShowDebugComponentsHP
	ExposedMembers.GCO.DebugComponentsHP 				= DebugComponentsHP
	-- units flag strings
	ExposedMembers.GCO.GetPrisonnersStringByCiv 			= GetPrisonnersStringByCiv
	ExposedMembers.GCO.GetUnitFoodConsumptionRatioString 	= GetUnitFoodConsumptionRatioString
	ExposedMembers.GCO.GetUnitFoodConsumptionString 		= GetUnitFoodConsumptionString
	ExposedMembers.GCO.GetUnitFoodStockString 				= GetUnitFoodStockString
	ExposedMembers.GCO.GetFuelStockString 					= GetFuelStockString
	ExposedMembers.GCO.GetFuelConsumptionString 			= GetFuelConsumptionString
	ExposedMembers.GCO.GetMoraleString 						= GetMoraleString
	-- units floating texts
	ExposedMembers.GCO.ShowCasualtiesFloatingText 		= ShowCasualtiesFloatingText
	ExposedMembers.GCO.ShowCombatPlunderingFloatingText = ShowCombatPlunderingFloatingText
	ExposedMembers.GCO.ShowFoodFloatingText 			= ShowFoodFloatingText
	ExposedMembers.GCO.ShowFrontLineHealingFloatingText	= ShowFrontLineHealingFloatingText
	ExposedMembers.GCO.ShowReserveHealingFloatingText 	= ShowReserveHealingFloatingText
	ExposedMembers.GCO.ShowDesertionFloatingText 		= ShowDesertionFloatingText
	ExposedMembers.GCO.ShowFuelConsumptionFloatingText 	= ShowFuelConsumptionFloatingText
	-- initialization	
	ExposedMembers.Utils_Initialized 	= true
end
Initialize()


-----------------------------------------------------------------------------------------
-- Cleaning on exit
-----------------------------------------------------------------------------------------
function Cleaning()
	print ("Cleaning GCO stuff on LeaveGameComplete...")
	-- 
	ExposedMembers.SaveLoad_Initialized 		= nil
	ExposedMembers.ContextFunctions_Initialized	= nil
	ExposedMembers.Utils_Initialized 			= nil
	ExposedMembers.Serialize_Initialized 		= nil
	ExposedMembers.RouteConnections_Initialized	= nil	
	ExposedMembers.PlotIterator_Initialized		= nil
	ExposedMembers.PlotScript_Initialized 		= nil
	ExposedMembers.CityScript_Initialized 		= nil
	--
	ExposedMembers.UnitHitPointsTable 			= nil
	--
	ExposedMembers.UnitData 					= nil
	ExposedMembers.CityData 					= nil
	ExposedMembers.PlayerData 					= nil
	ExposedMembers.CultureMap 					= nil
	ExposedMembers.PreviousCultureMap 			= nil
	ExposedMembers.GCO 							= nil
	--
	ExposedMembers.UI 							= nil
	ExposedMembers.Calendar 					= nil
	ExposedMembers.CombatTypes 					= nil
end
Events.LeaveGameComplete.Add(Cleaning)


-----------------------------------------------------------------------------------------
-- Testing...
-----------------------------------------------------------------------------------------

local currentTurn = -1
local playerMadeTurn = {}
function GetPlayerTurn(playerID)
	if (currentTurn ~= Game.GetCurrentGameTurn()) then
		currentTurn = Game.GetCurrentGameTurn()
		playerMadeTurn = {}
	end
	if not playerMadeTurn[playerID] then
		LuaEvents.StartPlayerTurn(playerID)			
		print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
		print("-- Test Start Turn player#"..tostring(playerID))
		print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
		playerMadeTurn[playerID] = true
	end
end
function OnUnitMovementPointsChanged(playerID)
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	print("-- Test Start Turn On UnitMovementPointsChanged player#"..tostring(playerID))
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	GetPlayerTurn(playerID)
end
function OnAiAdvisorUpdated(playerID)
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	print("-- Test Start Turn On AiAdvisorUpdated player#"..tostring(playerID))
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	GetPlayerTurn(playerID)
end
function FindActivePlayer()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		local player = Players[playerID]
		if player:IsTurnActive() then
			GetPlayerTurn(playerID)
		end
	end
end
Events.GameCoreEventPublishComplete.Add( FindActivePlayer )
--Events.UnitMovementPointsChanged.Add(OnUnitMovementPointsChanged)
--Events.OnAiAdvisorUpdated.Add(OnAiAdvisorUpdated)

function TestA()
	print ("Calling TestA...")
end
function TestB()
	print ("Calling TestB...")
end
function TestC()
	print ("Calling TestC...")
end
function TestD()
	print ("Calling TestD...")
end
function TestE()
	print ("Calling TestE...")
end
function TestF()
	print ("Calling TestF...")
end
--Events.AppInitComplete.Add(TestA)
--Events.GameViewStateDone.Add(TestB)
--Events.LoadGameViewStateDone.Add(TestC)
--Events.LoadScreenContentReady.Add(TestD)
--Events.MainMenuStateDone.Add(TestE)
--Events.LoadComplete.Add(TestA)
--Events.RequestSave.Add(TestB)
--Events.RequestLoad.Add(TestC)
--EndGameView