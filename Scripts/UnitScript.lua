--=====================================================================================--
--	FILE:	 UnitScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading UnitScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------
local UnitHitPointsTable = {} -- cached table to store the required values of an unit components based on it's HP
local EverAliveZeroTable = {} -- cached table to initialize an empty table with civID as keys and 0 as initial values

local maxHP = GlobalParameters.COMBAT_MAX_HIT_POINTS -- 100

local lightRationing 	=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_LIGHT_RATIO"].Value)
local mediumRationing 	=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_MEDIUM_RATIO"].Value)
local heavyRationing 	=  tonumber(GameInfo.GlobalParameters["FOOD_RATIONING_HEAVY_RATIO"].Value)

-----------------------------------------------------------------------------------------
-- Initialize 
-----------------------------------------------------------------------------------------
local GCO = {}
local CombatTypes = {}
function InitializeUtilityFunctions()
	GCO 		= ExposedMembers.GCO			-- contains functions from other contexts
	CombatTypes = ExposedMembers.CombatTypes 	-- need those in combat results
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function PostInitialize() -- everything that may require other context to be loaded first
	LoadUnitTable()
	EverAliveZeroTable = GCO.CreateEverAliveTableWithDefaultValue(0)
end

function Initialize() -- Everything that can be initialized immediatly after loading this file(cached tables)
	CreateUnitHitPointsTable()
	ExposedMembers.UnitHitPointsTable = UnitHitPointsTable
	ShareFunctions()
	
	Events.UnitAddedToMap.Add( InitializeUnitFunctions )
	Events.UnitAddedToMap.Add( InitializeUnit ) -- InitializeUnitFunctions must be called before InitializeUnit...
end

-----------------------------------------------------------------------------------------
-- Unit composition
-----------------------------------------------------------------------------------------
local minCompLeftFactor = GameInfo.GlobalParameters["UNIT_MIN_COMPONENT_LEFT_FACTOR"].Value -- Modded global parameters are not in GlobalParameters.NAME like vanilla parameters ?????
local maxCompLeftFactor = GameInfo.GlobalParameters["UNIT_MAX_COMPONENT_LEFT_FACTOR"].Value
function GetNumComponentAtHP(maxNumComponent, HPLeft)
	local numComponent = 0
	local maxCompLeft100 = 0
	local minCompLeft100 = ((HPLeft * 100) * (maxNumComponent / maxHP) * (HPLeft / maxHP))
	if maxHP > maxNumComponent then
		maxCompLeft100 = math.min(HPLeft * 100, math.min(maxNumComponent * 100, (HPLeft * 100 / (maxNumComponent / maxHP))))
	else
		maxCompLeft100 = math.min(maxNumComponent * 100, HPLeft * 100 * ( maxNumComponent / maxHP))
	end
	local numComponent100 = math.max( 100, ((( minCompLeft100 * minCompLeftFactor) + ( maxCompLeft100 * maxCompLeftFactor)) / ( minCompLeftFactor + maxCompLeftFactor )))
	numComponent = math.ceil(numComponent100 / 100)
	return numComponent
end

function CreateUnitHitPointsTable()
	for row in GameInfo.Units() do
		UnitHitPointsTable[row.Index] = {}
		local Personnel = row.Personnel
		local Vehicles = row.Vehicles
		local Horses = row.Horses
		local Materiel = row.Materiel
		for hp = 0, maxHP do
			UnitHitPointsTable[row.Index][hp] = {}
			if Personnel > 0 then UnitHitPointsTable[row.Index][hp].Personnel = GetNumComponentAtHP(Personnel, hp) else UnitHitPointsTable[row.Index][hp].Personnel = 0 end
			if Vehicles > 0 then UnitHitPointsTable[row.Index][hp].Vehicles = GetNumComponentAtHP(Vehicles, hp) else UnitHitPointsTable[row.Index][hp].Vehicles = 0 end
			if Horses > 0 then UnitHitPointsTable[row.Index][hp].Horses = GetNumComponentAtHP(Horses, hp) else UnitHitPointsTable[row.Index][hp].Horses = 0 end
			if Materiel > 0 then UnitHitPointsTable[row.Index][hp].Materiel = GetNumComponentAtHP(Materiel, hp) else UnitHitPointsTable[row.Index][hp].Materiel = 0 end
		end
	end
end

-----------------------------------------------------------------------------------------
-- Load/Save the tables
-----------------------------------------------------------------------------------------
-- Use Enum for faster serialization
local unitTableEnum = {

	unitID					= 1,
	playerID				= 2,
	unitType				= 3,
	MaterielPerVehicles		= 4,
	Personnel				= 5,
	Vehicles				= 6,
	Horses					= 7,
	Materiel				= 8,
	PersonnelReserve		= 9,
	VehiclesReserve			= 10,
	HorsesReserve			= 11,
	MaterielReserve			= 12,
	WoundedPersonnel		= 13,
	DamagedVehicles			= 14,
	Prisonners				= 15,
	FoodStock				= 16,
	PreviousFoodStock		= 17,
	TotalDeath				= 18,
	TotalVehiclesLost		= 19,
	TotalHorsesLost			= 20,
	TotalKill				= 21,
	TotalUnitsKilled		= 22,
	TotalShipSunk			= 23,
	TotalTankDestroyed		= 24,
	TotalAircraftKilled		= 25,
	Morale					= 26,
	MoraleVariation			= 27,
	LastCombatTurn			= 28,
	LastCombatResult		= 29,
	LastCombatType			= 30,
	Alive					= 31,
	TotalXP					= 32,
	CombatXP				= 33,
	SupplyLineCityKey		= 34,
	SupplyLineEfficiency	= 35,
	FuelStock				= 36,
	PreviousFuelStock		= 37,
	HP 						= 38,
	testHP					= 39,
	TurnCreated				= 40,
	
	EndOfEnum				= 99
}                           

function SaveUnitTable()
	local UnitData = ExposedMembers.UnitData
	print("--------------------------- UnitData: Save w/Enum ---------------------------")
	local t = {}
	for key, data in pairs(UnitData) do
		t[key] = {}
		for name, enum in pairs(unitTableEnum) do
			t[key][enum] = data[name]
		end
	end	
	GCO.SaveTableToSlot(t, "UnitData")	
end

function LoadUnitTable()

	print("--------------------------- UnitData: Load w/Enum ---------------------------")
	local unitData = {}
	local loadedTable = GCO.LoadTableFromSlot("UnitData")
	if loadedTable then
		for key, data in pairs(loadedTable) do
			unitData[key] = {}
			for name, enum in pairs(unitTableEnum) do
				unitData[key][name] = data[enum]
			end			
		end
		ExposedMembers.UnitData = unitData
	else
		ExposedMembers.UnitData = {}
	end
end

function SaveTables()
	SaveUnitTable()
end
LuaEvents.SaveTables.Add(SaveTables)

-- for debugging load/save
function ShowUnitData()
	for unitKey, data in pairs(ExposedMembers.UnitData) do
		print (unitKey, data)
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
-- Units Initialization
-----------------------------------------------------------------------------------------
function RegisterNewUnit(playerID, unit)

	local unitType = unit:GetType()
	local unitID = unit:GetID()
	local unitKey = unit:GetKey()
	local hp = unit:GetMaxDamage() - unit:GetDamage()

	ExposedMembers.UnitData[unitKey] = {
		TurnCreated				= Game.GetCurrentGameTurn(),
		unitID 					= unitID,
		playerID 				= playerID,
		unitType 				= unitType,
		MaterielPerVehicles 	= GameInfo.Units[unitType].MaterielPerVehicles,
		HP	 					= unit:GetMaxDamage() - unit:GetDamage(),
		testHP	 				= unit:GetMaxDamage() - unit:GetDamage(),
		-- "Frontline" : combat ready, units HP are restored only if there is enough reserve to move to frontline for all required components
		Personnel 				= UnitHitPointsTable[unitType][hp].Personnel,
		Vehicles 				= UnitHitPointsTable[unitType][hp].Vehicles,
		Horses 					= UnitHitPointsTable[unitType][hp].Horses,
		Materiel 				= UnitHitPointsTable[unitType][hp].Materiel,
		-- "Tactical Reserve" : ready to reinforce frontline, that's where reinforcements from cities, healed personnel and repaired Vehicles are affected first
		PersonnelReserve		= GetPersonnelReserve(unitType),
		VehiclesReserve			= GetVehiclesReserve(unitType),
		HorsesReserve			= GetHorsesReserve(unitType),
		MaterielReserve			= GetMaterielReserve(unitType),
		-- "Rear"
		WoundedPersonnel		= 0,
		DamagedVehicles			= 0,
		Prisonners				= GCO.CreateEverAliveTableWithDefaultValue(0), -- table with all civs in game (including Barbarians) to track Prisonners by nationality
		FoodStock 				= GetUnitBaseFoodStock(unitType),
		PreviousFoodStock		= 0,
		FuelStock 				= GetBaseFuelStock(unitType),
		PreviousFuelStock		= 0,		
		-- Statistics
		TotalDeath				= 0,
		TotalVehiclesLost		= 0,
		TotalHorsesLost			= 0,
		TotalKill				= 0,
		TotalUnitsKilled		= 0,
		TotalShipSunk			= 0,
		TotalTankDestroyed		= 0,
		TotalAircraftKilled		= 0,
		-- Others
		Morale 					= tonumber(GameInfo.GlobalParameters["MORALE_BASE_VALUE"].Value), -- 100
		MoraleVariation			= 0,
		LastCombatTurn			= 0,
		LastCombatResult		= 0,
		LastCombatType			= -1,
		Alive 					= true,
		TotalXP 				= unit:GetExperience():GetExperiencePoints(),
		CombatXP 				= 0,
		SupplyLineCityKey		= nil,
		SupplyLineEfficiency 	= 0,
	}
	SetUnitsupplyLine(unit)
	LuaEvents.NewUnitCreated()
end

function InitializeUnit(playerID, unitID)
	local unit = UnitManager.GetUnit(playerID, unitID)
	if unit then
		local unitKey = unit:GetKey()

		if ExposedMembers.UnitData[unitKey] then
			-- unit already registered, don't add it again...
			print("  - ".. unit:GetName() .." is already registered")
			return
		end

		print ("Initializing new unit (".. unit:GetName() ..") for player #".. tostring(playerID).. " id#" .. tostring(unit:GetID()))
		RegisterNewUnit(playerID, unit)
		--print("-------------------------------------")
	else
		print ("- WARNING : tried to initialize nil unit for player #".. tostring(playerID) .." (you can ignore this warning when launching a new game)")
	end

end


-----------------------------------------------------------------------------------------
-- Units functions
-----------------------------------------------------------------------------------------
function GetUnitKeyFromIDs(ownerID, unitID) -- local
	return unitID..","..ownerID
end

-- return unique key for units table [unitID,playerID]
function GetKey(self)
	local ownerID = self:GetOwner()
	local unitID = self:GetID()
	local unitKey = GetUnitKeyFromIDs(ownerID, unitID)
	return unitKey
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
	local key = unit:GetKey()
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


-----------------------------------------------------------------------------------------
-- Resources functions
-----------------------------------------------------------------------------------------
function GetPersonnelReserve(unitType)
	return GCO.Round((GameInfo.Units[unitType].Personnel * GameInfo.GlobalParameters["UNIT_RESERVE_RATIO"].Value / 10) * 10)
end

function GetVehiclesReserve(unitType)
	return GCO.Round((GameInfo.Units[unitType].Vehicles * GameInfo.GlobalParameters["UNIT_RESERVE_RATIO"].Value / 10) * 10)
end

function GetHorsesReserve(unitType)
	return GCO.Round((GameInfo.Units[unitType].Horses * GameInfo.GlobalParameters["UNIT_RESERVE_RATIO"].Value / 10) * 10)
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
		foodConsumption1000 = foodConsumption1000 + (GCO.GetTotalPrisonners(unitData) * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PRISONNERS_FACTOR"].Value) * ratio )
	end	
	return math.max(1, GCO.Round( foodConsumption1000 / 1000 ))
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
	return math.max(1, GCO.Round( fuelConsumption1000 / 1000))
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
	local unitInfo = GameInfo.Units[unitType]
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
		moraleFromCombat = GCO.Round(moraleFromCombat * tonumber(GameInfo.GlobalParameters["MORALE_COMBAT_NON_MELEE_RATIO"].Value))
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
-- Flag
function GetUnitFoodConsumptionString(unitData)
	local str = ""
	local ratio = GetUnitFoodConsumptionRatio(unitData)
	local totalPersonnel = unitData.Personnel + unitData.PersonnelReserve
	if totalPersonnel > 0 then 
		local personnelFood = ( totalPersonnel * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PERSONNEL_FACTOR"].Value) )/1000
		str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FOOD_CONSUMPTION_PERSONNEL", GCO.ToDecimals(personnelFood * ratio), totalPersonnel) 
	end	
	local totalHorses = unitData.Horses + unitData.HorsesReserve
	if totalHorses > 0 then 
		local horsesFood = ( totalHorses * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_HORSES_FACTOR"].Value) )/1000
		str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FOOD_CONSUMPTION_HORSES", GCO.ToDecimals(horsesFood * ratio), totalHorses ) 
	end
	
	-- value belows may be nil
	if unitData.WoundedPersonnel and unitData.WoundedPersonnel > 0 then 
		local woundedFood = ( unitData.WoundedPersonnel * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_WOUNDED_FACTOR"].Value) )/1000
		str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FOOD_CONSUMPTION_WOUNDED", GCO.ToDecimals(woundedFood * ratio), unitData.WoundedPersonnel ) 
	end
	if unitData.Prisonners then	
		local totalPrisonners = GCO.GetTotalPrisonners(unitData)		
		if totalPrisonners > 0 then 
			local prisonnersFood = ( totalPrisonners * tonumber(GameInfo.GlobalParameters["FOOD_CONSUMPTION_PRISONNERS_FACTOR"].Value) )/1000
			str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FOOD_CONSUMPTION_PRISONNERS", GCO.ToDecimals(prisonnersFood * ratio), totalPrisonners )
		end
	end	
	return str
end

function GetMoraleString(unitData) 
	local baseMorale 		= tonumber(GameInfo.GlobalParameters["MORALE_BASE_VALUE"].Value)
	local lowMorale 		= GCO.Round(baseMorale * tonumber(GameInfo.GlobalParameters["MORALE_LOW_PERCENT"].Value) / 100)
	local badMorale 		= GCO.Round(baseMorale * tonumber(GameInfo.GlobalParameters["MORALE_BAD_PERCENT"].Value) / 100)
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
		str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FUEL_CONSUMPTION_ACTIVE", GCO.ToDecimals(fuel * ratio), unitData.Vehicles) 
	end	
	if unitData.DamagedVehicles > 0 then 
		local fuel = ( unitData.DamagedVehicles * tonumber(GameInfo.GlobalParameters["FUEL_CONSUMPTION_ACTIVE_FACTOR"].Value) )/1000
		str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_FUEL_CONSUMPTION_DAMAGED", GCO.ToDecimals(fuel * ratio), unitData.DamagedVehicles) 
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

-- Floating text
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


-----------------------------------------------------------------------------------------
-- Combat
-----------------------------------------------------------------------------------------
function AddCombatInfoTo(Opponent)

	Opponent.unit = UnitManager.GetUnit(Opponent.playerID, Opponent.unitID)
	if Opponent.unit then
		Opponent.unitType = Opponent.unit:GetType()
		Opponent.unitKey = Opponent.unit:GetKey()
		Opponent.IsLandUnit = GameInfo.Units[Opponent.unitType].Domain == "DOMAIN_LAND"
		-- Max number of prisonners can't be higher than the unit's operationnal number of personnel or the number of remaining valid personnel x10
		Opponent.MaxPrisonners = math.min(GameInfo.Units[Opponent.unitType].Personnel, (ExposedMembers.UnitData[Opponent.unitKey].Personnel+ExposedMembers.UnitData[Opponent.unitKey].PersonnelReserve)*10)
		local diff = (Opponent.MaxPrisonners - GCO.GetTotalPrisonners(ExposedMembers.UnitData[Opponent.unitKey]))
		if diff > 0 then
			Opponent.MaxCapture = GCO.Round(diff * GameInfo.GlobalParameters["COMBAT_CAPTURE_FROM_CAPACITY_PERCENT"].Value/100)
		else
			Opponent.MaxCapture = 0
		end
		Opponent.AntiPersonnel = GameInfo.Units[Opponent.unitType].AntiPersonnel
	else
		Opponent.unitKey = GetUnitKeyFromIDs(Opponent.playerID, Opponent.unitID)
	end	

	return Opponent
end

function AddFrontLineCasualtiesInfoTo(Opponent)

	if Opponent.IsDead then

		Opponent.FinalHP = 0
		--[[
		Opponent.PersonnelCasualties 	= ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.InitialHP].Personnel
		Opponent.VehiclesCasualties 	= ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.InitialHP].Vehicles
		Opponent.HorsesCasualties 		= ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.InitialHP].Horses
		Opponent.MaterielCasualties 	= ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.InitialHP].Materiel

		-- "Kill" the unit
		ExposedMembers.UnitData[Opponent.unitKey].Personnel = 0
		ExposedMembers.UnitData[Opponent.unitKey].Vehicles  = 0
		ExposedMembers.UnitData[Opponent.unitKey].Horses	= 0
		ExposedMembers.UnitData[Opponent.unitKey].Materiel 	= 0
		--]]
		ExposedMembers.UnitData[Opponent.unitKey].Alive 	= false
	end
	--else
		Opponent.PersonnelCasualties 	= ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.InitialHP].Personnel 	- ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.FinalHP].Personnel
		Opponent.VehiclesCasualties 	= ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.InitialHP].Vehicles 	- ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.FinalHP].Vehicles
		Opponent.HorsesCasualties 		= ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.InitialHP].Horses		- ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.FinalHP].Horses
		Opponent.MaterielCasualties		= ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.InitialHP].Materiel 	- ExposedMembers.UnitHitPointsTable[Opponent.unitType][Opponent.FinalHP].Materiel

		-- Remove casualties from frontline
		ExposedMembers.UnitData[Opponent.unitKey].Personnel = ExposedMembers.UnitData[Opponent.unitKey].Personnel  	- Opponent.PersonnelCasualties
		ExposedMembers.UnitData[Opponent.unitKey].Vehicles  = ExposedMembers.UnitData[Opponent.unitKey].Vehicles  	- Opponent.VehiclesCasualties
		ExposedMembers.UnitData[Opponent.unitKey].Horses	= ExposedMembers.UnitData[Opponent.unitKey].Horses	  	- Opponent.HorsesCasualties
		ExposedMembers.UnitData[Opponent.unitKey].Materiel 	= ExposedMembers.UnitData[Opponent.unitKey].Materiel 	- Opponent.MaterielCasualties
	--end

	return Opponent
end

function AddCasualtiesInfoByTo(OpponentA, OpponentB)

	-- Send wounded to the rear, bury the dead, take prisonners
	if OpponentA.AntiPersonnel then
		OpponentB.Dead = GCO.Round(OpponentB.PersonnelCasualties * OpponentA.AntiPersonnel / 100)
	else
		OpponentB.Dead = GCO.Round(OpponentB.PersonnelCasualties * GameInfo.GlobalParameters["COMBAT_BASE_ANTIPERSONNEL_PERCENT"].Value / 100)
	end	
	if OpponentA.CanTakePrisonners then	
		if OpponentA.CapturedPersonnelRatio then
			OpponentB.Captured = GCO.Round((OpponentB.PersonnelCasualties - OpponentB.Dead) * OpponentA.CapturedPersonnelRatio / 100)
		else
			OpponentB.Captured = GCO.Round((OpponentB.PersonnelCasualties - OpponentB.Dead) * GameInfo.GlobalParameters["COMBAT_CAPTURED_PERSONNEL_PERCENT"].Value / 100)
		end	
		if OpponentA.MaxCapture then
			OpponentB.Captured = math.min(OpponentA.MaxCapture, OpponentB.Captured)
		end
	else
		OpponentB.Captured = 0
	end	
	OpponentB.Wounded = OpponentB.PersonnelCasualties - OpponentB.Dead - OpponentB.Captured
	
	-- Salvage Vehicles
	OpponentB.VehiclesLost = GCO.Round(OpponentB.VehiclesCasualties / 2) -- hardcoded for testing, to do : get Anti-Vehicule stat (anti-tank, anti-ship, anti-air...) from opponent, maybe use also era difference (asymetry between weapon and protection used)
	OpponentB.DamagedVehicles = OpponentB.VehiclesCasualties - OpponentB.VehiclesLost
	
	-- They Shoot Horses, Don't They?
	OpponentB.HorsesLost = OpponentB.HorsesCasualties -- some of those may be captured by the opponent ?
	
	-- Materiel too is a full lost
	OpponentB.MaterielLost = OpponentB.MaterielCasualties
				
	-- Apply Casualties	transfert
	ExposedMembers.UnitData[OpponentB.unitKey].WoundedPersonnel = ExposedMembers.UnitData[OpponentB.unitKey].WoundedPersonnel 	+ OpponentB.Wounded
	ExposedMembers.UnitData[OpponentB.unitKey].DamagedVehicles 	= ExposedMembers.UnitData[OpponentB.unitKey].DamagedVehicles 	+ OpponentB.DamagedVehicles
	
	-- Update Stats
	ExposedMembers.UnitData[OpponentB.unitKey].TotalDeath			= ExposedMembers.UnitData[OpponentB.unitKey].TotalDeath 		+ OpponentB.Dead
	ExposedMembers.UnitData[OpponentB.unitKey].TotalVehiclesLost	= ExposedMembers.UnitData[OpponentB.unitKey].TotalVehiclesLost 	+ OpponentB.VehiclesLost
	ExposedMembers.UnitData[OpponentB.unitKey].TotalHorsesLost 		= ExposedMembers.UnitData[OpponentB.unitKey].TotalHorsesLost 	+ OpponentB.HorsesLost

	return OpponentB
end

function GetMaterielFromKillOfBy(OpponentA, OpponentB)
	-- capture most materiel, convert some damaged Vehicles
	local materielFromKill = 0
	local materielFromCombat = OpponentA.MaterielLost * tonumber(GameInfo.GlobalParameters["COMBAT_ATTACKER_MATERIEL_GAIN_PERCENT"].Value) / 100
	local materielFromReserve = ExposedMembers.UnitData[OpponentA.unitKey].MaterielReserve * tonumber(GameInfo.GlobalParameters["COMBAT_ATTACKER_MATERIEL_KILL_PERCENT"].Value) /100
	local materielFromVehicles = ExposedMembers.UnitData[OpponentA.unitKey].DamagedVehicles * ExposedMembers.UnitData[OpponentA.unitKey].MaterielPerVehicles * tonumber(GameInfo.GlobalParameters["UNIT_MATERIEL_TO_REPAIR_VEHICLE_PERCENT"].Value) / 100 * tonumber(GameInfo.GlobalParameters["COMBAT_ATTACKER_VEHICLES_KILL_PERCENT"].Value) / 100
	materielFromKill = GCO.Round(materielFromCombat + materielFromReserve + materielFromVehicles) 
	return materielFromKill
end

local combatCount = 0
function OnCombat( combatResult )
	-- for console debugging...
	ExposedMembers.lastCombat = combatResult
	
	combatCount = combatCount + 1
	print("--============================================--")
	print("-- Starting Combat #"..tostring(combatCount))
	print("--============================================--")

	local attacker = combatResult[CombatResultParameters.ATTACKER]
	local defender = combatResult[CombatResultParameters.DEFENDER]

	local combatType = combatResult[CombatResultParameters.COMBAT_TYPE]

	attacker.IsUnit = attacker[CombatResultParameters.ID].type == ComponentType.UNIT
	defender.IsUnit = defender[CombatResultParameters.ID].type == ComponentType.UNIT

	local componentString = { [ComponentType.UNIT] = "UNIT", [ComponentType.CITY] = "CITY", [ComponentType.DISTRICT] = "DISTRICT"}
	print("-- Attacker is " .. tostring(componentString[attacker[CombatResultParameters.ID].type]) ..", Damage = " .. attacker[CombatResultParameters.DAMAGE_TO] ..", Final HP = " .. tostring(attacker[CombatResultParameters.MAX_HIT_POINTS] - attacker[CombatResultParameters.FINAL_DAMAGE_TO]))
	print("-- Defender is " .. tostring(componentString[defender[CombatResultParameters.ID].type]) ..", Damage = " .. defender[CombatResultParameters.DAMAGE_TO] ..", Final HP = " .. tostring(defender[CombatResultParameters.MAX_HIT_POINTS] - defender[CombatResultParameters.FINAL_DAMAGE_TO]))

	-- We need to set some info before handling the change in the units composition
	if attacker.IsUnit then
		attacker.IsAttacker = true
		-- attach everything required by the update functions from the base CombatResultParameters
		attacker.FinalHP = attacker[CombatResultParameters.MAX_HIT_POINTS] - attacker[CombatResultParameters.FINAL_DAMAGE_TO]
		attacker.InitialHP = attacker.FinalHP + attacker[CombatResultParameters.DAMAGE_TO]
		attacker.IsDead = attacker[CombatResultParameters.FINAL_DAMAGE_TO] > attacker[CombatResultParameters.MAX_HIT_POINTS]
		attacker.playerID = tostring(attacker[CombatResultParameters.ID].player) -- playerID is a key for Prisonners table
		attacker.unitID = attacker[CombatResultParameters.ID].id
		-- add information needed to handle casualties made to the other opponent (including unitKey)
		attacker = AddCombatInfoTo(attacker)
		--
		attacker.CanTakePrisonners = attacker.IsLandUnit and combatType == CombatTypes.MELEE and not attacker.IsDead
		print("-- Attacker data initialized : "..tostring(GameInfo.Units[attacker.unit:GetType()].UnitType).." id#".. tostring(attacker.unit:GetID()).." player#"..tostring(attacker.unit:GetOwner()) .. ", IsDead = ".. tostring(attacker.IsDead) .. ", CanTakePrisonners = ".. tostring(attacker.CanTakePrisonners))
	end
	if defender.IsUnit then
		defender.IsDefender = true
		-- attach everything required by the update functions from the base CombatResultParameters
		defender.FinalHP = defender[CombatResultParameters.MAX_HIT_POINTS] - defender[CombatResultParameters.FINAL_DAMAGE_TO]
		defender.InitialHP = defender.FinalHP + defender[CombatResultParameters.DAMAGE_TO]
		defender.IsDead = defender[CombatResultParameters.FINAL_DAMAGE_TO] > defender[CombatResultParameters.MAX_HIT_POINTS]
		defender.playerID = tostring(defender[CombatResultParameters.ID].player)
		defender.unitID = defender[CombatResultParameters.ID].id
		-- add information needed to handle casualties made to the other opponent (including unitKey)
		defender = AddCombatInfoTo(defender)
		--
		defender.CanTakePrisonners = defender.IsLandUnit and combatType == CombatTypes.MELEE and not defender.IsDead
		print("-- Defender data initialized : "..tostring(GameInfo.Units[defender.unit:GetType()].UnitType).." id#".. tostring(defender.unit:GetID()).." player#"..tostring(defender.unit:GetOwner()) .. ", IsDead = ".. tostring(defender.IsDead) .. ", CanTakePrisonners = ".. tostring(defender.CanTakePrisonners))
	end

	-- Error control
	---[[
	if attacker.unit then
		local testHP = attacker.unit:GetMaxDamage() - attacker.unit:GetDamage()
		if testHP ~= attacker.FinalHP or ExposedMembers.UnitData[attacker.unitKey].HP ~= attacker.InitialHP then
			print("ERROR: HP not equals to prediction in combatResult for "..tostring(GameInfo.Units[attacker.unit:GetType()].UnitType).." id#".. tostring(attacker.unit:GetID()).." player#"..tostring(attacker.unit:GetOwner()))
			print("attacker.FinalHP = attacker[CombatResultParameters.MAX_HIT_POINTS] - attacker[CombatResultParameters.FINAL_DAMAGE_TO] = ")
			print(attacker.FinalHP, "=", attacker[CombatResultParameters.MAX_HIT_POINTS], "-", attacker[CombatResultParameters.FINAL_DAMAGE_TO])
			print("real HP =", testHP)
			print("attacker.InitialHP = ", attacker.InitialHP)
			print("previous HP = ", ExposedMembers.UnitData[attacker.unitKey].HP)
			print("attacker[CombatResultParameters.DAMAGE_TO] = ", attacker[CombatResultParameters.DAMAGE_TO])
			--attacker.InitialHP = ExposedMembers.UnitData[attacker.unitKey].HP
			--attacker.FinalHP = testHP			
		end		
		ExposedMembers.UnitData[attacker.unitKey].HP = testHP
	end
	if defender.unit then
		local testHP = defender.unit:GetMaxDamage() - defender.unit:GetDamage()
		if testHP ~= defender.FinalHP or ExposedMembers.UnitData[defender.unitKey].HP ~= defender.InitialHP then
			print("ERROR: HP not equals to prediction in combatResult for "..tostring(GameInfo.Units[defender.unit:GetType()].UnitType).." id#".. tostring(defender.unit:GetID()).." player#"..tostring(defender.unit:GetOwner()))
			print("defender.FinalHP = defender[CombatResultParameters.MAX_HIT_POINTS] - defender[CombatResultParameters.FINAL_DAMAGE_TO] = ")
			print(defender.FinalHP, "=", defender[CombatResultParameters.MAX_HIT_POINTS], "-", defender[CombatResultParameters.FINAL_DAMAGE_TO])
			print("real HP =", testHP)
			print("defender.InitialHP = ", defender.InitialHP)
			print("previous HP = ", ExposedMembers.UnitData[defender.unitKey].HP)
			print("defender[CombatResultParameters.DAMAGE_TO] = ", defender[CombatResultParameters.DAMAGE_TO])
			--defender.InitialHP = ExposedMembers.UnitData[defender.unitKey].HP
			--defender.FinalHP = testHP			
		end		
		ExposedMembers.UnitData[defender.unitKey].HP = testHP
	end	
	
	if attacker.IsUnit and not attacker.IsDead then
		CheckComponentsHP(attacker.unit, "attacker before handling combat casualties", true)
	end
	if defender.IsUnit and not defender.IsDead then
		CheckComponentsHP(defender.unit, "defender before handling combat casualties", true)
	end	

	print("--++++++++++++++++++++++--")
	print("-- Casualties in Combat #"..tostring(combatCount))
	print("--++++++++++++++++++++++--")
	--]]

	-- Handle casualties
	if attacker.IsUnit then -- and attacker[CombatResultParameters.DAMAGE_TO] > 0 (we must fill data for even when the unit didn't take damage, else we'll have to check for nil entries before all operations...)
		if attacker.unit then
			if ExposedMembers.UnitData[attacker.unitKey] then
				attacker = AddFrontLineCasualtiesInfoTo(attacker) 		-- Set Personnel, Vehicles, Horses and Materiel casualties from the HP lost
				attacker = AddCasualtiesInfoByTo(defender, attacker) 	-- set detailed casualties (Dead, Captured, Wounded, Damaged, ...) from frontline Casualties and return the updated table
				if not attacker.IsDead then
					LuaEvents.UnitsCompositionUpdated(attacker.playerID, attacker.unitID) 	-- call to update flag
					ShowCasualtiesFloatingText(attacker)									-- visualize all casualties
				end
			end
		end
	end

	if defender.IsUnit then -- and defender[CombatResultParameters.DAMAGE_TO] > 0 (we must fill data for even when the unit didn't take damage, else we'll have to check for nil entries before all operations...)
		if defender.unit then
			if ExposedMembers.UnitData[defender.unitKey] then
				defender = AddFrontLineCasualtiesInfoTo(defender) 		-- Set Personnel, Vehicles, Horses and Materiel casualties from the HP lost
				defender = AddCasualtiesInfoByTo(attacker, defender) 	-- set detailed casualties (Dead, Captured, Wounded, Damaged, ...) from frontline Casualties and return the updated table
				if not defender.IsDead then
					LuaEvents.UnitsCompositionUpdated(defender.playerID, defender.unitID)	-- call to update flag
					ShowCasualtiesFloatingText(defender)									-- visualize all casualties
				end
			end
		end
	end
	

	--print("--++++++++++++++++++++++--")
	--print("-- Stats in Combat #"..tostring(combatCount))
	--print("--++++++++++++++++++++++--")

	-- Update some stats
	if attacker.IsUnit and defender.Dead then ExposedMembers.UnitData[attacker.unitKey].TotalKill = ExposedMembers.UnitData[attacker.unitKey].TotalKill + defender.Dead end
	if defender.IsUnit and attacker.Dead then ExposedMembers.UnitData[defender.unitKey].TotalKill = ExposedMembers.UnitData[defender.unitKey].TotalKill + attacker.Dead end

	if attacker.IsUnit and defender.IsUnit then
		local turn = Game.GetCurrentGameTurn()
		ExposedMembers.UnitData[attacker.unitKey].LastCombatTurn = turn
		ExposedMembers.UnitData[defender.unitKey].LastCombatTurn = turn

		ExposedMembers.UnitData[attacker.unitKey].LastCombatResult = defender[CombatResultParameters.DAMAGE_TO] - attacker[CombatResultParameters.DAMAGE_TO]
		ExposedMembers.UnitData[defender.unitKey].LastCombatResult = attacker[CombatResultParameters.DAMAGE_TO] - defender[CombatResultParameters.DAMAGE_TO]

		ExposedMembers.UnitData[attacker.unitKey].LastCombatType = combatType
		ExposedMembers.UnitData[defender.unitKey].LastCombatType = combatType
	end
	

	--print("--++++++++++++++++++++++--")
	--print("-- Plundering in Combat #"..tostring(combatCount))
	--print("--++++++++++++++++++++++--")

	-- Plundering (with some bonuses to attack)
	if defender.IsLandUnit and combatType == CombatTypes.MELEE then -- and attacker.IsLandUnit (allow raiding on coast ?)

		if defender.IsDead then

			attacker.Prisonners = defender.Captured + ExposedMembers.UnitData[defender.unitKey].WoundedPersonnel -- capture all the wounded (to do : add prisonners drom enemy nationality here)
			attacker.MaterielGained = GetMaterielFromKillOfBy(defender, attacker)
			attacker.LiberatedPrisonners = GCO.GetTotalPrisonners(ExposedMembers.UnitData[defender.unitKey]) -- to do : recruit only some of the enemy prisonners and liberate own prisonners
			attacker.FoodGained = GCO.Round(ExposedMembers.UnitData[defender.unitKey].FoodStock * tonumber(GameInfo.GlobalParameters["COMBAT_ATTACKER_FOOD_KILL_PERCENT"].Value) /100)
			attacker.FoodGained = math.max(0, math.min(GetUnitBaseFoodStock(attacker.unit:GetType()) - ExposedMembers.UnitData[attacker.unitKey].FoodStock, attacker.FoodGained ))

			-- Update composition
			ExposedMembers.UnitData[defender.unitKey].WoundedPersonnel 	= 0 -- Just to keep things clean...
			ExposedMembers.UnitData[defender.unitKey].FoodStock 		= ExposedMembers.UnitData[defender.unitKey].FoodStock 			- attacker.FoodGained -- Just to keep things clean...
			ExposedMembers.UnitData[attacker.unitKey].MaterielReserve 	= ExposedMembers.UnitData[attacker.unitKey].MaterielReserve 	+ attacker.MaterielGained
			ExposedMembers.UnitData[attacker.unitKey].PersonnelReserve 	= ExposedMembers.UnitData[attacker.unitKey].PersonnelReserve 	+ attacker.LiberatedPrisonners
			ExposedMembers.UnitData[attacker.unitKey].FoodStock 		= ExposedMembers.UnitData[attacker.unitKey].FoodStock 			+ attacker.FoodGained
			-- To do : prisonners by nationality
			ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID]	= ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID] + attacker.Prisonners

		else
			-- attacker
			attacker.Prisonners 	= defender.Captured
			attacker.MaterielGained = GCO.Round(defender.MaterielLost * tonumber(GameInfo.GlobalParameters["COMBAT_ATTACKER_MATERIEL_GAIN_PERCENT"].Value) /100)
			ExposedMembers.UnitData[attacker.unitKey].MaterielReserve 				= ExposedMembers.UnitData[attacker.unitKey].MaterielReserve + attacker.MaterielGained
			ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID]	= ExposedMembers.UnitData[attacker.unitKey].Prisonners[defender.playerID] + attacker.Prisonners

			-- defender
			defender.Prisonners 	= attacker.Captured
			defender.MaterielGained = GCO.Round(attacker.MaterielLost * tonumber(GameInfo.GlobalParameters["COMBAT_DEFENDER_MATERIEL_GAIN_PERCENT"].Value) /100)
			ExposedMembers.UnitData[defender.unitKey].MaterielReserve 				= ExposedMembers.UnitData[defender.unitKey].MaterielReserve + defender.MaterielGained
			ExposedMembers.UnitData[defender.unitKey].Prisonners[attacker.playerID]	= ExposedMembers.UnitData[defender.unitKey].Prisonners[attacker.playerID] + defender.Prisonners

		end

		-- Update unit's flag & visualize for attacker
		if attacker.unit then
			ShowCombatPlunderingFloatingText(attacker)
			LuaEvents.UnitsCompositionUpdated(attacker.playerID, attacker.unitID)
		end

		-- Update unit's flag & visualize for defender
		if defender.unit then
			ShowCombatPlunderingFloatingText(defender)
			LuaEvents.UnitsCompositionUpdated(defender.playerID, defender.unitID)
		end
	end
	
	---[[
	print("--++++++++++++++++++++++--")
	print("-- Control in Combat #"..tostring(combatCount))
	print("--++++++++++++++++++++++--")
		
	if attacker.IsUnit and not attacker.IsDead then CheckComponentsHP(attacker.unit, "attacker after combat") end
	if defender.IsUnit and not defender.IsDead then CheckComponentsHP(defender.unit, "defender after combat") end		
	
	function p(table)
		 for k, v in pairs(table) do
			 if type(k) == "string" and type(v) ~= "table" then print(k,v); end
		end;
	end
--[[
	print("--++++++++++++++++++++++--")
	print("-- Ending Combat #"..tostring(combatCount))
	print("--++++++++++++++++++++++--")
	print("-  ATTACKER -")
	print("--+++++++++--")
	p(attacker)
	print("--+++++++++--")
	print("-  DEFENDER -")
	print("--+++++++++--")
	p(defender)
	print("-----------------------------------------------------------------------------------------")
	--]]
	
end
Events.Combat.Add( OnCombat )


-----------------------------------------------------------------------------------------
-- Healing
-----------------------------------------------------------------------------------------
function HealingUnits(playerID)

	local player = Players[playerID]
	local playerConfig = PlayerConfigurations[playerID]
	local playerUnits = player:GetUnits()
	if playerUnits then
		print("-----------------------------------------------------------------------------------------")
		print("Healing units for " .. tostring(Locale.Lookup(playerConfig:GetCivilizationShortDescription())))

		local startTime = Automation.GetTime()

		-- stock units in a table from higher damage to lower
		local damaged = {}		-- List of damaged units needing reinforcements, ordered by healt left
		local healTable = {} 	-- This table store HP gained to apply en masse after all reinforcements are calculated (visual fix)
		for n = 0, maxHP do 	-- An unit can still be alive at 0 HP ?
			damaged[n] = {}
		end

		local maxTransfert = {}	-- maximum value of a component that can be used to heal in one turn
		local alreadyUsed = {}	-- materiel is used both to heal the unit (reserve -> front) and repair vehicules in reserve, up to a limit
		for i, unit in playerUnits:Members() do
			-- todo : check if the unit can heal (has a supply line, is not on water, ...)
			local hp = unit:GetMaxDamage() - unit:GetDamage()
			if hp < maxHP and CheckComponentsHP(unit, "bypassing healing") then
				table.insert(damaged[hp], unit)
				healTable[unit] = 0
			end
			maxTransfert[unit] = GetMaxTransfertTable(unit)
			alreadyUsed[unit] = {}
			alreadyUsed[unit].Materiel = 0
		end

		-- try to reinforce the selected units (move personnel, vehicule, horses, materiel from reserve to frontline)
		-- up to MAX_HP_HEALED (or an unit component limit), 1hp per loop
		local hasReachedLimit = {}
		for healHP = 1, GameInfo.GlobalParameters["UNIT_MAX_HP_HEALED_FROM_RESERVE"].Value do -- to do : add limit by units in the loop
			for n = 0, maxHP do
				local unitTable = damaged[n]
				for j, unit in ipairs (unitTable) do
					if not hasReachedLimit[unit] then
						local hp = unit:GetMaxDamage() - unit:GetDamage()
						local key = unit:GetKey()						
						if key then
							if (hp + healTable[unit] < maxHP) then
								local unitInfo = GameInfo.Units[unit:GetType()] -- GetType in script, GetUnitType in UI context...
								-- check here if the unit has enough reserves to get +1HP
								local reqPersonnel 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Personnel - UnitHitPointsTable[unitInfo.Index][hp].Personnel
								local reqVehicles 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Vehicles 	- UnitHitPointsTable[unitInfo.Index][hp].Vehicles
								local reqHorses 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Horses 	- UnitHitPointsTable[unitInfo.Index][hp].Horses
								local reqMateriel 	= UnitHitPointsTable[unitInfo.Index][hp + healTable[unit] +1].Materiel 	- UnitHitPointsTable[unitInfo.Index][hp].Materiel
								if not ExposedMembers.UnitData[key] then print ("WARNING, no entry for " .. tostring(unit:GetName()) .. " id#" .. tostring(unit:GetID())) end
								-- unit limit (vehicles and horses are handled by personnel...)
								if reqPersonnel > tonumber(maxTransfert[unit].Personnel) or reqMateriel > tonumber(maxTransfert[unit].Materiel) then
									hasReachedLimit[unit] = true
									print("- Reached healing limit for " .. unit:GetName() .. " at " .. tostring(healHP) ..", Requirements : Personnel = ".. tostring(reqPersonnel) .. ", Materiel = " .. tostring(reqMateriel))

								elseif  ExposedMembers.UnitData[key].PersonnelReserve >= reqPersonnel
								and 	ExposedMembers.UnitData[key].VehiclesReserve >= reqVehicles
								and 	ExposedMembers.UnitData[key].HorsesReserve >= reqHorses
								and 	ExposedMembers.UnitData[key].MaterielReserve >= reqMateriel
								then
									healTable[unit] = healTable[unit] + 1 -- store +1 HP for this unit
								end
							end
						end
					end
				end
			end
		end

		-- apply reinforcement from all passes to units in one call to SetDamage (fix visual display of one "+1" when the unit was getting possibly more)
		for unit, hp in pairs (healTable) do
			CheckComponentsHP(unit, "before Healing")
			local key = unit:GetKey()
			if key then

				local unitInfo = GameInfo.Units[unit:GetType()]
				local damage = unit:GetDamage()
				local initialHP = maxHP - damage
				local finalHP = initialHP + hp
				--print("initialHP:", initialHP , "finalHP:", finalHP, "hp from heal table:", hp)
				unit:SetDamage(damage-hp)
				ExposedMembers.UnitData[key].HP = finalHP

				-- update reserve and frontline...
				local reqPersonnel 	= UnitHitPointsTable[unitInfo.Index][finalHP].Personnel - UnitHitPointsTable[unitInfo.Index][initialHP].Personnel
				local reqVehicles 	= UnitHitPointsTable[unitInfo.Index][finalHP].Vehicles - UnitHitPointsTable[unitInfo.Index][initialHP].Vehicles
				local reqHorses 	= UnitHitPointsTable[unitInfo.Index][finalHP].Horses 	- UnitHitPointsTable[unitInfo.Index][initialHP].Horses
				local reqMateriel 	= UnitHitPointsTable[unitInfo.Index][finalHP].Materiel 	- UnitHitPointsTable[unitInfo.Index][initialHP].Materiel

				ExposedMembers.UnitData[key].PersonnelReserve 	= ExposedMembers.UnitData[key].PersonnelReserve - reqPersonnel
				ExposedMembers.UnitData[key].VehiclesReserve 	= ExposedMembers.UnitData[key].VehiclesReserve 	- reqVehicles
				ExposedMembers.UnitData[key].HorsesReserve 		= ExposedMembers.UnitData[key].HorsesReserve 	- reqHorses
				ExposedMembers.UnitData[key].MaterielReserve 	= ExposedMembers.UnitData[key].MaterielReserve 	- reqMateriel

				ExposedMembers.UnitData[key].Personnel 	= ExposedMembers.UnitData[key].Personnel 	+ reqPersonnel
				ExposedMembers.UnitData[key].Vehicles 	= ExposedMembers.UnitData[key].Vehicles 	+ reqVehicles
				ExposedMembers.UnitData[key].Horses 	= ExposedMembers.UnitData[key].Horses 		+ reqHorses
				ExposedMembers.UnitData[key].Materiel 	= ExposedMembers.UnitData[key].Materiel 	+ reqMateriel

				alreadyUsed[unit].Materiel = reqMateriel

				-- Visualize healing
				local healingData = {reqPersonnel = reqPersonnel, reqMateriel = reqMateriel, reqVehicles = reqVehicles, reqHorses = reqHorses, X = unit:GetX(), Y = unit:GetY() }
				ShowFrontLineHealingFloatingText(healingData)

				LuaEvents.UnitsCompositionUpdated(playerID, unit:GetID()) -- call to update flag
				
				CheckComponentsHP(unit, "after Healing")
			end

		end

		-- try to heal wounded and repair Vehicles using materiel (move healed personnel and repaired Vehicles to reserve)
		for i, unit in playerUnits:Members() do
			local key = unit:GetKey()
			if key then
				if ExposedMembers.UnitData[key] then
					-- wounded soldiers may die...
					local deads = GCO.Round(ExposedMembers.UnitData[key].WoundedPersonnel * 25/100) -- hardcoded, to do : era, promotions, support
					ExposedMembers.UnitData[key].WoundedPersonnel = ExposedMembers.UnitData[key].WoundedPersonnel - deads
					-- wounded soldiers may heal...
					local healed = math.ceil(ExposedMembers.UnitData[key].WoundedPersonnel * 25/100) -- hardcoded, to do : era, promotions, support (not rounded to heal last wounded)
					ExposedMembers.UnitData[key].WoundedPersonnel = ExposedMembers.UnitData[key].WoundedPersonnel - healed
					ExposedMembers.UnitData[key].PersonnelReserve = ExposedMembers.UnitData[key].PersonnelReserve + healed

					-- try to repair vehicles with materiel available left (= logistic/maintenance limit)
					local materielAvailable = maxTransfert[unit].Materiel - alreadyUsed[unit].Materiel
					local maxRepairedVehicles = GCO.Round(materielAvailable/(ExposedMembers.UnitData[key].MaterielPerVehicles* GameInfo.GlobalParameters["UNIT_MATERIEL_TO_REPAIR_VEHICLE_PERCENT"].Value/100))
					local repairedVehicules = 0
					if maxRepairedVehicles > 0 then
						repairedVehicules = math.min(maxRepairedVehicles, ExposedMembers.UnitData[key].DamagedVehicles)
						ExposedMembers.UnitData[key].DamagedVehicles = ExposedMembers.UnitData[key].DamagedVehicles - repairedVehicules
						ExposedMembers.UnitData[key].VehiclesReserve = ExposedMembers.UnitData[key].VehiclesReserve + repairedVehicules
					end

					-- Visualize healing
					local healingData = {deads = deads, healed = healed, repairedVehicules = repairedVehicules, X = unit:GetX(), Y = unit:GetY() }
					ShowReserveHealingFloatingText(healingData)

					LuaEvents.UnitsCompositionUpdated(playerID, unit:GetID()) -- call to update flag
				else
					print ("- WARNING : no entry in ExposedMembers.UnitData for unit ".. tostring(unit:GetName()) .." (key = ".. tostring(key) ..") in HealingUnits()")
				end
			else
				print ("- WARNING : key is nil for unit ".. tostring(unit) .." in HealingUnits()")
			end
		end

		local endTime = Automation.GetTime()
		print("Healing units used " .. tostring(endTime-startTime) .. " seconds")
		print("-----------------------------------------------------------------------------------------")
	end
end


-----------------------------------------------------------------------------------------
-- Supply Lines
-----------------------------------------------------------------------------------------
-- cf Worldinput.lua
--pathPlots, turnsList, obstacles = UnitManager.GetMoveToPath( kUnit, endPlotId )

function SupplyPathBlocked(pPlot, pPlayer)

	local ownerID = pPlot:GetOwner()
	local playerID = pPlayer:GetID()

	local aUnits = Units.GetUnitsInPlot(plot);
	for i, pUnit in ipairs(aUnits) do
		if pPlayer:GetDiplomacy():IsAtWarWith( pUnit:GetOwner() ) then return true end -- path blocked
	end
		
	if ( ownerID == playerID or ownerID == -1 ) then
		return false
	end

	if GCO.HasPlayerOpenBordersFrom(pPlayer, ownerID) then
		return false
	end	

	return true -- return true if the path is blocked...
end

function SetUnitsupplyLine(unit)
	local key = unit:GetKey()
	local NoLinkToCity = true
	--local unitData = ExposedMembers.UnitData[key]
	local closestCity, distance = GCO.FindNearestPlayerCity( unit:GetOwner(), unit:GetX(), unit:GetY() )
	if closestCity then
		GCO.AttachCityFunctions(closestCity)
		local cityPlot = Map.GetPlot(closestCity:GetX(), closestCity:GetY())
		--[[
		local pathPlots, turnsList, obstacles = GCO.GetMoveToPath( unit, cityPlot:GetIndex() ) -- can't be used as it takes unit stacking in account and return false if there is an unit in the city.
		if table.count(pathPlots) > 1 then
			local numTurns = turnsList[table.count( turnsList )]
			local efficiency = GCO.Round( 100 - math.pow(numTurns,2) )
			if efficiency > 50 then -- to do : allow players to change this value
				ExposedMembers.UnitData[key].SupplyLineCityKey = GCO.GetCityKey(closestCity)
				ExposedMembers.UnitData[key].SupplyLineCityOwner = closestCity:GetOwner()
				ExposedMembers.UnitData[key].SupplyLineEfficiency = efficiency
				NoLinkToCity = false
			end
		--]]
		local bShortestRoute = true
		local bIsPlotConnected = GCO.IsPlotConnected(Players[unit:GetOwner()], Map.GetPlot(unit:GetX(), unit:GetY()), cityPlot, "Land", bShortestRoute, nil, SupplyPathBlocked)
		local routeLength = GCO.GetRouteLength()
		if bIsPlotConnected then
			local efficiency = GCO.Round( 100 - math.pow(routeLength*0.85,2) )
			if efficiency > 50 then -- to do : allow players to change this value
				ExposedMembers.UnitData[key].SupplyLineCityKey = closestCity:GetKey()
				ExposedMembers.UnitData[key].SupplyLineEfficiency = efficiency
				NoLinkToCity = false
			else
				ExposedMembers.UnitData[key].SupplyLineCityKey = closestCity:GetKey()
				ExposedMembers.UnitData[key].SupplyLineEfficiency = 0
				NoLinkToCity = false
			end
		
		elseif distance == 0 then -- unit is on the city's plot...
			ExposedMembers.UnitData[key].SupplyLineCityKey = closestCity:GetKey()
			ExposedMembers.UnitData[key].SupplyLineEfficiency = 100
			NoLinkToCity = false
		end
	end
	
	if NoLinkToCity then
		ExposedMembers.UnitData[key].SupplyLineCityKey = nil
		ExposedMembers.UnitData[key].SupplyLineEfficiency = 0
	end
end


-----------------------------------------------------------------------------------------
-- Do Turn for Units
-----------------------------------------------------------------------------------------
function DoUnitFood(unit)

	local key = unit:GetKey()
	local unitData = ExposedMembers.UnitData[key]
	
	if unitData.TurnCreated == Game.GetCurrentGameTurn() then return end -- don't eat on first turn

	-- Eat Food
	local foodEat = math.min(GetUnitFoodConsumption(unitData), unitData.FoodStock)

	-- Get Food
	local foodGet = 0
	local iX = unit:GetX()
	local iY = unit:GetY()
	local adjacentRatio = tonumber(GameInfo.GlobalParameters["FOOD_COLLECTING_ADJACENT_PLOT_RATIO"].Value)
	local yieldFood = GameInfo.Yields["YIELD_FOOD"].Index
	local maxFoodStock = GetUnitBaseFoodStock(unitData.unitType)
	-- Get food from the plot
	local plot = Map.GetPlot(iX, iY)
	if plot then
		foodGet = foodGet + (plot:GetYield(yieldFood) / (math.max(1, Units.GetUnitCountInPlot(plot))))
	end
	-- Get food from adjacent plots
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil) and ((not adjacentPlot:IsOwned()) or adjacentPlot:GetOwner() == unit:GetOwner() ) then
			foodGet = foodGet + ((adjacentPlot:GetYield(yieldFood) / (1 + Units.GetUnitCountInPlot(adjacentPlot))) * adjacentRatio)
		end
	end
	foodGet = GCO.Round(foodGet)
	foodGet = math.max(0, math.min(maxFoodStock + foodEat - unitData.FoodStock, foodGet))

	-- Update variation
	local foodVariation = foodGet - foodEat
	ExposedMembers.UnitData[key].PreviousFoodStock = unitData.FoodStock
	ExposedMembers.UnitData[key].FoodStock = unitData.FoodStock + foodVariation

	-- Visualize
	local foodData = { foodEat = foodEat, foodGet = foodGet, X = unit:GetX(), Y = unit:GetY() }
	ShowFoodFloatingText(foodData)
end

function DoUnitMorale(unit)

	if not CheckComponentsHP(unit, "bypassing DoUnitMorale()") then
		return
	end
	
	local key = unit:GetKey()
	local unitData = ExposedMembers.UnitData[key]
	local moraleVariation = 0
	
	moraleVariation = moraleVariation + GetMoraleFromFood(unitData)
	moraleVariation = moraleVariation + GetMoraleFromLastCombat(unitData)
	moraleVariation = moraleVariation + GetMoraleFromWounded(unitData)
	moraleVariation = moraleVariation + GetMoraleFromHP(unitData)
	
	local morale = math.max(0, math.min(ExposedMembers.UnitData[key].Morale + moraleVariation, tonumber(GameInfo.GlobalParameters["MORALE_BASE_VALUE"].Value)))
	ExposedMembers.UnitData[key].Morale = morale
	ExposedMembers.UnitData[key].MoraleVariation = moraleVariation

	local desertionRate, minPercentHP, minPercentReserve = 0
	if morale < tonumber(GameInfo.GlobalParameters["MORALE_BAD_PERCENT"].Value) then -- very low morale
		desertionRate 		= tonumber(GameInfo.GlobalParameters["MORALE_BAD_DESERTION_RATE"].Value) --3
		minPercentHP 		= tonumber(GameInfo.GlobalParameters["MORALE_BAD_MIN_PERCENT_HP"].Value) --50
		minPercentReserve 	= tonumber(GameInfo.GlobalParameters["MORALE_BAD_MIN_PERCENT_RESERVE"].Value) --25
	elseif morale < tonumber(GameInfo.GlobalParameters["MORALE_LOW_PERCENT"].Value) then -- low morale
		desertionRate 		= tonumber(GameInfo.GlobalParameters["MORALE_LOW_DESERTION_RATE"].Value) --1
		minPercentHP 		= tonumber(GameInfo.GlobalParameters["MORALE_LOW_MIN_PERCENT_HP"].Value) --75
		minPercentReserve 	= tonumber(GameInfo.GlobalParameters["MORALE_LOW_MIN_PERCENT_RESERVE"].Value) --50
	end
	
	CheckComponentsHP(unit, "In DoUnitMorale(), desertion Rate = " .. tostring(desertionRate))
	if desertionRate > 0 then
		local HP = unit:GetMaxDamage() - unit:GetDamage()
		local unitType = unit:GetType()
		local personnelReservePercent = GCO.Round( ExposedMembers.UnitData[key].PersonnelReserve / GetPersonnelReserve(unitType) * 100)
		local desertionData = {Personnel = 0, Vehicles = 0, Horses = 0, Materiel = 0, GiveDamage = false, Show = false, X = unit:GetX(), Y = unit:GetY() }
		local lostHP = 0
		local finalHP = HP
		if HP > minPercentHP then
			lostHP = math.max(1, GCO.Round(HP * desertionRate / 100))
			finalHP = HP - lostHP

			-- Get desertion number
			desertionData.Personnel = UnitHitPointsTable[unitType][HP].Personnel 	- UnitHitPointsTable[unitType][finalHP].Personnel
			desertionData.Vehicles 	= UnitHitPointsTable[unitType][HP].Vehicles 	- UnitHitPointsTable[unitType][finalHP].Vehicles
			desertionData.Horses 	= UnitHitPointsTable[unitType][HP].Horses		- UnitHitPointsTable[unitType][finalHP].Horses
			desertionData.Materiel	= UnitHitPointsTable[unitType][HP].Materiel 	- UnitHitPointsTable[unitType][finalHP].Materiel

			-- Remove deserters from frontline
			ExposedMembers.UnitData[key].Personnel 	= ExposedMembers.UnitData[key].Personnel  	- desertionData.Personnel
			ExposedMembers.UnitData[key].Vehicles  	= ExposedMembers.UnitData[key].Vehicles  	- desertionData.Vehicles
			ExposedMembers.UnitData[key].Horses		= ExposedMembers.UnitData[key].Horses	  	- desertionData.Horses
			ExposedMembers.UnitData[key].Materiel 	= ExposedMembers.UnitData[key].Materiel 	- desertionData.Materiel

			-- Store materiel, vehicles, horses
			ExposedMembers.UnitData[key].VehiclesReserve  	= ExposedMembers.UnitData[key].VehiclesReserve 	+ desertionData.Vehicles
			ExposedMembers.UnitData[key].HorsesReserve		= ExposedMembers.UnitData[key].HorsesReserve	+ desertionData.Horses
			ExposedMembers.UnitData[key].MaterielReserve 	= ExposedMembers.UnitData[key].MaterielReserve 	+ desertionData.Materiel

			desertionData.GiveDamage = true
			desertionData.Show = true

		end
		if personnelReservePercent > minPercentReserve then
			local lostPersonnel = math.max(1, GCO.Round(ExposedMembers.UnitData[key].PersonnelReserve * desertionRate / 100))

			-- Add desertion number
			desertionData.Personnel = desertionData.Personnel + lostPersonnel

			-- Remove deserters from reserve
			ExposedMembers.UnitData[key].PersonnelReserve 	= ExposedMembers.UnitData[key].PersonnelReserve	- lostPersonnel

			desertionData.Show = true

		end
		-- Visualize
		if desertionData.Show then
			ShowDesertionFloatingText(desertionData)
		end

		-- Set Damage
		if desertionData.GiveDamage then
			unit:SetDamage(unit:GetDamage() + lostHP)
			ExposedMembers.UnitData[key].HP = finalHP
		end
	end
	CheckComponentsHP(unit, "after DoUnitMorale()")	
end

function DoUnitFuel(unit)

	local key = unit:GetKey()
	local unitData = ExposedMembers.UnitData[key]
	local fuelConsumption = math.min(GetFuelConsumption(unitData), unitData.FuelStock)
	if fuelConsumption > 0 then
		-- Update variation
		ExposedMembers.UnitData[key].PreviousFuelStock = unitData.FuelStock
		ExposedMembers.UnitData[key].FuelStock = unitData.FuelStock - fuelConsumption
		-- Visualize
		local fuelData = { fuelConsumption = fuelConsumption, X = unit:GetX(), Y = unit:GetY() }
		ShowFuelConsumptionFloatingText(fuelData)
	end
end

function UnitDoTurn(unit)
	local key = unit:GetKey()
	if not ExposedMembers.UnitData[key] then
		return
	end
	local playerID = unit:GetOwner()
	
	DoUnitFood(unit)
	DoUnitMorale(unit)
	DoUnitFuel(unit)
	SetUnitsupplyLine(unit)
	LuaEvents.UnitsCompositionUpdated(playerID, unit:GetID())
end

function DoUnitsTurn( playerID )
	HealingUnits( playerID )

	local player = Players[playerID]
	local playerConfig = PlayerConfigurations[playerID]
	local playerUnits = player:GetUnits()
	if playerUnits then
		for i, unit in playerUnits:Members() do
			UnitDoTurn(unit)
		end
	end
end
LuaEvents.DoUnitsTurn.Add( DoUnitsTurn )


-----------------------------------------------------------------------------------------
-- Initialize Unit Functions
-----------------------------------------------------------------------------------------
function InitializeUnitFunctions(playerID, unitID) -- Note that those are limited to this file context
	local unit = UnitManager.GetUnit(playerID, unitID)
	AttachUnitFunctions(unit)
	Events.UnitAddedToMap.Remove(InitializeUnitFunctions)
end

function AttachUnitFunctions(unit)
	local u = getmetatable(unit).__index	
	u.GetKey		= GetKey
end


----------------------------------------------
-- Share functions for other contexts
----------------------------------------------
function ShareFunctions()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	--
	ExposedMembers.GCO.AttachUnitFunctions 			= AttachUnitFunctions
	--
	ExposedMembers.GCO.GetUnitFoodConsumption 		= GetUnitFoodConsumption
	ExposedMembers.GCO.GetFuelConsumption 			= GetFuelConsumption
	-- flag strings
	ExposedMembers.GCO.GetPrisonnersStringByCiv 	= GetPrisonnersStringByCiv
	ExposedMembers.GCO.GetUnitFoodConsumptionString = GetUnitFoodConsumptionString
	ExposedMembers.GCO.GetUnitFoodStockString 		= GetUnitFoodStockString
	ExposedMembers.GCO.GetFuelStockString 			= GetFuelStockString
	ExposedMembers.GCO.GetFuelConsumptionString 	= GetFuelConsumptionString
	ExposedMembers.GCO.GetMoraleString 				= GetMoraleString
	--
	ExposedMembers.UnitScript_Initialized 	= true
end


-----------------------------------------------------------------------------------------
-- Initialize after loading the file...
-----------------------------------------------------------------------------------------
Initialize()


-----------------------------------------------------------------------------------------
-- Test / Debug
-----------------------------------------------------------------------------------------

function TestDamage()
	if not ExposedMembers.UnitData then return end
	for unitKey, data in pairs(ExposedMembers.UnitData) do
		local unit = UnitManager.GetUnit(data.playerID, data.unitID)
		if unit then
			local testHP = unit:GetMaxDamage() - unit:GetDamage()
			if testHP ~= data.testHP then
				print("--------------------------------------- GameCoreEventPublishComplete ---------------------------------------")
				print("changing HP of unit "..tostring(GameInfo.Units[unit:GetType()].UnitType).." id#".. tostring(unit:GetID()).." player#"..tostring(unit:GetOwner()))
				print("previous HP =", data.testHP)
				print("new HP =", testHP)
				print("HP change =", testHP - data.testHP)
				print("------------------------------------------------------------------------------")
				ExposedMembers.UnitData[unitKey].testHP = testHP
			end
		end
	end
end
--Events.GameCoreEventPublishComplete.Add( TestDamage )

function DamageChanged (playerID, unitID, newDamage, prevDamage)
	local unit = UnitManager.GetUnit(playerID, unitID)
	if unit then
		local unitKey = unit:GetKey()
		local data = ExposedMembers.UnitData[unitKey]
		local testHP = unit:GetMaxDamage() - unit:GetDamage()
		print("--------------------------------------- UnitDamageChanged ---------------------------------------")
		print("changing HP of unit "..tostring(GameInfo.Units[unit:GetType()].UnitType).." id#".. tostring(unit:GetID()).." player#"..tostring(unit:GetOwner()))
		print("previous HP =", data.testHP)
		print("new HP =", testHP)
		print("HP change =", testHP - data.testHP)
		print("newDamage, prevDamage =", newDamage, prevDamage)
		print("------------------------------------------------------------------------------")
		--ExposedMembers.UnitData[unitKey].testHP = testHP
	end
end
--Events.UnitDamageChanged.Add(DamageChanged)

